/// Para gösterimi — tek bileşen, dört boy, sabit kurallar.
///
/// **Neden `Money.format` sarmalanıyor, değiştirilmiyor:** kuruş matematiği
/// (`packages/core`) doğru ve KDS ile fiş şablonları da onu okuyor. Eksik olan
/// hesap değil SUNUM: hangi boyda, hangi renkte, hangi rakam genişliğinde
/// çizileceği. Bu dosya yalnız onu ekliyor.
///
/// Uygulanan kurallar (marka kılavuzu):
///  * Rakamlar **tabular** — alt alta gelen fiyat sütunu kaymaz.
///  * Para **asla sarmalanmaz, asla kırpılmaz**. Sığmıyorsa düzen yanlıştır;
///    "1.234," diye biten bir tutar yanlış bilgidir.
///  * `₺` rakamlarla AYNI boy ve AYNI renktedir — küçültülmüş bir para birimi
///    işareti tutarı "yaklaşık" gösteriyor.
///  * İşaret rengi anlamdan gelir: nötr fark, müşterinin LEHİNE (alacak/
///    indirim) ve ALEYHİNE (borç) ayrı renklerdedir.
library;

import 'package:bld_core/bld_core.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';

import '../theme/bld_semantic_colors.dart';
import '../theme/bld_theme.dart';

/// Para ölçeğinin dört basamağı.
enum MoneyScale {
  /// Liste satırındaki birim fiyat.
  sm(BldTextScale.moneySm, BldTextScale.moneySmLineHeight, FontWeight.w600),

  /// Kart üzerindeki fiyat.
  md(BldTextScale.moneyMd, BldTextScale.moneyMdLineHeight, FontWeight.w700),

  /// Sepet ara toplamı.
  lg(BldTextScale.moneyLg, BldTextScale.moneyLgLineHeight, FontWeight.w700),

  /// Ödenecek tutar — bir ekranda EN FAZLA bir kez.
  xl(BldTextScale.moneyXl, BldTextScale.moneyXlLineHeight, FontWeight.w700);

  const MoneyScale(this.size, this.lineHeight, this.weight);

  final double size;
  final double lineHeight;
  final FontWeight weight;
}

/// Tutarın taşıdığı anlam — rengi bu belirler.
enum MoneyTone {
  /// Ürün fiyatı, toplam. Gövde metniyle aynı renk.
  plain,

  /// İkincil tutar (birim fiyat, "3 × 45,00 ₺" gibi).
  muted,

  /// Nötr fark: kargo, servis ücreti. Dikkat çekmez.
  difference,

  /// Müşterinin LEHİNE: indirim, iade, alacak.
  credit,

  /// Müşterinin ALEYHİNE: borç.
  debt,

  /// Marka dolgusunun (birincil buton, hero) ÜSTÜNDE.
  onPrimary,
}

/// Kuruş tutarını marka kurallarına göre çizer.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.kurus, {
    super.key,
    this.scale = MoneyScale.md,
    this.tone = MoneyTone.plain,
    this.withSymbol = true,
    this.showPlusSign = false,
    this.textAlign,
  }) : _strikethrough = false;

  /// Üstü çizili ESKİ fiyat.
  ///
  /// Marka kuralı: üstü çizili tutar `neutral400`'dür ve güncel fiyat ONDAN
  /// SONRA gelir. Sıra tersine döndüğünde göz önce eski fiyatı okuyor ve
  /// indirim bir zam gibi görünüyor.
  const MoneyText.previous(
    this.kurus, {
    super.key,
    this.scale = MoneyScale.sm,
    this.withSymbol = true,
    this.textAlign,
  }) : tone = MoneyTone.muted,
       showPlusSign = false,
       _strikethrough = true;

  /// Tutar — **kuruş**. (`41000` → `410,00 ₺`)
  final int kurus;
  final MoneyScale scale;
  final MoneyTone tone;

  /// Fiş dışında hemen her yerde `true`; sembolsüz biçim tablo başlığında
  /// para birimi bir kez yazıldığında işe yarar.
  final bool withSymbol;

  /// Pozitif tutarın başına `+` koyar (fark satırları: "+12,00 ₺ kargo").
  ///
  /// `Money.format` bunu yapmaz ve YAPMAMALI: eksi işareti tutarın kendisine
  /// aittir, artı işareti ise bir SUNUM kararıdır — aynı `4500`, sepet
  /// satırında işaretsiz, fark satırında `+45,00 ₺` diye okunur.
  final bool showPlusSign;

  final TextAlign? textAlign;

  final bool _strikethrough;

  @override
  Widget build(BuildContext context) {
    final formatted = Money.format(kurus, withSymbol: withSymbol);
    final text = showPlusSign && kurus > 0 ? '+$formatted' : formatted;

    return Text(
      text,
      textAlign: textAlign,
      // Para sarmalanmaz ve kırpılmaz: taşma görünür kalır ki düzen hatası
      // sessizce yanlış bir tutara dönüşmesin.
      softWrap: false,
      maxLines: 1,
      overflow: TextOverflow.visible,
      style: styleOf(
        context,
        scale: scale,
        tone: tone,
        strikethrough: _strikethrough,
      ),
    );
  }

  /// Para stilini tek yerden verir — `RichText`/`TextSpan` kuran ekranlar da
  /// aynı kuralları alsın diye ayrı bir metot.
  static TextStyle styleOf(
    BuildContext context, {
    MoneyScale scale = MoneyScale.md,
    MoneyTone tone = MoneyTone.plain,
    bool strikethrough = false,
  }) {
    final theme = Theme.of(context);
    final bld = context.bld;

    final color = switch (tone) {
      MoneyTone.plain => theme.colorScheme.onSurface,
      MoneyTone.muted =>
        strikethrough
            // Üstü çizili fiyat için marka kılavuzu neutral400 diyor: metin
            // rolü DEĞİL ama bu tutar da artık bilgi taşımıyor — geçerli olan
            // yanındaki fiyat.
            ? bldColor(BldColors.neutral400)
            : theme.colorScheme.onSurfaceVariant,
      MoneyTone.difference => bld.moneyPositive,
      MoneyTone.credit => bld.moneyCredit,
      MoneyTone.debt => bld.moneyDebt,
      MoneyTone.onPrimary => theme.colorScheme.onPrimary,
    };

    return TextStyle(
      // Para İŞLEVSEL metindir: Inter. Serif rakamları hizasız (old-style)
      // çizebiliyor ve fiyat sütunu bozuluyor.
      fontFamily: BldFontFamily.body,
      fontSize: scale.size,
      height: scale.lineHeight / scale.size,
      fontWeight: scale.weight,
      color: color,
      fontFeatures: kBldTabularFigures,
      decoration: strikethrough ? TextDecoration.lineThrough : null,
      decorationColor: color,
    );
  }
}
