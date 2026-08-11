/// BBD Store köprüsü istemcisi — `GET /kitchen/bbd-orders` (K-16).
///
/// **BBD Store bir KİTAP e-ticaret sitesidir**, catering değil ve ayrı bir
/// sunucuda ayrı bir projedir.
///
/// **TEK AMAÇ:** oradaki sipariş için BBD'ye özel bir ses çalmak ve aynı
/// termal yazıcıdan bir **paketleme fişi** bastırmak. Köprünün varlık
/// sebebi yazıcıyı paylaşmak; başka hiçbir şey değil.
///
/// Bu siparişler panoya girmez, üretim şeridine, vardiya istatistiğine ve
/// günlük sayaca **karışmaz**.
///
/// NEDEN `since` YOK, `printed_at IS NULL` VAR: BBD fişleri bir "liste"
/// değil, bir **kuyruk**. Zaman damgasıyla artımlı çekmek, ağ
/// kesintisinde basılmamış bir fişi sonsuza dek atlayabilirdi. Kasa
/// bastıkça sunucuya bildiriyor ve kuyruk boşalıyor.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bld_api_client/bld_api_client.dart';

/// Basılmayı bekleyen tek BBD fişi.
class BbdOrder {
  const BbdOrder({
    required this.id,
    required this.externalId,
    required this.orderNumber,
    required this.items,
    this.customerLabel,
    this.customerPhone,
    this.address,
    this.note,
    this.deliveryType,
    this.amountKurus,
    this.createdAt,
    this.cargoCompany,
    this.trackingNumber,
    this.paymentLabel,
  });

  /// BLD'deki satır kimliği — ack bununla gönderilir.
  final int id;

  /// BBD'nin kendi kimliği — tekilleştirmenin dayanağı.
  final String externalId;

  final String orderNumber;
  final List<BbdOrderItem> items;
  final String? customerLabel;
  final String? customerPhone;

  /// Serbest metin adres — BLD'nin yapılandırılmış modeli DEĞİL.
  final String? address;

  final String? note;

  /// `delivery` (kargo) / `pickup` (mağazadan teslim).
  ///
  /// Kitap satışında `delivery` **kargo** demek, kurye değil.
  final String? deliveryType;

  final int? amountKurus;
  final DateTime? createdAt;

  /// Kargo firması — paketleyen kişi doğru poşeti seçsin diye.
  final String? cargoCompany;

  /// Kargo takip numarası.
  final String? trackingNumber;

  /// "Ödendi (kredi kartı)" / "Kapıda ödeme" gibi serbest metin.
  final String? paymentLabel;

  factory BbdOrder.fromJson(Map<String, Object?> json) {
    final payload = json['payload'];
    final data = payload is Map
        ? Map<String, Object?>.from(payload)
        : const <String, Object?>{};

    return BbdOrder(
      id: (json['id'] as num).toInt(),
      externalId: '${json['external_id']}',
      orderNumber: '${data['order_number'] ?? json['external_id']}',
      items: (data['items'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => BbdOrderItem.fromJson(Map<String, Object?>.from(row)))
          .toList(growable: false),
      customerLabel: _stringOrNull(data['customer_label']),
      customerPhone: _stringOrNull(data['phone']),
      address: _stringOrNull(data['address']),
      note: _stringOrNull(data['note']),
      deliveryType: _stringOrNull(data['delivery_type']),
      amountKurus: (data['amount_kurus'] as num?)?.toInt(),
      createdAt: _dateOrNull(data['created_at']),
      cargoCompany: _stringOrNull(data['cargo_company']),
      trackingNumber: _stringOrNull(data['tracking_number']),
      paymentLabel: _stringOrNull(data['payment_label']),
    );
  }
}

/// Siparişteki tek kitap kalemi.
class BbdOrderItem {
  const BbdOrderItem({
    required this.name,
    required this.quantity,
    this.sku,
    this.attributes = const <String>[],
    this.note,
  });

  /// Kitap adı — uzun olabilir; fiş şablonu satıra sarıyor.
  final String name;

  final int quantity;

  /// Stok kodu / ISBN — raftan bulmanın en hızlı yolu.
  final String? sku;

  /// Yazar, cilt, baskı gibi ek nitelikler.
  final List<String> attributes;

  final String? note;

  factory BbdOrderItem.fromJson(Map<String, Object?> json) => BbdOrderItem(
    name: '${json['name']}',
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    sku: _stringOrNull(json['sku']),
    attributes: (json['attributes'] as List? ?? const [])
        .map((attribute) => '$attribute')
        .toList(growable: false),
    note: _stringOrNull(json['note']),
  );
}

abstract interface class BbdApi {
  /// Basılmayı bekleyen fişler.
  Future<List<BbdOrder>> pending();

  /// Fiş basıldı — kuyruktan düşer.
  Future<void> ack(int receiptId);
}

class HttpBbdApi implements BbdApi {
  HttpBbdApi({
    required this.baseUrl,
    required this.appId,
    required this.appVersion,
    required Future<String?> Function() readToken,
    HttpClient? client,
    this.timeout = const Duration(seconds: 10),
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
  Future<List<BbdOrder>> pending() async {
    final json = await _send('GET', 'kitchen/bbd-orders');
    final data = json['data'];
    if (data is! List) return const [];

    return data
        .whereType<Map>()
        .map((row) => BbdOrder.fromJson(Map<String, Object?>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<void> ack(int receiptId) async {
    await _send('POST', 'kitchen/bbd-orders/$receiptId/ack');
  }

  Future<Map<String, Object?>> _send(String method, String path) async {
    final uri = Uri.parse('$baseUrl/$path');

    try {
      final request = await _client.openUrl(method, uri).timeout(timeout);
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

      // `ack` 204 döner: gövde yok ve bu bir hata değil.
      return decoded is Map ? Map<String, Object?>.from(decoded) : const {};
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

DateTime? _dateOrNull(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value)?.toUtc();
}
