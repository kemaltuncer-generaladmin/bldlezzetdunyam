/// Siparişlerim — geçmiş liste (`docs/07-musteriapp.md` §2).
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/labels.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/order_providers.dart';
import '../../router/app_router.dart';
import '../../theme/bld_theme.dart';
import '../../widgets/status_views.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.ordersTitle)),
      body: ordersAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(ordersProvider),
        ),
        data: (page) {
          if (page.data.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(BldSpacing.lg),
                child: Text(l10n.ordersEmpty, textAlign: TextAlign.center),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(ordersProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(BldSpacing.md),
              itemCount: page.data.length,
              separatorBuilder: (_, _) => const SizedBox(height: BldSpacing.sm),
              itemBuilder: (context, index) =>
                  _OrderTile(order: page.data[index]),
            ),
          );
        },
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});

  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Card(
      child: ListTile(
        onTap: () => context.push(Routes.orderTracking(order.id)),
        contentPadding: const EdgeInsets.all(BldSpacing.md),
        title: Text(
          l10n.orderNumberLabel(order.orderNumber),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: BldSpacing.xs),
          child: Text(
            '${TurkishTime.longDateTime(order.createdAt)}'
            '  ·  ${l10n.cartItemCount(order.itemCount)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              Money.format(order.total),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: bldColor(BldColors.brand700),
              ),
            ),
            const SizedBox(height: BldSpacing.xs),
            OrderStatusBadge(status: order.status),
          ],
        ),
      ),
    );
  }
}

/// Durum rozeti. Renk eşlemesi tek yerdedir; takip ekranı da bunu kullanır.
class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({super.key, required this.status});

  final OrderStatus status;

  static int backgroundFor(OrderStatus status) => switch (status) {
    OrderStatus.yeni => BldColors.info,
    OrderStatus.onaylandi => BldColors.info,
    OrderStatus.hazirlaniyor => BldColors.warning,
    OrderStatus.hazir => BldColors.success,
    OrderStatus.yolda => BldColors.brand500,
    OrderStatus.teslimEdildi => BldColors.neutral600,
    OrderStatus.iptal => BldColors.danger,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BldBadge(
      label: orderStatusLabel(status, l10n),
      background: backgroundFor(status),
    );
  }
}
