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

 int get id; String get orderNumber;@OrderStatusConverter() OrderStatus get status;@DeliveryTypeConverter() DeliveryType get deliveryType; List<KitchenOrderItem> get items; DateTime get createdAt; DateTime get updatedAt; DateTime? get requestedAt;/// Yalnızca ad + soyad baş harfi (kartın üst satırı).
 String? get customerLabel;/// Müşterinin tam adı ve telefonu (K-14).
///
/// KURAL DEĞİŞTİ (11.08.2026): `docs/03` §5 eskiden "mutfak listesinde
/// telefon GÖRÜNMEZ" diyordu ve sipariş düzenleme gelene kadar
/// doğruydu. Artık personel müşteriyi ARAYIP anlaşmak zorunda;
/// numarayı görmek için fiş basmak saçma. **Fiyat ve adres hâlâ
/// gönderilmiyor** — kural kaldırılmadı, daraltıldı.
///
/// Eski sunucu bu alanları göndermezse `null` gelir ve kart eskisi
/// gibi çizilir.
 String? get customerName; String? get customerPhone; String? get customerNote;/// Kaçıncı revizyon (K-12). 0 = hiç düzenlenmedi.
///
/// Artması, fişlerin yeniden basılması gerektiği anlamına gelir
/// (`print_triggers.dart`).
 int get revisionNo;/// Bu sipariş bir abonelik kuralından mı üretildi? (`docs/openapi.yaml`
/// `is_subscription`.) KDS bunu rozet + "bugün abonelik var" paneliyle
/// gösterir. Eski sunucu göndermezse `false`.
 bool get isSubscription;
/// Create a copy of KitchenOrder
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KitchenOrderCopyWith<KitchenOrder> get copyWith => _$KitchenOrderCopyWithImpl<KitchenOrder>(this as KitchenOrder, _$identity);

  /// Serializes this KitchenOrder to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KitchenOrder&&(identical(other.id, id) || other.id == id)&&(identical(other.orderNumber, orderNumber) || other.orderNumber == orderNumber)&&(identical(other.status, status) || other.status == status)&&(identical(other.deliveryType, deliveryType) || other.deliveryType == deliveryType)&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.requestedAt, requestedAt) || other.requestedAt == requestedAt)&&(identical(other.customerLabel, customerLabel) || other.customerLabel == customerLabel)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.customerPhone, customerPhone) || other.customerPhone == customerPhone)&&(identical(other.customerNote, customerNote) || other.customerNote == customerNote)&&(identical(other.revisionNo, revisionNo) || other.revisionNo == revisionNo)&&(identical(other.isSubscription, isSubscription) || other.isSubscription == isSubscription));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,orderNumber,status,deliveryType,const DeepCollectionEquality().hash(items),createdAt,updatedAt,requestedAt,customerLabel,customerName,customerPhone,customerNote,revisionNo,isSubscription);

@override
String toString() {
  return 'KitchenOrder(id: $id, orderNumber: $orderNumber, status: $status, deliveryType: $deliveryType, items: $items, createdAt: $createdAt, updatedAt: $updatedAt, requestedAt: $requestedAt, customerLabel: $customerLabel, customerName: $customerName, customerPhone: $customerPhone, customerNote: $customerNote, revisionNo: $revisionNo, isSubscription: $isSubscription)';
}


}

/// @nodoc
abstract mixin class $KitchenOrderCopyWith<$Res>  {
  factory $KitchenOrderCopyWith(KitchenOrder value, $Res Function(KitchenOrder) _then) = _$KitchenOrderCopyWithImpl;
@useResult
$Res call({
 int id, String orderNumber,@OrderStatusConverter() OrderStatus status,@DeliveryTypeConverter() DeliveryType deliveryType, List<KitchenOrderItem> items, DateTime createdAt, DateTime updatedAt, DateTime? requestedAt, String? customerLabel, String? customerName, String? customerPhone, String? customerNote, int revisionNo, bool isSubscription
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? orderNumber = null,Object? status = null,Object? deliveryType = null,Object? items = null,Object? createdAt = null,Object? updatedAt = null,Object? requestedAt = freezed,Object? customerLabel = freezed,Object? customerName = freezed,Object? customerPhone = freezed,Object? customerNote = freezed,Object? revisionNo = null,Object? isSubscription = null,}) {
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
as String?,customerName: freezed == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String?,customerPhone: freezed == customerPhone ? _self.customerPhone : customerPhone // ignore: cast_nullable_to_non_nullable
as String?,customerNote: freezed == customerNote ? _self.customerNote : customerNote // ignore: cast_nullable_to_non_nullable
as String?,revisionNo: null == revisionNo ? _self.revisionNo : revisionNo // ignore: cast_nullable_to_non_nullable
as int,isSubscription: null == isSubscription ? _self.isSubscription : isSubscription // ignore: cast_nullable_to_non_nullable
as bool,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String orderNumber, @OrderStatusConverter()  OrderStatus status, @DeliveryTypeConverter()  DeliveryType deliveryType,  List<KitchenOrderItem> items,  DateTime createdAt,  DateTime updatedAt,  DateTime? requestedAt,  String? customerLabel,  String? customerName,  String? customerPhone,  String? customerNote,  int revisionNo,  bool isSubscription)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _KitchenOrder() when $default != null:
return $default(_that.id,_that.orderNumber,_that.status,_that.deliveryType,_that.items,_that.createdAt,_that.updatedAt,_that.requestedAt,_that.customerLabel,_that.customerName,_that.customerPhone,_that.customerNote,_that.revisionNo,_that.isSubscription);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String orderNumber, @OrderStatusConverter()  OrderStatus status, @DeliveryTypeConverter()  DeliveryType deliveryType,  List<KitchenOrderItem> items,  DateTime createdAt,  DateTime updatedAt,  DateTime? requestedAt,  String? customerLabel,  String? customerName,  String? customerPhone,  String? customerNote,  int revisionNo,  bool isSubscription)  $default,) {final _that = this;
switch (_that) {
case _KitchenOrder():
return $default(_that.id,_that.orderNumber,_that.status,_that.deliveryType,_that.items,_that.createdAt,_that.updatedAt,_that.requestedAt,_that.customerLabel,_that.customerName,_that.customerPhone,_that.customerNote,_that.revisionNo,_that.isSubscription);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String orderNumber, @OrderStatusConverter()  OrderStatus status, @DeliveryTypeConverter()  DeliveryType deliveryType,  List<KitchenOrderItem> items,  DateTime createdAt,  DateTime updatedAt,  DateTime? requestedAt,  String? customerLabel,  String? customerName,  String? customerPhone,  String? customerNote,  int revisionNo,  bool isSubscription)?  $default,) {final _that = this;
switch (_that) {
case _KitchenOrder() when $default != null:
return $default(_that.id,_that.orderNumber,_that.status,_that.deliveryType,_that.items,_that.createdAt,_that.updatedAt,_that.requestedAt,_that.customerLabel,_that.customerName,_that.customerPhone,_that.customerNote,_that.revisionNo,_that.isSubscription);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _KitchenOrder extends KitchenOrder {
  const _KitchenOrder({required this.id, required this.orderNumber, @OrderStatusConverter() required this.status, @DeliveryTypeConverter() required this.deliveryType, required final  List<KitchenOrderItem> items, required this.createdAt, required this.updatedAt, this.requestedAt, this.customerLabel, this.customerName, this.customerPhone, this.customerNote, this.revisionNo = 0, this.isSubscription = false}): _items = items,super._();
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
/// Yalnızca ad + soyad baş harfi (kartın üst satırı).
@override final  String? customerLabel;
/// Müşterinin tam adı ve telefonu (K-14).
///
/// KURAL DEĞİŞTİ (11.08.2026): `docs/03` §5 eskiden "mutfak listesinde
/// telefon GÖRÜNMEZ" diyordu ve sipariş düzenleme gelene kadar
/// doğruydu. Artık personel müşteriyi ARAYIP anlaşmak zorunda;
/// numarayı görmek için fiş basmak saçma. **Fiyat ve adres hâlâ
/// gönderilmiyor** — kural kaldırılmadı, daraltıldı.
///
/// Eski sunucu bu alanları göndermezse `null` gelir ve kart eskisi
/// gibi çizilir.
@override final  String? customerName;
@override final  String? customerPhone;
@override final  String? customerNote;
/// Kaçıncı revizyon (K-12). 0 = hiç düzenlenmedi.
///
/// Artması, fişlerin yeniden basılması gerektiği anlamına gelir
/// (`print_triggers.dart`).
@override@JsonKey() final  int revisionNo;
/// Bu sipariş bir abonelik kuralından mı üretildi? (`docs/openapi.yaml`
/// `is_subscription`.) KDS bunu rozet + "bugün abonelik var" paneliyle
/// gösterir. Eski sunucu göndermezse `false`.
@override@JsonKey() final  bool isSubscription;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _KitchenOrder&&(identical(other.id, id) || other.id == id)&&(identical(other.orderNumber, orderNumber) || other.orderNumber == orderNumber)&&(identical(other.status, status) || other.status == status)&&(identical(other.deliveryType, deliveryType) || other.deliveryType == deliveryType)&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.requestedAt, requestedAt) || other.requestedAt == requestedAt)&&(identical(other.customerLabel, customerLabel) || other.customerLabel == customerLabel)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.customerPhone, customerPhone) || other.customerPhone == customerPhone)&&(identical(other.customerNote, customerNote) || other.customerNote == customerNote)&&(identical(other.revisionNo, revisionNo) || other.revisionNo == revisionNo)&&(identical(other.isSubscription, isSubscription) || other.isSubscription == isSubscription));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,orderNumber,status,deliveryType,const DeepCollectionEquality().hash(_items),createdAt,updatedAt,requestedAt,customerLabel,customerName,customerPhone,customerNote,revisionNo,isSubscription);

