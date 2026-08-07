// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SubscriptionLine _$SubscriptionLineFromJson(Map<String, dynamic> json) =>
    _SubscriptionLine(
      menuId: (json['menu_id'] as num?)?.toInt(),
      quantity: (json['quantity'] as num).toInt(),
      agreedUnitPrice: (json['agreed_unit_price'] as num?)?.toInt(),
      label: json['label'] as String?,
    );

Map<String, dynamic> _$SubscriptionLineToJson(_SubscriptionLine instance) =>
    <String, dynamic>{
      'menu_id': ?instance.menuId,
      'quantity': instance.quantity,
      'agreed_unit_price': ?instance.agreedUnitPrice,
      'label': ?instance.label,
    };

_SubscriptionDeliveryPoint _$SubscriptionDeliveryPointFromJson(
  Map<String, dynamic> json,
) => _SubscriptionDeliveryPoint(
  id: (json['id'] as num).toInt(),
  addressId: (json['address_id'] as num).toInt(),
  quantity: (json['quantity'] as num?)?.toInt(),
  note: json['note'] as String?,
);

Map<String, dynamic> _$SubscriptionDeliveryPointToJson(
  _SubscriptionDeliveryPoint instance,
) => <String, dynamic>{
  'id': instance.id,
  'address_id': instance.addressId,
  'quantity': ?instance.quantity,
  'note': ?instance.note,
};

_Subscription _$SubscriptionFromJson(Map<String, dynamic> json) =>
    _Subscription(
      id: (json['id'] as num).toInt(),
      status: json['status'] as String,
      locationId: (json['location_id'] as num).toInt(),
      deliveryType: const DeliveryTypeConverter().fromJson(
        json['delivery_type'] as String,
      ),
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] == null
          ? null
          : DateTime.parse(json['end_date'] as String),
      serviceDays:
          (json['service_days'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const <int>[],
      deliveryTimeFrom: json['delivery_time_from'] as String?,
      deliveryTimeTo: json['delivery_time_to'] as String?,
      defaultQuantity: (json['default_quantity'] as num).toInt(),
      agreedUnitPrice: (json['agreed_unit_price'] as num?)?.toInt(),
      paymentMode: json['payment_mode'] as String,
      menuMode: json['menu_mode'] as String,
      lines:
          (json['lines'] as List<dynamic>?)
              ?.map((e) => SubscriptionLine.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <SubscriptionLine>[],
      deliveryPoints:
          (json['delivery_points'] as List<dynamic>?)
              ?.map(
                (e) => SubscriptionDeliveryPoint.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList() ??
          const <SubscriptionDeliveryPoint>[],
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$SubscriptionToJson(
  _Subscription instance,
) => <String, dynamic>{
  'id': instance.id,
  'status': instance.status,
  'location_id': instance.locationId,
  'delivery_type': const DeliveryTypeConverter().toJson(instance.deliveryType),
  'start_date': instance.startDate.toIso8601String(),
  'end_date': ?instance.endDate?.toIso8601String(),
  'service_days': instance.serviceDays,
  'delivery_time_from': ?instance.deliveryTimeFrom,
  'delivery_time_to': ?instance.deliveryTimeTo,
  'default_quantity': instance.defaultQuantity,
  'agreed_unit_price': ?instance.agreedUnitPrice,
  'payment_mode': instance.paymentMode,
  'menu_mode': instance.menuMode,
  'lines': instance.lines.map((e) => e.toJson()).toList(),
  'delivery_points': instance.deliveryPoints.map((e) => e.toJson()).toList(),
  'created_at': instance.createdAt.toIso8601String(),
};

_SubscriptionCreateItem _$SubscriptionCreateItemFromJson(
  Map<String, dynamic> json,
) => _SubscriptionCreateItem(
  menuId: (json['menu_id'] as num).toInt(),
  quantity: (json['quantity'] as num).toInt(),
  label: json['label'] as String?,
);

Map<String, dynamic> _$SubscriptionCreateItemToJson(
  _SubscriptionCreateItem instance,
) => <String, dynamic>{
  'menu_id': instance.menuId,
  'quantity': instance.quantity,
  'label': ?instance.label,
};

_SubscriptionCreatePoint _$SubscriptionCreatePointFromJson(
  Map<String, dynamic> json,
) => _SubscriptionCreatePoint(
  addressId: (json['address_id'] as num).toInt(),
  quantity: (json['quantity'] as num?)?.toInt(),
  note: json['note'] as String?,
);

Map<String, dynamic> _$SubscriptionCreatePointToJson(
  _SubscriptionCreatePoint instance,
) => <String, dynamic>{
  'address_id': instance.addressId,
  'quantity': ?instance.quantity,
  'note': ?instance.note,
};

_SubscriptionCreateRequest _$SubscriptionCreateRequestFromJson(
  Map<String, dynamic> json,
) => _SubscriptionCreateRequest(
  locationId: (json['location_id'] as num).toInt(),
  deliveryType: const DeliveryTypeConverter().fromJson(
    json['delivery_type'] as String,
  ),
  startDate: json['start_date'] as String,
  endDate: json['end_date'] as String?,
  serviceDays: (json['service_days'] as List<dynamic>)
      .map((e) => (e as num).toInt())
      .toList(),
  defaultQuantity: (json['default_quantity'] as num).toInt(),
  deliveryTimeFrom: json['delivery_time_from'] as String?,
  deliveryTimeTo: json['delivery_time_to'] as String?,
  lines:
      (json['lines'] as List<dynamic>?)
          ?.map(
            (e) => SubscriptionCreateItem.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const <SubscriptionCreateItem>[],
  deliveryPoints:
      (json['delivery_points'] as List<dynamic>?)
          ?.map(
            (e) => SubscriptionCreatePoint.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const <SubscriptionCreatePoint>[],
  customerNote: json['customer_note'] as String?,
);

Map<String, dynamic> _$SubscriptionCreateRequestToJson(
  _SubscriptionCreateRequest instance,
) => <String, dynamic>{
  'location_id': instance.locationId,
  'delivery_type': const DeliveryTypeConverter().toJson(instance.deliveryType),
  'start_date': instance.startDate,
  'end_date': ?instance.endDate,
  'service_days': instance.serviceDays,
  'default_quantity': instance.defaultQuantity,
  'delivery_time_from': ?instance.deliveryTimeFrom,
  'delivery_time_to': ?instance.deliveryTimeTo,
  'lines': instance.lines.map((e) => e.toJson()).toList(),
  'delivery_points': instance.deliveryPoints.map((e) => e.toJson()).toList(),
  'customer_note': ?instance.customerNote,
};

_SubscriptionExceptionRequest _$SubscriptionExceptionRequestFromJson(
  Map<String, dynamic> json,
) => _SubscriptionExceptionRequest(
  serviceDate: json['service_date'] as String,
  skip: json['skip'] as bool?,
  quantityOverride: (json['quantity_override'] as num?)?.toInt(),
);

Map<String, dynamic> _$SubscriptionExceptionRequestToJson(
  _SubscriptionExceptionRequest instance,
) => <String, dynamic>{
  'service_date': instance.serviceDate,
  'skip': ?instance.skip,
  'quantity_override': ?instance.quantityOverride,
};
