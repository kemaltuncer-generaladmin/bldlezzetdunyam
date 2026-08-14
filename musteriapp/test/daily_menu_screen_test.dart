/// Günün menüsü ekranı — gün şeridi, paket kartı ve sepete ekleme (B-19).
///
/// NEDEN VAR: satış artık YALNIZCA bu ekrandan yapılıyor. Ekranın üç kararı
/// var ve üçü de sessizce bozulabilir: doğru günün menüsünü göstermek,
/// sipariş edilemeyen günde sepete ekletmemek, gün değiştiğinde sepetin
/// boşaldığını SÖYLEMEK. Üçü de hata mesajı üretmeden yanlış çalışabilir —
/// müşteri yanlış güne sipariş verir ve bunu ancak yemek gelmeyince anlar.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musteriapp/src/app.dart';
import 'package:musteriapp/src/features/cart/cart_controller.dart';
import 'package:musteriapp/src/features/menu/menu_screen.dart';
import 'package:musteriapp/src/providers/catalog_providers.dart';
import 'package:musteriapp/src/providers/infra_providers.dart';
import 'package:musteriapp/src/providers/session_provider.dart';
import 'package:musteriapp/src/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/daily_menu_fixtures.dart';

const Location _location = Location(
  id: 1,
  name: 'Benim Lezzet Dünyam',
  slug: 'catering',
  isOpen: true,
  orderingEnabled: true,
  minOrderTotal: 0,
  paymentMethods: [PaymentMethod.cash],
  dailyMenuEnabled: true,
);

class _FakeSession extends SessionNotifier {
  @override
  Future<Session> build() async => const Session(isSignedIn: false);
}

