/// Tipografi ölçeği.
///
/// İki ayrı ölçek vardır çünkü iki farklı okuma mesafesi vardır: müşteri
/// telefonu elinde tutar, mutfak personeli ekrana bir metreden bakar.
library;

/// Müşteriye görünen yüzeyler (web, mobil).
abstract final class BldTextScale {
  static const double caption = 12;
  static const double body = 16;
  static const double title = 20;
  static const double heading = 28;
  static const double display = 40;
}

/// Mutfak ekranı — `docs/05-mutfakapp.md` §3'teki asgari boyutlar.
///
/// Bunlar tavsiye değil **alt sınırdır**: ürün adı en az 20, adet en az 28.
abstract final class KdsTextScale {
  /// Durum çubuğu, ikincil bilgi.
  static const double statusBar = 16;

  /// Sipariş numarası ve rozet.
  static const double orderNumber = 22;

  /// Ürün adı — asgari 20.
  static const double itemName = 24;

  /// Adet — asgari 28, kalın.
  static const double quantity = 32;

  /// Sütun başlığı (YENİ / HAZIRLANIYOR / HAZIR).
  static const double columnHeader = 26;

  /// Sipariş notu — gizlenmez, büyük basılır.
  static const double note = 22;
}
