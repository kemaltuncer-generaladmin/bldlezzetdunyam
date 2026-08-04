/// Alt durum çubuğu — `docs/05-mutfakapp.md` §3:
/// `● Bağlı  ● Yazıcı hazır  Kuyruk: 0   14:32   [Ayarlar]`
library;

import 'dart:async';

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../data/printer_probe.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';

class KdsStatusBar extends ConsumerWidget {
  const KdsStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final connection =
        ref.watch(connectionProvider).value ?? OrderSourceConnection.connecting;
    final printer =
        ref.watch(printerStatusProvider).value ??
        PrinterAvailability.unavailable;
    final queueCount = ref.watch(printQueueCountProvider);

    return Container(
      color: const Color(KdsColors.surface),
      padding: const EdgeInsets.symmetric(
        horizontal: BldSpacing.md,
        vertical: BldSpacing.sm,
      ),
      child: Row(
        children: [
          // Göstergeler dar ekranda taşmak yerine kayar; saat ve ayarlar
          // her zaman görünür kalır.
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _Indicator(
                    color: _connectionColor(connection),
                    label: _connectionLabel(l10n, connection),
                  ),
                  const SizedBox(width: BldSpacing.lg),
                  _Indicator(
                    color: printer == PrinterAvailability.ready
                        ? const Color(KdsColors.statusOk)
                        : const Color(KdsColors.statusDown),
                    label: printer == PrinterAvailability.ready
                        ? l10n.printerReady
                        : l10n.printerUnavailable,
                  ),
                  const SizedBox(width: BldSpacing.lg),
                  Text(
                    l10n.printQueueCount(queueCount),
                    style: const TextStyle(fontSize: KdsTextScale.statusBar),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: BldSpacing.lg),
          const _Clock(),
          const SizedBox(width: BldSpacing.lg),
          TextButton(
            onPressed: () => _showDeviceInfo(context, ref),
            child: Text(
              l10n.settings,
              style: const TextStyle(fontSize: KdsTextScale.statusBar),
            ),
          ),
        ],
      ),
    );
  }
}

Color _connectionColor(OrderSourceConnection state) => switch (state) {
  OrderSourceConnection.connected => const Color(KdsColors.statusOk),
  OrderSourceConnection.connecting => const Color(KdsColors.statusWarn),
  OrderSourceConnection.disconnected ||
  OrderSourceConnection.revoked => const Color(KdsColors.statusDown),
};

String _connectionLabel(AppL10n l10n, OrderSourceConnection state) =>
    switch (state) {
      OrderSourceConnection.connected => l10n.connectionConnected,
      OrderSourceConnection.connecting => l10n.connectionConnecting,
      OrderSourceConnection.disconnected => l10n.connectionDisconnected,
      OrderSourceConnection.revoked => l10n.connectionRevoked,
    };

/// Ayarlar ekranı `K-08`'de PIN arkasına alınacak; şimdilik düğme sahadaki
/// teşhis için gereken üç değeri gösterir (`docs/05` §8 "sürüm bilgisi").
void _showDeviceInfo(BuildContext context, WidgetRef ref) {
  final l10n = AppL10n.of(context);
  final config = ref.read(appConfigProvider);

  unawaited(
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deviceInfoTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${l10n.deviceInfoServer}: ${config.baseUrl}'),
            Text('${l10n.deviceInfoPrinter}: ${config.printerDevicePath}'),
            Text('${l10n.deviceInfoVersion}: ${AppConfig.appVersion}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.close),
          ),
        ],
      ),
    ),
  );
}

class _Indicator extends StatelessWidget {
  const _Indicator({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(Icons.circle, size: 12, color: color),
      const SizedBox(width: BldSpacing.xs),
      Text(label, style: const TextStyle(fontSize: KdsTextScale.statusBar)),
    ],
  );
}

/// Duvar saati. Ayrı bir parça olması bilinçli: saniyede bir yalnızca bu
/// yeniden çizilir, durum çubuğunun tamamı değil.
class _Clock extends StatefulWidget {
  const _Clock();

  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock> {
  late Timer _timer;
  DateTime _now = DateTime.now().toUtc();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _now = DateTime.now().toUtc()),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
    TurkishTime.time(_now),
    style: const TextStyle(
      fontSize: KdsTextScale.statusBar,
      fontWeight: FontWeight.bold,
    ),
  );
}
