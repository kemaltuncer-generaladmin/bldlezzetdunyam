// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'announcement.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Announcement {

 int get id;/// Duyurunun gösterileceği yer; bilinen değerler
/// [AnnouncementPlacement] içinde. Kapalı enum değildir.
 String get placement;/// Duyuru metni (düz metin). Biçimlendirme istemcinindir.
 String get body;/// Kullanıcı bu duyuruyu kapatabilir mi?
///
/// `false` ise duyuru yayın penceresi boyunca ekranda kalır — hizmet
/// kesintisi gibi duyurular kapatıldıktan sonra bir daha görünmezse
/// müşteri aynı soruyu telefonla sorar.
 bool get dismissible;/// Bu müşteri duyuruyu daha önce gördü mü?
 bool get seen;/// Bu müşteri duyuruyu kapattı mı?
///
/// Kapatılan duyuru listeye **girmez**; alan, istemcinin iyimser
/// güncellemesini geri alabilmesi ve yönetim görünümleri için duruyor.
 bool get dismissed;/// Duyurunun tonu; istemci rengi ve ikonu buna göre seçer.
///
/// [AnnouncementSeverity.critical] **kapanmaz** demek değildir;
/// kapanabilirliği [dismissible] söyler. İkisi ayrı çünkü kritik ama bir
/// kez okunması yeten duyurular var ("yarın servis yok").
@AnnouncementSeverityConverter() AnnouncementSeverity get severity; String? get title; String? get actionLabel;/// Duyurunun düğmesi. [actionLabel] boşsa düğme çizilmez. Adresin
/// **uygulama içi** bir yola işaret etmesi beklenir; istemci tanımadığı
/// adresi tarayıcıda açar.
 String? get actionUrl; String? get imageUrl; DateTime? get startsAt;/// Yayın penceresinin sonu; süresizse `null`.
///
/// İstemci **kendi saatine göre eleme YAPMAZ**: pencere dışına çıkmış
/// duyuru listeye zaten girmez. Alan yalnız "şu tarihe kadar geçerli"
/// cümlesini kurmak için var — saati kaymış bir telefonda eleme yapmak,
/// geçerli duyuruyu gizlerdi.
 DateTime? get endsAt; DateTime? get createdAt;
/// Create a copy of Announcement
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AnnouncementCopyWith<Announcement> get copyWith => _$AnnouncementCopyWithImpl<Announcement>(this as Announcement, _$identity);

  /// Serializes this Announcement to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Announcement&&(identical(other.id, id) || other.id == id)&&(identical(other.placement, placement) || other.placement == placement)&&(identical(other.body, body) || other.body == body)&&(identical(other.dismissible, dismissible) || other.dismissible == dismissible)&&(identical(other.seen, seen) || other.seen == seen)&&(identical(other.dismissed, dismissed) || other.dismissed == dismissed)&&(identical(other.severity, severity) || other.severity == severity)&&(identical(other.title, title) || other.title == title)&&(identical(other.actionLabel, actionLabel) || other.actionLabel == actionLabel)&&(identical(other.actionUrl, actionUrl) || other.actionUrl == actionUrl)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,placement,body,dismissible,seen,dismissed,severity,title,actionLabel,actionUrl,imageUrl,startsAt,endsAt,createdAt);

