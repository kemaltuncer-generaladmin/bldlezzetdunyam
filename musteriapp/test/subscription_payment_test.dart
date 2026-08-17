/// Abonelik dönem ödemesi — durum makinesi ve her hata yolu.
///
/// Ağ yoktur: `apiProvider` sahte bir istemciyle değiştirilir. Sınanan şey
/// HTTP katmanı değil, ekranın sunucunun kararına (`next_action`) nasıl
/// uyduğu.
///
/// Buradaki dört kural sessizce bozulabilecek türden:
///  * `three_ds` dalı KAPALI olduğunu söylemeli, sessizce beklememeli;
///  * yoklama SINIRLI olmalı — sipariş takibinin sonsuz döngüsü buraya
///    kopyalanırsa test yalnızca daha yavaş geçer, hata vermez;
///  * yanlış SMS kodu kullanıcıyı akışın başına atmamalı;
///  * `next_action = unknown` "bitti" sayılmamalı.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musteriapp/src/app.dart';
import 'package:musteriapp/src/features/subscriptions/subscription_payment_controller.dart';
import 'package:musteriapp/src/features/subscriptions/subscription_payment_screen.dart';
import 'package:musteriapp/src/l10n/app_localizations.dart';
import 'package:musteriapp/src/providers/catalog_providers.dart';
import 'package:musteriapp/src/providers/infra_providers.dart';
import 'package:musteriapp/src/providers/session_provider.dart';
import 'package:musteriapp/src/router/app_router.dart';
import 'package:musteriapp/src/theme/bld_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/daily_menu_fixtures.dart';

const int _subscriptionId = 7;

/// Bu testin dokunmadığı servisleri tek tek yazmamak için `noSuchMethod`.
///
/// Beklenmeyen bir uç çağrılırsa test `NoSuchMethodError` ile düşer ve hangi
/// çağrının sızdığını söyler — sessizce `null` dönen bir sahte, testi yalancı
/// biçimde yeşil tutardı.
class _FakeApi implements BldApi {
  _FakeApi(this.subscriptions);

