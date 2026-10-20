import 'package:flutter/material.dart';
import '../models/reserva.dart';
import '../services/api.dart';
import '../widgets/common.dart';
import 'detail_page.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});
  @override
  State<CatalogPage> createState() => _CatalogPageState();
}
class _CatalogPageState extends State<CatalogPage> {
  final _busca = TextEditingController();
  final _preco = TextEditingController();
  int _hospedes = 1;
  late Future<List<Casa>> _future;
  @override
  void initState() { super.initState(); _future = api.casas(); }
  @override
  void dispose() { _busca.dispose(); _preco.dispose(); super.dispose(); }
  void _buscar() {
    final text = _preco.text.trim().replaceAll(',', '.');
    final value = text.isEmpty ? null : double.tryParse(text);
    if (text.isNotEmpty && (value == null || !value.isFinite || value < 1 || value > 100000)) {
      avisar(context, 'Informe uma diária entre R\$ 1 e R\$ 100.000.'); return;
    }
    setState(() => _future = api.casas(query: _busca.text.trim(), preco: value == null ? null : (value * 100).round(), hospedes: _hospedes));
  }
  @override
  Widget build(BuildContext context) => SingleChildScrollView(child: Conteudo(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: double.infinity, padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(color: tinta, borderRadius: BorderRadius.circular(28)),
        child: LayoutBuilder(builder: (context, size) => Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ENCONTRE SEU LUGAR AO SOL', style: TextStyle(color: Color(0xFFB5D9BE), letterSpacing: 2, fontSize: 11)),
            const SizedBox(height: 16), Text('Dias leves.\nPerto do mar.', style: TextStyle(color: Colors.white, fontSize: size.maxWidth > 600 ? 52 : 34, fontWeight: FontWeight.w700, height: 1.1)),
            const SizedBox(height: 16), const Text('Casas para descansar, reunir e criar boas memórias.', style: TextStyle(color: Color(0xFFD8E7DF), height: 1.5)),
          ])),
          if (size.maxWidth > 650) const Padding(padding: EdgeInsets.all(24), child: Icon(Icons.waves_rounded, size: 128, color: Color(0xFF8BB8A2))),
        ])),
      ),
      const SizedBox(height: 24),
      Card(child: Padding(padding: const EdgeInsets.all(20), child: Wrap(spacing: 16, runSpacing: 16, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(width: 270, child: TextField(controller: _busca, decoration: const InputDecoration(labelText: 'Destino ou nome da casa', prefixIcon: Icon(Icons.search)), onSubmitted: (_) => _buscar())),
        SizedBox(width: 190, child: TextField(controller: _preco, decoration: const InputDecoration(labelText: 'Diária máxima', prefixText: 'R\$ '), keyboardType: const TextInputType.numberWithOptions(decimal: true), onSubmitted: (_) => _buscar())),
        Contador(label: 'Hóspedes', value: _hospedes, onChanged: (v) => setState(() => _hospedes = v)),
        FilledButton.icon(onPressed: _buscar, icon: const Icon(Icons.tune), label: const Text('Buscar casas')),
        TextButton(onPressed: () { _busca.clear(); _preco.clear(); _hospedes = 1; _buscar(); }, child: const Text('Limpar')),
      ]))),
      const SizedBox(height: 28),
      Text('Uma casa para cada pausa', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8), const Text('Escolha o destino. A próxima história é sua.'),
      const SizedBox(height: 20),
      FutureBuilder<List<Casa>>(future: _future, builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
        if (snapshot.hasError) return Falha(error: snapshot.error!, retry: _buscar);
        final casas = snapshot.data!;
        if (casas.isEmpty) return const Vazio(title: 'Nenhuma casa por aqui ainda', message: 'Experimente outros filtros ou cadastre o primeiro anúncio no painel do anfitrião.');
        return LayoutBuilder(builder: (context, size) {
          final columns = size.maxWidth >= 1000 ? 3 : size.maxWidth >= 650 ? 2 : 1;
          return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, mainAxisExtent: 370, crossAxisSpacing: 20, mainAxisSpacing: 20),
            itemCount: casas.length, itemBuilder: (context, index) {
              final casa = casas[index];
              return Card(clipBehavior: Clip.antiAlias, child: InkWell(
                onTap: () async {
                  await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => DetailPage(casaId: casa.id)));
                  if (mounted) _buscar();
                },
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  FotoCasa(url: casa.fotos.isEmpty ? null : casa.fotos.first, height: 190),
                  Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(casa.cidade, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: oceano, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6), Text(casa.nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8), Text('${casa.hospedes} hóspedes · ${casa.quartos} quarto(s)'),
                    const SizedBox(height: 14), Text('${moeda(casa.diariaCentavos)} / noite', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ])),
                ]),
              ));
            },
          );
        });
      }),
      const SizedBox(height: 24),
    ],
  )));
}
