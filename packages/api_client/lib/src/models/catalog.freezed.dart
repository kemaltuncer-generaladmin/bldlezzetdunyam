// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'catalog.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EtaWindow {

/// Aralığın alt sınırı (dakika).
 int get minMinutes;/// Aralığın üst sınırı (dakika).
 int get maxMinutes;/// Tahmin ölçüldü mü, yoksa panelde mi girildi?
@EtaSourceConverter() EtaSource get source;/// Mutfak yoğun. **Aralık sunucuda zaten uzatılmıştır** — istemci ayrıca
/// süre eklemez, yalnızca nedenini söyler.
 bool get busy;
/// Create a copy of EtaWindow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EtaWindowCopyWith<EtaWindow> get copyWith => _$EtaWindowCopyWithImpl<EtaWindow>(this as EtaWindow, _$identity);

  /// Serializes this EtaWindow to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EtaWindow&&(identical(other.minMinutes, minMinutes) || other.minMinutes == minMinutes)&&(identical(other.maxMinutes, maxMinutes) || other.maxMinutes == maxMinutes)&&(identical(other.source, source) || other.source == source)&&(identical(other.busy, busy) || other.busy == busy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,minMinutes,maxMinutes,source,busy);

@override
String toString() {
  return 'EtaWindow(minMinutes: $minMinutes, maxMinutes: $maxMinutes, source: $source, busy: $busy)';
}


}

