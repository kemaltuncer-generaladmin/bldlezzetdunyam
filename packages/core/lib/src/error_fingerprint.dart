/// Hata parmak izi — "bu, birazdan gelecek olanın aynısı mı?"
///
/// İstemci hataları `POST /client-errors` ile sunucuya boşaltılır
/// (`docs/03-api-sozlesmesi.md` §15.6). Tek bir bozuk döngü aynı hatayı
/// dakikada yüzlerce kez üretebilir; hepsini ayrı ayrı göndermek hem müşterinin
/// veri paketini hem de monitör tablosunu yakar. Bu yüzden istemci, göndermeden
/// önce hataya bir parmak izi basar ve **aynı izi kısa süre içinde ikinci kez
/// göndermez**.
///
/// ## Neden burada
///
/// Aynı tarif iki istemcide de uygulanır: bu dosya (Dart — `musteriapp`,
/// `mutfakapp`) ve web sitesinin TypeScript karşılığı. İkisi DEĞİŞİRSE
/// BİRLİKTE değişir; ayrışırlarsa "web'de tek satır, mobilde altmış satır"
/// gibi kıyaslanamaz iki tablo çıkar ve hangi platformun daha çok hata
/// ürettiği sorusunun cevabı bozulur.
///
/// ## Sunucunun parmak izi ile karıştırılmamalı
///
/// `docs/control/monitor.md` §Tekilleştirme'deki
/// `sha256(source|code|device_id|normalize(message))` **sunucunun** kendi
/// birleştirme anahtarıdır ve `veykemtu_monitor_events.fingerprint` sütununa
/// yazılır. Buradaki iz istemcide kalır, sözleşmede bir alana karşılık gelmez
/// (`ClientErrorReport` içinde `fingerprint` yoktur) ve gövdeye konmaz.
library;

import 'dart:convert';

/// Parmak izine giren yığın çerçevesi sayısı.
///
/// Üç, "hata nerede doğdu" sorusunu ayırt etmeye yeter. Daha derini, aynı
/// hatanın farklı çağrı yollarından gelen kopyalarını ayrı olaylar hâline
/// getirir ve tekilleştirmeyi işe yaramaz kılar.
const int _frameCount = 3;

/// Boşluk dizileri — çerçeve metinleri sürüme göre farklı girintileniyor.
final RegExp _whitespaceRun = RegExp(r'\s+');

/// Rakamlar. `\d` yerine açık aralık yazılıdır ki TypeScript karşılığı da
/// aynı kümeyi silsin.
final RegExp _digits = RegExp('[0-9]');

/// [kind], [message] ve [stackFrames]'in ilk üç çerçevesinden 16 haneli
/// onaltılık bir iz üretir.
///
/// Tarif — TypeScript karşılığı **birebir** bunu uygular:
///
/// 1. `kind`, `message` ve ilk [_frameCount] çerçeve alınır; çerçeve sayısı
///    azsa boş dizeyle tamamlanır, böylece anahtar **her zaman beş alandır**.
///    Tamamlanmasaydı iki çerçeveli bir hata ile üç çerçeveli başka bir hata
///    aynı metne katlanabilirdi.
/// 2. Her alanda boşluk dizileri tek boşluğa indirilir ve kenarlar kırpılır.
/// 3. Alanlar `|` ile birleştirilir.
/// 4. **Bütün anahtardan rakamlar silinir.** Sebebi `docs/control/monitor.md`
///    §Tekilleştirme ile aynıdır: "Sipariş 8421 basılamadı" ile "Sipariş 8422
///    basılamadı" tek hatanın iki tekrarıdır; çerçevelerdeki satır ve sütun
///    numaraları da her yapıda kayar.
/// 5. UTF-8 baytları üzerinde FNV-1a (64 bit) hesaplanır, sonuç sıfırla
///    doldurulmuş küçük harf onaltılık olarak döner.
///
/// İz bir **güvenlik** değeri değildir; çakışma direnci değil, ucuzluk ve iki
/// dilde aynı sonucu vermek arandığı için kriptografik özet kullanılmaz.
String fingerprint(String kind, String message, List<String> stackFrames) {
  final fields = <String>[
    _normalize(kind),
    _normalize(message),
    for (var i = 0; i < _frameCount; i++)
      i < stackFrames.length ? _normalize(stackFrames[i]) : '',
  ];

  final key = fields.join('|').replaceAll(_digits, '');

  return _toHex64(_fnv1a64(utf8.encode(key)));
}

/// Boşlukları tekleştirir ve kırpar.
String _normalize(String value) =>
    value.replaceAll(_whitespaceRun, ' ').trim();

/// FNV-1a, 64 bit.
///
/// Dart'ın tam sayıları 64 bittir ve taşma sarmalanır; çarpım bu yüzden
/// maskesiz yazılabilir. TypeScript karşılığı aynı sonucu `BigInt` ile ve
/// `& 0xFFFFFFFFFFFFFFFFn` maskesiyle üretir — `number` ile denenirse 2^53'ten
/// sonra basamak kaybeder ve iki platform ayrışır.
int _fnv1a64(List<int> bytes) {
  var hash = 0xCBF29CE484222325; // FNV offset basis (işaretli karşılığı eksi).
  for (final byte in bytes) {
    hash ^= byte;
    hash *= 0x100000001B3; // FNV prime.
  }
  return hash;
}

/// 64 bitlik değeri 16 haneli onaltılığa çevirir.
///
/// İki yarı ayrı biçimlenir: `toRadixString` negatif sayıya başına eksi koyar,
/// oysa parmak izi işaretsiz bir bit dizisidir.
String _toHex64(int value) {
  final high = (value >> 32) & 0xFFFFFFFF;
  final low = value & 0xFFFFFFFF;
  return '${high.toRadixString(16).padLeft(8, '0')}'
      '${low.toRadixString(16).padLeft(8, '0')}';
}
