/// Anlamsal rozet — durum, teslimat tipi, "abonelik" işareti.
///
/// Yumuşak tint zemin + koyu metin. Renkler artık beyaza karıştırılarak
/// TÜRETİLMİYOR: her ton için hem yüzey hem metin rolü palette tanımlı
/// (`successBg`/`successFg` …). Türetilen ton koyu temada çalışmıyordu —
/// koyu zeminde beyazla karıştırmak rengi zeminden AÇIK yapıyor, tint ise
/// zeminden bir adım açık olmalı, ondan altı adım değil.
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';

import '../theme/bld_semantic_colors.dart';

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

  /// Yalnız OUTLINE ikon (`Icons.*_outlined`). Dolu varyant 13 px'te siyah bir
  /// lekeye dönüyor ve rozetin metnini bastırıyor.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bld = context.bld;

    final (Color bg, Color fg) = switch (variant) {
      BldPillVariant.brand => (
        theme.colorScheme.secondaryContainer,
        theme.colorScheme.onSecondaryContainer,
      ),
      BldPillVariant.neutral => (
        theme.colorScheme.surfaceContainer,
        theme.colorScheme.onSurfaceVariant,
      ),
      BldPillVariant.info => (bld.infoBg, bld.infoFg),
      BldPillVariant.success => (bld.successBg, bld.successFg),
      BldPillVariant.warning => (bld.warningBg, bld.warningFg),
      BldPillVariant.danger => (bld.dangerBg, bld.dangerFg),
    };

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
          Text(label, style: theme.textTheme.labelMedium?.copyWith(color: fg)),
        ],
      ),
    );
  }
}
