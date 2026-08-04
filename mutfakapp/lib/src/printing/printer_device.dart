/// Termal yazıcıya ham bayt yazma — `docs/05-mutfakapp.md` §5.1, ADR-07.
///
/// CUPS kullanılmaz: sürücü katmanı ESC/POS baytlarını yeniden yorumlar,
/// kuyruk davranışını gizler ve hata durumunu uygulamaya geç bildirir. Cihaz
/// dosyasına doğrudan yazmak, "bastı mı basmadı mı" sorusunu tek bir
/// `write()` çağrısına indirger.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Baytları bir yazıcıya ileten arayüz. Testlerde sahtelenir.
abstract interface class PrinterDevice {
  /// Baytları basar. Başarısızlıkta istisna atar — kuyruk bunu hata sayar.
  Future<void> write(Uint8List bytes);
}

/// `/dev/thermal0` gibi bir karakter cihazına yazan uygulama.
class UsbPrinterDevice implements PrinterDevice {
  const UsbPrinterDevice(this.devicePath, {this.timeout = defaultTimeout});

  /// Yazıcı kapalıyken çekirdek arabelleği dolarsa `write` süresiz bloklar ve
  /// kuyruk işçisi bir daha dönmez. Zaman aşımı, işi "başarısız"a çevirip
  /// geri çekilmeli tekrara sokar.
  static const Duration defaultTimeout = Duration(seconds: 10);

  final String devicePath;
  final Duration timeout;

  /// **`flush: true` KULLANILMAZ.** Karakter cihazında `fsync` geçersizdir:
  /// `/dev/usb/lp*` üzerinde `EINVAL (errno 22)` döner. Baytlar cihaza
  /// ulaşmış olsa bile çağrı istisna atar; kuyruk işi "başarısız" sayar,
  /// geri çekilmeyle tekrar dener ve **her denemede bir fiş daha basar**.
  /// Gerçek yazıcıda koşulan `docs/10` S4 senaryosu bunu yakaladı.
  ///
  /// Karakter cihazının önbelleği yoktur; `write()` baytları doğrudan
  /// sürücüye teslim eder, boşaltılacak bir tampon yoktur.
  @override
  Future<void> write(Uint8List bytes) => File(devicePath)
      .writeAsBytes(bytes, mode: FileMode.writeOnlyAppend, flush: false)
      .timeout(
        timeout,
        onTimeout: () => throw TimeoutException(
          'Yazıcı $timeout içinde yanıt vermedi: $devicePath',
        ),
      );
}
