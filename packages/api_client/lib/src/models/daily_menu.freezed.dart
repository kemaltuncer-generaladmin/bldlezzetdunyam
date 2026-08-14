// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'daily_menu.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DailyMenuPackageComponent {

/// Ürünün gerçek kimliği. Sipariş satırına **yazılmaz** — paket tek bir
/// `menu_id` ile sipariş edilir; bu kimlik yalnızca ürün detayını
/// eşleştirmek için.
 int get menuId; String get name;/// Bir pakette bu kalemden kaç porsiyon var.
 int get quantity; String? get imageUrl; List<String> get allergens;
/// Create a copy of DailyMenuPackageComponent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DailyMenuPackageComponentCopyWith<DailyMenuPackageComponent> get copyWith => _$DailyMenuPackageComponentCopyWithImpl<DailyMenuPackageComponent>(this as DailyMenuPackageComponent, _$identity);

  /// Serializes this DailyMenuPackageComponent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DailyMenuPackageComponent&&(identical(other.menuId, menuId) || other.menuId == menuId)&&(identical(other.name, name) || other.name == name)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&const DeepCollectionEquality().equals(other.allergens, allergens));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,menuId,name,quantity,imageUrl,const DeepCollectionEquality().hash(allergens));

@override
String toString() {
  return 'DailyMenuPackageComponent(menuId: $menuId, name: $name, quantity: $quantity, imageUrl: $imageUrl, allergens: $allergens)';
}


}

