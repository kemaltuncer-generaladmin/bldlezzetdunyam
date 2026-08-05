/// Panonun üst çubuğu: alarm sayacı, yük sayacı ve arama.
///
/// Üç bilgi bir arada durur çünkü hepsi "şu an durum ne" sorusunun
/// parçalarıdır. Alarm rozeti solda ve en büyüktür: ekrana bir metreden
/// bakan şefin ilk göreceği şey geciken sipariş sayısı olmalıdır.
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/kds_theme.dart';

class KdsHeaderBar extends ConsumerWidget {
  const KdsHeaderBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final lateCount = ref.watch(lateOrderCountProvider);
    final total = ref.watch(activeOrdersProvider).length;
    final visible = ref.watch(visibleOrderCountProvider);
    final filtering = ref.watch(searchQueryProvider).trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BldSpacing.md,
        vertical: BldSpacing.sm,
      ),
      color: const Color(KdsColors.background),
      child: Row(
        children: [
          _AlarmBadge(count: lateCount),
          const SizedBox(width: BldSpacing.lg),
          Text(
            filtering
                ? l10n.searchResultCount(visible, total)
                : l10n.activeOrderCount(total),
            style: const TextStyle(
              fontSize: KdsTextScale.orderNumber,
              fontWeight: FontWeight.bold,
              color: Color(KdsColors.onSurfaceMuted),
            ),
          ),
          const Spacer(),
          const SizedBox(width: _searchFieldWidth, child: _SearchField()),
        ],
      ),
    );
  }
}

/// Arama kutusu sabit genişliktedir: esnek olsaydı sipariş sayısı arttıkça
/// yer değiştirir, kas hafızasını bozardı.
const double _searchFieldWidth = 380;

/// Geciken sipariş sayacı.
///
/// Sıfırken de görünür kalır ve yeşil "Gecikme yok" der. Kaybolan bir
/// gösterge, "acaba çalışıyor mu" sorusunu doğurur; sabit duran bir gösterge
/// güven verir.
class _AlarmBadge extends StatelessWidget {
  const _AlarmBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final alarm = count > 0;
    final color = Color(alarm ? BldColors.danger : BldColors.success);
    final foreground = KdsAccents.onAccent(color);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BldSpacing.md,
        vertical: BldSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(BldRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            alarm ? Icons.notification_important : Icons.check_circle_outline,
            size: 26,
            color: foreground,
          ),
          const SizedBox(width: BldSpacing.sm),
          Text(
            alarm ? l10n.lateOrderCount(count) : l10n.noLateOrders,
            style: TextStyle(
              fontSize: KdsTextScale.columnHeader,
              fontWeight: FontWeight.bold,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sipariş no / müşteri / ürün araması.
///
/// Kendi denetleyicisini tutar ama tek doğru kaynak [searchQueryProvider]'dır:
/// aramayı başka bir yerden (ör. "sonuç yok" ekranındaki temizle düğmesi)
/// sıfırlamak mümkün olmalı ve alan buna uymalıdır.
class _SearchField extends ConsumerStatefulWidget {
  const _SearchField();

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final query = ref.watch(searchQueryProvider);

    // Dışarıdan temizlenirse alan da temizlensin. Karşılaştırma şart:
    // koşulsuz atama imleci her tuş vuruşunda başa atar.
    if (_controller.text != query) {
      _controller.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }

    return TextField(
      controller: _controller,
      onChanged: ref.read(searchQueryProvider.notifier).set,
      style: const TextStyle(fontSize: KdsTextScale.orderNumber),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: const Color(KdsColors.surface),
        prefixIcon: const Icon(Icons.search, size: 26),
        suffixIcon: query.isEmpty
            ? null
            : IconButton(
                tooltip: l10n.searchClear,
                icon: const Icon(Icons.close),
                onPressed: ref.read(searchQueryProvider.notifier).clear,
              ),
        labelText: l10n.searchLabel,
        hintText: l10n.searchHint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BldRadius.sm),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