/// @nodoc
abstract mixin class $EtaWindowCopyWith<$Res>  {
  factory $EtaWindowCopyWith(EtaWindow value, $Res Function(EtaWindow) _then) = _$EtaWindowCopyWithImpl;
@useResult
$Res call({
 int minMinutes, int maxMinutes,@EtaSourceConverter() EtaSource source, bool busy
});




}
/// @nodoc
class _$EtaWindowCopyWithImpl<$Res>
    implements $EtaWindowCopyWith<$Res> {
  _$EtaWindowCopyWithImpl(this._self, this._then);

  final EtaWindow _self;
  final $Res Function(EtaWindow) _then;

/// Create a copy of EtaWindow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? minMinutes = null,Object? maxMinutes = null,Object? source = null,Object? busy = null,}) {
  return _then(_self.copyWith(
minMinutes: null == minMinutes ? _self.minMinutes : minMinutes // ignore: cast_nullable_to_non_nullable
as int,maxMinutes: null == maxMinutes ? _self.maxMinutes : maxMinutes // ignore: cast_nullable_to_non_nullable
as int,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as EtaSource,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [EtaWindow].
extension EtaWindowPatterns on EtaWindow {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EtaWindow value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EtaWindow() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EtaWindow value)  $default,){
final _that = this;
switch (_that) {
case _EtaWindow():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EtaWindow value)?  $default,){
final _that = this;
switch (_that) {
case _EtaWindow() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int minMinutes,  int maxMinutes, @EtaSourceConverter()  EtaSource source,  bool busy)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EtaWindow() when $default != null:
return $default(_that.minMinutes,_that.maxMinutes,_that.source,_that.busy);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int minMinutes,  int maxMinutes, @EtaSourceConverter()  EtaSource source,  bool busy)  $default,) {final _that = this;
switch (_that) {
case _EtaWindow():
return $default(_that.minMinutes,_that.maxMinutes,_that.source,_that.busy);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int minMinutes,  int maxMinutes, @EtaSourceConverter()  EtaSource source,  bool busy)?  $default,) {final _that = this;
switch (_that) {
case _EtaWindow() when $default != null:
return $default(_that.minMinutes,_that.maxMinutes,_that.source,_that.busy);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EtaWindow extends EtaWindow {
  const _EtaWindow({required this.minMinutes, required this.maxMinutes, @EtaSourceConverter() this.source = EtaSource.unknown, this.busy = false}): super._();
  factory _EtaWindow.fromJson(Map<String, dynamic> json) => _$EtaWindowFromJson(json);

/// Aralığın alt sınırı (dakika).
@override final  int minMinutes;
/// Aralığın üst sınırı (dakika).
@override final  int maxMinutes;
/// Tahmin ölçüldü mü, yoksa panelde mi girildi?
@override@JsonKey()@EtaSourceConverter() final  EtaSource source;
/// Mutfak yoğun. **Aralık sunucuda zaten uzatılmıştır** — istemci ayrıca
/// süre eklemez, yalnızca nedenini söyler.
@override@JsonKey() final  bool busy;

/// Create a copy of EtaWindow
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EtaWindowCopyWith<_EtaWindow> get copyWith => __$EtaWindowCopyWithImpl<_EtaWindow>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EtaWindowToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EtaWindow&&(identical(other.minMinutes, minMinutes) || other.minMinutes == minMinutes)&&(identical(other.maxMinutes, maxMinutes) || other.maxMinutes == maxMinutes)&&(identical(other.source, source) || other.source == source)&&(identical(other.busy, busy) || other.busy == busy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,minMinutes,maxMinutes,source,busy);

@override
String toString() {
  return 'EtaWindow(minMinutes: $minMinutes, maxMinutes: $maxMinutes, source: $source, busy: $busy)';
}


}

/// @nodoc
abstract mixin class _$EtaWindowCopyWith<$Res> implements $EtaWindowCopyWith<$Res> {
  factory _$EtaWindowCopyWith(_EtaWindow value, $Res Function(_EtaWindow) _then) = __$EtaWindowCopyWithImpl;
@override @useResult
$Res call({
 int minMinutes, int maxMinutes,@EtaSourceConverter() EtaSource source, bool busy
});




}
/// @nodoc
class __$EtaWindowCopyWithImpl<$Res>
    implements _$EtaWindowCopyWith<$Res> {
  __$EtaWindowCopyWithImpl(this._self, this._then);

  final _EtaWindow _self;
  final $Res Function(_EtaWindow) _then;

/// Create a copy of EtaWindow
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? minMinutes = null,Object? maxMinutes = null,Object? source = null,Object? busy = null,}) {
  return _then(_EtaWindow(
minMinutes: null == minMinutes ? _self.minMinutes : minMinutes // ignore: cast_nullable_to_non_nullable
as int,maxMinutes: null == maxMinutes ? _self.maxMinutes : maxMinutes // ignore: cast_nullable_to_non_nullable
as int,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as EtaSource,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$LocationEta {

 EtaWindow? get delivery; EtaWindow? get pickup;
/// Create a copy of LocationEta
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LocationEtaCopyWith<LocationEta> get copyWith => _$LocationEtaCopyWithImpl<LocationEta>(this as LocationEta, _$identity);

  /// Serializes this LocationEta to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LocationEta&&(identical(other.delivery, delivery) || other.delivery == delivery)&&(identical(other.pickup, pickup) || other.pickup == pickup));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,delivery,pickup);

@override
String toString() {
  return 'LocationEta(delivery: $delivery, pickup: $pickup)';
}


}

/// @nodoc
abstract mixin class $LocationEtaCopyWith<$Res>  {
  factory $LocationEtaCopyWith(LocationEta value, $Res Function(LocationEta) _then) = _$LocationEtaCopyWithImpl;
@useResult
$Res call({
 EtaWindow? delivery, EtaWindow? pickup
});


$EtaWindowCopyWith<$Res>? get delivery;$EtaWindowCopyWith<$Res>? get pickup;

}
/// @nodoc
class _$LocationEtaCopyWithImpl<$Res>
    implements $LocationEtaCopyWith<$Res> {
  _$LocationEtaCopyWithImpl(this._self, this._then);

  final LocationEta _self;
  final $Res Function(LocationEta) _then;

/// Create a copy of LocationEta
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? delivery = freezed,Object? pickup = freezed,}) {
  return _then(_self.copyWith(
delivery: freezed == delivery ? _self.delivery : delivery // ignore: cast_nullable_to_non_nullable
as EtaWindow?,pickup: freezed == pickup ? _self.pickup : pickup // ignore: cast_nullable_to_non_nullable
as EtaWindow?,
  ));
}
/// Create a copy of LocationEta
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$EtaWindowCopyWith<$Res>? get delivery {
    if (_self.delivery == null) {
    return null;
  }

  return $EtaWindowCopyWith<$Res>(_self.delivery!, (value) {
    return _then(_self.copyWith(delivery: value));
  });
}/// Create a copy of LocationEta
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$EtaWindowCopyWith<$Res>? get pickup {
    if (_self.pickup == null) {
    return null;
  }

  return $EtaWindowCopyWith<$Res>(_self.pickup!, (value) {
    return _then(_self.copyWith(pickup: value));
  });
}
}


/// Adds pattern-matching-related methods to [LocationEta].
extension LocationEtaPatterns on LocationEta {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LocationEta value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LocationEta() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LocationEta value)  $default,){
final _that = this;
switch (_that) {
case _LocationEta():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LocationEta value)?  $default,){
final _that = this;
switch (_that) {
case _LocationEta() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( EtaWindow? delivery,  EtaWindow? pickup)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LocationEta() when $default != null:
return $default(_that.delivery,_that.pickup);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( EtaWindow? delivery,  EtaWindow? pickup)  $default,) {final _that = this;
switch (_that) {
case _LocationEta():
return $default(_that.delivery,_that.pickup);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( EtaWindow? delivery,  EtaWindow? pickup)?  $default,) {final _that = this;
switch (_that) {
case _LocationEta() when $default != null:
return $default(_that.delivery,_that.pickup);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LocationEta extends LocationEta {
  const _LocationEta({this.delivery, this.pickup}): super._();
  factory _LocationEta.fromJson(Map<String, dynamic> json) => _$LocationEtaFromJson(json);

@override final  EtaWindow? delivery;
@override final  EtaWindow? pickup;

/// Create a copy of LocationEta
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LocationEtaCopyWith<_LocationEta> get copyWith => __$LocationEtaCopyWithImpl<_LocationEta>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LocationEtaToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LocationEta&&(identical(other.delivery, delivery) || other.delivery == delivery)&&(identical(other.pickup, pickup) || other.pickup == pickup));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,delivery,pickup);

@override
String toString() {
  return 'LocationEta(delivery: $delivery, pickup: $pickup)';
}


}

/// @nodoc
abstract mixin class _$LocationEtaCopyWith<$Res> implements $LocationEtaCopyWith<$Res> {
  factory _$LocationEtaCopyWith(_LocationEta value, $Res Function(_LocationEta) _then) = __$LocationEtaCopyWithImpl;
@override @useResult
$Res call({
 EtaWindow? delivery, EtaWindow? pickup
});


@override $EtaWindowCopyWith<$Res>? get delivery;@override $EtaWindowCopyWith<$Res>? get pickup;

}
/// @nodoc
class __$LocationEtaCopyWithImpl<$Res>
    implements _$LocationEtaCopyWith<$Res> {
  __$LocationEtaCopyWithImpl(this._self, this._then);

  final _LocationEta _self;
  final $Res Function(_LocationEta) _then;

/// Create a copy of LocationEta
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? delivery = freezed,Object? pickup = freezed,}) {
  return _then(_LocationEta(
delivery: freezed == delivery ? _self.delivery : delivery // ignore: cast_nullable_to_non_nullable
as EtaWindow?,pickup: freezed == pickup ? _self.pickup : pickup // ignore: cast_nullable_to_non_nullable
as EtaWindow?,
  ));
}

/// Create a copy of LocationEta
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$EtaWindowCopyWith<$Res>? get delivery {
    if (_self.delivery == null) {
    return null;
  }

  return $EtaWindowCopyWith<$Res>(_self.delivery!, (value) {
    return _then(_self.copyWith(delivery: value));
  });
}/// Create a copy of LocationEta
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$EtaWindowCopyWith<$Res>? get pickup {
    if (_self.pickup == null) {
    return null;
  }

  return $EtaWindowCopyWith<$Res>(_self.pickup!, (value) {
    return _then(_self.copyWith(pickup: value));
  });
}
}


/// @nodoc
mixin _$Location {

 int get id; String get name; String get slug;/// Çalışma saatlerinden türetilir — şu an sipariş saati içinde miyiz?
 bool get isOpen;/// Elle ana şalter — yönetici ya da mutfak çevirir (K-11).
 bool get orderingEnabled;/// Sipariş almanın neden durdurulduğu; müşteriye gösterilir.
///
/// **İsteğe bağlı ve öyle kalmalı:** alan sözleşmeye sonradan eklendi
/// ve eski sunucu/önbellek onu içermez. `null` normal bir durumdur —
/// istemci o zaman genel bir metin gösterir.
 String? get orderingPauseReason;/// Süreli durdurmanın bitişi; süresizse `null`.
 DateTime? get orderingResumesAt;/// Kuruş. Altında sipariş `422 VALIDATION_FAILED`.
 int get minOrderTotal;/// Bu vitrinde **açık** olan ödeme yöntemleri. İstemci yalnızca bunları gösterir.
@PaymentMethodConverter() List<PaymentMethod> get paymentMethods;/// Günlük son sipariş saati (`HH:mm`, Europe/Istanbul) veya `null`.
 String? get orderCutoff;/// Teslim süresi tahminleri.
///
/// **İsteğe bağlıdır ve öyle kalmalıdır.** Alan sözleşmeye sonradan
/// eklendi; eski bir sunucu, mock veya cihazdaki eski önbellek kaydı bu
/// alanı içermez. `null` gelmesi normal bir durumdur, hata değildir —
/// istemci o zaman tahmini hiç göstermez.
 LocationEta? get eta;
/// Create a copy of Location
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LocationCopyWith<Location> get copyWith => _$LocationCopyWithImpl<Location>(this as Location, _$identity);

  /// Serializes this Location to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Location&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.isOpen, isOpen) || other.isOpen == isOpen)&&(identical(other.orderingEnabled, orderingEnabled) || other.orderingEnabled == orderingEnabled)&&(identical(other.orderingPauseReason, orderingPauseReason) || other.orderingPauseReason == orderingPauseReason)&&(identical(other.orderingResumesAt, orderingResumesAt) || other.orderingResumesAt == orderingResumesAt)&&(identical(other.minOrderTotal, minOrderTotal) || other.minOrderTotal == minOrderTotal)&&const DeepCollectionEquality().equals(other.paymentMethods, paymentMethods)&&(identical(other.orderCutoff, orderCutoff) || other.orderCutoff == orderCutoff)&&(identical(other.eta, eta) || other.eta == eta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,slug,isOpen,orderingEnabled,orderingPauseReason,orderingResumesAt,minOrderTotal,const DeepCollectionEquality().hash(paymentMethods),orderCutoff,eta);

@override
String toString() {
  return 'Location(id: $id, name: $name, slug: $slug, isOpen: $isOpen, orderingEnabled: $orderingEnabled, orderingPauseReason: $orderingPauseReason, orderingResumesAt: $orderingResumesAt, minOrderTotal: $minOrderTotal, paymentMethods: $paymentMethods, orderCutoff: $orderCutoff, eta: $eta)';
}


}

/// @nodoc
abstract mixin class $LocationCopyWith<$Res>  {
  factory $LocationCopyWith(Location value, $Res Function(Location) _then) = _$LocationCopyWithImpl;
@useResult
$Res call({
 int id, String name, String slug, bool isOpen, bool orderingEnabled, String? orderingPauseReason, DateTime? orderingResumesAt, int minOrderTotal,@PaymentMethodConverter() List<PaymentMethod> paymentMethods, String? orderCutoff, LocationEta? eta
});


$LocationEtaCopyWith<$Res>? get eta;

}
/// @nodoc
class _$LocationCopyWithImpl<$Res>
    implements $LocationCopyWith<$Res> {
  _$LocationCopyWithImpl(this._self, this._then);

  final Location _self;
  final $Res Function(Location) _then;

/// Create a copy of Location
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? slug = null,Object? isOpen = null,Object? orderingEnabled = null,Object? orderingPauseReason = freezed,Object? orderingResumesAt = freezed,Object? minOrderTotal = null,Object? paymentMethods = null,Object? orderCutoff = freezed,Object? eta = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,isOpen: null == isOpen ? _self.isOpen : isOpen // ignore: cast_nullable_to_non_nullable
as bool,orderingEnabled: null == orderingEnabled ? _self.orderingEnabled : orderingEnabled // ignore: cast_nullable_to_non_nullable
as bool,orderingPauseReason: freezed == orderingPauseReason ? _self.orderingPauseReason : orderingPauseReason // ignore: cast_nullable_to_non_nullable
as String?,orderingResumesAt: freezed == orderingResumesAt ? _self.orderingResumesAt : orderingResumesAt // ignore: cast_nullable_to_non_nullable
as DateTime?,minOrderTotal: null == minOrderTotal ? _self.minOrderTotal : minOrderTotal // ignore: cast_nullable_to_non_nullable
as int,paymentMethods: null == paymentMethods ? _self.paymentMethods : paymentMethods // ignore: cast_nullable_to_non_nullable
as List<PaymentMethod>,orderCutoff: freezed == orderCutoff ? _self.orderCutoff : orderCutoff // ignore: cast_nullable_to_non_nullable
as String?,eta: freezed == eta ? _self.eta : eta // ignore: cast_nullable_to_non_nullable
as LocationEta?,
  ));
}
/// Create a copy of Location
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LocationEtaCopyWith<$Res>? get eta {
    if (_self.eta == null) {
    return null;
  }

  return $LocationEtaCopyWith<$Res>(_self.eta!, (value) {
    return _then(_self.copyWith(eta: value));
  });
}
}


