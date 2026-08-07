// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'order.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Address {

 String get line1; String get district; String get city; String? get note;
/// Create a copy of Address
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AddressCopyWith<Address> get copyWith => _$AddressCopyWithImpl<Address>(this as Address, _$identity);

  /// Serializes this Address to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Address&&(identical(other.line1, line1) || other.line1 == line1)&&(identical(other.district, district) || other.district == district)&&(identical(other.city, city) || other.city == city)&&(identical(other.note, note) || other.note == note));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,line1,district,city,note);

@override
String toString() {
  return 'Address(line1: $line1, district: $district, city: $city, note: $note)';
}


}

/// @nodoc
abstract mixin class $AddressCopyWith<$Res>  {
  factory $AddressCopyWith(Address value, $Res Function(Address) _then) = _$AddressCopyWithImpl;
@useResult
$Res call({
 String line1, String district, String city, String? note
});




}
/// @nodoc
class _$AddressCopyWithImpl<$Res>
    implements $AddressCopyWith<$Res> {
  _$AddressCopyWithImpl(this._self, this._then);

  final Address _self;
  final $Res Function(Address) _then;

/// Create a copy of Address
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? line1 = null,Object? district = null,Object? city = null,Object? note = freezed,}) {
  return _then(_self.copyWith(
line1: null == line1 ? _self.line1 : line1 // ignore: cast_nullable_to_non_nullable
as String,district: null == district ? _self.district : district // ignore: cast_nullable_to_non_nullable
as String,city: null == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Address].
extension AddressPatterns on Address {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Address value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Address() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Address value)  $default,){
final _that = this;
switch (_that) {
case _Address():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Address value)?  $default,){
final _that = this;
switch (_that) {
case _Address() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String line1,  String district,  String city,  String? note)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Address() when $default != null:
return $default(_that.line1,_that.district,_that.city,_that.note);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String line1,  String district,  String city,  String? note)  $default,) {final _that = this;
switch (_that) {
case _Address():
return $default(_that.line1,_that.district,_that.city,_that.note);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String line1,  String district,  String city,  String? note)?  $default,) {final _that = this;
switch (_that) {
case _Address() when $default != null:
return $default(_that.line1,_that.district,_that.city,_that.note);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Address implements Address {
  const _Address({required this.line1, required this.district, required this.city, this.note});
  factory _Address.fromJson(Map<String, dynamic> json) => _$AddressFromJson(json);

@override final  String line1;
@override final  String district;
@override final  String city;
@override final  String? note;

/// Create a copy of Address
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AddressCopyWith<_Address> get copyWith => __$AddressCopyWithImpl<_Address>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AddressToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Address&&(identical(other.line1, line1) || other.line1 == line1)&&(identical(other.district, district) || other.district == district)&&(identical(other.city, city) || other.city == city)&&(identical(other.note, note) || other.note == note));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,line1,district,city,note);

@override
String toString() {
  return 'Address(line1: $line1, district: $district, city: $city, note: $note)';
}


}

/// @nodoc
abstract mixin class _$AddressCopyWith<$Res> implements $AddressCopyWith<$Res> {
  factory _$AddressCopyWith(_Address value, $Res Function(_Address) _then) = __$AddressCopyWithImpl;
@override @useResult
$Res call({
 String line1, String district, String city, String? note
});




}
/// @nodoc
class __$AddressCopyWithImpl<$Res>
    implements _$AddressCopyWith<$Res> {
  __$AddressCopyWithImpl(this._self, this._then);

  final _Address _self;
  final $Res Function(_Address) _then;

/// Create a copy of Address
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? line1 = null,Object? district = null,Object? city = null,Object? note = freezed,}) {
  return _then(_Address(
line1: null == line1 ? _self.line1 : line1 // ignore: cast_nullable_to_non_nullable
as String,district: null == district ? _self.district : district // ignore: cast_nullable_to_non_nullable
as String,city: null == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$SavedAddress {

 int get id; String get line1; String get district; String get city; bool get isDefault;/// Müşterinin verdiği ad — "Ev", "Ofis", "Şantiye".
 String? get label;/// Kuryeye not. Fişte görünür.
 String? get note;
/// Create a copy of SavedAddress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SavedAddressCopyWith<SavedAddress> get copyWith => _$SavedAddressCopyWithImpl<SavedAddress>(this as SavedAddress, _$identity);

  /// Serializes this SavedAddress to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SavedAddress&&(identical(other.id, id) || other.id == id)&&(identical(other.line1, line1) || other.line1 == line1)&&(identical(other.district, district) || other.district == district)&&(identical(other.city, city) || other.city == city)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault)&&(identical(other.label, label) || other.label == label)&&(identical(other.note, note) || other.note == note));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,line1,district,city,isDefault,label,note);

@override
String toString() {
  return 'SavedAddress(id: $id, line1: $line1, district: $district, city: $city, isDefault: $isDefault, label: $label, note: $note)';
}


}

/// @nodoc
abstract mixin class $SavedAddressCopyWith<$Res>  {
  factory $SavedAddressCopyWith(SavedAddress value, $Res Function(SavedAddress) _then) = _$SavedAddressCopyWithImpl;
@useResult
$Res call({
 int id, String line1, String district, String city, bool isDefault, String? label, String? note
});




}
/// @nodoc
class _$SavedAddressCopyWithImpl<$Res>
    implements $SavedAddressCopyWith<$Res> {
  _$SavedAddressCopyWithImpl(this._self, this._then);

  final SavedAddress _self;
  final $Res Function(SavedAddress) _then;

/// Create a copy of SavedAddress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? line1 = null,Object? district = null,Object? city = null,Object? isDefault = null,Object? label = freezed,Object? note = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,line1: null == line1 ? _self.line1 : line1 // ignore: cast_nullable_to_non_nullable
as String,district: null == district ? _self.district : district // ignore: cast_nullable_to_non_nullable
as String,city: null == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SavedAddress].
extension SavedAddressPatterns on SavedAddress {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SavedAddress value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SavedAddress() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SavedAddress value)  $default,){
final _that = this;
switch (_that) {
case _SavedAddress():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SavedAddress value)?  $default,){
final _that = this;
switch (_that) {
case _SavedAddress() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String line1,  String district,  String city,  bool isDefault,  String? label,  String? note)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SavedAddress() when $default != null:
return $default(_that.id,_that.line1,_that.district,_that.city,_that.isDefault,_that.label,_that.note);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String line1,  String district,  String city,  bool isDefault,  String? label,  String? note)  $default,) {final _that = this;
switch (_that) {
case _SavedAddress():
return $default(_that.id,_that.line1,_that.district,_that.city,_that.isDefault,_that.label,_that.note);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String line1,  String district,  String city,  bool isDefault,  String? label,  String? note)?  $default,) {final _that = this;
switch (_that) {
case _SavedAddress() when $default != null:
return $default(_that.id,_that.line1,_that.district,_that.city,_that.isDefault,_that.label,_that.note);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SavedAddress extends SavedAddress {
  const _SavedAddress({required this.id, required this.line1, required this.district, required this.city, required this.isDefault, this.label, this.note}): super._();
  factory _SavedAddress.fromJson(Map<String, dynamic> json) => _$SavedAddressFromJson(json);

@override final  int id;
@override final  String line1;
@override final  String district;
@override final  String city;
@override final  bool isDefault;
/// Müşterinin verdiği ad — "Ev", "Ofis", "Şantiye".
@override final  String? label;
/// Kuryeye not. Fişte görünür.
@override final  String? note;

/// Create a copy of SavedAddress
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SavedAddressCopyWith<_SavedAddress> get copyWith => __$SavedAddressCopyWithImpl<_SavedAddress>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SavedAddressToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SavedAddress&&(identical(other.id, id) || other.id == id)&&(identical(other.line1, line1) || other.line1 == line1)&&(identical(other.district, district) || other.district == district)&&(identical(other.city, city) || other.city == city)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault)&&(identical(other.label, label) || other.label == label)&&(identical(other.note, note) || other.note == note));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,line1,district,city,isDefault,label,note);

@override
String toString() {
  return 'SavedAddress(id: $id, line1: $line1, district: $district, city: $city, isDefault: $isDefault, label: $label, note: $note)';
}


}

