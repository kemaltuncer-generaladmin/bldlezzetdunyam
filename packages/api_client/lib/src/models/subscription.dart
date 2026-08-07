/// Abonelik DTO'ları — `docs/openapi.yaml` §Abonelik.
///
/// Durum/ödeme/menü modu düz `String` tutulur (katı enum değil): sözleşmeye
/// ileride yeni bir değer eklenirse istemci çökmez, bilinmeyen değeri gösterir.
library;

import 'package:bld_core/bld_core.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'converters.dart';

part 'subscription.freezed.dart';
part 'subscription.g.dart';

@freezed
abstract class SubscriptionLine with _$SubscriptionLine {
  const factory SubscriptionLine({
    int? menuId,
    required int quantity,

    /// Porsiyon başı anlaşmalı fiyat (kuruş); satır fiyatı yoksa `null`.
    int? agreedUnitPrice,

    /// Diyet/alerjen etiketi — "Vejetaryen" vb.
    String? label,
  }) = _SubscriptionLine;

  factory SubscriptionLine.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionLineFromJson(json);
}

@freezed
abstract class SubscriptionDeliveryPoint with _$SubscriptionDeliveryPoint {
  const factory SubscriptionDeliveryPoint({
    required int id,
    required int addressId,
    int? quantity,
    String? note,
  }) = _SubscriptionDeliveryPoint;

  factory SubscriptionDeliveryPoint.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionDeliveryPointFromJson(json);
}

/// `GET /subscriptions` / `GET /subscriptions/{id}` — abonelik kuralı.
@freezed
abstract class Subscription with _$Subscription {
  const factory Subscription({
    required int id,

    /// `pending` (talep, fiyatsız) | `active` | `paused` | `cancelled`.
    required String status,
    required int locationId,
    @DeliveryTypeConverter() required DeliveryType deliveryType,
    required DateTime startDate,
    DateTime? endDate,

    /// ISO hafta günleri (1 Pazartesi .. 7 Pazar).
    @Default(<int>[]) List<int> serviceDays,
    String? deliveryTimeFrom,
    String? deliveryTimeTo,
    required int defaultQuantity,

    /// Porsiyon başı anlaşmalı fiyat (kuruş). Talepte `null`; admin belirler.
    int? agreedUnitPrice,

    /// `account` (ay sonu cari) | `prepaid_monthly` (peşin).
    required String paymentMode,

    /// `fixed_list` | `daily_menu`.
    required String menuMode,
    @Default(<SubscriptionLine>[]) List<SubscriptionLine> lines,
    @Default(<SubscriptionDeliveryPoint>[])
    List<SubscriptionDeliveryPoint> deliveryPoints,
    required DateTime createdAt,
  }) = _Subscription;

  const Subscription._();

  factory Subscription.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionFromJson(json);

  bool get isActive => status == 'active';

  bool get isPending => status == 'pending';

  bool get isPaused => status == 'paused';

  bool get isCancelled => status == 'cancelled';
}

@freezed
abstract class SubscriptionCreateItem with _$SubscriptionCreateItem {
  const factory SubscriptionCreateItem({
    required int menuId,
    required int quantity,
    String? label,
  }) = _SubscriptionCreateItem;

  factory SubscriptionCreateItem.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionCreateItemFromJson(json);
}

@freezed
abstract class SubscriptionCreatePoint with _$SubscriptionCreatePoint {
  const factory SubscriptionCreatePoint({
    required int addressId,
    int? quantity,
    String? note,
  }) = _SubscriptionCreatePoint;

  factory SubscriptionCreatePoint.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionCreatePointFromJson(json);
}

/// `POST /subscriptions` gövdesi — TALEP (fiyatı admin belirler).
///
/// Tarihler `String` ("2026-08-15"): kullanıcı bir gün seçer, saat/zaman dilimi
/// karışmasın; sunucu `date` bekliyor.
@freezed
abstract class SubscriptionCreateRequest with _$SubscriptionCreateRequest {
  const factory SubscriptionCreateRequest({
    required int locationId,
    @DeliveryTypeConverter() required DeliveryType deliveryType,
    required String startDate,
    String? endDate,
    required List<int> serviceDays,
    required int defaultQuantity,
    String? deliveryTimeFrom,
    String? deliveryTimeTo,
    @Default(<SubscriptionCreateItem>[]) List<SubscriptionCreateItem> lines,
    @Default(<SubscriptionCreatePoint>[])
    List<SubscriptionCreatePoint> deliveryPoints,
    String? customerNote,
  }) = _SubscriptionCreateRequest;

  factory SubscriptionCreateRequest.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionCreateRequestFromJson(json);
}

/// `POST /subscriptions/{id}/exceptions` gövdesi — tek-günlük istisna.
@freezed
abstract class SubscriptionExceptionRequest
    with _$SubscriptionExceptionRequest {
  const factory SubscriptionExceptionRequest({
    required String serviceDate,
    bool? skip,
    int? quantityOverride,
  }) = _SubscriptionExceptionRequest;

  factory SubscriptionExceptionRequest.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionExceptionRequestFromJson(json);
}