/// Adds pattern-matching-related methods to [Location].
extension LocationPatterns on Location {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Location value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Location() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Location value)  $default,){
final _that = this;
switch (_that) {
case _Location():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Location value)?  $default,){
final _that = this;
switch (_that) {
case _Location() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name,  String slug,  bool isOpen,  bool orderingEnabled,  String? orderingPauseReason,  DateTime? orderingResumesAt,  int minOrderTotal, @PaymentMethodConverter()  List<PaymentMethod> paymentMethods,  String? orderCutoff,  LocationEta? eta)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Location() when $default != null:
return $default(_that.id,_that.name,_that.slug,_that.isOpen,_that.orderingEnabled,_that.orderingPauseReason,_that.orderingResumesAt,_that.minOrderTotal,_that.paymentMethods,_that.orderCutoff,_that.eta);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name,  String slug,  bool isOpen,  bool orderingEnabled,  String? orderingPauseReason,  DateTime? orderingResumesAt,  int minOrderTotal, @PaymentMethodConverter()  List<PaymentMethod> paymentMethods,  String? orderCutoff,  LocationEta? eta)  $default,) {final _that = this;
switch (_that) {
case _Location():
return $default(_that.id,_that.name,_that.slug,_that.isOpen,_that.orderingEnabled,_that.orderingPauseReason,_that.orderingResumesAt,_that.minOrderTotal,_that.paymentMethods,_that.orderCutoff,_that.eta);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name,  String slug,  bool isOpen,  bool orderingEnabled,  String? orderingPauseReason,  DateTime? orderingResumesAt,  int minOrderTotal, @PaymentMethodConverter()  List<PaymentMethod> paymentMethods,  String? orderCutoff,  LocationEta? eta)?  $default,) {final _that = this;
switch (_that) {
case _Location() when $default != null:
return $default(_that.id,_that.name,_that.slug,_that.isOpen,_that.orderingEnabled,_that.orderingPauseReason,_that.orderingResumesAt,_that.minOrderTotal,_that.paymentMethods,_that.orderCutoff,_that.eta);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Location extends Location {
  const _Location({required this.id, required this.name, required this.slug, required this.isOpen, required this.orderingEnabled, this.orderingPauseReason, this.orderingResumesAt, required this.minOrderTotal, @PaymentMethodConverter() required final  List<PaymentMethod> paymentMethods, this.orderCutoff, this.eta}): _paymentMethods = paymentMethods,super._();
  factory _Location.fromJson(Map<String, dynamic> json) => _$LocationFromJson(json);

@override final  int id;
@override final  String name;
@override final  String slug;
/// Çalışma saatlerinden türetilir — şu an sipariş saati içinde miyiz?
@override final  bool isOpen;
/// Elle ana şalter — yönetici ya da mutfak çevirir (K-11).
@override final  bool orderingEnabled;
/// Sipariş almanın neden durdurulduğu; müşteriye gösterilir.
///
/// **İsteğe bağlı ve öyle kalmalı:** alan sözleşmeye sonradan eklendi
/// ve eski sunucu/önbellek onu içermez. `null` normal bir durumdur —
/// istemci o zaman genel bir metin gösterir.
@override final  String? orderingPauseReason;
/// Süreli durdurmanın bitişi; süresizse `null`.
@override final  DateTime? orderingResumesAt;
/// Kuruş. Altında sipariş `422 VALIDATION_FAILED`.
@override final  int minOrderTotal;
/// Bu vitrinde **açık** olan ödeme yöntemleri. İstemci yalnızca bunları gösterir.
 final  List<PaymentMethod> _paymentMethods;
/// Bu vitrinde **açık** olan ödeme yöntemleri. İstemci yalnızca bunları gösterir.
@override@PaymentMethodConverter() List<PaymentMethod> get paymentMethods {
  if (_paymentMethods is EqualUnmodifiableListView) return _paymentMethods;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_paymentMethods);
}

/// Günlük son sipariş saati (`HH:mm`, Europe/Istanbul) veya `null`.
@override final  String? orderCutoff;
/// Teslim süresi tahminleri.
///
/// **İsteğe bağlıdır ve öyle kalmalıdır.** Alan sözleşmeye sonradan
/// eklendi; eski bir sunucu, mock veya cihazdaki eski önbellek kaydı bu
/// alanı içermez. `null` gelmesi normal bir durumdur, hata değildir —
/// istemci o zaman tahmini hiç göstermez.
@override final  LocationEta? eta;

/// Create a copy of Location
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LocationCopyWith<_Location> get copyWith => __$LocationCopyWithImpl<_Location>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LocationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Location&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.isOpen, isOpen) || other.isOpen == isOpen)&&(identical(other.orderingEnabled, orderingEnabled) || other.orderingEnabled == orderingEnabled)&&(identical(other.orderingPauseReason, orderingPauseReason) || other.orderingPauseReason == orderingPauseReason)&&(identical(other.orderingResumesAt, orderingResumesAt) || other.orderingResumesAt == orderingResumesAt)&&(identical(other.minOrderTotal, minOrderTotal) || other.minOrderTotal == minOrderTotal)&&const DeepCollectionEquality().equals(other._paymentMethods, _paymentMethods)&&(identical(other.orderCutoff, orderCutoff) || other.orderCutoff == orderCutoff)&&(identical(other.eta, eta) || other.eta == eta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,slug,isOpen,orderingEnabled,orderingPauseReason,orderingResumesAt,minOrderTotal,const DeepCollectionEquality().hash(_paymentMethods),orderCutoff,eta);

