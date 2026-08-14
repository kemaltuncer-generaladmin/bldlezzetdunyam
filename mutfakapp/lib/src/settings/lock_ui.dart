/// Kilitli eylemlerin arayüz kabuğu — K-21 §5.4 / `docs/05-mutfakapp.md` §8.
///
/// Kilit politikası [KdsSettings] üzerindedir; burada yalnızca onun
/// **görünen yüzü** vardır. Tek yerde durması bilinçli: altı yetenek altı
/// ayrı ekranda kilitleniyor ve her birinin kendi "kilitli görünüm"
/// yorumunu yazması, personelin her ekranda farklı bir şey öğrenmesi
/// demekti.
///
/// ÜÇ KURAL:
///
///   1. **Kilitli düğme GİZLENMEZ.** Kaybolan düğme personeli "bozuldu"
///      sanısına iter ve mutfakta telefon açtırır; pasif düğme "yasak"
///      der. Bu yüzden `onPressed: null` + [LockedIcon].
///   2. **Dokunuş yutulmaz.** Pasif bir düğme hiçbir şey söylemez;
///      [LockedAction] üstüne saydam bir katman koyar ve dokunulduğunda
///      kilit metnini gösterir.
///   3. **Metin yöneticinindir.** `lockMessage` doluysa o gösterilir,
///      boşsa arayüzün genel cümlesi (AGENTS.md §4: sabit metin l10n'dan).
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../l10n/app_localizations.dart';

/// Personele gösterilecek kilit cümlesi.
///
/// Yöneticinin yazdığı metin boşsa arayüzün genel metni kullanılır —
/// "kilitli" bilgisini vermeyen boş bir uyarı, hiç uyarı vermemekle aynı.
String lockMessageFor(AppL10n l10n, String lockMessage) {
  final custom = lockMessage.trim();
  return custom.isEmpty ? l10n.lockedMessage : custom;
}

/// Ayarlardaki kilit metnini çözer (izleyerek — metin değişince yeniden çizer).
String watchLockMessage(BuildContext context, WidgetRef ref) => lockMessageFor(
  AppL10n.of(context),
  ref.watch(kdsSettingsProvider.select((settings) => settings.lockMessage)),
);

/// Kilit metnini şerit olarak gösterir.
///
/// Pencere değil şerit: mutfakta eli dolu personelin kapatması gereken bir
/// pencere, yanlış dokunuşun cezasına dönüşür. Şerit kendiliğinden kapanır.
void showLockMessage(BuildContext context, WidgetRef ref) {
  final message = lockMessageFor(
    AppL10n.of(context),
    ref.read(kdsSettingsProvider).lockMessage,
  );

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: const Color(BldColors.warning),
        content: Row(
          children: [
            const Icon(
              Icons.lock_outline,
              size: 26,
              color: Color(BldColors.neutral900),
            ),
            const SizedBox(width: BldSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: KdsTextScale.statusBar,
                  fontWeight: FontWeight.bold,
                  color: Color(BldColors.neutral900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
}

/// Pasifleştirilmiş bir düğmeyi saran dokunma katmanı.
///
/// Pasif düğme dokunuşu kendisi almaz (kayıtlı jesti yoktur); bu katman
/// `opaque` davranışıyla dokunuşu üstlenir ve kilit metnini gösterir.
/// Serbestken hiçbir şey sarmaz — kilitsiz kasada davranış birebir aynıdır.
class LockedAction extends ConsumerWidget {
  const LockedAction({required this.locked, required this.child, super.key});

  final bool locked;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!locked) return child;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showLockMessage(context, ref),
      onLongPress: () => showLockMessage(context, ref),
      child: child,
    );
  }
}

/// Simgeye küçük bir asma kilit iliştirir.
///
/// Simgenin KENDİSİ değişmez: `Icons.print_outlined` yerine kilit çizmek,
/// personelin düğmeyi tanıdığı tek işareti silerdi. Kilit sağ alt köşeye
/// binen ikinci bir işarettir.
class LockedIcon extends StatelessWidget {
  const LockedIcon({
    required this.icon,
    required this.locked,
    this.size,
    super.key,
  });

  final IconData icon;
  final bool locked;

  /// `null` ise `IconTheme`'den gelir — `IconButton.iconSize` bozulmasın.
  final double? size;

  @override
  Widget build(BuildContext context) {
    if (!locked) return Icon(icon, size: size);

    final base = size ?? IconTheme.of(context).size ?? 24;

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Icon(icon, size: base),
        Icon(
          Icons.lock,
          size: base * 0.55,
          color: const Color(BldColors.warning),
        ),
      ],
    );
  }
}

