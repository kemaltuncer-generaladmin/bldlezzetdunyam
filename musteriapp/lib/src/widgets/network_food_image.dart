/// Yemek görseli sarmalayıcı — sabit oran, yer tutucu, fotoğraf iç halkası.
///
/// Ana sayfa, menü ve ürün detayındaki tekrarlı `Image.network + errorBuilder`
/// bloklarını tek yerde toplar.
///
/// **Fotoğrafın 1 px iç halkası:** beyaz tabaklı bir yemek fotoğrafı beyaz
/// kartın içinde eriyor ve kartın kenarı kayboluyordu. Halka sınırı geri
/// veriyor. Fotoğrafa marka rengi overlay ATILMAZ — yemeğin kendi rengi
/// ürünün kendisidir; `overlay` yalnız alt köşeye metin basılacaksa açılır ve
/// o da nötr bir koyulaştırmadır.
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';

import '../theme/bld_semantic_colors.dart';
import 'wheat_arc.dart';

class NetworkFoodImage extends StatelessWidget {
  const NetworkFoodImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.aspectRatio = 4 / 3,
    this.radius = BldRadius.md,
    this.overlay = false,
  });

  final String? url;
  final double? width;
  final double? height;

  /// `width` ve `height` verilmediğinde kullanılır.
  final double aspectRatio;
  final double radius;

  /// Alt köşeye metin basılabilsin diye koyulaşan gradyan ekler.
  final bool overlay;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);

    Widget image = url == null
        ? const WheatArcPlaceholder()
        : Image.network(
            url!,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const WheatArcPlaceholder(),
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const WheatArcPlaceholder(loading: true),
          );

    Widget content = Stack(
      fit: StackFit.passthrough,
      children: [
        ClipRRect(
          borderRadius: borderRadius,
          child: overlay
              ? Stack(
                  fit: StackFit.passthrough,
                  children: [
                    image,
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.center,
                            colors: [
                              const Color(
                                BldColors.neutral950,
                              ).withValues(alpha: 0.55),
                              const Color(
                                BldColors.neutral950,
                              ).withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : image,
        ),
        // Halka görselin ÜSTÜNE çiziliyor (`IgnorePointer` değil, zaten
        // dokunulmuyor): altına çizilseydi `object-cover` fotoğraf onu
        // tamamen örterdi.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                border: Border.all(color: context.bld.photoRing),
              ),
            ),
          ),
        ),
      ],
    );

    if (width == null && height == null) {
      content = AspectRatio(aspectRatio: aspectRatio, child: content);
    }
    return content;
  }
}
