/// HTTP istemcisi ve servis uygulamaları.
///
/// Zorunlu başlıklar (`X-App-Id`, `X-App-Version`, `Accept-Language`) ve
/// `Authorization` tek bir interceptor'da eklenir; çağrı yerlerinde tekrar
/// edilmez. Tüm hatalar [ApiException]'a çevrilir — çağıran `DioException`
/// görmez.
library;

import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'models/announcement.dart';
import 'models/auth.dart';
import 'models/catalog.dart';
import 'models/client_error.dart';
import 'models/converters.dart';
import 'models/daily_menu.dart';
import 'models/kitchen.dart';
import 'models/order.dart';
import 'models/subscription.dart';
import 'services.dart';

/// Token'ın nerede saklandığını istemci bilmez.
///
/// `musteriapp` ve `mutfakapp` bunu `shared_preferences` ile, `website` ise
/// cookie ile uygular; testler bellekte tutar.
abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

/// Bellekte tutan basit uygulama — testler ve mock'a bağlanan denemeler için.
class InMemoryTokenStore implements TokenStore {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}

/// İstemci kimliği — `docs/03-api-sozlesmesi.md` §1.1.
class BldApiConfig {
  const BldApiConfig({
    required this.baseUrl,
    required this.appId,
    required this.appVersion,
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 20),
  });

  /// `/api` dahil taban adres, örn. `http://localhost:4010/api`.
  final String baseUrl;

  /// `website` | `musteriapp` | `mutfakapp`.
  final String appId;

  /// Semver, örn. `1.0.0`.
  final String appVersion;

  final Duration connectTimeout;
  final Duration receiveTimeout;
}

/// Tüm servislerin giriş noktası.
class BldApi {
  BldApi({required BldApiConfig config, TokenStore? tokenStore, Dio? dio})
    : _tokenStore = tokenStore ?? InMemoryTokenStore(),
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: config.baseUrl,
              connectTimeout: config.connectTimeout,
              receiveTimeout: config.receiveTimeout,
              contentType: 'application/json; charset=utf-8',
              // Hata yanıtlarını da elimize alalım ki tek biçime çevirelim.
              validateStatus: (_) => true,
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.headers['X-App-Id'] = config.appId;
          options.headers['X-App-Version'] = config.appVersion;
          options.headers['Accept-Language'] = 'tr';

          final token = await _tokenStore.read();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );

    auth = _AuthService(this);
    catalog = _CatalogService(this);
    orders = _OrderService(this);
    addresses = _AddressService(this);
    kitchen = _KitchenService(this);
    appVersion = _AppVersionService(this);
    subscriptions = _SubscriptionService(this);
    contracts = _ContractService(this);
    announcements = _AnnouncementService(this);
    diagnostics = _DiagnosticsService(this);
  }

  final Dio _dio;
  final TokenStore _tokenStore;

  late final AuthService auth;
  late final CatalogService catalog;
  late final OrderService orders;
  late final AddressService addresses;
  late final KitchenService kitchen;
  late final AppVersionService appVersion;
  late final SubscriptionService subscriptions;
  late final ContractService contracts;
  late final AnnouncementService announcements;
  late final DiagnosticsService diagnostics;

  TokenStore get tokenStore => _tokenStore;

  void close() => _dio.close(force: true);

  /// Tek çağrı noktası: gönderir, durum kodunu denetler, hatayı çevirir.
  Future<T> _send<T>(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    required T Function(Object? data) parse,
  }) async {
    Response<dynamic> response;
    try {
      response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method),
      );
    } on DioException catch (e) {
      // Ağ katmanı hiç yanıt üretemedi.
      throw ApiException.network(
        e.type == DioExceptionType.connectionTimeout ||
                e.type == DioExceptionType.receiveTimeout
            ? 'Sunucu yanıt vermedi. Tekrar deneyin.'
            : null,
      );
    }

    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw ApiException.fromResponse(response.data, status);
    }
    return parse(response.data);
  }

  /// Yanıt gövdesini `Map` olarak bekler.
  static Map<String, dynamic> _asMap(Object? data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const ApiException(
      code: ApiErrorCode.unknown,
      message: 'Sunucu beklenmeyen bir yanıt döndü.',
    );
  }

  /// `{ "data": { ... } }` sarmalayıcısından nesneyi çıkarır.
  ///
  /// Tekil kaynaklar (`GET /orders/{id}`) gövdeyi doğrudan döndürür, katalog
  /// uçları ise `data` içinde sarar. Sarmalayıcı sözleşmede uca göre
  /// değişiyor — [_asMap] ile ayrı tutuluyorlar ki hangi ucun hangisini
  /// kullandığı çağrı yerinde okunsun.
  static Map<String, dynamic> _asDataMap(Object? data) {
    final map = _asMap(data);
    final inner = map['data'];
    if (inner is! Map) {
      throw const ApiException(
        code: ApiErrorCode.unknown,
        message: 'Sunucu beklenmeyen bir yanıt döndü.',
      );
    }
    return Map<String, dynamic>.from(inner);
  }

  /// `{ "data": { ... } | null }` — `data: null` geçerli bir cevaptır.
  static Map<String, dynamic>? _asNullableDataMap(Object? data) {
    final map = _asMap(data);
    final inner = map['data'];
    if (inner == null) return null;
    if (inner is! Map) {
      throw const ApiException(
        code: ApiErrorCode.unknown,
        message: 'Sunucu beklenmeyen bir yanıt döndü.',
      );
    }
    return Map<String, dynamic>.from(inner);
  }

  /// `{ "data": [...] }` sarmalayıcısından listeyi çıkarır.
  static List<T> _asDataList<T>(
    Object? data,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final map = _asMap(data);
    final list = map['data'];
    if (list is! List) {
      throw const ApiException(
        code: ApiErrorCode.unknown,
        message: 'Sunucu beklenmeyen bir yanıt döndü.',
      );
    }
    return list
        .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }
}

