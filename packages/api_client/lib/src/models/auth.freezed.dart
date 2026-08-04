// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RegisterRequest {

 String get firstName; String get lastName; String get email;/// Başında 0 veya +90 olmadan 10 hane.
 String get telephone; String get password;/// `false` ise sunucu `422 VALIDATION_FAILED` döner.
 bool get kvkkAccepted;
/// Create a copy of RegisterRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RegisterRequestCopyWith<RegisterRequest> get copyWith => _$RegisterRequestCopyWithImpl<RegisterRequest>(this as RegisterRequest, _$identity);

  /// Serializes this RegisterRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RegisterRequest&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.email, email) || other.email == email)&&(identical(other.telephone, telephone) || other.telephone == telephone)&&(identical(other.password, password) || other.password == password)&&(identical(other.kvkkAccepted, kvkkAccepted) || other.kvkkAccepted == kvkkAccepted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,firstName,lastName,email,telephone,password,kvkkAccepted);

@override
String toString() {
  return 'RegisterRequest(firstName: $firstName, lastName: $lastName, email: $email, telephone: $telephone, password: $password, kvkkAccepted: $kvkkAccepted)';
}


}

/// @nodoc
abstract mixin class $RegisterRequestCopyWith<$Res>  {
  factory $RegisterRequestCopyWith(RegisterRequest value, $Res Function(RegisterRequest) _then) = _$RegisterRequestCopyWithImpl;
@useResult
$Res call({
 String firstName, String lastName, String email, String telephone, String password, bool kvkkAccepted
});




}
/// @nodoc
class _$RegisterRequestCopyWithImpl<$Res>
    implements $RegisterRequestCopyWith<$Res> {
  _$RegisterRequestCopyWithImpl(this._self, this._then);

  final RegisterRequest _self;
  final $Res Function(RegisterRequest) _then;

/// Create a copy of RegisterRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? firstName = null,Object? lastName = null,Object? email = null,Object? telephone = null,Object? password = null,Object? kvkkAccepted = null,}) {
  return _then(_self.copyWith(
firstName: null == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String,lastName: null == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,telephone: null == telephone ? _self.telephone : telephone // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,kvkkAccepted: null == kvkkAccepted ? _self.kvkkAccepted : kvkkAccepted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [RegisterRequest].
extension RegisterRequestPatterns on RegisterRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RegisterRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RegisterRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RegisterRequest value)  $default,){
final _that = this;
switch (_that) {
case _RegisterRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RegisterRequest value)?  $default,){
final _that = this;
switch (_that) {
case _RegisterRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String firstName,  String lastName,  String email,  String telephone,  String password,  bool kvkkAccepted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RegisterRequest() when $default != null:
return $default(_that.firstName,_that.lastName,_that.email,_that.telephone,_that.password,_that.kvkkAccepted);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String firstName,  String lastName,  String email,  String telephone,  String password,  bool kvkkAccepted)  $default,) {final _that = this;
switch (_that) {
case _RegisterRequest():
return $default(_that.firstName,_that.lastName,_that.email,_that.telephone,_that.password,_that.kvkkAccepted);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String firstName,  String lastName,  String email,  String telephone,  String password,  bool kvkkAccepted)?  $default,) {final _that = this;
switch (_that) {
case _RegisterRequest() when $default != null:
return $default(_that.firstName,_that.lastName,_that.email,_that.telephone,_that.password,_that.kvkkAccepted);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RegisterRequest implements RegisterRequest {
  const _RegisterRequest({required this.firstName, required this.lastName, required this.email, required this.telephone, required this.password, required this.kvkkAccepted});
  factory _RegisterRequest.fromJson(Map<String, dynamic> json) => _$RegisterRequestFromJson(json);

@override final  String firstName;
@override final  String lastName;
@override final  String email;
/// Başında 0 veya +90 olmadan 10 hane.
@override final  String telephone;
@override final  String password;
/// `false` ise sunucu `422 VALIDATION_FAILED` döner.
@override final  bool kvkkAccepted;

/// Create a copy of RegisterRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RegisterRequestCopyWith<_RegisterRequest> get copyWith => __$RegisterRequestCopyWithImpl<_RegisterRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RegisterRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RegisterRequest&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.email, email) || other.email == email)&&(identical(other.telephone, telephone) || other.telephone == telephone)&&(identical(other.password, password) || other.password == password)&&(identical(other.kvkkAccepted, kvkkAccepted) || other.kvkkAccepted == kvkkAccepted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,firstName,lastName,email,telephone,password,kvkkAccepted);

@override
String toString() {
  return 'RegisterRequest(firstName: $firstName, lastName: $lastName, email: $email, telephone: $telephone, password: $password, kvkkAccepted: $kvkkAccepted)';
}


}

/// @nodoc
abstract mixin class _$RegisterRequestCopyWith<$Res> implements $RegisterRequestCopyWith<$Res> {
  factory _$RegisterRequestCopyWith(_RegisterRequest value, $Res Function(_RegisterRequest) _then) = __$RegisterRequestCopyWithImpl;
@override @useResult
$Res call({
 String firstName, String lastName, String email, String telephone, String password, bool kvkkAccepted
});




}
/// @nodoc
class __$RegisterRequestCopyWithImpl<$Res>
    implements _$RegisterRequestCopyWith<$Res> {
  __$RegisterRequestCopyWithImpl(this._self, this._then);

  final _RegisterRequest _self;
  final $Res Function(_RegisterRequest) _then;

/// Create a copy of RegisterRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? firstName = null,Object? lastName = null,Object? email = null,Object? telephone = null,Object? password = null,Object? kvkkAccepted = null,}) {
  return _then(_RegisterRequest(
firstName: null == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String,lastName: null == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,telephone: null == telephone ? _self.telephone : telephone // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,kvkkAccepted: null == kvkkAccepted ? _self.kvkkAccepted : kvkkAccepted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$LoginRequest {

 String get email; String get password;
/// Create a copy of LoginRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LoginRequestCopyWith<LoginRequest> get copyWith => _$LoginRequestCopyWithImpl<LoginRequest>(this as LoginRequest, _$identity);

  /// Serializes this LoginRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginRequest&&(identical(other.email, email) || other.email == email)&&(identical(other.password, password) || other.password == password));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,email,password);

@override
String toString() {
  return 'LoginRequest(email: $email, password: $password)';
}


}

/// @nodoc
abstract mixin class $LoginRequestCopyWith<$Res>  {
  factory $LoginRequestCopyWith(LoginRequest value, $Res Function(LoginRequest) _then) = _$LoginRequestCopyWithImpl;
@useResult
$Res call({
 String email, String password
});




}
/// @nodoc
class _$LoginRequestCopyWithImpl<$Res>
    implements $LoginRequestCopyWith<$Res> {
  _$LoginRequestCopyWithImpl(this._self, this._then);

  final LoginRequest _self;
  final $Res Function(LoginRequest) _then;

/// Create a copy of LoginRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? email = null,Object? password = null,}) {
  return _then(_self.copyWith(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [LoginRequest].
extension LoginRequestPatterns on LoginRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LoginRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LoginRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LoginRequest value)  $default,){
final _that = this;
switch (_that) {
case _LoginRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LoginRequest value)?  $default,){
final _that = this;
switch (_that) {
case _LoginRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String email,  String password)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LoginRequest() when $default != null:
return $default(_that.email,_that.password);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String email,  String password)  $default,) {final _that = this;
switch (_that) {
case _LoginRequest():
return $default(_that.email,_that.password);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String email,  String password)?  $default,) {final _that = this;
switch (_that) {
case _LoginRequest() when $default != null:
return $default(_that.email,_that.password);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LoginRequest implements LoginRequest {
  const _LoginRequest({required this.email, required this.password});
  factory _LoginRequest.fromJson(Map<String, dynamic> json) => _$LoginRequestFromJson(json);

@override final  String email;
@override final  String password;

/// Create a copy of LoginRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LoginRequestCopyWith<_LoginRequest> get copyWith => __$LoginRequestCopyWithImpl<_LoginRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LoginRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LoginRequest&&(identical(other.email, email) || other.email == email)&&(identical(other.password, password) || other.password == password));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,email,password);

@override
String toString() {
  return 'LoginRequest(email: $email, password: $password)';
}


}

/// @nodoc
abstract mixin class _$LoginRequestCopyWith<$Res> implements $LoginRequestCopyWith<$Res> {
  factory _$LoginRequestCopyWith(_LoginRequest value, $Res Function(_LoginRequest) _then) = __$LoginRequestCopyWithImpl;
@override @useResult
$Res call({
 String email, String password
});




}
/// @nodoc
class __$LoginRequestCopyWithImpl<$Res>
    implements _$LoginRequestCopyWith<$Res> {
  __$LoginRequestCopyWithImpl(this._self, this._then);

  final _LoginRequest _self;
  final $Res Function(_LoginRequest) _then;

/// Create a copy of LoginRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? email = null,Object? password = null,}) {
  return _then(_LoginRequest(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$AuthResponse {

 String get token; AuthCustomer get customer;
/// Create a copy of AuthResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthResponseCopyWith<AuthResponse> get copyWith => _$AuthResponseCopyWithImpl<AuthResponse>(this as AuthResponse, _$identity);

  /// Serializes this AuthResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthResponse&&(identical(other.token, token) || other.token == token)&&(identical(other.customer, customer) || other.customer == customer));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,token,customer);

@override
String toString() {
  return 'AuthResponse(token: $token, customer: $customer)';
}


}

/// @nodoc
abstract mixin class $AuthResponseCopyWith<$Res>  {
  factory $AuthResponseCopyWith(AuthResponse value, $Res Function(AuthResponse) _then) = _$AuthResponseCopyWithImpl;
@useResult
$Res call({
 String token, AuthCustomer customer
});


$AuthCustomerCopyWith<$Res> get customer;

}
/// @nodoc
class _$AuthResponseCopyWithImpl<$Res>
    implements $AuthResponseCopyWith<$Res> {
  _$AuthResponseCopyWithImpl(this._self, this._then);

  final AuthResponse _self;
  final $Res Function(AuthResponse) _then;

/// Create a copy of AuthResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? token = null,Object? customer = null,}) {
  return _then(_self.copyWith(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,customer: null == customer ? _self.customer : customer // ignore: cast_nullable_to_non_nullable
as AuthCustomer,
  ));
}
/// Create a copy of AuthResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AuthCustomerCopyWith<$Res> get customer {
  
  return $AuthCustomerCopyWith<$Res>(_self.customer, (value) {
    return _then(_self.copyWith(customer: value));
  });
}
}


/// Adds pattern-matching-related methods to [AuthResponse].
extension AuthResponsePatterns on AuthResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AuthResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AuthResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AuthResponse value)  $default,){
final _that = this;
switch (_that) {
case _AuthResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AuthResponse value)?  $default,){
final _that = this;
switch (_that) {
case _AuthResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String token,  AuthCustomer customer)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AuthResponse() when $default != null:
return $default(_that.token,_that.customer);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String token,  AuthCustomer customer)  $default,) {final _that = this;
switch (_that) {
case _AuthResponse():
return $default(_that.token,_that.customer);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String token,  AuthCustomer customer)?  $default,) {final _that = this;
switch (_that) {
case _AuthResponse() when $default != null:
return $default(_that.token,_that.customer);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AuthResponse implements AuthResponse {
  const _AuthResponse({required this.token, required this.customer});
  factory _AuthResponse.fromJson(Map<String, dynamic> json) => _$AuthResponseFromJson(json);

@override final  String token;
@override final  AuthCustomer customer;

/// Create a copy of AuthResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AuthResponseCopyWith<_AuthResponse> get copyWith => __$AuthResponseCopyWithImpl<_AuthResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AuthResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AuthResponse&&(identical(other.token, token) || other.token == token)&&(identical(other.customer, customer) || other.customer == customer));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,token,customer);

@override
String toString() {
  return 'AuthResponse(token: $token, customer: $customer)';
}


}

/// @nodoc
abstract mixin class _$AuthResponseCopyWith<$Res> implements $AuthResponseCopyWith<$Res> {
  factory _$AuthResponseCopyWith(_AuthResponse value, $Res Function(_AuthResponse) _then) = __$AuthResponseCopyWithImpl;
@override @useResult
$Res call({
 String token, AuthCustomer customer
});


@override $AuthCustomerCopyWith<$Res> get customer;

}
/// @nodoc
class __$AuthResponseCopyWithImpl<$Res>
    implements _$AuthResponseCopyWith<$Res> {
  __$AuthResponseCopyWithImpl(this._self, this._then);

  final _AuthResponse _self;
  final $Res Function(_AuthResponse) _then;

/// Create a copy of AuthResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? token = null,Object? customer = null,}) {
  return _then(_AuthResponse(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,customer: null == customer ? _self.customer : customer // ignore: cast_nullable_to_non_nullable
as AuthCustomer,
  ));
}

/// Create a copy of AuthResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AuthCustomerCopyWith<$Res> get customer {
  
  return $AuthCustomerCopyWith<$Res>(_self.customer, (value) {
    return _then(_self.copyWith(customer: value));
  });
}
}


/// @nodoc
mixin _$AuthCustomer {

 int get id; String get firstName;
/// Create a copy of AuthCustomer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthCustomerCopyWith<AuthCustomer> get copyWith => _$AuthCustomerCopyWithImpl<AuthCustomer>(this as AuthCustomer, _$identity);

  /// Serializes this AuthCustomer to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthCustomer&&(identical(other.id, id) || other.id == id)&&(identical(other.firstName, firstName) || other.firstName == firstName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,firstName);

@override
String toString() {
  return 'AuthCustomer(id: $id, firstName: $firstName)';
}


}

/// @nodoc
abstract mixin class $AuthCustomerCopyWith<$Res>  {
  factory $AuthCustomerCopyWith(AuthCustomer value, $Res Function(AuthCustomer) _then) = _$AuthCustomerCopyWithImpl;
@useResult
$Res call({
 int id, String firstName
});




}
/// @nodoc
class _$AuthCustomerCopyWithImpl<$Res>
    implements $AuthCustomerCopyWith<$Res> {
  _$AuthCustomerCopyWithImpl(this._self, this._then);

  final AuthCustomer _self;
  final $Res Function(AuthCustomer) _then;

/// Create a copy of AuthCustomer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? firstName = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,firstName: null == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [AuthCustomer].
extension AuthCustomerPatterns on AuthCustomer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AuthCustomer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AuthCustomer() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AuthCustomer value)  $default,){
final _that = this;
switch (_that) {
case _AuthCustomer():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AuthCustomer value)?  $default,){
final _that = this;
switch (_that) {
case _AuthCustomer() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String firstName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AuthCustomer() when $default != null:
return $default(_that.id,_that.firstName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String firstName)  $default,) {final _that = this;
switch (_that) {
case _AuthCustomer():
return $default(_that.id,_that.firstName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String firstName)?  $default,) {final _that = this;
switch (_that) {
case _AuthCustomer() when $default != null:
return $default(_that.id,_that.firstName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AuthCustomer implements AuthCustomer {
  const _AuthCustomer({required this.id, required this.firstName});
  factory _AuthCustomer.fromJson(Map<String, dynamic> json) => _$AuthCustomerFromJson(json);

@override final  int id;
@override final  String firstName;

/// Create a copy of AuthCustomer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AuthCustomerCopyWith<_AuthCustomer> get copyWith => __$AuthCustomerCopyWithImpl<_AuthCustomer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AuthCustomerToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AuthCustomer&&(identical(other.id, id) || other.id == id)&&(identical(other.firstName, firstName) || other.firstName == firstName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,firstName);

@override
String toString() {
  return 'AuthCustomer(id: $id, firstName: $firstName)';
}


}

/// @nodoc
abstract mixin class _$AuthCustomerCopyWith<$Res> implements $AuthCustomerCopyWith<$Res> {
  factory _$AuthCustomerCopyWith(_AuthCustomer value, $Res Function(_AuthCustomer) _then) = __$AuthCustomerCopyWithImpl;
@override @useResult
$Res call({
 int id, String firstName
});




}
/// @nodoc
class __$AuthCustomerCopyWithImpl<$Res>
    implements _$AuthCustomerCopyWith<$Res> {
  __$AuthCustomerCopyWithImpl(this._self, this._then);

  final _AuthCustomer _self;
  final $Res Function(_AuthCustomer) _then;

/// Create a copy of AuthCustomer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? firstName = null,}) {
  return _then(_AuthCustomer(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,firstName: null == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$Customer {

 int get id; String get firstName; String get lastName; String get email; String get telephone; int? get defaultLocationId;
/// Create a copy of Customer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CustomerCopyWith<Customer> get copyWith => _$CustomerCopyWithImpl<Customer>(this as Customer, _$identity);

  /// Serializes this Customer to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Customer&&(identical(other.id, id) || other.id == id)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.email, email) || other.email == email)&&(identical(other.telephone, telephone) || other.telephone == telephone)&&(identical(other.defaultLocationId, defaultLocationId) || other.defaultLocationId == defaultLocationId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,firstName,lastName,email,telephone,defaultLocationId);

@override
String toString() {
  return 'Customer(id: $id, firstName: $firstName, lastName: $lastName, email: $email, telephone: $telephone, defaultLocationId: $defaultLocationId)';
}


}

/// @nodoc
abstract mixin class $CustomerCopyWith<$Res>  {
  factory $CustomerCopyWith(Customer value, $Res Function(Customer) _then) = _$CustomerCopyWithImpl;
@useResult
$Res call({
 int id, String firstName, String lastName, String email, String telephone, int? defaultLocationId
});




}
/// @nodoc
class _$CustomerCopyWithImpl<$Res>
    implements $CustomerCopyWith<$Res> {
  _$CustomerCopyWithImpl(this._self, this._then);

  final Customer _self;
  final $Res Function(Customer) _then;

/// Create a copy of Customer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? firstName = null,Object? lastName = null,Object? email = null,Object? telephone = null,Object? defaultLocationId = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,firstName: null == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String,lastName: null == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,telephone: null == telephone ? _self.telephone : telephone // ignore: cast_nullable_to_non_nullable
as String,defaultLocationId: freezed == defaultLocationId ? _self.defaultLocationId : defaultLocationId // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [Customer].
extension CustomerPatterns on Customer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Customer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Customer() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Customer value)  $default,){
final _that = this;
switch (_that) {
case _Customer():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Customer value)?  $default,){
final _that = this;
switch (_that) {
case _Customer() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String firstName,  String lastName,  String email,  String telephone,  int? defaultLocationId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Customer() when $default != null:
return $default(_that.id,_that.firstName,_that.lastName,_that.email,_that.telephone,_that.defaultLocationId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String firstName,  String lastName,  String email,  String telephone,  int? defaultLocationId)  $default,) {final _that = this;
switch (_that) {
case _Customer():
return $default(_that.id,_that.firstName,_that.lastName,_that.email,_that.telephone,_that.defaultLocationId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String firstName,  String lastName,  String email,  String telephone,  int? defaultLocationId)?  $default,) {final _that = this;
switch (_that) {
case _Customer() when $default != null:
return $default(_that.id,_that.firstName,_that.lastName,_that.email,_that.telephone,_that.defaultLocationId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Customer extends Customer {
  const _Customer({required this.id, required this.firstName, required this.lastName, required this.email, required this.telephone, this.defaultLocationId}): super._();
  factory _Customer.fromJson(Map<String, dynamic> json) => _$CustomerFromJson(json);

@override final  int id;
@override final  String firstName;
@override final  String lastName;
@override final  String email;
@override final  String telephone;
@override final  int? defaultLocationId;

/// Create a copy of Customer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CustomerCopyWith<_Customer> get copyWith => __$CustomerCopyWithImpl<_Customer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CustomerToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Customer&&(identical(other.id, id) || other.id == id)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.email, email) || other.email == email)&&(identical(other.telephone, telephone) || other.telephone == telephone)&&(identical(other.defaultLocationId, defaultLocationId) || other.defaultLocationId == defaultLocationId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,firstName,lastName,email,telephone,defaultLocationId);

@override
String toString() {
  return 'Customer(id: $id, firstName: $firstName, lastName: $lastName, email: $email, telephone: $telephone, defaultLocationId: $defaultLocationId)';
}


}

/// @nodoc
abstract mixin class _$CustomerCopyWith<$Res> implements $CustomerCopyWith<$Res> {
  factory _$CustomerCopyWith(_Customer value, $Res Function(_Customer) _then) = __$CustomerCopyWithImpl;
@override @useResult
$Res call({
 int id, String firstName, String lastName, String email, String telephone, int? defaultLocationId
});




}
/// @nodoc
class __$CustomerCopyWithImpl<$Res>
    implements _$CustomerCopyWith<$Res> {
  __$CustomerCopyWithImpl(this._self, this._then);

  final _Customer _self;
  final $Res Function(_Customer) _then;

/// Create a copy of Customer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? firstName = null,Object? lastName = null,Object? email = null,Object? telephone = null,Object? defaultLocationId = freezed,}) {
  return _then(_Customer(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,firstName: null == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String,lastName: null == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,telephone: null == telephone ? _self.telephone : telephone // ignore: cast_nullable_to_non_nullable
as String,defaultLocationId: freezed == defaultLocationId ? _self.defaultLocationId : defaultLocationId // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$PushTokenRequest {

 String get fcmToken;/// Sözleşmede yalnızca `android` geçerlidir (`docs/openapi.yaml`).
 String get platform;
/// Create a copy of PushTokenRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PushTokenRequestCopyWith<PushTokenRequest> get copyWith => _$PushTokenRequestCopyWithImpl<PushTokenRequest>(this as PushTokenRequest, _$identity);

  /// Serializes this PushTokenRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PushTokenRequest&&(identical(other.fcmToken, fcmToken) || other.fcmToken == fcmToken)&&(identical(other.platform, platform) || other.platform == platform));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fcmToken,platform);

@override
String toString() {
  return 'PushTokenRequest(fcmToken: $fcmToken, platform: $platform)';
}


}

/// @nodoc
abstract mixin class $PushTokenRequestCopyWith<$Res>  {
  factory $PushTokenRequestCopyWith(PushTokenRequest value, $Res Function(PushTokenRequest) _then) = _$PushTokenRequestCopyWithImpl;
@useResult
$Res call({
 String fcmToken, String platform
});




}
/// @nodoc
class _$PushTokenRequestCopyWithImpl<$Res>
    implements $PushTokenRequestCopyWith<$Res> {
  _$PushTokenRequestCopyWithImpl(this._self, this._then);

  final PushTokenRequest _self;
  final $Res Function(PushTokenRequest) _then;

/// Create a copy of PushTokenRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fcmToken = null,Object? platform = null,}) {
  return _then(_self.copyWith(
fcmToken: null == fcmToken ? _self.fcmToken : fcmToken // ignore: cast_nullable_to_non_nullable
as String,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PushTokenRequest].
extension PushTokenRequestPatterns on PushTokenRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PushTokenRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PushTokenRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PushTokenRequest value)  $default,){
final _that = this;
switch (_that) {
case _PushTokenRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PushTokenRequest value)?  $default,){
final _that = this;
switch (_that) {
case _PushTokenRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String fcmToken,  String platform)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PushTokenRequest() when $default != null:
return $default(_that.fcmToken,_that.platform);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String fcmToken,  String platform)  $default,) {final _that = this;
switch (_that) {
case _PushTokenRequest():
return $default(_that.fcmToken,_that.platform);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String fcmToken,  String platform)?  $default,) {final _that = this;
switch (_that) {
case _PushTokenRequest() when $default != null:
return $default(_that.fcmToken,_that.platform);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PushTokenRequest implements PushTokenRequest {
  const _PushTokenRequest({required this.fcmToken, this.platform = 'android'});
  factory _PushTokenRequest.fromJson(Map<String, dynamic> json) => _$PushTokenRequestFromJson(json);

@override final  String fcmToken;
/// Sözleşmede yalnızca `android` geçerlidir (`docs/openapi.yaml`).
@override@JsonKey() final  String platform;

/// Create a copy of PushTokenRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PushTokenRequestCopyWith<_PushTokenRequest> get copyWith => __$PushTokenRequestCopyWithImpl<_PushTokenRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PushTokenRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PushTokenRequest&&(identical(other.fcmToken, fcmToken) || other.fcmToken == fcmToken)&&(identical(other.platform, platform) || other.platform == platform));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fcmToken,platform);

@override
String toString() {
  return 'PushTokenRequest(fcmToken: $fcmToken, platform: $platform)';
}


}

/// @nodoc
abstract mixin class _$PushTokenRequestCopyWith<$Res> implements $PushTokenRequestCopyWith<$Res> {
  factory _$PushTokenRequestCopyWith(_PushTokenRequest value, $Res Function(_PushTokenRequest) _then) = __$PushTokenRequestCopyWithImpl;
@override @useResult
$Res call({
 String fcmToken, String platform
});




}
/// @nodoc
class __$PushTokenRequestCopyWithImpl<$Res>
    implements _$PushTokenRequestCopyWith<$Res> {
  __$PushTokenRequestCopyWithImpl(this._self, this._then);

  final _PushTokenRequest _self;
  final $Res Function(_PushTokenRequest) _then;

/// Create a copy of PushTokenRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fcmToken = null,Object? platform = null,}) {
  return _then(_PushTokenRequest(
fcmToken: null == fcmToken ? _self.fcmToken : fcmToken // ignore: cast_nullable_to_non_nullable
as String,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
