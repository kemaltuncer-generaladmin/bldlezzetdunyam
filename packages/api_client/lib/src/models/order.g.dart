// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Address _$AddressFromJson(Map<String, dynamic> json) => _Address(
  line1: json['line1'] as String,
  district: json['district'] as String,
  city: json['city'] as String,
  neighbourhood: json['neighbourhood'] as String?,
  street: json['street'] as String?,
  buildingNo: json['building_no'] as String?,
  floor: json['floor'] as String?,
  doorNo: json['door_no'] as String?,
  note: json['note'] as String?,
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
);

Map<String, dynamic> _$AddressToJson(_Address instance) => <String, dynamic>{
  'line1': instance.line1,
  'district': instance.district,
  'city': instance.city,
  'neighbourhood': ?instance.neighbourhood,
  'street': ?instance.street,
  'building_no': ?instance.buildingNo,
  'floor': ?instance.floor,
  'door_no': ?instance.doorNo,
  'note': ?instance.note,
  'latitude': ?instance.latitude,
  'longitude': ?instance.longitude,
};

_SavedAddress _$SavedAddressFromJson(Map<String, dynamic> json) =>
    _SavedAddress(
      id: (json['id'] as num).toInt(),
      line1: json['line1'] as String,
      district: json['district'] as String,
      city: json['city'] as String,
      isDefault: json['is_default'] as bool,
      label: json['label'] as String?,
      neighbourhood: json['neighbourhood'] as String?,
      street: json['street'] as String?,
      buildingNo: json['building_no'] as String?,
      floor: json['floor'] as String?,
      doorNo: json['door_no'] as String?,
      note: json['note'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$SavedAddressToJson(_SavedAddress instance) =>
    <String, dynamic>{
      'id': instance.id,
      'line1': instance.line1,
      'district': instance.district,
      'city': instance.city,
      'is_default': instance.isDefault,
      'label': ?instance.label,
      'neighbourhood': ?instance.neighbourhood,
      'street': ?instance.street,
      'building_no': ?instance.buildingNo,
      'floor': ?instance.floor,
      'door_no': ?instance.doorNo,
      'note': ?instance.note,
      'latitude': ?instance.latitude,
      'longitude': ?instance.longitude,
    };

_SavedAddressInput _$SavedAddressInputFromJson(Map<String, dynamic> json) =>
    _SavedAddressInput(
      line1: json['line1'] as String,
      district: json['district'] as String,
      city: json['city'] as String,
      label: json['label'] as String?,
      note: json['note'] as String?,
      isDefault: json['is_default'] as bool?,
      neighbourhood: json['neighbourhood'] as String?,
      street: json['street'] as String?,
      buildingNo: json['building_no'] as String?,
      floor: json['floor'] as String?,
      doorNo: json['door_no'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$SavedAddressInputToJson(_SavedAddressInput instance) =>
    <String, dynamic>{
      'line1': instance.line1,
      'district': instance.district,
      'city': instance.city,
      'label': ?instance.label,
      'note': ?instance.note,
      'is_default': ?instance.isDefault,
      'neighbourhood': instance.neighbourhood,
      'street': instance.street,
      'building_no': instance.buildingNo,
      'floor': instance.floor,
      'door_no': instance.doorNo,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
    };

_AddressSuggestion _$AddressSuggestionFromJson(Map<String, dynamic> json) =>
    _AddressSuggestion(
      label: json['label'] as String,
      line1: json['line1'] as String,
      district: json['district'] as String,
      city: json['city'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      source: json['source'] as String,
      neighbourhood: json['neighbourhood'] as String?,
      street: json['street'] as String?,
    );

Map<String, dynamic> _$AddressSuggestionToJson(_AddressSuggestion instance) =>
    <String, dynamic>{
      'label': instance.label,
      'line1': instance.line1,
      'district': instance.district,
      'city': instance.city,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'source': instance.source,
      'neighbourhood': ?instance.neighbourhood,
      'street': ?instance.street,
    };

_OrderCreateItem _$OrderCreateItemFromJson(Map<String, dynamic> json) =>
    _OrderCreateItem(
      menuId: (json['menu_id'] as num).toInt(),
      quantity: (json['quantity'] as num).toInt(),
      optionValueIds:
          (json['option_value_ids'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const <int>[],
      note: json['note'] as String?,
    );

Map<String, dynamic> _$OrderCreateItemToJson(_OrderCreateItem instance) =>
    <String, dynamic>{
      'menu_id': instance.menuId,
      'quantity': instance.quantity,
      'option_value_ids': instance.optionValueIds,
      'note': ?instance.note,
    };

_OrderCreateRequest _$OrderCreateRequestFromJson(Map<String, dynamic> json) =>
    _OrderCreateRequest(
      locationId: (json['location_id'] as num).toInt(),
      items: (json['items'] as List<dynamic>)
          .map((e) => OrderCreateItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      deliveryType: const DeliveryTypeConverter().fromJson(
        json['delivery_type'] as String,
      ),
      paymentMethod: const PaymentMethodConverter().fromJson(
        json['payment_method'] as String,
      ),
      address: json['address'] == null
          ? null
          : Address.fromJson(json['address'] as Map<String, dynamic>),
      serviceDate: json['service_date'] as String?,
      requestedAt: json['requested_at'] == null
          ? null
          : DateTime.parse(json['requested_at'] as String),
      customerNote: json['customer_note'] as String?,
    );

Map<String, dynamic> _$OrderCreateRequestToJson(
  _OrderCreateRequest instance,
) => <String, dynamic>{
  'location_id': instance.locationId,
  'items': instance.items.map((e) => e.toJson()).toList(),
  'delivery_type': const DeliveryTypeConverter().toJson(instance.deliveryType),
  'payment_method': const PaymentMethodConverter().toJson(
    instance.paymentMethod,
  ),
  'address': ?instance.address?.toJson(),
  'service_date': ?instance.serviceDate,
  'requested_at': ?instance.requestedAt?.toIso8601String(),
  'customer_note': ?instance.customerNote,
};

_Payment _$PaymentFromJson(Map<String, dynamic> json) => _Payment(
  method: const PaymentMethodConverter().fromJson(json['method'] as String),
  status: const PaymentStatusConverter().fromJson(json['status'] as String),
  redirectUrl: json['redirect_url'] as String?,
);

Map<String, dynamic> _$PaymentToJson(_Payment instance) => <String, dynamic>{
  'method': const PaymentMethodConverter().toJson(instance.method),
  'status': const PaymentStatusConverter().toJson(instance.status),
  'redirect_url': ?instance.redirectUrl,
};

_OrderCreated _$OrderCreatedFromJson(Map<String, dynamic> json) =>
    _OrderCreated(
      id: (json['id'] as num).toInt(),
      orderNumber: json['order_number'] as String,
      status: const OrderStatusConverter().fromJson(json['status'] as String),
      total: (json['total'] as num).toInt(),
      currency: json['currency'] as String,
      payment: Payment.fromJson(json['payment'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$OrderCreatedToJson(_OrderCreated instance) =>
    <String, dynamic>{
      'id': instance.id,
      'order_number': instance.orderNumber,
      'status': const OrderStatusConverter().toJson(instance.status),
      'total': instance.total,
      'currency': instance.currency,
      'payment': instance.payment.toJson(),
      'created_at': instance.createdAt.toIso8601String(),
    };

_OrderSummary _$OrderSummaryFromJson(Map<String, dynamic> json) =>
    _OrderSummary(
      id: (json['id'] as num).toInt(),
      orderNumber: json['order_number'] as String,
      status: const OrderStatusConverter().fromJson(json['status'] as String),
      total: (json['total'] as num).toInt(),
      currency: json['currency'] as String,
      itemCount: (json['item_count'] as num).toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
      serviceDate: json['service_date'] as String?,
      subscriptionId: (json['subscription_id'] as num?)?.toInt(),
    );

Map<String, dynamic> _$OrderSummaryToJson(_OrderSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'order_number': instance.orderNumber,
      'status': const OrderStatusConverter().toJson(instance.status),
      'total': instance.total,
      'currency': instance.currency,
      'item_count': instance.itemCount,
      'created_at': instance.createdAt.toIso8601String(),
      'service_date': ?instance.serviceDate,
      'subscription_id': ?instance.subscriptionId,
    };

_OrderItem _$OrderItemFromJson(Map<String, dynamic> json) => _OrderItem(
  menuId: (json['menu_id'] as num).toInt(),
  name: json['name'] as String,
  quantity: (json['quantity'] as num).toInt(),
  unitPrice: (json['unit_price'] as num).toInt(),
  lineTotal: (json['line_total'] as num).toInt(),
  options:
      (json['options'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  note: json['note'] as String?,
  role: json['role'] as String? ?? 'item',
  includedIn: (json['included_in'] as num?)?.toInt(),
  dailyMenuId: (json['daily_menu_id'] as num?)?.toInt(),
);

Map<String, dynamic> _$OrderItemToJson(_OrderItem instance) =>
    <String, dynamic>{
      'menu_id': instance.menuId,
      'name': instance.name,
      'quantity': instance.quantity,
      'unit_price': instance.unitPrice,
      'line_total': instance.lineTotal,
      'options': instance.options,
      'note': ?instance.note,
      'role': instance.role,
      'included_in': ?instance.includedIn,
      'daily_menu_id': ?instance.dailyMenuId,
    };

_StatusHistoryEntry _$StatusHistoryEntryFromJson(Map<String, dynamic> json) =>
    _StatusHistoryEntry(
      status: const OrderStatusConverter().fromJson(json['status'] as String),
      at: DateTime.parse(json['at'] as String),
    );

Map<String, dynamic> _$StatusHistoryEntryToJson(_StatusHistoryEntry instance) =>
    <String, dynamic>{
      'status': const OrderStatusConverter().toJson(instance.status),
      'at': instance.at.toIso8601String(),
    };

_OrderDetail _$OrderDetailFromJson(Map<String, dynamic> json) => _OrderDetail(
  id: (json['id'] as num).toInt(),
  orderNumber: json['order_number'] as String,
  status: const OrderStatusConverter().fromJson(json['status'] as String),
  items: (json['items'] as List<dynamic>)
      .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  subtotal: (json['subtotal'] as num).toInt(),
  deliveryFee: (json['delivery_fee'] as num).toInt(),
  total: (json['total'] as num).toInt(),
  currency: json['currency'] as String,
  deliveryType: const DeliveryTypeConverter().fromJson(
    json['delivery_type'] as String,
  ),
  payment: Payment.fromJson(json['payment'] as Map<String, dynamic>),
  statusHistory: (json['status_history'] as List<dynamic>)
      .map((e) => StatusHistoryEntry.fromJson(e as Map<String, dynamic>))
      .toList(),
  createdAt: DateTime.parse(json['created_at'] as String),
  address: json['address'] == null
      ? null
      : Address.fromJson(json['address'] as Map<String, dynamic>),
  requestedAt: json['requested_at'] == null
      ? null
      : DateTime.parse(json['requested_at'] as String),
  serviceDate: json['service_date'] as String?,
  customerNote: json['customer_note'] as String?,
  subscriptionId: (json['subscription_id'] as num?)?.toInt(),
);

Map<String, dynamic> _$OrderDetailToJson(
  _OrderDetail instance,
) => <String, dynamic>{
  'id': instance.id,
  'order_number': instance.orderNumber,
  'status': const OrderStatusConverter().toJson(instance.status),
  'items': instance.items.map((e) => e.toJson()).toList(),
  'subtotal': instance.subtotal,
  'delivery_fee': instance.deliveryFee,
  'total': instance.total,
  'currency': instance.currency,
  'delivery_type': const DeliveryTypeConverter().toJson(instance.deliveryType),
  'payment': instance.payment.toJson(),
  'status_history': instance.statusHistory.map((e) => e.toJson()).toList(),
  'created_at': instance.createdAt.toIso8601String(),
  'address': ?instance.address?.toJson(),
  'requested_at': ?instance.requestedAt?.toIso8601String(),
  'service_date': ?instance.serviceDate,
  'customer_note': ?instance.customerNote,
  'subscription_id': ?instance.subscriptionId,
};

_PaginationMeta _$PaginationMetaFromJson(Map<String, dynamic> json) =>
    _PaginationMeta(
      page: (json['page'] as num).toInt(),
      perPage: (json['per_page'] as num).toInt(),
      total: (json['total'] as num).toInt(),
      lastPage: (json['last_page'] as num).toInt(),
    );

Map<String, dynamic> _$PaginationMetaToJson(_PaginationMeta instance) =>
    <String, dynamic>{
      'page': instance.page,
      'per_page': instance.perPage,
      'total': instance.total,
      'last_page': instance.lastPage,
    };

_OrderPage _$OrderPageFromJson(Map<String, dynamic> json) => _OrderPage(
  data: (json['data'] as List<dynamic>)
      .map((e) => OrderSummary.fromJson(e as Map<String, dynamic>))
      .toList(),
  meta: PaginationMeta.fromJson(json['meta'] as Map<String, dynamic>),
);

Map<String, dynamic> _$OrderPageToJson(_OrderPage instance) =>
    <String, dynamic>{
      'data': instance.data.map((e) => e.toJson()).toList(),
      'meta': instance.meta.toJson(),
    };
