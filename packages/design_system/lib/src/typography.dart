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

/// Yazı tipi aileleri.
///
/// Türkçe tam destek (Latin Extended-A: ş/ğ/İ/ı/ç/ö/ü) şart; ikisi de OFL.
/// **Asset olarak bundle edilir** — çalışma anında Google Fonts indirme YOK;
/// aksi çevrimdışı menü kararıyla çelişirdi. Aileler tek yerde tanımlıdır ki
/// marka fontu değişince tek satır güncellensin.
abstract final class BldFontFamily {
  /// Başlık/marka — geometrik-humanist, kurumsal-modern.
  static const String display = 'Sora';

  /// Gövde/arayüz — yüksek okunabilirlik, tabular rakam (para hizası).
  static const String body = 'Inter';

  /// Display metinlerde sıkı harf aralığı (başlıklar toplu görünsün).
  static const double displayLetterSpacing = -0.5;
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
