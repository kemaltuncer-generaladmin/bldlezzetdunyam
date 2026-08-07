// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AccountSummary _$AccountSummaryFromJson(Map<String, dynamic> json) =>
    _AccountSummary(
      balance: (json['balance'] as num).toInt(),
      currency: json['currency'] as String,
      asOf: DateTime.parse(json['as_of'] as String),
    );

Map<String, dynamic> _$AccountSummaryToJson(_AccountSummary instance) =>
    <String, dynamic>{
      'balance': instance.balance,
      'currency': instance.currency,
      'as_of': instance.asOf.toIso8601String(),
    };

_AccountEntry _$AccountEntryFromJson(Map<String, dynamic> json) =>
    _AccountEntry(
      date: DateTime.parse(json['date'] as String),
      entryType: json['entry_type'] as String,
      amount: (json['amount'] as num).toInt(),
      runningBalance: (json['running_balance'] as num).toInt(),
      source: json['source'] as String,
      description: json['description'] as String?,
    );

Map<String, dynamic> _$AccountEntryToJson(_AccountEntry instance) =>
    <String, dynamic>{
      'date': instance.date.toIso8601String(),
      'entry_type': instance.entryType,
      'amount': instance.amount,
      'running_balance': instance.runningBalance,
      'source': instance.source,
      'description': ?instance.description,
    };

_AccountStatement _$AccountStatementFromJson(Map<String, dynamic> json) =>
    _AccountStatement(
      openingBalance: (json['opening_balance'] as num).toInt(),
      closingBalance: (json['closing_balance'] as num).toInt(),
      currency: json['currency'] as String,
      from: DateTime.parse(json['from'] as String),
      to: DateTime.parse(json['to'] as String),
      entries:
          (json['entries'] as List<dynamic>?)
              ?.map((e) => AccountEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <AccountEntry>[],
    );

Map<String, dynamic> _$AccountStatementToJson(_AccountStatement instance) =>
    <String, dynamic>{
      'opening_balance': instance.openingBalance,
      'closing_balance': instance.closingBalance,
      'currency': instance.currency,
      'from': instance.from.toIso8601String(),
      'to': instance.to.toIso8601String(),
      'entries': instance.entries.map((e) => e.toJson()).toList(),
    };
