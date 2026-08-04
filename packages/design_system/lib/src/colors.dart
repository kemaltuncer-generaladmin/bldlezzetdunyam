/// BLD renk paleti — yer tutucu (BILINMEYENLER #11).
///
/// Değerler `0xAARRGGBB` biçiminde `int`'tir; Flutter `Color(...)`, web
/// `#RRGGBB` olarak tüketir. Doğrudan `dart:ui` kullanılmaz ki paket saf Dart kalsın.
library;

/// Ana marka rengi ve tonları. Turuncu — işletme sahibinin kararı (04.08).
abstract final class BldColors {
  // ── Marka: turuncu ────────────────────────────────────────────────────
  static const int brand50 = 0xFFFFF7ED;
  static const int brand100 = 0xFFFFEDD5;
  static const int brand200 = 0xFFFED7AA;
  static const int brand300 = 0xFFFDBA74;
  static const int brand400 = 0xFFFB923C;

  /// Birincil marka rengi. Butonlar, vurgular, logo yer tutucusu.
  static const int brand500 = 0xFFF97316;
  static const int brand600 = 0xFFEA580C;
  static const int brand700 = 0xFFC2410C;
  static const int brand800 = 0xFF9A3412;
  static const int brand900 = 0xFF7C2D12;

  // ── Nötr ──────────────────────────────────────────────────────────────
  static const int neutral0 = 0xFFFFFFFF;
  static const int neutral50 = 0xFFFAFAF9;
  static const int neutral100 = 0xFFF5F5F4;
  static const int neutral200 = 0xFFE7E5E4;
  static const int neutral400 = 0xFFA8A29E;
  static const int neutral600 = 0xFF57534E;
  static const int neutral800 = 0xFF292524;
  static const int neutral900 = 0xFF1C1917;

  // ── Durum renkleri ────────────────────────────────────────────────────
  static const int success = 0xFF16A34A;
  static const int warning = 0xFFCA8A04;
  static const int danger = 0xFFDC2626;
  static const int info = 0xFF2563EB;
}

/// Mutfak ekranı renkleri — `docs/05-mutfakapp.md` §3.
///
/// KDS uzaktan okunur; bu yüzden koyu zemin ve yüksek kontrast kullanılır,
/// müşteri arayüzünün açık temasından ayrışır.
abstract final class KdsColors {
  static const int background = 0xFF16130F;
  static const int surface = 0xFF241E18;
  static const int surfaceRaised = 0xFF332A21;
  static const int onSurface = 0xFFF5F5F4;
  static const int onSurfaceMuted = 0xFFA8A29E;

  /// Sipariş notu vurgusu — asla gizlenmez, kırmızı zeminde basılır.
  static const int noteBackground = 0xFF7F1D1D;
  static const int noteForeground = 0xFFFFF1F2;

  /// Adrese gönderim rozeti.
  static const int badgeDelivery = BldColors.brand500;

  /// Gel-al rozeti.
  static const int badgePickup = BldColors.neutral400;

  /// Bağlantı ve yazıcı göstergeleri (durum çubuğu).
  static const int statusOk = BldColors.success;
  static const int statusWarn = BldColors.warning;
  static const int statusDown = BldColors.danger;
}
