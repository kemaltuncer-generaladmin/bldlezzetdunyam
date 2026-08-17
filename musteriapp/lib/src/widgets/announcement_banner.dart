/// Uygulama-içi duyuru bandı — `docs/openapi.yaml` §Duyuru.
///
/// Duyuru sunucudan gelen **düz metindir**; biçimlendirme istemcinindir. Ton
/// (`severity`) rengi ve ikonu seçer, metni değil.
///
/// **GÜVENLİK — açık yönlendirme:** `action_url` sunucudan gelen serbest bir
/// dizedir ve doğrudan `context.go()`'ya verilemez. Uygulama-içi yol
/// [kAnnouncementAllowedRoutes] beyaz listesine karşı doğrulanır; dış adres
/// yalnız `https` ise ve yalnız sistem tarayıcısında açılır. Doğrulama
/// geçmezse **düğme hiç çizilmez** — devre dışı bir düğme, kullanıcıya
/// tıklanacak bir şey vaat edip vermemektir.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../providers/announcement_providers.dart';
import '../theme/bld_semantic_colors.dart';

/// Duyurunun düğmesinin gidebileceği **sabit** uygulama-içi yollar.
///
/// Beyaz liste, sunucunun bilebileceği yolların tamamı değildir: yalnız bir
/// duyurunun kullanıcıyı göndermesi anlamlı olan yerlerdir. Giriş, ödeme ve
/// adres ekranları bilerek DIŞARIDA — bir duyurunun kullanıcıyı ödeme adımına
/// atlatması, kimlik avının uygulama içindeki karşılığı olurdu.
const Set<String> kAnnouncementAllowedRoutes = {
  '/menu',
  '/subscriptions',
  '/orders',
  '/account',
};

/// Duyuru düğmesinin varabileceği yer türü.
enum AnnouncementActionKind {
  /// Adres yok, tanınmıyor ya da güvenli değil — düğme çizilmez.
  none,

  /// Beyaz listedeki uygulama-içi yol.
  inApp,

  /// `https` dış adres; sistem tarayıcısında açılır.
  external,
}

/// `Announcement.actionUrl`'in çözülmüş hâli.
@immutable
class AnnouncementAction {
  const AnnouncementAction._(this.kind, this.target);

  /// Adres yok ya da güvenli değil.
  static const AnnouncementAction none = AnnouncementAction._(
    AnnouncementActionKind.none,
    '',
  );

  final AnnouncementActionKind kind;

  /// [AnnouncementActionKind.inApp] için yol, [AnnouncementActionKind.external]
  /// için tam adres; [AnnouncementActionKind.none] için boş.
  final String target;

  /// Sunucudan gelen adresi güvenli bir hedefe çevirir; çeviremezse [none].
  ///
  /// Sıra ÖNEMLİ ve her adım ayrı bir saldırıyı kesiyor:
  /// 1. Şema varsa adres DIŞARIDIR. `https` dışındaki her şey reddedilir —
  ///    `http` (araya girme), `javascript:`, `intent:`, `market:` ve
  ///    uygulamanın kendi derin bağlantı şeması dâhil.
  /// 2. Şema yoksa ama **yetkili alan** varsa (`//baska-site/x`) bu adres
  ///    uygulama-içi DEĞİLDİR: tarayıcı onu protokole göreli bir dış adres
  ///    sayar ve `String.startsWith('/')` denetimini geçtiği için açık
  ///    yönlendirmenin klasik biçimidir.
  /// 3. Sorgu ve çapa reddedilir: beyaz liste yolları parametre almıyor ve
  ///    `?next=` taşıyan bir yol, denetlenen yolun arkasına denetlenmemiş
  ///    ikinci bir hedef iliştirmenin yoludur.
  /// 4. Kalan düz yol, beyaz listeye **birebir** uyar. Normalleştirme
  ///    yapılmıyor: `/menu/../..` hiçbir kalıba uymadığı için zaten düşer.
  static AnnouncementAction resolve(String? actionUrl) {
    final raw = actionUrl?.trim() ?? '';
    if (raw.isEmpty) return none;

    final uri = Uri.tryParse(raw);
    if (uri == null) return none;

    if (uri.hasScheme) {
      // Alan adı BOŞ olamaz: `https:///bir-yol` ayrıştırılabilir bir adres ama
      // hiçbir sunucuyu göstermiyor ve tarayıcıda açılamaz.
      if (uri.scheme != 'https' || uri.host.isEmpty) return none;
      return AnnouncementAction._(AnnouncementActionKind.external, raw);
    }

    if (uri.hasAuthority || uri.hasQuery || uri.hasFragment) return none;
    if (!_isAllowedRoute(uri.path)) return none;
    return AnnouncementAction._(AnnouncementActionKind.inApp, uri.path);
  }

  static bool _isAllowedRoute(String path) {
    if (kAnnouncementAllowedRoutes.contains(path)) return true;

    // Tek parametreli yol: `/menu/<YYYY-AA-GG>/<kalem>`. Elle ayrıştırılıyor
    // çünkü `go_router` bir yolun kalıba uyup uymadığını dışarıdan sormuyor;
    // uydurma bir düzenli ifade yerine yolun kendi parçaları denetleniyor.
    final segments = path.split('/');
    if (segments.length != 4) return false;
    if (segments[0].isNotEmpty || segments[1] != 'menu') return false;
    if (!BusinessDate.isValid(segments[2])) return false;

    final menuItemId = int.tryParse(segments[3]);
    return menuItemId != null && menuItemId > 0;
  }
}

