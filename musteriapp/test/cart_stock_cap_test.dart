/// Sepetin stok tavanı — `bld_core` `maxAddable`'ın sepetteki karşılığı.
///
/// NEDEN AYRI DOSYA: aritmetiğin kendisi `packages/core`'da ve altın veri
/// kümesiyle (`docs/contract/sales-rules.cases.json`) zaten sınanıyor. Burada
/// sınanan şey farklı: sepetin o aritmetiğe DOĞRU GİRDİYİ verip vermediği.
/// Saha hatası da tam olarak orada çıkıyordu — hesap doğru, ama "sepette kaç
/// tane var" sorusu yanlış cevaplanınca müşteri kalmayan porsiyonu sipariş
/// ediyor ve `422` yiyor.
///
/// Üç girdi ayrı ayrı yanlış olabilir ve üçü de sessizdir:
/// - gün toplamı ile kalem tavanı karıştırılabilir,
/// - başka bir güne ait sepetin adetleri bu günün tavanından düşülebilir,
/// - aynı ürünün iki satırı ayrı sayılıp tavanı iki kez tüketebilir.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musteriapp/src/features/cart/cart_controller.dart';
import 'package:musteriapp/src/features/cart/cart_model.dart';
import 'package:musteriapp/src/providers/infra_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/daily_menu_fixtures.dart';

MenuItem _item({int id = 101, int? remaining, bool available = true}) =>
    MenuItem(
      id: id,
      name: 'Mercimek Çorbası',
      price: 6000,
      currency: 'TRY',
      isAvailable: available,
      remainingPortions: remaining,
    );

