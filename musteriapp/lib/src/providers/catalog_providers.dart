/// Vitrin, menü ve sürüm sağlayıcıları.
///
/// Üç iş kuralını da sunucu söyler (`docs/07-musteriapp.md` §3): hangi menü,
/// sipariş alınıyor mu (`is_open` + `ordering_enabled`), hangi ödeme yöntemleri
/// açık (`payment_methods`). Bu dosya onları taşır, yorumlamaz.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../features/update/version_check.dart';
import 'infra_providers.dart';

/// Vitrin ve nereden geldiği.
@immutable
class LocationSnapshot {
  const LocationSnapshot({required this.location, required this.fromCache});

  final Location location;

  /// `true` ise değerler cihazdaki kopyadan geldi ve eskimiş olabilir.
  final bool fromCache;
}

/// Faz 1'de tek vitrin döner ama sözleşme dizi verir; ilk eleman alınır.
final locationProvider = FutureProvider<LocationSnapshot>((ref) async {
  final cache = ref.watch(localCacheProvider);
  final connectivity = ref.read(connectivityProvider.notifier);

  try {
    final locations = await ref.watch(apiProvider).catalog.locations();
    connectivity.reportSuccess();

    if (locations.isEmpty) {
      // Sözleşme en az bir vitrin garanti etmiyor. Mesaj boş bırakılır:
      // `NOT_FOUND` ekranda l10n metnine çevrilir, bu dize gösterilmez.
      throw const ApiException(code: ApiErrorCode.notFound, message: '');
    }

    final location = locations.first;
    await cache.writeLocation(location);
    return LocationSnapshot(location: location, fromCache: false);
  } on ApiException catch (error) {
    connectivity.reportFailure(error);

    final cached = cache.readLocation();
    if (cached != null) {
      return LocationSnapshot(location: cached, fromCache: true);
    }
    rethrow;
  }
});

/// Menü ve nereden geldiği.
@immutable
class MenuSnapshot {
  const MenuSnapshot({
    required this.categories,
    required this.fromCache,
    this.cachedAt,
  });

  final List<MenuCategory> categories;

  /// `true` ise menü cihazdaki kopyadan geldi — salt okunur gösterilir.
  final bool fromCache;

  /// Önbelleğe alınma zamanı (UTC). Yalnızca [fromCache] doğruyken anlamlı.
  final DateTime? cachedAt;

  /// Tüm kategorilerin ürünleri, kategori sırasıyla.
  List<MenuItem> get allItems => [
    for (final category in categories) ...category.items,
  ];
}

/// Menü. Ağ başarısız olursa son kaydedilen menü döner
/// (`docs/07-musteriapp.md` §5).
final menuProvider = FutureProvider.family<MenuSnapshot, int>((
  ref,
  locationId,
) async {
  final cache = ref.watch(localCacheProvider);
  final connectivity = ref.read(connectivityProvider.notifier);

  try {
    final categories = await ref.watch(apiProvider).catalog.menu(locationId);
    connectivity.reportSuccess();
    await cache.writeMenu(locationId, categories);

    return MenuSnapshot(
      categories: _sorted(categories),
      fromCache: false,
    );
  } on ApiException catch (error) {
    connectivity.reportFailure(error);

    final cached = cache.readMenu(locationId);
    if (cached != null) {
      return MenuSnapshot(
        categories: _sorted(cached),
        fromCache: true,
        cachedAt: cache.readMenuTimestamp(),
      );
    }
    rethrow;
  }
});

List<MenuCategory> _sorted(List<MenuCategory> categories) =>
    [...categories]..sort((a, b) => a.sort.compareTo(b.sort));

/// Tek ürün. Menüden çözülür; ayrı bir uç yoktur (`docs/openapi.yaml`).
///
/// Ürün menüde yoksa `null` döner — derin bağlantı eski bir ürüne işaret
/// ediyorsa ekran "bulunamadı" gösterir, çökmez.
final menuItemProvider = FutureProvider.family<MenuItem?, int>((
  ref,
  menuItemId,
) async {
  final location = await ref.watch(locationProvider.future);
  final menu = await ref.watch(menuProvider(location.location.id).future);

  for (final item in menu.allItems) {
    if (item.id == menuItemId) return item;
  }
  return null;
});

/// Zorunlu güncelleme kararı.
@immutable
class VersionGate {
  const VersionGate({
    required this.updateRequired,
    required this.installedVersion,
    this.minSupported,
  });

  /// Sürüm denetlenemedi (sunucuya ulaşılamadı vb.) — kullanıcı engellenmez.
  const VersionGate.undetermined()
    : updateRequired = false,
      installedVersion = AppConfig.appVersion,
      minSupported = null;

  final bool updateRequired;
  final String installedVersion;
  final String? minSupported;
}

/// `GET /app-version` + sürüm karşılaştırması.
///
/// Sunucuya ulaşılamazsa engelleme yapılmaz: çevrimdışı bir kullanıcıyı
/// "güncelleyin" ekranında kilitlemek, eski bir istemciyi çalıştırmaktan daha
/// kötüdür (menü önbellekten okunabiliyor olmalı).
final versionGateProvider = FutureProvider<VersionGate>((ref) async {
  try {
    final info = await ref
        .watch(apiProvider)
        .appVersion
        .check(AppConfig.appId);
    ref.read(connectivityProvider.notifier).reportSuccess();

    return VersionGate(
      updateRequired: isUpdateRequired(
        current: AppConfig.appVersion,
        minSupported: info.minSupported,
      ),
      installedVersion: AppConfig.appVersion,
      minSupported: info.minSupported,
    );
  } on ApiException catch (error) {
    ref.read(connectivityProvider.notifier).reportFailure(error);
    return const VersionGate.undetermined();
  }
});
