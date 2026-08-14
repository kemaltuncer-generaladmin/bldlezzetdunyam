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
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              bldColor(BldColors.brand600),
              bldColor(BldColors.brand500),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(BldSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _BrandMark(),
                  const SizedBox(height: BldSpacing.lg),
                  Text(
                    l10n.appTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: BldFontFamily.display,
                      color: bldColor(BldColors.neutral0),
                      fontSize: BldTextScale.heading,
                      fontWeight: FontWeight.w700,
                      letterSpacing: BldFontFamily.displayLetterSpacing,
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
                    SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: bldColor(BldColors.neutral0),
                      ),
                    ),
                    const SizedBox(height: BldSpacing.md),
                    Text(
                      l10n.splashChecking,
                      style: TextStyle(
                        color: bldColor(
                          BldColors.neutral0,
                        ).withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Marka işareti — yumuşak beyaz daire içinde tabak ikonu.
class _BrandMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: bldColor(BldColors.neutral0).withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: bldColor(BldColors.neutral0),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.restaurant_menu_outlined,
          size: 32,
          color: bldColor(BldColors.brand600),
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
      borderRadius: BorderRadius.circular(BldRadius.lg),
      child: Padding(
        padding: const EdgeInsets.all(BldSpacing.md),
        child: ErrorView(error: error, onRetry: onRetry),
      ),
    );
  }
}
