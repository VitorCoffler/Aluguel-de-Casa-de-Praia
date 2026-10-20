import 'package:flutter/material.dart';
import '../models/reserva.dart';
import '../services/api.dart';
import '../widgets/common.dart';
import 'auth_page.dart';

class BookingsPage extends StatefulWidget {
  final bool anfitriao;
  const BookingsPage({super.key, this.anfitriao = false});
  @override
  State<BookingsPage> createState() => _BookingsPageState();
}
class _BookingsPageState extends State<BookingsPage> {
  Future<Map<String, dynamic>>? _future;
  final Set<int> _busy = {};
  @override
  void initState() { super.initState(); _carregar(); }
  void _carregar() { if (api.usuario != null) setState(() => _future = api.request('GET', widget.anfitriao ? '/host/bookings' : '/bookings')); }
  Future<void> _cancelar(Map<String, dynamic> item) async {
    final id = item['id'] as int;
    if (!await confirmar(context, 'Cancelar reserva?', 'O período ficará disponível para uma nova reserva.') || !mounted) return;
    setState(() => _busy.add(id));
    try {
      await api.request('POST', '/bookings/$id/cancel', {});
      if (mounted) { avisar(context, 'Reserva cancelada.'); _carregar(); }
    } catch (e) { if (mounted) avisar(context, e); }
    finally { if (mounted) setState(() => _busy.remove(id)); }
  }
  @override
  Widget build(BuildContext context) {
    if (api.usuario == null) return Vazio(title: 'Suas viagens em um só lugar', message: 'Entre para acompanhar suas reservas.',
      action: FilledButton(onPressed: () async { if (await exigirLogin(context) && mounted) _carregar(); }, child: const Text('Entrar')));
    return SingleChildScrollView(child: Conteudo(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(widget.anfitriao ? 'Reservas recebidas' : 'Minhas reservas', style: Theme.of(context).textTheme.headlineMedium)), IconButton(tooltip: 'Atualizar', onPressed: _carregar, icon: const Icon(Icons.refresh))]),
      const SizedBox(height: 8), const Text('Consulte os detalhes e acompanhe cada estadia.'), const SizedBox(height: 24),
      FutureBuilder<Map<String, dynamic>>(future: _future, builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Falha(error: snapshot.error!, retry: _carregar);
        final items = (snapshot.data!['bookings'] as List).cast<Map<String, dynamic>>();
        if (items.isEmpty) return const Vazio(title: 'Ainda não há reservas', message: 'As próximas estadias aparecerão aqui.');
        return Column(children: items.map((item) {
          final cancelled = item['status'] == 'cancelled';
          final start = lerData(item['start_date'] as String), end = lerData(item['end_date'] as String);
          return Card(margin: const EdgeInsets.only(bottom: 16), child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(item['house_name'] as String, style: Theme.of(context).textTheme.titleLarge),
              Chip(label: Text(cancelled ? 'Cancelada' : 'Confirmada'), backgroundColor: cancelled ? const Color(0xFFFBE7E2) : const Color(0xFFDCEAE3)),
            ]),
            Text(item['city'] as String),
            if (widget.anfitriao) Text('Hóspede: ${item['guest_name']}'),
            const SizedBox(height: 12), Text('${formatarData(start)} → ${formatarData(end)}'),
            Text('${end.difference(start).inDays} noite(s) · ${item['guests']} hóspede(s)'),
            const SizedBox(height: 12), Text('Total: ${moeda(item['total_cents'] as int)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (!cancelled && !start.isBefore(hoje)) TextButton.icon(
              onPressed: _busy.contains(item['id']) ? null : () => _cancelar(item), icon: const Icon(Icons.close), label: const Text('Cancelar reserva')),
          ])));
        }).toList());
      }),
    ])));
  }
}
