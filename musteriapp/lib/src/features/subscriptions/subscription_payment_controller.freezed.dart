// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'subscription_payment_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SubscriptionPaymentState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionPaymentState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SubscriptionPaymentState()';
}


}

/// @nodoc
class $SubscriptionPaymentStateCopyWith<$Res>  {
$SubscriptionPaymentStateCopyWith(SubscriptionPaymentState _, $Res Function(SubscriptionPaymentState) __);
}


/// Adds pattern-matching-related methods to [SubscriptionPaymentState].
extension SubscriptionPaymentStatePatterns on SubscriptionPaymentState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( SubscriptionPaymentIdle value)?  idle,TResult Function( SubscriptionPaymentStarting value)?  starting,TResult Function( SubscriptionPaymentAwaitingOtp value)?  awaitingOtp,TResult Function( SubscriptionPaymentVerifying value)?  verifying,TResult Function( SubscriptionPaymentPolling value)?  polling,TResult Function( SubscriptionPaymentSucceeded value)?  succeeded,TResult Function( SubscriptionPaymentFailed value)?  failed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case SubscriptionPaymentIdle() when idle != null:
return idle(_that);case SubscriptionPaymentStarting() when starting != null:
return starting(_that);case SubscriptionPaymentAwaitingOtp() when awaitingOtp != null:
return awaitingOtp(_that);case SubscriptionPaymentVerifying() when verifying != null:
return verifying(_that);case SubscriptionPaymentPolling() when polling != null:
return polling(_that);case SubscriptionPaymentSucceeded() when succeeded != null:
return succeeded(_that);case SubscriptionPaymentFailed() when failed != null:
return failed(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( SubscriptionPaymentIdle value)  idle,required TResult Function( SubscriptionPaymentStarting value)  starting,required TResult Function( SubscriptionPaymentAwaitingOtp value)  awaitingOtp,required TResult Function( SubscriptionPaymentVerifying value)  verifying,required TResult Function( SubscriptionPaymentPolling value)  polling,required TResult Function( SubscriptionPaymentSucceeded value)  succeeded,required TResult Function( SubscriptionPaymentFailed value)  failed,}){
final _that = this;
switch (_that) {
case SubscriptionPaymentIdle():
return idle(_that);case SubscriptionPaymentStarting():
return starting(_that);case SubscriptionPaymentAwaitingOtp():
return awaitingOtp(_that);case SubscriptionPaymentVerifying():
return verifying(_that);case SubscriptionPaymentPolling():
return polling(_that);case SubscriptionPaymentSucceeded():
return succeeded(_that);case SubscriptionPaymentFailed():
return failed(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( SubscriptionPaymentIdle value)?  idle,TResult? Function( SubscriptionPaymentStarting value)?  starting,TResult? Function( SubscriptionPaymentAwaitingOtp value)?  awaitingOtp,TResult? Function( SubscriptionPaymentVerifying value)?  verifying,TResult? Function( SubscriptionPaymentPolling value)?  polling,TResult? Function( SubscriptionPaymentSucceeded value)?  succeeded,TResult? Function( SubscriptionPaymentFailed value)?  failed,}){
final _that = this;
switch (_that) {
case SubscriptionPaymentIdle() when idle != null:
return idle(_that);case SubscriptionPaymentStarting() when starting != null:
return starting(_that);case SubscriptionPaymentAwaitingOtp() when awaitingOtp != null:
return awaitingOtp(_that);case SubscriptionPaymentVerifying() when verifying != null:
return verifying(_that);case SubscriptionPaymentPolling() when polling != null:
return polling(_that);case SubscriptionPaymentSucceeded() when succeeded != null:
return succeeded(_that);case SubscriptionPaymentFailed() when failed != null:
return failed(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  idle,TResult Function()?  starting,TResult Function( SubscriptionPayment payment,  ApiException? error)?  awaitingOtp,TResult Function( SubscriptionPayment payment)?  verifying,TResult Function( SubscriptionPayment payment,  int attempt,  int total)?  polling,TResult Function( SubscriptionPayment payment)?  succeeded,TResult Function( SubscriptionPaymentFailure reason,  SubscriptionPayment? payment,  ApiException? error)?  failed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case SubscriptionPaymentIdle() when idle != null:
return idle();case SubscriptionPaymentStarting() when starting != null:
return starting();case SubscriptionPaymentAwaitingOtp() when awaitingOtp != null:
return awaitingOtp(_that.payment,_that.error);case SubscriptionPaymentVerifying() when verifying != null:
return verifying(_that.payment);case SubscriptionPaymentPolling() when polling != null:
return polling(_that.payment,_that.attempt,_that.total);case SubscriptionPaymentSucceeded() when succeeded != null:
return succeeded(_that.payment);case SubscriptionPaymentFailed() when failed != null:
return failed(_that.reason,_that.payment,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  idle,required TResult Function()  starting,required TResult Function( SubscriptionPayment payment,  ApiException? error)  awaitingOtp,required TResult Function( SubscriptionPayment payment)  verifying,required TResult Function( SubscriptionPayment payment,  int attempt,  int total)  polling,required TResult Function( SubscriptionPayment payment)  succeeded,required TResult Function( SubscriptionPaymentFailure reason,  SubscriptionPayment? payment,  ApiException? error)  failed,}) {final _that = this;
switch (_that) {
case SubscriptionPaymentIdle():
return idle();case SubscriptionPaymentStarting():
return starting();case SubscriptionPaymentAwaitingOtp():
return awaitingOtp(_that.payment,_that.error);case SubscriptionPaymentVerifying():
return verifying(_that.payment);case SubscriptionPaymentPolling():
return polling(_that.payment,_that.attempt,_that.total);case SubscriptionPaymentSucceeded():
return succeeded(_that.payment);case SubscriptionPaymentFailed():
return failed(_that.reason,_that.payment,_that.error);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  idle,TResult? Function()?  starting,TResult? Function( SubscriptionPayment payment,  ApiException? error)?  awaitingOtp,TResult? Function( SubscriptionPayment payment)?  verifying,TResult? Function( SubscriptionPayment payment,  int attempt,  int total)?  polling,TResult? Function( SubscriptionPayment payment)?  succeeded,TResult? Function( SubscriptionPaymentFailure reason,  SubscriptionPayment? payment,  ApiException? error)?  failed,}) {final _that = this;
switch (_that) {
case SubscriptionPaymentIdle() when idle != null:
return idle();case SubscriptionPaymentStarting() when starting != null:
return starting();case SubscriptionPaymentAwaitingOtp() when awaitingOtp != null:
return awaitingOtp(_that.payment,_that.error);case SubscriptionPaymentVerifying() when verifying != null:
return verifying(_that.payment);case SubscriptionPaymentPolling() when polling != null:
return polling(_that.payment,_that.attempt,_that.total);case SubscriptionPaymentSucceeded() when succeeded != null:
return succeeded(_that.payment);case SubscriptionPaymentFailed() when failed != null:
return failed(_that.reason,_that.payment,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class SubscriptionPaymentIdle extends SubscriptionPaymentState {
  const SubscriptionPaymentIdle(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionPaymentIdle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SubscriptionPaymentState.idle()';
}


}




/// @nodoc


class SubscriptionPaymentStarting extends SubscriptionPaymentState {
  const SubscriptionPaymentStarting(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionPaymentStarting);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SubscriptionPaymentState.starting()';
}


}




/// @nodoc


class SubscriptionPaymentAwaitingOtp extends SubscriptionPaymentState {
  const SubscriptionPaymentAwaitingOtp({required this.payment, this.error}): super._();
  

 final  SubscriptionPayment payment;
 final  ApiException? error;

/// Create a copy of SubscriptionPaymentState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubscriptionPaymentAwaitingOtpCopyWith<SubscriptionPaymentAwaitingOtp> get copyWith => _$SubscriptionPaymentAwaitingOtpCopyWithImpl<SubscriptionPaymentAwaitingOtp>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionPaymentAwaitingOtp&&(identical(other.payment, payment) || other.payment == payment)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,payment,error);

@override
String toString() {
  return 'SubscriptionPaymentState.awaitingOtp(payment: $payment, error: $error)';
}


}

/// @nodoc
abstract mixin class $SubscriptionPaymentAwaitingOtpCopyWith<$Res> implements $SubscriptionPaymentStateCopyWith<$Res> {
  factory $SubscriptionPaymentAwaitingOtpCopyWith(SubscriptionPaymentAwaitingOtp value, $Res Function(SubscriptionPaymentAwaitingOtp) _then) = _$SubscriptionPaymentAwaitingOtpCopyWithImpl;
@useResult
$Res call({
 SubscriptionPayment payment, ApiException? error
});


$SubscriptionPaymentCopyWith<$Res> get payment;

}
/// @nodoc
class _$SubscriptionPaymentAwaitingOtpCopyWithImpl<$Res>
    implements $SubscriptionPaymentAwaitingOtpCopyWith<$Res> {
  _$SubscriptionPaymentAwaitingOtpCopyWithImpl(this._self, this._then);

  final SubscriptionPaymentAwaitingOtp _self;
  final $Res Function(SubscriptionPaymentAwaitingOtp) _then;

/// Create a copy of SubscriptionPaymentState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? payment = null,Object? error = freezed,}) {
  return _then(SubscriptionPaymentAwaitingOtp(
payment: null == payment ? _self.payment : payment // ignore: cast_nullable_to_non_nullable
as SubscriptionPayment,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ApiException?,
  ));
}

/// Create a copy of SubscriptionPaymentState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SubscriptionPaymentCopyWith<$Res> get payment {
  
  return $SubscriptionPaymentCopyWith<$Res>(_self.payment, (value) {
    return _then(_self.copyWith(payment: value));
  });
}
}

/// @nodoc


class SubscriptionPaymentVerifying extends SubscriptionPaymentState {
  const SubscriptionPaymentVerifying({required this.payment}): super._();
  

 final  SubscriptionPayment payment;

/// Create a copy of SubscriptionPaymentState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubscriptionPaymentVerifyingCopyWith<SubscriptionPaymentVerifying> get copyWith => _$SubscriptionPaymentVerifyingCopyWithImpl<SubscriptionPaymentVerifying>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionPaymentVerifying&&(identical(other.payment, payment) || other.payment == payment));
}


@override
int get hashCode => Object.hash(runtimeType,payment);

@override
String toString() {
  return 'SubscriptionPaymentState.verifying(payment: $payment)';
}


}

/// @nodoc
abstract mixin class $SubscriptionPaymentVerifyingCopyWith<$Res> implements $SubscriptionPaymentStateCopyWith<$Res> {
  factory $SubscriptionPaymentVerifyingCopyWith(SubscriptionPaymentVerifying value, $Res Function(SubscriptionPaymentVerifying) _then) = _$SubscriptionPaymentVerifyingCopyWithImpl;
@useResult
$Res call({
 SubscriptionPayment payment
});


$SubscriptionPaymentCopyWith<$Res> get payment;

}
/// @nodoc
class _$SubscriptionPaymentVerifyingCopyWithImpl<$Res>
    implements $SubscriptionPaymentVerifyingCopyWith<$Res> {
  _$SubscriptionPaymentVerifyingCopyWithImpl(this._self, this._then);

  final SubscriptionPaymentVerifying _self;
  final $Res Function(SubscriptionPaymentVerifying) _then;

/// Create a copy of SubscriptionPaymentState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? payment = null,}) {
  return _then(SubscriptionPaymentVerifying(
payment: null == payment ? _self.payment : payment // ignore: cast_nullable_to_non_nullable
as SubscriptionPayment,
  ));
}

/// Create a copy of SubscriptionPaymentState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SubscriptionPaymentCopyWith<$Res> get payment {
  
  return $SubscriptionPaymentCopyWith<$Res>(_self.payment, (value) {
    return _then(_self.copyWith(payment: value));
  });
}
}

