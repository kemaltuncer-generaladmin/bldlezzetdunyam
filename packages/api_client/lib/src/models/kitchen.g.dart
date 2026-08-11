// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kitchen.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PairRequest _$PairRequestFromJson(Map<String, dynamic> json) => _PairRequest(
  pairingCode: json['pairing_code'] as String,
  deviceName: json['device_name'] as String,
);

Map<String, dynamic> _$PairRequestToJson(_PairRequest instance) =>
    <String, dynamic>{
      'pairing_code': instance.pairingCode,
      'device_name': instance.deviceName,
    };

_PairResponse _$PairResponseFromJson(Map<String, dynamic> json) =>
    _PairResponse(
      deviceId: (json['device_id'] as num).toInt(),
      token: json['token'] as String,
      serverTime: DateTime.parse(json['server_time'] as String),
    );

Map<String, dynamic> _$PairResponseToJson(_PairResponse instance) =>
    <String, dynamic>{
      'device_id': instance.deviceId,
      'token': instance.token,
      'server_time': instance.serverTime.toIso8601String(),
    };

_KitchenOrderItem _$KitchenOrderItemFromJson(Map<String, dynamic> json) =>
    _KitchenOrderItem(
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toInt(),
      options:
          (json['options'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      note: json['note'] as String?,
    );

Map<String, dynamic> _$KitchenOrderItemToJson(_KitchenOrderItem instance) =>
    <String, dynamic>{
      'name': instance.name,
      'quantity': instance.quantity,
      'options': instance.options,
      'note': ?instance.note,
    };

_KitchenOrder _$KitchenOrderFromJson(Map<String, dynamic> json) =>
    _KitchenOrder(
      id: (json['id'] as num).toInt(),
      orderNumber: json['order_number'] as String,
      status: const OrderStatusConverter().fromJson(json['status'] as String),
      deliveryType: const DeliveryTypeConverter().fromJson(
        json['delivery_type'] as String,
      ),
      items: (json['items'] as List<dynamic>)
          .map((e) => KitchenOrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      requestedAt: json['requested_at'] == null
          ? null
          : DateTime.parse(json['requested_at'] as String),
      customerLabel: json['customer_label'] as String?,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      customerNote: json['customer_note'] as String?,
      revisionNo: (json['revision_no'] as num?)?.toInt() ?? 0,
      isSubscription: json['is_subscription'] as bool? ?? false,
    );

Map<String, dynamic> _$KitchenOrderToJson(
  _KitchenOrder instance,
) => <String, dynamic>{
  'id': instance.id,
  'order_number': instance.orderNumber,
  'status': const OrderStatusConverter().toJson(instance.status),
  'delivery_type': const DeliveryTypeConverter().toJson(instance.deliveryType),
  'items': instance.items.map((e) => e.toJson()).toList(),
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt.toIso8601String(),
  'requested_at': ?instance.requestedAt?.toIso8601String(),
  'customer_label': ?instance.customerLabel,
  'customer_name': ?instance.customerName,
  'customer_phone': ?instance.customerPhone,
  'customer_note': ?instance.customerNote,
  'revision_no': instance.revisionNo,
  'is_subscription': instance.isSubscription,
};

_KitchenOrderPage _$KitchenOrderPageFromJson(Map<String, dynamic> json) =>
    _KitchenOrderPage(
      data: (json['data'] as List<dynamic>)
          .map((e) => KitchenOrder.fromJson(e as Map<String, dynamic>))
          .toList(),
      serverTime: DateTime.parse(json['server_time'] as String),
      maxId: (json['max_id'] as num).toInt(),
    );

Map<String, dynamic> _$KitchenOrderPageToJson(_KitchenOrderPage instance) =>
    <String, dynamic>{
      'data': instance.data.map((e) => e.toJson()).toList(),
      'server_time': instance.serverTime.toIso8601String(),
      'max_id': instance.maxId,
    };

_KitchenSubscriptionOrders _$KitchenSubscriptionOrdersFromJson(
  Map<String, dynamic> json,
) => _KitchenSubscriptionOrders(
  today:
      (json['today'] as List<dynamic>?)
          ?.map((e) => KitchenOrder.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <KitchenOrder>[],
  tomorrow:
      (json['tomorrow'] as List<dynamic>?)
          ?.map((e) => KitchenOrder.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <KitchenOrder>[],
  serverTime: DateTime.parse(json['server_time'] as String),
);

Map<String, dynamic> _$KitchenSubscriptionOrdersToJson(
  _KitchenSubscriptionOrders instance,
) => <String, dynamic>{
  'today': instance.today.map((e) => e.toJson()).toList(),
  'tomorrow': instance.tomorrow.map((e) => e.toJson()).toList(),
  'server_time': instance.serverTime.toIso8601String(),
};

_ReceiptLine _$ReceiptLineFromJson(Map<String, dynamic> json) => _ReceiptLine(
  quantity: (json['quantity'] as num).toInt(),
  name: json['name'] as String,
  options:
      (json['options'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  note: json['note'] as String?,
);

Map<String, dynamic> _$ReceiptLineToJson(_ReceiptLine instance) =>
    <String, dynamic>{
      'quantity': instance.quantity,
      'name': instance.name,
      'options': instance.options,
      'note': ?instance.note,
    };

_KitchenReceipt _$KitchenReceiptFromJson(Map<String, dynamic> json) =>
    _KitchenReceipt(
      orderNumber: json['order_number'] as String,
      deliveryType: const DeliveryTypeConverter().fromJson(
        json['delivery_type'] as String,
      ),
      lines: (json['lines'] as List<dynamic>)
          .map((e) => ReceiptLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      type: json['type'] as String? ?? 'mutfak',
      requestedAt: json['requested_at'] == null
          ? null
          : DateTime.parse(json['requested_at'] as String),
      customerPhone: json['customer_phone'] as String?,
      customerNote: json['customer_note'] as String?,
      printedAt: json['printed_at'] == null
          ? null
          : DateTime.parse(json['printed_at'] as String),
    );

Map<String, dynamic> _$KitchenReceiptToJson(
  _KitchenReceipt instance,
) => <String, dynamic>{
  'order_number': instance.orderNumber,
  'delivery_type': const DeliveryTypeConverter().toJson(instance.deliveryType),
  'lines': instance.lines.map((e) => e.toJson()).toList(),
  'type': instance.type,
  'requested_at': ?instance.requestedAt?.toIso8601String(),
  'customer_phone': ?instance.customerPhone,
  'customer_note': ?instance.customerNote,
  'printed_at': ?instance.printedAt?.toIso8601String(),
};

_CustomerReceipt _$CustomerReceiptFromJson(Map<String, dynamic> json) =>
    _CustomerReceipt(
      orderNumber: json['order_number'] as String,
      deliveryType: const DeliveryTypeConverter().fromJson(
        json['delivery_type'] as String,
      ),
      items: (json['items'] as List<dynamic>)
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      subtotal: (json['subtotal'] as num).toInt(),
      deliveryFee: (json['delivery_fee'] as num).toInt(),
      total: (json['total'] as num).toInt(),
      currency: json['currency'] as String,
      payment: Payment.fromJson(json['payment'] as Map<String, dynamic>),
      type: json['type'] as String? ?? 'musteri',
      address: json['address'] == null
          ? null
          : Address.fromJson(json['address'] as Map<String, dynamic>),
      requestedAt: json['requested_at'] == null
          ? null
          : DateTime.parse(json['requested_at'] as String),
      customerLabel: json['customer_label'] as String?,
      printedAt: json['printed_at'] == null
          ? null
          : DateTime.parse(json['printed_at'] as String),
    );

Map<String, dynamic> _$CustomerReceiptToJson(
  _CustomerReceipt instance,
) => <String, dynamic>{
  'order_number': instance.orderNumber,
  'delivery_type': const DeliveryTypeConverter().toJson(instance.deliveryType),
  'items': instance.items.map((e) => e.toJson()).toList(),
  'subtotal': instance.subtotal,
  'delivery_fee': instance.deliveryFee,
  'total': instance.total,
  'currency': instance.currency,
  'payment': instance.payment.toJson(),
  'type': instance.type,
  'address': ?instance.address?.toJson(),
  'requested_at': ?instance.requestedAt?.toIso8601String(),
  'customer_label': ?instance.customerLabel,
  'printed_at': ?instance.printedAt?.toIso8601String(),
};

_CourierReceipt _$CourierReceiptFromJson(Map<String, dynamic> json) =>
    _CourierReceipt(
      orderNumber: json['order_number'] as String,
      deliveryType: const DeliveryTypeConverter().fromJson(
        json['delivery_type'] as String,
      ),
      items: (json['items'] as List<dynamic>)
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
      currency: json['currency'] as String,
      payment: Payment.fromJson(json['payment'] as Map<String, dynamic>),
      type: json['type'] as String? ?? 'kurye',
      address: json['address'] == null
          ? null
          : Address.fromJson(json['address'] as Map<String, dynamic>),
      requestedAt: json['requested_at'] == null
          ? null
          : DateTime.parse(json['requested_at'] as String),
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      customerNote: json['customer_note'] as String?,
      printedAt: json['printed_at'] == null
          ? null
          : DateTime.parse(json['printed_at'] as String),
      revisionNo: (json['revision_no'] as num?)?.toInt() ?? 0,
      revisionSummary:
          (json['revision_summary'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      collectAmount: (json['collect_amount'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$CourierReceiptToJson(
  _CourierReceipt instance,
) => <String, dynamic>{
  'order_number': instance.orderNumber,
  'delivery_type': const DeliveryTypeConverter().toJson(instance.deliveryType),
  'items': instance.items.map((e) => e.toJson()).toList(),
  'total': instance.total,
  'currency': instance.currency,
  'payment': instance.payment.toJson(),
  'type': instance.type,
  'address': ?instance.address?.toJson(),
  'requested_at': ?instance.requestedAt?.toIso8601String(),
  'customer_name': ?instance.customerName,
  'customer_phone': ?instance.customerPhone,
  'customer_note': ?instance.customerNote,
  'printed_at': ?instance.printedAt?.toIso8601String(),
  'revision_no': instance.revisionNo,
  'revision_summary': instance.revisionSummary,
  'collect_amount': instance.collectAmount,
};

_PrintAckRequest _$PrintAckRequestFromJson(Map<String, dynamic> json) =>
    _PrintAckRequest(
      type: const ReceiptTypeConverter().fromJson(json['type'] as String),
      printedAt: DateTime.parse(json['printed_at'] as String),
    );

Map<String, dynamic> _$PrintAckRequestToJson(_PrintAckRequest instance) =>
    <String, dynamic>{
      'type': const ReceiptTypeConverter().toJson(instance.type),
      'printed_at': instance.printedAt.toIso8601String(),
    };

_ProductionListItem _$ProductionListItemFromJson(Map<String, dynamic> json) =>
    _ProductionListItem(
      menuId: (json['menu_id'] as num).toInt(),
      name: json['name'] as String,
      total: (json['total'] as num).toInt(),
    );

Map<String, dynamic> _$ProductionListItemToJson(_ProductionListItem instance) =>
    <String, dynamic>{
      'menu_id': instance.menuId,
      'name': instance.name,
      'total': instance.total,
    };

_ProductionList _$ProductionListFromJson(Map<String, dynamic> json) =>
    _ProductionList(
      data: (json['data'] as List<dynamic>)
          .map((e) => ProductionListItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      asOf: DateTime.parse(json['as_of'] as String),
    );

Map<String, dynamic> _$ProductionListToJson(_ProductionList instance) =>
    <String, dynamic>{
      'data': instance.data.map((e) => e.toJson()).toList(),
      'as_of': instance.asOf.toIso8601String(),
    };

_HeartbeatResponse _$HeartbeatResponseFromJson(Map<String, dynamic> json) =>
    _HeartbeatResponse(
      serverTime: DateTime.parse(json['server_time'] as String),
      minSupportedVersion: json['min_supported_version'] as String,
    );

Map<String, dynamic> _$HeartbeatResponseToJson(_HeartbeatResponse instance) =>
    <String, dynamic>{
      'server_time': instance.serverTime.toIso8601String(),
      'min_supported_version': instance.minSupportedVersion,
    };

_BusyState _$BusyStateFromJson(Map<String, dynamic> json) => _BusyState(
  busy: json['busy'] as bool,
  busyMessage: json['busy_message'] as String,
  serverTime: DateTime.parse(json['server_time'] as String),
);

Map<String, dynamic> _$BusyStateToJson(_BusyState instance) =>
    <String, dynamic>{
      'busy': instance.busy,
      'busy_message': instance.busyMessage,
      'server_time': instance.serverTime.toIso8601String(),
    };

_AppVersionInfo _$AppVersionInfoFromJson(Map<String, dynamic> json) =>
    _AppVersionInfo(
      appId: json['app_id'] as String,
      latest: json['latest'] as String,
      minSupported: json['min_supported'] as String,
      downloadUrl: json['download_url'] as String?,
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$AppVersionInfoToJson(_AppVersionInfo instance) =>
    <String, dynamic>{
      'app_id': instance.appId,
      'latest': instance.latest,
      'min_supported': instance.minSupported,
      'download_url': ?instance.downloadUrl,
      'notes': ?instance.notes,
    };
