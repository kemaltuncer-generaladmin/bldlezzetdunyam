/// KDS ekranı widget testi — `docs/05-mutfakapp.md` §3'teki üç bölge.
///
/// Ağ yoktur: [OrderSource] sahtelenir, ekran yalnızca gelen listeyi çizer.
library;

import 'dart:typed_data';

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/app.dart';
import 'package:mutfakapp/src/data/device_session.dart';
import 'package:mutfakapp/src/data/printer_probe.dart';
import 'package:mutfakapp/src/data/providers.dart';
import 'package:mutfakapp/src/lock/unlock_screen.dart';
import 'package:mutfakapp/src/printing/print_queue.dart';
import 'package:mutfakapp/src/printing/print_service.dart';
import 'package:mutfakapp/src/printing/printer_device.dart';
import 'package:mutfakapp/src/settings/kds_settings.dart';

import 'package:mutfakapp/src/data/kitchen_health.dart';
import 'package:mutfakapp/src/kds/widgets/order_card.dart';
import 'package:mutfakapp/src/sound/alarm_player.dart';
import 'package:mutfakapp/src/sound/tts_announcer.dart';

import 'fake_kds_settings_store.dart';
import 'fake_unlock_store.dart';
import 'fake_update_check.dart';
import 'unlock_helper.dart';
import 'fake_device_session_store.dart';
import 'fake_kitchen_service.dart';
import 'fake_kitchen_health_api.dart';
import 'fake_system_audio.dart';

class FakeOrderSource implements OrderSource {
  FakeOrderSource({
    required this.orders,
    this.state = OrderSourceConnection.connected,
  });

  final List<KitchenOrder> orders;
  final OrderSourceConnection state;
  int refreshCount = 0;

  @override
  Stream<List<KitchenOrder>> watch() =>
      Stream<List<KitchenOrder>>.value(orders);

  @override
  Stream<OrderSourceConnection> get connection =>
      Stream<OrderSourceConnection>.value(state);

  @override
  Future<void> refresh() async => refreshCount++;

  @override
  Future<void> dispose() async {}
}

