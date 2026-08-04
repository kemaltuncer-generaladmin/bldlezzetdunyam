/// Zorunlu güncelleme mantığı (`version < min_supported`) —
/// `docs/07-musteriapp.md` §7 üçüncü madde.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:musteriapp/src/features/update/version_check.dart';

void main() {
  group('SemanticVersion.tryParse', () {
    test('sözleşmedeki biçimi ayrıştırır', () {
      final version = SemanticVersion.tryParse('1.2.3');

      expect(version, const SemanticVersion(1, 2, 3));
      expect(version.toString(), '1.2.3');
    });

    test('baştaki ve sondaki boşluk yok sayılır', () {
      expect(SemanticVersion.tryParse('  2.0.1 '), const SemanticVersion(2, 0, 1));
    });

    test('sözleşmeye uymayan biçimlerde null döner', () {
      for (final invalid in ['1.2', '1.2.3.4', 'v1.2.3', '1.2.x', '', 'abc']) {
        expect(
          SemanticVersion.tryParse(invalid),
          isNull,
          reason: 'Kabul edilmemeliydi: "$invalid"',
        );
      }
    });

    test('karşılaştırma majör, minör, yama sırasıyla yapılır', () {
      const base = SemanticVersion(1, 2, 3);

      expect(base.compareTo(const SemanticVersion(1, 2, 3)), 0);
      expect(base < const SemanticVersion(2, 0, 0), isTrue);
      expect(base < const SemanticVersion(1, 3, 0), isTrue);
      expect(base < const SemanticVersion(1, 2, 4), isTrue);
      expect(base < const SemanticVersion(1, 2, 2), isFalse);
      // 10 > 9: sayısal karşılaştırma, dize karşılaştırması değil.
      expect(const SemanticVersion(1, 9, 0) < const SemanticVersion(1, 10, 0),
          isTrue);
    });
  });

  group('isUpdateRequired', () {
    test('yüklü sürüm eşikten düşükse güncelleme zorunludur', () {
      expect(isUpdateRequired(current: '1.0.0', minSupported: '1.1.0'), isTrue);
      expect(isUpdateRequired(current: '1.0.9', minSupported: '1.1.0'), isTrue);
      expect(isUpdateRequired(current: '0.9.9', minSupported: '1.0.0'), isTrue);
      expect(isUpdateRequired(current: '1.9.0', minSupported: '1.10.0'), isTrue);
    });

    test('eşitlik engellenmez — min_supported desteklenen en düşük sürümdür', () {
      expect(isUpdateRequired(current: '1.0.0', minSupported: '1.0.0'), isFalse);
    });

    test('yüklü sürüm eşikten yüksekse engellenmez', () {
      expect(isUpdateRequired(current: '1.2.0', minSupported: '1.1.0'), isFalse);
      expect(isUpdateRequired(current: '2.0.0', minSupported: '1.9.9'), isFalse);
      expect(isUpdateRequired(current: '1.0.1', minSupported: '1.0.0'), isFalse);
    });

    test('ayrıştırılamayan sürümde kullanıcı kilitlenmez', () {
      expect(isUpdateRequired(current: 'bozuk', minSupported: '1.0.0'), isFalse);
      expect(isUpdateRequired(current: '1.0.0', minSupported: ''), isFalse);
      expect(isUpdateRequired(current: '', minSupported: ''), isFalse);
    });

    test('mock sunucunun döndüğü değerlerle uygulama açılır', () {
      // infra/mock: latest 1.0.0, min_supported 1.0.0; pubspec sürümü 1.0.0.
      expect(isUpdateRequired(current: '1.0.0', minSupported: '1.0.0'), isFalse);
    });
  });
}
