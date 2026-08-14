/// İşletme takvimindeki GÜN — `YYYY-AA-GG` (Europe/Istanbul).
///
/// [TurkishTime] bir ANI (UTC zaman damgası) biçimler; burası bir GÜNÜ.
/// İkisi ayrı tutuluyor çünkü günün saati yok: `2026-08-20`, gün boyunca
/// hangi saatte bakılırsa bakılsın 20 Ağustos'tur. `DateTime`'a çevirmek o
/// güne olmayan bir saat ve zaman dilimi ekler; UTC−3'teki bir cihazda
/// "20 Ağustos menüsü" 19 Ağustos'a kayar.
///
/// Bu yüzden günler kod boyunca `String` taşınır (`DailyMenu.date`,
/// `OrderCreateRequest.service_date`, `menu-calendar` yanıtı) ve buradaki
/// yardımcılar onların üstünde çalışır.
library;

import 'turkish_time.dart';

const List<String> _monthNamesTr = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

/// Pazartesi = 1 … Pazar = 7 (`DateTime.weekday` ile aynı sıra).
const List<String> _weekdayNamesTr = [
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar',
];

/// `YYYY-AA-GG` biçimindeki işletme günleri üzerinde işlemler.
///
/// Bütün metotlar bozuk girdiye **dayanıklıdır**: ayrıştırılamayan bir gün
/// için biçimleyiciler metnin kendisini döndürür, karşılaştırıcılar `false`
/// döner. Sunucudan gelen bir bozukluk ekranı çökertmemeli — okunmayan bir
/// tarih, boş bir ekrandan iyidir.
abstract final class BusinessDate {
  /// Türkiye saatine göre bugünün günü.
  ///
  /// [nowUtc] testler için; verilmezse cihazın saati UTC'ye çevrilip
  /// kullanılır. Gün sınırı UTC'de değil Türkiye'de hesaplanır: saat
  /// 00:00–03:00 arasında UTC hâlâ dünü gösteriyor olurdu ve müşteri gece
  /// yarısı dünün menüsünü görürdü.
  static String today({DateTime? nowUtc}) =>
      fromUtc(nowUtc ?? DateTime.now().toUtc());

  /// UTC anın düştüğü işletme günü.
  static String fromUtc(DateTime utc) {
    final local = TurkishTime.toIstanbul(utc);
    return of(local.year, local.month, local.day);
  }

  /// Alanlardan gün metni kurar — `of(2026, 8, 20) == '2026-08-20'`.
  static String of(int year, int month, int day) =>
      '${year.toString().padLeft(4, '0')}-${_pad(month)}-${_pad(day)}';

  /// Gün metnini takvim değerine çevirir; bozuksa `null`.
  ///
  /// Dönen [DateTime] **UTC gece yarısıdır**: saat dilimi taşımayan bir
  /// değere ihtiyaç var ve yerel gece yarısı, yaz saati uygulayan bir cihaz
  /// zaman diliminde var olmayabiliyor. Bu değer yalnızca gün aritmetiği
  /// içindir; ekrana basılacak an DEĞİLDİR.
  static DateTime? tryParse(String iso) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(iso);
    if (match == null) return null;

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);

    final parsed = DateTime.utc(year, month, day);

    // Taşma denetimi: `DateTime.utc(2026, 2, 31)` sessizce 3 Mart üretir.
    // Onu geçerli saymak, olmayan bir güne sipariş verdirir.
    if (parsed.month != month || parsed.day != day) return null;

    return parsed;
  }

  /// Gün metni geçerli mi?
  static bool isValid(String iso) => tryParse(iso) != null;

  /// [days] gün sonrası (negatif değer öncesi); bozuk girdide metnin kendisi.
  static String addDays(String iso, int days) {
    final parsed = tryParse(iso);
    if (parsed == null) return iso;
    final shifted = parsed.add(Duration(days: days));
    return of(shifted.year, shifted.month, shifted.day);
  }

  /// [from]'dan [to]'ya kaç gün; bozuk girdide `null`.
  static int? daysBetween(String from, String to) {
    final a = tryParse(from);
    final b = tryParse(to);
    if (a == null || b == null) return null;
    return b.difference(a).inDays;
  }

  /// Sıralama karşılaştırıcısı — `List<String>.sort(BusinessDate.compare)`.
  ///
  /// `YYYY-AA-GG` sabit genişlikte ve büyükten küçüğe sıralı olduğu için
  /// metin karşılaştırması kronolojik karşılaştırmaya EŞİTTİR; ayrıştırma
  /// yapmaya gerek yok. Bu bilerek böyle bir biçim; bozulmasın diye burada
  /// yazılı.
  static int compare(String a, String b) => a.compareTo(b);

  /// [iso], [other]'dan önce mi?
  static bool isBefore(String iso, String other) => compare(iso, other) < 0;

  /// [iso], [other]'dan sonra mı?
  static bool isAfter(String iso, String other) => compare(iso, other) > 0;

  /// `"20 Ağustos 2026"`
  static String long(String iso) {
    final parsed = tryParse(iso);
    if (parsed == null) return iso;
    return '${parsed.day} ${_monthNamesTr[parsed.month - 1]} ${parsed.year}';
  }

  /// `"20 Ağustos"` — yıl, aynı yıl içindeki günlerde gürültüdür.
  static String short(String iso) {
    final parsed = tryParse(iso);
    if (parsed == null) return iso;
    return '${parsed.day} ${_monthNamesTr[parsed.month - 1]}';
  }

  /// `"Ağustos 2026"` — takvim sayfasının ay başlığı.
  ///
  /// Gün taşımaz: başlık bir ayın TAMAMINI adlandırır, o ayın herhangi bir
  /// gününü değil. [long]'dan gün numarasını kırpmakla aynı şey değil —
  /// kırpma, biçim değiştiğinde sessizce bozulan bir metin işlemi olurdu.
  static String month(String iso) {
    final parsed = tryParse(iso);
    if (parsed == null) return iso;
    return '${_monthNamesTr[parsed.month - 1]} ${parsed.year}';
  }

  /// `"Perşembe"`
  static String weekday(String iso) {
    final parsed = tryParse(iso);
    if (parsed == null) return '';
    return _weekdayNamesTr[parsed.weekday - 1];
  }

  /// Gün seçicideki başlık: `"Bugün"`, `"Yarın"` ya da `"20 Ağustos Perşembe"`.
  ///
  /// **Neden "Dün" yok:** geçmiş güne sipariş verilemiyor ve geçmiş bir gün
  /// bu ekranlarda hiç gösterilmiyor. Olmayan bir durum için kelime
  /// uydurmak, ilk gördüğümüzde onu doğru sanmamıza yol açardı.
  static String label(String iso, {String? todayIso, DateTime? nowUtc}) {
    final reference = todayIso ?? today(nowUtc: nowUtc);
    if (iso == reference) return 'Bugün';
    if (iso == addDays(reference, 1)) return 'Yarın';

    final name = weekday(iso);
    return name.isEmpty ? short(iso) : '${short(iso)} $name';
  }

  static String _pad(int value) => value.toString().padLeft(2, '0');
}
