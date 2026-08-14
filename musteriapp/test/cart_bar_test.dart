/// Sepete gitme çubuğu her sekmede görünüyor mu?
///
/// NEDEN VAR: çubuk önceden yalnızca menü ekranındaydı. Ürün ekleyip başka
/// bir sekmeye geçen kullanıcı sepete dönmek için önce menüye geri gelmek
/// zorundaydı ve sepetin nerede olduğu görünmüyordu. Biri çubuğu tekrar tek
/// bir ekrana taşırsa ya da kabuktan düşürürse burası düşer.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musteriapp/src/app.dart';
import 'package:musteriapp/src/features/cart/cart_controller.dart';
import 'package:musteriapp/src/providers/catalog_providers.dart';
import 'package:musteriapp/src/providers/infra_providers.dart';
import 'package:musteriapp/src/providers/session_provider.dart';
import 'package:musteriapp/src/widgets/cart_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/daily_menu_fixtures.dart';

const Location _location = Location(
  id: 1,
  name: 'Benim Lezzet Dünyam',
  slug: 'catering',
  isOpen: true,
  orderingEnabled: true,
  minOrderTotal: 25000,
  paymentMethods: [PaymentMethod.cash],
  orderCutoff: '16:00',
);

const MenuItem _item = MenuItem(
  id: 101,
  name: 'Tavuk Sote',
  price: 18500,
  currency: 'TRY',
  isAvailable: true,
);

class _FakeSession extends SessionNotifier {
  @override
  Future<Session> build() async => const Session(isSignedIn: false);
}

Future<ProviderContainer> _pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      versionGateProvider.overrideWith(
        (ref) async => const VersionGate(
          updateRequired: false,
          installedVersion: '1.0.0',
          minSupported: '1.0.0',
        ),
      ),
      sessionProvider.overrideWith(_FakeSession.new),
      locationProvider.overrideWith(
        (ref) async =>
            const LocationSnapshot(location: _location, fromCache: false),
      ),
      // Menü sekmesi artık GÜNÜN MENÜSÜNÜ çiziyor; katalog sağlayıcısını
      // sahtelemek bu ekranı hiç beslemezdi.
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
  return container;
}

void main() {
  testWidgets('sepet boşken çubuk hiç çizilmez', (tester) async {
    await _pump(tester);

    // Boş bir "sepetiniz boş" şeridi her ekranda yer kaplar, hiçbir şey
    // söylemez.
    //
    // Arama ÇUBUĞUN İÇİNE daraltıldı: ana sayfada artık günün menüsünü
    // sepete ekleyen kendi `FilledButton`'ı var ve genel bir arama onu
    // yakalayıp testi sepet çubuğuyla ilgisiz bir sebeple düşürüyordu.
    expect(find.byType(CartBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CartBar),
        matching: find.byType(FilledButton),
      ),
      findsNothing,
    );
  });

  testWidgets('sepet doluyken çubuk sekme değişse de kalır', (tester) async {
    final container = await _pump(tester);

    container
        .read(cartProvider.notifier)
        .add(
          item: _item,
          locationId: _location.id,
          serviceDate: fixedToday,
          quantity: 2,
        );
    await tester.pumpAndSettle();

    // Ana sayfada görünüyor.
    expect(find.text('Sepet · 370,00 ₺'), findsOneWidget);

    // Adet rozeti: iki porsiyon eklendi.
    expect(find.text('2'), findsOneWidget);

    // Menü sekmesine geç — çubuk KAYBOLMAMALI.
    await tester.tap(find.text('Menü').last);
    await tester.pumpAndSettle();
    expect(find.text('Sepet · 370,00 ₺'), findsOneWidget);

    // Ana sayfaya dön — asıl şikâyet buydu: menüden çıkınca sepet ortadan
    // kayboluyordu.
    //
    // Hesabım sekmesi bilerek sınanmıyor: o ekran `notificationsProvider`
    // istiyor ve burada sahtelemek, testin sorduğu soruya (çubuk sekme
    // değişiminde kalıyor mu) hiçbir şey katmadan kurgunun yarısını
    // bildirim altyapısına ayırırdı.
    await tester.tap(find.text('Ana Sayfa').last);
    await tester.pumpAndSettle();
    expect(find.text('Sepet · 370,00 ₺'), findsOneWidget);
  });
}
