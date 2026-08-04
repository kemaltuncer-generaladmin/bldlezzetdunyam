/// Sipariş durum makinesi — `docs/02-veri-modeli.md` §3.
///
/// Bu, sözleşmenin **istemci tarafı kopyasıdır**. Kararı her zaman sunucu verir;
/// buradaki matris yalnızca kullanıcıya geçersiz bir buton göstermemek içindir.
/// Sunucu `422 INVALID_TRANSITION` dönerse istemci haksızdır, sunucu değil.
library;

import 'delivery_type.dart';

/// Sözleşmedeki 7 sabit durum kodu. Değerler API ile birebir aynıdır.
enum OrderStatus {
  yeni('yeni'),
  onaylandi('onaylandi'),
  hazirlaniyor('hazirlaniyor'),
  hazir('hazir'),
  yolda('yolda'),
  teslimEdildi('teslim_edildi'),
  iptal('iptal');

  const OrderStatus(this.wireName);

  /// API'de kullanılan değer. Dart adı camelCase olsa da tel üzerindeki ad budur.
  final String wireName;

  /// Bilinmeyen değerde `null` döner — sözleşmeye yeni durum eklenirse istemci
  /// çökmez (bkz. `docs/03-api-sozlesmesi.md` §1.4).
  static OrderStatus? tryParse(String value) {
    for (final status in OrderStatus.values) {
      if (status.wireName == value) return status;
    }
    return null;
  }

  /// Daha ileri gidilemeyen durumlar.
  bool get isTerminal => this == teslimEdildi || this == iptal;

  /// Mutfak ekranında "aktif" sayılan, yani ekranda kart olarak duran durumlar.
  bool get isActiveInKitchen => !isTerminal;
}

/// Geçiş matrisi. `docs/02-veri-modeli.md` §3'teki tablonun birebir karşılığı.
///
/// `hazir` durumundan çıkış `delivery_type`'a bağlı olduğu için bu harita ham
/// haliyle kullanılmaz — [OrderStatusMachine.allowedFrom] üzerinden erişilir.
const Map<OrderStatus, Set<OrderStatus>> _transitions = {
  OrderStatus.yeni: {OrderStatus.onaylandi, OrderStatus.iptal},
  OrderStatus.onaylandi: {OrderStatus.hazirlaniyor, OrderStatus.iptal},
  OrderStatus.hazirlaniyor: {OrderStatus.hazir, OrderStatus.iptal},
  OrderStatus.hazir: {
    OrderStatus.yolda,
    OrderStatus.teslimEdildi,
    OrderStatus.iptal,
  },
  OrderStatus.yolda: {OrderStatus.teslimEdildi, OrderStatus.iptal},
  OrderStatus.teslimEdildi: {},
  OrderStatus.iptal: {},
};

/// Durum geçişlerini doğrular.
abstract final class OrderStatusMachine {
  /// [from] durumundan, [deliveryType] teslimat tipiyle gidilebilecek durumlar.
  ///
  /// `hazir`'dan çıkış teslimat tipine bağlıdır: adrese gönderimde `yolda`,
  /// gel-al'da doğrudan `teslim_edildi`. İkisi birden asla açık değildir.
  static Set<OrderStatus> allowedFrom(
    OrderStatus from,
    DeliveryType deliveryType,
  ) {
    final base = _transitions[from]!;
    if (from != OrderStatus.hazir) return base;

    return switch (deliveryType) {
      DeliveryType.delivery => base.difference({OrderStatus.teslimEdildi}),
      DeliveryType.pickup => base.difference({OrderStatus.yolda}),
    };
  }

  /// [from] → [to] geçişi sözleşmeye uygun mu?
  static bool canTransition(
    OrderStatus from,
    OrderStatus to,
    DeliveryType deliveryType,
  ) => allowedFrom(from, deliveryType).contains(to);

  /// Mutfak ekranında gösterilecek **tek** ileri adım.
  ///
  /// İptal bir ilerleme değil, yan yoldur; bu yüzden döndürülmez.
  /// Terminal durumlarda `null` döner (buton gösterilmez).
  static OrderStatus? nextForward(
    OrderStatus from,
    DeliveryType deliveryType,
  ) => switch (from) {
    OrderStatus.yeni => OrderStatus.onaylandi,
    OrderStatus.onaylandi => OrderStatus.hazirlaniyor,
    OrderStatus.hazirlaniyor => OrderStatus.hazir,
    OrderStatus.hazir => deliveryType == DeliveryType.delivery
        ? OrderStatus.yolda
        : OrderStatus.teslimEdildi,
    OrderStatus.yolda => OrderStatus.teslimEdildi,
    OrderStatus.teslimEdildi || OrderStatus.iptal => null,
  };

  /// Müşteri bu siparişi iptal edebilir mi?
  ///
  /// Sözleşme: yalnızca `yeni` ve `onaylandi` (`docs/03` §4). Mutfak personelinin
  /// iptal yetkisi bundan farklıdır ve sunucuda ayrıca denetlenir.
  static bool customerCanCancel(OrderStatus current) =>
      current == OrderStatus.yeni || current == OrderStatus.onaylandi;
}

/// Arayüzde gösterilecek Türkçe durum adları.
///
/// Sabit metinler normalde `l10n` üzerinden gelir (`AGENTS.md` §4); bu harita
/// tek dilli Faz 1 için `l10n` anahtarlarının karşılığıdır ve l10n kurulunca
/// oradan beslenecektir.
const Map<OrderStatus, String> orderStatusLabelsTr = {
  OrderStatus.yeni: 'Yeni',
  OrderStatus.onaylandi: 'Onaylandı',
  OrderStatus.hazirlaniyor: 'Hazırlanıyor',
  OrderStatus.hazir: 'Hazır',
  OrderStatus.yolda: 'Yolda',
  OrderStatus.teslimEdildi: 'Teslim edildi',
  OrderStatus.iptal: 'İptal',
};
