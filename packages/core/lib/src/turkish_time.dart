/// Tarih/saat biçimleme — `docs/03-api-sozlesmesi.md` §1.3.
///
/// API her zaman UTC gönderir; kullanıcı her zaman Türkiye saatini görür.
///
/// **Neden zaman dilimi veritabanı yok:** Türkiye 2016'dan beri kalıcı olarak
/// UTC+3'tedir ve yaz saati uygulaması yoktur. Sabit ofset doğru sonucu verir
/// ve `timezone` paketinin ~1 MB'lık IANA veritabanını mutfak kasasına ve
/// telefon uygulamasına taşımaktan kurtarır. Bu karar değişirse — Türkiye yaz
/// saatine dönerse — burada tek bir yer değişir.
library;

/// Türkiye'nin sabit UTC ofseti.
const Duration istanbulOffset = Duration(hours: 3);

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

/// UTC zaman damgalarını Türkiye yerel saatine çevirip biçimler.
abstract final class TurkishTime {
  /// UTC anını Türkiye duvar saatine taşır.
  ///
  /// Dönen [DateTime] `isUtc == true`'dur ama alanları Türkiye saatini gösterir.
  /// Bu bilinçlidir: cihazın kendi zaman dilimi ne olursa olsun (mutfak kasası
  /// yanlış kurulmuş olabilir) sonuç değişmez.
  static DateTime toIstanbul(DateTime utc) => utc.toUtc().add(istanbulOffset);

  /// `"14:32"`
  static String time(DateTime utc) {
    final local = toIstanbul(utc);
    return '${_pad(local.hour)}:${_pad(local.minute)}';
  }

  /// `"04.08.2026"`
  static String date(DateTime utc) {
    final local = toIstanbul(utc);
    return '${_pad(local.day)}.${_pad(local.month)}.${local.year}';
  }

  /// `"04.08.2026 14:32"` — fiş başlığı biçimi.
  static String dateTime(DateTime utc) => '${date(utc)} ${time(utc)}';

  /// `"04.08 09:30"` — fişte istenen teslim zamanı için kısa biçim.
  static String shortDateTime(DateTime utc) {
    final local = toIstanbul(utc);
    return '${_pad(local.day)}.${_pad(local.month)} ${time(utc)}';
  }

  /// `"4 Ağustos 2026, 14:32"` — arayüzde okunur biçim.
  static String longDateTime(DateTime utc) {
    final local = toIstanbul(utc);
    return '${local.day} ${_monthNamesTr[local.month - 1]} ${local.year}, '
        '${time(utc)}';
  }

  /// İki UTC anı aynı Türkiye gününe mi düşüyor?
  ///
  /// "Bugünün siparişleri" gibi filtreler için gerekir; UTC gün sınırı Türkiye
  /// gün sınırından 3 saat kayıktır ve saat 00:00–03:00 arasında yanlış cevap verir.
  static bool isSameIstanbulDay(DateTime a, DateTime b) {
    final localA = toIstanbul(a);
    final localB = toIstanbul(b);
    return localA.year == localB.year &&
        localA.month == localB.month &&
        localA.day == localB.day;
  }

  /// `"13:15-13:40"` — bir ana dakika aralığı eklenerek bulunan saat penceresi.
  ///
  /// [from] UTC bir andır (şu an, ya da siparişin oluşturulma zamanı); sonuç
  /// Türkiye duvar saatidir.
  ///
  /// **Neden 5 dakikaya yuvarlanır:** tahmin dakika hassasiyetinde değildir.
  /// "13:17" yazmak, elimizde olmayan bir kesinlik iddia eder; alt sınır aşağı,
  /// üst sınır yukarı yuvarlanınca pencere hem okunur hem de dürüst kalır.
  ///
  /// Sınırlar ters sıralıysa yer değiştirir; böylece sunucudaki bir hata
  /// ekranda "13:40-13:15" gibi anlamsız bir metne dönüşmez.
  static String minuteWindow(DateTime from, int minMinutes, int maxMinutes) {
    final low = minMinutes <= maxMinutes ? minMinutes : maxMinutes;
    final high = minMinutes <= maxMinutes ? maxMinutes : minMinutes;

    final start = from.toUtc().add(Duration(minutes: low));
    final end = from.toUtc().add(Duration(minutes: high));

    return '${_roundedTime(start, up: false)}-${_roundedTime(end, up: true)}';
  }

  /// Geçen süreyi kabaca anlatır: `"3 dk önce"`, `"2 sa önce"`.
  ///
  /// KDS kartlarında siparişin ne kadar beklediğini göstermek için.
  static String relativeFromNow(DateTime utc, {DateTime? now}) {
    final elapsed = (now ?? DateTime.now().toUtc()).difference(utc);
    if (elapsed.isNegative) return 'birazdan';
    if (elapsed.inMinutes < 1) return 'şimdi';
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} dk önce';
    if (elapsed.inHours < 24) return '${elapsed.inHours} sa önce';
    return '${elapsed.inDays} gün önce';
  }

  static String _pad(int value) => value.toString().padLeft(2, '0');

  /// UTC anını Türkiye saatine çevirip 5 dakikalık dilime yuvarlar.
  ///
  /// Yuvarlama dakikayı taşırabilir (58 → 60), bu yüzden saat hesabı
  /// [Duration] üzerinden yapılır; gün ve yıl sınırı kendiliğinden doğru olur.
  static String _roundedTime(DateTime utc, {required bool up}) {
    final local = toIstanbul(utc);
    final remainder = local.minute % 5;
    if (remainder == 0) return time(utc);

    final shift = up ? 5 - remainder : -remainder;
    final rounded = local.add(Duration(minutes: shift));
    return '${_pad(rounded.hour)}:${_pad(rounded.minute)}';
  }
}
