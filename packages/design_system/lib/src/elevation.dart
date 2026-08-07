/// Gölge belirteçleri — yumuşak, katmanlı.
///
/// **Neden veri, `BoxShadow` değil:** paket saf Dart kalmalı (`dart:ui` yok)
/// ki aynı değerler `website/`'in Tailwind gölgelerine de üretilebilsin.
/// Flutter tema katmanı (`bldShadow`) bu katmanları `BoxShadow`'a çevirir.
/// Renk her katmanda `BldColors.neutral900` üzerine `alpha` (0–255) uygulanır
/// — sıcak-koyu gri, saf siyah DEĞİL; saf siyah gölge ucuz/sert durur.
library;

/// Tek gölge katmanı.
class BldShadowLayer {
  const BldShadowLayer({
    this.dx = 0,
    required this.dy,
    required this.blur,
    this.spread = 0,
    required this.alpha,
  });

  final double dx;
  final double dy;
  final double blur;
  final double spread;

  /// `BldColors.neutral900` üzerine uygulanacak opaklık (0–255).
  final int alpha;
}

/// İki katmanlı yumuşak gölgeler: yakın temas + yayılan derinlik.
abstract final class BldElevation {
  /// Kartlar, liste satırları — zemine hafif oturur.
  static const List<BldShadowLayer> card = [
    BldShadowLayer(dy: 1, blur: 2, alpha: 10),
    BldShadowLayer(dy: 6, blur: 16, alpha: 18),
  ];

  /// Yükseltilmiş yüzeyler — seçili kart, sabit alt çubuk, FAB.
  static const List<BldShadowLayer> raised = [
    BldShadowLayer(dy: 2, blur: 6, alpha: 14),
    BldShadowLayer(dy: 10, blur: 24, alpha: 26),
  ];

  /// Katman üstü — bottom sheet, diyalog, açılır menü.
  static const List<BldShadowLayer> overlay = [
    BldShadowLayer(dy: 4, blur: 12, alpha: 20),
    BldShadowLayer(dy: 18, blur: 36, alpha: 38),
  ];
}
