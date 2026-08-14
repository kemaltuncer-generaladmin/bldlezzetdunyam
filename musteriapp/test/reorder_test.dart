/// Tekrar sipariş kararı.
///
/// NEDEN VAR: menü her gün değişiyor. Dünkü siparişin bir kısmı bugün
/// menüde olmayabilir ya da satışta olmayabilir. Sessizce atlamak, müşterinin
/// eksik sipariş verip farkı ancak teslimatta görmesi demek — bu yüzden
/// atlanan kalem sayısı sonuçta taşınıyor ve arayüz onu ayrı bir mesajla
/// söylüyor.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musteriapp/src/features/home/reorder.dart';

MenuItem _item(int id, {bool available = true}) => MenuItem(
  id: id,
  name: 'Ürün $id',
  price: 18500,
  currency: 'TRY',
  isAvailable: available,
);

OrderDetail _order(List<int> menuIds, {List<OrderItem> extra = const []}) =>
    OrderDetail(
  id: 1,
  orderNumber: 'BLD-1',
  status: OrderStatus.hazirlaniyor,
  items: [
    for (final id in menuIds)
      OrderItem(
        menuId: id,
        name: 'Ürün $id',
        quantity: 2,
        unitPrice: 18500,
        lineTotal: 37000,
      ),
    ...extra,
  ],
  subtotal: 0,
  deliveryFee: 0,
  total: 0,
  currency: 'TRY',
  deliveryType: DeliveryType.delivery,
  payment: const Payment(
    method: PaymentMethod.cash,
    status: PaymentStatus.pending,
  ),
  statusHistory: const [],
  createdAt: DateTime.utc(2026, 8, 7),
);


void main() {
  test('menüdeki ürünler sepete adediyle birlikte eklenir', () {
    final eklenen = <(int, int)>[];

    final outcome = reorderInto(
      order: _order([10, 11]),
      menuItems: [_item(10), _item(11)],
      addToCart: (item, quantity) => eklenen.add((item.id, quantity)),
    );

    expect(outcome.added, 2);
    expect(outcome.missing, 0);
    expect(outcome.isPartial, isFalse);

    // Adet TAŞINIYOR: iki porsiyon sipariş eden müşteri tekrar sipariş
    // verdiğinde bire düşerse eksik sipariş verir.
    expect(eklenen, [(10, 2), (11, 2)]);
  });

  test('menüde olmayan ürün atlanır ve sayılır', () {
    final eklenen = <int>[];

    final outcome = reorderInto(
      order: _order([10, 99]),
      menuItems: [_item(10)],
      addToCart: (item, _) => eklenen.add(item.id),
    );

    expect(eklenen, [10]);
    expect(outcome.added, 1);
    expect(outcome.missing, 1);
    expect(outcome.isPartial, isTrue, reason: 'Kullanıcı eksiği bilmeli.');
  });

  test('satışta olmayan ürün menüde DURSA BİLE eklenmez', () {
    // `is_available == false` ürün listede kalır ama sepete giremez
    // (`docs/openapi.yaml` MenuItem). Burada da aynı kural geçerli olmalı;
    // aksi hâlde tekrar sipariş, menü ekranının reddettiği ürünü sepete
    // sokan bir arka kapı olurdu.
    final eklenen = <int>[];

    final outcome = reorderInto(
      order: _order([10]),
      menuItems: [_item(10, available: false)],
      addToCart: (item, _) => eklenen.add(item.id),
    );

    expect(eklenen, isEmpty);
    expect(outcome.added, 0);
    expect(outcome.missing, 1);
    expect(outcome.isEmpty, isTrue);
  });

  test('hiçbiri bulunamazsa sepete dokunulmaz', () {
    var cagrildi = false;

    final outcome = reorderInto(
      order: _order([98, 99]),
      menuItems: [_item(10)],
      addToCart: (_, _) => cagrildi = true,
    );

    expect(cagrildi, isFalse);
    expect(outcome.isEmpty, isTrue);
    expect(outcome.isPartial, isFalse, reason: 'Kısmi değil, tamamen boş.');
    expect(outcome.missing, 2);
  });

  test('aynı ürün iki kalemdeyse ikisi de eklenir', () {
    // Aynı ürün farklı notlarla iki ayrı kalem olabilir. Kimliğe göre
    // tekilleştirmek kalemlerden birini sessizce düşürürdü.
    final eklenen = <int>[];

    final outcome = reorderInto(
      order: _order([10, 10]),
      menuItems: [_item(10)],
      addToCart: (item, _) => eklenen.add(item.id),
    );

    expect(eklenen, [10, 10]);
    expect(outcome.added, 2);
  });

  test('paketin BİLEŞEN satırları atlanır ve eksik sayılmaz', () {
    // Menü paketi siparişte FİYATLI bir üst satır + SIFIR FİYATLI bileşen
    // satırları olarak duruyor. Bileşenler de eklenseydi menü hem paket
    // olarak hem içindekiler tek tek olarak sepete girer, müşteri iki kat
    // öderdi. `missing` olarak sayılmaları da yanlış olurdu: eksik olan bir
    // şey yok, o yemekler zaten paketin içinde.
    final eklenen = <int>[];

    final outcome = reorderInto(
      order: _order(
        const [],
        extra: const [
          OrderItem(
            menuId: 900,
            name: 'Günün Menüsü',
            quantity: 1,
            unitPrice: 18000,
            lineTotal: 18000,
            role: 'package',
          ),
          OrderItem(
            menuId: 101,
            name: 'Mercimek Çorbası',
            quantity: 1,
            unitPrice: 0,
            lineTotal: 0,
            role: 'component',
            includedIn: 0,
          ),
        ],
      ),
      menuItems: [_item(900)],
      addToCart: (item, _) => eklenen.add(item.id),
    );

    expect(eklenen, [900], reason: 'Yalnız paketin kendisi eklenmeli.');
    expect(outcome.added, 1);
    expect(outcome.missing, 0);
  });
}
