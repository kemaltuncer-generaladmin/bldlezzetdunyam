/// KDS ana ekranı — `docs/05-mutfakapp.md` §3.
///
/// Beş bölge, yukarıdan aşağı: üretim şeridi, alarm/arama çubuğu, kesinti
/// şeridi (yalnızca gerekince), üç sütunlu pano, durum çubuğu. Pano her
/// zaman kalan tüm yeri alır — çevresindeki şeritler bilgi taşır ama panonun
/// yerini çalmaz.
///
/// Tuş takımı da buradadır: mutfakta fare kullanılmıyor (`docs/05` §1), bu
/// yüzden panonun tamamı klavyeyle sürülebilir. Kısayolların listesi `F1` ile
/// açılır; ezberlenmesi beklenen bir şey yok.
library;

import 'dart:async';

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../l10n/app_localizations.dart';
import 'board.dart';
import 'new_order_highlights.dart';
import 'widgets/kds_alert_banner.dart';
import 'widgets/kds_header_bar.dart';
import 'widgets/health_panel_dialog.dart';
import 'widgets/kds_status_bar.dart';
import 'widgets/keyboard_help_dialog.dart';
import 'widgets/order_column.dart';
import 'widgets/production_strip.dart';
import 'widgets/shift_summary_dialog.dart';

class KdsScreen extends ConsumerWidget {
  const KdsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `CallbackShortcuts` yalnızca odak kendi alt ağacındayken çalışır; bu
    // yüzden içeride odağı kendine çeken bir düğüm var. Arama kutusuna
    // tıklandığında odak oraya geçer ve ok tuşları imleci hareket ettirir —
    // istenen davranış budur.
    return CallbackShortcuts(
      bindings: _bindings(context, ref),
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                ProductionStrip(totals: ref.watch(productionTotalsProvider)),
                const KdsHeaderBar(),
                const KdsAlertBanner(),
                const Expanded(child: _Board()),
                const KdsStatusBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<ShortcutActivator, VoidCallback> _bindings(
    BuildContext context,
    WidgetRef ref,
  ) {
    final selection = ref.read(boardSelectionProvider.notifier);

    void advanceSelected() {
      final order = selection.selectedOrder();
      if (order != null) unawaited(advanceOrder(context, ref, order.id));
    }

    return <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
          selection.moveVertically(1),
      const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
          selection.moveVertically(-1),
      const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
          selection.moveHorizontally(1),
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
          selection.moveHorizontally(-1),
      const SingleActivator(LogicalKeyboardKey.enter): advanceSelected,
      const SingleActivator(LogicalKeyboardKey.numpadEnter): advanceSelected,
      const SingleActivator(LogicalKeyboardKey.escape): () {
        ref.read(searchQueryProvider.notifier).clear();
        selection.clear();
      },
      const SingleActivator(LogicalKeyboardKey.f1): () =>
          unawaited(showKeyboardHelpDialog(context)),
      const SingleActivator(LogicalKeyboardKey.f2): () =>
          ref.read(searchFocusProvider).requestFocus(),
      const SingleActivator(LogicalKeyboardKey.f3): () =>
          unawaited(showShiftSummaryDialog(context)),
      const SingleActivator(LogicalKeyboardKey.f4): () =>
          ref.read(newOrderAlarmProvider.notifier).silence(),
      const SingleActivator(LogicalKeyboardKey.f5): () =>
          unawaited(refreshBoard(context, ref)),
      const SingleActivator(LogicalKeyboardKey.f6): () =>
          unawaited(showHealthPanelDialog(context)),
    };
  }
}

/// Seçili kartı bir adım ilerletir ve sonucu personele bildirir.
///
/// Geri alma yoktur (`docs/05` §3): buton tek yön çalışır, hata görünür olur.
/// Çift dokunma ve bayat kart koruması [OrderActionController]'dadır.
Future<void> advanceOrder(
  BuildContext context,
  WidgetRef ref,
  int orderId,
) async {
  // Mesajlaşıcı ve metinler `await`ten ÖNCE alınır: sonrasında `context`
  // kullanmak, kart bu arada ekrandan düşmüşse çökme sebebidir.
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppL10n.of(context);

  final outcome = await ref.read(orderActionProvider.notifier).advance(orderId);

  switch (outcome.result) {
    case OrderAdvanceResult.ok:
    case OrderAdvanceResult.ignored:
      return;
    case OrderAdvanceResult.conflict:
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(BldColors.warning),
          content: Text(
            l10n.statusChangeConflict,
            style: const TextStyle(
              fontSize: KdsTextScale.statusBar,
              color: Color(BldColors.neutral900),
            ),
          ),
        ),
      );
    case OrderAdvanceResult.failed:
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(BldColors.danger),
          content: Text(
            l10n.statusChangeFailed(outcome.message ?? ''),
            style: const TextStyle(fontSize: KdsTextScale.statusBar),
          ),
        ),
      );
  }
}

