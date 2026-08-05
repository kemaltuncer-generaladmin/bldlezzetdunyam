/// Ayarlar ekranı — `docs/05-mutfakapp.md` §8.
///
/// **PIN YOKTUR.** Açılışta bir kez parola soruluyor; ikinci bir katman
/// yalnızca sürtünme üretir ve parolanın duvara yazılmasıyla sonuçlanır
/// (`docs/05` §7.5).
///
/// Ekranın amacı, mutfağın bir teknisyen ya da yeni bir `.deb` beklemeden
/// kendini kurtarabilmesidir: yazıcı yolu değişti, sunucu taşındı, fiş
/// çıkmadı, ses rahatsız ediyor. Hepsi buradan çözülür.
library;

import 'dart:async';

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:bld_core/escpos.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../data/device_session.dart';
import '../data/printer_probe.dart';
import '../data/providers.dart';
import '../l10n/app_localizations.dart';
import '../printing/print_job.dart';
import '../printing/test_receipt.dart';
import 'kds_settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// Durum çubuğundaki düğmeden açılır.
  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(KdsColors.surface),
        title: Text(
          l10n.settingsTitle,
          style: const TextStyle(
            fontSize: KdsTextScale.columnHeader,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          tooltip: l10n.settingsBack,
          iconSize: 32,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(BldSpacing.lg),
          children: const [
            _ServerSection(),
            SizedBox(height: BldSpacing.lg),
            _PrinterSection(),
            SizedBox(height: BldSpacing.lg),
            _AlertsSection(),
            SizedBox(height: BldSpacing.lg),
            _QueueSection(),
            SizedBox(height: BldSpacing.lg),
            _DeviceSection(),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────── Sunucu ──────────────────────────────

class _ServerSection extends ConsumerWidget {
  const _ServerSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final session = ref.watch(deviceSessionProvider);

    return _Section(
      title: l10n.settingsSectionServer,
      icon: Icons.dns_outlined,
      children: [
        _ValueRow(label: l10n.deviceInfoServer, value: session.baseUrl),
        const SizedBox(height: BldSpacing.md),
        FilledButton.tonalIcon(
          onPressed: () => unawaited(_changeServer(context, ref)),
          icon: const Icon(Icons.edit_outlined),
          label: Text(l10n.settingsServerChange),
        ),
      ],
    );
  }

  Future<void> _changeServer(BuildContext context, WidgetRef ref) async {
    final l10n = AppL10n.of(context);
    final entered = await _promptForText(
      context,
      title: l10n.pairingServerLabel,
      hint: l10n.settingsServerChangeWarning,
      initialValue: ref.read(deviceSessionProvider).baseUrl,
    );
    if (entered == null) return;

    final normalized = normalizeBaseUrl(entered);
    if (normalized.isEmpty) return;

    await ref.read(deviceSessionProvider.notifier).changeBaseUrl(normalized);
    // Eşleme koptu: kök bileşen eşleme ekranını gösterecek, ayarlar ekranı
    // onun üstünde asılı kalmamalı.
    if (context.mounted) Navigator.of(context).pop();
  }
}

// ────────────────────────────── Yazıcı ──────────────────────────────

class _PrinterSection extends ConsumerWidget {
  const _PrinterSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final settings = ref.watch(kdsSettingsProvider);
    final config = ref.watch(appConfigProvider);
    final ready =
        ref.watch(printerStatusProvider).value == PrinterAvailability.ready;

    return _Section(
      title: l10n.settingsSectionPrinter,
      icon: Icons.print_outlined,
      children: [
        _TextSetting(
          label: l10n.settingsPrinterPath,
          value: settings.printerDevicePath,
          // Geri bildirimsiz bir "Kaydet", personelin aynı düğmeye üç kez
          // basmasına ve kaydedip kaydetmediğini bilememesine yol açar.
          onSaved: (value) {
            unawaited(
              ref
                  .read(kdsSettingsProvider.notifier)
                  .update(settings.copyWith(printerDevicePath: value)),
            );
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.settingsSaved)));
          },
        ),
        const SizedBox(height: BldSpacing.sm),
        _StatusRow(
          ok: ready,
          label: ready ? l10n.printerReady : l10n.printerUnavailable,
        ),
        const SizedBox(height: BldSpacing.sm),
        // Kod sayfası salt okunur: yanlış değer Türkçe harfleri boşluk
        // bastırır ve doğrusu ancak `kodsayfasi-tara.sh` ile bulunur
        // (`docs/05` §5.2). Ekrandan tahminle değiştirilecek bir şey değil.
        _ValueRow(
          label: l10n.settingsPrinterCodePage,
          value: '${config.printerCodePage}',
        ),
        const SizedBox(height: BldSpacing.md),
        _TestReceiptButton(devicePath: settings.printerDevicePath),
      ],
    );
  }
}

