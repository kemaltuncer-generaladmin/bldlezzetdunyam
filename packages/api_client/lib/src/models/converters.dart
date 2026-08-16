/// `bld_core` enum'ları ile JSON arasındaki çeviriciler.
///
/// **Katılık politikası** — `docs/03-api-sozlesmesi.md` §1.4:
/// - `OrderStatus` ve `DeliveryType` sözleşmede "sabit, değiştirilmez" ilan
///   edildi. Bilinmeyen değer gelirse bu bir sunucu hatasıdır; sessizce yutmak
///   yerine gürültülü hata veririz.
/// - `PaymentMethod` ve `PaymentStatus` ileride büyüyebilir (sanal POS gelince
///   `failed`/`refunded`). Bunlarda bilinmeyen değer `unknown`'a düşer ve
///   uygulama çalışmaya devam eder.
library;

import 'package:bld_core/bld_core.dart';
import 'package:json_annotation/json_annotation.dart';

/// Sözleşmeye aykırı bir enum değeri geldiğinde atılır.
class UnknownEnumValueException implements Exception {
  const UnknownEnumValueException(this.enumName, this.value);

  final String enumName;
  final String value;

  @override
  String toString() =>
      'Sözleşme dışı $enumName değeri: "$value". Sunucu ile istemci sürümleri '
      'uyuşmuyor olabilir.';
}

class OrderStatusConverter implements JsonConverter<OrderStatus, String> {
  const OrderStatusConverter();

  @override
  OrderStatus fromJson(String json) =>
      OrderStatus.tryParse(json) ??
      (throw UnknownEnumValueException('OrderStatus', json));

  @override
  String toJson(OrderStatus object) => object.wireName;
}

class DeliveryTypeConverter implements JsonConverter<DeliveryType, String> {
  const DeliveryTypeConverter();

  @override
  DeliveryType fromJson(String json) =>
      DeliveryType.tryParse(json) ??
      (throw UnknownEnumValueException('DeliveryType', json));

  @override
  String toJson(DeliveryType object) => object.wireName;
}

/// Ödeme yöntemi — `docs/03-api-sozlesmesi.md` §4.
///
/// Faz 1'de `online` hiçbir vitrinin `payment_methods` listesinde bulunmaz;
/// enum'da durur çünkü sanal POS gelince yalnızca sunucu tarafı değişecek.
enum PaymentMethod {
  online('online'),
  cash('cash'),
  account('account'),

  /// Sunucu bizim bilmediğimiz bir yöntem gönderdi. İstemci bunu gösterir ama
  /// seçtiremez; sipariş isteğinde **kullanılamaz**.
  unknown('');

  const PaymentMethod(this.wireName);

  final String wireName;

  static PaymentMethod parse(String value) {
    for (final method in PaymentMethod.values) {
      if (method != unknown && method.wireName == value) return method;
    }
    return unknown;
  }

  bool get isSelectable => this != unknown;
}

const Map<PaymentMethod, String> paymentMethodLabelsTr = {
  PaymentMethod.online: 'Online ödeme',
  PaymentMethod.cash: 'Kapıda ödeme',
  PaymentMethod.account: 'Cari hesap',
  PaymentMethod.unknown: 'Bilinmeyen yöntem',
};

class PaymentMethodConverter implements JsonConverter<PaymentMethod, String> {
  const PaymentMethodConverter();

  @override
  PaymentMethod fromJson(String json) => PaymentMethod.parse(json);

  @override
  String toJson(PaymentMethod object) {
    assert(
      object.isSelectable,
      'PaymentMethod.unknown sunucuya gönderilemez — bu bir istemci hatasıdır.',
    );
    return object.wireName;
  }
}

/// Ödeme durumu. Faz 1'de yalnızca `pending` ve `paid` üretilir.
enum PaymentStatus {
  pending('pending'),
  paid('paid'),

  /// Sözleşme büyüdüğünde (`failed`, `refunded`) eski istemciler buraya düşer
  /// ve çökmez — `docs/openapi.yaml` `PaymentStatus` açıklamasına bakın.
  unknown('');

  const PaymentStatus(this.wireName);

  final String wireName;

  static PaymentStatus parse(String value) {
    for (final status in PaymentStatus.values) {
      if (status != unknown && status.wireName == value) return status;
    }
    return unknown;
  }
}

const Map<PaymentStatus, String> paymentStatusLabelsTr = {
  PaymentStatus.pending: 'Bekliyor',
  PaymentStatus.paid: 'Ödendi',
  PaymentStatus.unknown: 'Belirsiz',
};

class PaymentStatusConverter implements JsonConverter<PaymentStatus, String> {
  const PaymentStatusConverter();

  @override
  PaymentStatus fromJson(String json) => PaymentStatus.parse(json);

  @override
  String toJson(PaymentStatus object) => object.wireName;
}

