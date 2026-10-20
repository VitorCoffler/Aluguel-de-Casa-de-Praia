import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/auth_page.dart';
import 'screens/bookings_page.dart';
import 'screens/catalog_page.dart';
import 'screens/host_page.dart';
import 'services/api.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  runApp(const CasaDaPraiaApp());
}

class CasaDaPraiaApp extends StatelessWidget {
  const CasaDaPraiaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Casa da Praia', debugShowCheckedModeBanner: false,
    locale: const Locale('pt', 'BR'), supportedLocales: const [Locale('pt', 'BR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: oceano, primary: oceano, surface: areia),
      scaffoldBackgroundColor: areia,
      appBarTheme: const AppBarTheme(backgroundColor: areia, foregroundColor: tinta, centerTitle: false, elevation: 0),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD8DED5))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18)),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
    ),
    home: const Inicializacao(),
  );
}
class Inicializacao extends StatefulWidget {
  const Inicializacao({super.key});
  @override
  State<Inicializacao> createState() => _InicializacaoState();
}
class _InicializacaoState extends State<Inicializacao> {
  late Future<void> _future;
  @override
  void initState() { super.initState(); _future = api.restaurar(); }
  @override
  Widget build(BuildContext context) => FutureBuilder<void>(future: _future, builder: (context, snapshot) {
    if (snapshot.connectionState != ConnectionState.done) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (snapshot.hasError) return Scaffold(body: Falha(error: snapshot.error!, retry: () => setState(() => _future = api.restaurar())));
    return const HomePage();
  });
}
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  int _index = 0;
  bool _saindo = false;
  final _labels = ['Explorar', 'Minhas reservas', 'Anfitrião', 'Minha conta'];
  final _icons = [Icons.explore_outlined, Icons.luggage_outlined, Icons.add_home_outlined, Icons.person_outline];
  Future<void> _sair() async {
    setState(() => _saindo = true);
    try { await api.sair(); if (mounted) setState(() => _index = 0); }
    catch (e) { if (mounted) avisar(context, e); }
    finally { if (mounted) setState(() => _saindo = false); }
  }
  Widget _conta() => SingleChildScrollView(child: Conteudo(width: 650, child: api.usuario == null
    ? Vazio(title: 'Viaje. Anuncie. Sinta-se em casa.', message: 'Crie uma conta e aproveite os dois perfis.', action: FilledButton(onPressed: () => exigirLogin(context), child: const Text('Entrar ou cadastrar')))
    : Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.account_circle_outlined, size: 72, color: oceano), const SizedBox(height: 20),
        Text(api.usuario!.nome, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
        Text(api.usuario!.email, textAlign: TextAlign.center), const SizedBox(height: 28),
        const Text('Você pode reservar casas e publicar seus próprios anúncios com esta conta.'),
        const SizedBox(height: 24), OutlinedButton(onPressed: _saindo ? null : _sair, child: Text(_saindo ? 'Saindo…' : 'Sair da conta')),
      ]))),
  ));
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: api, builder: (context, _) {
    final pages = [
      const CatalogPage(),
      BookingsPage(key: ValueKey('bookings-${api.usuario?.id}')),
      HostPage(key: ValueKey('host-${api.usuario?.id}')),
      _conta(),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 1050;
    return Scaffold(
      appBar: AppBar(title: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.waves_rounded, color: oceano), SizedBox(width: 10), Text('Casa da Praia', style: TextStyle(fontWeight: FontWeight.bold))]),
        actions: [if (wide) Padding(padding: const EdgeInsets.only(right: 24), child: TextButton.icon(onPressed: () => setState(() => _index = 3), icon: const Icon(Icons.person_outline), label: Text(api.usuario?.nome ?? 'Entrar')))]),
      body: Row(children: [
        if (wide) NavigationRail(selectedIndex: _index, onDestinationSelected: (i) => setState(() => _index = i), labelType: NavigationRailLabelType.all,
          destinations: List.generate(4, (i) => NavigationRailDestination(icon: Icon(_icons[i]), label: Text(_labels[i])))),
        Expanded(child: pages[_index]),
      ]),
      bottomNavigationBar: wide ? null : NavigationBar(selectedIndex: _index, onDestinationSelected: (i) => setState(() => _index = i),
        destinations: List.generate(4, (i) => NavigationDestination(icon: Icon(_icons[i]), label: _labels[i]))),
    );
  });
}
