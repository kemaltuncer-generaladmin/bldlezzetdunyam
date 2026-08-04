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

  Future<PrinterAvailability> check() async {
    final stat = await FileStat.stat(devicePath);
    return stat.type == FileSystemEntityType.notFound
        ? PrinterAvailability.unavailable
        : PrinterAvailability.ready;
  }

  /// [period] aralıklarla yoklayıp durum yayınlar; ilk değeri hemen verir.
  Stream<PrinterAvailability> watch({
    Duration period = const Duration(seconds: 10),
  }) async* {
    yield await check();
    yield* Stream<void>.periodic(period).asyncMap((_) => check());
  }
}
