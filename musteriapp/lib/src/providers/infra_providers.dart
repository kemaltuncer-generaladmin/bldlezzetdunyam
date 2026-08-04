/// Altyapı sağlayıcıları: depolama, token, API istemcisi, bağlantı durumu.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../core/api_error_text.dart';
import '../data/local_cache.dart';
import '../data/token_store.dart';

/// `main()` içinde `overrideWithValue` ile doldurulur.
///
/// Eşzamanlı erişim gerektiği için `FutureProvider` yerine override edilen bir
/// `Provider` kullanılır: sepet ve token açılıştan itibaren senkron okunabilsin.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw StateError('sharedPreferencesProvider must be overridden in main().');
});

final localCacheProvider = Provider<LocalCache>(
  (ref) => LocalCache(ref.watch(sharedPreferencesProvider)),
);

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => SharedPreferencesTokenStore(ref.watch(sharedPreferencesProvider)),
);

/// Tek API istemcisi. Uygulamada başka HTTP çağrısı yoktur (`AGENTS.md` §2.4).
final apiProvider = Provider<BldApi>((ref) {
  final api = BldApi(
    config: const BldApiConfig(
      baseUrl: AppConfig.apiBaseUrl,
      appId: AppConfig.appId,
      appVersion: AppConfig.appVersion,
    ),
    tokenStore: ref.watch(tokenStoreProvider),
  );
  ref.onDispose(api.close);
  return api;
});

/// Cihaz sunucuya ulaşabiliyor mu?
///
/// Ayrı bir bağlantı eklentisi kullanılmaz: "ağ arayüzü var" ile "sunucuya
/// ulaşılıyor" aynı şey değildir ve bizi ilgilendiren ikincisidir. Durum, son
/// API çağrısının sonucundan türetilir.
class ConnectivityNotifier extends Notifier<bool> {
  /// `true` = çevrimdışı.
  @override
  bool build() => false;

  /// Başarısız bir çağrının sonucunu bildirir; yalnızca ağ kaynaklı hatalar
  /// çevrimdışı sayılır (`422` çevrimdışı değildir).
  void reportFailure(Object error) {
    final offline = isOfflineError(error);
    if (state != offline) state = offline;
  }

  void reportSuccess() {
    if (state) state = false;
  }
}

/// `true` ise cihaz sunucuya ulaşamıyor.
final connectivityProvider = NotifierProvider<ConnectivityNotifier, bool>(
  ConnectivityNotifier.new,
);