/// Test fişi düğmesi. Basım sırasında kilitlenir: iki kez basmak iki kâğıt
/// harcar ve mutfakta kâğıt para demektir.
class _TestReceiptButton extends ConsumerStatefulWidget {
  const _TestReceiptButton({required this.devicePath});

  final String devicePath;

  @override
  ConsumerState<_TestReceiptButton> createState() => _TestReceiptButtonState();
}

class _TestReceiptButtonState extends ConsumerState<_TestReceiptButton> {
  bool _printing = false;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: _printing ? null : () => unawaited(_print()),
    icon: const Icon(Icons.receipt_long_outlined),
    label: Text(AppL10n.of(context).settingsPrinterTest),
  );

  Future<void> _print() async {
    setState(() => _printing = true);
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final config = ref.read(appConfigProvider);

    try {
      await ref
          .read(printServiceProvider)
          .printDiagnostic(
            buildTestReceipt(
              devicePath: widget.devicePath,
              printedAt: DateTime.now().toUtc(),
              style: ReceiptStyle(codePage: config.printerCodePage),
            ),
          );
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsPrinterTestSent)),
      );
    } on Object catch (error) {
      // Yazıcı yoksa `FileSystemException`, kapalıysa `TimeoutException`
      // gelir. İkisi de personel için aynı şey: fiş çıkmadı, sebebi ekranda.
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(BldColors.danger),
          content: Text(l10n.settingsPrinterTestFailed('$error')),
        ),
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }
}

// ─────────────────────────── Uyarılar ve aciliyet ───────────────────────────

class _AlertsSection extends ConsumerWidget {
  const _AlertsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final settings = ref.watch(kdsSettingsProvider);
    final controller = ref.read(kdsSettingsProvider.notifier);

