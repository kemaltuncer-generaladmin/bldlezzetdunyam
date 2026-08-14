/// Aralık ve köşe yarıçapı belirteçleri. 4 px tabanlı ölçek.
library;

abstract final class BldSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Köşe yarıçapı.
///
/// Beş adım var ve her adımın bir İŞİ var — "biraz daha yuvarlak" diye ara
/// değer eklenmez, çünkü iki bileşen 12 ve 14 kullandığında fark ölçülemez
/// ama tutarsızlık görünür.
abstract final class BldRadius {
  /// Rozet, küçük etiket.
  static const double xs = 6;

  /// Buton, form alanı.
  static const double sm = 10;

  /// Kart, liste satırı, görsel.
  static const double md = 14;

  /// Bottom sheet, diyalog.
  static const double lg = 20;

  /// Tam yuvarlak (çip, avatar, adet sayacı).
  static const double pill = 9999;

  /// İç içe köşelerin kuralı: çocuk = ebeveyn − 4, taban 6.
  ///
  /// **Neden formül, sabit değil:** eş merkezli iki yuvarlak köşe aynı
  /// yarıçapı kullandığında iç öğe dışarıdakine "yapışık" görünür; fark 4 px
  /// olduğunda iki kenar arasındaki boşluk sabit kalır. 6'nın altına inmek
  /// köşeyi düz gösterdiği için taban orada.
  static double nested(double parent) {
    final double child = parent - 4;
    return child < xs ? xs : child;
  }
}