/// @nodoc
abstract mixin class $DailyMenuPackageComponentCopyWith<$Res>  {
  factory $DailyMenuPackageComponentCopyWith(DailyMenuPackageComponent value, $Res Function(DailyMenuPackageComponent) _then) = _$DailyMenuPackageComponentCopyWithImpl;
@useResult
$Res call({
 int menuId, String name, int quantity, String? imageUrl, List<String> allergens
});




}
/// @nodoc
class _$DailyMenuPackageComponentCopyWithImpl<$Res>
    implements $DailyMenuPackageComponentCopyWith<$Res> {
  _$DailyMenuPackageComponentCopyWithImpl(this._self, this._then);

  final DailyMenuPackageComponent _self;
  final $Res Function(DailyMenuPackageComponent) _then;

/// Create a copy of DailyMenuPackageComponent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? menuId = null,Object? name = null,Object? quantity = null,Object? imageUrl = freezed,Object? allergens = null,}) {
  return _then(_self.copyWith(
menuId: null == menuId ? _self.menuId : menuId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,allergens: null == allergens ? _self.allergens : allergens // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [DailyMenuPackageComponent].
extension DailyMenuPackageComponentPatterns on DailyMenuPackageComponent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DailyMenuPackageComponent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DailyMenuPackageComponent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DailyMenuPackageComponent value)  $default,){
final _that = this;
switch (_that) {
case _DailyMenuPackageComponent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DailyMenuPackageComponent value)?  $default,){
final _that = this;
switch (_that) {
case _DailyMenuPackageComponent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int menuId,  String name,  int quantity,  String? imageUrl,  List<String> allergens)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DailyMenuPackageComponent() when $default != null:
return $default(_that.menuId,_that.name,_that.quantity,_that.imageUrl,_that.allergens);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int menuId,  String name,  int quantity,  String? imageUrl,  List<String> allergens)  $default,) {final _that = this;
switch (_that) {
case _DailyMenuPackageComponent():
return $default(_that.menuId,_that.name,_that.quantity,_that.imageUrl,_that.allergens);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int menuId,  String name,  int quantity,  String? imageUrl,  List<String> allergens)?  $default,) {final _that = this;
switch (_that) {
case _DailyMenuPackageComponent() when $default != null:
return $default(_that.menuId,_that.name,_that.quantity,_that.imageUrl,_that.allergens);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DailyMenuPackageComponent implements DailyMenuPackageComponent {
  const _DailyMenuPackageComponent({required this.menuId, required this.name, required this.quantity, this.imageUrl, final  List<String> allergens = const <String>[]}): _allergens = allergens;
  factory _DailyMenuPackageComponent.fromJson(Map<String, dynamic> json) => _$DailyMenuPackageComponentFromJson(json);

/// Ürünün gerçek kimliği. Sipariş satırına **yazılmaz** — paket tek bir
/// `menu_id` ile sipariş edilir; bu kimlik yalnızca ürün detayını
/// eşleştirmek için.
@override final  int menuId;
@override final  String name;
/// Bir pakette bu kalemden kaç porsiyon var.
@override final  int quantity;
@override final  String? imageUrl;
 final  List<String> _allergens;
@override@JsonKey() List<String> get allergens {
  if (_allergens is EqualUnmodifiableListView) return _allergens;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_allergens);
}


/// Create a copy of DailyMenuPackageComponent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DailyMenuPackageComponentCopyWith<_DailyMenuPackageComponent> get copyWith => __$DailyMenuPackageComponentCopyWithImpl<_DailyMenuPackageComponent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DailyMenuPackageComponentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DailyMenuPackageComponent&&(identical(other.menuId, menuId) || other.menuId == menuId)&&(identical(other.name, name) || other.name == name)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&const DeepCollectionEquality().equals(other._allergens, _allergens));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,menuId,name,quantity,imageUrl,const DeepCollectionEquality().hash(_allergens));

@override
String toString() {
  return 'DailyMenuPackageComponent(menuId: $menuId, name: $name, quantity: $quantity, imageUrl: $imageUrl, allergens: $allergens)';
}


}

/// @nodoc
abstract mixin class _$DailyMenuPackageComponentCopyWith<$Res> implements $DailyMenuPackageComponentCopyWith<$Res> {
  factory _$DailyMenuPackageComponentCopyWith(_DailyMenuPackageComponent value, $Res Function(_DailyMenuPackageComponent) _then) = __$DailyMenuPackageComponentCopyWithImpl;
@override @useResult
$Res call({
 int menuId, String name, int quantity, String? imageUrl, List<String> allergens
});




}
/// @nodoc
class __$DailyMenuPackageComponentCopyWithImpl<$Res>
    implements _$DailyMenuPackageComponentCopyWith<$Res> {
  __$DailyMenuPackageComponentCopyWithImpl(this._self, this._then);

  final _DailyMenuPackageComponent _self;
  final $Res Function(_DailyMenuPackageComponent) _then;

/// Create a copy of DailyMenuPackageComponent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? menuId = null,Object? name = null,Object? quantity = null,Object? imageUrl = freezed,Object? allergens = null,}) {
  return _then(_DailyMenuPackageComponent(
menuId: null == menuId ? _self.menuId : menuId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,allergens: null == allergens ? _self._allergens : allergens // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$DailyMenuPackage {

/// **Sipariş verirken `OrderCreateItem.menuId` alanına yazılacak değer.**
///
/// Paket, sözleşme açısından bir ürün gibi sipariş edilir; sunucu bu
/// kimliği tanır, fiyatı o günün paket fiyatından alır ve içindekileri
/// satırın altına kendisi açar. İstemci "paket mi ürün mü" ayrımını
/// istek biçiminde taşımaz.
 int get menuId; String get name;/// Paketin o günkü fiyatı (kuruş). Kalemlerin toplamından ucuz olabilir.
 int get price;/// Paket bugün satılabilir mi?
///
/// İçindeki **zorunlu** bir kalem tükendiyse bu da yanlıştır: ana yemeği
/// olmayan bir menüyü satmak, bir telefon özrünü kırka çevirir.
 bool get isAvailable; String? get soldOutReason; List<DailyMenuPackageComponent> get components;
/// Create a copy of DailyMenuPackage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DailyMenuPackageCopyWith<DailyMenuPackage> get copyWith => _$DailyMenuPackageCopyWithImpl<DailyMenuPackage>(this as DailyMenuPackage, _$identity);

  /// Serializes this DailyMenuPackage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DailyMenuPackage&&(identical(other.menuId, menuId) || other.menuId == menuId)&&(identical(other.name, name) || other.name == name)&&(identical(other.price, price) || other.price == price)&&(identical(other.isAvailable, isAvailable) || other.isAvailable == isAvailable)&&(identical(other.soldOutReason, soldOutReason) || other.soldOutReason == soldOutReason)&&const DeepCollectionEquality().equals(other.components, components));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,menuId,name,price,isAvailable,soldOutReason,const DeepCollectionEquality().hash(components));

@override
String toString() {
  return 'DailyMenuPackage(menuId: $menuId, name: $name, price: $price, isAvailable: $isAvailable, soldOutReason: $soldOutReason, components: $components)';
}


}

/// @nodoc
abstract mixin class $DailyMenuPackageCopyWith<$Res>  {
  factory $DailyMenuPackageCopyWith(DailyMenuPackage value, $Res Function(DailyMenuPackage) _then) = _$DailyMenuPackageCopyWithImpl;
@useResult
$Res call({
 int menuId, String name, int price, bool isAvailable, String? soldOutReason, List<DailyMenuPackageComponent> components
});




}
/// @nodoc
class _$DailyMenuPackageCopyWithImpl<$Res>
    implements $DailyMenuPackageCopyWith<$Res> {
  _$DailyMenuPackageCopyWithImpl(this._self, this._then);

  final DailyMenuPackage _self;
  final $Res Function(DailyMenuPackage) _then;

/// Create a copy of DailyMenuPackage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? menuId = null,Object? name = null,Object? price = null,Object? isAvailable = null,Object? soldOutReason = freezed,Object? components = null,}) {
  return _then(_self.copyWith(
menuId: null == menuId ? _self.menuId : menuId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as int,isAvailable: null == isAvailable ? _self.isAvailable : isAvailable // ignore: cast_nullable_to_non_nullable
as bool,soldOutReason: freezed == soldOutReason ? _self.soldOutReason : soldOutReason // ignore: cast_nullable_to_non_nullable
as String?,components: null == components ? _self.components : components // ignore: cast_nullable_to_non_nullable
as List<DailyMenuPackageComponent>,
  ));
}

}


/// Adds pattern-matching-related methods to [DailyMenuPackage].
extension DailyMenuPackagePatterns on DailyMenuPackage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DailyMenuPackage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DailyMenuPackage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DailyMenuPackage value)  $default,){
final _that = this;
switch (_that) {
case _DailyMenuPackage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DailyMenuPackage value)?  $default,){
final _that = this;
switch (_that) {
case _DailyMenuPackage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int menuId,  String name,  int price,  bool isAvailable,  String? soldOutReason,  List<DailyMenuPackageComponent> components)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DailyMenuPackage() when $default != null:
return $default(_that.menuId,_that.name,_that.price,_that.isAvailable,_that.soldOutReason,_that.components);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int menuId,  String name,  int price,  bool isAvailable,  String? soldOutReason,  List<DailyMenuPackageComponent> components)  $default,) {final _that = this;
switch (_that) {
case _DailyMenuPackage():
return $default(_that.menuId,_that.name,_that.price,_that.isAvailable,_that.soldOutReason,_that.components);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int menuId,  String name,  int price,  bool isAvailable,  String? soldOutReason,  List<DailyMenuPackageComponent> components)?  $default,) {final _that = this;
switch (_that) {
case _DailyMenuPackage() when $default != null:
return $default(_that.menuId,_that.name,_that.price,_that.isAvailable,_that.soldOutReason,_that.components);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DailyMenuPackage extends DailyMenuPackage {
  const _DailyMenuPackage({required this.menuId, required this.name, required this.price, required this.isAvailable, this.soldOutReason, final  List<DailyMenuPackageComponent> components = const <DailyMenuPackageComponent>[]}): _components = components,super._();
  factory _DailyMenuPackage.fromJson(Map<String, dynamic> json) => _$DailyMenuPackageFromJson(json);

/// **Sipariş verirken `OrderCreateItem.menuId` alanına yazılacak değer.**
///
/// Paket, sözleşme açısından bir ürün gibi sipariş edilir; sunucu bu
/// kimliği tanır, fiyatı o günün paket fiyatından alır ve içindekileri
/// satırın altına kendisi açar. İstemci "paket mi ürün mü" ayrımını
/// istek biçiminde taşımaz.
@override final  int menuId;
@override final  String name;
/// Paketin o günkü fiyatı (kuruş). Kalemlerin toplamından ucuz olabilir.
@override final  int price;
/// Paket bugün satılabilir mi?
///
/// İçindeki **zorunlu** bir kalem tükendiyse bu da yanlıştır: ana yemeği
/// olmayan bir menüyü satmak, bir telefon özrünü kırka çevirir.
@override final  bool isAvailable;
@override final  String? soldOutReason;
 final  List<DailyMenuPackageComponent> _components;
@override@JsonKey() List<DailyMenuPackageComponent> get components {
  if (_components is EqualUnmodifiableListView) return _components;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_components);
}


/// Create a copy of DailyMenuPackage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DailyMenuPackageCopyWith<_DailyMenuPackage> get copyWith => __$DailyMenuPackageCopyWithImpl<_DailyMenuPackage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DailyMenuPackageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DailyMenuPackage&&(identical(other.menuId, menuId) || other.menuId == menuId)&&(identical(other.name, name) || other.name == name)&&(identical(other.price, price) || other.price == price)&&(identical(other.isAvailable, isAvailable) || other.isAvailable == isAvailable)&&(identical(other.soldOutReason, soldOutReason) || other.soldOutReason == soldOutReason)&&const DeepCollectionEquality().equals(other._components, _components));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,menuId,name,price,isAvailable,soldOutReason,const DeepCollectionEquality().hash(_components));

@override
String toString() {
  return 'DailyMenuPackage(menuId: $menuId, name: $name, price: $price, isAvailable: $isAvailable, soldOutReason: $soldOutReason, components: $components)';
}


}

/// @nodoc
abstract mixin class _$DailyMenuPackageCopyWith<$Res> implements $DailyMenuPackageCopyWith<$Res> {
  factory _$DailyMenuPackageCopyWith(_DailyMenuPackage value, $Res Function(_DailyMenuPackage) _then) = __$DailyMenuPackageCopyWithImpl;
@override @useResult
$Res call({
 int menuId, String name, int price, bool isAvailable, String? soldOutReason, List<DailyMenuPackageComponent> components
});




}
/// @nodoc
class __$DailyMenuPackageCopyWithImpl<$Res>
    implements _$DailyMenuPackageCopyWith<$Res> {
  __$DailyMenuPackageCopyWithImpl(this._self, this._then);

  final _DailyMenuPackage _self;
  final $Res Function(_DailyMenuPackage) _then;

/// Create a copy of DailyMenuPackage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? menuId = null,Object? name = null,Object? price = null,Object? isAvailable = null,Object? soldOutReason = freezed,Object? components = null,}) {
  return _then(_DailyMenuPackage(
menuId: null == menuId ? _self.menuId : menuId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as int,isAvailable: null == isAvailable ? _self.isAvailable : isAvailable // ignore: cast_nullable_to_non_nullable
as bool,soldOutReason: freezed == soldOutReason ? _self.soldOutReason : soldOutReason // ignore: cast_nullable_to_non_nullable
as String?,components: null == components ? _self._components : components // ignore: cast_nullable_to_non_nullable
as List<DailyMenuPackageComponent>,
  ));
}


}


