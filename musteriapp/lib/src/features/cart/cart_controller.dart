/// Sepet durumu. Yerelde korunur — çevrimdışıyken de kaybolmaz
/// (`docs/07-musteriapp.md` §5).
library;

import 'dart:async';

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/infra_providers.dart';
import 'cart_model.dart';

/// [CartNotifier.add] çağrısının sonucu.
///
/// Dönüş değeri VAR çünkü sepetin boşaltıldığı sessizce geçilemez: müşteri
/// perşembe menüsünü doldurmuşken cuma menüsünden bir yemeğe dokunduğunda
/// önceki seçimleri kayboluyor. Ekran bunu söylemek zorunda; söylemezse
/// müşteri ödeme ekranında eksik sepetle karşılaşır ve hatayı uygulamada
/// değil kendisinde arar.
enum CartAddResult {
  /// Kalem sepete girdi.
  added,

  /// Kalem girdi ama sepet BAŞKA BİR SERVİS GÜNÜNE aitti ve boşaltıldı.
  addedAfterDayChange,

  /// Kalem girmedi: satışta değil ya da adet geçersiz.
  rejected,

  /// Kalem girmedi: istenen adet o günün ya da o yemeğin **kalan porsiyonunu**
  /// aşıyor (`bld_core` `maxAddable`).
  ///
  /// [rejected]'tan AYRI çünkü müşteriye kurulacak cümle ayrı: biri "bu satışta
  /// değil", öbürü "bu kadarı kalmadı". Aynı değere sıkıştırılsalardı, son iki
  /// porsiyonu kalan bir yemeği üç isteyen müşteri onu hiç satılmıyor sanır ve
  /// vazgeçerdi.
  ///
  /// **Ekleme HEPSİ YA DA HİÇBİRİ:** sığmayan istek sessizce kısılmaz. Üç
  /// isteyip iki alan müşteri, farkı ancak yemek gelince görürdü; sepet ise
  /// hiç dokunulmadan durur ve müşteri adedi kendi düşürür.
  stockCapped,
}

class CartNotifier extends Notifier<Cart> {
  @override
  Cart build() {
    final json = ref.watch(localCacheProvider).readCart();
    if (json == null) return Cart.empty;

    try {
      return Cart.fromJson(json);
    } on Object {
      // Bozuk kayıt (yarım yazma) kullanıcıyı kilitlememeli. Eski ŞEMA ise
      // buraya hiç gelmez: `LocalCache.readCart` sürümü tanımadığı kaydı
      // okumadan siler ve `null` döner.
      return Cart.empty;
    }
  }

  /// Sepete ekler. Aynı ürün + aynı seçenekler + aynı not tek kalemde birleşir.
  ///
  /// İki durumda sepet sıfırlanır ve kalem boş sepete girer:
  /// - **Vitrin değiştiyse:** bir sipariş tek vitrine verilir
  ///   (`OrderCreateRequest.location_id`).
  /// - **Servis günü değiştiyse:** bir sipariş tek güne verilir
  ///   (`OrderCreateRequest.service_date`). Bu durum [CartAddResult] ile
  ///   çağırana bildirilir.
  ///
  /// [dayRemaining] o servis gününün TOPLAM kalan porsiyonu
  /// (`DailyMenu.remainingPortions`); kalem tavanı [item]'ın kendi
  /// `remainingPortions` alanından okunur. **İkisi de `null` olabilir ve `null`
  /// SINIRSIZ demektir.** Çağıran günün menüsünü elinde tutuyorsa bu değeri
  /// vermelidir: verilmezse yalnız kalem tavanı bağlar ve gün toplamı dolmuş
  /// bir menüden sepete kalem girer.
  CartAddResult add({
    required MenuItem item,
    required int locationId,
    required String serviceDate,
    int quantity = 1,
    int? dayRemaining,
    List<int> optionValueIds = const <int>[],
    String? note,
    List<DailyMenuPackageComponent> packageComponents =
        const <DailyMenuPackageComponent>[],
  }) {
    // Satışta olmayan ürün sepete girmez (`docs/openapi.yaml` `MenuItem`).
    if (!item.isAvailable || quantity < 1) return CartAddResult.rejected;

    // `isNotEmpty` şart: boş sepetin günü değişmiş sayılmaz ve kullanıcıya
    // kaybetmediği bir şey için uyarı gösterilmez.
    final dayChanged =
        state.isNotEmpty &&
        state.serviceDate != null &&
        state.serviceDate != serviceDate;
    final locationChanged =
        state.locationId != null && state.locationId != locationId;
    final base = (dayChanged || locationChanged) ? Cart.empty : state;

    // Tavan denetimi SIFIRLANMIŞ sepete göre yapılıyor: gün değişiyorsa önceki
    // günün adetleri bu günün tavanını tüketmiyor.
    //
    // Denetim `_emit`'ten ÖNCE ve erken dönüşle: sığmayan bir ekleme yüzünden
    // müşterinin dolu sepetini boşaltmak, istemediği bir kaybı istemediği bir
    // isteğe bedel yapardı.
    final room = maxAddable(
      dayRemaining: dayRemaining,
      itemRemaining: item.remainingPortions,
      alreadyInCartForDay: base.quantityOn(serviceDate),
      alreadyInCartForItem: base.quantityOfItemOn(serviceDate, item.id),
      hardMax: kMaxCartLineQuantity,
    );
    if (quantity > room) return CartAddResult.stockCapped;

    final incoming = CartLine(
      item: item,
      quantity: quantity,
      optionValueIds: [...optionValueIds]..sort(),
      note: (note == null || note.trim().isEmpty) ? null : note.trim(),
      packageComponents: packageComponents,
    );

    final existing = base.indexOfSignature(incoming.signature);
    final lines = [...base.lines];
    if (existing >= 0) {
      lines[existing] = lines[existing].copyWith(
        quantity: lines[existing].quantity + quantity,
      );
    } else {
      lines.add(incoming);
    }

    _emit(
      base.copyWith(
        lines: lines,
        locationId: locationId,
        serviceDate: serviceDate,
      ),
    );
    return dayChanged ? CartAddResult.addedAfterDayChange : CartAddResult.added;
  }