// ─────────────────────────── Servis uygulamaları ───────────────────────────

class _AuthService implements AuthService {
  _AuthService(this._api);

  final BldApi _api;

  @override
  Future<AuthResponse> register(RegisterRequest request) async {
    final result = await _api._send(
      'POST',
      '/auth/register',
      body: request.toJson(),
      parse: (data) => AuthResponse.fromJson(BldApi._asMap(data)),
    );
    await _api._tokenStore.write(result.token);
    return result;
  }

  @override
  Future<AuthResponse> login(LoginRequest request) async {
    final result = await _api._send(
      'POST',
      '/auth/login',
      body: request.toJson(),
      parse: (data) => AuthResponse.fromJson(BldApi._asMap(data)),
    );
    await _api._tokenStore.write(result.token);
    return result;
  }

  @override
  Future<void> logout() async {
    try {
      await _api._send<void>('POST', '/auth/logout', parse: (_) {});
    } finally {
      // Sunucu ne derse desin yerel token silinir; aksi halde kullanıcı
      // sunucu erişilemezken çıkış yapamaz.
      await _api._tokenStore.clear();
    }
  }

  @override
  Future<Customer> me() => _api._send(
    'GET',
    '/auth/me',
    parse: (data) => Customer.fromJson(BldApi._asMap(data)),
  );

  @override
  Future<void> registerPushToken(PushTokenRequest request) => _api._send<void>(
    'POST',
    '/me/push-token',
    body: request.toJson(),
    parse: (_) {},
  );
}

class _CatalogService implements CatalogService {
  _CatalogService(this._api);

  final BldApi _api;

  @override
  Future<List<Location>> locations() => _api._send(
    'GET',
    '/locations',
    parse: (data) => BldApi._asDataList(data, Location.fromJson),
  );

  @override
  Future<List<MenuCategory>> menu(int locationId) => _api._send(
    'GET',
    '/locations/$locationId/menu',
    parse: (data) => BldApi._asDataList(data, MenuCategory.fromJson),
  );

  @override
  Future<DailyMenu> dailyMenu(int locationId, {String? date}) => _api._send(
    'GET',
    '/locations/$locationId/daily-menu',
    query: {'date': ?date},
    parse: (data) => DailyMenu.fromJson(BldApi._asDataMap(data)),
  );

  @override
  Future<List<MenuCalendarDay>> menuCalendar(
    int locationId, {
    String? from,
    String? to,
  }) => _api._send(
    'GET',
    '/locations/$locationId/menu-calendar',
    query: {'from': ?from, 'to': ?to},
    parse: (data) => BldApi._asDataList(data, MenuCalendarDay.fromJson),
  );
}

class _OrderService implements OrderService {
  _OrderService(this._api);

  final BldApi _api;

