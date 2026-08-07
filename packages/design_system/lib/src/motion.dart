/// Hareket belirteçleri — süre ve eğri kimlikleri.
///
/// **Neden ms `int` ve enum, `Duration`/`Curves` değil:** paket saf Dart
/// kalmalı (Flutter importu yok). Flutter tema katmanı (`bldDuration`,
/// `bldCurve`) bunları `Duration`/`Curves`'e çevirir. Tek ölçek müşteri
/// yüzeyi içindir; mutfak (KDS) ekranı hareket kullanmaz.
library;

abstract final class BldMotion {
  /// Basış geri bildirimi, chip seçimi.
  static const int fastMs = 120;

  /// Standart giriş/çıkış, liste öğesi belirişi.
  static const int baseMs = 220;

  /// Vurgulu geçiş, adım çubuğu dolumu.
  static const int slowMs = 320;

  /// Sayfa (route) geçişi.
  static const int pageMs = 280;
}

/// Eğri kimliği — uygulama katmanı `Curves`'e çevirir.
enum BldEase {
  /// Simetrik giriş-çıkış (standart hareket).
  standard,

  /// Hızlı çıkış, yumuşak yerleşme (vurgulu eylem).
  emphasized,

  /// Yavaşlayarak yerleşen giriş (yeni içerik).
  decelerate,
}
