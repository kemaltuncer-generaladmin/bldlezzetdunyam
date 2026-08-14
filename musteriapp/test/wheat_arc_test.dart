/// Buğday yayının GEOMETRİ SÖZLEŞMESİ.
///
/// Sayılar `website/components/product-image.tsx` içindeki `WHEAT_ARC` ile
/// birebir aynı olmak zorunda; ürünlerin yarısında fotoğraf yok ve iki
/// platformun farklı yer tutucu çizmesi kullanıcının gördüğü en belirgin
/// tutarsızlıktı. Test o sayıları burada sabitliyor: biri tek tarafta
/// değiştirirse buradan düşer ve iki tarafı birlikte değiştirmesi gerektiğini
/// öğrenir.
///
/// Ayrıca SVG'nin `t` (yansıtılmış denetim noktası) komutunun elle açılışı
/// sınanıyor — Flutter'da `t` yok ve iki platformun ayrılabileceği en olası
/// yer o dönüşüm.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musteriapp/src/theme/bld_theme.dart';
import 'package:musteriapp/src/widgets/network_food_image.dart';
import 'package:musteriapp/src/widgets/wheat_arc.dart';

void main() {
  test('kutu ve çentik ofseti web ile aynı', () {
    expect(kWheatArcViewBox, 64);
    expect(kWheatArcNotchDelta, const Offset(2.8, -2.8));
  });

  test('üç sıra, web`deki `M … q … t …` sayılarıyla', () {
    // 'M12 22q10-3.4 20 0t20 0'
    // 'M15 32q8.5-3 17 0t17 0'
    // 'M19 42q6.5-2.6 13 0t13 0'
    expect(kWheatArcRows.length, 3);

    expect(
      [
        for (final r in kWheatArcRows)
          [r.startX, r.startY, r.ctrlDx, r.ctrlDy, r.halfWidth],
      ],
      [
        [12.0, 22.0, 10.0, -3.4, 20.0],
        [15.0, 32.0, 8.5, -3.0, 17.0],
        [19.0, 42.0, 6.5, -2.6, 13.0],
      ],
    );
  });

  test('sıralar sırayla daralır (40 → 34 → 26 birim)', () {
    expect(
      [for (final r in kWheatArcRows) r.halfWidth * 2],
      [40.0, 34.0, 26.0],
    );
  });

  test('`t` yansıması SVG`nin ima ettiği MUTLAK noktaları veriyor', () {
    // Yansıma kuralı: yeni denetim = 2·(geçerli nokta) − (önceki denetim).
    for (final row in kWheatArcRows) {
      final current = Offset(row.startX + row.halfWidth, row.startY);
      final previousControl = Offset(
        row.startX + row.ctrlDx,
        row.startY + row.ctrlDy,
      );
      final expected = current * 2 - previousControl;
      final actual = current + row.mirroredControl;

      expect(actual.dx, closeTo(expected.dx, 1e-9));
      expect(actual.dy, closeTo(expected.dy, 1e-9));
    }

    // İlk sıranın somut değeri: (42, 25.4) — SVG'de `t20 0`'ın karşılığı.
    final first = kWheatArcRows.first;
    final control =
        Offset(first.startX + first.halfWidth, first.startY) +
        first.mirroredControl;
    expect(control.dx, closeTo(42, 1e-9));
    expect(control.dy, closeTo(25.4, 1e-9));
    expect(first.end, const Offset(52, 22));
  });

  test('on iki çentik, sıra başına dördü', () {
    expect(kWheatArcNotches.length, 12);
    expect(kWheatArcNotches.first, const Offset(16.5, 22.4));
    expect(kWheatArcNotches.last, const Offset(40.5, 44));

    // Hepsi çizimin kutusunun içinde kalmalı — çentiğin ucu da dahil.
    for (final start in kWheatArcNotches) {
      final tip = start + kWheatArcNotchDelta;
      for (final point in [start, tip]) {
        expect(point.dx, inInclusiveRange(0, kWheatArcViewBox));
        expect(point.dy, inInclusiveRange(0, kWheatArcViewBox));
      }
    }
  });

  testWidgets('görselsiz ürün buğday yayını KISA kenarın %33`ünde çizer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BldTheme.light(),
        home: const Scaffold(
          body: SizedBox(
            width: 300,
            height: 100,
            child: NetworkFoodImage(url: null),
          ),
        ),
      ),
    );

    expect(find.byType(WheatArcMark), findsOneWidget);
    // Kısa kenar 100 → işaret 33. Yüzde GENİŞLİK olsaydı 16:9 bir detay
    // görselinde işaret devleşir, 1:1 sepet satırında kaybolurdu.
    expect(tester.getSize(find.byType(WheatArcMark)), const Size(33, 33));
  });

  testWidgets('görsel adresi olan ürün yer tutucu çizmez', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BldTheme.light(),
        home: const Scaffold(
          body: SizedBox(
            width: 200,
            height: 200,
            child: NetworkFoodImage(url: 'https://ornek.test/yemek.jpg'),
          ),
        ),
      ),
    );

    // Adres varsa çizilen şey fotoğraftır; buğday yayı yalnız fotoğrafın
    // OLMADIĞI (ya da yüklenemediği) durumun işareti.
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(WheatArcMark), findsNothing);
  });
}