@override
String toString() {
  return 'Announcement(id: $id, placement: $placement, body: $body, dismissible: $dismissible, seen: $seen, dismissed: $dismissed, severity: $severity, title: $title, actionLabel: $actionLabel, actionUrl: $actionUrl, imageUrl: $imageUrl, startsAt: $startsAt, endsAt: $endsAt, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $AnnouncementCopyWith<$Res>  {
  factory $AnnouncementCopyWith(Announcement value, $Res Function(Announcement) _then) = _$AnnouncementCopyWithImpl;
@useResult
$Res call({
 int id, String placement, String body, bool dismissible, bool seen, bool dismissed,@AnnouncementSeverityConverter() AnnouncementSeverity severity, String? title, String? actionLabel, String? actionUrl, String? imageUrl, DateTime? startsAt, DateTime? endsAt, DateTime? createdAt
});




}
/// @nodoc
class _$AnnouncementCopyWithImpl<$Res>
    implements $AnnouncementCopyWith<$Res> {
  _$AnnouncementCopyWithImpl(this._self, this._then);

  final Announcement _self;
  final $Res Function(Announcement) _then;

/// Create a copy of Announcement
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? placement = null,Object? body = null,Object? dismissible = null,Object? seen = null,Object? dismissed = null,Object? severity = null,Object? title = freezed,Object? actionLabel = freezed,Object? actionUrl = freezed,Object? imageUrl = freezed,Object? startsAt = freezed,Object? endsAt = freezed,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,placement: null == placement ? _self.placement : placement // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,dismissible: null == dismissible ? _self.dismissible : dismissible // ignore: cast_nullable_to_non_nullable
as bool,seen: null == seen ? _self.seen : seen // ignore: cast_nullable_to_non_nullable
as bool,dismissed: null == dismissed ? _self.dismissed : dismissed // ignore: cast_nullable_to_non_nullable
as bool,severity: null == severity ? _self.severity : severity // ignore: cast_nullable_to_non_nullable
as AnnouncementSeverity,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,actionLabel: freezed == actionLabel ? _self.actionLabel : actionLabel // ignore: cast_nullable_to_non_nullable
as String?,actionUrl: freezed == actionUrl ? _self.actionUrl : actionUrl // ignore: cast_nullable_to_non_nullable
as String?,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,startsAt: freezed == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime?,endsAt: freezed == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Announcement].
extension AnnouncementPatterns on Announcement {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Announcement value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Announcement() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Announcement value)  $default,){
final _that = this;
switch (_that) {
case _Announcement():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Announcement value)?  $default,){
final _that = this;
switch (_that) {
case _Announcement() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String placement,  String body,  bool dismissible,  bool seen,  bool dismissed, @AnnouncementSeverityConverter()  AnnouncementSeverity severity,  String? title,  String? actionLabel,  String? actionUrl,  String? imageUrl,  DateTime? startsAt,  DateTime? endsAt,  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Announcement() when $default != null:
return $default(_that.id,_that.placement,_that.body,_that.dismissible,_that.seen,_that.dismissed,_that.severity,_that.title,_that.actionLabel,_that.actionUrl,_that.imageUrl,_that.startsAt,_that.endsAt,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String placement,  String body,  bool dismissible,  bool seen,  bool dismissed, @AnnouncementSeverityConverter()  AnnouncementSeverity severity,  String? title,  String? actionLabel,  String? actionUrl,  String? imageUrl,  DateTime? startsAt,  DateTime? endsAt,  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _Announcement():
return $default(_that.id,_that.placement,_that.body,_that.dismissible,_that.seen,_that.dismissed,_that.severity,_that.title,_that.actionLabel,_that.actionUrl,_that.imageUrl,_that.startsAt,_that.endsAt,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String placement,  String body,  bool dismissible,  bool seen,  bool dismissed, @AnnouncementSeverityConverter()  AnnouncementSeverity severity,  String? title,  String? actionLabel,  String? actionUrl,  String? imageUrl,  DateTime? startsAt,  DateTime? endsAt,  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Announcement() when $default != null:
return $default(_that.id,_that.placement,_that.body,_that.dismissible,_that.seen,_that.dismissed,_that.severity,_that.title,_that.actionLabel,_that.actionUrl,_that.imageUrl,_that.startsAt,_that.endsAt,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Announcement extends Announcement {
  const _Announcement({required this.id, required this.placement, required this.body, required this.dismissible, required this.seen, required this.dismissed, @AnnouncementSeverityConverter() this.severity = AnnouncementSeverity.info, this.title, this.actionLabel, this.actionUrl, this.imageUrl, this.startsAt, this.endsAt, this.createdAt}): super._();
  factory _Announcement.fromJson(Map<String, dynamic> json) => _$AnnouncementFromJson(json);

@override final  int id;
/// Duyurunun gösterileceği yer; bilinen değerler
/// [AnnouncementPlacement] içinde. Kapalı enum değildir.
@override final  String placement;
/// Duyuru metni (düz metin). Biçimlendirme istemcinindir.
@override final  String body;
/// Kullanıcı bu duyuruyu kapatabilir mi?
///
/// `false` ise duyuru yayın penceresi boyunca ekranda kalır — hizmet
/// kesintisi gibi duyurular kapatıldıktan sonra bir daha görünmezse
/// müşteri aynı soruyu telefonla sorar.
@override final  bool dismissible;
/// Bu müşteri duyuruyu daha önce gördü mü?
@override final  bool seen;
/// Bu müşteri duyuruyu kapattı mı?
///
/// Kapatılan duyuru listeye **girmez**; alan, istemcinin iyimser
/// güncellemesini geri alabilmesi ve yönetim görünümleri için duruyor.
@override final  bool dismissed;
/// Duyurunun tonu; istemci rengi ve ikonu buna göre seçer.
///
/// [AnnouncementSeverity.critical] **kapanmaz** demek değildir;
/// kapanabilirliği [dismissible] söyler. İkisi ayrı çünkü kritik ama bir
/// kez okunması yeten duyurular var ("yarın servis yok").
@override@JsonKey()@AnnouncementSeverityConverter() final  AnnouncementSeverity severity;
@override final  String? title;
@override final  String? actionLabel;
/// Duyurunun düğmesi. [actionLabel] boşsa düğme çizilmez. Adresin
/// **uygulama içi** bir yola işaret etmesi beklenir; istemci tanımadığı
/// adresi tarayıcıda açar.
@override final  String? actionUrl;
@override final  String? imageUrl;
@override final  DateTime? startsAt;
/// Yayın penceresinin sonu; süresizse `null`.
///
/// İstemci **kendi saatine göre eleme YAPMAZ**: pencere dışına çıkmış
/// duyuru listeye zaten girmez. Alan yalnız "şu tarihe kadar geçerli"
/// cümlesini kurmak için var — saati kaymış bir telefonda eleme yapmak,
/// geçerli duyuruyu gizlerdi.
@override final  DateTime? endsAt;
@override final  DateTime? createdAt;

/// Create a copy of Announcement
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AnnouncementCopyWith<_Announcement> get copyWith => __$AnnouncementCopyWithImpl<_Announcement>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AnnouncementToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Announcement&&(identical(other.id, id) || other.id == id)&&(identical(other.placement, placement) || other.placement == placement)&&(identical(other.body, body) || other.body == body)&&(identical(other.dismissible, dismissible) || other.dismissible == dismissible)&&(identical(other.seen, seen) || other.seen == seen)&&(identical(other.dismissed, dismissed) || other.dismissed == dismissed)&&(identical(other.severity, severity) || other.severity == severity)&&(identical(other.title, title) || other.title == title)&&(identical(other.actionLabel, actionLabel) || other.actionLabel == actionLabel)&&(identical(other.actionUrl, actionUrl) || other.actionUrl == actionUrl)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.startsAt, startsAt) || other.startsAt == startsAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,placement,body,dismissible,seen,dismissed,severity,title,actionLabel,actionUrl,imageUrl,startsAt,endsAt,createdAt);

@override
String toString() {
  return 'Announcement(id: $id, placement: $placement, body: $body, dismissible: $dismissible, seen: $seen, dismissed: $dismissed, severity: $severity, title: $title, actionLabel: $actionLabel, actionUrl: $actionUrl, imageUrl: $imageUrl, startsAt: $startsAt, endsAt: $endsAt, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$AnnouncementCopyWith<$Res> implements $AnnouncementCopyWith<$Res> {
  factory _$AnnouncementCopyWith(_Announcement value, $Res Function(_Announcement) _then) = __$AnnouncementCopyWithImpl;
@override @useResult
$Res call({
 int id, String placement, String body, bool dismissible, bool seen, bool dismissed,@AnnouncementSeverityConverter() AnnouncementSeverity severity, String? title, String? actionLabel, String? actionUrl, String? imageUrl, DateTime? startsAt, DateTime? endsAt, DateTime? createdAt
});




}
/// @nodoc
class __$AnnouncementCopyWithImpl<$Res>
    implements _$AnnouncementCopyWith<$Res> {
  __$AnnouncementCopyWithImpl(this._self, this._then);

  final _Announcement _self;
  final $Res Function(_Announcement) _then;

/// Create a copy of Announcement
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? placement = null,Object? body = null,Object? dismissible = null,Object? seen = null,Object? dismissed = null,Object? severity = null,Object? title = freezed,Object? actionLabel = freezed,Object? actionUrl = freezed,Object? imageUrl = freezed,Object? startsAt = freezed,Object? endsAt = freezed,Object? createdAt = freezed,}) {
  return _then(_Announcement(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,placement: null == placement ? _self.placement : placement // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,dismissible: null == dismissible ? _self.dismissible : dismissible // ignore: cast_nullable_to_non_nullable
as bool,seen: null == seen ? _self.seen : seen // ignore: cast_nullable_to_non_nullable
as bool,dismissed: null == dismissed ? _self.dismissed : dismissed // ignore: cast_nullable_to_non_nullable
as bool,severity: null == severity ? _self.severity : severity // ignore: cast_nullable_to_non_nullable
as AnnouncementSeverity,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,actionLabel: freezed == actionLabel ? _self.actionLabel : actionLabel // ignore: cast_nullable_to_non_nullable
as String?,actionUrl: freezed == actionUrl ? _self.actionUrl : actionUrl // ignore: cast_nullable_to_non_nullable
as String?,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,startsAt: freezed == startsAt ? _self.startsAt : startsAt // ignore: cast_nullable_to_non_nullable
as DateTime?,endsAt: freezed == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