  @override
  Future<OrderCreated> create(OrderCreateRequest request) => _api._send(
    'POST',
    '/orders',
    body: request.toJson(),
    parse: (data) => OrderCreated.fromJson(BldApi._asMap(data)),
  );

  @override
  Future<OrderPage> list({int page = 1, int perPage = 25}) => _api._send(
    'GET',
    '/orders',
    query: {'page': page, 'per_page': perPage},
    parse: (data) => OrderPage.fromJson(BldApi._asMap(data)),
  );

  @override
  Future<OrderDetail> get(int id) => _api._send(
    'GET',
    '/orders/$id',
    parse: (data) => OrderDetail.fromJson(BldApi._asMap(data)),
  );

  @override
  Future<OrderDetail> cancel(int id) => _api._send(
    'POST',
    '/orders/$id/cancel',
    parse: (data) => OrderDetail.fromJson(BldApi._asMap(data)),
  );
}

class _AddressService implements AddressService {
  _AddressService(this._api);

  final BldApi _api;

  @override
  Future<List<SavedAddress>> list() => _api._send(
    'GET',
    '/addresses',
    parse: (data) => BldApi._asDataList(data, SavedAddress.fromJson),
  );

  @override
  Future<SavedAddress> create(SavedAddressInput input) => _api._send(
    'POST',
    '/addresses',
    body: input.toJson(),
    parse: (data) => SavedAddress.fromJson(BldApi._asMap(data)),
  );

  @override
  Future<SavedAddress> update(int id, SavedAddressInput input) => _api._send(
    'PATCH',
    '/addresses/$id',
    body: input.toJson(),
    parse: (data) => SavedAddress.fromJson(BldApi._asMap(data)),
  );

  @override
  // 204 döner; gövde yok.
  Future<void> delete(int id) =>
      _api._send<void>('DELETE', '/addresses/$id', parse: (_) {});

  /// Sunucunun altına indiği en kısa sorgu (`docs/openapi.yaml` `q.minLength`).
  static const int _minSuggestQueryLength = 3;

  @override
  Future<List<AddressSuggestion>> suggest(String query, {int limit = 5}) async {
    final trimmed = query.trim();

    // ÜÇ KARAKTERİN ALTINDA AĞA HİÇ ÇIKILMAZ.
    //
    // Sunucu bu isteği `422` ile reddediyor ve sözleşme bunu bir İSTEMCİ
    // hatası sayıyor: "k" yazan kullanıcı bir şey yapmadı, biz erken sorduk.
    // Kuralı burada uygulamak, üç ekranın (arama kutusu, harita paneli,
    // ödeme formu) aynı korumayı ayrı ayrı yazıp birinde unutmasını önler —
    // unutulduğunda kullanıcı her harfte kırmızı bir hata görürdü.
    //
    // Bekleme (debounce) arayüzün işidir ve burada TAŞINMAZ: zamanlayıcı
    // tutmak bu katmanın işi değil, ayrıca her ekranın gecikmesi farklı
    // olabilir. İkisi birlikte sağlayıcı kotasını korur.
    if (trimmed.length < _minSuggestQueryLength) {
      return const <AddressSuggestion>[];
    }

    return _api._send(
      'GET',
      '/addresses/suggest',
      // Üst sınır sözleşmede 10; aşan bir değer `422` olurdu. Çağıranı
      // hataya sokmak yerine kısıyoruz — sonuç sayısı bir tercih, bir
      // sözleşme değil.
      query: {'q': trimmed, 'limit': limit.clamp(1, 10)},
      parse: (data) => BldApi._asDataList(data, AddressSuggestion.fromJson),
    );
  }

  @override
  Future<AddressSuggestion?> reverse(double lat, double lng) => _api._send(
    'GET',
    '/addresses/reverse',
    query: {'lat': lat, 'lng': lng},
    parse: (data) {
      final map = BldApi._asNullableDataMap(data);
      return map == null ? null : AddressSuggestion.fromJson(map);
    },
  );
}

class _KitchenService implements KitchenService {
  _KitchenService(this._api);

  final BldApi _api;

  @override
  Future<PairResponse> pair(PairRequest request) async {
    final result = await _api._send(
      'POST',
      '/kitchen/pair',
      body: request.toJson(),
      parse: (data) => PairResponse.fromJson(BldApi._asMap(data)),
    );
    await _api._tokenStore.write(result.token);
    return result;
  }

