/// Uygulama teması — `packages/design_system` belirteçlerinden kurulur.
///
/// Renk sabitleri burada **yeniden tanımlanmaz**; `BldColors` tek kaynaktır.
/// Palet kilitlidir (turuncu marka + stone nötr); bu dosya paleti bir görsel
/// dile çevirir: sıcak/premium tipografi, yumuşak gölge, disiplinli tek-vurgu
/// (turuncu yalnız birincil eylem + hero + aktif durum), gölgeli beyaz kartlar.
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';

/// `0xAARRGGBB` belirtecini Flutter rengine çevirir.
Color bldColor(int token) => Color(token);

/// Gölge belirteci katmanlarını `BoxShadow` listesine çevirir.
///
/// Özel yüzeyler (`BldCard`, hero) Material `elevation`'ın tonal yıkamasını
/// değil bu yumuşak, çift-katmanlı gölgeyi kullanır.
List<BoxShadow> bldShadow(List<BldShadowLayer> layers) => [
  for (final layer in layers)
    BoxShadow(
      color: bldColor(BldColors.neutral900).withValues(alpha: layer.alpha / 255),
      offset: Offset(layer.dx, layer.dy),
      blurRadius: layer.blur,
      spreadRadius: layer.spread,
    ),
];

/// Hareket eğrisi kimliğini Flutter `Curve`'üne çevirir.
Curve bldCurve(BldEase ease) => switch (ease) {
  BldEase.standard => Curves.easeInOutCubic,
  BldEase.emphasized => Curves.easeOutCubic,
  BldEase.decelerate => Curves.decelerate,
};

/// Süre belirtecini `Duration`'a çevirir.
Duration bldDuration(int milliseconds) => Duration(milliseconds: milliseconds);

abstract final class BldTheme {
  static ThemeData light() {
    // NEDEN `fromSeed` + kapsamlı `copyWith`, elle 30-argümanlı `ColorScheme`
    // DEĞİL: seed'in ürettiği rastgele ara tonlar "jenerik Material" hissinin
    // kaynağıdır; hepsini burada paletle EZİYORUZ. Kalan (yalnız iç) türevler
    // için seed pratik bir taban; kırılgan bir literal yerine bu güvenli.
    final scheme =
        ColorScheme.fromSeed(
          seedColor: bldColor(BldColors.brand500),
          brightness: Brightness.light,
        ).copyWith(
          primary: bldColor(BldColors.brand500),
          onPrimary: bldColor(BldColors.neutral0),
          primaryContainer: bldColor(BldColors.brand100),
          onPrimaryContainer: bldColor(BldColors.brand900),
          secondary: bldColor(BldColors.brand700),
          onSecondary: bldColor(BldColors.neutral0),
          secondaryContainer: bldColor(BldColors.brand50),
          onSecondaryContainer: bldColor(BldColors.brand900),
          tertiary: bldColor(BldColors.neutral600),
          onTertiary: bldColor(BldColors.neutral0),
          surface: bldColor(BldColors.neutral0),
          onSurface: bldColor(BldColors.neutral900),
          onSurfaceVariant: bldColor(BldColors.neutral600),
          surfaceContainerLowest: bldColor(BldColors.neutral0),
          surfaceContainerLow: bldColor(BldColors.neutral50),
          surfaceContainer: bldColor(BldColors.neutral100),
          surfaceContainerHigh: bldColor(BldColors.neutral100),
          surfaceContainerHighest: bldColor(BldColors.neutral200),
          error: bldColor(BldColors.danger),
          onError: bldColor(BldColors.neutral0),
          outline: bldColor(BldColors.neutral200),
          outlineVariant: bldColor(BldColors.neutral100),
          // Gölgeyi kendimiz veriyoruz; M3 tonal yükseklik yıkamasını kapat.
          surfaceTint: Colors.transparent,
        );

    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: BldFontFamily.body,
      scaffoldBackgroundColor: bldColor(BldColors.neutral50),
      splashFactory: InkSparkle.splashFactory,
    );

    final onSurface = bldColor(BldColors.neutral900);
    final muted = bldColor(BldColors.neutral600);

    // Display/başlık ailesi Sora; gövde Inter (base.fontFamily'den gelir).
    TextStyle display(double size, {FontWeight weight = FontWeight.w700}) =>
        TextStyle(
          fontFamily: BldFontFamily.display,
          fontSize: size,
          fontWeight: weight,
          letterSpacing: BldFontFamily.displayLetterSpacing,
          color: onSurface,
          height: 1.15,
        );

