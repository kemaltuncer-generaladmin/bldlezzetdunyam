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

import '../../l10n/app_localizations.dart';
import '../../sales/sales_control_screen.dart';
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
    builder: (sheetContext) => SafeArea(
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
            onTap: () {
              Navigator.of(sheetContext).pop();
              unawaited(navigator.push(SettingsScreen.route()));
            },
          ),
          const SizedBox(height: BldSpacing.md),
        ],
      ),
    ),
  );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(
      horizontal: BldSpacing.lg,
      vertical: BldSpacing.sm,
    ),
    leading: Icon(icon, size: 32),
    title: Text(
      label,
      style: const TextStyle(fontSize: KdsTextScale.orderNumber),
    ),
    onTap: onTap,
  );
}
