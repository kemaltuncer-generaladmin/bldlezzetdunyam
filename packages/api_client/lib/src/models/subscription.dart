/// Abonelik DTO'ları — `docs/openapi.yaml` §Abonelik, §Ödeme, §Sözleşme.
///
/// Durum/ödeme/menü modu düz `String` tutulur (katı enum değil): sözleşmeye
/// ileride yeni bir değer eklenirse istemci çökmez, bilinmeyen değeri gösterir.
/// Sözleşme durumu ([SubscriptionContract.status]) de aynı gerekçeyle
/// `String`'tir; okuma kolaylığı için her ikisinde de getter'lar var.
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

/// Aboneliğin tek bir servis günü için geçerli istisnası —
/// `docs/openapi.yaml` `SubscriptionException`.
///
/// Kuralın kendisini değiştirmez; yalnız o günü etkiler.
///
/// **NEDEN VAR (16.08.2026):** `POST /subscriptions/{id}/exceptions` istisnayı
/// yazıyordu ama hiçbir uç geri okumuyordu — abone bir günü atladıktan sonra
/// atladığını ekranda göremiyor, emin olmak için aynı günü tekrar tekrar
/// atlıyordu. Gün-atlama arayüzü bu modele bağlıdır.
@freezed
abstract class SubscriptionException with _$SubscriptionException {
  const factory SubscriptionException({
    /// İstisnanın geçerli olduğu servis günü, `YYYY-AA-GG` (Europe/Istanbul).
    ///
    /// `DateTime` değil `String`: bu bir an değil, takvimdeki bir gün —
    /// gerekçe `daily_menu.dart` kitaplık açıklamasında.
    required String serviceDate,

    /// `true` ise o gün sipariş **üretilmez**. `false` ise gün üretilir ve
    /// varsa [quantityOverride] uygulanır.
    required bool skip,

    /// O güne özel porsiyon adedi; verilmemişse `null` ve aboneliğin
    /// `defaultQuantity` değeri geçerlidir. [skip] doğruyken anlamsızdır.
    int? quantityOverride,

    /// İstisnanın girildiği an.
    ///
    /// Ekranda "12 Ağustos'ta atladınız" diyebilmek için var: aynı gün için
    /// iki kez işlem yapıldığında abone hangisinin geçerli olduğunu ancak
    /// zamana bakarak anlar.
    DateTime? createdAt,
  }) = _SubscriptionException;

  const SubscriptionException._();

  factory SubscriptionException.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionExceptionFromJson(json);

  /// O gün için geçerli porsiyon adedi; atlanan günde `0`.
  ///
  /// [defaultQuantity] aboneliğin kendi varsayılanıdır. Hesabı burada tutmak,
  /// "atlandı mı, adet mi değişti, yoksa varsayılan mı" üçlüsünü her ekranın
  /// ayrı ayrı dallandırmasını önler.
  int effectiveQuantity(int defaultQuantity) {
    if (skip) return 0;
    return quantityOverride ?? defaultQuantity;
  }
}

/// Yürürlükteki dönem ödemesinin ÖZETİ — `docs/openapi.yaml`
/// `SubscriptionPaymentSummary`.
///
/// Ödemenin geçmişi burada değildir; bu tip "şu an ne bekleniyor" sorusunu
/// yanıtlar. Ayrıntı ve akış [SubscriptionPayment]'tadır.
@freezed
abstract class SubscriptionPaymentSummary with _$SubscriptionPaymentSummary {
  const factory SubscriptionPaymentSummary({
    /// Ödeme dönemi, `YYYY-AA` (Europe/Istanbul takvim ayı). **Gün taşımaz:**
    /// dönem bir aydır, bir tarih değil.
    required String period,

    /// Dönem tutarı (kuruş). **Sunucu hesaplar** — servis günü sayısı ×
    /// porsiyon × anlaşmalı birim fiyat, atlanan günler düşülmüş hâlde.
    /// İstemci bu çarpımı tekrarlamaz; atlanan gün kuralını iki yerde
    /// tutmak, iki farklı tutar göstermenin en kısa yoludur.
    required int amount,
    required String currency,
    @PaymentStatusConverter() required PaymentStatus status,

    /// Ödeme kaydının kimliği; henüz ödeme başlatılmadıysa `null`. `null` ile
    /// `0` karıştırılmaz — `0` diye bir kayıt yoktur.
    int? paymentId,

    /// Son ödeme günü, `YYYY-AA-GG` (Europe/Istanbul); tanımlı değilse `null`.
    /// Tarih olarak veriliyor, an olarak değil: "ayın 5'i" bir gün adıdır ve
    /// saat dilimi tartışması yaratmaz.
    String? dueDate,
  }) = _SubscriptionPaymentSummary;