/// @nodoc
mixin _$DailyMenu {

/// `YYYY-AA-GG`, işletme takviminde (Europe/Istanbul).
 String get date; String get currency;/// İşletmenin kapalı olduğu gün. Menü girilmiş olsa bile sipariş alınmaz.
 bool get closed;/// Bu güne **şu anda** sipariş verilebilir mi?
///
/// Bağlayıcı olan yine `POST /orders` anındaki denetimdir; bu alan
/// arayüzü doğru çizmek içindir, karar vermek için değil.
 bool get isOrderable;/// O günün yayınlanmış menüsünün kimliği; **`null` ise o gün menü yok**.
 int? get id;/// Günün adı, örn. "Ev Yemeği Menüsü".
 String? get title; String? get description; String? get imageUrl;/// Menünün paket hâli; o gün paket satılmıyorsa `null` — kalemler yine
/// tek tek satılabilir.
 DailyMenuPackage? get package;/// Kalemlerin tek tek alınması hâlindeki toplam (kuruş).
///
/// Sunucu hesaplar; para hesabı tek yerde kalsın diye alan olarak
/// veriliyor.
 int? get itemsTotal;/// [isOrderable] yanlışken sebebin makine okunur hâli.
@DailyMenuUnavailableReasonConverter() DailyMenuUnavailableReason get unavailableReason;/// Menüyü oluşturan kalemler, yöneticinin verdiği sırada.
///
/// `price` **o gün için geçerli** birim fiyattır (ürünün kendi fiyatı ya
/// da o güne girilmiş istisna); istemci ayrıca fiyat hesaplamaz.
 List<MenuItem> get items;
/// Create a copy of DailyMenu
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DailyMenuCopyWith<DailyMenu> get copyWith => _$DailyMenuCopyWithImpl<DailyMenu>(this as DailyMenu, _$identity);

  /// Serializes this DailyMenu to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DailyMenu&&(identical(other.date, date) || other.date == date)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.closed, closed) || other.closed == closed)&&(identical(other.isOrderable, isOrderable) || other.isOrderable == isOrderable)&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.package, package) || other.package == package)&&(identical(other.itemsTotal, itemsTotal) || other.itemsTotal == itemsTotal)&&(identical(other.unavailableReason, unavailableReason) || other.unavailableReason == unavailableReason)&&const DeepCollectionEquality().equals(other.items, items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date,currency,closed,isOrderable,id,title,description,imageUrl,package,itemsTotal,unavailableReason,const DeepCollectionEquality().hash(items));

@override
String toString() {
  return 'DailyMenu(date: $date, currency: $currency, closed: $closed, isOrderable: $isOrderable, id: $id, title: $title, description: $description, imageUrl: $imageUrl, package: $package, itemsTotal: $itemsTotal, unavailableReason: $unavailableReason, items: $items)';
}


}

