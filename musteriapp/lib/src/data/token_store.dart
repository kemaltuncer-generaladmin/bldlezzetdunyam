/// `packages/api_client`'ın [TokenStore] arayüzünün mobil uygulaması.
///
/// Arayüz api_client'ta tanımlıdır; token'ın nerede durduğunu istemci bilmez
/// (`docs/07-musteriapp.md` §1 — `shared_preferences`).
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Token'ı cihazda `shared_preferences` içinde saklar.
///
/// **Not:** `shared_preferences` şifreli depolama değildir. Faz 1'de kabul
/// edilmiştir: token yalnızca `customer` kapsamındadır, sunucudan iptal
/// edilebilir ve cihaz kilidi arkasındadır. Şifreli depolamaya geçiş kararı
/// `docs/BILINMEYENLER.md`'de.
class SharedPreferencesTokenStore implements TokenStore {
  const SharedPreferencesTokenStore(this._prefs);

  static const String _key = 'bld.auth.token';

  final SharedPreferences _prefs;

  @override
  Future<String?> read() async {
    final value = _prefs.getString(_key);
    // Boş dize saklanmışsa (eski sürüm hatası) token yok sayılır; aksi halde
    // istemci "Bearer " gönderip her istekte 401 alırdı.
    if (value == null || value.isEmpty) return null;
    return value;
  }

  @override
  Future<void> write(String token) async {
    await _prefs.setString(_key, token);
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}