/// Ödemenin kesinleşmesi için sıradaki adım — `docs/openapi.yaml`
/// `PaymentNextAction`.
///
/// **Gevşek enum, bilerek.** Sözleşme buraya ileride yeni adım tipleri
/// ekleneceğini (`app2app`, `biometric`) ve ek değerin kırıcı sayılmadığını
/// yazıyor.
///
/// Bilinmeyen değer [unknown]'a düşer ve **[none] SAYILMAZ**. Ayrım burada
/// hayati: `none` saymak, atlanmış bir doğrulama adımını "ödeme bitti" diye
/// göstermek olurdu. Bilinmeyen adımı gören istemcinin doğru davranışı
/// kullanıcıya güncelleme gerektiğini söylemek ve sonucu
/// `GET /subscriptions/{id}/payments/{paymentId}` ile yoklamaktır.
enum PaymentNextAction {
  /// Ek adım yok; sonuç `status` alanındadır. Kesim: `cash` siparişte ve
  /// ödeme akışı hiç doğmamışken sunucu `null` gönderir, o da buraya düşer.
  none('none'),

  /// Kullanıcıdan SMS kodu alınır ve `.../confirm` ucuna gönderilir.
  otp('otp'),

  /// `redirect_url` açılır; dönüşte ödeme yoklanır.
  threeDs('three_ds'),

  /// Sözleşmeye sonradan eklenmiş, bu istemcinin bilmediği bir adım.
  ///
  /// [wireName] `null`: bu alan **yalnızca okunur**, istemci hiçbir uca geri
  /// göndermez.
  unknown(null);

  const PaymentNextAction(this.wireName);

  /// Sözleşmedeki karşılığı; [unknown] için `null`.
  final String? wireName;

  /// `null` gövde değeri [none] demektir — "adım yok".
  static PaymentNextAction parse(String? value) {
    if (value == null || value.isEmpty) return none;
    for (final action in PaymentNextAction.values) {
      if (action.wireName == value) return action;
    }
    return unknown;
  }

  /// Ödemenin ilerlemesi için kullanıcıdan bir şey isteniyor mu?
  ///
  /// [unknown] burada `true`'dur: ne istendiğini bilmesek de bir şey
  /// istendiğini biliyoruz ve ekranı "bitti" diye kapatmamalıyız.
  bool get requiresCustomerStep => this != none;

  /// Adımı bu istemci uygulayabiliyor mu? [unknown] için `false` — ekran
  /// kullanıcıya uygulamayı güncellemesini söyler.
  bool get isSupported => this != unknown;
}

const Map<PaymentNextAction, String> paymentNextActionLabelsTr = {
  PaymentNextAction.none: '',
  PaymentNextAction.otp: 'SMS kodunu girin.',
  PaymentNextAction.threeDs:
      'Bankanızın doğrulama sayfasına yönlendirileceksiniz.',
  PaymentNextAction.unknown:
      'Bu ödeme adımı için uygulamayı güncellemeniz gerekiyor.',
};

class PaymentNextActionConverter
    implements JsonConverter<PaymentNextAction, String?> {
  const PaymentNextActionConverter();

  @override
  PaymentNextAction fromJson(String? json) => PaymentNextAction.parse(json);

  @override
  String? toJson(PaymentNextAction object) => object.wireName;
}

/// Teslim süresi tahmininin nereden geldiği — `Location.eta`.
///
/// **Neden gevşek (bilinmeyen değer çökertmez):** bu alan yalnızca kullanıcıya
/// hangi dille konuşacağımızı seçtirir, iş kuralı taşımaz. Sunucu ileride
/// üçüncü bir kaynak eklerse (ör. harita servisi) eski istemcinin sipariş
/// akışını durdurmasının anlamı yok; en temkinli dile düşer.
enum EtaSource {
  /// Gerçekleşmiş siparişlerin sürelerinden ölçüldü.
  measured('measured'),

  /// Panelde elle girilen başlangıç değeri; henüz ölçülmedi.
  configured('configured'),

  /// Sözleşmede olmayan bir kaynak. [isMeasured] `false`'tur — ölçülmemiş gibi
  /// davranmak, ölçülmüş gibi davranmaktan güvenlidir.
  unknown('');

  const EtaSource(this.wireName);

  final String wireName;

  static EtaSource parse(String value) {
    for (final source in EtaSource.values) {
      if (source != unknown && source.wireName == value) return source;
    }
    return unknown;
  }

  /// Tahmin gerçek verilerden mi hesaplandı? Yalnızca bu doğruyken kesin
  /// konuşulur.
  bool get isMeasured => this == measured;
}

class EtaSourceConverter implements JsonConverter<EtaSource, String> {
  const EtaSourceConverter();

  @override
  EtaSource fromJson(String json) => EtaSource.parse(json);

  @override
  String toJson(EtaSource object) => object.wireName;
}

/// Fiş tipi — `docs/05-mutfakapp.md` §5.3.
///
/// İki tip vardır. Teslim fişi, öğrenci kanalıyla birlikte iptal edilmiştir.
enum ReceiptType {
  mutfak('mutfak'),
  musteri('musteri'),

  /// Kurye fişi (K-14): ad + telefon + adres + tahsil edilecek tutar.
  ///
  /// Yalnız `delivery` siparişte basılır — gel-al'da kurye yok.
  kurye('kurye');

  const ReceiptType(this.wireName);

  final String wireName;

  static ReceiptType? tryParse(String value) {
    for (final type in ReceiptType.values) {
      if (type.wireName == value) return type;
    }
    return null;
  }
}

class ReceiptTypeConverter implements JsonConverter<ReceiptType, String> {
  const ReceiptTypeConverter();

  @override
  ReceiptType fromJson(String json) =>
      ReceiptType.tryParse(json) ??
      (throw UnknownEnumValueException('ReceiptType', json));

  @override
  String toJson(ReceiptType object) => object.wireName;
}