/// @nodoc


class SubscriptionPaymentPolling extends SubscriptionPaymentState {
  const SubscriptionPaymentPolling({required this.payment, required this.attempt, required this.total}): super._();
  

 final  SubscriptionPayment payment;
 final  int attempt;
 final  int total;

/// Create a copy of SubscriptionPaymentState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubscriptionPaymentPollingCopyWith<SubscriptionPaymentPolling> get copyWith => _$SubscriptionPaymentPollingCopyWithImpl<SubscriptionPaymentPolling>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionPaymentPolling&&(identical(other.payment, payment) || other.payment == payment)&&(identical(other.attempt, attempt) || other.attempt == attempt)&&(identical(other.total, total) || other.total == total));
}


@override
int get hashCode => Object.hash(runtimeType,payment,attempt,total);

@override
String toString() {
  return 'SubscriptionPaymentState.polling(payment: $payment, attempt: $attempt, total: $total)';
}


}

/// @nodoc
abstract mixin class $SubscriptionPaymentPollingCopyWith<$Res> implements $SubscriptionPaymentStateCopyWith<$Res> {
  factory $SubscriptionPaymentPollingCopyWith(SubscriptionPaymentPolling value, $Res Function(SubscriptionPaymentPolling) _then) = _$SubscriptionPaymentPollingCopyWithImpl;
@useResult
$Res call({
 SubscriptionPayment payment, int attempt, int total
});


$SubscriptionPaymentCopyWith<$Res> get payment;

}
/// @nodoc
class _$SubscriptionPaymentPollingCopyWithImpl<$Res>
    implements $SubscriptionPaymentPollingCopyWith<$Res> {
  _$SubscriptionPaymentPollingCopyWithImpl(this._self, this._then);

  final SubscriptionPaymentPolling _self;
  final $Res Function(SubscriptionPaymentPolling) _then;

/// Create a copy of SubscriptionPaymentState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? payment = null,Object? attempt = null,Object? total = null,}) {
  return _then(SubscriptionPaymentPolling(
payment: null == payment ? _self.payment : payment // ignore: cast_nullable_to_non_nullable
as SubscriptionPayment,attempt: null == attempt ? _self.attempt : attempt // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of SubscriptionPaymentState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SubscriptionPaymentCopyWith<$Res> get payment {
  
  return $SubscriptionPaymentCopyWith<$Res>(_self.payment, (value) {
    return _then(_self.copyWith(payment: value));
  });
}
}

/// @nodoc


class SubscriptionPaymentSucceeded extends SubscriptionPaymentState {
  const SubscriptionPaymentSucceeded({required this.payment}): super._();
  

 final  SubscriptionPayment payment;

/// Create a copy of SubscriptionPaymentState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubscriptionPaymentSucceededCopyWith<SubscriptionPaymentSucceeded> get copyWith => _$SubscriptionPaymentSucceededCopyWithImpl<SubscriptionPaymentSucceeded>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionPaymentSucceeded&&(identical(other.payment, payment) || other.payment == payment));
}


@override
int get hashCode => Object.hash(runtimeType,payment);

@override
String toString() {
  return 'SubscriptionPaymentState.succeeded(payment: $payment)';
}


}

