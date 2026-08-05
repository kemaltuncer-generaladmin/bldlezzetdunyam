/// Yazıcı varlık denetimi — durum çubuğundaki "Yazıcı hazır" göstergesi.
///
/// Yalnızca cihaz dosyasının **var olup olmadığına** bakar. Gerçekten
/// yazılabildiğini kanıtlayan şey basımın kendisidir; kuyruk (`K-04`) başarısız
/// denemeleri sayar. Burada cihazı açmayız: `usblp` cihazını açmak yazıcı
/// kapalıyken bloklayabilir ve arayüzü dondurabilir.
library;

import 'dart:io';

/// Yazıcı cihaz dosyasının durumu.
enum PrinterAvailability {
  /// Cihaz dosyası yerinde.
  ready,

  /// Cihaz dosyası yok — yazıcı çıkarılmış ya da udev kuralı yüklenmemiş.
  unavailable,
}

/// Cihaz dosyasının varlığını yoklar.
class PrinterProbe {
  const PrinterProbe(this.devicePath);

  final String devicePath;

  /// `FileStat` KULLANILMAZ — sahada yazıcıyı "yok" gösteren hata buydu.
  ///
  /// Dart'ın `FileSystemEntityType` listesinde karakter aygıtı YOKTUR ve
  /// `FileStat.stat('/dev/thermal0')` çalışan bir yazıcı için bile
  /// `notFound` döner. Yoklama buna bakıyordu; sonuç, yazıcı takılıyken
  /// ve fiş basarken ekranda "Yazıcı yok" yazmasıydı.
  ///
  /// `File.exists()` aynı yolda `true` döner: dosyanın türünü değil,
  /// varlığını sorar — bizim de sorduğumuz bu.
  Future<PrinterAvailability> check() async {
    return await File(devicePath).exists()
        ? PrinterAvailability.ready
        : PrinterAvailability.unavailable;
  }

  /// [period] aralıklarla yoklayıp durum yayınlar; ilk değeri hemen verir.
  Stream<PrinterAvailability> watch({
    Duration period = const Duration(seconds: 10),
  }) async* {
    yield await check();
    yield* Stream<void>.periodic(period).asyncMap((_) => check());
  }
}
