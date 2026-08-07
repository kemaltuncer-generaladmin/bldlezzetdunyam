/// Abonelik talebi oluşturma.
///
/// Bu bir TALEP'tir: fiyat ekibimizce belirlenir (`status = pending`). Bu yüzden
/// form yalnız kuralın çekirdeğini toplar — günler, günlük adet, başlangıç,
/// teslimat tipi, not. Fiyat/tutar alanı yoktur; istemci fiyat hesaplamaz.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_error_text.dart';
import '../../core/labels.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/infra_providers.dart';
import '../../providers/subscription_providers.dart';
import '../../theme/bld_theme.dart';
import '../../widgets/bld_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_views.dart';
import 'subscriptions_screen.dart';

class SubscriptionCreateScreen extends ConsumerStatefulWidget {
  const SubscriptionCreateScreen({super.key});

  @override
  ConsumerState<SubscriptionCreateScreen> createState() =>
      _SubscriptionCreateScreenState();
}

class _SubscriptionCreateScreenState
    extends ConsumerState<SubscriptionCreateScreen> {
  final _noteController = TextEditingController();

  /// ISO hafta günleri (1..5 varsayılan — kurumsal öğle hafta içi).
  final Set<int> _days = {1, 2, 3, 4, 5};
  int _quantity = 10;
  DeliveryType _deliveryType = DeliveryType.delivery;
  late DateTime _startDate;

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Varsayılan başlangıç yarın; kullanıcı değiştirebilir.
    final now = DateTime.now();
    _startDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (_days.isEmpty) {
      setState(() => _error = l10n.subscriptionCreatePickDay);
      return;
    }

    final location = ref.read(locationProvider).valueOrNull;
    if (location == null) {
      setState(() => _error = l10n.errorUnknown);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final note = _noteController.text.trim();
    final sortedDays = _days.toList()..sort();

    try {
      await ref
          .read(apiProvider)
          .subscriptions
          .create(
            SubscriptionCreateRequest(
              locationId: location.location.id,
              deliveryType: _deliveryType,
              startDate: _isoDate(_startDate),
              serviceDays: sortedDays,
              defaultQuantity: _quantity,
              customerNote: note.isEmpty ? null : note,
            ),
          );
      ref.invalidate(subscriptionsProvider);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.subscriptionRequestSent)),
      );
      if (router.canPop()) router.pop();
    } on ApiException catch (error) {
      setState(() => _error = apiErrorDisplayMessage(error, l10n));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.subscriptionCreateTitle)),
      body: ListView(
        padding: const EdgeInsets.all(BldSpacing.md),
        children: [
          Text(
            l10n.subscriptionCreateIntro,
            style: textTheme.bodyMedium?.copyWith(
              color: bldColor(BldColors.neutral600),
            ),
          ),
          const SizedBox(height: BldSpacing.md),

          // Teslimat günleri.
          SectionHeader(
            title: l10n.subscriptionCreateDays,
            padding: const EdgeInsets.only(
              left: BldSpacing.xs,
              bottom: BldSpacing.sm,
            ),
          ),
          Wrap(
            spacing: BldSpacing.sm,
            runSpacing: BldSpacing.sm,
            children: [
              for (var day = 1; day <= 7; day++)
                FilterChip(
                  label: Text(subscriptionDayLabel(day, l10n)),
                  selected: _days.contains(day),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _days.add(day);
                    } else {
                      _days.remove(day);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: BldSpacing.lg),

          // Günlük porsiyon.
          SectionHeader(
            title: l10n.subscriptionCreateQuantity,
            padding: const EdgeInsets.only(
              left: BldSpacing.xs,
              bottom: BldSpacing.sm,
            ),
          ),
          BldCard(
            child: Row(
              children: [
                Text(
                  l10n.subscriptionQuantityLabel(_quantity),
                  style: textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton.outlined(
                  onPressed: _quantity > 1
                      ? () => setState(() => _quantity--)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                const SizedBox(width: BldSpacing.sm),
                IconButton.filled(
                  onPressed: () => setState(() => _quantity++),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          const SizedBox(height: BldSpacing.lg),

          // Teslimat tipi.
          SectionHeader(
            title: l10n.checkoutDeliveryType,
            padding: const EdgeInsets.only(
              left: BldSpacing.xs,
              bottom: BldSpacing.sm,
            ),
          ),
          SegmentedButton<DeliveryType>(
            segments: [
              ButtonSegment(
                value: DeliveryType.delivery,
                label: Text(deliveryTypeLabel(DeliveryType.delivery, l10n)),
                icon: const Icon(Icons.local_shipping_outlined),
              ),
              ButtonSegment(
                value: DeliveryType.pickup,
                label: Text(deliveryTypeLabel(DeliveryType.pickup, l10n)),
                icon: const Icon(Icons.storefront_outlined),
              ),
            ],
            selected: {_deliveryType},
            onSelectionChanged: (selection) =>
                setState(() => _deliveryType = selection.first),
          ),
          const SizedBox(height: BldSpacing.lg),

          // Başlangıç tarihi.
          SectionHeader(
            title: l10n.subscriptionCreateStart,
            padding: const EdgeInsets.only(
              left: BldSpacing.xs,
              bottom: BldSpacing.sm,
            ),
          ),
          BldCard(
            onTap: _pickStartDate,
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 20,
                  color: bldColor(BldColors.brand600),
                ),
                const SizedBox(width: BldSpacing.md),
                Text(_humanDate(_startDate), style: textTheme.titleMedium),
                const Spacer(),
                Icon(
                  Icons.edit_outlined,
                  color: bldColor(BldColors.neutral400),
                ),
              ],
            ),
          ),
          const SizedBox(height: BldSpacing.lg),

          // Not.
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.subscriptionCreateNote,
              alignLabelWithHint: true,
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: BldSpacing.md),
            FormErrorBox(message: _error!),
          ],

          const SizedBox(height: BldSpacing.lg),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.subscriptionCreateSubmit),
          ),
          const SizedBox(height: BldSpacing.md),
        ],
      ),
    );
  }

  /// Sunucu `date` bekler: "2026-08-15" (zaman dilimi karışmasın).
  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static const _months = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  static String _humanDate(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';
}
