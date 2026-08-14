// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cart_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CartLine {

 MenuItem get item; int get quantity;/// Seçilen `MenuOptionValue` kimlikleri. Sıra anlamlı değildir; kimlik
/// karşılaştırması [signature] üzerinden sıralı yapılır.
 List<int> get optionValueIds; String? get note;/// Bu satır GÜNÜN MENÜSÜ PAKETİ ise içindeki yemekler; değilse boş.
///
/// Yalnızca GÖSTERİM içindir: pakete tek bir `menu_id` ile sipariş
/// veriliyor ve içindekileri sunucu kendisi açıyor
/// (`OrderCreateItem.menuId`). Buradaki liste sepette "ne alıyorum"
/// sorusunu cevaplamak için duruyor — paketi satın alırken içindekileri
/// görmeyen müşteri sepeti ödeme ekranında terk ediyor.
///
/// İstek gövdesine GİRMEZ; [toOrderItem] onu okumaz.
 List<DailyMenuPackageComponent> get packageComponents;
/// Create a copy of CartLine
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CartLineCopyWith<CartLine> get copyWith => _$CartLineCopyWithImpl<CartLine>(this as CartLine, _$identity);

  /// Serializes this CartLine to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CartLine&&(identical(other.item, item) || other.item == item)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&const DeepCollectionEquality().equals(other.optionValueIds, optionValueIds)&&(identical(other.note, note) || other.note == note)&&const DeepCollectionEquality().equals(other.packageComponents, packageComponents));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,item,quantity,const DeepCollectionEquality().hash(optionValueIds),note,const DeepCollectionEquality().hash(packageComponents));

@override
String toString() {
  return 'CartLine(item: $item, quantity: $quantity, optionValueIds: $optionValueIds, note: $note, packageComponents: $packageComponents)';
}


}

/// @nodoc
abstract mixin class $CartLineCopyWith<$Res>  {
  factory $CartLineCopyWith(CartLine value, $Res Function(CartLine) _then) = _$CartLineCopyWithImpl;
@useResult
$Res call({
 MenuItem item, int quantity, List<int> optionValueIds, String? note, List<DailyMenuPackageComponent> packageComponents
});


$MenuItemCopyWith<$Res> get item;

}
/// @nodoc
class _$CartLineCopyWithImpl<$Res>
    implements $CartLineCopyWith<$Res> {
  _$CartLineCopyWithImpl(this._self, this._then);

  final CartLine _self;
  final $Res Function(CartLine) _then;

/// Create a copy of CartLine
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? item = null,Object? quantity = null,Object? optionValueIds = null,Object? note = freezed,Object? packageComponents = null,}) {
  return _then(_self.copyWith(
item: null == item ? _self.item : item // ignore: cast_nullable_to_non_nullable
as MenuItem,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,optionValueIds: null == optionValueIds ? _self.optionValueIds : optionValueIds // ignore: cast_nullable_to_non_nullable
as List<int>,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,packageComponents: null == packageComponents ? _self.packageComponents : packageComponents // ignore: cast_nullable_to_non_nullable
as List<DailyMenuPackageComponent>,
  ));
}
/// Create a copy of CartLine
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MenuItemCopyWith<$Res> get item {
  
  return $MenuItemCopyWith<$Res>(_self.item, (value) {
    return _then(_self.copyWith(item: value));
  });
}
}


