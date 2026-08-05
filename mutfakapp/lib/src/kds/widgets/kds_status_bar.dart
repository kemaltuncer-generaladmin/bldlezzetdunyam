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
import '../../window/kiosk_window.dart';

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
    final queueCount = ref.watch(printQueueCountProvider).value ?? 0;

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
          const _BusyToggle(),
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
          const _WindowButtons(),
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

/// Yoğunluk şalteri — mutfaktaki tek tuş.
///
/// Sipariş almayı DURDURMAZ. Açıkken müşteri arayüzlerinde "hazırlanması
/// uzun sürebilir" uyarısı çıkar ve admin panelde görünür. Siparişi
/// gerçekten kesen şalter `ordering_enabled`'dır ve yöneticinindir —
/// mutfak personeli tek tuşla cirosu kapatabilmemeli.
class _BusyToggle extends ConsumerStatefulWidget {
  const _BusyToggle();

  @override
  ConsumerState<_BusyToggle> createState() => _BusyToggleState();
}

class _BusyToggleState extends ConsumerState<_BusyToggle> {
  bool _busy = false;
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    // İPUCU BUTONUN İÇİNDE, DIŞINDA DEĞİL. `Tooltip` çocuğuna
    // `OverlayPortal` üzerinden SINIRSIZ genişlik geçiriyor; butonun
    // dokunma hedefi dolgusu bunu minimum genişlik sanıp sonsuz
    // hesaplıyor ve tüm durum çubuğunun düzeni çöküyor. Metnin sınırsız
    // genişlikle sorunu yok.
    return FilledButton.tonal(
      onPressed: _sending ? null : _toggle,
      style: FilledButton.styleFrom(
        backgroundColor: _busy
            ? const Color(KdsColors.statusWarn)
            : const Color(KdsColors.surface),
        foregroundColor: _busy ? Colors.black : null,
        // TEMA EZİLİYOR. `KdsTheme` tüm dolu butonlara
        // `Size.fromHeight(56)` veriyor — genişliği sonsuz bırakan,
        // eşleme ekranındaki tam genişlik butonlar için doğru bir
        // varsayılan. Durum çubuğunda o sonsuz genişlik satırın düzenini
        // çökertiyor; burada içeriğe göre daralması gerekiyor.
        minimumSize: const Size(0, 44),
        textStyle: const TextStyle(fontSize: KdsTextScale.statusBar),
        padding: const EdgeInsets.symmetric(horizontal: BldSpacing.md),
      ),
      child: Tooltip(
        message: l10n.busyTooltip,
        child: Text(
          _busy ? l10n.busyOff : l10n.busyOn,
          style: const TextStyle(fontSize: KdsTextScale.statusBar),
        ),
      ),
    );
  }

  Future<void> _toggle() async {
    setState(() => _sending = true);
    final hedef = !_busy;

    try {
      final state = await ref.read(kitchenServiceProvider).setBusy(hedef);
      // Sunucunun döndürdüğü değeri alıyoruz, kendi tahminimizi değil:
      // iki kasa varsa ikincisi de aynı anda değiştirmiş olabilir.
      if (mounted) setState(() => _busy = state.busy);
    } on ApiException catch (error) {
      if (!mounted) return;
      // Sessizce yutmuyoruz: personel tuşa bastı, bir şey olmadıysa
      // bunu bilmeli — yoksa müşterinin uyarıldığını sanır.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppL10n.of(context).busyFailed}: ${error.message}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

/// Pencere denetimleri: küçült ve tam ekran aç/kapa.
///
/// Kasa kiosk modunda açılır ama arada masaüstüne inmek gerekiyor —
/// yazıcı ayarı, ağ, güncelleme. Bunu yapmanın tek yolu servisi durdurmak
/// olmamalı.
class _WindowButtons extends StatefulWidget {
  const _WindowButtons();

  @override
  State<_WindowButtons> createState() => _WindowButtonsState();
}

class _WindowButtonsState extends State<_WindowButtons> {
  static const _window = KioskWindow();

  bool _fullScreen = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => unawaited(_window.minimize()),
          tooltip: l10n.windowMinimize,
          icon: const Icon(Icons.remove),
        ),
        IconButton(
          onPressed: _toggle,
          tooltip: _fullScreen
              ? l10n.windowFullScreenOff
              : l10n.windowFullScreenOn,
          icon: Icon(_fullScreen ? Icons.fullscreen_exit : Icons.fullscreen),
        ),
      ],
    );
  }

  Future<void> _toggle() async {
    // Gerçek durumu pencere yöneticisinden alıyoruz, kendi bayrağımızı
    // körlemesine ters çevirmiyoruz: kullanıcı F11 ile de değiştirebilir
    // ve ikon o zaman yalan söylerdi.
    final full = await _window.toggleFullScreen();
    if (mounted) setState(() => _fullScreen = full);
  }
}

/// Ayarlar penceresi teşhis için gereken üç değeri gösterir
/// (`docs/05` §8 "sürüm bilgisi"). Parola İSTEMEZ: açılışta bir kez
/// soruluyor, her işlemde tekrar sormak parolanın duvara yazılmasıyla
/// sonuçlanır.
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
