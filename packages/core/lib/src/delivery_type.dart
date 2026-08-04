/// Teslimat tipi — `docs/03-api-sozlesmesi.md` §4.
///
/// Sipariş çeşitliliğini ifade eden **tek** boyut budur. Kanal kavramı
/// (öğrenci / kurum içi) iptal edilmiştir, bkz. `docs/00-genel-bakis.md` §4.
library;

enum DeliveryType {
  delivery('delivery'),
  pickup('pickup');

  const DeliveryType(this.wireName);

  final String wireName;

  static DeliveryType? tryParse(String value) {
    for (final type in DeliveryType.values) {
      if (type.wireName == value) return type;
    }
    return null;
  }

  /// Teslimat ücreti bu siparişe eklenir mi?
  ///
  /// Yalnızca gösterim içindir — tutarın kendisi her zaman sunucudan gelir.
  bool get hasDeliveryFee => this == delivery;

  /// Adres alanı zorunlu mu?
  bool get requiresAddress => this == delivery;
}

/// KDS kartındaki rozet metni — `docs/05-mutfakapp.md` §3.
const Map<DeliveryType, String> deliveryTypeBadgeTr = {
  DeliveryType.delivery: 'ADR',
  DeliveryType.pickup: 'GELAL',
};

/// Arayüzde gösterilecek tam ad.
const Map<DeliveryType, String> deliveryTypeLabelsTr = {
  DeliveryType.delivery: 'Adrese gönderim',
  DeliveryType.pickup: 'Gel-al',
};
