/// Operasyonel yeteneklerin ekran testleri: aciliyet, arama, boş/hata
/// durumları, sesli uyarı ve karttan fiş yeniden basma.
///
/// Kilit gerçekten açılıyor (`unlock_helper.dart`); üretim kodunda "testte
/// kilidi atla" bayrağı yok.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/config/app_config.dart';
import 'package:mutfakapp/src/data/printer_probe.dart';
import 'package:mutfakapp/src/data/providers.dart';
import 'package:mutfakapp/src/kds/order_alert.dart';
import 'package:mutfakapp/src/kds/widgets/order_card.dart';
import 'package:mutfakapp/src/printing/print_queue.dart';
import 'package:mutfakapp/src/printing/print_service.dart';
import 'package:mutfakapp/src/printing/printer_device.dart';
import 'package:mutfakapp/src/settings/kds_settings.dart';
import 'package:mutfakapp/src/settings/settings_screen.dart';

import 'fake_kds_settings_store.dart';
import 'fake_kitchen_service.dart';
import 'kds_screen_test.dart' show pumpKds, tearDownTree;

/// Testin sabit eşikleri; gerçek saat yerine `createdAt` geriye alınır.
const KdsSettings settings = KdsSettings(
  soundEnabled: true,
  pollSeconds: 5,
  printerDevicePath: '/dev/thermal0',
  warningAfterMinutes: 10,
  lateAfterMinutes: 20,
);

/// Yayınları testin denetlediği [OrderSource].
///
/// `FakeOrderSource` tek bir değer yayınlar; "yeni sipariş DÜŞTÜ" olayını
/// ölçmek için en az iki yayın gerekiyor.
class ControllableOrderSource implements OrderSource {
  final StreamController<List<KitchenOrder>> _orders =
      StreamController<List<KitchenOrder>>.broadcast();

  @override
  Stream<List<KitchenOrder>> watch() => _orders.stream;

  @override
  Stream<OrderSourceConnection> get connection =>
      Stream<OrderSourceConnection>.value(OrderSourceConnection.connected);

  @override
  Future<void> refresh() async {}

  @override
  Future<void> dispose() async => _orders.close();

  void emit(List<KitchenOrder> orders) => _orders.add(orders);
}

/// Çalınan uyarıları sayan sahte [OrderAlert].
class RecordingAlert implements OrderAlert {
  int dings = 0;

  @override
  void ding() => dings++;
}

class NullPrinter implements PrinterDevice {
  @override
  Future<void> write(Uint8List bytes) async {}
}

/// Geçmişte oluşmuş sipariş: gecikme senaryolarında sabit bir yaş verir.
KitchenOrder agedOrder({
  required int id,
  required Duration age,
  OrderStatus status = OrderStatus.yeni,
}) => makeOrder(
  id: id,
  status: status,
  createdAt: DateTime.now().toUtc().subtract(age),
);

