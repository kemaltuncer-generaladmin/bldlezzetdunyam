/// Cari hesap DTO'ları — `docs/openapi.yaml` §Cari hesap.
///
/// Bakiye alanları İMZALI kuruş `int`'tir (pozitif = müşterinin borcu, negatif
/// = fazla ödeme); tutar (`amount`) her zaman pozitiftir, yön `entryType`'ta.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'account.freezed.dart';
part 'account.g.dart';

/// `GET /account/summary`.
@freezed
abstract class AccountSummary with _$AccountSummary {
  const factory AccountSummary({
    /// Güncel bakiye (kuruş, işaretli). Pozitif = borç.
    required int balance,
    required String currency,
    required DateTime asOf,
  }) = _AccountSummary;

  const AccountSummary._();

  factory AccountSummary.fromJson(Map<String, dynamic> json) =>
      _$AccountSummaryFromJson(json);

  bool get hasDebt => balance > 0;
}

/// Ekstredeki tek hareket.
@freezed
abstract class AccountEntry with _$AccountEntry {
  const factory AccountEntry({
    required DateTime date,

    /// `debit` (borç) | `credit` (alacak/tahsilat).
    required String entryType,

    /// Tutar (kuruş, pozitif). İşaret ve renk `entryType`'tan gelir.
    required int amount,

    /// O satırdan sonraki yürüyen bakiye (kuruş, işaretli).
    required int runningBalance,

    /// `order` | `subscription` | `payment` | `manual` | `adjustment`.
    required String source,
    String? description,
  }) = _AccountEntry;

  const AccountEntry._();

  factory AccountEntry.fromJson(Map<String, dynamic> json) =>
      _$AccountEntryFromJson(json);

  bool get isDebit => entryType == 'debit';
}

/// `GET /account/statement`.
@freezed
abstract class AccountStatement with _$AccountStatement {
  const factory AccountStatement({
    required int openingBalance,
    required int closingBalance,
    required String currency,
    required DateTime from,
    required DateTime to,
    @Default(<AccountEntry>[]) List<AccountEntry> entries,
  }) = _AccountStatement;

  factory AccountStatement.fromJson(Map<String, dynamic> json) =>
      _$AccountStatementFromJson(json);
}
