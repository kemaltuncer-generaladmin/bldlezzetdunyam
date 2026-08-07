/// `packages/api_client`'ın [TokenStore] arayüzünün mobil uygulaması.
///
/// Arayüz api_client'ta tanımlıdır; token'ın nerede durduğunu istemci bilmez
/// (`docs/07-musteriapp.md` §1 — `shared_preferences`).
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Token'ı cihazda `shared_preferences` içinde saklar.
///
/// ## "Beni hatırla"
///
/// Kullanıcı giriş ekranında kutuyu **işaretlemezse** token diske hiç
/// yazılmaz, yalnızca bellekte tutulur: uygulama kapanınca oturum biter.
/// Ortak kullanılan bir telefondan sipariş veren müşterinin hesabı açık
/// kalmasın diye vardır.
///
/// Tercih (`bld.auth.remember`) diskte tutulur ama TOKEN tutulmaz — ikisi
/// karıştırılırsa "beni hatırlama" dediği hâlde oturumu açık kalan bir
/// kullanıcı doğar.
///
/// **Not:** `shared_preferences` şifreli depolama değildir. Faz 1'de kabul
/// edilmiştir: token yalnızca `customer` kapsamındadır, sunucudan iptal
/// edilebilir ve cihaz kilidi arkasındadır. Şifreli depolamaya geçiş kararı
/// `docs/BILINMEYENLER.md`'de.
class SharedPreferencesTokenStore implements TokenStore {
  SharedPreferencesTokenStore(this._prefs);

  static const String _key = 'bld.auth.token';
  static const String _rememberKey = 'bld.auth.remember';

  final SharedPreferences _prefs;

  /// Hatırlanmayan oturumun token'ı. Yalnızca uygulama açık kaldığı sürece
  /// yaşar.
  String? _ephemeral;

  /// Kullanıcının son tercihi. Kayıt yoksa `true`: uygulamanın bugüne kadarki
  /// davranışı buydu, güncelleyen kullanıcı oturumundan düşmemeli.
  bool get remember => _prefs.getBool(_rememberKey) ?? true;

  /// Tercihi değiştirir. Giriş **öncesinde** çağrılır ki token doğru yere
  /// yazılsın.
  ///
  /// Hatırlamaya geçilirken bellekteki token diske taşınır, tersinde diskteki
  /// token belleğe alınıp diskten silinir — açık oturum her iki yönde de
  /// bozulmaz.
  Future<void> setRemember({required bool value}) async {
    if (value == remember) return;
    await _prefs.setBool(_rememberKey, value);

    if (value) {
      final token = _ephemeral;
      _ephemeral = null;
      if (token != null) await _prefs.setString(_key, token);
      return;
    }

    final token = _prefs.getString(_key);
    if (token != null && token.isNotEmpty) _ephemeral = token;
    await _prefs.remove(_key);
  }

  @override
  Future<String?> read() async {
    final value = _ephemeral ?? _prefs.getString(_key);
    // Boş dize saklanmışsa (eski sürüm hatası) token yok sayılır; aksi halde
    // istemci "Bearer " gönderip her istekte 401 alırdı.
    if (value == null || value.isEmpty) return null;
    return value;
  }

  @override
  Future<void> write(String token) async {
    if (!remember) {
      _ephemeral = token;
      // Önceki oturumdan kalmış olabilir: hatırlanmayacak bir girişte
      // diskteki eski token kalırsa uygulama yeniden açıldığında o token'la
      // oturum açılır.
      await _prefs.remove(_key);
      return;
    }

    _ephemeral = null;
    await _prefs.setString(_key, token);
  }

  @override
  Future<void> clear() async {
    _ephemeral = null;
    await _prefs.remove(_key);
  }
}