  @override
  Future<KitchenOrderPage> orders({
    int? after,
    DateTime? since,
    bool includeCompleted = false,
  }) => _api._send(
    'GET',
    '/kitchen/orders',
    query: {
      'after': ?after,
      if (since != null) 'since': since.toUtc().toIso8601String(),
      if (includeCompleted) 'include_completed': true,
    },
    parse: (data) => KitchenOrderPage.fromJson(BldApi._asMap(data)),
  );

  @override
  Future<KitchenOrder> setStatus(int orderId, OrderStatus status) => _api._send(
    'POST',
    '/kitchen/orders/$orderId/status',
    body: {'status': status.wireName},
    parse: (data) => KitchenOrder.fromJson(BldApi._asMap(data)),
  );

  @override
  Future<KitchenSubscriptionOrders> subscriptionOrders() => _api._send(
    'GET',
    '/kitchen/subscription-orders',
    parse: (data) => KitchenSubscriptionOrders.fromJson(BldApi._asMap(data)),
  );

  @override
  Future<KitchenReceipt> kitchenReceipt(int orderId) => _api._send(
    'GET',
    '/kitchen/orders/$orderId/receipt',
    query: {'type': ReceiptType.mutfak.wireName},
    parse: (data) => KitchenReceipt.fromJson(BldApi._asMap(data)),
  );

  @override
  Future<CustomerReceipt> customerReceipt(int orderId) => _api._send(
    'GET',
    '/kitchen/orders/$orderId/receipt',
    query: {'type': ReceiptType.musteri.wireName},
    parse: (data) => CustomerReceipt.fromJson(BldApi._asMap(data)),
  );

  @override
  Future<CourierReceipt> courierReceipt(int orderId) => _api._send(
    'GET',
    '/kitchen/orders/$orderId/receipt',
    query: {'type': ReceiptType.kurye.wireName},
    parse: (data) => CourierReceipt.fromJson(BldApi._asMap(data)),
  );

  @override
  Future<void> ackPrint(int orderId, PrintAckRequest request) =>
      _api._send<void>(
        'POST',
        '/kitchen/print-jobs/$orderId/ack',
        body: request.toJson(),
        parse: (_) {},
      );

  @override
  Future<ProductionList> productionList() => _api._send(
    'GET',
    '/kitchen/production-list',
    parse: (data) => ProductionList.fromJson(BldApi._asMap(data)),
  );

  @override
  Future<HeartbeatResponse> heartbeat() => _api._send(
    'GET',
    '/kitchen/heartbeat',
    parse: (data) => HeartbeatResponse.fromJson(BldApi._asMap(data)),
  );

  @override
  Future<BusyState> setBusy(bool busy) => _api._send(
    'POST',
    '/kitchen/busy',
    body: {'busy': busy},
    parse: (data) => BusyState.fromJson(BldApi._asMap(data)),
  );
}

class _AppVersionService implements AppVersionService {
  _AppVersionService(this._api);

  final BldApi _api;

  @override
  Future<AppVersionInfo> check(String appId) => _api._send(
    'GET',
    '/app-version',
    query: {'app_id': appId},
    parse: (data) => AppVersionInfo.fromJson(BldApi._asMap(data)),
  );
}

class _SubscriptionService implements SubscriptionService {
  _SubscriptionService(this._api);

  final BldApi _api;

  @override
  Future<List<Subscription>> list() => _api._send(
    'GET',
    '/subscriptions',
    parse: (data) => BldApi._asDataList(data, Subscription.fromJson),
  );

  @override
  Future<Subscription> get(int id) => _api._send(
    'GET',
    '/subscriptions/$id',
    parse: (data) => Subscription.fromJson(BldApi._asMap(data)),
  );

  @override
  Future<Subscription> create(SubscriptionCreateRequest request) => _api._send(
    'POST',
    '/subscriptions',
    body: request.toJson(),
    parse: (data) => Subscription.fromJson(BldApi._asMap(data)),
  );

  @override
  Future<Subscription> pause(int id) => _api._send(
    'POST',
    '/subscriptions/$id/pause',
    parse: (data) => Subscription.fromJson(BldApi._asMap(data)),
  );

  @override
  Future<Subscription> resume(int id) => _api._send(
    'POST',
    '/subscriptions/$id/resume',
    parse: (data) => Subscription.fromJson(BldApi._asMap(data)),
  );

