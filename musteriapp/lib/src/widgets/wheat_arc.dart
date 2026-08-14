/// BUĞDAY YAYI — görseli olmayan ürünün yer tutucusu.
///
/// **Neden bu çizim:** logodaki kürenin ayırt edici yarısı buğday yayıdır
/// (bkz. `website/app/icon.svg`). Ürünlerin yaklaşık yarısında fotoğraf yok;
/// yer tutucu, kullanıcının menüde en çok gördüğü İKİNCİ grafik. Önceki hâli
/// genel bir "tabak" ikonuydu — hiçbir markaya ait değildi ve web BAŞKA bir
/// çizim kullanıyordu. Platformlar arasındaki en görünür tutarsızlık buydu.
///
/// **Koordinat sistemi SÖZLEŞMEDİR.** Sayılar 64×64'lük bir kutuda, yay için
/// 2, çentik için 1,4 kalınlıkla tanımlı ve `website/components/
/// product-image.tsx` içindeki `WHEAT_ARC` ile BİREBİR aynı. Buradaki bir
/// sayıyı tek başına değiştirmek iki yüzeyi ayırır; çizim değişecekse iki
/// tarafta birlikte değişir.
///
/// **Neden `CustomPainter`, `flutter_svg` DEĞİL:** çizim üç yaydan ve on iki
/// kısa çizgiden ibaret. Bunun için bir SVG ayrıştırıcısı paketi eklemek,
/// uygulamaya yalnız yer tutucu için yeni bir bağımlılık ve yeni bir
/// varlık dosyası sokardı.
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';

import '../theme/bld_semantic_colors.dart';

/// Bir buğday sırası: `M sx sy q cdx cdy w 0 t w 0`.
///
/// `t` (yansıtılmış denetim noktası) yüzünden yayın SOL yarısı yukarı, SAĞ
/// yarısı aşağı bombelidir; sağ yarının çentikleri bu yüzden iki birim daha
/// aşağıda duruyor.
@immutable
class WheatArcRow {
  const WheatArcRow(
    this.startX,
    this.startY,
    this.ctrlDx,
    this.ctrlDy,
    this.halfWidth,
  );

  final double startX;
  final double startY;
  final double ctrlDx;
  final double ctrlDy;

  /// Her yarının yatay uzunluğu; sıranın toplam genişliği bunun iki katı.
  final double halfWidth;

  /// İkinci yarının denetim noktası — GEÇERLİ NOKTAYA göre ofset.
  ///
  /// SVG'nin `t` komutu, önceki denetim noktasını geçerli noktanın etrafında
  /// YANSITIR. Flutter'da `t` yok, o yüzden yansıma burada bir kez hesaplanıp
  /// test edilebilir hâlde duruyor: elle açılmış bir eğri, iki platformun
  /// ayrıldığı en olası yer.
  Offset get mirroredControl => Offset(halfWidth - ctrlDx, -ctrlDy);

  /// Sıranın bittiği mutlak nokta.
  Offset get end => Offset(startX + 2 * halfWidth, startY);
}

/// `WHEAT_ARC.rows` — üç yığılı sıra, sırayla daralır (40 → 34 → 26 birim).
const List<WheatArcRow> kWheatArcRows = [
  WheatArcRow(12, 22, 10, -3.4, 20),
  WheatArcRow(15, 32, 8.5, -3, 17),
  WheatArcRow(19, 42, 6.5, -2.6, 13),
];

/// `WHEAT_ARC.notches` — başak çentiklerinin başlangıç noktaları. Hepsi
/// `l 2.8 -2.8` çiziyor; çentiksiz hâli su dalgası gibi görünüyordu.
const List<Offset> kWheatArcNotches = [
  Offset(16.5, 22.4),
  Offset(23.5, 22.4),
  Offset(35.5, 24.6),
  Offset(42.5, 24.6),
  Offset(19, 32.4),
  Offset(25.5, 32.4),
  Offset(36, 34.4),
  Offset(42, 34.4),
  Offset(22.5, 42.4),
  Offset(28, 42.4),
  Offset(36, 44),
  Offset(40.5, 44),
];

/// Çizimin tanımlandığı kare kutu.
const double kWheatArcViewBox = 64;

/// Çentiğin yer değiştirmesi (`l 2.8 -2.8`).
const Offset kWheatArcNotchDelta = Offset(2.8, -2.8);

/// Buğday yayı işareti. Kabın tamamını doldurur; boyutu çağıran verir.
class WheatArcMark extends StatelessWidget {
  const WheatArcMark({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _WheatArcPainter(color), size: Size.infinite);
}

class _WheatArcPainter extends CustomPainter {
  const _WheatArcPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    if (side <= 0) return;

    final scale = side / kWheatArcViewBox;
    canvas.save();
    // Kabın kısa kenarına göre ortala: 16:9 bir detay görselinde de 1:1
    // sepet satırında da işaret aynı okunmalı.
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    canvas.scale(scale);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2;

    final arcs = Path();
    for (final row in kWheatArcRows) {
      arcs.moveTo(row.startX, row.startY);
      arcs.relativeQuadraticBezierTo(row.ctrlDx, row.ctrlDy, row.halfWidth, 0);
      final mirrored = row.mirroredControl;
      arcs.relativeQuadraticBezierTo(
        mirrored.dx,
        mirrored.dy,
        row.halfWidth,
        0,
      );
    }
    canvas.drawPath(arcs, stroke);

    final notches = Path();
    for (final start in kWheatArcNotches) {
      notches
        ..moveTo(start.dx, start.dy)
        ..relativeLineTo(kWheatArcNotchDelta.dx, kWheatArcNotchDelta.dy);
    }
    canvas.drawPath(notches, stroke..strokeWidth = 1.4);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_WheatArcPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Görselsiz (ya da henüz yüklenmemiş) ürünün kabı: tintli zemin + işaret.
class WheatArcPlaceholder extends StatelessWidget {
  const WheatArcPlaceholder({super.key, this.loading = false});

  /// Yükleme sırasında iskelet tonları kullanılır: marka tinti "bu ürünün
  /// görseli yok" der, oysa görsel yolda.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final bld = context.bld;
    final isLight = Theme.of(context).brightness == Brightness.light;

    final (Color from, Color to, Color mark) = loading
        ? (bld.skeletonBase, bld.skeletonBase, bld.skeletonShine)
        : isLight
        ? (
            const Color(BldColors.brand50),
            const Color(BldColors.brand100),
            const Color(BldColors.brand300),
          )
        // Koyu temada krem bir blok kartın içinde ışık lekesi gibi duruyor;
        // aynı çizim, marka ailesinin koyu yüzeyleriyle.
        : (
            const Color(BldDarkColors.accent),
            const Color(BldDarkColors.surface2),
            const Color(BldColors.brand300),
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          // CSS `135deg` = sol üstten sağ alta.
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [from, to],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // İşaretin boyu kabın KISA kenarının %33'ü (web'de `33cqmin`).
          final side = constraints.biggest.shortestSide;
          return Center(
            child: SizedBox.square(
              dimension: side.isFinite ? side * 0.33 : 0,
              child: WheatArcMark(color: mark),
            ),
          );
        },
      ),
    );
  }
}
