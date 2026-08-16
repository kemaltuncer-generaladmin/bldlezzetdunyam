// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'client_error.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ClientErrorReport {

/// Hatanın tek satırlık özeti. Sunucu 500 karakteri aşan metni **keser**,
/// isteği reddetmez.
 String get message;/// Hatanın türü — bilinen değerler [ClientErrorKind] içinde.
 String? get kind;/// Yığın izi. Sunucu 8000 karakteri aşan kısmı keser.
 String? get stack;/// Hatanın oluştuğu ekran/rota (`/siparislerim/1234`).
///
/// **Sorgu dizesi olmadan** gönderilmelidir: adres çubuğundaki
/// parametreler zaman zaman kişisel veri taşır ve hata kaydı onları
/// saklamak için yanlış yerdir.
 String? get route;/// Hatanın istemcide oluştuğu an. Sunucu kendi alış anını ayrıca yazar;
/// ikisi arasındaki fark, çevrimdışıyken biriktirilip sonra gönderilen
/// raporları ayırt eder.
 DateTime? get occurredAt;/// Sürüm numarasının altındaki yapı kimliği (build number, commit
/// kısaltması). `X-App-Version` semver'i aynı kalırken yeniden yayınlanan
/// bir yapıyı ayırmanın tek yolu budur.
 String? get appBuild;/// Cihaz/işletim sistemi/tarayıcı özeti. Serbest metin: üç uygulamanın üç
/// farklı kaynağı var ve tek bir yapıya sıkıştırmak hiçbirine uymuyordu.
 String? get device;/// Ek bağlam (ekrandaki kayıt kimliği, deneme sayısı gibi).
///
/// **KİŞİSEL VERİ VE SIR KONMAZ** — token, parola, kart bilgisi ya da tam
/// adres gönderen istemci hata raporunu bir sızıntı kanalına çevirir.
 Map<String, dynamic>? get context;
/// Create a copy of ClientErrorReport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClientErrorReportCopyWith<ClientErrorReport> get copyWith => _$ClientErrorReportCopyWithImpl<ClientErrorReport>(this as ClientErrorReport, _$identity);

  /// Serializes this ClientErrorReport to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClientErrorReport&&(identical(other.message, message) || other.message == message)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.stack, stack) || other.stack == stack)&&(identical(other.route, route) || other.route == route)&&(identical(other.occurredAt, occurredAt) || other.occurredAt == occurredAt)&&(identical(other.appBuild, appBuild) || other.appBuild == appBuild)&&(identical(other.device, device) || other.device == device)&&const DeepCollectionEquality().equals(other.context, context));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,message,kind,stack,route,occurredAt,appBuild,device,const DeepCollectionEquality().hash(context));

@override
String toString() {
  return 'ClientErrorReport(message: $message, kind: $kind, stack: $stack, route: $route, occurredAt: $occurredAt, appBuild: $appBuild, device: $device, context: $context)';
}


}