/// Menü sekmesini telefon boyutunda açar.
///
/// Yüzey boyutu SABİTLENİYOR: varsayılan 800×600 test yüzeyi telefon değil,
/// tablet oranında. Paket kartının 16:9 görseli o genişlikte 414 px'e
/// çıkıyor ve "sepete ekle" düğmesini ekran dışına itiyordu — testin
/// sorduğu şeyle ilgisi olmayan bir başarısızlık.
Future<ProviderContainer> _openMenu(
  WidgetTester tester, {
  DailyMenu? today,
  DailyMenu? tomorrow,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

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
      ...dailyMenuOverrides(today: today, tomorrow: tomorrow),
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

  container.read(routerProvider).go(Routes.menu);
  await tester.pumpAndSettle();
  return container;
}

/// "Menüyü sepete ekle" düğmesi — YALNIZ menü ekranındaki.
///
/// Kapsam daraltması şart: ana sayfada da bugünün menüsünü sepete ekleyen
/// aynı metinli bir düğme var ve o daima BUGÜNE ekliyor. Genel bir arama,
/// gün şeridinden yarına geçildiğinde sessizce ana sayfanın düğmesini
/// bulup testi yanlış güne ekleterek geçiriyordu.
final Finder _addPackageButton = find.descendant(
  of: find.byType(MenuScreen),
  matching: find.widgetWithText(FilledButton, 'Menüyü sepete ekle'),
);

void main() {
  testWidgets('paket kartı fiyatı ve içindekileri gösterir', (tester) async {
    await _openMenu(tester);

    Finder inMenu(Finder finder) =>
        find.descendant(of: find.byType(MenuScreen), matching: finder);

    expect(inMenu(find.text('Ev Yemeği Menüsü')), findsWidgets);
    expect(inMenu(find.text('Günün Menüsü')), findsWidgets);
    expect(inMenu(find.text('180,00 ₺')), findsOneWidget);

    // İçindekiler FİYATSIZ listelenir: paketin parası üst satırda.
    expect(inMenu(find.text('Mercimek Çorbası')), findsWidgets);
    expect(inMenu(find.text('Etli Nohut')), findsWidgets);

    // Kalemlerin toplamı 200,00 ₺; paket 180,00 ₺ → 20,00 ₺ avantaj.
    expect(inMenu(find.text('20,00 ₺ avantajlı')), findsOneWidget);
  });

  testWidgets('menü sepete PAKET olarak girer', (tester) async {
    final container = await _openMenu(tester);

    await tester.ensureVisible(_addPackageButton);
    await tester.tap(_addPackageButton);
    await tester.pumpAndSettle();

    final cart = container.read(cartProvider);
    expect(cart.lineCount, 1);
    // Siparişe giden kimlik PAKETİN kimliği; içindekileri sunucu açar.
    expect(cart.lines.single.item.id, 900);
    expect(cart.lines.single.packageComponents, hasLength(2));
    expect(cart.serviceDate, fixedToday);
  });

  testWidgets('sipariş edilemeyen günde düğme kapalı ve SEBEBİ yazılı', (
    tester,
  ) async {
    await _openMenu(
      tester,
      today: sampleDailyMenu(
        isOrderable: false,
        unavailableReason: DailyMenuUnavailableReason.cutoffPassed,
      ),
    );

    // Devre dışı düğme HER ZAMAN bir sebep metniyle birlikte.
    expect(find.text('Bugünün sipariş saati doldu.'), findsWidgets);

    expect(tester.widget<FilledButton>(_addPackageButton).onPressed, isNull);
  });

  testWidgets('gün şeridinden yarına geçilince o günün menüsü gelir', (
    tester,
  ) async {
    await _openMenu(
      tester,
      // Paketsiz kurgu: kalemler paket kartının 16:9 görselinin altına
      // itilmesin, testin sorduğu şey kaydırma değil GÜN DEĞİŞİMİ.
      tomorrow: sampleDailyMenu(
        date: fixedTomorrow,
        withPackage: false,
        items: const [
          MenuItem(
            id: 201,
            name: 'Kuru Fasulye',
            price: 15000,
            currency: 'TRY',
            isAvailable: true,
          ),
        ],
      ),
    );

    expect(find.text('Kuru Fasulye'), findsNothing);

    await tester.tap(find.text('Yarın'));
    await tester.pumpAndSettle();

    expect(find.text('21 Ağustos 2026 · Cuma'), findsOneWidget);
    expect(find.text('Kuru Fasulye'), findsOneWidget);
  });

  testWidgets('başka güne ekleme sepeti sıfırlar ve KULLANICIYA söyler', (
    tester,
  ) async {
    final container = await _openMenu(tester);

    // Önce bugüne ekle.
    await tester.ensureVisible(_addPackageButton);
    await tester.tap(_addPackageButton);
    await tester.pumpAndSettle();
    expect(container.read(cartProvider).serviceDate, fixedToday);

    // Bildirim şeridinin kapanması BEKLENİYOR: ekranın altında duruyor ve
    // ikinci dokunuşu yutuyor. (Bunun kullanıcı için karşılığı yok — parmak
    // şeridin üstüne değil düğmeye iner; test yalnız aynı noktaya iki kez
    // dokunduğu için çakışıyor.)
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Sonra yarına geç ve yarınki menüyü ekle.
    await tester.tap(find.text('Yarın'));
    await tester.pumpAndSettle();
    expect(find.text('21 Ağustos 2026 · Cuma'), findsOneWidget);
    await tester.ensureVisible(_addPackageButton);
    await tester.tap(_addPackageButton);
    await tester.pumpAndSettle();

    final cart = container.read(cartProvider);
    expect(cart.serviceDate, fixedTomorrow);
    expect(cart.lineCount, 1, reason: 'Önceki günün sepeti boşalmalı.');

    // Sessizce boşaltmak yasak: müşteri kaybettiğini bilmeli.
    expect(
      find.textContaining('21 Ağustos 2026 gününe taşındı'),
      findsOneWidget,
    );
  });

  testWidgets('menüsü olmayan gün boş durumla anlatılır', (tester) async {
    await _openMenu(
      tester,
      today: const DailyMenu(
        date: fixedToday,
        currency: 'TRY',
        closed: false,
        isOrderable: false,
        unavailableReason: DailyMenuUnavailableReason.notPublished,
      ),
    );

    expect(find.text('Bu güne menü girilmedi'), findsWidgets);
    expect(_addPackageButton, findsNothing);
  });
}