@override
String toString() {
  return 'KitchenOrder(id: $id, orderNumber: $orderNumber, status: $status, deliveryType: $deliveryType, items: $items, createdAt: $createdAt, updatedAt: $updatedAt, requestedAt: $requestedAt, customerLabel: $customerLabel, customerName: $customerName, customerPhone: $customerPhone, customerNote: $customerNote, revisionNo: $revisionNo, isSubscription: $isSubscription)';
}


}

/// @nodoc
abstract mixin class _$KitchenOrderCopyWith<$Res> implements $KitchenOrderCopyWith<$Res> {
  factory _$KitchenOrderCopyWith(_KitchenOrder value, $Res Function(_KitchenOrder) _then) = __$KitchenOrderCopyWithImpl;
@override @useResult
$Res call({
 int id, String orderNumber,@OrderStatusConverter() OrderStatus status,@DeliveryTypeConverter() DeliveryType deliveryType, List<KitchenOrderItem> items, DateTime createdAt, DateTime updatedAt, DateTime? requestedAt, String? customerLabel, String? customerName, String? customerPhone, String? customerNote, int revisionNo, bool isSubscription
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? orderNumber = null,Object? status = null,Object? deliveryType = null,Object? items = null,Object? createdAt = null,Object? updatedAt = null,Object? requestedAt = freezed,Object? customerLabel = freezed,Object? customerName = freezed,Object? customerPhone = freezed,Object? customerNote = freezed,Object? revisionNo = null,Object? isSubscription = null,}) {
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
as String?,customerName: freezed == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String?,customerPhone: freezed == customerPhone ? _self.customerPhone : customerPhone // ignore: cast_nullable_to_non_nullable
as String?,customerNote: freezed == customerNote ? _self.customerNote : customerNote // ignore: cast_nullable_to_non_nullable
as String?,revisionNo: null == revisionNo ? _self.revisionNo : revisionNo // ignore: cast_nullable_to_non_nullable
as int,isSubscription: null == isSubscription ? _self.isSubscription : isSubscription // ignore: cast_nullable_to_non_nullable
as bool,
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
mixin _$KitchenSubscriptionOrders {

 List<KitchenOrder> get today; List<KitchenOrder> get tomorrow; DateTime get serverTime;
/// Create a copy of KitchenSubscriptionOrders
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KitchenSubscriptionOrdersCopyWith<KitchenSubscriptionOrders> get copyWith => _$KitchenSubscriptionOrdersCopyWithImpl<KitchenSubscriptionOrders>(this as KitchenSubscriptionOrders, _$identity);

  /// Serializes this KitchenSubscriptionOrders to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KitchenSubscriptionOrders&&const DeepCollectionEquality().equals(other.today, today)&&const DeepCollectionEquality().equals(other.tomorrow, tomorrow)&&(identical(other.serverTime, serverTime) || other.serverTime == serverTime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(today),const DeepCollectionEquality().hash(tomorrow),serverTime);

@override
String toString() {
  return 'KitchenSubscriptionOrders(today: $today, tomorrow: $tomorrow, serverTime: $serverTime)';
}


}

/// @nodoc
abstract mixin class $KitchenSubscriptionOrdersCopyWith<$Res>  {
  factory $KitchenSubscriptionOrdersCopyWith(KitchenSubscriptionOrders value, $Res Function(KitchenSubscriptionOrders) _then) = _$KitchenSubscriptionOrdersCopyWithImpl;
@useResult
$Res call({
 List<KitchenOrder> today, List<KitchenOrder> tomorrow, DateTime serverTime
});




}
/// @nodoc
class _$KitchenSubscriptionOrdersCopyWithImpl<$Res>
    implements $KitchenSubscriptionOrdersCopyWith<$Res> {
  _$KitchenSubscriptionOrdersCopyWithImpl(this._self, this._then);

  final KitchenSubscriptionOrders _self;
  final $Res Function(KitchenSubscriptionOrders) _then;

/// Create a copy of KitchenSubscriptionOrders
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? today = null,Object? tomorrow = null,Object? serverTime = null,}) {
  return _then(_self.copyWith(
today: null == today ? _self.today : today // ignore: cast_nullable_to_non_nullable
as List<KitchenOrder>,tomorrow: null == tomorrow ? _self.tomorrow : tomorrow // ignore: cast_nullable_to_non_nullable
as List<KitchenOrder>,serverTime: null == serverTime ? _self.serverTime : serverTime // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [KitchenSubscriptionOrders].
extension KitchenSubscriptionOrdersPatterns on KitchenSubscriptionOrders {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _KitchenSubscriptionOrders value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _KitchenSubscriptionOrders() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _KitchenSubscriptionOrders value)  $default,){
final _that = this;
switch (_that) {
case _KitchenSubscriptionOrders():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _KitchenSubscriptionOrders value)?  $default,){
final _that = this;
switch (_that) {
case _KitchenSubscriptionOrders() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<KitchenOrder> today,  List<KitchenOrder> tomorrow,  DateTime serverTime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _KitchenSubscriptionOrders() when $default != null:
return $default(_that.today,_that.tomorrow,_that.serverTime);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<KitchenOrder> today,  List<KitchenOrder> tomorrow,  DateTime serverTime)  $default,) {final _that = this;
switch (_that) {
case _KitchenSubscriptionOrders():
return $default(_that.today,_that.tomorrow,_that.serverTime);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<KitchenOrder> today,  List<KitchenOrder> tomorrow,  DateTime serverTime)?  $default,) {final _that = this;
switch (_that) {
case _KitchenSubscriptionOrders() when $default != null:
return $default(_that.today,_that.tomorrow,_that.serverTime);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _KitchenSubscriptionOrders implements KitchenSubscriptionOrders {
  const _KitchenSubscriptionOrders({final  List<KitchenOrder> today = const <KitchenOrder>[], final  List<KitchenOrder> tomorrow = const <KitchenOrder>[], required this.serverTime}): _today = today,_tomorrow = tomorrow;
  factory _KitchenSubscriptionOrders.fromJson(Map<String, dynamic> json) => _$KitchenSubscriptionOrdersFromJson(json);

 final  List<KitchenOrder> _today;
@override@JsonKey() List<KitchenOrder> get today {
  if (_today is EqualUnmodifiableListView) return _today;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_today);
}

 final  List<KitchenOrder> _tomorrow;
@override@JsonKey() List<KitchenOrder> get tomorrow {
  if (_tomorrow is EqualUnmodifiableListView) return _tomorrow;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tomorrow);
}

@override final  DateTime serverTime;

/// Create a copy of KitchenSubscriptionOrders
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$KitchenSubscriptionOrdersCopyWith<_KitchenSubscriptionOrders> get copyWith => __$KitchenSubscriptionOrdersCopyWithImpl<_KitchenSubscriptionOrders>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$KitchenSubscriptionOrdersToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _KitchenSubscriptionOrders&&const DeepCollectionEquality().equals(other._today, _today)&&const DeepCollectionEquality().equals(other._tomorrow, _tomorrow)&&(identical(other.serverTime, serverTime) || other.serverTime == serverTime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_today),const DeepCollectionEquality().hash(_tomorrow),serverTime);

@override
String toString() {
  return 'KitchenSubscriptionOrders(today: $today, tomorrow: $tomorrow, serverTime: $serverTime)';
}


}

/// @nodoc
abstract mixin class _$KitchenSubscriptionOrdersCopyWith<$Res> implements $KitchenSubscriptionOrdersCopyWith<$Res> {
  factory _$KitchenSubscriptionOrdersCopyWith(_KitchenSubscriptionOrders value, $Res Function(_KitchenSubscriptionOrders) _then) = __$KitchenSubscriptionOrdersCopyWithImpl;
@override @useResult
$Res call({
 List<KitchenOrder> today, List<KitchenOrder> tomorrow, DateTime serverTime
});




}
/// @nodoc
class __$KitchenSubscriptionOrdersCopyWithImpl<$Res>
    implements _$KitchenSubscriptionOrdersCopyWith<$Res> {
  __$KitchenSubscriptionOrdersCopyWithImpl(this._self, this._then);

  final _KitchenSubscriptionOrders _self;
  final $Res Function(_KitchenSubscriptionOrders) _then;

/// Create a copy of KitchenSubscriptionOrders
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? today = null,Object? tomorrow = null,Object? serverTime = null,}) {
  return _then(_KitchenSubscriptionOrders(
today: null == today ? _self._today : today // ignore: cast_nullable_to_non_nullable
as List<KitchenOrder>,tomorrow: null == tomorrow ? _self._tomorrow : tomorrow // ignore: cast_nullable_to_non_nullable
as List<KitchenOrder>,serverTime: null == serverTime ? _self.serverTime : serverTime // ignore: cast_nullable_to_non_nullable
as DateTime,
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

 String get orderNumber;@DeliveryTypeConverter() DeliveryType get deliveryType; List<ReceiptLine> get lines; String get type; DateTime? get requestedAt;/// Müşterinin telefonu — yalnızca **fişe** basmak için.
///
/// KDS kartında ([KitchenOrder]) telefon yoktur: ekran mutfakta gün boyu
/// açık durur. Fiş tek bir sipariş için basılıp kuryeye gider.
 String? get customerPhone; String? get customerNote; DateTime? get printedAt;/// Kaçıncı revizyon; `0` = düzenlenmedi (K-20).
///
/// `>0` ise fişin başına çift boy `GÜNCEL FİŞ — REVİZE #N / ÖNCEKİ FİŞİ
/// ATIN` bandı basılır. K-20'ye kadar mutfak fişi bu bilgiyi hiç
/// almıyordu: düzenlenen sipariş için yeni kâğıt çıkıyor ama üstünde
/// onu öncekinden ayıran hiçbir şey yazmıyordu.
 int get revisionNo;/// İnsan okuyabilir değişiklik satırları; boşsa liste basılmaz.
 List<String> get revisionSummary;
/// Create a copy of KitchenReceipt
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KitchenReceiptCopyWith<KitchenReceipt> get copyWith => _$KitchenReceiptCopyWithImpl<KitchenReceipt>(this as KitchenReceipt, _$identity);

  /// Serializes this KitchenReceipt to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KitchenReceipt&&(identical(other.orderNumber, orderNumber) || other.orderNumber == orderNumber)&&(identical(other.deliveryType, deliveryType) || other.deliveryType == deliveryType)&&const DeepCollectionEquality().equals(other.lines, lines)&&(identical(other.type, type) || other.type == type)&&(identical(other.requestedAt, requestedAt) || other.requestedAt == requestedAt)&&(identical(other.customerPhone, customerPhone) || other.customerPhone == customerPhone)&&(identical(other.customerNote, customerNote) || other.customerNote == customerNote)&&(identical(other.printedAt, printedAt) || other.printedAt == printedAt)&&(identical(other.revisionNo, revisionNo) || other.revisionNo == revisionNo)&&const DeepCollectionEquality().equals(other.revisionSummary, revisionSummary));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,orderNumber,deliveryType,const DeepCollectionEquality().hash(lines),type,requestedAt,customerPhone,customerNote,printedAt,revisionNo,const DeepCollectionEquality().hash(revisionSummary));

@override
String toString() {
  return 'KitchenReceipt(orderNumber: $orderNumber, deliveryType: $deliveryType, lines: $lines, type: $type, requestedAt: $requestedAt, customerPhone: $customerPhone, customerNote: $customerNote, printedAt: $printedAt, revisionNo: $revisionNo, revisionSummary: $revisionSummary)';
}


}

/// @nodoc
abstract mixin class $KitchenReceiptCopyWith<$Res>  {
  factory $KitchenReceiptCopyWith(KitchenReceipt value, $Res Function(KitchenReceipt) _then) = _$KitchenReceiptCopyWithImpl;
@useResult
$Res call({
 String orderNumber,@DeliveryTypeConverter() DeliveryType deliveryType, List<ReceiptLine> lines, String type, DateTime? requestedAt, String? customerPhone, String? customerNote, DateTime? printedAt, int revisionNo, List<String> revisionSummary
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
@pragma('vm:prefer-inline') @override $Res call({Object? orderNumber = null,Object? deliveryType = null,Object? lines = null,Object? type = null,Object? requestedAt = freezed,Object? customerPhone = freezed,Object? customerNote = freezed,Object? printedAt = freezed,Object? revisionNo = null,Object? revisionSummary = null,}) {
  return _then(_self.copyWith(
orderNumber: null == orderNumber ? _self.orderNumber : orderNumber // ignore: cast_nullable_to_non_nullable
as String,deliveryType: null == deliveryType ? _self.deliveryType : deliveryType // ignore: cast_nullable_to_non_nullable
as DeliveryType,lines: null == lines ? _self.lines : lines // ignore: cast_nullable_to_non_nullable
as List<ReceiptLine>,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,requestedAt: freezed == requestedAt ? _self.requestedAt : requestedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,customerPhone: freezed == customerPhone ? _self.customerPhone : customerPhone // ignore: cast_nullable_to_non_nullable
as String?,customerNote: freezed == customerNote ? _self.customerNote : customerNote // ignore: cast_nullable_to_non_nullable
as String?,printedAt: freezed == printedAt ? _self.printedAt : printedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,revisionNo: null == revisionNo ? _self.revisionNo : revisionNo // ignore: cast_nullable_to_non_nullable
as int,revisionSummary: null == revisionSummary ? _self.revisionSummary : revisionSummary // ignore: cast_nullable_to_non_nullable
as List<String>,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String orderNumber, @DeliveryTypeConverter()  DeliveryType deliveryType,  List<ReceiptLine> lines,  String type,  DateTime? requestedAt,  String? customerPhone,  String? customerNote,  DateTime? printedAt,  int revisionNo,  List<String> revisionSummary)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _KitchenReceipt() when $default != null:
return $default(_that.orderNumber,_that.deliveryType,_that.lines,_that.type,_that.requestedAt,_that.customerPhone,_that.customerNote,_that.printedAt,_that.revisionNo,_that.revisionSummary);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String orderNumber, @DeliveryTypeConverter()  DeliveryType deliveryType,  List<ReceiptLine> lines,  String type,  DateTime? requestedAt,  String? customerPhone,  String? customerNote,  DateTime? printedAt,  int revisionNo,  List<String> revisionSummary)  $default,) {final _that = this;
switch (_that) {
case _KitchenReceipt():
return $default(_that.orderNumber,_that.deliveryType,_that.lines,_that.type,_that.requestedAt,_that.customerPhone,_that.customerNote,_that.printedAt,_that.revisionNo,_that.revisionSummary);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String orderNumber, @DeliveryTypeConverter()  DeliveryType deliveryType,  List<ReceiptLine> lines,  String type,  DateTime? requestedAt,  String? customerPhone,  String? customerNote,  DateTime? printedAt,  int revisionNo,  List<String> revisionSummary)?  $default,) {final _that = this;
switch (_that) {
case _KitchenReceipt() when $default != null:
return $default(_that.orderNumber,_that.deliveryType,_that.lines,_that.type,_that.requestedAt,_that.customerPhone,_that.customerNote,_that.printedAt,_that.revisionNo,_that.revisionSummary);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _KitchenReceipt implements KitchenReceipt {
  const _KitchenReceipt({required this.orderNumber, @DeliveryTypeConverter() required this.deliveryType, required final  List<ReceiptLine> lines, this.type = 'mutfak', this.requestedAt, this.customerPhone, this.customerNote, this.printedAt, this.revisionNo = 0, final  List<String> revisionSummary = const <String>[]}): _lines = lines,_revisionSummary = revisionSummary;
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
/// Müşterinin telefonu — yalnızca **fişe** basmak için.
///
/// KDS kartında ([KitchenOrder]) telefon yoktur: ekran mutfakta gün boyu
/// açık durur. Fiş tek bir sipariş için basılıp kuryeye gider.
@override final  String? customerPhone;
@override final  String? customerNote;
@override final  DateTime? printedAt;
/// Kaçıncı revizyon; `0` = düzenlenmedi (K-20).
///
/// `>0` ise fişin başına çift boy `GÜNCEL FİŞ — REVİZE #N / ÖNCEKİ FİŞİ
/// ATIN` bandı basılır. K-20'ye kadar mutfak fişi bu bilgiyi hiç
/// almıyordu: düzenlenen sipariş için yeni kâğıt çıkıyor ama üstünde
/// onu öncekinden ayıran hiçbir şey yazmıyordu.
@override@JsonKey() final  int revisionNo;
/// İnsan okuyabilir değişiklik satırları; boşsa liste basılmaz.
 final  List<String> _revisionSummary;
/// İnsan okuyabilir değişiklik satırları; boşsa liste basılmaz.
@override@JsonKey() List<String> get revisionSummary {
  if (_revisionSummary is EqualUnmodifiableListView) return _revisionSummary;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_revisionSummary);
}


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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _KitchenReceipt&&(identical(other.orderNumber, orderNumber) || other.orderNumber == orderNumber)&&(identical(other.deliveryType, deliveryType) || other.deliveryType == deliveryType)&&const DeepCollectionEquality().equals(other._lines, _lines)&&(identical(other.type, type) || other.type == type)&&(identical(other.requestedAt, requestedAt) || other.requestedAt == requestedAt)&&(identical(other.customerPhone, customerPhone) || other.customerPhone == customerPhone)&&(identical(other.customerNote, customerNote) || other.customerNote == customerNote)&&(identical(other.printedAt, printedAt) || other.printedAt == printedAt)&&(identical(other.revisionNo, revisionNo) || other.revisionNo == revisionNo)&&const DeepCollectionEquality().equals(other._revisionSummary, _revisionSummary));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,orderNumber,deliveryType,const DeepCollectionEquality().hash(_lines),type,requestedAt,customerPhone,customerNote,printedAt,revisionNo,const DeepCollectionEquality().hash(_revisionSummary));

@override
String toString() {
  return 'KitchenReceipt(orderNumber: $orderNumber, deliveryType: $deliveryType, lines: $lines, type: $type, requestedAt: $requestedAt, customerPhone: $customerPhone, customerNote: $customerNote, printedAt: $printedAt, revisionNo: $revisionNo, revisionSummary: $revisionSummary)';
}


}

/// @nodoc
abstract mixin class _$KitchenReceiptCopyWith<$Res> implements $KitchenReceiptCopyWith<$Res> {
  factory _$KitchenReceiptCopyWith(_KitchenReceipt value, $Res Function(_KitchenReceipt) _then) = __$KitchenReceiptCopyWithImpl;
@override @useResult
$Res call({
 String orderNumber,@DeliveryTypeConverter() DeliveryType deliveryType, List<ReceiptLine> lines, String type, DateTime? requestedAt, String? customerPhone, String? customerNote, DateTime? printedAt, int revisionNo, List<String> revisionSummary
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
@override @pragma('vm:prefer-inline') $Res call({Object? orderNumber = null,Object? deliveryType = null,Object? lines = null,Object? type = null,Object? requestedAt = freezed,Object? customerPhone = freezed,Object? customerNote = freezed,Object? printedAt = freezed,Object? revisionNo = null,Object? revisionSummary = null,}) {
  return _then(_KitchenReceipt(
orderNumber: null == orderNumber ? _self.orderNumber : orderNumber // ignore: cast_nullable_to_non_nullable
as String,deliveryType: null == deliveryType ? _self.deliveryType : deliveryType // ignore: cast_nullable_to_non_nullable
as DeliveryType,lines: null == lines ? _self._lines : lines // ignore: cast_nullable_to_non_nullable
as List<ReceiptLine>,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,requestedAt: freezed == requestedAt ? _self.requestedAt : requestedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,customerPhone: freezed == customerPhone ? _self.customerPhone : customerPhone // ignore: cast_nullable_to_non_nullable
as String?,customerNote: freezed == customerNote ? _self.customerNote : customerNote // ignore: cast_nullable_to_non_nullable
as String?,printedAt: freezed == printedAt ? _self.printedAt : printedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,revisionNo: null == revisionNo ? _self.revisionNo : revisionNo // ignore: cast_nullable_to_non_nullable
as int,revisionSummary: null == revisionSummary ? _self._revisionSummary : revisionSummary // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$CustomerReceipt {

 String get orderNumber;@DeliveryTypeConverter() DeliveryType get deliveryType; List<OrderItem> get items; int get subtotal; int get deliveryFee; int get total; String get currency; Payment get payment; String get type;/// `pickup` siparişte `null` — fişte adres bloğu basılmaz.
 Address? get address; DateTime? get requestedAt; String? get customerLabel; DateTime? get printedAt;/// Sipariş takip sayfası — fişe QR olarak basılır (K-18).
///
/// `null` gelirse QR basılmaz: sunucuda `FRONTEND_URL` tanımsız
/// demektir ve çalışmayan bir kare basmak, okutup boş sayfa gören
/// müşteri üretmekten iyi değil.
 String? get trackUrl;/// Ödeme sayfası — fişe QR olarak basılır (K-19).
///
/// YALNIZCA ödenmemiş siparişte dolu. Ödenmiş siparişin fişine ödeme
/// QR'ı basmak, ikinci kez ödemeye davet etmek olurdu.
 String? get payUrl;// ── K-20: kurye fişinden devralınan alanlar ─────────────────────────
/// Tam ad — kurye kapıda "kime teslim ediyorum" sorusunu bundan
/// cevaplıyor. Gel-al siparişinde `null`.
 String? get customerName;/// Müşterinin telefonu — kapı açılmadığında kuryenin arayacağı numara.
/// Gel-al siparişinde `null`.
 String? get customerPhone;/// Sipariş notu ("Zili çalmayın").
///
/// BU FİŞE TAŞINMASI ŞARTTI: kapı talimatı kuryeye bugüne kadar yalnız
/// kurye fişiyle ulaşıyordu; o fişi otomatik basmaktan vazgeçip notu
/// taşımasaydık kuryenin elinden bir kapı talimatını silmiş olurduk.
 String? get customerNote;/// Kapıda tahsil edilecek tutar (kuruş). Ödenmişse ve gel-al'da `0`;
/// KDS o durumda satırı hiç basmaz.
 int get collectAmount;/// Kaçıncı revizyon; `0` = düzenlenmedi.
 int get revisionNo;/// İnsan okuyabilir değişiklik satırları.
 List<String> get revisionSummary;/// "Teslim ettim" QR'ı — kurye okutunca tek düğmeli onay sayfası açılır.
///
/// `null` olduğu hâller: gel-al siparişi (kurye yok) ya da sunucuda imza
/// sırrı yapılandırılmamış. İkisinde de kare hiç basılmaz.
 String? get deliverUrl;
/// Create a copy of CustomerReceipt
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CustomerReceiptCopyWith<CustomerReceipt> get copyWith => _$CustomerReceiptCopyWithImpl<CustomerReceipt>(this as CustomerReceipt, _$identity);

  /// Serializes this CustomerReceipt to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CustomerReceipt&&(identical(other.orderNumber, orderNumber) || other.orderNumber == orderNumber)&&(identical(other.deliveryType, deliveryType) || other.deliveryType == deliveryType)&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.subtotal, subtotal) || other.subtotal == subtotal)&&(identical(other.deliveryFee, deliveryFee) || other.deliveryFee == deliveryFee)&&(identical(other.total, total) || other.total == total)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.payment, payment) || other.payment == payment)&&(identical(other.type, type) || other.type == type)&&(identical(other.address, address) || other.address == address)&&(identical(other.requestedAt, requestedAt) || other.requestedAt == requestedAt)&&(identical(other.customerLabel, customerLabel) || other.customerLabel == customerLabel)&&(identical(other.printedAt, printedAt) || other.printedAt == printedAt)&&(identical(other.trackUrl, trackUrl) || other.trackUrl == trackUrl)&&(identical(other.payUrl, payUrl) || other.payUrl == payUrl)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.customerPhone, customerPhone) || other.customerPhone == customerPhone)&&(identical(other.customerNote, customerNote) || other.customerNote == customerNote)&&(identical(other.collectAmount, collectAmount) || other.collectAmount == collectAmount)&&(identical(other.revisionNo, revisionNo) || other.revisionNo == revisionNo)&&const DeepCollectionEquality().equals(other.revisionSummary, revisionSummary)&&(identical(other.deliverUrl, deliverUrl) || other.deliverUrl == deliverUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,orderNumber,deliveryType,const DeepCollectionEquality().hash(items),subtotal,deliveryFee,total,currency,payment,type,address,requestedAt,customerLabel,printedAt,trackUrl,payUrl,customerName,customerPhone,customerNote,collectAmount,revisionNo,const DeepCollectionEquality().hash(revisionSummary),deliverUrl]);

@override
String toString() {
  return 'CustomerReceipt(orderNumber: $orderNumber, deliveryType: $deliveryType, items: $items, subtotal: $subtotal, deliveryFee: $deliveryFee, total: $total, currency: $currency, payment: $payment, type: $type, address: $address, requestedAt: $requestedAt, customerLabel: $customerLabel, printedAt: $printedAt, trackUrl: $trackUrl, payUrl: $payUrl, customerName: $customerName, customerPhone: $customerPhone, customerNote: $customerNote, collectAmount: $collectAmount, revisionNo: $revisionNo, revisionSummary: $revisionSummary, deliverUrl: $deliverUrl)';
}


}

/// @nodoc
abstract mixin class $CustomerReceiptCopyWith<$Res>  {
  factory $CustomerReceiptCopyWith(CustomerReceipt value, $Res Function(CustomerReceipt) _then) = _$CustomerReceiptCopyWithImpl;
@useResult
$Res call({
 String orderNumber,@DeliveryTypeConverter() DeliveryType deliveryType, List<OrderItem> items, int subtotal, int deliveryFee, int total, String currency, Payment payment, String type, Address? address, DateTime? requestedAt, String? customerLabel, DateTime? printedAt, String? trackUrl, String? payUrl, String? customerName, String? customerPhone, String? customerNote, int collectAmount, int revisionNo, List<String> revisionSummary, String? deliverUrl
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
@pragma('vm:prefer-inline') @override $Res call({Object? orderNumber = null,Object? deliveryType = null,Object? items = null,Object? subtotal = null,Object? deliveryFee = null,Object? total = null,Object? currency = null,Object? payment = null,Object? type = null,Object? address = freezed,Object? requestedAt = freezed,Object? customerLabel = freezed,Object? printedAt = freezed,Object? trackUrl = freezed,Object? payUrl = freezed,Object? customerName = freezed,Object? customerPhone = freezed,Object? customerNote = freezed,Object? collectAmount = null,Object? revisionNo = null,Object? revisionSummary = null,Object? deliverUrl = freezed,}) {
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
as DateTime?,trackUrl: freezed == trackUrl ? _self.trackUrl : trackUrl // ignore: cast_nullable_to_non_nullable
as String?,payUrl: freezed == payUrl ? _self.payUrl : payUrl // ignore: cast_nullable_to_non_nullable
as String?,customerName: freezed == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String?,customerPhone: freezed == customerPhone ? _self.customerPhone : customerPhone // ignore: cast_nullable_to_non_nullable
as String?,customerNote: freezed == customerNote ? _self.customerNote : customerNote // ignore: cast_nullable_to_non_nullable
as String?,collectAmount: null == collectAmount ? _self.collectAmount : collectAmount // ignore: cast_nullable_to_non_nullable
as int,revisionNo: null == revisionNo ? _self.revisionNo : revisionNo // ignore: cast_nullable_to_non_nullable
as int,revisionSummary: null == revisionSummary ? _self.revisionSummary : revisionSummary // ignore: cast_nullable_to_non_nullable
as List<String>,deliverUrl: freezed == deliverUrl ? _self.deliverUrl : deliverUrl // ignore: cast_nullable_to_non_nullable
as String?,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String orderNumber, @DeliveryTypeConverter()  DeliveryType deliveryType,  List<OrderItem> items,  int subtotal,  int deliveryFee,  int total,  String currency,  Payment payment,  String type,  Address? address,  DateTime? requestedAt,  String? customerLabel,  DateTime? printedAt,  String? trackUrl,  String? payUrl,  String? customerName,  String? customerPhone,  String? customerNote,  int collectAmount,  int revisionNo,  List<String> revisionSummary,  String? deliverUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CustomerReceipt() when $default != null:
return $default(_that.orderNumber,_that.deliveryType,_that.items,_that.subtotal,_that.deliveryFee,_that.total,_that.currency,_that.payment,_that.type,_that.address,_that.requestedAt,_that.customerLabel,_that.printedAt,_that.trackUrl,_that.payUrl,_that.customerName,_that.customerPhone,_that.customerNote,_that.collectAmount,_that.revisionNo,_that.revisionSummary,_that.deliverUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String orderNumber, @DeliveryTypeConverter()  DeliveryType deliveryType,  List<OrderItem> items,  int subtotal,  int deliveryFee,  int total,  String currency,  Payment payment,  String type,  Address? address,  DateTime? requestedAt,  String? customerLabel,  DateTime? printedAt,  String? trackUrl,  String? payUrl,  String? customerName,  String? customerPhone,  String? customerNote,  int collectAmount,  int revisionNo,  List<String> revisionSummary,  String? deliverUrl)  $default,) {final _that = this;
switch (_that) {
case _CustomerReceipt():
return $default(_that.orderNumber,_that.deliveryType,_that.items,_that.subtotal,_that.deliveryFee,_that.total,_that.currency,_that.payment,_that.type,_that.address,_that.requestedAt,_that.customerLabel,_that.printedAt,_that.trackUrl,_that.payUrl,_that.customerName,_that.customerPhone,_that.customerNote,_that.collectAmount,_that.revisionNo,_that.revisionSummary,_that.deliverUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String orderNumber, @DeliveryTypeConverter()  DeliveryType deliveryType,  List<OrderItem> items,  int subtotal,  int deliveryFee,  int total,  String currency,  Payment payment,  String type,  Address? address,  DateTime? requestedAt,  String? customerLabel,  DateTime? printedAt,  String? trackUrl,  String? payUrl,  String? customerName,  String? customerPhone,  String? customerNote,  int collectAmount,  int revisionNo,  List<String> revisionSummary,  String? deliverUrl)?  $default,) {final _that = this;
switch (_that) {
case _CustomerReceipt() when $default != null:
return $default(_that.orderNumber,_that.deliveryType,_that.items,_that.subtotal,_that.deliveryFee,_that.total,_that.currency,_that.payment,_that.type,_that.address,_that.requestedAt,_that.customerLabel,_that.printedAt,_that.trackUrl,_that.payUrl,_that.customerName,_that.customerPhone,_that.customerNote,_that.collectAmount,_that.revisionNo,_that.revisionSummary,_that.deliverUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CustomerReceipt implements CustomerReceipt {
  const _CustomerReceipt({required this.orderNumber, @DeliveryTypeConverter() required this.deliveryType, required final  List<OrderItem> items, required this.subtotal, required this.deliveryFee, required this.total, required this.currency, required this.payment, this.type = 'musteri', this.address, this.requestedAt, this.customerLabel, this.printedAt, this.trackUrl, this.payUrl, this.customerName, this.customerPhone, this.customerNote, this.collectAmount = 0, this.revisionNo = 0, final  List<String> revisionSummary = const <String>[], this.deliverUrl}): _items = items,_revisionSummary = revisionSummary;
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
/// Sipariş takip sayfası — fişe QR olarak basılır (K-18).
///
/// `null` gelirse QR basılmaz: sunucuda `FRONTEND_URL` tanımsız
/// demektir ve çalışmayan bir kare basmak, okutup boş sayfa gören
/// müşteri üretmekten iyi değil.
@override final  String? trackUrl;
/// Ödeme sayfası — fişe QR olarak basılır (K-19).
///
/// YALNIZCA ödenmemiş siparişte dolu. Ödenmiş siparişin fişine ödeme
/// QR'ı basmak, ikinci kez ödemeye davet etmek olurdu.
@override final  String? payUrl;
// ── K-20: kurye fişinden devralınan alanlar ─────────────────────────
/// Tam ad — kurye kapıda "kime teslim ediyorum" sorusunu bundan
/// cevaplıyor. Gel-al siparişinde `null`.
@override final  String? customerName;
/// Müşterinin telefonu — kapı açılmadığında kuryenin arayacağı numara.
/// Gel-al siparişinde `null`.
@override final  String? customerPhone;
/// Sipariş notu ("Zili çalmayın").
///
/// BU FİŞE TAŞINMASI ŞARTTI: kapı talimatı kuryeye bugüne kadar yalnız
/// kurye fişiyle ulaşıyordu; o fişi otomatik basmaktan vazgeçip notu
/// taşımasaydık kuryenin elinden bir kapı talimatını silmiş olurduk.
@override final  String? customerNote;
/// Kapıda tahsil edilecek tutar (kuruş). Ödenmişse ve gel-al'da `0`;
/// KDS o durumda satırı hiç basmaz.
@override@JsonKey() final  int collectAmount;
/// Kaçıncı revizyon; `0` = düzenlenmedi.
@override@JsonKey() final  int revisionNo;
/// İnsan okuyabilir değişiklik satırları.
 final  List<String> _revisionSummary;
/// İnsan okuyabilir değişiklik satırları.
@override@JsonKey() List<String> get revisionSummary {
  if (_revisionSummary is EqualUnmodifiableListView) return _revisionSummary;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_revisionSummary);
}

/// "Teslim ettim" QR'ı — kurye okutunca tek düğmeli onay sayfası açılır.
///
/// `null` olduğu hâller: gel-al siparişi (kurye yok) ya da sunucuda imza
/// sırrı yapılandırılmamış. İkisinde de kare hiç basılmaz.
@override final  String? deliverUrl;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CustomerReceipt&&(identical(other.orderNumber, orderNumber) || other.orderNumber == orderNumber)&&(identical(other.deliveryType, deliveryType) || other.deliveryType == deliveryType)&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.subtotal, subtotal) || other.subtotal == subtotal)&&(identical(other.deliveryFee, deliveryFee) || other.deliveryFee == deliveryFee)&&(identical(other.total, total) || other.total == total)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.payment, payment) || other.payment == payment)&&(identical(other.type, type) || other.type == type)&&(identical(other.address, address) || other.address == address)&&(identical(other.requestedAt, requestedAt) || other.requestedAt == requestedAt)&&(identical(other.customerLabel, customerLabel) || other.customerLabel == customerLabel)&&(identical(other.printedAt, printedAt) || other.printedAt == printedAt)&&(identical(other.trackUrl, trackUrl) || other.trackUrl == trackUrl)&&(identical(other.payUrl, payUrl) || other.payUrl == payUrl)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.customerPhone, customerPhone) || other.customerPhone == customerPhone)&&(identical(other.customerNote, customerNote) || other.customerNote == customerNote)&&(identical(other.collectAmount, collectAmount) || other.collectAmount == collectAmount)&&(identical(other.revisionNo, revisionNo) || other.revisionNo == revisionNo)&&const DeepCollectionEquality().equals(other._revisionSummary, _revisionSummary)&&(identical(other.deliverUrl, deliverUrl) || other.deliverUrl == deliverUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,orderNumber,deliveryType,const DeepCollectionEquality().hash(_items),subtotal,deliveryFee,total,currency,payment,type,address,requestedAt,customerLabel,printedAt,trackUrl,payUrl,customerName,customerPhone,customerNote,collectAmount,revisionNo,const DeepCollectionEquality().hash(_revisionSummary),deliverUrl]);

@override
String toString() {
  return 'CustomerReceipt(orderNumber: $orderNumber, deliveryType: $deliveryType, items: $items, subtotal: $subtotal, deliveryFee: $deliveryFee, total: $total, currency: $currency, payment: $payment, type: $type, address: $address, requestedAt: $requestedAt, customerLabel: $customerLabel, printedAt: $printedAt, trackUrl: $trackUrl, payUrl: $payUrl, customerName: $customerName, customerPhone: $customerPhone, customerNote: $customerNote, collectAmount: $collectAmount, revisionNo: $revisionNo, revisionSummary: $revisionSummary, deliverUrl: $deliverUrl)';
}


}

/// @nodoc
abstract mixin class _$CustomerReceiptCopyWith<$Res> implements $CustomerReceiptCopyWith<$Res> {
  factory _$CustomerReceiptCopyWith(_CustomerReceipt value, $Res Function(_CustomerReceipt) _then) = __$CustomerReceiptCopyWithImpl;
@override @useResult
$Res call({
 String orderNumber,@DeliveryTypeConverter() DeliveryType deliveryType, List<OrderItem> items, int subtotal, int deliveryFee, int total, String currency, Payment payment, String type, Address? address, DateTime? requestedAt, String? customerLabel, DateTime? printedAt, String? trackUrl, String? payUrl, String? customerName, String? customerPhone, String? customerNote, int collectAmount, int revisionNo, List<String> revisionSummary, String? deliverUrl
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
@override @pragma('vm:prefer-inline') $Res call({Object? orderNumber = null,Object? deliveryType = null,Object? items = null,Object? subtotal = null,Object? deliveryFee = null,Object? total = null,Object? currency = null,Object? payment = null,Object? type = null,Object? address = freezed,Object? requestedAt = freezed,Object? customerLabel = freezed,Object? printedAt = freezed,Object? trackUrl = freezed,Object? payUrl = freezed,Object? customerName = freezed,Object? customerPhone = freezed,Object? customerNote = freezed,Object? collectAmount = null,Object? revisionNo = null,Object? revisionSummary = null,Object? deliverUrl = freezed,}) {
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
as DateTime?,trackUrl: freezed == trackUrl ? _self.trackUrl : trackUrl // ignore: cast_nullable_to_non_nullable
as String?,payUrl: freezed == payUrl ? _self.payUrl : payUrl // ignore: cast_nullable_to_non_nullable
as String?,customerName: freezed == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String?,customerPhone: freezed == customerPhone ? _self.customerPhone : customerPhone // ignore: cast_nullable_to_non_nullable
as String?,customerNote: freezed == customerNote ? _self.customerNote : customerNote // ignore: cast_nullable_to_non_nullable
as String?,collectAmount: null == collectAmount ? _self.collectAmount : collectAmount // ignore: cast_nullable_to_non_nullable
as int,revisionNo: null == revisionNo ? _self.revisionNo : revisionNo // ignore: cast_nullable_to_non_nullable
as int,revisionSummary: null == revisionSummary ? _self._revisionSummary : revisionSummary // ignore: cast_nullable_to_non_nullable
as List<String>,deliverUrl: freezed == deliverUrl ? _self.deliverUrl : deliverUrl // ignore: cast_nullable_to_non_nullable
as String?,
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
mixin _$CourierReceipt {

 String get orderNumber;@DeliveryTypeConverter() DeliveryType get deliveryType; List<OrderItem> get items; int get total; String get currency; Payment get payment; String get type; Address? get address; DateTime? get requestedAt; String? get customerName; String? get customerPhone; String? get customerNote; DateTime? get printedAt;/// Kaçıncı revizyon; 0 = düzenlenmemiş.
 int get revisionNo;/// İnsan okuyabilir değişiklik satırları.
 List<String> get revisionSummary;/// Kapıda tahsil edilecek tutar (kuruş). Ödenmişse 0.
 int get collectAmount;
/// Create a copy of CourierReceipt
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CourierReceiptCopyWith<CourierReceipt> get copyWith => _$CourierReceiptCopyWithImpl<CourierReceipt>(this as CourierReceipt, _$identity);

  /// Serializes this CourierReceipt to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CourierReceipt&&(identical(other.orderNumber, orderNumber) || other.orderNumber == orderNumber)&&(identical(other.deliveryType, deliveryType) || other.deliveryType == deliveryType)&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.total, total) || other.total == total)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.payment, payment) || other.payment == payment)&&(identical(other.type, type) || other.type == type)&&(identical(other.address, address) || other.address == address)&&(identical(other.requestedAt, requestedAt) || other.requestedAt == requestedAt)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.customerPhone, customerPhone) || other.customerPhone == customerPhone)&&(identical(other.customerNote, customerNote) || other.customerNote == customerNote)&&(identical(other.printedAt, printedAt) || other.printedAt == printedAt)&&(identical(other.revisionNo, revisionNo) || other.revisionNo == revisionNo)&&const DeepCollectionEquality().equals(other.revisionSummary, revisionSummary)&&(identical(other.collectAmount, collectAmount) || other.collectAmount == collectAmount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,orderNumber,deliveryType,const DeepCollectionEquality().hash(items),total,currency,payment,type,address,requestedAt,customerName,customerPhone,customerNote,printedAt,revisionNo,const DeepCollectionEquality().hash(revisionSummary),collectAmount);

@override
String toString() {
  return 'CourierReceipt(orderNumber: $orderNumber, deliveryType: $deliveryType, items: $items, total: $total, currency: $currency, payment: $payment, type: $type, address: $address, requestedAt: $requestedAt, customerName: $customerName, customerPhone: $customerPhone, customerNote: $customerNote, printedAt: $printedAt, revisionNo: $revisionNo, revisionSummary: $revisionSummary, collectAmount: $collectAmount)';
}


}

/// @nodoc
abstract mixin class $CourierReceiptCopyWith<$Res>  {
  factory $CourierReceiptCopyWith(CourierReceipt value, $Res Function(CourierReceipt) _then) = _$CourierReceiptCopyWithImpl;
@useResult
$Res call({
 String orderNumber,@DeliveryTypeConverter() DeliveryType deliveryType, List<OrderItem> items, int total, String currency, Payment payment, String type, Address? address, DateTime? requestedAt, String? customerName, String? customerPhone, String? customerNote, DateTime? printedAt, int revisionNo, List<String> revisionSummary, int collectAmount
});


$PaymentCopyWith<$Res> get payment;$AddressCopyWith<$Res>? get address;

}
/// @nodoc
class _$CourierReceiptCopyWithImpl<$Res>
    implements $CourierReceiptCopyWith<$Res> {
  _$CourierReceiptCopyWithImpl(this._self, this._then);

  final CourierReceipt _self;
  final $Res Function(CourierReceipt) _then;

/// Create a copy of CourierReceipt
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? orderNumber = null,Object? deliveryType = null,Object? items = null,Object? total = null,Object? currency = null,Object? payment = null,Object? type = null,Object? address = freezed,Object? requestedAt = freezed,Object? customerName = freezed,Object? customerPhone = freezed,Object? customerNote = freezed,Object? printedAt = freezed,Object? revisionNo = null,Object? revisionSummary = null,Object? collectAmount = null,}) {
  return _then(_self.copyWith(
orderNumber: null == orderNumber ? _self.orderNumber : orderNumber // ignore: cast_nullable_to_non_nullable
as String,deliveryType: null == deliveryType ? _self.deliveryType : deliveryType // ignore: cast_nullable_to_non_nullable
as DeliveryType,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<OrderItem>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,payment: null == payment ? _self.payment : payment // ignore: cast_nullable_to_non_nullable
as Payment,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as Address?,requestedAt: freezed == requestedAt ? _self.requestedAt : requestedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,customerName: freezed == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String?,customerPhone: freezed == customerPhone ? _self.customerPhone : customerPhone // ignore: cast_nullable_to_non_nullable
as String?,customerNote: freezed == customerNote ? _self.customerNote : customerNote // ignore: cast_nullable_to_non_nullable
as String?,printedAt: freezed == printedAt ? _self.printedAt : printedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,revisionNo: null == revisionNo ? _self.revisionNo : revisionNo // ignore: cast_nullable_to_non_nullable
as int,revisionSummary: null == revisionSummary ? _self.revisionSummary : revisionSummary // ignore: cast_nullable_to_non_nullable
as List<String>,collectAmount: null == collectAmount ? _self.collectAmount : collectAmount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of CourierReceipt
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PaymentCopyWith<$Res> get payment {
  
  return $PaymentCopyWith<$Res>(_self.payment, (value) {
    return _then(_self.copyWith(payment: value));
  });
}/// Create a copy of CourierReceipt
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


/// Adds pattern-matching-related methods to [CourierReceipt].
extension CourierReceiptPatterns on CourierReceipt {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CourierReceipt value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CourierReceipt() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CourierReceipt value)  $default,){
final _that = this;
switch (_that) {
case _CourierReceipt():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CourierReceipt value)?  $default,){
final _that = this;
switch (_that) {
case _CourierReceipt() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String orderNumber, @DeliveryTypeConverter()  DeliveryType deliveryType,  List<OrderItem> items,  int total,  String currency,  Payment payment,  String type,  Address? address,  DateTime? requestedAt,  String? customerName,  String? customerPhone,  String? customerNote,  DateTime? printedAt,  int revisionNo,  List<String> revisionSummary,  int collectAmount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CourierReceipt() when $default != null:
return $default(_that.orderNumber,_that.deliveryType,_that.items,_that.total,_that.currency,_that.payment,_that.type,_that.address,_that.requestedAt,_that.customerName,_that.customerPhone,_that.customerNote,_that.printedAt,_that.revisionNo,_that.revisionSummary,_that.collectAmount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String orderNumber, @DeliveryTypeConverter()  DeliveryType deliveryType,  List<OrderItem> items,  int total,  String currency,  Payment payment,  String type,  Address? address,  DateTime? requestedAt,  String? customerName,  String? customerPhone,  String? customerNote,  DateTime? printedAt,  int revisionNo,  List<String> revisionSummary,  int collectAmount)  $default,) {final _that = this;
switch (_that) {
case _CourierReceipt():
return $default(_that.orderNumber,_that.deliveryType,_that.items,_that.total,_that.currency,_that.payment,_that.type,_that.address,_that.requestedAt,_that.customerName,_that.customerPhone,_that.customerNote,_that.printedAt,_that.revisionNo,_that.revisionSummary,_that.collectAmount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String orderNumber, @DeliveryTypeConverter()  DeliveryType deliveryType,  List<OrderItem> items,  int total,  String currency,  Payment payment,  String type,  Address? address,  DateTime? requestedAt,  String? customerName,  String? customerPhone,  String? customerNote,  DateTime? printedAt,  int revisionNo,  List<String> revisionSummary,  int collectAmount)?  $default,) {final _that = this;
switch (_that) {
case _CourierReceipt() when $default != null:
return $default(_that.orderNumber,_that.deliveryType,_that.items,_that.total,_that.currency,_that.payment,_that.type,_that.address,_that.requestedAt,_that.customerName,_that.customerPhone,_that.customerNote,_that.printedAt,_that.revisionNo,_that.revisionSummary,_that.collectAmount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CourierReceipt implements CourierReceipt {
  const _CourierReceipt({required this.orderNumber, @DeliveryTypeConverter() required this.deliveryType, required final  List<OrderItem> items, required this.total, required this.currency, required this.payment, this.type = 'kurye', this.address, this.requestedAt, this.customerName, this.customerPhone, this.customerNote, this.printedAt, this.revisionNo = 0, final  List<String> revisionSummary = const <String>[], this.collectAmount = 0}): _items = items,_revisionSummary = revisionSummary;
  factory _CourierReceipt.fromJson(Map<String, dynamic> json) => _$CourierReceiptFromJson(json);

@override final  String orderNumber;
@override@DeliveryTypeConverter() final  DeliveryType deliveryType;
 final  List<OrderItem> _items;
@override List<OrderItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override final  int total;
@override final  String currency;
@override final  Payment payment;
@override@JsonKey() final  String type;
@override final  Address? address;
@override final  DateTime? requestedAt;
@override final  String? customerName;
@override final  String? customerPhone;
@override final  String? customerNote;
@override final  DateTime? printedAt;
/// Kaçıncı revizyon; 0 = düzenlenmemiş.
@override@JsonKey() final  int revisionNo;
/// İnsan okuyabilir değişiklik satırları.
 final  List<String> _revisionSummary;
/// İnsan okuyabilir değişiklik satırları.
@override@JsonKey() List<String> get revisionSummary {
  if (_revisionSummary is EqualUnmodifiableListView) return _revisionSummary;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_revisionSummary);
}

/// Kapıda tahsil edilecek tutar (kuruş). Ödenmişse 0.
@override@JsonKey() final  int collectAmount;

/// Create a copy of CourierReceipt
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CourierReceiptCopyWith<_CourierReceipt> get copyWith => __$CourierReceiptCopyWithImpl<_CourierReceipt>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CourierReceiptToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CourierReceipt&&(identical(other.orderNumber, orderNumber) || other.orderNumber == orderNumber)&&(identical(other.deliveryType, deliveryType) || other.deliveryType == deliveryType)&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.total, total) || other.total == total)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.payment, payment) || other.payment == payment)&&(identical(other.type, type) || other.type == type)&&(identical(other.address, address) || other.address == address)&&(identical(other.requestedAt, requestedAt) || other.requestedAt == requestedAt)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.customerPhone, customerPhone) || other.customerPhone == customerPhone)&&(identical(other.customerNote, customerNote) || other.customerNote == customerNote)&&(identical(other.printedAt, printedAt) || other.printedAt == printedAt)&&(identical(other.revisionNo, revisionNo) || other.revisionNo == revisionNo)&&const DeepCollectionEquality().equals(other._revisionSummary, _revisionSummary)&&(identical(other.collectAmount, collectAmount) || other.collectAmount == collectAmount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,orderNumber,deliveryType,const DeepCollectionEquality().hash(_items),total,currency,payment,type,address,requestedAt,customerName,customerPhone,customerNote,printedAt,revisionNo,const DeepCollectionEquality().hash(_revisionSummary),collectAmount);

@override
String toString() {
  return 'CourierReceipt(orderNumber: $orderNumber, deliveryType: $deliveryType, items: $items, total: $total, currency: $currency, payment: $payment, type: $type, address: $address, requestedAt: $requestedAt, customerName: $customerName, customerPhone: $customerPhone, customerNote: $customerNote, printedAt: $printedAt, revisionNo: $revisionNo, revisionSummary: $revisionSummary, collectAmount: $collectAmount)';
}


}

/// @nodoc
abstract mixin class _$CourierReceiptCopyWith<$Res> implements $CourierReceiptCopyWith<$Res> {
  factory _$CourierReceiptCopyWith(_CourierReceipt value, $Res Function(_CourierReceipt) _then) = __$CourierReceiptCopyWithImpl;
@override @useResult
$Res call({
 String orderNumber,@DeliveryTypeConverter() DeliveryType deliveryType, List<OrderItem> items, int total, String currency, Payment payment, String type, Address? address, DateTime? requestedAt, String? customerName, String? customerPhone, String? customerNote, DateTime? printedAt, int revisionNo, List<String> revisionSummary, int collectAmount
});


@override $PaymentCopyWith<$Res> get payment;@override $AddressCopyWith<$Res>? get address;

}
/// @nodoc
class __$CourierReceiptCopyWithImpl<$Res>
    implements _$CourierReceiptCopyWith<$Res> {
  __$CourierReceiptCopyWithImpl(this._self, this._then);

  final _CourierReceipt _self;
  final $Res Function(_CourierReceipt) _then;

/// Create a copy of CourierReceipt
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? orderNumber = null,Object? deliveryType = null,Object? items = null,Object? total = null,Object? currency = null,Object? payment = null,Object? type = null,Object? address = freezed,Object? requestedAt = freezed,Object? customerName = freezed,Object? customerPhone = freezed,Object? customerNote = freezed,Object? printedAt = freezed,Object? revisionNo = null,Object? revisionSummary = null,Object? collectAmount = null,}) {
  return _then(_CourierReceipt(
orderNumber: null == orderNumber ? _self.orderNumber : orderNumber // ignore: cast_nullable_to_non_nullable
as String,deliveryType: null == deliveryType ? _self.deliveryType : deliveryType // ignore: cast_nullable_to_non_nullable
as DeliveryType,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<OrderItem>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,payment: null == payment ? _self.payment : payment // ignore: cast_nullable_to_non_nullable
as Payment,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as Address?,requestedAt: freezed == requestedAt ? _self.requestedAt : requestedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,customerName: freezed == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String?,customerPhone: freezed == customerPhone ? _self.customerPhone : customerPhone // ignore: cast_nullable_to_non_nullable
as String?,customerNote: freezed == customerNote ? _self.customerNote : customerNote // ignore: cast_nullable_to_non_nullable
as String?,printedAt: freezed == printedAt ? _self.printedAt : printedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,revisionNo: null == revisionNo ? _self.revisionNo : revisionNo // ignore: cast_nullable_to_non_nullable
as int,revisionSummary: null == revisionSummary ? _self._revisionSummary : revisionSummary // ignore: cast_nullable_to_non_nullable
as List<String>,collectAmount: null == collectAmount ? _self.collectAmount : collectAmount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of CourierReceipt
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PaymentCopyWith<$Res> get payment {
  
  return $PaymentCopyWith<$Res>(_self.payment, (value) {
    return _then(_self.copyWith(payment: value));
  });
}/// Create a copy of CourierReceipt
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

@ReceiptTypeConverter() ReceiptType get type; DateTime get printedAt;/// Fişin hangi revizyon için basıldığı (K-20).
///
/// Sunucudaki denetim tekilliği `(order_id, type, revision)`. Alan
/// gönderilmezse `0` sayılır; eski KDS sürümleri çalışmaya devam eder.
 int get revision;
/// Create a copy of PrintAckRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PrintAckRequestCopyWith<PrintAckRequest> get copyWith => _$PrintAckRequestCopyWithImpl<PrintAckRequest>(this as PrintAckRequest, _$identity);

  /// Serializes this PrintAckRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PrintAckRequest&&(identical(other.type, type) || other.type == type)&&(identical(other.printedAt, printedAt) || other.printedAt == printedAt)&&(identical(other.revision, revision) || other.revision == revision));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,printedAt,revision);

@override
String toString() {
  return 'PrintAckRequest(type: $type, printedAt: $printedAt, revision: $revision)';
}


}

/// @nodoc
abstract mixin class $PrintAckRequestCopyWith<$Res>  {
  factory $PrintAckRequestCopyWith(PrintAckRequest value, $Res Function(PrintAckRequest) _then) = _$PrintAckRequestCopyWithImpl;
@useResult
$Res call({
@ReceiptTypeConverter() ReceiptType type, DateTime printedAt, int revision
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
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? printedAt = null,Object? revision = null,}) {
  return _then(_self.copyWith(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ReceiptType,printedAt: null == printedAt ? _self.printedAt : printedAt // ignore: cast_nullable_to_non_nullable
as DateTime,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@ReceiptTypeConverter()  ReceiptType type,  DateTime printedAt,  int revision)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PrintAckRequest() when $default != null:
return $default(_that.type,_that.printedAt,_that.revision);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@ReceiptTypeConverter()  ReceiptType type,  DateTime printedAt,  int revision)  $default,) {final _that = this;
switch (_that) {
case _PrintAckRequest():
return $default(_that.type,_that.printedAt,_that.revision);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@ReceiptTypeConverter()  ReceiptType type,  DateTime printedAt,  int revision)?  $default,) {final _that = this;
switch (_that) {
case _PrintAckRequest() when $default != null:
return $default(_that.type,_that.printedAt,_that.revision);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PrintAckRequest implements PrintAckRequest {
  const _PrintAckRequest({@ReceiptTypeConverter() required this.type, required this.printedAt, this.revision = 0});
  factory _PrintAckRequest.fromJson(Map<String, dynamic> json) => _$PrintAckRequestFromJson(json);

@override@ReceiptTypeConverter() final  ReceiptType type;
@override final  DateTime printedAt;
/// Fişin hangi revizyon için basıldığı (K-20).
///
/// Sunucudaki denetim tekilliği `(order_id, type, revision)`. Alan
/// gönderilmezse `0` sayılır; eski KDS sürümleri çalışmaya devam eder.
@override@JsonKey() final  int revision;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PrintAckRequest&&(identical(other.type, type) || other.type == type)&&(identical(other.printedAt, printedAt) || other.printedAt == printedAt)&&(identical(other.revision, revision) || other.revision == revision));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,printedAt,revision);

@override
String toString() {
  return 'PrintAckRequest(type: $type, printedAt: $printedAt, revision: $revision)';
}


}

/// @nodoc
abstract mixin class _$PrintAckRequestCopyWith<$Res> implements $PrintAckRequestCopyWith<$Res> {
  factory _$PrintAckRequestCopyWith(_PrintAckRequest value, $Res Function(_PrintAckRequest) _then) = __$PrintAckRequestCopyWithImpl;
@override @useResult
$Res call({
@ReceiptTypeConverter() ReceiptType type, DateTime printedAt, int revision
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
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? printedAt = null,Object? revision = null,}) {
  return _then(_PrintAckRequest(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ReceiptType,printedAt: null == printedAt ? _self.printedAt : printedAt // ignore: cast_nullable_to_non_nullable
as DateTime,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,
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
mixin _$BusyState {

 bool get busy; String get busyMessage; DateTime get serverTime;
/// Create a copy of BusyState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BusyStateCopyWith<BusyState> get copyWith => _$BusyStateCopyWithImpl<BusyState>(this as BusyState, _$identity);

  /// Serializes this BusyState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BusyState&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.busyMessage, busyMessage) || other.busyMessage == busyMessage)&&(identical(other.serverTime, serverTime) || other.serverTime == serverTime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,busy,busyMessage,serverTime);

@override
String toString() {
  return 'BusyState(busy: $busy, busyMessage: $busyMessage, serverTime: $serverTime)';
}


}

/// @nodoc
abstract mixin class $BusyStateCopyWith<$Res>  {
  factory $BusyStateCopyWith(BusyState value, $Res Function(BusyState) _then) = _$BusyStateCopyWithImpl;
@useResult
$Res call({
 bool busy, String busyMessage, DateTime serverTime
});




}
/// @nodoc
class _$BusyStateCopyWithImpl<$Res>
    implements $BusyStateCopyWith<$Res> {
  _$BusyStateCopyWithImpl(this._self, this._then);

  final BusyState _self;
  final $Res Function(BusyState) _then;

/// Create a copy of BusyState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? busy = null,Object? busyMessage = null,Object? serverTime = null,}) {
  return _then(_self.copyWith(
busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,busyMessage: null == busyMessage ? _self.busyMessage : busyMessage // ignore: cast_nullable_to_non_nullable
as String,serverTime: null == serverTime ? _self.serverTime : serverTime // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [BusyState].
extension BusyStatePatterns on BusyState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BusyState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BusyState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BusyState value)  $default,){
final _that = this;
switch (_that) {
case _BusyState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BusyState value)?  $default,){
final _that = this;
switch (_that) {
case _BusyState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool busy,  String busyMessage,  DateTime serverTime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BusyState() when $default != null:
return $default(_that.busy,_that.busyMessage,_that.serverTime);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool busy,  String busyMessage,  DateTime serverTime)  $default,) {final _that = this;
switch (_that) {
case _BusyState():
return $default(_that.busy,_that.busyMessage,_that.serverTime);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool busy,  String busyMessage,  DateTime serverTime)?  $default,) {final _that = this;
switch (_that) {
case _BusyState() when $default != null:
return $default(_that.busy,_that.busyMessage,_that.serverTime);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BusyState implements BusyState {
  const _BusyState({required this.busy, required this.busyMessage, required this.serverTime});
  factory _BusyState.fromJson(Map<String, dynamic> json) => _$BusyStateFromJson(json);

@override final  bool busy;
@override final  String busyMessage;
@override final  DateTime serverTime;

/// Create a copy of BusyState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BusyStateCopyWith<_BusyState> get copyWith => __$BusyStateCopyWithImpl<_BusyState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BusyStateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BusyState&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.busyMessage, busyMessage) || other.busyMessage == busyMessage)&&(identical(other.serverTime, serverTime) || other.serverTime == serverTime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,busy,busyMessage,serverTime);

@override
String toString() {
  return 'BusyState(busy: $busy, busyMessage: $busyMessage, serverTime: $serverTime)';
}


}

/// @nodoc
abstract mixin class _$BusyStateCopyWith<$Res> implements $BusyStateCopyWith<$Res> {
  factory _$BusyStateCopyWith(_BusyState value, $Res Function(_BusyState) _then) = __$BusyStateCopyWithImpl;
@override @useResult
$Res call({
 bool busy, String busyMessage, DateTime serverTime
});




}
/// @nodoc
class __$BusyStateCopyWithImpl<$Res>
    implements _$BusyStateCopyWith<$Res> {
  __$BusyStateCopyWithImpl(this._self, this._then);

  final _BusyState _self;
  final $Res Function(_BusyState) _then;

/// Create a copy of BusyState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? busy = null,Object? busyMessage = null,Object? serverTime = null,}) {
  return _then(_BusyState(
busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,busyMessage: null == busyMessage ? _self.busyMessage : busyMessage // ignore: cast_nullable_to_non_nullable
as String,serverTime: null == serverTime ? _self.serverTime : serverTime // ignore: cast_nullable_to_non_nullable
as DateTime,
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