@override
String toString() {
  return 'Location(id: $id, name: $name, slug: $slug, isOpen: $isOpen, orderingEnabled: $orderingEnabled, orderingPauseReason: $orderingPauseReason, orderingResumesAt: $orderingResumesAt, minOrderTotal: $minOrderTotal, paymentMethods: $paymentMethods, orderCutoff: $orderCutoff, eta: $eta)';
}


}

/// @nodoc
abstract mixin class _$LocationCopyWith<$Res> implements $LocationCopyWith<$Res> {
  factory _$LocationCopyWith(_Location value, $Res Function(_Location) _then) = __$LocationCopyWithImpl;
@override @useResult
$Res call({
 int id, String name, String slug, bool isOpen, bool orderingEnabled, String? orderingPauseReason, DateTime? orderingResumesAt, int minOrderTotal,@PaymentMethodConverter() List<PaymentMethod> paymentMethods, String? orderCutoff, LocationEta? eta
});


@override $LocationEtaCopyWith<$Res>? get eta;

}
/// @nodoc
class __$LocationCopyWithImpl<$Res>
    implements _$LocationCopyWith<$Res> {
  __$LocationCopyWithImpl(this._self, this._then);

  final _Location _self;
  final $Res Function(_Location) _then;

/// Create a copy of Location
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? slug = null,Object? isOpen = null,Object? orderingEnabled = null,Object? orderingPauseReason = freezed,Object? orderingResumesAt = freezed,Object? minOrderTotal = null,Object? paymentMethods = null,Object? orderCutoff = freezed,Object? eta = freezed,}) {
  return _then(_Location(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,isOpen: null == isOpen ? _self.isOpen : isOpen // ignore: cast_nullable_to_non_nullable
as bool,orderingEnabled: null == orderingEnabled ? _self.orderingEnabled : orderingEnabled // ignore: cast_nullable_to_non_nullable
as bool,orderingPauseReason: freezed == orderingPauseReason ? _self.orderingPauseReason : orderingPauseReason // ignore: cast_nullable_to_non_nullable
as String?,orderingResumesAt: freezed == orderingResumesAt ? _self.orderingResumesAt : orderingResumesAt // ignore: cast_nullable_to_non_nullable
as DateTime?,minOrderTotal: null == minOrderTotal ? _self.minOrderTotal : minOrderTotal // ignore: cast_nullable_to_non_nullable
as int,paymentMethods: null == paymentMethods ? _self._paymentMethods : paymentMethods // ignore: cast_nullable_to_non_nullable
as List<PaymentMethod>,orderCutoff: freezed == orderCutoff ? _self.orderCutoff : orderCutoff // ignore: cast_nullable_to_non_nullable
as String?,eta: freezed == eta ? _self.eta : eta // ignore: cast_nullable_to_non_nullable
as LocationEta?,
  ));
}