/// Elle tam yenileme (`F5` ve durum çubuğundaki düğme).
///
/// Kaçırılan durum değişimlerini toparlar; personel "ekran takıldı mı"
/// dediğinde servisi yeniden başlatmak zorunda kalmasın.
Future<void> refreshBoard(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppL10n.of(context);

  try {
    await ref.read(orderSourceProvider).refresh();
  } on Object catch (error) {
    final message = error is ApiException ? error.message : '$error';
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: const Color(BldColors.danger),
        content: Text(
          l10n.refreshFailed(message),
          style: const TextStyle(fontSize: KdsTextScale.statusBar),
        ),
      ),
    );
  }
}

class _Board extends ConsumerWidget {
  const _Board();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final board = ref.watch(boardProvider);
    final highlights = ref.watch(newOrderHighlightsProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now().toUtc();
    final thresholds = ref.watch(urgencyThresholdsProvider);
    final busyIds = ref.watch(orderActionProvider);
    final progress = ref.watch(orderItemProgressProvider);

    // Yükleniyor ile "hiç sipariş yok" AYRI durumlardır. İlk liste gelmeden
    // "Bekleyen sipariş yok" yazmak, mutfağa sakin bir gün olduğunu söyler.
    if (ref.watch(boardLoadingProvider)) return const _LoadingBoard();
    if (ref.watch(visibleOrderCountProvider) == 0) return const _EmptyBoard();

    final selection = ref.watch(boardSelectionProvider).clampedTo({
      for (final entry in board.entries) entry.key: entry.value.length,
    });

    final titles = <KdsColumn, String>{
      KdsColumn.yeni: l10n.columnNew,
      KdsColumn.hazirlaniyor: l10n.columnPreparing,
      KdsColumn.hazir: l10n.columnReady,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BldSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final column in KdsColumn.values) ...[
            if (column != KdsColumn.values.first)
              const SizedBox(width: BldSpacing.md),
            Expanded(
              child: OrderColumn(
                column: column,
                title: titles[column]!,
                orders: board[column]!,
                highlightedIds: highlights,
                busyIds: busyIds,
                progress: progress,
                selectedIndex: selection.column == column
                    ? selection.index
                    : null,
                now: now,
                thresholds: thresholds,
                onAdvance: (order) =>
                    unawaited(advanceOrder(context, ref, order.id)),
                onToggleItem: (order, index) => ref
                    .read(orderItemProgressProvider.notifier)
                    .toggle(order.id, index),
                onReprint: (order, type) => _reprint(context, ref, order, type),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Fişi kuyruğa geri koyar. Basımın kendisi kuyruk işçisinin işidir; bu
  /// yüzden onay mesajı "basıldı" değil "kuyruğa alındı" der — yazıcı
  /// kapalıysa kâğıt hemen çıkmaz ve yalan söylememeliyiz.
  void _reprint(
    BuildContext context,
    WidgetRef ref,
    KitchenOrder order,
    ReceiptType type,
  ) {
    ref.read(printServiceProvider).reprint(order.id, type);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppL10n.of(context).reprintQueued(order.orderNumber),
          style: const TextStyle(fontSize: KdsTextScale.statusBar),
        ),
      ),
    );
  }
}

/// İlk liste beklenirken. Boş panodan ayrı bir ekran olması bilinçlidir:
/// "henüz sormadık" ile "sorduk, sipariş yok" mutfakta farklı iki cevaptır.
class _LoadingBoard extends StatelessWidget {
  const _LoadingBoard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(strokeWidth: 6),
          ),
          const SizedBox(height: BldSpacing.lg),
          Text(
            l10n.boardLoading,
            style: const TextStyle(
              fontSize: KdsTextScale.columnHeader,
              fontWeight: FontWeight.bold,
              color: Color(KdsColors.onSurfaceMuted),
            ),
          ),
          const SizedBox(height: BldSpacing.sm),
          Text(
            l10n.boardLoadingHint,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: KdsTextScale.statusBar,
              color: Color(KdsColors.onSurfaceMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pano boşken ne yazdığı önemlidir: "hata mı var, yoksa gerçekten sipariş mi
/// yok" sorusu mutfakta her sabah sorulur. Arama açıkken sebep de çıkış yolu
/// da farklıdır — bu yüzden iki ayrı metin.
class _EmptyBoard extends ConsumerWidget {
  const _EmptyBoard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final filtering = ref.watch(searchQueryProvider).trim().isNotEmpty;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            filtering ? Icons.search_off : Icons.ramen_dining_outlined,
            size: 96,
            color: const Color(KdsColors.surfaceRaised),
          ),
          const SizedBox(height: BldSpacing.md),
          Text(
            filtering ? l10n.searchNoResult : l10n.boardEmpty,
            style: const TextStyle(
              fontSize: KdsTextScale.columnHeader,
              fontWeight: FontWeight.bold,
              color: Color(KdsColors.onSurfaceMuted),
            ),
          ),
          const SizedBox(height: BldSpacing.sm),
          if (filtering)
            TextButton.icon(
              onPressed: ref.read(searchQueryProvider.notifier).clear,
              icon: const Icon(Icons.close),
              label: Text(
                l10n.searchClear,
                style: const TextStyle(fontSize: KdsTextScale.statusBar),
              ),
            )
          else
            Text(
              l10n.boardEmptyHint,
              style: const TextStyle(
                fontSize: KdsTextScale.statusBar,
                color: Color(KdsColors.onSurfaceMuted),
              ),
            ),
        ],
      ),
    );
  }
}
