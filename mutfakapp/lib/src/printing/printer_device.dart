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

  @override
  Future<void> write(Uint8List bytes) => File(devicePath)
      .writeAsBytes(bytes, mode: FileMode.writeOnlyAppend, flush: true)
      .timeout(
        timeout,
        onTimeout: () => throw TimeoutException(
          'Yazıcı $timeout içinde yanıt vermedi: $devicePath',
        ),
      );
}
