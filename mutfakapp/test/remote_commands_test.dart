/// K-22 §2 — sunucudan gelen komutların kasadaki UÇTAN UCA etkisi.
///
/// `managed_settings_test.dart` komutun doğru eyleme bağlandığını ölçüyor;
/// burada ölçülen şey o eylemin ekranda gerçekten olduğu: `unpair` komutu
/// gelen bir kasa eşleme ekranına DÖNMELİ. Bağlantı `providers.dart`
/// içindeki eylem haritasından geçiyor ve orada bir kopukluk olsa iki
/// katman da kendi başına yeşil kalırdı.
library;

import 'dart:typed_data';

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/app.dart';
import 'package:mutfakapp/src/data/device_session.dart';
import 'package:mutfakapp/src/data/kitchen_health.dart';
import 'package:mutfakapp/src/data/providers.dart';
import 'package:mutfakapp/src/pairing/pairing_screen.dart';
import 'package:mutfakapp/src/printing/print_queue.dart';
import 'package:mutfakapp/src/printing/print_service.dart';
import 'package:mutfakapp/src/printing/printer_device.dart';
import 'package:mutfakapp/src/sound/alarm_player.dart';
import 'package:mutfakapp/src/sound/kds_sound_event.dart';
import 'package:mutfakapp/src/sound/tts_announcer.dart';

import 'fake_device_session_store.dart';
import 'fake_kds_settings_store.dart';
import 'fake_kitchen_health_api.dart';
import 'fake_kitchen_service.dart';
import 'fake_system_audio.dart';
import 'fake_unlock_store.dart';
import 'unlock_helper.dart';

class _NullPrinter implements PrinterDevice {
  @override
  Future<void> write(Uint8List bytes) async {}
}

class _NullOrderSource implements OrderSource {
  @override
  Stream<List<KitchenOrder>> watch() =>
      Stream<List<KitchenOrder>>.value(const <KitchenOrder>[]);

  @override
  Stream<OrderSourceConnection> get connection =>
      Stream<OrderSourceConnection>.value(OrderSourceConnection.connected);

  @override
  Future<void> refresh() async {}

  @override
  Future<void> dispose() async {}
}

/// Eşlenmiş bir kasa kurar ve sağlık ucunu sahteler.
Future<({FakeDeviceSessionStore session, PrintQueue queue})> pumpPaired(
  WidgetTester tester,
  FakeKitchenHealthApi health,
) async {
  await tester.binding.setSurfaceSize(const Size(1920, 1080));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final session = FakeDeviceSessionStore(
    baseUrl: 'http://test/api',
    token: 'kdev_test',
  );
  final queue = PrintQueue.inMemory();
  addTearDown(queue.close);

  final kitchen = FakeKitchenService();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        deviceSessionStoreProvider.overrideWithValue(session),
        initialDeviceSessionProvider.overrideWithValue(
          const DeviceSession(baseUrl: 'http://test/api', token: 'kdev_test'),
        ),
        orderSourceProvider.overrideWithValue(_NullOrderSource()),
        printQueueProvider.overrideWithValue(queue),
        printerDeviceProvider.overrideWithValue(_NullPrinter()),
        kitchenServiceProvider.overrideWithValue(kitchen),
        kdsSettingsStoreProvider.overrideWithValue(FakeKdsSettingsStore()),
        unlockStoreProvider.overrideWithValue(FakeUnlockStore()),
        // Alt süreç açan her şey sahte: gerçekleri test makinesinde
        // `pw-play` / `spd-say` / `wpctl` çağırır ve asılı zamanlayıcı
        // bırakır.
        alarmPlayerProvider.overrideWithValue(SilentAlarmPlayer()),
        connectionAlarmPlayerProvider.overrideWithValue(SilentAlarmPlayer()),
        bbdAlarmPlayerProvider.overrideWithValue(SilentAlarmPlayer()),
        ttsAnnouncerProvider.overrideWithValue(const SilentTtsAnnouncer()),
        systemAudioProvider.overrideWithValue(FakeSystemAudio()),
        salesControlApiProvider.overrideWithValue(FakeSalesControlApi()),
        bbdApiProvider.overrideWithValue(FakeBbdApi()),
        kitchenHealthApiProvider.overrideWithValue(health),
        printServiceProvider.overrideWith(
          (ref) => PrintService(
            queue: queue,
            device: _NullPrinter(),
            kitchen: kitchen,
          ),
        ),
      ],
      child: const MutfakApp(),
    ),
  );

  await tester.pump();
  await unlockApp(tester);
  await tester.pump();

  return (session: session, queue: queue);
}