/// @nodoc
abstract mixin class $DailyMenuCopyWith<$Res>  {
  factory $DailyMenuCopyWith(DailyMenu value, $Res Function(DailyMenu) _then) = _$DailyMenuCopyWithImpl;
@useResult
$Res call({
 String date, String currency, bool closed, bool isOrderable, int? id, String? title, String? description, String? imageUrl, DailyMenuPackage? package, int? itemsTotal,@DailyMenuUnavailableReasonConverter() DailyMenuUnavailableReason unavailableReason, List<MenuItem> items
});


$DailyMenuPackageCopyWith<$Res>? get package;

}
/// @nodoc
class _$DailyMenuCopyWithImpl<$Res>
    implements $DailyMenuCopyWith<$Res> {
  _$DailyMenuCopyWithImpl(this._self, this._then);

  final DailyMenu _self;
  final $Res Function(DailyMenu) _then;

/// Create a copy of DailyMenu
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? date = null,Object? currency = null,Object? closed = null,Object? isOrderable = null,Object? id = freezed,Object? title = freezed,Object? description = freezed,Object? imageUrl = freezed,Object? package = freezed,Object? itemsTotal = freezed,Object? unavailableReason = null,Object? items = null,}) {
  return _then(_self.copyWith(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,closed: null == closed ? _self.closed : closed // ignore: cast_nullable_to_non_nullable
as bool,isOrderable: null == isOrderable ? _self.isOrderable : isOrderable // ignore: cast_nullable_to_non_nullable
as bool,id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,package: freezed == package ? _self.package : package // ignore: cast_nullable_to_non_nullable
as DailyMenuPackage?,itemsTotal: freezed == itemsTotal ? _self.itemsTotal : itemsTotal // ignore: cast_nullable_to_non_nullable
as int?,unavailableReason: null == unavailableReason ? _self.unavailableReason : unavailableReason // ignore: cast_nullable_to_non_nullable
as DailyMenuUnavailableReason,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<MenuItem>,
  ));
}
/// Create a copy of DailyMenu
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DailyMenuPackageCopyWith<$Res>? get package {
    if (_self.package == null) {
    return null;
  }

  return $DailyMenuPackageCopyWith<$Res>(_self.package!, (value) {
    return _then(_self.copyWith(package: value));
  });
}
}


