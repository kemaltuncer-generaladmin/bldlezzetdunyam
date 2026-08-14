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
import '../input/keyboard_text_field.dart';
import '../l10n/app_localizations.dart';
import '../printing/print_job.dart';
import '../printing/test_receipt.dart';
import '../sound/alarm_asset.dart';
import '../sound/kds_sound_event.dart';
import '../sound/system_audio.dart';
import '../sound/tts_announcer.dart';
import 'kds_settings.dart';
import 'lock_ui.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// Ekranın bölümleri — kilitli kipte tek tek kalkanlanabilsin diye liste.
  ///
  /// `ListView` çocukları AYRI KALIYOR: hepsini tek bir `Column`a koymak
  /// tembel kurulumu bitirir ve ayarlar ekranı açılışta yedi bölümü birden
  /// çizerdi.
  static const List<Widget> _sections = <Widget>[
    _ServerSection(),
    _PrinterSection(),
    _SoundSection(),
    _AlertsSection(),
    _TouchSection(),
    _QueueSection(),
    _DeviceSection(),
  ];

  /// Durum çubuğundaki düğmeden açılır.
  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    // İKİNCİ SAVUNMA KATMANI (K-21 §5.4). Kapıyı kapatmak yetmez: ekran
    // başka bir yoldan açılırsa (kod içinden bir rota, ileride eklenecek
    // bir kısayol) içerideki düğmeler de kapalı olmalı. Değerler okunur
    // kalır — "yazıcı yolu neydi" sorusu kilitli kasada da sorulur.
    final allowSettings = ref.watch(
      kdsSettingsProvider.select((settings) => settings.allowSettings),
    );

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
          children: [
            if (!allowSettings) ...[
              const LockNotice(),
              const SizedBox(height: BldSpacing.lg),
            ],
            for (var index = 0; index < _sections.length; index++) ...[
              if (index > 0) const SizedBox(height: BldSpacing.lg),
              LockShield(locked: !allowSettings, child: _sections[index]),
            ],
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
    // Sunucu adresi kilitliyse ADRES YİNE GÖRÜNÜR, yalnız değiştirilemez:
    // hangi sunucuya bağlı olduğunu bilmek destek çağrısının ilk sorusu.
    final allowed = ref.watch(
      kdsSettingsProvider.select((settings) => settings.allowServerChange),
    );

    return _Section(
      title: l10n.settingsSectionServer,
      icon: Icons.dns_outlined,
      children: [
        _ValueRow(label: l10n.deviceInfoServer, value: session.baseUrl),
        const SizedBox(height: BldSpacing.md),
        LockedAction(
          locked: !allowed,
          child: FilledButton.tonalIcon(
            onPressed: allowed
                ? () => unawaited(_changeServer(context, ref))
                : null,
            icon: LockedIcon(icon: Icons.edit_outlined, locked: !allowed),
            label: Text(l10n.settingsServerChange),
          ),
        ),
      ],
    );
  }

  Future<void> _changeServer(BuildContext context, WidgetRef ref) async {
    if (!ref.read(kdsSettingsProvider).allowServerChange) {
      showLockMessage(context, ref);
      return;
    }

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

// ────────────────────────── Ses ve hoparlör (K-09) ──────────────────────────

/// Sesin tamamı: şalterler, seviye, çıkış cihazı, anons ve tanılama.
///
/// NEDEN AYRI BÖLÜM: sahada "ses çalmıyor" en sık bildirilen arıza oldu ve
/// sebebi tek bir yerden görülemiyordu (`pw-play` argüman hatası, kısık
/// hoparlör, yanlış çıkış, eksik ikili — dördü de aynı belirtiyi veriyor).
/// Artık dördü de bu bölümde görünür ve buradan çözülür.
class _SoundSection extends ConsumerWidget {
  const _SoundSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final settings = ref.watch(kdsSettingsProvider);
    final controller = ref.read(kdsSettingsProvider.notifier);

    return _Section(
      title: l10n.settingsSectionSound,
      icon: Icons.volume_up_outlined,
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
          secondary: _SoundTestButton(enabled: settings.soundEnabled),
        ),
        const Divider(color: Color(KdsColors.surfaceRaised)),
        _NumberSetting(
          label: l10n.settingsSoundVolume,
          hint: l10n.settingsSoundVolumeHint,
          value: settings.volumePercent,
          min: 0,
          max: 100,
          step: 5,
          format: l10n.settingsPercent,
          enabled: settings.soundEnabled,
          onChanged: (value) => unawaited(
            controller.update(settings.copyWith(volumePercent: value)),
          ),
        ),
        const Divider(color: Color(KdsColors.surfaceRaised)),
        const _SpeakerVolumeRow(),
        const Divider(color: Color(KdsColors.surfaceRaised)),
        const _AudioOutputRow(),
        const Divider(color: Color(KdsColors.surfaceRaised)),
        _SoundEventList(settings: settings),
        const Divider(color: Color(KdsColors.surfaceRaised)),
        _NumberSetting(
          label: l10n.settingsAlarmRepeat,
          hint: l10n.settingsAlarmRepeatHint,
          value: settings.alarmRepeatSeconds,
          min: 0,
          max: KdsSettings.maxAlarmRepeatSeconds,
          step: 5,
          format: l10n.settingsSeconds,
          onChanged: (value) => unawaited(
            controller.update(settings.copyWith(alarmRepeatSeconds: value)),
          ),
        ),
        const Divider(color: Color(KdsColors.surfaceRaised)),
        _NumberSetting(
          label: l10n.settingsAlarmMaxRepeats,
          hint: l10n.settingsAlarmMaxRepeatsHint,
          value: settings.alarmMaxRepeats,
          min: 0,
          max: 60,
          step: 1,
          format: l10n.settingsTimes,
          onChanged: (value) => unawaited(
            controller.update(settings.copyWith(alarmMaxRepeats: value)),
          ),
        ),
        const Divider(color: Color(KdsColors.surfaceRaised)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: settings.ttsEnabled,
          onChanged: (value) =>
              unawaited(controller.update(settings.copyWith(ttsEnabled: value))),
          title: Text(
            l10n.settingsTts,
            style: const TextStyle(fontSize: KdsTextScale.orderNumber),
          ),
          subtitle: Text(
            l10n.settingsTtsHint,
            style: const TextStyle(
              fontSize: KdsTextScale.statusBar,
              color: Color(KdsColors.onSurfaceMuted),
            ),
          ),
          secondary: _TtsTestButton(enabled: settings.ttsEnabled),
        ),
        if (settings.ttsEnabled)
          _NumberSetting(
            label: l10n.settingsTtsRate,
            hint: '',
            value: settings.ttsRatePercent,
            min: minTtsRatePercent,
            max: maxTtsRatePercent,
            step: 10,
            format: l10n.settingsPercent,
            onChanged: (value) => unawaited(
              controller.update(settings.copyWith(ttsRatePercent: value)),
            ),
          ),
        const Divider(color: Color(KdsColors.surfaceRaised)),
        const _SoundDiagnostics(),
      ],
    );
  }
}

