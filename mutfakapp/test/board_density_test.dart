/// Pano yoğunluğu: sütun genişleyince kartlar yan yana dizilir.
///
/// NEDEN VAR: yoğun saatte YENİ sütununda sipariş birikirken diğer sütunlar
/// boşalıyor. Eşit üçte bir düzende aşçı sekiz siparişin yalnızca üçünü
/// görüyor, kalanı görmek için kaydırıyordu — oysa ekranın üçte ikisi boştu.
/// Bu testler o davranışın sessizce geri gelmesini engelliyor: birinin
/// `Expanded(flex:)` satırını sadeleştirmesi ya da satır gruplamasını tekrar
/// düz listeye çevirmesi yeterli.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_kitchen_service.dart';
import 'kds_screen_test.dart' show pumpKds;

/// Kartın ekrandaki sol kenarı — aynı satırdakiler aynı yüksekliktedir.
double _ust(WidgetTester tester, int orderId) =>
    tester.getTopLeft(_kart(orderId)).dy;

double _sol(WidgetTester tester, int orderId) =>
    tester.getTopLeft(_kart(orderId)).dx;

double _genislik(WidgetTester tester, int orderId) =>
    tester.getSize(_kart(orderId)).width;

Finder _kart(int orderId) =>
    find.byKey(ValueKey<int>(orderId), skipOffstage: false);

List<KitchenOrder> _yeniSiparisler(int adet, DateTime now) => [
  for (var i = 0; i < adet; i++)
    makeOrder(
      id: 300 + i,
      createdAt: now.subtract(Duration(minutes: 2 + i)),
      items: const [KitchenOrderItem(name: 'Tavuk Sote', quantity: 4)],
    ),
];

void main() {
  testWidgets('komşu sütunlar boşken kartlar yan yana dizilir', (tester) async {
    final now = DateTime.now().toUtc();

    // YENİ dolu, diğer ikisi boş: sütun genişliyor.
    await pumpKds(tester, orders: _yeniSiparisler(4, now));
    await tester.pump(const Duration(milliseconds: 100));

    // Sıralamaya bağlanmıyoruz — pano en eski siparişi öne alıyor ve bu kural
    // burada sınanan şey değil. Sorulan tek şey: aynı yükseklikte iki kart
    // yan yana duruyor mu?
    final konumlar = [for (var i = 0; i < 4; i++) tester.getTopLeft(_kart(300 + i))];
    final ustler = konumlar.map((k) => k.dy).toSet();

    // Dört kart iki satıra dağılmalı; tek sıra düzende dört ayrı yükseklik olurdu.
    expect(ustler.length, 2);

    // Aynı satırdaki iki kartın sol kenarları farklı.
    for (final ust in ustler) {
      final satir = konumlar.where((k) => k.dy == ust).toList();
      expect(satir.length, 2);
      expect(satir[0].dx, isNot(satir[1].dx));
    }
  });

  testWidgets('pano dengeliyken kartlar tek sıra kalır', (tester) async {
    final now = DateTime.now().toUtc();

    await pumpKds(
      tester,
      orders: [
        ..._yeniSiparisler(2, now),
        makeOrder(id: 500, status: OrderStatus.hazirlaniyor, createdAt: now),
        makeOrder(id: 600, status: OrderStatus.hazir, createdAt: now),
      ],
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Üç sütun da doluyken hiçbiri iki kart sığdıracak kadar geniş değil;
    // YENİ'deki iki kart alt alta durmalı (aynı sol kenar, farklı yükseklik).
    expect(_sol(tester, 300), _sol(tester, 301));
    expect(_ust(tester, 300), isNot(_ust(tester, 301)));
  });

  // İki senaryo AYRI testlerde: `pumpKds` aynı test içinde iki kez
  // çağrılamıyor (aynı `GlobalObjectKey`'ler iki ağaçta birden yaşıyor).
  testWidgets('sütunda tek sipariş varsa kart tam genişlikte durur', (
    tester,
  ) async {
    await pumpKds(tester, orders: _yeniSiparisler(1, DateTime.now().toUtc()));
    await tester.pump(const Duration(milliseconds: 100));

    // Komşular boş olduğu için sütun ~795 px; tek kart yarım kalıp yanında
    // boşluk bırakmamalı.
    expect(_genislik(tester, 300), greaterThan(600));
  });

  testWidgets('ikinci sipariş gelince kartlar yarı genişliğe geçer', (
    tester,
  ) async {
    await pumpKds(tester, orders: _yeniSiparisler(2, DateTime.now().toUtc()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(_genislik(tester, 300), lessThan(600));
  });

  testWidgets('yan yana dizilen kartlar okunur genişlikte kalır', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();

    await pumpKds(tester, orders: _yeniSiparisler(6, now));
    await tester.pump(const Duration(milliseconds: 100));

    // Eşik `OrderColumn._minCardWidth`; altına inerse ürün adı ve düğme aynı
    // satıra sığmayıp kart iki kata çıkar ve kazanılan yer geri verilir.
    expect(_genislik(tester, 300), greaterThanOrEqualTo(360));
  });

  testWidgets('kart sayısı arttıkça ekranda daha çoğu görünür', (tester) async {
    final now = DateTime.now().toUtc();

    await pumpKds(tester, orders: _yeniSiparisler(8, now));
    await tester.pump(const Duration(milliseconds: 100));

    // `pumpKds` yüzeyi 1920×1080'e sabitliyor (mutfak monitörü). `tester.view`
    // bu değeri yansıtmıyor, bu yüzden yükseklik doğrudan yazılı.
    const ekranYuksekligi = 1080.0;

    final gorunen = [
      for (var i = 0; i < 8; i++)
        if (_kart(300 + i).evaluate().isNotEmpty &&
            _ust(tester, 300 + i) < ekranYuksekligi)
          300 + i,
    ];

    // Tek sıra düzende üç kart görünüyordu. Dört, iki sıraya geçildiğinin
    // kanıtı; eşiği "altıya çıksın" diye zorlamak kart yüksekliğine bağımlı
    // kırılgan bir test üretirdi.
    expect(gorunen.length, greaterThan(3));
  });
}
