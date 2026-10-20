import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/reserva.dart';
import '../services/api.dart';
import '../widgets/common.dart';
import 'auth_page.dart';

class DetailPage extends StatefulWidget {
  final int casaId;
  const DetailPage({super.key, required this.casaId});
  @override
  State<DetailPage> createState() => _DetailPageState();
}
class _DetailPageState extends State<DetailPage> {
  Casa? _casa;
  List<Periodo> _ocupados = [];
  DateTime _foco = hoje;
  DateTime? _entrada;
  DateTime? _saida;
  int _hospedes = 1;
  int _foto = 0;
  bool _loading = true;
  bool _busy = false;
  Object? _error;
  final _pages = PageController();
  int get _noites => _entrada == null || _saida == null ? 0 : _saida!.difference(_entrada!).inDays;
  bool _conflita(DateTime start, DateTime end) => _ocupados.any((p) => p.sobrepoe(start, end));
  bool get _valido => _noites > 0 && _noites <= 90 && !_saida!.isAfter(limiteReservas) && !_conflita(_entrada!, _saida!);
  @override
  void initState() { super.initState(); _carregar(); }
  @override
  void dispose() { _pages.dispose(); super.dispose(); }

  Future<void> _carregar() async {
    setState(() { _loading = true; _error = null; });
    try {
      final values = await Future.wait([
        api.request('GET', '/houses/${widget.casaId}'),
        api.request('GET', '/houses/${widget.casaId}/availability'),
      ]);
      if (!mounted) return;
      setState(() {
        _casa = Casa.fromJson(values[0]['house'] as Map<String, dynamic>);
        _ocupados = (values[1]['ranges'] as List).map((r) => Periodo.fromJson(r as Map<String, dynamic>)).toList();
      });
    } catch (e) { if (mounted) setState(() => _error = e); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _reservar() async {
    if (!_valido || _busy) return;
    if (!await exigirLogin(context) || !mounted) return;
    final total = moeda(_casa!.diariaCentavos * _noites);
    if (!await confirmar(context, 'Confirmar estadia?', '${formatarData(_entrada!)} até ${formatarData(_saida!)}\n$_noites noite(s) · $total\n\nEsta versão registra a reserva, sem cobrança online.') || !mounted) return;
    setState(() => _busy = true);
    try {
      await api.request('POST', '/bookings', {
        'house_id': _casa!.id, 'start_date': dataApi(_entrada!), 'end_date': dataApi(_saida!),
        'guests': _hospedes, 'expected_price_cents': _casa!.diariaCentavos,
      });
      if (!mounted) return;
      avisar(context, 'Reserva confirmada! Consulte “Minhas reservas”.');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      avisar(context, e);
      // Atualiza preço e disponibilidade após um conflito no servidor.
      await _carregar();
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Widget _calendario(Casa casa) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${moeda(casa.diariaCentavos)} / noite', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8), const Text('Selecione entrada e saída. Até 90 noites.'),
      TableCalendar<Object?>(locale: 'pt_BR', firstDay: hoje, lastDay: limiteReservas, focusedDay: _foco,
        rangeStartDay: _entrada, rangeEndDay: _saida, rangeSelectionMode: RangeSelectionMode.toggledOn,
        startingDayOfWeek: StartingDayOfWeek.monday,
        headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
        calendarStyle: const CalendarStyle(
          rangeStartDecoration: BoxDecoration(color: oceano, shape: BoxShape.circle),
          rangeEndDecoration: BoxDecoration(color: oceano, shape: BoxShape.circle),
          rangeHighlightColor: Color(0xFFDCEAE3), markerDecoration: BoxDecoration(color: Colors.deepOrange, shape: BoxShape.circle)),
        eventLoader: (day) => _ocupados.any((p) => p.contem(somenteData(day))) ? ['ocupado'] : [],
        enabledDayPredicate: (day) {
          final d = somenteData(day);
          if (_entrada != null && _saida == null && d.isAfter(_entrada!)) {
            return d.difference(_entrada!).inDays <= 90 && !_conflita(_entrada!, d);
          }
          return !_ocupados.any((p) => p.contem(d));
        },
        onPageChanged: (day) => _foco = day,
        onRangeSelected: (start, end, focus) {
          setState(() { _entrada = start == null ? null : somenteData(start); _saida = end == null ? null : somenteData(end); _foco = focus; });
        },
      ),
      const Text('● Noite indisponível', style: TextStyle(fontSize: 12, color: Colors.deepOrange)),
      TextButton(onPressed: () => setState(() { _entrada = null; _saida = null; }), child: const Text('Limpar datas')),
      Text('Entrada: ${_entrada == null ? 'Selecione' : formatarData(_entrada!)}'),
      Text('Saída: ${_saida == null ? 'Selecione' : formatarData(_saida!)}'),
      const SizedBox(height: 12),
      Contador(label: 'Hóspedes', value: _hospedes, max: casa.hospedes, onChanged: (n) => setState(() => _hospedes = n)),
      if (_noites > 0) ...[
        Contador(label: 'Noites', value: _noites, max: 90, onChanged: (n) {
          final end = _entrada!.add(Duration(days: n));
          if (_conflita(_entrada!, end) || end.isAfter(limiteReservas)) { avisar(context, 'Este período está indisponível.'); return; }
          setState(() => _saida = end);
        }),
        const Divider(height: 30), Text('${moeda(casa.diariaCentavos)} × $_noites noite(s)'),
        const SizedBox(height: 8), Text('Total: ${moeda(casa.diariaCentavos * _noites)}', style: Theme.of(context).textTheme.titleLarge),
      ],
      if (_noites > 0 && !_valido) const Text('O intervalo selecionado está indisponível.', style: TextStyle(color: Colors.red)),
      const SizedBox(height: 20),
      FilledButton(onPressed: _valido && !_busy && casa.donoId != api.usuario?.id ? _reservar : null,
        child: Text(_busy ? 'Confirmando…' : casa.donoId == api.usuario?.id ? 'Este anúncio é seu' : 'Reservar esta casa')),
      const SizedBox(height: 8), const Text('Sem pagamento online nesta versão.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
    ],
  )));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Conheça sua próxima estadia')),
    body: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? Falha(error: _error!, retry: _carregar) : SingleChildScrollView(child: Conteudo(child: Builder(builder: (context) {
      final casa = _casa!;
      final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(casa.nome, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8), Text('${casa.cidade} · ${casa.hospedes} hóspedes · ${casa.quartos} quarto(s)'),
        const SizedBox(height: 20),
        ClipRRect(borderRadius: BorderRadius.circular(24), child: SizedBox(height: 320, child: PageView.builder(
          controller: _pages, itemCount: casa.fotos.length, onPageChanged: (n) => setState(() => _foto = n),
          itemBuilder: (_, i) => FotoCasa(url: casa.fotos[i]),
        ))),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(tooltip: 'Foto anterior', onPressed: _foto > 0 ? () => _pages.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut) : null, icon: const Icon(Icons.chevron_left)),
          Text('${_foto + 1} / ${casa.fotos.length}'),
          IconButton(tooltip: 'Próxima foto', onPressed: _foto < casa.fotos.length - 1 ? () => _pages.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut) : null, icon: const Icon(Icons.chevron_right)),
        ]),
        const SizedBox(height: 20), Text('Sobre este lugar', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12), Text(casa.descricao, style: const TextStyle(height: 1.7)),
        const SizedBox(height: 24), Text('Para você aproveitar', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12), Wrap(spacing: 8, runSpacing: 8, children: casa.comodidades.map((c) => Chip(avatar: const Icon(Icons.check, size: 16), label: Text(c))).toList()),
      ]);
      return LayoutBuilder(builder: (context, size) => size.maxWidth >= 950
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: info), const SizedBox(width: 28), SizedBox(width: 390, child: _calendario(casa))])
        : Column(children: [info, const SizedBox(height: 24), _calendario(casa)]));
    }))),
  );
}
