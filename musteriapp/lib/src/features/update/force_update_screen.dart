/// Zorunlu güncelleme — engelleyici ekran (`docs/07-musteriapp.md` §2).
///
/// Geri tuşu çalışmaz ve gezinme yoktur: sürüm `min_supported` altındayken
/// uygulamanın hiçbir yüzeyi kullanılamaz.
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/catalog_providers.dart';
import '../../theme/bld_theme.dart';

class ForceUpdateScreen extends ConsumerWidget {
  const ForceUpdateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final gate = ref.watch(versionGateProvider);
    final minSupported = gate.valueOrNull?.minSupported;
    final installed =
        gate.valueOrNull?.installedVersion ?? const VersionGate.undetermined().installedVersion;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(BldSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.system_update,
                    size: 64,
                    color: bldColor(BldColors.brand500),
                  ),
                  const SizedBox(height: BldSpacing.lg),
                  Text(
                    l10n.updateTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: BldSpacing.md),
                  Text(
                    l10n.updateBody,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: BldSpacing.lg),
                  Text(
                    l10n.updateCurrentVersion(installed),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (minSupported != null)
                    Text(
                      l10n.updateMinimumVersion(minSupported),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: BldSpacing.xl),
                  FilledButton(
                    onPressed: gate.isLoading
                        ? null
                        : () => ref.invalidate(versionGateProvider),
                    child: Text(l10n.updateRecheck),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