/// Create a copy of Location
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LocationEtaCopyWith<$Res>? get eta {
    if (_self.eta == null) {
    return null;
  }

  return $LocationEtaCopyWith<$Res>(_self.eta!, (value) {
    return _then(_self.copyWith(eta: value));
  });
}
}


/// @nodoc
mixin _$MenuCategory {

 int get id; String get name; int get sort; List<MenuItem> get items;
/// Create a copy of MenuCategory
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MenuCategoryCopyWith<MenuCategory> get copyWith => _$MenuCategoryCopyWithImpl<MenuCategory>(this as MenuCategory, _$identity);

  /// Serializes this MenuCategory to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MenuCategory&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.sort, sort) || other.sort == sort)&&const DeepCollectionEquality().equals(other.items, items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,sort,const DeepCollectionEquality().hash(items));

@override
String toString() {
  return 'MenuCategory(id: $id, name: $name, sort: $sort, items: $items)';
}


}

/// @nodoc
abstract mixin class $MenuCategoryCopyWith<$Res>  {
  factory $MenuCategoryCopyWith(MenuCategory value, $Res Function(MenuCategory) _then) = _$MenuCategoryCopyWithImpl;
@useResult
$Res call({
 int id, String name, int sort, List<MenuItem> items
});




}
/// @nodoc
class _$MenuCategoryCopyWithImpl<$Res>
    implements $MenuCategoryCopyWith<$Res> {
  _$MenuCategoryCopyWithImpl(this._self, this._then);

  final MenuCategory _self;
  final $Res Function(MenuCategory) _then;

/// Create a copy of MenuCategory
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? sort = null,Object? items = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sort: null == sort ? _self.sort : sort // ignore: cast_nullable_to_non_nullable
as int,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<MenuItem>,
  ));
}

}


/// Adds pattern-matching-related methods to [MenuCategory].
extension MenuCategoryPatterns on MenuCategory {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MenuCategory value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MenuCategory() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MenuCategory value)  $default,){
final _that = this;
switch (_that) {
case _MenuCategory():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MenuCategory value)?  $default,){
final _that = this;
switch (_that) {
case _MenuCategory() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name,  int sort,  List<MenuItem> items)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MenuCategory() when $default != null:
return $default(_that.id,_that.name,_that.sort,_that.items);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name,  int sort,  List<MenuItem> items)  $default,) {final _that = this;
switch (_that) {
case _MenuCategory():
return $default(_that.id,_that.name,_that.sort,_that.items);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name,  int sort,  List<MenuItem> items)?  $default,) {final _that = this;
switch (_that) {
case _MenuCategory() when $default != null:
return $default(_that.id,_that.name,_that.sort,_that.items);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MenuCategory implements MenuCategory {
  const _MenuCategory({required this.id, required this.name, required this.sort, required final  List<MenuItem> items}): _items = items;
  factory _MenuCategory.fromJson(Map<String, dynamic> json) => _$MenuCategoryFromJson(json);

@override final  int id;
@override final  String name;
@override final  int sort;
 final  List<MenuItem> _items;
@override List<MenuItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


/// Create a copy of MenuCategory
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MenuCategoryCopyWith<_MenuCategory> get copyWith => __$MenuCategoryCopyWithImpl<_MenuCategory>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MenuCategoryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MenuCategory&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.sort, sort) || other.sort == sort)&&const DeepCollectionEquality().equals(other._items, _items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,sort,const DeepCollectionEquality().hash(_items));

@override
String toString() {
  return 'MenuCategory(id: $id, name: $name, sort: $sort, items: $items)';
}


}

/// @nodoc
abstract mixin class _$MenuCategoryCopyWith<$Res> implements $MenuCategoryCopyWith<$Res> {
  factory _$MenuCategoryCopyWith(_MenuCategory value, $Res Function(_MenuCategory) _then) = __$MenuCategoryCopyWithImpl;
@override @useResult
$Res call({
 int id, String name, int sort, List<MenuItem> items
});




}
/// @nodoc
class __$MenuCategoryCopyWithImpl<$Res>
    implements _$MenuCategoryCopyWith<$Res> {
  __$MenuCategoryCopyWithImpl(this._self, this._then);

  final _MenuCategory _self;
  final $Res Function(_MenuCategory) _then;

/// Create a copy of MenuCategory
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? sort = null,Object? items = null,}) {
  return _then(_MenuCategory(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sort: null == sort ? _self.sort : sort // ignore: cast_nullable_to_non_nullable
as int,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<MenuItem>,
  ));
}


}


