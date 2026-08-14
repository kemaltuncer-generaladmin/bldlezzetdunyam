/// Klavye odağı halkası — 2 px halka + 2 px boşluk, kutunun DIŞINDA.
///
/// **Neden ayrı bir bileşen:** `ButtonStyle` yalnız butonun kendi kenarını
/// verebiliyor; ofsetli bir halka kutunun dışına boyanmak zorunda ve bunu
/// yapabilen tek şey gölge. Bu sarmalayıcı, odaklanabilir HERHANGİ bir alt
/// ağacın (kart, liste satırı, özel dokunma hedefi) çevresine o halkayı
/// çiziyor.
///
/// **Neden `Focus` alt ağacı dinliyor:** `Focus.onFocusChange`, düğümün
/// KENDİSİ ya da bir ALTI odaklandığında tetikleniyor. Böylece sarmalayıcı
/// odağı çalmadan (`canRequestFocus: false`, `skipTraversal: true`) içerideki
/// gerçek odak hedefini izleyebiliyor — sekme sırası hiç değişmiyor.
///
/// **Neden hiç gerekli:** Material'ın varsayılan odağı yüzeye düşük alfalı
/// bir yıkama sürüyor ve marka zemininde neredeyse görünmüyor. iPad'de
/// fiziksel klavye gerçek bir kullanım biçimi; klavyeyle gezen kullanıcı
/// nerede olduğunu göremiyordu.
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';

import '../theme/bld_semantic_colors.dart';
import '../theme/bld_theme.dart';

class BldFocusRing extends StatefulWidget {
  const BldFocusRing({
    super.key,
    required this.child,
    this.radius = BldRadius.md,
    this.gapColor,
    this.enabled = true,
  });

  final Widget child;

  /// Halkanın yarıçapı — sarmalanan yüzeyinkiyle AYNI olmalı, yoksa halka
  /// köşede yüzeyin dışına taşar.
  final double radius;

  /// Halka ile yüzey arasındaki 2 px boşluğun rengi.
  ///
  /// Boşluk aslında bir renk değil, ARKADAKİ zeminin görünmesidir; Flutter'da
  /// bunu ancak zeminin rengini boyayarak taklit edebiliyoruz. Varsayılan
  /// sayfa zemini; kartın İÇİNDEKİ bir satır için kartın rengi verilmeli.
  final Color? gapColor;

  /// Dokunmatik-yalnız yüzeylerde kapatılabilir.
  final bool enabled;

  @override
  State<BldFocusRing> createState() => _BldFocusRingState();
}

class _BldFocusRingState extends State<BldFocusRing> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final bld = context.bld;
    final show = widget.enabled && _focused;

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (hasFocus) {
        if (hasFocus == _focused) return;
        setState(() => _focused = hasFocus);
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: show
              ? bldFocusRing(
                  ring: bld.focusRing,
                  gap: widget.gapColor ?? bld.canvas,
                )
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}
