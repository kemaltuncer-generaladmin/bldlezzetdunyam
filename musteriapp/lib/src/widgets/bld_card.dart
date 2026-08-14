/// Yüzey kartı — uygulamadaki her içerik bloğunun kabı.
///
/// Material `Card`'ın tonal yükseklik yıkaması yerine `BldElevation`'ın
/// yumuşak çift-katmanlı gölgesini kullanır; "jenerik Material" hissini kıran
/// temel karar budur. Dokunulabilir kart için `onTap` ver (ripple + odak
/// halkası).
///
/// **Yükseltme temaya göre değişir:** açık temada gölge, koyu temada bir
/// AÇIKLIK adımı ve üst kenarda 1 px ışık. Kararı `BldSurfaceLevel` veriyor,
/// çağrı yeri yalnız niyetini söylüyor.
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';

import '../theme/bld_theme.dart';
import 'bld_focus_ring.dart';

class BldCard extends StatelessWidget {
  const BldCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(BldSpacing.md),
    this.onTap,
    this.color,
    this.border,
    this.level = BldSurfaceLevel.card,
    this.radius = BldRadius.md,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Yüzey rengi. Verilmezse temanın o seviyedeki yüzeyi kullanılır —
  /// **ham `BldColors` sabiti geçmeyin**, koyu temada beyaz üstüne beyaz
  /// çıkar.
  final Color? color;

  final BorderSide? border;
  final BldSurfaceLevel level;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final surface = color ?? level.surfaceOf(context);

    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: borderRadius,
        boxShadow: level.shadowsOf(context),
        border: border != null
            ? Border.fromBorderSide(border!)
            : level.highlightOf(context),
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

    // Odak halkası yalnız dokunulabilir kartta: dokunulamayan bir kutunun
    // çevresinde halka, klavye odağının orada durabildiğini söyleyerek
    // yalan söyler.
    if (onTap == null) return decorated;
    return BldFocusRing(radius: radius, child: decorated);
  }
}
