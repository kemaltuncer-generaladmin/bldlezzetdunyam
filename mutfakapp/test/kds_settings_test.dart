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

    test('kilit metni 160 karaktere kırpılır', () {
      // Uyarı kutusuna sığmayan metin, personelin asıl cümleyi hiç
      // görmemesi demek.
      final result = defaults
          .copyWith(lockMessage: 'ç' * 500)
          .sanitized(fallback: defaults);

      expect(result.lockMessage, hasLength(KdsSettings.maxLockMessageLength));
    });

    test('kilit metnindeki boşluklar kırpılır', () {
      final result = defaults
          .copyWith(lockMessage: '  Müdüre haber verin.  ')
          .sanitized(fallback: defaults);

      expect(result.lockMessage, 'Müdüre haber verin.');
    });

    test('sınırdaki kilit metni olduğu gibi kalır', () {
      final tam = 'a' * KdsSettings.maxLockMessageLength;
      final result = defaults
          .copyWith(lockMessage: tam)
          .sanitized(fallback: defaults);

      expect(result.lockMessage, tam);
    });
  });

  group('kilit politikası', () {
    test('varsayılan SERBESTtir — yeni alan bugünkü kasayı kilitlemez', () {
      expect(defaults.allowSettings, isTrue);
      expect(defaults.allowServerChange, isTrue);
      expect(defaults.allowWindowControls, isTrue);
      expect(defaults.allowOrderEdit, isTrue);
      expect(defaults.allowManualReprint, isTrue);
      expect(defaults.allowSalesControl, isTrue);
      expect(defaults.lockMessage, '');
      expect(defaults.hasLock, isFalse);
    });

    test('tek bir kilit `hasLock` için yeter', () {
      expect(defaults.copyWith(allowManualReprint: false).hasLock, isTrue);
    });

    test('kilit alanları eşitliğe girer', () {
      // Girmeseydi `KdsSettingsController.update` değişikliği "aynı" sayıp
      // diske hiç yazmazdı ve kilit yeniden başlatmada kaybolurdu.
      expect(defaults.copyWith(allowSettings: false), isNot(defaults));
      expect(defaults.copyWith(lockMessage: 'x'), isNot(defaults));
      expect(
        defaults.copyWith(allowSettings: false).hashCode,
        isNot(defaults.hashCode),
      );
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
