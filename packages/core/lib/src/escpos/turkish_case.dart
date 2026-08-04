/// Türkçe'ye duyarlı büyük/küçük harf dönüşümü.
///
/// **Neden gerekli:** Dart'ın `toUpperCase()`'i dilden bağımsızdır ve
/// `"Mercimek Çorbası".toUpperCase()` → `"MERCIMEK ÇORBASI"` verir. Doğrusu
/// `"MERCİMEK ÇORBASI"`'dır: Türkçe'de `i`'nin büyüğü `İ`, `ı`'nın büyüğü
/// `I`'dır. Mutfak fişinde ürün adları iri ve büyük harf basıldığı için
/// (`docs/05-mutfakapp.md` §5.3) bu fark her fişte görünür.
library;

/// Türkçe harf çiftlerini gözeten dönüşümler.
abstract final class TurkishCase {
  static const Map<String, String> _toUpper = {
    'i': 'İ',
    'ı': 'I',
    'ç': 'Ç',
    'ğ': 'Ğ',
    'ö': 'Ö',
    'ş': 'Ş',
    'ü': 'Ü',
  };

  static const Map<String, String> _toLower = {
    'İ': 'i',
    'I': 'ı',
    'Ç': 'ç',
    'Ğ': 'ğ',
    'Ö': 'ö',
    'Ş': 'ş',
    'Ü': 'ü',
  };

  /// `"Mercimek Çorbası"` → `"MERCİMEK ÇORBASI"`.
  static String toUpperCase(String value) =>
      _map(value, _toUpper, (rest) => rest.toUpperCase());

  /// `"MERCİMEK ÇORBASI"` → `"mercimek çorbası"`.
  static String toLowerCase(String value) =>
      _map(value, _toLower, (rest) => rest.toLowerCase());

  static String _map(
    String value,
    Map<String, String> overrides,
    String Function(String) fallback,
  ) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final character = String.fromCharCode(rune);
      buffer.write(overrides[character] ?? fallback(character));
    }
    return buffer.toString();
  }
}
