/// Operasyonel yeteneklerin ekran testleri: aciliyet, arama, boş/hata
/// durumları, sesli uyarı ve karttan fiş yeniden basma.
///
/// Kilit gerçekten açılıyor (`unlock_helper.dart`); üretim kodunda "testte
/// kilidi atla" bayrağı yok.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/config/app_config.dart';
import 'package:mutfakapp/src/data/printer_probe.dart';
import 'package:mutfakapp/src/data/providers.dart';
import 'package:mutfakapp/src/kds/widgets/order_card.dart';
import 'package:mutfakapp/src/sound/alarm_player.dart';
import 'package:mutfakapp/src/printing/print_queue.dart';
import 'package:mutfakapp/src/printing/print_service.dart';
import 'package:mutfakapp/src/printing/printer_device.dart';
import 'package:mutfakapp/src/settings/kds_settings.dart';
import 'package:mutfakapp/src/settings/settings_screen.dart';

import 'fake_kds_settings_store.dart';
import 'fake_kitchen_service.dart';
import 'fake_unlock_store.dart';
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

/// Kaç kez başlatılıp durdurulduğunu sayan sahte [AlarmPlayer].
class RecordingAlarmPlayer implements AlarmPlayer {
  int starts = 0;
  int stops = 0;
  bool _playing = false;

  /// `true` ise ses hiç çıkmıyor sayılır (oynatıcı yok / ayar kapalı).
  bool muted = false;

  @override
  bool get isPlaying => _playing;

  @override
  bool get isMuted => muted;
  @override
  String? get muteReason => muted ? 'test: ses yok' : null;

  @override
  String? get playerExecutable => muted ? null : 'test-player';

  @override
  Future<void> start() async {
    if (_playing) return;
    _playing = true;
    starts++;
  }

  @override
  Future<void> stop() async {
    if (!_playing) return;
    _playing = false;
    stops++;
  }

