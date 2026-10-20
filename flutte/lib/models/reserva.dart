import 'package:intl/intl.dart';

String moeda(int centavos) => NumberFormat.currency(
  locale: 'pt_BR', symbol: 'R\$',
).format(centavos / 100);
String formatarData(DateTime date) => DateFormat('dd/MM/yyyy').format(date);
DateTime somenteData(DateTime date) => DateTime.utc(date.year, date.month, date.day);
DateTime get hoje => somenteData(DateTime.now());
DateTime get limiteReservas => hoje.add(const Duration(days: 730));
String dataApi(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
DateTime lerData(String date) => DateTime.parse('${date}T00:00:00Z');

class Usuario {
  final int id;
  final String nome;
  final String email;
  Usuario.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      nome = json['name'] as String,
      email = json['email'] as String;
}

class Casa {
  final int id;
  final int donoId;
  final String nome;
  final String cidade;
  final String descricao;
  final int diariaCentavos;
  final int hospedes;
  final int quartos;
  final bool ativa;
  final List<String> fotos;
  final List<String> comodidades;

  Casa.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      donoId = json['owner_id'] as int,
      nome = json['name'] as String,
      cidade = json['city'] as String,
      descricao = json['description'] as String,
      diariaCentavos = json['price_cents'] as int,
      hospedes = json['guests'] as int,
      quartos = json['bedrooms'] as int,
      ativa = json['active'] == 1,
      fotos = List<String>.from(json['photos'] as List),
      comodidades = List<String>.from(json['amenities'] as List);
}

class Periodo {
  final DateTime entrada;
  final DateTime saida;
  Periodo(this.entrada, this.saida);
  Periodo.fromJson(Map<String, dynamic> json)
    : entrada = lerData(json['start_date'] as String),
      saida = lerData(json['end_date'] as String);

  // O checkout não ocupa uma noite: [entrada, saída).
  bool contem(DateTime dia) => !dia.isBefore(entrada) && dia.isBefore(saida);
  bool sobrepoe(DateTime inicio, DateTime fim) =>
    entrada.isBefore(fim) && saida.isAfter(inicio);
}
