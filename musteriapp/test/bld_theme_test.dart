/// Temanın MARKA KURALLARINI tuttuğunu sınar.
///
/// Bunlar estetik tercih değil, kod tabanının bir kez pahalıya öğrendiği
/// kurallar: beyaz metin `brand700`'den önce başlamaz, `neutral400` metin
/// değildir, koyu temada yükseltme gölge değil açıklıktır ve para rakamları
/// her yerde tabulardır. Hepsi derlenen ama cihazda görülene kadar
/// fark edilmeyen türden hatalar — bu yüzden test edilirler.
library;

import 'dart:math' as math;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musteriapp/src/theme/bld_semantic_colors.dart';
import 'package:musteriapp/src/theme/bld_theme.dart';

/// Göreli parlaklık (WCAG 2.x). Kontrast oranını burada HESAPLIYORUZ:
/// palet dosyasındaki yorumlarda yazan sayıya güvenmek, o yorumun eskimesi
/// hâlinde testi de birlikte yanıltırdı.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('açık tema', () {
    final theme = BldTheme.light();

    test('marka rolleri temaya kayıtlı', () {
      expect(theme.extension<BldSemanticColors>(), isNotNull);
    });

    test('birincil dolgu beyaz metni TAŞIYABİLDİĞİ tondan başlar', () {
      // brand500 (3,72) ve brand600 (4,91) tuzağı: dolgu brand700 olmalı.
      expect(theme.colorScheme.primary, const Color(BldColors.brand700));
      expect(
        _contrast(theme.colorScheme.primary, theme.colorScheme.onPrimary),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('başlık rengi marka kahvesi, gövde nötr', () {
      expect(
        theme.textTheme.titleLarge?.color,
        const Color(BldColors.brand900),
      );
      expect(
        theme.textTheme.bodyMedium?.color,
        const Color(BldColors.neutral900),
      );
    });

    test('işlevsel kenarlık dekoratiften KOYU (dokunulabilir sınır 3:1)', () {
      final scheme = theme.colorScheme;
      expect(scheme.outline, const Color(BldColors.neutral400));
      expect(scheme.outlineVariant, const Color(BldColors.neutral200));
      expect(
        _contrast(scheme.outline, scheme.surface),
        greaterThanOrEqualTo(3.0),
      );
    });

    test('ipucu metni neutral500 — neutral400 METİN DEĞİLDİR', () {
      expect(
        theme.inputDecorationTheme.hintStyle?.color,
        const Color(BldColors.neutral500),
      );
    });

    test('M3 tonal yükseklik yıkaması kapalı', () {
      expect(theme.colorScheme.surfaceTint, Colors.transparent);
    });
  });

  group('koyu tema', () {
    final theme = BldTheme.dark();

    test('marka rolleri temaya kayıtlı', () {
      expect(theme.extension<BldSemanticColors>(), isNotNull);
    });

    test('birincil dolgu AÇIK, üstündeki yazı KOYU', () {
      expect(theme.colorScheme.primary, const Color(BldColors.brand300));
      expect(theme.colorScheme.onPrimary, const Color(BldColors.neutral950));
      expect(
        _contrast(theme.colorScheme.primary, theme.colorScheme.onPrimary),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('gövde metni zeminden okunur', () {
      expect(
        _contrast(theme.colorScheme.onSurface, theme.colorScheme.surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('surfaceTint şeffaf kalır', () {
      expect(theme.colorScheme.surfaceTint, Colors.transparent);
    });
  });

  test('her iki temada da tüm metin stilleri TABULAR rakam kullanır', () {
    for (final theme in [BldTheme.light(), BldTheme.dark()]) {
      final styles = <String, TextStyle?>{
        'displayLarge': theme.textTheme.displayLarge,
        'headlineMedium': theme.textTheme.headlineMedium,
        'titleLarge': theme.textTheme.titleLarge,
        'titleMedium': theme.textTheme.titleMedium,
        'bodyLarge': theme.textTheme.bodyLarge,
        'bodyMedium': theme.textTheme.bodyMedium,
        'bodySmall': theme.textTheme.bodySmall,
        'labelLarge': theme.textTheme.labelLarge,
        'labelMedium': theme.textTheme.labelMedium,
        'labelSmall': theme.textTheme.labelSmall,
      };
      styles.forEach((name, style) {
        expect(
          style?.fontFeatures,
          contains(const FontFeature.tabularFigures()),
          reason: '$name tabular rakam taşımıyor; fiyat sütunu kayar',
        );
      });
    }
  });

  testWidgets('açık temada yükseltmeyi GÖLGE taşır', (tester) async {
    final context = await _contextWith(tester, BldTheme.light());

    // Açık temada iki seviye de aynı beyaz yüzey; farkı yalnız gölge taşıyor.
    expect(BldSurfaceLevel.card.shadowsOf(context), isNotEmpty);
    expect(BldSurfaceLevel.raised.shadowsOf(context), isNotEmpty);
    expect(BldSurfaceLevel.card.highlightOf(context), isNull);
    expect(
      BldSurfaceLevel.raised.surfaceOf(context),
      BldSurfaceLevel.card.surfaceOf(context),
    );
  });

  testWidgets('koyu temada yükseltme AÇIKLIK adımıdır, gölge değil', (
    tester,
  ) async {
    final context = await _contextWith(tester, BldTheme.dark());

    // Siyaha yakın bir zeminde gölge görünmez: gölge zeminden koyu olamaz.
    expect(BldSurfaceLevel.raised.shadowsOf(context), isEmpty);
    expect(BldSurfaceLevel.raised.highlightOf(context), isNotNull);
    expect(
      _luminance(BldSurfaceLevel.raised.surfaceOf(context)),
      greaterThan(_luminance(BldSurfaceLevel.card.surfaceOf(context))),
    );
  });
}

/// Verilen temayla bir kare pompalar ve içerideki `BuildContext`'i döndürür.
///
/// Her tema için AYRI bir pompalama gerekiyor: `MaterialApp.home`'un kurduğu
/// rota, uygulama yeniden kurulduğunda kendiliğinden yeniden çizilmiyor ve
/// aynı test içinde ikinci bir tema pompalamak eski temayı okumaya devam
/// ediyor (bu tuzağa bir kez düşüldü).
Future<BuildContext> _contextWith(WidgetTester tester, ThemeData theme) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Builder(
        builder: (context) {
          captured = context;
          return const SizedBox();
        },
      ),
    ),
  );
  return captured;
}