void main() {
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

  CartAddResult add({
    MenuItem? item,
    int quantity = 1,
    int? dayRemaining,
    String date = fixedToday,
    String? note,
  }) => notifier().add(
    item: item ?? _item(),
    locationId: 1,
    serviceDate: date,
    quantity: quantity,
    dayRemaining: dayRemaining,
    note: note,
  );

  group('add', () {
    test('tavan konmamışsa (null) satış SINIRSIZDIR', () {
      // `null`'ı sıfır sayan istemci, tavanı hiç konmamış bir günü tükenmiş
      // gösterir ve satışı kapatır.
      expect(add(quantity: 40), CartAddResult.added);
      expect(cart().itemCount, 40);
    });

    test('kalem tavanı kadarı girer, bir fazlası HİÇ girmez', () {
      expect(
        add(item: _item(remaining: 3), quantity: 4),
        CartAddResult.stockCapped,
      );
      expect(cart().isEmpty, isTrue, reason: 'Ekleme hepsi ya da hiçbiri.');

      expect(add(item: _item(remaining: 3), quantity: 3), CartAddResult.added);
      expect(cart().itemCount, 3);
    });

    test('gün toplamı kalem tavanından DAR ise günü bağlar', () {
      // Gün toplamından 2 kalmışken bu yemekten 10 olması satışı açmaz.
      expect(
        add(item: _item(remaining: 10), quantity: 3, dayRemaining: 2),
        CartAddResult.stockCapped,
      );
      expect(
        add(item: _item(remaining: 10), quantity: 2, dayRemaining: 2),
        CartAddResult.added,
      );
    });

    test('gün toplamı sepetteki BAŞKA ürünlerle birlikte tükenir', () {
      expect(add(item: _item(id: 101), quantity: 2, dayRemaining: 3),
          CartAddResult.added);
      // Gün tavanından geriye 1 kaldı; ikinci üründen 2 istemek sığmaz.
      expect(
        add(item: _item(id: 102), quantity: 2, dayRemaining: 3),
        CartAddResult.stockCapped,
      );
      expect(
        add(item: _item(id: 102), quantity: 1, dayRemaining: 3),
        CartAddResult.added,
      );
      expect(cart().itemCount, 3);
    });

    test('aynı ürünün İKİ SATIRI kalem tavanını birlikte tüketir', () {
      // Farklı not ayrı satır açıyor ama mutfakta aynı tencereden çıkıyor.
      // Satır başına saysaydık iki satırlık bir ürün tavanı iki kez tüketirdi.
      expect(
        add(item: _item(remaining: 3), quantity: 2, note: 'az tuzlu'),
        CartAddResult.added,
      );
      expect(
        add(item: _item(remaining: 3), quantity: 2, note: 'bol tuzlu'),
        CartAddResult.stockCapped,
      );
      expect(cart().lineCount, 1);
    });

    test('BAŞKA GÜNÜN sepeti bu günün tavanını tüketmez', () {
      // Sepet ilk eklemede zaten boşalacak; eski adetleri yeni günün
      // tavanından düşmek, dolu sepetle gelen müşteriye bugünü tükenmiş
      // gösterirdi.
      expect(add(quantity: 3, dayRemaining: 3), CartAddResult.added);

      expect(
        add(quantity: 3, dayRemaining: 3, date: fixedTomorrow),
        CartAddResult.addedAfterDayChange,
      );
      expect(cart().serviceDate, fixedTomorrow);
      expect(cart().itemCount, 3);
    });

    test('sığmayan ekleme DOLU SEPETİ boşaltmaz', () {
      // Gün değişimi sepeti sıfırlıyor; tavan denetimi o sıfırlamadan ÖNCE
      // dönmezse müşteri istemediği bir kaybı istemediği bir istekle yaşardı.
      expect(add(quantity: 2), CartAddResult.added);

      expect(
        add(quantity: 5, dayRemaining: 1, date: fixedTomorrow),
        CartAddResult.stockCapped,
      );
      expect(cart().serviceDate, fixedToday);
      expect(cart().itemCount, 2);
    });

    test('satışta olmayan ürün stok değil KABUL sebebiyle reddedilir', () {
      // İki sonuç ayrı: biri "bu satılmıyor", öbürü "bu kadarı kalmadı".
      expect(
        add(item: _item(available: false, remaining: 10)),
        CartAddResult.rejected,
      );
    });

    test('satır başı tavan aşılamaz', () {
      expect(add(quantity: kMaxCartLineQuantity), CartAddResult.added);
      expect(add(quantity: 1), CartAddResult.stockCapped);
    });
  });

  group('setQuantity / increment', () {
    test('artırma tavanda KISILIR', () {
      add(item: _item(remaining: 3), quantity: 1);
      final signature = cart().lines.single.signature;

      notifier().setQuantity(signature, 9);
      expect(cart().lines.single.quantity, 3, reason: 'Kalan 3, tavan 3.');

      notifier().increment(signature);
      expect(cart().lines.single.quantity, 3, reason: 'Tavanda artmaz.');
    });

    test('artırma GÜN toplamıyla da kısılır', () {
      add(quantity: 1, dayRemaining: 2);
      final signature = cart().lines.single.signature;

      notifier().setQuantity(signature, 5, dayRemaining: 2);
      expect(cart().lines.single.quantity, 2);
    });

    test('eksiltme tavandan ETKİLENMEZ', () {
      // Tavan sepet doldurulduktan sonra inmiş olabilir; müşteriyi adedini
      // düşüremez hâle getirmek onu kilitlerdi.
      add(item: _item(remaining: 10), quantity: 5);
      final signature = cart().lines.single.signature;

      notifier().setQuantity(signature, 2, dayRemaining: 0);
      expect(cart().lines.single.quantity, 2);
    });
  });

  group('cartExceedsStock', () {
    DailyMenu menuWith({int? dayRemaining, int? itemRemaining}) =>
        sampleDailyMenu(
          withPackage: false,
          items: [_item(remaining: itemRemaining)],
        ).copyWith(remainingPortions: dayRemaining);

    test('menü tavanı yoksa hiçbir sepet aşmaz', () {
      add(quantity: 50);
      expect(cartExceedsStock(cart(), menuWith()), isFalse);
    });

    test('gün tavanı aşıldığında engel doğar', () {
      add(quantity: 4);
      expect(cartExceedsStock(cart(), menuWith(dayRemaining: 3)), isTrue);
      expect(cartExceedsStock(cart(), menuWith(dayRemaining: 4)), isFalse);
    });

    test('kalem tavanı aşıldığında engel doğar', () {
      add(quantity: 4);
      expect(cartExceedsStock(cart(), menuWith(itemRemaining: 3)), isTrue);
    });

    test('BAŞKA GÜNÜN menüsü sepeti yargılamaz', () {
      // Sepetin günü menünün gününden farklıysa karşılaştırma anlamsız;
      // "aşıyor" demek, ilgisiz bir günün tavanıyla sepeti kilitlemek olurdu.
      add(quantity: 9);
      final other = menuWith(dayRemaining: 1).copyWith(date: fixedTomorrow);
      expect(cartExceedsStock(cart(), other), isFalse);
    });
  });
}
