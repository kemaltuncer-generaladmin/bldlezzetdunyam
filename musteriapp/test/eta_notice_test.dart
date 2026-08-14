/// Tahmin kutusunun ne gösterip ne gizlediği.
///
/// Kritik olan tek kural: dar görünümde kaynak açıklaması düşer ama
/// **yoğunluk uyarısı düşmez** — o, kullanıcının beklentisini değiştirir.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musteriapp/src/core/eta_text.dart';
import 'package:musteriapp/src/theme/bld_theme.dart';
import 'package:musteriapp/src/widgets/eta_notice.dart';

void main() {
  // Kutu marka rollerini (`BldSemanticColors`) okuyor; Material'ın varsayılan
  // teması onları taşımıyor. Uygulamanın gerçek temasıyla pompalamak, testin
  // ekranda çizilenle aynı ağacı kurmasını da sağlıyor.
  Widget wrap(Widget child) => MaterialApp(
    theme: BldTheme.light(),
    home: Scaffold(body: child),
  );

  Future<void> pump(WidgetTester tester, EtaPresentation eta) async {
    await tester.pumpWidget(wrap(EtaNotice(eta: eta)));
  }

  const yogun = EtaPresentation(
    title: 'Tahmini teslim',
    value: 'yaklaşık 75-100 dakika · 13:30-13:55 arası',
    sourceNote: 'Kaynak açıklaması',
    busyNote: 'Yoğunluk uyarısı',
  );

  testWidgets('ayrıntılı görünümde başlık, değer ve açıklamalar görünür', (
    tester,
  ) async {
    await pump(tester, yogun);

    expect(
      find.text('Tahmini teslim: yaklaşık 75-100 dakika · 13:30-13:55 arası'),
      findsOneWidget,
    );
    expect(find.text('Kaynak açıklaması'), findsOneWidget);
    expect(find.text('Yoğunluk uyarısı'), findsOneWidget);
  });

  testWidgets('dar görünümde kaynak açıklaması gizlenir, uyarı kalır', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const EtaNotice(eta: yogun, compact: true)));

    expect(find.text('Kaynak açıklaması'), findsNothing);
    expect(find.text('Yoğunluk uyarısı'), findsOneWidget);
  });

  testWidgets('yoğunluk yokken uyarı satırı hiç çizilmez', (tester) async {
    await pump(
      tester,
      const EtaPresentation(
        title: 'Tahmini hazır olma',
        value: '40-55 dakika · 12:55-13:10 arası',
        sourceNote: 'Kaynak açıklaması',
      ),
    );

    expect(find.text('Yoğunluk uyarısı'), findsNothing);
    expect(
      find.text('Tahmini hazır olma: 40-55 dakika · 12:55-13:10 arası'),
      findsOneWidget,
    );
  });
}
