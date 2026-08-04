/// Para biçimleme — `docs/03-api-sozlesmesi.md` §1.3.
///
/// **Değişmez kural:** para her yerde kuruş cinsinden `int`'tir. `double`
/// kullanılmaz; 0.1 + 0.2 problemi bir sipariş toplamında kabul edilemez.
/// Dönüşüm yalnızca kullanıcıya gösterirken, son anda yapılır.
library;

/// Kuruş tutarlarını Türkçe biçime çevirir.
abstract final class Money {
  static const String currencySymbol = '₺';

  /// `41000` → `"410,00 ₺"`, `1234567` → `"12.345,67 ₺"`.
  ///
  /// Negatif tutarlar (indirim, iade) desteklenir: `-4550` → `"-45,50 ₺"`.
  static String format(int kurus, {bool withSymbol = true}) {
    final isNegative = kurus < 0;
    final absolute = isNegative ? -kurus : kurus;

    final lira = absolute ~/ 100;
    final cents = absolute % 100;

    final buffer = StringBuffer();
    if (isNegative) buffer.write('-');
    buffer
      ..write(_groupThousands(lira))
      ..write(',')
      ..write(cents.toString().padLeft(2, '0'));
    if (withSymbol) buffer.write(' $currencySymbol');

    return buffer.toString();
  }

  /// Sembolsüz, fişe basılmaya uygun biçim: `41000` → `"410,00"`.
  ///
  /// Termal fişte sembol kullanılmaz; sütun hizası bozulur ve `₺` karakteri
  /// PC857 kod sayfasında yoktur (bkz. `docs/05-mutfakapp.md` §5.2).
  static String formatForReceipt(int kurus) => format(kurus, withSymbol: false);

  /// `"410,00"` veya `"410.00"` → `41000`. Ayrıştırılamazsa `null`.
  ///
  /// Yalnızca elle giriş alanları içindir; API'den gelen değer zaten `int`'tir.
  static int? tryParse(String input) {
    final cleaned = input
        .replaceAll(currencySymbol, '')
        .replaceAll(RegExp(r'\s'), '')
        .replaceAll('.', '')
        .replaceAll(',', '.');
    if (cleaned.isEmpty) return null;

    final asDouble = double.tryParse(cleaned);
    if (asDouble == null) return null;

    return (asDouble * 100).round();
  }

  /// Binlik ayracı olarak nokta koyar: `12345` → `"12.345"`.
  static String _groupThousands(int value) {
    final digits = value.toString();
    if (digits.length <= 3) return digits;

    final buffer = StringBuffer();
    final firstGroupLength = digits.length % 3;

    if (firstGroupLength > 0) {
      buffer.write(digits.substring(0, firstGroupLength));
    }
    for (var i = firstGroupLength; i < digits.length; i += 3) {
      if (buffer.isNotEmpty) buffer.write('.');
      buffer.write(digits.substring(i, i + 3));
    }
    return buffer.toString();
  }
}
