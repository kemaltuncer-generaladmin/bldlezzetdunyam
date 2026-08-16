/// Adres koordinatlarının seri hâle getirilmesi.
///
/// NEDEN AYRI DOSYA: bu testlerin koruduğu şey bir davranış değil, bir
/// **yapılandırma detayı** — ve tam da bu yüzden sessizce kaybolabilir.
///
/// `build.yaml` içinde `include_if_null: false` var: `null` alanlar gövdeden
/// tamamen çıkarılır. Sunucu ise ikisini ayırt ediyor:
///
///   - alan yok   → mevcut iğne korunur
///   - alan null  → iğne silinir
///
/// Bu yüzden `latitude`/`longitude` alanları `@JsonKey(includeIfNull: true)`
/// ile işaretli. Biri o açıklamayı "gereksiz" diye kaldırırsa kod derlenir,
/// analiz temiz geçer, uygulama çalışır — yalnızca **iğne kaldırma** sessizce
/// çalışmaz olur ve kurye eski noktaya gitmeye devam eder. Aşağıdaki ilk test
/// tam olarak o silmeyi yakalar.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:test/test.dart';

void main() {
  group('SavedAddressInput seri hâli', () {
    test('iğne yokken latitude/longitude AÇIKÇA null olarak gönderilir', () {
      const input = SavedAddressInput(
        line1: 'Atatürk Caddesi No:12',
        district: 'Nilüfer',
        city: 'Bursa',
      );

      final json = input.toJson();

      // `containsKey`, `json['latitude'] == null` DEĞİL: eksik anahtar da
      // null okunur ve test yanlışlıkla geçerdi. Sorulan şey anahtarın
      // GÖVDEDE OLUP OLMADIĞI.
      expect(
        json.containsKey('latitude'),
        isTrue,
        reason: 'null gönderilemezse müşteri iğnesini kaldıramaz.',
      );
      expect(json.containsKey('longitude'), isTrue);
      expect(json['latitude'], isNull);
    });

    test('iğne varken koordinat gövdeye girer', () {
      const input = SavedAddressInput(
        line1: 'Atatürk Caddesi No:12',
        district: 'Nilüfer',
        city: 'Bursa',
        latitude: 40.2114567,
        longitude: 28.9876543,
      );

      final json = input.toJson();

      expect(json['latitude'], 40.2114567);
      expect(json['longitude'], 28.9876543);
    });

    test('boş isteğe bağlı alanlar hâlâ gövdeden çıkarılıyor', () {
      // Koordinat istisnası diğer alanlara SIZMAMALI. Sızsaydı `label: null`
      // gönderilir ve etiketi olan bir adres düzenlenince etiketi silinirdi.
      const input = SavedAddressInput(
        line1: 'Atatürk Caddesi No:12',
        district: 'Nilüfer',
        city: 'Bursa',
      );

      final json = input.toJson();

      expect(json.containsKey('label'), isFalse);
      expect(json.containsKey('note'), isFalse);
    });
  });

  group('koordinat çifti', () {
    test('hasPin yalnızca ikisi de doluysa true', () {
      const tam = SavedAddress(
        id: 1,
        line1: 'a',
        district: 'b',
        city: 'c',
        isDefault: false,
        latitude: 40.2,
        longitude: 29.0,
      );
      const yarim = SavedAddress(
        id: 2,
        line1: 'a',
        district: 'b',
        city: 'c',
        isDefault: false,
        latitude: 40.2,
      );
      const yok = SavedAddress(
        id: 3,
        line1: 'a',
        district: 'b',
        city: 'c',
        isDefault: false,
      );

      expect(tam.hasPin, isTrue);
      expect(
        yarim.hasPin,
        isFalse,
        reason: 'Yarım çift haritada gösterilemez.',
      );
      expect(yok.hasPin, isFalse);
    });

    test('defterden siparişe kopyalanırken iğne de taşınır', () {
      // Taşınmazsa harita hiçbir işe yaramaz: müşteri kapıyı işaretler,
      // kurye yine serbest metne bakar.
      const saved = SavedAddress(
        id: 1,
        line1: 'Atatürk Caddesi No:12',
        district: 'Nilüfer',
        city: 'Bursa',
        isDefault: true,
        note: 'Zili çalmayın',
        latitude: 40.2114567,
        longitude: 28.9876543,
      );

      final order = saved.toOrderAddress();

      expect(order.latitude, 40.2114567);
      expect(order.longitude, 28.9876543);
      expect(order.hasPin, isTrue);
      expect(order.note, 'Zili çalmayın');
    });

    test('iğnesiz defter kaydı iğnesiz siparişe dönüşür', () {
      const saved = SavedAddress(
        id: 1,
        line1: 'a',
        district: 'b',
        city: 'c',
        isDefault: false,
      );

      expect(saved.toOrderAddress().hasPin, isFalse);
    });
  });

  group('sunucudan okuma', () {
    test('koordinat alanları eksikse çökmez', () {
      // Eski istemci/sunucu eşleşmelerinde alan hiç gelmeyebilir.
      final address = Address.fromJson(<String, dynamic>{
        'line1': 'Atatürk Caddesi No:12',
        'district': 'Nilüfer',
        'city': 'Bursa',
        'note': null,
      });

      expect(address.hasPin, isFalse);
      expect(address.latitude, isNull);
    });

    test('tam duyarlılık okunurken korunur', () {
      final address = Address.fromJson(<String, dynamic>{
        'line1': 'a',
        'district': 'b',
        'city': 'c',
        'latitude': 40.2114567,
        'longitude': 28.9876543,
      });

      expect(address.latitude, 40.2114567);
      expect(address.longitude, 28.9876543);
    });
  });
}
