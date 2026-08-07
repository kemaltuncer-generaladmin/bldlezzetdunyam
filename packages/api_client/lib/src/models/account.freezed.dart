// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'account.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AccountSummary {

/// Güncel bakiye (kuruş, işaretli). Pozitif = borç.
 int get balance; String get currency; DateTime get asOf;
/// Create a copy of AccountSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AccountSummaryCopyWith<AccountSummary> get copyWith => _$AccountSummaryCopyWithImpl<AccountSummary>(this as AccountSummary, _$identity);

  /// Serializes this AccountSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AccountSummary&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.asOf, asOf) || other.asOf == asOf));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,balance,currency,asOf);

@override
String toString() {
  return 'AccountSummary(balance: $balance, currency: $currency, asOf: $asOf)';
}


}

/// @nodoc
abstract mixin class $AccountSummaryCopyWith<$Res>  {
  factory $AccountSummaryCopyWith(AccountSummary value, $Res Function(AccountSummary) _then) = _$AccountSummaryCopyWithImpl;
@useResult
$Res call({
 int balance, String currency, DateTime asOf
});




}
/// @nodoc
class _$AccountSummaryCopyWithImpl<$Res>
    implements $AccountSummaryCopyWith<$Res> {
  _$AccountSummaryCopyWithImpl(this._self, this._then);

  final AccountSummary _self;
  final $Res Function(AccountSummary) _then;

/// Create a copy of AccountSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? balance = null,Object? currency = null,Object? asOf = null,}) {
  return _then(_self.copyWith(
balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as int,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,asOf: null == asOf ? _self.asOf : asOf // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [AccountSummary].
extension AccountSummaryPatterns on AccountSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AccountSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AccountSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AccountSummary value)  $default,){
final _that = this;
switch (_that) {
case _AccountSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AccountSummary value)?  $default,){
final _that = this;
switch (_that) {
case _AccountSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int balance,  String currency,  DateTime asOf)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AccountSummary() when $default != null:
return $default(_that.balance,_that.currency,_that.asOf);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int balance,  String currency,  DateTime asOf)  $default,) {final _that = this;
switch (_that) {
case _AccountSummary():
return $default(_that.balance,_that.currency,_that.asOf);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int balance,  String currency,  DateTime asOf)?  $default,) {final _that = this;
switch (_that) {
case _AccountSummary() when $default != null:
return $default(_that.balance,_that.currency,_that.asOf);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AccountSummary extends AccountSummary {
  const _AccountSummary({required this.balance, required this.currency, required this.asOf}): super._();
  factory _AccountSummary.fromJson(Map<String, dynamic> json) => _$AccountSummaryFromJson(json);

/// Güncel bakiye (kuruş, işaretli). Pozitif = borç.
@override final  int balance;
@override final  String currency;
@override final  DateTime asOf;

/// Create a copy of AccountSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AccountSummaryCopyWith<_AccountSummary> get copyWith => __$AccountSummaryCopyWithImpl<_AccountSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AccountSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AccountSummary&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.asOf, asOf) || other.asOf == asOf));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,balance,currency,asOf);

@override
String toString() {
  return 'AccountSummary(balance: $balance, currency: $currency, asOf: $asOf)';
}


}

/// @nodoc
abstract mixin class _$AccountSummaryCopyWith<$Res> implements $AccountSummaryCopyWith<$Res> {
  factory _$AccountSummaryCopyWith(_AccountSummary value, $Res Function(_AccountSummary) _then) = __$AccountSummaryCopyWithImpl;
@override @useResult
$Res call({
 int balance, String currency, DateTime asOf
});




}
/// @nodoc
class __$AccountSummaryCopyWithImpl<$Res>
    implements _$AccountSummaryCopyWith<$Res> {
  __$AccountSummaryCopyWithImpl(this._self, this._then);

  final _AccountSummary _self;
  final $Res Function(_AccountSummary) _then;

/// Create a copy of AccountSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? balance = null,Object? currency = null,Object? asOf = null,}) {
  return _then(_AccountSummary(
balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as int,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,asOf: null == asOf ? _self.asOf : asOf // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$AccountEntry {

 DateTime get date;/// `debit` (borç) | `credit` (alacak/tahsilat).
 String get entryType;/// Tutar (kuruş, pozitif). İşaret ve renk `entryType`'tan gelir.
 int get amount;/// O satırdan sonraki yürüyen bakiye (kuruş, işaretli).
 int get runningBalance;/// `order` | `subscription` | `payment` | `manual` | `adjustment`.
 String get source; String? get description;
/// Create a copy of AccountEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AccountEntryCopyWith<AccountEntry> get copyWith => _$AccountEntryCopyWithImpl<AccountEntry>(this as AccountEntry, _$identity);

  /// Serializes this AccountEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AccountEntry&&(identical(other.date, date) || other.date == date)&&(identical(other.entryType, entryType) || other.entryType == entryType)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.runningBalance, runningBalance) || other.runningBalance == runningBalance)&&(identical(other.source, source) || other.source == source)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date,entryType,amount,runningBalance,source,description);

@override
String toString() {
  return 'AccountEntry(date: $date, entryType: $entryType, amount: $amount, runningBalance: $runningBalance, source: $source, description: $description)';
}


}

/// @nodoc
abstract mixin class $AccountEntryCopyWith<$Res>  {
  factory $AccountEntryCopyWith(AccountEntry value, $Res Function(AccountEntry) _then) = _$AccountEntryCopyWithImpl;
@useResult
$Res call({
 DateTime date, String entryType, int amount, int runningBalance, String source, String? description
});




}
/// @nodoc
class _$AccountEntryCopyWithImpl<$Res>
    implements $AccountEntryCopyWith<$Res> {
  _$AccountEntryCopyWithImpl(this._self, this._then);

  final AccountEntry _self;
  final $Res Function(AccountEntry) _then;

/// Create a copy of AccountEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? date = null,Object? entryType = null,Object? amount = null,Object? runningBalance = null,Object? source = null,Object? description = freezed,}) {
  return _then(_self.copyWith(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,entryType: null == entryType ? _self.entryType : entryType // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int,runningBalance: null == runningBalance ? _self.runningBalance : runningBalance // ignore: cast_nullable_to_non_nullable
as int,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AccountEntry].
extension AccountEntryPatterns on AccountEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AccountEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AccountEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AccountEntry value)  $default,){
final _that = this;
switch (_that) {
case _AccountEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AccountEntry value)?  $default,){
final _that = this;
switch (_that) {
case _AccountEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime date,  String entryType,  int amount,  int runningBalance,  String source,  String? description)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AccountEntry() when $default != null:
return $default(_that.date,_that.entryType,_that.amount,_that.runningBalance,_that.source,_that.description);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime date,  String entryType,  int amount,  int runningBalance,  String source,  String? description)  $default,) {final _that = this;
switch (_that) {
case _AccountEntry():
return $default(_that.date,_that.entryType,_that.amount,_that.runningBalance,_that.source,_that.description);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime date,  String entryType,  int amount,  int runningBalance,  String source,  String? description)?  $default,) {final _that = this;
switch (_that) {
case _AccountEntry() when $default != null:
return $default(_that.date,_that.entryType,_that.amount,_that.runningBalance,_that.source,_that.description);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AccountEntry extends AccountEntry {
  const _AccountEntry({required this.date, required this.entryType, required this.amount, required this.runningBalance, required this.source, this.description}): super._();
  factory _AccountEntry.fromJson(Map<String, dynamic> json) => _$AccountEntryFromJson(json);

@override final  DateTime date;
/// `debit` (borç) | `credit` (alacak/tahsilat).
@override final  String entryType;
/// Tutar (kuruş, pozitif). İşaret ve renk `entryType`'tan gelir.
@override final  int amount;
/// O satırdan sonraki yürüyen bakiye (kuruş, işaretli).
@override final  int runningBalance;
/// `order` | `subscription` | `payment` | `manual` | `adjustment`.
@override final  String source;
@override final  String? description;

/// Create a copy of AccountEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AccountEntryCopyWith<_AccountEntry> get copyWith => __$AccountEntryCopyWithImpl<_AccountEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AccountEntryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AccountEntry&&(identical(other.date, date) || other.date == date)&&(identical(other.entryType, entryType) || other.entryType == entryType)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.runningBalance, runningBalance) || other.runningBalance == runningBalance)&&(identical(other.source, source) || other.source == source)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date,entryType,amount,runningBalance,source,description);

@override
String toString() {
  return 'AccountEntry(date: $date, entryType: $entryType, amount: $amount, runningBalance: $runningBalance, source: $source, description: $description)';
}


}

/// @nodoc
abstract mixin class _$AccountEntryCopyWith<$Res> implements $AccountEntryCopyWith<$Res> {
  factory _$AccountEntryCopyWith(_AccountEntry value, $Res Function(_AccountEntry) _then) = __$AccountEntryCopyWithImpl;
@override @useResult
$Res call({
 DateTime date, String entryType, int amount, int runningBalance, String source, String? description
});




}
/// @nodoc
class __$AccountEntryCopyWithImpl<$Res>
    implements _$AccountEntryCopyWith<$Res> {
  __$AccountEntryCopyWithImpl(this._self, this._then);

  final _AccountEntry _self;
  final $Res Function(_AccountEntry) _then;

/// Create a copy of AccountEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? date = null,Object? entryType = null,Object? amount = null,Object? runningBalance = null,Object? source = null,Object? description = freezed,}) {
  return _then(_AccountEntry(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,entryType: null == entryType ? _self.entryType : entryType // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int,runningBalance: null == runningBalance ? _self.runningBalance : runningBalance // ignore: cast_nullable_to_non_nullable
as int,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$AccountStatement {

 int get openingBalance; int get closingBalance; String get currency; DateTime get from; DateTime get to; List<AccountEntry> get entries;
/// Create a copy of AccountStatement
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AccountStatementCopyWith<AccountStatement> get copyWith => _$AccountStatementCopyWithImpl<AccountStatement>(this as AccountStatement, _$identity);

  /// Serializes this AccountStatement to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AccountStatement&&(identical(other.openingBalance, openingBalance) || other.openingBalance == openingBalance)&&(identical(other.closingBalance, closingBalance) || other.closingBalance == closingBalance)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.from, from) || other.from == from)&&(identical(other.to, to) || other.to == to)&&const DeepCollectionEquality().equals(other.entries, entries));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,openingBalance,closingBalance,currency,from,to,const DeepCollectionEquality().hash(entries));

@override
String toString() {
  return 'AccountStatement(openingBalance: $openingBalance, closingBalance: $closingBalance, currency: $currency, from: $from, to: $to, entries: $entries)';
}


}

/// @nodoc
abstract mixin class $AccountStatementCopyWith<$Res>  {
  factory $AccountStatementCopyWith(AccountStatement value, $Res Function(AccountStatement) _then) = _$AccountStatementCopyWithImpl;
@useResult
$Res call({
 int openingBalance, int closingBalance, String currency, DateTime from, DateTime to, List<AccountEntry> entries
});




}
/// @nodoc
class _$AccountStatementCopyWithImpl<$Res>
    implements $AccountStatementCopyWith<$Res> {
  _$AccountStatementCopyWithImpl(this._self, this._then);

  final AccountStatement _self;
  final $Res Function(AccountStatement) _then;

/// Create a copy of AccountStatement
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? openingBalance = null,Object? closingBalance = null,Object? currency = null,Object? from = null,Object? to = null,Object? entries = null,}) {
  return _then(_self.copyWith(
openingBalance: null == openingBalance ? _self.openingBalance : openingBalance // ignore: cast_nullable_to_non_nullable
as int,closingBalance: null == closingBalance ? _self.closingBalance : closingBalance // ignore: cast_nullable_to_non_nullable
as int,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,from: null == from ? _self.from : from // ignore: cast_nullable_to_non_nullable
as DateTime,to: null == to ? _self.to : to // ignore: cast_nullable_to_non_nullable
as DateTime,entries: null == entries ? _self.entries : entries // ignore: cast_nullable_to_non_nullable
as List<AccountEntry>,
  ));
}

}


/// Adds pattern-matching-related methods to [AccountStatement].
extension AccountStatementPatterns on AccountStatement {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AccountStatement value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AccountStatement() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AccountStatement value)  $default,){
final _that = this;
switch (_that) {
case _AccountStatement():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AccountStatement value)?  $default,){
final _that = this;
switch (_that) {
case _AccountStatement() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int openingBalance,  int closingBalance,  String currency,  DateTime from,  DateTime to,  List<AccountEntry> entries)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AccountStatement() when $default != null:
return $default(_that.openingBalance,_that.closingBalance,_that.currency,_that.from,_that.to,_that.entries);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int openingBalance,  int closingBalance,  String currency,  DateTime from,  DateTime to,  List<AccountEntry> entries)  $default,) {final _that = this;
switch (_that) {
case _AccountStatement():
return $default(_that.openingBalance,_that.closingBalance,_that.currency,_that.from,_that.to,_that.entries);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int openingBalance,  int closingBalance,  String currency,  DateTime from,  DateTime to,  List<AccountEntry> entries)?  $default,) {final _that = this;
switch (_that) {
case _AccountStatement() when $default != null:
return $default(_that.openingBalance,_that.closingBalance,_that.currency,_that.from,_that.to,_that.entries);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AccountStatement implements AccountStatement {
  const _AccountStatement({required this.openingBalance, required this.closingBalance, required this.currency, required this.from, required this.to, final  List<AccountEntry> entries = const <AccountEntry>[]}): _entries = entries;
  factory _AccountStatement.fromJson(Map<String, dynamic> json) => _$AccountStatementFromJson(json);

@override final  int openingBalance;
@override final  int closingBalance;
@override final  String currency;
@override final  DateTime from;
@override final  DateTime to;
 final  List<AccountEntry> _entries;
@override@JsonKey() List<AccountEntry> get entries {
  if (_entries is EqualUnmodifiableListView) return _entries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_entries);
}


/// Create a copy of AccountStatement
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AccountStatementCopyWith<_AccountStatement> get copyWith => __$AccountStatementCopyWithImpl<_AccountStatement>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AccountStatementToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AccountStatement&&(identical(other.openingBalance, openingBalance) || other.openingBalance == openingBalance)&&(identical(other.closingBalance, closingBalance) || other.closingBalance == closingBalance)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.from, from) || other.from == from)&&(identical(other.to, to) || other.to == to)&&const DeepCollectionEquality().equals(other._entries, _entries));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,openingBalance,closingBalance,currency,from,to,const DeepCollectionEquality().hash(_entries));

@override
String toString() {
  return 'AccountStatement(openingBalance: $openingBalance, closingBalance: $closingBalance, currency: $currency, from: $from, to: $to, entries: $entries)';
}


}

/// @nodoc
abstract mixin class _$AccountStatementCopyWith<$Res> implements $AccountStatementCopyWith<$Res> {
  factory _$AccountStatementCopyWith(_AccountStatement value, $Res Function(_AccountStatement) _then) = __$AccountStatementCopyWithImpl;
@override @useResult
$Res call({
 int openingBalance, int closingBalance, String currency, DateTime from, DateTime to, List<AccountEntry> entries
});




}
/// @nodoc
class __$AccountStatementCopyWithImpl<$Res>
    implements _$AccountStatementCopyWith<$Res> {
  __$AccountStatementCopyWithImpl(this._self, this._then);

  final _AccountStatement _self;
  final $Res Function(_AccountStatement) _then;

/// Create a copy of AccountStatement
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? openingBalance = null,Object? closingBalance = null,Object? currency = null,Object? from = null,Object? to = null,Object? entries = null,}) {
  return _then(_AccountStatement(
openingBalance: null == openingBalance ? _self.openingBalance : openingBalance // ignore: cast_nullable_to_non_nullable
as int,closingBalance: null == closingBalance ? _self.closingBalance : closingBalance // ignore: cast_nullable_to_non_nullable
as int,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,from: null == from ? _self.from : from // ignore: cast_nullable_to_non_nullable
as DateTime,to: null == to ? _self.to : to // ignore: cast_nullable_to_non_nullable
as DateTime,entries: null == entries ? _self._entries : entries // ignore: cast_nullable_to_non_nullable
as List<AccountEntry>,
  ));
}


}

// dart format on