/// Adds pattern-matching-related methods to [CartLine].
extension CartLinePatterns on CartLine {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CartLine value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CartLine() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CartLine value)  $default,){
final _that = this;
switch (_that) {
case _CartLine():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CartLine value)?  $default,){
final _that = this;
switch (_that) {
case _CartLine() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( MenuItem item,  int quantity,  List<int> optionValueIds,  String? note,  List<DailyMenuPackageComponent> packageComponents)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CartLine() when $default != null:
return $default(_that.item,_that.quantity,_that.optionValueIds,_that.note,_that.packageComponents);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( MenuItem item,  int quantity,  List<int> optionValueIds,  String? note,  List<DailyMenuPackageComponent> packageComponents)  $default,) {final _that = this;
switch (_that) {
case _CartLine():
return $default(_that.item,_that.quantity,_that.optionValueIds,_that.note,_that.packageComponents);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( MenuItem item,  int quantity,  List<int> optionValueIds,  String? note,  List<DailyMenuPackageComponent> packageComponents)?  $default,) {final _that = this;
switch (_that) {
case _CartLine() when $default != null:
return $default(_that.item,_that.quantity,_that.optionValueIds,_that.note,_that.packageComponents);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CartLine extends CartLine {
  const _CartLine({required this.item, required this.quantity, final  List<int> optionValueIds = const <int>[], this.note, final  List<DailyMenuPackageComponent> packageComponents = const <DailyMenuPackageComponent>[]}): _optionValueIds = optionValueIds,_packageComponents = packageComponents,super._();
  factory _CartLine.fromJson(Map<String, dynamic> json) => _$CartLineFromJson(json);

@override final  MenuItem item;
@override final  int quantity;
/// Seçilen `MenuOptionValue` kimlikleri. Sıra anlamlı değildir; kimlik
/// karşılaştırması [signature] üzerinden sıralı yapılır.
 final  List<int> _optionValueIds;
/// Seçilen `MenuOptionValue` kimlikleri. Sıra anlamlı değildir; kimlik
/// karşılaştırması [signature] üzerinden sıralı yapılır.
@override@JsonKey() List<int> get optionValueIds {
  if (_optionValueIds is EqualUnmodifiableListView) return _optionValueIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_optionValueIds);
}

@override final  String? note;
/// Bu satır GÜNÜN MENÜSÜ PAKETİ ise içindeki yemekler; değilse boş.
///
/// Yalnızca GÖSTERİM içindir: pakete tek bir `menu_id` ile sipariş
/// veriliyor ve içindekileri sunucu kendisi açıyor
/// (`OrderCreateItem.menuId`). Buradaki liste sepette "ne alıyorum"
/// sorusunu cevaplamak için duruyor — paketi satın alırken içindekileri
/// görmeyen müşteri sepeti ödeme ekranında terk ediyor.
///
/// İstek gövdesine GİRMEZ; [toOrderItem] onu okumaz.
 final  List<DailyMenuPackageComponent> _packageComponents;
/// Bu satır GÜNÜN MENÜSÜ PAKETİ ise içindeki yemekler; değilse boş.
///
/// Yalnızca GÖSTERİM içindir: pakete tek bir `menu_id` ile sipariş
/// veriliyor ve içindekileri sunucu kendisi açıyor
/// (`OrderCreateItem.menuId`). Buradaki liste sepette "ne alıyorum"
/// sorusunu cevaplamak için duruyor — paketi satın alırken içindekileri
/// görmeyen müşteri sepeti ödeme ekranında terk ediyor.
///
/// İstek gövdesine GİRMEZ; [toOrderItem] onu okumaz.
@override@JsonKey() List<DailyMenuPackageComponent> get packageComponents {
  if (_packageComponents is EqualUnmodifiableListView) return _packageComponents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_packageComponents);
}


/// Create a copy of CartLine
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CartLineCopyWith<_CartLine> get copyWith => __$CartLineCopyWithImpl<_CartLine>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CartLineToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CartLine&&(identical(other.item, item) || other.item == item)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&const DeepCollectionEquality().equals(other._optionValueIds, _optionValueIds)&&(identical(other.note, note) || other.note == note)&&const DeepCollectionEquality().equals(other._packageComponents, _packageComponents));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,item,quantity,const DeepCollectionEquality().hash(_optionValueIds),note,const DeepCollectionEquality().hash(_packageComponents));

@override
String toString() {
  return 'CartLine(item: $item, quantity: $quantity, optionValueIds: $optionValueIds, note: $note, packageComponents: $packageComponents)';
}


}

