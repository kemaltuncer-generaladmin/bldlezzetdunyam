/// `POST /api/kitchen/health` — çift yönlü sağlık bildirimi.
///
/// Cihaz kendi bilebildiğini gönderir (yazıcı erişilebilir mi, kuyrukta kaç
/// fiş var), sunucu cihazın bilemeyeceğini döner: **bugün kaç sipariş girdi**.
/// Mutfak listesi yalnızca aktif siparişleri taşır; teslim edilenler düşer ve
/// günlük toplam yerelde hesaplanamaz.
///
/// `heartbeat` ile karıştırılmamalı: o yalnızca "cihaz ayakta" der. İkisi de
/// kalır ve ikisi de ayrı zamanlayıcıda koşar.
///
/// > **NEDEN BURADA, `packages/api_client`'ta DEĞİL:** uç sözleşmeye yeni
/// > eklendi ve `packages/` bu görevin kapsamı dışında. İstemci geçici olarak
/// > `dart:io` ile yazıldı — `dio` mutfakapp'in doğrudan bağımlılığı değil ve
/// > öyle davranmak `depend_on_referenced_packages` ihlalidir. Uç
/// > `KitchenService`'e taşındığında bu dosyanın yalnızca [KitchenHealthApi]
/// > uygulaması değişir; monitör ve arayüz aynen kalır.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bld_api_client/bld_api_client.dart';

/// Cihazın sunucuya bildirdiği durum.
///
/// Değerlerin **gerçek** olması şart: sabit `true` göndermek göstergeyi
/// yalancı yapar ve gösterge yalan söylüyorsa hiç olmaması daha iyidir.
class KitchenHealthReport {
  const KitchenHealthReport({
    required this.printerOk,
    required this.printQueuePending,
    required this.printQueueFailed,
    this.appVersion,
  });

  final bool printerOk;
  final int printQueuePending;
  final int printQueueFailed;
  final String? appVersion;

  Map<String, Object?> toJson() => <String, Object?>{
    'printer_ok': printerOk,
    // Sunucu `min:0` istiyor; negatif bir sayacın buraya kadar gelmesi bir
    // hata olurdu ama isteği 422 ile geri çevirtmesine gerek yok.
    'print_queue_pending': printQueuePending < 0 ? 0 : printQueuePending,
    'print_queue_failed': printQueueFailed < 0 ? 0 : printQueueFailed,
    if (appVersion != null) 'app_version': appVersion,
  };
}

/// Sunucunun döndüğü durum.
class KitchenHealthStatus {
  const KitchenHealthStatus({
    required this.serverTime,
    required this.ordersToday,
    required this.ordersActive,
  });

  /// Sunucu saati (UTC).
  final DateTime serverTime;

  /// Bugün girilen sipariş sayısı — **iptaller hariç**, gün sınırı
  /// Europe/Istanbul.
  final int ordersToday;

  /// Sunucudaki aktif sipariş sayısı.
  final int ordersActive;

  factory KitchenHealthStatus.fromJson(Map<String, Object?> json) =>
      KitchenHealthStatus(
        serverTime:
            DateTime.tryParse('${json['server_time']}')?.toUtc() ??
            DateTime.now().toUtc(),
        ordersToday: _asInt(json['orders_today']),
        ordersActive: _asInt(json['orders_active']),
      );

  static int _asInt(Object? value) => switch (value) {
    final int v => v,
    final num v => v.toInt(),
    final String v => int.tryParse(v) ?? 0,
    _ => 0,
  };

  @override
  bool operator ==(Object other) =>
      other is KitchenHealthStatus &&
      other.serverTime == serverTime &&
      other.ordersToday == ordersToday &&
      other.ordersActive == ordersActive;

  @override
  int get hashCode => Object.hash(serverTime, ordersToday, ordersActive);

  @override
  String toString() =>
      'KitchenHealthStatus(today: $ordersToday, active: $ordersActive)';
}

/// Sağlık ucunun soyutlaması. Testte sahtelenir.
abstract interface class KitchenHealthApi {
  Future<KitchenHealthStatus> report(KitchenHealthReport report);
}

