/// Ayar doğrulama testleri.
///
/// Diskteki değer bozulabilir: yarım yazma, elle düzenleme, eski sürüm.
/// Bozuk bir ayarın mutfağı durdurmaması gerekir — en kötü ihtimalle
/// varsayılana düşer.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/settings/kds_settings.dart';

const KdsSettings defaults = KdsSettings(
  soundEnabled: true,
  pollSeconds: 5,
  printerDevicePath: '/dev/thermal0',
  warningAfterMinutes: 10,
  lateAfterMinutes: 20,
);

void main() {
  group('sanitized', () {
    test('geçerli değerleri değiştirmez', () {
      expect(defaults.sanitized(fallback: defaults), defaults);
    });

    test('yoklama aralığını alt sınıra çeker', () {
      final result = defaults
          .copyWith(pollSeconds: 0)
          .sanitized(fallback: defaults);
      expect(result.pollSeconds, KdsSettings.minPollSeconds);
    });

    test('yoklama aralığını üst sınıra çeker', () {
      final result = defaults
          .copyWith(pollSeconds: 9999)
          .sanitized(fallback: defaults);
      expect(result.pollSeconds, KdsSettings.maxPollSeconds);
    });

    test('boş yazıcı yolu varsayılana döner', () {
      final result = defaults
          .copyWith(printerDevicePath: '   ')
          .sanitized(fallback: defaults);
      expect(result.printerDevicePath, '/dev/thermal0');
    });

    test('yazıcı yolundaki boşluklar kırpılır', () {
      final result = defaults
          .copyWith(printerDevicePath: ' /dev/usb/lp0 ')
          .sanitized(fallback: defaults);
      expect(result.printerDevicePath, '/dev/usb/lp0');
    });

    test('gecikme eşiği uyarı eşiğinin altına inemez', () {
      // Aksi hâlde kart doğrudan kırmızıya atlar ve sarı uyarı penceresi
      // hiç görünmez.
      final result = defaults
          .copyWith(warningAfterMinutes: 30, lateAfterMinutes: 5)
          .sanitized(fallback: defaults);

      expect(result.warningAfterMinutes, 30);
      expect(result.lateAfterMinutes, 30);
    });

    test('sıfır ve negatif eşikler alt sınıra çekilir', () {
      final result = defaults
          .copyWith(warningAfterMinutes: 0, lateAfterMinutes: -5)
          .sanitized(fallback: defaults);

      expect(result.warningAfterMinutes, KdsSettings.minThresholdMinutes);
      expect(result.lateAfterMinutes, KdsSettings.minThresholdMinutes);
    });
  });

  group('türetilmiş süreler', () {
    test('saniye ve dakika değerleri Duration olur', () {
      expect(defaults.pollInterval, const Duration(seconds: 5));
      expect(defaults.warningAfter, const Duration(minutes: 10));
      expect(defaults.lateAfter, const Duration(minutes: 20));
    });
  });

  group('copyWith ve eşitlik', () {
    test('yalnızca verilen alanı değiştirir', () {
      final result = defaults.copyWith(soundEnabled: false);

      expect(result.soundEnabled, isFalse);
      expect(result.pollSeconds, defaults.pollSeconds);
      expect(result.printerDevicePath, defaults.printerDevicePath);
    });

    test('aynı değerler eşit sayılır', () {
      // Eşitlik önemlidir: sağlayıcı aynı ayarla gereksiz yere yeniden
      // kurulmasın diye `update` bu karşılaştırmaya güveniyor.
      expect(defaults.copyWith(), defaults);
      expect(defaults.copyWith().hashCode, defaults.hashCode);
    });

    test('farklı değerler eşit değildir', () {
      expect(defaults.copyWith(pollSeconds: 7), isNot(defaults));
    });
  });
}
