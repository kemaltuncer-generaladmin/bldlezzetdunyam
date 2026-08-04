/// Çevrimdışı davranış için yerel önbellek — `docs/07-musteriapp.md` §5.
///
/// İnternet yoksa son çekilen menü **salt okunur** gösterilir ve sepet yerelde
/// korunur. Bu dosya o iki şeyi saklar; iş kuralı içermez.
library;

import 'dart:convert';

import 'package:bld_api_client/bld_api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Menü ve sepetin cihazdaki kopyası.
///
/// **VARSAYIM:** `docs/07-musteriapp.md` §1 sepet için `sqflite` diyor. Faz
/// 1'de sepet tek bir küçük JSON belgesidir; ilişkisel sorgu, göç veya eşzamanlı
/// yazma ihtiyacı yok. `shared_preferences` seçildi — bir bağımlılık ve bir şema
/// göç mekanizması eksilmiş oldu. Karar `docs/BILINMEYENLER.md`'de.
class LocalCache {
  const LocalCache(this._prefs);

  static const String _menuKey = 'bld.cache.menu';
  static const String _menuLocationKey = 'bld.cache.menu.location';
  static const String _menuAtKey = 'bld.cache.menu.at';
  static const String _locationKey = 'bld.cache.location';
  static const String _cartKey = 'bld.cart';

  final SharedPreferences _prefs;

  // ── Vitrin ──────────────────────────────────────────────────────────────

  Future<void> writeLocation(Location location) async {
    await _prefs.setString(_locationKey, jsonEncode(location.toJson()));
  }

  /// Kayıtlı vitrin. Çevrimdışı açılışta menüyü gösterebilmek için gerekir —
  /// menü önbelleği vitrin kimliğine bağlıdır.
  ///
  /// **Dikkat:** buradan okunan `is_open` / `ordering_enabled` / `payment_methods`
  /// eskimiş olabilir. Çevrimdışıyken zaten sipariş verilemez; bu değerler
  /// yalnızca menüyü çizmek için kullanılır.
  Location? readLocation() {
    final raw = _prefs.getString(_locationKey);
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return Location.fromJson(Map<String, dynamic>.from(decoded));
    } on Object {
      return null;
    }
  }

  // ── Menü ────────────────────────────────────────────────────────────────

  Future<void> writeMenu(int locationId, List<MenuCategory> categories) async {
    final payload = jsonEncode([for (final c in categories) c.toJson()]);
    await _prefs.setString(_menuKey, payload);
    await _prefs.setInt(_menuLocationKey, locationId);
    await _prefs.setString(
      _menuAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  /// Kayıtlı menü. Yoksa, başka bir vitrine aitse veya bozuksa `null`.
  ///
  /// Bozuk JSON'da çökmek yerine `null` dönmek bilinçlidir: önbellek bir kolaylık,
  /// doğruluk kaynağı değil.
  List<MenuCategory>? readMenu(int locationId) {
    if (_prefs.getInt(_menuLocationKey) != locationId) return null;

    final raw = _prefs.getString(_menuKey);
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return [
        for (final item in decoded)
          MenuCategory.fromJson(Map<String, dynamic>.from(item as Map)),
      ];
    } on Object {
      return null;
    }
  }

  /// Önbelleğe alınan menünün zamanı (UTC).
  DateTime? readMenuTimestamp() {
    final raw = _prefs.getString(_menuAtKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  // ── Sepet ───────────────────────────────────────────────────────────────

  Future<void> writeCart(Object? json) async {
    if (json == null) {
      await _prefs.remove(_cartKey);
      return;
    }
    await _prefs.setString(_cartKey, jsonEncode(json));
  }

  Map<String, dynamic>? readCart() {
    final raw = _prefs.getString(_cartKey);
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } on Object {
      return null;
    }
  }
}
