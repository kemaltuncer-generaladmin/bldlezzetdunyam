/// Tüm ekranların dokunmatik girişi — "İşlemler" alt sayfası.
///
/// KURAL (12.08.2026): **klavye kısayolu olan her işin dokunmatik bir
/// karşılığı olacak.** Kasada dokunmatik kip açıkken klavye ve fare takılı
/// değil; yalnız klavyeden açılabilen bir ekran, o kasada yok demektir.
///
/// Kapatılan üç açık: vardiya özeti (F3) hiçbir yerden dokunuşla
/// açılmıyordu; satış kontrolü (F7) yalnız satış **kapalıyken** çıkan
/// şeritten açılıyordu — yani dokunmatik kasada satışı kapatmanın yolu
/// yoktu; abonelik planı (F8) yalnız abonelik siparişi varken görünen
/// şeritten açılıyordu.
///
/// KLAVYE KISAYOLLARI DURUYOR: klavyeli bir kasada F7 hâlâ çalışıyor. Bu
/// alt sayfa onların yerine değil, yanına eklendi.
library;

import 'dart:async';

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../sales/sales_control_screen.dart';
import '../../settings/lock_ui.dart';
import '../../settings/settings_screen.dart';
import '../../subscription/subscription_plan_screen.dart';
import 'health_panel_dialog.dart';
import 'shift_summary_dialog.dart';

/// İşlemler alt sayfasını açar.
Future<void> showActionsSheet(BuildContext context) async {
  final l10n = AppL10n.of(context);
  final navigator = Navigator.of(context);

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(KdsColors.surface),
    // `Consumer` — alt sayfa bir işlevden açılıyor ve `ref` taşımıyor.
    // Kilit durumu SAYFA AÇIKKEN de değişebilir (sağlık turu yeni ayarı
    // getirir); izlemek satırları anında günceller.
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final settings = ref.watch(kdsSettingsProvider);
        final lockText = lockMessageFor(l10n, settings.lockMessage);

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: BldSpacing.sm),
              Text(
                l10n.actionsTitle,
                style: const TextStyle(
                  fontSize: KdsTextScale.columnHeader,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: BldSpacing.sm),
              _ActionRow(
                icon: Icons.point_of_sale,
                label: l10n.salesTitle,
                lockNote: settings.allowSalesControl ? null : lockText,
                // ÖNCE ALT SAYFA KAPANIR: kapanmazsa dönüşte ekranın üstünde
                // asılı kalıyor ve personel panoyu göremiyor.
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(navigator.push(SalesControlScreen.route()));
                },
              ),
              _ActionRow(
                icon: Icons.event_repeat,
                label: l10n.planTitle,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(navigator.push(SubscriptionPlanScreen.route()));
                },
              ),
              _ActionRow(
                icon: Icons.summarize_outlined,
                label: l10n.shiftSummaryTitle,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(showShiftSummaryDialog(context));
                },
              ),
              _ActionRow(
                icon: Icons.monitor_heart_outlined,
                label: l10n.healthOpen,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(showHealthPanelDialog(context));
                },
              ),
              _ActionRow(
                icon: Icons.settings_outlined,
                label: l10n.settings,
                lockNote: settings.allowSettings ? null : lockText,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(navigator.push(SettingsScreen.route()));
                },
              ),
              const SizedBox(height: BldSpacing.md),
            ],
          ),
        );
      },
    ),
  );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.lockNote,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Kilitliyse gösterilecek metin; `null` ise satır serbest.
  ///
  /// METİN SATIRIN İÇİNDE, ŞERİTTE DEĞİL: alt sayfa ekranın altını
  /// kapatıyor ve orada açılan bir uyarı şeridi sayfanın ARKASINDA kalır.
  /// Personelin göremeyeceği bir açıklama, açıklama değildir.
  final String? lockNote;

  @override
  Widget build(BuildContext context) {
    final locked = lockNote != null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: BldSpacing.lg,
        vertical: BldSpacing.sm,
      ),
      // Satır GİZLENMEZ: kaybolan bir giriş, personeli "menü bozuldu"
      // sanısına iter (K-21 §5.4).
      enabled: !locked,
      leading: LockedIcon(icon: icon, locked: locked, size: 32),
      title: Text(
        label,
        style: const TextStyle(fontSize: KdsTextScale.orderNumber),
      ),
      subtitle: locked
          ? Text(
              lockNote!,
              style: const TextStyle(
                fontSize: KdsTextScale.statusBar,
                color: Color(BldColors.warning),
              ),
            )
          : null,
      trailing: locked
          ? const Icon(
              Icons.lock_outline,
              size: 28,
              color: Color(BldColors.warning),
            )
          : null,
      onTap: locked ? null : onTap,
    );
  }
}