/// @nodoc
abstract mixin class $SubscriptionPaymentSucceededCopyWith<$Res> implements $SubscriptionPaymentStateCopyWith<$Res> {
  factory $SubscriptionPaymentSucceededCopyWith(SubscriptionPaymentSucceeded value, $Res Function(SubscriptionPaymentSucceeded) _then) = _$SubscriptionPaymentSucceededCopyWithImpl;
@useResult
$Res call({
 SubscriptionPayment payment
});


$SubscriptionPaymentCopyWith<$Res> get payment;

}
/// @nodoc
class _$SubscriptionPaymentSucceededCopyWithImpl<$Res>
    implements $SubscriptionPaymentSucceededCopyWith<$Res> {
  _$SubscriptionPaymentSucceededCopyWithImpl(this._self, this._then);

  final SubscriptionPaymentSucceeded _self;
  final $Res Function(SubscriptionPaymentSucceeded) _then;

/// Create a copy of SubscriptionPaymentState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? payment = null,}) {
  return _then(SubscriptionPaymentSucceeded(
payment: null == payment ? _self.payment : payment // ignore: cast_nullable_to_non_nullable
as SubscriptionPayment,
  ));
}

/// Create a copy of SubscriptionPaymentState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SubscriptionPaymentCopyWith<$Res> get payment {
  
  return $SubscriptionPaymentCopyWith<$Res>(_self.payment, (value) {
    return _then(_self.copyWith(payment: value));
  });
}
}

