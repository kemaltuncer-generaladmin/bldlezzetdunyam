/// Material `ColorScheme`'in karşılığı olmayan marka rolleri.
///
/// **Neden bir `ThemeExtension`, doğrudan `BldColors` sabitleri değil:** ham
/// sabit çağrısı temayı ATLAR. Ölçüldü — `lib/` içinde tema dosyasının dışında
/// 143 doğrudan `BldColors.` çağrısı vardı ve bunların 43'ü `neutral0`'ı
/// "beyaz" diye kullanıyordu. Koyu temada o beyazlar beyaz zemin üstünde beyaz
/// metne dönüşür; hata derlenmez, yalnız cihazda görünür. Rolü `Theme.of` ile
/// okumak bu sınıfı yapısal olarak imkânsız kılar.
///
/// **Neden `ColorScheme`'e sığmıyor:** `ColorScheme` bir tasarım sisteminin
/// tamamını değil Material'ın kendi rollerini taşır. Başlık rengi (marka
/// kahvesi), işlevsel/dekoratif kenarlık ayrımı, para işareti renkleri,
/// iskelet tonları ve fotoğraf iç halkası Material'da karşılıksızdır. Bunları
/// `secondary`, `tertiary` gibi boş slotlara doldurmak, o slotu okuyan
/// Material bileşenlerini (Chip, SnackBar, Badge) sessizce bozar.
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';

@immutable
class BldSemanticColors extends ThemeExtension<BldSemanticColors> {
  const BldSemanticColors({
    required this.heading,
    required this.canvas,
    required this.surfaceRaised,
    required this.inputBorder,
    required this.decorativeBorder,
    required this.successFg,
    required this.successBg,
    required this.warningFg,
    required this.warningBg,
    required this.dangerFg,
    required this.dangerBg,
    required this.infoFg,
    required this.infoBg,
    required this.moneyPositive,
    required this.moneyCredit,
    required this.moneyDebt,
    required this.placeholder,
    required this.skeletonBase,
    required this.skeletonShine,
    required this.photoRing,
    required this.focusRing,
  });

  /// Başlık rengi — açık temada marka kahvesi (`brand900`).
  ///
  /// Gövde metninden AYRI bir rol: başlıkları markanın kahvesiyle çizmek, web
  /// ve mobili tek ürün gibi gösteren en ucuz hamle. Gövde metni nötr kalır,
  /// yoksa sayfa tek renge boyanmış gibi okunur.
  final Color heading;

  /// Sayfa zemini (`Scaffold`). Karttan bir adım GERİDE durur.
  final Color canvas;

  /// Yükseltilmiş yüzey — seçili kart, sabit alt çubuk.
  ///
  /// **Koyu temada yükseltme gölge değil AÇIKLIK adımıdır:** siyaha yakın bir
  /// zeminde gölge görünmez, çünkü gölge zaten zeminden koyu olamaz. Bu yüzden
  /// koyu temada `surfaceRaised` karttan bir ton AÇIK; açık temada ikisi de
  /// beyazdır ve farkı gölge taşır.
  final Color surfaceRaised;

  /// İŞLEVSEL kenarlık — form alanı, seçilebilir kutu, girdi çerçevesi.
  ///
  /// Dekoratif kenarlıktan koyudur: kullanıcının dokunabileceği bir sınır
  /// 3:1 kontrast ister (WCAG 1.4.11). Açık temada `neutral400`.
  final Color inputBorder;

  /// DEKORATİF kenarlık — ayraç, kart çerçevesi, liste çizgisi.
  ///
  /// Bilgi taşımaz; kontrast eşiği yoktur. Açık temada `neutral200`.
  final Color decorativeBorder;

  /// Başarı metni/ikonu. Zemin için [successBg].
  final Color successFg;

  /// Başarı yüzeyi (tint). Üstüne [successFg] yazılır.
  final Color successBg;

  /// Uyarı metni/ikonu.
  final Color warningFg;

  /// Uyarı yüzeyi (tint) — çevrimdışı şeridi de bunu kullanır.
  final Color warningBg;

  /// Hata metni/ikonu; yıkıcı eylemin yazı rengi.
  final Color dangerFg;

  /// Hata yüzeyi (tint).
  final Color dangerBg;

  /// Bilgi metni/ikonu.
  final Color infoFg;

  /// Bilgi yüzeyi (tint).
  final Color infoBg;

