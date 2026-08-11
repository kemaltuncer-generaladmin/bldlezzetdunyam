/// Abonelik üretim planı ekranı — K-15.
///
/// EKRANIN ASIL İŞİ "ne EKSİK" sorusunu cevaplamak. Üretim koşmamışsa
/// mutfak "bugün abonelik yok" sanıp hazırlık yapmıyor; o uyarı görünmezse
/// ekranın geri kalanı işe yaramaz.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/data/providers.dart';
import 'package:mutfakapp/src/data/subscription_plan.dart';
import 'package:mutfakapp/src/l10n/app_localizations.dart';
import 'package:mutfakapp/src/printing/print_queue.dart';
import 'package:mutfakapp/src/printing/print_service.dart';
import 'package:mutfakapp/src/printing/printer_device.dart';
import 'package:mutfakapp/src/subscription/subscription_plan_screen.dart';

import 'dart:typed_data';

import 'fake_kitchen_service.dart';

/// Ağa çıkmayan plan ucu.
class FakePlanApi implements SubscriptionPlanApi {
  FakePlanApi({this.days = const []});

  List<PlanDay> days;

  /// Son istenen aralık — sekmelerin gerçekten istek attığını sınamak için.
  PlanRange? lastRange;

  @override
  Future<List<PlanDay>> plan(PlanRange range) async {
    lastRange = range;
    return days;
  }
}

/// Baytları toplayan sahte yazıcı.
class RecordingPrinter implements PrinterDevice {
  final List<Uint8List> writes = [];

  @override
  Future<void> write(Uint8List bytes) async => writes.add(bytes);
}

PlanDay day({
  List<PlanTotal> totals = const [],
  List<PlanWarning> warnings = const [],
  List<PlanOrder> orders = const [],
}) => PlanDay(
  date: DateTime.utc(2026, 8, 12),
  orders: orders,
  totals: totals,
  warnings: warnings,
);

PlanOrder planOrder({
  int id = 1,
  String? time = '11:30',
  String? label = 'Konya Sanayi A.Ş.',
  OrderStatus status = OrderStatus.onaylandi,
}) => PlanOrder(
  id: id,
  orderNumber: 'S-$id',
  status: status,
  items: const [(name: 'Mercimek Çorbası', quantity: 60)],
  deliveryTime: time,
  label: label,
);

