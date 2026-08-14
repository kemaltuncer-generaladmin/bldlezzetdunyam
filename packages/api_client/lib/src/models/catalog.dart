/// Katalog DTO'ları — `docs/openapi.yaml` `Location`, `MenuCategory`, `MenuItem`.
library;

import 'package:bld_core/bld_core.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'converters.dart';

part 'catalog.freezed.dart';
part 'catalog.g.dart';

/// Tek bir teslimat tipi için teslim süresi tahmini — `Location.eta.*`.
///
/// Dakika aralığıdır, tek bir sayı değil: mutfak süresi doğası gereği
/// aralıklıdır ve tek sayı vermek tutamayacağımız bir söz verir.
@freezed
abstract class EtaWindow with _$EtaWindow {
  const factory EtaWindow({
    /// Aralığın alt sınırı (dakika).
    required int minMinutes,

    /// Aralığın üst sınırı (dakika).
    required int maxMinutes,

    /// Tahmin ölçüldü mü, yoksa panelde mi girildi?
    @EtaSourceConverter() @Default(EtaSource.unknown) EtaSource source,

    /// Mutfak yoğun. **Aralık sunucuda zaten uzatılmıştır** — istemci ayrıca
    /// süre eklemez, yalnızca nedenini söyler.
    @Default(false) bool busy,
  }) = _EtaWindow;

  const EtaWindow._();

  factory EtaWindow.fromJson(Map<String, dynamic> json) =>
      _$EtaWindowFromJson(json);

  /// Aralık gösterilebilir mi?
  ///
  /// Sunucu bozuk bir aralık gönderirse (sıfır, negatif veya ters sıralı)
  /// tahmini hiç göstermemek, saçma bir saat göstermekten iyidir.
  bool get isUsable => minMinutes > 0 && maxMinutes >= minMinutes;

  /// Tahmin gerçekleşmiş siparişlerden mi hesaplandı?
  bool get isMeasured => source.isMeasured;
}

/// Vitrinin iki teslimat tipi için teslim süresi tahminleri.
@freezed
abstract class LocationEta with _$LocationEta {
  const factory LocationEta({EtaWindow? delivery, EtaWindow? pickup}) =
      _LocationEta;

  const LocationEta._();

  factory LocationEta.fromJson(Map<String, dynamic> json) =>
      _$LocationEtaFromJson(json);

  /// Seçili teslimat tipinin tahmini. Yoksa veya kullanılamazsa `null`.
  EtaWindow? forDeliveryType(DeliveryType type) {
    final eta = switch (type) {
      DeliveryType.delivery => delivery,
      DeliveryType.pickup => pickup,
    };
    return (eta != null && eta.isUsable) ? eta : null;
  }
}

@freezed
abstract class Location with _$Location {
  const factory Location({
    required int id,
    required String name,
    required String slug,

    /// Çalışma saatlerinden türetilir — şu an sipariş saati içinde miyiz?
    required bool isOpen,

    /// Elle ana şalter — yönetici ya da mutfak çevirir (K-11).
    required bool orderingEnabled,

    /// Sipariş almanın neden durdurulduğu; müşteriye gösterilir.
    ///
    /// **İsteğe bağlı ve öyle kalmalı:** alan sözleşmeye sonradan eklendi
    /// ve eski sunucu/önbellek onu içermez. `null` normal bir durumdur —
    /// istemci o zaman genel bir metin gösterir.
    String? orderingPauseReason,

    /// Süreli durdurmanın bitişi; süresizse `null`.
    DateTime? orderingResumesAt,

    /// Satış **günün menüsü** üzerinden mi yürüyor? (B-19)
    ///
    /// Sunucu tarafı şalter, bilerek: günün menüsü akışına geçmek bir ay
    /// ileriye menü girilmiş olmasını gerektiriyor. Şalter olmasaydı geri
    /// dönmek üç uygulamayı birden yeniden yayınlamak demekti.
    ///
    /// Varsayılanı `false`: alan sözleşmeye sonradan eklendi ve eski
    /// sunucu/önbellek onu içermiyor — o durumda eski katalog akışı çalışır.
    @Default(false) bool dailyMenuEnabled,

    /// Bugünden itibaren kaç gün sonrasına sipariş alınabileceği.
    ///
    /// Gün seçici takvimi bu kadar ileriye çizer; **sunucu aynı sınırı
    /// `POST /orders` üzerinde yeniden uygular** — istemcinin çizdiği takvim
    /// bir kolaylıktır, kapı değil.
    @Default(30) int maxLookaheadDays,

    /// Kuruş. Altında sipariş `422 VALIDATION_FAILED`.
    required int minOrderTotal,

    /// Bu vitrinde **açık** olan ödeme yöntemleri. İstemci yalnızca bunları gösterir.
    @PaymentMethodConverter() required List<PaymentMethod> paymentMethods,

    /// Günlük son sipariş saati (`HH:mm`, Europe/Istanbul) veya `null`.
    String? orderCutoff,

    /// Teslim süresi tahminleri.
    ///
    /// **İsteğe bağlıdır ve öyle kalmalıdır.** Alan sözleşmeye sonradan
    /// eklendi; eski bir sunucu, mock veya cihazdaki eski önbellek kaydı bu
    /// alanı içermez. `null` gelmesi normal bir durumdur, hata değildir —
    /// istemci o zaman tahmini hiç göstermez.
    LocationEta? eta,
  }) = _Location;