  /// Nötr para farkı ("+12,00 ₺ kargo") — dikkat çekmez.
  final Color moneyPositive;

  /// İndirim/alacak — müşterinin LEHİNE olan tutar.
  final Color moneyCredit;

  /// Borç — müşterinin ALEYHİNE olan tutar.
  final Color moneyDebt;

  /// Boş form alanı ipucu metni.
  ///
  /// `decorativeBorder`'dan koyu olmak ZORUNDA: ipucu metindir ve okunması
  /// gerekir. Açık temada `neutral500` (6,20:1), `neutral400` DEĞİL.
  final Color placeholder;

  /// İskelet bloğunun taban rengi.
  final Color skeletonBase;

  /// İskeletin üzerinden geçen parıltı.
  final Color skeletonShine;

  /// Fotoğrafın üzerine çizilen 1 px iç halka.
  ///
  /// **Neden var:** beyaz tabaklı yemek fotoğrafı beyaz kartın içinde eriyor ve
  /// kartın kenarı kayboluyordu. Halka fotoğrafın sınırını geri veriyor.
  final Color photoRing;

  /// Klavye odağı halkası (açık temada `brand600`, koyu temada `brand400`).
  ///
  /// `ColorScheme`'de karşılığı yok: Material'ın `focusColor`'ı bir DOLGU
  /// rengidir (odaklanan yüzeye sürülen yıkama), halka değil. Oraya opak bir
  /// marka rengi koymak her odaklanan satırı turuncuya boyardı.
  final Color focusRing;

  /// Açık tema rolleri (`BldLightColors`).
  static BldSemanticColors light() => const BldSemanticColors(
    heading: Color(BldLightColors.heading),
    canvas: Color(BldLightColors.background),
    surfaceRaised: Color(BldLightColors.surface2),
    inputBorder: Color(BldLightColors.input),
    decorativeBorder: Color(BldLightColors.border),
    successFg: Color(BldLightColors.successForeground),
    successBg: Color(BldLightColors.successSurface),
    warningFg: Color(BldLightColors.warningForeground),
    warningBg: Color(BldLightColors.warningSurface),
    dangerFg: Color(BldLightColors.dangerForeground),
    dangerBg: Color(BldLightColors.dangerSurface),
    infoFg: Color(BldLightColors.infoForeground),
    infoBg: Color(BldLightColors.infoSurface),
    moneyPositive: Color(BldColors.neutral600),
    moneyCredit: Color(BldColors.success700),
    moneyDebt: Color(BldColors.danger700),
    placeholder: Color(BldLightColors.placeholder),
    skeletonBase: Color(BldLightColors.skeletonBase),
    skeletonShine: Color(BldLightColors.skeletonSheen),
    photoRing: _lightPhotoRing,
    focusRing: Color(BldLightColors.ring),
  );

  /// Koyu tema rolleri (`BldDarkColors`).
  static BldSemanticColors dark() => const BldSemanticColors(
    heading: Color(BldDarkColors.heading),
    canvas: Color(BldDarkColors.background),
    surfaceRaised: Color(BldDarkColors.surface2),
    inputBorder: Color(BldDarkColors.input),
    decorativeBorder: Color(BldDarkColors.border),
    successFg: Color(BldDarkColors.successForeground),
    successBg: Color(BldDarkColors.successSurface),
    warningFg: Color(BldDarkColors.warningForeground),
    warningBg: Color(BldDarkColors.warningSurface),
    dangerFg: Color(BldDarkColors.dangerForeground),
    dangerBg: Color(BldDarkColors.dangerSurface),
    infoFg: Color(BldDarkColors.infoForeground),
    infoBg: Color(BldDarkColors.infoSurface),
    moneyPositive: Color(BldColors.neutral300),
    moneyCredit: Color(BldColors.success400),
    moneyDebt: Color(BldColors.danger300),
    placeholder: Color(BldDarkColors.placeholder),
    skeletonBase: Color(BldDarkColors.skeletonBase),
    skeletonShine: Color(BldDarkColors.skeletonSheen),
    // Koyu temada halka AÇIK olmalı: fotoğrafın kenarı koyu yüzeyde koyu bir
    // çizgiyle değil, ancak açık bir çizgiyle ayrılır.
    photoRing: _darkPhotoRing,
    focusRing: Color(BldDarkColors.ring),
  );

  /// `rgb(42 26 18 / .06)` — marka kılavuzundaki fotoğraf halkası.
  static const Color _lightPhotoRing = Color(0x0F2A1A12);

