/// KDS teması. Renkler ve punto ölçeği `packages/design_system`'den gelir —
/// mutfak ekranı kendi rengini uydurmaz.
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';

/// `KdsColors` değerlerini Flutter [Color] nesnesine çevirir.
Color kdsColor(int argb) => Color(argb);

abstract final class KdsTheme {
  static ThemeData build() {
    const surface = Color(KdsColors.surface);
    const onSurface = Color(KdsColors.onSurface);

    final scheme =
        ColorScheme.fromSeed(
          seedColor: const Color(BldColors.brand500),
          brightness: Brightness.dark,
        ).copyWith(
          surface: const Color(KdsColors.background),
          onSurface: onSurface,
          primary: const Color(BldColors.brand500),
          onPrimary: const Color(BldColors.neutral0),
          error: const Color(BldColors.danger),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(KdsColors.background),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BldRadius.md),
        ),
      ),
      textTheme: Typography.whiteMountainView.apply(
        bodyColor: onSurface,
        displayColor: onSurface,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // Uzaktan ve aceleyle basılır: dokunma hedefi büyük tutulur.
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(
            fontSize: KdsTextScale.orderNumber,
            fontWeight: FontWeight.bold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BldRadius.sm),
          ),
        ),
      ),
    );
  }
}
