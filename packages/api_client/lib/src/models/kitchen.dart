/// Mutfak (KDS) DTO'ları — `docs/openapi.yaml` §Mutfak.
///
/// Bu modellerde **fiyat ve müşteri iletişim bilgisi yoktur**. İstisnalar
/// yalnızca fişlerdir: [CustomerReceipt] fiyatlı ve (adrese gönderimde)
/// adreslidir, [KitchenReceipt] ise müşteri telefonunu taşır. Fiş tek bir
/// sipariş için basılır; ekranda duran kartlar (`KitchenOrder`) hâlâ iletişim
/// bilgisi görmez.
library;

import 'package:bld_core/bld_core.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'converters.dart';
import 'order.dart';

part 'kitchen.freezed.dart';
part 'kitchen.g.dart';

@freezed
abstract class PairRequest with _$PairRequest {
  const factory PairRequest({
    required String pairingCode,
    required String deviceName,
  }) = _PairRequest;

  factory PairRequest.fromJson(Map<String, dynamic> json) =>
      _$PairRequestFromJson(json);
}

@freezed
abstract class PairResponse with _$PairResponse {
  const factory PairResponse({
    required int deviceId,
    required String token,
    required DateTime serverTime,
  }) = _PairResponse;

  factory PairResponse.fromJson(Map<String, dynamic> json) =>
      _$PairResponseFromJson(json);
}

@freezed
abstract class KitchenOrderItem with _$KitchenOrderItem {
  const factory KitchenOrderItem({
    required String name,
    required int quantity,
    @Default(<String>[]) List<String> options,
    String? note,
  }) = _KitchenOrderItem;

  factory KitchenOrderItem.fromJson(Map<String, dynamic> json) =>
      _$KitchenOrderItemFromJson(json);
}

@freezed
abstract class KitchenOrder with _$KitchenOrder {
  const factory KitchenOrder({
    required int id,
    required String orderNumber,
    @OrderStatusConverter() required OrderStatus status,
    @DeliveryTypeConverter() required DeliveryType deliveryType,
    required List<KitchenOrderItem> items,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? requestedAt,

    /// Yalnızca ad + soyad baş harfi (kartın üst satırı).
    String? customerLabel,

    /// Müşterinin tam adı ve telefonu (K-14).
    ///
    /// KURAL DEĞİŞTİ (11.08.2026): `docs/03` §5 eskiden "mutfak listesinde
    /// telefon GÖRÜNMEZ" diyordu ve sipariş düzenleme gelene kadar
    /// doğruydu. Artık personel müşteriyi ARAYIP anlaşmak zorunda;
    /// numarayı görmek için fiş basmak saçma. **Fiyat ve adres hâlâ
    /// gönderilmiyor** — kural kaldırılmadı, daraltıldı.
    ///
    /// Eski sunucu bu alanları göndermezse `null` gelir ve kart eskisi
    /// gibi çizilir.
    String? customerName,
    String? customerPhone,
    String? customerNote,

    /// Kaçıncı revizyon (K-12). 0 = hiç düzenlenmedi.
    ///
    /// Artması, fişlerin yeniden basılması gerektiği anlamına gelir
    /// (`print_triggers.dart`).
    @Default(0) int revisionNo,

    /// Bu sipariş bir abonelik kuralından mı üretildi? (`docs/openapi.yaml`
    /// `is_subscription`.) KDS bunu rozet + "bugün abonelik var" paneliyle
    /// gösterir. Eski sunucu göndermezse `false`.
    @Default(false) bool isSubscription,
  }) = _KitchenOrder;

  const KitchenOrder._();

  factory KitchenOrder.fromJson(Map<String, dynamic> json) =>
      _$KitchenOrderFromJson(json);

  /// KDS kartındaki rozet: `ADR` veya `GELAL`.
  String get deliveryBadge => deliveryTypeBadgeTr[deliveryType]!;

