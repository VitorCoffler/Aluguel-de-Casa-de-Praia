import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:table_calendar/table_calendar.dart';

import 'models/reserva.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  runApp(const CasaDaPraiaApp());
}

class CasaDaPraiaApp extends StatelessWidget {
  const CasaDaPraiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Casa da Praia',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Esta lista simula o armazenamento do carrinho.
  final List<Reserva> _reservas = [];

  Future<void> _selecionarCasa(Casa casa) async {
    final reserva = await Navigator.push<Reserva>(
      context,
      MaterialPageRoute(
        builder: (_) => ReservaPage(casa: casa),
      ),
    );

    if (!mounted || reserva == null) return;

    setState(() {
      // Cada casa possui uma seleção por carrinho.
      // Uma nova seleção da mesma casa substitui o período anterior.
      final indice = _reservas.indexWhere(
        (item) => item.casa.id == casa.id,
      );

      if (indice == -1) {
        _reservas.add(reserva);
      } else {
        _reservas[indice] = reserva;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Período salvo no carrinho.'),
      ),
    );
  }

  Future<void> _abrirCarrinho() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CarrinhoPage(reservas: _reservas),
      ),
    );

    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Casa da Praia'),
        actions: [
          TextButton.icon(
            onPressed: _abrirCarrinho,
            icon: const Icon(Icons.shopping_cart_outlined),
            label: Text('${_reservas.length}'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Escolha sua próxima estadia',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Confira as casas e selecione suas datas.'),
          const SizedBox(height: 16),
          for (final casa in casas)
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.beach_access,
                      size: 48,
                      color: Colors.teal,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      casa.nome,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(casa.cidade),
                    const SizedBox(height: 8),
                    Text(casa.descricao),
                    const SizedBox(height: 12),
                    Text(
                      '${moeda(casa.diariaCentavos)} / noite',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => _selecionarCasa(casa),
                      child: const Text('Selecionar datas'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ReservaPage extends StatefulWidget {
  final Casa casa;

  const ReservaPage({
    super.key,
    required this.casa,
  });

  @override
  State<ReservaPage> createState() => _ReservaPageState();
}

class _ReservaPageState extends State<ReservaPage> {
  DateTime _diaFocado = hoje;
  DateTime? _entrada;
  DateTime? _saida;

  int get _noites {
    if (_entrada == null || _saida == null) return 0;
    return _saida!.difference(_entrada!).inDays;
  }

  void _adicionarAoCarrinho() {
    if (_entrada == null || _noites < 1) return;

    final reserva = Reserva(
      casa: widget.casa,
      entrada: _entrada!,
      quantidadeNoites: _noites,
    );

    // Devolve a reserva à tela que abriu esta página.
    Navigator.pop(context, reserva);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.casa.nome)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.casa.descricao),
          const SizedBox(height: 8),
          Text(
            'Diária: ${moeda(widget.casa.diariaCentavos)}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          const Text(
            'Selecione a entrada e depois a saída. '
            'A estadia deve ter pelo menos uma noite.',
          ),
          const SizedBox(height: 12),

          // Widget pesquisado: permite selecionar um intervalo.
          TableCalendar<Object?>(
            locale: 'pt_BR',
            firstDay: hoje,
            lastDay: limiteReservas,
            focusedDay: _diaFocado,
            rangeStartDay: _entrada,
            rangeEndDay: _saida,
            rangeSelectionMode: RangeSelectionMode.toggledOn,
            startingDayOfWeek: StartingDayOfWeek.monday,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            onPageChanged: (dia) {
              _diaFocado = dia;
            },
            onRangeSelected: (entrada, saida, diaFocado) {
              setState(() {
                _entrada = entrada == null ? null : somenteData(entrada);
                _saida = saida == null ? null : somenteData(saida);
                _diaFocado = diaFocado;
              });
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Entrada: ${_entrada == null ? 'Selecione' : formatarData(_entrada!)}',
          ),
          Text(
            'Saída: ${_saida == null ? 'Selecione' : formatarData(_saida!)}',
          ),
          Text('Quantidade: $_noites noite(s)'),
          const SizedBox(height: 8),
          Text(
            'Subtotal: ${moeda(widget.casa.diariaCentavos * _noites)}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _noites > 0 ? _adicionarAoCarrinho : null,
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Adicionar ao carrinho'),
          ),
        ],
      ),
    );
  }
}

class CarrinhoPage extends StatefulWidget {
  final List<Reserva> reservas;

  const CarrinhoPage({
    super.key,
    required this.reservas,
  });

  @override
  State<CarrinhoPage> createState() => _CarrinhoPageState();
}

class _CarrinhoPageState extends State<CarrinhoPage> {
  int get _totalCentavos {
    return widget.reservas.fold<int>(
      0,
      (total, reserva) => total + reserva.subtotalCentavos,
    );
  }

  void _alterarQuantidade(Reserva reserva, int variacao) {
    final novaQuantidade = reserva.quantidadeNoites + variacao;
    final novaSaida = reserva.entrada.add(
      Duration(days: novaQuantidade),
    );

    // Mantém uma noite mínima e respeita o limite do calendário.
    if (novaQuantidade < 1 || novaSaida.isAfter(limiteReservas)) {
      return;
    }

    setState(() {
      reserva.quantidadeNoites = novaQuantidade;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Carrinho de reservas')),
      body: widget.reservas.isEmpty
          ? const Center(
              child: Text('Seu carrinho está vazio.'),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Altere as noites pelos botões abaixo. '
                  'A entrada permanece a mesma e a saída é atualizada.',
                ),
                const SizedBox(height: 12),
                for (final reserva in widget.reservas)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reserva.casa.nome,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            'Diária: ${moeda(reserva.casa.diariaCentavos)}',
                          ),
                          Text(
                            'Entrada: ${formatarData(reserva.entrada)}',
                          ),
                          Text(
                            'Saída: ${formatarData(reserva.saida)}',
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              IconButton(
                                tooltip: 'Diminuir uma noite',
                                onPressed: reserva.quantidadeNoites > 1
                                    ? () => _alterarQuantidade(reserva, -1)
                                    : null,
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                ),
                              ),
                              Text(
                                '${reserva.quantidadeNoites} noite(s)',
                              ),
                              IconButton(
                                tooltip: 'Adicionar uma noite',
                                onPressed:
                                    reserva.saida.isBefore(limiteReservas)
                                        ? () => _alterarQuantidade(reserva, 1)
                                        : null,
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remover reserva',
                                onPressed: () {
                                  setState(() {
                                    widget.reservas.remove(reserva);
                                  });
                                },
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Subtotal: ${moeda(reserva.subtotalCentavos)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const Divider(),
                Text(
                  'Total: ${moeda(_totalCentavos)}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
    );
  }
}