/// `dart:io` ile yazılmış istemci.
class HttpKitchenHealthApi implements KitchenHealthApi {
  HttpKitchenHealthApi({
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
  Future<KitchenHealthStatus> report(KitchenHealthReport report) async {
    final uri = Uri.parse('$baseUrl/kitchen/health');

    try {
      final request = await _client.postUrl(uri).timeout(timeout);
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

      request.write(jsonEncode(report.toJson()));
      final response = await request.close().timeout(timeout);
      final body = await utf8.decoder.bind(response).join().timeout(timeout);

      final decoded = body.isEmpty ? null : jsonDecode(body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException.fromResponse(decoded, response.statusCode);
      }
      if (decoded is! Map) {
        throw const ApiException(
          code: ApiErrorCode.unknown,
          message: 'Sunucu beklenmeyen bir yanıt döndü.',
        );
      }

      return KitchenHealthStatus.fromJson(Map<String, Object?>.from(decoded));
    } on ApiException {
      rethrow;
    } on Object catch (error) {
      // Soket hatası, DNS, zaman aşımı, bozuk JSON — hepsi çağıran için aynı:
      // sunucuya ulaşılamadı.
      throw ApiException.network('$error');
    }
  }
}

/// Sağlık göstergesinin arayüze verdiği durum.
class KitchenHealthState {
  const KitchenHealthState({
    this.status,
    this.lastSuccessAt,
    this.reachable = false,
    this.everTried = false,
  });

  static const KitchenHealthState initial = KitchenHealthState();

  /// Sunucudan gelen son sayılar. Bağlantı koptuysa **eskir ama silinmez**:
  /// "bugün 12 sipariş (3 dk önce)" bilgisi, hiç sayı görmemekten iyidir.
  final KitchenHealthStatus? status;

  /// Son başarılı bildirim anı (UTC).
  final DateTime? lastSuccessAt;

  /// Son deneme başarılı mıydı?
  final bool reachable;

  /// Hiç denendi mi? Açılışta "sunucu yok" demeden önce bir deneme beklenir.
  final bool everTried;

  KitchenHealthState copyWith({
    KitchenHealthStatus? status,
    DateTime? lastSuccessAt,
    bool? reachable,
    bool? everTried,
  }) => KitchenHealthState(
    status: status ?? this.status,
    lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
    reachable: reachable ?? this.reachable,
    everTried: everTried ?? this.everTried,
  );

  @override
  bool operator ==(Object other) =>
      other is KitchenHealthState &&
      other.status == status &&
      other.lastSuccessAt == lastSuccessAt &&
      other.reachable == reachable &&
      other.everTried == everTried;

  @override
  int get hashCode => Object.hash(status, lastSuccessAt, reachable, everTried);
}

/// Sağlık bildirimini yapan ve sonucu durumda tutan saf mantık.
///
/// Zamanlayıcı burada DEĞİL: [poll] dışarıdan çağrılır, böylece test sahte
/// saat ya da `FakeAsync` kurmadan davranışı doğrulayabilir.
class KitchenHealthMonitor {
  KitchenHealthMonitor({
    required KitchenHealthApi api,
    required Future<KitchenHealthReport> Function() collect,
    DateTime Function()? clock,
  }) : _api = api,
       _collect = collect,
       _clock = clock ?? (() => DateTime.now().toUtc());

  final KitchenHealthApi _api;

  /// Toplayıcı ASENKRON.
  ///
  /// Yazıcı durumu önbellekten değil, cihazın kendisinden okunmalı; bu da
  /// bir dosya sistemi çağrısı demek. Senkron bir imza, çağıranı önbelleğe
  /// bakmaya zorluyordu ve önbellek açılışta boştu — sonuç, her açılışta
  /// "yazıcı arızalı" diye yalan bildirim.
  final Future<KitchenHealthReport> Function() _collect;
  final DateTime Function() _clock;

  KitchenHealthState _state = KitchenHealthState.initial;

  KitchenHealthState get state => _state;

  /// Bir bildirim gönderir ve durumu günceller.
  ///
  /// Hata YUKARI ATILMAZ. Sağlık bildirimi bir yan işlevdir; başarısızlığı
  /// mutfağın sipariş görmesini engellememeli. Başarısızlığın kendisi zaten
  /// bilgidir: "sunucu" göstergesi kırmızıya döner ve son başarılı iletişimin
  /// üzerinden geçen süre görünür kalır.
  Future<KitchenHealthState> poll() async {
    try {
      final status = await _api.report(await _collect());
      _state = KitchenHealthState(
        status: status,
        lastSuccessAt: _clock(),
        reachable: true,
        everTried: true,
      );
    } on Object {
      _state = _state.copyWith(reachable: false, everTried: true);
    }
    return _state;
  }
}