  @override
  Future<void> playOnce() async {
    starts++;
  }
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

/// Ayarlar listesini [target] görünene kadar kaydırır.
///
/// `scrollUntilVisible`'a kaydırılabilir alan AÇIKÇA veriliyor: ağaçta
/// ayarların altında pano da duruyor ve onun sütunları da kaydırılabilir.
/// Verilmezse "birden çok Scrollable" hatası alınır.
Future<void> scrollSettingsTo(WidgetTester tester, Finder target) =>
    tester.scrollUntilVisible(
      target,
      300,
      scrollable: find
          .descendant(
            of: find.byType(SettingsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
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

  group('Yeni sipariş alarmı', () {
    test('ses şalteri oynatıcıyı değiştirir', () {
      final container = ProviderContainer(
        overrides: [
          initialKdsSettingsProvider.overrideWithValue(settings),
          kdsSettingsStoreProvider.overrideWithValue(FakeKdsSettingsStore()),
          // Bağlantı uyarısı üretimde genel ses şalterini DİNLEMEZ; testte
          // gerçek oynatıcı alt süreç açar ve asılı zamanlayıcı bırakır.
          connectionAlarmPlayerProvider.overrideWithValue(SilentAlarmPlayer()),
          unlockStoreProvider.overrideWithValue(FakeUnlockStore()),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(alarmPlayerProvider), isA<ProcessAlarmPlayer>());

      container
          .read(kdsSettingsProvider.notifier)
          .update(settings.copyWith(soundEnabled: false));

      expect(container.read(alarmPlayerProvider), isA<SilentAlarmPlayer>());
    });

    testWidgets('yeni sipariş düşünce alarm çalar', (tester) async {
      final source = ControllableOrderSource();
      final alarm = RecordingAlarmPlayer();
      addTearDown(source.dispose);

      await pumpKds(
        tester,
        settings: settings,
        orders: const [],
        source: source,
        alarm: alarm,
      );

      source.emit(const []);
      await tester.pump();
      expect(alarm.starts, isZero);

      source.emit([makeOrder(id: 1)]);
      await tester.pump();
      expect(alarm.starts, 1);
      expect(alarm.isPlaying, isTrue);

      await tearDownTree(tester);
    });

    testWidgets('AÇILIŞTA bekleyen yeni sipariş varsa alarm çalar', (
      tester,
    ) async {
      // Elektrik kesintisi sonrası sessiz açılmak, siparişi kaçırmak demektir.
      final alarm = RecordingAlarmPlayer();

      await pumpKds(
        tester,
        settings: settings,
        orders: [makeOrder(id: 1, status: OrderStatus.yeni)],
        alarm: alarm,
      );

      expect(alarm.starts, 1);

      await tearDownTree(tester);
    });

    testWidgets('onaylanınca susar', (tester) async {
      final source = ControllableOrderSource();
      final alarm = RecordingAlarmPlayer();
      addTearDown(source.dispose);

      await pumpKds(
        tester,
        settings: settings,
        orders: const [],
        source: source,
        alarm: alarm,
      );

      source.emit([makeOrder(id: 1, status: OrderStatus.yeni)]);
      await tester.pump();
      expect(alarm.isPlaying, isTrue);

      source.emit([makeOrder(id: 1, status: OrderStatus.onaylandi)]);
      await tester.pump();

      expect(alarm.isPlaying, isFalse);
      expect(alarm.stops, 1);

      await tearDownTree(tester);
    });

    testWidgets('başka yeni sipariş kaldıysa çalmaya DEVAM eder', (
      tester,
    ) async {
      final source = ControllableOrderSource();
      final alarm = RecordingAlarmPlayer();
      addTearDown(source.dispose);

      await pumpKds(
        tester,
        settings: settings,
        orders: const [],
        source: source,
        alarm: alarm,
      );

      source.emit([
        makeOrder(id: 1, status: OrderStatus.yeni),
        makeOrder(id: 2, status: OrderStatus.yeni),
      ]);
      await tester.pump();

      source.emit([
        makeOrder(id: 1, status: OrderStatus.onaylandi),
        makeOrder(id: 2, status: OrderStatus.yeni),
      ]);
      await tester.pump();

      expect(alarm.isPlaying, isTrue);
      expect(alarm.stops, isZero);

      await tearDownTree(tester);
    });

    testWidgets('"Sesi sustur" düğmesi alarmı keser, kartı bırakmaz', (
      tester,
    ) async {
      final alarm = RecordingAlarmPlayer();

      await pumpKds(
        tester,
        settings: settings,
        orders: [makeOrder(id: 1, status: OrderStatus.yeni)],
        alarm: alarm,
      );

      expect(find.text('SESİ SUSTUR'), findsOneWidget);
      await tester.tap(find.text('SESİ SUSTUR'));
      await tester.pump();

      expect(alarm.isPlaying, isFalse);
      // Sipariş hâlâ onay bekliyor ve bunu yazıyor.
      expect(find.textContaining('Alarm susturuldu'), findsOneWidget);
      expect(find.text('S-1'), findsOneWidget);

      await tearDownTree(tester);
    });

    testWidgets('susturduktan sonra YENİ bir sipariş alarmı geri getirir', (
      tester,
    ) async {
      final source = ControllableOrderSource();
      final alarm = RecordingAlarmPlayer();
      addTearDown(source.dispose);

      await pumpKds(
        tester,
        settings: settings,
        orders: const [],
        source: source,
        alarm: alarm,
      );

      source.emit([makeOrder(id: 1, status: OrderStatus.yeni)]);
      await tester.pump();
      await tester.tap(find.text('SESİ SUSTUR'));
      await tester.pump();
      expect(alarm.isPlaying, isFalse);

      source.emit([
        makeOrder(id: 1, status: OrderStatus.yeni),
        makeOrder(id: 2, status: OrderStatus.yeni),
      ]);
      await tester.pump();

      expect(alarm.isPlaying, isTrue, reason: 'Yeni sipariş yeniden çalmalı.');

      await tearDownTree(tester);
    });

    testWidgets('onaylanmış sipariş listeye girince çalmaz', (tester) async {
      // Uygulama yeniden başladığında tüm liste "yeni gelmiş" gibi görünür;
      // dikkat isteyen kart yalnızca henüz onaylanmamış olandır.
      final alarm = RecordingAlarmPlayer();

      await pumpKds(
        tester,
        settings: settings,
        orders: [makeOrder(id: 7, status: OrderStatus.hazirlaniyor)],
        alarm: alarm,
      );

      expect(alarm.starts, isZero);

      await tearDownTree(tester);
    });

    testWidgets('ses çıkmıyorsa arayüz bunu GÖRÜNÜR biçimde söyler', (
      tester,
    ) async {
      // Sessiz bir alarm, alarm olmadığını bilmemekten iyidir.
      final alarm = RecordingAlarmPlayer()..muted = true;

      await pumpKds(
        tester,
        settings: settings,
        orders: [makeOrder(id: 1, status: OrderStatus.yeni)],
        alarm: alarm,
      );

      expect(find.text('ALARM ÇALMIYOR'), findsOneWidget);
      expect(find.text('SESİ SUSTUR'), findsNothing);

      await tearDownTree(tester);
    });

    testWidgets('bekleyen sipariş yokken bile sessizlik rozeti durur', (
      tester,
    ) async {
      final alarm = RecordingAlarmPlayer()..muted = true;

      await pumpKds(tester, settings: settings, orders: const [], alarm: alarm);

      expect(find.text('SES KAPALI'), findsOneWidget);

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

    testWidgets('KURYE FİŞİ de yeniden bastırılabilir', (tester) async {
      // Kurye fişi K-14'te üçüncü tip olarak eklendi ve tetikleyici onu
      // otomatik basıyor; ama kâğıt sıkışırsa personelin elle yeniden
      // bastıracak bir yolu YOKTU — menüde yalnız mutfak ve müşteri vardı.
      final queue = PrintQueue.inMemory();
      addTearDown(queue.close);
      final service = PrintService(
        queue: queue,
        device: NullPrinter(),
        kitchen: FakeKitchenService(),
      );
      addTearDown(service.dispose);

      await pumpKds(
        tester,
        settings: settings,
        orders: [makeOrder(id: 5013)],
        printService: service,
      );

      await tester.tap(find.byIcon(Icons.print_outlined));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Kurye fişini yeniden bas'));
      await tester.pump();

      expect(queue.all().single.type, ReceiptType.kurye);

      await tearDownTree(tester);
    });

    testWidgets('GEL-AL siparişte kurye fişi ÖNERİLMEZ', (tester) async {
      // Gel-al siparişin kuryesi yok; boş adresli bir kâğıt basmak
      // personeli olmayan bir teslimatı aramaya iter.
      await pumpKds(
        tester,
        settings: settings,
        orders: [makeOrder(id: 5014, deliveryType: DeliveryType.pickup)],
      );

      await tester.tap(find.byIcon(Icons.print_outlined));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Mutfak fişini yeniden bas'), findsOneWidget);
      expect(find.text('Kurye fişini yeniden bas'), findsNothing);

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

      // Alttaki bölümler `ListView` içinde tembel kuruluyor; ekrana
      // getirmeden aranırsa "yok" görünürler.
      for (final title in const [
        'Ses ve hoparlör',
        'Uyarılar ve aciliyet',
        'Dokunmatik',
        'Yazdırma kuyruğu',
      ]) {
        await scrollSettingsTo(tester, find.text(title));
        expect(find.text(title), findsOneWidget);
      }

      await tearDownTree(tester);
    });

    testWidgets('eşik düğmesi ayarı değiştirir', (tester) async {
      await pumpKds(tester, settings: settings, orders: const []);

      await tester.tap(find.text('Ayarlar'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // "Kırmızı gecikme eşiği" satırındaki artırma düğmesi. Sıra yerine
      // satırın KENDİ içinden aranıyor: ekranda başka sayısal ayarlar da
      // var ve `.last` gibi sıraya dayalı bir seçim, araya yeni bir ayar
      // eklenince sessizce başka düğmeye basardı.
      //
      // `.first` = etikete EN YAKIN satır, yani `_NumberSetting`'in kendi
      // satırı; `.last` ekranın tamamını kapsayan dış satırı seçerdi.
      final artir = find.descendant(
        of: find.ancestor(
          of: find.text('Kırmızı gecikme eşiği'),
          matching: find.byType(Row),
        ).first,
        matching: find.byIcon(Icons.add),
      );

      // İki adım: önce satır ağaca girsin (`ListView` tembel kuruyor),
      // sonra DÜĞMENİN kendisi görüş alanına alınsın. Yalnız etikete
      // kaydırmak yetmiyor — etiket görünürken düğme altta kalıyor ve
      // dokunuş boşa gidiyor (uyarı verir ama testi düşürmez: sessiz bir
      // yanlış geçme).
      await scrollSettingsTo(tester, find.text('Kırmızı gecikme eşiği'));
      await tester.ensureVisible(artir);
      await tester.pump();

      expect(find.text('20 dk'), findsOneWidget);

      await tester.tap(artir);
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