  const SubscriptionPaymentSummary._();

  factory SubscriptionPaymentSummary.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionPaymentSummaryFromJson(json);

  /// Bu dönem için ödeme başlatılmış mı?
  bool get isStarted => paymentId != null;

  bool get isPaid => status == PaymentStatus.paid;
}

/// Abonelik sözleşmesinin ÖZETİ — `docs/openapi.yaml`
/// `SubscriptionContractSummary`.
///
/// Metin burada **yoktur**, imzalı bağlantının arkasındadır
/// ([SubscriptionContract]) — sözleşme sayfalarca sürüyor ve abonelik
/// listesinde taşınacak bir şey değil.
@freezed
abstract class SubscriptionContractSummary with _$SubscriptionContractSummary {
  const factory SubscriptionContractSummary({
    /// `draft` | `sent` | `approved` | `expired` | `cancelled`.
    required String status,

    /// Sözleşme metninin sürümü. Fiyat ya da koşul değişince yeni bir sürüm
    /// üretilir ve **yeniden onay** istenir.
    int? version,

    /// Bağlantının SMS ile gönderildiği an.
    DateTime? sentAt,

    /// Abonenin SMS koduyla onayladığı an; onaylanmadıysa `null`.
    DateTime? approvedAt,
  }) = _SubscriptionContractSummary;

  const SubscriptionContractSummary._();

  factory SubscriptionContractSummary.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionContractSummaryFromJson(json);

  bool get isApproved => status == 'approved';

  bool get isAwaitingApproval => status == 'sent';

  /// Bağlantının süresi doldu; abonenin yapacağı iş **yeni bağlantı
  /// istemek**. [isCancelled] ile ayrı tutuluyor çünkü orada yapacak bir şey
  /// yok — tek düğmeye indirgemek ikisine de aynı çözümü önermek olurdu.
  bool get isExpired => status == 'expired';

  bool get isCancelled => status == 'cancelled';
}

/// İmzalı bağlantının arkasındaki sözleşme görünümü —
/// `GET /contracts/{token}`.
///
/// **Kimlik gerektirmeyen bir uçtan döndüğü için bilinçli olarak dardır:**
/// abonenin adresleri, e-postası, sipariş geçmişi ve müşteri kimliği burada
/// yoktur. Bağlantıyı ele geçiren biri yalnız sözleşmenin kendisini ve
/// maskeli telefonu görür; onay için SMS kodu ayrıca gerekir.
@freezed
abstract class SubscriptionContract with _$SubscriptionContract {
  const factory SubscriptionContract({
    /// `draft` | `sent` | `approved` | `expired` | `cancelled`.
    ///
    /// Süresi dolmuş bağlantı `410` değil **`200` + `expired`** döner:
    /// istemci "bu bağlantının süresi doldu, yenisini isteyin" cümlesini
    /// kurabilmeli, boş bir hata sayfası görmemelidir.
    required String status,
    required int version,

    /// Sözleşme metninin tamamı.
    required String body,

    /// `markdown` | `plain`. Sunucudan **HTML gönderilmez**: metin panelde
    /// yazılıyor ve doğrudan HTML gömmek sözleşme sayfasına script sokabilecek
    /// bir kapı açardı. İstemci bu alanı bilmediği bir değerde görürse metni
    /// DÜZ METİN gibi çizmelidir.
    required String bodyFormat,

    /// ISO hafta günleri (1 Pazartesi .. 7 Pazar).
    @Default(<int>[]) List<int> serviceDays,

    /// Porsiyon başı anlaşmalı fiyat (kuruş).
    required int unitPrice,
    required String currency,
    String? title,

    /// Sözleşmenin karşı tarafı — kurum unvanı ya da ad soyad. Onaylayan kişi
    /// doğru sözleşmeye baktığını buradan anlar.
    String? customerLabel,

    /// SMS kodunun gideceği numaranın **maskeli** hâli ("0555 *** ** 33").
    ///
    /// Tamamı gösterilmez: bağlantı kimlik istemiyor ve tam numarayı basmak,
    /// bağlantıyı ele geçirene doğrulanmış bir telefon numarası hediye etmek
    /// olurdu.
    String? maskedPhone,

    /// `YYYY-AA-GG`.
    String? startDate,
    String? endDate,
    int? defaultQuantity,

    /// Tipik bir ayın tahmini tutarı (kuruş). Onaylayan kişi neyi imzaladığını
    /// porsiyon fiyatından zihninde çarparak değil, yazılı bir rakamla
    /// görmelidir.
    int? monthlyEstimate,

    /// Bağlantının geçerlilik sonu; süresizse `null`.
    DateTime? expiresAt,
    DateTime? approvedAt,
  }) = _SubscriptionContract;

