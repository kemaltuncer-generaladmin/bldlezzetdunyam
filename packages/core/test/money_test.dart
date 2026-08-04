import 'package:bld_core/bld_core.dart';
import 'package:test/test.dart';

void main() {
  group('Money.format', () {
    test('sözleşmedeki örnekler', () {
      // docs/03-api-sozlesmesi.md §1.3
      expect(Money.format(4550), '45,50 ₺');
      // docs/06-website.md §5
      expect(Money.format(41000), '410,00 ₺');
    });

    test('binlik ayracı nokta', () {
      expect(Money.format(1234567), '12.345,67 ₺');
      expect(Money.format(100000000), '1.000.000,00 ₺');
    });

    test('kuruş her zaman iki hane', () {
      expect(Money.format(5), '0,05 ₺');
      expect(Money.format(50), '0,50 ₺');
      expect(Money.format(100), '1,00 ₺');
    });

    test('sıfır ve negatif', () {
      expect(Money.format(0), '0,00 ₺');
      expect(Money.format(-4550), '-45,50 ₺');
      expect(Money.format(-1234567), '-12.345,67 ₺');
    });

    test('grup sınırları', () {
      expect(Money.format(99900), '999,00 ₺');
      expect(Money.format(100000), '1.000,00 ₺');
      expect(Money.format(1000000), '10.000,00 ₺');
    });

    test('fiş biçiminde sembol yok', () {
      // ₺ karakteri PC857'de yok — docs/05-mutfakapp.md §5.2
      expect(Money.formatForReceipt(41000), '410,00');
      expect(Money.formatForReceipt(41000), isNot(contains('₺')));
    });
  });

  group('Money.tryParse', () {
    test('Türkçe biçimi okur', () {
      expect(Money.tryParse('410,00'), 41000);
      expect(Money.tryParse('12.345,67'), 1234567);
      expect(Money.tryParse('45,50 ₺'), 4550);
    });

    test('boşluk ve sembol tolere edilir', () {
      expect(Money.tryParse('  410,00  ₺ '), 41000);
    });

    test('geçersiz girdi null döner', () {
      expect(Money.tryParse(''), isNull);
      expect(Money.tryParse('abc'), isNull);
      expect(Money.tryParse('₺'), isNull);
    });

    test('format ve tryParse birbirinin tersi', () {
      for (final kurus in [0, 5, 4550, 41000, 1234567, 100000000]) {
        expect(
          Money.tryParse(Money.format(kurus)),
          kurus,
          reason: 'gidiş-dönüş bozuldu: $kurus',
        );
      }
    });
  });
}