/// @nodoc
mixin _$MenuItem {

 int get id; String get name;/// Kuruş.
 int get price; String get currency;/// `false` ürün listede **kalır**; soluk gösterilir, sepete eklenemez.
///
/// İki sebepten biriyle `false` olur: yöneticinin kalıcı kararı ya da
/// mutfağın günlük [soldOutToday] işareti (K-11).
 bool get isAvailable;/// Mutfak bugünlük tükendi işaretledi mi?
///
/// Varsayılanı `false`: alan sözleşmeye sonradan eklendi ve eski
/// sunucu/önbellek onu içermiyor.
 bool get soldOutToday;/// `soldOutToday` doğruyken mutfağın yazdığı sebep.
 String? get soldOutReason; String? get description; String? get imageUrl; List<String> get allergens; List<MenuOption> get options;
/// Create a copy of MenuItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MenuItemCopyWith<MenuItem> get copyWith => _$MenuItemCopyWithImpl<MenuItem>(this as MenuItem, _$identity);

  /// Serializes this MenuItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MenuItem&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.price, price) || other.price == price)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.isAvailable, isAvailable) || other.isAvailable == isAvailable)&&(identical(other.soldOutToday, soldOutToday) || other.soldOutToday == soldOutToday)&&(identical(other.soldOutReason, soldOutReason) || other.soldOutReason == soldOutReason)&&(identical(other.description, description) || other.description == description)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&const DeepCollectionEquality().equals(other.allergens, allergens)&&const DeepCollectionEquality().equals(other.options, options));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,price,currency,isAvailable,soldOutToday,soldOutReason,description,imageUrl,const DeepCollectionEquality().hash(allergens),const DeepCollectionEquality().hash(options));

@override
String toString() {
  return 'MenuItem(id: $id, name: $name, price: $price, currency: $currency, isAvailable: $isAvailable, soldOutToday: $soldOutToday, soldOutReason: $soldOutReason, description: $description, imageUrl: $imageUrl, allergens: $allergens, options: $options)';
}


}

/// @nodoc
abstract mixin class $MenuItemCopyWith<$Res>  {
  factory $MenuItemCopyWith(MenuItem value, $Res Function(MenuItem) _then) = _$MenuItemCopyWithImpl;
@useResult
$Res call({
 int id, String name, int price, String currency, bool isAvailable, bool soldOutToday, String? soldOutReason, String? description, String? imageUrl, List<String> allergens, List<MenuOption> options
});




}
/// @nodoc
class _$MenuItemCopyWithImpl<$Res>
    implements $MenuItemCopyWith<$Res> {
  _$MenuItemCopyWithImpl(this._self, this._then);

  final MenuItem _self;
  final $Res Function(MenuItem) _then;

/// Create a copy of MenuItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? price = null,Object? currency = null,Object? isAvailable = null,Object? soldOutToday = null,Object? soldOutReason = freezed,Object? description = freezed,Object? imageUrl = freezed,Object? allergens = null,Object? options = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as int,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,isAvailable: null == isAvailable ? _self.isAvailable : isAvailable // ignore: cast_nullable_to_non_nullable
as bool,soldOutToday: null == soldOutToday ? _self.soldOutToday : soldOutToday // ignore: cast_nullable_to_non_nullable
as bool,soldOutReason: freezed == soldOutReason ? _self.soldOutReason : soldOutReason // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,allergens: null == allergens ? _self.allergens : allergens // ignore: cast_nullable_to_non_nullable
as List<String>,options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as List<MenuOption>,
  ));
}

}


/// Adds pattern-matching-related methods to [MenuItem].
extension MenuItemPatterns on MenuItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MenuItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MenuItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MenuItem value)  $default,){
final _that = this;
switch (_that) {
case _MenuItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MenuItem value)?  $default,){
final _that = this;
switch (_that) {
case _MenuItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name,  int price,  String currency,  bool isAvailable,  bool soldOutToday,  String? soldOutReason,  String? description,  String? imageUrl,  List<String> allergens,  List<MenuOption> options)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MenuItem() when $default != null:
return $default(_that.id,_that.name,_that.price,_that.currency,_that.isAvailable,_that.soldOutToday,_that.soldOutReason,_that.description,_that.imageUrl,_that.allergens,_that.options);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name,  int price,  String currency,  bool isAvailable,  bool soldOutToday,  String? soldOutReason,  String? description,  String? imageUrl,  List<String> allergens,  List<MenuOption> options)  $default,) {final _that = this;
switch (_that) {
case _MenuItem():
return $default(_that.id,_that.name,_that.price,_that.currency,_that.isAvailable,_that.soldOutToday,_that.soldOutReason,_that.description,_that.imageUrl,_that.allergens,_that.options);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name,  int price,  String currency,  bool isAvailable,  bool soldOutToday,  String? soldOutReason,  String? description,  String? imageUrl,  List<String> allergens,  List<MenuOption> options)?  $default,) {final _that = this;
switch (_that) {
case _MenuItem() when $default != null:
return $default(_that.id,_that.name,_that.price,_that.currency,_that.isAvailable,_that.soldOutToday,_that.soldOutReason,_that.description,_that.imageUrl,_that.allergens,_that.options);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MenuItem extends MenuItem {
  const _MenuItem({required this.id, required this.name, required this.price, required this.currency, required this.isAvailable, this.soldOutToday = false, this.soldOutReason, this.description, this.imageUrl, final  List<String> allergens = const <String>[], final  List<MenuOption> options = const <MenuOption>[]}): _allergens = allergens,_options = options,super._();
  factory _MenuItem.fromJson(Map<String, dynamic> json) => _$MenuItemFromJson(json);

@override final  int id;
@override final  String name;
/// Kuruş.
@override final  int price;
@override final  String currency;
/// `false` ürün listede **kalır**; soluk gösterilir, sepete eklenemez.
///
/// İki sebepten biriyle `false` olur: yöneticinin kalıcı kararı ya da
/// mutfağın günlük [soldOutToday] işareti (K-11).
@override final  bool isAvailable;
/// Mutfak bugünlük tükendi işaretledi mi?
///
/// Varsayılanı `false`: alan sözleşmeye sonradan eklendi ve eski
/// sunucu/önbellek onu içermiyor.
@override@JsonKey() final  bool soldOutToday;
/// `soldOutToday` doğruyken mutfağın yazdığı sebep.
@override final  String? soldOutReason;
@override final  String? description;
@override final  String? imageUrl;
 final  List<String> _allergens;
@override@JsonKey() List<String> get allergens {
  if (_allergens is EqualUnmodifiableListView) return _allergens;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_allergens);
}

 final  List<MenuOption> _options;
@override@JsonKey() List<MenuOption> get options {
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_options);
}


/// Create a copy of MenuItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MenuItemCopyWith<_MenuItem> get copyWith => __$MenuItemCopyWithImpl<_MenuItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MenuItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MenuItem&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.price, price) || other.price == price)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.isAvailable, isAvailable) || other.isAvailable == isAvailable)&&(identical(other.soldOutToday, soldOutToday) || other.soldOutToday == soldOutToday)&&(identical(other.soldOutReason, soldOutReason) || other.soldOutReason == soldOutReason)&&(identical(other.description, description) || other.description == description)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&const DeepCollectionEquality().equals(other._allergens, _allergens)&&const DeepCollectionEquality().equals(other._options, _options));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,price,currency,isAvailable,soldOutToday,soldOutReason,description,imageUrl,const DeepCollectionEquality().hash(_allergens),const DeepCollectionEquality().hash(_options));

@override
String toString() {
  return 'MenuItem(id: $id, name: $name, price: $price, currency: $currency, isAvailable: $isAvailable, soldOutToday: $soldOutToday, soldOutReason: $soldOutReason, description: $description, imageUrl: $imageUrl, allergens: $allergens, options: $options)';
}


}

