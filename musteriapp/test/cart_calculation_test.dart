/// Sepet hesabı — `docs/07-musteriapp.md` §7 birinci madde.
///
/// Adet, seçenek fiyat farkı ve ara toplam. Tutarlar kuruş cinsinden `int`'tir;
/// hiçbir yerde `double` kullanılmaz.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musteriapp/src/features/cart/cart_controller.dart';
import 'package:musteriapp/src/features/cart/cart_model.dart';
import 'package:musteriapp/src/providers/infra_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/daily_menu_fixtures.dart';

/// 45,50 TL ana yemek; iki seçenek grubu.
MenuItem buildMainCourse() => const MenuItem(
  id: 101,
  name: 'Kuru Fasulye',
  price: 4550,
  currency: 'TRY',
  isAvailable: true,
  options: [
    MenuOption(
      id: 1,
      name: 'Porsiyon',
      type: 'radio',
      required: true,
      values: [
        MenuOptionValue(id: 11, name: 'Yarım', priceDelta: -1000),
        MenuOptionValue(id: 12, name: 'Tam', priceDelta: 0),
        MenuOptionValue(id: 13, name: 'Bol', priceDelta: 1250),
      ],
    ),
    MenuOption(
      id: 2,
      name: 'Ekstralar',
      type: 'checkbox',
      required: false,
      values: [
        MenuOptionValue(id: 21, name: 'Pilav', priceDelta: 2000),
        MenuOptionValue(id: 22, name: 'Turşu', priceDelta: 750),
      ],
    ),
  ],
);

MenuItem buildDrink() => const MenuItem(
  id: 202,
  name: 'Ayran',
  price: 1200,
  currency: 'TRY',
  isAvailable: true,
);

