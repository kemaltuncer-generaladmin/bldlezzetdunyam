// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'subscription.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SubscriptionLine {

 int? get menuId; int get quantity;/// Porsiyon başı anlaşmalı fiyat (kuruş); satır fiyatı yoksa `null`.
 int? get agreedUnitPrice;/// Diyet/alerjen etiketi — "Vejetaryen" vb.
 String? get label;
/// Create a copy of SubscriptionLine
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubscriptionLineCopyWith<SubscriptionLine> get copyWith => _$SubscriptionLineCopyWithImpl<SubscriptionLine>(this as SubscriptionLine, _$identity);

  /// Serializes this SubscriptionLine to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionLine&&(identical(other.menuId, menuId) || other.menuId == menuId)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.agreedUnitPrice, agreedUnitPrice) || other.agreedUnitPrice == agreedUnitPrice)&&(identical(other.label, label) || other.label == label));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,menuId,quantity,agreedUnitPrice,label);

@override
String toString() {
  return 'SubscriptionLine(menuId: $menuId, quantity: $quantity, agreedUnitPrice: $agreedUnitPrice, label: $label)';
}


}

/// @nodoc
abstract mixin class $SubscriptionLineCopyWith<$Res>  {
  factory $SubscriptionLineCopyWith(SubscriptionLine value, $Res Function(SubscriptionLine) _then) = _$SubscriptionLineCopyWithImpl;
@useResult
$Res call({
 int? menuId, int quantity, int? agreedUnitPrice, String? label
});




}
/// @nodoc
class _$SubscriptionLineCopyWithImpl<$Res>
    implements $SubscriptionLineCopyWith<$Res> {
  _$SubscriptionLineCopyWithImpl(this._self, this._then);

  final SubscriptionLine _self;
  final $Res Function(SubscriptionLine) _then;

/// Create a copy of SubscriptionLine
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? menuId = freezed,Object? quantity = null,Object? agreedUnitPrice = freezed,Object? label = freezed,}) {
  return _then(_self.copyWith(
menuId: freezed == menuId ? _self.menuId : menuId // ignore: cast_nullable_to_non_nullable
as int?,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,agreedUnitPrice: freezed == agreedUnitPrice ? _self.agreedUnitPrice : agreedUnitPrice // ignore: cast_nullable_to_non_nullable
as int?,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SubscriptionLine].
extension SubscriptionLinePatterns on SubscriptionLine {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SubscriptionLine value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SubscriptionLine() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SubscriptionLine value)  $default,){
final _that = this;
switch (_that) {
case _SubscriptionLine():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SubscriptionLine value)?  $default,){
final _that = this;
switch (_that) {
case _SubscriptionLine() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? menuId,  int quantity,  int? agreedUnitPrice,  String? label)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SubscriptionLine() when $default != null:
return $default(_that.menuId,_that.quantity,_that.agreedUnitPrice,_that.label);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? menuId,  int quantity,  int? agreedUnitPrice,  String? label)  $default,) {final _that = this;
switch (_that) {
case _SubscriptionLine():
return $default(_that.menuId,_that.quantity,_that.agreedUnitPrice,_that.label);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? menuId,  int quantity,  int? agreedUnitPrice,  String? label)?  $default,) {final _that = this;
switch (_that) {
case _SubscriptionLine() when $default != null:
return $default(_that.menuId,_that.quantity,_that.agreedUnitPrice,_that.label);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SubscriptionLine implements SubscriptionLine {
  const _SubscriptionLine({this.menuId, required this.quantity, this.agreedUnitPrice, this.label});
  factory _SubscriptionLine.fromJson(Map<String, dynamic> json) => _$SubscriptionLineFromJson(json);

@override final  int? menuId;
@override final  int quantity;
/// Porsiyon başı anlaşmalı fiyat (kuruş); satır fiyatı yoksa `null`.
@override final  int? agreedUnitPrice;
/// Diyet/alerjen etiketi — "Vejetaryen" vb.
@override final  String? label;

/// Create a copy of SubscriptionLine
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubscriptionLineCopyWith<_SubscriptionLine> get copyWith => __$SubscriptionLineCopyWithImpl<_SubscriptionLine>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SubscriptionLineToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SubscriptionLine&&(identical(other.menuId, menuId) || other.menuId == menuId)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.agreedUnitPrice, agreedUnitPrice) || other.agreedUnitPrice == agreedUnitPrice)&&(identical(other.label, label) || other.label == label));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,menuId,quantity,agreedUnitPrice,label);

@override
String toString() {
  return 'SubscriptionLine(menuId: $menuId, quantity: $quantity, agreedUnitPrice: $agreedUnitPrice, label: $label)';
}


}

/// @nodoc
abstract mixin class _$SubscriptionLineCopyWith<$Res> implements $SubscriptionLineCopyWith<$Res> {
  factory _$SubscriptionLineCopyWith(_SubscriptionLine value, $Res Function(_SubscriptionLine) _then) = __$SubscriptionLineCopyWithImpl;
@override @useResult
$Res call({
 int? menuId, int quantity, int? agreedUnitPrice, String? label
});




}
/// @nodoc
class __$SubscriptionLineCopyWithImpl<$Res>
    implements _$SubscriptionLineCopyWith<$Res> {
  __$SubscriptionLineCopyWithImpl(this._self, this._then);

  final _SubscriptionLine _self;
  final $Res Function(_SubscriptionLine) _then;

/// Create a copy of SubscriptionLine
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? menuId = freezed,Object? quantity = null,Object? agreedUnitPrice = freezed,Object? label = freezed,}) {
  return _then(_SubscriptionLine(
menuId: freezed == menuId ? _self.menuId : menuId // ignore: cast_nullable_to_non_nullable
as int?,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,agreedUnitPrice: freezed == agreedUnitPrice ? _self.agreedUnitPrice : agreedUnitPrice // ignore: cast_nullable_to_non_nullable
as int?,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$SubscriptionDeliveryPoint {

 int get id; int get addressId; int? get quantity; String? get note;
/// Create a copy of SubscriptionDeliveryPoint
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubscriptionDeliveryPointCopyWith<SubscriptionDeliveryPoint> get copyWith => _$SubscriptionDeliveryPointCopyWithImpl<SubscriptionDeliveryPoint>(this as SubscriptionDeliveryPoint, _$identity);

  /// Serializes this SubscriptionDeliveryPoint to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionDeliveryPoint&&(identical(other.id, id) || other.id == id)&&(identical(other.addressId, addressId) || other.addressId == addressId)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.note, note) || other.note == note));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,addressId,quantity,note);

@override
String toString() {
  return 'SubscriptionDeliveryPoint(id: $id, addressId: $addressId, quantity: $quantity, note: $note)';
}


}

/// @nodoc
abstract mixin class $SubscriptionDeliveryPointCopyWith<$Res>  {
  factory $SubscriptionDeliveryPointCopyWith(SubscriptionDeliveryPoint value, $Res Function(SubscriptionDeliveryPoint) _then) = _$SubscriptionDeliveryPointCopyWithImpl;
@useResult
$Res call({
 int id, int addressId, int? quantity, String? note
});




}
/// @nodoc
class _$SubscriptionDeliveryPointCopyWithImpl<$Res>
    implements $SubscriptionDeliveryPointCopyWith<$Res> {
  _$SubscriptionDeliveryPointCopyWithImpl(this._self, this._then);

  final SubscriptionDeliveryPoint _self;
  final $Res Function(SubscriptionDeliveryPoint) _then;

/// Create a copy of SubscriptionDeliveryPoint
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? addressId = null,Object? quantity = freezed,Object? note = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,addressId: null == addressId ? _self.addressId : addressId // ignore: cast_nullable_to_non_nullable
as int,quantity: freezed == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SubscriptionDeliveryPoint].
extension SubscriptionDeliveryPointPatterns on SubscriptionDeliveryPoint {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SubscriptionDeliveryPoint value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SubscriptionDeliveryPoint() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SubscriptionDeliveryPoint value)  $default,){
final _that = this;
switch (_that) {
case _SubscriptionDeliveryPoint():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SubscriptionDeliveryPoint value)?  $default,){
final _that = this;
switch (_that) {
case _SubscriptionDeliveryPoint() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int addressId,  int? quantity,  String? note)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SubscriptionDeliveryPoint() when $default != null:
return $default(_that.id,_that.addressId,_that.quantity,_that.note);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int addressId,  int? quantity,  String? note)  $default,) {final _that = this;
switch (_that) {
case _SubscriptionDeliveryPoint():
return $default(_that.id,_that.addressId,_that.quantity,_that.note);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int addressId,  int? quantity,  String? note)?  $default,) {final _that = this;
switch (_that) {
case _SubscriptionDeliveryPoint() when $default != null:
return $default(_that.id,_that.addressId,_that.quantity,_that.note);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SubscriptionDeliveryPoint implements SubscriptionDeliveryPoint {
  const _SubscriptionDeliveryPoint({required this.id, required this.addressId, this.quantity, this.note});
  factory _SubscriptionDeliveryPoint.fromJson(Map<String, dynamic> json) => _$SubscriptionDeliveryPointFromJson(json);

@override final  int id;
@override final  int addressId;
@override final  int? quantity;
@override final  String? note;

/// Create a copy of SubscriptionDeliveryPoint
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubscriptionDeliveryPointCopyWith<_SubscriptionDeliveryPoint> get copyWith => __$SubscriptionDeliveryPointCopyWithImpl<_SubscriptionDeliveryPoint>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SubscriptionDeliveryPointToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SubscriptionDeliveryPoint&&(identical(other.id, id) || other.id == id)&&(identical(other.addressId, addressId) || other.addressId == addressId)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.note, note) || other.note == note));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,addressId,quantity,note);