    return _Section(
      title: l10n.settingsSectionAlerts,
      icon: Icons.notifications_active_outlined,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: settings.soundEnabled,
          onChanged: (value) => unawaited(
            controller.update(settings.copyWith(soundEnabled: value)),
          ),
          title: Text(
            l10n.settingsSound,
            style: const TextStyle(fontSize: KdsTextScale.orderNumber),
          ),
          secondary: TextButton(
            // Ses kapalıyken denemek anlamsız: sağlayıcı sessiz uygulamayı
            // döndürür ve düğme "bozuk" görünürdü.
            onPressed: settings.soundEnabled
                ? ref.read(orderAlertProvider).ding
                : null,
            child: Text(l10n.settingsSoundTest),
          ),
        ),
        const Divider(color: Color(KdsColors.surfaceRaised)),
        _NumberSetting(
          label: l10n.settingsPollInterval,
          hint: l10n.settingsPollIntervalHint,
          value: settings.pollSeconds,
          min: KdsSettings.minPollSeconds,
          max: KdsSettings.maxPollSeconds,
          step: 1,
          format: l10n.settingsSeconds,
          onChanged: (value) => unawaited(
            controller.update(settings.copyWith(pollSeconds: value)),
          ),
        ),
        const Divider(color: Color(KdsColors.surfaceRaised)),
        _NumberSetting(
          label: l10n.settingsWarningAfter,
          hint: l10n.settingsThresholdHint,
          value: settings.warningAfterMinutes,
          min: KdsSettings.minThresholdMinutes,
          max: KdsSettings.maxThresholdMinutes,
          step: 5,
          format: l10n.settingsMinutes,
          accent: const Color(BldColors.warning),
          onChanged: (value) => unawaited(
            controller.update(settings.copyWith(warningAfterMinutes: value)),
          ),
        ),
        const Divider(color: Color(KdsColors.surfaceRaised)),
        _NumberSetting(
          label: l10n.settingsLateAfter,
          hint: l10n.settingsThresholdHint,
          value: settings.lateAfterMinutes,
          min: KdsSettings.minThresholdMinutes,
          max: KdsSettings.maxThresholdMinutes,
          step: 5,
          format: l10n.settingsMinutes,
          accent: const Color(BldColors.danger),
          onChanged: (value) => unawaited(
            controller.update(settings.copyWith(lateAfterMinutes: value)),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── Yazdırma kuyruğu ───────────────────────────

/// Kuyruk listesi. Diskten senkron okunur ve **elle** tazelenir: her saniye
/// SQLite'a sorgu atmak, ayarlar ekranı açıkken kasayı boşuna meşgul eder.
class _QueueSection extends ConsumerStatefulWidget {
  const _QueueSection();

  @override
  ConsumerState<_QueueSection> createState() => _QueueSectionState();
}

class _QueueSectionState extends ConsumerState<_QueueSection> {
  List<PrintJob>? _jobs;

  List<PrintJob> get _visibleJobs =>
      _jobs ??= ref.read(printServiceProvider).recentJobs(limit: 30);

  void _reload() => setState(() => _jobs = null);

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final jobs = _visibleJobs;

    return _Section(
      title: l10n.settingsSectionQueue,
      icon: Icons.receipt_long_outlined,
      trailing: IconButton(
        tooltip: l10n.settingsQueueRefresh,
        iconSize: 28,
        icon: const Icon(Icons.refresh),
        onPressed: _reload,
      ),
      children: [
        if (jobs.isEmpty)
          Text(
            l10n.settingsQueueEmpty,
            style: const TextStyle(
              fontSize: KdsTextScale.statusBar,
              color: Color(KdsColors.onSurfaceMuted),
            ),
          )
        else
          for (final job in jobs) _QueueRow(job: job, onReprint: _reprint),
      ],
    );
  }

  void _reprint(PrintJob job) {
    ref.read(printServiceProvider).reprint(job.orderId, job.type);
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppL10n.of(context).reprintQueued('#${job.orderId}')),
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.job, required this.onReprint});

  final PrintJob job;
  final void Function(PrintJob job) onReprint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final failed = !job.isPrinted && job.attempts > 0;

    final status = switch ((job.isPrinted, failed)) {
      (true, _) => l10n.settingsQueuePrinted(TurkishTime.time(job.printedAt!)),
      (_, true) => l10n.settingsQueueAttempts(job.attempts),
      _ => l10n.settingsQueuePending,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BldSpacing.xs),
      child: Row(
        children: [
          Icon(
            job.isPrinted ? Icons.check_circle_outline : Icons.schedule,
            size: 24,
            color: Color(
              failed
                  ? BldColors.danger
                  : job.isPrinted
                  ? BldColors.success
                  : KdsColors.onSurfaceMuted,
            ),
          ),
          const SizedBox(width: BldSpacing.md),
          Expanded(
            child: Text(
              '${l10n.settingsQueueOrder(job.orderId)} · '
              '${_receiptTypeLabel(l10n, job.type)}',
              style: const TextStyle(fontSize: KdsTextScale.statusBar),
            ),
          ),
          Text(
            status,
            style: TextStyle(
              fontSize: KdsTextScale.statusBar,
              color: Color(
                failed ? BldColors.danger : KdsColors.onSurfaceMuted,
              ),
            ),
          ),
          const SizedBox(width: BldSpacing.md),
          TextButton(
            onPressed: () => onReprint(job),
            child: Text(l10n.reprintTooltip),
          ),
        ],
      ),
    );
  }
}

