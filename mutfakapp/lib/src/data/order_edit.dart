/// Sipariş düzenleme istemcisi — `GET /kitchen/orders/{id}/editable`,
/// `POST /kitchen/orders/{id}/revisions`, `GET /kitchen/menu` (K-14).
///
/// > **NEDEN BURADA, `packages/api_client`'ta DEĞİL:** `kitchen_health.dart`
/// > ve `sales_control.dart` ile aynı gerekçe — uçlar sözleşmeye yeni
/// > eklendi ve `packages/` bu görevin kapsamı dışında. Uçlar
/// > `KitchenService`'e taşındığında bu dosyanın yalnızca [OrderEditApi]
/// > uygulaması değişir; ekran ve model sınıfları aynen kalır.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';

/// Düzenleme ekranının gördüğü sipariş — **fiyatsız** (ADR-08).
class EditableOrder {
  const EditableOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.deliveryType,
    required this.items,
    this.requestedAt,
    this.customerName,
    this.customerPhone,
    this.customerNote,
    this.revisionNo = 0,
    this.isSubscription = false,
  });

  final int id;
  final String orderNumber;
  final OrderStatus status;
  final DeliveryType deliveryType;
  final List<EditableItem> items;
  final DateTime? requestedAt;
  final String? customerName;
  final String? customerPhone;
  final String? customerNote;
  final int revisionNo;

  /// Abonelikten doğan sipariş.
  ///
  /// Düzenleme **yalnız o günü** etkiler; abonelik tanımı değişmez.
  /// Ekran bunu personele yazıyor — aksi hâlde "her gün 10 olsun" sanıp
  /// yanlış beklenti oluşuyor.
  final bool isSubscription;

  factory EditableOrder.fromJson(Map<String, Object?> json) => EditableOrder(
    id: (json['id'] as num).toInt(),
    orderNumber: '${json['order_number']}',
    status:
        OrderStatus.values
            .where((s) => s.wireName == json['status'])
            .firstOrNull ??
        OrderStatus.yeni,
    deliveryType: json['delivery_type'] == 'pickup'
        ? DeliveryType.pickup
        : DeliveryType.delivery,
    items: (json['items'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => EditableItem.fromJson(Map<String, Object?>.from(row)))
        .toList(growable: false),
    requestedAt: _dateOrNull(json['requested_at']),
    customerName: _stringOrNull(json['customer_name']),
    customerPhone: _stringOrNull(json['customer_phone']),
    customerNote: _stringOrNull(json['customer_note']),
    revisionNo: (json['revision_no'] as num?)?.toInt() ?? 0,
    isSubscription: json['is_subscription'] == true,
  );
}

/// Düzenlenebilir tek kalem.
class EditableItem {
  const EditableItem({
    required this.menuId,
    required this.name,
    required this.quantity,
    this.options = const <String>[],
    this.optionValueIds = const <int>[],
    this.note,
  });

  final int menuId;
  final String name;
  final int quantity;

  /// Seçeneklerin **adları** — personele gösterilen hâl ("Bol").
  final List<String> options;

  /// Aynı seçeneklerin **kimlikleri** — sunucuya geri gönderilen hâl.
  ///
  /// İki ayrı alan, çünkü satırda iki ayrı yerde duruyorlar:
  /// `order_menus.option_values` yalnız adları, `order_menu_options` ise
  /// kimlikleri tutuyor. Adı kimliğe geri çevirmek seçenek değil — aynı
  /// adı taşıyan iki değer ("Bol" iki ayrı grupta) yanlış eşleşirdi.
  final List<int> optionValueIds;

  final String? note;

  factory EditableItem.fromJson(Map<String, Object?> json) => EditableItem(
    menuId: (json['menu_id'] as num).toInt(),
    name: '${json['name']}',
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    options: (json['options'] as List? ?? const [])
        .map((option) => '$option')
        .toList(growable: false),
    optionValueIds: (json['option_value_ids'] as List? ?? const [])
        .whereType<num>()
        .map((id) => id.toInt())
        .toList(growable: false),
    note: _stringOrNull(json['note']),
  );

  EditableItem copyWith({int? quantity}) => EditableItem(
    menuId: menuId,
    name: name,
    quantity: quantity ?? this.quantity,
    options: options,
    // ADET DEĞİŞİNCE SEÇENEK DÜŞMEZ. Kayıp tam olarak burada
    // oluşuyordu: satır seçeneksiz geri gidiyor, sunucu onu seçeneksiz
    // yeniden fiyatlıyordu.
    optionValueIds: optionValueIds,
    note: note,
  );

  /// Sunucuya gönderilecek biçim.
  ///
  /// SEÇENEK KİMLİKLERİ AYNEN GERİ GÖNDERİLİR: personel seçeneğe
  /// dokunmadıysa sipariş seçeneğini korumalı. Sunucu kalemleri
  /// sil-yeniden yaz ile güncelliyor (`LineResolver::writeLines`), yani
  /// göndermediğimiz her seçenek **silinmiş** sayılıyor.
  ///
  /// BOŞ DİZİ İLE ALANIN HİÇ OLMAMASI AYRI ŞEYLER: alan yoksa "bu
  /// kalemin seçeneği yok" (menüden yeni eklenen ürün), boş dizi ise
  /// "seçenekleri boşalt" demek. Seçeneksiz kalemde alanı hiç
  /// göndermiyoruz — gövde bugünküyle birebir aynı kalıyor.
  Map<String, Object?> toRequest() => <String, Object?>{
    'menu_id': menuId,
    'quantity': quantity,
    if (optionValueIds.isNotEmpty) 'option_value_ids': optionValueIds,
    'note': ?note,
  };