  const Location._();

  factory Location.fromJson(Map<String, dynamic> json) =>
      _$LocationFromJson(json);

  /// Şu anda sipariş alınabiliyor mu?
  ///
  /// İkisi de doğru olmalı: saat uygun **ve** şalter açık. `order_cutoff`
  /// kontrolü sunucudadır — istemci saatine güvenilmez.
  bool get acceptsOrders => isOpen && orderingEnabled;

  /// Müşteriye gösterilebilecek ödeme yöntemleri.
  List<PaymentMethod> get selectablePaymentMethods =>
      paymentMethods.where((m) => m.isSelectable).toList(growable: false);

  /// Seçili teslimat tipinin teslim süresi tahmini; yoksa `null`.
  ///
  /// Sipariş alınmıyorken `null` döner: kapalı bir vitrinde "60-85 dakika"
  /// demek, sipariş verilebileceği izlenimi yaratır.
  EtaWindow? etaFor(DeliveryType type) =>
      acceptsOrders ? eta?.forDeliveryType(type) : null;
}

@freezed
abstract class MenuCategory with _$MenuCategory {
  const factory MenuCategory({
    required int id,
    required String name,
    required int sort,
    required List<MenuItem> items,
  }) = _MenuCategory;

  factory MenuCategory.fromJson(Map<String, dynamic> json) =>
      _$MenuCategoryFromJson(json);
}

@freezed
abstract class MenuItem with _$MenuItem {
  const factory MenuItem({
    required int id,
    required String name,

    /// Kuruş.
    required int price,
    required String currency,

    /// `false` ürün listede **kalır**; soluk gösterilir, sepete eklenemez.
    ///
    /// İki sebepten biriyle `false` olur: yöneticinin kalıcı kararı ya da
    /// mutfağın günlük [soldOutToday] işareti (K-11).
    required bool isAvailable,

    /// Mutfak bugünlük tükendi işaretledi mi?
    ///
    /// Varsayılanı `false`: alan sözleşmeye sonradan eklendi ve eski
    /// sunucu/önbellek onu içermiyor.
    @Default(false) bool soldOutToday,

    /// `soldOutToday` doğruyken mutfağın yazdığı sebep.
    String? soldOutReason,
    String? description,
    String? imageUrl,
    @Default(<String>[]) List<String> allergens,
    @Default(<MenuOption>[]) List<MenuOption> options,
  }) = _MenuItem;

  const MenuItem._();

  factory MenuItem.fromJson(Map<String, dynamic> json) =>
      _$MenuItemFromJson(json);

  /// Seçilen seçenek değerleriyle birlikte birim fiyat (kuruş).
  ///
  /// Bu **gösterim** hesabıdır. Siparişin gerçek tutarı her zaman sunucudan
  /// gelir; ikisi çelişirse sunucu haklıdır (`docs/openapi.yaml` `createOrder`).
  int unitPriceWith(Set<int> optionValueIds) {
    var total = price;
    for (final option in options) {
      for (final value in option.values) {
        if (optionValueIds.contains(value.id)) total += value.priceDelta;
      }
    }
    return total;
  }
}

@freezed
abstract class MenuOption with _$MenuOption {
  const factory MenuOption({
    required int id,
    required String name,

    /// Bilinen değerler: `radio`, `checkbox`, `select`. Kapalı enum değildir —
    /// TastyIgniter'ın gerçek kümesi `B-02`'de doğrulanacak (BILINMEYENLER).
    required String type,
    required bool required,
    required List<MenuOptionValue> values,
  }) = _MenuOption;

  const MenuOption._();

  factory MenuOption.fromJson(Map<String, dynamic> json) =>
      _$MenuOptionFromJson(json);

  /// Birden fazla değer seçilebilir mi? Bilinmeyen tip tek seçim varsayılır.
  bool get isMultiSelect => type == 'checkbox';
}

@freezed
abstract class MenuOptionValue with _$MenuOptionValue {
  const factory MenuOptionValue({
    required int id,
    required String name,

    /// Kuruş cinsinden **işaretli** fark; negatif olabilir.
    required int priceDelta,
  }) = _MenuOptionValue;

  factory MenuOptionValue.fromJson(Map<String, dynamic> json) =>
      _$MenuOptionValueFromJson(json);
}
