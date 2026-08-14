/// Uçların TEL ÜZERİNDEKİ hâli: hangi yol çağrılıyor, sorguya ne giriyor,
/// yanıttan ne çıkarılıyor.
///
/// NEDEN AYRI DOSYA: `contract_test.dart` DTO'ların JSON'unu koruyor —
/// modeller doğru olduğu hâlde `bld_api.dart` yanlış yolu çağırabilir, sorguya
/// boş bir `date=` koyabilir ya da `{"data": ...}` sarmalayıcısını yanlış
/// açabilir. Bu üç hatanın hiçbirini model testi göremez; hepsi ancak
/// çalışan uygulamada, sunucu `422` döndüğünde fark edilir.
///
/// Özellikle korunan iki davranış:
///
///   1. **`?date` boş anahtar üretmez.** `bld_api.dart` isteğe bağlı sorgu
///      parametrelerini `{'date': ?date}` (null-aware) ile kuruyor. Biri onu
///      düz `{'date': date}` yapsa kod derlenir ve analiz temiz geçer, ama
///      gün seçilmediğinde sunucuya `?date=` gider — sözleşme onu geçerli bir
///      gün saymaz.
///   2. **Üç karakterin altında ağa HİÇ ÇIKILMAZ.** `AddressService.suggest`
///      bunu söz veriyor; sözü ancak isteğin sayıldığı bir test tutabilir.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:bld_api_client/bld_api_client.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

/// Ağa çıkmayan sahte taşıma katmanı: her isteği kaydeder, sıradaki hazır
/// yanıtı döndürür.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this._body, {this.statusCode = 200});

  final Object? _body;
  final int statusCode;

  /// Gelen istekler, geliş sırasıyla. Boş kalması "ağa çıkılmadı" demektir.
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(_body),
      statusCode,
      // Content-type olmadan Dio gövdeyi çözmez ve `data` düz metin kalır.
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Sahte taşımaya bağlı bir istemci. `BldApi` kendi `Dio`sunu kurarken
/// uyguladığı ayarların (özellikle `validateStatus`) aynısı burada da
/// veriliyor; aksi hâlde test gerçek çalışma anından farklı davranırdı.
({BldApi api, _RecordingAdapter adapter}) _client(
  Object? body, {
  int statusCode = 200,
}) {
  final adapter = _RecordingAdapter(body, statusCode: statusCode);
  final dio = Dio(
    BaseOptions(baseUrl: 'https://ornek.test/api', validateStatus: (_) => true),
  )..httpClientAdapter = adapter;

  final api = BldApi(
    config: const BldApiConfig(
      baseUrl: 'https://ornek.test/api',
      appId: 'musteriapp',
      appVersion: '1.0.0',
    ),
    dio: dio,
  );

  return (api: api, adapter: adapter);
}