/// Durum çubuğundaki kilit rozeti (K-21 §5.4).
///
/// NEDEN GEREKLİ: kilitli düğmeler ekranın dört bir yanına dağılmış
/// durumda. Rozet olmadan personel tek tek deneyip keşfediyor; rozetle
/// "bu kasada bazı şeyler yönetici tarafından kapatılmış" bilgisini tek
/// bakışta alıyor.
///
/// HİÇ KİLİT YOKSA ÇİZİLMEZ: normal kasada durum çubuğundan yer çalmaz.
class LockBadge extends ConsumerWidget {
  const LockBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasLock = ref.watch(
      kdsSettingsProvider.select((settings) => settings.hasLock),
    );
    if (!hasLock) return const SizedBox.shrink();

    final l10n = AppL10n.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: BldSpacing.lg),
      child: Tooltip(
        message: l10n.lockedBadgeTooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showLockMessage(context, ref),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 20,
                color: Color(BldColors.warning),
              ),
              const SizedBox(width: BldSpacing.xs),
              Text(
                l10n.lockedBadge,
                style: const TextStyle(
                  fontSize: KdsTextScale.statusBar,
                  fontWeight: FontWeight.bold,
                  color: Color(BldColors.warning),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kilitli bir ekranın en üstündeki açıklama şeridi.
///
/// Ekranın kapısı kapalıyken (ör. `allowSettings` yanlışken) buraya başka
/// bir yoldan girilirse, personel düğmelerin neden çalışmadığını okumadan
/// anlayamaz.
class LockNotice extends ConsumerWidget {
  const LockNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);

    return Container(
      padding: const EdgeInsets.all(BldSpacing.md),
      decoration: BoxDecoration(
        color: const Color(BldColors.warning),
        borderRadius: BorderRadius.circular(BldRadius.md),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_outline,
            size: 30,
            color: Color(BldColors.neutral900),
          ),
          const SizedBox(width: BldSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.lockedBadge,
                  style: const TextStyle(
                    fontSize: KdsTextScale.statusBar,
                    fontWeight: FontWeight.bold,
                    color: Color(BldColors.neutral900),
                  ),
                ),
                Text(
                  watchLockMessage(context, ref),
                  style: const TextStyle(
                    fontSize: KdsTextScale.orderNumber,
                    color: Color(BldColors.neutral900),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kilitli ekranın gövdesi: OKUNUR kalır, dokunuşa kapanır.
///
/// Değerleri silmiyoruz — "yazıcı yolu neydi" sorusu destek görüşmesinin
/// ilk sorusudur ve kilitli bir kasada da cevaplanabilmeli. Yalnız
/// değiştirmek kapalı.
///
/// KAYDIRMAYI ENGELLEMEZ: `IgnorePointer` yalnız kendi alt ağacını
/// kapatır; listeyi kaydıran jest üstteki `Scrollable`'da tanımlıdır ve
/// çalışmaya devam eder — yoksa kilitli ekranın alt yarısı hiç görülemezdi.
class LockShield extends StatelessWidget {
  const LockShield({required this.locked, required this.child, super.key});

  final bool locked;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!locked) return child;

    return IgnorePointer(child: Opacity(opacity: 0.55, child: child));
  }
}