  @override
  Future<Subscription> cancel(int id) => _api._send(
    'POST',
    '/subscriptions/$id/cancel',
    parse: (data) => Subscription.fromJson(BldApi._asMap(data)),
  );

  @override
  Future<Subscription> addException(
    int id,
    SubscriptionExceptionRequest request,
  ) => _api._send(
    'POST',
    '/subscriptions/$id/exceptions',
    body: request.toJson(),
    parse: (data) => Subscription.fromJson(BldApi._asMap(data)),
  );

  @override
  Future<SubscriptionPayment> startPayment(int id, {String? period}) =>
      _api._send(
        'POST',
        '/subscriptions/$id/payments',
        // Dönem verilmediğinde gövde BOŞ gider: `{"period": null}` göndermek,
        // sunucuya "dönemi bilmiyorum" değil "dönem yok" demektir.
        body: period == null ? null : {'period': period},
        parse: (data) => SubscriptionPayment.fromJson(BldApi._asMap(data)),
      );

  @override
  Future<SubscriptionPayment> confirmPayment(
    int id,
    int paymentId, {
    String? otp,
  }) => _api._send(
    'POST',
    '/subscriptions/$id/payments/$paymentId/confirm',
    // Sözleşmedeki alan adı `code`; istemci tarafında `otp` deniyor çünkü
    // ekranın sorduğu şey "SMS kodu". Çeviri tek yerde.
    body: otp == null ? null : {'code': otp},
    parse: (data) => SubscriptionPayment.fromJson(BldApi._asMap(data)),
  );

  @override
  Future<SubscriptionPayment> payment(int id, int paymentId) => _api._send(
    'GET',
    '/subscriptions/$id/payments/$paymentId',
    parse: (data) => SubscriptionPayment.fromJson(BldApi._asMap(data)),
  );
}

class _ContractService implements ContractService {
  _ContractService(this._api);

  final BldApi _api;

  @override
  Future<SubscriptionContract> get(String token) => _api._send(
    'GET',
    '/contracts/${Uri.encodeComponent(token)}',
    parse: (data) => SubscriptionContract.fromJson(BldApi._asDataMap(data)),
  );

  @override
  // 202 döner; gövdesi ("kod X saniye geçerli") ekranda kullanılmıyor —
  // geri sayımı sunucudan almak yerine sabit tutmak, kodun ömrü değişince
  // ekranın yalan söylemesi demekti. Gerekirse ayrı bir tip eklenir.
  Future<void> requestOtp(String token) => _api._send<void>(
    'POST',
    '/contracts/${Uri.encodeComponent(token)}/otp',
    parse: (_) {},
  );

  @override
  Future<SubscriptionContract> approve(String token, String code) => _api._send(
    'POST',
    '/contracts/${Uri.encodeComponent(token)}/approve',
    body: {'code': code},
    parse: (data) => SubscriptionContract.fromJson(BldApi._asDataMap(data)),
  );
}

class _AnnouncementService implements AnnouncementService {
  _AnnouncementService(this._api);

  final BldApi _api;

  @override
  Future<List<Announcement>> list({String? placement}) => _api._send(
    'GET',
    '/announcements',
    query: {'placement': ?placement},
    parse: (data) => BldApi._asDataList(data, Announcement.fromJson),
  );
}

class _DiagnosticsService implements DiagnosticsService {
  _DiagnosticsService(this._api);

  final BldApi _api;

  @override
  Future<void> reportError(ClientErrorReport report) async {
    // HER ŞEYİ YUTAR. Hata bildirme yolunda atılan bir istisna, çağıranı
    // catch bloğunun içinde ikinci bir hataya sokar ve kendini besleyen bir
    // döngü doğar. Sunucu zaten `204` dışında bir şey döndürmemeye söz
    // veriyor; buradaki tek gerçek risk ağın hiç olmamasıdır ve o durumda
    // kaybedilecek şey bir teşhis satırıdır.
    //
    // TEKRAR DENEME DE YOK: döngüye girmiş bir ekran saniyede onlarca rapor
    // üretiyor; üstüne tekrar denemek oran sınırını doldurur ve asıl teşhisi
    // kaybettirir.
    try {
      await _api._send<void>(
        'POST',
        '/client-errors',
        body: report.truncated().toJson(),
        parse: (_) {},
      );
    } on ApiException {
      // Sessiz.
    } on Object {
      // Serileştirme dahil her şey. Rapor kaybı kabul edilmiş bir kayıptır.
    }
  }
}
