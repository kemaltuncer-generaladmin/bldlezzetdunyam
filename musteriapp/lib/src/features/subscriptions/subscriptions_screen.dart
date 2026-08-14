/// Aboneliklerim — kurumsal öğle yemeği abonelikleri listesi.
///
/// Abonelik bir kuraldır: her gün sipariş üretir. Müşteri buradan durumu görür,
/// talep açar ve detaya girip duraklatır/iptal eder.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/subscription_providers.dart';
import '../../router/app_router.dart';
import '../../theme/bld_theme.dart';
import '../../widgets/bld_card.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/pill.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/status_views.dart';

/// Abonelik durumunun etiketi + rozet rengi — liste ve detay paylaşır.
(String, BldPillVariant) subscriptionStatusPresentation(
  String status,
  AppLocalizations l10n,
) {
  return switch (status) {
    'active' => (l10n.subscriptionStatusActive, BldPillVariant.success),
    'pending' => (l10n.subscriptionStatusPending, BldPillVariant.info),
    'paused' => (l10n.subscriptionStatusPaused, BldPillVariant.warning),
    'cancelled' => (l10n.subscriptionStatusCancelled, BldPillVariant.neutral),
    _ => (status, BldPillVariant.neutral),
  };
}

/// ISO hafta günü (1..7) → kısa ad. Liste/detay/oluşturma paylaşır.
String subscriptionDayLabel(int isoDay, AppLocalizations l10n) {
  return switch (isoDay) {
    1 => l10n.dayMon,
    2 => l10n.dayTue,
    3 => l10n.dayWed,
    4 => l10n.dayThu,
    5 => l10n.dayFri,
    6 => l10n.daySat,
    7 => l10n.daySun,
    _ => '$isoDay',
  };
}

class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(subscriptionsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.subscriptionsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.subscriptionNew),
        icon: const Icon(Icons.add_outlined),
        label: Text(l10n.subscriptionsNew),
      ),
      body: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(BldSpacing.md),
          child: ListRowSkeleton(),
        ),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(subscriptionsProvider),
        ),
        data: (subscriptions) {
          if (subscriptions.isEmpty) {
            return EmptyView(
              icon: Icons.event_repeat_outlined,
              title: l10n.subscriptionsEmpty,
              actionLabel: l10n.subscriptionsNew,
              onAction: () => context.push(Routes.subscriptionNew),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(subscriptionsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(BldSpacing.md),
              itemCount: subscriptions.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: BldSpacing.md - 4),
              itemBuilder: (context, index) =>
                  _SubscriptionTile(subscription: subscriptions[index]),
            ),
          );
        },
      ),
    );
  }
}

class _SubscriptionTile extends StatelessWidget {
  const _SubscriptionTile({required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final (label, variant) = subscriptionStatusPresentation(
      subscription.status,
      l10n,
    );
    final price = subscription.agreedUnitPrice;

    return BldCard(
      onTap: () => context.push(Routes.subscriptionDetail(subscription.id)),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bldColor(BldColors.brand50),
              borderRadius: BorderRadius.circular(BldRadius.md),
            ),
            child: Icon(
              Icons.event_repeat_outlined,
              color: bldColor(BldColors.brand700),
            ),
          ),
          const SizedBox(width: BldSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    BldPill(label: label, variant: variant),
                    const SizedBox(width: BldSpacing.sm),
                    Flexible(
                      child: Text(
                        l10n.subscriptionQuantityLabel(
                          subscription.defaultQuantity,
                        ),
                        style: textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: BldSpacing.xs),
                Text(
                  price != null
                      ? '${l10n.subscriptionAgreedPrice}: ${Money.format(price)}'
                      : l10n.subscriptionNoPrice,
                  style: textTheme.titleMedium,
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_outlined,
            color: bldColor(BldColors.neutral400),
          ),
        ],
      ),
    );
  }
}
