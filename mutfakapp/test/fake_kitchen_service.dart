/// Testler için sahte [KitchenService].
///
/// Gerçek HTTP yerine sıraya konan yanıtları döndürür ve yapılan çağrıları
/// kaydeder; `PollingOrderSource`'un ne zaman hangi parametreyle istek attığı
/// böylece doğrulanabilir.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';

/// `orders()` çağrısının parametreleri.
class OrdersCall {
  const OrdersCall({
    required this.after,
    required this.since,
    required this.includeCompleted,
  });

  final int? after;
  final DateTime? since;
  final bool includeCompleted;
}

class FakeKitchenService implements KitchenService {
  /// Sırayla döndürülecek yanıtlar. Tükenirse sonuncusu tekrarlanır.
  final List<Object> responses = <Object>[];

  final List<OrdersCall> ordersCalls = <OrdersCall>[];
  final List<(int, OrderStatus)> statusCalls = <(int, OrderStatus)>[];
  int heartbeatCount = 0;

  /// Sipariş kimliğine göre hazır fiş verisi. Eksikse çağrı `NOT_FOUND` atar.
  final Map<int, KitchenReceipt> kitchenReceipts = <int, KitchenReceipt>{};
  final Map<int, CustomerReceipt> customerReceipts = <int, CustomerReceipt>{};

  /// Kaç kez fiş verisi istendi — payload'ın bir kez çekildiğini doğrular.
  int receiptCalls = 0;

  final List<(int, ReceiptType)> ackCalls = <(int, ReceiptType)>[];

  /// `true` ise `ack` hata atar; fişin basılmış sayılması buna bağlı olmamalı.
  bool ackFails = false;

  @override
  Future<KitchenOrderPage> orders({
    int? after,
    DateTime? since,
    bool includeCompleted = false,
  }) async {
    ordersCalls.add(
      OrdersCall(
        after: after,
        since: since,
        includeCompleted: includeCompleted,
      ),
    );

    final index = ordersCalls.length - 1;
    if (responses.isEmpty) throw StateError('Sıraya yanıt konmadı');
    final response =
        responses[index < responses.length ? index : responses.length - 1];

    if (response is ApiException) throw response;
    return response as KitchenOrderPage;
  }

  @override
  Future<HeartbeatResponse> heartbeat() async {
    heartbeatCount++;
    return HeartbeatResponse(
      serverTime: DateTime.utc(2026, 8, 4),
      minSupportedVersion: '1.0.0',
    );
  }

  @override
  Future<KitchenOrder> setStatus(int orderId, OrderStatus status) async {
    statusCalls.add((orderId, status));
    throw UnsupportedError('Bu testte kullanılmıyor');
  }

  /// Yoğunluk şalterine yapılan çağrılar.
  final List<bool> busyCalls = [];

  bool busy = false;

  @override
  Future<BusyState> setBusy(bool value) async {
    busyCalls.add(value);
    busy = value;
    return BusyState(
      busy: value,
      busyMessage: 'Mutfağımız şu anda yoğun.',
      serverTime: DateTime.utc(2026, 8, 4),
    );
  }

  @override
  Future<PairResponse> pair(PairRequest request) =>
      throw UnsupportedError('Bu testte kullanılmıyor');

  @override
  Future<KitchenReceipt> kitchenReceipt(int orderId) async {
    receiptCalls++;
    final receipt = kitchenReceipts[orderId];
    if (receipt == null) throw _notFound(orderId);
    return receipt;
  }

  @override
  Future<CustomerReceipt> customerReceipt(int orderId) async {
    receiptCalls++;
    final receipt = customerReceipts[orderId];
    if (receipt == null) throw _notFound(orderId);
    return receipt;
  }

  @override
  Future<void> ackPrint(int orderId, PrintAckRequest request) async {
    if (ackFails) throw const ApiException.network();
    ackCalls.add((orderId, request.type));
  }

  static ApiException _notFound(int orderId) => ApiException(
    code: ApiErrorCode.notFound,
    message: 'Sipariş $orderId için fiş yok.',
    statusCode: 404,
  );

  @override
  Future<ProductionList> productionList() =>
      throw UnsupportedError('Bu testte kullanılmıyor');
}

/// Test verisi üreticisi.
KitchenOrder makeOrder({
  required int id,
  OrderStatus status = OrderStatus.yeni,
  DeliveryType deliveryType = DeliveryType.delivery,
  List<KitchenOrderItem> items = const [
    KitchenOrderItem(name: 'Tavuk Sote', quantity: 1),
  ],
  DateTime? createdAt,
  String? customerNote,
  DateTime? requestedAt,
}) => KitchenOrder(
  id: id,
  orderNumber: 'S-$id',
  status: status,
  deliveryType: deliveryType,
  items: items,
  createdAt: createdAt ?? DateTime.utc(2026, 8, 4, 10),
  updatedAt: createdAt ?? DateTime.utc(2026, 8, 4, 10),
  customerNote: customerNote,
  requestedAt: requestedAt,
);

KitchenOrderPage makePage(List<KitchenOrder> orders, {DateTime? serverTime}) =>
    KitchenOrderPage(
      data: orders,
      serverTime: serverTime ?? DateTime.utc(2026, 8, 4, 12),
      maxId: orders.isEmpty
          ? 0
          : orders.map((o) => o.id).reduce((a, b) => a > b ? a : b),
    );