Future<void> pumpKds(
  WidgetTester tester, {
  required List<KitchenOrder> orders,
  OrderSourceConnection state = OrderSourceConnection.connected,
  PrinterAvailability printer = PrinterAvailability.ready,
  FakeKitchenService? kitchen,
  // Aşağıdakiler yeni davranışları ölçmek için: ayarlar (eşikler, ses),
  // alarm oynatıcısı, akış denetimi ve sağlık ucu gerektiren senaryolar.
  KdsSettings? settings,
  AlarmPlayer? alarm,
  OrderSource? source,
  PrintService? printService,
  KitchenHealthApi? health,
  FakeUnlockStore? store,
  FakeSalesControlApi? sales,

  /// `false` ise kilit ekranı açık bırakılır — arkada ne olduğunu ölçmek için.
  bool unlock = true,
}) async {
  final kitchenService = kitchen ?? FakeKitchenService();
  // Kasa 1920×1080 bir mutfak monitörüne bağlıdır; testin varsayılan
  // 800×600 yüzeyi bu ekranı temsil etmez.
  await tester.binding.setSurfaceSize(const Size(1920, 1080));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final queue = PrintQueue.inMemory();
  addTearDown(queue.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Eşlenmiş cihaz: kök bileşen KDS ekranını gösterir.
        deviceSessionStoreProvider.overrideWithValue(
          FakeDeviceSessionStore(
            baseUrl: 'http://test/api',
            token: 'kdev_test',
          ),
        ),
        initialDeviceSessionProvider.overrideWithValue(
          const DeviceSession(baseUrl: 'http://test/api', token: 'kdev_test'),
        ),
        orderSourceProvider.overrideWithValue(
          source ?? FakeOrderSource(orders: orders, state: state),
        ),
        printerStatusProvider.overrideWith(
          (ref) => Stream<PrinterAvailability>.value(printer),
        ),
        printQueueProvider.overrideWithValue(queue),
        // Bağlantı uyarısı üretimde genel ses şalterini DİNLEMEZ; testte
        // gerçek oynatıcı alt süreç açar ve asılı zamanlayıcı bırakır.
        connectionAlarmPlayerProvider.overrideWithValue(SilentAlarmPlayer()),
        unlockStoreProvider.overrideWithValue(store ?? FakeUnlockStore()),
        // Saatlik sürüm denetimi ağ isteği açıyor ve HTTP zaman aşımı
        // zamanlayıcısı test bittikten sonra asılı kalıyor.
        updateCheckProvider.overrideWith(FakeUpdateCheck.new),
        printerDeviceProvider.overrideWithValue(_NullPrinter()),
        kitchenServiceProvider.overrideWithValue(kitchenService),
        // Ayar deposu her testte sahtedir: gerçek `shared_preferences`
        // platform kanalı test ortamında yok ve her yazma istisna atar.
        kdsSettingsStoreProvider.overrideWithValue(FakeKdsSettingsStore()),
        if (settings != null)
          initialKdsSettingsProvider.overrideWithValue(settings),
        // Alarm oynatıcısı HER TESTTE sahtedir: gerçek `ProcessAlarmPlayer`
        // test makinesinde `pw-play` süreci açardı.
        alarmPlayerProvider.overrideWithValue(alarm ?? SilentAlarmPlayer()),
        // Sağlık ucu de öyle: gerçek istemci `dart:io` ile ağa çıkar.
        kitchenHealthApiProvider.overrideWithValue(
          health ?? FakeKitchenHealthApi(),
        ),
        // Sesli anons ve hoparlör denetimi de sahte: ikisi de alt süreç
        // (`spd-say`, `wpctl`) açar ve test makinesinin ses kurulumuna
        // bağlı, kararsız testler üretir.
        ttsAnnouncerProvider.overrideWithValue(const SilentTtsAnnouncer()),
        systemAudioProvider.overrideWithValue(FakeSystemAudio()),
        // Satış kontrolü de sahte: gerçek uç `dart:io` ile ağa çıkar ve
        // ekran testini test makinesinin ağına bağlar.
        salesControlApiProvider.overrideWithValue(
          sales ?? FakeSalesControlApi(),
        ),
        // BBD köprüsü de sahte: gerçek uç `dart:io` ile ağa çıkar ve
        // ekran testini test makinesinin ağına bağlar (K-16).
        bbdApiProvider.overrideWithValue(FakeBbdApi()),
        bbdAlarmPlayerProvider.overrideWithValue(SilentAlarmPlayer()),
        // İşçi BAŞLATILMAZ: ekran testi yazdırmayı değil çizimi ölçer,
        // çalışan bir kuyruk döngüsü testte asılı zamanlayıcı bırakır.
        printServiceProvider.overrideWith(
          (ref) =>
              printService ??
              PrintService(
                queue: queue,
                device: _NullPrinter(),
                kitchen: kitchenService,
              ),
        ),
      ],
      child: const MutfakApp(),
    ),
  );
  await tester.pump();
  if (unlock) {
    await unlockApp(tester);
  }
  await tester.pump();
}

/// Kilit ekranı AÇIK hâlde kurar — arkadaki ağacın çalıştığını ölçmek için.
Future<void> pumpKdsLocked(
  WidgetTester tester, {
  required List<KitchenOrder> orders,
  FakeUnlockStore? store,
}) => pumpKds(tester, orders: orders, store: store, unlock: false);

/// Zamanlayıcı taşıyan parçaları (saat, yanıp sönme) söker.
Future<void> tearDownTree(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox.shrink());

/// Hiçbir şey yapmayan yazıcı: ekran testleri fiş basmamalı.
class _NullPrinter implements PrinterDevice {
  @override
  Future<void> write(Uint8List bytes) async {}
}

