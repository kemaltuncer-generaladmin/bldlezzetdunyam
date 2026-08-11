/// KDS teması. Renkler ve punto ölçeği `packages/design_system`'den gelir —
/// mutfak ekranı kendi rengini uydurmaz.
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';

import '../kds/board.dart';
import '../kds/urgency.dart';

/// `KdsColors` değerlerini Flutter [Color] nesnesine çevirir.
Color kdsColor(int argb) => Color(argb);

/// Panodaki anlam renkleri.
///
/// **Buradaki hiçbir değer uydurulmamıştır**: hepsi `bld_design_system`
/// belirteçleridir (AGENTS.md §4 — "mutfak ekranı kendi rengini uydurmaz").
/// Bu sınıf yalnızca "hangi durum hangi belirteci kullanır" eşlemesini
/// tutar; belirteçlerin kendisi tasarım sisteminde durur.
abstract final class KdsAccents {
  /// Sütun kimlik rengi. Uzaktan bakan personel sütunu başlığı okumadan,
  /// yalnızca renginden tanır.
  static Color column(KdsColumn column) => switch (column) {
    KdsColumn.yeni => const Color(BldColors.brand500),
    KdsColumn.hazirlaniyor => const Color(BldColors.info),
    KdsColumn.hazir => const Color(BldColors.success),
  };

  /// Aciliyet rengi; [OrderUrgency.normal] için sütun rengine düşülür.
  static Color urgency(OrderUrgency urgency, KdsColumn fallbackColumn) =>
      switch (urgency) {
        OrderUrgency.normal => column(fallbackColumn),
        OrderUrgency.warning => const Color(BldColors.warning),
        OrderUrgency.late => const Color(BldColors.danger),
      };

  /// Renkli zemin üzerine basılacak yazı rengi.
  ///
  /// Sarı zeminde beyaz yazı okunmaz; koyu zeminde siyah yazı okunmaz.
  /// Seçim rengin parlaklığına göre yapılır, göz kararı değil: 0.179, siyah
  /// ve beyaz kontrast oranlarının kesiştiği WCAG eşiğidir.
  static Color onAccent(Color accent) => accent.computeLuminance() > 0.179
      ? const Color(BldColors.neutral900)
      : const Color(BldColors.neutral0);
}

abstract final class KdsTheme {
  /// Dokunmatik kipte en küçük dokunma hedefi.
  ///
  /// Material'ın 48 px önerisi parmak ucu içindir. Mutfakta eldivenli ya da
  /// yağlı elle basılıyor; sahada 48 px'te komşu düğmeye basma yaygındı.
  static const double touchTargetSize = 56;

  /// Dokunmatik kipte ikon boyutu (varsayılan 22–24).
  static const double touchIconSize = 30;

  /// [touch] açıkken düğmeler ve ikonlar büyür.
  ///
  /// Kipin TEMADA olması bilinçli: her widget'a bayrak geçirmek yerine tek
  /// yerden büyütmek, gözden kaçan küçük hedef bırakmaz. Kapalıyken çıktı
  /// bugünküyle bit bit aynıdır — dokunmatik olmayan kasalarda hiçbir
  /// regresyon riski yok.
  static ThemeData build({bool touch = false}) {
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
          minimumSize: Size.fromHeight(touch ? 64 : 56),
          textStyle: const TextStyle(
            fontSize: KdsTextScale.orderNumber,
            fontWeight: FontWeight.bold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BldRadius.sm),
          ),
        ),
      ),
      // Aşağıdaki üçü YALNIZCA dokunmatik kipte devreye giriyor. Varsayılan
      // kipte `null` bırakmak, bugünkü görünümün bit bit korunmasını
      // garanti eder.
      iconButtonTheme: touch
          ? IconButtonThemeData(
              style: IconButton.styleFrom(
                minimumSize: const Size.square(touchTargetSize),
                iconSize: touchIconSize,
              ),
            )
          : null,
      textButtonTheme: touch
          ? TextButtonThemeData(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, touchTargetSize),
                textStyle: const TextStyle(
                  fontSize: KdsTextScale.orderNumber,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      // Dokunmatik ekranda fare tekerleği yok; kaydırma parmakla ve
      // ivmeli olmalı. `BouncingScrollPhysics` bitiş noktasını hissettirir
      // ve "liste bitti mi, takıldı mı" belirsizliğini kaldırır.
      scrollbarTheme: touch
          ? const ScrollbarThemeData(
              thickness: WidgetStatePropertyAll(12),
              thumbVisibility: WidgetStatePropertyAll(true),
            )
          : null,
      listTileTheme: touch
          ? const ListTileThemeData(minVerticalPadding: 14)
          : null,
    );
  }
}