  @override
  final SubscriptionService subscriptions;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSubscriptions implements SubscriptionService {
  _FakeSubscriptions({
    required this.subscription,
    this.startResult,
    this.startError,
    this.confirmResult,
    this.confirmError,
    this.confirmFailures = 0,
    this.pollResults = const <SubscriptionPayment>[],
  });

  final Subscription subscription;
  final SubscriptionPayment? startResult;
  final ApiException? startError;
  final SubscriptionPayment? confirmResult;
  final ApiException? confirmError;

  /// İlk kaç `confirm` çağrısı [confirmError] ile düşsün?
  final int confirmFailures;

  /// `GET .../payments/{id}` yanıtları, sırayla; liste bitince sonuncusu
  /// tekrarlanır.
  final List<SubscriptionPayment> pollResults;

  int startCalls = 0;
  int confirmCalls = 0;
  int pollCalls = 0;
  final List<String?> codes = <String?>[];

  @override
  Future<Subscription> get(int id) async => subscription;

  @override
  Future<SubscriptionPayment> startPayment(int id, {String? period}) async {
    startCalls++;
    final error = startError;
    if (error != null) throw error;
    return startResult!;
  }

  @override
  Future<SubscriptionPayment> confirmPayment(
    int id,
    int paymentId, {
    String? otp,
  }) async {
    confirmCalls++;
    codes.add(otp);
    if (confirmCalls <= confirmFailures) throw confirmError!;
    return confirmResult!;
  }

  @override
  Future<SubscriptionPayment> payment(int id, int paymentId) async {
    final index = pollCalls;
    pollCalls++;
    if (pollResults.isEmpty) return startResult!;
    return pollResults[index < pollResults.length
        ? index
        : pollResults.length - 1];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fiyatı girilmiş, ilk dönemi ödenmemiş abonelik.
Subscription _subscription({
  SubscriptionPaymentSummary? payment = const SubscriptionPaymentSummary(
    period: '2026-08',
    amount: 450000,
    currency: 'TRY',
    status: PaymentStatus.pending,
    dueDate: '2026-08-05',
  ),
  String status = 'awaiting_payment',
}) => Subscription(
  id: _subscriptionId,
  status: status,
  locationId: 1,
  deliveryType: DeliveryType.delivery,
  startDate: DateTime.utc(2026, 8, 1),
  serviceDays: const [1, 2, 3, 4, 5],
  defaultQuantity: 20,
  agreedUnitPrice: 22500,
  paymentMode: 'prepaid_monthly',
  menuMode: 'daily_menu',
  payment: payment,
  createdAt: DateTime.utc(2026, 7, 20),
);

SubscriptionPayment _payment({
  PaymentStatus status = PaymentStatus.pending,
  PaymentNextAction nextAction = PaymentNextAction.none,
  String? failureReason,
  DateTime? paidAt,
}) => SubscriptionPayment(
  paymentId: 991,
  subscriptionId: _subscriptionId,
  period: '2026-08',
  amount: 450000,
  currency: 'TRY',
  status: status,
  nextAction: nextAction,
  createdAt: DateTime.utc(2026, 8, 1, 6),
  failureReason: failureReason,
  paidAt: paidAt,
);

/// Ekranı tek başına çizer.
///
/// `pumpAndSettle` KULLANILMIYOR: bekleme ekranlarında sonsuz dönen bir
/// gösterge var ve `pumpAndSettle` orada zaman aşımına düşer. Kare kare
/// ilerlemek testin ne beklediğini de görünür kılıyor.
Future<void> _pumpScreen(WidgetTester tester, _FakeSubscriptions service) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [apiProvider.overrideWithValue(_FakeApi(service))],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: BldTheme.light(),
        home: const SubscriptionPaymentScreen(id: _subscriptionId),
      ),
    ),
  );
  // Abonelik + (varsa) ödeme kaydı okunana kadar.
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('ek adım yoksa ödeme biter ve makbuz çizilir', (tester) async {
    final service = _FakeSubscriptions(
      subscription: _subscription(),
      startResult: _payment(
        status: PaymentStatus.paid,
        paidAt: DateTime.utc(2026, 8, 1, 6, 32),
      ),
    );
    await _pumpScreen(tester, service);

    // Dönem başlığı ve tutar sunucudan; istemci çarpım yapmıyor.
    expect(find.text('Ağustos 2026'), findsOneWidget);
    expect(find.text('4.500,00 ₺'), findsWidgets);

    await _tap(tester, 'Ödemeyi başlat');

    expect(service.startCalls, 1);
    expect(find.text('Ödeme alındı'), findsOneWidget);
    expect(find.text('Makbuz'), findsOneWidget);
    expect(find.text('991'), findsOneWidget);
    expect(find.text('1 Ağustos 2026, 09:32'), findsOneWidget);
  });

  testWidgets('yanlış SMS kodu kullanıcıyı kod ekranında bırakır', (
    tester,
  ) async {
    final service = _FakeSubscriptions(
      subscription: _subscription(),
      startResult: _payment(nextAction: PaymentNextAction.otp),
      confirmFailures: 1,
      confirmError: const ApiException(
        code: ApiErrorCode.validationFailed,
        message: 'Kod hatalı. 2 deneme hakkınız kaldı.',
        statusCode: 422,
      ),
      confirmResult: _payment(
        status: PaymentStatus.paid,
        paidAt: DateTime.utc(2026, 8, 1, 6, 40),
      ),
    );
    await _pumpScreen(tester, service);

    await _tap(tester, 'Ödemeyi başlat');
    expect(find.text('SMS kodunu girin'), findsOneWidget);

    // Kısa kod sunucuya HİÇ gitmez.
    await tester.enterText(find.byType(TextFormField), '12');
    await _tap(tester, 'Onayla');
    expect(find.text('Kod 4 ile 8 hane arasında olmalı.'), findsOneWidget);
    expect(service.confirmCalls, 0);

    // Yanlış kod: sunucunun gerekçesi görünür, kod ekranı KAPANMAZ.
    await tester.enterText(find.byType(TextFormField), '482913');
    await _tap(tester, 'Onayla');
    expect(service.confirmCalls, 1);
    expect(service.codes, ['482913']);
    expect(find.text('Kod hatalı. 2 deneme hakkınız kaldı.'), findsOneWidget);
    expect(find.text('SMS kodunu girin'), findsOneWidget);
    expect(find.text('Ödeme alındı'), findsNothing);

    // İkinci deneme tutar.
    await _tap(tester, 'Onayla');
    expect(service.confirmCalls, 2);
    expect(find.text('Ödeme alındı'), findsOneWidget);
  });

  testWidgets('three_ds dalı kapalı gösterilir ve yoklama SINIRLI kalır', (
    tester,
  ) async {
    final pending = _payment(nextAction: PaymentNextAction.threeDs);
    final service = _FakeSubscriptions(
      subscription: _subscription(),
      startResult: pending,
      // Sağlayıcı hiç sonuçlandırmıyor: bütçe dolmalı ve ekran susmalı.
      pollResults: [pending],
    );
    await _pumpScreen(tester, service);

    await _tap(tester, 'Ödemeyi başlat');

    // Dal ilan edilmiş ama gövdesiz; kullanıcı bunu AÇIKÇA görüyor.
    expect(find.text('3-D Secure bu sürümde açık değil'), findsOneWidget);
    expect(find.text('Sonuç izleniyor…'), findsOneWidget);
    expect(service.pollCalls, 0);

    // 2 sn × 5.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
    }
    expect(service.pollCalls, 5);

    // 5 sn × 12.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
    }
    expect(service.pollCalls, kSubscriptionPaymentPollSchedule.length);
    expect(
      find.text('Sonuç bu sürede gelmedi. Ekranı aşağı çekerek yenileyebilirsiniz.'),
      findsOneWidget,
    );

    // Bütçe dolduktan sonra TEK bir istek daha çıkmamalı.
    await tester.pump(const Duration(minutes: 5));
    await tester.pump();
    expect(service.pollCalls, kSubscriptionPaymentPollSchedule.length);
  });

  testWidgets('bilinmeyen adım "bitti" sayılmaz', (tester) async {
    final service = _FakeSubscriptions(
      subscription: _subscription(),
      startResult: _payment(nextAction: PaymentNextAction.unknown),
    );
    await _pumpScreen(tester, service);

    await _tap(tester, 'Ödemeyi başlat');

    expect(
      find.text('Bu ödeme adımı için uygulamayı güncellemeniz gerekiyor.'),
      findsOneWidget,
    );
    expect(find.text('Ödeme alındı'), findsNothing);
  });

  testWidgets('sağlayıcı reddederse gerekçesi gösterilir', (tester) async {
    final service = _FakeSubscriptions(
      subscription: _subscription(),
      startResult: _payment(failureReason: 'Kart limiti yetersiz.'),
    );
    await _pumpScreen(tester, service);

    await _tap(tester, 'Ödemeyi başlat');

    expect(find.text('Kart limiti yetersiz.'), findsOneWidget);
    expect(find.text('Ödemeyi yeniden dene'), findsOneWidget);
  });

  testWidgets('sunucu ödemeyi reddederse mesajı gösterilir', (tester) async {
    final service = _FakeSubscriptions(
      subscription: _subscription(),
      startError: const ApiException(
        code: ApiErrorCode.validationFailed,
        message: 'Bu dönem zaten ödendi.',
        statusCode: 422,
      ),
    );
    await _pumpScreen(tester, service);

    await _tap(tester, 'Ödemeyi başlat');

    // Sunucunun bağlama özgü açıklaması, yerel genel metinden daha faydalı.
    expect(find.text('Bu dönem zaten ödendi.'), findsOneWidget);
    // Ödeme kaydı yok; "durumu yenile" düğmesi de olmamalı.
    expect(find.text('Durumu yenile'), findsNothing);
  });

  testWidgets('fiyatlanmamış abonelikte ödeme düğmesi çizilmez', (
    tester,
  ) async {
    final service = _FakeSubscriptions(
      subscription: _subscription(payment: null, status: 'pending'),
    );
    await _pumpScreen(tester, service);

    expect(find.text('Ödemeyi başlat'), findsNothing);
    expect(
      find.text(
        'Bu abonelik henüz ödemeye hazır değil. '
        'Fiyat girildikten sonra dönem tutarı burada görünecek.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('yarım kalan kod akışı ekran yeniden açıldığında sürer', (
    tester,
  ) async {
    // Özet ödemenin BAŞLADIĞINI söylüyor; sıradaki adımı yalnız ödeme kaydı
    // biliyor ve ekran onu okuyup kod formunu geri getiriyor.
    final service = _FakeSubscriptions(
      subscription: _subscription(
        payment: const SubscriptionPaymentSummary(
          period: '2026-08',
          amount: 450000,
          currency: 'TRY',
          status: PaymentStatus.pending,
          paymentId: 991,
        ),
      ),
      startResult: _payment(nextAction: PaymentNextAction.otp),
    );
    await _pumpScreen(tester, service);

    expect(service.pollCalls, 1);
    expect(service.startCalls, 0);
    expect(find.text('SMS kodunu girin'), findsOneWidget);
  });

  testWidgets('/subscriptions/:id/payment ödeme ekranını açar', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiProvider.overrideWithValue(
          _FakeApi(
            _FakeSubscriptions(
              subscription: _subscription(),
              startResult: _payment(status: PaymentStatus.paid),
            ),
          ),
        ),
        versionGateProvider.overrideWith(
          (ref) async => const VersionGate(
            updateRequired: false,
            installedVersion: '1.0.0',
            minSupported: '1.0.0',
          ),
        ),
        sessionProvider.overrideWith(_SignedInSession.new),
        locationProvider.overrideWith(
          (ref) async => const LocationSnapshot(
            location: Location(
              id: 1,
              name: 'Benim Lezzet Dünyam',
              slug: 'catering',
              isOpen: true,
              orderingEnabled: true,
              minOrderTotal: 25000,
              paymentMethods: [PaymentMethod.cash],
              orderCutoff: '16:00',
            ),
            fromCache: false,
          ),
        ),
        ...dailyMenuOverrides(),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BldCustomerApp(),
      ),
    );
    await tester.pumpAndSettle();

    container
        .read(routerProvider)
        .go(Routes.subscriptionPayment(_subscriptionId));
    await tester.pumpAndSettle();

    // Ödeme yolu `/subscriptions/:id`'den ÖNCE kayıtlı; detay ekranı DEĞİL,
    // ödeme ekranı açılmalı.
    expect(find.text('Abonelik ödemesi'), findsOneWidget);
    expect(find.text('Ödemeyi başlat'), findsOneWidget);
  });
}

class _SignedInSession extends SessionNotifier {
  @override
  Future<Session> build() async => const Session(isSignedIn: true);
}
