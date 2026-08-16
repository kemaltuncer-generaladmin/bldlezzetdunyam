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
mixin _$SubscriptionException {

/// İstisnanın geçerli olduğu servis günü, `YYYY-AA-GG` (Europe/Istanbul).
///
/// `DateTime` değil `String`: bu bir an değil, takvimdeki bir gün —
/// gerekçe `daily_menu.dart` kitaplık açıklamasında.
 String get serviceDate;/// `true` ise o gün sipariş **üretilmez**. `false` ise gün üretilir ve
/// varsa [quantityOverride] uygulanır.
 bool get skip;/// O güne özel porsiyon adedi; verilmemişse `null` ve aboneliğin
/// `defaultQuantity` değeri geçerlidir. [skip] doğruyken anlamsızdır.
 int? get quantityOverride;/// İstisnanın girildiği an.
///
/// Ekranda "12 Ağustos'ta atladınız" diyebilmek için var: aynı gün için
/// iki kez işlem yapıldığında abone hangisinin geçerli olduğunu ancak
/// zamana bakarak anlar.
 DateTime? get createdAt;
/// Create a copy of SubscriptionException
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubscriptionExceptionCopyWith<SubscriptionException> get copyWith => _$SubscriptionExceptionCopyWithImpl<SubscriptionException>(this as SubscriptionException, _$identity);

  /// Serializes this SubscriptionException to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionException&&(identical(other.serviceDate, serviceDate) || other.serviceDate == serviceDate)&&(identical(other.skip, skip) || other.skip == skip)&&(identical(other.quantityOverride, quantityOverride) || other.quantityOverride == quantityOverride)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,serviceDate,skip,quantityOverride,createdAt);

@override
String toString() {
  return 'SubscriptionException(serviceDate: $serviceDate, skip: $skip, quantityOverride: $quantityOverride, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $SubscriptionExceptionCopyWith<$Res>  {
  factory $SubscriptionExceptionCopyWith(SubscriptionException value, $Res Function(SubscriptionException) _then) = _$SubscriptionExceptionCopyWithImpl;
@useResult
$Res call({
 String serviceDate, bool skip, int? quantityOverride, DateTime? createdAt
});




}
/// @nodoc
class _$SubscriptionExceptionCopyWithImpl<$Res>
    implements $SubscriptionExceptionCopyWith<$Res> {
  _$SubscriptionExceptionCopyWithImpl(this._self, this._then);

  final SubscriptionException _self;
  final $Res Function(SubscriptionException) _then;

/// Create a copy of SubscriptionException
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? serviceDate = null,Object? skip = null,Object? quantityOverride = freezed,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
serviceDate: null == serviceDate ? _self.serviceDate : serviceDate // ignore: cast_nullable_to_non_nullable
as String,skip: null == skip ? _self.skip : skip // ignore: cast_nullable_to_non_nullable
as bool,quantityOverride: freezed == quantityOverride ? _self.quantityOverride : quantityOverride // ignore: cast_nullable_to_non_nullable
as int?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [SubscriptionException].
extension SubscriptionExceptionPatterns on SubscriptionException {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SubscriptionException value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SubscriptionException() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SubscriptionException value)  $default,){
final _that = this;
switch (_that) {
case _SubscriptionException():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SubscriptionException value)?  $default,){
final _that = this;
switch (_that) {
case _SubscriptionException() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String serviceDate,  bool skip,  int? quantityOverride,  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SubscriptionException() when $default != null:
return $default(_that.serviceDate,_that.skip,_that.quantityOverride,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String serviceDate,  bool skip,  int? quantityOverride,  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _SubscriptionException():
return $default(_that.serviceDate,_that.skip,_that.quantityOverride,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String serviceDate,  bool skip,  int? quantityOverride,  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _SubscriptionException() when $default != null:
return $default(_that.serviceDate,_that.skip,_that.quantityOverride,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SubscriptionException extends SubscriptionException {
  const _SubscriptionException({required this.serviceDate, required this.skip, this.quantityOverride, this.createdAt}): super._();
  factory _SubscriptionException.fromJson(Map<String, dynamic> json) => _$SubscriptionExceptionFromJson(json);

/// İstisnanın geçerli olduğu servis günü, `YYYY-AA-GG` (Europe/Istanbul).
///
/// `DateTime` değil `String`: bu bir an değil, takvimdeki bir gün —
/// gerekçe `daily_menu.dart` kitaplık açıklamasında.
@override final  String serviceDate;
/// `true` ise o gün sipariş **üretilmez**. `false` ise gün üretilir ve
/// varsa [quantityOverride] uygulanır.
@override final  bool skip;
/// O güne özel porsiyon adedi; verilmemişse `null` ve aboneliğin
/// `defaultQuantity` değeri geçerlidir. [skip] doğruyken anlamsızdır.
@override final  int? quantityOverride;
/// İstisnanın girildiği an.
///
/// Ekranda "12 Ağustos'ta atladınız" diyebilmek için var: aynı gün için
/// iki kez işlem yapıldığında abone hangisinin geçerli olduğunu ancak
/// zamana bakarak anlar.
@override final  DateTime? createdAt;

/// Create a copy of SubscriptionException
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubscriptionExceptionCopyWith<_SubscriptionException> get copyWith => __$SubscriptionExceptionCopyWithImpl<_SubscriptionException>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SubscriptionExceptionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SubscriptionException&&(identical(other.serviceDate, serviceDate) || other.serviceDate == serviceDate)&&(identical(other.skip, skip) || other.skip == skip)&&(identical(other.quantityOverride, quantityOverride) || other.quantityOverride == quantityOverride)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,serviceDate,skip,quantityOverride,createdAt);

@override
String toString() {
  return 'SubscriptionException(serviceDate: $serviceDate, skip: $skip, quantityOverride: $quantityOverride, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$SubscriptionExceptionCopyWith<$Res> implements $SubscriptionExceptionCopyWith<$Res> {
  factory _$SubscriptionExceptionCopyWith(_SubscriptionException value, $Res Function(_SubscriptionException) _then) = __$SubscriptionExceptionCopyWithImpl;
@override @useResult
$Res call({
 String serviceDate, bool skip, int? quantityOverride, DateTime? createdAt
});




}
/// @nodoc
class __$SubscriptionExceptionCopyWithImpl<$Res>
    implements _$SubscriptionExceptionCopyWith<$Res> {
  __$SubscriptionExceptionCopyWithImpl(this._self, this._then);

  final _SubscriptionException _self;
  final $Res Function(_SubscriptionException) _then;

/// Create a copy of SubscriptionException
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? serviceDate = null,Object? skip = null,Object? quantityOverride = freezed,Object? createdAt = freezed,}) {
  return _then(_SubscriptionException(
serviceDate: null == serviceDate ? _self.serviceDate : serviceDate // ignore: cast_nullable_to_non_nullable
as String,skip: null == skip ? _self.skip : skip // ignore: cast_nullable_to_non_nullable
as bool,quantityOverride: freezed == quantityOverride ? _self.quantityOverride : quantityOverride // ignore: cast_nullable_to_non_nullable
as int?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$SubscriptionPaymentSummary {

/// Ödeme dönemi, `YYYY-AA` (Europe/Istanbul takvim ayı). **Gün taşımaz:**
/// dönem bir aydır, bir tarih değil.
 String get period;/// Dönem tutarı (kuruş). **Sunucu hesaplar** — servis günü sayısı ×
/// porsiyon × anlaşmalı birim fiyat, atlanan günler düşülmüş hâlde.
/// İstemci bu çarpımı tekrarlamaz; atlanan gün kuralını iki yerde
/// tutmak, iki farklı tutar göstermenin en kısa yoludur.
 int get amount; String get currency;@PaymentStatusConverter() PaymentStatus get status;/// Ödeme kaydının kimliği; henüz ödeme başlatılmadıysa `null`. `null` ile
/// `0` karıştırılmaz — `0` diye bir kayıt yoktur.
 int? get paymentId;/// Son ödeme günü, `YYYY-AA-GG` (Europe/Istanbul); tanımlı değilse `null`.
/// Tarih olarak veriliyor, an olarak değil: "ayın 5'i" bir gün adıdır ve
/// saat dilimi tartışması yaratmaz.
 String? get dueDate;
/// Create a copy of SubscriptionPaymentSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubscriptionPaymentSummaryCopyWith<SubscriptionPaymentSummary> get copyWith => _$SubscriptionPaymentSummaryCopyWithImpl<SubscriptionPaymentSummary>(this as SubscriptionPaymentSummary, _$identity);

  /// Serializes this SubscriptionPaymentSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionPaymentSummary&&(identical(other.period, period) || other.period == period)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.status, status) || other.status == status)&&(identical(other.paymentId, paymentId) || other.paymentId == paymentId)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,period,amount,currency,status,paymentId,dueDate);

@override
String toString() {
  return 'SubscriptionPaymentSummary(period: $period, amount: $amount, currency: $currency, status: $status, paymentId: $paymentId, dueDate: $dueDate)';
}


}

/// @nodoc
abstract mixin class $SubscriptionPaymentSummaryCopyWith<$Res>  {
  factory $SubscriptionPaymentSummaryCopyWith(SubscriptionPaymentSummary value, $Res Function(SubscriptionPaymentSummary) _then) = _$SubscriptionPaymentSummaryCopyWithImpl;
@useResult
$Res call({
 String period, int amount, String currency,@PaymentStatusConverter() PaymentStatus status, int? paymentId, String? dueDate
});




}
/// @nodoc
class _$SubscriptionPaymentSummaryCopyWithImpl<$Res>
    implements $SubscriptionPaymentSummaryCopyWith<$Res> {
  _$SubscriptionPaymentSummaryCopyWithImpl(this._self, this._then);

  final SubscriptionPaymentSummary _self;
  final $Res Function(SubscriptionPaymentSummary) _then;

/// Create a copy of SubscriptionPaymentSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? period = null,Object? amount = null,Object? currency = null,Object? status = null,Object? paymentId = freezed,Object? dueDate = freezed,}) {
  return _then(_self.copyWith(
period: null == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PaymentStatus,paymentId: freezed == paymentId ? _self.paymentId : paymentId // ignore: cast_nullable_to_non_nullable
as int?,dueDate: freezed == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SubscriptionPaymentSummary].
extension SubscriptionPaymentSummaryPatterns on SubscriptionPaymentSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SubscriptionPaymentSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SubscriptionPaymentSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SubscriptionPaymentSummary value)  $default,){
final _that = this;
switch (_that) {
case _SubscriptionPaymentSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SubscriptionPaymentSummary value)?  $default,){
final _that = this;
switch (_that) {
case _SubscriptionPaymentSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String period,  int amount,  String currency, @PaymentStatusConverter()  PaymentStatus status,  int? paymentId,  String? dueDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SubscriptionPaymentSummary() when $default != null:
return $default(_that.period,_that.amount,_that.currency,_that.status,_that.paymentId,_that.dueDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String period,  int amount,  String currency, @PaymentStatusConverter()  PaymentStatus status,  int? paymentId,  String? dueDate)  $default,) {final _that = this;
switch (_that) {
case _SubscriptionPaymentSummary():
return $default(_that.period,_that.amount,_that.currency,_that.status,_that.paymentId,_that.dueDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String period,  int amount,  String currency, @PaymentStatusConverter()  PaymentStatus status,  int? paymentId,  String? dueDate)?  $default,) {final _that = this;
switch (_that) {
case _SubscriptionPaymentSummary() when $default != null:
return $default(_that.period,_that.amount,_that.currency,_that.status,_that.paymentId,_that.dueDate);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SubscriptionPaymentSummary extends SubscriptionPaymentSummary {
  const _SubscriptionPaymentSummary({required this.period, required this.amount, required this.currency, @PaymentStatusConverter() required this.status, this.paymentId, this.dueDate}): super._();
  factory _SubscriptionPaymentSummary.fromJson(Map<String, dynamic> json) => _$SubscriptionPaymentSummaryFromJson(json);

/// Ödeme dönemi, `YYYY-AA` (Europe/Istanbul takvim ayı). **Gün taşımaz:**
/// dönem bir aydır, bir tarih değil.
@override final  String period;
/// Dönem tutarı (kuruş). **Sunucu hesaplar** — servis günü sayısı ×
/// porsiyon × anlaşmalı birim fiyat, atlanan günler düşülmüş hâlde.
/// İstemci bu çarpımı tekrarlamaz; atlanan gün kuralını iki yerde
/// tutmak, iki farklı tutar göstermenin en kısa yoludur.
@override final  int amount;
@override final  String currency;
@override@PaymentStatusConverter() final  PaymentStatus status;
/// Ödeme kaydının kimliği; henüz ödeme başlatılmadıysa `null`. `null` ile
/// `0` karıştırılmaz — `0` diye bir kayıt yoktur.
@override final  int? paymentId;
/// Son ödeme günü, `YYYY-AA-GG` (Europe/Istanbul); tanımlı değilse `null`.
/// Tarih olarak veriliyor, an olarak değil: "ayın 5'i" bir gün adıdır ve
/// saat dilimi tartışması yaratmaz.
@override final  String? dueDate;

/// Create a copy of SubscriptionPaymentSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubscriptionPaymentSummaryCopyWith<_SubscriptionPaymentSummary> get copyWith => __$SubscriptionPaymentSummaryCopyWithImpl<_SubscriptionPaymentSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SubscriptionPaymentSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SubscriptionPaymentSummary&&(identical(other.period, period) || other.period == period)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.status, status) || other.status == status)&&(identical(other.paymentId, paymentId) || other.paymentId == paymentId)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,period,amount,currency,status,paymentId,dueDate);

@override
String toString() {
  return 'SubscriptionPaymentSummary(period: $period, amount: $amount, currency: $currency, status: $status, paymentId: $paymentId, dueDate: $dueDate)';
}


}

/// @nodoc
abstract mixin class _$SubscriptionPaymentSummaryCopyWith<$Res> implements $SubscriptionPaymentSummaryCopyWith<$Res> {
  factory _$SubscriptionPaymentSummaryCopyWith(_SubscriptionPaymentSummary value, $Res Function(_SubscriptionPaymentSummary) _then) = __$SubscriptionPaymentSummaryCopyWithImpl;
@override @useResult
$Res call({
 String period, int amount, String currency,@PaymentStatusConverter() PaymentStatus status, int? paymentId, String? dueDate
});




}
/// @nodoc
class __$SubscriptionPaymentSummaryCopyWithImpl<$Res>
    implements _$SubscriptionPaymentSummaryCopyWith<$Res> {
  __$SubscriptionPaymentSummaryCopyWithImpl(this._self, this._then);

  final _SubscriptionPaymentSummary _self;
  final $Res Function(_SubscriptionPaymentSummary) _then;

/// Create a copy of SubscriptionPaymentSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? period = null,Object? amount = null,Object? currency = null,Object? status = null,Object? paymentId = freezed,Object? dueDate = freezed,}) {
  return _then(_SubscriptionPaymentSummary(
period: null == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PaymentStatus,paymentId: freezed == paymentId ? _self.paymentId : paymentId // ignore: cast_nullable_to_non_nullable
as int?,dueDate: freezed == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$SubscriptionContractSummary {

/// `draft` | `sent` | `approved` | `expired` | `cancelled`.
 String get status;/// Sözleşme metninin sürümü. Fiyat ya da koşul değişince yeni bir sürüm
/// üretilir ve **yeniden onay** istenir.
 int? get version;/// Bağlantının SMS ile gönderildiği an.
 DateTime? get sentAt;/// Abonenin SMS koduyla onayladığı an; onaylanmadıysa `null`.
 DateTime? get approvedAt;
/// Create a copy of SubscriptionContractSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubscriptionContractSummaryCopyWith<SubscriptionContractSummary> get copyWith => _$SubscriptionContractSummaryCopyWithImpl<SubscriptionContractSummary>(this as SubscriptionContractSummary, _$identity);

  /// Serializes this SubscriptionContractSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionContractSummary&&(identical(other.status, status) || other.status == status)&&(identical(other.version, version) || other.version == version)&&(identical(other.sentAt, sentAt) || other.sentAt == sentAt)&&(identical(other.approvedAt, approvedAt) || other.approvedAt == approvedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,version,sentAt,approvedAt);

@override
String toString() {
  return 'SubscriptionContractSummary(status: $status, version: $version, sentAt: $sentAt, approvedAt: $approvedAt)';
}


}

/// @nodoc
abstract mixin class $SubscriptionContractSummaryCopyWith<$Res>  {
  factory $SubscriptionContractSummaryCopyWith(SubscriptionContractSummary value, $Res Function(SubscriptionContractSummary) _then) = _$SubscriptionContractSummaryCopyWithImpl;
@useResult
$Res call({
 String status, int? version, DateTime? sentAt, DateTime? approvedAt
});




}
/// @nodoc
class _$SubscriptionContractSummaryCopyWithImpl<$Res>
    implements $SubscriptionContractSummaryCopyWith<$Res> {
  _$SubscriptionContractSummaryCopyWithImpl(this._self, this._then);

  final SubscriptionContractSummary _self;
  final $Res Function(SubscriptionContractSummary) _then;

/// Create a copy of SubscriptionContractSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? version = freezed,Object? sentAt = freezed,Object? approvedAt = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int?,sentAt: freezed == sentAt ? _self.sentAt : sentAt // ignore: cast_nullable_to_non_nullable
as DateTime?,approvedAt: freezed == approvedAt ? _self.approvedAt : approvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [SubscriptionContractSummary].
extension SubscriptionContractSummaryPatterns on SubscriptionContractSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SubscriptionContractSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SubscriptionContractSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SubscriptionContractSummary value)  $default,){
final _that = this;
switch (_that) {
case _SubscriptionContractSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SubscriptionContractSummary value)?  $default,){
final _that = this;
switch (_that) {
case _SubscriptionContractSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String status,  int? version,  DateTime? sentAt,  DateTime? approvedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SubscriptionContractSummary() when $default != null:
return $default(_that.status,_that.version,_that.sentAt,_that.approvedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String status,  int? version,  DateTime? sentAt,  DateTime? approvedAt)  $default,) {final _that = this;
switch (_that) {
case _SubscriptionContractSummary():
return $default(_that.status,_that.version,_that.sentAt,_that.approvedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String status,  int? version,  DateTime? sentAt,  DateTime? approvedAt)?  $default,) {final _that = this;
switch (_that) {
case _SubscriptionContractSummary() when $default != null:
return $default(_that.status,_that.version,_that.sentAt,_that.approvedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SubscriptionContractSummary extends SubscriptionContractSummary {
  const _SubscriptionContractSummary({required this.status, this.version, this.sentAt, this.approvedAt}): super._();
  factory _SubscriptionContractSummary.fromJson(Map<String, dynamic> json) => _$SubscriptionContractSummaryFromJson(json);

/// `draft` | `sent` | `approved` | `expired` | `cancelled`.
@override final  String status;
/// Sözleşme metninin sürümü. Fiyat ya da koşul değişince yeni bir sürüm
/// üretilir ve **yeniden onay** istenir.
@override final  int? version;
/// Bağlantının SMS ile gönderildiği an.
@override final  DateTime? sentAt;
/// Abonenin SMS koduyla onayladığı an; onaylanmadıysa `null`.
@override final  DateTime? approvedAt;

/// Create a copy of SubscriptionContractSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubscriptionContractSummaryCopyWith<_SubscriptionContractSummary> get copyWith => __$SubscriptionContractSummaryCopyWithImpl<_SubscriptionContractSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SubscriptionContractSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SubscriptionContractSummary&&(identical(other.status, status) || other.status == status)&&(identical(other.version, version) || other.version == version)&&(identical(other.sentAt, sentAt) || other.sentAt == sentAt)&&(identical(other.approvedAt, approvedAt) || other.approvedAt == approvedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,version,sentAt,approvedAt);

@override
String toString() {
  return 'SubscriptionContractSummary(status: $status, version: $version, sentAt: $sentAt, approvedAt: $approvedAt)';
}


}

/// @nodoc
abstract mixin class _$SubscriptionContractSummaryCopyWith<$Res> implements $SubscriptionContractSummaryCopyWith<$Res> {
  factory _$SubscriptionContractSummaryCopyWith(_SubscriptionContractSummary value, $Res Function(_SubscriptionContractSummary) _then) = __$SubscriptionContractSummaryCopyWithImpl;
@override @useResult
$Res call({
 String status, int? version, DateTime? sentAt, DateTime? approvedAt
});




}
/// @nodoc
class __$SubscriptionContractSummaryCopyWithImpl<$Res>
    implements _$SubscriptionContractSummaryCopyWith<$Res> {
  __$SubscriptionContractSummaryCopyWithImpl(this._self, this._then);

  final _SubscriptionContractSummary _self;
  final $Res Function(_SubscriptionContractSummary) _then;

/// Create a copy of SubscriptionContractSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? version = freezed,Object? sentAt = freezed,Object? approvedAt = freezed,}) {
  return _then(_SubscriptionContractSummary(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int?,sentAt: freezed == sentAt ? _self.sentAt : sentAt // ignore: cast_nullable_to_non_nullable
as DateTime?,approvedAt: freezed == approvedAt ? _self.approvedAt : approvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$SubscriptionContract {

/// `draft` | `sent` | `approved` | `expired` | `cancelled`.
///
/// Süresi dolmuş bağlantı `410` değil **`200` + `expired`** döner:
/// istemci "bu bağlantının süresi doldu, yenisini isteyin" cümlesini
/// kurabilmeli, boş bir hata sayfası görmemelidir.
 String get status; int get version;/// Sözleşme metninin tamamı.
 String get body;/// `markdown` | `plain`. Sunucudan **HTML gönderilmez**: metin panelde
/// yazılıyor ve doğrudan HTML gömmek sözleşme sayfasına script sokabilecek
/// bir kapı açardı. İstemci bu alanı bilmediği bir değerde görürse metni
/// DÜZ METİN gibi çizmelidir.
 String get bodyFormat;/// ISO hafta günleri (1 Pazartesi .. 7 Pazar).
 List<int> get serviceDays;/// Porsiyon başı anlaşmalı fiyat (kuruş).
 int get unitPrice; String get currency; String? get title;/// Sözleşmenin karşı tarafı — kurum unvanı ya da ad soyad. Onaylayan kişi
/// doğru sözleşmeye baktığını buradan anlar.
 String? get customerLabel;/// SMS kodunun gideceği numaranın **maskeli** hâli ("0555 *** ** 33").
///
/// Tamamı gösterilmez: bağlantı kimlik istemiyor ve tam numarayı basmak,
/// bağlantıyı ele geçirene doğrulanmış bir telefon numarası hediye etmek
/// olurdu.
 String? get maskedPhone;/// `YYYY-AA-GG`.
 String? get startDate; String? get endDate; int? get defaultQuantity;/// Tipik bir ayın tahmini tutarı (kuruş). Onaylayan kişi neyi imzaladığını
/// porsiyon fiyatından zihninde çarparak değil, yazılı bir rakamla
/// görmelidir.
 int? get monthlyEstimate;/// Bağlantının geçerlilik sonu; süresizse `null`.
 DateTime? get expiresAt; DateTime? get approvedAt;
/// Create a copy of SubscriptionContract
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubscriptionContractCopyWith<SubscriptionContract> get copyWith => _$SubscriptionContractCopyWithImpl<SubscriptionContract>(this as SubscriptionContract, _$identity);

  /// Serializes this SubscriptionContract to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionContract&&(identical(other.status, status) || other.status == status)&&(identical(other.version, version) || other.version == version)&&(identical(other.body, body) || other.body == body)&&(identical(other.bodyFormat, bodyFormat) || other.bodyFormat == bodyFormat)&&const DeepCollectionEquality().equals(other.serviceDays, serviceDays)&&(identical(other.unitPrice, unitPrice) || other.unitPrice == unitPrice)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.title, title) || other.title == title)&&(identical(other.customerLabel, customerLabel) || other.customerLabel == customerLabel)&&(identical(other.maskedPhone, maskedPhone) || other.maskedPhone == maskedPhone)&&(identical(other.startDate, startDate) || other.startDate == startDate)&&(identical(other.endDate, endDate) || other.endDate == endDate)&&(identical(other.defaultQuantity, defaultQuantity) || other.defaultQuantity == defaultQuantity)&&(identical(other.monthlyEstimate, monthlyEstimate) || other.monthlyEstimate == monthlyEstimate)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.approvedAt, approvedAt) || other.approvedAt == approvedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,version,body,bodyFormat,const DeepCollectionEquality().hash(serviceDays),unitPrice,currency,title,customerLabel,maskedPhone,startDate,endDate,defaultQuantity,monthlyEstimate,expiresAt,approvedAt);

@override
String toString() {
  return 'SubscriptionContract(status: $status, version: $version, body: $body, bodyFormat: $bodyFormat, serviceDays: $serviceDays, unitPrice: $unitPrice, currency: $currency, title: $title, customerLabel: $customerLabel, maskedPhone: $maskedPhone, startDate: $startDate, endDate: $endDate, defaultQuantity: $defaultQuantity, monthlyEstimate: $monthlyEstimate, expiresAt: $expiresAt, approvedAt: $approvedAt)';
}


}

/// @nodoc
abstract mixin class $SubscriptionContractCopyWith<$Res>  {
  factory $SubscriptionContractCopyWith(SubscriptionContract value, $Res Function(SubscriptionContract) _then) = _$SubscriptionContractCopyWithImpl;
@useResult
$Res call({
 String status, int version, String body, String bodyFormat, List<int> serviceDays, int unitPrice, String currency, String? title, String? customerLabel, String? maskedPhone, String? startDate, String? endDate, int? defaultQuantity, int? monthlyEstimate, DateTime? expiresAt, DateTime? approvedAt
});




}
/// @nodoc
class _$SubscriptionContractCopyWithImpl<$Res>
    implements $SubscriptionContractCopyWith<$Res> {
  _$SubscriptionContractCopyWithImpl(this._self, this._then);

  final SubscriptionContract _self;
  final $Res Function(SubscriptionContract) _then;

/// Create a copy of SubscriptionContract
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? version = null,Object? body = null,Object? bodyFormat = null,Object? serviceDays = null,Object? unitPrice = null,Object? currency = null,Object? title = freezed,Object? customerLabel = freezed,Object? maskedPhone = freezed,Object? startDate = freezed,Object? endDate = freezed,Object? defaultQuantity = freezed,Object? monthlyEstimate = freezed,Object? expiresAt = freezed,Object? approvedAt = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,bodyFormat: null == bodyFormat ? _self.bodyFormat : bodyFormat // ignore: cast_nullable_to_non_nullable
as String,serviceDays: null == serviceDays ? _self.serviceDays : serviceDays // ignore: cast_nullable_to_non_nullable
as List<int>,unitPrice: null == unitPrice ? _self.unitPrice : unitPrice // ignore: cast_nullable_to_non_nullable
as int,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,customerLabel: freezed == customerLabel ? _self.customerLabel : customerLabel // ignore: cast_nullable_to_non_nullable
as String?,maskedPhone: freezed == maskedPhone ? _self.maskedPhone : maskedPhone // ignore: cast_nullable_to_non_nullable
as String?,startDate: freezed == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as String?,endDate: freezed == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as String?,defaultQuantity: freezed == defaultQuantity ? _self.defaultQuantity : defaultQuantity // ignore: cast_nullable_to_non_nullable
as int?,monthlyEstimate: freezed == monthlyEstimate ? _self.monthlyEstimate : monthlyEstimate // ignore: cast_nullable_to_non_nullable
as int?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,approvedAt: freezed == approvedAt ? _self.approvedAt : approvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [SubscriptionContract].
extension SubscriptionContractPatterns on SubscriptionContract {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SubscriptionContract value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SubscriptionContract() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SubscriptionContract value)  $default,){
final _that = this;
switch (_that) {
case _SubscriptionContract():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SubscriptionContract value)?  $default,){
final _that = this;
switch (_that) {
case _SubscriptionContract() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String status,  int version,  String body,  String bodyFormat,  List<int> serviceDays,  int unitPrice,  String currency,  String? title,  String? customerLabel,  String? maskedPhone,  String? startDate,  String? endDate,  int? defaultQuantity,  int? monthlyEstimate,  DateTime? expiresAt,  DateTime? approvedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SubscriptionContract() when $default != null:
return $default(_that.status,_that.version,_that.body,_that.bodyFormat,_that.serviceDays,_that.unitPrice,_that.currency,_that.title,_that.customerLabel,_that.maskedPhone,_that.startDate,_that.endDate,_that.defaultQuantity,_that.monthlyEstimate,_that.expiresAt,_that.approvedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String status,  int version,  String body,  String bodyFormat,  List<int> serviceDays,  int unitPrice,  String currency,  String? title,  String? customerLabel,  String? maskedPhone,  String? startDate,  String? endDate,  int? defaultQuantity,  int? monthlyEstimate,  DateTime? expiresAt,  DateTime? approvedAt)  $default,) {final _that = this;
switch (_that) {
case _SubscriptionContract():
return $default(_that.status,_that.version,_that.body,_that.bodyFormat,_that.serviceDays,_that.unitPrice,_that.currency,_that.title,_that.customerLabel,_that.maskedPhone,_that.startDate,_that.endDate,_that.defaultQuantity,_that.monthlyEstimate,_that.expiresAt,_that.approvedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String status,  int version,  String body,  String bodyFormat,  List<int> serviceDays,  int unitPrice,  String currency,  String? title,  String? customerLabel,  String? maskedPhone,  String? startDate,  String? endDate,  int? defaultQuantity,  int? monthlyEstimate,  DateTime? expiresAt,  DateTime? approvedAt)?  $default,) {final _that = this;
switch (_that) {
case _SubscriptionContract() when $default != null:
return $default(_that.status,_that.version,_that.body,_that.bodyFormat,_that.serviceDays,_that.unitPrice,_that.currency,_that.title,_that.customerLabel,_that.maskedPhone,_that.startDate,_that.endDate,_that.defaultQuantity,_that.monthlyEstimate,_that.expiresAt,_that.approvedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SubscriptionContract extends SubscriptionContract {
  const _SubscriptionContract({required this.status, required this.version, required this.body, required this.bodyFormat, final  List<int> serviceDays = const <int>[], required this.unitPrice, required this.currency, this.title, this.customerLabel, this.maskedPhone, this.startDate, this.endDate, this.defaultQuantity, this.monthlyEstimate, this.expiresAt, this.approvedAt}): _serviceDays = serviceDays,super._();
  factory _SubscriptionContract.fromJson(Map<String, dynamic> json) => _$SubscriptionContractFromJson(json);

/// `draft` | `sent` | `approved` | `expired` | `cancelled`.
///
/// Süresi dolmuş bağlantı `410` değil **`200` + `expired`** döner:
/// istemci "bu bağlantının süresi doldu, yenisini isteyin" cümlesini
/// kurabilmeli, boş bir hata sayfası görmemelidir.
@override final  String status;
@override final  int version;
/// Sözleşme metninin tamamı.
@override final  String body;
/// `markdown` | `plain`. Sunucudan **HTML gönderilmez**: metin panelde
/// yazılıyor ve doğrudan HTML gömmek sözleşme sayfasına script sokabilecek
/// bir kapı açardı. İstemci bu alanı bilmediği bir değerde görürse metni
/// DÜZ METİN gibi çizmelidir.
@override final  String bodyFormat;
/// ISO hafta günleri (1 Pazartesi .. 7 Pazar).
 final  List<int> _serviceDays;
/// ISO hafta günleri (1 Pazartesi .. 7 Pazar).
@override@JsonKey() List<int> get serviceDays {
  if (_serviceDays is EqualUnmodifiableListView) return _serviceDays;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_serviceDays);
}

/// Porsiyon başı anlaşmalı fiyat (kuruş).
@override final  int unitPrice;
@override final  String currency;
@override final  String? title;
/// Sözleşmenin karşı tarafı — kurum unvanı ya da ad soyad. Onaylayan kişi
/// doğru sözleşmeye baktığını buradan anlar.
@override final  String? customerLabel;
/// SMS kodunun gideceği numaranın **maskeli** hâli ("0555 *** ** 33").
///
/// Tamamı gösterilmez: bağlantı kimlik istemiyor ve tam numarayı basmak,
/// bağlantıyı ele geçirene doğrulanmış bir telefon numarası hediye etmek
/// olurdu.
@override final  String? maskedPhone;
/// `YYYY-AA-GG`.
@override final  String? startDate;
@override final  String? endDate;
@override final  int? defaultQuantity;
/// Tipik bir ayın tahmini tutarı (kuruş). Onaylayan kişi neyi imzaladığını
/// porsiyon fiyatından zihninde çarparak değil, yazılı bir rakamla
/// görmelidir.
@override final  int? monthlyEstimate;
/// Bağlantının geçerlilik sonu; süresizse `null`.
@override final  DateTime? expiresAt;
@override final  DateTime? approvedAt;

/// Create a copy of SubscriptionContract
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubscriptionContractCopyWith<_SubscriptionContract> get copyWith => __$SubscriptionContractCopyWithImpl<_SubscriptionContract>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SubscriptionContractToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SubscriptionContract&&(identical(other.status, status) || other.status == status)&&(identical(other.version, version) || other.version == version)&&(identical(other.body, body) || other.body == body)&&(identical(other.bodyFormat, bodyFormat) || other.bodyFormat == bodyFormat)&&const DeepCollectionEquality().equals(other._serviceDays, _serviceDays)&&(identical(other.unitPrice, unitPrice) || other.unitPrice == unitPrice)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.title, title) || other.title == title)&&(identical(other.customerLabel, customerLabel) || other.customerLabel == customerLabel)&&(identical(other.maskedPhone, maskedPhone) || other.maskedPhone == maskedPhone)&&(identical(other.startDate, startDate) || other.startDate == startDate)&&(identical(other.endDate, endDate) || other.endDate == endDate)&&(identical(other.defaultQuantity, defaultQuantity) || other.defaultQuantity == defaultQuantity)&&(identical(other.monthlyEstimate, monthlyEstimate) || other.monthlyEstimate == monthlyEstimate)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.approvedAt, approvedAt) || other.approvedAt == approvedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,version,body,bodyFormat,const DeepCollectionEquality().hash(_serviceDays),unitPrice,currency,title,customerLabel,maskedPhone,startDate,endDate,defaultQuantity,monthlyEstimate,expiresAt,approvedAt);

@override
String toString() {
  return 'SubscriptionContract(status: $status, version: $version, body: $body, bodyFormat: $bodyFormat, serviceDays: $serviceDays, unitPrice: $unitPrice, currency: $currency, title: $title, customerLabel: $customerLabel, maskedPhone: $maskedPhone, startDate: $startDate, endDate: $endDate, defaultQuantity: $defaultQuantity, monthlyEstimate: $monthlyEstimate, expiresAt: $expiresAt, approvedAt: $approvedAt)';
}


}

/// @nodoc
abstract mixin class _$SubscriptionContractCopyWith<$Res> implements $SubscriptionContractCopyWith<$Res> {
  factory _$SubscriptionContractCopyWith(_SubscriptionContract value, $Res Function(_SubscriptionContract) _then) = __$SubscriptionContractCopyWithImpl;
@override @useResult
$Res call({
 String status, int version, String body, String bodyFormat, List<int> serviceDays, int unitPrice, String currency, String? title, String? customerLabel, String? maskedPhone, String? startDate, String? endDate, int? defaultQuantity, int? monthlyEstimate, DateTime? expiresAt, DateTime? approvedAt
});




}
/// @nodoc
class __$SubscriptionContractCopyWithImpl<$Res>
    implements _$SubscriptionContractCopyWith<$Res> {
  __$SubscriptionContractCopyWithImpl(this._self, this._then);

  final _SubscriptionContract _self;
  final $Res Function(_SubscriptionContract) _then;

/// Create a copy of SubscriptionContract
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? version = null,Object? body = null,Object? bodyFormat = null,Object? serviceDays = null,Object? unitPrice = null,Object? currency = null,Object? title = freezed,Object? customerLabel = freezed,Object? maskedPhone = freezed,Object? startDate = freezed,Object? endDate = freezed,Object? defaultQuantity = freezed,Object? monthlyEstimate = freezed,Object? expiresAt = freezed,Object? approvedAt = freezed,}) {
  return _then(_SubscriptionContract(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,bodyFormat: null == bodyFormat ? _self.bodyFormat : bodyFormat // ignore: cast_nullable_to_non_nullable
as String,serviceDays: null == serviceDays ? _self._serviceDays : serviceDays // ignore: cast_nullable_to_non_nullable
as List<int>,unitPrice: null == unitPrice ? _self.unitPrice : unitPrice // ignore: cast_nullable_to_non_nullable
as int,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,customerLabel: freezed == customerLabel ? _self.customerLabel : customerLabel // ignore: cast_nullable_to_non_nullable
as String?,maskedPhone: freezed == maskedPhone ? _self.maskedPhone : maskedPhone // ignore: cast_nullable_to_non_nullable
as String?,startDate: freezed == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as String?,endDate: freezed == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as String?,defaultQuantity: freezed == defaultQuantity ? _self.defaultQuantity : defaultQuantity // ignore: cast_nullable_to_non_nullable
as int?,monthlyEstimate: freezed == monthlyEstimate ? _self.monthlyEstimate : monthlyEstimate // ignore: cast_nullable_to_non_nullable
as int?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,approvedAt: freezed == approvedAt ? _self.approvedAt : approvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$SubscriptionPayment {

 int get paymentId; int get subscriptionId;/// `YYYY-AA` (Europe/Istanbul takvim ayı).
 String get period;/// Dönem tutarı (kuruş). Sunucu hesaplar; istekte GÖNDERİLMEZ.
 int get amount; String get currency;@PaymentStatusConverter() PaymentStatus get status;/// Sıradaki adım — gevşek enum, bkz. [PaymentNextAction].
@PaymentNextActionConverter() PaymentNextAction get nextAction; DateTime get createdAt;/// Yalnız `nextAction == threeDs` iken dolu. Ödeme kesinleştikten sonra
/// `null` döner — kullanıcı ikinci kez ödeme sayfasına gönderilmemelidir.
 String? get redirectUrl;/// Başarısız denemenin kullanıcıya gösterilebilir Türkçe sebebi ("Kart
/// limiti yetersiz."). Sağlayıcının ham hata kodu **dönmez**: müşteriye
/// bir şey anlatmıyor ve teşhis günlükte.
 String? get failureReason; DateTime? get paidAt;
/// Create a copy of SubscriptionPayment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubscriptionPaymentCopyWith<SubscriptionPayment> get copyWith => _$SubscriptionPaymentCopyWithImpl<SubscriptionPayment>(this as SubscriptionPayment, _$identity);

  /// Serializes this SubscriptionPayment to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionPayment&&(identical(other.paymentId, paymentId) || other.paymentId == paymentId)&&(identical(other.subscriptionId, subscriptionId) || other.subscriptionId == subscriptionId)&&(identical(other.period, period) || other.period == period)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.status, status) || other.status == status)&&(identical(other.nextAction, nextAction) || other.nextAction == nextAction)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.redirectUrl, redirectUrl) || other.redirectUrl == redirectUrl)&&(identical(other.failureReason, failureReason) || other.failureReason == failureReason)&&(identical(other.paidAt, paidAt) || other.paidAt == paidAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,paymentId,subscriptionId,period,amount,currency,status,nextAction,createdAt,redirectUrl,failureReason,paidAt);

@override
String toString() {
  return 'SubscriptionPayment(paymentId: $paymentId, subscriptionId: $subscriptionId, period: $period, amount: $amount, currency: $currency, status: $status, nextAction: $nextAction, createdAt: $createdAt, redirectUrl: $redirectUrl, failureReason: $failureReason, paidAt: $paidAt)';
}


}

/// @nodoc
abstract mixin class $SubscriptionPaymentCopyWith<$Res>  {
  factory $SubscriptionPaymentCopyWith(SubscriptionPayment value, $Res Function(SubscriptionPayment) _then) = _$SubscriptionPaymentCopyWithImpl;
@useResult
$Res call({
 int paymentId, int subscriptionId, String period, int amount, String currency,@PaymentStatusConverter() PaymentStatus status,@PaymentNextActionConverter() PaymentNextAction nextAction, DateTime createdAt, String? redirectUrl, String? failureReason, DateTime? paidAt
});




}
/// @nodoc
class _$SubscriptionPaymentCopyWithImpl<$Res>
    implements $SubscriptionPaymentCopyWith<$Res> {
  _$SubscriptionPaymentCopyWithImpl(this._self, this._then);

  final SubscriptionPayment _self;
  final $Res Function(SubscriptionPayment) _then;

/// Create a copy of SubscriptionPayment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? paymentId = null,Object? subscriptionId = null,Object? period = null,Object? amount = null,Object? currency = null,Object? status = null,Object? nextAction = null,Object? createdAt = null,Object? redirectUrl = freezed,Object? failureReason = freezed,Object? paidAt = freezed,}) {
  return _then(_self.copyWith(
paymentId: null == paymentId ? _self.paymentId : paymentId // ignore: cast_nullable_to_non_nullable
as int,subscriptionId: null == subscriptionId ? _self.subscriptionId : subscriptionId // ignore: cast_nullable_to_non_nullable
as int,period: null == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PaymentStatus,nextAction: null == nextAction ? _self.nextAction : nextAction // ignore: cast_nullable_to_non_nullable
as PaymentNextAction,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,redirectUrl: freezed == redirectUrl ? _self.redirectUrl : redirectUrl // ignore: cast_nullable_to_non_nullable
as String?,failureReason: freezed == failureReason ? _self.failureReason : failureReason // ignore: cast_nullable_to_non_nullable
as String?,paidAt: freezed == paidAt ? _self.paidAt : paidAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [SubscriptionPayment].
extension SubscriptionPaymentPatterns on SubscriptionPayment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SubscriptionPayment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SubscriptionPayment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SubscriptionPayment value)  $default,){
final _that = this;
switch (_that) {
case _SubscriptionPayment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SubscriptionPayment value)?  $default,){
final _that = this;
switch (_that) {
case _SubscriptionPayment() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int paymentId,  int subscriptionId,  String period,  int amount,  String currency, @PaymentStatusConverter()  PaymentStatus status, @PaymentNextActionConverter()  PaymentNextAction nextAction,  DateTime createdAt,  String? redirectUrl,  String? failureReason,  DateTime? paidAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SubscriptionPayment() when $default != null:
return $default(_that.paymentId,_that.subscriptionId,_that.period,_that.amount,_that.currency,_that.status,_that.nextAction,_that.createdAt,_that.redirectUrl,_that.failureReason,_that.paidAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int paymentId,  int subscriptionId,  String period,  int amount,  String currency, @PaymentStatusConverter()  PaymentStatus status, @PaymentNextActionConverter()  PaymentNextAction nextAction,  DateTime createdAt,  String? redirectUrl,  String? failureReason,  DateTime? paidAt)  $default,) {final _that = this;
switch (_that) {
case _SubscriptionPayment():
return $default(_that.paymentId,_that.subscriptionId,_that.period,_that.amount,_that.currency,_that.status,_that.nextAction,_that.createdAt,_that.redirectUrl,_that.failureReason,_that.paidAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int paymentId,  int subscriptionId,  String period,  int amount,  String currency, @PaymentStatusConverter()  PaymentStatus status, @PaymentNextActionConverter()  PaymentNextAction nextAction,  DateTime createdAt,  String? redirectUrl,  String? failureReason,  DateTime? paidAt)?  $default,) {final _that = this;
switch (_that) {
case _SubscriptionPayment() when $default != null:
return $default(_that.paymentId,_that.subscriptionId,_that.period,_that.amount,_that.currency,_that.status,_that.nextAction,_that.createdAt,_that.redirectUrl,_that.failureReason,_that.paidAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SubscriptionPayment extends SubscriptionPayment {
  const _SubscriptionPayment({required this.paymentId, required this.subscriptionId, required this.period, required this.amount, required this.currency, @PaymentStatusConverter() required this.status, @PaymentNextActionConverter() this.nextAction = PaymentNextAction.none, required this.createdAt, this.redirectUrl, this.failureReason, this.paidAt}): super._();
  factory _SubscriptionPayment.fromJson(Map<String, dynamic> json) => _$SubscriptionPaymentFromJson(json);

@override final  int paymentId;
@override final  int subscriptionId;
/// `YYYY-AA` (Europe/Istanbul takvim ayı).
@override final  String period;
/// Dönem tutarı (kuruş). Sunucu hesaplar; istekte GÖNDERİLMEZ.
@override final  int amount;
@override final  String currency;
@override@PaymentStatusConverter() final  PaymentStatus status;
/// Sıradaki adım — gevşek enum, bkz. [PaymentNextAction].
@override@JsonKey()@PaymentNextActionConverter() final  PaymentNextAction nextAction;
@override final  DateTime createdAt;
/// Yalnız `nextAction == threeDs` iken dolu. Ödeme kesinleştikten sonra
/// `null` döner — kullanıcı ikinci kez ödeme sayfasına gönderilmemelidir.
@override final  String? redirectUrl;
/// Başarısız denemenin kullanıcıya gösterilebilir Türkçe sebebi ("Kart
/// limiti yetersiz."). Sağlayıcının ham hata kodu **dönmez**: müşteriye
/// bir şey anlatmıyor ve teşhis günlükte.
@override final  String? failureReason;
@override final  DateTime? paidAt;

/// Create a copy of SubscriptionPayment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubscriptionPaymentCopyWith<_SubscriptionPayment> get copyWith => __$SubscriptionPaymentCopyWithImpl<_SubscriptionPayment>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SubscriptionPaymentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SubscriptionPayment&&(identical(other.paymentId, paymentId) || other.paymentId == paymentId)&&(identical(other.subscriptionId, subscriptionId) || other.subscriptionId == subscriptionId)&&(identical(other.period, period) || other.period == period)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.status, status) || other.status == status)&&(identical(other.nextAction, nextAction) || other.nextAction == nextAction)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.redirectUrl, redirectUrl) || other.redirectUrl == redirectUrl)&&(identical(other.failureReason, failureReason) || other.failureReason == failureReason)&&(identical(other.paidAt, paidAt) || other.paidAt == paidAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,paymentId,subscriptionId,period,amount,currency,status,nextAction,createdAt,redirectUrl,failureReason,paidAt);

@override
String toString() {
  return 'SubscriptionPayment(paymentId: $paymentId, subscriptionId: $subscriptionId, period: $period, amount: $amount, currency: $currency, status: $status, nextAction: $nextAction, createdAt: $createdAt, redirectUrl: $redirectUrl, failureReason: $failureReason, paidAt: $paidAt)';
}


}

/// @nodoc
abstract mixin class _$SubscriptionPaymentCopyWith<$Res> implements $SubscriptionPaymentCopyWith<$Res> {
  factory _$SubscriptionPaymentCopyWith(_SubscriptionPayment value, $Res Function(_SubscriptionPayment) _then) = __$SubscriptionPaymentCopyWithImpl;
@override @useResult
$Res call({
 int paymentId, int subscriptionId, String period, int amount, String currency,@PaymentStatusConverter() PaymentStatus status,@PaymentNextActionConverter() PaymentNextAction nextAction, DateTime createdAt, String? redirectUrl, String? failureReason, DateTime? paidAt
});




}
/// @nodoc
class __$SubscriptionPaymentCopyWithImpl<$Res>
    implements _$SubscriptionPaymentCopyWith<$Res> {
  __$SubscriptionPaymentCopyWithImpl(this._self, this._then);

  final _SubscriptionPayment _self;
  final $Res Function(_SubscriptionPayment) _then;

/// Create a copy of SubscriptionPayment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? paymentId = null,Object? subscriptionId = null,Object? period = null,Object? amount = null,Object? currency = null,Object? status = null,Object? nextAction = null,Object? createdAt = null,Object? redirectUrl = freezed,Object? failureReason = freezed,Object? paidAt = freezed,}) {
  return _then(_SubscriptionPayment(
paymentId: null == paymentId ? _self.paymentId : paymentId // ignore: cast_nullable_to_non_nullable
as int,subscriptionId: null == subscriptionId ? _self.subscriptionId : subscriptionId // ignore: cast_nullable_to_non_nullable
as int,period: null == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PaymentStatus,nextAction: null == nextAction ? _self.nextAction : nextAction // ignore: cast_nullable_to_non_nullable
as PaymentNextAction,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,redirectUrl: freezed == redirectUrl ? _self.redirectUrl : redirectUrl // ignore: cast_nullable_to_non_nullable
as String?,failureReason: freezed == failureReason ? _self.failureReason : failureReason // ignore: cast_nullable_to_non_nullable
as String?,paidAt: freezed == paidAt ? _self.paidAt : paidAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$Subscription {

 int get id;/// `pending` (talep, fiyatsız) | `awaiting_contract` | `awaiting_payment`
/// | `active` | `paused` | `cancelled`.
///
/// Ara iki durum 16.08.2026'da eklendi ve ayrı tutuldu çünkü ekranın
/// kuracağı cümle ayrı: birinde abonenin yapacağı iş sözleşmeyi okuyup
/// onaylamak, öbüründe ödemek. Tek bir `pending` altında toplansalardı
/// istemci "ne bekleniyor" sorusunu yanıtlayamaz, abone de hiçbir şey
/// yapmadan beklerdi.
///
/// **Bilinmeyen durum çökertmez** (düz `String`); ekran onu nötr bir
/// metinle gösterir ve eylem düğmelerini kapatır.
 String get status; int get locationId;@DeliveryTypeConverter() DeliveryType get deliveryType; DateTime get startDate; DateTime? get endDate;/// ISO hafta günleri (1 Pazartesi .. 7 Pazar).
 List<int> get serviceDays; String? get deliveryTimeFrom; String? get deliveryTimeTo; int get defaultQuantity;/// Porsiyon başı anlaşmalı fiyat (kuruş). Talepte `null`; admin belirler.
 int? get agreedUnitPrice;/// `prepaid_monthly` (peşin). `account` (ay sonu cari) **kullanımdan
/// kaldırıldı** (16.08.2026) ve yeni abonelikte dönmez; cutover öncesi
/// kayıtlar o değerle duruyor.
 String get paymentMode;/// `fixed_list` | `daily_menu`.
 String get menuMode; List<SubscriptionLine> get lines; List<SubscriptionDeliveryPoint> get deliveryPoints;/// Aboneliğin **tek-günlük istisnaları**: atlanan günler ve adedi
/// değiştirilen günler.
///
/// Yalnız **bugün ve sonrası** için girilmiş istisnalar döner. Geçmiş
/// istisnalar tabloda durur (yalnız-ekleme) ama listeye girmez: abonenin
/// ekranında üç aylık atlama geçmişi işe yaramaz ve yanıtı büyütür.
 List<SubscriptionException> get exceptions;/// **Yürürlükteki dönemin** ödeme durumu; henüz fiyatlanmamış talepte
/// `null`. Ödemenin geçmişi burada değildir.
 SubscriptionPaymentSummary? get payment;/// Sözleşmenin durumu; sözleşme henüz üretilmediyse `null`. Metnin kendisi
/// burada YOKTUR, imzalı bağlantının arkasındadır.
 SubscriptionContractSummary? get contract; DateTime get createdAt;
/// Create a copy of Subscription
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubscriptionCopyWith<Subscription> get copyWith => _$SubscriptionCopyWithImpl<Subscription>(this as Subscription, _$identity);

  /// Serializes this Subscription to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Subscription&&(identical(other.id, id) || other.id == id)&&(identical(other.status, status) || other.status == status)&&(identical(other.locationId, locationId) || other.locationId == locationId)&&(identical(other.deliveryType, deliveryType) || other.deliveryType == deliveryType)&&(identical(other.startDate, startDate) || other.startDate == startDate)&&(identical(other.endDate, endDate) || other.endDate == endDate)&&const DeepCollectionEquality().equals(other.serviceDays, serviceDays)&&(identical(other.deliveryTimeFrom, deliveryTimeFrom) || other.deliveryTimeFrom == deliveryTimeFrom)&&(identical(other.deliveryTimeTo, deliveryTimeTo) || other.deliveryTimeTo == deliveryTimeTo)&&(identical(other.defaultQuantity, defaultQuantity) || other.defaultQuantity == defaultQuantity)&&(identical(other.agreedUnitPrice, agreedUnitPrice) || other.agreedUnitPrice == agreedUnitPrice)&&(identical(other.paymentMode, paymentMode) || other.paymentMode == paymentMode)&&(identical(other.menuMode, menuMode) || other.menuMode == menuMode)&&const DeepCollectionEquality().equals(other.lines, lines)&&const DeepCollectionEquality().equals(other.deliveryPoints, deliveryPoints)&&const DeepCollectionEquality().equals(other.exceptions, exceptions)&&(identical(other.payment, payment) || other.payment == payment)&&(identical(other.contract, contract) || other.contract == contract)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,status,locationId,deliveryType,startDate,endDate,const DeepCollectionEquality().hash(serviceDays),deliveryTimeFrom,deliveryTimeTo,defaultQuantity,agreedUnitPrice,paymentMode,menuMode,const DeepCollectionEquality().hash(lines),const DeepCollectionEquality().hash(deliveryPoints),const DeepCollectionEquality().hash(exceptions),payment,contract,createdAt]);

@override
String toString() {
  return 'Subscription(id: $id, status: $status, locationId: $locationId, deliveryType: $deliveryType, startDate: $startDate, endDate: $endDate, serviceDays: $serviceDays, deliveryTimeFrom: $deliveryTimeFrom, deliveryTimeTo: $deliveryTimeTo, defaultQuantity: $defaultQuantity, agreedUnitPrice: $agreedUnitPrice, paymentMode: $paymentMode, menuMode: $menuMode, lines: $lines, deliveryPoints: $deliveryPoints, exceptions: $exceptions, payment: $payment, contract: $contract, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $SubscriptionCopyWith<$Res>  {
  factory $SubscriptionCopyWith(Subscription value, $Res Function(Subscription) _then) = _$SubscriptionCopyWithImpl;
@useResult
$Res call({
 int id, String status, int locationId,@DeliveryTypeConverter() DeliveryType deliveryType, DateTime startDate, DateTime? endDate, List<int> serviceDays, String? deliveryTimeFrom, String? deliveryTimeTo, int defaultQuantity, int? agreedUnitPrice, String paymentMode, String menuMode, List<SubscriptionLine> lines, List<SubscriptionDeliveryPoint> deliveryPoints, List<SubscriptionException> exceptions, SubscriptionPaymentSummary? payment, SubscriptionContractSummary? contract, DateTime createdAt
});


$SubscriptionPaymentSummaryCopyWith<$Res>? get payment;$SubscriptionContractSummaryCopyWith<$Res>? get contract;

}
/// @nodoc
class _$SubscriptionCopyWithImpl<$Res>
    implements $SubscriptionCopyWith<$Res> {
  _$SubscriptionCopyWithImpl(this._self, this._then);

  final Subscription _self;
  final $Res Function(Subscription) _then;

/// Create a copy of Subscription
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? status = null,Object? locationId = null,Object? deliveryType = null,Object? startDate = null,Object? endDate = freezed,Object? serviceDays = null,Object? deliveryTimeFrom = freezed,Object? deliveryTimeTo = freezed,Object? defaultQuantity = null,Object? agreedUnitPrice = freezed,Object? paymentMode = null,Object? menuMode = null,Object? lines = null,Object? deliveryPoints = null,Object? exceptions = null,Object? payment = freezed,Object? contract = freezed,Object? createdAt = null,}) {
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
as List<SubscriptionDeliveryPoint>,exceptions: null == exceptions ? _self.exceptions : exceptions // ignore: cast_nullable_to_non_nullable
as List<SubscriptionException>,payment: freezed == payment ? _self.payment : payment // ignore: cast_nullable_to_non_nullable
as SubscriptionPaymentSummary?,contract: freezed == contract ? _self.contract : contract // ignore: cast_nullable_to_non_nullable
as SubscriptionContractSummary?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of Subscription
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SubscriptionPaymentSummaryCopyWith<$Res>? get payment {
    if (_self.payment == null) {
    return null;
  }

  return $SubscriptionPaymentSummaryCopyWith<$Res>(_self.payment!, (value) {
    return _then(_self.copyWith(payment: value));
  });
}/// Create a copy of Subscription
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SubscriptionContractSummaryCopyWith<$Res>? get contract {
    if (_self.contract == null) {
    return null;
  }

  return $SubscriptionContractSummaryCopyWith<$Res>(_self.contract!, (value) {
    return _then(_self.copyWith(contract: value));
  });
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String status,  int locationId, @DeliveryTypeConverter()  DeliveryType deliveryType,  DateTime startDate,  DateTime? endDate,  List<int> serviceDays,  String? deliveryTimeFrom,  String? deliveryTimeTo,  int defaultQuantity,  int? agreedUnitPrice,  String paymentMode,  String menuMode,  List<SubscriptionLine> lines,  List<SubscriptionDeliveryPoint> deliveryPoints,  List<SubscriptionException> exceptions,  SubscriptionPaymentSummary? payment,  SubscriptionContractSummary? contract,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Subscription() when $default != null:
return $default(_that.id,_that.status,_that.locationId,_that.deliveryType,_that.startDate,_that.endDate,_that.serviceDays,_that.deliveryTimeFrom,_that.deliveryTimeTo,_that.defaultQuantity,_that.agreedUnitPrice,_that.paymentMode,_that.menuMode,_that.lines,_that.deliveryPoints,_that.exceptions,_that.payment,_that.contract,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String status,  int locationId, @DeliveryTypeConverter()  DeliveryType deliveryType,  DateTime startDate,  DateTime? endDate,  List<int> serviceDays,  String? deliveryTimeFrom,  String? deliveryTimeTo,  int defaultQuantity,  int? agreedUnitPrice,  String paymentMode,  String menuMode,  List<SubscriptionLine> lines,  List<SubscriptionDeliveryPoint> deliveryPoints,  List<SubscriptionException> exceptions,  SubscriptionPaymentSummary? payment,  SubscriptionContractSummary? contract,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _Subscription():
return $default(_that.id,_that.status,_that.locationId,_that.deliveryType,_that.startDate,_that.endDate,_that.serviceDays,_that.deliveryTimeFrom,_that.deliveryTimeTo,_that.defaultQuantity,_that.agreedUnitPrice,_that.paymentMode,_that.menuMode,_that.lines,_that.deliveryPoints,_that.exceptions,_that.payment,_that.contract,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String status,  int locationId, @DeliveryTypeConverter()  DeliveryType deliveryType,  DateTime startDate,  DateTime? endDate,  List<int> serviceDays,  String? deliveryTimeFrom,  String? deliveryTimeTo,  int defaultQuantity,  int? agreedUnitPrice,  String paymentMode,  String menuMode,  List<SubscriptionLine> lines,  List<SubscriptionDeliveryPoint> deliveryPoints,  List<SubscriptionException> exceptions,  SubscriptionPaymentSummary? payment,  SubscriptionContractSummary? contract,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Subscription() when $default != null:
return $default(_that.id,_that.status,_that.locationId,_that.deliveryType,_that.startDate,_that.endDate,_that.serviceDays,_that.deliveryTimeFrom,_that.deliveryTimeTo,_that.defaultQuantity,_that.agreedUnitPrice,_that.paymentMode,_that.menuMode,_that.lines,_that.deliveryPoints,_that.exceptions,_that.payment,_that.contract,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Subscription extends Subscription {
  const _Subscription({required this.id, required this.status, required this.locationId, @DeliveryTypeConverter() required this.deliveryType, required this.startDate, this.endDate, final  List<int> serviceDays = const <int>[], this.deliveryTimeFrom, this.deliveryTimeTo, required this.defaultQuantity, this.agreedUnitPrice, required this.paymentMode, required this.menuMode, final  List<SubscriptionLine> lines = const <SubscriptionLine>[], final  List<SubscriptionDeliveryPoint> deliveryPoints = const <SubscriptionDeliveryPoint>[], final  List<SubscriptionException> exceptions = const <SubscriptionException>[], this.payment, this.contract, required this.createdAt}): _serviceDays = serviceDays,_lines = lines,_deliveryPoints = deliveryPoints,_exceptions = exceptions,super._();
  factory _Subscription.fromJson(Map<String, dynamic> json) => _$SubscriptionFromJson(json);

@override final  int id;
/// `pending` (talep, fiyatsız) | `awaiting_contract` | `awaiting_payment`
/// | `active` | `paused` | `cancelled`.
///
/// Ara iki durum 16.08.2026'da eklendi ve ayrı tutuldu çünkü ekranın
/// kuracağı cümle ayrı: birinde abonenin yapacağı iş sözleşmeyi okuyup
/// onaylamak, öbüründe ödemek. Tek bir `pending` altında toplansalardı
/// istemci "ne bekleniyor" sorusunu yanıtlayamaz, abone de hiçbir şey
/// yapmadan beklerdi.
///
/// **Bilinmeyen durum çökertmez** (düz `String`); ekran onu nötr bir
/// metinle gösterir ve eylem düğmelerini kapatır.
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
/// `prepaid_monthly` (peşin). `account` (ay sonu cari) **kullanımdan
/// kaldırıldı** (16.08.2026) ve yeni abonelikte dönmez; cutover öncesi
/// kayıtlar o değerle duruyor.
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

/// Aboneliğin **tek-günlük istisnaları**: atlanan günler ve adedi
/// değiştirilen günler.
///
/// Yalnız **bugün ve sonrası** için girilmiş istisnalar döner. Geçmiş
/// istisnalar tabloda durur (yalnız-ekleme) ama listeye girmez: abonenin
/// ekranında üç aylık atlama geçmişi işe yaramaz ve yanıtı büyütür.
 final  List<SubscriptionException> _exceptions;
/// Aboneliğin **tek-günlük istisnaları**: atlanan günler ve adedi
/// değiştirilen günler.
///
/// Yalnız **bugün ve sonrası** için girilmiş istisnalar döner. Geçmiş
/// istisnalar tabloda durur (yalnız-ekleme) ama listeye girmez: abonenin
/// ekranında üç aylık atlama geçmişi işe yaramaz ve yanıtı büyütür.
@override@JsonKey() List<SubscriptionException> get exceptions {
  if (_exceptions is EqualUnmodifiableListView) return _exceptions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_exceptions);
}

/// **Yürürlükteki dönemin** ödeme durumu; henüz fiyatlanmamış talepte
/// `null`. Ödemenin geçmişi burada değildir.
@override final  SubscriptionPaymentSummary? payment;
/// Sözleşmenin durumu; sözleşme henüz üretilmediyse `null`. Metnin kendisi
/// burada YOKTUR, imzalı bağlantının arkasındadır.
@override final  SubscriptionContractSummary? contract;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Subscription&&(identical(other.id, id) || other.id == id)&&(identical(other.status, status) || other.status == status)&&(identical(other.locationId, locationId) || other.locationId == locationId)&&(identical(other.deliveryType, deliveryType) || other.deliveryType == deliveryType)&&(identical(other.startDate, startDate) || other.startDate == startDate)&&(identical(other.endDate, endDate) || other.endDate == endDate)&&const DeepCollectionEquality().equals(other._serviceDays, _serviceDays)&&(identical(other.deliveryTimeFrom, deliveryTimeFrom) || other.deliveryTimeFrom == deliveryTimeFrom)&&(identical(other.deliveryTimeTo, deliveryTimeTo) || other.deliveryTimeTo == deliveryTimeTo)&&(identical(other.defaultQuantity, defaultQuantity) || other.defaultQuantity == defaultQuantity)&&(identical(other.agreedUnitPrice, agreedUnitPrice) || other.agreedUnitPrice == agreedUnitPrice)&&(identical(other.paymentMode, paymentMode) || other.paymentMode == paymentMode)&&(identical(other.menuMode, menuMode) || other.menuMode == menuMode)&&const DeepCollectionEquality().equals(other._lines, _lines)&&const DeepCollectionEquality().equals(other._deliveryPoints, _deliveryPoints)&&const DeepCollectionEquality().equals(other._exceptions, _exceptions)&&(identical(other.payment, payment) || other.payment == payment)&&(identical(other.contract, contract) || other.contract == contract)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,status,locationId,deliveryType,startDate,endDate,const DeepCollectionEquality().hash(_serviceDays),deliveryTimeFrom,deliveryTimeTo,defaultQuantity,agreedUnitPrice,paymentMode,menuMode,const DeepCollectionEquality().hash(_lines),const DeepCollectionEquality().hash(_deliveryPoints),const DeepCollectionEquality().hash(_exceptions),payment,contract,createdAt]);

@override
String toString() {
  return 'Subscription(id: $id, status: $status, locationId: $locationId, deliveryType: $deliveryType, startDate: $startDate, endDate: $endDate, serviceDays: $serviceDays, deliveryTimeFrom: $deliveryTimeFrom, deliveryTimeTo: $deliveryTimeTo, defaultQuantity: $defaultQuantity, agreedUnitPrice: $agreedUnitPrice, paymentMode: $paymentMode, menuMode: $menuMode, lines: $lines, deliveryPoints: $deliveryPoints, exceptions: $exceptions, payment: $payment, contract: $contract, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$SubscriptionCopyWith<$Res> implements $SubscriptionCopyWith<$Res> {
  factory _$SubscriptionCopyWith(_Subscription value, $Res Function(_Subscription) _then) = __$SubscriptionCopyWithImpl;
@override @useResult
$Res call({
 int id, String status, int locationId,@DeliveryTypeConverter() DeliveryType deliveryType, DateTime startDate, DateTime? endDate, List<int> serviceDays, String? deliveryTimeFrom, String? deliveryTimeTo, int defaultQuantity, int? agreedUnitPrice, String paymentMode, String menuMode, List<SubscriptionLine> lines, List<SubscriptionDeliveryPoint> deliveryPoints, List<SubscriptionException> exceptions, SubscriptionPaymentSummary? payment, SubscriptionContractSummary? contract, DateTime createdAt
});


@override $SubscriptionPaymentSummaryCopyWith<$Res>? get payment;@override $SubscriptionContractSummaryCopyWith<$Res>? get contract;

}
/// @nodoc
class __$SubscriptionCopyWithImpl<$Res>
    implements _$SubscriptionCopyWith<$Res> {
  __$SubscriptionCopyWithImpl(this._self, this._then);

  final _Subscription _self;
  final $Res Function(_Subscription) _then;

/// Create a copy of Subscription
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? status = null,Object? locationId = null,Object? deliveryType = null,Object? startDate = null,Object? endDate = freezed,Object? serviceDays = null,Object? deliveryTimeFrom = freezed,Object? deliveryTimeTo = freezed,Object? defaultQuantity = null,Object? agreedUnitPrice = freezed,Object? paymentMode = null,Object? menuMode = null,Object? lines = null,Object? deliveryPoints = null,Object? exceptions = null,Object? payment = freezed,Object? contract = freezed,Object? createdAt = null,}) {
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
as List<SubscriptionDeliveryPoint>,exceptions: null == exceptions ? _self._exceptions : exceptions // ignore: cast_nullable_to_non_nullable
as List<SubscriptionException>,payment: freezed == payment ? _self.payment : payment // ignore: cast_nullable_to_non_nullable
as SubscriptionPaymentSummary?,contract: freezed == contract ? _self.contract : contract // ignore: cast_nullable_to_non_nullable
as SubscriptionContractSummary?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of Subscription
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SubscriptionPaymentSummaryCopyWith<$Res>? get payment {
    if (_self.payment == null) {
    return null;
  }

  return $SubscriptionPaymentSummaryCopyWith<$Res>(_self.payment!, (value) {
    return _then(_self.copyWith(payment: value));
  });
}/// Create a copy of Subscription
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SubscriptionContractSummaryCopyWith<$Res>? get contract {
    if (_self.contract == null) {
    return null;
  }

  return $SubscriptionContractSummaryCopyWith<$Res>(_self.contract!, (value) {
    return _then(_self.copyWith(contract: value));
  });
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
