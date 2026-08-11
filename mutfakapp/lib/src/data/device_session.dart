/// `K-07` — cihaz oturumu: sunucu adresi + mutfak token'ı
/// (`docs/05-mutfakapp.md` §7).
///
/// İkisi birlikte tutulur çünkü birlikte anlam taşırlar: token bir sunucuya
/// aittir, adres değişirse token geçersizdir.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Diskten okunan oturum durumu.
class DeviceSession {
  const DeviceSession({required this.baseUrl, this.token});

  final String baseUrl;

  /// `POST /kitchen/pair` ile alınan token; eşlenmemişse `null`.
  final String? token;

  bool get isPaired => token != null && token!.isNotEmpty;

  DeviceSession copyWith({String? baseUrl, String? token}) =>
      DeviceSession(baseUrl: baseUrl ?? this.baseUrl, token: token);
}

/// Oturumu `shared_preferences`'ta saklar.
///
/// Token'ın anahtarı [SharedPreferencesTokenStore] ile **aynıdır**: `BldApi`
/// token'ı oradan okur, burası aynı satırı yazar. İki kopya tutmak, birinin
/// bayatlaması demek olurdu.
class DeviceSessionStore {
  DeviceSessionStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const String baseUrlKey = 'kitchen_base_url';

  final SharedPreferencesAsync _preferences;

  late final TokenStore tokens = SharedPreferencesTokenStore(
    preferences: _preferences,
  );

  /// Kayıtlı oturumu okur; adres yoksa [fallbackBaseUrl] kullanılır.
  Future<DeviceSession> read({required String fallbackBaseUrl}) async {
    final baseUrl = await _preferences.getString(baseUrlKey);
    return DeviceSession(
      baseUrl: (baseUrl == null || baseUrl.isEmpty) ? fallbackBaseUrl : baseUrl,
      token: await tokens.read(),
    );
  }

  Future<void> writeBaseUrl(String baseUrl) =>
      _preferences.setString(baseUrlKey, baseUrl);

  Future<void> clearToken() => tokens.clear();

  // Pairing cooldown: when server signals rate limiting, we persist a
  // timestamp (ms since epoch UTC) until which pairing attempts should be
  // blocked. This prevents the UI from hammering the pair endpoint.
  static const String _pairCooldownKey = 'kitchen_next_pair_at';

  Future<void> writePairCooldown(Duration duration) async {
    final until = DateTime.now().toUtc().millisecondsSinceEpoch +
        duration.inMilliseconds;
    await _preferences.setInt(_pairCooldownKey, until);
  }

  Future<int?> readPairCooldownMillis() => _preferences.getInt(_pairCooldownKey);
}

/// `shared_preferences` üzerinde saklayan [TokenStore].
class SharedPreferencesTokenStore implements TokenStore {
  SharedPreferencesTokenStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  /// Anahtar bir kez yayımlandıktan sonra değişmez; değişirse kasadaki
  /// eşleme kaybolur ve mutfak sabah sipariş göremez.
  static const String tokenKey = 'kitchen_device_token';

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read() => _preferences.getString(tokenKey);

  @override
  Future<void> write(String token) => _preferences.setString(tokenKey, token);

  @override
  Future<void> clear() => _preferences.remove(tokenKey);
}

/// Sunucu adresini kullanıcı girdisinden normalleştirir.
///
/// Personel "192.168.1.5:8080" ya da "https://api.example.com/" yazabilir;
/// sözleşme `/api` ile biten bir taban adres bekler.
String normalizeBaseUrl(String input) {
  var value = input.trim();
  if (value.isEmpty) return value;

  if (!value.startsWith('http://') && !value.startsWith('https://')) {
    value = 'http://$value';
  }
  while (value.endsWith('/')) {
    value = value.substring(0, value.length - 1);
  }
  if (!value.endsWith('/api')) value = '$value/api';

  return value;
}
