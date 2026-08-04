/// Sepet modeli ve hesabı.
///
/// **Buradaki tutarlar yalnızca gösterim içindir.** Siparişin gerçek tutarını
/// her zaman sunucu hesaplar; istemcinin gönderdiği tutar alanları yok sayılır
/// (`docs/openapi.yaml` `createOrder`). İkisi çelişirse sunucu haklıdır.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'cart_model.freezed.dart';
part 'cart_model.g.dart';

/// Sepetteki tek bir kalem: ürün + seçilen seçenekler + adet + not.
@freezed
abstract class CartLine with _$CartLine {
  const factory CartLine({
    required MenuItem item,
    required int quantity,

    /// Seçilen `MenuOptionValue` kimlikleri. Sıra anlamlı değildir; kimlik
    /// karşılaştırması [signature] üzerinden sıralı yapılır.
    @Default(<int>[]) List<int> optionValueIds,
    String? note,
  }) = _CartLine;

  const CartLine._();

  factory CartLine.fromJson(Map<String, dynamic> json) =>
      _$CartLineFromJson(json);

  /// Seçenek farkları dahil birim fiyat (kuruş).
  int get unitPrice => item.unitPriceWith(optionValueIds.toSet());

  /// Kalem toplamı (kuruş).
  int get lineTotal => unitPrice * quantity;

  /// Seçilen seçeneklerin görünen adları, menüdeki sırayla.
  List<String> get optionLabels => [
    for (final option in item.options)
      for (final value in option.values)
        if (optionValueIds.contains(value.id)) value.name,
  ];

  /// İki kalemin "aynı" sayılıp birleştirileceğini belirleyen kimlik.
  ///
  /// Aynı ürün farklı seçenek veya farklı notla eklendiğinde ayrı kalem olur —
  /// mutfak fişinde de ayrı satır olarak basılacağı için birleştirmek yanlış
  /// olurdu.
  String get signature {
    final sortedIds = [...optionValueIds]..sort();
    return '${item.id}|${sortedIds.join(',')}|${note?.trim() ?? ''}';
  }

  /// Sipariş isteğindeki karşılığı (`docs/openapi.yaml` `OrderCreateRequest`).
  OrderCreateItem toOrderItem() => OrderCreateItem(
    menuId: item.id,
    quantity: quantity,
    optionValueIds: [...optionValueIds]..sort(),
    note: (note == null || note!.trim().isEmpty) ? null : note!.trim(),
  );
}

/// Sepetin tamamı.
@freezed
abstract class Cart with _$Cart {
  const factory Cart({
    @Default(<CartLine>[]) List<CartLine> lines,

    /// Sepet hangi vitrine ait? Vitrin değişirse sepet sıfırlanır — sipariş tek
    /// vitrine verilir (`OrderCreateRequest.location_id`).
    int? locationId,
  }) = _Cart;

  const Cart._();

  factory Cart.fromJson(Map<String, dynamic> json) => _$CartFromJson(json);

  static const Cart empty = Cart();

  bool get isEmpty => lines.isEmpty;

  bool get isNotEmpty => lines.isNotEmpty;

  /// Farklı kalem sayısı (adetler değil).
  int get lineCount => lines.length;

  /// Toplam ürün adedi.
  int get itemCount =>
      lines.fold(0, (total, line) => total + line.quantity);

  /// Kalem toplamlarının toplamı (kuruş). Teslimat ücreti **dahil değildir** —
  /// onu sunucu ekler.
  int get subtotal => lines.fold(0, (total, line) => total + line.lineTotal);

  /// Belirli bir kalem kimliğiyle eşleşen satırın konumu; yoksa `-1`.
  int indexOfSignature(String signature) =>
      lines.indexWhere((line) => line.signature == signature);
}
