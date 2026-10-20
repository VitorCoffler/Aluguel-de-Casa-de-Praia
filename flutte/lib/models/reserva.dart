import 'package:intl/intl.dart';

// Centraliza a apresentação de preços e datas.
String moeda(int centavos) {
  return NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  ).format(centavos / 100);
}

String formatarData(DateTime data) {
  return DateFormat('dd/MM/yyyy').format(data);
}

// UTC é usado apenas para representar dias do calendário,
// evitando diferenças de duração causadas pelo horário de verão.
DateTime somenteData(DateTime data) {
  return DateTime.utc(data.year, data.month, data.day);
}

DateTime get hoje => somenteData(DateTime.now());

DateTime get limiteReservas {
  final data = hoje;
  return DateTime.utc(data.year + 1, data.month, data.day);
}

class Casa {
  final int id;
  final String nome;
  final String cidade;
  final String descricao;
  final int diariaCentavos;

  const Casa({
    required this.id,
    required this.nome,
    required this.cidade,
    required this.descricao,
    required this.diariaCentavos,
  });
}

class Reserva {
  final Casa casa;
  final DateTime entrada;
  int quantidadeNoites;

  Reserva({
    required this.casa,
    required this.entrada,
    required this.quantidadeNoites,
  });

  DateTime get saida {
    return entrada.add(Duration(days: quantidadeNoites));
  }

  int get subtotalCentavos {
    return casa.diariaCentavos * quantidadeNoites;
  }
}

// Dados fictícios mantidos em memória.
const List<Casa> casas = [
  Casa(
    id: 1,
    nome: 'Casa Brisa do Mar',
    cidade: 'Guarapari - ES',
    descricao: 'Casa com dois quartos, varanda e espaço para quatro pessoas.',
    diariaCentavos: 25000,
  ),
  Casa(
    id: 2,
    nome: 'Recanto da Praia',
    cidade: 'Piúma - ES',
    descricao: 'Casa com três quartos, churrasqueira e garagem.',
    diariaCentavos: 35000,
  ),
  Casa(
    id: 3,
    nome: 'Cantinho das Ondas',
    cidade: 'Anchieta - ES',
    descricao: 'Casa para duas pessoas, com cozinha e quintal.',
    diariaCentavos: 18000,
  ),
];