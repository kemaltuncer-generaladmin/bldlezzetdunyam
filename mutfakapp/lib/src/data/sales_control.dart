/// Satış kontrolü istemcisi — `GET/POST /api/kitchen/ordering` ve
/// `/api/kitchen/menu-availability` (K-11).
///
/// > **NEDEN BURADA, `packages/api_client`'ta DEĞİL:** `kitchen_health.dart`
/// > ile aynı gerekçe — uçlar sözleşmeye yeni eklendi ve `packages/` bu
/// > görevin kapsamı dışında. İstemci `dart:io` ile yazıldı; `dio`
/// > mutfakapp'in doğrudan bağımlılığı değil ve öyle davranmak
/// > `depend_on_referenced_packages` ihlalidir. Uçlar `KitchenService`'e
/// > taşındığında bu dosyanın yalnızca [SalesControlApi] uygulaması
/// > değişir; ekran ve durum sınıfları aynen kalır.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bld_api_client/bld_api_client.dart';

/// Satış şalterinin durumu.
class OrderingState {
  const OrderingState({
    required this.enabled,
    required this.serverTime,
    this.reason,
    this.resumesAt,
    this.busy = false,
  });

  /// Sipariş alınıyor mu?
  final bool enabled;

  /// Durdurma sebebi — müşteriye de gösterilir.
  final String? reason;

  /// Süreli durdurmanın bitişi. `null` = süresiz (elle açılana kadar).
  final DateTime? resumesAt;

  /// Yoğunluk uyarısı (satışı kesmez, yalnız uyarır).
  final bool busy;

  final DateTime serverTime;

  /// Kapalıyken kalan süre. Süresiz kapalıysa ya da açıksa `null`.
  Duration? remaining(DateTime now) {
    if (enabled) return null;

    final until = resumesAt;
    if (until == null) return null;

    final left = until.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  factory OrderingState.fromJson(Map<String, Object?> json) => OrderingState(
    enabled: json['ordering_enabled'] == true,
    reason: _stringOrNull(json['reason']),
    resumesAt: _dateOrNull(json['resumes_at']),
    busy: json['busy'] == true,
    serverTime: _dateOrNull(json['server_time']) ?? DateTime.now().toUtc(),
  );

  @override
  bool operator ==(Object other) =>
      other is OrderingState &&
      other.enabled == enabled &&
      other.reason == reason &&
      other.resumesAt == resumesAt &&
      other.busy == busy;

  @override
  int get hashCode => Object.hash(enabled, reason, resumesAt, busy);

  @override
  String toString() =>
      'OrderingState(enabled: $enabled, reason: $reason, '
      'resumesAt: $resumesAt, busy: $busy)';
}

/// Mutfağın gördüğü ürün — **fiyatsız** (ADR-08).
class KitchenMenuItem {
  const KitchenMenuItem({
    required this.menuId,
    required this.name,
    required this.listed,
    required this.soldOut,
    this.soldOutReason,
  });

  final int menuId;
  final String name;

  /// Yöneticinin kalıcı kararı: ürün menüde mi?
  ///
  /// Mutfağın günlük kararından ayrı gösteriliyor; personel "ben açtım ama
  /// görünmüyor" dediğinde sebep burada.
  final bool listed;

  /// Mutfağın günlük kararı: bugün tükendi mi?
  final bool soldOut;

  final String? soldOutReason;

  /// Müşteri bu ürünü sipariş edebilir mi?
  bool get orderable => listed && !soldOut;

  factory KitchenMenuItem.fromJson(Map<String, Object?> json) =>
      KitchenMenuItem(
        menuId: (json['menu_id'] as num).toInt(),
        name: '${json['name']}',
        listed: json['listed'] == true,
        soldOut: json['sold_out'] == true,
        soldOutReason: _stringOrNull(json['sold_out_reason']),
      );
}

/// Durdurma süresi seçenekleri.
///
/// SABİT SEÇENEKLER, serbest dakika girişi değil: mutfakta "kaç dakika?"
/// sorusuna cevap aramak, kapatma kararını geciktiriyor. Dördü de sahada
/// istenen davranışları karşılıyor.
enum OrderingPauseDuration {
  /// 30 dakika — yoğunluk dalgası.
  halfHour(30, '30 dakika'),

  /// 1 saat — malzeme bekleniyor.
  oneHour(60, '1 saat'),