String _receiptTypeLabel(AppL10n l10n, ReceiptType type) => switch (type) {
  ReceiptType.mutfak => l10n.receiptTypeKitchen,
  ReceiptType.musteri => l10n.receiptTypeCustomer,
};

// ────────────────────────────── Cihaz ──────────────────────────────

class _DeviceSection extends ConsumerWidget {
  const _DeviceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);

    return _Section(
      title: l10n.settingsSectionDevice,
      icon: Icons.developer_board_outlined,
      children: [
        _ValueRow(label: l10n.deviceInfoVersion, value: AppConfig.appVersion),
        const SizedBox(height: BldSpacing.md),
        const _UpdateCheckButton(),
        const SizedBox(height: BldSpacing.md),
        FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(BldColors.danger),
            foregroundColor: const Color(BldColors.neutral0),
          ),
          onPressed: () => unawaited(_resetPairing(context, ref)),
          icon: const Icon(Icons.link_off),
          label: Text(l10n.settingsResetPairing),
        ),
      ],
    );
  }

  Future<void> _resetPairing(BuildContext context, WidgetRef ref) async {
    final l10n = AppL10n.of(context);
    final confirmed = await _confirm(
      context,
      title: l10n.settingsResetPairing,
      body: l10n.settingsResetPairingWarning,
    );
    if (!confirmed) return;

    await ref.read(deviceSessionProvider.notifier).clearToken();
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _UpdateCheckButton extends ConsumerStatefulWidget {
  const _UpdateCheckButton();

  @override
  ConsumerState<_UpdateCheckButton> createState() => _UpdateCheckButtonState();
}

class _UpdateCheckButtonState extends ConsumerState<_UpdateCheckButton> {
  bool _checking = false;

  @override
  Widget build(BuildContext context) => FilledButton.tonalIcon(
    onPressed: _checking ? null : () => unawaited(_check()),
    icon: const Icon(Icons.system_update_alt),
    label: Text(AppL10n.of(context).settingsCheckUpdate),
  );

  Future<void> _check() async {
    setState(() => _checking = true);
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final info = await ref
          .read(bldApiProvider)
          .appVersion
          .check(AppConfig.appId);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            info.latest == AppConfig.appVersion
                ? l10n.settingsUpdateLatest(info.latest)
                : l10n.settingsUpdateAvailable(info.latest),
          ),
        ),
      );
    } on ApiException catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsUpdateFailed(error.message))),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }
}

// ──────────────────────── Yeniden kullanılan parçalar ────────────────────────

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;

  // `Container` + `BoxDecoration` DEĞİL `Material`: bölümün içinde
  // `ListTile` türevleri var ve onlar mürekkep efektini en yakın
  // `Material`'a çizer. Araya renkli bir kutu girerse efekt görünmez olur ve
  // Flutter bunu iddia hatasıyla bildirir.
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(KdsColors.surface),
    borderRadius: BorderRadius.circular(BldRadius.md),
    child: Padding(
      padding: const EdgeInsets.all(BldSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 28, color: const Color(BldColors.brand400)),
              const SizedBox(width: BldSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: KdsTextScale.columnHeader,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: BldSpacing.md),
          ...children,
        ],
      ),
    ),
  );
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$label: ',
        style: const TextStyle(
          fontSize: KdsTextScale.statusBar,
          color: Color(KdsColors.onSurfaceMuted),
        ),
      ),
      Expanded(
        child: SelectableText(
          value,
          style: const TextStyle(
            fontSize: KdsTextScale.statusBar,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ],
  );
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.ok, required this.label});

  final bool ok;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        Icons.circle,
        size: 14,
        color: Color(ok ? KdsColors.statusOk : KdsColors.statusDown),
      ),
      const SizedBox(width: BldSpacing.sm),
      Text(label, style: const TextStyle(fontSize: KdsTextScale.statusBar)),
    ],
  );
}

