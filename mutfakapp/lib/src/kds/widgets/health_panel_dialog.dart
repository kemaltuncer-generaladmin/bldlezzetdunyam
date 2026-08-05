/// `F6` — sistem durumu panosu.
///
/// Şefin bir bakışta göreceği dört kutu: yazıcı, sunucu, bugünkü sipariş,
/// alarm sesi. Üstünde canlı tarih ve saat (Europe/Istanbul, dakika dahil).
///
/// **Neden ayrı bir pencere, neden ekranın üstünde sabit bir şerit değil:**
/// asıl iş sipariş kartlarıdır. Kalıcı bir pano her kartın boyundan çalar ve
/// mutfak monitörü zaten dolu. Sürekli görünmesi gereken özet — bağlantı,
/// yazıcı, kuyruk, günlük sayaç, saat — durum çubuğundadır; bu pencere onun
/// uzaktan okunur, ayrıntılı hâlidir.
library;

import 'dart:async';

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/printer_probe.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';

Future<void> showHealthPanelDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => const _HealthPanelDialog(),
);

class _HealthPanelDialog extends ConsumerWidget {
  const _HealthPanelDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);

    return AlertDialog(
      backgroundColor: const Color(KdsColors.background),
      title: Row(
        children: [
          const Icon(
            Icons.monitor_heart_outlined,
            size: 32,
            color: Color(BldColors.brand400),
          ),
          const SizedBox(width: BldSpacing.sm),
          Expanded(
            child: Text(
              l10n.healthTitle,
              style: const TextStyle(
                fontSize: KdsTextScale.columnHeader,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 860,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              _LiveClock(),
              SizedBox(height: BldSpacing.lg),
              _HealthGrid(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () =>
              unawaited(ref.read(kitchenHealthProvider.notifier).poll()),
          icon: const Icon(Icons.sync),
          label: Text(
            l10n.healthRefresh,
            style: const TextStyle(fontSize: KdsTextScale.statusBar),
          ),
        ),
        FilledButton(
          // Tema tüm dolu butonlara sonsuz genişlik veriyor; pencere eyleminde
          // bu düzeni çökertir (`docs/05` §6 notu).
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            l10n.close,
            style: const TextStyle(fontSize: KdsTextScale.statusBar),
          ),
        ),
      ],
    );
  }
}

/// Canlı tarih ve saat, uzaktan okunacak boyda.
///
/// Kendi zamanlayıcısı yok: pano saatine bağlı. Beş saniyelik tik, dakika
/// çözünürlüğündeki bir gösterge için fazlasıyla yeterli ve kasa aynı anda
/// kırk kartı çizerken ikinci bir saniye zamanlayıcısı istemiyoruz.
class _LiveClock extends ConsumerWidget {
  const _LiveClock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).value ?? DateTime.now().toUtc();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BldSpacing.lg,
        vertical: BldSpacing.md,
      ),
      decoration: BoxDecoration(
        color: const Color(KdsColors.surface),
        borderRadius: BorderRadius.circular(BldRadius.md),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            TurkishTime.longDateTime(now).split(',').first,
            style: const TextStyle(
              fontSize: KdsTextScale.columnHeader,
              color: Color(KdsColors.onSurfaceMuted),
            ),
          ),
          Text(
            TurkishTime.time(now),
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthGrid extends ConsumerWidget {
  const _HealthGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);

    final printer =
        ref.watch(printerStatusProvider).value ??
        PrinterAvailability.unavailable;
    final queueCount = ref.watch(printQueueCountProvider).value ?? 0;
    final failedCount = ref.watch(printQueueFailedCountProvider);
    final connection =
        ref.watch(connectionProvider).value ?? OrderSourceConnection.connecting;
    final health = ref.watch(kitchenHealthProvider);
    final alarm = ref.watch(newOrderAlarmProvider);
    final activeCount = ref.watch(activeOrdersProvider).length;

    final printerOk = printer == PrinterAvailability.ready && failedCount == 0;
    // "Sunucu" iki kanalın birleşimidir: sipariş yoklaması ve sağlık
    // bildirimi. Biri çalışıp diğeri çalışmıyorsa sorun vardır ve gösterge
    // iyimser davranmamalı.
    final serverOk =
        connection == OrderSourceConnection.connected && health.reachable;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _HealthTile(
                icon: Icons.print_outlined,
                label: l10n.healthPrinter,
                value: printer == PrinterAvailability.ready
                    ? l10n.printerReady
                    : l10n.printerUnavailable,
                detail: failedCount > 0
                    ? l10n.healthPrinterFailed(failedCount)
                    : l10n.healthPrinterQueue(queueCount),
                ok: printerOk,
              ),
            ),
            const SizedBox(width: BldSpacing.md),
            Expanded(
              child: _HealthTile(
                icon: serverOk ? Icons.cloud_done_outlined : Icons.cloud_off,
                label: l10n.healthServer,
                value: switch ((health.everTried, serverOk)) {
                  (false, _) => l10n.healthServerUnknown,
                  (_, true) => l10n.healthServerOk,
                  (_, false) => l10n.healthServerDown,
                },
                detail: health.lastSuccessAt == null
                    ? l10n.healthNoContact
                    : l10n.healthLastContact(
                        TurkishTime.time(health.lastSuccessAt!),
                      ),
                ok: serverOk,
              ),
            ),
          ],
        ),
        const SizedBox(height: BldSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _HealthTile(
                icon: Icons.receipt_long_outlined,
                label: l10n.healthOrdersToday,
                value: health.status == null
                    ? l10n.healthTodayUnknown
                    : '${health.status!.ordersToday}',
                detail:
                    '${l10n.healthActiveOrders(activeCount)} · '
                    '${l10n.healthTodayHint}',
                // Sayaç bir arıza göstergesi değil; nötr kalır.
                ok: null,
              ),
            ),
            const SizedBox(width: BldSpacing.md),
            Expanded(
              child: _HealthTile(
                icon: alarm.muted ? Icons.volume_off : Icons.volume_up,
                label: l10n.healthSound,
                value: alarm.muted ? l10n.healthSoundMuted : l10n.healthSoundOk,
                detail: l10n.healthSoundHint,
                ok: !alarm.muted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Tek sağlık kutusu. Renk yalnızca yardımcı: durum metinle de yazılır, çünkü
/// yeşil/kırmızı ayrımı herkes için okunur değildir.
class _HealthTile extends StatelessWidget {
  const _HealthTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.ok,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;

  /// `null` ise nötr (sayaç), `true` iyi, `false` sorunlu.
  final bool? ok;

  @override
  Widget build(BuildContext context) {
    final accent = switch (ok) {
      null => const Color(BldColors.brand400),
      true => const Color(KdsColors.statusOk),
      false => const Color(KdsColors.statusDown),
    };

    return Container(
      padding: const EdgeInsets.all(BldSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(KdsColors.surface),
        borderRadius: BorderRadius.circular(BldRadius.md),
        border: Border(left: BorderSide(color: accent, width: 8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 26, color: accent),
              const SizedBox(width: BldSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: KdsTextScale.statusBar,
                    color: Color(KdsColors.onSurfaceMuted),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: BldSpacing.xs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
          const SizedBox(height: BldSpacing.xs),
          Text(
            detail,
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
