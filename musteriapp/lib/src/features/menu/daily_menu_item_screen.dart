/// Günün menüsündeki tek bir kalemin detayı — görsel, açıklama, alerjenler,
/// seçenekler, adet, not ve sepete ekleme.
///
/// **KATALOG ÜRÜN DETAYININ YERİNİ ALDI** (B-19). Eski ekran ürünü bütün
/// menüden çözüyordu; bu ekran onu O GÜNÜN menüsünden çözüyor. Fark sadece
/// veri kaynağı değil: bir kalem yalnızca belirli günlerde satılıyor ve
/// fiyatı o güne özel olabiliyor (`DailyMenuItem.effective_unit_price`).
/// Ürünü günden bağımsız açan bir ekran, hangi günün fiyatını gösterdiğini
/// söyleyemezdi.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/catalog_providers.dart';
import '../../theme/bld_semantic_colors.dart';
import '../../theme/bld_theme.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/money_text.dart';
import '../../widgets/network_food_image.dart';
import '../../widgets/pill.dart';
import '../../widgets/status_views.dart';
import '../../widgets/stock_pill.dart';
import '../cart/cart_controller.dart';
import '../cart/cart_model.dart';
import 'daily_menu_cart.dart';

class DailyMenuItemScreen extends ConsumerWidget {
  const DailyMenuItemScreen({
    super.key,
    required this.date,
    required this.menuItemId,
  });

  /// Kalemin ait olduğu servis günü (`YYYY-AA-GG`).
  final String date;
  final int menuItemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final menuAsync = ref.watch(dailyMenuProvider(date));
    final locationAsync = ref.watch(locationProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          menuAsync.valueOrNull?.menu.itemFor(menuItemId)?.name ??
              l10n.dailyMenuTitle,
        ),
      ),
      body: menuAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(dailyMenuProvider(date)),
        ),
        data: (snapshot) {
          final item = snapshot.menu.itemFor(menuItemId);
          if (item == null) {
            // Derin bağlantı ya da eski bir bildirim, o gün olmayan bir
            // kaleme işaret ediyor olabilir. Çökmek yerine söyleniyor.
            return EmptyView(
              icon: Icons.search_off_outlined,
              title: l10n.errorNotFound,
              message: l10n.dailyMenuItemMissing(BusinessDate.long(date)),
            );
          }

          final location = locationAsync.valueOrNull?.location;
          if (location == null) return const LoadingView();

          return _ItemForm(
            item: item,
            menu: snapshot.menu,
            location: location,
          );
        },
      ),
    );
  }
}

class _ItemForm extends ConsumerStatefulWidget {
  const _ItemForm({
    required this.item,
    required this.menu,
    required this.location,
  });

  final MenuItem item;
  final DailyMenu menu;
  final Location location;

