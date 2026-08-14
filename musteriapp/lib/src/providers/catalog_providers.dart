/// Vitrin, menü ve sürüm sağlayıcıları.
///
/// Üç iş kuralını da sunucu söyler (`docs/07-musteriapp.md` §3): hangi menü,
/// sipariş alınıyor mu (`is_open` + `ordering_enabled`), hangi ödeme yöntemleri
/// açık (`payment_methods`). Bu dosya onları taşır, yorumlamaz.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
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

/// Genel ürün kataloğu.
///
/// **Satış artık buradan yapılmıyor** (B-19): müşteri yalnızca o günün
/// menüsünü görüyor ve sipariş [dailyMenuProvider] üzerinden veriliyor.
/// Katalog ekranları (ürün listesi + ürün detayı) mobilden kaldırıldı.
///
/// Sağlayıcı yine de duruyor çünkü ABONELİK TALEBİ ürün seçtiriyor: aylık
/// bir anlaşmanın kalemleri tek bir günün menüsünden değil, ürün
/// kataloğundan seçilir. Onu da günün menüsüne bağlamak, salı günü talep
/// oluşturan müşteriye yalnızca salı yemeklerini gösterirdi.
///
/// Ağ başarısız olursa son kaydedilen katalog döner
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

    return MenuSnapshot(categories: _sorted(categories), fromCache: false);
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

// ── Günün menüsü (B-19) ─────────────────────────────────────────────────────

/// İçinde bulunulan işletme günü (`YYYY-AA-GG`, Europe/Istanbul).
///
/// NEDEN SAĞLAYICI, NEDEN SABİT ÇAĞRI DEĞİL: uygulama gece açık kalabiliyor.
/// `BusinessDate.today()` her çağrıldığında doğru cevabı verir ama widget'lar
/// yeniden çizilmez — kullanıcı ekranda hâlâ dünü "Bugün" diye görür ve
/// sipariş verince sunucudan `past` yer. Gün buradan okunduğunda [refresh]
/// bir kez çağrılması bütün ağacı tazeliyor.
class BusinessTodayNotifier extends Notifier<String> {
  @override
  String build() => BusinessDate.today();

  /// Gün döndüyse durumu tazeler. Dönmediyse HİÇBİR ŞEY yapmaz — koşulsuz
  /// atama, uygulama her öne geldiğinde menüyü ve seçili günü boşuna
  /// sıfırlardı.
  void refresh() {
    final today = BusinessDate.today();
    if (state != today) state = today;
  }
}

final businessTodayProvider =
    NotifierProvider<BusinessTodayNotifier, String>(BusinessTodayNotifier.new);

/// Müşterinin gün şeridinden seçtiği servis günü.
///
/// Gün döndüğünde [build] yeniden koşar ve seçim bugüne düşer: dün seçiliyken
/// gece yarısını geçen bir uygulamada seçili gün artık sipariş edilemez.
class SelectedServiceDateNotifier extends Notifier<String> {
  @override
  String build() => ref.watch(businessTodayProvider);

  void select(String date) {
    if (!BusinessDate.isValid(date)) return;
    state = date;
  }
}

final selectedServiceDateProvider =
    NotifierProvider<SelectedServiceDateNotifier, String>(
      SelectedServiceDateNotifier.new,
    );

/// Bir günün menüsü ve nereden geldiği.
@immutable
class DailyMenuSnapshot {
  const DailyMenuSnapshot({required this.menu, required this.fromCache});

  final DailyMenu menu;

  /// `true` ise menü cihazdaki kopyadan geldi; sipariş verilemez.
  final bool fromCache;
}

/// Bir günün menüsü — `GET /locations/{id}/daily-menu?date=`.
///
/// Aile anahtarı GÜN'dür (`YYYY-AA-GG`), vitrin değil: vitrin faz 1'de tek ve
/// [locationProvider]'dan çözülüyor. Günü anahtar yapmak, gün şeridinde
/// gezinen kullanıcının geri döndüğü günü yeniden indirmemesini sağlıyor.
///
/// Çevrimdışıyken son kaydedilen gün döner ([DailyMenuSnapshot.fromCache]).
/// Önbellekten gelen menü **satılabilir sayılmaz**: `is_orderable` yazıldığı
/// andaki cevaptır, kesim saati o zamandan beri geçmiş olabilir.
final dailyMenuProvider = FutureProvider.family<DailyMenuSnapshot, String>((
  ref,
  date,
) async {
  final cache = ref.watch(localCacheProvider);
  final connectivity = ref.read(connectivityProvider.notifier);
  final location = await ref.watch(locationProvider.future);
  final locationId = location.location.id;

  try {
    final menu = await ref
        .watch(apiProvider)
        .catalog
        .dailyMenu(locationId, date: date);
    connectivity.reportSuccess();
    await cache.writeDailyMenu(locationId, menu);

    return DailyMenuSnapshot(menu: menu, fromCache: false);
  } on ApiException catch (error) {
    connectivity.reportFailure(error);

    final cached = cache.readDailyMenu(locationId, date);
    if (cached != null) {
      return DailyMenuSnapshot(menu: cached, fromCache: true);
    }
    rethrow;
  }
});

/// Takvim sorgusunun aralığı. Kayıt tipi: alan değerleri eşitse aile anahtarı
/// da eşittir, aynı aralık iki kez indirilmez.
typedef MenuCalendarRange = ({String from, String to});

/// Gün şeridinin ve takvim sayfasının çizdiği aralık.
///
/// Sonu **sunucunun bildirdiği** ileri görüş penceresidir
/// (`Location.max_lookahead_days`); istemci kendi sınırını uydurmaz. Vitrin
/// henüz yüklenmediyse `null` — çağıran o sırada iskelet çizer.
final menuCalendarRangeProvider = Provider<MenuCalendarRange?>((ref) {
  final location = ref.watch(locationProvider).valueOrNull?.location;
  if (location == null) return null;

  final today = ref.watch(businessTodayProvider);
  return (
    from: today,
    to: BusinessDate.addDays(today, location.maxLookaheadDays),
  );
});

/// Menü takvimi — `GET /locations/{id}/menu-calendar?from=&to=`.
///
/// Yalnız menüsü olan ya da kapalı olan günler döner; listede olmayan gün
/// "o gün bir şey yok" demektir. Ağ yoksa son kaydedilen takvim döner;
/// hiç kayıt yoksa **boş liste** döner, hata değil: takvimsiz bir gün şeridi
/// hâlâ çizilebilir (her gün "menü yok" görünür) ama takvim yüzünden menü
/// ekranını komple hata ekranına çevirmek çevrimdışı kullanıcıyı boşuna
/// kilitlerdi.
final menuCalendarProvider =
    FutureProvider.family<List<MenuCalendarDay>, MenuCalendarRange>((
      ref,
      range,
    ) async {
      final cache = ref.watch(localCacheProvider);
      final connectivity = ref.read(connectivityProvider.notifier);
      final location = await ref.watch(locationProvider.future);
      final locationId = location.location.id;

      try {
        final days = await ref
            .watch(apiProvider)
            .catalog
            .menuCalendar(locationId, from: range.from, to: range.to);
        connectivity.reportSuccess();
        await cache.writeMenuCalendar(locationId, days);
        return days;
      } on ApiException catch (error) {
        connectivity.reportFailure(error);
        return cache.readMenuCalendar(locationId, today: range.from) ??
            const <MenuCalendarDay>[];
      }
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
    final info = await ref.watch(apiProvider).appVersion.check(AppConfig.appId);
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
