/// Uygulama teması — `packages/design_system` belirteçlerinden kurulur.
///
/// Renk sabitleri burada **yeniden tanımlanmaz**; `BldColors` tek kaynaktır
/// (`docs/BILINMEYENLER.md` #11 ile değişecek).
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';

/// `0xAARRGGBB` belirtecini Flutter rengine çevirir.
Color bldColor(int token) => Color(token);

abstract final class BldTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: bldColor(BldColors.brand500),
      brightness: Brightness.light,
    ).copyWith(
      primary: bldColor(BldColors.brand500),
      onPrimary: bldColor(BldColors.neutral0),
      secondary: bldColor(BldColors.brand700),
      surface: bldColor(BldColors.neutral0),
      onSurface: bldColor(BldColors.neutral900),
      error: bldColor(BldColors.danger),
    );

    final base = ThemeData(colorScheme: scheme, useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: bldColor(BldColors.neutral50),
      appBarTheme: AppBarTheme(
        backgroundColor: bldColor(BldColors.brand500),
        foregroundColor: bldColor(BldColors.neutral0),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: bldColor(BldColors.neutral0),
          fontSize: BldTextScale.title,
          fontWeight: FontWeight.w600,
        ),
      ),
      textTheme: base.textTheme.copyWith(
        displaySmall: base.textTheme.displaySmall?.copyWith(
          fontSize: BldTextScale.display,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontSize: BldTextScale.heading,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontSize: BldTextScale.title,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          fontSize: BldTextScale.body,
        ),
        bodySmall: base.textTheme.bodySmall?.copyWith(
          fontSize: BldTextScale.caption,
          color: bldColor(BldColors.neutral600),
        ),
      ),
      cardTheme: CardThemeData(
        color: bldColor(BldColors.neutral0),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BldRadius.md),
          side: BorderSide(color: bldColor(BldColors.neutral200)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: bldColor(BldColors.neutral100),
        selectedColor: bldColor(BldColors.brand100),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BldRadius.pill),
        ),
        side: BorderSide.none,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bldColor(BldColors.neutral0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BldRadius.sm),
          borderSide: BorderSide(color: bldColor(BldColors.neutral200)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BldRadius.sm),
          borderSide: BorderSide(color: bldColor(BldColors.neutral200)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BldRadius.sm),
          borderSide: BorderSide(color: bldColor(BldColors.brand500), width: 2),
        ),
      ),
      // DİKKAT — `Size.fromHeight` GENİŞLİĞİ SONSUZ yapar.
      //
      // Amaç "buton bulunduğu sütunu doldursun" ve sütun içinde tam olarak
      // bunu yapıyor. Ama sonsuz bir asgari GENİŞLİK, sınırsız genişlik
      // veren bir kapsayıcıyla (`Row`, `Wrap`, kaydırılabilir satır)
      // buluştuğunda düzen hesabı istisna fırlatır.
      //
      // Belirtisi butonla ilgili görünmez: istisna fırlatan alt ağaç
      // yerleşemediği için kapsayan liste kaydırılamaz hâle gelir. Ödeme
      // ekranında tam olarak bu yaşandı (`checkout_screen.dart`,
      // `checkout_scroll_test.dart` bunu koruyor).
      //
      // Bu butonlardan birini `Row` içine koyacaksanız `Expanded` veya
      // `Flexible` ile sarın; ikisi de sınırlı genişlik verir.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: bldColor(BldColors.brand500),
          foregroundColor: bldColor(BldColors.neutral0),
          textStyle: const TextStyle(
            fontSize: BldTextScale.body,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BldRadius.sm),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: bldColor(BldColors.brand700),
          side: BorderSide(color: bldColor(BldColors.brand300)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BldRadius.sm),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: bldColor(BldColors.neutral200),
        space: 1,
        thickness: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bldColor(BldColors.neutral0),
        indicatorColor: bldColor(BldColors.brand100),
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: bldColor(BldColors.neutral800),
        contentTextStyle: TextStyle(color: bldColor(BldColors.neutral0)),
      ),
    );
  }
}