/// @nodoc
abstract mixin class _$CartLineCopyWith<$Res> implements $CartLineCopyWith<$Res> {
  factory _$CartLineCopyWith(_CartLine value, $Res Function(_CartLine) _then) = __$CartLineCopyWithImpl;
@override @useResult
$Res call({
 MenuItem item, int quantity, List<int> optionValueIds, String? note, List<DailyMenuPackageComponent> packageComponents
});


@override $MenuItemCopyWith<$Res> get item;

}
/// @nodoc
class __$CartLineCopyWithImpl<$Res>
    implements _$CartLineCopyWith<$Res> {
  __$CartLineCopyWithImpl(this._self, this._then);

  final _CartLine _self;
  final $Res Function(_CartLine) _then;

/// Create a copy of CartLine
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? item = null,Object? quantity = null,Object? optionValueIds = null,Object? note = freezed,Object? packageComponents = null,}) {
  return _then(_CartLine(
item: null == item ? _self.item : item // ignore: cast_nullable_to_non_nullable
as MenuItem,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,optionValueIds: null == optionValueIds ? _self._optionValueIds : optionValueIds // ignore: cast_nullable_to_non_nullable
as List<int>,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,packageComponents: null == packageComponents ? _self._packageComponents : packageComponents // ignore: cast_nullable_to_non_nullable
as List<DailyMenuPackageComponent>,
  ));
}

/// Create a copy of CartLine
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MenuItemCopyWith<$Res> get item {
  
  return $MenuItemCopyWith<$Res>(_self.item, (value) {
    return _then(_self.copyWith(item: value));
  });
}
}


/// @nodoc
mixin _$Cart {

 List<CartLine> get lines;/// Sepet hangi vitrine ait? Vitrin değişirse sepet sıfırlanır — sipariş tek
/// vitrine verilir (`OrderCreateRequest.location_id`).
 int? get locationId;/// Sepetin bağlı olduğu SERVİS GÜNÜ (`YYYY-AA-GG`, Europe/Istanbul).
///
/// Bir sipariş tek bir güne verilir (`OrderCreateRequest.service_date`):
/// perşembe menüsünden bir yemekle cuma menüsünden bir yemeği aynı fişe
/// koymak mutfağın karşılayamayacağı bir sipariş üretirdi. Bu yüzden gün
/// değiştiğinde sepet [locationId] ile aynı kuralla SIFIRLANIR.
///
/// `null` yalnızca boş sepette olur.
 String? get serviceDate;
/// Create a copy of Cart
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CartCopyWith<Cart> get copyWith => _$CartCopyWithImpl<Cart>(this as Cart, _$identity);

  /// Serializes this Cart to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Cart&&const DeepCollectionEquality().equals(other.lines, lines)&&(identical(other.locationId, locationId) || other.locationId == locationId)&&(identical(other.serviceDate, serviceDate) || other.serviceDate == serviceDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(lines),locationId,serviceDate);

@override
String toString() {
  return 'Cart(lines: $lines, locationId: $locationId, serviceDate: $serviceDate)';
}


}

