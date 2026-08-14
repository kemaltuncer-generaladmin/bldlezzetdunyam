/// Para gösteriminin kuralları.
///
/// Buradaki her beklenti, bir kez gerçekten yaşanmış bir hataya karşılık
/// geliyor: kayan fiyat sütunu (tabular rakam yok), iki satıra bölünen tutar
/// (sarmalama), ve indirimin zam gibi görünmesi (üstü çizili fiyatın sırası
/// ve rengi).
library;

import 'package:bld_core/bld_core.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musteriapp/src/theme/bld_semantic_colors.dart';
import 'package:musteriapp/src/theme/bld_theme.dart';
import 'package:musteriapp/src/widgets/money_text.dart';

Widget _wrap(Widget child, {bool dark = false}) => MaterialApp(
  theme: dark ? BldTheme.dark() : BldTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

TextStyle _styleOf(WidgetTester tester) =>
    tester.widget<Text>(find.byType(Text)).style!;

void main() {
  testWidgets('tutar Money.format ile aynı metni basar', (tester) async {
    await tester.pumpWidget(_wrap(const MoneyText(1234567)));

    expect(find.text('12.345,67 ₺'), findsOneWidget);
    expect(find.text(Money.format(1234567)), findsOneWidget);
  });

  testWidgets('rakamlar tabular ve metin ASLA sarmalanmaz', (tester) async {
    await tester.pumpWidget(_wrap(const MoneyText(41000)));

    final text = tester.widget<Text>(find.byType(Text));
    expect(
      text.style?.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
    expect(text.softWrap, isFalse);
    expect(text.maxLines, 1);
    // Kırpma DEĞİL taşma: kırpılmış bir tutar yanlış bilgidir.
    expect(text.overflow, TextOverflow.visible);
  });

  testWidgets('para İŞLEVSEL metindir — serif değil Inter', (tester) async {
    await tester.pumpWidget(_wrap(const MoneyText(41000)));

    expect(_styleOf(tester).fontFamily, BldFontFamily.body);
  });

  testWidgets('dört ölçek marka tablosundaki boyları verir', (tester) async {
    for (final (scale, size, weight) in [
      (MoneyScale.sm, BldTextScale.moneySm, FontWeight.w600),
      (MoneyScale.md, BldTextScale.moneyMd, FontWeight.w700),
      (MoneyScale.lg, BldTextScale.moneyLg, FontWeight.w700),
      (MoneyScale.xl, BldTextScale.moneyXl, FontWeight.w700),
    ]) {
      await tester.pumpWidget(_wrap(MoneyText(41000, scale: scale)));
      final style = _styleOf(tester);
      expect(style.fontSize, size);
      expect(style.fontWeight, weight);
    }
  });

  testWidgets('negatif tutar eksiyle, pozitif fark istenirse artıyla basılır', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const MoneyText(-4550)));
    expect(find.text('-45,50 ₺'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(
        const MoneyText(1200, showPlusSign: true, tone: MoneyTone.difference),
      ),
    );
    expect(find.text('+12,00 ₺'), findsOneWidget);

    // Artı işareti YALNIZ pozitifte: "+-45,50 ₺" diye bir tutar yok.
    await tester.pumpWidget(_wrap(const MoneyText(-4550, showPlusSign: true)));
    expect(find.text('-45,50 ₺'), findsOneWidget);
  });

  testWidgets('işaret renkleri anlamdan gelir', (tester) async {
    late BldSemanticColors bld;
    await tester.pumpWidget(
      MaterialApp(
        theme: BldTheme.light(),
        home: Builder(
          builder: (context) {
            bld = context.bld;
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );

    for (final (tone, expected) in [
      (MoneyTone.difference, bld.moneyPositive),
      (MoneyTone.credit, bld.moneyCredit),
      (MoneyTone.debt, bld.moneyDebt),
    ]) {
      await tester.pumpWidget(_wrap(MoneyText(4500, tone: tone)));
      expect(_styleOf(tester).color, expected);
    }
  });

  testWidgets('üstü çizili eski fiyat neutral400 ve çizgili', (tester) async {
    await tester.pumpWidget(_wrap(const MoneyText.previous(9900)));

    final style = _styleOf(tester);
    expect(style.decoration, TextDecoration.lineThrough);
    expect(style.color, const Color(BldColors.neutral400));
  });

  testWidgets('koyu temada düz tutar zeminden okunur bir renkte', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const MoneyText(41000), dark: true));

    // Işık temanın neutral900'ü koyu zeminde görünmez olurdu; renk temadan
    // geliyor mu, onu soruyoruz.
    expect(_styleOf(tester).color, const Color(BldDarkColors.foreground));
  });
}