    final textTheme = base.textTheme.copyWith(
      displaySmall: display(BldTextScale.display),
      headlineMedium: display(BldTextScale.heading + 4),
      headlineSmall: display(BldTextScale.heading),
      titleLarge: display(BldTextScale.title + 2, weight: FontWeight.w600),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontSize: BldTextScale.title,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleSmall: base.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        fontSize: BldTextScale.body,
        color: onSurface,
        height: 1.4,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        fontSize: BldTextScale.body,
        color: onSurface,
        height: 1.4,
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(
        fontSize: BldTextScale.caption,
        color: muted,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      // AppBar artık dolu turuncu DEĞİL: beyaz zemin + koyu marka başlığı,
      // kaydırınca ince gölge. Turuncu vurgu hero ve birincil eyleme saklandı.
      appBarTheme: AppBarTheme(
        backgroundColor: bldColor(BldColors.neutral0),
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 3,
        shadowColor: bldColor(BldColors.neutral900).withValues(alpha: 0.06),
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: BldFontFamily.display,
          color: onSurface,
          fontSize: BldTextScale.title,
          fontWeight: FontWeight.w600,
          letterSpacing: BldFontFamily.displayLetterSpacing,
        ),
        iconTheme: IconThemeData(color: onSurface),
      ),
      cardTheme: CardThemeData(
        color: bldColor(BldColors.neutral0),
        elevation: 3,
        shadowColor: bldColor(BldColors.neutral900).withValues(alpha: 0.10),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BldRadius.md),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: bldColor(BldColors.neutral100),
        selectedColor: bldColor(BldColors.brand100),
        labelStyle: TextStyle(
          fontSize: BldTextScale.caption + 1,
          fontWeight: FontWeight.w600,
          color: muted,
        ),
        secondaryLabelStyle: TextStyle(
          fontSize: BldTextScale.caption + 1,
          fontWeight: FontWeight.w600,
          color: bldColor(BldColors.brand700),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: BldSpacing.md - 4,
          vertical: BldSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BldRadius.pill),
        ),
        side: BorderSide.none,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bldColor(BldColors.neutral0),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: BldSpacing.md,
          vertical: BldSpacing.md - 2,
        ),
        hintStyle: TextStyle(color: bldColor(BldColors.neutral400)),
        border: _inputBorder(BldColors.neutral200),
        enabledBorder: _inputBorder(BldColors.neutral200),
        focusedBorder: _inputBorder(BldColors.brand500, width: 2),
        errorBorder: _inputBorder(BldColors.danger),
        focusedErrorBorder: _inputBorder(BldColors.danger, width: 2),
      ),
      // DİKKAT — `Size.fromHeight` GENİŞLİĞİ SONSUZ yapar.
      //
      // Amaç "buton bulunduğu sütunu doldursun" ve sütun içinde tam olarak
      // bunu yapıyor. Ama sonsuz asgari GENİŞLİK, sınırsız genişlik veren bir
      // kapsayıcıyla (`Row`, `Wrap`, kaydırılabilir satır) buluşunca düzen
      // hesabı istisna fırlatır ve kapsayan liste kaydırılamaz olur. Ödeme
      // ekranında tam bu yaşandı (`checkout_screen.dart`,
      // `checkout_scroll_test.dart` bunu koruyor). `Row` içine koyacaksanız
      // `Expanded`/`Flexible` ile sarın.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: bldColor(BldColors.brand500),
          foregroundColor: bldColor(BldColors.neutral0),
          disabledBackgroundColor: bldColor(BldColors.neutral200),
          disabledForegroundColor: bldColor(BldColors.neutral400),
          elevation: 0,
          textStyle: const TextStyle(
            fontFamily: BldFontFamily.body,
            fontSize: BldTextScale.body,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BldRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          foregroundColor: bldColor(BldColors.brand700),
          side: BorderSide(color: bldColor(BldColors.brand300)),
          textStyle: const TextStyle(
            fontFamily: BldFontFamily.body,
            fontSize: BldTextScale.body,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BldRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: bldColor(BldColors.brand700),
          textStyle: const TextStyle(
            fontFamily: BldFontFamily.body,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? bldColor(BldColors.brand500)
                : bldColor(BldColors.neutral0),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? bldColor(BldColors.neutral0)
                : muted,
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: bldColor(BldColors.neutral200)),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BldRadius.md),
            ),
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: bldColor(BldColors.brand700),
        unselectedLabelColor: muted,
        indicatorColor: bldColor(BldColors.brand500),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: bldColor(BldColors.neutral200),
        labelStyle: const TextStyle(
          fontSize: BldTextScale.body,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: BldTextScale.body),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BldRadius.md),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: bldColor(BldColors.neutral0),
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(BldRadius.lg),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: bldColor(BldColors.neutral0),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BldRadius.lg),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bldColor(BldColors.neutral0),
        indicatorColor: bldColor(BldColors.brand100),
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shadowColor: bldColor(BldColors.neutral900).withValues(alpha: 0.08),
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? bldColor(BldColors.brand700)
                : bldColor(BldColors.neutral400),
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: BldTextScale.caption,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? bldColor(BldColors.brand700)
                : muted,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: bldColor(BldColors.neutral200),
        space: 1,
        thickness: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: bldColor(BldColors.brand500),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: bldColor(BldColors.neutral900),
        contentTextStyle: TextStyle(
          color: bldColor(BldColors.neutral0),
          fontSize: BldTextScale.body,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BldRadius.md),
        ),
      ),
      // Modern, iki platformda tutarlı ileri geçiş (Android'de öngörülü geri
      // hareketiyle uyumlu). Cupertino oluşturucusu bu sürümde material'da
      // değil; FadeForwards material'dadır ve premium bir his verir.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static OutlineInputBorder _inputBorder(int colorToken, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(BldRadius.md),
        borderSide: BorderSide(color: bldColor(colorToken), width: width),
      );
}
