// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'kitchen.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PairRequest {

 String get pairingCode; String get deviceName;
/// Create a copy of PairRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PairRequestCopyWith<PairRequest> get copyWith => _$PairRequestCopyWithImpl<PairRequest>(this as PairRequest, _$identity);

  /// Serializes this PairRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PairRequest&&(identical(other.pairingCode, pairingCode) || other.pairingCode == pairingCode)&&(identical(other.deviceName, deviceName) || other.deviceName == deviceName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pairingCode,deviceName);

@override
String toString() {
  return 'PairRequest(pairingCode: $pairingCode, deviceName: $deviceName)';
}


}

/// @nodoc
abstract mixin class $PairRequestCopyWith<$Res>  {
  factory $PairRequestCopyWith(PairRequest value, $Res Function(PairRequest) _then) = _$PairRequestCopyWithImpl;
@useResult
$Res call({
 String pairingCode, String deviceName
});




}
/// @nodoc
class _$PairRequestCopyWithImpl<$Res>
    implements $PairRequestCopyWith<$Res> {
  _$PairRequestCopyWithImpl(this._self, this._then);

  final PairRequest _self;
  final $Res Function(PairRequest) _then;

/// Create a copy of PairRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pairingCode = null,Object? deviceName = null,}) {
  return _then(_self.copyWith(
pairingCode: null == pairingCode ? _self.pairingCode : pairingCode // ignore: cast_nullable_to_non_nullable
as String,deviceName: null == deviceName ? _self.deviceName : deviceName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PairRequest].
extension PairRequestPatterns on PairRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PairRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PairRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PairRequest value)  $default,){
final _that = this;
switch (_that) {
case _PairRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PairRequest value)?  $default,){
final _that = this;
switch (_that) {
case _PairRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String pairingCode,  String deviceName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PairRequest() when $default != null:
return $default(_that.pairingCode,_that.deviceName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String pairingCode,  String deviceName)  $default,) {final _that = this;
switch (_that) {
case _PairRequest():
return $default(_that.pairingCode,_that.deviceName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String pairingCode,  String deviceName)?  $default,) {final _that = this;
switch (_that) {
case _PairRequest() when $default != null:
return $default(_that.pairingCode,_that.deviceName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PairRequest implements PairRequest {
  const _PairRequest({required this.pairingCode, required this.deviceName});
  factory _PairRequest.fromJson(Map<String, dynamic> json) => _$PairRequestFromJson(json);

@override final  String pairingCode;
@override final  String deviceName;

/// Create a copy of PairRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PairRequestCopyWith<_PairRequest> get copyWith => __$PairRequestCopyWithImpl<_PairRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PairRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PairRequest&&(identical(other.pairingCode, pairingCode) || other.pairingCode == pairingCode)&&(identical(other.deviceName, deviceName) || other.deviceName == deviceName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pairingCode,deviceName);

@override
String toString() {
  return 'PairRequest(pairingCode: $pairingCode, deviceName: $deviceName)';
}


}

/// @nodoc
abstract mixin class _$PairRequestCopyWith<$Res> implements $PairRequestCopyWith<$Res> {
  factory _$PairRequestCopyWith(_PairRequest value, $Res Function(_PairRequest) _then) = __$PairRequestCopyWithImpl;
@override @useResult
$Res call({
 String pairingCode, String deviceName
});




}
/// @nodoc
class __$PairRequestCopyWithImpl<$Res>
    implements _$PairRequestCopyWith<$Res> {
  __$PairRequestCopyWithImpl(this._self, this._then);

  final _PairRequest _self;
  final $Res Function(_PairRequest) _then;

/// Create a copy of PairRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pairingCode = null,Object? deviceName = null,}) {
  return _then(_PairRequest(
pairingCode: null == pairingCode ? _self.pairingCode : pairingCode // ignore: cast_nullable_to_non_nullable
as String,deviceName: null == deviceName ? _self.deviceName : deviceName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$PairResponse {

 int get deviceId; String get token; DateTime get serverTime;
/// Create a copy of PairResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PairResponseCopyWith<PairResponse> get copyWith => _$PairResponseCopyWithImpl<PairResponse>(this as PairResponse, _$identity);

  /// Serializes this PairResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PairResponse&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.token, token) || other.token == token)&&(identical(other.serverTime, serverTime) || other.serverTime == serverTime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,deviceId,token,serverTime);

@override
String toString() {
  return 'PairResponse(deviceId: $deviceId, token: $token, serverTime: $serverTime)';
}


}

/// @nodoc
abstract mixin class $PairResponseCopyWith<$Res>  {
  factory $PairResponseCopyWith(PairResponse value, $Res Function(PairResponse) _then) = _$PairResponseCopyWithImpl;
@useResult
$Res call({
 int deviceId, String token, DateTime serverTime
});




}
/// @nodoc
class _$PairResponseCopyWithImpl<$Res>
    implements $PairResponseCopyWith<$Res> {
  _$PairResponseCopyWithImpl(this._self, this._then);

  final PairResponse _self;
  final $Res Function(PairResponse) _then;

/// Create a copy of PairResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? deviceId = null,Object? token = null,Object? serverTime = null,}) {
  return _then(_self.copyWith(
deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as int,token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,serverTime: null == serverTime ? _self.serverTime : serverTime // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [PairResponse].
extension PairResponsePatterns on PairResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PairResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PairResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PairResponse value)  $default,){
final _that = this;
switch (_that) {
case _PairResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PairResponse value)?  $default,){
final _that = this;
switch (_that) {
case _PairResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int deviceId,  String token,  DateTime serverTime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PairResponse() when $default != null:
return $default(_that.deviceId,_that.token,_that.serverTime);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int deviceId,  String token,  DateTime serverTime)  $default,) {final _that = this;
switch (_that) {
case _PairResponse():
return $default(_that.deviceId,_that.token,_that.serverTime);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int deviceId,  String token,  DateTime serverTime)?  $default,) {final _that = this;
switch (_that) {
case _PairResponse() when $default != null:
return $default(_that.deviceId,_that.token,_that.serverTime);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PairResponse implements PairResponse {
  const _PairResponse({required this.deviceId, required this.token, required this.serverTime});
  factory _PairResponse.fromJson(Map<String, dynamic> json) => _$PairResponseFromJson(json);

@override final  int deviceId;
@override final  String token;
@override final  DateTime serverTime;

/// Create a copy of PairResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PairResponseCopyWith<_PairResponse> get copyWith => __$PairResponseCopyWithImpl<_PairResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PairResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PairResponse&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.token, token) || other.token == token)&&(identical(other.serverTime, serverTime) || other.serverTime == serverTime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,deviceId,token,serverTime);

@override
String toString() {
  return 'PairResponse(deviceId: $deviceId, token: $token, serverTime: $serverTime)';
}


}

/// @nodoc
abstract mixin class _$PairResponseCopyWith<$Res> implements $PairResponseCopyWith<$Res> {
  factory _$PairResponseCopyWith(_PairResponse value, $Res Function(_PairResponse) _then) = __$PairResponseCopyWithImpl;
@override @useResult
$Res call({
 int deviceId, String token, DateTime serverTime
});




}
/// @nodoc
class __$PairResponseCopyWithImpl<$Res>
    implements _$PairResponseCopyWith<$Res> {
  __$PairResponseCopyWithImpl(this._self, this._then);

  final _PairResponse _self;
  final $Res Function(_PairResponse) _then;

/// Create a copy of PairResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? deviceId = null,Object? token = null,Object? serverTime = null,}) {
  return _then(_PairResponse(
deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as int,token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,serverTime: null == serverTime ? _self.serverTime : serverTime // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$KitchenOrderItem {

 String get name; int get quantity; List<String> get options; String? get note;
/// Create a copy of KitchenOrderItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KitchenOrderItemCopyWith<KitchenOrderItem> get copyWith => _$KitchenOrderItemCopyWithImpl<KitchenOrderItem>(this as KitchenOrderItem, _$identity);

  /// Serializes this KitchenOrderItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KitchenOrderItem&&(identical(other.name, name) || other.name == name)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&const DeepCollectionEquality().equals(other.options, options)&&(identical(other.note, note) || other.note == note));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,quantity,const DeepCollectionEquality().hash(options),note);

@override
String toString() {
  return 'KitchenOrderItem(name: $name, quantity: $quantity, options: $options, note: $note)';
}


}

/// @nodoc
abstract mixin class $KitchenOrderItemCopyWith<$Res>  {
  factory $KitchenOrderItemCopyWith(KitchenOrderItem value, $Res Function(KitchenOrderItem) _then) = _$KitchenOrderItemCopyWithImpl;
@useResult
$Res call({
 String name, int quantity, List<String> options, String? note
});




}
/// @nodoc
class _$KitchenOrderItemCopyWithImpl<$Res>
    implements $KitchenOrderItemCopyWith<$Res> {
  _$KitchenOrderItemCopyWithImpl(this._self, this._then);

  final KitchenOrderItem _self;
  final $Res Function(KitchenOrderItem) _then;

/// Create a copy of KitchenOrderItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? quantity = null,Object? options = null,Object? note = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as List<String>,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [KitchenOrderItem].
extension KitchenOrderItemPatterns on KitchenOrderItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _KitchenOrderItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _KitchenOrderItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _KitchenOrderItem value)  $default,){
final _that = this;
switch (_that) {
case _KitchenOrderItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _KitchenOrderItem value)?  $default,){
final _that = this;
switch (_that) {
case _KitchenOrderItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  int quantity,  List<String> options,  String? note)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _KitchenOrderItem() when $default != null:
return $default(_that.name,_that.quantity,_that.options,_that.note);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  int quantity,  List<String> options,  String? note)  $default,) {final _that = this;
switch (_that) {
case _KitchenOrderItem():
return $default(_that.name,_that.quantity,_that.options,_that.note);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  int quantity,  List<String> options,  String? note)?  $default,) {final _that = this;
switch (_that) {
case _KitchenOrderItem() when $default != null:
return $default(_that.name,_that.quantity,_that.options,_that.note);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _KitchenOrderItem implements KitchenOrderItem {
  const _KitchenOrderItem({required this.name, required this.quantity, final  List<String> options = const <String>[], this.note}): _options = options;
  factory _KitchenOrderItem.fromJson(Map<String, dynamic> json) => _$KitchenOrderItemFromJson(json);

@override final  String name;
@override final  int quantity;
 final  List<String> _options;
@override@JsonKey() List<String> get options {
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_options);
}

@override final  String? note;

/// Create a copy of KitchenOrderItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$KitchenOrderItemCopyWith<_KitchenOrderItem> get copyWith => __$KitchenOrderItemCopyWithImpl<_KitchenOrderItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$KitchenOrderItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _KitchenOrderItem&&(identical(other.name, name) || other.name == name)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&const DeepCollectionEquality().equals(other._options, _options)&&(identical(other.note, note) || other.note == note));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,quantity,const DeepCollectionEquality().hash(_options),note);

@override
String toString() {
  return 'KitchenOrderItem(name: $name, quantity: $quantity, options: $options, note: $note)';
}


}

/// @nodoc
abstract mixin class _$KitchenOrderItemCopyWith<$Res> implements $KitchenOrderItemCopyWith<$Res> {
  factory _$KitchenOrderItemCopyWith(_KitchenOrderItem value, $Res Function(_KitchenOrderItem) _then) = __$KitchenOrderItemCopyWithImpl;
@override @useResult
$Res call({
 String name, int quantity, List<String> options, String? note
});




}
/// @nodoc
class __$KitchenOrderItemCopyWithImpl<$Res>
    implements _$KitchenOrderItemCopyWith<$Res> {
  __$KitchenOrderItemCopyWithImpl(this._self, this._then);

  final _KitchenOrderItem _self;
  final $Res Function(_KitchenOrderItem) _then;

/// Create a copy of KitchenOrderItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? quantity = null,Object? options = null,Object? note = freezed,}) {
  return _then(_KitchenOrderItem(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,options: null == options ? _self._options : options // ignore: cast_nullable_to_non_nullable
as List<String>,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$KitchenOrder {

 int get id; String get orderNumber;@OrderStatusConverter() OrderStatus get status;@DeliveryTypeConverter() DeliveryType get deliveryType; List<KitchenOrderItem> get items; DateTime get createdAt; DateTime get updatedAt; DateTime? get requestedAt;/// Yalnızca ad + soyad baş harfi. Telefon/adres/e-posta gönderilmez.
 String? get customerLabel; String? get customerNote;
/// Create a copy of KitchenOrder
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KitchenOrderCopyWith<KitchenOrder> get copyWith => _$KitchenOrderCopyWithImpl<KitchenOrder>(this as KitchenOrder, _$identity);

  /// Serializes this KitchenOrder to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KitchenOrder&&(identical(other.id, id) || other.id == id)&&(identical(other.orderNumber, orderNumber) || other.orderNumber == orderNumber)&&(identical(other.status, status) || other.status == status)&&(identical(other.deliveryType, deliveryType) || other.deliveryType == deliveryType)&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.requestedAt, requestedAt) || other.requestedAt == requestedAt)&&(identical(other.customerLabel, customerLabel) || other.customerLabel == customerLabel)&&(identical(other.customerNote, customerNote) || other.customerNote == customerNote));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,orderNumber,status,deliveryType,const DeepCollectionEquality().hash(items),createdAt,updatedAt,requestedAt,customerLabel,customerNote);

@override
String toString() {
  return 'KitchenOrder(id: $id, orderNumber: $orderNumber, status: $status, deliveryType: $deliveryType, items: $items, createdAt: $createdAt, updatedAt: $updatedAt, requestedAt: $requestedAt, customerLabel: $customerLabel, customerNote: $customerNote)';
}


}

/// @nodoc
abstract mixin class $KitchenOrderCopyWith<$Res>  {
  factory $KitchenOrderCopyWith(KitchenOrder value, $Res Function(KitchenOrder) _then) = _$KitchenOrderCopyWithImpl;
@useResult
$Res call({
 int id, String orderNumber,@OrderStatusConverter() OrderStatus status,@DeliveryTypeConverter() DeliveryType deliveryType, List<KitchenOrderItem> items, DateTime createdAt, DateTime updatedAt, DateTime? requestedAt, String? customerLabel, String? customerNote
});




}
/// @nodoc
class _$KitchenOrderCopyWithImpl<$Res>
    implements $KitchenOrderCopyWith<$Res> {
  _$KitchenOrderCopyWithImpl(this._self, this._then);

  final KitchenOrder _self;
  final $Res Function(KitchenOrder) _then;

/// Create a copy of KitchenOrder
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? orderNumber = null,Object? status = null,Object? deliveryType = null,Object? items = null,Object? createdAt = null,Object? updatedAt = null,Object? requestedAt = freezed,Object? customerLabel = freezed,Object? customerNote = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,orderNumber: null == orderNumber ? _self.orderNumber : orderNumber // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as OrderStatus,deliveryType: null == deliveryType ? _self.deliveryType : deliveryType // ignore: cast_nullable_to_non_nullable
as DeliveryType,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<KitchenOrderItem>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,requestedAt: freezed == requestedAt ? _self.requestedAt : requestedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,customerLabel: freezed == customerLabel ? _self.customerLabel : customerLabel // ignore: cast_nullable_to_non_nullable
as String?,customerNote: freezed == customerNote ? _self.customerNote : customerNote // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [KitchenOrder].
extension KitchenOrderPatterns on KitchenOrder {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _KitchenOrder value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _KitchenOrder() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _KitchenOrder value)  $default,){
final _that = this;
switch (_that) {
case _KitchenOrder():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _KitchenOrder value)?  $default,){
final _that = this;
switch (_that) {
case _KitchenOrder() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String orderNumber, @OrderStatusConverter()  OrderStatus status, @DeliveryTypeConverter()  DeliveryType deliveryType,  List<KitchenOrderItem> items,  DateTime createdAt,  DateTime updatedAt,  DateTime? requestedAt,  String? customerLabel,  String? customerNote)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _KitchenOrder() when $default != null:
return $default(_that.id,_that.orderNumber,_that.status,_that.deliveryType,_that.items,_that.createdAt,_that.updatedAt,_that.requestedAt,_that.customerLabel,_that.customerNote);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String orderNumber, @OrderStatusConverter()  OrderStatus status, @DeliveryTypeConverter()  DeliveryType deliveryType,  List<KitchenOrderItem> items,  DateTime createdAt,  DateTime updatedAt,  DateTime? requestedAt,  String? customerLabel,  String? customerNote)  $default,) {final _that = this;
switch (_that) {
case _KitchenOrder():
return $default(_that.id,_that.orderNumber,_that.status,_that.deliveryType,_that.items,_that.createdAt,_that.updatedAt,_that.requestedAt,_that.customerLabel,_that.customerNote);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String orderNumber, @OrderStatusConverter()  OrderStatus status, @DeliveryTypeConverter()  DeliveryType deliveryType,  List<KitchenOrderItem> items,  DateTime createdAt,  DateTime updatedAt,  DateTime? requestedAt,  String? customerLabel,  String? customerNote)?  $default,) {final _that = this;
switch (_that) {
case _KitchenOrder() when $default != null:
return $default(_that.id,_that.orderNumber,_that.status,_that.deliveryType,_that.items,_that.createdAt,_that.updatedAt,_that.requestedAt,_that.customerLabel,_that.customerNote);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _KitchenOrder extends KitchenOrder {
  const _KitchenOrder({required this.id, required this.orderNumber, @OrderStatusConverter() required this.status, @DeliveryTypeConverter() required this.deliveryType, required final  List<KitchenOrderItem> items, required this.createdAt, required this.updatedAt, this.requestedAt, this.customerLabel, this.customerNote}): _items = items,super._();
  factory _KitchenOrder.fromJson(Map<String, dynamic> json) => _$KitchenOrderFromJson(json);

@override final  int id;
@override final  String orderNumber;
@override@OrderStatusConverter() final  OrderStatus status;
@override@DeliveryTypeConverter() final  DeliveryType deliveryType;
 final  List<KitchenOrderItem> _items;
@override List<KitchenOrderItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override final  DateTime? requestedAt;
/// Yalnızca ad + soyad baş harfi. Telefon/adres/e-posta gönderilmez.
@override final  String? customerLabel;
@override final  String? customerNote;

/// Create a copy of KitchenOrder
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$KitchenOrderCopyWith<_KitchenOrder> get copyWith => __$KitchenOrderCopyWithImpl<_KitchenOrder>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$KitchenOrderToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _KitchenOrder&&(identical(other.id, id) || other.id == id)&&(identical(other.orderNumber, orderNumber) || other.orderNumber == orderNumber)&&(identical(other.status, status) || other.status == status)&&(identical(other.deliveryType, deliveryType) || other.deliveryType == deliveryType)&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.requestedAt, requestedAt) || other.requestedAt == requestedAt)&&(identical(other.customerLabel, customerLabel) || other.customerLabel == customerLabel)&&(identical(other.customerNote, customerNote) || other.customerNote == customerNote));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,orderNumber,status,deliveryType,const DeepCollectionEquality().hash(_items),createdAt,updatedAt,requestedAt,customerLabel,customerNote);

@override
String toString() {
  return 'KitchenOrder(id: $id, orderNumber: $orderNumber, status: $status, deliveryType: $deliveryType, items: $items, createdAt: $createdAt, updatedAt: $updatedAt, requestedAt: $requestedAt, customerLabel: $customerLabel, customerNote: $customerNote)';
}


}

/// @nodoc
abstract mixin class _$KitchenOrderCopyWith<$Res> implements $KitchenOrderCopyWith<$Res> {
  factory _$KitchenOrderCopyWith(_KitchenOrder value, $Res Function(_KitchenOrder) _then) = __$KitchenOrderCopyWithImpl;
@override @useResult
$Res call({
 int id, String orderNumber,@OrderStatusConverter() OrderStatus status,@DeliveryTypeConverter() DeliveryType deliveryType, List<KitchenOrderItem> items, DateTime createdAt, DateTime updatedAt, DateTime? requestedAt, String? customerLabel, String? customerNote
});




}
/// @nodoc
class __$KitchenOrderCopyWithImpl<$Res>
    implements _$KitchenOrderCopyWith<$Res> {
  __$KitchenOrderCopyWithImpl(this._self, this._then);

  final _KitchenOrder _self;
  final $Res Function(_KitchenOrder) _then;

/// Create a copy of KitchenOrder
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? orderNumber = null,Object? status = null,Object? deliveryType = null,Object? items = null,Object? createdAt = null,Object? updatedAt = null,Object? requestedAt = freezed,Object? customerLabel = freezed,Object? customerNote = freezed,}) {
  return _then(_KitchenOrder(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,orderNumber: null == orderNumber ? _self.orderNumber : orderNumber // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as OrderStatus,deliveryType: null == deliveryType ? _self.deliveryType : deliveryType // ignore: cast_nullable_to_non_nullable
as DeliveryType,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<KitchenOrderItem>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,requestedAt: freezed == requestedAt ? _self.requestedAt : requestedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,customerLabel: freezed == customerLabel ? _self.customerLabel : customerLabel // ignore: cast_nullable_to_non_nullable
as String?,customerNote: freezed == customerNote ? _self.customerNote : customerNote // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$KitchenOrderPage {

 List<KitchenOrder> get data; DateTime get serverTime; int get maxId;
/// Create a copy of KitchenOrderPage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KitchenOrderPageCopyWith<KitchenOrderPage> get copyWith => _$KitchenOrderPageCopyWithImpl<KitchenOrderPage>(this as KitchenOrderPage, _$identity);

  /// Serializes this KitchenOrderPage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KitchenOrderPage&&const DeepCollectionEquality().equals(other.data, data)&&(identical(other.serverTime, serverTime) || other.serverTime == serverTime)&&(identical(other.maxId, maxId) || other.maxId == maxId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data),serverTime,maxId);

@override
String toString() {
  return 'KitchenOrderPage(data: $data, serverTime: $serverTime, maxId: $maxId)';
}


}

/// @nodoc
abstract mixin class $KitchenOrderPageCopyWith<$Res>  {
  factory $KitchenOrderPageCopyWith(KitchenOrderPage value, $Res Function(KitchenOrderPage) _then) = _$KitchenOrderPageCopyWithImpl;
@useResult
$Res call({
 List<KitchenOrder> data, DateTime serverTime, int maxId
});




}
/// @nodoc
class _$KitchenOrderPageCopyWithImpl<$Res>
    implements $KitchenOrderPageCopyWith<$Res> {
  _$KitchenOrderPageCopyWithImpl(this._self, this._then);

  final KitchenOrderPage _self;
  final $Res Function(KitchenOrderPage) _then;

/// Create a copy of KitchenOrderPage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,Object? serverTime = null,Object? maxId = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<KitchenOrder>,serverTime: null == serverTime ? _self.serverTime : serverTime // ignore: cast_nullable_to_non_nullable
as DateTime,maxId: null == maxId ? _self.maxId : maxId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [KitchenOrderPage].
extension KitchenOrderPagePatterns on KitchenOrderPage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _KitchenOrderPage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _KitchenOrderPage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _KitchenOrderPage value)  $default,){
final _that = this;
switch (_that) {
case _KitchenOrderPage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _KitchenOrderPage value)?  $default,){
final _that = this;
switch (_that) {
case _KitchenOrderPage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<KitchenOrder> data,  DateTime serverTime,  int maxId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _KitchenOrderPage() when $default != null:
return $default(_that.data,_that.serverTime,_that.maxId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<KitchenOrder> data,  DateTime serverTime,  int maxId)  $default,) {final _that = this;
switch (_that) {
case _KitchenOrderPage():
return $default(_that.data,_that.serverTime,_that.maxId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<KitchenOrder> data,  DateTime serverTime,  int maxId)?  $default,) {final _that = this;
switch (_that) {
case _KitchenOrderPage() when $default != null:
return $default(_that.data,_that.serverTime,_that.maxId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _KitchenOrderPage implements KitchenOrderPage {
  const _KitchenOrderPage({required final  List<KitchenOrder> data, required this.serverTime, required this.maxId}): _data = data;
  factory _KitchenOrderPage.fromJson(Map<String, dynamic> json) => _$KitchenOrderPageFromJson(json);

 final  List<KitchenOrder> _data;
@override List<KitchenOrder> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}

@override final  DateTime serverTime;
@override final  int maxId;

/// Create a copy of KitchenOrderPage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$KitchenOrderPageCopyWith<_KitchenOrderPage> get copyWith => __$KitchenOrderPageCopyWithImpl<_KitchenOrderPage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$KitchenOrderPageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _KitchenOrderPage&&const DeepCollectionEquality().equals(other._data, _data)&&(identical(other.serverTime, serverTime) || other.serverTime == serverTime)&&(identical(other.maxId, maxId) || other.maxId == maxId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data),serverTime,maxId);

@override
String toString() {
  return 'KitchenOrderPage(data: $data, serverTime: $serverTime, maxId: $maxId)';
}


}

/// @nodoc
abstract mixin class _$KitchenOrderPageCopyWith<$Res> implements $KitchenOrderPageCopyWith<$Res> {
  factory _$KitchenOrderPageCopyWith(_KitchenOrderPage value, $Res Function(_KitchenOrderPage) _then) = __$KitchenOrderPageCopyWithImpl;
@override @useResult
$Res call({
 List<KitchenOrder> data, DateTime serverTime, int maxId
});




}
/// @nodoc
class __$KitchenOrderPageCopyWithImpl<$Res>
    implements _$KitchenOrderPageCopyWith<$Res> {
  __$KitchenOrderPageCopyWithImpl(this._self, this._then);

  final _KitchenOrderPage _self;
  final $Res Function(_KitchenOrderPage) _then;

/// Create a copy of KitchenOrderPage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,Object? serverTime = null,Object? maxId = null,}) {
  return _then(_KitchenOrderPage(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<KitchenOrder>,serverTime: null == serverTime ? _self.serverTime : serverTime // ignore: cast_nullable_to_non_nullable
as DateTime,maxId: null == maxId ? _self.maxId : maxId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$ReceiptLine {

 int get quantity; String get name; List<String> get options; String? get note;
/// Create a copy of ReceiptLine
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReceiptLineCopyWith<ReceiptLine> get copyWith => _$ReceiptLineCopyWithImpl<ReceiptLine>(this as ReceiptLine, _$identity);

  /// Serializes this ReceiptLine to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReceiptLine&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.options, options)&&(identical(other.note, note) || other.note == note));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,quantity,name,const DeepCollectionEquality().hash(options),note);

@override
String toString() {
  return 'ReceiptLine(quantity: $quantity, name: $name, options: $options, note: $note)';
}


}

/// @nodoc
abstract mixin class $ReceiptLineCopyWith<$Res>  {
  factory $ReceiptLineCopyWith(ReceiptLine value, $Res Function(ReceiptLine) _then) = _$ReceiptLineCopyWithImpl;
@useResult
$Res call({
 int quantity, String name, List<String> options, String? note
});




}
/// @nodoc
class _$ReceiptLineCopyWithImpl<$Res>
    implements $ReceiptLineCopyWith<$Res> {
  _$ReceiptLineCopyWithImpl(this._self, this._then);

  final ReceiptLine _self;
  final $Res Function(ReceiptLine) _then;

/// Create a copy of ReceiptLine
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? quantity = null,Object? name = null,Object? options = null,Object? note = freezed,}) {
  return _then(_self.copyWith(
quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as List<String>,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ReceiptLine].
extension ReceiptLinePatterns on ReceiptLine {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReceiptLine value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReceiptLine() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReceiptLine value)  $default,){
final _that = this;
switch (_that) {
case _ReceiptLine():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReceiptLine value)?  $default,){
final _that = this;
switch (_that) {
case _ReceiptLine() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int quantity,  String name,  List<String> options,  String? note)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReceiptLine() when $default != null:
return $default(_that.quantity,_that.name,_that.options,_that.note);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int quantity,  String name,  List<String> options,  String? note)  $default,) {final _that = this;
switch (_that) {
case _ReceiptLine():
return $default(_that.quantity,_that.name,_that.options,_that.note);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int quantity,  String name,  List<String> options,  String? note)?  $default,) {final _that = this;
switch (_that) {
case _ReceiptLine() when $default != null:
return $default(_that.quantity,_that.name,_that.options,_that.note);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReceiptLine implements ReceiptLine {
  const _ReceiptLine({required this.quantity, required this.name, final  List<String> options = const <String>[], this.note}): _options = options;
  factory _ReceiptLine.fromJson(Map<String, dynamic> json) => _$ReceiptLineFromJson(json);

@override final  int quantity;
@override final  String name;
 final  List<String> _options;
@override@JsonKey() List<String> get options {
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_options);
}

@override final  String? note;

/// Create a copy of ReceiptLine
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReceiptLineCopyWith<_ReceiptLine> get copyWith => __$ReceiptLineCopyWithImpl<_ReceiptLine>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReceiptLineToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReceiptLine&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other._options, _options)&&(identical(other.note, note) || other.note == note));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,quantity,name,const DeepCollectionEquality().hash(_options),note);

@override
String toString() {
  return 'ReceiptLine(quantity: $quantity, name: $name, options: $options, note: $note)';
}


}

/// @nodoc
abstract mixin class _$ReceiptLineCopyWith<$Res> implements $ReceiptLineCopyWith<$Res> {
  factory _$ReceiptLineCopyWith(_ReceiptLine value, $Res Function(_ReceiptLine) _then) = __$ReceiptLineCopyWithImpl;
@override @useResult
$Res call({
 int quantity, String name, List<String> options, String? note
});




}
/// @nodoc
class __$ReceiptLineCopyWithImpl<$Res>
    implements _$ReceiptLineCopyWith<$Res> {
  __$ReceiptLineCopyWithImpl(this._self, this._then);

  final _ReceiptLine _self;
  final $Res Function(_ReceiptLine) _then;

/// Create a copy of ReceiptLine
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? quantity = null,Object? name = null,Object? options = null,Object? note = freezed,}) {
  return _then(_ReceiptLine(
quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,options: null == options ? _self._options : options // ignore: cast_nullable_to_non_nullable
as List<String>,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$KitchenReceipt {

 String get orderNumber;@DeliveryTypeConverter() DeliveryType get deliveryType; List<ReceiptLine> get lines; String get type; DateTime? get requestedAt; String? get customerNote; DateTime? get printedAt;
/// Create a copy of KitchenReceipt
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KitchenReceiptCopyWith<KitchenReceipt> get copyWith => _$KitchenReceiptCopyWithImpl<KitchenReceipt>(this as KitchenReceipt, _$identity);

  /// Serializes this KitchenReceipt to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KitchenReceipt&&(identical(other.orderNumber, orderNumber) || other.orderNumber == orderNumber)&&(identical(other.deliveryType, deliveryType) || other.deliveryType == deliveryType)&&const DeepCollectionEquality().equals(other.lines, lines)&&(identical(other.type, type) || other.type == type)&&(identical(other.requestedAt, requestedAt) || other.requestedAt == requestedAt)&&(identical(other.customerNote, customerNote) || other.customerNote == customerNote)&&(identical(other.printedAt, printedAt) || other.printedAt == printedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,orderNumber,deliveryType,const DeepCollectionEquality().hash(lines),type,requestedAt,customerNote,printedAt);

@override
String toString() {
  return 'KitchenReceipt(orderNumber: $orderNumber, deliveryType: $deliveryType, lines: $lines, type: $type, requestedAt: $requestedAt, customerNote: $customerNote, printedAt: $printedAt)';
}


}

/// @nodoc
abstract mixin class $KitchenReceiptCopyWith<$Res>  {
  factory $KitchenReceiptCopyWith(KitchenReceipt value, $Res Function(KitchenReceipt) _then) = _$KitchenReceiptCopyWithImpl;
@useResult
$Res call({
 String orderNumber,@DeliveryTypeConverter() DeliveryType deliveryType, List<ReceiptLine> lines, String type, DateTime? requestedAt, String? customerNote, DateTime? printedAt
});




}
/// @nodoc
class _$KitchenReceiptCopyWithImpl<$Res>
    implements $KitchenReceiptCopyWith<$Res> {
  _$KitchenReceiptCopyWithImpl(this._self, this._then);

  final KitchenReceipt _self;
  final $Res Function(KitchenReceipt) _then;

/// Create a copy of KitchenReceipt
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? orderNumber = null,Object? deliveryType = null,Object? lines = null,Object? type = null,Object? requestedAt = freezed,Object? customerNote = freezed,Object? printedAt = freezed,}) {
  return _then(_self.copyWith(
orderNumber: null == orderNumber ? _self.orderNumber : orderNumber // ignore: cast_nullable_to_non_nullable
as String,deliveryType: null == deliveryType ? _self.deliveryType : deliveryType // ignore: cast_nullable_to_non_nullable
as DeliveryType,lines: null == lines ? _self.lines : lines // ignore: cast_nullable_to_non_nullable
as List<ReceiptLine>,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,requestedAt: freezed == requestedAt ? _self.requestedAt : requestedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,customerNote: freezed == customerNote ? _self.customerNote : customerNote // ignore: cast_nullable_to_non_nullable
as String?,printedAt: freezed == printedAt ? _self.printedAt : printedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [KitchenReceipt].
extension KitchenReceiptPatterns on KitchenReceipt {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _KitchenReceipt value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _KitchenReceipt() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _KitchenReceipt value)  $default,){
final _that = this;
switch (_that) {
case _KitchenReceipt():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _KitchenReceipt value)?  $default,){
final _that = this;
switch (_that) {
case _KitchenReceipt() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String orderNumber, @DeliveryTypeConverter()  DeliveryType deliveryType,  List<ReceiptLine> lines,  String type,  DateTime? requestedAt,  String? customerNote,  DateTime? printedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _KitchenReceipt() when $default != null:
return $default(_that.orderNumber,_that.deliveryType,_that.lines,_that.type,_that.requestedAt,_that.customerNote,_that.printedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String orderNumber, @DeliveryTypeConverter()  DeliveryType deliveryType,  List<ReceiptLine> lines,  String type,  DateTime? requestedAt,  String? customerNote,  DateTime? printedAt)  $default,) {final _that = this;
switch (_that) {
case _KitchenReceipt():
return $default(_that.orderNumber,_that.deliveryType,_that.lines,_that.type,_that.requestedAt,_that.customerNote,_that.printedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String orderNumber, @DeliveryTypeConverter()  DeliveryType deliveryType,  List<ReceiptLine> lines,  String type,  DateTime? requestedAt,  String? customerNote,  DateTime? printedAt)?  $default,) {final _that = this;
switch (_that) {
case _KitchenReceipt() when $default != null:
return $default(_that.orderNumber,_that.deliveryType,_that.lines,_that.type,_that.requestedAt,_that.customerNote,_that.printedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _KitchenReceipt implements KitchenReceipt {
  const _KitchenReceipt({required this.orderNumber, @DeliveryTypeConverter() required this.deliveryType, required final  List<ReceiptLine> lines, this.type = 'mutfak', this.requestedAt, this.customerNote, this.printedAt}): _lines = lines;
  factory _KitchenReceipt.fromJson(Map<String, dynamic> json) => _$KitchenReceiptFromJson(json);

@override final  String orderNumber;
@override@DeliveryTypeConverter() final  DeliveryType deliveryType;
 final  List<ReceiptLine> _lines;
@override List<ReceiptLine> get lines {
  if (_lines is EqualUnmodifiableListView) return _lines;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lines);
}

@override@JsonKey() final  String type;
@override final  DateTime? requestedAt;
@override final  String? customerNote;
@override final  DateTime? printedAt;

/// Create a copy of KitchenReceipt
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$KitchenReceiptCopyWith<_KitchenReceipt> get copyWith => __$KitchenReceiptCopyWithImpl<_KitchenReceipt>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$KitchenReceiptToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _KitchenReceipt&&(identical(other.orderNumber, orderNumber) || other.orderNumber == orderNumber)&&(identical(other.deliveryType, deliveryType) || other.deliveryType == deliveryType)&&const DeepCollectionEquality().equals(other._lines, _lines)&&(identical(other.type, type) || other.type == type)&&(identical(other.requestedAt, requestedAt) || other.requestedAt == requestedAt)&&(identical(other.customerNote, customerNote) || other.customerNote == customerNote)&&(identical(other.printedAt, printedAt) || other.printedAt == printedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,orderNumber,deliveryType,const DeepCollectionEquality().hash(_lines),type,requestedAt,customerNote,printedAt);

@override
String toString() {
  return 'KitchenReceipt(orderNumber: $orderNumber, deliveryType: $deliveryType, lines: $lines, type: $type, requestedAt: $requestedAt, customerNote: $customerNote, printedAt: $printedAt)';
}


}

/// @nodoc
abstract mixin class _$KitchenReceiptCopyWith<$Res> implements $KitchenReceiptCopyWith<$Res> {
  factory _$KitchenReceiptCopyWith(_KitchenReceipt value, $Res Function(_KitchenReceipt) _then) = __$KitchenReceiptCopyWithImpl;
@override @useResult
$Res call({
 String orderNumber,@DeliveryTypeConverter() DeliveryType deliveryType, List<ReceiptLine> lines, String type, DateTime? requestedAt, String? customerNote, DateTime? printedAt
});




}
/// @nodoc
class __$KitchenReceiptCopyWithImpl<$Res>
    implements _$KitchenReceiptCopyWith<$Res> {
  __$KitchenReceiptCopyWithImpl(this._self, this._then);

  final _KitchenReceipt _self;
  final $Res Function(_KitchenReceipt) _then;

/// Create a copy of KitchenReceipt
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? orderNumber = null,Object? deliveryType = null,Object? lines = null,Object? type = null,Object? requestedAt = freezed,Object? customerNote = freezed,Object? printedAt = freezed,}) {
  return _then(_KitchenReceipt(
orderNumber: null == orderNumber ? _self.orderNumber : orderNumber // ignore: cast_nullable_to_non_nullable
as String,deliveryType: null == deliveryType ? _self.deliveryType : deliveryType // ignore: cast_nullable_to_non_nullable
as DeliveryType,lines: null == lines ? _self._lines : lines // ignore: cast_nullable_to_non_nullable
as List<ReceiptLine>,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,requestedAt: freezed == requestedAt ? _self.requestedAt : requestedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,customerNote: freezed == customerNote ? _self.customerNote : customerNote // ignore: cast_nullable_to_non_nullable
as String?,printedAt: freezed == printedAt ? _self.printedAt : printedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$CustomerReceipt {

 String get orderNumber;@DeliveryTypeConverter() DeliveryType get deliveryType; List<OrderItem> get items; int get subtotal; int get deliveryFee; int get total; String get currency; Payment get payment; String get type;/// `pickup` siparişte `null` — fişte adres bloğu basılmaz.
 Address? get address; DateTime? get requestedAt; String? get customerLabel; DateTime? get printedAt;
/// Create a copy of CustomerReceipt
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CustomerReceiptCopyWith<CustomerReceipt> get copyWith => _$CustomerReceiptCopyWithImpl<CustomerReceipt>(this as CustomerReceipt, _$identity);

  /// Serializes this CustomerReceipt to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CustomerReceipt&&(identical(other.orderNumber, orderNumber) || other.orderNumber == orderNumber)&&(identical(other.deliveryType, deliveryType) || other.deliveryType == deliveryType)&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.subtotal, subtotal) || other.subtotal == subtotal)&&(identical(other.deliveryFee, deliveryFee) || other.deliveryFee == deliveryFee)&&(identical(other.total, total) || other.total == total)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.payment, payment) || other.payment == payment)&&(identical(other.type, type) || other.type == type)&&(identical(other.address, address) || other.address == address)&&(identical(other.requestedAt, requestedAt) || other.requestedAt == requestedAt)&&(identical(other.customerLabel, customerLabel) || other.customerLabel == customerLabel)&&(identical(other.printedAt, printedAt) || other.printedAt == printedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,orderNumber,deliveryType,const DeepCollectionEquality().hash(items),subtotal,deliveryFee,total,currency,payment,type,address,requestedAt,customerLabel,printedAt);

@override
String toString() {
  return 'CustomerReceipt(orderNumber: $orderNumber, deliveryType: $deliveryType, items: $items, subtotal: $subtotal, deliveryFee: $deliveryFee, total: $total, currency: $currency, payment: $payment, type: $type, address: $address, requestedAt: $requestedAt, customerLabel: $customerLabel, printedAt: $printedAt)';
}


}

/// @nodoc
abstract mixin class $CustomerReceiptCopyWith<$Res>  {
  factory $CustomerReceiptCopyWith(CustomerReceipt value, $Res Function(CustomerReceipt) _then) = _$CustomerReceiptCopyWithImpl;
@useResult
$Res call({
 String orderNumber,@DeliveryTypeConverter() DeliveryType deliveryType, List<OrderItem> items, int subtotal, int deliveryFee, int total, String currency, Payment payment, String type, Address? address, DateTime? requestedAt, String? customerLabel, DateTime? printedAt
});


$PaymentCopyWith<$Res> get payment;$AddressCopyWith<$Res>? get address;

}
/// @nodoc
class _$CustomerReceiptCopyWithImpl<$Res>
    implements $CustomerReceiptCopyWith<$Res> {
  _$CustomerReceiptCopyWithImpl(this._self, this._then);

  final CustomerReceipt _self;
  final $Res Function(CustomerReceipt) _then;

/// Create a copy of CustomerReceipt
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? orderNumber = null,Object? deliveryType = null,Object? items = null,Object? subtotal = null,Object? deliveryFee = null,Object? total = null,Object? currency = null,Object? payment = null,Object? type = null,Object? address = freezed,Object? requestedAt = freezed,Object? customerLabel = freezed,Object? printedAt = freezed,}) {
  return _then(_self.copyWith(
orderNumber: null == orderNumber ? _self.orderNumber : orderNumber // ignore: cast_nullable_to_non_nullable
as String,deliveryType: null == deliveryType ? _self.deliveryType : deliveryType // ignore: cast_nullable_to_non_nullable
as DeliveryType,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<OrderItem>,subtotal: null == subtotal ? _self.subtotal : subtotal // ignore: cast_nullable_to_non_nullable
as int,deliveryFee: null == deliveryFee ? _self.deliveryFee : deliveryFee // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,payment: null == payment ? _self.payment : payment // ignore: cast_nullable_to_non_nullable
as Payment,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as Address?,requestedAt: freezed == requestedAt ? _self.requestedAt : requestedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,customerLabel: freezed == customerLabel ? _self.customerLabel : customerLabel // ignore: cast_nullable_to_non_nullable
as String?,printedAt: freezed == printedAt ? _self.printedAt : printedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of CustomerReceipt
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PaymentCopyWith<$Res> get payment {
  
  return $PaymentCopyWith<$Res>(_self.payment, (value) {
    return _then(_self.copyWith(payment: value));
  });
}/// Create a copy of CustomerReceipt
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


/// Adds pattern-matching-related methods to [CustomerReceipt].
extension CustomerReceiptPatterns on CustomerReceipt {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CustomerReceipt value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CustomerReceipt() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CustomerReceipt value)  $default,){
final _that = this;
switch (_that) {
case _CustomerReceipt():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CustomerReceipt value)?  $default,){
final _that = this;
switch (_that) {
case _CustomerReceipt() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String orderNumber, @DeliveryTypeConverter()  DeliveryType deliveryType,  List<OrderItem> items,  int subtotal,  int deliveryFee,  int total,  String currency,  Payment payment,  String type,  Address? address,  DateTime? requestedAt,  String? customerLabel,  DateTime? printedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CustomerReceipt() when $default != null:
return $default(_that.orderNumber,_that.deliveryType,_that.items,_that.subtotal,_that.deliveryFee,_that.total,_that.currency,_that.payment,_that.type,_that.address,_that.requestedAt,_that.customerLabel,_that.printedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String orderNumber, @DeliveryTypeConverter()  DeliveryType deliveryType,  List<OrderItem> items,  int subtotal,  int deliveryFee,  int total,  String currency,  Payment payment,  String type,  Address? address,  DateTime? requestedAt,  String? customerLabel,  DateTime? printedAt)  $default,) {final _that = this;
switch (_that) {
case _CustomerReceipt():
return $default(_that.orderNumber,_that.deliveryType,_that.items,_that.subtotal,_that.deliveryFee,_that.total,_that.currency,_that.payment,_that.type,_that.address,_that.requestedAt,_that.customerLabel,_that.printedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String orderNumber, @DeliveryTypeConverter()  DeliveryType deliveryType,  List<OrderItem> items,  int subtotal,  int deliveryFee,  int total,  String currency,  Payment payment,  String type,  Address? address,  DateTime? requestedAt,  String? customerLabel,  DateTime? printedAt)?  $default,) {final _that = this;
switch (_that) {
case _CustomerReceipt() when $default != null:
return $default(_that.orderNumber,_that.deliveryType,_that.items,_that.subtotal,_that.deliveryFee,_that.total,_that.currency,_that.payment,_that.type,_that.address,_that.requestedAt,_that.customerLabel,_that.printedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CustomerReceipt implements CustomerReceipt {
  const _CustomerReceipt({required this.orderNumber, @DeliveryTypeConverter() required this.deliveryType, required final  List<OrderItem> items, required this.subtotal, required this.deliveryFee, required this.total, required this.currency, required this.payment, this.type = 'musteri', this.address, this.requestedAt, this.customerLabel, this.printedAt}): _items = items;
  factory _CustomerReceipt.fromJson(Map<String, dynamic> json) => _$CustomerReceiptFromJson(json);

@override final  String orderNumber;
@override@DeliveryTypeConverter() final  DeliveryType deliveryType;
 final  List<OrderItem> _items;
@override List<OrderItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override final  int subtotal;
@override final  int deliveryFee;
@override final  int total;
@override final  String currency;
@override final  Payment payment;
@override@JsonKey() final  String type;
/// `pickup` siparişte `null` — fişte adres bloğu basılmaz.
@override final  Address? address;
@override final  DateTime? requestedAt;
@override final  String? customerLabel;
@override final  DateTime? printedAt;

/// Create a copy of CustomerReceipt
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CustomerReceiptCopyWith<_CustomerReceipt> get copyWith => __$CustomerReceiptCopyWithImpl<_CustomerReceipt>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CustomerReceiptToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CustomerReceipt&&(identical(other.orderNumber, orderNumber) || other.orderNumber == orderNumber)&&(identical(other.deliveryType, deliveryType) || other.deliveryType == deliveryType)&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.subtotal, subtotal) || other.subtotal == subtotal)&&(identical(other.deliveryFee, deliveryFee) || other.deliveryFee == deliveryFee)&&(identical(other.total, total) || other.total == total)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.payment, payment) || other.payment == payment)&&(identical(other.type, type) || other.type == type)&&(identical(other.address, address) || other.address == address)&&(identical(other.requestedAt, requestedAt) || other.requestedAt == requestedAt)&&(identical(other.customerLabel, customerLabel) || other.customerLabel == customerLabel)&&(identical(other.printedAt, printedAt) || other.printedAt == printedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,orderNumber,deliveryType,const DeepCollectionEquality().hash(_items),subtotal,deliveryFee,total,currency,payment,type,address,requestedAt,customerLabel,printedAt);

@override
String toString() {
  return 'CustomerReceipt(orderNumber: $orderNumber, deliveryType: $deliveryType, items: $items, subtotal: $subtotal, deliveryFee: $deliveryFee, total: $total, currency: $currency, payment: $payment, type: $type, address: $address, requestedAt: $requestedAt, customerLabel: $customerLabel, printedAt: $printedAt)';
}


}

/// @nodoc
abstract mixin class _$CustomerReceiptCopyWith<$Res> implements $CustomerReceiptCopyWith<$Res> {
  factory _$CustomerReceiptCopyWith(_CustomerReceipt value, $Res Function(_CustomerReceipt) _then) = __$CustomerReceiptCopyWithImpl;
@override @useResult
$Res call({
 String orderNumber,@DeliveryTypeConverter() DeliveryType deliveryType, List<OrderItem> items, int subtotal, int deliveryFee, int total, String currency, Payment payment, String type, Address? address, DateTime? requestedAt, String? customerLabel, DateTime? printedAt
});


@override $PaymentCopyWith<$Res> get payment;@override $AddressCopyWith<$Res>? get address;

}
/// @nodoc
class __$CustomerReceiptCopyWithImpl<$Res>
    implements _$CustomerReceiptCopyWith<$Res> {
  __$CustomerReceiptCopyWithImpl(this._self, this._then);

  final _CustomerReceipt _self;
  final $Res Function(_CustomerReceipt) _then;

/// Create a copy of CustomerReceipt
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? orderNumber = null,Object? deliveryType = null,Object? items = null,Object? subtotal = null,Object? deliveryFee = null,Object? total = null,Object? currency = null,Object? payment = null,Object? type = null,Object? address = freezed,Object? requestedAt = freezed,Object? customerLabel = freezed,Object? printedAt = freezed,}) {
  return _then(_CustomerReceipt(
orderNumber: null == orderNumber ? _self.orderNumber : orderNumber // ignore: cast_nullable_to_non_nullable
as String,deliveryType: null == deliveryType ? _self.deliveryType : deliveryType // ignore: cast_nullable_to_non_nullable
as DeliveryType,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<OrderItem>,subtotal: null == subtotal ? _self.subtotal : subtotal // ignore: cast_nullable_to_non_nullable
as int,deliveryFee: null == deliveryFee ? _self.deliveryFee : deliveryFee // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,payment: null == payment ? _self.payment : payment // ignore: cast_nullable_to_non_nullable
as Payment,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as Address?,requestedAt: freezed == requestedAt ? _self.requestedAt : requestedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,customerLabel: freezed == customerLabel ? _self.customerLabel : customerLabel // ignore: cast_nullable_to_non_nullable
as String?,printedAt: freezed == printedAt ? _self.printedAt : printedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of CustomerReceipt
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PaymentCopyWith<$Res> get payment {
  
  return $PaymentCopyWith<$Res>(_self.payment, (value) {
    return _then(_self.copyWith(payment: value));
  });
}/// Create a copy of CustomerReceipt
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
mixin _$PrintAckRequest {

@ReceiptTypeConverter() ReceiptType get type; DateTime get printedAt;
/// Create a copy of PrintAckRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PrintAckRequestCopyWith<PrintAckRequest> get copyWith => _$PrintAckRequestCopyWithImpl<PrintAckRequest>(this as PrintAckRequest, _$identity);

  /// Serializes this PrintAckRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PrintAckRequest&&(identical(other.type, type) || other.type == type)&&(identical(other.printedAt, printedAt) || other.printedAt == printedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,printedAt);

@override
String toString() {
  return 'PrintAckRequest(type: $type, printedAt: $printedAt)';
}


}

/// @nodoc
abstract mixin class $PrintAckRequestCopyWith<$Res>  {
  factory $PrintAckRequestCopyWith(PrintAckRequest value, $Res Function(PrintAckRequest) _then) = _$PrintAckRequestCopyWithImpl;
@useResult
$Res call({
@ReceiptTypeConverter() ReceiptType type, DateTime printedAt
});




}
/// @nodoc
class _$PrintAckRequestCopyWithImpl<$Res>
    implements $PrintAckRequestCopyWith<$Res> {
  _$PrintAckRequestCopyWithImpl(this._self, this._then);

  final PrintAckRequest _self;
  final $Res Function(PrintAckRequest) _then;

/// Create a copy of PrintAckRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? printedAt = null,}) {
  return _then(_self.copyWith(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ReceiptType,printedAt: null == printedAt ? _self.printedAt : printedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [PrintAckRequest].
extension PrintAckRequestPatterns on PrintAckRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PrintAckRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PrintAckRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PrintAckRequest value)  $default,){
final _that = this;
switch (_that) {
case _PrintAckRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PrintAckRequest value)?  $default,){
final _that = this;
switch (_that) {
case _PrintAckRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@ReceiptTypeConverter()  ReceiptType type,  DateTime printedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PrintAckRequest() when $default != null:
return $default(_that.type,_that.printedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@ReceiptTypeConverter()  ReceiptType type,  DateTime printedAt)  $default,) {final _that = this;
switch (_that) {
case _PrintAckRequest():
return $default(_that.type,_that.printedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@ReceiptTypeConverter()  ReceiptType type,  DateTime printedAt)?  $default,) {final _that = this;
switch (_that) {
case _PrintAckRequest() when $default != null:
return $default(_that.type,_that.printedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PrintAckRequest implements PrintAckRequest {
  const _PrintAckRequest({@ReceiptTypeConverter() required this.type, required this.printedAt});
  factory _PrintAckRequest.fromJson(Map<String, dynamic> json) => _$PrintAckRequestFromJson(json);

@override@ReceiptTypeConverter() final  ReceiptType type;
@override final  DateTime printedAt;

/// Create a copy of PrintAckRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PrintAckRequestCopyWith<_PrintAckRequest> get copyWith => __$PrintAckRequestCopyWithImpl<_PrintAckRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PrintAckRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PrintAckRequest&&(identical(other.type, type) || other.type == type)&&(identical(other.printedAt, printedAt) || other.printedAt == printedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,printedAt);

@override
String toString() {
  return 'PrintAckRequest(type: $type, printedAt: $printedAt)';
}


}

/// @nodoc
abstract mixin class _$PrintAckRequestCopyWith<$Res> implements $PrintAckRequestCopyWith<$Res> {
  factory _$PrintAckRequestCopyWith(_PrintAckRequest value, $Res Function(_PrintAckRequest) _then) = __$PrintAckRequestCopyWithImpl;
@override @useResult
$Res call({
@ReceiptTypeConverter() ReceiptType type, DateTime printedAt
});




}
/// @nodoc
class __$PrintAckRequestCopyWithImpl<$Res>
    implements _$PrintAckRequestCopyWith<$Res> {
  __$PrintAckRequestCopyWithImpl(this._self, this._then);

  final _PrintAckRequest _self;
  final $Res Function(_PrintAckRequest) _then;

/// Create a copy of PrintAckRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? printedAt = null,}) {
  return _then(_PrintAckRequest(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ReceiptType,printedAt: null == printedAt ? _self.printedAt : printedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$ProductionListItem {

 int get menuId; String get name; int get total;
/// Create a copy of ProductionListItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductionListItemCopyWith<ProductionListItem> get copyWith => _$ProductionListItemCopyWithImpl<ProductionListItem>(this as ProductionListItem, _$identity);

  /// Serializes this ProductionListItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductionListItem&&(identical(other.menuId, menuId) || other.menuId == menuId)&&(identical(other.name, name) || other.name == name)&&(identical(other.total, total) || other.total == total));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,menuId,name,total);

@override
String toString() {
  return 'ProductionListItem(menuId: $menuId, name: $name, total: $total)';
}


}

/// @nodoc
abstract mixin class $ProductionListItemCopyWith<$Res>  {
  factory $ProductionListItemCopyWith(ProductionListItem value, $Res Function(ProductionListItem) _then) = _$ProductionListItemCopyWithImpl;
@useResult
$Res call({
 int menuId, String name, int total
});




}
/// @nodoc
class _$ProductionListItemCopyWithImpl<$Res>
    implements $ProductionListItemCopyWith<$Res> {
  _$ProductionListItemCopyWithImpl(this._self, this._then);

  final ProductionListItem _self;
  final $Res Function(ProductionListItem) _then;

/// Create a copy of ProductionListItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? menuId = null,Object? name = null,Object? total = null,}) {
  return _then(_self.copyWith(
menuId: null == menuId ? _self.menuId : menuId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ProductionListItem].
extension ProductionListItemPatterns on ProductionListItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProductionListItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProductionListItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProductionListItem value)  $default,){
final _that = this;
switch (_that) {
case _ProductionListItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProductionListItem value)?  $default,){
final _that = this;
switch (_that) {
case _ProductionListItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int menuId,  String name,  int total)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProductionListItem() when $default != null:
return $default(_that.menuId,_that.name,_that.total);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int menuId,  String name,  int total)  $default,) {final _that = this;
switch (_that) {
case _ProductionListItem():
return $default(_that.menuId,_that.name,_that.total);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int menuId,  String name,  int total)?  $default,) {final _that = this;
switch (_that) {
case _ProductionListItem() when $default != null:
return $default(_that.menuId,_that.name,_that.total);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProductionListItem implements ProductionListItem {
  const _ProductionListItem({required this.menuId, required this.name, required this.total});
  factory _ProductionListItem.fromJson(Map<String, dynamic> json) => _$ProductionListItemFromJson(json);

@override final  int menuId;
@override final  String name;
@override final  int total;

/// Create a copy of ProductionListItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProductionListItemCopyWith<_ProductionListItem> get copyWith => __$ProductionListItemCopyWithImpl<_ProductionListItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProductionListItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProductionListItem&&(identical(other.menuId, menuId) || other.menuId == menuId)&&(identical(other.name, name) || other.name == name)&&(identical(other.total, total) || other.total == total));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,menuId,name,total);

@override
String toString() {
  return 'ProductionListItem(menuId: $menuId, name: $name, total: $total)';
}


}

/// @nodoc
abstract mixin class _$ProductionListItemCopyWith<$Res> implements $ProductionListItemCopyWith<$Res> {
  factory _$ProductionListItemCopyWith(_ProductionListItem value, $Res Function(_ProductionListItem) _then) = __$ProductionListItemCopyWithImpl;
@override @useResult
$Res call({
 int menuId, String name, int total
});




}
/// @nodoc
class __$ProductionListItemCopyWithImpl<$Res>
    implements _$ProductionListItemCopyWith<$Res> {
  __$ProductionListItemCopyWithImpl(this._self, this._then);

  final _ProductionListItem _self;
  final $Res Function(_ProductionListItem) _then;

/// Create a copy of ProductionListItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? menuId = null,Object? name = null,Object? total = null,}) {
  return _then(_ProductionListItem(
menuId: null == menuId ? _self.menuId : menuId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$ProductionList {

 List<ProductionListItem> get data; DateTime get asOf;
/// Create a copy of ProductionList
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductionListCopyWith<ProductionList> get copyWith => _$ProductionListCopyWithImpl<ProductionList>(this as ProductionList, _$identity);

  /// Serializes this ProductionList to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductionList&&const DeepCollectionEquality().equals(other.data, data)&&(identical(other.asOf, asOf) || other.asOf == asOf));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data),asOf);

@override
String toString() {
  return 'ProductionList(data: $data, asOf: $asOf)';
}


}

/// @nodoc
abstract mixin class $ProductionListCopyWith<$Res>  {
  factory $ProductionListCopyWith(ProductionList value, $Res Function(ProductionList) _then) = _$ProductionListCopyWithImpl;
@useResult
$Res call({
 List<ProductionListItem> data, DateTime asOf
});




}
/// @nodoc
class _$ProductionListCopyWithImpl<$Res>
    implements $ProductionListCopyWith<$Res> {
  _$ProductionListCopyWithImpl(this._self, this._then);

  final ProductionList _self;
  final $Res Function(ProductionList) _then;

/// Create a copy of ProductionList
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,Object? asOf = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<ProductionListItem>,asOf: null == asOf ? _self.asOf : asOf // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [ProductionList].
extension ProductionListPatterns on ProductionList {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProductionList value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProductionList() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProductionList value)  $default,){
final _that = this;
switch (_that) {
case _ProductionList():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProductionList value)?  $default,){
final _that = this;
switch (_that) {
case _ProductionList() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<ProductionListItem> data,  DateTime asOf)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProductionList() when $default != null:
return $default(_that.data,_that.asOf);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<ProductionListItem> data,  DateTime asOf)  $default,) {final _that = this;
switch (_that) {
case _ProductionList():
return $default(_that.data,_that.asOf);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<ProductionListItem> data,  DateTime asOf)?  $default,) {final _that = this;
switch (_that) {
case _ProductionList() when $default != null:
return $default(_that.data,_that.asOf);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProductionList implements ProductionList {
  const _ProductionList({required final  List<ProductionListItem> data, required this.asOf}): _data = data;
  factory _ProductionList.fromJson(Map<String, dynamic> json) => _$ProductionListFromJson(json);

 final  List<ProductionListItem> _data;
@override List<ProductionListItem> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}

@override final  DateTime asOf;

/// Create a copy of ProductionList
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProductionListCopyWith<_ProductionList> get copyWith => __$ProductionListCopyWithImpl<_ProductionList>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProductionListToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProductionList&&const DeepCollectionEquality().equals(other._data, _data)&&(identical(other.asOf, asOf) || other.asOf == asOf));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data),asOf);

@override
String toString() {
  return 'ProductionList(data: $data, asOf: $asOf)';
}


}

/// @nodoc
abstract mixin class _$ProductionListCopyWith<$Res> implements $ProductionListCopyWith<$Res> {
  factory _$ProductionListCopyWith(_ProductionList value, $Res Function(_ProductionList) _then) = __$ProductionListCopyWithImpl;
@override @useResult
$Res call({
 List<ProductionListItem> data, DateTime asOf
});




}
/// @nodoc
class __$ProductionListCopyWithImpl<$Res>
    implements _$ProductionListCopyWith<$Res> {
  __$ProductionListCopyWithImpl(this._self, this._then);

  final _ProductionList _self;
  final $Res Function(_ProductionList) _then;

/// Create a copy of ProductionList
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,Object? asOf = null,}) {
  return _then(_ProductionList(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<ProductionListItem>,asOf: null == asOf ? _self.asOf : asOf // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$HeartbeatResponse {

 DateTime get serverTime; String get minSupportedVersion;
/// Create a copy of HeartbeatResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HeartbeatResponseCopyWith<HeartbeatResponse> get copyWith => _$HeartbeatResponseCopyWithImpl<HeartbeatResponse>(this as HeartbeatResponse, _$identity);

  /// Serializes this HeartbeatResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HeartbeatResponse&&(identical(other.serverTime, serverTime) || other.serverTime == serverTime)&&(identical(other.minSupportedVersion, minSupportedVersion) || other.minSupportedVersion == minSupportedVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,serverTime,minSupportedVersion);

@override
String toString() {
  return 'HeartbeatResponse(serverTime: $serverTime, minSupportedVersion: $minSupportedVersion)';
}


}

/// @nodoc
abstract mixin class $HeartbeatResponseCopyWith<$Res>  {
  factory $HeartbeatResponseCopyWith(HeartbeatResponse value, $Res Function(HeartbeatResponse) _then) = _$HeartbeatResponseCopyWithImpl;
@useResult
$Res call({
 DateTime serverTime, String minSupportedVersion
});




}
/// @nodoc
class _$HeartbeatResponseCopyWithImpl<$Res>
    implements $HeartbeatResponseCopyWith<$Res> {
  _$HeartbeatResponseCopyWithImpl(this._self, this._then);

  final HeartbeatResponse _self;
  final $Res Function(HeartbeatResponse) _then;

/// Create a copy of HeartbeatResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? serverTime = null,Object? minSupportedVersion = null,}) {
  return _then(_self.copyWith(
serverTime: null == serverTime ? _self.serverTime : serverTime // ignore: cast_nullable_to_non_nullable
as DateTime,minSupportedVersion: null == minSupportedVersion ? _self.minSupportedVersion : minSupportedVersion // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [HeartbeatResponse].
extension HeartbeatResponsePatterns on HeartbeatResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HeartbeatResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HeartbeatResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HeartbeatResponse value)  $default,){
final _that = this;
switch (_that) {
case _HeartbeatResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HeartbeatResponse value)?  $default,){
final _that = this;
switch (_that) {
case _HeartbeatResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime serverTime,  String minSupportedVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HeartbeatResponse() when $default != null:
return $default(_that.serverTime,_that.minSupportedVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime serverTime,  String minSupportedVersion)  $default,) {final _that = this;
switch (_that) {
case _HeartbeatResponse():
return $default(_that.serverTime,_that.minSupportedVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime serverTime,  String minSupportedVersion)?  $default,) {final _that = this;
switch (_that) {
case _HeartbeatResponse() when $default != null:
return $default(_that.serverTime,_that.minSupportedVersion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _HeartbeatResponse implements HeartbeatResponse {
  const _HeartbeatResponse({required this.serverTime, required this.minSupportedVersion});
  factory _HeartbeatResponse.fromJson(Map<String, dynamic> json) => _$HeartbeatResponseFromJson(json);

@override final  DateTime serverTime;
@override final  String minSupportedVersion;

/// Create a copy of HeartbeatResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HeartbeatResponseCopyWith<_HeartbeatResponse> get copyWith => __$HeartbeatResponseCopyWithImpl<_HeartbeatResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HeartbeatResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HeartbeatResponse&&(identical(other.serverTime, serverTime) || other.serverTime == serverTime)&&(identical(other.minSupportedVersion, minSupportedVersion) || other.minSupportedVersion == minSupportedVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,serverTime,minSupportedVersion);

@override
String toString() {
  return 'HeartbeatResponse(serverTime: $serverTime, minSupportedVersion: $minSupportedVersion)';
}


}

/// @nodoc
abstract mixin class _$HeartbeatResponseCopyWith<$Res> implements $HeartbeatResponseCopyWith<$Res> {
  factory _$HeartbeatResponseCopyWith(_HeartbeatResponse value, $Res Function(_HeartbeatResponse) _then) = __$HeartbeatResponseCopyWithImpl;
@override @useResult
$Res call({
 DateTime serverTime, String minSupportedVersion
});




}
/// @nodoc
class __$HeartbeatResponseCopyWithImpl<$Res>
    implements _$HeartbeatResponseCopyWith<$Res> {
  __$HeartbeatResponseCopyWithImpl(this._self, this._then);

  final _HeartbeatResponse _self;
  final $Res Function(_HeartbeatResponse) _then;

/// Create a copy of HeartbeatResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? serverTime = null,Object? minSupportedVersion = null,}) {
  return _then(_HeartbeatResponse(
serverTime: null == serverTime ? _self.serverTime : serverTime // ignore: cast_nullable_to_non_nullable
as DateTime,minSupportedVersion: null == minSupportedVersion ? _self.minSupportedVersion : minSupportedVersion // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$AppVersionInfo {

 String get appId; String get latest; String get minSupported;/// Yalnızca `mutfakapp` için dolu (`.deb` adresi).
 String? get downloadUrl; String? get notes;
/// Create a copy of AppVersionInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppVersionInfoCopyWith<AppVersionInfo> get copyWith => _$AppVersionInfoCopyWithImpl<AppVersionInfo>(this as AppVersionInfo, _$identity);

  /// Serializes this AppVersionInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppVersionInfo&&(identical(other.appId, appId) || other.appId == appId)&&(identical(other.latest, latest) || other.latest == latest)&&(identical(other.minSupported, minSupported) || other.minSupported == minSupported)&&(identical(other.downloadUrl, downloadUrl) || other.downloadUrl == downloadUrl)&&(identical(other.notes, notes) || other.notes == notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,appId,latest,minSupported,downloadUrl,notes);

@override
String toString() {
  return 'AppVersionInfo(appId: $appId, latest: $latest, minSupported: $minSupported, downloadUrl: $downloadUrl, notes: $notes)';
}


}

/// @nodoc
abstract mixin class $AppVersionInfoCopyWith<$Res>  {
  factory $AppVersionInfoCopyWith(AppVersionInfo value, $Res Function(AppVersionInfo) _then) = _$AppVersionInfoCopyWithImpl;
@useResult
$Res call({
 String appId, String latest, String minSupported, String? downloadUrl, String? notes
});




}
/// @nodoc
class _$AppVersionInfoCopyWithImpl<$Res>
    implements $AppVersionInfoCopyWith<$Res> {
  _$AppVersionInfoCopyWithImpl(this._self, this._then);

  final AppVersionInfo _self;
  final $Res Function(AppVersionInfo) _then;

/// Create a copy of AppVersionInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? appId = null,Object? latest = null,Object? minSupported = null,Object? downloadUrl = freezed,Object? notes = freezed,}) {
  return _then(_self.copyWith(
appId: null == appId ? _self.appId : appId // ignore: cast_nullable_to_non_nullable
as String,latest: null == latest ? _self.latest : latest // ignore: cast_nullable_to_non_nullable
as String,minSupported: null == minSupported ? _self.minSupported : minSupported // ignore: cast_nullable_to_non_nullable
as String,downloadUrl: freezed == downloadUrl ? _self.downloadUrl : downloadUrl // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AppVersionInfo].
extension AppVersionInfoPatterns on AppVersionInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppVersionInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppVersionInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppVersionInfo value)  $default,){
final _that = this;
switch (_that) {
case _AppVersionInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppVersionInfo value)?  $default,){
final _that = this;
switch (_that) {
case _AppVersionInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String appId,  String latest,  String minSupported,  String? downloadUrl,  String? notes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppVersionInfo() when $default != null:
return $default(_that.appId,_that.latest,_that.minSupported,_that.downloadUrl,_that.notes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String appId,  String latest,  String minSupported,  String? downloadUrl,  String? notes)  $default,) {final _that = this;
switch (_that) {
case _AppVersionInfo():
return $default(_that.appId,_that.latest,_that.minSupported,_that.downloadUrl,_that.notes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String appId,  String latest,  String minSupported,  String? downloadUrl,  String? notes)?  $default,) {final _that = this;
switch (_that) {
case _AppVersionInfo() when $default != null:
return $default(_that.appId,_that.latest,_that.minSupported,_that.downloadUrl,_that.notes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppVersionInfo implements AppVersionInfo {
  const _AppVersionInfo({required this.appId, required this.latest, required this.minSupported, this.downloadUrl, this.notes});
  factory _AppVersionInfo.fromJson(Map<String, dynamic> json) => _$AppVersionInfoFromJson(json);

@override final  String appId;
@override final  String latest;
@override final  String minSupported;
/// Yalnızca `mutfakapp` için dolu (`.deb` adresi).
@override final  String? downloadUrl;
@override final  String? notes;

/// Create a copy of AppVersionInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppVersionInfoCopyWith<_AppVersionInfo> get copyWith => __$AppVersionInfoCopyWithImpl<_AppVersionInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppVersionInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppVersionInfo&&(identical(other.appId, appId) || other.appId == appId)&&(identical(other.latest, latest) || other.latest == latest)&&(identical(other.minSupported, minSupported) || other.minSupported == minSupported)&&(identical(other.downloadUrl, downloadUrl) || other.downloadUrl == downloadUrl)&&(identical(other.notes, notes) || other.notes == notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,appId,latest,minSupported,downloadUrl,notes);

@override
String toString() {
  return 'AppVersionInfo(appId: $appId, latest: $latest, minSupported: $minSupported, downloadUrl: $downloadUrl, notes: $notes)';
}


}

/// @nodoc
abstract mixin class _$AppVersionInfoCopyWith<$Res> implements $AppVersionInfoCopyWith<$Res> {
  factory _$AppVersionInfoCopyWith(_AppVersionInfo value, $Res Function(_AppVersionInfo) _then) = __$AppVersionInfoCopyWithImpl;
@override @useResult
$Res call({
 String appId, String latest, String minSupported, String? downloadUrl, String? notes
});




}
/// @nodoc
class __$AppVersionInfoCopyWithImpl<$Res>
    implements _$AppVersionInfoCopyWith<$Res> {
  __$AppVersionInfoCopyWithImpl(this._self, this._then);

  final _AppVersionInfo _self;
  final $Res Function(_AppVersionInfo) _then;

/// Create a copy of AppVersionInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? appId = null,Object? latest = null,Object? minSupported = null,Object? downloadUrl = freezed,Object? notes = freezed,}) {
  return _then(_AppVersionInfo(
appId: null == appId ? _self.appId : appId // ignore: cast_nullable_to_non_nullable
as String,latest: null == latest ? _self.latest : latest // ignore: cast_nullable_to_non_nullable
as String,minSupported: null == minSupported ? _self.minSupported : minSupported // ignore: cast_nullable_to_non_nullable
as String,downloadUrl: freezed == downloadUrl ? _self.downloadUrl : downloadUrl // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
