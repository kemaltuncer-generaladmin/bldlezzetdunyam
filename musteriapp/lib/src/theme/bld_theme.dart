/// Uygulama teması — `packages/design_system` belirteçlerinden kurulur.
///
/// Renk sabitleri burada **yeniden tanımlanmaz**; `BldColors` ve onun rol
/// tabloları (`BldLightColors` / `BldDarkColors`) tek kaynaktır. Bu dosya o
/// paleti bir görsel dile çevirir: serif isim/başlık + Inter işlevsel metin,
/// yumuşak çift katmanlı gölge, disiplinli tek vurgu, tabular rakamlı para.
///
/// **İki tema, tek gövde:** `light()` ve `dark()` aynı [_build] gövdesini
/// paylaşır ve yalnız bir [_Roles] tablosuyla ayrışır. Kopyalanan iki tema
/// gövdesi kaçınılmaz olarak birbirinden uzaklaşır — biri düzeltilir, öteki
/// unutulur. Ayrışması gereken tek şey rollerdir, düzen değil.
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';

import 'bld_semantic_colors.dart';

/// `0xAARRGGBB` belirtecini Flutter rengine çevirir.
Color bldColor(int token) => Color(token);

/// Gölge belirteci katmanlarını `BoxShadow` listesine çevirir.
///
/// Özel yüzeyler (`BldCard`, hero) Material `elevation`'ın tonal yıkamasını
/// değil bu yumuşak, çift-katmanlı gölgeyi kullanır.
List<BoxShadow> bldShadow(List<BldShadowLayer> layers) => [
  for (final layer in layers)
    BoxShadow(
      color: bldColor(
        BldColors.neutral900,
      ).withValues(alpha: layer.alpha / 255),
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

/// Rakamları eşit genişlikte dizen OpenType özelliği.
///
/// **Neden her yerde:** para bu uygulamada tek bir bileşenden geçmiyor —
/// sepet satırı, sipariş listesi, ekstre ve abonelik özeti hepsi kendi
/// `Text`'ini basıyor. Orantılı rakamlarda `1` ile `8` farklı genişlikte
/// olduğu için alt alta gelen fiyat sütunu kayıyordu. Özelliği tema
/// düzeyinde açmak, tek tek çağrı yerlerini düzeltmeyi beklemeden bütün
/// sütunları hizalar. Her iki font da `tnum` içeriyor (bkz.
/// `assets/fonts/README.md` — alt kümeleme `--layout-features='*'` ile
/// yapıldı).
const List<FontFeature> kBldTabularFigures = [FontFeature.tabularFigures()];

/// Yükseltme adımı — gölge (açık tema) ya da açıklık (koyu tema).
///
/// **Neden gölge listesi değil bir enum:** koyu temada yükseltme gölgeyle
/// ANLATILAMAZ. Siyaha yakın bir zeminde gölge görünmez, çünkü gölge zeminden
/// daha koyu olamaz; oradaki yükseltme bir açıklık adımıdır. Çağrı yerinin
/// "gölge listesi" seçmesi, kararı yanlış katmana koyuyordu — artık niyetini
/// (`card` / `raised` / `overlay`) söylüyor, karşılığını tema veriyor.
enum BldSurfaceLevel {
  /// Kart, liste satırı — zemine hafif oturur.
  card(BldElevation.card),

  /// Seçili kart, sabit alt çubuk, FAB.
  raised(BldElevation.raised),

  /// Bottom sheet, diyalog, açılır menü.
  overlay(BldElevation.overlay);

  const BldSurfaceLevel(this.shadowLayers);

  /// Yalnız AÇIK temada kullanılır.
  final List<BldShadowLayer> shadowLayers;
}

/// [BldSurfaceLevel]'i içinde bulunduğu temaya göre boyaya çevirir.
extension BldSurfaceLevelPaint on BldSurfaceLevel {
  /// Yüzeyin dolgu rengi. Koyu temada seviye arttıkça AÇILIR.
  Color surfaceOf(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.light) return theme.colorScheme.surface;
    return switch (this) {
      BldSurfaceLevel.card => theme.colorScheme.surface,
      BldSurfaceLevel.raised ||
      BldSurfaceLevel.overlay => context.bld.surfaceRaised,
    };
  }

  /// Gölge — koyu temada BOŞ liste.
  List<BoxShadow> shadowsOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
      ? bldShadow(shadowLayers)
      : const [];

  /// Koyu temada yüzeyin üst kenarına düşen 1 px ışık.
  ///
  /// Marka kılavuzundaki `inset 0 1px 0 rgb(255 255 255 / .04)` karşılığı:
  /// Flutter'ın `BoxShadow`'unda iç gölge yok, aynı iş 1 px üst kenarlıkla
  /// yapılıyor. Yükseltilmiş yüzeyin üstünde ince bir aydınlık kenar olmadan
  /// iki koyu ton arasındaki fark cihazda kaybolur.
  Border? highlightOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Border(top: BorderSide(color: Color(0x0AFFFFFF)))
      : null;
}

/// Odak halkası: 2 px halka + 2 px boşluk, zemin renginde.
///
/// **Neden `BoxShadow`:** Flutter'ın kenarlığı kutunun İÇİNE çizilir; ofsetli
/// bir halka ancak kutunun dışına boyanabilir ve bunu yapabilen tek şey
/// gölgedir. İki katman, CSS'teki `0 0 0 2px <zemin>, 0 0 0 4px <halka>`
/// yazımının birebir karşılığı: önce halka (spread 4), üstüne zemin renginde
/// boşluk (spread 2).
///
/// **Neden gerekli:** Material'ın varsayılan odağı yüzeye %10 alfalı bir
/// yıkama sürüyor; marka zemininde neredeyse görünmüyor. iPad'de fiziksel
/// klavye gerçek bir kullanım biçimi ve klavyeyle gezen kullanıcı nerede
/// olduğunu göremiyordu.
List<BoxShadow> bldFocusRing({required Color ring, required Color gap}) => [
  BoxShadow(color: ring, spreadRadius: 4, blurRadius: 0),
  BoxShadow(color: gap, spreadRadius: 2, blurRadius: 0),
];

/// Bir temanın renk rolleri. `BldLightColors` / `BldDarkColors` tablolarının
/// tema kurulumunda gereken alt kümesi.
///
/// **Neden ayrı bir sınıf:** Dart'ta statik üyeler arayüz olamaz, yani
/// "şu tabloyu ver" diyemiyoruz. Rolleri tek yerde açıkça eşleştirmek,
/// gövdenin içine serpiştirilmiş onlarca `isDark ? ... : ...` üçlüsünden hem
/// okunaklı hem de eksik rolü derleme zamanında yakalanabilir kılıyor.
@immutable
class _Roles {
  const _Roles({
    required this.brightness,
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.foreground,
    required this.heading,
    required this.mutedSurface,
    required this.mutedForeground,
    required this.placeholder,
    required this.primary,
    required this.onPrimary,
    required this.tonalSurface,
    required this.tonalForeground,
    required this.primaryText,
    required this.border,
    required this.input,
    required this.ring,
    required this.destructive,
    required this.onDestructive,
    required this.destructiveSurface,
    required this.onDestructiveSurface,
    required this.disabledSurface,
    required this.disabledForeground,
    required this.scrim,
  });

  final Brightness brightness;
  final int canvas;
  final int surface;
  final int surfaceRaised;
  final int foreground;
  final int heading;
  final int mutedSurface;
  final int mutedForeground;
  final int placeholder;
  final int primary;
  final int onPrimary;
  final int tonalSurface;
  final int tonalForeground;
  final int primaryText;
  final int border;
  final int input;
  final int ring;
  final int destructive;
  final int onDestructive;
  final int destructiveSurface;
  final int onDestructiveSurface;
  final int disabledSurface;
  final int disabledForeground;
  final int scrim;

  static const _Roles light = _Roles(
    brightness: Brightness.light,
    canvas: BldLightColors.background,
    surface: BldLightColors.card,
    surfaceRaised: BldLightColors.surface2,
    foreground: BldLightColors.foreground,
    heading: BldLightColors.heading,
    mutedSurface: BldLightColors.muted,
    mutedForeground: BldLightColors.mutedForeground,
    placeholder: BldLightColors.placeholder,
    // Birincil DOLGU brand700'den başlar: brand500 ve daha açığı beyaz metin
    // taşımaz (3,72 < 4,50). Bu kural kod tabanına bir kez turuncuyla
    // öğretildi, ikinci kez öğretilmeyecek.
    primary: BldLightColors.primary,
    onPrimary: BldLightColors.primaryForeground,
    tonalSurface: BldLightColors.secondary,
    tonalForeground: BldLightColors.secondaryForeground,
    primaryText: BldLightColors.primaryText,
    border: BldLightColors.border,
    input: BldLightColors.input,
    ring: BldLightColors.ring,
    destructive: BldLightColors.danger,
    onDestructive: BldColors.neutral0,
    destructiveSurface: BldLightColors.dangerSurface,
    onDestructiveSurface: BldLightColors.dangerForeground,
    disabledSurface: BldColors.neutral200,
    // Devre dışı metin neutral500: neutral400 metin DEĞİLDİR (kenarlık/ikon
    // rengidir) ve devre dışı bir butonun etiketi hâlâ okunmak zorunda —
    // kullanıcı neden basamadığını ancak okuyabildiği bir etiketle anlar.
    disabledForeground: BldColors.neutral500,
    scrim: BldColors.neutral900,
  );

  static const _Roles dark = _Roles(
    brightness: Brightness.dark,
    canvas: BldDarkColors.background,
    surface: BldDarkColors.card,
    surfaceRaised: BldDarkColors.surface2,
    foreground: BldDarkColors.foreground,
    heading: BldDarkColors.heading,
    mutedSurface: BldDarkColors.muted,
    mutedForeground: BldDarkColors.mutedForeground,
    placeholder: BldDarkColors.placeholder,
    // Koyu temada dolgu AÇIK (brand300), üstündeki yazı KOYU (#1B120C, 9,22).
    // Koyu zeminde koyu bir dolgu düğmeyi kaybediyor; ilişki tersine döner.
    primary: BldDarkColors.primary,
    onPrimary: BldDarkColors.primaryForeground,
    tonalSurface: BldDarkColors.secondary,
    tonalForeground: BldDarkColors.secondaryForeground,
    // METİN olarak marka rengi brand400 (6,95); dolgunun brand300'ü metin
    // için gereğinden parlak ve göz yorar.
    primaryText: BldDarkColors.primaryText,
    border: BldDarkColors.border,
    input: BldDarkColors.input,
    ring: BldDarkColors.ring,
    destructive: BldDarkColors.destructive,
    onDestructive: BldDarkColors.destructiveForeground,
    destructiveSurface: BldDarkColors.dangerSurface,
    onDestructiveSurface: BldDarkColors.dangerForeground,
    disabledSurface: BldDarkColors.muted,
    disabledForeground: BldColors.neutral400,
    scrim: BldColors.neutral950,
  );
}

abstract final class BldTheme {
  /// Açık tema — uygulamanın bugün gönderdiği tek tema.
  static ThemeData light() =>
      _light ??= _build(_Roles.light, BldSemanticColors.light());

  /// Koyu tema.
  ///
  /// Tanımı burada duruyor ama `themeMode` henüz `light`'a kilitli; nedeni
  /// `app.dart`'ta yazılı.
  static ThemeData dark() =>
      _dark ??= _build(_Roles.dark, BldSemanticColors.dark());

  // Temalar BİR KEZ kuruluyor. `MaterialApp` uygulamanın kökünde ve her
  // yönlendirici değişikliğinde yeniden çiziliyor; `theme:`/`darkTheme:`
  // argümanları o çizimlerin hepsinde yeniden hesaplanırdı. `ColorScheme
  // .fromSeed` ucuz bir çağrı değil ve `ThemeData` değişmez — aynı örneği
  // vermek ayrıca `Theme` altındaki ağacın gereksiz yere yeniden çizilmesini
  // de önlüyor (kimlik karşılaştırması eşit çıkıyor).
  static ThemeData? _light;
  static ThemeData? _dark;

  static ThemeData _build(_Roles roles, BldSemanticColors semantic) {
    // NEDEN `fromSeed` + kapsamlı `copyWith`, elle 30-argümanlı `ColorScheme`
    // DEĞİL: seed'in ürettiği rastgele ara tonlar "jenerik Material" hissinin
    // kaynağıdır; hepsini burada paletle EZİYORUZ. Kalan (yalnız iç) türevler
    // için seed pratik bir taban; kırılgan bir literal yerine bu güvenli.
    final scheme =
        ColorScheme.fromSeed(
          seedColor: bldColor(BldColors.brand700),
          brightness: roles.brightness,
        ).copyWith(
          primary: bldColor(roles.primary),
          onPrimary: bldColor(roles.onPrimary),
          primaryContainer: bldColor(roles.tonalSurface),
          onPrimaryContainer: bldColor(roles.tonalForeground),
          // `secondaryContainer` BİLEREK tonal butonun zemini: `FilledButton`
          // ile `FilledButton.tonal` arasındaki tek fark budur. Buton
          // temasında `backgroundColor` sabitlenirse tonal varyant birincil
          // butonun tıpatıp aynısına dönüşür ve beş basamaklı buton
          // hiyerarşisi dörde iner.
          secondary: bldColor(roles.primaryText),
          onSecondary: bldColor(roles.onPrimary),
          secondaryContainer: bldColor(roles.tonalSurface),
          onSecondaryContainer: bldColor(roles.tonalForeground),
          tertiary: bldColor(roles.mutedForeground),
          onTertiary: bldColor(roles.surface),
          surface: bldColor(roles.surface),
          onSurface: bldColor(roles.foreground),
          onSurfaceVariant: bldColor(roles.mutedForeground),
          surfaceContainerLowest: bldColor(roles.surface),
          surfaceContainerLow: bldColor(roles.canvas),
          surfaceContainer: bldColor(roles.mutedSurface),
          surfaceContainerHigh: bldColor(roles.mutedSurface),
          surfaceContainerHighest: bldColor(roles.surfaceRaised),
          error: bldColor(roles.destructive),
          onError: bldColor(roles.onDestructive),
          errorContainer: bldColor(roles.destructiveSurface),
          onErrorContainer: bldColor(roles.onDestructiveSurface),
          // DEKORATİF kenarlık ile İŞLEVSEL kenarlık ayrı rollerdir:
          // dokunulabilir bir sınır 3:1 ister (WCAG 1.4.11), bir ayraç
          // istemez. `outline` işlevsel, `outlineVariant` dekoratif.
          outline: bldColor(roles.input),
          outlineVariant: bldColor(roles.border),
          scrim: bldColor(roles.scrim),
          // Gölgeyi kendimiz veriyoruz; M3 tonal yükseklik yıkamasını kapat.
          surfaceTint: Colors.transparent,
        );

    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: BldFontFamily.body,
      scaffoldBackgroundColor: bldColor(roles.canvas),
      splashFactory: InkSparkle.splashFactory,
      extensions: [semantic],
    );

    final foreground = bldColor(roles.foreground);
    final heading = bldColor(roles.heading);
    final muted = bldColor(roles.mutedForeground);
    final ring = bldColor(roles.ring);

    final textTheme = TextTheme(
      // ── SERİF: isim ve başlık ──
      displayLarge: _serif(
        BldTextScale.display,
        BldTextScale.displayLineHeight,
        color: heading,
      ),
      displayMedium: _serif(
        BldTextScale.h1,
        BldTextScale.h1LineHeight,
        color: heading,
      ),
      displaySmall: _serif(
        BldTextScale.h2,
        BldTextScale.h2LineHeight,
        color: heading,
      ),
      headlineLarge: _serif(
        BldTextScale.h1,
        BldTextScale.h1LineHeight,
        color: heading,
      ),
      headlineMedium: _serif(
        BldTextScale.h2,
        BldTextScale.h2LineHeight,
        color: heading,
      ),
      headlineSmall: _serif(
        BldTextScale.h3,
        BldTextScale.h3LineHeight,
        weight: FontWeight.w600,
        color: heading,
      ),
      // `titleLarge` bölüm başlığıdır (h3) — bu uygulamada `SectionHeader` ve
      // boş durum başlığı onu okuyor.
      titleLarge: _serif(
        BldTextScale.h3,
        BldTextScale.h3LineHeight,
        weight: FontWeight.w600,
        color: heading,
      ),
      // Kart başlığı / ürün adı: bir İSİMDİR, serif.
      titleMedium: _serif(
        BldTextScale.title,
        BldTextScale.titleLineHeight,
        weight: FontWeight.w600,
        color: heading,
      ),
      // ── INTER: işlevsel metin ──
      titleSmall: _sans(
        BldTextScale.label,
        BldTextScale.labelLineHeight,
        weight: FontWeight.w600,
        color: foreground,
      ),
      bodyLarge: _sans(
        BldTextScale.bodyLg,
        BldTextScale.bodyLgLineHeight,
        color: foreground,
      ),
      bodyMedium: _sans(
        BldTextScale.body,
        BldTextScale.bodyLineHeight,
        color: foreground,
      ),
      bodySmall: _sans(
        BldTextScale.bodySm,
        BldTextScale.bodySmLineHeight,
        color: muted,
      ),
      labelLarge: _sans(
        BldTextScale.body,
        BldTextScale.bodyLineHeight,
        weight: FontWeight.w600,
        color: foreground,
      ),
      labelMedium: _sans(
        BldTextScale.caption,
        BldTextScale.captionLineHeight,
        weight: FontWeight.w600,
        color: muted,
      ),
      // `overline`: büyük harf TASARIMDA vardır ama `text-transform`
      // karşılığıyla ZORLANMAZ — Türkçe'de "İ/ı" kırılır. Metin gerekiyorsa
      // zaten büyük yazılır.
      labelSmall: _sans(
        BldTextScale.overline,
        BldTextScale.overlineLineHeight,
        weight: FontWeight.w700,
        color: muted,
        letterSpacing: BldTextScale.overline * BldTextScale.overlineTracking,
      ),
    );

    final buttonText = _sans(
      BldTextScale.body,
      BldTextScale.bodyLineHeight,
      weight: FontWeight.w600,
      color: foreground,
    );

    return base.copyWith(
      textTheme: textTheme,
      // AppBar dolu marka rengi DEĞİL: yüzey zemini + marka kahvesi başlık,
      // kaydırınca ince gölge. Marka vurgusu hero'ya ve birincil eyleme
      // saklandı.
      appBarTheme: AppBarTheme(
        backgroundColor: bldColor(roles.surface),
        foregroundColor: heading,
        elevation: 0,
        scrolledUnderElevation: roles.brightness == Brightness.light ? 3 : 0,
        shadowColor: bldColor(BldColors.neutral900).withValues(alpha: 0.06),
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium,
        iconTheme: IconThemeData(color: foreground),
      ),
      cardTheme: CardThemeData(
        color: bldColor(roles.surface),
        // Koyu temada gölge yok: yükseltme açıklık adımıyla anlatılıyor
        // (bkz. [BldSurfaceLevel]).
        elevation: roles.brightness == Brightness.light ? 3 : 0,
        shadowColor: bldColor(BldColors.neutral900).withValues(alpha: 0.10),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BldRadius.md),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: bldColor(roles.mutedSurface),
        selectedColor: bldColor(roles.tonalSurface),
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: bldColor(roles.tonalForeground),
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
        fillColor: bldColor(roles.surface),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: BldSpacing.md,
          vertical: BldSpacing.md - 2,
        ),
        // Etiket alanın ÜSTÜNDE durur ve orada KALIR. Yüzen etiket Türkçe uzun
        // sözcüklerde ve autofill sırasında alanın içine biniyordu; hareketli
        // etiket ayrıca hata metniyle aynı bölgeyi paylaşıyor.
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: textTheme.titleSmall?.copyWith(color: muted),
        floatingLabelStyle: textTheme.titleSmall?.copyWith(color: muted),
        // İpucu metni okunmak zorunda: placeholder rolü neutral500'dür,
        // neutral400 DEĞİL (o kenarlık/ikon rengi).
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: bldColor(roles.placeholder),
        ),
        helperStyle: textTheme.bodySmall,
        errorStyle: textTheme.bodySmall?.copyWith(
          color: bldColor(roles.onDestructiveSurface),
        ),
        // İki satır: Türkçe doğrulama metinleri ("Bu alanı doldurmanız
        // gerekiyor") tek satıra sığmadığında kırpılmak yerine sarmalanır.
        errorMaxLines: 2,
        helperMaxLines: 2,
        border: _inputBorder(bldColor(roles.input)),
        enabledBorder: _inputBorder(bldColor(roles.input)),
        focusedBorder: _inputBorder(ring, width: 2),
        disabledBorder: _inputBorder(bldColor(roles.border)),
        errorBorder: _inputBorder(bldColor(roles.destructive)),
        focusedErrorBorder: _inputBorder(bldColor(roles.destructive), width: 2),
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
      //
      // Dolgu ve yazı rengi BİLEREK verilmiyor: `FilledButton` şemanın
      // `primary`'sini, `FilledButton.tonal` `secondaryContainer`'ını okuyor
      // ve ikisi ayrı basamak olarak kalıyor (bkz. `secondaryContainer`
      // yorumu).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          disabledBackgroundColor: bldColor(roles.disabledSurface),
          disabledForegroundColor: bldColor(roles.disabledForeground),
          elevation: 0,
          textStyle: buttonText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BldRadius.sm),
          ),
        ).copyWith(side: _focusOnlySide(ring)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              // 50 değil 48: `BldSpacing` 4'ün katları üzerine kurulu ve 44 px
              // asgari dokunma hedefi zaten aşılıyor.
              minimumSize: const Size.fromHeight(48),
              foregroundColor: bldColor(roles.primaryText),
              disabledForegroundColor: bldColor(roles.disabledForeground),
              textStyle: buttonText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(BldRadius.sm),
              ),
            ).copyWith(
              // Kenar İŞLEVSEL kenarlık rengindedir (neutral400 / #75655A):
              // marka rampasının açık tonu (eski brand300) beyaz üstünde
              // 2,00'da kalıyordu ve butonun sınırı kayboluyordu.
              side: _focusOnlySide(
                ring,
                base: BorderSide(color: bldColor(roles.input)),
              ),
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: bldColor(roles.primaryText),
          disabledForegroundColor: bldColor(roles.disabledForeground),
          minimumSize: const Size(0, 44),
          textStyle: buttonText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BldRadius.sm),
          ),
        ).copyWith(side: _focusOnlySide(ring)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: bldColor(roles.primaryText),
          disabledForegroundColor: bldColor(roles.disabledForeground),
          // İkon-yalnız buton da 44×44'ü tutmak zorunda.
          minimumSize: const Size(44, 44),
        ).copyWith(side: _focusOnlySide(ring)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? bldColor(roles.primary)
                : bldColor(roles.surface),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? bldColor(roles.onPrimary)
                : muted,
          ),
          textStyle: WidgetStatePropertyAll(buttonText),
          side: _focusOnlySide(
            ring,
            base: BorderSide(color: bldColor(roles.input)),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BldRadius.sm),
            ),
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: bldColor(roles.primaryText),
        unselectedLabelColor: muted,
        indicatorColor: bldColor(roles.primary),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: bldColor(roles.border),
        labelStyle: buttonText,
        unselectedLabelStyle: textTheme.bodyMedium,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodySmall,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BldRadius.md),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: bldColor(
          roles.brightness == Brightness.light
              ? roles.surface
              : roles.surfaceRaised,
        ),
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(BldRadius.lg),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: bldColor(
          roles.brightness == Brightness.light
              ? roles.surface
              : roles.surfaceRaised,
        ),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BldRadius.lg),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bldColor(roles.surface),
        indicatorColor: bldColor(roles.tonalSurface),
        surfaceTintColor: Colors.transparent,
        elevation: roles.brightness == Brightness.light ? 3 : 0,
        shadowColor: bldColor(BldColors.neutral900).withValues(alpha: 0.08),
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? bldColor(roles.tonalForeground)
                : muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) =>
              textTheme.labelMedium?.copyWith(
                color: states.contains(WidgetState.selected)
                    ? bldColor(roles.tonalForeground)
                    : muted,
              ) ??
              const TextStyle(),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: bldColor(roles.border),
        space: 1,
        thickness: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: bldColor(roles.primary),
        linearTrackColor: bldColor(roles.mutedSurface),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: bldColor(
          roles.brightness == Brightness.light
              ? BldColors.neutral900
              : BldColors.neutral200,
        ),
        contentTextStyle: _sans(
          BldTextScale.body,
          BldTextScale.bodyLineHeight,
          color: bldColor(
            roles.brightness == Brightness.light
                ? BldColors.neutral0
                : BldColors.neutral900,
          ),
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

  /// Serif (isim/başlık) stili.
  ///
  /// `opsz` ekseni ELLE veriliyor: web'de `font-optical-sizing: auto` bunu
  /// kendiliğinden yapıyor, Flutter yapmıyor (bkz. `assets/fonts/README.md`).
  /// Eksen olmadan 44 punto başlık, 13 punto etiketle aynı kalınlıkta
  /// çiziliyor ve Source Serif 4'ün seçilme gerekçesi boşa gidiyor.
  static TextStyle _serif(
    double size,
    double lineHeight, {
    FontWeight weight = FontWeight.w700,
    required Color color,
  }) => TextStyle(
    fontFamily: BldFontFamily.display,
    fontSize: size,
    height: lineHeight / size,
    fontWeight: weight,
    letterSpacing: BldFontFamily.displayLetterSpacing,
    color: color,
    fontFeatures: kBldTabularFigures,
    fontVariations: [
      // Alt kümede `wght` 400–700'e daraltıldı; dışına çıkan bir istek
      // fontun kendisi tarafından kırpılır, biz de burada kırpıyoruz ki
      // istenen ile çizilen aynı olsun.
      FontVariation('wght', weight.value.clamp(400, 700).toDouble()),
      // Source Serif 4'ün `opsz` ekseni 8–60.
      FontVariation('opsz', size.clamp(8, 60)),
    ],
  );

  /// Inter (işlevsel metin) stili.
  static TextStyle _sans(
    double size,
    double lineHeight, {
    FontWeight weight = FontWeight.w400,
    required Color color,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: BldFontFamily.body,
    fontSize: size,
    height: lineHeight / size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    fontFeatures: kBldTabularFigures,
  );

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(BldRadius.sm),
        borderSide: BorderSide(color: color, width: width),
      );

  /// Odaklandığında 2 px halka çizen kenar; diğer durumlarda [base].
  ///
  /// **Neden butonda ofset YOK:** `ButtonStyle` yalnız butonun kendi kenarını
  /// verebiliyor, kutunun dışına boyayamıyor. Ofsetli halka için
  /// [bldFocusRing] ve onu kullanan `BldFocusRing` bileşeni var; buton
  /// gövdesinde halka kenarın kendisi oluyor. Görünürlük hedefi tutuluyor,
  /// yalnız ofset düşüyor.
  static WidgetStateProperty<BorderSide?> _focusOnlySide(
    Color ring, {
    BorderSide? base,
  }) => WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.focused)
        ? BorderSide(color: ring, width: 2)
        : base,
  );
}