  @override
  bool operator ==(Object other) =>
      other is EditableItem &&
      other.menuId == menuId &&
      other.quantity == quantity &&
      // Seçenek kimliği de farkın parçası: bir gün seçenek düzenlenebilir
      // olduğunda "hiçbir şey değişmedi" kontrolü onu görmeliydi.
      _sameIds(other.optionValueIds, optionValueIds) &&
      other.note == note;

  @override
  int get hashCode =>
      Object.hash(menuId, quantity, Object.hashAll(optionValueIds), note);

  static bool _sameIds(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Bir düzenlemenin sonucu.
class RevisionResult {
  const RevisionResult({
    required this.revisionNo,
    required this.refundKurus,
    required this.extraChargeKurus,
    this.summaryLines = const <String>[],
    this.settlementStatus,
    this.settlementMessage,
  });

  final int revisionNo;

  /// Müşteriye iade edilecek tutar (kuruş). İkisi de pozitif; hangisinin
  /// dolu olduğu yönü belirler.
  final int refundKurus;
  final int extraChargeKurus;

  final List<String> summaryLines;
  final String? settlementStatus;
  final String? settlementMessage;

  factory RevisionResult.fromJson(Map<String, Object?> json) {
    final settlement = json['settlement'];

    return RevisionResult(
      revisionNo: (json['revision_no'] as num?)?.toInt() ?? 0,
      refundKurus: (json['refund_kurus'] as num?)?.toInt() ?? 0,
      extraChargeKurus: (json['extra_charge_kurus'] as num?)?.toInt() ?? 0,
      summaryLines: (json['summary_lines'] as List? ?? const [])
          .map((line) => '$line')
          .toList(growable: false),
      settlementStatus: settlement is Map
          ? _stringOrNull(settlement['status'])
          : null,
      settlementMessage: settlement is Map
          ? _stringOrNull(settlement['message'])
          : null,
    );
  }
}

/// Düzenleme sebepleri.
///
/// SABİT LİSTE, serbest metin değil: sebep hem müşteriye gidiyor hem
/// raporlanıyor. Herkesin kendi cümlesini yazdığı bir alan, "neden
/// düzenleniyor" sorusunu cevaplanamaz kılar. "Diğer" yine de var —
/// listede olmayan bir durum her zaman çıkar.
enum RevisionReason {
  customerRequest('Müşteri talebi'),
  outOfStock('Malzeme yetmedi'),
  staffError('Personel hatası'),
  other('Diğer');

  const RevisionReason(this.label);

  final String label;
}

abstract interface class OrderEditApi {
  Future<EditableOrder> editable(int orderId);

  /// Ürün ekleme için menü — **fiyatsız**.
  Future<List<({int menuId, String name})>> menu();

  Future<RevisionResult> createRevision({
    required int orderId,
    required String reason,
    required List<EditableItem> items,
    String? note,
    DateTime? requestedAt,
    String? customerNote,
  });
}

/// `dart:io` tabanlı uygulama.
class HttpOrderEditApi implements OrderEditApi {
  HttpOrderEditApi({
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
  Future<EditableOrder> editable(int orderId) async {
    final json = await _send('GET', 'kitchen/orders/$orderId/editable');
    final data = json['data'];

    if (data is! Map) {
      throw const ApiException(
        code: ApiErrorCode.unknown,
        message: 'Sipariş görüntüsü alınamadı.',
      );
    }

    return EditableOrder.fromJson(Map<String, Object?>.from(data));
  }

  @override
  Future<List<({int menuId, String name})>> menu() async {
    final json = await _send('GET', 'kitchen/menu');
    final data = json['data'];
    if (data is! List) return const [];

    return data
        .whereType<Map>()
        .map(
          (row) => (
            menuId: (row['menu_id'] as num).toInt(),
            name: '${row['name']}',
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<RevisionResult> createRevision({
    required int orderId,
    required String reason,
    required List<EditableItem> items,
    String? note,
    DateTime? requestedAt,
    String? customerNote,
  }) async {
    final json = await _send(
      'POST',
      'kitchen/orders/$orderId/revisions',
      body: <String, Object?>{
        'reason': reason,
        'items': items.map((item) => item.toRequest()).toList(growable: false),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        if (requestedAt != null)
          'requested_at': requestedAt.toUtc().toIso8601String(),
        'customer_note': ?customerNote,
      },
    );

    final revision = json['revision'];
    if (revision is! Map) {
      throw const ApiException(
        code: ApiErrorCode.unknown,
        message: 'Sunucu revizyon sonucunu döndürmedi.',
      );
    }

    return RevisionResult.fromJson(Map<String, Object?>.from(revision));
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
        ..set('X-App-Id', appId)
        ..set('X-App-Version', appVersion)
        ..set('Accept-Language', 'tr');

      final token = await _readToken();
      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }

      if (body != null) request.write(jsonEncode(body));

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
