/// Sipariş takip — adım çubuğu ve canlı durum (`docs/07-musteriapp.md` §2).
///
/// Durum 5 saniyede bir yoklanır (`orderTrackingProvider`). Adım çubuğu
/// `OrderDetail.trackingSteps` üzerinden çizilir; gel-al siparişte `yolda`
/// adımı **yoktur**.
library;

import 'dart:async';

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_error_text.dart';
import '../../core/eta_text.dart';
import '../../core/labels.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/infra_providers.dart';
import '../../providers/notification_providers.dart';
import '../../providers/order_providers.dart';
import '../../theme/bld_theme.dart';
import '../../widgets/bld_card.dart';
import '../../widgets/eta_notice.dart';
import '../../widgets/status_views.dart';
import 'orders_screen.dart';

class OrderTrackingScreen extends ConsumerWidget {
  const OrderTrackingScreen({super.key, required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    /*
     * KDS ile senkron: mutfak durumu değiştirdiğinde yoklama yeni durumu
     * getiriyor ve kullanıcıya bildirim düşüyor.
     *
     * `ref.listen` build içinde: yoklama bu ekran açıkken çalışıyor, ekran
     * kapanınca provider zaten atılıyor. Bildirimi sağlayıcı katmanında
     * kurmadık — orada l10n yok ve durum metinleri koda gömülürdü.
     */
    ref.listen<AsyncValue<OrderDetail>>(orderTrackingProvider(orderId), (
      previous,
      next,
    ) {
      final order = next.valueOrNull;
      if (order == null) return;
      unawaited(_notifyStatusChange(ref, order, l10n));
    });

    final orderAsync = ref.watch(orderTrackingProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.trackingTitle)),
      body: orderAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(orderTrackingProvider(orderId)),
        ),
        data: (order) => _OrderDetailBody(order: order),
      ),
    );
  }
}

/// Durum değiştiyse bildirim gösterir.
///
/// Hangi durumun bildirildiği cihazda tutuluyor: yoklama beş saniyede bir
/// çalışıyor, hatırlamasaydık aynı bildirim her turda yeniden düşerdi. `yeni`
/// bildirilmez — kullanıcı siparişi kendi verdi, haber vermeye gerek yok.
Future<void> _notifyStatusChange(
  WidgetRef ref,
  OrderDetail order,
  AppLocalizations l10n,
) async {
  if (order.status == OrderStatus.yeni) return;

  final cache = ref.read(localCacheProvider);
  final code = order.status.name;
  if (cache.readNotifiedStatus(order.id) == code) return;

  await cache.writeNotifiedStatus(order.id, code);
  await ref
      .read(notificationsProvider)
      .showOrderStatus(
        orderId: order.id,
        title: order.status == OrderStatus.hazir
            ? l10n.notificationOrderReadyTitle
            : l10n.notificationOrderUpdatedTitle,
        body: l10n.notificationOrderBody(
          order.orderNumber,
          orderStatusLabel(order.status, l10n),
        ),
      );
}

class _OrderDetailBody extends ConsumerWidget {
  const _OrderDetailBody({required this.order});