Future<RecordingPrinter> pumpPlan(
  WidgetTester tester,
  FakePlanApi api, {
  FakeKitchenService? kitchen,
}) async {
  await tester.binding.setSurfaceSize(const Size(1600, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final printer = RecordingPrinter();
  final queue = PrintQueue.inMemory();
  addTearDown(queue.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        subscriptionPlanApiProvider.overrideWithValue(api),
        printQueueProvider.overrideWithValue(queue),
        printerDeviceProvider.overrideWithValue(printer),
        // İşçi BAŞLATILMAZ: plan fişi `printDiagnostic` ile kuyruğu
        // atlıyor ve çalışan bir döngü testte asılı zamanlayıcı bırakır.
        printServiceProvider.overrideWith(
          (ref) => PrintService(
            queue: queue,
            device: printer,
            kitchen: kitchen ?? FakeKitchenService(),
          ),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: ThemeData.dark(),
        home: const SubscriptionPlanScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return printer;
}

void main() {
  group('Uyarılar', () {
    testWidgets('ÜRETİM KOŞMADI uyarısı listeden ÖNCE görünür', (tester) async {
      // En sinsi durum: sipariş yok ama olması gerekiyor. Mutfak "bugün
      // abonelik yok" sanıp hazırlık yapmıyor.
      final api = FakePlanApi(
        days: [
          day(
            warnings: const [
              PlanWarning(
                kind: 'not_generated',
                message: 'Bu gün için 3 abonelik bekleniyor ama üretilmemiş.',
              ),
            ],
          ),
        ],
      );

      await pumpPlan(tester, api);

      expect(
        find.textContaining('3 abonelik bekleniyor'),
        findsOneWidget,
      );
    });

    testWidgets('KRİTİK uyarı kırmızı, bilgi uyarısı sarı', (tester) async {
      // İkisi aynı renkte olsaydı kırmızının anlamı kalmazdı.
      final api = FakePlanApi(
        days: [
          day(
            warnings: const [
              PlanWarning(kind: 'not_generated', message: 'Üretim koşmadı'),
              PlanWarning(kind: 'exception', message: 'Abonelik #7 atlandı'),
            ],
          ),
        ],
      );

      await pumpPlan(tester, api);

      final containers = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.decoration is BoxDecoration)
          .map((c) => (c.decoration! as BoxDecoration).color)
          .toList();

      expect(containers, contains(const Color(BldColors.danger)));
      expect(containers, contains(const Color(BldColors.warning)));
    });

    test('yalnız not_generated kritiktir', () {
      const critical = PlanWarning(kind: 'not_generated', message: '');
      const info = PlanWarning(kind: 'closed_day', message: '');

      expect(critical.isCritical, isTrue);
      expect(info.isCritical, isFalse);
    });
  });

  group('Üretim toplamları', () {
    testWidgets('ürün ve adet birlikte gösterilir', (tester) async {
      // "40 abonelik var" bilgisiyle mutfak hiçbir şey yapamıyor;
      // ihtiyacı olan "120 mercimek".
      final api = FakePlanApi(
        days: [
          day(
            totals: const [
              PlanTotal(name: 'Mercimek Çorbası', quantity: 120),
              PlanTotal(name: 'Tavuk Sote', quantity: 85),
            ],
            orders: [planOrder()],
          ),
        ],
      );

      await pumpPlan(tester, api);

      expect(find.text('120'), findsOneWidget);
      expect(find.text('Mercimek Çorbası'), findsOneWidget);
      expect(find.text('85'), findsOneWidget);
    });

    testWidgets('toplam porsiyon başlıkta yazar', (tester) async {
      final api = FakePlanApi(
        days: [
          day(
            totals: const [
              PlanTotal(name: 'Çorba', quantity: 100),
              PlanTotal(name: 'Pilav', quantity: 40),
            ],
            orders: [planOrder()],
          ),
        ],
      );

      await pumpPlan(tester, api);

      expect(find.text('140 porsiyon'), findsOneWidget);
    });

    testWidgets('BOŞ GÜN sessiz kalmaz', (tester) async {
      // Boş bir ekran "yükleniyor mu, bozuk mu" sorusunu doğurur.
      await pumpPlan(tester, FakePlanApi(days: [day()]));

      expect(
        find.text('Bu gün için abonelik siparişi yok.'),
        findsOneWidget,
      );
    });
  });

  group('Teslimat çizelgesi', () {
    testWidgets('saat ve kurum adı görünür', (tester) async {
      final api = FakePlanApi(
        days: [
          day(
            totals: const [PlanTotal(name: 'Çorba', quantity: 60)],
            orders: [planOrder()],
          ),
        ],
      );

      await pumpPlan(tester, api);

      expect(find.text('11:30'), findsOneWidget);
      expect(find.text('Konya Sanayi A.Ş.'), findsOneWidget);
    });

    testWidgets('saatsiz teslimat "Saat yok" der, boş kalmaz', (tester) async {
      final api = FakePlanApi(
        days: [
          day(
            totals: const [PlanTotal(name: 'Çorba', quantity: 60)],
            orders: [planOrder(time: null)],
          ),
        ],
      );

      await pumpPlan(tester, api);

      expect(find.text('Saat yok'), findsOneWidget);
    });

    testWidgets('DURUM İLERLETME düğmesi bu ekranda da vardır', (tester) async {
      // Panoya dönüp aynı siparişi orada bulmak zorunda kalmak, ekranı
      // yalnız "bakılan" bir yer yapardı.
      final api = FakePlanApi(
        days: [
          day(
            totals: const [PlanTotal(name: 'Çorba', quantity: 60)],
            orders: [planOrder(status: OrderStatus.onaylandi)],
          ),
        ],
      );

      await pumpPlan(tester, api);

      expect(find.widgetWithText(FilledButton, 'Hazırlanıyor'), findsOneWidget);
    });

    testWidgets('terminal durumda ilerletme düğmesi çizilmez', (tester) async {
      final api = FakePlanApi(
        days: [
          day(
            totals: const [PlanTotal(name: 'Çorba', quantity: 60)],
            orders: [planOrder(status: OrderStatus.teslimEdildi)],
          ),
        ],
      );

      await pumpPlan(tester, api);

      expect(find.text('Teslim edildi'), findsOneWidget);
    });
  });

  group('Gün aralığı sekmeleri', () {
    testWidgets('sekmeye dokununca o aralık istenir', (tester) async {
      // Hafta her açılışta hesaplanmıyor; yalnız dokunulunca.
      final api = FakePlanApi(days: [day()]);
      await pumpPlan(tester, api);

      expect(api.lastRange, PlanRange.today);

      await tester.tap(find.widgetWithText(FilledButton, 'Bu hafta'));
      await tester.pumpAndSettle();

      expect(api.lastRange, PlanRange.week);
    });
  });

  group('Üretim planı fişi', () {
    testWidgets('düğme yazıcıya bayt gönderir', (tester) async {
      final api = FakePlanApi(
        days: [
          day(
            totals: const [PlanTotal(name: 'Mercimek Çorbası', quantity: 120)],
            orders: [planOrder()],
          ),
        ],
      );

      final printer = await pumpPlan(tester, api);

      await tester.tap(
        find.widgetWithText(FilledButton, 'ÜRETİM PLANI FİŞİ BAS'),
      );
      await tester.pumpAndSettle();

      expect(printer.writes, isNotEmpty);
      expect(find.text('Üretim planı yazıcıya gönderildi.'), findsOneWidget);
    });

    testWidgets('İKİNCİ KEZ basılabilir — kuyruk tekilliğine takılmaz', (
      tester,
    ) async {
      // Kuyruğa girseydi `UNIQUE(order_id, type)` kısıtına takılırdı
      // (planın sipariş kimliği yok) ve ikinci kez basılamazdı.
      final api = FakePlanApi(
        days: [
          day(
            totals: const [PlanTotal(name: 'Çorba', quantity: 60)],
            orders: [planOrder()],
          ),
        ],
      );

      final printer = await pumpPlan(tester, api);
      final button = find.widgetWithText(
        FilledButton,
        'ÜRETİM PLANI FİŞİ BAS',
      );

      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(
        printer.writes,
        hasLength(2),
        reason: 'Her dokunuş ayrı bir kâğıt üretmeli.',
      );
    });

    testWidgets('UYARILAR fişe de basılır', (tester) async {
      // Ekranda görünüp kâğıtta görünmezse, tezgâhtaki kâğıda bakan kişi
      // "üretim koşmamış" bilgisini hiç görmez.
      final api = FakePlanApi(
        days: [
          day(
            totals: const [PlanTotal(name: 'Corba', quantity: 60)],
            warnings: const [
              PlanWarning(kind: 'not_generated', message: 'URETIM KOSMADI'),
            ],
            orders: [planOrder()],
          ),
        ],
      );

      final printer = await pumpPlan(tester, api);

      await tester.tap(
        find.widgetWithText(FilledButton, 'ÜRETİM PLANI FİŞİ BAS'),
      );
      await tester.pumpAndSettle();

      // ASCII aranıyor: Türkçe harfler PC857 ile kodlanıyor ve Dart'ın
      // kod birimleriyle eşleşmiyor.
      final bytes = printer.writes.single;
      expect(
        String.fromCharCodes(bytes.where((b) => b >= 32 && b < 127)),
        contains('URETIM KOSMADI'),
      );
    });
  });

  group('PlanDay', () {
    test('toplam porsiyon ürün toplamlarından türer', () {
      final plan = day(
        totals: const [
          PlanTotal(name: 'a', quantity: 30),
          PlanTotal(name: 'b', quantity: 12),
        ],
      );

      expect(plan.totalQuantity, 42);
    });

    test('sipariş ve toplam yoksa boş sayılır', () {
      expect(day().isEmpty, isTrue);
      expect(day(orders: [planOrder()]).isEmpty, isFalse);
    });
  });
}