/// Hangi olayda ses çalacağını seçen liste.
class _SoundEventList extends ConsumerWidget {
  const _SoundEventList({required this.settings});

  final KdsSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final controller = ref.read(kdsSettingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.settingsSoundEvents,
          style: const TextStyle(
            fontSize: KdsTextScale.statusBar,
            color: Color(KdsColors.onSurfaceMuted),
          ),
        ),
        for (final event in KdsSoundEvent.values)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            // Bağlantı uyarısı kapatılamaz: ekran son bilinen listeyi
            // gösterir ve DOĞRU görünür; tek uyarıyı kapatmak mutfağı
            // kör bırakır (`docs/05` §5.5).
            value: settings.soundEnabledFor(event),
            onChanged: event.canBeDisabled && settings.soundEnabled
                ? (value) => unawaited(
                    controller.update(
                      settings.withSoundEvent(event, enabled: value),
                    ),
                  )
                : null,
            title: Text(
              event.label,
              style: const TextStyle(fontSize: KdsTextScale.statusBar),
            ),
            subtitle: event.canBeDisabled
                ? null
                : Text(
                    l10n.settingsSoundEventAlways,
                    style: const TextStyle(
                      fontSize: KdsTextScale.statusBar,
                      color: Color(KdsColors.onSurfaceMuted),
                    ),
                  ),
          ),
      ],
    );
  }
}

