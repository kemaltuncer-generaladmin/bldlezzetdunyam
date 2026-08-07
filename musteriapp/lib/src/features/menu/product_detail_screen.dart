/// Ürün detayı — görsel, açıklama, seçenekler, adet, not, sepete ekle
/// (`docs/07-musteriapp.md` §2).
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/catalog_providers.dart';
import '../../theme/bld_theme.dart';
import '../../widgets/network_food_image.dart';
import '../../widgets/pill.dart';
import '../../widgets/status_views.dart';
import '../cart/cart_controller.dart';

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.menuItemId});

  final int menuItemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final itemAsync = ref.watch(menuItemProvider(menuItemId));
    final locationAsync = ref.watch(locationProvider);

    return Scaffold(
      appBar: AppBar(title: Text(itemAsync.valueOrNull?.name ?? l10n.menuTitle)),
      body: itemAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(menuItemProvider(menuItemId)),
        ),
        data: (item) {
          if (item == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(BldSpacing.lg),
                child: Text(l10n.errorNotFound, textAlign: TextAlign.center),
              ),
            );
          }
          final locationId = locationAsync.valueOrNull?.location.id;
          if (locationId == null) return const LoadingView();

          return _ProductForm(item: item, locationId: locationId);
        },
      ),
    );
  }
}

class _ProductForm extends ConsumerStatefulWidget {
  const _ProductForm({required this.item, required this.locationId});

  final MenuItem item;
  final int locationId;

  @override
  ConsumerState<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<_ProductForm> {
  final _note = TextEditingController();

  /// Seçenek kimliği → seçilen değer kimlikleri.
  final Map<int, Set<int>> _selection = {};

  int _quantity = 1;
  bool _showMissingOptionWarning = false;

  @override
  void initState() {
    super.initState();
    // Zorunlu tek seçimli seçeneklerde ilk değer önceden işaretlenir; kullanıcı
    // hiçbir şeye dokunmadan sepete ekleyebilsin.
    for (final option in widget.item.options) {
      if (option.required && !option.isMultiSelect && option.values.isNotEmpty) {
        _selection[option.id] = {option.values.first.id};
      }
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Set<int> get _selectedValueIds =>
      _selection.values.expand((ids) => ids).toSet();

  /// Zorunlu seçeneklerin hepsi işaretli mi?
  bool get _requiredOptionsSatisfied => widget.item.options
      .where((option) => option.required)
      .every((option) => (_selection[option.id] ?? const <int>{}).isNotEmpty);

  int get _unitPrice => widget.item.unitPriceWith(_selectedValueIds);

  void _toggle(MenuOption option, MenuOptionValue value) {
    setState(() {
      final current = _selection[option.id] ?? <int>{};
      if (option.isMultiSelect) {
        if (current.contains(value.id)) {
          current.remove(value.id);
        } else {
          current.add(value.id);
        }
        _selection[option.id] = current;
      } else {
        // Bilinmeyen tip tek seçim gibi ele alınır (`MenuOption.isMultiSelect`).
        _selection[option.id] = {value.id};
      }
      _showMissingOptionWarning = false;
    });
  }

  void _addToCart() {
    final l10n = AppLocalizations.of(context);
    if (!_requiredOptionsSatisfied) {
      setState(() => _showMissingOptionWarning = true);
      return;
    }

    ref
        .read(cartProvider.notifier)
        .add(
          item: widget.item,
          locationId: widget.locationId,
          quantity: _quantity,
          optionValueIds: _selectedValueIds.toList(),
          note: _note.text,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.productAdded(widget.item.name))),
    );
    if (context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final item = widget.item;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              BldSpacing.md,
              BldSpacing.md,
              BldSpacing.md,
              BldSpacing.lg,
            ),
            children: [
              NetworkFoodImage(url: item.imageUrl, aspectRatio: 16 / 9),
              const SizedBox(height: BldSpacing.lg),
              Text(item.name, style: textTheme.headlineSmall),
              const SizedBox(height: BldSpacing.sm),
              Text(
                Money.format(item.price),
                style: TextStyle(
                  color: bldColor(BldColors.brand700),
                  fontWeight: FontWeight.w700,
                  fontSize: BldTextScale.title,
                ),
              ),
              if (item.description != null && item.description!.isNotEmpty) ...[
                const SizedBox(height: BldSpacing.md),
                Text(item.description!, style: textTheme.bodyMedium),
              ],
              if (item.allergens.isNotEmpty) ...[
                const SizedBox(height: BldSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: bldColor(BldColors.neutral400),
                    ),
                    const SizedBox(width: BldSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.productAllergens(item.allergens.join(', ')),
                        style: textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
              if (!item.isAvailable) ...[
                const SizedBox(height: BldSpacing.md),
                FormErrorBox(message: l10n.productUnavailableNotice),
              ],
              for (final option in item.options) ...[
                const SizedBox(height: BldSpacing.lg),
                _OptionGroup(
                  option: option,
                  selected: _selection[option.id] ?? const <int>{},
                  onToggle: (value) => _toggle(option, value),
                ),
              ],
              const SizedBox(height: BldSpacing.lg),
              Text(l10n.productQuantity, style: textTheme.titleMedium),
              const SizedBox(height: BldSpacing.sm),
              _QuantityStepper(
                quantity: _quantity,
                onChanged: (value) => setState(() => _quantity = value),
              ),
              const SizedBox(height: BldSpacing.lg),
              TextField(
                controller: _note,
                maxLength: 255,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.productNote,
                  hintText: l10n.productNoteHint,
                ),
              ),
              if (_showMissingOptionWarning) ...[
                const SizedBox(height: BldSpacing.sm),
                FormErrorBox(message: l10n.productMissingRequiredOption),
              ],
            ],
          ),
        ),
        _StickyAddBar(
          enabled: item.isAvailable,
          label: l10n.productAddToCart,
          total: Money.format(_unitPrice * _quantity),
          onPressed: _addToCart,
        ),
      ],
    );
  }
}

