/// Açılıştaki iki kapının davranışı: zorunlu güncelleme ve oturum.
///
/// Ağ yoktur — sağlayıcılar override edilir. Amaç `routerProvider`'ın
/// `redirect` kararlarını doğrulamak, HTTP katmanını değil.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musteriapp/src/app.dart';
import 'package:musteriapp/src/providers/catalog_providers.dart';
import 'package:musteriapp/src/providers/infra_providers.dart';
import 'package:musteriapp/src/providers/session_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/daily_menu_fixtures.dart';

const Location _location = Location(
  id: 1,
  name: 'Benim Lezzet Dünyam',
  slug: 'catering',
  isOpen: true,
  orderingEnabled: true,
  minOrderTotal: 25000,
  paymentMethods: [PaymentMethod.cash, PaymentMethod.account],
  orderCutoff: '16:00',
);

/// Günün menüsündeki kalemler: biri satışta, biri tükenmiş.
///
/// PAKET YOK: bu testin sorduğu şey menünün AÇILIP kalemleri listeleyip
/// listelemediği. Paket kartı 16:9 görseliyle test yüzeyinin (800×600)
/// yarısını kaplıyor ve kalemleri kaydırma gerektiren bir yere itiyor —
/// testin cevabını değiştirmeden zorluğunu artırırdı.
final DailyMenu _menu = sampleDailyMenu(
  withPackage: false,
  items: const [
    MenuItem(
      id: 101,
      name: 'Tavuk Sote',
      price: 18500,
      currency: 'TRY',
      isAvailable: true,
    ),
    MenuItem(
      id: 102,
      name: 'Izgara Köfte',
      price: 21000,
      currency: 'TRY',
      isAvailable: false,
    ),
  ],
);

class _FakeSession extends SessionNotifier {
  _FakeSession(this.session);

  final Session session;

  @override
  Future<Session> build() async => session;
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required VersionGate gate,
  Session session = Session.signedOut,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        versionGateProvider.overrideWith((ref) async => gate),
        sessionProvider.overrideWith(() => _FakeSession(session)),
        locationProvider.overrideWith(
          (ref) async =>
              const LocationSnapshot(location: _location, fromCache: false),
        ),
        ...dailyMenuOverrides(today: _menu),
      ],
      child: const BldCustomerApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sürüm desteklenmiyorsa engelleyici ekran açılır', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      gate: const VersionGate(
        updateRequired: true,
        installedVersion: '1.0.0',
        minSupported: '2.0.0',
      ),
    );

    expect(find.text('Güncelleme gerekli'), findsOneWidget);
    expect(find.text('Yüklü sürüm: 1.0.0'), findsOneWidget);
    expect(find.text('En düşük desteklenen sürüm: 2.0.0'), findsOneWidget);

    // Menü hiçbir biçimde erişilebilir olmamalı.
    expect(find.text('Tavuk Sote'), findsNothing);
  });

  testWidgets('sürüm uygunsa menü açılır ve ürünler listelenir', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      gate: const VersionGate(
        updateRequired: false,
        installedVersion: '1.0.0',
        minSupported: '1.0.0',
      ),
    );

    // Uygulama ANA SAYFA ile açılıyor; menü ikinci sekmede.
    expect(find.text('Bugün ne yesek?'), findsOneWidget);

    await _openMenuTab(tester);

    expect(find.text('Ev Yemeği Menüsü'), findsOneWidget);
    expect(find.text('Tavuk Sote'), findsOneWidget);
    expect(find.text('185,00 ₺'), findsOneWidget);

    // Satışta olmayan ürün listede kalır ve etiketlenir.
    expect(find.text('Izgara Köfte'), findsOneWidget);
    expect(find.text('Satışta değil'), findsOneWidget);

    expect(find.text('Güncelleme gerekli'), findsNothing);
  });

  testWidgets('sürüm denetlenemediyse kullanıcı engellenmez', (tester) async {
    await _pumpApp(tester, gate: const VersionGate.undetermined());

    expect(find.text('Güncelleme gerekli'), findsNothing);

    // Sürüm belirlenemese bile kullanıcı menüye ulaşabilmeli — sınanan şey
    // bu, hangi ekranın önce açıldığı değil.
    await _openMenuTab(tester);
    expect(find.text('Tavuk Sote'), findsOneWidget);
  });
}

/// Alt çubuktan menü sekmesine geçer.
///
/// Sekme ADIYLA bulunuyor, sırasıyla değil: yeni bir sekme eklendiğinde
/// indeks kayar ve testler sessizce başka bir ekranı doğrulamaya başlardı.
Future<void> _openMenuTab(WidgetTester tester) async {
  await tester.tap(find.text('Menü').last);
  await tester.pumpAndSettle();
}