/// @nodoc


class SubscriptionPaymentFailed extends SubscriptionPaymentState {
  const SubscriptionPaymentFailed({required this.reason, this.payment, this.error}): super._();
  

 final  SubscriptionPaymentFailure reason;
 final  SubscriptionPayment? payment;
 final  ApiException? error;

/// Create a copy of SubscriptionPaymentState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubscriptionPaymentFailedCopyWith<SubscriptionPaymentFailed> get copyWith => _$SubscriptionPaymentFailedCopyWithImpl<SubscriptionPaymentFailed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionPaymentFailed&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.payment, payment) || other.payment == payment)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,reason,payment,error);

@override
String toString() {
  return 'SubscriptionPaymentState.failed(reason: $reason, payment: $payment, error: $error)';
}


}

/// @nodoc
abstract mixin class $SubscriptionPaymentFailedCopyWith<$Res> implements $SubscriptionPaymentStateCopyWith<$Res> {
  factory $SubscriptionPaymentFailedCopyWith(SubscriptionPaymentFailed value, $Res Function(SubscriptionPaymentFailed) _then) = _$SubscriptionPaymentFailedCopyWithImpl;
@useResult
$Res call({
 SubscriptionPaymentFailure reason, SubscriptionPayment? payment, ApiException? error
});


$SubscriptionPaymentCopyWith<$Res>? get payment;

}
/// @nodoc
class _$SubscriptionPaymentFailedCopyWithImpl<$Res>
    implements $SubscriptionPaymentFailedCopyWith<$Res> {
  _$SubscriptionPaymentFailedCopyWithImpl(this._self, this._then);

  final SubscriptionPaymentFailed _self;
  final $Res Function(SubscriptionPaymentFailed) _then;

/// Create a copy of SubscriptionPaymentState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? reason = null,Object? payment = freezed,Object? error = freezed,}) {
  return _then(SubscriptionPaymentFailed(
reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as SubscriptionPaymentFailure,payment: freezed == payment ? _self.payment : payment // ignore: cast_nullable_to_non_nullable
as SubscriptionPayment?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ApiException?,
  ));
}

/// Create a copy of SubscriptionPaymentState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SubscriptionPaymentCopyWith<$Res>? get payment {
    if (_self.payment == null) {
    return null;
  }

  return $SubscriptionPaymentCopyWith<$Res>(_self.payment!, (value) {
    return _then(_self.copyWith(payment: value));
  });
}
}

// dart format on