/// Adds pattern-matching-related methods to [DailyMenu].
extension DailyMenuPatterns on DailyMenu {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DailyMenu value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DailyMenu() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DailyMenu value)  $default,){
final _that = this;
switch (_that) {
case _DailyMenu():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DailyMenu value)?  $default,){
final _that = this;
switch (_that) {
case _DailyMenu() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String date,  String currency,  bool closed,  bool isOrderable,  int? id,  String? title,  String? description,  String? imageUrl,  DailyMenuPackage? package,  int? itemsTotal, @DailyMenuUnavailableReasonConverter()  DailyMenuUnavailableReason unavailableReason,  List<MenuItem> items)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DailyMenu() when $default != null:
return $default(_that.date,_that.currency,_that.closed,_that.isOrderable,_that.id,_that.title,_that.description,_that.imageUrl,_that.package,_that.itemsTotal,_that.unavailableReason,_that.items);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String date,  String currency,  bool closed,  bool isOrderable,  int? id,  String? title,  String? description,  String? imageUrl,  DailyMenuPackage? package,  int? itemsTotal, @DailyMenuUnavailableReasonConverter()  DailyMenuUnavailableReason unavailableReason,  List<MenuItem> items)  $default,) {final _that = this;
switch (_that) {
case _DailyMenu():
return $default(_that.date,_that.currency,_that.closed,_that.isOrderable,_that.id,_that.title,_that.description,_that.imageUrl,_that.package,_that.itemsTotal,_that.unavailableReason,_that.items);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String date,  String currency,  bool closed,  bool isOrderable,  int? id,  String? title,  String? description,  String? imageUrl,  DailyMenuPackage? package,  int? itemsTotal, @DailyMenuUnavailableReasonConverter()  DailyMenuUnavailableReason unavailableReason,  List<MenuItem> items)?  $default,) {final _that = this;
switch (_that) {
case _DailyMenu() when $default != null:
return $default(_that.date,_that.currency,_that.closed,_that.isOrderable,_that.id,_that.title,_that.description,_that.imageUrl,_that.package,_that.itemsTotal,_that.unavailableReason,_that.items);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DailyMenu extends DailyMenu {
  const _DailyMenu({required this.date, required this.currency, required this.closed, required this.isOrderable, this.id, this.title, this.description, this.imageUrl, this.package, this.itemsTotal, @DailyMenuUnavailableReasonConverter() this.unavailableReason = DailyMenuUnavailableReason.none, final  List<MenuItem> items = const <MenuItem>[]}): _items = items,super._();
  factory _DailyMenu.fromJson(Map<String, dynamic> json) => _$DailyMenuFromJson(json);

/// `YYYY-AA-GG`, işletme takviminde (Europe/Istanbul).
@override final  String date;
@override final  String currency;
/// İşletmenin kapalı olduğu gün. Menü girilmiş olsa bile sipariş alınmaz.
@override final  bool closed;
/// Bu güne **şu anda** sipariş verilebilir mi?
///
/// Bağlayıcı olan yine `POST /orders` anındaki denetimdir; bu alan
/// arayüzü doğru çizmek içindir, karar vermek için değil.
@override final  bool isOrderable;
/// O günün yayınlanmış menüsünün kimliği; **`null` ise o gün menü yok**.
@override final  int? id;
/// Günün adı, örn. "Ev Yemeği Menüsü".
@override final  String? title;
@override final  String? description;
@override final  String? imageUrl;
/// Menünün paket hâli; o gün paket satılmıyorsa `null` — kalemler yine
/// tek tek satılabilir.
@override final  DailyMenuPackage? package;
/// Kalemlerin tek tek alınması hâlindeki toplam (kuruş).
///
/// Sunucu hesaplar; para hesabı tek yerde kalsın diye alan olarak
/// veriliyor.
@override final  int? itemsTotal;
/// [isOrderable] yanlışken sebebin makine okunur hâli.
@override@JsonKey()@DailyMenuUnavailableReasonConverter() final  DailyMenuUnavailableReason unavailableReason;
/// Menüyü oluşturan kalemler, yöneticinin verdiği sırada.
///
/// `price` **o gün için geçerli** birim fiyattır (ürünün kendi fiyatı ya
/// da o güne girilmiş istisna); istemci ayrıca fiyat hesaplamaz.
 final  List<MenuItem> _items;
/// Menüyü oluşturan kalemler, yöneticinin verdiği sırada.
///
/// `price` **o gün için geçerli** birim fiyattır (ürünün kendi fiyatı ya
/// da o güne girilmiş istisna); istemci ayrıca fiyat hesaplamaz.
@override@JsonKey() List<MenuItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


/// Create a copy of DailyMenu
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DailyMenuCopyWith<_DailyMenu> get copyWith => __$DailyMenuCopyWithImpl<_DailyMenu>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DailyMenuToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DailyMenu&&(identical(other.date, date) || other.date == date)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.closed, closed) || other.closed == closed)&&(identical(other.isOrderable, isOrderable) || other.isOrderable == isOrderable)&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.package, package) || other.package == package)&&(identical(other.itemsTotal, itemsTotal) || other.itemsTotal == itemsTotal)&&(identical(other.unavailableReason, unavailableReason) || other.unavailableReason == unavailableReason)&&const DeepCollectionEquality().equals(other._items, _items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date,currency,closed,isOrderable,id,title,description,imageUrl,package,itemsTotal,unavailableReason,const DeepCollectionEquality().hash(_items));