/// @nodoc
abstract mixin class $ClientErrorReportCopyWith<$Res>  {
  factory $ClientErrorReportCopyWith(ClientErrorReport value, $Res Function(ClientErrorReport) _then) = _$ClientErrorReportCopyWithImpl;
@useResult
$Res call({
 String message, String? kind, String? stack, String? route, DateTime? occurredAt, String? appBuild, String? device, Map<String, dynamic>? context
});




}
/// @nodoc
class _$ClientErrorReportCopyWithImpl<$Res>
    implements $ClientErrorReportCopyWith<$Res> {
  _$ClientErrorReportCopyWithImpl(this._self, this._then);

  final ClientErrorReport _self;
  final $Res Function(ClientErrorReport) _then;

/// Create a copy of ClientErrorReport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? message = null,Object? kind = freezed,Object? stack = freezed,Object? route = freezed,Object? occurredAt = freezed,Object? appBuild = freezed,Object? device = freezed,Object? context = freezed,}) {
  return _then(_self.copyWith(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String?,stack: freezed == stack ? _self.stack : stack // ignore: cast_nullable_to_non_nullable
as String?,route: freezed == route ? _self.route : route // ignore: cast_nullable_to_non_nullable
as String?,occurredAt: freezed == occurredAt ? _self.occurredAt : occurredAt // ignore: cast_nullable_to_non_nullable
as DateTime?,appBuild: freezed == appBuild ? _self.appBuild : appBuild // ignore: cast_nullable_to_non_nullable
as String?,device: freezed == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as String?,context: freezed == context ? _self.context : context // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}

}


/// Adds pattern-matching-related methods to [ClientErrorReport].
extension ClientErrorReportPatterns on ClientErrorReport {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClientErrorReport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClientErrorReport() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClientErrorReport value)  $default,){
final _that = this;
switch (_that) {
case _ClientErrorReport():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClientErrorReport value)?  $default,){
final _that = this;
switch (_that) {
case _ClientErrorReport() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String message,  String? kind,  String? stack,  String? route,  DateTime? occurredAt,  String? appBuild,  String? device,  Map<String, dynamic>? context)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClientErrorReport() when $default != null:
return $default(_that.message,_that.kind,_that.stack,_that.route,_that.occurredAt,_that.appBuild,_that.device,_that.context);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String message,  String? kind,  String? stack,  String? route,  DateTime? occurredAt,  String? appBuild,  String? device,  Map<String, dynamic>? context)  $default,) {final _that = this;
switch (_that) {
case _ClientErrorReport():
return $default(_that.message,_that.kind,_that.stack,_that.route,_that.occurredAt,_that.appBuild,_that.device,_that.context);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String message,  String? kind,  String? stack,  String? route,  DateTime? occurredAt,  String? appBuild,  String? device,  Map<String, dynamic>? context)?  $default,) {final _that = this;
switch (_that) {
case _ClientErrorReport() when $default != null:
return $default(_that.message,_that.kind,_that.stack,_that.route,_that.occurredAt,_that.appBuild,_that.device,_that.context);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ClientErrorReport extends ClientErrorReport {
  const _ClientErrorReport({required this.message, this.kind, this.stack, this.route, this.occurredAt, this.appBuild, this.device, final  Map<String, dynamic>? context}): _context = context,super._();
  factory _ClientErrorReport.fromJson(Map<String, dynamic> json) => _$ClientErrorReportFromJson(json);

/// Hatanın tek satırlık özeti. Sunucu 500 karakteri aşan metni **keser**,
/// isteği reddetmez.
@override final  String message;
/// Hatanın türü — bilinen değerler [ClientErrorKind] içinde.
@override final  String? kind;
/// Yığın izi. Sunucu 8000 karakteri aşan kısmı keser.
@override final  String? stack;
/// Hatanın oluştuğu ekran/rota (`/siparislerim/1234`).
///
/// **Sorgu dizesi olmadan** gönderilmelidir: adres çubuğundaki
/// parametreler zaman zaman kişisel veri taşır ve hata kaydı onları
/// saklamak için yanlış yerdir.
@override final  String? route;
/// Hatanın istemcide oluştuğu an. Sunucu kendi alış anını ayrıca yazar;
/// ikisi arasındaki fark, çevrimdışıyken biriktirilip sonra gönderilen
/// raporları ayırt eder.
@override final  DateTime? occurredAt;
/// Sürüm numarasının altındaki yapı kimliği (build number, commit
/// kısaltması). `X-App-Version` semver'i aynı kalırken yeniden yayınlanan
/// bir yapıyı ayırmanın tek yolu budur.
@override final  String? appBuild;
/// Cihaz/işletim sistemi/tarayıcı özeti. Serbest metin: üç uygulamanın üç
/// farklı kaynağı var ve tek bir yapıya sıkıştırmak hiçbirine uymuyordu.
@override final  String? device;
/// Ek bağlam (ekrandaki kayıt kimliği, deneme sayısı gibi).
///
/// **KİŞİSEL VERİ VE SIR KONMAZ** — token, parola, kart bilgisi ya da tam
/// adres gönderen istemci hata raporunu bir sızıntı kanalına çevirir.
 final  Map<String, dynamic>? _context;
/// Ek bağlam (ekrandaki kayıt kimliği, deneme sayısı gibi).
///
/// **KİŞİSEL VERİ VE SIR KONMAZ** — token, parola, kart bilgisi ya da tam
/// adres gönderen istemci hata raporunu bir sızıntı kanalına çevirir.
@override Map<String, dynamic>? get context {
  final value = _context;
  if (value == null) return null;
  if (_context is EqualUnmodifiableMapView) return _context;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


/// Create a copy of ClientErrorReport
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClientErrorReportCopyWith<_ClientErrorReport> get copyWith => __$ClientErrorReportCopyWithImpl<_ClientErrorReport>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClientErrorReportToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClientErrorReport&&(identical(other.message, message) || other.message == message)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.stack, stack) || other.stack == stack)&&(identical(other.route, route) || other.route == route)&&(identical(other.occurredAt, occurredAt) || other.occurredAt == occurredAt)&&(identical(other.appBuild, appBuild) || other.appBuild == appBuild)&&(identical(other.device, device) || other.device == device)&&const DeepCollectionEquality().equals(other._context, _context));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,message,kind,stack,route,occurredAt,appBuild,device,const DeepCollectionEquality().hash(_context));

@override
String toString() {
  return 'ClientErrorReport(message: $message, kind: $kind, stack: $stack, route: $route, occurredAt: $occurredAt, appBuild: $appBuild, device: $device, context: $context)';
}


}

/// @nodoc
abstract mixin class _$ClientErrorReportCopyWith<$Res> implements $ClientErrorReportCopyWith<$Res> {
  factory _$ClientErrorReportCopyWith(_ClientErrorReport value, $Res Function(_ClientErrorReport) _then) = __$ClientErrorReportCopyWithImpl;
@override @useResult
$Res call({
 String message, String? kind, String? stack, String? route, DateTime? occurredAt, String? appBuild, String? device, Map<String, dynamic>? context
});




}
/// @nodoc
class __$ClientErrorReportCopyWithImpl<$Res>
    implements _$ClientErrorReportCopyWith<$Res> {
  __$ClientErrorReportCopyWithImpl(this._self, this._then);

  final _ClientErrorReport _self;
  final $Res Function(_ClientErrorReport) _then;

/// Create a copy of ClientErrorReport
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? message = null,Object? kind = freezed,Object? stack = freezed,Object? route = freezed,Object? occurredAt = freezed,Object? appBuild = freezed,Object? device = freezed,Object? context = freezed,}) {
  return _then(_ClientErrorReport(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String?,stack: freezed == stack ? _self.stack : stack // ignore: cast_nullable_to_non_nullable
as String?,route: freezed == route ? _self.route : route // ignore: cast_nullable_to_non_nullable
as String?,occurredAt: freezed == occurredAt ? _self.occurredAt : occurredAt // ignore: cast_nullable_to_non_nullable
as DateTime?,appBuild: freezed == appBuild ? _self.appBuild : appBuild // ignore: cast_nullable_to_non_nullable
as String?,device: freezed == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as String?,context: freezed == context ? _self._context : context // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}


}

// dart format on