Future<void> tearDownTree(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox.shrink());

/// Bir sağlık turunun tamamlanmasını bekler.
///
/// `runAsync` ŞART: toplayıcı yazıcı cihaz dosyasını GERÇEKTEN yokluyor
/// (`PrinterProbe.check` → `File.exists`) ve bu gerçek bir `dart:io`
/// çağrısı. Widget testleri sahte saat bölgesinde koşuyor; orada gerçek
/// asenkron GÇ hiç tamamlanmaz ve bildirim sonsuza dek yarım kalırdı.
/// Bu yoklamanın sahteleneMEmesi bilinçli: sahada "yazıcı arızalı" diye
/// yalan bildirim üreten hata tam olarak önbellekten okumaktı.
Future<void> saglikTuru(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('UNPAIR komutu kasayı eşleme ekranına döndürür', (tester) async {
    final health = FakeKitchenHealthApi()
      ..commands = const [KitchenCommand(id: 1, command: KitchenCommand.unpair)];

    final kurulum = await pumpPaired(tester, health);

    expect(find.byType(PairingScreen), findsNothing);

    // İlk sağlık turu komutu getirir ve çalıştırır.
    await saglikTuru(tester);

    expect(
      find.byType(PairingScreen),
      findsOneWidget,
      reason: 'Token silinince kök bileşen eşleme ekranını göstermeli.',
    );
    expect(await kurulum.session.tokens.read(), isNull);

    await tearDownTree(tester);
  });

  testWidgets('CLEAR_QUEUE komutu bekleyen işleri düşürür', (tester) async {
    final health = FakeKitchenHealthApi()
      ..commands = const [
        KitchenCommand(id: 2, command: KitchenCommand.clearQueue),
      ];

    final kurulum = await pumpPaired(tester, health);

    kurulum.queue.enqueue(
      orderId: 41,
      type: ReceiptType.mutfak,
      createdAt: DateTime.utc(2026, 8, 18),
    );
    expect(kurulum.queue.pendingCount(), 1);

    await saglikTuru(tester);

    expect(kurulum.queue.pendingCount(), isZero);

    await tearDownTree(tester);
  });

  testWidgets('SUNUCUDAN GELEN ses listesi kasada uygulanır', (tester) async {
    // K-22 §1'in uçtan uca hâli: yönetici panelden yazıcı uyarısını
    // kapatıyor ve kasa bir sağlık turu sonra sesi kesiyor.
    final health = FakeKitchenHealthApi()
      ..settings = const KitchenManagedSettings(
        disabledSoundEvents: {KdsSoundEvent.printerError},
      );

    await pumpPaired(tester, health);
    await saglikTuru(tester);

    final kapsam = tester
        .element(find.byType(MutfakApp))
        .findAncestorWidgetOfExactType<UncontrolledProviderScope>();
    expect(kapsam, isNotNull);

    final ayarlar = kapsam!.container.read(kdsSettingsProvider);

    expect(ayarlar.soundEnabledFor(KdsSoundEvent.printerError), isFalse);
    expect(
      ayarlar.soundEnabledFor(KdsSoundEvent.newOrder),
      isTrue,
      reason: 'Listede olmayan uyarı açık kalmalı.',
    );
    expect(
      ayarlar.soundEnabledFor(KdsSoundEvent.connectionLost),
      isTrue,
      reason: 'Bağlantı uyarısı hiçbir koşulda kapanmaz.',
    );

    await tearDownTree(tester);
  });

  testWidgets('sağlık bildirimi TELEMETRİYİ taşır', (tester) async {
    final health = FakeKitchenHealthApi();
    final kurulum = await pumpPaired(tester, health);

    kurulum.queue.enqueue(
      orderId: 7,
      type: ReceiptType.mutfak,
      createdAt: DateTime.utc(2026, 8, 18, 6),
    );

    await saglikTuru(tester);

    expect(health.reports, isNotEmpty);
    final son = health.reports.last;

    // Ses açık ve oynatıcı susturulmuş (`SilentAlarmPlayer`): kasa bunu
    // olduğu gibi bildirmeli, gizlememeli.
    expect(son.alarmMuted, isTrue);
    expect(son.alarmMuteReason, isNotNull);
    expect(son.soundOk, isFalse);

    await tearDownTree(tester);
  });
}