void main() {
  group('Aciliyet', () {
    testWidgets('gecikme yokken üst çubuk yeşil "Gecikme yok" der', (
      tester,
    ) async {
      await pumpKds(
        tester,
        settings: settings,
        orders: [agedOrder(id: 1, age: const Duration(minutes: 1))],
      );

      expect(find.text('Gecikme yok'), findsOneWidget);

      await tearDownTree(tester);
    });

    testWidgets('geciken sipariş üst çubukta sayılır', (tester) async {
      await pumpKds(
        tester,
        settings: settings,
        orders: [
          agedOrder(id: 1, age: const Duration(minutes: 1)),
          agedOrder(id: 2, age: const Duration(minutes: 25)),
          agedOrder(id: 3, age: const Duration(minutes: 40)),
        ],
      );

      expect(find.text('GECİKEN 2'), findsOneWidget);
      expect(find.text('Gecikme yok'), findsNothing);

      await tearDownTree(tester);
    });

    testWidgets('kart bekleme süresini gösterir', (tester) async {
      await pumpKds(
        tester,
        settings: settings,
        orders: [agedOrder(id: 1, age: const Duration(minutes: 12))],
      );

      expect(find.text('12 dk'), findsOneWidget);

      await tearDownTree(tester);
    });

    testWidgets('bir saati aşan bekleme saat + dakika yazar', (tester) async {
      await pumpKds(
        tester,
        settings: settings,
        orders: [agedOrder(id: 1, age: const Duration(hours: 1, minutes: 5))],
      );

      expect(find.text('1 sa 5 dk'), findsOneWidget);

      await tearDownTree(tester);
    });

    testWidgets('eşikler ayarlardan gelir', (tester) async {
      // 25 dakika bekleyen sipariş, eşik 40 dakikaysa gecikmiş sayılmaz.
      await pumpKds(
        tester,
        settings: settings.copyWith(
          warningAfterMinutes: 30,
          lateAfterMinutes: 40,
        ),
        orders: [agedOrder(id: 1, age: const Duration(minutes: 25))],
      );

      expect(find.text('Gecikme yok'), findsOneWidget);

      await tearDownTree(tester);
    });
  });

  group('Arama', () {
    final orders = [
      makeOrder(
        id: 5012,
        items: const [KitchenOrderItem(name: 'Mercimek Çorbası', quantity: 2)],
      ),
      makeOrder(
        id: 5013,
        items: const [KitchenOrderItem(name: 'Pilav', quantity: 1)],
      ),
    ];

    testWidgets('sorgu eşleşmeyen kartları gizler', (tester) async {
      await pumpKds(tester, settings: settings, orders: orders);
      expect(find.text('S-5012'), findsOneWidget);
      expect(find.text('S-5013'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'pilav');
      await tester.pump();

      expect(find.text('S-5012'), findsNothing);
      expect(find.text('S-5013'), findsOneWidget);
      expect(find.text('1/2 sipariş'), findsOneWidget);

      await tearDownTree(tester);
    });

    testWidgets('sonuç yoksa açıklama ve temizleme çıkışı gösterilir', (
      tester,
    ) async {
      await pumpKds(tester, settings: settings, orders: orders);

      await tester.enterText(find.byType(TextField), 'lahmacun');
      await tester.pump();

      expect(find.text('Aramayla eşleşen sipariş yok'), findsOneWidget);
      expect(find.text('Bekleyen sipariş yok'), findsNothing);

      // Temizleme, personeli aramada kilitli bırakmaz.
      await tester.tap(find.text('Aramayı temizle'));
      await tester.pump();

      expect(find.text('S-5012'), findsOneWidget);

      await tearDownTree(tester);
    });

    testWidgets('arama geciken sayacını etkilemez', (tester) async {
      // Filtre yalnızca çizimi daraltır; mutfağın toplam yükü değişmez.
      await pumpKds(
        tester,
        settings: settings,
        orders: [
          agedOrder(id: 1, age: const Duration(minutes: 40)),
          makeOrder(id: 2, createdAt: DateTime.now().toUtc()),
        ],
      );

      await tester.enterText(find.byType(TextField), 'S-2');
      await tester.pump();

      expect(find.text('S-1'), findsNothing);
      expect(find.text('GECİKEN 1'), findsOneWidget);

      await tearDownTree(tester);
    });
  });

  group('Boş ve hata durumları', () {
    testWidgets('hiç sipariş yokken pano ne olduğunu açıklar', (tester) async {
      await pumpKds(tester, settings: settings, orders: const []);

      expect(find.text('Bekleyen sipariş yok'), findsOneWidget);
      expect(
        find.text(
          'Yeni sipariş düştüğünde burada belirir ve sesli uyarı verir.',
        ),
        findsOneWidget,
      );

      await tearDownTree(tester);
    });

    testWidgets('bağlantı kopunca panonun üstünde büyük şerit çıkar', (
      tester,
    ) async {
      await pumpKds(
        tester,
        settings: settings,
        orders: [makeOrder(id: 1)],
        state: OrderSourceConnection.disconnected,
      );

      expect(find.text('BAĞLANTI YOK'), findsOneWidget);
      // Son bilinen liste silinmez (`docs/10` S4 adım 4).
      expect(find.text('S-1'), findsOneWidget);

      await tearDownTree(tester);
    });

    testWidgets('yazıcı yoksa şerit fişlerin biriktiğini söyler', (
      tester,
    ) async {
      await pumpKds(
        tester,
        settings: settings,
        orders: const [],
        printer: PrinterAvailability.unavailable,
      );

      expect(find.text('YAZICI YOK'), findsOneWidget);

      await tearDownTree(tester);
    });

    testWidgets('her şey yolundayken şerit görünmez', (tester) async {
      await pumpKds(tester, settings: settings, orders: const []);

      expect(find.text('BAĞLANTI YOK'), findsNothing);
      expect(find.text('YAZICI YOK'), findsNothing);

      await tearDownTree(tester);
    });
  });

  group('Sesli uyarı', () {
    test('ses şalteri sağlayıcıyı değiştirir', () {
      final container = ProviderContainer(
        overrides: [
          initialKdsSettingsProvider.overrideWithValue(settings),
          kdsSettingsStoreProvider.overrideWithValue(FakeKdsSettingsStore()),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(orderAlertProvider), isA<SystemOrderAlert>());

      container
          .read(kdsSettingsProvider.notifier)
          .update(settings.copyWith(soundEnabled: false));

      expect(container.read(orderAlertProvider), isA<SilentOrderAlert>());
    });

    testWidgets('yeni sipariş düşünce bir kez öter', (tester) async {
      final source = ControllableOrderSource();
      final alert = RecordingAlert();
      addTearDown(source.dispose);

      await pumpKds(
        tester,
        settings: settings,
        orders: const [],
        source: source,
        alert: alert,
      );

      // İlk yayın "zaten ekranda olanlar" sayılır, uyarı üretmez.
      source.emit([makeOrder(id: 1)]);
      await tester.pump();
      expect(alert.dings, isZero);

      source.emit([makeOrder(id: 1), makeOrder(id: 2)]);
      await tester.pump();
      expect(alert.dings, 1);

      await tearDownTree(tester);
    });

    testWidgets('aynı anda düşen üç sipariş üç kez ötmez', (tester) async {
      final source = ControllableOrderSource();
      final alert = RecordingAlert();
      addTearDown(source.dispose);

      await pumpKds(
        tester,
        settings: settings,
        orders: const [],
        source: source,
        alert: alert,
      );

      source.emit(const []);
      await tester.pump();
      source.emit([makeOrder(id: 1), makeOrder(id: 2), makeOrder(id: 3)]);
      await tester.pump();

      expect(alert.dings, 1);

      await tearDownTree(tester);
    });

    testWidgets('onaylanmış sipariş listeye girince ötmez', (tester) async {
      // Uygulama yeniden başladığında tüm liste "yeni gelmiş" gibi görünür;
      // dikkat isteyen kart yalnızca henüz onaylanmamış olandır.
      final source = ControllableOrderSource();
      final alert = RecordingAlert();
      addTearDown(source.dispose);

      await pumpKds(
        tester,
        settings: settings,
        orders: const [],
        source: source,
        alert: alert,
      );

      source.emit(const []);
      await tester.pump();
      source.emit([makeOrder(id: 7, status: OrderStatus.hazirlaniyor)]);
      await tester.pump();

      expect(alert.dings, isZero);

      await tearDownTree(tester);
    });
  });

  group('Karttan fiş yeniden basma', () {
    testWidgets('menüden mutfak fişi seçilince iş kuyruğa girer', (
      tester,
    ) async {
      final queue = PrintQueue.inMemory();
      addTearDown(queue.close);
      // İşçi başlatılmaz: kuyruğa girdiğini ölçüyoruz, kâğıt basmıyoruz.
      final service = PrintService(
        queue: queue,
        device: NullPrinter(),
        kitchen: FakeKitchenService(),
      );
      addTearDown(service.dispose);

      await pumpKds(
        tester,
        settings: settings,
        orders: [makeOrder(id: 5012)],
        printService: service,
      );

      await tester.tap(find.byIcon(Icons.print_outlined));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Mutfak fişini yeniden bas'));
      await tester.pump();

      expect(queue.all(), hasLength(1));
      expect(queue.all().single.orderId, 5012);
      expect(queue.all().single.type, ReceiptType.mutfak);

      await tearDownTree(tester);
    });

    testWidgets('her kartta yeniden basma düğmesi vardır', (tester) async {
      await pumpKds(
        tester,
        settings: settings,
        orders: [makeOrder(id: 1), makeOrder(id: 2)],
      );

      expect(
        find.descendant(
          of: find.byType(OrderCard),
          matching: find.byIcon(Icons.print_outlined),
        ),
        findsNWidgets(2),
      );

      await tearDownTree(tester);
    });
  });

  group('Ayarlar ekranı', () {
    testWidgets('durum çubuğundaki düğme ayarları açar ve PIN istemez', (
      tester,
    ) async {
      await pumpKds(tester, settings: settings, orders: const []);

      await tester.tap(find.text('Ayarlar'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SettingsScreen), findsOneWidget);
      // `docs/05` §8: PIN kaldırıldı, ayarlar doğrudan açılır.
      expect(find.text('Sunucu'), findsOneWidget);
      expect(find.text('Yazıcı'), findsOneWidget);
      expect(find.text('Uyarılar ve aciliyet'), findsOneWidget);
      expect(find.text('Yazdırma kuyruğu'), findsOneWidget);

      await tearDownTree(tester);
    });

    testWidgets('eşik düğmesi ayarı değiştirir', (tester) async {
      await pumpKds(tester, settings: settings, orders: const []);

      await tester.tap(find.text('Ayarlar'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('20 dk'), findsOneWidget);
      // "Kırmızı gecikme eşiği" satırındaki artırma düğmesi.
      await tester.tap(
        find
            .descendant(
              of: find.byTooltip('Artır'),
              matching: find.byIcon(Icons.add),
            )
            .last,
      );
      await tester.pump();

      expect(find.text('25 dk'), findsOneWidget);

      await tearDownTree(tester);
    });

    testWidgets('sürüm bilgisi gösterilir', (tester) async {
      await pumpKds(tester, settings: settings, orders: const []);

      await tester.tap(find.text('Ayarlar'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.dragUntilVisible(
        find.text(AppConfig.appVersion),
        find.byType(ListView),
        const Offset(0, -200),
      );

      expect(find.text(AppConfig.appVersion), findsOneWidget);

      await tearDownTree(tester);
    });
  });
}
