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
            padding: const EdgeInsets.all(BldSpacing.md),
            children: [
              if (!session.isSignedIn) ...[
                Text(l10n.accountGuest),
                const SizedBox(height: BldSpacing.md),
                FilledButton(
                  onPressed: () => context.go(Routes.login),
                  child: Text(l10n.accountLogin),
                ),
              ] else ...[
                if (customer != null) ...[
                  _ProfileRow(
                    label: l10n.accountName,
                    value: customer.fullName,
                  ),
                  _ProfileRow(
                    label: l10n.accountEmail,
                    value: customer.email,
                  ),
                  _ProfileRow(
                    label: l10n.accountTelephone,
                    value: customer.telephone,
                  ),
                ] else
                  // Token var ama profil çekilemedi (çevrimdışı açılış).
                  Text(l10n.offlineBadge),

                const Divider(height: BldSpacing.lg),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(l10n.addressBookTitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.addresses),
                ),
              ],

              // Bildirim ayarı giriş yapmamış kullanıcıya da açık: günlük menü
              // hatırlatması sunucuya bağlı değil, sipariş vermeyen biri de
              // "bugün ne var?" hatırlatması isteyebilir.
              const Divider(height: BldSpacing.lg),
              const _NotificationSettings(),

              if (session.isSignedIn) ...[
                const SizedBox(height: BldSpacing.lg),
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(sessionProvider.notifier).logout();
                    if (context.mounted) context.go(Routes.menu);
                  },
                  icon: const Icon(Icons.logout),
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
        Text(
          l10n.notificationsSection,
          style: Theme.of(context).textTheme.titleMedium,
        ),
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
              icon: const Icon(Icons.schedule, size: 18),
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

    final ok = await ref.read(dailyReminderProvider.notifier).setEnabled(enabled);
    if (!ok && enabled) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.notificationsDenied)),
      );
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

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BldSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
