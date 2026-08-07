/// Sipariş DTO'ları — `docs/openapi.yaml` §Sipariş.
library;

import 'package:bld_core/bld_core.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'converters.dart';

part 'order.freezed.dart';
part 'order.g.dart';

@freezed
abstract class Address with _$Address {
  const factory Address({
    required String line1,
    required String district,
    required String city,
    String? note,
  }) = _Address;

  factory Address.fromJson(Map<String, dynamic> json) =>
      _$AddressFromJson(json);
}

/// Adres defterindeki kayıt — `GET /addresses`.
///
/// [Address] ile karıştırılmamalı. [Address] siparişin taşıdığı **kopyadır**;
/// bu ise müşterinin defterindeki kayıttır. Sipariş verilirken defterdeki
/// satır kopyalanır, bağlanmaz: müşteri adresini düzelttiğinde teslim edilmiş
/// bir siparişin nereye gittiği değişmemeli (`docs/openapi.yaml` §SavedAddress).
@freezed
abstract class SavedAddress with _$SavedAddress {
  const factory SavedAddress({
    required int id,
    required String line1,
    required String district,
    required String city,
    required bool isDefault,

    /// Müşterinin verdiği ad — "Ev", "Ofis", "Şantiye".
    String? label,

    /// Kuryeye not. Fişte görünür.
    String? note,
  }) = _SavedAddress;

  const SavedAddress._();

  factory SavedAddress.fromJson(Map<String, dynamic> json) =>
      _$SavedAddressFromJson(json);

  /// Siparişe gidecek kopya.
  Address toOrderAddress() =>
      Address(line1: line1, district: district, city: city, note: note);

  /// Tek satırda okunabilir hâli — liste ve seçicide kullanılır.
  String get summary => '$line1, $district / $city';
}

/// `POST /addresses` ve `PATCH /addresses/{id}` gövdesi.
@freezed
abstract class SavedAddressInput with _$SavedAddressInput {
  const factory SavedAddressInput({
    required String line1,
    required String district,
    required String city,
    String? label,
    String? note,
    bool? isDefault,
  }) = _SavedAddressInput;

  factory SavedAddressInput.fromJson(Map<String, dynamic> json) =>
      _$SavedAddressInputFromJson(json);
}

@freezed
abstract class OrderCreateItem with _$OrderCreateItem {
  const factory OrderCreateItem({
    required int menuId,
    required int quantity,
    @Default(<int>[]) List<int> optionValueIds,
    String? note,
  }) = _OrderCreateItem;

  factory OrderCreateItem.fromJson(Map<String, dynamic> json) =>
      _$OrderCreateItemFromJson(json);
}

/// `POST /orders` gövdesi.
///
/// Tutar alanı **yoktur** — hesap sunucuda yapılır (`docs/10` S6 adım 5).
@freezed
abstract class OrderCreateRequest with _$OrderCreateRequest {
  const factory OrderCreateRequest({
    required int locationId,
    required List<OrderCreateItem> items,
    @DeliveryTypeConverter() required DeliveryType deliveryType,
    @PaymentMethodConverter() required PaymentMethod paymentMethod,

    /// `delivery` ise zorunlu, `pickup` ise sunucu yok sayar.
    Address? address,

    /// İstenen teslim zamanı (UTC). `order_cutoff`'a takılırsa `LOCATION_CLOSED`.
    DateTime? requestedAt,
    String? customerNote,
  }) = _OrderCreateRequest;

  factory OrderCreateRequest.fromJson(Map<String, dynamic> json) =>
      _$OrderCreateRequestFromJson(json);
}

@freezed
abstract class Payment with _$Payment {
  const factory Payment({
    @PaymentMethodConverter() required PaymentMethod method,
    @PaymentStatusConverter() required PaymentStatus status,

    /// Yalnızca `online` yönteminde dolu; istemci kullanıcıyı buraya yönlendirir.
    String? redirectUrl,
  }) = _Payment;

  const Payment._();

  factory Payment.fromJson(Map<String, dynamic> json) =>
      _$PaymentFromJson(json);

  /// Sanal POS'a yönlendirme gerekiyor mu?
  bool get requiresRedirect =>
      method == PaymentMethod.online &&
      status == PaymentStatus.pending &&
      redirectUrl != null;
}

