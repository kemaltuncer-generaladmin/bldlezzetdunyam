/// PC857 (IBM857 / DOS Latin-5) kod sayfası çevirisi — `docs/05-mutfakapp.md` §5.2.
///
/// **Neden gerekli:** termal yazıcı UTF-8 anlamaz. Yazıcıya `ESC t n` ile bu
/// düzendeki kod sayfası seçtirilir ve metin tek bayta bu tabloya göre
/// çevrilir. Çevirmeden UTF-8 gönderilirse "ç" iki bayt olarak basılır ve
/// fişte "Ã§" görünür.
///
/// **Seçim numarası tablonun parçası değildir.** Sahadaki yazıcıda doğru değer
/// `n = 29`'dur, PC857'nin yaygın numarası olan 13 değil — gerekçe
/// [EscPosCommands.turkishCodePage] belgesinde. Bayt düzeni yine de tam olarak
/// aşağıdaki tablodur; doğrulama gerçek donanımda yapılmıştır.
///
/// Tablonun kaynağı Unicode Konsorsiyumu'nun `CP857.TXT` eşlemesidir.
/// 0x00–0x7F aralığı ASCII ile birebir aynıdır, bu yüzden tabloda tutulmaz.
library;

import 'dart:typed_data';

/// UTF-16 metni PC857 baytlarına çevirir.
abstract final class Pc857 {
  /// Tabloda karşılığı olmayan karakterin yerine basılan bayt (`?`).
  static const int replacementByte = 0x3F;

  /// Türkçe'nin PC857'de karşılığı olan **12** harfi.
  ///
  /// Kabul ölçütü bunların hepsinin doğru basılmasıdır (`docs/05` §5.2).
  static const String turkishLetters = 'çğıöşüÇĞİÖŞÜ';

  /// Metni tek baytlık PC857 dizisine çevirir.
  ///
  /// Tabloda olmayan karakterler önce [_transliterations] ile sadeleştirilir
  /// (tipografik tırnak, uzun tire, ₺ gibi ürün adlarına sızan karakterler),
  /// hâlâ karşılığı yoksa [replacementByte] basılır. Yazdırma hiçbir zaman
  /// istisna atmaz: mutfakta fişin eksik çıkması, hiç çıkmamasından iyidir.
  static Uint8List encode(String text) {
    final out = BytesBuilder(copy: false);

    for (final rune in text.runes) {
      final direct = _encodeRune(rune);
      if (direct != null) {
        out.addByte(direct);
        continue;
      }

      final fallback = _transliterations[rune];
      if (fallback == null) {
        out.addByte(replacementByte);
        continue;
      }
      for (final substitute in fallback.runes) {
        out.addByte(_encodeRune(substitute) ?? replacementByte);
      }
    }

    return out.toBytes();
  }

  /// [text] tamamen PC857'de temsil edilebiliyor mu? (Çeviri tablosu hariç.)
  ///
  /// Ayarlar ekranındaki "test fişi" ve geliştirme denetimleri için.
  static bool canEncode(String text) =>
      text.runes.every((rune) => _encodeRune(rune) != null);

  /// Tek bir kod noktasının PC857 karşılığı; yoksa `null`.
  static int? _encodeRune(int rune) {
    if (rune < 0x80) return rune;
    return _highBytes[rune];
  }

