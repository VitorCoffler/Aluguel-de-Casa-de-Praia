import 'package:flutter_test/flutter_test.dart';
import 'package:casa_da_praia/models/reserva.dart';

void main() {
  test('checkout libera a noite seguinte e intervalos contíguos não conflitam', () {
    final range = Periodo(DateTime.utc(2027, 1, 10), DateTime.utc(2027, 1, 13));
    expect(range.contem(DateTime.utc(2027, 1, 12)), isTrue);
    expect(range.contem(DateTime.utc(2027, 1, 13)), isFalse);
    expect(range.sobrepoe(DateTime.utc(2027, 1, 13), DateTime.utc(2027, 1, 15)), isFalse);
    expect(range.sobrepoe(DateTime.utc(2027, 1, 9), DateTime.utc(2027, 1, 11)), isTrue);
    expect(range.sobrepoe(DateTime.utc(2027, 1, 9), DateTime.utc(2027, 1, 14)), isTrue);
  });
  test('datas da API preservam o dia sem deslocamento de fuso', () {
    expect(dataApi(lerData('2027-01-10')), '2027-01-10');
    expect(lerData('2027-01-13').difference(lerData('2027-01-10')).inDays, 3);
  });
}