/// `POST /orders` yanıtı (201).
@freezed
abstract class OrderCreated with _$OrderCreated {
  const factory OrderCreated({
    required int id,
    required String orderNumber,
    @OrderStatusConverter() required OrderStatus status,

    /// Kuruş.
    required int total,
    required String currency,
    required Payment payment,
    required DateTime createdAt,
  }) = _OrderCreated;

  factory OrderCreated.fromJson(Map<String, dynamic> json) =>
      _$OrderCreatedFromJson(json);
}

/// `GET /orders` listesindeki özet.
@freezed
abstract class OrderSummary with _$OrderSummary {
  const factory OrderSummary({
    required int id,
    required String orderNumber,
    @OrderStatusConverter() required OrderStatus status,
    required int total,
    required String currency,
    required int itemCount,
    required DateTime createdAt,
  }) = _OrderSummary;

  factory OrderSummary.fromJson(Map<String, dynamic> json) =>
      _$OrderSummaryFromJson(json);
}

@freezed
abstract class OrderItem with _$OrderItem {
  const factory OrderItem({
    required int menuId,
    required String name,
    required int quantity,

    /// Seçenek farkları **dahil** birim fiyat (kuruş).
    required int unitPrice,
    required int lineTotal,
    @Default(<String>[]) List<String> options,
    String? note,
  }) = _OrderItem;

  factory OrderItem.fromJson(Map<String, dynamic> json) =>
      _$OrderItemFromJson(json);
}

@freezed
abstract class StatusHistoryEntry with _$StatusHistoryEntry {
  const factory StatusHistoryEntry({
    @OrderStatusConverter() required OrderStatus status,
    required DateTime at,
  }) = _StatusHistoryEntry;

  factory StatusHistoryEntry.fromJson(Map<String, dynamic> json) =>
      _$StatusHistoryEntryFromJson(json);
}

/// `GET /orders/{id}` yanıtı.
@freezed
abstract class OrderDetail with _$OrderDetail {
  const factory OrderDetail({
    required int id,
    required String orderNumber,
    @OrderStatusConverter() required OrderStatus status,
    required List<OrderItem> items,
    required int subtotal,

    /// `pickup` siparişte her zaman `0`.
    required int deliveryFee,
    required int total,
    required String currency,
    @DeliveryTypeConverter() required DeliveryType deliveryType,
    required Payment payment,
    required List<StatusHistoryEntry> statusHistory,
    required DateTime createdAt,

    /// `pickup` siparişte `null`.
    Address? address,
    DateTime? requestedAt,
    String? customerNote,
  }) = _OrderDetail;

  const OrderDetail._();

  factory OrderDetail.fromJson(Map<String, dynamic> json) =>
      _$OrderDetailFromJson(json);

  /// Müşteri bu siparişi iptal edebilir mi? (`docs/03` §4)
  bool get canBeCancelledByCustomer =>
      OrderStatusMachine.customerCanCancel(status);

  /// Takip ekranındaki adım çubuğu — gel-al siparişte `yolda` gösterilmez.
  List<OrderStatus> get trackingSteps => [
    OrderStatus.yeni,
    OrderStatus.onaylandi,
    OrderStatus.hazirlaniyor,
    OrderStatus.hazir,
    if (deliveryType == DeliveryType.delivery) OrderStatus.yolda,
    OrderStatus.teslimEdildi,
  ];
}

@freezed
abstract class PaginationMeta with _$PaginationMeta {
  const factory PaginationMeta({
    required int page,
    required int perPage,
    required int total,
    required int lastPage,
  }) = _PaginationMeta;

  const PaginationMeta._();

  factory PaginationMeta.fromJson(Map<String, dynamic> json) =>
      _$PaginationMetaFromJson(json);

  bool get hasNextPage => page < lastPage;
}

/// `GET /orders` yanıtının tamamı.
@freezed
abstract class OrderPage with _$OrderPage {
  const factory OrderPage({
    required List<OrderSummary> data,
    required PaginationMeta meta,
  }) = _OrderPage;

  factory OrderPage.fromJson(Map<String, dynamic> json) =>
      _$OrderPageFromJson(json);
}
