/// Alt durum çubuğu — `docs/05-mutfakapp.md` §3:
/// `● Bağlı  ● Yazıcı hazır  Kuyruk: 0   14:32   [Ayarlar]`
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
import '../../settings/settings_screen.dart';
import '../../window/kiosk_window.dart';
import '../kds_screen.dart';
import 'health_panel_dialog.dart';
import 'keyboard_help_dialog.dart';

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
    final failedCount = ref.watch(printQueueFailedCountProvider);

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
                  // Bekleyen iş sayısı ile hata alan iş sayısı farklı iki
                  // sorundur: ilki yazıcı yetişemiyor, ikincisi kâğıt bitmiş.
                  // Hata varsa kırmızıyla ayrıca yazılır.
                  if (failedCount > 0) ...[
                    const SizedBox(width: BldSpacing.lg),
                    _Indicator(
                      color: const Color(KdsColors.statusDown),
                      label: l10n.queueFailedCount(failedCount),
                    ),
                  ],
                  const SizedBox(width: BldSpacing.lg),
                  const _BbdChip(),
                  const _TodayCounter(),
                  const SizedBox(width: BldSpacing.lg),
                  const _Freshness(),
                ],
              ),
            ),
          ),
          const SizedBox(width: BldSpacing.lg),
          const _BusyToggle(),
          const SizedBox(width: BldSpacing.lg),
          const _Clock(),
          const SizedBox(width: BldSpacing.sm),
          IconButton(
            tooltip: l10n.healthOpen,
            iconSize: 22,
            icon: const Icon(Icons.monitor_heart_outlined),
            onPressed: () => unawaited(showHealthPanelDialog(context)),
          ),
          IconButton(
            tooltip: l10n.refreshNow,
            iconSize: 22,
            icon: const Icon(Icons.refresh),
            onPressed: () => unawaited(refreshBoard(context, ref)),
          ),
          IconButton(
            tooltip: '${l10n.shortcutsTitle} (${l10n.shortcutsHint})',
            iconSize: 22,
            icon: const Icon(Icons.keyboard_outlined),
            onPressed: () => unawaited(showKeyboardHelpDialog(context)),
          ),
          TextButton.icon(
            onPressed: () =>
                unawaited(Navigator.of(context).push(SettingsScreen.route())),
            icon: const Icon(Icons.settings_outlined, size: 22),
            label: Text(
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

/// Bugün girilen sipariş sayısı — sunucudan gelir (`POST /kitchen/health`).
///
/// Yerelde hesaplanamaz: mutfak listesi yalnızca aktif siparişleri taşır,
/// teslim edilenler düşer. Sayı gelmeden gösterge hiç çizilmez; sıfır yazmak
/// "bugün hiç sipariş girmedi" demek olurdu ve bu yanlış olabilir.
class _TodayCounter extends ConsumerWidget {
  const _TodayCounter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(kitchenHealthProvider).status;
    if (status == null) return const SizedBox.shrink();

    return Text(
      AppL10n.of(context).statusToday(status.ordersToday),
      style: const TextStyle(
        fontSize: KdsTextScale.statusBar,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

/// BBD Store sayacı (K-16).
///
/// BU SİPARİŞLER PANODA YOK — kasıtlı. Çip, "bir yerde bir şey oldu ve
/// kâğıt çıktı" bilgisini veriyor; personel panoda arayıp bulamadığında
/// nereye bakacağını bilsin diye.
///
/// HİÇ FİŞ GELMEDİYSE ÇİZİLMEZ: BBD kullanmayan bir kurulumda durum
/// çubuğunda boşuna yer kaplamaz.
class _BbdChip extends ConsumerWidget {
  const _BbdChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final bbd = ref.watch(bbdMonitorProvider);

    if (bbd.printedToday == 0 && bbd.pending == 0) {
      return const SizedBox.shrink();
    }

    // Bekleyen fiş varsa sarı: yazıcı sorunu olabilir ve kâğıt çıkmamış
    // olabilir. Basılmışsa nötr — yalnız bilgi.
    final waiting = bbd.pending > 0;

    return Padding(
      padding: const EdgeInsets.only(right: BldSpacing.lg),
      child: Tooltip(
        message: waiting
            ? l10n.bbdPending(bbd.pending)
            : l10n.bbdTooltip,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 20,
              color: Color(
                waiting ? KdsColors.statusWarn : KdsColors.onSurfaceMuted,
              ),
            ),
            const SizedBox(width: BldSpacing.xs),
            Text(
              l10n.bbdPrinted(
                waiting ? bbd.pending : bbd.printedToday,
              ),
              style: TextStyle(
                fontSize: KdsTextScale.statusBar,
                fontWeight: FontWeight.bold,
                color: Color(
                  waiting ? KdsColors.statusWarn : KdsColors.onSurfaceMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Listenin yaşı: "şu an güncel" mi, "on dakikadır donmuş" mu?
///
/// Kesinti şeridi bağlantının koptuğunu söyler ama ekrandaki listeye ne kadar
/// güvenilebileceğini söylemez. İkisi farklı sorulardır: yeni kopmuş bir
/// bağlantının listesi hâlâ işe yarar, yirmi dakikalık liste yaramaz.
class _Freshness extends ConsumerWidget {
  const _Freshness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final updatedAt = ref.watch(lastUpdatedAtProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now().toUtc();

    final String label;
    var stale = false;

    if (updatedAt == null) {
      label = l10n.lastUpdateNever;
      stale = true;
    } else {
      final age = now.toUtc().difference(updatedAt.toUtc());
      final minutes = age.isNegative ? 0 : age.inMinutes;
      label = minutes < 1 ? l10n.lastUpdateNow : l10n.lastUpdateAgo(minutes);
      // Bir dakika, en uzun geri çekilme aralığının (60 sn) katıdır: normal
      // çalışmada asla aşılmaz, aşıldıysa gerçekten bir sorun vardır.
      stale = minutes >= 1;
    }

    return Text(
      label,
      style: TextStyle(
        fontSize: KdsTextScale.statusBar,
        fontWeight: stale ? FontWeight.bold : FontWeight.normal,
        color: Color(stale ? KdsColors.statusWarn : KdsColors.onSurfaceMuted),
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

  /// Personelin bu oturumda düğmeye bastığı an.
  ///
  /// Sunucudan okunan değeri ne zaman kabul edeceğimizi belirliyor:
  /// istek uçarken gelen bir yanıt, personelin az önceki dokunuşunu geri
  /// alıyormuş gibi görünüyordu.
  bool _touched = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    // AÇILIŞTA SUNUCUDAN OKUNUR (K-11 düzeltmesi).
    //
    // Önceden yalnız yerel `_busy` tutuluyordu: kasa yeniden başladığında
    // düğme "yoğunluk kapalı" gösteriyor, oysa vitrin hâlâ yoğun
    // işaretliydi. İki kasalı kurulumda ikinci kasa da hiç haberdar
    // olmuyordu. Artık şalterin durumu satış kontrolü uçlarından geliyor.
    final remote = ref.watch(orderingStateProvider).value;
    if (remote != null && !_sending && !_touched && remote.busy != _busy) {
      // `build` içinde `setState` çağrılamaz; bir sonraki kareye bırakıyoruz.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _busy = remote.busy);
      });
    }

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
    setState(() {
      _sending = true;
      _touched = true;
    });
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
