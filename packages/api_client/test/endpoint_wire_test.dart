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

  group('SubscriptionService — dönem ödemesi', () {
    Map<String, dynamic> paymentBody() => {
      'payment_id': 501,
      'subscription_id': 12,
      'period': '2026-09',
      'amount': 660000,
      'currency': 'TRY',
      'status': 'pending',
      'next_action': 'otp',
      'created_at': '2026-08-28T09:00:00Z',
    };

    test('ödeme başlatma yolu kurulur, TUTAR GÖNDERİLMEZ', () async {
      final client = _client(paymentBody(), statusCode: 201);

      final payment = await client.api.subscriptions.startPayment(12);

      final request = client.adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/subscriptions/12/payments');
      // Tutar sunucuda hesaplanır; istemciden alınsaydı bir gün atlandığında
      // abone eksik ödeyip "kapattım" sanırdı.
      expect(request.data, isNull);
      expect(payment.paymentId, 501);
      expect(payment.needsOtp, isTrue);
    });

    test('dönem verilirse gövdeye girer', () async {
      final client = _client(paymentBody());

      await client.api.subscriptions.startPayment(12, period: '2026-10');

      expect(client.adapter.requests.single.data, {'period': '2026-10'});
    });

    test('OTP sözleşmedeki `code` adıyla gider', () async {
      final client = _client(paymentBody());

      await client.api.subscriptions.confirmPayment(12, 501, otp: '482913');

      final request = client.adapter.requests.single;
      expect(request.path, '/subscriptions/12/payments/501/confirm');
      // Ekranın sorduğu şey "SMS kodu" (otp); sözleşmedeki ad `code`.
      // Çeviri tek yerde olmalı.
      expect(request.data, {'code': '482913'});
    });

    test('kod verilmezse gövde BOŞ gider', () async {
      final client = _client(paymentBody());

      await client.api.subscriptions.confirmPayment(12, 501);

      expect(client.adapter.requests.single.data, isNull);
    });

    test('ödeme yoklama yolu kurulur', () async {
      final client = _client(paymentBody());

      await client.api.subscriptions.payment(12, 501);

      final request = client.adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/subscriptions/12/payments/501');
    });
  });

  group('ContractService', () {
    Map<String, dynamic> contractBody() => {
      'data': {
        'status': 'sent',
        'version': 1,
        'body': 'Taraflar ...',
        'body_format': 'markdown',
        'service_days': [1, 2, 3, 4, 5],
        'unit_price': 15000,
        'currency': 'TRY',
        'masked_phone': '0555 *** ** 33',
      },
    };

    test('belirteç yola KAÇIŞLANARAK girer', () async {
      // Belirteç imzalıdır ve taban64url dışı bir karakter taşıyabilir;
      // ham gömmek bozuk bir yol üretir ve sunucu 404 döner.
      final client = _client(contractBody());

      final contract = await client.api.contracts.get('abc/def+123');

      expect(client.adapter.requests.single.path, '/contracts/abc%2Fdef%2B123');
      expect(contract.version, 1);
      expect(contract.maskedPhone, '0555 *** ** 33');
    });

    test('kod isteği gövdesizdir — NUMARA İSTEKTE ALINMAZ', () async {
      // İstemciden alınsaydı bağlantıyı ele geçiren biri kodu kendi
      // telefonuna ısmarlayıp sözleşmeyi onaylayabilirdi.
      final client = _client({
        'message': 'Kod gönderildi',
        'expires_in': 300,
        'resend_after': 60,
      }, statusCode: 202);

      await client.api.contracts.requestOtp('token12345678901234567890');

      final request = client.adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/contracts/token12345678901234567890/otp');
      expect(request.data, isNull);
    });

    test('onay kodu gövdeye girer ve sarmalayıcı açılır', () async {
      final client = _client({
        'data': {
          ...(contractBody()['data']! as Map<String, dynamic>),
          'status': 'approved',
          'approved_at': '2026-08-26T12:30:00Z',
        },
      });

      final contract = await client.api.contracts.approve(
        'token12345678901234567890',
        '482913',
      );

      final request = client.adapter.requests.single;
      expect(request.path, '/contracts/token12345678901234567890/approve');
      expect(request.data, {'code': '482913'});
      expect(contract.isApproved, isTrue);
    });

    test(
      'sözleşme ucu Authorization İSTEMEZ ama başlıklar yine gider',
      () async {
        // Uç kimlik gerektirmiyor; token deposu boşken istek yine kurulmalı.
        final client = _client(contractBody());

        await client.api.contracts.get('token12345678901234567890');

        final headers = client.adapter.requests.single.headers;
        expect(headers.containsKey('Authorization'), isFalse);
        expect(headers['X-App-Id'], 'musteriapp');
      },
    );
  });

  group('AnnouncementService', () {
    Map<String, dynamic> body() => {
      'data': [
        {
          'id': 31,
          'placement': 'home',
          'body': 'Yarın servisimiz yoktur.',
          'dismissible': true,
          'seen': false,
          'dismissed': false,
        },
      ],
    };

    test('yerleşim sorguya girer ve liste sarmalayıcıdan çıkar', () async {
      final client = _client(body());

      final duyurular = await client.api.announcements.list(
        placement: AnnouncementPlacement.home,
      );

      final request = client.adapter.requests.single;
      expect(request.path, '/announcements');
      expect(request.queryParameters['placement'], 'home');
      expect(duyurular.single.id, 31);
    });

    test('yerleşim verilmezse BOŞ anahtar oluşmaz', () async {
      final client = _client(body());

      await client.api.announcements.list();

      expect(
        client.adapter.requests.single.queryParameters.containsKey('placement'),
        isFalse,
      );
    });
  });

  group('DiagnosticsService.reportError', () {
    test('rapor sözleşmedeki yola gider', () async {
      final client = _client(null, statusCode: 204);

      await client.api.diagnostics.reportError(
        const ClientErrorReport(
          message: 'Menü çizilemedi',
          kind: ClientErrorKind.render,
        ),
      );

      final request = client.adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/client-errors');
      expect((request.data! as Map)['message'], 'Menü çizilemedi');
      expect((request.data! as Map)['kind'], 'render');
    });

    test('uzun metin TELE ÇIKMADAN kesilir', () async {
      final client = _client(null, statusCode: 204);

      await client.api.diagnostics.reportError(
        ClientErrorReport(message: 'x' * 900, stack: 'y' * 9000),
      );

      final body = client.adapter.requests.single.data! as Map;
      expect((body['message'] as String).length, 500);
      expect((body['stack'] as String).length, 8000);
    });

    test('SUNUCU HATASI FIRLATMAZ — hata bildirmek hata üretmemeli', () async {
      // Bu metodun istisna atması, çağıranı catch bloğunun içinde ikinci bir
      // hataya sokar ve kendini besleyen bir döngü doğar.
      final client = _client({
        'error': {'code': 'SERVER_ERROR', 'message': 'Sunucu hatası'},
      }, statusCode: 500);

      await expectLater(
        client.api.diagnostics.reportError(
          const ClientErrorReport(message: 'Hata'),
        ),
        completes,
      );
    });

    test('oran sınırında da sessiz kalır ve TEKRAR DENEMEZ', () async {
      final client = _client({
        'error': {'code': 'RATE_LIMITED', 'message': 'Çok fazla istek'},
      }, statusCode: 429);

      await client.api.diagnostics.reportError(
        const ClientErrorReport(message: 'Hata'),
      );

      expect(
        client.adapter.requests,
        hasLength(1),
        reason: 'Tekrar denemek asıl teşhisi kaybettirir.',
      );
    });
  });
}