/// @nodoc
abstract mixin class _$MenuItemCopyWith<$Res> implements $MenuItemCopyWith<$Res> {
  factory _$MenuItemCopyWith(_MenuItem value, $Res Function(_MenuItem) _then) = __$MenuItemCopyWithImpl;
@override @useResult
$Res call({
 int id, String name, int price, String currency, bool isAvailable, bool soldOutToday, String? soldOutReason, String? description, String? imageUrl, List<String> allergens, List<MenuOption> options
});




}
/// @nodoc
class __$MenuItemCopyWithImpl<$Res>
    implements _$MenuItemCopyWith<$Res> {
  __$MenuItemCopyWithImpl(this._self, this._then);

  final _MenuItem _self;
  final $Res Function(_MenuItem) _then;

/// Create a copy of MenuItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? price = null,Object? currency = null,Object? isAvailable = null,Object? soldOutToday = null,Object? soldOutReason = freezed,Object? description = freezed,Object? imageUrl = freezed,Object? allergens = null,Object? options = null,}) {
  return _then(_MenuItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as int,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,isAvailable: null == isAvailable ? _self.isAvailable : isAvailable // ignore: cast_nullable_to_non_nullable
as bool,soldOutToday: null == soldOutToday ? _self.soldOutToday : soldOutToday // ignore: cast_nullable_to_non_nullable
as bool,soldOutReason: freezed == soldOutReason ? _self.soldOutReason : soldOutReason // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,allergens: null == allergens ? _self._allergens : allergens // ignore: cast_nullable_to_non_nullable
as List<String>,options: null == options ? _self._options : options // ignore: cast_nullable_to_non_nullable
as List<MenuOption>,
  ));
}


}


/// @nodoc
mixin _$MenuOption {

 int get id; String get name;/// Bilinen değerler: `radio`, `checkbox`, `select`. Kapalı enum değildir —
/// TastyIgniter'ın gerçek kümesi `B-02`'de doğrulanacak (BILINMEYENLER).
 String get type; bool get required; List<MenuOptionValue> get values;
/// Create a copy of MenuOption
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MenuOptionCopyWith<MenuOption> get copyWith => _$MenuOptionCopyWithImpl<MenuOption>(this as MenuOption, _$identity);

  /// Serializes this MenuOption to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MenuOption&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.required, required) || other.required == required)&&const DeepCollectionEquality().equals(other.values, values));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,type,required,const DeepCollectionEquality().hash(values));

@override
String toString() {
  return 'MenuOption(id: $id, name: $name, type: $type, required: $required, values: $values)';
}


}

/// @nodoc
abstract mixin class $MenuOptionCopyWith<$Res>  {
  factory $MenuOptionCopyWith(MenuOption value, $Res Function(MenuOption) _then) = _$MenuOptionCopyWithImpl;
@useResult
$Res call({
 int id, String name, String type, bool required, List<MenuOptionValue> values
});




}
/// @nodoc
class _$MenuOptionCopyWithImpl<$Res>
    implements $MenuOptionCopyWith<$Res> {
  _$MenuOptionCopyWithImpl(this._self, this._then);

  final MenuOption _self;
  final $Res Function(MenuOption) _then;

/// Create a copy of MenuOption
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? type = null,Object? required = null,Object? values = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,required: null == required ? _self.required : required // ignore: cast_nullable_to_non_nullable
as bool,values: null == values ? _self.values : values // ignore: cast_nullable_to_non_nullable
as List<MenuOptionValue>,
  ));
}

}


/// Adds pattern-matching-related methods to [MenuOption].
extension MenuOptionPatterns on MenuOption {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MenuOption value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MenuOption() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MenuOption value)  $default,){
final _that = this;
switch (_that) {
case _MenuOption():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MenuOption value)?  $default,){
final _that = this;
switch (_that) {
case _MenuOption() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name,  String type,  bool required,  List<MenuOptionValue> values)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MenuOption() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.required,_that.values);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name,  String type,  bool required,  List<MenuOptionValue> values)  $default,) {final _that = this;
switch (_that) {
case _MenuOption():
return $default(_that.id,_that.name,_that.type,_that.required,_that.values);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name,  String type,  bool required,  List<MenuOptionValue> values)?  $default,) {final _that = this;
switch (_that) {
case _MenuOption() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.required,_that.values);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MenuOption extends MenuOption {
  const _MenuOption({required this.id, required this.name, required this.type, required this.required, required final  List<MenuOptionValue> values}): _values = values,super._();
  factory _MenuOption.fromJson(Map<String, dynamic> json) => _$MenuOptionFromJson(json);

@override final  int id;
@override final  String name;
/// Bilinen değerler: `radio`, `checkbox`, `select`. Kapalı enum değildir —
/// TastyIgniter'ın gerçek kümesi `B-02`'de doğrulanacak (BILINMEYENLER).
@override final  String type;
@override final  bool required;
 final  List<MenuOptionValue> _values;
@override List<MenuOptionValue> get values {
  if (_values is EqualUnmodifiableListView) return _values;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_values);
}


/// Create a copy of MenuOption
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MenuOptionCopyWith<_MenuOption> get copyWith => __$MenuOptionCopyWithImpl<_MenuOption>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MenuOptionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MenuOption&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.required, required) || other.required == required)&&const DeepCollectionEquality().equals(other._values, _values));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,type,required,const DeepCollectionEquality().hash(_values));

