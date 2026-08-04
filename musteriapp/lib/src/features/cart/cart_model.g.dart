// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CartLine _$CartLineFromJson(Map<String, dynamic> json) => _CartLine(
  item: MenuItem.fromJson(json['item'] as Map<String, dynamic>),
  quantity: (json['quantity'] as num).toInt(),
  optionValueIds:
      (json['optionValueIds'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const <int>[],
  note: json['note'] as String?,
);

Map<String, dynamic> _$CartLineToJson(_CartLine instance) => <String, dynamic>{
  'item': instance.item,
  'quantity': instance.quantity,
  'optionValueIds': instance.optionValueIds,
  'note': instance.note,
};

_Cart _$CartFromJson(Map<String, dynamic> json) => _Cart(
  lines:
      (json['lines'] as List<dynamic>?)
          ?.map((e) => CartLine.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <CartLine>[],
  locationId: (json['locationId'] as num?)?.toInt(),
);

Map<String, dynamic> _$CartToJson(_Cart instance) => <String, dynamic>{
  'lines': instance.lines,
  'locationId': instance.locationId,
};