  /// `rgb(255 255 255 / .08)`.
  static const Color _darkPhotoRing = Color(0x14FFFFFF);

  @override
  BldSemanticColors copyWith({
    Color? heading,
    Color? canvas,
    Color? surfaceRaised,
    Color? inputBorder,
    Color? decorativeBorder,
    Color? successFg,
    Color? successBg,
    Color? warningFg,
    Color? warningBg,
    Color? dangerFg,
    Color? dangerBg,
    Color? infoFg,
    Color? infoBg,
    Color? moneyPositive,
    Color? moneyCredit,
    Color? moneyDebt,
    Color? placeholder,
    Color? skeletonBase,
    Color? skeletonShine,
    Color? photoRing,
    Color? focusRing,
  }) => BldSemanticColors(
    heading: heading ?? this.heading,
    canvas: canvas ?? this.canvas,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    inputBorder: inputBorder ?? this.inputBorder,
    decorativeBorder: decorativeBorder ?? this.decorativeBorder,
    successFg: successFg ?? this.successFg,
    successBg: successBg ?? this.successBg,
    warningFg: warningFg ?? this.warningFg,
    warningBg: warningBg ?? this.warningBg,
    dangerFg: dangerFg ?? this.dangerFg,
    dangerBg: dangerBg ?? this.dangerBg,
    infoFg: infoFg ?? this.infoFg,
    infoBg: infoBg ?? this.infoBg,
    moneyPositive: moneyPositive ?? this.moneyPositive,
    moneyCredit: moneyCredit ?? this.moneyCredit,
    moneyDebt: moneyDebt ?? this.moneyDebt,
    placeholder: placeholder ?? this.placeholder,
    skeletonBase: skeletonBase ?? this.skeletonBase,
    skeletonShine: skeletonShine ?? this.skeletonShine,
    photoRing: photoRing ?? this.photoRing,
    focusRing: focusRing ?? this.focusRing,
  );

  /// **Tema geçişi ASLA animasyonlu değildir** (marka kuralı): iki palet
  /// arasında geçen ara kareler markanın olmayan renkler üretir. Yine de
  /// `lerp` doğru uygulanır — `ThemeExtension` sözleşmesi bunu şart koşuyor ve
  /// `AnimatedTheme` dışında `Theme.of` çözümlemesi de bu yolu kullanabilir.
  @override
  BldSemanticColors lerp(ThemeExtension<BldSemanticColors>? other, double t) {
    if (other is! BldSemanticColors) return this;
    return BldSemanticColors(
      heading: Color.lerp(heading, other.heading, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      decorativeBorder: Color.lerp(
        decorativeBorder,
        other.decorativeBorder,
        t,
      )!,
      successFg: Color.lerp(successFg, other.successFg, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      warningFg: Color.lerp(warningFg, other.warningFg, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      dangerFg: Color.lerp(dangerFg, other.dangerFg, t)!,
      dangerBg: Color.lerp(dangerBg, other.dangerBg, t)!,
      infoFg: Color.lerp(infoFg, other.infoFg, t)!,
      infoBg: Color.lerp(infoBg, other.infoBg, t)!,
      moneyPositive: Color.lerp(moneyPositive, other.moneyPositive, t)!,
      moneyCredit: Color.lerp(moneyCredit, other.moneyCredit, t)!,
      moneyDebt: Color.lerp(moneyDebt, other.moneyDebt, t)!,
      placeholder: Color.lerp(placeholder, other.placeholder, t)!,
      skeletonBase: Color.lerp(skeletonBase, other.skeletonBase, t)!,
      skeletonShine: Color.lerp(skeletonShine, other.skeletonShine, t)!,
      photoRing: Color.lerp(photoRing, other.photoRing, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
    );
  }
}

/// `Theme.of(context).extension<BldSemanticColors>()!` kısayolu.
///
/// **Neden `!` güvenli:** uzantı `BldTheme.light()` ve `BldTheme.dark()`'ın
/// ikisinde de kayıtlı; ikisi de uygulamanın TEK tema kaynağı. Kayıtsız bir
/// temayla çağrılırsa burada patlaması, ekranda sessizce yanlış renk
/// çizilmesinden iyidir.
extension BldSemanticColorsAccess on BuildContext {
  BldSemanticColors get bld => Theme.of(this).extension<BldSemanticColors>()!;
}
