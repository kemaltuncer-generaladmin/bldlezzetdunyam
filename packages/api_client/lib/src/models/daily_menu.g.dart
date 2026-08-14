// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_menu.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DailyMenuPackageComponent _$DailyMenuPackageComponentFromJson(
  Map<String, dynamic> json,
) => _DailyMenuPackageComponent(
  menuId: (json['menu_id'] as num).toInt(),
  name: json['name'] as String,
  quantity: (json['quantity'] as num).toInt(),
  imageUrl: json['image_url'] as String?,
  allergens:
      (json['allergens'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
);

Map<String, dynamic> _$DailyMenuPackageComponentToJson(
  _DailyMenuPackageComponent instance,
) => <String, dynamic>{
  'menu_id': instance.menuId,
  'name': instance.name,
  'quantity': instance.quantity,
  'image_url': ?instance.imageUrl,
  'allergens': instance.allergens,
};

_DailyMenuPackage _$DailyMenuPackageFromJson(Map<String, dynamic> json) =>
    _DailyMenuPackage(
      menuId: (json['menu_id'] as num).toInt(),
      name: json['name'] as String,
      price: (json['price'] as num).toInt(),
      isAvailable: json['is_available'] as bool,
      soldOutReason: json['sold_out_reason'] as String?,
      components:
          (json['components'] as List<dynamic>?)
              ?.map(
                (e) => DailyMenuPackageComponent.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList() ??
          const <DailyMenuPackageComponent>[],
    );

Map<String, dynamic> _$DailyMenuPackageToJson(_DailyMenuPackage instance) =>
    <String, dynamic>{
      'menu_id': instance.menuId,
      'name': instance.name,
      'price': instance.price,
      'is_available': instance.isAvailable,
      'sold_out_reason': ?instance.soldOutReason,
      'components': instance.components.map((e) => e.toJson()).toList(),
    };

_DailyMenu _$DailyMenuFromJson(Map<String, dynamic> json) => _DailyMenu(
  date: json['date'] as String,
  currency: json['currency'] as String,
  closed: json['closed'] as bool,
  isOrderable: json['is_orderable'] as bool,
  id: (json['id'] as num?)?.toInt(),
  title: json['title'] as String?,
  description: json['description'] as String?,
  imageUrl: json['image_url'] as String?,
  package: json['package'] == null
      ? null
      : DailyMenuPackage.fromJson(json['package'] as Map<String, dynamic>),
  itemsTotal: (json['items_total'] as num?)?.toInt(),
  unavailableReason: json['unavailable_reason'] == null
      ? DailyMenuUnavailableReason.none
      : const DailyMenuUnavailableReasonConverter().fromJson(
          json['unavailable_reason'] as String?,
        ),
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <MenuItem>[],
);

Map<String, dynamic> _$DailyMenuToJson(_DailyMenu instance) =>
    <String, dynamic>{
      'date': instance.date,
      'currency': instance.currency,
      'closed': instance.closed,
      'is_orderable': instance.isOrderable,
      'id': ?instance.id,
      'title': ?instance.title,
      'description': ?instance.description,
      'image_url': ?instance.imageUrl,
      'package': ?instance.package?.toJson(),
      'items_total': ?instance.itemsTotal,
      'unavailable_reason': ?const DailyMenuUnavailableReasonConverter().toJson(
        instance.unavailableReason,
      ),
      'items': instance.items.map((e) => e.toJson()).toList(),
    };

_MenuCalendarDay _$MenuCalendarDayFromJson(Map<String, dynamic> json) =>
    _MenuCalendarDay(
      date: json['date'] as String,
      hasMenu: json['has_menu'] as bool,
      closed: json['closed'] as bool,
      isOrderable: json['is_orderable'] as bool,
      title: json['title'] as String?,
      packagePrice: (json['package_price'] as num?)?.toInt(),
      note: json['note'] as String?,
    );

Map<String, dynamic> _$MenuCalendarDayToJson(_MenuCalendarDay instance) =>
    <String, dynamic>{
      'date': instance.date,
      'has_menu': instance.hasMenu,
      'closed': instance.closed,
      'is_orderable': instance.isOrderable,
      'title': ?instance.title,
      'package_price': ?instance.packagePrice,
      'note': ?instance.note,
    };