  const SubscriptionContract._();

  factory SubscriptionContract.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionContractFromJson(json);

  bool get isApproved => status == 'approved';

  bool get isExpired => status == 'expired';

  bool get isCancelled => status == 'cancelled';

  /// Şu anda onaylanabilir mi? (`draft` ve `sent` onaya açıktır.)
  ///
  /// Bilinmeyen bir durum burada `false` verir: tanımadığımız bir durumda
  /// onay düğmesi çizmek, sunucunun `422` ile reddedeceği bir işi kullanıcıya
  /// yaptırmaktır.
  bool get canApprove => status == 'sent' || status == 'draft';

  /// Metin Markdown mı? Bilinmeyen biçim düz metin sayılır — biçimlendirmeyi
  /// yanlış tahmin etmek, hiç biçimlendirmemekten kötüdür.
  bool get isMarkdown => bodyFormat == 'markdown';
}

/// Bir abonelik dönem ödemesinin tam hâli — `POST/GET
/// /subscriptions/{id}/payments...`.
@freezed
abstract class SubscriptionPayment with _$SubscriptionPayment {
  const factory SubscriptionPayment({
    required int paymentId,
    required int subscriptionId,

    /// `YYYY-AA` (Europe/Istanbul takvim ayı).
    required String period,

    /// Dönem tutarı (kuruş). Sunucu hesaplar; istekte GÖNDERİLMEZ.
    required int amount,
    required String currency,
    @PaymentStatusConverter() required PaymentStatus status,

    /// Sıradaki adım — gevşek enum, bkz. [PaymentNextAction].
    @PaymentNextActionConverter()
    @Default(PaymentNextAction.none)
    PaymentNextAction nextAction,
    required DateTime createdAt,

    /// Yalnız `nextAction == threeDs` iken dolu. Ödeme kesinleştikten sonra
    /// `null` döner — kullanıcı ikinci kez ödeme sayfasına gönderilmemelidir.
    String? redirectUrl,

    /// Başarısız denemenin kullanıcıya gösterilebilir Türkçe sebebi ("Kart
    /// limiti yetersiz."). Sağlayıcının ham hata kodu **dönmez**: müşteriye
    /// bir şey anlatmıyor ve teşhis günlükte.
    String? failureReason,
    DateTime? paidAt,
  }) = _SubscriptionPayment;

  const SubscriptionPayment._();

  factory SubscriptionPayment.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionPaymentFromJson(json);

  bool get isPaid => status == PaymentStatus.paid;

  /// Kullanıcıdan SMS kodu bekleniyor mu?
  bool get needsOtp => nextAction == PaymentNextAction.otp;

  /// 3-D Secure sayfasına yönlendirme gerekiyor mu?
  ///
  /// [redirectUrl] de aranıyor: adres olmadan "yönlendirileceksiniz" demek,
  /// açılacak bir sayfası olmayan bir düğme çizmektir.
  bool get needsRedirect =>
      nextAction == PaymentNextAction.threeDs && redirectUrl != null;

  /// Ödeme yoklanmalı mı? (`GET .../payments/{paymentId}`)
  ///
  /// Ödenmemiş her ödeme yoklanır — `unknown` durum da dahil, çünkü sözleşme
  /// büyüdüğünde (`failed`, `refunded`) eski istemcinin sonucu okumayı
  /// bırakması, ödemesi tamamlanmış aboneyi bekleme ekranında bırakırdı.
  ///
  /// **Yoklama aralığı en az 2 saniye olmalıdır** (sözleşme): daha sık
  /// yoklamak yalnız oran sınırını doldurur ve sınıra takılan istemci,
  /// başarılı olmuş bir ödemede başarısız ekranı gösterir.
  bool get shouldPoll => !isPaid;
}