@override
String toString() {
  return 'SubscriptionDeliveryPoint(id: $id, addressId: $addressId, quantity: $quantity, note: $note)';
}


}

/// @nodoc
abstract mixin class _$SubscriptionDeliveryPointCopyWith<$Res> implements $SubscriptionDeliveryPointCopyWith<$Res> {
  factory _$SubscriptionDeliveryPointCopyWith(_SubscriptionDeliveryPoint value, $Res Function(_SubscriptionDeliveryPoint) _then) = __$SubscriptionDeliveryPointCopyWithImpl;
@override @useResult
$Res call({
 int id, int addressId, int? quantity, String? note
});




}
/// @nodoc
class __$SubscriptionDeliveryPointCopyWithImpl<$Res>
    implements _$SubscriptionDeliveryPointCopyWith<$Res> {
  __$SubscriptionDeliveryPointCopyWithImpl(this._self, this._then);

  final _SubscriptionDeliveryPoint _self;
  final $Res Function(_SubscriptionDeliveryPoint) _then;

/// Create a copy of SubscriptionDeliveryPoint
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? addressId = null,Object? quantity = freezed,Object? note = freezed,}) {
  return _then(_SubscriptionDeliveryPoint(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,addressId: null == addressId ? _self.addressId : addressId // ignore: cast_nullable_to_non_nullable
as int,quantity: freezed == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$Subscription {

 int get id;/// `pending` (talep, fiyatsız) | `active` | `paused` | `cancelled`.
 String get status; int get locationId;@DeliveryTypeConverter() DeliveryType get deliveryType; DateTime get startDate; DateTime? get endDate;/// ISO hafta günleri (1 Pazartesi .. 7 Pazar).
 List<int> get serviceDays; String? get deliveryTimeFrom; String? get deliveryTimeTo; int get defaultQuantity;/// Porsiyon başı anlaşmalı fiyat (kuruş). Talepte `null`; admin belirler.
 int? get agreedUnitPrice;/// `account` (ay sonu cari) | `prepaid_monthly` (peşin).
 String get paymentMode;/// `fixed_list` | `daily_menu`.
 String get menuMode; List<SubscriptionLine> get lines; List<SubscriptionDeliveryPoint> get deliveryPoints; DateTime get createdAt;
/// Create a copy of Subscription
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubscriptionCopyWith<Subscription> get copyWith => _$SubscriptionCopyWithImpl<Subscription>(this as Subscription, _$identity);

  /// Serializes this Subscription to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Subscription&&(identical(other.id, id) || other.id == id)&&(identical(other.status, status) || other.status == status)&&(identical(other.locationId, locationId) || other.locationId == locationId)&&(identical(other.deliveryType, deliveryType) || other.deliveryType == deliveryType)&&(identical(other.startDate, startDate) || other.startDate == startDate)&&(identical(other.endDate, endDate) || other.endDate == endDate)&&const DeepCollectionEquality().equals(other.serviceDays, serviceDays)&&(identical(other.deliveryTimeFrom, deliveryTimeFrom) || other.deliveryTimeFrom == deliveryTimeFrom)&&(identical(other.deliveryTimeTo, deliveryTimeTo) || other.deliveryTimeTo == deliveryTimeTo)&&(identical(other.defaultQuantity, defaultQuantity) || other.defaultQuantity == defaultQuantity)&&(identical(other.agreedUnitPrice, agreedUnitPrice) || other.agreedUnitPrice == agreedUnitPrice)&&(identical(other.paymentMode, paymentMode) || other.paymentMode == paymentMode)&&(identical(other.menuMode, menuMode) || other.menuMode == menuMode)&&const DeepCollectionEquality().equals(other.lines, lines)&&const DeepCollectionEquality().equals(other.deliveryPoints, deliveryPoints)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,status,locationId,deliveryType,startDate,endDate,const DeepCollectionEquality().hash(serviceDays),deliveryTimeFrom,deliveryTimeTo,defaultQuantity,agreedUnitPrice,paymentMode,menuMode,const DeepCollectionEquality().hash(lines),const DeepCollectionEquality().hash(deliveryPoints),createdAt);

@override
String toString() {
  return 'Subscription(id: $id, status: $status, locationId: $locationId, deliveryType: $deliveryType, startDate: $startDate, endDate: $endDate, serviceDays: $serviceDays, deliveryTimeFrom: $deliveryTimeFrom, deliveryTimeTo: $deliveryTimeTo, defaultQuantity: $defaultQuantity, agreedUnitPrice: $agreedUnitPrice, paymentMode: $paymentMode, menuMode: $menuMode, lines: $lines, deliveryPoints: $deliveryPoints, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $SubscriptionCopyWith<$Res>  {
  factory $SubscriptionCopyWith(Subscription value, $Res Function(Subscription) _then) = _$SubscriptionCopyWithImpl;
@useResult
$Res call({
 int id, String status, int locationId,@DeliveryTypeConverter() DeliveryType deliveryType, DateTime startDate, DateTime? endDate, List<int> serviceDays, String? deliveryTimeFrom, String? deliveryTimeTo, int defaultQuantity, int? agreedUnitPrice, String paymentMode, String menuMode, List<SubscriptionLine> lines, List<SubscriptionDeliveryPoint> deliveryPoints, DateTime createdAt
});




}
/// @nodoc
class _$SubscriptionCopyWithImpl<$Res>
    implements $SubscriptionCopyWith<$Res> {
  _$SubscriptionCopyWithImpl(this._self, this._then);

  final Subscription _self;
  final $Res Function(Subscription) _then;

/// Create a copy of Subscription
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? status = null,Object? locationId = null,Object? deliveryType = null,Object? startDate = null,Object? endDate = freezed,Object? serviceDays = null,Object? deliveryTimeFrom = freezed,Object? deliveryTimeTo = freezed,Object? defaultQuantity = null,Object? agreedUnitPrice = freezed,Object? paymentMode = null,Object? menuMode = null,Object? lines = null,Object? deliveryPoints = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,locationId: null == locationId ? _self.locationId : locationId // ignore: cast_nullable_to_non_nullable
as int,deliveryType: null == deliveryType ? _self.deliveryType : deliveryType // ignore: cast_nullable_to_non_nullable
as DeliveryType,startDate: null == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as DateTime,endDate: freezed == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as DateTime?,serviceDays: null == serviceDays ? _self.serviceDays : serviceDays // ignore: cast_nullable_to_non_nullable
as List<int>,deliveryTimeFrom: freezed == deliveryTimeFrom ? _self.deliveryTimeFrom : deliveryTimeFrom // ignore: cast_nullable_to_non_nullable
as String?,deliveryTimeTo: freezed == deliveryTimeTo ? _self.deliveryTimeTo : deliveryTimeTo // ignore: cast_nullable_to_non_nullable
as String?,defaultQuantity: null == defaultQuantity ? _self.defaultQuantity : defaultQuantity // ignore: cast_nullable_to_non_nullable
as int,agreedUnitPrice: freezed == agreedUnitPrice ? _self.agreedUnitPrice : agreedUnitPrice // ignore: cast_nullable_to_non_nullable
as int?,paymentMode: null == paymentMode ? _self.paymentMode : paymentMode // ignore: cast_nullable_to_non_nullable
as String,menuMode: null == menuMode ? _self.menuMode : menuMode // ignore: cast_nullable_to_non_nullable
as String,lines: null == lines ? _self.lines : lines // ignore: cast_nullable_to_non_nullable
as List<SubscriptionLine>,deliveryPoints: null == deliveryPoints ? _self.deliveryPoints : deliveryPoints // ignore: cast_nullable_to_non_nullable
as List<SubscriptionDeliveryPoint>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Subscription].
extension SubscriptionPatterns on Subscription {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Subscription value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Subscription() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Subscription value)  $default,){
final _that = this;
switch (_that) {
case _Subscription():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Subscription value)?  $default,){
final _that = this;
switch (_that) {
case _Subscription() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String status,  int locationId, @DeliveryTypeConverter()  DeliveryType deliveryType,  DateTime startDate,  DateTime? endDate,  List<int> serviceDays,  String? deliveryTimeFrom,  String? deliveryTimeTo,  int defaultQuantity,  int? agreedUnitPrice,  String paymentMode,  String menuMode,  List<SubscriptionLine> lines,  List<SubscriptionDeliveryPoint> deliveryPoints,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Subscription() when $default != null:
return $default(_that.id,_that.status,_that.locationId,_that.deliveryType,_that.startDate,_that.endDate,_that.serviceDays,_that.deliveryTimeFrom,_that.deliveryTimeTo,_that.defaultQuantity,_that.agreedUnitPrice,_that.paymentMode,_that.menuMode,_that.lines,_that.deliveryPoints,_that.createdAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String status,  int locationId, @DeliveryTypeConverter()  DeliveryType deliveryType,  DateTime startDate,  DateTime? endDate,  List<int> serviceDays,  String? deliveryTimeFrom,  String? deliveryTimeTo,  int defaultQuantity,  int? agreedUnitPrice,  String paymentMode,  String menuMode,  List<SubscriptionLine> lines,  List<SubscriptionDeliveryPoint> deliveryPoints,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _Subscription():
return $default(_that.id,_that.status,_that.locationId,_that.deliveryType,_that.startDate,_that.endDate,_that.serviceDays,_that.deliveryTimeFrom,_that.deliveryTimeTo,_that.defaultQuantity,_that.agreedUnitPrice,_that.paymentMode,_that.menuMode,_that.lines,_that.deliveryPoints,_that.createdAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String status,  int locationId, @DeliveryTypeConverter()  DeliveryType deliveryType,  DateTime startDate,  DateTime? endDate,  List<int> serviceDays,  String? deliveryTimeFrom,  String? deliveryTimeTo,  int defaultQuantity,  int? agreedUnitPrice,  String paymentMode,  String menuMode,  List<SubscriptionLine> lines,  List<SubscriptionDeliveryPoint> deliveryPoints,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Subscription() when $default != null:
return $default(_that.id,_that.status,_that.locationId,_that.deliveryType,_that.startDate,_that.endDate,_that.serviceDays,_that.deliveryTimeFrom,_that.deliveryTimeTo,_that.defaultQuantity,_that.agreedUnitPrice,_that.paymentMode,_that.menuMode,_that.lines,_that.deliveryPoints,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Subscription extends Subscription {
  const _Subscription({required this.id, required this.status, required this.locationId, @DeliveryTypeConverter() required this.deliveryType, required this.startDate, this.endDate, final  List<int> serviceDays = const <int>[], this.deliveryTimeFrom, this.deliveryTimeTo, required this.defaultQuantity, this.agreedUnitPrice, required this.paymentMode, required this.menuMode, final  List<SubscriptionLine> lines = const <SubscriptionLine>[], final  List<SubscriptionDeliveryPoint> deliveryPoints = const <SubscriptionDeliveryPoint>[], required this.createdAt}): _serviceDays = serviceDays,_lines = lines,_deliveryPoints = deliveryPoints,super._();
  factory _Subscription.fromJson(Map<String, dynamic> json) => _$SubscriptionFromJson(json);

@override final  int id;
/// `pending` (talep, fiyatsız) | `active` | `paused` | `cancelled`.
@override final  String status;
@override final  int locationId;
@override@DeliveryTypeConverter() final  DeliveryType deliveryType;
@override final  DateTime startDate;
@override final  DateTime? endDate;
/// ISO hafta günleri (1 Pazartesi .. 7 Pazar).
 final  List<int> _serviceDays;
/// ISO hafta günleri (1 Pazartesi .. 7 Pazar).
@override@JsonKey() List<int> get serviceDays {
  if (_serviceDays is EqualUnmodifiableListView) return _serviceDays;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_serviceDays);
}

@override final  String? deliveryTimeFrom;
@override final  String? deliveryTimeTo;
@override final  int defaultQuantity;
/// Porsiyon başı anlaşmalı fiyat (kuruş). Talepte `null`; admin belirler.
@override final  int? agreedUnitPrice;
/// `account` (ay sonu cari) | `prepaid_monthly` (peşin).
@override final  String paymentMode;
/// `fixed_list` | `daily_menu`.
@override final  String menuMode;
 final  List<SubscriptionLine> _lines;
@override@JsonKey() List<SubscriptionLine> get lines {
  if (_lines is EqualUnmodifiableListView) return _lines;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lines);
}

 final  List<SubscriptionDeliveryPoint> _deliveryPoints;
@override@JsonKey() List<SubscriptionDeliveryPoint> get deliveryPoints {
  if (_deliveryPoints is EqualUnmodifiableListView) return _deliveryPoints;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_deliveryPoints);
}

@override final  DateTime createdAt;

/// Create a copy of Subscription
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubscriptionCopyWith<_Subscription> get copyWith => __$SubscriptionCopyWithImpl<_Subscription>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SubscriptionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Subscription&&(identical(other.id, id) || other.id == id)&&(identical(other.status, status) || other.status == status)&&(identical(other.locationId, locationId) || other.locationId == locationId)&&(identical(other.deliveryType, deliveryType) || other.deliveryType == deliveryType)&&(identical(other.startDate, startDate) || other.startDate == startDate)&&(identical(other.endDate, endDate) || other.endDate == endDate)&&const DeepCollectionEquality().equals(other._serviceDays, _serviceDays)&&(identical(other.deliveryTimeFrom, deliveryTimeFrom) || other.deliveryTimeFrom == deliveryTimeFrom)&&(identical(other.deliveryTimeTo, deliveryTimeTo) || other.deliveryTimeTo == deliveryTimeTo)&&(identical(other.defaultQuantity, defaultQuantity) || other.defaultQuantity == defaultQuantity)&&(identical(other.agreedUnitPrice, agreedUnitPrice) || other.agreedUnitPrice == agreedUnitPrice)&&(identical(other.paymentMode, paymentMode) || other.paymentMode == paymentMode)&&(identical(other.menuMode, menuMode) || other.menuMode == menuMode)&&const DeepCollectionEquality().equals(other._lines, _lines)&&const DeepCollectionEquality().equals(other._deliveryPoints, _deliveryPoints)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,status,locationId,deliveryType,startDate,endDate,const DeepCollectionEquality().hash(_serviceDays),deliveryTimeFrom,deliveryTimeTo,defaultQuantity,agreedUnitPrice,paymentMode,menuMode,const DeepCollectionEquality().hash(_lines),const DeepCollectionEquality().hash(_deliveryPoints),createdAt);

@override
String toString() {
  return 'Subscription(id: $id, status: $status, locationId: $locationId, deliveryType: $deliveryType, startDate: $startDate, endDate: $endDate, serviceDays: $serviceDays, deliveryTimeFrom: $deliveryTimeFrom, deliveryTimeTo: $deliveryTimeTo, defaultQuantity: $defaultQuantity, agreedUnitPrice: $agreedUnitPrice, paymentMode: $paymentMode, menuMode: $menuMode, lines: $lines, deliveryPoints: $deliveryPoints, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$SubscriptionCopyWith<$Res> implements $SubscriptionCopyWith<$Res> {
  factory _$SubscriptionCopyWith(_Subscription value, $Res Function(_Subscription) _then) = __$SubscriptionCopyWithImpl;
@override @useResult
$Res call({
 int id, String status, int locationId,@DeliveryTypeConverter() DeliveryType deliveryType, DateTime startDate, DateTime? endDate, List<int> serviceDays, String? deliveryTimeFrom, String? deliveryTimeTo, int defaultQuantity, int? agreedUnitPrice, String paymentMode, String menuMode, List<SubscriptionLine> lines, List<SubscriptionDeliveryPoint> deliveryPoints, DateTime createdAt
});




}
/// @nodoc
class __$SubscriptionCopyWithImpl<$Res>
    implements _$SubscriptionCopyWith<$Res> {
  __$SubscriptionCopyWithImpl(this._self, this._then);

  final _Subscription _self;
  final $Res Function(_Subscription) _then;

/// Create a copy of Subscription
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? status = null,Object? locationId = null,Object? deliveryType = null,Object? startDate = null,Object? endDate = freezed,Object? serviceDays = null,Object? deliveryTimeFrom = freezed,Object? deliveryTimeTo = freezed,Object? defaultQuantity = null,Object? agreedUnitPrice = freezed,Object? paymentMode = null,Object? menuMode = null,Object? lines = null,Object? deliveryPoints = null,Object? createdAt = null,}) {
  return _then(_Subscription(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,locationId: null == locationId ? _self.locationId : locationId // ignore: cast_nullable_to_non_nullable
as int,deliveryType: null == deliveryType ? _self.deliveryType : deliveryType // ignore: cast_nullable_to_non_nullable
as DeliveryType,startDate: null == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as DateTime,endDate: freezed == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as DateTime?,serviceDays: null == serviceDays ? _self._serviceDays : serviceDays // ignore: cast_nullable_to_non_nullable
as List<int>,deliveryTimeFrom: freezed == deliveryTimeFrom ? _self.deliveryTimeFrom : deliveryTimeFrom // ignore: cast_nullable_to_non_nullable
as String?,deliveryTimeTo: freezed == deliveryTimeTo ? _self.deliveryTimeTo : deliveryTimeTo // ignore: cast_nullable_to_non_nullable
as String?,defaultQuantity: null == defaultQuantity ? _self.defaultQuantity : defaultQuantity // ignore: cast_nullable_to_non_nullable
as int,agreedUnitPrice: freezed == agreedUnitPrice ? _self.agreedUnitPrice : agreedUnitPrice // ignore: cast_nullable_to_non_nullable
as int?,paymentMode: null == paymentMode ? _self.paymentMode : paymentMode // ignore: cast_nullable_to_non_nullable
as String,menuMode: null == menuMode ? _self.menuMode : menuMode // ignore: cast_nullable_to_non_nullable
as String,lines: null == lines ? _self._lines : lines // ignore: cast_nullable_to_non_nullable
as List<SubscriptionLine>,deliveryPoints: null == deliveryPoints ? _self._deliveryPoints : deliveryPoints // ignore: cast_nullable_to_non_nullable
as List<SubscriptionDeliveryPoint>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$SubscriptionCreateItem {

 int get menuId; int get quantity; String? get label;
/// Create a copy of SubscriptionCreateItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubscriptionCreateItemCopyWith<SubscriptionCreateItem> get copyWith => _$SubscriptionCreateItemCopyWithImpl<SubscriptionCreateItem>(this as SubscriptionCreateItem, _$identity);

  /// Serializes this SubscriptionCreateItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionCreateItem&&(identical(other.menuId, menuId) || other.menuId == menuId)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.label, label) || other.label == label));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,menuId,quantity,label);

@override
String toString() {
  return 'SubscriptionCreateItem(menuId: $menuId, quantity: $quantity, label: $label)';
}


}

/// @nodoc
abstract mixin class $SubscriptionCreateItemCopyWith<$Res>  {
  factory $SubscriptionCreateItemCopyWith(SubscriptionCreateItem value, $Res Function(SubscriptionCreateItem) _then) = _$SubscriptionCreateItemCopyWithImpl;
@useResult
$Res call({
 int menuId, int quantity, String? label
});




}
/// @nodoc
class _$SubscriptionCreateItemCopyWithImpl<$Res>
    implements $SubscriptionCreateItemCopyWith<$Res> {
  _$SubscriptionCreateItemCopyWithImpl(this._self, this._then);

  final SubscriptionCreateItem _self;
  final $Res Function(SubscriptionCreateItem) _then;

/// Create a copy of SubscriptionCreateItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? menuId = null,Object? quantity = null,Object? label = freezed,}) {
  return _then(_self.copyWith(
menuId: null == menuId ? _self.menuId : menuId // ignore: cast_nullable_to_non_nullable
as int,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SubscriptionCreateItem].
extension SubscriptionCreateItemPatterns on SubscriptionCreateItem {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SubscriptionCreateItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SubscriptionCreateItem() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SubscriptionCreateItem value)  $default,){
final _that = this;
switch (_that) {
case _SubscriptionCreateItem():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SubscriptionCreateItem value)?  $default,){
final _that = this;
switch (_that) {
case _SubscriptionCreateItem() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int menuId,  int quantity,  String? label)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SubscriptionCreateItem() when $default != null:
return $default(_that.menuId,_that.quantity,_that.label);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int menuId,  int quantity,  String? label)  $default,) {final _that = this;
switch (_that) {
case _SubscriptionCreateItem():
return $default(_that.menuId,_that.quantity,_that.label);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int menuId,  int quantity,  String? label)?  $default,) {final _that = this;
switch (_that) {
case _SubscriptionCreateItem() when $default != null:
return $default(_that.menuId,_that.quantity,_that.label);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SubscriptionCreateItem implements SubscriptionCreateItem {
  const _SubscriptionCreateItem({required this.menuId, required this.quantity, this.label});
  factory _SubscriptionCreateItem.fromJson(Map<String, dynamic> json) => _$SubscriptionCreateItemFromJson(json);

@override final  int menuId;
@override final  int quantity;
@override final  String? label;

/// Create a copy of SubscriptionCreateItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubscriptionCreateItemCopyWith<_SubscriptionCreateItem> get copyWith => __$SubscriptionCreateItemCopyWithImpl<_SubscriptionCreateItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SubscriptionCreateItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SubscriptionCreateItem&&(identical(other.menuId, menuId) || other.menuId == menuId)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.label, label) || other.label == label));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,menuId,quantity,label);

@override
String toString() {
  return 'SubscriptionCreateItem(menuId: $menuId, quantity: $quantity, label: $label)';
}


}

/// @nodoc
abstract mixin class _$SubscriptionCreateItemCopyWith<$Res> implements $SubscriptionCreateItemCopyWith<$Res> {
  factory _$SubscriptionCreateItemCopyWith(_SubscriptionCreateItem value, $Res Function(_SubscriptionCreateItem) _then) = __$SubscriptionCreateItemCopyWithImpl;
@override @useResult
$Res call({
 int menuId, int quantity, String? label
});




}
/// @nodoc
class __$SubscriptionCreateItemCopyWithImpl<$Res>
    implements _$SubscriptionCreateItemCopyWith<$Res> {
  __$SubscriptionCreateItemCopyWithImpl(this._self, this._then);

  final _SubscriptionCreateItem _self;
  final $Res Function(_SubscriptionCreateItem) _then;

/// Create a copy of SubscriptionCreateItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? menuId = null,Object? quantity = null,Object? label = freezed,}) {
  return _then(_SubscriptionCreateItem(
menuId: null == menuId ? _self.menuId : menuId // ignore: cast_nullable_to_non_nullable
as int,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$SubscriptionCreatePoint {

 int get addressId; int? get quantity; String? get note;
/// Create a copy of SubscriptionCreatePoint
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubscriptionCreatePointCopyWith<SubscriptionCreatePoint> get copyWith => _$SubscriptionCreatePointCopyWithImpl<SubscriptionCreatePoint>(this as SubscriptionCreatePoint, _$identity);

  /// Serializes this SubscriptionCreatePoint to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionCreatePoint&&(identical(other.addressId, addressId) || other.addressId == addressId)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.note, note) || other.note == note));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,addressId,quantity,note);

@override
String toString() {
  return 'SubscriptionCreatePoint(addressId: $addressId, quantity: $quantity, note: $note)';
}


}

/// @nodoc
abstract mixin class $SubscriptionCreatePointCopyWith<$Res>  {
  factory $SubscriptionCreatePointCopyWith(SubscriptionCreatePoint value, $Res Function(SubscriptionCreatePoint) _then) = _$SubscriptionCreatePointCopyWithImpl;
@useResult
$Res call({
 int addressId, int? quantity, String? note
});




}
/// @nodoc
class _$SubscriptionCreatePointCopyWithImpl<$Res>
    implements $SubscriptionCreatePointCopyWith<$Res> {
  _$SubscriptionCreatePointCopyWithImpl(this._self, this._then);

  final SubscriptionCreatePoint _self;
  final $Res Function(SubscriptionCreatePoint) _then;

/// Create a copy of SubscriptionCreatePoint
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? addressId = null,Object? quantity = freezed,Object? note = freezed,}) {
  return _then(_self.copyWith(
addressId: null == addressId ? _self.addressId : addressId // ignore: cast_nullable_to_non_nullable
as int,quantity: freezed == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SubscriptionCreatePoint].
extension SubscriptionCreatePointPatterns on SubscriptionCreatePoint {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SubscriptionCreatePoint value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SubscriptionCreatePoint() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SubscriptionCreatePoint value)  $default,){
final _that = this;
switch (_that) {
case _SubscriptionCreatePoint():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SubscriptionCreatePoint value)?  $default,){
final _that = this;
switch (_that) {
case _SubscriptionCreatePoint() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int addressId,  int? quantity,  String? note)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SubscriptionCreatePoint() when $default != null:
return $default(_that.addressId,_that.quantity,_that.note);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int addressId,  int? quantity,  String? note)  $default,) {final _that = this;
switch (_that) {
case _SubscriptionCreatePoint():
return $default(_that.addressId,_that.quantity,_that.note);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int addressId,  int? quantity,  String? note)?  $default,) {final _that = this;
switch (_that) {
case _SubscriptionCreatePoint() when $default != null:
return $default(_that.addressId,_that.quantity,_that.note);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SubscriptionCreatePoint implements SubscriptionCreatePoint {
  const _SubscriptionCreatePoint({required this.addressId, this.quantity, this.note});
  factory _SubscriptionCreatePoint.fromJson(Map<String, dynamic> json) => _$SubscriptionCreatePointFromJson(json);

@override final  int addressId;
@override final  int? quantity;
@override final  String? note;

/// Create a copy of SubscriptionCreatePoint
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubscriptionCreatePointCopyWith<_SubscriptionCreatePoint> get copyWith => __$SubscriptionCreatePointCopyWithImpl<_SubscriptionCreatePoint>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SubscriptionCreatePointToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SubscriptionCreatePoint&&(identical(other.addressId, addressId) || other.addressId == addressId)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.note, note) || other.note == note));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,addressId,quantity,note);

@override
String toString() {
  return 'SubscriptionCreatePoint(addressId: $addressId, quantity: $quantity, note: $note)';
}


}

/// @nodoc
abstract mixin class _$SubscriptionCreatePointCopyWith<$Res> implements $SubscriptionCreatePointCopyWith<$Res> {
  factory _$SubscriptionCreatePointCopyWith(_SubscriptionCreatePoint value, $Res Function(_SubscriptionCreatePoint) _then) = __$SubscriptionCreatePointCopyWithImpl;
@override @useResult
$Res call({
 int addressId, int? quantity, String? note
});




}
/// @nodoc
class __$SubscriptionCreatePointCopyWithImpl<$Res>
    implements _$SubscriptionCreatePointCopyWith<$Res> {
  __$SubscriptionCreatePointCopyWithImpl(this._self, this._then);

  final _SubscriptionCreatePoint _self;
  final $Res Function(_SubscriptionCreatePoint) _then;

/// Create a copy of SubscriptionCreatePoint
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? addressId = null,Object? quantity = freezed,Object? note = freezed,}) {
  return _then(_SubscriptionCreatePoint(
addressId: null == addressId ? _self.addressId : addressId // ignore: cast_nullable_to_non_nullable
as int,quantity: freezed == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$SubscriptionCreateRequest {

 int get locationId;@DeliveryTypeConverter() DeliveryType get deliveryType; String get startDate; String? get endDate; List<int> get serviceDays; int get defaultQuantity; String? get deliveryTimeFrom; String? get deliveryTimeTo; List<SubscriptionCreateItem> get lines; List<SubscriptionCreatePoint> get deliveryPoints; String? get customerNote;
/// Create a copy of SubscriptionCreateRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubscriptionCreateRequestCopyWith<SubscriptionCreateRequest> get copyWith => _$SubscriptionCreateRequestCopyWithImpl<SubscriptionCreateRequest>(this as SubscriptionCreateRequest, _$identity);

  /// Serializes this SubscriptionCreateRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionCreateRequest&&(identical(other.locationId, locationId) || other.locationId == locationId)&&(identical(other.deliveryType, deliveryType) || other.deliveryType == deliveryType)&&(identical(other.startDate, startDate) || other.startDate == startDate)&&(identical(other.endDate, endDate) || other.endDate == endDate)&&const DeepCollectionEquality().equals(other.serviceDays, serviceDays)&&(identical(other.defaultQuantity, defaultQuantity) || other.defaultQuantity == defaultQuantity)&&(identical(other.deliveryTimeFrom, deliveryTimeFrom) || other.deliveryTimeFrom == deliveryTimeFrom)&&(identical(other.deliveryTimeTo, deliveryTimeTo) || other.deliveryTimeTo == deliveryTimeTo)&&const DeepCollectionEquality().equals(other.lines, lines)&&const DeepCollectionEquality().equals(other.deliveryPoints, deliveryPoints)&&(identical(other.customerNote, customerNote) || other.customerNote == customerNote));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,locationId,deliveryType,startDate,endDate,const DeepCollectionEquality().hash(serviceDays),defaultQuantity,deliveryTimeFrom,deliveryTimeTo,const DeepCollectionEquality().hash(lines),const DeepCollectionEquality().hash(deliveryPoints),customerNote);

@override
String toString() {
  return 'SubscriptionCreateRequest(locationId: $locationId, deliveryType: $deliveryType, startDate: $startDate, endDate: $endDate, serviceDays: $serviceDays, defaultQuantity: $defaultQuantity, deliveryTimeFrom: $deliveryTimeFrom, deliveryTimeTo: $deliveryTimeTo, lines: $lines, deliveryPoints: $deliveryPoints, customerNote: $customerNote)';
}


}

/// @nodoc
abstract mixin class $SubscriptionCreateRequestCopyWith<$Res>  {
  factory $SubscriptionCreateRequestCopyWith(SubscriptionCreateRequest value, $Res Function(SubscriptionCreateRequest) _then) = _$SubscriptionCreateRequestCopyWithImpl;
@useResult
$Res call({
 int locationId,@DeliveryTypeConverter() DeliveryType deliveryType, String startDate, String? endDate, List<int> serviceDays, int defaultQuantity, String? deliveryTimeFrom, String? deliveryTimeTo, List<SubscriptionCreateItem> lines, List<SubscriptionCreatePoint> deliveryPoints, String? customerNote
});




}
/// @nodoc
class _$SubscriptionCreateRequestCopyWithImpl<$Res>
    implements $SubscriptionCreateRequestCopyWith<$Res> {
  _$SubscriptionCreateRequestCopyWithImpl(this._self, this._then);

  final SubscriptionCreateRequest _self;
  final $Res Function(SubscriptionCreateRequest) _then;

/// Create a copy of SubscriptionCreateRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? locationId = null,Object? deliveryType = null,Object? startDate = null,Object? endDate = freezed,Object? serviceDays = null,Object? defaultQuantity = null,Object? deliveryTimeFrom = freezed,Object? deliveryTimeTo = freezed,Object? lines = null,Object? deliveryPoints = null,Object? customerNote = freezed,}) {
  return _then(_self.copyWith(
locationId: null == locationId ? _self.locationId : locationId // ignore: cast_nullable_to_non_nullable
as int,deliveryType: null == deliveryType ? _self.deliveryType : deliveryType // ignore: cast_nullable_to_non_nullable
as DeliveryType,startDate: null == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as String,endDate: freezed == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as String?,serviceDays: null == serviceDays ? _self.serviceDays : serviceDays // ignore: cast_nullable_to_non_nullable
as List<int>,defaultQuantity: null == defaultQuantity ? _self.defaultQuantity : defaultQuantity // ignore: cast_nullable_to_non_nullable
as int,deliveryTimeFrom: freezed == deliveryTimeFrom ? _self.deliveryTimeFrom : deliveryTimeFrom // ignore: cast_nullable_to_non_nullable
as String?,deliveryTimeTo: freezed == deliveryTimeTo ? _self.deliveryTimeTo : deliveryTimeTo // ignore: cast_nullable_to_non_nullable
as String?,lines: null == lines ? _self.lines : lines // ignore: cast_nullable_to_non_nullable
as List<SubscriptionCreateItem>,deliveryPoints: null == deliveryPoints ? _self.deliveryPoints : deliveryPoints // ignore: cast_nullable_to_non_nullable
as List<SubscriptionCreatePoint>,customerNote: freezed == customerNote ? _self.customerNote : customerNote // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SubscriptionCreateRequest].
extension SubscriptionCreateRequestPatterns on SubscriptionCreateRequest {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SubscriptionCreateRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SubscriptionCreateRequest() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SubscriptionCreateRequest value)  $default,){
final _that = this;
switch (_that) {
case _SubscriptionCreateRequest():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SubscriptionCreateRequest value)?  $default,){
final _that = this;
switch (_that) {
case _SubscriptionCreateRequest() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int locationId, @DeliveryTypeConverter()  DeliveryType deliveryType,  String startDate,  String? endDate,  List<int> serviceDays,  int defaultQuantity,  String? deliveryTimeFrom,  String? deliveryTimeTo,  List<SubscriptionCreateItem> lines,  List<SubscriptionCreatePoint> deliveryPoints,  String? customerNote)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SubscriptionCreateRequest() when $default != null:
return $default(_that.locationId,_that.deliveryType,_that.startDate,_that.endDate,_that.serviceDays,_that.defaultQuantity,_that.deliveryTimeFrom,_that.deliveryTimeTo,_that.lines,_that.deliveryPoints,_that.customerNote);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int locationId, @DeliveryTypeConverter()  DeliveryType deliveryType,  String startDate,  String? endDate,  List<int> serviceDays,  int defaultQuantity,  String? deliveryTimeFrom,  String? deliveryTimeTo,  List<SubscriptionCreateItem> lines,  List<SubscriptionCreatePoint> deliveryPoints,  String? customerNote)  $default,) {final _that = this;
switch (_that) {
case _SubscriptionCreateRequest():
return $default(_that.locationId,_that.deliveryType,_that.startDate,_that.endDate,_that.serviceDays,_that.defaultQuantity,_that.deliveryTimeFrom,_that.deliveryTimeTo,_that.lines,_that.deliveryPoints,_that.customerNote);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int locationId, @DeliveryTypeConverter()  DeliveryType deliveryType,  String startDate,  String? endDate,  List<int> serviceDays,  int defaultQuantity,  String? deliveryTimeFrom,  String? deliveryTimeTo,  List<SubscriptionCreateItem> lines,  List<SubscriptionCreatePoint> deliveryPoints,  String? customerNote)?  $default,) {final _that = this;
switch (_that) {
case _SubscriptionCreateRequest() when $default != null:
return $default(_that.locationId,_that.deliveryType,_that.startDate,_that.endDate,_that.serviceDays,_that.defaultQuantity,_that.deliveryTimeFrom,_that.deliveryTimeTo,_that.lines,_that.deliveryPoints,_that.customerNote);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SubscriptionCreateRequest implements SubscriptionCreateRequest {
  const _SubscriptionCreateRequest({required this.locationId, @DeliveryTypeConverter() required this.deliveryType, required this.startDate, this.endDate, required final  List<int> serviceDays, required this.defaultQuantity, this.deliveryTimeFrom, this.deliveryTimeTo, final  List<SubscriptionCreateItem> lines = const <SubscriptionCreateItem>[], final  List<SubscriptionCreatePoint> deliveryPoints = const <SubscriptionCreatePoint>[], this.customerNote}): _serviceDays = serviceDays,_lines = lines,_deliveryPoints = deliveryPoints;
  factory _SubscriptionCreateRequest.fromJson(Map<String, dynamic> json) => _$SubscriptionCreateRequestFromJson(json);

@override final  int locationId;
@override@DeliveryTypeConverter() final  DeliveryType deliveryType;
@override final  String startDate;
@override final  String? endDate;
 final  List<int> _serviceDays;
@override List<int> get serviceDays {
  if (_serviceDays is EqualUnmodifiableListView) return _serviceDays;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_serviceDays);
}

@override final  int defaultQuantity;
@override final  String? deliveryTimeFrom;
@override final  String? deliveryTimeTo;
 final  List<SubscriptionCreateItem> _lines;
@override@JsonKey() List<SubscriptionCreateItem> get lines {
  if (_lines is EqualUnmodifiableListView) return _lines;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lines);
}

 final  List<SubscriptionCreatePoint> _deliveryPoints;
@override@JsonKey() List<SubscriptionCreatePoint> get deliveryPoints {
  if (_deliveryPoints is EqualUnmodifiableListView) return _deliveryPoints;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_deliveryPoints);
}

@override final  String? customerNote;

/// Create a copy of SubscriptionCreateRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubscriptionCreateRequestCopyWith<_SubscriptionCreateRequest> get copyWith => __$SubscriptionCreateRequestCopyWithImpl<_SubscriptionCreateRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SubscriptionCreateRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SubscriptionCreateRequest&&(identical(other.locationId, locationId) || other.locationId == locationId)&&(identical(other.deliveryType, deliveryType) || other.deliveryType == deliveryType)&&(identical(other.startDate, startDate) || other.startDate == startDate)&&(identical(other.endDate, endDate) || other.endDate == endDate)&&const DeepCollectionEquality().equals(other._serviceDays, _serviceDays)&&(identical(other.defaultQuantity, defaultQuantity) || other.defaultQuantity == defaultQuantity)&&(identical(other.deliveryTimeFrom, deliveryTimeFrom) || other.deliveryTimeFrom == deliveryTimeFrom)&&(identical(other.deliveryTimeTo, deliveryTimeTo) || other.deliveryTimeTo == deliveryTimeTo)&&const DeepCollectionEquality().equals(other._lines, _lines)&&const DeepCollectionEquality().equals(other._deliveryPoints, _deliveryPoints)&&(identical(other.customerNote, customerNote) || other.customerNote == customerNote));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,locationId,deliveryType,startDate,endDate,const DeepCollectionEquality().hash(_serviceDays),defaultQuantity,deliveryTimeFrom,deliveryTimeTo,const DeepCollectionEquality().hash(_lines),const DeepCollectionEquality().hash(_deliveryPoints),customerNote);

@override
String toString() {
  return 'SubscriptionCreateRequest(locationId: $locationId, deliveryType: $deliveryType, startDate: $startDate, endDate: $endDate, serviceDays: $serviceDays, defaultQuantity: $defaultQuantity, deliveryTimeFrom: $deliveryTimeFrom, deliveryTimeTo: $deliveryTimeTo, lines: $lines, deliveryPoints: $deliveryPoints, customerNote: $customerNote)';
}


}

/// @nodoc
abstract mixin class _$SubscriptionCreateRequestCopyWith<$Res> implements $SubscriptionCreateRequestCopyWith<$Res> {
  factory _$SubscriptionCreateRequestCopyWith(_SubscriptionCreateRequest value, $Res Function(_SubscriptionCreateRequest) _then) = __$SubscriptionCreateRequestCopyWithImpl;
@override @useResult
$Res call({
 int locationId,@DeliveryTypeConverter() DeliveryType deliveryType, String startDate, String? endDate, List<int> serviceDays, int defaultQuantity, String? deliveryTimeFrom, String? deliveryTimeTo, List<SubscriptionCreateItem> lines, List<SubscriptionCreatePoint> deliveryPoints, String? customerNote
});




}
/// @nodoc
class __$SubscriptionCreateRequestCopyWithImpl<$Res>
    implements _$SubscriptionCreateRequestCopyWith<$Res> {
  __$SubscriptionCreateRequestCopyWithImpl(this._self, this._then);

  final _SubscriptionCreateRequest _self;
  final $Res Function(_SubscriptionCreateRequest) _then;

/// Create a copy of SubscriptionCreateRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? locationId = null,Object? deliveryType = null,Object? startDate = null,Object? endDate = freezed,Object? serviceDays = null,Object? defaultQuantity = null,Object? deliveryTimeFrom = freezed,Object? deliveryTimeTo = freezed,Object? lines = null,Object? deliveryPoints = null,Object? customerNote = freezed,}) {
  return _then(_SubscriptionCreateRequest(
locationId: null == locationId ? _self.locationId : locationId // ignore: cast_nullable_to_non_nullable
as int,deliveryType: null == deliveryType ? _self.deliveryType : deliveryType // ignore: cast_nullable_to_non_nullable
as DeliveryType,startDate: null == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as String,endDate: freezed == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as String?,serviceDays: null == serviceDays ? _self._serviceDays : serviceDays // ignore: cast_nullable_to_non_nullable
as List<int>,defaultQuantity: null == defaultQuantity ? _self.defaultQuantity : defaultQuantity // ignore: cast_nullable_to_non_nullable
as int,deliveryTimeFrom: freezed == deliveryTimeFrom ? _self.deliveryTimeFrom : deliveryTimeFrom // ignore: cast_nullable_to_non_nullable
as String?,deliveryTimeTo: freezed == deliveryTimeTo ? _self.deliveryTimeTo : deliveryTimeTo // ignore: cast_nullable_to_non_nullable
as String?,lines: null == lines ? _self._lines : lines // ignore: cast_nullable_to_non_nullable
as List<SubscriptionCreateItem>,deliveryPoints: null == deliveryPoints ? _self._deliveryPoints : deliveryPoints // ignore: cast_nullable_to_non_nullable
as List<SubscriptionCreatePoint>,customerNote: freezed == customerNote ? _self.customerNote : customerNote // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$SubscriptionExceptionRequest {

 String get serviceDate; bool? get skip; int? get quantityOverride;
/// Create a copy of SubscriptionExceptionRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubscriptionExceptionRequestCopyWith<SubscriptionExceptionRequest> get copyWith => _$SubscriptionExceptionRequestCopyWithImpl<SubscriptionExceptionRequest>(this as SubscriptionExceptionRequest, _$identity);

  /// Serializes this SubscriptionExceptionRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionExceptionRequest&&(identical(other.serviceDate, serviceDate) || other.serviceDate == serviceDate)&&(identical(other.skip, skip) || other.skip == skip)&&(identical(other.quantityOverride, quantityOverride) || other.quantityOverride == quantityOverride));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,serviceDate,skip,quantityOverride);

@override
String toString() {
  return 'SubscriptionExceptionRequest(serviceDate: $serviceDate, skip: $skip, quantityOverride: $quantityOverride)';
}


}

/// @nodoc
abstract mixin class $SubscriptionExceptionRequestCopyWith<$Res>  {
  factory $SubscriptionExceptionRequestCopyWith(SubscriptionExceptionRequest value, $Res Function(SubscriptionExceptionRequest) _then) = _$SubscriptionExceptionRequestCopyWithImpl;
@useResult
$Res call({
 String serviceDate, bool? skip, int? quantityOverride
});




}
/// @nodoc
class _$SubscriptionExceptionRequestCopyWithImpl<$Res>
    implements $SubscriptionExceptionRequestCopyWith<$Res> {
  _$SubscriptionExceptionRequestCopyWithImpl(this._self, this._then);

  final SubscriptionExceptionRequest _self;
  final $Res Function(SubscriptionExceptionRequest) _then;

/// Create a copy of SubscriptionExceptionRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? serviceDate = null,Object? skip = freezed,Object? quantityOverride = freezed,}) {
  return _then(_self.copyWith(
serviceDate: null == serviceDate ? _self.serviceDate : serviceDate // ignore: cast_nullable_to_non_nullable
as String,skip: freezed == skip ? _self.skip : skip // ignore: cast_nullable_to_non_nullable
as bool?,quantityOverride: freezed == quantityOverride ? _self.quantityOverride : quantityOverride // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [SubscriptionExceptionRequest].
extension SubscriptionExceptionRequestPatterns on SubscriptionExceptionRequest {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SubscriptionExceptionRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SubscriptionExceptionRequest() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SubscriptionExceptionRequest value)  $default,){
final _that = this;
switch (_that) {
case _SubscriptionExceptionRequest():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SubscriptionExceptionRequest value)?  $default,){
final _that = this;
switch (_that) {
case _SubscriptionExceptionRequest() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String serviceDate,  bool? skip,  int? quantityOverride)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SubscriptionExceptionRequest() when $default != null:
return $default(_that.serviceDate,_that.skip,_that.quantityOverride);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String serviceDate,  bool? skip,  int? quantityOverride)  $default,) {final _that = this;
switch (_that) {
case _SubscriptionExceptionRequest():
return $default(_that.serviceDate,_that.skip,_that.quantityOverride);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String serviceDate,  bool? skip,  int? quantityOverride)?  $default,) {final _that = this;
switch (_that) {
case _SubscriptionExceptionRequest() when $default != null:
return $default(_that.serviceDate,_that.skip,_that.quantityOverride);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SubscriptionExceptionRequest implements SubscriptionExceptionRequest {
  const _SubscriptionExceptionRequest({required this.serviceDate, this.skip, this.quantityOverride});
  factory _SubscriptionExceptionRequest.fromJson(Map<String, dynamic> json) => _$SubscriptionExceptionRequestFromJson(json);

@override final  String serviceDate;
@override final  bool? skip;
@override final  int? quantityOverride;

/// Create a copy of SubscriptionExceptionRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubscriptionExceptionRequestCopyWith<_SubscriptionExceptionRequest> get copyWith => __$SubscriptionExceptionRequestCopyWithImpl<_SubscriptionExceptionRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SubscriptionExceptionRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SubscriptionExceptionRequest&&(identical(other.serviceDate, serviceDate) || other.serviceDate == serviceDate)&&(identical(other.skip, skip) || other.skip == skip)&&(identical(other.quantityOverride, quantityOverride) || other.quantityOverride == quantityOverride));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,serviceDate,skip,quantityOverride);

@override
String toString() {
  return 'SubscriptionExceptionRequest(serviceDate: $serviceDate, skip: $skip, quantityOverride: $quantityOverride)';
}


}

/// @nodoc
abstract mixin class _$SubscriptionExceptionRequestCopyWith<$Res> implements $SubscriptionExceptionRequestCopyWith<$Res> {
  factory _$SubscriptionExceptionRequestCopyWith(_SubscriptionExceptionRequest value, $Res Function(_SubscriptionExceptionRequest) _then) = __$SubscriptionExceptionRequestCopyWithImpl;
@override @useResult
$Res call({
 String serviceDate, bool? skip, int? quantityOverride
});




}
/// @nodoc
class __$SubscriptionExceptionRequestCopyWithImpl<$Res>
    implements _$SubscriptionExceptionRequestCopyWith<$Res> {
  __$SubscriptionExceptionRequestCopyWithImpl(this._self, this._then);

  final _SubscriptionExceptionRequest _self;
  final $Res Function(_SubscriptionExceptionRequest) _then;

/// Create a copy of SubscriptionExceptionRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? serviceDate = null,Object? skip = freezed,Object? quantityOverride = freezed,}) {
  return _then(_SubscriptionExceptionRequest(
serviceDate: null == serviceDate ? _self.serviceDate : serviceDate // ignore: cast_nullable_to_non_nullable
as String,skip: freezed == skip ? _self.skip : skip // ignore: cast_nullable_to_non_nullable
as bool?,quantityOverride: freezed == quantityOverride ? _self.quantityOverride : quantityOverride // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
