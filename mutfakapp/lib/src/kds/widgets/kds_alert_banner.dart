/// Panonun üstündeki kesinti şeridi.
///
/// **Neden durum çubuğundaki nokta yetmiyor:** bağlantı koptuğunda ekrandaki
/// liste bozulmadan durur (`docs/05` §4) — yani ekran normal görünür. Mutfak,
/// on dakikadır yeni sipariş gelmediğini "sakin bir gün" sanabilir. Şerit bu
/// yanılgıyı imkânsız kılar: pano daralır, üstte kırmızı bir bant belirir.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/printer_probe.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/kds_theme.dart';

/// Gösterilecek uyarı varsa şerit, yoksa sıfır yükseklikte boşluk.
class KdsAlertBanner extends ConsumerWidget {
  const KdsAlertBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final connection = ref.watch(connectionProvider).value;
    final printer = ref.watch(printerStatusProvider).value;
    final failedCount = ref.watch(printQueueFailedCountProvider);
    final alarm = ref.watch(newOrderAlarmProvider);
    final connectionAlarm = ref.watch(connectionAlarmProvider);

    // Sıra önemlidir: bağlantı yoksa yazıcı uyarısı ikinci derecededir,
    // iki bant üst üste koymak paydan yer çalar.
    final banner = switch (connection) {
      OrderSourceConnection.disconnected => _Banner(
        color: const Color(BldColors.danger),
        icon: Icons.cloud_off,
        title: l10n.offlineBannerTitle,
        body: connectionAlarm.silentWhileDisconnected
            // Kopukken ses de çıkmıyorsa personelin bunu bilmesi gerekir:
            // sessiz bir kesinti, kesintiyi hiç bilmemekten farksızdır.
            ? '${l10n.offlineBannerBody} ${l10n.alarmMutedBody}'
            : l10n.offlineBannerBody,
        // SUSTURMA DÜĞMESİ YOK — bilinçli. Kopukluk saatlerce sürebilir
        // ve susturmak tek uyarıyı kapatıp mutfağı kör bırakmak olur.
        // Sesi durduran tek şey bağlantının geri gelmesidir.
      ),
      OrderSourceConnection.connecting => _Banner(
        color: const Color(BldColors.warning),
        icon: Icons.cloud_sync_outlined,
        title: l10n.connectingBannerTitle,
        body: l10n.connectingBannerBody,
      ),
      // `revoked` durumunda kök bileşen zaten eşleme ekranına geçiyor;
      // burada da uyarmak çift mesaj olurdu.
      //
      // Onay bekleyen sipariş varken ses çıkmıyorsa bu, yazıcıdan da önemli:
      // personel ekrana bakmadığı sürece siparişi hiç görmeyecek.
      _ when alarm.silentWhileWaiting => _Banner(
        color: const Color(BldColors.danger),
        icon: Icons.volume_off,
        title: l10n.alarmMutedTitle,
        body: l10n.alarmMutedBody,
      ),
      _ when printer == PrinterAvailability.unavailable => _Banner(
        color: const Color(BldColors.warning),
        icon: Icons.print_disabled_outlined,
        title: l10n.printerBannerTitle,
        body: l10n.printerBannerBody,
      ),
      // Yazıcı cihazı yerinde ama basım başarısız oluyor: kâğıt bitmiş,
      // kapak açık kalmış ya da kablo oynamış. Cihaz dosyası var olduğu için
      // "yazıcı yok" uyarısı bu durumu YAKALAMAZ.
      _ when failedCount > 0 => _Banner(
        color: const Color(BldColors.danger),
        icon: Icons.print_disabled_outlined,
        title: l10n.queueBacklogTitle,
        body: l10n.queueBacklogBody(failedCount),
      ),
      _ => null,
    };

    return banner ?? const SizedBox.shrink();
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
    this.onSilence,
    this.silenceLabel,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String body;

  /// Verilirse şeritte bir "sesi sustur" düğmesi çizilir.
  final VoidCallback? onSilence;
  final String? silenceLabel;

  @override
  Widget build(BuildContext context) {
    final foreground = KdsAccents.onAccent(color);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        BldSpacing.md,
        0,
        BldSpacing.md,
        BldSpacing.sm,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: BldSpacing.md,
        vertical: BldSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(BldRadius.sm),
      ),
      child: Row(
        children: [
          Icon(icon, size: 32, color: foreground),
          const SizedBox(width: BldSpacing.md),
          Text(
            title,
            style: TextStyle(
              fontSize: KdsTextScale.columnHeader,
              fontWeight: FontWeight.bold,
              color: foreground,
            ),
          ),
          const SizedBox(width: BldSpacing.md),
          Expanded(
            child: Text(
              body,
              style: TextStyle(
                fontSize: KdsTextScale.statusBar,
                color: foreground,
              ),
            ),
          ),
          if (onSilence != null && silenceLabel != null) ...[
            const SizedBox(width: BldSpacing.md),
            OutlinedButton.icon(
              onPressed: onSilence,
              icon: Icon(Icons.volume_off, color: foreground),
              label: Text(
                silenceLabel!,
                style: TextStyle(
                  fontSize: KdsTextScale.statusBar,
                  color: foreground,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: foreground),
                // Tema dolu butonlara tam genişlik veriyor; şeritte
                // içeriğe göre daralması gerekiyor.
                minimumSize: const Size(0, 44),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
