/// İskelet (shimmer) yükleme göstergeleri.
///
/// NEDEN dönen halka DEĞİL: boş bir spinner "bir şey yükleniyor" der ama
/// ekranın nasıl dolacağını göstermez. İçeriğin şeklini taklit eden soluk
/// bloklar, algılanan bekleme süresini kısaltır ve düzen sıçramasını önler.
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';

import '../theme/bld_theme.dart';

/// Alt ağacın üzerinden geçen açık-koyu parıltı. Soluk blokları sarmalayın.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              colors: [
                bldColor(BldColors.neutral100),
                bldColor(BldColors.neutral200),
                bldColor(BldColors.neutral100),
              ],
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
        color: bldColor(BldColors.neutral100),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Menü/ürün kartı iskeleti (görsel + iki satır).
class MenuCardSkeleton extends StatelessWidget {
  const MenuCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(
            width: double.infinity,
            height: 116,
            radius: BldRadius.md,
          ),
          const SizedBox(height: BldSpacing.sm),
          const SkeletonBox(width: 120, height: 14),
          const SizedBox(height: BldSpacing.xs),
          const SkeletonBox(width: 64, height: 14),
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: BldSpacing.sm),
              child: Row(
                children: [
                  const SkeletonBox(width: 48, height: 48, radius: BldRadius.md),
                  const SizedBox(width: BldSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonBox(width: 160, height: 14),
                        SizedBox(height: BldSpacing.sm),
                        SkeletonBox(width: 96, height: 12),
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
