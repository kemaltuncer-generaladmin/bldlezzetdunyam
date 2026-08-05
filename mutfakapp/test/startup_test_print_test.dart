/// Açılış test fişi — `docs/05-mutfakapp.md` §5.5.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/printing/startup_test_print.dart';

/// Bellekte tutan [StartupPrintLog] — platform eklentisi sahtelemeye gerek yok.
class FakeStartupPrintLog implements StartupPrintLog {
  DateTime? _at;

  @override
  Future<DateTime?> lastPrintedAt() async => _at;

  @override
  Future<void> record(DateTime at) async => _at = at;
}

void main() {
  late List<Uint8List> printed;
  late FakeStartupPrintLog log;

  final t0 = DateTime.utc(2026, 8, 5, 8);

  Future<void> fakePrinter(Uint8List bytes) async => printed.add(bytes);

  Future<bool> run({
    DateTime? now,
    Future<void> Function(Uint8List)? printer,
  }) => printStartupTestReceipt(
    print: printer ?? fakePrinter,
    devicePath: '/dev/thermal0',
    now: now ?? t0,
    log: log,
  );

  setUp(() {
    printed = [];
    log = FakeStartupPrintLog();
  });

  test('ilk açılışta fiş basar', () async {
    expect(await run(), isTrue);
    expect(printed, hasLength(1));
    expect(printed.single, isNotEmpty);
  });

  test('bekleme süresi içinde ikinci kez basmaz', () async {
    // Servis `Restart=always` ve `RestartSec=5` ile koşuyor. Korumasız
    // bir çökme döngüsü her beş saniyede bir fiş basar ve ruloyu bitirir.
    await run();
    final crashLoop = await run(now: t0.add(const Duration(seconds: 5)));

    expect(crashLoop, isFalse);
    expect(printed, hasLength(1), reason: 'Çökme döngüsü kâğıt harcamamalı.');
  });

  test('bekleme süresi dolunca yeniden basar', () async {
    await run();
    final later = await run(now: t0.add(const Duration(minutes: 4)));

    expect(later, isTrue);
    expect(printed, hasLength(2));
  });

  test('yazıcı hata verse bile damga yazılır', () async {
    // Damga BASMADAN ÖNCE yazılıyor. Sonraya bırakılsaydı, yazma
    // sırasında çöken uygulama damgayı hiç yazamaz ve yeniden başlayıp
    // tekrar basardı — korumanın engellemesi gereken döngünün ta kendisi.
    final ok = await run(
      printer: (_) async => throw const FormatException('yazıcı yok'),
    );

    expect(ok, isFalse);
    expect(await log.lastPrintedAt(), t0);
    expect(
      await run(now: t0.add(const Duration(seconds: 5))),
      isFalse,
      reason: 'Başarısız deneme de bekleme süresini başlatmalı.',
    );
  });

  test('yazıcı hatası yukarı atılmaz', () async {
    // Mutfak, yazıcı arızalı diye sipariş göremez hâle gelemez.
    await expectLater(
      run(printer: (_) async => throw const FormatException('yazıcı yok')),
      completion(isFalse),
    );
  });

  test('sistem saati geri alınırsa basar', () async {
    await run();

    // Negatif farkı "bekleme dolmadı" saymak, saat düzelene kadar fişi
    // tamamen susturur; basmak daha güvenli.
    expect(await run(now: t0.subtract(const Duration(hours: 2))), isTrue);
  });
}