  /// Personelin basacağı tek ileri buton; terminal durumda `null`.
  OrderStatus? get nextStatus =>
      OrderStatusMachine.nextForward(status, deliveryType);

  /// Kartta vurgulu (kırmızı) gösterilecek bir not var mı?
  bool get hasHighlightedNote =>
      (customerNote?.trim().isNotEmpty ?? false) ||
      items.any((i) => i.note?.trim().isNotEmpty ?? false);
}

/// `GET /kitchen/orders` yanıtının tamamı.
///
/// [serverTime] bir sonraki isteğin `since` değeri, [maxId] ise `after`
/// değeridir — `docs/05-mutfakapp.md` §4.
@freezed
abstract class KitchenOrderPage with _$KitchenOrderPage {
  const factory KitchenOrderPage({
    required List<KitchenOrder> data,
    required DateTime serverTime,
    required int maxId,
  }) = _KitchenOrderPage;

  factory KitchenOrderPage.fromJson(Map<String, dynamic> json) =>
      _$KitchenOrderPageFromJson(json);
}

/// `GET /kitchen/subscription-orders` — bugün + yarının abonelik siparişleri,
/// gün gün gruplu. Mutfak yemek kuyruğunu önceden planlar.
@freezed
abstract class KitchenSubscriptionOrders with _$KitchenSubscriptionOrders {
  const factory KitchenSubscriptionOrders({
    @Default(<KitchenOrder>[]) List<KitchenOrder> today,
    @Default(<KitchenOrder>[]) List<KitchenOrder> tomorrow,
    required DateTime serverTime,
  }) = _KitchenSubscriptionOrders;

  factory KitchenSubscriptionOrders.fromJson(Map<String, dynamic> json) =>
      _$KitchenSubscriptionOrdersFromJson(json);
}

@freezed
abstract class ReceiptLine with _$ReceiptLine {
  const factory ReceiptLine({
    required int quantity,
    required String name,
    @Default(<String>[]) List<String> options,
    String? note,
  }) = _ReceiptLine;

  factory ReceiptLine.fromJson(Map<String, dynamic> json) =>
      _$ReceiptLineFromJson(json);
}

/// `GET /kitchen/orders/{id}/receipt?type=mutfak` — fiyat içermez.
@freezed
abstract class KitchenReceipt with _$KitchenReceipt {
  const factory KitchenReceipt({
    required String orderNumber,
    @DeliveryTypeConverter() required DeliveryType deliveryType,
    required List<ReceiptLine> lines,
    @Default('mutfak') String type,
    DateTime? requestedAt,

    /// Müşterinin telefonu — yalnızca **fişe** basmak için.
    ///
    /// KDS kartında ([KitchenOrder]) telefon yoktur: ekran mutfakta gün boyu
    /// açık durur. Fiş tek bir sipariş için basılıp kuryeye gider.
    String? customerPhone,
    String? customerNote,
    DateTime? printedAt,
  }) = _KitchenReceipt;

  factory KitchenReceipt.fromJson(Map<String, dynamic> json) =>
      _$KitchenReceiptFromJson(json);
}

/// `GET /kitchen/orders/{id}/receipt?type=musteri` — fiyatlı, adrese
/// gönderimde adresli.
@freezed
abstract class CustomerReceipt with _$CustomerReceipt {
  const factory CustomerReceipt({
    required String orderNumber,
    @DeliveryTypeConverter() required DeliveryType deliveryType,
    required List<OrderItem> items,
    required int subtotal,
    required int deliveryFee,
    required int total,
    required String currency,
    required Payment payment,
    @Default('musteri') String type,

    /// `pickup` siparişte `null` — fişte adres bloğu basılmaz.
    Address? address,
    DateTime? requestedAt,
    String? customerLabel,
    DateTime? printedAt,
  }) = _CustomerReceipt;

  factory CustomerReceipt.fromJson(Map<String, dynamic> json) =>
      _$CustomerReceiptFromJson(json);
}

