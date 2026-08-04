/// Hesabım — profil ve çıkış (`docs/07-musteriapp.md` §2).
///
/// Adres defteri Faz 1'de yoktur: sözleşmede adres uçları bulunmuyor, adres
/// sipariş gövdesiyle gönderiliyor (`docs/openapi.yaml` `OrderCreateRequest`).
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
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