  final OrderDetail order;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.trackingCancelConfirmTitle),
        content: Text(l10n.trackingCancelConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.trackingCancelConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(apiProvider).orders.cancel(order.id);
      ref.invalidate(orderTrackingProvider(order.id));
      ref.invalidate(ordersProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.trackingCancelled)));
    } on ApiException catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(apiErrorDisplayMessage(error, l10n))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final offline = ref.watch(connectivityProvider);

    // Tahmini teslim saati üç durumda gösterilmez:
    // - sipariş bitmişse (teslim edildi / iptal) — geçmişe tahmin yürütülmez,
    // - müşteri belirli bir saat istediyse — o saat zaten aşağıda yazıyor,
    // - vitrin bilgisi yoksa veya sunucu `eta` göndermiyorsa.
    //
    // `Location.etaFor` yerine doğrudan `eta` okunuyor: o yardımcı vitrin
    // sipariş almıyorken `null` döner, oysa yolda olan bir sipariş kesim
    // saatinden sonra da takip edilir ve tahmini geçerliliğini korur.
    final location = ref.watch(locationProvider).valueOrNull?.location;
    final eta = (order.status.isTerminal || order.requestedAt != null)
        ? null
        : location?.eta?.forDeliveryType(order.deliveryType);

    return ListView(
      padding: const EdgeInsets.all(BldSpacing.md),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.orderNumberLabel(order.orderNumber),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            OrderStatusBadge(status: order.status),
          ],
        ),
        const SizedBox(height: BldSpacing.xs),
        Text(
          offline
              ? l10n.trackingStale
              : (order.status.isTerminal ? '' : l10n.trackingLive),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: BldSpacing.lg),

        if (order.status == OrderStatus.iptal)
          FormErrorBox(message: orderStatusLabel(OrderStatus.iptal, l10n))
        else
          _StatusStepBar(order: order),

        if (eta != null) ...[
          const SizedBox(height: BldSpacing.lg),
          EtaNotice(
            eta: etaAfterOrder(
              eta,
              order.deliveryType,
              l10n,
              orderCreatedAt: order.createdAt,
            ),
          ),
        ],

        const SizedBox(height: BldSpacing.lg),
        _Section(
          title: l10n.trackingItems,
          child: Column(
            children: [
              for (final item in order.items) _OrderItemRow(item: item),
            ],
          ),
        ),

        _Section(
          title: l10n.trackingTotal,
          child: Column(
            children: [
              _AmountRow(label: l10n.trackingSubtotal, amount: order.subtotal),
              _AmountRow(
                label: l10n.trackingDeliveryFee,
                amount: order.deliveryFee,
              ),
              const Divider(),
              _AmountRow(
                label: l10n.trackingTotal,
                amount: order.total,
                emphasized: true,
              ),
            ],
          ),
        ),

        _Section(
          title: l10n.trackingPayment,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(
                label: paymentMethodLabel(order.payment.method, l10n),
                value: paymentStatusLabel(order.payment.status, l10n),
              ),
              _InfoRow(
                label: l10n.trackingDeliveryType,
                value: deliveryTypeLabel(order.deliveryType, l10n),
              ),
              if (order.requestedAt != null)
                _InfoRow(
                  label: l10n.trackingRequestedAt,
                  value: TurkishTime.longDateTime(order.requestedAt!),
                ),
              _InfoRow(
                label: l10n.trackingCreatedAt,
                value: TurkishTime.longDateTime(order.createdAt),
              ),
            ],
          ),
        ),

        if (order.address != null)
          _Section(
            title: l10n.trackingAddress,
            child: Text(_formatAddress(order.address!)),
          ),

        if (order.customerNote != null && order.customerNote!.isNotEmpty)
          _Section(
            title: l10n.trackingCustomerNote,
            child: Text(order.customerNote!),
          ),

        if (order.canBeCancelledByCustomer) ...[
          const SizedBox(height: BldSpacing.lg),
          OutlinedButton.icon(
            onPressed: () => _cancel(context, ref),
            icon: const Icon(Icons.cancel_outlined),
            label: Text(l10n.trackingCancelAction),
          ),
        ],
        const SizedBox(height: BldSpacing.xl),
      ],
    );
  }

  String _formatAddress(Address address) {
    final parts = [
      address.line1,
      address.district,
      address.city,
      ?address.note,
    ];
    return parts.join('\n');
  }
}

/// Adım çubuğu. Tamamlanan adımlar dolu, sıradakiler boş çizilir.
class _StatusStepBar extends StatelessWidget {
  const _StatusStepBar({required this.order});

  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final steps = order.trackingSteps;
    final currentIndex = steps.indexOf(order.status);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < steps.length; index++)
          Expanded(
            child: _Step(
              label: orderStatusLabel(steps[index], l10n),
              reached: currentIndex >= 0 && index <= currentIndex,
              isFirst: index == 0,
              isLast: index == steps.length - 1,
              // Zaman damgası varsa gösterilir; sunucunun geçmişi kaynaktır.
              at: _timeOf(steps[index]),
            ),
          ),
      ],
    );
  }

  String? _timeOf(OrderStatus status) {
    for (final entry in order.statusHistory) {
      if (entry.status == status) return TurkishTime.time(entry.at);
    }
    return null;
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.label,
    required this.reached,
    required this.isFirst,
    required this.isLast,
    this.at,
  });

  final String label;
  final bool reached;
  final bool isFirst;
  final bool isLast;
  final String? at;

  @override
  Widget build(BuildContext context) {
    final active = reached
        ? bldColor(BldColors.brand500)
        : bldColor(BldColors.neutral200);

    return Column(
      children: [
        SizedBox(
          height: 28,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 3,
                  color: isFirst ? Colors.transparent : active,
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: active,
                  shape: BoxShape.circle,
                ),
                child: reached
                    ? Icon(
                        Icons.check,
                        size: 14,
                        color: bldColor(BldColors.neutral0),
                      )
                    : null,
              ),
              Expanded(
                child: Container(
                  height: 3,
                  color: isLast
                      ? Colors.transparent
                      : bldColor(
                          reached ? BldColors.brand200 : BldColors.neutral200,
                        ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: BldSpacing.xs),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: BldTextScale.caption,
            fontWeight: reached ? FontWeight.w700 : FontWeight.w400,
            color: reached
                ? bldColor(BldColors.neutral900)
                : bldColor(BldColors.neutral400),
          ),
        ),
        if (at != null)
          Text(
            at!,
            style: TextStyle(
              fontSize: BldTextScale.caption,
              color: bldColor(BldColors.neutral400),
            ),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: BldSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: BldSpacing.xs,
              bottom: BldSpacing.sm,
            ),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          BldCard(child: child),
        ],
      ),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BldSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '${item.quantity}×',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name),
                if (item.options.isNotEmpty)
                  Text(
                    item.options.join(', '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (item.note != null && item.note!.isNotEmpty)
                  Text(
                    item.note!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          Text(Money.format(item.lineTotal)),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amount,
    this.emphasized = false,
  });

  final String label;
  final int amount;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(Money.format(amount), style: style),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          Text(value, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