/// Kaydet düğmesi olan metin alanı.
///
/// Her tuş vuruşunda kaydetmiyoruz: yazıcı yolunu yazarken yarım kalmış her
/// dize diske gider ve `PrinterProbe` var olmayan yollara bakıp durur.
class _TextSetting extends StatefulWidget {
  const _TextSetting({
    required this.label,
    required this.value,
    required this.onSaved,
  });

  final String label;
  final String value;
  final void Function(String value) onSaved;

  @override
  State<_TextSetting> createState() => _TextSettingState();
}

class _TextSettingState extends State<_TextSetting> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            style: const TextStyle(fontSize: KdsTextScale.statusBar),
            onSubmitted: widget.onSaved,
            decoration: InputDecoration(
              isDense: true,
              labelText: widget.label,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: BldSpacing.md),
        FilledButton(
          // Tema tüm dolu butonlara sonsuz genişlik veriyor; satır içinde
          // bu düzeni çökertir (`docs/05` §6 notu).
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: () => widget.onSaved(_controller.text),
          child: Text(
            l10n.save,
            style: const TextStyle(fontSize: KdsTextScale.statusBar),
          ),
        ),
      ],
    );
  }
}

/// Artı/eksi düğmeli sayısal ayar.
///
/// Kaydırıcı (`Slider`) kullanılmadı: yağlı elle ve fareyle 5 dakika hassas
/// ayar yapmak imkânsız. İki büyük düğme her zaman doğru değeri verir.
class _NumberSetting extends StatelessWidget {
  const _NumberSetting({
    required this.label,
    required this.hint,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.format,
    required this.onChanged,
    this.accent,
  });

  final String label;
  final String hint;
  final int value;
  final int min;
  final int max;
  final int step;
  final String Function(int value) format;
  final void Function(int value) onChanged;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BldSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: KdsTextScale.orderNumber,
                    color: accent,
                  ),
                ),
                Text(
                  hint,
                  style: const TextStyle(
                    fontSize: KdsTextScale.statusBar,
                    color: Color(KdsColors.onSurfaceMuted),
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: l10n.settingsDecrease,
            iconSize: 28,
            onPressed: value <= min
                ? null
                : () => onChanged((value - step).clamp(min, max)),
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 110,
            child: Text(
              format(value),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: KdsTextScale.orderNumber,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton.filledTonal(
            tooltip: l10n.settingsIncrease,
            iconSize: 28,
            onPressed: value >= max
                ? null
                : () => onChanged((value + step).clamp(min, max)),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────── Pencereler ──────────────────────────────

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  final l10n = AppL10n.of(context);

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(
        body,
        style: const TextStyle(fontSize: KdsTextScale.statusBar),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 48),
            backgroundColor: const Color(BldColors.danger),
            foregroundColor: const Color(BldColors.neutral0),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            l10n.confirm,
            style: const TextStyle(fontSize: KdsTextScale.statusBar),
          ),
        ),
      ],
    ),
  );

  return result ?? false;
}

Future<String?> _promptForText(
  BuildContext context, {
  required String title,
  required String hint,
  required String initialValue,
}) async {
  final l10n = AppL10n.of(context);
  final controller = TextEditingController(text: initialValue);

  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            hint,
            style: const TextStyle(
              fontSize: KdsTextScale.statusBar,
              color: Color(BldColors.warning),
            ),
          ),
          const SizedBox(height: BldSpacing.md),
          TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(fontSize: KdsTextScale.statusBar),
            decoration: const InputDecoration(border: OutlineInputBorder()),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: Text(
            l10n.save,
            style: const TextStyle(fontSize: KdsTextScale.statusBar),
          ),
        ),
      ],
    ),
  );

  controller.dispose();
  return result;
}
