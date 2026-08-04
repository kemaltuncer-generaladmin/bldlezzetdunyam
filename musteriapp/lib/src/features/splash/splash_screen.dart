/// Açılış ekranı — token kontrolü ve sürüm kontrolü
/// (`docs/07-musteriapp.md` §2).
///
/// Yönlendirme kararını bu ekran vermez; `routerProvider`'ın `redirect`'i
/// verir. Burada yalnızca bekleme ve hata gösterilir.
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/session_provider.dart';
import '../../theme/bld_theme.dart';
import '../../widgets/status_views.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final gate = ref.watch(versionGateProvider);
    final session = ref.watch(sessionProvider);

    final failure = gate.error ?? session.error;

    return Scaffold(
      backgroundColor: bldColor(BldColors.brand500),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(BldSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.appTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: bldColor(BldColors.neutral0),
                    fontSize: BldTextScale.heading,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: BldSpacing.xl),
                if (failure != null)
                  _SplashError(
                    error: failure,
                    onRetry: () {
                      ref.invalidate(versionGateProvider);
                      ref.read(sessionProvider.notifier).refresh();
                    },
                  )
                else ...[
                  CircularProgressIndicator(
                    color: bldColor(BldColors.neutral0),
                  ),
                  const SizedBox(height: BldSpacing.md),
                  Text(
                    l10n.splashChecking,
                    style: TextStyle(color: bldColor(BldColors.neutral0)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashError extends StatelessWidget {
  const _SplashError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bldColor(BldColors.neutral0),
      borderRadius: BorderRadius.circular(BldRadius.md),
      child: Padding(
        padding: const EdgeInsets.all(BldSpacing.md),
        child: ErrorView(error: error, onRetry: onRetry),
      ),
    );
  }
}