  /// Kod noktası → 0x80–0xFF aralığındaki PC857 baytı.
  ///
  /// Tanımsız konumlar (0xD5, 0xE7, 0xF2) tabloda bilinçli olarak yoktur.
  static const Map<int, int> _highBytes = {
    0x00C7: 0x80, // Ç
    0x00FC: 0x81, // ü
    0x00E9: 0x82, // é
    0x00E2: 0x83, // â
    0x00E4: 0x84, // ä
    0x00E0: 0x85, // à
    0x00E5: 0x86, // å
    0x00E7: 0x87, // ç
    0x00EA: 0x88, // ê
    0x00EB: 0x89, // ë
    0x00E8: 0x8A, // è
    0x00EF: 0x8B, // ï
    0x00EE: 0x8C, // î
    0x0131: 0x8D, // ı
    0x00C4: 0x8E, // Ä
    0x00C5: 0x8F, // Å
    0x00C9: 0x90, // É
    0x00E6: 0x91, // æ
    0x00C6: 0x92, // Æ
    0x00F4: 0x93, // ô
    0x00F6: 0x94, // ö
    0x00F2: 0x95, // ò
    0x00FB: 0x96, // û
    0x00F9: 0x97, // ù
    0x0130: 0x98, // İ
    0x00D6: 0x99, // Ö
    0x00DC: 0x9A, // Ü
    0x00F8: 0x9B, // ø
    0x00A3: 0x9C, // £
    0x00D8: 0x9D, // Ø
    0x015E: 0x9E, // Ş
    0x015F: 0x9F, // ş
    0x00E1: 0xA0, // á
    0x00ED: 0xA1, // í
    0x00F3: 0xA2, // ó
    0x00FA: 0xA3, // ú
    0x00F1: 0xA4, // ñ
    0x00D1: 0xA5, // Ñ
    0x011E: 0xA6, // Ğ
    0x011F: 0xA7, // ğ
    0x00BF: 0xA8, // ¿
    0x00AE: 0xA9, // ®
    0x00AC: 0xAA, // ¬
    0x00BD: 0xAB, // ½
    0x00BC: 0xAC, // ¼
    0x00A1: 0xAD, // ¡
    0x00AB: 0xAE, // «
    0x00BB: 0xAF, // »
    0x2591: 0xB0, // ░
    0x2592: 0xB1, // ▒
    0x2593: 0xB2, // ▓
    0x2502: 0xB3, // │
    0x2524: 0xB4, // ┤
    0x00C1: 0xB5, // Á
    0x00C2: 0xB6, // Â
    0x00C0: 0xB7, // À
    0x00A9: 0xB8, // ©
    0x2563: 0xB9, // ╣
    0x2551: 0xBA, // ║
    0x2557: 0xBB, // ╗
    0x255D: 0xBC, // ╝
    0x00A2: 0xBD, // ¢
    0x00A5: 0xBE, // ¥
    0x2510: 0xBF, // ┐
    0x2514: 0xC0, // └
    0x2534: 0xC1, // ┴
    0x252C: 0xC2, // ┬
    0x251C: 0xC3, // ├
    0x2500: 0xC4, // ─
    0x253C: 0xC5, // ┼
    0x00E3: 0xC6, // ã
    0x00C3: 0xC7, // Ã
    0x255A: 0xC8, // ╚
    0x2554: 0xC9, // ╔
    0x2569: 0xCA, // ╩
    0x2566: 0xCB, // ╦
    0x2560: 0xCC, // ╠
    0x2550: 0xCD, // ═
    0x256C: 0xCE, // ╬
    0x00A4: 0xCF, // ¤
    0x00BA: 0xD0, // º
    0x00AA: 0xD1, // ª
    0x00CA: 0xD2, // Ê
    0x00CB: 0xD3, // Ë
    0x00C8: 0xD4, // È
    0x00CD: 0xD6, // Í
    0x00CE: 0xD7, // Î
    0x00CF: 0xD8, // Ï
    0x2518: 0xD9, // ┘
    0x250C: 0xDA, // ┌
    0x2588: 0xDB, // █
    0x2584: 0xDC, // ▄
    0x00A6: 0xDD, // ¦
    0x00CC: 0xDE, // Ì
    0x2580: 0xDF, // ▀
    0x00D3: 0xE0, // Ó
    0x00DF: 0xE1, // ß
    0x00D4: 0xE2, // Ô
    0x00D2: 0xE3, // Ò
    0x00F5: 0xE4, // õ
    0x00D5: 0xE5, // Õ
    0x00B5: 0xE6, // µ
    0x00D7: 0xE8, // ×
    0x00DA: 0xE9, // Ú
    0x00DB: 0xEA, // Û
    0x00D9: 0xEB, // Ù
    0x00EC: 0xEC, // ì
    0x00FF: 0xED, // ÿ
    0x00AF: 0xEE, // ¯
    0x00B4: 0xEF, // ´
    0x00AD: 0xF0, // yumuşak tire
    0x00B1: 0xF1, // ±
    0x00BE: 0xF3, // ¾
    0x00B6: 0xF4, // ¶
    0x00A7: 0xF5, // §
    0x00F7: 0xF6, // ÷
    0x00B8: 0xF7, // ¸
    0x00B0: 0xF8, // °
    0x00A8: 0xF9, // ¨
    0x00B7: 0xFA, // ·
    0x00B9: 0xFB, // ¹
    0x00B3: 0xFC, // ³
    0x00B2: 0xFD, // ²
    0x25A0: 0xFE, // ■
    0x00A0: 0xFF, // bölünmez boşluk
  };

  /// PC857'de karşılığı olmayan ama ürün adlarına ve notlara sızan karakterler.
  ///
  /// `?` basmak yerine anlamı koruyan sadeleştirme yapılır. Liste bilinçli
  /// olarak kısadır — burası bir Unicode normalleştirme kütüphanesi değildir.
  static const Map<int, String> _transliterations = {
    0x20BA: 'TL', // ₺
    0x20AC: 'EUR', // €
    0x2013: '-', // en tire
    0x2014: '-', // em tire
    0x2018: "'", // '
    0x2019: "'", // '
    0x201C: '"', // "
    0x201D: '"', // "
    0x2026: '...', // …
    0x2022: '*', // •
    0x2192: '->', // →
    0x0152: 'OE', // Œ
    0x0153: 'oe', // œ
    0x0160: 'S', // Š
    0x0161: 's', // š
    0x017D: 'Z', // Ž
    0x017E: 'z', // ž
    0x2009: ' ', // ince boşluk
    0x202F: ' ', // dar bölünmez boşluk
  };
}