  @override
  ConsumerState<_ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends ConsumerState<_ItemForm> {
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
      if (option.required &&
          !option.isMultiSelect &&
          option.values.isNotEmpty) {
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

  /// Bu kalemin bağlı olduğu kalan porsiyon: gün toplamı ile kalem tavanından
  /// hangisi darsa o. **`null` sınırsız.**
  int? get _remaining => effectiveRemaining(
    dayRemaining: widget.menu.remainingPortions,
    itemRemaining: widget.item.remainingPortions,
  );

  /// Sepete daha kaç tane girebilir? (`bld_core` `maxAddable`)
  int _room(Cart cart) => maxAddable(
    dayRemaining: widget.menu.remainingPortions,
    itemRemaining: widget.item.remainingPortions,
    alreadyInCartForDay: cart.quantityOn(widget.menu.date),
    alreadyInCartForItem: cart.quantityOfItemOn(
      widget.menu.date,
      widget.item.id,
    ),
    hardMax: kMaxCartLineQuantity,
  );

  /// Sepete eklemeyi engelleyen sebep; yoksa `null`.
  ///
  /// Sıra ÖNEMLİ: en dıştaki engel önce söyleniyor. "Tükendi" demek, aslında
  /// o güne hiç sipariş alınmıyorken müşteriyi yarın tekrar denemeye
  /// gönderirdi. Aynı gerekçeyle stok en sonda ve İKİ cümleye ayrılmış:
  /// yemek gerçekten bitti mi, yoksa kalanın tamamı zaten sepette mi?
  String? _blocker(int room) {
    final l10n = AppLocalizations.of(context);
    if (!widget.location.acceptsOrders) {
      return widget.location.orderingPauseReason ?? l10n.menuOrderingClosed;
    }
    if (!widget.menu.isOrderable) {
      return dailyMenuUnavailableLabelsTr[widget.menu.unavailableReason] ??
          l10n.dailyMenuNotOrderable;
    }
    if (!widget.item.isAvailable) {
      return widget.item.soldOutToday
          ? (widget.item.soldOutReason ?? l10n.productSoldOutToday)
          : l10n.productUnavailableNotice;
    }
    if (stockLevel(remaining: _remaining, lowThreshold: 0) ==
        StockLevel.soldOut) {
      return l10n.stockSoldOutNotice;
    }
    if (room <= 0) return l10n.cartStockAllInCart;
    return null;
  }

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
    if (!_requiredOptionsSatisfied) {
      setState(() => _showMissingOptionWarning = true);
      return;
    }

    final result = ref
        .read(cartProvider.notifier)
        .add(
          item: widget.item,
          locationId: widget.location.id,
          serviceDate: widget.menu.date,
          quantity: _quantity,
          // Gün toplamı kalemin kendi alanında YOK; verilmezse gün dolmuşken
          // bu kalem sınırsız görünür.
          dayRemaining: widget.menu.remainingPortions,
          optionValueIds: _selectedValueIds.toList(),
          note: _note.text,
        );

    showCartAddFeedback(
      context,
      result,
      itemName: widget.item.name,
      date: widget.menu.date,
    );
    if (context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final item = widget.item;
    final room = _room(ref.watch(cartProvider));
    final blocker = _blocker(room);

    // Tavan sepetteki adede göre daralabiliyor (başka bir sekmeden eklendi,
    // yönetici tavanı indirdi). Seçili adet o zaman kendiliğinden iniyor:
    // ekranda 5 yazarken sunucunun 2 kabul etmesi, hatayı en son adımda ve
    // en pahalı yerde gösterirdi.
    if (room > 0 && _quantity > room) _quantity = room;

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
              const SizedBox(height: BldSpacing.md),
              // Hangi GÜNÜN kalemi olduğu başlıktan önce: fiyat o güne ait
              // olabiliyor ve müşteri hangi güne baktığını bilmeden adet
              // seçmemeli.
              BldPill(
                label: l10n.dailyMenuOfDay(BusinessDate.long(widget.menu.date)),
                variant: BldPillVariant.brand,
                icon: Icons.event_outlined,
              ),
              const SizedBox(height: BldSpacing.sm),
              Text(item.name, style: theme.textTheme.headlineSmall),
              const SizedBox(height: BldSpacing.sm),
              Wrap(
                spacing: BldSpacing.sm,
                runSpacing: BldSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  MoneyText(item.price, scale: MoneyScale.md),
                  StockPill(remaining: _remaining),
                ],
              ),
              if (item.description != null && item.description!.isNotEmpty) ...[
                const SizedBox(height: BldSpacing.md),
                Text(item.description!, style: theme.textTheme.bodyMedium),
              ],
              if (item.allergens.isNotEmpty) ...[
                const SizedBox(height: BldSpacing.md),
                _AllergenNotice(allergens: item.allergens),
              ],
              if (blocker != null) ...[
                const SizedBox(height: BldSpacing.md),
                FormErrorBox(message: blocker),
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
              Text(l10n.productQuantity, style: theme.textTheme.titleMedium),
              const SizedBox(height: BldSpacing.sm),
              _QuantityStepper(
                quantity: _quantity,
                max: room,
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
          label: l10n.productAddToCart,
          total: _unitPrice * _quantity,
          onPressed: blocker == null ? _addToCart : null,
        ),
      ],
    );
  }
}