/// `GET /kitchen/orders/{id}/receipt?type=kurye` — kuryenin eline giden
/// fiş (K-14).
///
/// NEDEN ÜÇÜNCÜ TİP: kurye üç bilgiye ihtiyaç duyuyor ve hiçbiri tek bir
/// mevcut fişte birlikte yok — kime (ad + telefon), nereye (adres + QR),
/// ne kadar tahsil edilecek. Mutfak fişinde adres yok; müşteri fişi ise
/// müşteride kalıyor.
@freezed
abstract class CourierReceipt with _$CourierReceipt {
  const factory CourierReceipt({
    required String orderNumber,
    @DeliveryTypeConverter() required DeliveryType deliveryType,
    required List<OrderItem> items,
    required int total,
    required String currency,
    required Payment payment,
    @Default('kurye') String type,
    Address? address,
    DateTime? requestedAt,
    String? customerName,
    String? customerPhone,
    String? customerNote,
    DateTime? printedAt,

    /// Kaçıncı revizyon; 0 = düzenlenmemiş.
    @Default(0) int revisionNo,

    /// İnsan okuyabilir değişiklik satırları.
    @Default(<String>[]) List<String> revisionSummary,

    /// Kapıda tahsil edilecek tutar (kuruş). Ödenmişse 0.
    @Default(0) int collectAmount,
  }) = _CourierReceipt;

  factory CourierReceipt.fromJson(Map<String, dynamic> json) =>
      _$CourierReceiptFromJson(json);
}

/// `POST /kitchen/print-jobs/{order_id}/ack` gövdesi.
@freezed
abstract class PrintAckRequest with _$PrintAckRequest {
  const factory PrintAckRequest({
    @ReceiptTypeConverter() required ReceiptType type,
    required DateTime printedAt,
  }) = _PrintAckRequest;

  factory PrintAckRequest.fromJson(Map<String, dynamic> json) =>
      _$PrintAckRequestFromJson(json);
}

@freezed
abstract class ProductionListItem with _$ProductionListItem {
  const factory ProductionListItem({
    required int menuId,
    required String name,
    required int total,
  }) = _ProductionListItem;

  factory ProductionListItem.fromJson(Map<String, dynamic> json) =>
      _$ProductionListItemFromJson(json);
}

@freezed
abstract class ProductionList with _$ProductionList {
  const factory ProductionList({
    required List<ProductionListItem> data,
    required DateTime asOf,
  }) = _ProductionList;

  factory ProductionList.fromJson(Map<String, dynamic> json) =>
      _$ProductionListFromJson(json);
}

@freezed
abstract class HeartbeatResponse with _$HeartbeatResponse {
  const factory HeartbeatResponse({
    required DateTime serverTime,
    required String minSupportedVersion,
  }) = _HeartbeatResponse;

  factory HeartbeatResponse.fromJson(Map<String, dynamic> json) =>
      _$HeartbeatResponseFromJson(json);
}

/// `POST /kitchen/busy` yanıtı.
///
/// Mesaj SUNUCUDAN gelir; istemciler kendi metnini gömmez. Yönetici metni
/// admin panelden değiştirince üç uygulamayı da yayınlamak gerekmesin.
@freezed
abstract class BusyState with _$BusyState {
  const factory BusyState({
    required bool busy,
    required String busyMessage,
    required DateTime serverTime,
  }) = _BusyState;

  factory BusyState.fromJson(Map<String, dynamic> json) =>
      _$BusyStateFromJson(json);
}

@freezed
abstract class AppVersionInfo with _$AppVersionInfo {
  const factory AppVersionInfo({
    required String appId,
    required String latest,
    required String minSupported,

    /// Yalnızca `mutfakapp` için dolu (`.deb` adresi).
    String? downloadUrl,
    String? notes,
  }) = _AppVersionInfo;

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) =>
      _$AppVersionInfoFromJson(json);
}