/// @nodoc
abstract mixin class $CartCopyWith<$Res>  {
  factory $CartCopyWith(Cart value, $Res Function(Cart) _then) = _$CartCopyWithImpl;
@useResult
$Res call({
 List<CartLine> lines, int? locationId, String? serviceDate
});




}
/// @nodoc
class _$CartCopyWithImpl<$Res>
    implements $CartCopyWith<$Res> {
  _$CartCopyWithImpl(this._self, this._then);

  final Cart _self;
  final $Res Function(Cart) _then;

/// Create a copy of Cart
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? lines = null,Object? locationId = freezed,Object? serviceDate = freezed,}) {
  return _then(_self.copyWith(
lines: null == lines ? _self.lines : lines // ignore: cast_nullable_to_non_nullable
as List<CartLine>,locationId: freezed == locationId ? _self.locationId : locationId // ignore: cast_nullable_to_non_nullable
as int?,serviceDate: freezed == serviceDate ? _self.serviceDate : serviceDate // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Cart].
extension CartPatterns on Cart {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Cart value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Cart() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Cart value)  $default,){
final _that = this;
switch (_that) {
case _Cart():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Cart value)?  $default,){
final _that = this;
switch (_that) {
case _Cart() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<CartLine> lines,  int? locationId,  String? serviceDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Cart() when $default != null:
return $default(_that.lines,_that.locationId,_that.serviceDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<CartLine> lines,  int? locationId,  String? serviceDate)  $default,) {final _that = this;
switch (_that) {
case _Cart():
return $default(_that.lines,_that.locationId,_that.serviceDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<CartLine> lines,  int? locationId,  String? serviceDate)?  $default,) {final _that = this;
switch (_that) {
case _Cart() when $default != null:
return $default(_that.lines,_that.locationId,_that.serviceDate);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Cart extends Cart {
  const _Cart({final  List<CartLine> lines = const <CartLine>[], this.locationId, this.serviceDate}): _lines = lines,super._();
  factory _Cart.fromJson(Map<String, dynamic> json) => _$CartFromJson(json);

 final  List<CartLine> _lines;
@override@JsonKey() List<CartLine> get lines {
  if (_lines is EqualUnmodifiableListView) return _lines;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lines);
}

/// Sepet hangi vitrine ait? Vitrin değişirse sepet sıfırlanır — sipariş tek
/// vitrine verilir (`OrderCreateRequest.location_id`).
@override final  int? locationId;
/// Sepetin bağlı olduğu SERVİS GÜNÜ (`YYYY-AA-GG`, Europe/Istanbul).
///
/// Bir sipariş tek bir güne verilir (`OrderCreateRequest.service_date`):
/// perşembe menüsünden bir yemekle cuma menüsünden bir yemeği aynı fişe
/// koymak mutfağın karşılayamayacağı bir sipariş üretirdi. Bu yüzden gün
/// değiştiğinde sepet [locationId] ile aynı kuralla SIFIRLANIR.
///
/// `null` yalnızca boş sepette olur.
@override final  String? serviceDate;

/// Create a copy of Cart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CartCopyWith<_Cart> get copyWith => __$CartCopyWithImpl<_Cart>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CartToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Cart&&const DeepCollectionEquality().equals(other._lines, _lines)&&(identical(other.locationId, locationId) || other.locationId == locationId)&&(identical(other.serviceDate, serviceDate) || other.serviceDate == serviceDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_lines),locationId,serviceDate);

@override
String toString() {
  return 'Cart(lines: $lines, locationId: $locationId, serviceDate: $serviceDate)';
}


}

/// @nodoc
abstract mixin class _$CartCopyWith<$Res> implements $CartCopyWith<$Res> {
  factory _$CartCopyWith(_Cart value, $Res Function(_Cart) _then) = __$CartCopyWithImpl;
@override @useResult
$Res call({
 List<CartLine> lines, int? locationId, String? serviceDate
});




}
/// @nodoc
class __$CartCopyWithImpl<$Res>
    implements _$CartCopyWith<$Res> {
  __$CartCopyWithImpl(this._self, this._then);

  final _Cart _self;
  final $Res Function(_Cart) _then;

/// Create a copy of Cart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? lines = null,Object? locationId = freezed,Object? serviceDate = freezed,}) {
  return _then(_Cart(
lines: null == lines ? _self._lines : lines // ignore: cast_nullable_to_non_nullable
as List<CartLine>,locationId: freezed == locationId ? _self.locationId : locationId // ignore: cast_nullable_to_non_nullable
as int?,serviceDate: freezed == serviceDate ? _self.serviceDate : serviceDate // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
