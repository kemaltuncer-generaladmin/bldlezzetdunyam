/// Abonelik detayı — kural özeti + duraklat/devam/iptal.
///
/// Aksiyonlar sunucuda durum makinesini yürütür; istemci yalnız çağırır ve
/// sağlayıcıları tazeler (sipariş iptalindeki kalıp). Fiyat/tutar asla
/// istemcide hesaplanmaz — `agreedUnitPrice` sunucudan gelir.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_error_text.dart';
import '../../core/labels.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/infra_providers.dart';
import '../../providers/subscription_providers.dart';
import '../../theme/bld_theme.dart';
import '../../widgets/bld_card.dart';
import '../../widgets/pill.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_views.dart';
import 'subscriptions_screen.dart';

class SubscriptionDetailScreen extends ConsumerStatefulWidget {
  const SubscriptionDetailScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<SubscriptionDetailScreen> createState() =>
      _SubscriptionDetailScreenState();
}

class _SubscriptionDetailScreenState
    extends ConsumerState<SubscriptionDetailScreen> {
  bool _busy = false;

  Future<void> _run(
    Future<Subscription> Function(SubscriptionService s) action,
    String successMessage,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await action(ref.read(apiProvider).subscriptions);
      ref.invalidate(subscriptionProvider(widget.id));
      ref.invalidate(subscriptionsProvider);
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    } on ApiException catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(apiErrorDisplayMessage(error, l10n))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmCancel() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.subscriptionCancelConfirmTitle),
        content: Text(l10n.subscriptionCancelConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.subscriptionCancel),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run((s) => s.cancel(widget.id), l10n.subscriptionCancelled);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(subscriptionProvider(widget.id));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.subscriptionDetailTitle)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(subscriptionProvider(widget.id)),
        ),
        data: (subscription) => _Body(
          subscription: subscription,
          busy: _busy,
          onPause: () =>
              _run((s) => s.pause(widget.id), l10n.subscriptionPaused),
          onResume: () =>
              _run((s) => s.resume(widget.id), l10n.subscriptionResumed),
          onCancel: _confirmCancel,
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.subscription,
    required this.busy,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  final Subscription subscription;
  final bool busy;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final (label, variant) = subscriptionStatusPresentation(
      subscription.status,
      l10n,
    );
    final price = subscription.agreedUnitPrice;

    return ListView(
      padding: const EdgeInsets.all(BldSpacing.md),
      children: [
        // Durum + fiyat başlığı.
        BldCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  BldPill(label: label, variant: variant),
                  const Spacer(),
                  Text(
                    l10n.subscriptionQuantityLabel(
                      subscription.defaultQuantity,
                    ),
                    style: textTheme.bodyMedium?.copyWith(
                      color: bldColor(BldColors.neutral600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: BldSpacing.md),
              Text(
                price != null ? Money.format(price) : l10n.subscriptionNoPrice,
                style: textTheme.headlineSmall,
              ),
              Text(
                l10n.subscriptionAgreedPrice,
                style: textTheme.bodySmall?.copyWith(
                  color: bldColor(BldColors.neutral600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: BldSpacing.md),

        // Kural özeti.
        BldCard(
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.local_shipping_outlined,
                label: l10n.subscriptionDelivery,
                value: deliveryTypeLabel(subscription.deliveryType, l10n),
              ),
              if (subscription.deliveryTimeFrom != null)
                _InfoRow(
                  icon: Icons.schedule,
                  label: l10n.subscriptionDeliveryTime,
                  value: _timeWindow(subscription),
                ),
              _InfoRow(
                icon: Icons.date_range_outlined,
                label: l10n.subscriptionPeriod,
                value: _period(subscription, l10n),
              ),
            ],
          ),
        ),
        const SizedBox(height: BldSpacing.md),

        // Servis günleri.
        SectionHeader(
          title: l10n.subscriptionDays,
          padding: const EdgeInsets.only(
            left: BldSpacing.xs,
            bottom: BldSpacing.sm,
          ),
        ),
        Wrap(
          spacing: BldSpacing.sm,
          runSpacing: BldSpacing.sm,
          children: [
            for (final day in subscription.serviceDays)
              BldPill(
                label: subscriptionDayLabel(day, l10n),
                variant: BldPillVariant.brand,
              ),
          ],
        ),
        const SizedBox(height: BldSpacing.sm),

        // İçerik (satırlar).
        SectionHeader(
          title: l10n.subscriptionProducts,
          padding: const EdgeInsets.only(
            left: BldSpacing.xs,
            top: BldSpacing.md,
            bottom: BldSpacing.sm,
          ),
        ),
        if (subscription.lines.isEmpty)
          BldCard(
            child: Text(
              l10n.subscriptionNoProducts,
              style: textTheme.bodyMedium?.copyWith(
                color: bldColor(BldColors.neutral600),
              ),
            ),
          )
        else
          BldCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < subscription.lines.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, color: bldColor(BldColors.neutral100)),
                  _LineRow(line: subscription.lines[i]),
                ],
              ],
            ),
          ),
        const SizedBox(height: BldSpacing.xl),

        // Aksiyonlar.
        ..._actions(context, l10n),
      ],
    );
  }

  List<Widget> _actions(BuildContext context, AppLocalizations l10n) {
    if (subscription.isCancelled) return const [];

    final buttons = <Widget>[];
    if (subscription.isActive) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: busy ? null : onPause,
          icon: const Icon(Icons.pause_circle_outline),
          label: Text(l10n.subscriptionPause),
        ),
      );
    } else if (subscription.isPaused) {
      buttons.add(
        FilledButton.icon(
          onPressed: busy ? null : onResume,
          icon: const Icon(Icons.play_circle_outline),
          label: Text(l10n.subscriptionResume),
        ),
      );
    }
    buttons.add(
      TextButton.icon(
        onPressed: busy ? null : onCancel,
        style: TextButton.styleFrom(
          foregroundColor: bldColor(BldColors.danger),
        ),
        icon: const Icon(Icons.cancel_outlined),
        label: Text(l10n.subscriptionCancel),
      ),
    );

    return [
      for (final button in buttons) ...[
        SizedBox(width: double.infinity, child: button),
        const SizedBox(height: BldSpacing.sm),
      ],
    ];
  }

  String _timeWindow(Subscription s) {
    final from = s.deliveryTimeFrom ?? '';
    final to = s.deliveryTimeTo;
    return to != null && to.isNotEmpty ? '$from – $to' : from;
  }

  String _period(Subscription s, AppLocalizations l10n) {
    final start = _date(s.startDate);
    final end = s.endDate != null
        ? _date(s.endDate!)
        : l10n.subscriptionOpenEnded;
    return '$start → $end';
  }

  /// Tarih-yalnız alan; zaman dilimi çevirmeden alanlardan biçimlenir.
  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.${d.year}';
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BldSpacing.sm - 2),
      child: Row(
        children: [
          Icon(icon, size: 20, color: bldColor(BldColors.neutral600)),
          const SizedBox(width: BldSpacing.md),
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: bldColor(BldColors.neutral600),
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line});

  final SubscriptionLine line;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final price = line.agreedUnitPrice;
    return Padding(
      padding: const EdgeInsets.all(BldSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: BldSpacing.sm,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: bldColor(BldColors.neutral100),
              borderRadius: BorderRadius.circular(BldRadius.sm),
            ),
            child: Text('×${line.quantity}', style: textTheme.labelLarge),
          ),
          const SizedBox(width: BldSpacing.md),
          Expanded(
            child: Text(
              line.label ?? l10n.subscriptionProducts,
              style: textTheme.bodyLarge,
            ),
          ),
          if (price != null)
            Text(Money.format(price), style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}