@override
String toString() {
  return 'DailyMenu(date: $date, currency: $currency, closed: $closed, isOrderable: $isOrderable, id: $id, title: $title, description: $description, imageUrl: $imageUrl, package: $package, itemsTotal: $itemsTotal, unavailableReason: $unavailableReason, items: $items)';
}


}

/// @nodoc
abstract mixin class _$DailyMenuCopyWith<$Res> implements $DailyMenuCopyWith<$Res> {
  factory _$DailyMenuCopyWith(_DailyMenu value, $Res Function(_DailyMenu) _then) = __$DailyMenuCopyWithImpl;
@override @useResult
$Res call({
 String date, String currency, bool closed, bool isOrderable, int? id, String? title, String? description, String? imageUrl, DailyMenuPackage? package, int? itemsTotal,@DailyMenuUnavailableReasonConverter() DailyMenuUnavailableReason unavailableReason, List<MenuItem> items
});


@override $DailyMenuPackageCopyWith<$Res>? get package;

}
/// @nodoc
class __$DailyMenuCopyWithImpl<$Res>
    implements _$DailyMenuCopyWith<$Res> {
  __$DailyMenuCopyWithImpl(this._self, this._then);

  final _DailyMenu _self;
  final $Res Function(_DailyMenu) _then;

/// Create a copy of DailyMenu
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? date = null,Object? currency = null,Object? closed = null,Object? isOrderable = null,Object? id = freezed,Object? title = freezed,Object? description = freezed,Object? imageUrl = freezed,Object? package = freezed,Object? itemsTotal = freezed,Object? unavailableReason = null,Object? items = null,}) {
  return _then(_DailyMenu(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,closed: null == closed ? _self.closed : closed // ignore: cast_nullable_to_non_nullable
as bool,isOrderable: null == isOrderable ? _self.isOrderable : isOrderable // ignore: cast_nullable_to_non_nullable
as bool,id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,package: freezed == package ? _self.package : package // ignore: cast_nullable_to_non_nullable
as DailyMenuPackage?,itemsTotal: freezed == itemsTotal ? _self.itemsTotal : itemsTotal // ignore: cast_nullable_to_non_nullable
as int?,unavailableReason: null == unavailableReason ? _self.unavailableReason : unavailableReason // ignore: cast_nullable_to_non_nullable
as DailyMenuUnavailableReason,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<MenuItem>,
  ));
}