void main() {
  testWidgets('üç sütun başlığı ve sayaçları görünür', (tester) async {
    await pumpKds(
      tester,
      orders: [
        makeOrder(id: 1, status: OrderStatus.yeni),
        makeOrder(id: 2, status: OrderStatus.yeni),
        makeOrder(id: 3, status: OrderStatus.hazirlaniyor),
        makeOrder(id: 4, status: OrderStatus.hazir),
      ],
    );

    expect(find.text('YENİ (2)'), findsOneWidget);
    expect(find.text('HAZIRLANIYOR (1)'), findsOneWidget);
    expect(find.text('HAZIR (1)'), findsOneWidget);

    await tearDownTree(tester);
  });

  testWidgets('kart sipariş numarasını, rozeti ve adedi gösterir', (
    tester,
  ) async {
    await pumpKds(
      tester,
      orders: [
        makeOrder(
          id: 5012,
          status: OrderStatus.yeni,
          items: const [KitchenOrderItem(name: 'Tavuk Sote', quantity: 2)],
        ),
      ],
    );

    expect(find.text('S-5012'), findsOneWidget);
    expect(find.text('ADR'), findsOneWidget);
    expect(find.text('2×'), findsOneWidget);
    expect(find.text('Tavuk Sote'), findsOneWidget);

    await tearDownTree(tester);
  });

  testWidgets('gel-al siparişte GELAL rozeti basılır', (tester) async {
    await pumpKds(
      tester,
      orders: [
        makeOrder(
          id: 9,
          status: OrderStatus.hazir,
          deliveryType: DeliveryType.pickup,
        ),
      ],
    );

    expect(find.text('GELAL'), findsOneWidget);
    // `hazir` + `pickup` → tek ileri adım "TESLİM EDİLDİ" (yolda gösterilmez).
    expect(find.text('TESLİM EDİLDİ'), findsOneWidget);
    expect(find.text('YOLA ÇIKTI'), findsNothing);

    await tearDownTree(tester);
  });

  testWidgets('adrese gönderim hazır siparişinde YOLA ÇIKTI görünür', (
    tester,
  ) async {
    await pumpKds(
      tester,
      orders: [makeOrder(id: 9, status: OrderStatus.hazir)],
    );

    expect(find.text('YOLA ÇIKTI'), findsOneWidget);
    expect(find.text('TESLİM EDİLDİ'), findsNothing);

    await tearDownTree(tester);
  });

  testWidgets('her durum için doğru ileri buton yazısı', (tester) async {
    const expected = <OrderStatus, String>{
      OrderStatus.yeni: 'ONAYLA',
      OrderStatus.onaylandi: 'BAŞLA',
      OrderStatus.hazirlaniyor: 'HAZIR',
      OrderStatus.yolda: 'TESLİM EDİLDİ',
    };

    for (final entry in expected.entries) {
      await pumpKds(tester, orders: [makeOrder(id: 1, status: entry.key)]);
      expect(
        find.widgetWithText(FilledButton, entry.value),
        findsOneWidget,
        reason: '${entry.key} için buton yazısı yanlış',
      );
      await tearDownTree(tester);
    }
  });

  testWidgets('sipariş notu gizlenmez ve vurgulu basılır', (tester) async {
    await pumpKds(
      tester,
      orders: [
        makeOrder(id: 1, status: OrderStatus.yeni, customerNote: 'Az acılı'),
      ],
    );

    expect(find.text('NOT: Az acılı'), findsOneWidget);

    final noteBox = tester.widget<Container>(
      find
          .ancestor(
            of: find.text('NOT: Az acılı'),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(
      (noteBox.decoration! as BoxDecoration).color,
      const Color(KdsColors.noteBackground),
    );

    await tearDownTree(tester);
  });

  testWidgets('ürün adı ve adet punto alt sınırlarını karşılar', (
    tester,
  ) async {
    await pumpKds(
      tester,
      orders: [
        makeOrder(
          id: 1,
          items: const [KitchenOrderItem(name: 'Tavuk Sote', quantity: 2)],
        ),
      ],
    );

    // `docs/05` §3: ürün adı en az 20sp, adet en az 28sp ve kalın.
    final name = tester.widget<Text>(find.text('Tavuk Sote'));
    expect(name.style!.fontSize, greaterThanOrEqualTo(20));

    final quantity = tester.widget<Text>(find.text('2×'));
    expect(quantity.style!.fontSize, greaterThanOrEqualTo(28));
    expect(quantity.style!.fontWeight, FontWeight.bold);

    await tearDownTree(tester);
  });

  testWidgets('üretim şeridi hazırlanacakları toplar', (tester) async {
    await pumpKds(
      tester,
      orders: [
        makeOrder(
          id: 1,
          status: OrderStatus.hazirlaniyor,
          items: const [KitchenOrderItem(name: 'Tavuk Sote', quantity: 40)],
        ),
      ],
    );

    expect(find.text('ÜRETİM LİSTESİ'), findsOneWidget);
    expect(find.textContaining('Tavuk Sote'), findsWidgets);

    await tearDownTree(tester);
  });

  testWidgets('durum çubuğu bağlantı, yazıcı ve kuyruk gösterir', (
    tester,
  ) async {
    await pumpKds(tester, orders: const []);

    expect(find.text('Bağlı'), findsOneWidget);
    expect(find.text('Yazıcı hazır'), findsOneWidget);
    expect(find.text('Kuyruk: 0'), findsOneWidget);
    expect(find.text('Ayarlar'), findsOneWidget);

    await tearDownTree(tester);
  });

  testWidgets('bağlantı yokken uyarı çıkar, liste ekranda kalır', (
    tester,
  ) async {
    await pumpKds(
      tester,
      orders: [makeOrder(id: 1)],
      state: OrderSourceConnection.disconnected,
    );

    expect(find.text('Bağlantı yok'), findsOneWidget);
    // S4 adım 4: son bilinen liste silinmez.
    expect(find.text('S-1'), findsOneWidget);

    await tearDownTree(tester);
  });

  testWidgets('yazıcı yoksa kalıcı uyarı görünür', (tester) async {
    await pumpKds(
      tester,
      orders: const [],
      printer: PrinterAvailability.unavailable,
    );

    expect(find.text('Yazıcı yok'), findsOneWidget);

    await tearDownTree(tester);
  });

  testWidgets('cihaz iptal edilince eşleme ekranına dönülür', (tester) async {
    await pumpKds(
      tester,
      orders: [makeOrder(id: 1)],
      state: OrderSourceConnection.revoked,
    );
    await tester.pump();

    // `docs/05` §7 adım 5: pano kalkar, eşleme ekranı gelir.
    expect(find.text('Mutfak ekranını eşle'), findsOneWidget);
    expect(
      find.text('Bu cihazın yetkisi kaldırıldı. Yeni bir eşleme kodu girin.'),
      findsOneWidget,
    );
    expect(find.text('S-1'), findsNothing);

    await tearDownTree(tester);
  });

  testWidgets('geri alma butonu yoktur — yalnızca ileri adım gösterilir', (
    tester,
  ) async {
    await pumpKds(
      tester,
      orders: [makeOrder(id: 1, status: OrderStatus.hazirlaniyor)],
    );

    // Sipariş KARTI içindeki butonlara bakıyoruz: durum çubuğundaki
    // yoğunluk şalteri de bir FilledButton ve testi yanıltıyordu.
    expect(
      find.descendant(
        of: find.byType(OrderCard),
        matching: find.byType(FilledButton),
      ),
      findsOneWidget,
    );

    await tearDownTree(tester);
  });

  testWidgets('geri alma şeridi dar, yüzer ve büyük hedeflidir', (
    tester,
  ) async {
    final kitchen = FakeKitchenService()
      ..statusResult = makeOrder(id: 1, status: OrderStatus.hazir);
    await pumpKds(
      tester,
      orders: [makeOrder(id: 1, status: OrderStatus.hazirlaniyor)],
      kitchen: kitchen,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(OrderCard),
        matching: find.byType(FilledButton),
      ),
    );
    // `pumpAndSettle` kullanılmıyor: panoda sürekli dönen bir animasyon var
    // (aciliyet nabzı), test asla durulmaz.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Şerit panonun tamamını kaplamamalı: tam genişlikteki eski çubuk en alt
    // kartların düğmelerini kapatıyordu.
    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.behavior, SnackBarBehavior.floating);
    expect(bar.width, isNotNull);
    expect(bar.width, lessThan(600));

    // Ekranda 5 saniyeden uzun kalmamalı: uzun kalan şerit panoyu kapatıyor.
    expect(bar.duration, const Duration(seconds: 5));

    // Metin kısa, hedef büyük: parmakla basılan şey bir metin bağlantısı değil.
    expect(find.text('Hazırlanıyor durumuna'), findsOneWidget);
    final undo = find.widgetWithText(FilledButton, 'GERİ AL');
    expect(tester.getSize(undo).height, greaterThanOrEqualTo(48));

    // Kapatmak geri alma DEĞİLDİR: sunucuya yalnızca ilerletme gitmiş olmalı.
    await tester.tap(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('GERİ AL'), findsNothing);
    expect(kitchen.statusCalls, [(1, OrderStatus.hazir)]);

    await tearDownTree(tester);
  });

  testWidgets('yoğunluk tuşu sunucuya yazar ve etiketi değişir', (
    tester,
  ) async {
    final kitchen = FakeKitchenService();
    await pumpKds(tester, orders: const [], kitchen: kitchen);

    expect(find.text('Yoğunluk: KAPALI'), findsOneWidget);

    await tester.tap(find.text('Yoğunluk: KAPALI'));
    await tester.pump();

    expect(kitchen.busyCalls, [true]);
    expect(find.text('YOĞUNLUK AÇIK'), findsOneWidget);

    await tearDownTree(tester);
  });

  testWidgets('kilitliyken bile siparişler arkada akar', (tester) async {
    // SAHADA YAŞANDI: kilitliyken `_PairedRoot` hiç kurulmuyordu; sipariş
    // kaynağı, yazdırma tetikleri ve alarmlar da kurulmuyordu. Kasa
    // yeniden başladığında parola girilene kadar SİPARİŞ GELMİYORDU ve
    // bağlantı alarmı da çalmıyordu — çünkü yoklama hiç başlamamıştı.
    // Servis çökmede kendini geri getiriyor; bunu kimse fark etmez.
    await pumpKdsLocked(tester, orders: [makeOrder(id: 1)]);

    expect(find.byType(UnlockScreen), findsOneWidget);
    expect(
      find.text('S-1'),
      findsOneWidget,
      reason: 'Kilit ekranın ÜSTÜNDE durmalı, ağacın yerine geçmemeli.',
    );

    await tearDownTree(tester);
  });

  testWidgets('parola bir kez girilir, sonraki açılışta sorulmaz', (
    tester,
  ) async {
    // Her yeniden başlatmada sormak, çökme sonrası mutfağı kilit
    // ekranında bırakırdı.
    final store = FakeUnlockStore();

    await pumpKdsLocked(tester, orders: const [], store: store);
    expect(find.byType(UnlockScreen), findsOneWidget);

    await unlockApp(tester);
    await tester.pump();

    expect(find.byType(UnlockScreen), findsNothing);
    expect(store.unlocked, isTrue, reason: 'Açılış diske yazılmalı.');

    await tearDownTree(tester);
  });
}