  /// Adedi ayarlar. `0` ve altı kalemi siler.
  ///
  /// **Artırma stok tavanıyla KISILIR, eksiltme kısılmaz:** sepeti azaltan bir
  /// hareketin stokla işi yok ve tavan sonradan indirilmiş bir sepette
  /// müşterinin adedi düşürmesini engellemek onu kilitlerdi.
  ///
  /// [dayRemaining] verilmezse yalnız kalem tavanı ve satır başı tavan bağlar
  /// (bkz. [add]).
  void setQuantity(String signature, int quantity, {int? dayRemaining}) {
    final index = state.indexOfSignature(signature);
    if (index < 0) return;

    if (quantity < 1) {
      removeLine(signature);
      return;
    }

    final line = state.lines[index];
    if (quantity > line.quantity) {
      final room = maxAddable(
        dayRemaining: dayRemaining,
        itemRemaining: line.item.remainingPortions,
        alreadyInCartForDay: state.itemCount,
        alreadyInCartForItem: state.quantityOfItem(line.item.id),
        hardMax: kMaxCartLineQuantity,
      );
      final ceiling = line.quantity + room;
      // Sepette hiç yer yoksa hiçbir şey yazılmaz: aynı değeri yeniden
      // yazmak, dinleyen her ekranı boşuna çizdirir.
      if (ceiling <= line.quantity) return;
      if (quantity > ceiling) quantity = ceiling;
    }

    final lines = [...state.lines];
    lines[index] = line.copyWith(quantity: quantity);
    _emit(state.copyWith(lines: lines));
  }

  void increment(String signature, {int? dayRemaining}) {
    final index = state.indexOfSignature(signature);
    if (index < 0) return;
    setQuantity(
      signature,
      state.lines[index].quantity + 1,
      dayRemaining: dayRemaining,
    );
  }

  void decrement(String signature) {
    final index = state.indexOfSignature(signature);
    if (index < 0) return;
    setQuantity(signature, state.lines[index].quantity - 1);
  }

  void removeLine(String signature) {
    final lines = state.lines
        .where((line) => line.signature != signature)
        .toList();
    _emit(lines.isEmpty ? Cart.empty : state.copyWith(lines: lines));
  }

  void clear() => _emit(Cart.empty);

  void _emit(Cart next) {
    state = next;
    // Yazma beklenmez: sepet kaybı kabul edilebilir, arayüzün donması değil.
    unawaited(
      ref
          .read(localCacheProvider)
          .writeCart(next.isEmpty ? null : next.toJson()),
    );
  }
}

final cartProvider = NotifierProvider<CartNotifier, Cart>(CartNotifier.new);