/// Kasanın kendi hoparlör seviyesi — `wpctl` / `amixer`.
///
/// AYRI SATIR: uygulama seviyesiyle karıştırılmamalı. Sahada "sesi %100
/// yaptım hâlâ duyulmuyor" şikâyetinin sebebi, sistem seviyesinin kısık
/// ya da sessize alınmış olmasıydı.
class _SpeakerVolumeRow extends ConsumerStatefulWidget {
  const _SpeakerVolumeRow();

  @override
  ConsumerState<_SpeakerVolumeRow> createState() => _SpeakerVolumeRowState();
}

class _SpeakerVolumeRowState extends ConsumerState<_SpeakerVolumeRow> {
  int? _current;
  int? _pending;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_read());
  }

  Future<void> _read() async {
    final value = await ref.read(systemAudioProvider).currentVolume();
    if (!mounted) return;

    setState(() {
      _current = value;
      _pending = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final value = _pending ?? _current;

    // Okunamıyorsa (wpctl/amixer yok) ayarı da sunmuyoruz: çalışmayan bir
    // düğme, olmayan bir düğmeden kötüdür.
    if (value == null) {
      return _ValueRow(
        label: l10n.settingsSpeakerVolume,
        value: l10n.settingsSpeakerUnknown,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NumberSetting(
          label: l10n.settingsSpeakerVolume,
          hint: l10n.settingsSpeakerVolumeHint,
          value: value,
          min: 0,
          max: 100,
          step: 5,
          format: l10n.settingsPercent,
          enabled: !_busy,
          onChanged: (next) => setState(() => _pending = next),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonal(
            // Anında uygulamıyoruz: her dokunuşta `wpctl` çağırmak, beş
            // dokunuşta beş süreç açar ve seviye zıplar.
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: _busy || _pending == null || _pending == _current
                ? null
                : _apply,
            child: Text(l10n.settingsSpeakerApply),
          ),
        ),
      ],
    );
  }

  Future<void> _apply() async {
    final target = _pending;
    if (target == null) return;

    setState(() => _busy = true);
    final ok = await ref.read(systemAudioProvider).setVolume(target);
    if (!mounted) return;

    setState(() {
      _busy = false;
      if (ok) _current = target;
    });

    if (!ok) {
      final l10n = AppL10n.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.settingsSpeakerFailed)));
    }
  }
}

/// Sesin hangi çıkıştan verileceği.
class _AudioOutputRow extends ConsumerWidget {
  const _AudioOutputRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final settings = ref.watch(kdsSettingsProvider);
    final controller = ref.read(kdsSettingsProvider.notifier);
    final sinks = ref.watch(audioSinksProvider);

    final available = sinks.value ?? const <AudioSink>[];