@override
String toString() {
  return 'MenuOption(id: $id, name: $name, type: $type, required: $required, values: $values)';
}


}

/// @nodoc
abstract mixin class _$MenuOptionCopyWith<$Res> implements $MenuOptionCopyWith<$Res> {
  factory _$MenuOptionCopyWith(_MenuOption value, $Res Function(_MenuOption) _then) = __$MenuOptionCopyWithImpl;
@override @useResult
$Res call({
 int id, String name, String type, bool required, List<MenuOptionValue> values
});




}
/// @nodoc
class __$MenuOptionCopyWithImpl<$Res>
    implements _$MenuOptionCopyWith<$Res> {
  __$MenuOptionCopyWithImpl(this._self, this._then);

  final _MenuOption _self;
  final $Res Function(_MenuOption) _then;

/// Create a copy of MenuOption
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? type = null,Object? required = null,Object? values = null,}) {
  return _then(_MenuOption(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,required: null == required ? _self.required : required // ignore: cast_nullable_to_non_nullable
as bool,values: null == values ? _self._values : values // ignore: cast_nullable_to_non_nullable
as List<MenuOptionValue>,
  ));
}


}


/// @nodoc
mixin _$MenuOptionValue {

 int get id; String get name;/// Kuruş cinsinden **işaretli** fark; negatif olabilir.
 int get priceDelta;
/// Create a copy of MenuOptionValue
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MenuOptionValueCopyWith<MenuOptionValue> get copyWith => _$MenuOptionValueCopyWithImpl<MenuOptionValue>(this as MenuOptionValue, _$identity);

  /// Serializes this MenuOptionValue to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MenuOptionValue&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.priceDelta, priceDelta) || other.priceDelta == priceDelta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,priceDelta);

@override
String toString() {
  return 'MenuOptionValue(id: $id, name: $name, priceDelta: $priceDelta)';
}


}

/// @nodoc
abstract mixin class $MenuOptionValueCopyWith<$Res>  {
  factory $MenuOptionValueCopyWith(MenuOptionValue value, $Res Function(MenuOptionValue) _then) = _$MenuOptionValueCopyWithImpl;
@useResult
$Res call({
 int id, String name, int priceDelta
});




}
/// @nodoc
class _$MenuOptionValueCopyWithImpl<$Res>
    implements $MenuOptionValueCopyWith<$Res> {
  _$MenuOptionValueCopyWithImpl(this._self, this._then);

  final MenuOptionValue _self;
  final $Res Function(MenuOptionValue) _then;

/// Create a copy of MenuOptionValue
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? priceDelta = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,priceDelta: null == priceDelta ? _self.priceDelta : priceDelta // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [MenuOptionValue].
extension MenuOptionValuePatterns on MenuOptionValue {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MenuOptionValue value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MenuOptionValue() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MenuOptionValue value)  $default,){
final _that = this;
switch (_that) {
case _MenuOptionValue():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MenuOptionValue value)?  $default,){
final _that = this;
switch (_that) {
case _MenuOptionValue() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name,  int priceDelta)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MenuOptionValue() when $default != null:
return $default(_that.id,_that.name,_that.priceDelta);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name,  int priceDelta)  $default,) {final _that = this;
switch (_that) {
case _MenuOptionValue():
return $default(_that.id,_that.name,_that.priceDelta);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name,  int priceDelta)?  $default,) {final _that = this;
switch (_that) {
case _MenuOptionValue() when $default != null:
return $default(_that.id,_that.name,_that.priceDelta);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MenuOptionValue implements MenuOptionValue {
  const _MenuOptionValue({required this.id, required this.name, required this.priceDelta});
  factory _MenuOptionValue.fromJson(Map<String, dynamic> json) => _$MenuOptionValueFromJson(json);

@override final  int id;
@override final  String name;
/// Kuruş cinsinden **işaretli** fark; negatif olabilir.
@override final  int priceDelta;

/// Create a copy of MenuOptionValue
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MenuOptionValueCopyWith<_MenuOptionValue> get copyWith => __$MenuOptionValueCopyWithImpl<_MenuOptionValue>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MenuOptionValueToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MenuOptionValue&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.priceDelta, priceDelta) || other.priceDelta == priceDelta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,priceDelta);

@override
String toString() {
  return 'MenuOptionValue(id: $id, name: $name, priceDelta: $priceDelta)';
}


}

/// @nodoc
abstract mixin class _$MenuOptionValueCopyWith<$Res> implements $MenuOptionValueCopyWith<$Res> {
  factory _$MenuOptionValueCopyWith(_MenuOptionValue value, $Res Function(_MenuOptionValue) _then) = __$MenuOptionValueCopyWithImpl;
@override @useResult
$Res call({
 int id, String name, int priceDelta
});




}
/// @nodoc
class __$MenuOptionValueCopyWithImpl<$Res>
    implements _$MenuOptionValueCopyWith<$Res> {
  __$MenuOptionValueCopyWithImpl(this._self, this._then);

  final _MenuOptionValue _self;
  final $Res Function(_MenuOptionValue) _then;

/// Create a copy of MenuOptionValue
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? priceDelta = null,}) {
  return _then(_MenuOptionValue(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,priceDelta: null == priceDelta ? _self.priceDelta : priceDelta // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