void main() {
  group('CatalogService.dailyMenu', () {
    Map<String, dynamic> dayBody() => {
      'data': {
        'id': 77,
        'date': '2026-08-20',
        'currency': 'TRY',
        'closed': false,
        'is_orderable': true,
        'items': <dynamic>[],
      },
    };

    test('yol ve gün sorgusu sözleşmedeki gibi kurulur', () async {
      final client = _client(dayBody());

      final menu = await client.api.catalog.dailyMenu(3, date: '2026-08-20');

      final request = client.adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/locations/3/daily-menu');
      expect(request.queryParameters['date'], '2026-08-20');
      expect(menu.date, '2026-08-20');
      expect(menu.exists, isTrue);
    });

    test('gün verilmezse sorguda BOŞ date anahtarı OLUŞMAZ', () async {
      final client = _client(dayBody());

      await client.api.catalog.dailyMenu(3);

      // `containsKey`, `== null` DEĞİL: null bir değer de `?date=` olarak
      // tele çıkar ve sunucu onu geçersiz gün sayar.
      expect(
        client.adapter.requests.single.queryParameters.containsKey('date'),
        isFalse,
        reason: 'Gün seçilmediğinde sunucu BUGÜNÜ varsayar; boş date değil.',
      );
    });

    test('zorunlu istemci başlıkları her isteğe eklenir', () async {
      final client = _client(dayBody());

      await client.api.catalog.dailyMenu(3);

      final headers = client.adapter.requests.single.headers;
      expect(headers['X-App-Id'], 'musteriapp');
      expect(headers['X-App-Version'], '1.0.0');
      expect(headers['Accept-Language'], 'tr');
    });
  });

  group('CatalogService.menuCalendar', () {
    Map<String, dynamic> calendarBody() => {
      'data': [
        {
          'date': '2026-08-20',
          'has_menu': true,
          'closed': false,
          'is_orderable': true,
        },
        {
          'date': '2026-08-22',
          'has_menu': false,
          'closed': true,
          'is_orderable': false,
          'note': 'Kurban Bayramı',
        },
      ],
    };

    test('aralık sorgusu geçer ve liste sarmalayıcıdan çıkarılır', () async {
      final client = _client(calendarBody());

      final days = await client.api.catalog.menuCalendar(
        3,
        from: '2026-08-20',
        to: '2026-09-01',
      );

      final request = client.adapter.requests.single;
      expect(request.path, '/locations/3/menu-calendar');
      expect(request.queryParameters['from'], '2026-08-20');
      expect(request.queryParameters['to'], '2026-09-01');
      expect(days, hasLength(2));
      expect(days.last.note, 'Kurban Bayramı');
    });

    test('aralık verilmezse iki anahtar da sorguya GİRMEZ', () async {
      final client = _client(calendarBody());

      await client.api.catalog.menuCalendar(3);

      final query = client.adapter.requests.single.queryParameters;
      expect(query.containsKey('from'), isFalse);
      expect(query.containsKey('to'), isFalse);
    });
  });

  group('AddressService.suggest', () {
    Map<String, dynamic> suggestionBody() => {
      'data': [
        {
          'label': 'Feritpaşa Mah., Kültür Sk. No:12, Selçuklu / Konya',
          'line1': 'Kültür Sk. No:12',
          'district': 'Selçuklu',
          'city': 'Konya',
          'latitude': 37.8746,
          'longitude': 32.4932,
          'source': 'osm_nominatim',
        },
      ],
    };

    test('üç karakterin altında AĞA HİÇ ÇIKILMAZ', () async {
      final client = _client(suggestionBody());

      expect(await client.api.addresses.suggest('ku'), isEmpty);
      // Boşluklar kırpıldıktan sonra da kısa: "  k  " iki değil bir karakter.
      expect(await client.api.addresses.suggest('  k  '), isEmpty);

      expect(
        client.adapter.requests,
        isEmpty,
        reason: 'Sunucu bunu 422 ile reddediyor; istek hiç doğmamalı.',
      );
    });

    test('sorgu kırpılarak gider, limit sözleşmedeki tavana kısılır', () async {
      final client = _client(suggestionBody());

      final results = await client.api.addresses.suggest(
        '  kültür sokak  ',
        limit: 50,
      );

      final query = client.adapter.requests.single.queryParameters;
      expect(query['q'], 'kültür sokak');
      expect(query['limit'], 10, reason: 'Sözleşmedeki üst sınır 10.');
      expect(results.single.source, 'osm_nominatim');
    });

    test('limit alt sınıra da kısılır', () async {
      final client = _client(suggestionBody());

      await client.api.addresses.suggest('kültür', limit: 0);

      expect(client.adapter.requests.single.queryParameters['limit'], 1);
    });
  });

  group('AddressService.reverse', () {
    test('nokta bilinmiyorsa null döner, hata ATILMAZ', () async {
      // Sağlayıcı o noktayı bilmiyor. Doğru davranış iğneyi korumak;
      // istisna atmak haritayı hata ekranına çevirirdi.
      final client = _client({'data': null});

      expect(await client.api.addresses.reverse(37.8746, 32.4932), isNull);

      final query = client.adapter.requests.single.queryParameters;
      expect(query['lat'], 37.8746);
      expect(query['lng'], 32.4932);
    });
  });
}