/// `GET /subscriptions` / `GET /subscriptions/{id}` — abonelik kuralı.
@freezed
abstract class Subscription with _$Subscription {
  const factory Subscription({
    required int id,

    /// `pending` (talep, fiyatsız) | `awaiting_contract` | `awaiting_payment`
    /// | `active` | `paused` | `cancelled`.
    ///
    /// Ara iki durum 16.08.2026'da eklendi ve ayrı tutuldu çünkü ekranın
    /// kuracağı cümle ayrı: birinde abonenin yapacağı iş sözleşmeyi okuyup
    /// onaylamak, öbüründe ödemek. Tek bir `pending` altında toplansalardı
    /// istemci "ne bekleniyor" sorusunu yanıtlayamaz, abone de hiçbir şey
    /// yapmadan beklerdi.
    ///
    /// **Bilinmeyen durum çökertmez** (düz `String`); ekran onu nötr bir
    /// metinle gösterir ve eylem düğmelerini kapatır.
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

    /// `prepaid_monthly` (peşin). `account` (ay sonu cari) **kullanımdan
    /// kaldırıldı** (16.08.2026) ve yeni abonelikte dönmez; cutover öncesi
    /// kayıtlar o değerle duruyor.
    required String paymentMode,

    /// `fixed_list` | `daily_menu`.
    required String menuMode,
    @Default(<SubscriptionLine>[]) List<SubscriptionLine> lines,
    @Default(<SubscriptionDeliveryPoint>[])
    List<SubscriptionDeliveryPoint> deliveryPoints,

    /// Aboneliğin **tek-günlük istisnaları**: atlanan günler ve adedi
    /// değiştirilen günler.
    ///
    /// Yalnız **bugün ve sonrası** için girilmiş istisnalar döner. Geçmiş
    /// istisnalar tabloda durur (yalnız-ekleme) ama listeye girmez: abonenin
    /// ekranında üç aylık atlama geçmişi işe yaramaz ve yanıtı büyütür.
    @Default(<SubscriptionException>[]) List<SubscriptionException> exceptions,

    /// **Yürürlükteki dönemin** ödeme durumu; henüz fiyatlanmamış talepte
    /// `null`. Ödemenin geçmişi burada değildir.
    SubscriptionPaymentSummary? payment,

    /// Sözleşmenin durumu; sözleşme henüz üretilmediyse `null`. Metnin kendisi
    /// burada YOKTUR, imzalı bağlantının arkasındadır.
    SubscriptionContractSummary? contract,
    required DateTime createdAt,
  }) = _Subscription;

  const Subscription._();

  factory Subscription.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionFromJson(json);

  bool get isActive => status == 'active';

  bool get isPending => status == 'pending';

  /// Fiyat girildi, sözleşme bağlantısı gönderildi; abonenin yapacağı iş
  /// sözleşmeyi okuyup **onaylamak**.
  bool get isAwaitingContract => status == 'awaiting_contract';

  /// Sözleşme onaylandı; abonenin yapacağı iş ilk dönemi **ödemek**.
  bool get isAwaitingPayment => status == 'awaiting_payment';

  bool get isPaused => status == 'paused';

  bool get isCancelled => status == 'cancelled';

  /// Belirli bir servis gününün istisnası; o gün için istisna yoksa `null`.
  ///
  /// [serviceDate] `YYYY-AA-GG`. Gün-atlama arayüzü her hücre için bunu
  /// sorar; listeyi ekranda dolaşmak yerine tek yerde aramak, "atlandı"
  /// rozetinin üç ekranda üç ayrı biçimde hesaplanmasını önler.
  SubscriptionException? exceptionFor(String serviceDate) {
    for (final exception in exceptions) {
      if (exception.serviceDate == serviceDate) return exception;
    }
    return null;
  }

  /// Bir servis günü için geçerli porsiyon adedi; atlanan günde `0`.
  int quantityFor(String serviceDate) =>
      exceptionFor(serviceDate)?.effectiveQuantity(defaultQuantity) ??
      defaultQuantity;
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
