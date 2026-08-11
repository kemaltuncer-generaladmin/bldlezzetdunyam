/// Abonelik üretim planı istemcisi — `GET /kitchen/subscription-plan`
/// (K-15).
///
/// > **NEDEN BURADA, `packages/api_client`'ta DEĞİL:** `kitchen_health.dart`,
/// > `sales_control.dart` ve `order_edit.dart` ile aynı gerekçe — uç
/// > sözleşmeye yeni eklendi. Taşındığında yalnız [SubscriptionPlanApi]
/// > uygulaması değişir.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bld_api_client/bld_api_client.dart';

/// Planın kapsadığı gün aralığı.
enum PlanRange {
  /// Bugün + yarın — varsayılan; mutfağın günlük ihtiyacı.
  today('today', 'Bugün ve yarın'),

  /// Yalnız yarın — akşam kapatırken basılan liste.
  tomorrow('tomorrow', 'Yarın'),

  /// Yedi gün — haftalık malzeme planlaması.
  week('week', 'Bu hafta');

  const PlanRange(this.wireName, this.label);

  final String wireName;
  final String label;
}

/// Bir günün üretim planı.
class PlanDay {
  const PlanDay({
    required this.date,
    required this.orders,
    required this.totals,
    required this.warnings,
  });

  final DateTime date;
  final List<PlanOrder> orders;

  /// Ürün bazında toplam — mutfağın sabah baktığı tek şey.
  final List<PlanTotal> totals;

  /// "Ne EKSİK" uyarıları: üretim koşmadı, kapalı gün, atlanan abonelik.
  final List<PlanWarning> warnings;

  /// O gün hazırlanacak toplam porsiyon.
  int get totalQuantity =>
      totals.fold(0, (sum, total) => sum + total.quantity);

  bool get isEmpty => orders.isEmpty && totals.isEmpty;

  factory PlanDay.fromJson(Map<String, Object?> json) => PlanDay(
    date: DateTime.tryParse('${json['date']}') ?? DateTime.now(),
    orders: (json['orders'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => PlanOrder.fromJson(Map<String, Object?>.from(row)))
        .toList(growable: false),
    totals: (json['totals'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (row) => PlanTotal(
            name: '${row['name']}',
            quantity: (row['quantity'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList(growable: false),
    warnings: (json['warnings'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (row) => PlanWarning(
            kind: '${row['kind']}',
            message: '${row['message']}',
          ),
        )
        .toList(growable: false),
  );
}

class PlanTotal {
  const PlanTotal({required this.name, required this.quantity});

  final String name;
  final int quantity;
}

class PlanWarning {
  const PlanWarning({required this.kind, required this.message});

  final String kind;
  final String message;

  /// Üretim hiç koşmamış — en ciddi uyarı, kırmızı gösterilir.
  ///
  /// Diğerleri bilgi ("bugün kapalı", "bir abonelik atlandı"); bu ise
  /// **eylem gerektiriyor**: cron çalışmamış ve kimse haberdar değil.
  bool get isCritical => kind == 'not_generated';
}

/// Plandaki tek sipariş satırı.
class PlanOrder {
  const PlanOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.items,
    this.deliveryTime,
    this.label,
    this.note,
  });

  final int id;
  final String orderNumber;
  final OrderStatus status;
  final List<({String name, int quantity})> items;

  /// `HH:mm` — teslimat saati.
  final String? deliveryTime;

  /// Kurum/müşteri adı.
  final String? label;

  final String? note;

  factory PlanOrder.fromJson(Map<String, Object?> json) => PlanOrder(
    id: (json['id'] as num).toInt(),
    orderNumber: '${json['order_number']}',
    status:
        OrderStatus.values
            .where((s) => s.wireName == json['status'])
            .firstOrNull ??
        OrderStatus.yeni,
    items: (json['items'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (row) => (
            name: '${row['name']}',
            quantity: (row['quantity'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList(growable: false),
    deliveryTime: _stringOrNull(json['delivery_time']),
    label: _stringOrNull(json['subscription_label']),
    note: _stringOrNull(json['customer_note']),
  );
}

abstract interface class SubscriptionPlanApi {
  Future<List<PlanDay>> plan(PlanRange range);
}

class HttpSubscriptionPlanApi implements SubscriptionPlanApi {
  HttpSubscriptionPlanApi({
    required this.baseUrl,
    required this.appId,
    required this.appVersion,
    required Future<String?> Function() readToken,
    HttpClient? client,
    this.timeout = const Duration(seconds: 15),
  }) : _readToken = readToken,
       _client = client ?? (HttpClient()..connectionTimeout = timeout);

  final String baseUrl;
  final String appId;
  final String appVersion;
  final Duration timeout;

  final Future<String?> Function() _readToken;
  final HttpClient _client;

  void close() => _client.close(force: true);

  @override
  Future<List<PlanDay>> plan(PlanRange range) async {
    final uri = Uri.parse(
      '$baseUrl/kitchen/subscription-plan?days=${range.wireName}',
    );

    try {
      final request = await _client.getUrl(uri).timeout(timeout);
      request.headers
        ..set('X-App-Id', appId)
        ..set('X-App-Version', appVersion)
        ..set('Accept', 'application/json')
        ..set('Accept-Language', 'tr');

      final token = await _readToken();
      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
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

      final days = decoded['days'];
      if (days is! List) return const [];

      return days
          .whereType<Map>()
          .map((row) => PlanDay.fromJson(Map<String, Object?>.from(row)))
          .toList(growable: false);
    } on ApiException {
      rethrow;
    } on Object catch (error) {
      throw ApiException.network('$error');
    }
  }
}

String? _stringOrNull(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
