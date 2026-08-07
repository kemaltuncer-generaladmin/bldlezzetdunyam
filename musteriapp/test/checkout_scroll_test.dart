/// Ödeme ekranı telefon yüksekliğinde kaydırılabiliyor mu?
///
/// NEDEN VAR: ödeme formu uzun — teslimat türü, adres, harita, teslim zamanı,
/// ödeme yöntemi, sipariş notu ve özet alt alta. Telefonda hepsi aynı anda
/// sığmıyor. Kaydırma bozulursa kullanıcı formun altına ULAŞAMAZ ve sipariş
/// veremez; ekran çalışıyor gibi göründüğü için de hata mesajı çıkmaz.
///
/// Bu testin sorduğu tek şey: en alttaki alan kaydırarak görünür oluyor mu?
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
import 'package:musteriapp/src/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

const MenuItem _item = MenuItem(
  id: 101,
  name: 'Tavuk Sote',
  price: 18500,
  currency: 'TRY',
  isAvailable: true,
);

const MenuCategory _category = MenuCategory(
  id: 10,
  name: 'Ana Yemekler',
  sort: 1,
  items: [_item],
);

class _FakeSession extends SessionNotifier {
  _FakeSession(this.session);

  final Session session;

  @override
  Future<Session> build() async => session;
}

void main() {
  testWidgets('ödeme formu telefon yüksekliğinde sonuna kadar kaydırılır', (
    tester,
  ) async {
    // iPhone 13 mantıksal ölçüsü. Ödeme formu bu yüksekliğe sığmıyor —
    // testin anlamlı olması için sığmaMAması gerekiyor.
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

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
        sessionProvider.overrideWith(
          () => _FakeSession(
            const Session(isSignedIn: true),
          ),
        ),
        locationProvider.overrideWith(
          (ref) async =>
              const LocationSnapshot(location: _location, fromCache: false),
        ),
        menuProvider(_location.id).overrideWith(
          (ref) async =>
              const MenuSnapshot(categories: [_category], fromCache: false),
        ),
      ],
    );
    addTearDown(container.dispose);

    // Sepet dolu olmalı: boş sepette ödeme ekranı formu hiç çizmiyor.
    container
        .read(cartProvider.notifier)
        .add(item: _item, locationId: _location.id, quantity: 2);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BldCustomerApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(routerProvider).go(Routes.checkout);
    await tester.pumpAndSettle();

    // Formun en üstü görünüyor.
    expect(find.text('Teslimat tipi'), findsOneWidget);

    // Doğrudan asıl soru: kaydırma konumu ilerliyor mu?
    //
    // "Şu alan görünür oldu mu" diye sormuyoruz çünkü `ListView` TEMBEL —
    // yalnızca ekrandakileri kurar, dolayısıyla `.last` formun sonunu değil
    // çizilmiş son öğeyi verir ve test kendini kandırır.
    final liste = find.byType(Scrollable).first;
    final konum = tester.state<ScrollableState>(liste).position;

    expect(konum.pixels, 0, reason: 'Form en üstte açılmalı.');
    expect(
      konum.maxScrollExtent,
      greaterThan(0),
      reason: 'Form ekrana sığıyorsa bu test kaydırmayı sınamıyor demektir.',
    );

    await tester.drag(liste, const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(
      konum.pixels,
      greaterThan(0),
      reason: 'Aşağı kaydırılamıyorsa kullanıcı formun altına inemez.',
    );

    // Sonuna kadar inilebiliyor mu — sipariş notu formun son alanı.
    await tester.fling(liste, const Offset(0, -3000), 3000);
    await tester.pumpAndSettle();

    expect(konum.pixels, konum.maxScrollExtent);
    expect(find.text('Sipariş notu (isteğe bağlı)'), findsWidgets);
  });
}
