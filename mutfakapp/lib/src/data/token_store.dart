/// Mutfak cihaz token'ının kalıcı saklanması — `docs/05-mutfakapp.md` §7.
///
/// `bld_api_client` token'ın nerede durduğunu bilmez; bu, arayüzün Linux
/// masaüstü uygulaması tarafındaki karşılığıdır.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