    // Kayıtlı çıkış artık yoksa (kablo çıkarıldı, HDMI kapandı) seçimi
    // varsayılana düşürüyoruz: listede olmayan bir değer `DropdownButton`
    // için hatadır ve ekran çöker.
    final selected = available.any((s) => s.name == settings.audioSinkName)
        ? settings.audioSinkName
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.settingsAudioOutput,
          style: const TextStyle(fontSize: KdsTextScale.orderNumber),
        ),
        const SizedBox(height: BldSpacing.xs),
        if (available.isEmpty)
          Text(
            l10n.settingsAudioOutputEmpty,
            style: const TextStyle(
              fontSize: KdsTextScale.statusBar,
              color: Color(KdsColors.onSurfaceMuted),
            ),
          )
        else
          DropdownButton<String?>(
            value: selected,
            isExpanded: true,
            dropdownColor: const Color(KdsColors.surfaceRaised),
            items: [
              DropdownMenuItem<String?>(
                child: Text(l10n.settingsAudioOutputDefault),
              ),
              for (final sink in available)
                DropdownMenuItem<String?>(
                  value: sink.name,
                  child: Text(
                    sink.isDefault ? '${sink.label} ★' : sink.label,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => unawaited(
              controller.update(
                settings.copyWith(
                  audioSinkName: value,
                  clearAudioSink: value == null,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// "Ses neden çıkmıyor?" sorusunun cevabının yazdığı yer.
class _SoundDiagnostics extends ConsumerWidget {
  const _SoundDiagnostics();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final player = ref.watch(alarmPlayerProvider);
    final announcer = ref.watch(ttsAnnouncerProvider);
    final reason = player.muteReason;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.settingsSoundDiagnostics,
          style: const TextStyle(
            fontSize: KdsTextScale.statusBar,
            color: Color(KdsColors.onSurfaceMuted),
          ),
        ),
        const SizedBox(height: BldSpacing.xs),
        // "HENÜZ DENENMEDİ" İLE "YOK" AYRI: ikisini aynı metinle
        // göstermek, gerçekten eksik olan aracı "birazdan bulunur" gibi
        // okutuyordu ve kimse kurmuyordu.
        _ValueRow(
          label: l10n.settingsSoundPlayer,
          value: player.playerExecutable ??
              (player.isMuted
                  ? l10n.settingsSoundPlayerMissing
                  : l10n.settingsSoundNotProbed),
        ),
        _ValueRow(
          label: l10n.settingsSoundFolder,
          value: lastSoundDirectory ?? l10n.settingsSoundNotProbed,
        ),
        _ValueRow(
          label: l10n.settingsTts,
          value:
              announcer.executable ??
              (announcer.isUnavailable
                  ? l10n.settingsSoundPlayerMissing
                  : l10n.settingsSoundNotProbed),
        ),
        const SizedBox(height: BldSpacing.xs),
        if (reason == null)
          _StatusRow(ok: true, label: l10n.settingsSoundOk)
        else
          _StatusRow(ok: false, label: '${l10n.settingsSoundProblem}: $reason'),
        // KURULUM KOMUTU EKRANDA: "ses çalınamıyor" bilgisi tek başına
        // kimseyi harekete geçirmiyor. Sahada bu ekrana bakan kişinin
        // elinde terminal var; komutu ezberden yazmasını beklemek yerine
        // buraya yazıyoruz.
        if (player.playerExecutable == null && player.isMuted) ...[
          const SizedBox(height: BldSpacing.xs),
          _HintText(text: l10n.settingsSoundUnavailable),
        ],
        if (announcer.isUnavailable) ...[
          const SizedBox(height: BldSpacing.xs),
          _HintText(text: l10n.settingsTtsUnavailable),
        ],
      ],
    );
  }
}

/// Anonsu dinletir.
class _TtsTestButton extends ConsumerWidget {
  const _TtsTestButton({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);

    return TextButton(
      onPressed: enabled
          ? () => ref
                .read(ttsAnnouncerProvider)
                .announce('12 numaralı yeni sipariş, 4 ürün')
                .ignore()
          : null,
      child: Text(l10n.settingsTtsTest),
    );
  }
}

// ────────────────────────────── Dokunmatik (K-10) ──────────────────────────

class _TouchSection extends ConsumerWidget {
  const _TouchSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final settings = ref.watch(kdsSettingsProvider);
    final controller = ref.read(kdsSettingsProvider.notifier);

    return _Section(
      title: l10n.settingsSectionTouch,
      icon: Icons.touch_app_outlined,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: settings.touchMode,
          onChanged: (value) =>
              unawaited(controller.update(settings.copyWith(touchMode: value))),
          title: Text(
            l10n.settingsTouchMode,
            style: const TextStyle(fontSize: KdsTextScale.orderNumber),
          ),
          subtitle: Text(
            l10n.settingsTouchModeHint,
            style: const TextStyle(
              fontSize: KdsTextScale.statusBar,
              color: Color(KdsColors.onSurfaceMuted),
            ),
          ),
        ),
      ],
    );
  }
}

