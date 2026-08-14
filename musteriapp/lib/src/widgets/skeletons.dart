/// İskelet (shimmer) yükleme göstergeleri.
///
/// NEDEN dönen halka DEĞİL: boş bir spinner "bir şey yükleniyor" der ama
/// ekranın nasıl dolacağını göstermez. İçeriğin şeklini taklit eden soluk
/// bloklar, algılanan bekleme süresini kısaltır ve içerik gelince düzen
/// sıçramaz. İskelet GERÇEK düzenin kutu sayısını ve yüksekliklerini
/// yansıtmak zorundadır; yansıtmayan iskelet, sıçramayı önlemek yerine iki
/// kez sıçratır.
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';

import '../theme/bld_semantic_colors.dart';
import '../theme/bld_theme.dart';

/// Alt ağacın üzerinden geçen açık-koyu parıltı. Soluk blokları sarmalayın.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: bldDuration(_shimmerPeriodMs),
  );

  /// Parıltının bir turu. Marka kılavuzu: 1200 ms.
  static const int _shimmerPeriodMs = 1200;

  /// Hareket azaltma isteği onurlandırılır: sürekli tekrar eden bir parıltı,
  /// vestibüler duyarlılığı olan kullanıcı için bekleme boyunca kesintisiz
  /// bir uyarandır. Sabit taban rengi aynı bilgiyi taşıyor.
  bool _reducedMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Denetleyici `build` içinde değil BURADA başlatılıp durduruluyor: build
    // yan etkisiz kalmalı, yoksa aynı karede iki kez çizim isteyen bir döngü
    // kurulabiliyor.
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bld = context.bld;

    if (_reducedMotion) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final dx = bounds.width * (_controller.value * 2 - 1);
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [bld.skeletonBase, bld.skeletonShine, bld.skeletonBase],
              stops: const [0.35, 0.5, 0.65],
              transform: _SlideGradient(dx),
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

/// Gradyanı yatay kaydıran dönüşüm.
class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.dx);

  final double dx;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(dx, 0, 0);
}

/// Soluk yuvarlatılmış blok — iskelet yapı taşı.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = BldRadius.sm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.bld.skeletonBase,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Menü/ürün kartı iskeleti.
///
/// Kutular gerçek kartı taklit ediyor: 4:3 görsel + `title` (17/24) satırı +
/// `money-md` (17/24) fiyatı.
class MenuCardSkeleton extends StatelessWidget {
  const MenuCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AspectRatio(
            aspectRatio: 4 / 3,
            child: SkeletonBox(
              width: double.infinity,
              height: double.infinity,
              radius: BldRadius.md,
            ),
          ),
          const SizedBox(height: BldSpacing.sm),
          const SkeletonBox(width: 120, height: BldTextScale.titleLineHeight),
          const SizedBox(height: BldSpacing.xs),
          const SkeletonBox(width: 72, height: BldTextScale.moneyMdLineHeight),
        ],
      ),
    );
  }
}

/// Liste satırı iskeleti (dikey liste ekranları için).
class ListRowSkeleton extends StatelessWidget {
  const ListRowSkeleton({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        children: [
          for (var i = 0; i < count; i++)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: BldSpacing.sm),
              child: Row(
                children: [
                  // Sepet/sipariş satırı görseli 1:1 ve 56 px.
                  SkeletonBox(width: 56, height: 56, radius: BldRadius.md),
                  SizedBox(width: BldSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(
                          width: 160,
                          height: BldTextScale.titleLineHeight,
                        ),
                        SizedBox(height: BldSpacing.sm),
                        SkeletonBox(
                          width: 96,
                          height: BldTextScale.bodySmLineHeight,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
