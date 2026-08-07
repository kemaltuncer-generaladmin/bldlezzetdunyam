/// Abonelik talebi oluşturma.
///
/// Bu bir TALEP'tir: fiyat ekibimizce belirlenir (`status = pending`). Müşteri
/// ürünleri (menü kalemleri), günleri, teslimatı ve başlangıcı seçer; bu
/// ürünler aboneliğin SATIRLARI olur ve her servis günü sipariş üretir. Fiyat
/// alanı yoktur — istemci fiyat hesaplamaz.
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
import '../../widgets/network_food_image.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_views.dart';
import 'subscriptions_screen.dart';

/// Talebe eklenmiş bir ürün ve günlük adedi.
class _PickedProduct {
  _PickedProduct(this.item, this.quantity);

  final MenuItem item;
  int quantity;
}

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

  /// Eklenen ürünler (menuId → ürün + adet).
  final Map<int, _PickedProduct> _picked = {};

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

  int get _totalPortions =>
      _picked.values.fold(0, (sum, p) => sum + p.quantity);

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

  Future<void> _addProduct(List<MenuItem> items) async {
    final selected = await showModalBottomSheet<MenuItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ProductPickerSheet(items: items),
    );
    if (selected == null) return;
    setState(() {
      final existing = _picked[selected.id];
      if (existing != null) {
        existing.quantity++;
      } else {
        _picked[selected.id] = _PickedProduct(selected, 1);
      }
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (_picked.isEmpty) {
      setState(() => _error = l10n.subscriptionCreatePickProduct);
      return;
    }
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
    final lines = [
      for (final p in _picked.values)
        SubscriptionCreateItem(
          menuId: p.item.id,
          quantity: p.quantity,
          label: p.item.name,
        ),
    ];

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
              defaultQuantity: _totalPortions < 1 ? 1 : _totalPortions,
              lines: lines,
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

    final location = ref.watch(locationProvider).valueOrNull;
    final menuItems = location == null
        ? const <MenuItem>[]
        : (ref.watch(menuProvider(location.location.id)).valueOrNull?.allItems ??
                  const <MenuItem>[])
              .where((i) => i.isAvailable)
              .toList();

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

          // Ürünler — aboneliğin satırları.
          SectionHeader(
            title: l10n.subscriptionCreateProducts,
            padding: const EdgeInsets.only(
              left: BldSpacing.xs,
              bottom: BldSpacing.sm,
            ),
          ),
          if (_picked.isEmpty)
            BldCard(
              child: Text(
                l10n.subscriptionCreateNoProducts,
                style: textTheme.bodyMedium?.copyWith(
                  color: bldColor(BldColors.neutral600),
                ),
              ),
            )
          else
            for (final entry in _picked.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: BldSpacing.sm),
                child: _PickedRow(
                  product: entry.value,
                  onIncrement: () =>
                      setState(() => entry.value.quantity++),
                  onDecrement: () => setState(() {
                    if (entry.value.quantity > 1) {
                      entry.value.quantity--;
                    } else {
                      _picked.remove(entry.key);
                    }
                  }),
                  onRemove: () => setState(() => _picked.remove(entry.key)),
                ),
              ),
          const SizedBox(height: BldSpacing.sm),
          OutlinedButton.icon(
            onPressed: menuItems.isEmpty ? null : () => _addProduct(menuItems),
            icon: const Icon(Icons.add),
            label: Text(l10n.subscriptionCreateAddProduct),
          ),
          const SizedBox(height: BldSpacing.lg),

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

/// Eklenmiş ürün satırı — ad + adet ayarı + kaldır.
class _PickedRow extends StatelessWidget {
  const _PickedRow({
    required this.product,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  final _PickedProduct product;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return BldCard(
      padding: const EdgeInsets.symmetric(
        horizontal: BldSpacing.sm,
        vertical: BldSpacing.sm,
      ),
      child: Row(
        children: [
          NetworkFoodImage(
            url: product.item.imageUrl,
            width: 44,
            height: 44,
            radius: BldRadius.sm,
          ),
          const SizedBox(width: BldSpacing.sm),
          Expanded(
            child: Text(
              product.item.name,
              style: textTheme.bodyLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onDecrement,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text('${product.quantity}', style: textTheme.titleMedium),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onIncrement,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}

/// Menüden ürün seçme alt sayfası. Seçilen [MenuItem]'ı geri döndürür.
class _ProductPickerSheet extends StatelessWidget {
  const _ProductPickerSheet({required this.items});

  final List<MenuItem> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BldSpacing.md,
                0,
                BldSpacing.md,
                BldSpacing.sm,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.subscriptionCreatePickerTitle,
                  style: textTheme.titleLarge,
                ),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: BldSpacing.md,
                ),
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: BldSpacing.sm),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return BldCard(
                    padding: const EdgeInsets.all(BldSpacing.sm),
                    onTap: () => Navigator.of(context).pop(item),
                    child: Row(
                      children: [
                        NetworkFoodImage(
                          url: item.imageUrl,
                          width: 48,
                          height: 48,
                          radius: BldRadius.sm,
                        ),
                        const SizedBox(width: BldSpacing.md),
                        Expanded(
                          child: Text(
                            item.name,
                            style: textTheme.bodyLarge,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.add_circle,
                          color: bldColor(BldColors.brand600),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: BldSpacing.md),
          ],
        ),
      ),
    );
  }
}
