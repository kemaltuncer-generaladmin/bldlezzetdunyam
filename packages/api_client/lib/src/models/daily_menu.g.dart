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
      remainingPortions: (json['remaining_portions'] as num?)?.toInt(),
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
      'remaining_portions': ?instance.remainingPortions,
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
  imageUrls:
      (json['image_urls'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  package: json['package'] == null
      ? null
      : DailyMenuPackage.fromJson(json['package'] as Map<String, dynamic>),
  itemsTotal: (json['items_total'] as num?)?.toInt(),
  cutoffAt: json['cutoff_at'] == null
      ? null
      : DateTime.parse(json['cutoff_at'] as String),
  remainingPortions: (json['remaining_portions'] as num?)?.toInt(),
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
      'image_urls': instance.imageUrls,
      'package': ?instance.package?.toJson(),
      'items_total': ?instance.itemsTotal,
      'cutoff_at': ?instance.cutoffAt?.toIso8601String(),
      'remaining_portions': ?instance.remainingPortions,
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
      cutoffAt: json['cutoff_at'] == null
          ? null
          : DateTime.parse(json['cutoff_at'] as String),
      soldOut: json['sold_out'] as bool? ?? false,
      weekend: json['weekend'] as bool? ?? false,
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
      'cutoff_at': ?instance.cutoffAt?.toIso8601String(),
      'sold_out': instance.soldOut,
      'weekend': instance.weekend,
      'title': ?instance.title,
      'package_price': ?instance.packagePrice,
      'note': ?instance.note,
    };
