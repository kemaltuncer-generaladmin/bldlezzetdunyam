// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EtaWindow _$EtaWindowFromJson(Map<String, dynamic> json) => _EtaWindow(
  minMinutes: (json['min_minutes'] as num).toInt(),
  maxMinutes: (json['max_minutes'] as num).toInt(),
  source: json['source'] == null
      ? EtaSource.unknown
      : const EtaSourceConverter().fromJson(json['source'] as String),
  busy: json['busy'] as bool? ?? false,
);

Map<String, dynamic> _$EtaWindowToJson(_EtaWindow instance) =>
    <String, dynamic>{
      'min_minutes': instance.minMinutes,
      'max_minutes': instance.maxMinutes,
      'source': const EtaSourceConverter().toJson(instance.source),
      'busy': instance.busy,
    };

_LocationEta _$LocationEtaFromJson(Map<String, dynamic> json) => _LocationEta(
  delivery: json['delivery'] == null
      ? null
      : EtaWindow.fromJson(json['delivery'] as Map<String, dynamic>),
  pickup: json['pickup'] == null
      ? null
      : EtaWindow.fromJson(json['pickup'] as Map<String, dynamic>),
);

Map<String, dynamic> _$LocationEtaToJson(_LocationEta instance) =>
    <String, dynamic>{
      'delivery': ?instance.delivery?.toJson(),
      'pickup': ?instance.pickup?.toJson(),
    };

_Location _$LocationFromJson(Map<String, dynamic> json) => _Location(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  slug: json['slug'] as String,
  isOpen: json['is_open'] as bool,
  orderingEnabled: json['ordering_enabled'] as bool,
  minOrderTotal: (json['min_order_total'] as num).toInt(),
  paymentMethods: (json['payment_methods'] as List<dynamic>)
      .map((e) => const PaymentMethodConverter().fromJson(e as String))
      .toList(),
  orderCutoff: json['order_cutoff'] as String?,
  eta: json['eta'] == null
      ? null
      : LocationEta.fromJson(json['eta'] as Map<String, dynamic>),
);

Map<String, dynamic> _$LocationToJson(_Location instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'slug': instance.slug,
  'is_open': instance.isOpen,
  'ordering_enabled': instance.orderingEnabled,
  'min_order_total': instance.minOrderTotal,
  'payment_methods': instance.paymentMethods
      .map(const PaymentMethodConverter().toJson)
      .toList(),
  'order_cutoff': ?instance.orderCutoff,
  'eta': ?instance.eta?.toJson(),
};

_MenuCategory _$MenuCategoryFromJson(Map<String, dynamic> json) =>
    _MenuCategory(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      sort: (json['sort'] as num).toInt(),
      items: (json['items'] as List<dynamic>)
          .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$MenuCategoryToJson(_MenuCategory instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'sort': instance.sort,
      'items': instance.items.map((e) => e.toJson()).toList(),
    };

_MenuItem _$MenuItemFromJson(Map<String, dynamic> json) => _MenuItem(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  price: (json['price'] as num).toInt(),
  currency: json['currency'] as String,
  isAvailable: json['is_available'] as bool,
  description: json['description'] as String?,
  imageUrl: json['image_url'] as String?,
  allergens:
      (json['allergens'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  options:
      (json['options'] as List<dynamic>?)
          ?.map((e) => MenuOption.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <MenuOption>[],
);

Map<String, dynamic> _$MenuItemToJson(_MenuItem instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'price': instance.price,
  'currency': instance.currency,
  'is_available': instance.isAvailable,
  'description': ?instance.description,
  'image_url': ?instance.imageUrl,
  'allergens': instance.allergens,
  'options': instance.options.map((e) => e.toJson()).toList(),
};

_MenuOption _$MenuOptionFromJson(Map<String, dynamic> json) => _MenuOption(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  type: json['type'] as String,
  required: json['required'] as bool,
  values: (json['values'] as List<dynamic>)
      .map((e) => MenuOptionValue.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$MenuOptionToJson(_MenuOption instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': instance.type,
      'required': instance.required,
      'values': instance.values.map((e) => e.toJson()).toList(),
    };

_MenuOptionValue _$MenuOptionValueFromJson(Map<String, dynamic> json) =>
    _MenuOptionValue(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      priceDelta: (json['price_delta'] as num).toInt(),
    );

Map<String, dynamic> _$MenuOptionValueToJson(_MenuOptionValue instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'price_delta': instance.priceDelta,
    };