/// Alttan sabit "sepete ekle" çubuğu — üstten yumuşak gölge içeriği ayırır.
class _StickyAddBar extends StatelessWidget {
  const _StickyAddBar({
    required this.enabled,
    required this.label,
    required this.total,
    required this.onPressed,
  });

  final bool enabled;
  final String label;
  final String total;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bldColor(BldColors.neutral0),
        boxShadow: [
          BoxShadow(
            color: bldColor(BldColors.neutral900).withValues(alpha: 0.06),
            offset: const Offset(0, -4),
            blurRadius: 16,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(BldSpacing.md),
          child: FilledButton(
            onPressed: enabled ? onPressed : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label),
                Text(
                  total,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionGroup extends StatelessWidget {
  const _OptionGroup({
    required this.option,
    required this.selected,
    required this.onToggle,
  });

  final MenuOption option;
  final Set<int> selected;
  final ValueChanged<MenuOptionValue> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(option.name, style: textTheme.titleMedium)),
            if (option.required)
              BldPill(
                label: l10n.commonRequired,
                variant: BldPillVariant.brand,
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          option.isMultiSelect
              ? l10n.productOptionPickMany
              : l10n.productOptionPickOne,
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: BldSpacing.sm),
        for (final value in option.values)
          _OptionRow(
            value: value,
            multiSelect: option.isMultiSelect,
            selected: selected.contains(value.id),
            onTap: () => onToggle(value),
          ),
      ],
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.value,
    required this.multiSelect,
    required this.selected,
    required this.onTap,
  });

  final MenuOptionValue value;
  final bool multiSelect;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final delta = value.priceDelta;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BldRadius.md),
      child: AnimatedContainer(
        duration: bldDuration(BldMotion.fastMs),
        curve: bldCurve(BldEase.standard),
        margin: const EdgeInsets.only(bottom: BldSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: BldSpacing.md - 4,
          vertical: BldSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: selected
              ? bldColor(BldColors.brand50)
              : bldColor(BldColors.neutral0),
          borderRadius: BorderRadius.circular(BldRadius.md),
          border: Border.all(
            color: selected
                ? bldColor(BldColors.brand300)
                : bldColor(BldColors.neutral200),
          ),
        ),
        child: Row(
          children: [
            Icon(
              multiSelect
                  ? (selected ? Icons.check_box : Icons.check_box_outline_blank)
                  : (selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked),
              color: selected
                  ? bldColor(BldColors.brand500)
                  : bldColor(BldColors.neutral400),
            ),
            const SizedBox(width: BldSpacing.sm),
            Expanded(child: Text(value.name)),
            if (delta != 0)
              Text(
                // İşaretli fark: `+2,50 ₺` / `-2,50 ₺`.
                '${delta > 0 ? '+' : ''}${Money.format(delta)}',
                style: TextStyle(
                  color: bldColor(BldColors.neutral600),
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({required this.quantity, required this.onChanged});

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bldColor(BldColors.neutral50),
        borderRadius: BorderRadius.circular(BldRadius.pill),
        border: Border.all(color: bldColor(BldColors.neutral200)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove,
            onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
          ),
          SizedBox(
            width: 44,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          _StepButton(
            icon: Icons.add,
            onPressed: () => onChanged(quantity + 1),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(BldSpacing.sm + 2),
          child: Icon(
            icon,
            size: 20,
            color: enabled
                ? bldColor(BldColors.brand700)
                : bldColor(BldColors.neutral400),
          ),
        ),
      ),
    );
  }
}
