/// Gölgeli beyaz yüzey kartı.
///
/// Material `Card`'ın tonal yükseklik yıkaması yerine `BldElevation`'ın
/// yumuşak çift-katmanlı gölgesini kullanır — bu, "jenerik Material" hissini
/// kıran temel karardır. Dokunulabilir kart için `onTap` ver (ripple + basış).
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';

import '../theme/bld_theme.dart';

class BldCard extends StatelessWidget {
  const BldCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(BldSpacing.md),
    this.onTap,
    this.color = BldColors.neutral0,
    this.border,
    this.elevation = BldElevation.card,
    this.radius = BldRadius.md,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final int color;
  final BorderSide? border;
  final List<BldShadowLayer> elevation;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bldColor(color),
        borderRadius: borderRadius,
        boxShadow: bldShadow(elevation),
        border: border != null ? Border.fromBorderSide(border!) : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
