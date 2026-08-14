/// Yükleme, hata ve çevrimdışı göstergeleri.
///
/// Üçü de `EmptyView`'un tek düzenini paylaşır (bkz. `empty_view.dart`);
/// burada yalnız hangi tonun ne zaman kullanıldığı ve metnin nereden geldiği
/// tarif ediliyor.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';

import '../core/api_error_text.dart';
import '../l10n/app_localizations.dart';
import '../theme/bld_semantic_colors.dart';
import 'empty_view.dart';
import 'skeletons.dart';

/// Varsayılan yükleme göstergesi.
///
/// **Neden spinner değil iskelet:** dönen halka "bekle" der ve ekranın nasıl
/// dolacağı hakkında hiçbir şey söylemez; içerik gelince düzen sıçrar. Bu
/// uygulamada yükleme bekleyen ekranların tamamı liste ya da liste benzeri,
/// bu yüzden ortak gösterge satır iskeleti. Kendi düzeni belirgin biçimde
/// farklı olan bir ekran (ürün detayı gibi) kendi iskeletini vermeli — bunun
/// için `Shimmer` + `SkeletonBox` doğrudan kullanılabilir.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.rows = 6});

  final int rows;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(BldSpacing.md),
    child: Align(
      alignment: Alignment.topCenter,
      child: ListRowSkeleton(count: rows),
    ),
  );
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

    return EmptyView(
      tone: BldStatusTone.error,
      icon: Icons.error_outline,
      title: l10n.errorTitle,
      message: message,
      actionLabel: onRetry == null ? null : l10n.commonRetry,
      onAction: onRetry,
    );
  }
}

/// Çevrimdışı şeridi. Menü önbellekten gösterildiğinde ve sipariş
/// engellendiğinde kullanıcıya nedenini söyler (`docs/07-musteriapp.md` §5).
///
/// **Neden dolu renk değil tint:** şerit ekranın en üstünde ve kalıcı. Dolu
/// bir uyarı rengi orada bir felaket bandı gibi duruyordu; oysa çevrimdışılık
/// bir hata değil bir DURUM — menü hâlâ okunuyor, yalnız sipariş verilemiyor.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bld = context.bld;

    return Semantics(
      container: true,
      // `role="status"`: duyurulur ama hata gibi kesmez.
      liveRegion: true,
      child: Container(
        width: double.infinity,
        color: bld.warningBg,
        padding: const EdgeInsets.symmetric(
          horizontal: BldSpacing.md,
          vertical: BldSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined, size: 18, color: bld.warningFg),
            const SizedBox(width: BldSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: bld.warningFg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Form altındaki hata kutusu. Sunucudan dönen doğrulama hatası buraya basılır.
///
/// İkonlu: hatayı YALNIZ renkle işaretlemek, kırmızıyı ayırt edemeyen
/// kullanıcı için kutuyu sıradan bir bilgi kutusuna çevirir.
class FormErrorBox extends StatelessWidget {
  const FormErrorBox({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bld = context.bld;

    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(BldSpacing.md),
        decoration: BoxDecoration(
          color: bld.dangerBg,
          borderRadius: BorderRadius.circular(BldRadius.sm),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 18, color: bld.dangerFg),
            const SizedBox(width: BldSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: bld.dangerFg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
