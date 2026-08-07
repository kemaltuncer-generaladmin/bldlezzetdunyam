import 'package:bld_core/bld_core.dart';
import 'package:test/test.dart';

void main() {
  group('Hizmet alanı', () {
    test('yalnızca Konya', () {
      expect(ServiceArea.coversCity('Konya'), isTrue);
      expect(ServiceArea.coversCity('konya'), isTrue);
      expect(ServiceArea.coversCity(' Konya '), isTrue);
      expect(ServiceArea.coversCity('Ankara'), isFalse);
      expect(ServiceArea.coversCity(null), isFalse);
    });

    test('yalnızca Selçuklu ve Karatay', () {
      expect(ServiceArea.coversDistrict('Selçuklu'), isTrue);
      expect(ServiceArea.coversDistrict('KARATAY'), isTrue);
      // Meram Konya'da ama hizmet alanında değil — en olası yanlış kabul.
      expect(ServiceArea.coversDistrict('Meram'), isFalse);
      expect(ServiceArea.coversDistrict(''), isFalse);
    });

    test('kutu Konya merkezini içerir, başka şehri içermez', () {
      expect(
        ServiceArea.containsPoint(
          ServiceArea.centerLatitude,
          ServiceArea.centerLongitude,
        ),
        isTrue,
      );
      // Ankara Kızılay — kutunun dışında kalmalı.
      expect(ServiceArea.containsPoint(39.9208, 32.8541), isFalse);
    });

    test('kutu kenarları dahildir', () {
      expect(
        ServiceArea.containsPoint(ServiceArea.south, ServiceArea.west),
        isTrue,
      );
      expect(
        ServiceArea.containsPoint(ServiceArea.north, ServiceArea.east),
        isTrue,
      );
    });

    test('kutu tutarlı: güney kuzeyin altında, batı doğunun solunda', () {
      expect(ServiceArea.south, lessThan(ServiceArea.north));
      expect(ServiceArea.west, lessThan(ServiceArea.east));
    });
  });
}
