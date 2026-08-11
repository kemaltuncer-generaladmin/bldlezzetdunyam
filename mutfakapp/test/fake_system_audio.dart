/// Süreç açmayan [SystemAudio] — ekran testleri `wpctl`/`pactl`
/// çalıştırmasın.
///
/// Gerçek sınıf alt süreç açıyor ve sonucu test makinesinin ses kurulumuna
/// bağlı: geliştiricinin makinesinde geçen test, CI'da hoparlör olmadığı
/// için düşerdi.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:mutfakapp/src/data/bbd_source.dart';
import 'package:mutfakapp/src/data/order_edit.dart';
import 'package:mutfakapp/src/data/sales_control.dart';
import 'package:mutfakapp/src/sound/system_audio.dart';

class FakeSystemAudio implements SystemAudio {
  FakeSystemAudio({this.sinks = const [], this.volume = 50});

  final List<AudioSink> sinks;
  int? volume;

  /// Son ayarlanan seviye — testin doğrulaması için.
  int? lastSetVolume;

  @override
  Future<List<AudioSink>> listSinks() async => sinks;

  @override
  Future<int?> currentVolume() async => volume;

  @override
  Future<bool> setVolume(int percent) async {
    lastSetVolume = percent;
    volume = percent;
    return true;
  }
}

/// Ağa çıkmayan satış kontrolü — ekran testleri gerçek uca gitmesin.
class FakeSalesControlApi implements SalesControlApi {
  FakeSalesControlApi({this.enabled = true, this.items = const []});

  bool enabled;
  String? reason;
  DateTime? resumesAt;
  List<KitchenMenuItem> items;

  /// Son çağrılan `setOrdering` argümanları — testin doğrulaması için.
  ({bool enabled, String? reason, int? minutes})? lastOrderingCall;

  @override
  Future<OrderingState> ordering() async => _state();

  @override
  Future<OrderingState> setOrdering({
    required bool enabled,
    String? reason,
    int? minutes,
  }) async {
    lastOrderingCall = (enabled: enabled, reason: reason, minutes: minutes);
    this.enabled = enabled;
    this.reason = enabled ? null : reason;
    return _state();
  }

  @override
  Future<List<KitchenMenuItem>> menuAvailability() async => items;

  @override
  Future<List<KitchenMenuItem>> setMenuAvailability({
    required int menuId,
    required bool soldOut,
    String? reason,
  }) async {
    items = [
      for (final item in items)
        if (item.menuId == menuId)
          KitchenMenuItem(
            menuId: item.menuId,
            name: item.name,
            listed: item.listed,
            soldOut: soldOut,
            soldOutReason: reason,
          )
        else
          item,
    ];
    return items;
  }

  OrderingState _state() => OrderingState(
    enabled: enabled,
    reason: reason,
    resumesAt: resumesAt,
    serverTime: DateTime.utc(2026, 8, 11, 12),
  );
}

/// Ağa çıkmayan sipariş düzenleme ucu (K-14).
class FakeOrderEditApi implements OrderEditApi {
  FakeOrderEditApi({EditableOrder? order, this.menuItems = const []})
    : order =
          order ??
          const EditableOrder(
            id: 5012,
            orderNumber: 'S-5012',
            status: OrderStatus.onaylandi,
            deliveryType: DeliveryType.delivery,
            customerName: 'Ayşe Yılmaz',
            customerPhone: '0555 123 45 67',
            items: [
              EditableItem(menuId: 1, name: 'Mercimek Çorbası', quantity: 20),
              EditableItem(menuId: 2, name: 'Pilav', quantity: 3),
            ],
          );

  EditableOrder order;
  final List<({int menuId, String name})> menuItems;

  /// Son gönderilen revizyon — testin doğrulaması için.
  ({String reason, List<EditableItem> items})? lastRevision;

  /// `true` ise `createRevision` hata atar.
  bool failRevision = false;

  /// Sunucunun döndüreceği sonuç.
  RevisionResult result = const RevisionResult(
    revisionNo: 1,
    refundKurus: 18000,
    extraChargeKurus: 0,
    settlementStatus: 'succeeded',
  );

  @override
  Future<EditableOrder> editable(int orderId) async => order;

  @override
  Future<List<({int menuId, String name})>> menu() async => menuItems;

  @override
  Future<RevisionResult> createRevision({
    required int orderId,
    required String reason,
    required List<EditableItem> items,
    String? note,
    DateTime? requestedAt,
    String? customerNote,
  }) async {
    if (failRevision) {
      throw const ApiException(
        code: ApiErrorCode.unknown,
        message: 'sunucu hatası',
      );
    }

    lastRevision = (reason: reason, items: items);
    return result;
  }
}

/// Ağa çıkmayan BBD ucu (K-16).
class FakeBbdApi implements BbdApi {
  FakeBbdApi({this.orders = const []});

  List<BbdOrder> orders;

  /// Onaylanan fiş kimlikleri — testin doğrulaması için.
  final List<int> acked = [];

  /// `true` ise `pending()` hata atar.
  bool failPending = false;

  @override
  Future<List<BbdOrder>> pending() async {
    if (failPending) {
      throw const ApiException(
        code: ApiErrorCode.unknown,
        message: 'ağ yok',
      );
    }
    return orders;
  }

  @override
  Future<void> ack(int receiptId) async {
    acked.add(receiptId);
    orders = orders.where((o) => o.id != receiptId).toList(growable: false);
  }
}
