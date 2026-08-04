/// Yükleme, hata ve çevrimdışı göstergeleri.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';

import '../core/api_error_text.dart';
import '../l10n/app_localizations.dart';
import '../theme/bld_theme.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

/// Hata ekranı. Metin, hata **koduna** göre seçilir; sunucunun teknik
/// açıklaması kullanıcıya olduğu gibi basılmaz.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final message = error is ApiException
        ? apiErrorDisplayMessage(error as ApiException, l10n)
        : l10n.errorUnknown;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BldSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: bldColor(BldColors.danger),
            ),
            const SizedBox(height: BldSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: BldSpacing.lg),
              OutlinedButton(
                onPressed: onRetry,
                child: Text(l10n.commonRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Çevrimdışı şeridi. Menü önbellekten gösterildiğinde ve sipariş
/// engellendiğinde kullanıcıya nedenini söyler (`docs/07-musteriapp.md` §5).
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: bldColor(BldColors.warning),
      padding: const EdgeInsets.symmetric(
        horizontal: BldSpacing.md,
        vertical: BldSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off,
            size: 18,
            color: bldColor(BldColors.neutral0),
          ),
          const SizedBox(width: BldSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: bldColor(BldColors.neutral0),
                fontSize: BldTextScale.caption,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Form altındaki hata kutusu. Sunucudan dönen doğrulama hatası buraya basılır.
class FormErrorBox extends StatelessWidget {
  const FormErrorBox({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BldSpacing.md),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(BldRadius.sm),
      ),
      child: Text(message, style: TextStyle(color: scheme.onErrorContainer)),
    );
  }
}

/// Küçük renkli etiket (durum, teslimat tipi, "satışta değil").
class BldBadge extends StatelessWidget {
  const BldBadge({
    super.key,
    required this.label,
    required this.background,
    this.foreground,
  });

  final String label;
  final int background;
  final int? foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BldSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bldColor(background),
        borderRadius: BorderRadius.circular(BldRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: bldColor(foreground ?? BldColors.neutral0),
          fontSize: BldTextScale.caption,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
