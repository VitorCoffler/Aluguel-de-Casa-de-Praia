import 'package:flutter/material.dart';
import '../models/reserva.dart';
import '../services/api.dart';
import '../widgets/common.dart';

class BlocksPage extends StatefulWidget {
  final Casa casa;
  const BlocksPage({super.key, required this.casa});
  @override
  State<BlocksPage> createState() => _BlocksPageState();
}
class _BlocksPageState extends State<BlocksPage> {
  late Future<Map<String, dynamic>> _future;
  bool _busy = false;
  @override
  void initState() { super.initState(); _carregar(); }
  void _carregar() => setState(() => _future = api.request('GET', '/host/houses/${widget.casa.id}/blocks'));
  Future<void> _bloquear() async {
    final range = await showDateRangePicker(context: context, firstDate: hoje, lastDate: limiteReservas,
      helpText: 'Bloqueie as noites: início até liberação', saveText: 'Selecionar');
    if (range == null || !mounted) return;
    final start = somenteData(range.start), end = somenteData(range.end);
    if (end.difference(start).inDays < 1 || end.difference(start).inDays > 90) { avisar(context, 'Escolha de 1 a 90 noites.'); return; }
    setState(() => _busy = true);
    try {
      await api.request('POST', '/host/houses/${widget.casa.id}/blocks', {'start_date': dataApi(start), 'end_date': dataApi(end)});
      if (mounted) { avisar(context, 'Período bloqueado.'); _carregar(); }
    } catch (e) { if (mounted) avisar(context, e); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _remover(int id) async {
    if (!await confirmar(context, 'Liberar período?', 'Essas noites poderão receber reservas.') || !mounted) return;
    setState(() => _busy = true);
    try { await api.request('DELETE', '/host/blocks/$id'); if (mounted) _carregar(); }
    catch (e) { if (mounted) avisar(context, e); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Disponibilidade')),
    body: SingleChildScrollView(child: Conteudo(width: 800, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(widget.casa.nome, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 12), const Text('Bloqueie noites para manutenção ou uso pessoal. A data final é o dia da liberação. Reservas confirmadas já bloqueiam suas noites automaticamente.'),
      const SizedBox(height: 24), FilledButton.icon(onPressed: _busy ? null : _bloquear, icon: const Icon(Icons.event_busy), label: const Text('Bloquear período')),
      const SizedBox(height: 24), FutureBuilder<Map<String, dynamic>>(future: _future, builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Falha(error: snapshot.error!, retry: _carregar);
        final blocks = snapshot.data!['blocks'] as List;
        if (blocks.isEmpty) return const Vazio(title: 'Sem bloqueios manuais', message: 'Sua agenda está livre de bloqueios adicionados por você.');
        return Column(children: blocks.map((b) => Card(child: ListTile(
          title: Text('${formatarData(lerData(b['start_date'] as String))} → ${formatarData(lerData(b['end_date'] as String))}'),
          subtitle: const Text('Indisponível para novas reservas'),
          trailing: IconButton(tooltip: 'Liberar período', onPressed: _busy ? null : () => _remover(b['id'] as int), icon: const Icon(Icons.delete_outline)),
        ))).toList());
      }),
    ]))),
  );
}