class _AllergenNotice extends StatelessWidget {
  const _AllergenNotice({required this.allergens});

  final List<String> allergens;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bld = context.bld;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 16, color: bld.decorativeBorder),
        const SizedBox(width: BldSpacing.sm),
        Expanded(
          child: Text(
            l10n.productAllergens(allergens.join(', ')),
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

/// Alttan sabit "sepete ekle" çubuğu — üstten yumuşak gölge içeriği ayırır.
class _StickyAddBar extends StatelessWidget {
  const _StickyAddBar({
    required this.label,
    required this.total,
    required this.onPressed,
  });

  final String label;
  final int total;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // Yükseltme AÇIK temada gölge, KOYU temada açıklık adımıdır; ikisini de
    // `BldSurfaceLevel` biliyor.
    const level = BldSurfaceLevel.raised;

    return Container(
      decoration: BoxDecoration(
        color: level.surfaceOf(context),
        boxShadow: level.shadowsOf(context),
        border: level.highlightOf(context),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(BldSpacing.md),
          child: FilledButton(
            onPressed: onPressed,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label),
                MoneyText(
                  total,
                  scale: MoneyScale.sm,
                  tone: onPressed == null
                      ? MoneyTone.muted
                      : MoneyTone.onPrimary,
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
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(option.name, style: theme.textTheme.titleMedium),
            ),
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
          style: theme.textTheme.bodySmall,
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
    final theme = Theme.of(context);
    final bld = context.bld;
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
              ? theme.colorScheme.secondaryContainer
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(BldRadius.md),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : bld.decorativeBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(
              multiSelect
                  ? (selected
                        ? Icons.check_box_outlined
                        : Icons.check_box_outline_blank)
                  : (selected
                        ? Icons.radio_button_checked_outlined
                        : Icons.radio_button_unchecked_outlined),
              color: selected
                  ? theme.colorScheme.primary
                  : bld.decorativeBorder,
            ),
            const SizedBox(width: BldSpacing.sm),
            Expanded(child: Text(value.name)),
            if (delta != 0)
              // İşaretli fark: `+2,50 ₺` / `-2,50 ₺`.
              MoneyText(
                delta,
                scale: MoneyScale.sm,
                tone: MoneyTone.difference,
                showPlusSign: true,
              ),
          ],
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.max,
    required this.onChanged,
  });

  final int quantity;

  /// Sepete daha kaç tane girebileceği (`bld_core` `maxAddable`).
  ///
  /// Artı düğmesi bu sayıda KAPANIR. Kapatmasaydık müşteri 8'e çıkarır,
  /// "sepete ekle"ye basar ve tek bir uyarıyla 8'in de reddedildiğini
  /// görürdü; sayacı kapatmak reddi hiç doğurmuyor.
  final int max;

  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bld = context.bld;

    return Container(
      decoration: BoxDecoration(
        color: bld.canvas,
        borderRadius: BorderRadius.circular(BldRadius.pill),
        border: Border.all(color: bld.decorativeBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove_outlined,
            semanticLabel: AppLocalizations.of(context).commonDecrease,
            onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
          ),
          SizedBox(
            width: 44,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ),
          _StepButton(
            icon: Icons.add_outlined,
            semanticLabel: AppLocalizations.of(context).commonIncrease,
            onPressed: quantity < max ? () => onChanged(quantity + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bld = context.bld;
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
            semanticLabel: semanticLabel,
            color: enabled ? theme.colorScheme.primary : bld.placeholder,
          ),
        ),
      ),
    );
  }
}
