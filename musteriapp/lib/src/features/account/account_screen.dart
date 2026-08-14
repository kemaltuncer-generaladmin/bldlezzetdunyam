/// Hesabım — profil, adres defteri, bildirim ayarları ve çıkış
/// (`docs/07-musteriapp.md` §2).
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/notification_providers.dart';
import '../../providers/session_provider.dart';
import '../../router/app_router.dart';
import '../../theme/bld_theme.dart';
import '../../widgets/bld_card.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_views.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sessionAsync = ref.watch(sessionProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountTitle)),
      body: sessionAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.read(sessionProvider.notifier).refresh(),
        ),
        data: (session) {
          final customer = session.customer;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              BldSpacing.md,
              BldSpacing.md,
              BldSpacing.md,
              BldSpacing.xl,
            ),
            children: [
              if (!session.isSignedIn)
                EmptyView(
                  icon: Icons.person_outline,
                  title: l10n.accountGuest,
                  actionLabel: l10n.accountLogin,
                  onAction: () => context.go(Routes.login),
                )
              else ...[
                if (customer != null)
                  _ProfileCard(
                    name: customer.fullName,
                    email: customer.email,
                    telephone: customer.telephone,
                    company: customer.isCorporate ? customer.companyName : null,
                  )
                else
                  // Token var ama profil çekilemedi (çevrimdışı açılış).
                  BldCard(
                    child: Row(
                      children: [
                        Icon(
                          Icons.cloud_off_outlined,
                          color: bldColor(BldColors.warning),
                        ),
                        const SizedBox(width: BldSpacing.md),
                        Expanded(child: Text(l10n.offlineBadge)),
                      ],
                    ),
                  ),
                const SizedBox(height: BldSpacing.md),
                BldCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _AccountRow(
                        icon: Icons.event_repeat_outlined,
                        label: l10n.accountSubscriptions,
                        onTap: () => context.go(Routes.subscriptions),
                      ),
                      // CARİ HESAP KISAYOLU KALDIRILDI (B-19). Bakiye ve
                      // ekstre artık yalnızca admin panelinde; arka uç ve
                      // `AccountService` yerinde duruyor, müşteri
                      // arayüzünden çağrılmıyor.
                      const _RowDivider(),
                      _AccountRow(
                        icon: Icons.location_on_outlined,
                        label: l10n.addressBookTitle,
                        onTap: () => context.push(Routes.addresses),
                      ),
                    ],
                  ),
                ),
              ],

              // Bildirim ayarı giriş yapmamış kullanıcıya da açık: günlük menü
              // hatırlatması sunucuya bağlı değil, sipariş vermeyen biri de
              // "bugün ne var?" hatırlatması isteyebilir.
              SectionHeader(title: l10n.notificationsSection),
              const BldCard(child: _NotificationSettings()),

              if (session.isSignedIn) ...[
                const SizedBox(height: BldSpacing.xl),
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(sessionProvider.notifier).logout();
                    if (context.mounted) context.go(Routes.menu);
                  },
                  icon: const Icon(Icons.logout_outlined),
                  label: Text(l10n.accountLogout),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.email,
    required this.telephone,
    this.company,
  });

  final String name;
  final String email;
  final String telephone;

  /// Kurumsal hesapta firma unvanı; bireysel/eski hesapta `null`.
  final String? company;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return BldCard(
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: bldColor(BldColors.brand100),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _initials,
              style: TextStyle(
                fontFamily: BldFontFamily.display,
                fontSize: BldTextScale.title,
                fontWeight: FontWeight.w700,
                color: bldColor(BldColors.brand700),
              ),
            ),
          ),
          const SizedBox(width: BldSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (company != null && company!.isNotEmpty) ...[
                  Text(
                    company!,
                    style: textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(name, style: textTheme.bodyMedium),
                ] else
                  Text(name, style: textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(email, style: textTheme.bodySmall),
                Text(telephone, style: textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Gruplu kısayol kartında satırları ayıran ince çizgi.
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    indent: BldSpacing.md,
    endIndent: BldSpacing.md,
    color: bldColor(BldColors.neutral100),
  );
}

/// Ayar/kısayol satırı — kart içinde tıklanabilir liste öğesi.
class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BldRadius.md),
      child: Padding(
        padding: const EdgeInsets.all(BldSpacing.md),
        child: Row(
          children: [
            Icon(icon, size: 22, color: bldColor(BldColors.brand700)),
            const SizedBox(width: BldSpacing.md),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
            ),
            Icon(
              Icons.chevron_right_outlined,
              color: bldColor(BldColors.neutral400),
            ),
          ],
        ),
      ),
    );
  }
}

/// Günlük menü hatırlatması.
///
/// Anahtar iyimser açılmaz: izin reddedilirse kapalı kalır ve nedeni
/// söylenir. "Açık" görünen ama hiç bildirim atmayan bir ayar, kullanıcının
/// uygulamaya güvenini bozan sessiz arızalardan biri.
class _NotificationSettings extends ConsumerWidget {
  const _NotificationSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final reminder = ref.watch(dailyReminderProvider);
    final supported = ref.watch(notificationsProvider).isSupported;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: reminder.enabled,
          onChanged: supported
              ? (value) => _toggle(context, ref, enabled: value)
              : null,
          title: Text(l10n.notificationsDailyReminder),
          subtitle: Text(
            supported
                ? l10n.notificationsDailyReminderAt(reminder.label)
                : l10n.notificationsUnsupported,
          ),
        ),
        if (supported && reminder.enabled)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => _pickTime(context, ref),
              icon: const Icon(Icons.schedule_outlined, size: 18),
              label: Text(l10n.notificationsChangeTime),
            ),
          ),
      ],
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref, {
    required bool enabled,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final ok = await ref
        .read(dailyReminderProvider.notifier)
        .setEnabled(enabled);
    if (!ok && enabled) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.notificationsDenied)));
    }
  }

  Future<void> _pickTime(BuildContext context, WidgetRef ref) async {
    final current = ref.read(dailyReminderProvider);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null) return;

    await ref
        .read(dailyReminderProvider.notifier)
        .setTime(hour: picked.hour, minute: picked.minute);
  }
}