/// @nodoc
abstract mixin class _$SavedAddressCopyWith<$Res> implements $SavedAddressCopyWith<$Res> {
  factory _$SavedAddressCopyWith(_SavedAddress value, $Res Function(_SavedAddress) _then) = __$SavedAddressCopyWithImpl;
@override @useResult
$Res call({
 int id, String line1, String district, String city, bool isDefault, String? label, String? note
});




}
/// @nodoc
class __$SavedAddressCopyWithImpl<$Res>
    implements _$SavedAddressCopyWith<$Res> {
  __$SavedAddressCopyWithImpl(this._self, this._then);

  final _SavedAddress _self;
  final $Res Function(_SavedAddress) _then;

/// Create a copy of SavedAddress
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? line1 = null,Object? district = null,Object? city = null,Object? isDefault = null,Object? label = freezed,Object? note = freezed,}) {
  return _then(_SavedAddress(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,line1: null == line1 ? _self.line1 : line1 // ignore: cast_nullable_to_non_nullable
as String,district: null == district ? _self.district : district // ignore: cast_nullable_to_non_nullable
as String,city: null == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$SavedAddressInput {

 String get line1; String get district; String get city; String? get label; String? get note; bool? get isDefault;
/// Create a copy of SavedAddressInput
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SavedAddressInputCopyWith<SavedAddressInput> get copyWith => _$SavedAddressInputCopyWithImpl<SavedAddressInput>(this as SavedAddressInput, _$identity);

  /// Serializes this SavedAddressInput to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SavedAddressInput&&(identical(other.line1, line1) || other.line1 == line1)&&(identical(other.district, district) || other.district == district)&&(identical(other.city, city) || other.city == city)&&(identical(other.label, label) || other.label == label)&&(identical(other.note, note) || other.note == note)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,line1,district,city,label,note,isDefault);

@override
String toString() {
  return 'SavedAddressInput(line1: $line1, district: $district, city: $city, label: $label, note: $note, isDefault: $isDefault)';
}


}

/// @nodoc
abstract mixin class $SavedAddressInputCopyWith<$Res>  {
  factory $SavedAddressInputCopyWith(SavedAddressInput value, $Res Function(SavedAddressInput) _then) = _$SavedAddressInputCopyWithImpl;
@useResult
$Res call({
 String line1, String district, String city, String? label, String? note, bool? isDefault
});




}
/// @nodoc
class _$SavedAddressInputCopyWithImpl<$Res>
    implements $SavedAddressInputCopyWith<$Res> {
  _$SavedAddressInputCopyWithImpl(this._self, this._then);

  final SavedAddressInput _self;
  final $Res Function(SavedAddressInput) _then;

/// Create a copy of SavedAddressInput
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? line1 = null,Object? district = null,Object? city = null,Object? label = freezed,Object? note = freezed,Object? isDefault = freezed,}) {
  return _then(_self.copyWith(
line1: null == line1 ? _self.line1 : line1 // ignore: cast_nullable_to_non_nullable
as String,district: null == district ? _self.district : district // ignore: cast_nullable_to_non_nullable
as String,city: null == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,isDefault: freezed == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}


/// Adds pattern-matching-related methods to [SavedAddressInput].
extension SavedAddressInputPatterns on SavedAddressInput {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SavedAddressInput value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SavedAddressInput() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SavedAddressInput value)  $default,){
final _that = this;
switch (_that) {
case _SavedAddressInput():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SavedAddressInput value)?  $default,){
final _that = this;
switch (_that) {
case _SavedAddressInput() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String line1,  String district,  String city,  String? label,  String? note,  bool? isDefault)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SavedAddressInput() when $default != null:
return $default(_that.line1,_that.district,_that.city,_that.label,_that.note,_that.isDefault);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String line1,  String district,  String city,  String? label,  String? note,  bool? isDefault)  $default,) {final _that = this;
switch (_that) {
case _SavedAddressInput():
return $default(_that.line1,_that.district,_that.city,_that.label,_that.note,_that.isDefault);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String line1,  String district,  String city,  String? label,  String? note,  bool? isDefault)?  $default,) {final _that = this;
switch (_that) {
case _SavedAddressInput() when $default != null:
return $default(_that.line1,_that.district,_that.city,_that.label,_that.note,_that.isDefault);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SavedAddressInput implements SavedAddressInput {
  const _SavedAddressInput({required this.line1, required this.district, required this.city, this.label, this.note, this.isDefault});
  factory _SavedAddressInput.fromJson(Map<String, dynamic> json) => _$SavedAddressInputFromJson(json);

@override final  String line1;
@override final  String district;
@override final  String city;
@override final  String? label;
@override final  String? note;
@override final  bool? isDefault;

/// Create a copy of SavedAddressInput
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SavedAddressInputCopyWith<_SavedAddressInput> get copyWith => __$SavedAddressInputCopyWithImpl<_SavedAddressInput>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SavedAddressInputToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SavedAddressInput&&(identical(other.line1, line1) || other.line1 == line1)&&(identical(other.district, district) || other.district == district)&&(identical(other.city, city) || other.city == city)&&(identical(other.label, label) || other.label == label)&&(identical(other.note, note) || other.note == note)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,line1,district,city,label,note,isDefault);

@override
String toString() {
  return 'SavedAddressInput(line1: $line1, district: $district, city: $city, label: $label, note: $note, isDefault: $isDefault)';
}


}

/// @nodoc
abstract mixin class _$SavedAddressInputCopyWith<$Res> implements $SavedAddressInputCopyWith<$Res> {
  factory _$SavedAddressInputCopyWith(_SavedAddressInput value, $Res Function(_SavedAddressInput) _then) = __$SavedAddressInputCopyWithImpl;
@override @useResult
$Res call({
 String line1, String district, String city, String? label, String? note, bool? isDefault
});




}
/// @nodoc
class __$SavedAddressInputCopyWithImpl<$Res>
    implements _$SavedAddressInputCopyWith<$Res> {
  __$SavedAddressInputCopyWithImpl(this._self, this._then);

  final _SavedAddressInput _self;
  final $Res Function(_SavedAddressInput) _then;

/// Create a copy of SavedAddressInput
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? line1 = null,Object? district = null,Object? city = null,Object? label = freezed,Object? note = freezed,Object? isDefault = freezed,}) {
  return _then(_SavedAddressInput(
line1: null == line1 ? _self.line1 : line1 // ignore: cast_nullable_to_non_nullable
as String,district: null == district ? _self.district : district // ignore: cast_nullable_to_non_nullable
as String,city: null == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,isDefault: freezed == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}


/// @nodoc
mixin _$OrderCreateItem {

 int get menuId; int get quantity; List<int> get optionValueIds; String? get note;
/// Create a copy of OrderCreateItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrderCreateItemCopyWith<OrderCreateItem> get copyWith => _$OrderCreateItemCopyWithImpl<OrderCreateItem>(this as OrderCreateItem, _$identity);

  /// Serializes this OrderCreateItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrderCreateItem&&(identical(other.menuId, menuId) || other.menuId == menuId)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&const DeepCollectionEquality().equals(other.optionValueIds, optionValueIds)&&(identical(other.note, note) || other.note == note));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,menuId,quantity,const DeepCollectionEquality().hash(optionValueIds),note);

@override
String toString() {
  return 'OrderCreateItem(menuId: $menuId, quantity: $quantity, optionValueIds: $optionValueIds, note: $note)';
}


}

/// @nodoc
abstract mixin class $OrderCreateItemCopyWith<$Res>  {
  factory $OrderCreateItemCopyWith(OrderCreateItem value, $Res Function(OrderCreateItem) _then) = _$OrderCreateItemCopyWithImpl;
@useResult
$Res call({
 int menuId, int quantity, List<int> optionValueIds, String? note
});




}
/// @nodoc
class _$OrderCreateItemCopyWithImpl<$Res>
    implements $OrderCreateItemCopyWith<$Res> {
  _$OrderCreateItemCopyWithImpl(this._self, this._then);

  final OrderCreateItem _self;
  final $Res Function(OrderCreateItem) _then;

/// Create a copy of OrderCreateItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? menuId = null,Object? quantity = null,Object? optionValueIds = null,Object? note = freezed,}) {
  return _then(_self.copyWith(
menuId: null == menuId ? _self.menuId : menuId // ignore: cast_nullable_to_non_nullable
as int,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,optionValueIds: null == optionValueIds ? _self.optionValueIds : optionValueIds // ignore: cast_nullable_to_non_nullable
as List<int>,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [OrderCreateItem].
extension OrderCreateItemPatterns on OrderCreateItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrderCreateItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrderCreateItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrderCreateItem value)  $default,){
final _that = this;
switch (_that) {
case _OrderCreateItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrderCreateItem value)?  $default,){
final _that = this;
switch (_that) {
case _OrderCreateItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int menuId,  int quantity,  List<int> optionValueIds,  String? note)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrderCreateItem() when $default != null:
return $default(_that.menuId,_that.quantity,_that.optionValueIds,_that.note);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int menuId,  int quantity,  List<int> optionValueIds,  String? note)  $default,) {final _that = this;
switch (_that) {
case _OrderCreateItem():
return $default(_that.menuId,_that.quantity,_that.optionValueIds,_that.note);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int menuId,  int quantity,  List<int> optionValueIds,  String? note)?  $default,) {final _that = this;
switch (_that) {
case _OrderCreateItem() when $default != null:
return $default(_that.menuId,_that.quantity,_that.optionValueIds,_that.note);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OrderCreateItem implements OrderCreateItem {
  const _OrderCreateItem({required this.menuId, required this.quantity, final  List<int> optionValueIds = const <int>[], this.note}): _optionValueIds = optionValueIds;
  factory _OrderCreateItem.fromJson(Map<String, dynamic> json) => _$OrderCreateItemFromJson(json);

@override final  int menuId;
@override final  int quantity;
 final  List<int> _optionValueIds;
@override@JsonKey() List<int> get optionValueIds {
  if (_optionValueIds is EqualUnmodifiableListView) return _optionValueIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_optionValueIds);
}

@override final  String? note;

/// Create a copy of OrderCreateItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrderCreateItemCopyWith<_OrderCreateItem> get copyWith => __$OrderCreateItemCopyWithImpl<_OrderCreateItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrderCreateItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrderCreateItem&&(identical(other.menuId, menuId) || other.menuId == menuId)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&const DeepCollectionEquality().equals(other._optionValueIds, _optionValueIds)&&(identical(other.note, note) || other.note == note));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,menuId,quantity,const DeepCollectionEquality().hash(_optionValueIds),note);

@override
String toString() {
  return 'OrderCreateItem(menuId: $menuId, quantity: $quantity, optionValueIds: $optionValueIds, note: $note)';
}


}

/// @nodoc
abstract mixin class _$OrderCreateItemCopyWith<$Res> implements $OrderCreateItemCopyWith<$Res> {
  factory _$OrderCreateItemCopyWith(_OrderCreateItem value, $Res Function(_OrderCreateItem) _then) = __$OrderCreateItemCopyWithImpl;
@override @useResult
$Res call({
 int menuId, int quantity, List<int> optionValueIds, String? note
});




}
/// @nodoc
class __$OrderCreateItemCopyWithImpl<$Res>
    implements _$OrderCreateItemCopyWith<$Res> {
  __$OrderCreateItemCopyWithImpl(this._self, this._then);

  final _OrderCreateItem _self;
  final $Res Function(_OrderCreateItem) _then;

/// Create a copy of OrderCreateItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? menuId = null,Object? quantity = null,Object? optionValueIds = null,Object? note = freezed,}) {
  return _then(_OrderCreateItem(
menuId: null == menuId ? _self.menuId : menuId // ignore: cast_nullable_to_non_nullable
as int,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,optionValueIds: null == optionValueIds ? _self._optionValueIds : optionValueIds // ignore: cast_nullable_to_non_nullable
as List<int>,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$OrderCreateRequest {

 int get locationId; List<OrderCreateItem> get items;@DeliveryTypeConverter() DeliveryType get deliveryType;@PaymentMethodConverter() PaymentMethod get paymentMethod;/// `delivery` ise zorunlu, `pickup` ise sunucu yok sayar.
 Address? get address;/// İstenen teslim zamanı (UTC). `order_cutoff`'a takılırsa `LOCATION_CLOSED`.
 DateTime? get requestedAt; String? get customerNote;
/// Create a copy of OrderCreateRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrderCreateRequestCopyWith<OrderCreateRequest> get copyWith => _$OrderCreateRequestCopyWithImpl<OrderCreateRequest>(this as OrderCreateRequest, _$identity);

  /// Serializes this OrderCreateRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrderCreateRequest&&(identical(other.locationId, locationId) || other.locationId == locationId)&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.deliveryType, deliveryType) || other.deliveryType == deliveryType)&&(identical(other.paymentMethod, paymentMethod) || other.paymentMethod == paymentMethod)&&(identical(other.address, address) || other.address == address)&&(identical(other.requestedAt, requestedAt) || other.requestedAt == requestedAt)&&(identical(other.customerNote, customerNote) || other.customerNote == customerNote));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,locationId,const DeepCollectionEquality().hash(items),deliveryType,paymentMethod,address,requestedAt,customerNote);

@override
String toString() {
  return 'OrderCreateRequest(locationId: $locationId, items: $items, deliveryType: $deliveryType, paymentMethod: $paymentMethod, address: $address, requestedAt: $requestedAt, customerNote: $customerNote)';
}


}

/// @nodoc
abstract mixin class $OrderCreateRequestCopyWith<$Res>  {
  factory $OrderCreateRequestCopyWith(OrderCreateRequest value, $Res Function(OrderCreateRequest) _then) = _$OrderCreateRequestCopyWithImpl;
@useResult
$Res call({
 int locationId, List<OrderCreateItem> items,@DeliveryTypeConverter() DeliveryType deliveryType,@PaymentMethodConverter() PaymentMethod paymentMethod, Address? address, DateTime? requestedAt, String? customerNote
});


$AddressCopyWith<$Res>? get address;

}
/// @nodoc
class _$OrderCreateRequestCopyWithImpl<$Res>
    implements $OrderCreateRequestCopyWith<$Res> {
  _$OrderCreateRequestCopyWithImpl(this._self, this._then);

  final OrderCreateRequest _self;
  final $Res Function(OrderCreateRequest) _then;

/// Create a copy of OrderCreateRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? locationId = null,Object? items = null,Object? deliveryType = null,Object? paymentMethod = null,Object? address = freezed,Object? requestedAt = freezed,Object? customerNote = freezed,}) {
  return _then(_self.copyWith(
locationId: null == locationId ? _self.locationId : locationId // ignore: cast_nullable_to_non_nullable
as int,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<OrderCreateItem>,deliveryType: null == deliveryType ? _self.deliveryType : deliveryType // ignore: cast_nullable_to_non_nullable
as DeliveryType,paymentMethod: null == paymentMethod ? _self.paymentMethod : paymentMethod // ignore: cast_nullable_to_non_nullable
as PaymentMethod,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as Address?,requestedAt: freezed == requestedAt ? _self.requestedAt : requestedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,customerNote: freezed == customerNote ? _self.customerNote : customerNote // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of OrderCreateRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AddressCopyWith<$Res>? get address {
    if (_self.address == null) {
    return null;
  }

  return $AddressCopyWith<$Res>(_self.address!, (value) {
    return _then(_self.copyWith(address: value));
  });
}
}


/// Adds pattern-matching-related methods to [OrderCreateRequest].
extension OrderCreateRequestPatterns on OrderCreateRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrderCreateRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrderCreateRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrderCreateRequest value)  $default,){
final _that = this;
switch (_that) {
case _OrderCreateRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrderCreateRequest value)?  $default,){
final _that = this;
switch (_that) {
case _OrderCreateRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int locationId,  List<OrderCreateItem> items, @DeliveryTypeConverter()  DeliveryType deliveryType, @PaymentMethodConverter()  PaymentMethod paymentMethod,  Address? address,  DateTime? requestedAt,  String? customerNote)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrderCreateRequest() when $default != null:
return $default(_that.locationId,_that.items,_that.deliveryType,_that.paymentMethod,_that.address,_that.requestedAt,_that.customerNote);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int locationId,  List<OrderCreateItem> items, @DeliveryTypeConverter()  DeliveryType deliveryType, @PaymentMethodConverter()  PaymentMethod paymentMethod,  Address? address,  DateTime? requestedAt,  String? customerNote)  $default,) {final _that = this;
switch (_that) {
case _OrderCreateRequest():
return $default(_that.locationId,_that.items,_that.deliveryType,_that.paymentMethod,_that.address,_that.requestedAt,_that.customerNote);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int locationId,  List<OrderCreateItem> items, @DeliveryTypeConverter()  DeliveryType deliveryType, @PaymentMethodConverter()  PaymentMethod paymentMethod,  Address? address,  DateTime? requestedAt,  String? customerNote)?  $default,) {final _that = this;
switch (_that) {
case _OrderCreateRequest() when $default != null:
return $default(_that.locationId,_that.items,_that.deliveryType,_that.paymentMethod,_that.address,_that.requestedAt,_that.customerNote);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OrderCreateRequest implements OrderCreateRequest {
  const _OrderCreateRequest({required this.locationId, required final  List<OrderCreateItem> items, @DeliveryTypeConverter() required this.deliveryType, @PaymentMethodConverter() required this.paymentMethod, this.address, this.requestedAt, this.customerNote}): _items = items;
  factory _OrderCreateRequest.fromJson(Map<String, dynamic> json) => _$OrderCreateRequestFromJson(json);

@override final  int locationId;
 final  List<OrderCreateItem> _items;
@override List<OrderCreateItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override@DeliveryTypeConverter() final  DeliveryType deliveryType;
@override@PaymentMethodConverter() final  PaymentMethod paymentMethod;
/// `delivery` ise zorunlu, `pickup` ise sunucu yok sayar.
@override final  Address? address;
/// İstenen teslim zamanı (UTC). `order_cutoff`'a takılırsa `LOCATION_CLOSED`.
@override final  DateTime? requestedAt;
@override final  String? customerNote;

/// Create a copy of OrderCreateRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrderCreateRequestCopyWith<_OrderCreateRequest> get copyWith => __$OrderCreateRequestCopyWithImpl<_OrderCreateRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrderCreateRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrderCreateRequest&&(identical(other.locationId, locationId) || other.locationId == locationId)&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.deliveryType, deliveryType) || other.deliveryType == deliveryType)&&(identical(other.paymentMethod, paymentMethod) || other.paymentMethod == paymentMethod)&&(identical(other.address, address) || other.address == address)&&(identical(other.requestedAt, requestedAt) || other.requestedAt == requestedAt)&&(identical(other.customerNote, customerNote) || other.customerNote == customerNote));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,locationId,const DeepCollectionEquality().hash(_items),deliveryType,paymentMethod,address,requestedAt,customerNote);

@override
String toString() {
  return 'OrderCreateRequest(locationId: $locationId, items: $items, deliveryType: $deliveryType, paymentMethod: $paymentMethod, address: $address, requestedAt: $requestedAt, customerNote: $customerNote)';
}


}

/// @nodoc
abstract mixin class _$OrderCreateRequestCopyWith<$Res> implements $OrderCreateRequestCopyWith<$Res> {
  factory _$OrderCreateRequestCopyWith(_OrderCreateRequest value, $Res Function(_OrderCreateRequest) _then) = __$OrderCreateRequestCopyWithImpl;
@override @useResult
$Res call({
 int locationId, List<OrderCreateItem> items,@DeliveryTypeConverter() DeliveryType deliveryType,@PaymentMethodConverter() PaymentMethod paymentMethod, Address? address, DateTime? requestedAt, String? customerNote
});


@override $AddressCopyWith<$Res>? get address;

}
/// @nodoc
class __$OrderCreateRequestCopyWithImpl<$Res>
    implements _$OrderCreateRequestCopyWith<$Res> {
  __$OrderCreateRequestCopyWithImpl(this._self, this._then);

  final _OrderCreateRequest _self;
  final $Res Function(_OrderCreateRequest) _then;

/// Create a copy of OrderCreateRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? locationId = null,Object? items = null,Object? deliveryType = null,Object? paymentMethod = null,Object? address = freezed,Object? requestedAt = freezed,Object? customerNote = freezed,}) {
  return _then(_OrderCreateRequest(
locationId: null == locationId ? _self.locationId : locationId // ignore: cast_nullable_to_non_nullable
as int,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<OrderCreateItem>,deliveryType: null == deliveryType ? _self.deliveryType : deliveryType // ignore: cast_nullable_to_non_nullable
as DeliveryType,paymentMethod: null == paymentMethod ? _self.paymentMethod : paymentMethod // ignore: cast_nullable_to_non_nullable
as PaymentMethod,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as Address?,requestedAt: freezed == requestedAt ? _self.requestedAt : requestedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,customerNote: freezed == customerNote ? _self.customerNote : customerNote // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of OrderCreateRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AddressCopyWith<$Res>? get address {
    if (_self.address == null) {
    return null;
  }

  return $AddressCopyWith<$Res>(_self.address!, (value) {
    return _then(_self.copyWith(address: value));
  });
}
}


/// @nodoc
mixin _$Payment {

@PaymentMethodConverter() PaymentMethod get method;@PaymentStatusConverter() PaymentStatus get status;/// Yalnızca `online` yönteminde dolu; istemci kullanıcıyı buraya yönlendirir.
 String? get redirectUrl;
/// Create a copy of Payment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentCopyWith<Payment> get copyWith => _$PaymentCopyWithImpl<Payment>(this as Payment, _$identity);

  /// Serializes this Payment to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Payment&&(identical(other.method, method) || other.method == method)&&(identical(other.status, status) || other.status == status)&&(identical(other.redirectUrl, redirectUrl) || other.redirectUrl == redirectUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,method,status,redirectUrl);

@override
String toString() {
  return 'Payment(method: $method, status: $status, redirectUrl: $redirectUrl)';
}


}

/// @nodoc
abstract mixin class $PaymentCopyWith<$Res>  {
  factory $PaymentCopyWith(Payment value, $Res Function(Payment) _then) = _$PaymentCopyWithImpl;
@useResult
$Res call({
@PaymentMethodConverter() PaymentMethod method,@PaymentStatusConverter() PaymentStatus status, String? redirectUrl
});




}
/// @nodoc
class _$PaymentCopyWithImpl<$Res>
    implements $PaymentCopyWith<$Res> {
  _$PaymentCopyWithImpl(this._self, this._then);

  final Payment _self;
  final $Res Function(Payment) _then;

/// Create a copy of Payment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? method = null,Object? status = null,Object? redirectUrl = freezed,}) {
  return _then(_self.copyWith(
method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as PaymentMethod,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PaymentStatus,redirectUrl: freezed == redirectUrl ? _self.redirectUrl : redirectUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Payment].
extension PaymentPatterns on Payment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Payment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Payment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Payment value)  $default,){
final _that = this;
switch (_that) {
case _Payment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Payment value)?  $default,){
final _that = this;
switch (_that) {
case _Payment() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@PaymentMethodConverter()  PaymentMethod method, @PaymentStatusConverter()  PaymentStatus status,  String? redirectUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Payment() when $default != null:
return $default(_that.method,_that.status,_that.redirectUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@PaymentMethodConverter()  PaymentMethod method, @PaymentStatusConverter()  PaymentStatus status,  String? redirectUrl)  $default,) {final _that = this;
switch (_that) {
case _Payment():
return $default(_that.method,_that.status,_that.redirectUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@PaymentMethodConverter()  PaymentMethod method, @PaymentStatusConverter()  PaymentStatus status,  String? redirectUrl)?  $default,) {final _that = this;
switch (_that) {
case _Payment() when $default != null:
return $default(_that.method,_that.status,_that.redirectUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Payment extends Payment {
  const _Payment({@PaymentMethodConverter() required this.method, @PaymentStatusConverter() required this.status, this.redirectUrl}): super._();
  factory _Payment.fromJson(Map<String, dynamic> json) => _$PaymentFromJson(json);

@override@PaymentMethodConverter() final  PaymentMethod method;
@override@PaymentStatusConverter() final  PaymentStatus status;
/// Yalnızca `online` yönteminde dolu; istemci kullanıcıyı buraya yönlendirir.
@override final  String? redirectUrl;

/// Create a copy of Payment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentCopyWith<_Payment> get copyWith => __$PaymentCopyWithImpl<_Payment>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PaymentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Payment&&(identical(other.method, method) || other.method == method)&&(identical(other.status, status) || other.status == status)&&(identical(other.redirectUrl, redirectUrl) || other.redirectUrl == redirectUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,method,status,redirectUrl);

@override
String toString() {
  return 'Payment(method: $method, status: $status, redirectUrl: $redirectUrl)';
}


}

/// @nodoc
abstract mixin class _$PaymentCopyWith<$Res> implements $PaymentCopyWith<$Res> {
  factory _$PaymentCopyWith(_Payment value, $Res Function(_Payment) _then) = __$PaymentCopyWithImpl;
@override @useResult
$Res call({
@PaymentMethodConverter() PaymentMethod method,@PaymentStatusConverter() PaymentStatus status, String? redirectUrl
});




}
/// @nodoc
class __$PaymentCopyWithImpl<$Res>
    implements _$PaymentCopyWith<$Res> {
  __$PaymentCopyWithImpl(this._self, this._then);

  final _Payment _self;
  final $Res Function(_Payment) _then;

/// Create a copy of Payment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? method = null,Object? status = null,Object? redirectUrl = freezed,}) {
  return _then(_Payment(
method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as PaymentMethod,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PaymentStatus,redirectUrl: freezed == redirectUrl ? _self.redirectUrl : redirectUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$OrderCreated {

 int get id; String get orderNumber;@OrderStatusConverter() OrderStatus get status;/// Kuruş.
 int get total; String get currency; Payment get payment; DateTime get createdAt;
/// Create a copy of OrderCreated
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrderCreatedCopyWith<OrderCreated> get copyWith => _$OrderCreatedCopyWithImpl<OrderCreated>(this as OrderCreated, _$identity);

  /// Serializes this OrderCreated to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrderCreated&&(identical(other.id, id) || other.id == id)&&(identical(other.orderNumber, orderNumber) || other.orderNumber == orderNumber)&&(identical(other.status, status) || other.status == status)&&(identical(other.total, total) || other.total == total)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.payment, payment) || other.payment == payment)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,orderNumber,status,total,currency,payment,createdAt);

@override
String toString() {
  return 'OrderCreated(id: $id, orderNumber: $orderNumber, status: $status, total: $total, currency: $currency, payment: $payment, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $OrderCreatedCopyWith<$Res>  {
  factory $OrderCreatedCopyWith(OrderCreated value, $Res Function(OrderCreated) _then) = _$OrderCreatedCopyWithImpl;
@useResult
$Res call({
 int id, String orderNumber,@OrderStatusConverter() OrderStatus status, int total, String currency, Payment payment, DateTime createdAt
});


$PaymentCopyWith<$Res> get payment;

}
/// @nodoc
class _$OrderCreatedCopyWithImpl<$Res>
    implements $OrderCreatedCopyWith<$Res> {
  _$OrderCreatedCopyWithImpl(this._self, this._then);

  final OrderCreated _self;
  final $Res Function(OrderCreated) _then;

/// Create a copy of OrderCreated
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? orderNumber = null,Object? status = null,Object? total = null,Object? currency = null,Object? payment = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,orderNumber: null == orderNumber ? _self.orderNumber : orderNumber // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as OrderStatus,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,payment: null == payment ? _self.payment : payment // ignore: cast_nullable_to_non_nullable
as Payment,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of OrderCreated
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PaymentCopyWith<$Res> get payment {
  
  return $PaymentCopyWith<$Res>(_self.payment, (value) {
    return _then(_self.copyWith(payment: value));
  });
}
}


/// Adds pattern-matching-related methods to [OrderCreated].
extension OrderCreatedPatterns on OrderCreated {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrderCreated value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrderCreated() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrderCreated value)  $default,){
final _that = this;
switch (_that) {
case _OrderCreated():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrderCreated value)?  $default,){
final _that = this;
switch (_that) {
case _OrderCreated() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String orderNumber, @OrderStatusConverter()  OrderStatus status,  int total,  String currency,  Payment payment,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrderCreated() when $default != null:
return $default(_that.id,_that.orderNumber,_that.status,_that.total,_that.currency,_that.payment,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String orderNumber, @OrderStatusConverter()  OrderStatus status,  int total,  String currency,  Payment payment,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _OrderCreated():
return $default(_that.id,_that.orderNumber,_that.status,_that.total,_that.currency,_that.payment,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String orderNumber, @OrderStatusConverter()  OrderStatus status,  int total,  String currency,  Payment payment,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _OrderCreated() when $default != null:
return $default(_that.id,_that.orderNumber,_that.status,_that.total,_that.currency,_that.payment,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OrderCreated implements OrderCreated {
  const _OrderCreated({required this.id, required this.orderNumber, @OrderStatusConverter() required this.status, required this.total, required this.currency, required this.payment, required this.createdAt});
  factory _OrderCreated.fromJson(Map<String, dynamic> json) => _$OrderCreatedFromJson(json);

@override final  int id;
@override final  String orderNumber;
@override@OrderStatusConverter() final  OrderStatus status;
/// Kuruş.
@override final  int total;
@override final  String currency;
@override final  Payment payment;
@override final  DateTime createdAt;

/// Create a copy of OrderCreated
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrderCreatedCopyWith<_OrderCreated> get copyWith => __$OrderCreatedCopyWithImpl<_OrderCreated>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrderCreatedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrderCreated&&(identical(other.id, id) || other.id == id)&&(identical(other.orderNumber, orderNumber) || other.orderNumber == orderNumber)&&(identical(other.status, status) || other.status == status)&&(identical(other.total, total) || other.total == total)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.payment, payment) || other.payment == payment)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,orderNumber,status,total,currency,payment,createdAt);

@override
String toString() {
  return 'OrderCreated(id: $id, orderNumber: $orderNumber, status: $status, total: $total, currency: $currency, payment: $payment, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$OrderCreatedCopyWith<$Res> implements $OrderCreatedCopyWith<$Res> {
  factory _$OrderCreatedCopyWith(_OrderCreated value, $Res Function(_OrderCreated) _then) = __$OrderCreatedCopyWithImpl;
@override @useResult
$Res call({
 int id, String orderNumber,@OrderStatusConverter() OrderStatus status, int total, String currency, Payment payment, DateTime createdAt
});


@override $PaymentCopyWith<$Res> get payment;

}
/// @nodoc
class __$OrderCreatedCopyWithImpl<$Res>
    implements _$OrderCreatedCopyWith<$Res> {
  __$OrderCreatedCopyWithImpl(this._self, this._then);

  final _OrderCreated _self;
  final $Res Function(_OrderCreated) _then;

/// Create a copy of OrderCreated
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? orderNumber = null,Object? status = null,Object? total = null,Object? currency = null,Object? payment = null,Object? createdAt = null,}) {
  return _then(_OrderCreated(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,orderNumber: null == orderNumber ? _self.orderNumber : orderNumber // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as OrderStatus,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,payment: null == payment ? _self.payment : payment // ignore: cast_nullable_to_non_nullable
as Payment,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of OrderCreated
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PaymentCopyWith<$Res> get payment {
  
  return $PaymentCopyWith<$Res>(_self.payment, (value) {
    return _then(_self.copyWith(payment: value));
  });
}
}


/// @nodoc
mixin _$OrderSummary {

 int get id; String get orderNumber;@OrderStatusConverter() OrderStatus get status; int get total; String get currency; int get itemCount; DateTime get createdAt;
/// Create a copy of OrderSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrderSummaryCopyWith<OrderSummary> get copyWith => _$OrderSummaryCopyWithImpl<OrderSummary>(this as OrderSummary, _$identity);

  /// Serializes this OrderSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrderSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.orderNumber, orderNumber) || other.orderNumber == orderNumber)&&(identical(other.status, status) || other.status == status)&&(identical(other.total, total) || other.total == total)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.itemCount, itemCount) || other.itemCount == itemCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,orderNumber,status,total,currency,itemCount,createdAt);

@override
String toString() {
  return 'OrderSummary(id: $id, orderNumber: $orderNumber, status: $status, total: $total, currency: $currency, itemCount: $itemCount, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $OrderSummaryCopyWith<$Res>  {
  factory $OrderSummaryCopyWith(OrderSummary value, $Res Function(OrderSummary) _then) = _$OrderSummaryCopyWithImpl;
@useResult
$Res call({
 int id, String orderNumber,@OrderStatusConverter() OrderStatus status, int total, String currency, int itemCount, DateTime createdAt
});




}
/// @nodoc
class _$OrderSummaryCopyWithImpl<$Res>
    implements $OrderSummaryCopyWith<$Res> {
  _$OrderSummaryCopyWithImpl(this._self, this._then);

  final OrderSummary _self;
  final $Res Function(OrderSummary) _then;

/// Create a copy of OrderSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? orderNumber = null,Object? status = null,Object? total = null,Object? currency = null,Object? itemCount = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,orderNumber: null == orderNumber ? _self.orderNumber : orderNumber // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as OrderStatus,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,itemCount: null == itemCount ? _self.itemCount : itemCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [OrderSummary].
extension OrderSummaryPatterns on OrderSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrderSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrderSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrderSummary value)  $default,){
final _that = this;
switch (_that) {
case _OrderSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrderSummary value)?  $default,){
final _that = this;
switch (_that) {
case _OrderSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String orderNumber, @OrderStatusConverter()  OrderStatus status,  int total,  String currency,  int itemCount,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrderSummary() when $default != null:
return $default(_that.id,_that.orderNumber,_that.status,_that.total,_that.currency,_that.itemCount,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String orderNumber, @OrderStatusConverter()  OrderStatus status,  int total,  String currency,  int itemCount,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _OrderSummary():
return $default(_that.id,_that.orderNumber,_that.status,_that.total,_that.currency,_that.itemCount,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String orderNumber, @OrderStatusConverter()  OrderStatus status,  int total,  String currency,  int itemCount,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _OrderSummary() when $default != null:
return $default(_that.id,_that.orderNumber,_that.status,_that.total,_that.currency,_that.itemCount,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OrderSummary implements OrderSummary {
  const _OrderSummary({required this.id, required this.orderNumber, @OrderStatusConverter() required this.status, required this.total, required this.currency, required this.itemCount, required this.createdAt});
  factory _OrderSummary.fromJson(Map<String, dynamic> json) => _$OrderSummaryFromJson(json);

@override final  int id;
@override final  String orderNumber;
@override@OrderStatusConverter() final  OrderStatus status;
@override final  int total;
@override final  String currency;
@override final  int itemCount;
@override final  DateTime createdAt;

/// Create a copy of OrderSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrderSummaryCopyWith<_OrderSummary> get copyWith => __$OrderSummaryCopyWithImpl<_OrderSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrderSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrderSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.orderNumber, orderNumber) || other.orderNumber == orderNumber)&&(identical(other.status, status) || other.status == status)&&(identical(other.total, total) || other.total == total)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.itemCount, itemCount) || other.itemCount == itemCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,orderNumber,status,total,currency,itemCount,createdAt);

@override
String toString() {
  return 'OrderSummary(id: $id, orderNumber: $orderNumber, status: $status, total: $total, currency: $currency, itemCount: $itemCount, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$OrderSummaryCopyWith<$Res> implements $OrderSummaryCopyWith<$Res> {
  factory _$OrderSummaryCopyWith(_OrderSummary value, $Res Function(_OrderSummary) _then) = __$OrderSummaryCopyWithImpl;
@override @useResult
$Res call({
 int id, String orderNumber,@OrderStatusConverter() OrderStatus status, int total, String currency, int itemCount, DateTime createdAt
});




}
/// @nodoc
class __$OrderSummaryCopyWithImpl<$Res>
    implements _$OrderSummaryCopyWith<$Res> {
  __$OrderSummaryCopyWithImpl(this._self, this._then);

  final _OrderSummary _self;
  final $Res Function(_OrderSummary) _then;

/// Create a copy of OrderSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? orderNumber = null,Object? status = null,Object? total = null,Object? currency = null,Object? itemCount = null,Object? createdAt = null,}) {
  return _then(_OrderSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,orderNumber: null == orderNumber ? _self.orderNumber : orderNumber // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as OrderStatus,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,itemCount: null == itemCount ? _self.itemCount : itemCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$OrderItem {

 int get menuId; String get name; int get quantity;/// Seçenek farkları **dahil** birim fiyat (kuruş).
 int get unitPrice; int get lineTotal; List<String> get options; String? get note;
/// Create a copy of OrderItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrderItemCopyWith<OrderItem> get copyWith => _$OrderItemCopyWithImpl<OrderItem>(this as OrderItem, _$identity);

  /// Serializes this OrderItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrderItem&&(identical(other.menuId, menuId) || other.menuId == menuId)&&(identical(other.name, name) || other.name == name)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.unitPrice, unitPrice) || other.unitPrice == unitPrice)&&(identical(other.lineTotal, lineTotal) || other.lineTotal == lineTotal)&&const DeepCollectionEquality().equals(other.options, options)&&(identical(other.note, note) || other.note == note));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,menuId,name,quantity,unitPrice,lineTotal,const DeepCollectionEquality().hash(options),note);

@override
String toString() {
  return 'OrderItem(menuId: $menuId, name: $name, quantity: $quantity, unitPrice: $unitPrice, lineTotal: $lineTotal, options: $options, note: $note)';
}


}

/// @nodoc
abstract mixin class $OrderItemCopyWith<$Res>  {
  factory $OrderItemCopyWith(OrderItem value, $Res Function(OrderItem) _then) = _$OrderItemCopyWithImpl;
@useResult
$Res call({
 int menuId, String name, int quantity, int unitPrice, int lineTotal, List<String> options, String? note
});




}
/// @nodoc
class _$OrderItemCopyWithImpl<$Res>
    implements $OrderItemCopyWith<$Res> {
  _$OrderItemCopyWithImpl(this._self, this._then);

  final OrderItem _self;
  final $Res Function(OrderItem) _then;

/// Create a copy of OrderItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? menuId = null,Object? name = null,Object? quantity = null,Object? unitPrice = null,Object? lineTotal = null,Object? options = null,Object? note = freezed,}) {
  return _then(_self.copyWith(
menuId: null == menuId ? _self.menuId : menuId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,unitPrice: null == unitPrice ? _self.unitPrice : unitPrice // ignore: cast_nullable_to_non_nullable
as int,lineTotal: null == lineTotal ? _self.lineTotal : lineTotal // ignore: cast_nullable_to_non_nullable
as int,options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as List<String>,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [OrderItem].
extension OrderItemPatterns on OrderItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrderItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrderItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrderItem value)  $default,){
final _that = this;
switch (_that) {
case _OrderItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrderItem value)?  $default,){
final _that = this;
switch (_that) {
case _OrderItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int menuId,  String name,  int quantity,  int unitPrice,  int lineTotal,  List<String> options,  String? note)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrderItem() when $default != null:
return $default(_that.menuId,_that.name,_that.quantity,_that.unitPrice,_that.lineTotal,_that.options,_that.note);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int menuId,  String name,  int quantity,  int unitPrice,  int lineTotal,  List<String> options,  String? note)  $default,) {final _that = this;
switch (_that) {
case _OrderItem():
return $default(_that.menuId,_that.name,_that.quantity,_that.unitPrice,_that.lineTotal,_that.options,_that.note);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int menuId,  String name,  int quantity,  int unitPrice,  int lineTotal,  List<String> options,  String? note)?  $default,) {final _that = this;
switch (_that) {
case _OrderItem() when $default != null:
return $default(_that.menuId,_that.name,_that.quantity,_that.unitPrice,_that.lineTotal,_that.options,_that.note);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OrderItem implements OrderItem {
  const _OrderItem({required this.menuId, required this.name, required this.quantity, required this.unitPrice, required this.lineTotal, final  List<String> options = const <String>[], this.note}): _options = options;
  factory _OrderItem.fromJson(Map<String, dynamic> json) => _$OrderItemFromJson(json);

@override final  int menuId;
@override final  String name;
@override final  int quantity;
/// Seçenek farkları **dahil** birim fiyat (kuruş).
@override final  int unitPrice;
@override final  int lineTotal;
 final  List<String> _options;
@override@JsonKey() List<String> get options {
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_options);
}

@override final  String? note;

/// Create a copy of OrderItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrderItemCopyWith<_OrderItem> get copyWith => __$OrderItemCopyWithImpl<_OrderItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrderItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrderItem&&(identical(other.menuId, menuId) || other.menuId == menuId)&&(identical(other.name, name) || other.name == name)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.unitPrice, unitPrice) || other.unitPrice == unitPrice)&&(identical(other.lineTotal, lineTotal) || other.lineTotal == lineTotal)&&const DeepCollectionEquality().equals(other._options, _options)&&(identical(other.note, note) || other.note == note));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,menuId,name,quantity,unitPrice,lineTotal,const DeepCollectionEquality().hash(_options),note);

@override
String toString() {
  return 'OrderItem(menuId: $menuId, name: $name, quantity: $quantity, unitPrice: $unitPrice, lineTotal: $lineTotal, options: $options, note: $note)';
}


}

/// @nodoc
abstract mixin class _$OrderItemCopyWith<$Res> implements $OrderItemCopyWith<$Res> {
  factory _$OrderItemCopyWith(_OrderItem value, $Res Function(_OrderItem) _then) = __$OrderItemCopyWithImpl;
@override @useResult
$Res call({
 int menuId, String name, int quantity, int unitPrice, int lineTotal, List<String> options, String? note
});




}
/// @nodoc
class __$OrderItemCopyWithImpl<$Res>
    implements _$OrderItemCopyWith<$Res> {
  __$OrderItemCopyWithImpl(this._self, this._then);

  final _OrderItem _self;
  final $Res Function(_OrderItem) _then;

/// Create a copy of OrderItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? menuId = null,Object? name = null,Object? quantity = null,Object? unitPrice = null,Object? lineTotal = null,Object? options = null,Object? note = freezed,}) {
  return _then(_OrderItem(
menuId: null == menuId ? _self.menuId : menuId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,unitPrice: null == unitPrice ? _self.unitPrice : unitPrice // ignore: cast_nullable_to_non_nullable
as int,lineTotal: null == lineTotal ? _self.lineTotal : lineTotal // ignore: cast_nullable_to_non_nullable
as int,options: null == options ? _self._options : options // ignore: cast_nullable_to_non_nullable
as List<String>,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$StatusHistoryEntry {

@OrderStatusConverter() OrderStatus get status; DateTime get at;
/// Create a copy of StatusHistoryEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StatusHistoryEntryCopyWith<StatusHistoryEntry> get copyWith => _$StatusHistoryEntryCopyWithImpl<StatusHistoryEntry>(this as StatusHistoryEntry, _$identity);

  /// Serializes this StatusHistoryEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StatusHistoryEntry&&(identical(other.status, status) || other.status == status)&&(identical(other.at, at) || other.at == at));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,at);

@override
String toString() {
  return 'StatusHistoryEntry(status: $status, at: $at)';
}


}

/// @nodoc
abstract mixin class $StatusHistoryEntryCopyWith<$Res>  {
  factory $StatusHistoryEntryCopyWith(StatusHistoryEntry value, $Res Function(StatusHistoryEntry) _then) = _$StatusHistoryEntryCopyWithImpl;
@useResult
$Res call({
@OrderStatusConverter() OrderStatus status, DateTime at
});




}
/// @nodoc
class _$StatusHistoryEntryCopyWithImpl<$Res>
    implements $StatusHistoryEntryCopyWith<$Res> {
  _$StatusHistoryEntryCopyWithImpl(this._self, this._then);

  final StatusHistoryEntry _self;
  final $Res Function(StatusHistoryEntry) _then;

/// Create a copy of StatusHistoryEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? at = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as OrderStatus,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [StatusHistoryEntry].
extension StatusHistoryEntryPatterns on StatusHistoryEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StatusHistoryEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StatusHistoryEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StatusHistoryEntry value)  $default,){
final _that = this;
switch (_that) {
case _StatusHistoryEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StatusHistoryEntry value)?  $default,){
final _that = this;
switch (_that) {
case _StatusHistoryEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@OrderStatusConverter()  OrderStatus status,  DateTime at)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StatusHistoryEntry() when $default != null:
return $default(_that.status,_that.at);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@OrderStatusConverter()  OrderStatus status,  DateTime at)  $default,) {final _that = this;
switch (_that) {
case _StatusHistoryEntry():
return $default(_that.status,_that.at);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@OrderStatusConverter()  OrderStatus status,  DateTime at)?  $default,) {final _that = this;
switch (_that) {
case _StatusHistoryEntry() when $default != null:
return $default(_that.status,_that.at);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _StatusHistoryEntry implements StatusHistoryEntry {
  const _StatusHistoryEntry({@OrderStatusConverter() required this.status, required this.at});
  factory _StatusHistoryEntry.fromJson(Map<String, dynamic> json) => _$StatusHistoryEntryFromJson(json);

@override@OrderStatusConverter() final  OrderStatus status;
@override final  DateTime at;

/// Create a copy of StatusHistoryEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StatusHistoryEntryCopyWith<_StatusHistoryEntry> get copyWith => __$StatusHistoryEntryCopyWithImpl<_StatusHistoryEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StatusHistoryEntryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StatusHistoryEntry&&(identical(other.status, status) || other.status == status)&&(identical(other.at, at) || other.at == at));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,at);

@override
String toString() {
  return 'StatusHistoryEntry(status: $status, at: $at)';
}


}

/// @nodoc
abstract mixin class _$StatusHistoryEntryCopyWith<$Res> implements $StatusHistoryEntryCopyWith<$Res> {
  factory _$StatusHistoryEntryCopyWith(_StatusHistoryEntry value, $Res Function(_StatusHistoryEntry) _then) = __$StatusHistoryEntryCopyWithImpl;
@override @useResult
$Res call({
@OrderStatusConverter() OrderStatus status, DateTime at
});




}
/// @nodoc
class __$StatusHistoryEntryCopyWithImpl<$Res>
    implements _$StatusHistoryEntryCopyWith<$Res> {
  __$StatusHistoryEntryCopyWithImpl(this._self, this._then);

  final _StatusHistoryEntry _self;
  final $Res Function(_StatusHistoryEntry) _then;

/// Create a copy of StatusHistoryEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? at = null,}) {
  return _then(_StatusHistoryEntry(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as OrderStatus,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$OrderDetail {

 int get id; String get orderNumber;@OrderStatusConverter() OrderStatus get status; List<OrderItem> get items; int get subtotal;/// `pickup` siparişte her zaman `0`.
 int get deliveryFee; int get total; String get currency;@DeliveryTypeConverter() DeliveryType get deliveryType; Payment get payment; List<StatusHistoryEntry> get statusHistory; DateTime get createdAt;/// `pickup` siparişte `null`.
 Address? get address; DateTime? get requestedAt; String? get customerNote;
/// Create a copy of OrderDetail
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrderDetailCopyWith<OrderDetail> get copyWith => _$OrderDetailCopyWithImpl<OrderDetail>(this as OrderDetail, _$identity);

  /// Serializes this OrderDetail to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrderDetail&&(identical(other.id, id) || other.id == id)&&(identical(other.orderNumber, orderNumber) || other.orderNumber == orderNumber)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.subtotal, subtotal) || other.subtotal == subtotal)&&(identical(other.deliveryFee, deliveryFee) || other.deliveryFee == deliveryFee)&&(identical(other.total, total) || other.total == total)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.deliveryType, deliveryType) || other.deliveryType == deliveryType)&&(identical(other.payment, payment) || other.payment == payment)&&const DeepCollectionEquality().equals(other.statusHistory, statusHistory)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.address, address) || other.address == address)&&(identical(other.requestedAt, requestedAt) || other.requestedAt == requestedAt)&&(identical(other.customerNote, customerNote) || other.customerNote == customerNote));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,orderNumber,status,const DeepCollectionEquality().hash(items),subtotal,deliveryFee,total,currency,deliveryType,payment,const DeepCollectionEquality().hash(statusHistory),createdAt,address,requestedAt,customerNote);

@override
String toString() {
  return 'OrderDetail(id: $id, orderNumber: $orderNumber, status: $status, items: $items, subtotal: $subtotal, deliveryFee: $deliveryFee, total: $total, currency: $currency, deliveryType: $deliveryType, payment: $payment, statusHistory: $statusHistory, createdAt: $createdAt, address: $address, requestedAt: $requestedAt, customerNote: $customerNote)';
}


}

/// @nodoc
abstract mixin class $OrderDetailCopyWith<$Res>  {
  factory $OrderDetailCopyWith(OrderDetail value, $Res Function(OrderDetail) _then) = _$OrderDetailCopyWithImpl;
@useResult
$Res call({
 int id, String orderNumber,@OrderStatusConverter() OrderStatus status, List<OrderItem> items, int subtotal, int deliveryFee, int total, String currency,@DeliveryTypeConverter() DeliveryType deliveryType, Payment payment, List<StatusHistoryEntry> statusHistory, DateTime createdAt, Address? address, DateTime? requestedAt, String? customerNote
});


$PaymentCopyWith<$Res> get payment;$AddressCopyWith<$Res>? get address;

}
/// @nodoc
class _$OrderDetailCopyWithImpl<$Res>
    implements $OrderDetailCopyWith<$Res> {
  _$OrderDetailCopyWithImpl(this._self, this._then);

  final OrderDetail _self;
  final $Res Function(OrderDetail) _then;

/// Create a copy of OrderDetail
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? orderNumber = null,Object? status = null,Object? items = null,Object? subtotal = null,Object? deliveryFee = null,Object? total = null,Object? currency = null,Object? deliveryType = null,Object? payment = null,Object? statusHistory = null,Object? createdAt = null,Object? address = freezed,Object? requestedAt = freezed,Object? customerNote = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,orderNumber: null == orderNumber ? _self.orderNumber : orderNumber // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as OrderStatus,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<OrderItem>,subtotal: null == subtotal ? _self.subtotal : subtotal // ignore: cast_nullable_to_non_nullable
as int,deliveryFee: null == deliveryFee ? _self.deliveryFee : deliveryFee // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,deliveryType: null == deliveryType ? _self.deliveryType : deliveryType // ignore: cast_nullable_to_non_nullable
as DeliveryType,payment: null == payment ? _self.payment : payment // ignore: cast_nullable_to_non_nullable
as Payment,statusHistory: null == statusHistory ? _self.statusHistory : statusHistory // ignore: cast_nullable_to_non_nullable
as List<StatusHistoryEntry>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as Address?,requestedAt: freezed == requestedAt ? _self.requestedAt : requestedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,customerNote: freezed == customerNote ? _self.customerNote : customerNote // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of OrderDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PaymentCopyWith<$Res> get payment {
  
  return $PaymentCopyWith<$Res>(_self.payment, (value) {
    return _then(_self.copyWith(payment: value));
  });
}/// Create a copy of OrderDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AddressCopyWith<$Res>? get address {
    if (_self.address == null) {
    return null;
  }

  return $AddressCopyWith<$Res>(_self.address!, (value) {
    return _then(_self.copyWith(address: value));
  });
}
}


/// Adds pattern-matching-related methods to [OrderDetail].
extension OrderDetailPatterns on OrderDetail {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrderDetail value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrderDetail() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrderDetail value)  $default,){
final _that = this;
switch (_that) {
case _OrderDetail():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrderDetail value)?  $default,){
final _that = this;
switch (_that) {
case _OrderDetail() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String orderNumber, @OrderStatusConverter()  OrderStatus status,  List<OrderItem> items,  int subtotal,  int deliveryFee,  int total,  String currency, @DeliveryTypeConverter()  DeliveryType deliveryType,  Payment payment,  List<StatusHistoryEntry> statusHistory,  DateTime createdAt,  Address? address,  DateTime? requestedAt,  String? customerNote)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrderDetail() when $default != null:
return $default(_that.id,_that.orderNumber,_that.status,_that.items,_that.subtotal,_that.deliveryFee,_that.total,_that.currency,_that.deliveryType,_that.payment,_that.statusHistory,_that.createdAt,_that.address,_that.requestedAt,_that.customerNote);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String orderNumber, @OrderStatusConverter()  OrderStatus status,  List<OrderItem> items,  int subtotal,  int deliveryFee,  int total,  String currency, @DeliveryTypeConverter()  DeliveryType deliveryType,  Payment payment,  List<StatusHistoryEntry> statusHistory,  DateTime createdAt,  Address? address,  DateTime? requestedAt,  String? customerNote)  $default,) {final _that = this;
switch (_that) {
case _OrderDetail():
return $default(_that.id,_that.orderNumber,_that.status,_that.items,_that.subtotal,_that.deliveryFee,_that.total,_that.currency,_that.deliveryType,_that.payment,_that.statusHistory,_that.createdAt,_that.address,_that.requestedAt,_that.customerNote);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String orderNumber, @OrderStatusConverter()  OrderStatus status,  List<OrderItem> items,  int subtotal,  int deliveryFee,  int total,  String currency, @DeliveryTypeConverter()  DeliveryType deliveryType,  Payment payment,  List<StatusHistoryEntry> statusHistory,  DateTime createdAt,  Address? address,  DateTime? requestedAt,  String? customerNote)?  $default,) {final _that = this;
switch (_that) {
case _OrderDetail() when $default != null:
return $default(_that.id,_that.orderNumber,_that.status,_that.items,_that.subtotal,_that.deliveryFee,_that.total,_that.currency,_that.deliveryType,_that.payment,_that.statusHistory,_that.createdAt,_that.address,_that.requestedAt,_that.customerNote);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OrderDetail extends OrderDetail {
  const _OrderDetail({required this.id, required this.orderNumber, @OrderStatusConverter() required this.status, required final  List<OrderItem> items, required this.subtotal, required this.deliveryFee, required this.total, required this.currency, @DeliveryTypeConverter() required this.deliveryType, required this.payment, required final  List<StatusHistoryEntry> statusHistory, required this.createdAt, this.address, this.requestedAt, this.customerNote}): _items = items,_statusHistory = statusHistory,super._();
  factory _OrderDetail.fromJson(Map<String, dynamic> json) => _$OrderDetailFromJson(json);

@override final  int id;
@override final  String orderNumber;
@override@OrderStatusConverter() final  OrderStatus status;
 final  List<OrderItem> _items;
@override List<OrderItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override final  int subtotal;
/// `pickup` siparişte her zaman `0`.
@override final  int deliveryFee;
@override final  int total;
@override final  String currency;
@override@DeliveryTypeConverter() final  DeliveryType deliveryType;
@override final  Payment payment;
 final  List<StatusHistoryEntry> _statusHistory;
@override List<StatusHistoryEntry> get statusHistory {
  if (_statusHistory is EqualUnmodifiableListView) return _statusHistory;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_statusHistory);
}

@override final  DateTime createdAt;
/// `pickup` siparişte `null`.
@override final  Address? address;
@override final  DateTime? requestedAt;
@override final  String? customerNote;

/// Create a copy of OrderDetail
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrderDetailCopyWith<_OrderDetail> get copyWith => __$OrderDetailCopyWithImpl<_OrderDetail>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrderDetailToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrderDetail&&(identical(other.id, id) || other.id == id)&&(identical(other.orderNumber, orderNumber) || other.orderNumber == orderNumber)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.subtotal, subtotal) || other.subtotal == subtotal)&&(identical(other.deliveryFee, deliveryFee) || other.deliveryFee == deliveryFee)&&(identical(other.total, total) || other.total == total)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.deliveryType, deliveryType) || other.deliveryType == deliveryType)&&(identical(other.payment, payment) || other.payment == payment)&&const DeepCollectionEquality().equals(other._statusHistory, _statusHistory)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.address, address) || other.address == address)&&(identical(other.requestedAt, requestedAt) || other.requestedAt == requestedAt)&&(identical(other.customerNote, customerNote) || other.customerNote == customerNote));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,orderNumber,status,const DeepCollectionEquality().hash(_items),subtotal,deliveryFee,total,currency,deliveryType,payment,const DeepCollectionEquality().hash(_statusHistory),createdAt,address,requestedAt,customerNote);

@override
String toString() {
  return 'OrderDetail(id: $id, orderNumber: $orderNumber, status: $status, items: $items, subtotal: $subtotal, deliveryFee: $deliveryFee, total: $total, currency: $currency, deliveryType: $deliveryType, payment: $payment, statusHistory: $statusHistory, createdAt: $createdAt, address: $address, requestedAt: $requestedAt, customerNote: $customerNote)';
}


}

/// @nodoc
abstract mixin class _$OrderDetailCopyWith<$Res> implements $OrderDetailCopyWith<$Res> {
  factory _$OrderDetailCopyWith(_OrderDetail value, $Res Function(_OrderDetail) _then) = __$OrderDetailCopyWithImpl;
@override @useResult
$Res call({
 int id, String orderNumber,@OrderStatusConverter() OrderStatus status, List<OrderItem> items, int subtotal, int deliveryFee, int total, String currency,@DeliveryTypeConverter() DeliveryType deliveryType, Payment payment, List<StatusHistoryEntry> statusHistory, DateTime createdAt, Address? address, DateTime? requestedAt, String? customerNote
});


@override $PaymentCopyWith<$Res> get payment;@override $AddressCopyWith<$Res>? get address;

}
/// @nodoc
class __$OrderDetailCopyWithImpl<$Res>
    implements _$OrderDetailCopyWith<$Res> {
  __$OrderDetailCopyWithImpl(this._self, this._then);

  final _OrderDetail _self;
  final $Res Function(_OrderDetail) _then;

/// Create a copy of OrderDetail
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? orderNumber = null,Object? status = null,Object? items = null,Object? subtotal = null,Object? deliveryFee = null,Object? total = null,Object? currency = null,Object? deliveryType = null,Object? payment = null,Object? statusHistory = null,Object? createdAt = null,Object? address = freezed,Object? requestedAt = freezed,Object? customerNote = freezed,}) {
  return _then(_OrderDetail(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,orderNumber: null == orderNumber ? _self.orderNumber : orderNumber // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as OrderStatus,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<OrderItem>,subtotal: null == subtotal ? _self.subtotal : subtotal // ignore: cast_nullable_to_non_nullable
as int,deliveryFee: null == deliveryFee ? _self.deliveryFee : deliveryFee // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,deliveryType: null == deliveryType ? _self.deliveryType : deliveryType // ignore: cast_nullable_to_non_nullable
as DeliveryType,payment: null == payment ? _self.payment : payment // ignore: cast_nullable_to_non_nullable
as Payment,statusHistory: null == statusHistory ? _self._statusHistory : statusHistory // ignore: cast_nullable_to_non_nullable
as List<StatusHistoryEntry>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as Address?,requestedAt: freezed == requestedAt ? _self.requestedAt : requestedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,customerNote: freezed == customerNote ? _self.customerNote : customerNote // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of OrderDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PaymentCopyWith<$Res> get payment {
  
  return $PaymentCopyWith<$Res>(_self.payment, (value) {
    return _then(_self.copyWith(payment: value));
  });
}/// Create a copy of OrderDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AddressCopyWith<$Res>? get address {
    if (_self.address == null) {
    return null;
  }

  return $AddressCopyWith<$Res>(_self.address!, (value) {
    return _then(_self.copyWith(address: value));
  });
}
}


/// @nodoc
mixin _$PaginationMeta {

 int get page; int get perPage; int get total; int get lastPage;
/// Create a copy of PaginationMeta
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaginationMetaCopyWith<PaginationMeta> get copyWith => _$PaginationMetaCopyWithImpl<PaginationMeta>(this as PaginationMeta, _$identity);

  /// Serializes this PaginationMeta to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaginationMeta&&(identical(other.page, page) || other.page == page)&&(identical(other.perPage, perPage) || other.perPage == perPage)&&(identical(other.total, total) || other.total == total)&&(identical(other.lastPage, lastPage) || other.lastPage == lastPage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,page,perPage,total,lastPage);

@override
String toString() {
  return 'PaginationMeta(page: $page, perPage: $perPage, total: $total, lastPage: $lastPage)';
}


}

/// @nodoc
abstract mixin class $PaginationMetaCopyWith<$Res>  {
  factory $PaginationMetaCopyWith(PaginationMeta value, $Res Function(PaginationMeta) _then) = _$PaginationMetaCopyWithImpl;
@useResult
$Res call({
 int page, int perPage, int total, int lastPage
});




}
/// @nodoc
class _$PaginationMetaCopyWithImpl<$Res>
    implements $PaginationMetaCopyWith<$Res> {
  _$PaginationMetaCopyWithImpl(this._self, this._then);

  final PaginationMeta _self;
  final $Res Function(PaginationMeta) _then;

/// Create a copy of PaginationMeta
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? page = null,Object? perPage = null,Object? total = null,Object? lastPage = null,}) {
  return _then(_self.copyWith(
page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,perPage: null == perPage ? _self.perPage : perPage // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,lastPage: null == lastPage ? _self.lastPage : lastPage // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [PaginationMeta].
extension PaginationMetaPatterns on PaginationMeta {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaginationMeta value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaginationMeta() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaginationMeta value)  $default,){
final _that = this;
switch (_that) {
case _PaginationMeta():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaginationMeta value)?  $default,){
final _that = this;
switch (_that) {
case _PaginationMeta() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int page,  int perPage,  int total,  int lastPage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaginationMeta() when $default != null:
return $default(_that.page,_that.perPage,_that.total,_that.lastPage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int page,  int perPage,  int total,  int lastPage)  $default,) {final _that = this;
switch (_that) {
case _PaginationMeta():
return $default(_that.page,_that.perPage,_that.total,_that.lastPage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int page,  int perPage,  int total,  int lastPage)?  $default,) {final _that = this;
switch (_that) {
case _PaginationMeta() when $default != null:
return $default(_that.page,_that.perPage,_that.total,_that.lastPage);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PaginationMeta extends PaginationMeta {
  const _PaginationMeta({required this.page, required this.perPage, required this.total, required this.lastPage}): super._();
  factory _PaginationMeta.fromJson(Map<String, dynamic> json) => _$PaginationMetaFromJson(json);

@override final  int page;
@override final  int perPage;
@override final  int total;
@override final  int lastPage;

/// Create a copy of PaginationMeta
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaginationMetaCopyWith<_PaginationMeta> get copyWith => __$PaginationMetaCopyWithImpl<_PaginationMeta>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PaginationMetaToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaginationMeta&&(identical(other.page, page) || other.page == page)&&(identical(other.perPage, perPage) || other.perPage == perPage)&&(identical(other.total, total) || other.total == total)&&(identical(other.lastPage, lastPage) || other.lastPage == lastPage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,page,perPage,total,lastPage);

@override
String toString() {
  return 'PaginationMeta(page: $page, perPage: $perPage, total: $total, lastPage: $lastPage)';
}


}

/// @nodoc
abstract mixin class _$PaginationMetaCopyWith<$Res> implements $PaginationMetaCopyWith<$Res> {
  factory _$PaginationMetaCopyWith(_PaginationMeta value, $Res Function(_PaginationMeta) _then) = __$PaginationMetaCopyWithImpl;
@override @useResult
$Res call({
 int page, int perPage, int total, int lastPage
});




}
/// @nodoc
class __$PaginationMetaCopyWithImpl<$Res>
    implements _$PaginationMetaCopyWith<$Res> {
  __$PaginationMetaCopyWithImpl(this._self, this._then);

  final _PaginationMeta _self;
  final $Res Function(_PaginationMeta) _then;

/// Create a copy of PaginationMeta
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? page = null,Object? perPage = null,Object? total = null,Object? lastPage = null,}) {
  return _then(_PaginationMeta(
page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,perPage: null == perPage ? _self.perPage : perPage // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,lastPage: null == lastPage ? _self.lastPage : lastPage // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$OrderPage {

 List<OrderSummary> get data; PaginationMeta get meta;
/// Create a copy of OrderPage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrderPageCopyWith<OrderPage> get copyWith => _$OrderPageCopyWithImpl<OrderPage>(this as OrderPage, _$identity);

  /// Serializes this OrderPage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrderPage&&const DeepCollectionEquality().equals(other.data, data)&&(identical(other.meta, meta) || other.meta == meta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data),meta);

@override
String toString() {
  return 'OrderPage(data: $data, meta: $meta)';
}


}

/// @nodoc
abstract mixin class $OrderPageCopyWith<$Res>  {
  factory $OrderPageCopyWith(OrderPage value, $Res Function(OrderPage) _then) = _$OrderPageCopyWithImpl;
@useResult
$Res call({
 List<OrderSummary> data, PaginationMeta meta
});


$PaginationMetaCopyWith<$Res> get meta;

}
/// @nodoc
class _$OrderPageCopyWithImpl<$Res>
    implements $OrderPageCopyWith<$Res> {
  _$OrderPageCopyWithImpl(this._self, this._then);

  final OrderPage _self;
  final $Res Function(OrderPage) _then;

/// Create a copy of OrderPage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,Object? meta = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<OrderSummary>,meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as PaginationMeta,
  ));
}
/// Create a copy of OrderPage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PaginationMetaCopyWith<$Res> get meta {
  
  return $PaginationMetaCopyWith<$Res>(_self.meta, (value) {
    return _then(_self.copyWith(meta: value));
  });
}
}


/// Adds pattern-matching-related methods to [OrderPage].
extension OrderPagePatterns on OrderPage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrderPage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrderPage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrderPage value)  $default,){
final _that = this;
switch (_that) {
case _OrderPage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrderPage value)?  $default,){
final _that = this;
switch (_that) {
case _OrderPage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<OrderSummary> data,  PaginationMeta meta)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrderPage() when $default != null:
return $default(_that.data,_that.meta);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<OrderSummary> data,  PaginationMeta meta)  $default,) {final _that = this;
switch (_that) {
case _OrderPage():
return $default(_that.data,_that.meta);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<OrderSummary> data,  PaginationMeta meta)?  $default,) {final _that = this;
switch (_that) {
case _OrderPage() when $default != null:
return $default(_that.data,_that.meta);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OrderPage implements OrderPage {
  const _OrderPage({required final  List<OrderSummary> data, required this.meta}): _data = data;
  factory _OrderPage.fromJson(Map<String, dynamic> json) => _$OrderPageFromJson(json);

 final  List<OrderSummary> _data;
@override List<OrderSummary> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}

@override final  PaginationMeta meta;

/// Create a copy of OrderPage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrderPageCopyWith<_OrderPage> get copyWith => __$OrderPageCopyWithImpl<_OrderPage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrderPageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrderPage&&const DeepCollectionEquality().equals(other._data, _data)&&(identical(other.meta, meta) || other.meta == meta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data),meta);

@override
String toString() {
  return 'OrderPage(data: $data, meta: $meta)';
}


}

/// @nodoc
abstract mixin class _$OrderPageCopyWith<$Res> implements $OrderPageCopyWith<$Res> {
  factory _$OrderPageCopyWith(_OrderPage value, $Res Function(_OrderPage) _then) = __$OrderPageCopyWithImpl;
@override @useResult
$Res call({
 List<OrderSummary> data, PaginationMeta meta
});


@override $PaginationMetaCopyWith<$Res> get meta;

}
/// @nodoc
class __$OrderPageCopyWithImpl<$Res>
    implements _$OrderPageCopyWith<$Res> {
  __$OrderPageCopyWithImpl(this._self, this._then);

  final _OrderPage _self;
  final $Res Function(_OrderPage) _then;

/// Create a copy of OrderPage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,Object? meta = null,}) {
  return _then(_OrderPage(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<OrderSummary>,meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as PaginationMeta,
  ));
}

/// Create a copy of OrderPage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PaginationMetaCopyWith<$Res> get meta {
  
  return $PaginationMetaCopyWith<$Res>(_self.meta, (value) {
    return _then(_self.copyWith(meta: value));
  });
}
}

// dart format on