MenuItem buildSoldOut() => const MenuItem(
  id: 303,
  name: 'Izgara Köfte',
  price: 9000,
  currency: 'TRY',
  isAvailable: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CartLine hesabı', () {
    test('seçenek yoksa birim fiyat ürün fiyatıdır', () {
      final line = CartLine(item: buildMainCourse(), quantity: 1);

      expect(line.unitPrice, 4550);
      expect(line.lineTotal, 4550);
    });

    test('pozitif seçenek farkı birim fiyata eklenir', () {
      final line = CartLine(
        item: buildMainCourse(),
        quantity: 1,
        optionValueIds: const [13], // Bol +12,50
      );

      expect(line.unitPrice, 4550 + 1250);
    });

    test('negatif seçenek farkı birim fiyattan düşülür', () {
      final line = CartLine(
        item: buildMainCourse(),
        quantity: 1,
        optionValueIds: const [11], // Yarım -10,00
      );

      expect(line.unitPrice, 4550 - 1000);
    });

    test('çok seçimli grupta farklar toplanır', () {
      final line = CartLine(
        item: buildMainCourse(),
        quantity: 1,
        optionValueIds: const [12, 21, 22], // Tam + Pilav + Turşu
      );

      expect(line.unitPrice, 4550 + 0 + 2000 + 750);
    });

    test('kalem toplamı birim fiyat × adet', () {
      final line = CartLine(
        item: buildMainCourse(),
        quantity: 3,
        optionValueIds: const [21], // +20,00
      );

      expect(line.unitPrice, 6550);
      expect(line.lineTotal, 19650);
    });

    test('bilinmeyen seçenek kimliği fiyata etki etmez', () {
      final line = CartLine(
        item: buildMainCourse(),
        quantity: 1,
        optionValueIds: const [9999],
      );

      expect(line.unitPrice, 4550);
    });

    test('seçenek etiketleri menüdeki sırayla döner', () {
      final line = CartLine(
        item: buildMainCourse(),
        quantity: 1,
        optionValueIds: const [22, 12],
      );

      expect(line.optionLabels, ['Tam', 'Turşu']);
    });

    test('kimlik seçenek sırasından bağımsızdır, nottan bağımsız değildir', () {
      final a = CartLine(
        item: buildMainCourse(),
        quantity: 1,
        optionValueIds: const [21, 22],
      );
      final b = CartLine(
        item: buildMainCourse(),
        quantity: 5,
        optionValueIds: const [22, 21],
      );
      final withNote = CartLine(
        item: buildMainCourse(),
        quantity: 1,
        optionValueIds: const [21, 22],
        note: 'az tuzlu',
      );

      expect(a.signature, b.signature);
      expect(a.signature, isNot(withNote.signature));
    });

    test('sipariş kalemine çevirirken boş not null olur', () {
      final line = CartLine(
        item: buildMainCourse(),
        quantity: 2,
        optionValueIds: const [22, 21],
        note: '   ',
      );

      final orderItem = line.toOrderItem();
      expect(orderItem.menuId, 101);
      expect(orderItem.quantity, 2);
      expect(orderItem.optionValueIds, [21, 22]);
      expect(orderItem.note, isNull);
    });
  });

  group('Cart ara toplamı', () {
    test('boş sepetin ara toplamı sıfırdır', () {
      expect(Cart.empty.subtotal, 0);
      expect(Cart.empty.itemCount, 0);
      expect(Cart.empty.isEmpty, isTrue);
    });

    test('kalem toplamlarının toplamıdır', () {
      final cart = Cart(
        locationId: 1,
        serviceDate: fixedToday,
        lines: [
          CartLine(
            item: buildMainCourse(),
            quantity: 2,
            optionValueIds: const [13], // (45,50 + 12,50) × 2 = 116,00
          ),
          CartLine(item: buildDrink(), quantity: 3), // 12,00 × 3 = 36,00
        ],
      );

      expect(cart.subtotal, 11600 + 3600);
      expect(cart.itemCount, 5);
      expect(cart.lineCount, 2);
    });
  });

  group('CartNotifier', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
    });

    CartNotifier notifier() => container.read(cartProvider.notifier);
    Cart cart() => container.read(cartProvider);

    test('aynı ürün aynı seçeneklerle tek kalemde birleşir', () {
      notifier().add(
        item: buildMainCourse(),
        locationId: 1,
        serviceDate: fixedToday,
        quantity: 2,
        optionValueIds: const [12],
      );
      notifier().add(
        item: buildMainCourse(),
        locationId: 1,
        serviceDate: fixedToday,
        quantity: 3,
        optionValueIds: const [12],
      );

      expect(cart().lineCount, 1);
      expect(cart().lines.single.quantity, 5);
      expect(cart().subtotal, 4550 * 5);
    });

    test('farklı seçenek ayrı kalem açar', () {
      notifier().add(
        item: buildMainCourse(),
        locationId: 1,
        serviceDate: fixedToday,
        optionValueIds: const [12],
      );
      notifier().add(
        item: buildMainCourse(),
        locationId: 1,
        serviceDate: fixedToday,
        optionValueIds: const [13],
      );

      expect(cart().lineCount, 2);
      expect(cart().subtotal, 4550 + (4550 + 1250));
    });

    test('satışta olmayan ürün sepete girmez', () {
      notifier().add(item: buildSoldOut(), locationId: 1, serviceDate: fixedToday);

      expect(cart().isEmpty, isTrue);
    });

    test('adet artırma ve azaltma ara toplamı günceller', () {
      notifier().add(item: buildDrink(), locationId: 1, serviceDate: fixedToday);
      final signature = cart().lines.single.signature;

      notifier().increment(signature);
      expect(cart().subtotal, 2400);

      notifier().decrement(signature);
      expect(cart().subtotal, 1200);
    });

    test('adet sıfıra inince kalem silinir', () {
      notifier().add(item: buildDrink(), locationId: 1, serviceDate: fixedToday);
      final signature = cart().lines.single.signature;

      notifier().setQuantity(signature, 0);

      expect(cart().isEmpty, isTrue);
      expect(cart().locationId, isNull);
    });

    test('vitrin değişirse sepet sıfırlanır', () {
      notifier().add(item: buildDrink(), locationId: 1, serviceDate: fixedToday);
      notifier().add(item: buildMainCourse(), locationId: 2, serviceDate: fixedToday);

      expect(cart().locationId, 2);
      expect(cart().lineCount, 1);
      expect(cart().lines.single.item.id, 101);
    });

    test('sepet yerelde korunur ve geri okunur', () async {
      notifier().add(
        item: buildMainCourse(),
        locationId: 1,
        serviceDate: fixedToday,
        quantity: 2,
        optionValueIds: const [21],
      );
      final expectedSubtotal = cart().subtotal;

      // Aynı depolamayla yeni bir kap: uygulama yeniden başlatılmış gibi.
      final prefs = await SharedPreferences.getInstance();
      final restored = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(restored.dispose);

      expect(restored.read(cartProvider).subtotal, expectedSubtotal);
      expect(restored.read(cartProvider).locationId, 1);
      expect(restored.read(cartProvider).serviceDate, fixedToday);
    });

    test('servis günü değişirse sepet sıfırlanır ve bu SÖYLENİR', () {
      // Bir sipariş tek güne verilir (`OrderCreateRequest.service_date`).
      // Perşembe menüsüyle cuma menüsünü aynı fişe koymak mutfağın
      // karşılayamayacağı bir sipariş üretirdi.
      notifier().add(
        item: buildDrink(),
        locationId: 1,
        serviceDate: fixedToday,
      );

      final result = notifier().add(
        item: buildMainCourse(),
        locationId: 1,
        serviceDate: fixedTomorrow,
      );

      expect(result, CartAddResult.addedAfterDayChange);
      expect(cart().serviceDate, fixedTomorrow);
      expect(cart().lineCount, 1);
      expect(cart().lines.single.item.id, 101);
    });

    test('aynı gün eklemede uyarı çıkmaz', () {
      notifier().add(
        item: buildDrink(),
        locationId: 1,
        serviceDate: fixedToday,
      );
      final result = notifier().add(
        item: buildMainCourse(),
        locationId: 1,
        serviceDate: fixedToday,
      );

      expect(result, CartAddResult.added);
      expect(cart().lineCount, 2);
    });

    test('BOŞ sepette gün değişimi uyarı üretmez', () {
      // Kullanıcının kaybettiği bir şey yok; "önceki sepetiniz silindi"
      // demek yanlış olurdu.
      final result = notifier().add(
        item: buildDrink(),
        locationId: 1,
        serviceDate: fixedTomorrow,
      );

      expect(result, CartAddResult.added);
    });

    test('satışta olmayan ürün reddedildi olarak döner', () {
      expect(
        notifier().add(
          item: buildSoldOut(),
          locationId: 1,
          serviceDate: fixedToday,
        ),
        CartAddResult.rejected,
      );
    });

    test('sepet boşalınca servis günü de düşer', () {
      notifier().add(
        item: buildDrink(),
        locationId: 1,
        serviceDate: fixedToday,
      );
      notifier().clear();

      // Gün kalsaydı, ertesi gün eklenen ilk kalem "sepetiniz taşındı"
      // uyarısını boş yere tetiklerdi.
      expect(cart().serviceDate, isNull);
    });

    test('paket satırı içindekileri GÖSTERİM için taşır', () {
      notifier().add(
        item: const MenuItem(
          id: 900,
          name: 'Günün Menüsü',
          price: 18000,
          currency: 'TRY',
          isAvailable: true,
        ),
        locationId: 1,
        serviceDate: fixedToday,
        packageComponents: const [
          DailyMenuPackageComponent(
            menuId: 101,
            name: 'Mercimek Çorbası',
            quantity: 1,
          ),
        ],
      );

      final line = cart().lines.single;
      expect(line.isPackage, isTrue);
      expect(line.packageComponents.single.name, 'Mercimek Çorbası');

      // İstek gövdesine yalnız paketin kimliği gider; içindekileri sunucu
      // açar. Bileşenler de gönderilseydi menü iki kez satılmış olurdu.
      expect(line.toOrderItem().menuId, 900);
    });
  });

  group('cartDayProblem', () {
    CartLine line() => CartLine(item: buildDrink(), quantity: 1);

    test('boş sepette sorun yok', () {
      expect(cartDayProblem(Cart.empty, today: fixedToday), isNull);
    });

    test('bugüne ve ileriye bağlı sepet geçerlidir', () {
      expect(
        cartDayProblem(
          Cart(lines: [line()], locationId: 1, serviceDate: fixedToday),
          today: fixedToday,
        ),
        isNull,
      );
      expect(
        cartDayProblem(
          Cart(lines: [line()], locationId: 1, serviceDate: fixedTomorrow),
          today: fixedToday,
        ),
        isNull,
      );
    });

    test('geçmiş güne bağlı sepet engellenir', () {
      // Telefonu gece açık kalan müşteride olağan: akşam doldurulan sepet
      // sabah hâlâ dünkü güne bağlıdır.
      expect(
        cartDayProblem(
          Cart(lines: [line()], locationId: 1, serviceDate: '2026-08-19'),
          today: fixedToday,
        ),
        CartDayProblem.past,
      );
    });

    test('günü olmayan ya da bozuk günlü dolu sepet engellenir', () {
      expect(
        cartDayProblem(Cart(lines: [line()], locationId: 1), today: fixedToday),
        CartDayProblem.missing,
      );
      expect(
        cartDayProblem(
          Cart(lines: [line()], locationId: 1, serviceDate: 'bozuk'),
          today: fixedToday,
        ),
        CartDayProblem.missing,
      );
    });
  });
}
