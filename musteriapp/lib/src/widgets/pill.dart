/// Anlamsal pill/rozet — durum, teslimat tipi, "abonelik" işareti.
///
/// `status_views.BldBadge` katı zemin + beyaz metin veriyor; bu ise yumuşak
/// tint + koyu metinli, isteğe bağlı ikonlu daha sakin bir rozet — sipariş
/// kartları ve abonelik rozetleri için. Renk paletten türetilir (yeni renk
/// eklenmez): tint = anlamsal renk düşük alfada beyaza karışmış.
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';

import '../theme/bld_theme.dart';

enum BldPillVariant { brand, neutral, info, success, warning, danger }

class BldPill extends StatelessWidget {
  const BldPill({
    super.key,
    required this.label,
    this.variant = BldPillVariant.neutral,
    this.icon,
  });

  final String label;
  final BldPillVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors(variant);
    return Container(
      padding: EdgeInsets.fromLTRB(
        icon != null ? BldSpacing.sm : BldSpacing.md - 4,
        3,
        BldSpacing.md - 4,
        3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(BldRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: BldTextScale.caption,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Tint zemin + koyu metin. Marka/nötr için hazır tonlar; anlamsal renkler
  /// için renk beyaza %14 karıştırılır (paletten yeni renk eklemeden).
  (Color, Color) _colors(BldPillVariant variant) {
    switch (variant) {
      case BldPillVariant.brand:
        return (bldColor(BldColors.brand100), bldColor(BldColors.brand700));
      case BldPillVariant.neutral:
        return (bldColor(BldColors.neutral100), bldColor(BldColors.neutral600));
      case BldPillVariant.info:
        return (_tint(BldColors.info), bldColor(BldColors.info));
      case BldPillVariant.success:
        return (_tint(BldColors.success), bldColor(BldColors.success));
      case BldPillVariant.warning:
        return (_tint(BldColors.warning), bldColor(BldColors.warning));
      case BldPillVariant.danger:
        return (_tint(BldColors.danger), bldColor(BldColors.danger));
    }
  }

  Color _tint(int token) => Color.alphaBlend(
    bldColor(token).withValues(alpha: 0.14),
    bldColor(BldColors.neutral0),
  );
}
