/// Yazıcı cihazına yazma testleri.
///
/// Buradaki asıl test **gerileme testidir**: `docs/10-test-kabul.md` S4 gerçek
/// yazıcıda koşulurken, `writeAsBytes(..., flush: true)` çağrısının karakter
/// cihazında `EINVAL` verdiği ortaya çıktı. Baytlar yazıcıya ulaşıyor ama
/// çağrı istisna atıyordu; kuyruk işi başarısız sayıp tekrar deniyor ve
/// **her denemede bir fiş daha basıyordu**. Sessiz mükerrer basım, mutfakta
/// mükerrer yemek demektir.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/data/printer_probe.dart';
import 'package:mutfakapp/src/printing/printer_device.dart';

void main() {
  final payload = Uint8List.fromList([0x1B, 0x40, 0x41]);

  test(
    'karakter cihazına yazma başarılı sayılır',
    () async {
      // `/dev/null` da bir karakter cihazıdır ve `fsync` orada da geçersizdir;
      // gerçek yazıcı olmadan aynı hatayı yakalar.
      await expectLater(
        const UsbPrinterDevice('/dev/null').write(payload),
        completes,
      );
    },
    skip: Platform.isLinux ? false : 'Karakter cihazı yalnızca Linux\'ta',
  );

  test('olmayan cihaz istisna atar — iş kuyrukta kalsın diye', () async {
    await expectLater(
      const UsbPrinterDevice('/dev/thermal0-yok').write(payload),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('normal dosyaya yazma da çalışır', () async {
    final dir = await Directory.systemTemp.createTemp('bld_yazici');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/cikti.bin';

    await UsbPrinterDevice(path).write(payload);

    expect(File(path).readAsBytesSync(), payload);
  });

  test('ard arda yazmalar eklenir, üzerine yazmaz', () async {
    final dir = await Directory.systemTemp.createTemp('bld_yazici');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/cikti.bin';
    const device = UsbPrinterDevice('');

    await UsbPrinterDevice(path).write(payload);
    await UsbPrinterDevice(path).write(payload);

    expect(File(path).readAsBytesSync(), hasLength(payload.length * 2));
    expect(device.timeout, UsbPrinterDevice.defaultTimeout);
  });

  group('Yazıcı yoklaması', () {
    test('karakter aygıtı VAR sayılır', () async {
      // SAHADA YAŞANDI: yoklama `FileStat.stat().type` bakıyordu ve Dart'ın
      // tür listesinde karakter aygıtı yok — çalışan yazıcı için `notFound`
      // dönüyor. Ekranda "Yazıcı yok" yazarken fişler basılıyordu.
      const aygit = '/dev/null';
      final stat = await FileStat.stat(aygit);

      expect(
        stat.type,
        FileSystemEntityType.notFound,
        reason:
            'Dart karakter aygıtını notFound sayıyor — regresyonun kökü bu.',
      );
      expect(
        await const PrinterProbe(aygit).check(),
        PrinterAvailability.ready,
        reason: 'Yoklama türe değil varlığa bakmalı.',
      );
    });

    test('olmayan yol yok sayılır', () async {
      expect(
        await const PrinterProbe('/dev/boyle-bir-aygit-yok').check(),
        PrinterAvailability.unavailable,
      );
    });
  });
}
