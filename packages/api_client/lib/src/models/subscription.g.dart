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

_SubscriptionException _$SubscriptionExceptionFromJson(
  Map<String, dynamic> json,
) => _SubscriptionException(
  serviceDate: json['service_date'] as String,
  skip: json['skip'] as bool,
  quantityOverride: (json['quantity_override'] as num?)?.toInt(),
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$SubscriptionExceptionToJson(
  _SubscriptionException instance,
) => <String, dynamic>{
  'service_date': instance.serviceDate,
  'skip': instance.skip,
  'quantity_override': ?instance.quantityOverride,
  'created_at': ?instance.createdAt?.toIso8601String(),
};

_SubscriptionPaymentSummary _$SubscriptionPaymentSummaryFromJson(
  Map<String, dynamic> json,
) => _SubscriptionPaymentSummary(
  period: json['period'] as String,
  amount: (json['amount'] as num).toInt(),
  currency: json['currency'] as String,
  status: const PaymentStatusConverter().fromJson(json['status'] as String),
  paymentId: (json['payment_id'] as num?)?.toInt(),
  dueDate: json['due_date'] as String?,
);

Map<String, dynamic> _$SubscriptionPaymentSummaryToJson(
  _SubscriptionPaymentSummary instance,
) => <String, dynamic>{
  'period': instance.period,
  'amount': instance.amount,
  'currency': instance.currency,
  'status': const PaymentStatusConverter().toJson(instance.status),
  'payment_id': ?instance.paymentId,
  'due_date': ?instance.dueDate,
};

_SubscriptionContractSummary _$SubscriptionContractSummaryFromJson(
  Map<String, dynamic> json,
) => _SubscriptionContractSummary(
  status: json['status'] as String,
  version: (json['version'] as num?)?.toInt(),
  sentAt: json['sent_at'] == null
      ? null
      : DateTime.parse(json['sent_at'] as String),
  approvedAt: json['approved_at'] == null
      ? null
      : DateTime.parse(json['approved_at'] as String),
);

Map<String, dynamic> _$SubscriptionContractSummaryToJson(
  _SubscriptionContractSummary instance,
) => <String, dynamic>{
  'status': instance.status,
  'version': ?instance.version,
  'sent_at': ?instance.sentAt?.toIso8601String(),
  'approved_at': ?instance.approvedAt?.toIso8601String(),
};

_SubscriptionContract _$SubscriptionContractFromJson(
  Map<String, dynamic> json,
) => _SubscriptionContract(
  status: json['status'] as String,
  version: (json['version'] as num).toInt(),
  body: json['body'] as String,
  bodyFormat: json['body_format'] as String,
  serviceDays:
      (json['service_days'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const <int>[],
  unitPrice: (json['unit_price'] as num).toInt(),
  currency: json['currency'] as String,
  title: json['title'] as String?,
  customerLabel: json['customer_label'] as String?,
  maskedPhone: json['masked_phone'] as String?,
  startDate: json['start_date'] as String?,
  endDate: json['end_date'] as String?,
  defaultQuantity: (json['default_quantity'] as num?)?.toInt(),
  monthlyEstimate: (json['monthly_estimate'] as num?)?.toInt(),
  expiresAt: json['expires_at'] == null
      ? null
      : DateTime.parse(json['expires_at'] as String),
  approvedAt: json['approved_at'] == null
      ? null
      : DateTime.parse(json['approved_at'] as String),
);

Map<String, dynamic> _$SubscriptionContractToJson(
  _SubscriptionContract instance,
) => <String, dynamic>{
  'status': instance.status,
  'version': instance.version,
  'body': instance.body,
  'body_format': instance.bodyFormat,
  'service_days': instance.serviceDays,
  'unit_price': instance.unitPrice,
  'currency': instance.currency,
  'title': ?instance.title,
  'customer_label': ?instance.customerLabel,
  'masked_phone': ?instance.maskedPhone,
  'start_date': ?instance.startDate,
  'end_date': ?instance.endDate,
  'default_quantity': ?instance.defaultQuantity,
  'monthly_estimate': ?instance.monthlyEstimate,
  'expires_at': ?instance.expiresAt?.toIso8601String(),
  'approved_at': ?instance.approvedAt?.toIso8601String(),
};

_SubscriptionPayment _$SubscriptionPaymentFromJson(Map<String, dynamic> json) =>
    _SubscriptionPayment(
      paymentId: (json['payment_id'] as num).toInt(),
      subscriptionId: (json['subscription_id'] as num).toInt(),
      period: json['period'] as String,
      amount: (json['amount'] as num).toInt(),
      currency: json['currency'] as String,
      status: const PaymentStatusConverter().fromJson(json['status'] as String),
      nextAction: json['next_action'] == null
          ? PaymentNextAction.none
          : const PaymentNextActionConverter().fromJson(
              json['next_action'] as String?,
            ),
      createdAt: DateTime.parse(json['created_at'] as String),
      redirectUrl: json['redirect_url'] as String?,
      failureReason: json['failure_reason'] as String?,
      paidAt: json['paid_at'] == null
          ? null
          : DateTime.parse(json['paid_at'] as String),
    );

Map<String, dynamic> _$SubscriptionPaymentToJson(
  _SubscriptionPayment instance,
) => <String, dynamic>{
  'payment_id': instance.paymentId,
  'subscription_id': instance.subscriptionId,
  'period': instance.period,
  'amount': instance.amount,
  'currency': instance.currency,
  'status': const PaymentStatusConverter().toJson(instance.status),
  'next_action': ?const PaymentNextActionConverter().toJson(
    instance.nextAction,
  ),
  'created_at': instance.createdAt.toIso8601String(),
  'redirect_url': ?instance.redirectUrl,
  'failure_reason': ?instance.failureReason,
  'paid_at': ?instance.paidAt?.toIso8601String(),
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
      exceptions:
          (json['exceptions'] as List<dynamic>?)
              ?.map(
                (e) =>
                    SubscriptionException.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const <SubscriptionException>[],
      payment: json['payment'] == null
          ? null
          : SubscriptionPaymentSummary.fromJson(
              json['payment'] as Map<String, dynamic>,
            ),
      contract: json['contract'] == null
          ? null
          : SubscriptionContractSummary.fromJson(
              json['contract'] as Map<String, dynamic>,
            ),
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
  'exceptions': instance.exceptions.map((e) => e.toJson()).toList(),
  'payment': ?instance.payment?.toJson(),
  'contract': ?instance.contract?.toJson(),
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
