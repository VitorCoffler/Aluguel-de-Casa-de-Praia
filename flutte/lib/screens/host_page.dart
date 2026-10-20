import 'package:flutter/material.dart';
import '../models/reserva.dart';
import '../services/api.dart';
import '../widgets/common.dart';
import 'auth_page.dart';
import 'bookings_page.dart';
import 'edit_house_page.dart';
import 'blocks_page.dart';

class HostPage extends StatefulWidget {
  const HostPage({super.key});
  @override
  State<HostPage> createState() => _HostPageState();
}
class _HostPageState extends State<HostPage> {
  Future<List<Casa>>? _future;
  @override
  void initState() { super.initState(); _carregar(); }
  void _carregar() { if (api.usuario != null) setState(() => _future = api.casas(minhas: true)); }
  Future<void> _editar([Casa? casa]) async {
    await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => EditHousePage(casa: casa)));
    if (mounted) _carregar();
  }
  @override
  Widget build(BuildContext context) {
    if (api.usuario == null) return Vazio(title: 'Abra as portas para novas histórias', message: 'Anuncie sua casa e organize as reservas em um só lugar.',
      icon: Icons.add_home_outlined, action: FilledButton(onPressed: () async { if (await exigirLogin(context, anfitriao: true) && mounted) _carregar(); }, child: const Text('Entrar como anfitrião')));
    return SingleChildScrollView(child: Conteudo(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Painel do anfitrião', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8), const Text('Sua casa bem apresentada. Sua agenda organizada.'),
      const SizedBox(height: 24), Wrap(spacing: 12, runSpacing: 12, children: [
        FilledButton.icon(onPressed: () => _editar(), icon: const Icon(Icons.add), label: const Text('Novo anúncio')),
        OutlinedButton.icon(onPressed: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Anfitrião')), body: const BookingsPage(anfitriao: true)))), icon: const Icon(Icons.event_available), label: const Text('Reservas recebidas')),
        IconButton(tooltip: 'Atualizar anúncios', onPressed: _carregar, icon: const Icon(Icons.refresh)),
      ]), const SizedBox(height: 24),
      FutureBuilder<List<Casa>>(future: _future, builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Falha(error: snapshot.error!, retry: _carregar);
        final casas = snapshot.data!;
        if (casas.isEmpty) return Vazio(title: 'Seu primeiro anúncio começa aqui', message: 'Adicione fotos, conte o que sua casa oferece e escolha a diária.',
          action: FilledButton(onPressed: () => _editar(), child: const Text('Cadastrar minha casa')));
        return Column(children: casas.map((casa) => Card(margin: const EdgeInsets.only(bottom: 18), clipBehavior: Clip.antiAlias, child: Padding(
          padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(borderRadius: BorderRadius.circular(16), child: FotoCasa(url: casa.fotos.isEmpty ? null : casa.fotos.first, height: 190)),
            const SizedBox(height: 16), Text(casa.nome, style: Theme.of(context).textTheme.titleLarge),
            Text('${casa.cidade} · ${moeda(casa.diariaCentavos)} / noite'),
            Chip(label: Text(casa.ativa ? 'Publicado' : 'Pausado')),
            Wrap(spacing: 12, runSpacing: 8, children: [
              OutlinedButton.icon(onPressed: () => _editar(casa), icon: const Icon(Icons.edit_outlined), label: const Text('Editar anúncio')),
              TextButton.icon(onPressed: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => BlocksPage(casa: casa))), icon: const Icon(Icons.calendar_month_outlined), label: const Text('Bloquear datas')),
            ]),
          ]),
        ))).toList());
      }),
    ])));
  }
}
