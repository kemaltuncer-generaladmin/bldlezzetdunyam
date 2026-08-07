/// Yemek görseli sarmalayıcı — sabit oran, yüklenirken/hata placeholder,
/// isteğe bağlı alt gradyan.
///
/// Ana sayfa, menü ve ürün detayındaki tekrarlı `Image.network + errorBuilder`
/// bloklarını tek yerde toplar. Görsel gelmezse kart çökmez: sıcak nötr zemin
/// + tabak ikonu kalır. `overlay` ile alt köşeye fiyat/rozet basılabilsin diye
/// koyulaşan bir gradyan eklenir.
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';

import '../theme/bld_theme.dart';

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
    Widget image = url == null
        ? _placeholder()
        : Image.network(
            url!,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _placeholder(),
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : _placeholder(loading: true),
          );

    Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
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
                          bldColor(BldColors.neutral900).withValues(alpha: 0.55),
                          bldColor(BldColors.neutral900).withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          : image,
    );

    if (width == null && height == null) {
      content = AspectRatio(aspectRatio: aspectRatio, child: content);
    }
    return content;
  }

  Widget _placeholder({bool loading = false}) {
    return Container(
      width: width,
      height: height,
      color: bldColor(loading ? BldColors.neutral100 : BldColors.brand50),
      alignment: Alignment.center,
      child: Icon(
        Icons.restaurant_menu,
        color: bldColor(loading ? BldColors.neutral200 : BldColors.brand200),
        size: 32,
      ),
    );
  }
}
