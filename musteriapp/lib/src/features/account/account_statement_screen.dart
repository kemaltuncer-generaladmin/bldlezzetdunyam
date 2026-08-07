/// Cari hesabım — güncel bakiye + hareket ekstresi.
///
/// Tutarların hepsi sunucudan gelir; istemci hiçbir bakiye/tutar HESAPLAMAZ,
/// yalnız `Money.format` ile gösterir. Pozitif bakiye = müşterinin borcu.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/account_providers.dart';
import '../../theme/bld_theme.dart';
import '../../widgets/bld_card.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/section_header.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/status_views.dart';

String accountSourceLabel(String source, AppLocalizations l10n) {
  return switch (source) {
    'order' => l10n.accountSourceOrder,
    'subscription' => l10n.accountSourceSubscription,
    'payment' => l10n.accountSourcePayment,
    'manual' => l10n.accountSourceManual,
    'adjustment' => l10n.accountSourceAdjustment,
    _ => source,
  };
}

class AccountStatementScreen extends ConsumerWidget {
  const AccountStatementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final statementAsync = ref.watch(accountStatementProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountStatementTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(accountSummaryProvider);
          ref.invalidate(accountStatementProvider);
        },
        child: statementAsync.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(BldSpacing.md),
            children: const [ListRowSkeleton(), ListRowSkeleton()],
          ),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: BldSpacing.xxl),
              ErrorView(
                error: error,
                onRetry: () => ref.invalidate(accountStatementProvider),
              ),
            ],
          ),
          data: (statement) => _StatementBody(statement: statement),
        ),
      ),
    );
  }
}

class _StatementBody extends ConsumerWidget {
  const _StatementBody({required this.statement});

  final AccountStatement statement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final entries = statement.entries;

    return ListView(
      padding: const EdgeInsets.only(bottom: BldSpacing.xl),
      children: [
        const SizedBox(height: BldSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: BldSpacing.md),
          child: _BalanceHero(balance: statement.closingBalance),
        ),
        SectionHeader(title: l10n.accountStatementEntries),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: BldSpacing.xl),
            child: EmptyView(
              icon: Icons.receipt_long_outlined,
              title: l10n.accountStatementEmpty,
            ),
          )
        else
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BldSpacing.md,
                0,
                BldSpacing.md,
                BldSpacing.sm,
              ),
              child: _EntryTile(entry: entry),
            ),
      ],
    );
  }
}

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({required this.balance});

  /// İşaretli kuruş; pozitif = borç.
  final int balance;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    final (note, accent) = balance > 0
        ? (l10n.accountBalanceDebtNote, BldColors.danger)
        : balance < 0
        ? (l10n.accountBalanceCreditNote, BldColors.success)
        : (l10n.accountBalanceZeroNote, BldColors.neutral600);

    return BldCard(
      color: BldColors.brand600,
      elevation: BldElevation.raised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.accountBalanceLabel,
            style: textTheme.bodyMedium?.copyWith(
              color: bldColor(BldColors.brand50),
            ),
          ),
          const SizedBox(height: BldSpacing.xs),
          Text(
            Money.format(balance.abs()),
            style: textTheme.displaySmall?.copyWith(
              color: bldColor(BldColors.neutral0),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: BldSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: BldSpacing.sm + 2,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: bldColor(BldColors.neutral0).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(BldRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  balance == 0 ? Icons.check_circle_outline : Icons.circle,
                  size: 12,
                  color: bldColor(accent),
                ),
                const SizedBox(width: 6),
                Text(
                  note,
                  style: textTheme.bodySmall?.copyWith(
                    color: bldColor(BldColors.neutral0),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final AccountEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isDebit = entry.isDebit;

    // Borç bakiyeyi artırır (+), tahsilat/alacak azaltır (−).
    final amountColor = isDebit ? BldColors.neutral900 : BldColors.success;
    final sign = isDebit ? '+' : '−';

    return BldCard(
      padding: const EdgeInsets.symmetric(
        horizontal: BldSpacing.md,
        vertical: BldSpacing.md - 2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description ?? accountSourceLabel(entry.source, l10n),
                  style: textTheme.bodyLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${_date(entry.date)} · ${accountSourceLabel(entry.source, l10n)}',
                  style: textTheme.bodySmall?.copyWith(
                    color: bldColor(BldColors.neutral600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: BldSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$sign${Money.format(entry.amount)}',
                style: textTheme.titleMedium?.copyWith(
                  color: bldColor(amountColor),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                Money.format(entry.runningBalance),
                style: textTheme.bodySmall?.copyWith(
                  color: bldColor(BldColors.neutral600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.${d.year}';
}
