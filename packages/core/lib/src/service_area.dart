/// Hizmet alanı — nereye teslimat yapıyoruz?
///
/// Faz 1'de yalnızca **Konya / Selçuklu** ve **Konya / Karatay**. Müşteri il
/// ve ilçeyi serbest yazamaz; formlarda ikisi de kilitlidir ve harita bu
/// kutunun dışına çıkmaz.
///
/// ## Neden burada
///
/// Kural üç istemcide de aynı görünmeli: mobil form, web formu ve haritanın
/// sınırı. Dart tarafının tek kaynağı burasıdır. Web sitesi (TypeScript) ve
/// sunucu (PHP) aynı değerleri kendi dillerinde tekrarlar — karşılıkları
/// `website/lib/service-area.ts` ve
/// `platform/extensions/veykemtu/bridgeapi/src/Services/ServiceArea.php`.
/// Üçü DEĞİŞİRSE BİRLİKTE değişir; biri unutulursa istemci kabul ettiği
/// adresi sunucuya kabul ettiremez.
///
/// Bölge sayısı arttığında bu liste sunucudan gelmeli (`docs/11-yol-haritasi.md`
/// §bölgeler); üç ilçe için üç yerde sabit tutmak, sözleşmeye alan eklemekten
/// ucuzdur.
library;

import 'escpos/turkish_case.dart';

/// Teslimat yapılan il ve ilçeler.
abstract final class ServiceArea {
  /// Tek il. Formda seçilebilir değil, sabit gösterilir.
  static const String city = 'Konya';

  /// Teslimat yapılan ilçeler. Sıra formdaki sıradır.
  static const List<String> districts = <String>['Selçuklu', 'Karatay'];

  /// Kutunun güney kenarı (enlem).
  ///
  /// ## Kutu neden ilçe sınırı değil
  ///
  /// Değerler iki ilçenin **yerleşik alanını** kapsayan bir dikdörtgendir,
  /// idari sınır poligonu değil. Kenarlarda komşu ilçelerden (özellikle
  /// güneybatıda Meram) bir miktar alan da kutuya girer. Poligon denetimi
  /// sınır verisi gerektirir ve bir dikdörtgenin çözdüğü asıl sorunu —
  /// müşterinin haritayı Ankara'ya kaydırıp orayı işaretlemesi — zaten
  /// çözülmüş sayıyoruz.
  static const double south = 37.80;

  /// Kuzey kenarı — Selçuklu'nun kuzey yerleşimlerini içerir.
  static const double north = 38.10;

  /// Batı kenarı.
  static const double west = 32.35;

  /// Doğu kenarı — Karatay'ın doğu yerleşimlerini içerir.
  static const double east = 32.75;

  /// Harita iğnesiz açıldığında bakılan yer: Konya merkez.
  static const double centerLatitude = 37.8746;
  static const double centerLongitude = 32.4932;

  /// Kutu bu yakınlıktan daha uzağa çekilemez.
  ///
  /// Daha uzağı, ekrana kutudan büyük bir alan sığdırırdı; o noktada
  /// "haritayı kutuya hapset" kısıtı sağlanamaz hâle gelir ve harita
  /// donmuş gibi davranır.
  static const double minZoom = 12.5;

  /// Karo sağlayıcısının (OSM) verdiği en yakın seviye.
  static const double maxZoom = 19;

  /// Verilen ilçe hizmet alanında mı?
  ///
  /// Karşılaştırma Türkçe'ye duyarlı küçük harfe indirilerek yapılır, çünkü
  /// eski kayıtlarda ilçe adı büyük harfle de geçebiliyor. Dart'ın dilden
  /// bağımsız `toLowerCase()`'i `I` harfini `i`'ye düşürür; Türkçe'de doğrusu
  /// `ı`'dır ve bu fark ileride eklenecek bir ilçede ("KADINHANI") sessiz bir
  /// eşleşmeme yaratır.
  static bool coversDistrict(String? district) {
    if (district == null) return false;
    final needle = TurkishCase.toLowerCase(district.trim());
    return districts.any((known) => TurkishCase.toLowerCase(known) == needle);
  }

  /// Verilen il hizmet alanında mı?
  static bool coversCity(String? value) {
    if (value == null) return false;
    return TurkishCase.toLowerCase(value.trim()) ==
        TurkishCase.toLowerCase(city);
  }

  /// Nokta kutunun içinde mi?
  ///
  /// Kenarlar dahildir: tam sınırdaki bir iğneyi reddetmek, kutuyu bir
  /// santimetre içeriden çizmekle aynı şey olurdu.
  static bool containsPoint(double latitude, double longitude) =>
      latitude >= south &&
      latitude <= north &&
      longitude >= west &&
      longitude <= east;
}