/// Bir yerleşimin duyuru bandı.
///
/// Hangi duyurunun çizileceğine [firstVisibleAnnouncement] karar verir; bu
/// widget yalnız çizer.
class AnnouncementBanner extends ConsumerWidget {
  const AnnouncementBanner({
    super.key,
    this.placement = AnnouncementPlacement.home,
  });

  /// `AnnouncementPlacement` sabitlerinden biri. Kapalı bir enum değildir.
  final String placement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Yükleme ve hata **sessizdir**: bant bir süs, ekranın içeriği değil.
    // İskelet çizmek, çoğu gün hiç duyuru olmadığı için her açılışta boş yere
    // yanıp sönen bir şerit demekti.
    final announcement = firstVisibleAnnouncement(
      announcements:
          ref.watch(announcementsProvider(placement)).valueOrNull ??
          const <Announcement>[],
      dismissed: ref.watch(dismissedAnnouncementsProvider),
      placement: placement,
    );
    if (announcement == null) return const SizedBox.shrink();

    return _AnnouncementCard(
      announcement: announcement,
      onDismiss: () => ref
          .read(dismissedAnnouncementsProvider.notifier)
          .dismiss(announcement.id),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({
    required this.announcement,
    required this.onDismiss,
  });

  final Announcement announcement;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bld = context.bld;

    final (Color background, Color foreground, IconData icon, String tone) =
        switch (announcement.severity) {
          AnnouncementSeverity.info => (
            bld.infoBg,
            bld.infoFg,
            Icons.info_outlined,
            l10n.announcementSeverityInfo,
          ),
          AnnouncementSeverity.warning => (
            bld.warningBg,
            bld.warningFg,
            Icons.warning_amber_outlined,
            l10n.announcementSeverityWarning,
          ),
          AnnouncementSeverity.critical => (
            bld.dangerBg,
            bld.dangerFg,
            Icons.report_outlined,
            l10n.announcementSeverityCritical,
          ),
        };

    final action = AnnouncementAction.resolve(announcement.actionUrl);
    final label = announcement.actionLabel;
    final showAction =
        action.kind != AnnouncementActionKind.none &&
        label != null &&
        label.isNotEmpty;

    return Semantics(
      container: true,
      // Ton ekran okuyucuya YAZIYLA gidiyor: rengi ve ikonu görmeyen kullanıcı
      // "uyarı" ile "bilgi" arasındaki farkı başka türlü duyamaz.
      label: [tone, ?announcement.title, announcement.body].join('. '),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(
          BldSpacing.md,
          BldSpacing.md,
          BldSpacing.md,
          0,
        ),
        padding: const EdgeInsets.all(BldSpacing.md),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(BldRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(child: Icon(icon, size: 20, color: foreground)),
            const SizedBox(width: BldSpacing.md - 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Metin ekran okuyucudan gizleniyor çünkü aynı cümle dıştaki
                  // [Semantics] etiketinde TON'la birlikte zaten okunuyor;
                  // gizlenmeseydi başlık ve gövde iki kez duyulurdu. Düğme
                  // gizlenmiyor — o bir eylemdir, okunacak metin değil.
                  ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (announcement.title != null &&
                            announcement.title!.isNotEmpty) ...[
                          Text(
                            announcement.title!,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: foreground,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          announcement.body,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showAction) ...[
                    const SizedBox(height: BldSpacing.sm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => _follow(context, action),
                        style: TextButton.styleFrom(
                          foregroundColor: foreground,
                          padding: const EdgeInsets.symmetric(
                            horizontal: BldSpacing.sm,
                          ),
                        ),
                        child: Text(label),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Kapatılamayan duyuruda düğme HİÇ çizilmiyor: gri bir çarpı,
            // hizmet kesintisi duyurusunu kapatmayı deneyip başaramayan
            // kullanıcıya uygulamanın bozuk olduğunu düşündürürdü.
            if (announcement.dismissible)
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close_outlined, size: 18),
                color: foreground,
                tooltip: l10n.announcementDismiss,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _follow(BuildContext context, AnnouncementAction action) async {
    switch (action.kind) {
      case AnnouncementActionKind.inApp:
        context.go(action.target);
      case AnnouncementActionKind.external:
        final messenger = ScaffoldMessenger.of(context);
        final l10n = AppLocalizations.of(context);
        // Uygulama İÇİ tarayıcı değil sistem tarayıcısı: kullanıcı adres
        // çubuğundaki alan adını görüp duyurunun gerçekten bizi işaret edip
        // etmediğini kendisi doğrulayabilmeli.
        final opened = await launchUrl(
          Uri.parse(action.target),
          mode: LaunchMode.externalApplication,
        ).catchError((_) => false);
        if (!opened) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.announcementLinkFailed)),
          );
        }
      case AnnouncementActionKind.none:
        // Düğme zaten çizilmedi; bu dal yalnızca `switch`i tüketiyor.
        break;
    }
  }
}