/// Uyarı sesini dinletir.
///
/// AÇ/KAPA ŞEKLİNDE, tek atışlık değil: alarm gerçek hayatta **döngüde**
/// çalıyor ve personelin duyacağı ses budur. Bir zamanlayıcıyla üç saniye
/// sonra kesmek, hem gerçek davranışı yanlış tanıtır hem de ekran kapanırsa
/// arkada asılı bir zamanlayıcı bırakırdı.
class _SoundTestButton extends ConsumerStatefulWidget {
  const _SoundTestButton({required this.enabled});

  final bool enabled;

  @override
  ConsumerState<_SoundTestButton> createState() => _SoundTestButtonState();
}

class _SoundTestButtonState extends ConsumerState<_SoundTestButton> {
  bool _playing = false;

  @override
  void dispose() {
    // Ekrandan çıkıldığında deneme sesi susmalı. `ref` `dispose` içinde
    // okunamaz; bu yüzden oynatıcı önceden alınıp durdurulur.
    if (_playing) ref.read(alarmPlayerProvider).stop().ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return TextButton(
      // Ses kapalıyken denemek anlamsız: sağlayıcı sessiz uygulamayı döndürür
      // ve düğme "bozuk" görünürdü.
      onPressed: widget.enabled ? _toggle : null,
      child: Text(_playing ? l10n.settingsSoundStop : l10n.settingsSoundTest),
    );
  }

  void _toggle() {
    final player = ref.read(alarmPlayerProvider);
    final next = !_playing;

    if (next) {
      player.start().ignore();
    } else {
      player.stop().ignore();
    }
    setState(() => _playing = next);
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
    // Kuyruk LİSTESİ kilitten etkilenmez — "fiş bastı mı" sorusunu
    // cevaplıyor. Kapanan yalnız satırdaki yeniden basma düğmesi.
    final allowReprint = ref.watch(
      kdsSettingsProvider.select((settings) => settings.allowManualReprint),
    );

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
          for (final job in jobs)
            _QueueRow(
              job: job,
              onReprint: _reprint,
              locked: !allowReprint,
            ),
      ],
    );
  }

  void _reprint(PrintJob job) {
    if (!ref.read(kdsSettingsProvider).allowManualReprint) {
      showLockMessage(context, ref);
      return;
    }

    // Satırın kendi revizyonu elimizde — o sürümü geri koyuyoruz, en
    // güncelini değil: personel kuyrukta GÖRDÜĞÜ satıra basıyor.
    ref
        .read(printServiceProvider)
        .reprint(job.orderId, job.type, revision: job.revision);
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppL10n.of(context).reprintQueued('#${job.orderId}')),
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.job,
    required this.onReprint,
    this.locked = false,
  });

  final PrintJob job;
  final void Function(PrintJob job) onReprint;

  /// Elle yeniden basma kilitli mi? Satırın kendisi her hâlde görünür.
  final bool locked;

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
          // Kilitliyken düğme SATIRDA KALIR: kaybolsa personel yanlış
          // satıra bastığını sanır (K-21 §5.4).
          if (locked)
            LockedAction(
              locked: true,
              child: TextButton.icon(
                onPressed: null,
                icon: const Icon(
                  Icons.lock_outline,
                  size: 20,
                  color: Color(BldColors.warning),
                ),
                label: Text(l10n.reprintTooltip),
              ),
            )
          else
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
  ReceiptType.kurye => l10n.receiptTypeCourier,
};

// ────────────────────────────── Cihaz ──────────────────────────────

class _DeviceSection extends ConsumerWidget {
  const _DeviceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    // Eşlemeyi sıfırlamak sunucu değiştirmenin diğer yüzü: token'ı silmek,
    // kasayı yeni bir sunucuya bağlamanın ilk adımıdır. Aynı bayrak.
    final allowed = ref.watch(
      kdsSettingsProvider.select((settings) => settings.allowServerChange),
    );