/// Create a copy of DailyMenu
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DailyMenuPackageCopyWith<$Res>? get package {
    if (_self.package == null) {
    return null;
  }

  return $DailyMenuPackageCopyWith<$Res>(_self.package!, (value) {
    return _then(_self.copyWith(package: value));
  });
}
}


/// @nodoc
mixin _$MenuCalendarDay {

/// `YYYY-AA-GG`.
 String get date; bool get hasMenu; bool get closed; bool get isOrderable; String? get title;/// Paket fiyatı (kuruş); o gün paket satılmıyorsa `null`.
 int? get packagePrice;/// Kapalı günün açıklaması ("Kurban Bayramı") ya da `null`.
 String? get note;
/// Create a copy of MenuCalendarDay
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MenuCalendarDayCopyWith<MenuCalendarDay> get copyWith => _$MenuCalendarDayCopyWithImpl<MenuCalendarDay>(this as MenuCalendarDay, _$identity);

  /// Serializes this MenuCalendarDay to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MenuCalendarDay&&(identical(other.date, date) || other.date == date)&&(identical(other.hasMenu, hasMenu) || other.hasMenu == hasMenu)&&(identical(other.closed, closed) || other.closed == closed)&&(identical(other.isOrderable, isOrderable) || other.isOrderable == isOrderable)&&(identical(other.title, title) || other.title == title)&&(identical(other.packagePrice, packagePrice) || other.packagePrice == packagePrice)&&(identical(other.note, note) || other.note == note));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date,hasMenu,closed,isOrderable,title,packagePrice,note);

@override
String toString() {
  return 'MenuCalendarDay(date: $date, hasMenu: $hasMenu, closed: $closed, isOrderable: $isOrderable, title: $title, packagePrice: $packagePrice, note: $note)';
}


}