  /// Gün sonuna kadar — yarın sabah kendiliğinden açılır.
  endOfDay(0, 'Bugünün sonuna kadar'),

  /// Süresiz — elle açılana kadar. En riskli seçenek, en sona konuldu.
  indefinite(null, 'Ben açana kadar');

  const OrderingPauseDuration(this.minutes, this.label);

  /// Sunucuya gönderilen `minutes` değeri. `null` = süresiz, `0` = gün sonu.
  final int? minutes;
  final String label;
}

abstract interface class SalesControlApi {
  Future<OrderingState> ordering();

  Future<OrderingState> setOrdering({
    required bool enabled,
    String? reason,
    int? minutes,
  });

  Future<List<KitchenMenuItem>> menuAvailability();

  Future<List<KitchenMenuItem>> setMenuAvailability({
    required int menuId,
    required bool soldOut,
    String? reason,
  });
}

/// `dart:io` tabanlı uygulama.
class HttpSalesControlApi implements SalesControlApi {
  HttpSalesControlApi({
    required this.baseUrl,
    required this.appId,
    required this.appVersion,
    required Future<String?> Function() readToken,
    HttpClient? client,
    this.timeout = const Duration(seconds: 10),
  }) : _readToken = readToken,
       _client = client ?? (HttpClient()..connectionTimeout = timeout);

  /// `/api` dahil taban adres.
  final String baseUrl;
  final String appId;
  final String appVersion;
  final Duration timeout;

  final Future<String?> Function() _readToken;
  final HttpClient _client;

  void close() => _client.close(force: true);

  @override
  Future<OrderingState> ordering() async =>
      OrderingState.fromJson(await _send('GET', 'kitchen/ordering'));

  @override
  Future<OrderingState> setOrdering({
    required bool enabled,
    String? reason,
    int? minutes,
  }) async => OrderingState.fromJson(
    await _send(
      'POST',
      'kitchen/ordering',
      body: <String, Object?>{
        'enabled': enabled,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        // `minutes` YOKSA süresiz. `null` göndermekle hiç göndermemek
        // sunucuda aynı anlama geliyor; gövdeyi kısa tutuyoruz.
        'minutes': ?minutes,
      },
    ),
  );

  @override
  Future<List<KitchenMenuItem>> menuAvailability() async =>
      _items(await _send('GET', 'kitchen/menu-availability'));

  @override
  Future<List<KitchenMenuItem>> setMenuAvailability({
    required int menuId,
    required bool soldOut,
    String? reason,
  }) async => _items(
    await _send(
      'POST',
      'kitchen/menu-availability',
      body: <String, Object?>{
        'menu_id': menuId,
        'sold_out': soldOut,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    ),
  );

  List<KitchenMenuItem> _items(Map<String, Object?> json) {
    final data = json['data'];
    if (data is! List) return const [];

    return data
        .whereType<Map>()
        .map((row) => KitchenMenuItem.fromJson(Map<String, Object?>.from(row)))
        .toList(growable: false);
  }

  Future<Map<String, Object?>> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final uri = Uri.parse('$baseUrl/$path');

    try {
      final request = await _client.openUrl(method, uri).timeout(timeout);
      request.headers
        ..contentType = ContentType('application', 'json', charset: 'utf-8')
        // Sözleşmenin zorunlu başlıkları (`docs/03` §1.1).
        ..set('X-App-Id', appId)
        ..set('X-App-Version', appVersion)
        ..set('Accept-Language', 'tr');

      final token = await _readToken();
      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }

      if (body != null) {
        request.write(jsonEncode(body));
      }

      final response = await request.close().timeout(timeout);
      final text = await utf8.decoder.bind(response).join().timeout(timeout);

      final decoded = text.isEmpty ? null : jsonDecode(text);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException.fromResponse(decoded, response.statusCode);
      }
      if (decoded is! Map) {
        throw const ApiException(
          code: ApiErrorCode.unknown,
          message: 'Sunucu beklenmeyen bir yanıt döndü.',
        );
      }

      return Map<String, Object?>.from(decoded);
    } on ApiException {
      rethrow;
    } on Object catch (error) {
      // Soket hatası, DNS, zaman aşımı, bozuk JSON — çağıran için hepsi
      // aynı: sunucuya ulaşılamadı.
      throw ApiException.network('$error');
    }
  }
}

String? _stringOrNull(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

DateTime? _dateOrNull(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value)?.toUtc();
}