    return _Section(
      title: l10n.settingsSectionDevice,
      icon: Icons.developer_board_outlined,
      children: [
        _ValueRow(label: l10n.deviceInfoVersion, value: AppConfig.appVersion),
        const SizedBox(height: BldSpacing.md),
        const _UpdateCheckButton(),
        const SizedBox(height: BldSpacing.md),
        LockedAction(
          locked: !allowed,
          child: FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(BldColors.danger),
              foregroundColor: const Color(BldColors.neutral0),
            ),
            onPressed: allowed
                ? () => unawaited(_resetPairing(context, ref))
                : null,
            icon: LockedIcon(icon: Icons.link_off, locked: !allowed),
            label: Text(l10n.settingsResetPairing),
          ),
        ),
      ],
    );
  }

  Future<void> _resetPairing(BuildContext context, WidgetRef ref) async {
    if (!ref.read(kdsSettingsProvider).allowServerChange) {
      showLockMessage(context, ref);
      return;
    }

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

/// Kurulum komutu gibi kopyalanabilir olması gereken ipucu metni.
///
/// `SelectableText` — bu satırdaki `sudo apt install …` komutunu elle
/// yeniden yazmak yerine seçip kopyalamak isteyen kişi haklı.
class _HintText extends StatelessWidget {
  const _HintText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => SelectableText(
    text,
    style: const TextStyle(
      fontSize: KdsTextScale.statusBar,
      color: Color(BldColors.warning),
    ),
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
          // `Consumer` — bu widget `ref` taşımıyor ve yalnız dokunmatik
          // bayrağı için sınıf hiyerarşisini değiştirmek gereksiz.
          child: Consumer(
            builder: (context, ref, _) => KeyboardTextField(
              controller: _controller,
              touchMode: ref.watch(
                kdsSettingsProvider.select((settings) => settings.touchMode),
              ),
              isDense: true,
              label: widget.label,
              onSubmitted: widget.onSaved,
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
    this.enabled = true,
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

  /// Kapalıyken düğmeler pasifleşir ama değer okunur kalır.
  ///
  /// Gizlemek yerine pasifleştiriyoruz: ayarın var olduğunu bilmek,
  /// neden görünmediğini aramaktan iyidir.
  final bool enabled;

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
            onPressed: !enabled || value <= min
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
            onPressed: !enabled || value >= max
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
}) => showDialog<String>(
  context: context,
  builder: (context) =>
      _TextPromptDialog(title: title, hint: hint, initialValue: initialValue),
);

/// Metin soran pencere.
///
/// DENETLEYİCİYİ PENCERENİN KENDİSİ SAHİPLENİR. Önce `showDialog`'un
/// döndürdüğü `Future` beklenip denetleyici elden çıkarılıyordu; oysa
/// `Future` rota **atıldığı anda** tamamlanıyor, pencere ise kapanma
/// animasyonu boyunca hâlâ çizili duruyor. Aradaki karelerde `TextField`
/// elden çıkarılmış bir denetleyiciye erişip iddia hatası atıyordu.
class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.hint,
    required this.initialValue,
  });

  final String title;
  final String hint;
  final String initialValue;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.hint,
            style: const TextStyle(
              fontSize: KdsTextScale.statusBar,
              color: Color(BldColors.warning),
            ),
          ),
          const SizedBox(height: BldSpacing.md),
          Consumer(
            builder: (context, ref, _) => KeyboardTextField(
              controller: _controller,
              touchMode: ref.watch(
                kdsSettingsProvider.select((settings) => settings.touchMode),
              ),
              autofocus: true,
              onSubmitted: (value) => Navigator.of(context).pop(value),
            ),
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
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(
            l10n.save,
            style: const TextStyle(fontSize: KdsTextScale.statusBar),
          ),
        ),
      ],
    );
  }
}