/// @nodoc
abstract mixin class $MenuCalendarDayCopyWith<$Res>  {
  factory $MenuCalendarDayCopyWith(MenuCalendarDay value, $Res Function(MenuCalendarDay) _then) = _$MenuCalendarDayCopyWithImpl;
@useResult
$Res call({
 String date, bool hasMenu, bool closed, bool isOrderable, String? title, int? packagePrice, String? note
});




}
/// @nodoc
class _$MenuCalendarDayCopyWithImpl<$Res>
    implements $MenuCalendarDayCopyWith<$Res> {
  _$MenuCalendarDayCopyWithImpl(this._self, this._then);

  final MenuCalendarDay _self;
  final $Res Function(MenuCalendarDay) _then;

/// Create a copy of MenuCalendarDay
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? date = null,Object? hasMenu = null,Object? closed = null,Object? isOrderable = null,Object? title = freezed,Object? packagePrice = freezed,Object? note = freezed,}) {
  return _then(_self.copyWith(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,hasMenu: null == hasMenu ? _self.hasMenu : hasMenu // ignore: cast_nullable_to_non_nullable
as bool,closed: null == closed ? _self.closed : closed // ignore: cast_nullable_to_non_nullable
as bool,isOrderable: null == isOrderable ? _self.isOrderable : isOrderable // ignore: cast_nullable_to_non_nullable
as bool,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,packagePrice: freezed == packagePrice ? _self.packagePrice : packagePrice // ignore: cast_nullable_to_non_nullable
as int?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MenuCalendarDay].
extension MenuCalendarDayPatterns on MenuCalendarDay {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MenuCalendarDay value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MenuCalendarDay() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MenuCalendarDay value)  $default,){
final _that = this;
switch (_that) {
case _MenuCalendarDay():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MenuCalendarDay value)?  $default,){
final _that = this;
switch (_that) {
case _MenuCalendarDay() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String date,  bool hasMenu,  bool closed,  bool isOrderable,  String? title,  int? packagePrice,  String? note)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MenuCalendarDay() when $default != null:
return $default(_that.date,_that.hasMenu,_that.closed,_that.isOrderable,_that.title,_that.packagePrice,_that.note);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String date,  bool hasMenu,  bool closed,  bool isOrderable,  String? title,  int? packagePrice,  String? note)  $default,) {final _that = this;
switch (_that) {
case _MenuCalendarDay():
return $default(_that.date,_that.hasMenu,_that.closed,_that.isOrderable,_that.title,_that.packagePrice,_that.note);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String date,  bool hasMenu,  bool closed,  bool isOrderable,  String? title,  int? packagePrice,  String? note)?  $default,) {final _that = this;
switch (_that) {
case _MenuCalendarDay() when $default != null:
return $default(_that.date,_that.hasMenu,_that.closed,_that.isOrderable,_that.title,_that.packagePrice,_that.note);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MenuCalendarDay extends MenuCalendarDay {
  const _MenuCalendarDay({required this.date, required this.hasMenu, required this.closed, required this.isOrderable, this.title, this.packagePrice, this.note}): super._();
  factory _MenuCalendarDay.fromJson(Map<String, dynamic> json) => _$MenuCalendarDayFromJson(json);

/// `YYYY-AA-GG`.
@override final  String date;
@override final  bool hasMenu;
@override final  bool closed;
@override final  bool isOrderable;
@override final  String? title;
/// Paket fiyatı (kuruş); o gün paket satılmıyorsa `null`.
@override final  int? packagePrice;
/// Kapalı günün açıklaması ("Kurban Bayramı") ya da `null`.
@override final  String? note;

/// Create a copy of MenuCalendarDay
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MenuCalendarDayCopyWith<_MenuCalendarDay> get copyWith => __$MenuCalendarDayCopyWithImpl<_MenuCalendarDay>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MenuCalendarDayToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MenuCalendarDay&&(identical(other.date, date) || other.date == date)&&(identical(other.hasMenu, hasMenu) || other.hasMenu == hasMenu)&&(identical(other.closed, closed) || other.closed == closed)&&(identical(other.isOrderable, isOrderable) || other.isOrderable == isOrderable)&&(identical(other.title, title) || other.title == title)&&(identical(other.packagePrice, packagePrice) || other.packagePrice == packagePrice)&&(identical(other.note, note) || other.note == note));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date,hasMenu,closed,isOrderable,title,packagePrice,note);

@override
String toString() {
  return 'MenuCalendarDay(date: $date, hasMenu: $hasMenu, closed: $closed, isOrderable: $isOrderable, title: $title, packagePrice: $packagePrice, note: $note)';
}


}

/// @nodoc
abstract mixin class _$MenuCalendarDayCopyWith<$Res> implements $MenuCalendarDayCopyWith<$Res> {
  factory _$MenuCalendarDayCopyWith(_MenuCalendarDay value, $Res Function(_MenuCalendarDay) _then) = __$MenuCalendarDayCopyWithImpl;
@override @useResult
$Res call({
 String date, bool hasMenu, bool closed, bool isOrderable, String? title, int? packagePrice, String? note
});




}
/// @nodoc
class __$MenuCalendarDayCopyWithImpl<$Res>
    implements _$MenuCalendarDayCopyWith<$Res> {
  __$MenuCalendarDayCopyWithImpl(this._self, this._then);

  final _MenuCalendarDay _self;
  final $Res Function(_MenuCalendarDay) _then;

/// Create a copy of MenuCalendarDay
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? date = null,Object? hasMenu = null,Object? closed = null,Object? isOrderable = null,Object? title = freezed,Object? packagePrice = freezed,Object? note = freezed,}) {
  return _then(_MenuCalendarDay(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,hasMenu: null == hasMenu ? _self.hasMenu : hasMenu // ignore: cast_nullable_to_non_nullable
as bool,closed: null == closed ? _self.closed : closed // ignore: cast_nullable_to_non_nullable
as bool,isOrderable: null == isOrderable ? _self.isOrderable : isOrderable // ignore: cast_nullable_to_non_nullable
as bool,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,packagePrice: freezed == packagePrice ? _self.packagePrice : packagePrice // ignore: cast_nullable_to_non_nullable
as int?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
