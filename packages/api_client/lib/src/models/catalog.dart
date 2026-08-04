/// Katalog DTO'ları — `docs/openapi.yaml` `Location`, `MenuCategory`, `MenuItem`.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

import 'converters.dart';

part 'catalog.freezed.dart';
part 'catalog.g.dart';

@freezed
abstract class Location with _$Location {
  const factory Location({
    required int id,
    required String name,
    required String slug,

    /// Çalışma saatlerinden türetilir — şu an sipariş saati içinde miyiz?
    required bool isOpen,

    /// Yöneticinin admin panelden çevirdiği elle ana şalter.
    required bool orderingEnabled,

    /// Kuruş. Altında sipariş `422 VALIDATION_FAILED`.
    required int minOrderTotal,

    /// Bu vitrinde **açık** olan ödeme yöntemleri. İstemci yalnızca bunları gösterir.
    @PaymentMethodConverter() required List<PaymentMethod> paymentMethods,

    /// Günlük son sipariş saati (`HH:mm`, Europe/Istanbul) veya `null`.
    String? orderCutoff,
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
    required bool isAvailable,
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
