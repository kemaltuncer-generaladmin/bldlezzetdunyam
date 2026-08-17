/// Çevrimdışı davranış için yerel önbellek — `docs/07-musteriapp.md` §5.
///
/// İnternet yoksa son çekilen menü **salt okunur** gösterilir ve sepet yerelde
/// korunur. Bu dosya o iki şeyi saklar; iş kuralı içermez.
library;

import 'dart:async';
import 'dart:convert';

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Menü ve sepetin cihazdaki kopyası.
///
/// **VARSAYIM:** `docs/07-musteriapp.md` §1 sepet için `sqflite` diyor. Faz
/// 1'de sepet tek bir küçük JSON belgesidir; ilişkisel sorgu, göç veya eşzamanlı
/// yazma ihtiyacı yok. `shared_preferences` seçildi — bir bağımlılık ve bir şema
/// göç mekanizması eksilmiş oldu. Karar `docs/BILINMEYENLER.md`'de.
class LocalCache {
  const LocalCache(this._prefs);

  /// Kalıcı sepetin şema sürümü.
  ///
  /// **1 → 2 (B-19):** sepet artık bir SERVİS GÜNÜNE bağlı (`Cart.serviceDate`).
  /// Sürümsüz eski kayıtlar okunmuyor, SİLİNİYOR. Göç etmek teknik olarak
  /// mümkündü — eski sepete bugünün tarihini yazmak — ama o sepet dünkü
  /// menüden dolduruldu: kalemler bugün var olmayabilir ve fiyatları
  /// değişmiş olabilir. Kullanıcının sepetini sessizce yanlış güne bağlamak,
  /// boş bir sepetten çok daha pahalıya patlar; sunucu siparişi reddettiğinde
  /// müşteri hatanın nereden geldiğini anlayamaz.
  static const int cartSchemaVersion = 2;

  static const String _menuKey = 'bld.cache.menu';
  static const String _menuLocationKey = 'bld.cache.menu.location';
  static const String _menuAtKey = 'bld.cache.menu.at';
  static const String _locationKey = 'bld.cache.location';
  static const String _dailyMenuPrefix = 'bld.cache.gunun-menusu.';
  static const String _calendarKey = 'bld.cache.menu-takvimi';
  static const String _calendarLocationKey = 'bld.cache.menu-takvimi.location';
  static const String _cartKey = 'bld.cart';
  static const String _cartVersionField = 'v';
  static const String _cartPayloadField = 'cart';
  static const String _reminderOnKey = 'bld.bildirim.gunluk.acik';
  static const String _reminderHourKey = 'bld.bildirim.gunluk.saat';
  static const String _reminderMinuteKey = 'bld.bildirim.gunluk.dakika';
  static const String _seenStatusPrefix = 'bld.siparis.gorulen.';
  static const String _errorFingerprintsKey = 'bld.hata.izleri';
  static const String _fingerprintSentField = 'at';
  static const String _fingerprintCountField = 'n';

  /// Kalıcı tutulan en fazla hata parmak izi.
  ///
  /// Yirmi, "bu cihazda son zamanlarda neler bozuldu" sorusunu cevaplamaya
  /// yetiyor. Sınırsız bırakılsaydı defter, hatası çok olan bir cihazda —
  /// yani tam da yerin dar olduğu cihazda — sürekli büyürdü.
  static const int maxErrorFingerprints = 20;
  static const String _dismissedAnnouncementsKey = 'bld.duyuru.kapatilan';

  /// Cihazda tutulan kapatılmış duyuru kimliği sayısının tavanı.
  ///
  /// **NEDEN TAVAN VAR:** duyuru kapatma işareti yalnız burada duruyor ve
  /// hiçbir zaman silinmiyor; sınırsız bırakılsaydı liste uygulamanın ömrü
  /// boyunca büyür, her açılışta okunan bir çöp yığınına dönerdi. Elli kimlik,
  /// sunucunun aynı anda yayında tutabileceği duyuru sayısının kat kat
  /// üstünde: taşan kayıt zaten yayından kalkmış bir duyuruya ait olur ve
  /// düşmesi görünür bir şey değiştirmez.
  static const int dismissedAnnouncementLimit = 50;

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

  // ── Günün menüsü ────────────────────────────────────────────────────────

  /// Bir günün menüsünü saklar ve GEÇMİŞ günleri temizler.
  ///
  /// Her gün ayrı anahtarda: müşteri gün şeridinde ileri geri gezinirken
  /// çevrimdışı kalırsa gezdiği günlerin hepsi elinde kalsın. Tek bir
  /// anahtarda tutsaydık son bakılan gün dışındaki her şey kaybolurdu.
  ///
  /// Budama yazma sırasında yapılıyor: ileri görüş penceresi 30 gün, yani
  /// biriken kayıt sayısı doğal olarak sınırlı — asıl risk sayı değil,
  /// **geçmiş** günlerin kalması. Geçmişe sipariş verilemiyor ve o kayıtlar
  /// bir daha okunmayacak.
  Future<void> writeDailyMenu(int locationId, DailyMenu menu) async {
    await _prefs.setString(
      _dailyMenuKey(locationId, menu.date),
      jsonEncode(menu.toJson()),
    );
    await _pruneDailyMenus(BusinessDate.today());
  }

  /// Kayıtlı günün menüsü. Yoksa, başka vitrine aitse veya bozuksa `null`.
  DailyMenu? readDailyMenu(int locationId, String date) {
    final raw = _prefs.getString(_dailyMenuKey(locationId, date));
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return DailyMenu.fromJson(Map<String, dynamic>.from(decoded));
    } on Object {
      return null;
    }
  }

  /// Menü takvimi. Tek kayıt tutulur: gün şeridi her açılışta aynı geniş
  /// aralığı (bugün → ileri görüş sonu) istiyor, aralık başına kayıt tutmak
  /// aynı veriyi çoğaltmaktan başka bir şey yapmazdı.
  Future<void> writeMenuCalendar(
    int locationId,
    List<MenuCalendarDay> days,
  ) async {
    await _prefs.setString(
      _calendarKey,
      jsonEncode([for (final day in days) day.toJson()]),
    );
    await _prefs.setInt(_calendarLocationKey, locationId);
  }

  /// Kayıtlı takvim; **geçmiş günler ayıklanmış** hâlde döner.
  ///
  /// Ayıklama okuma tarafında: kayıt dün yazılmış olabilir ve içindeki "dün"
  /// bugün artık seçilebilir bir gün değil. Yazarken temizlemek yetmezdi.
  List<MenuCalendarDay>? readMenuCalendar(int locationId, {String? today}) {
    if (_prefs.getInt(_calendarLocationKey) != locationId) return null;

    final raw = _prefs.getString(_calendarKey);
    if (raw == null) return null;

    final from = today ?? BusinessDate.today();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return [
        for (final entry in decoded)
          MenuCalendarDay.fromJson(Map<String, dynamic>.from(entry as Map)),
      ].where((day) => !BusinessDate.isBefore(day.date, from)).toList();
    } on Object {
      return null;
    }
  }

  String _dailyMenuKey(int locationId, String date) =>
      '$_dailyMenuPrefix$locationId.$date';

  Future<void> _pruneDailyMenus(String today) async {
    for (final key in _prefs.getKeys()) {
      if (!key.startsWith(_dailyMenuPrefix)) continue;
      // Anahtarın son parçası gün: `<önek><vitrin>.<YYYY-AA-GG>`.
      final date = key.split('.').last;
      if (BusinessDate.isValid(date) && BusinessDate.isBefore(date, today)) {
        await _prefs.remove(key);
      }
    }
  }

  // ── Sepet ───────────────────────────────────────────────────────────────

  /// Sepeti [cartSchemaVersion] damgasıyla saklar.
  Future<void> writeCart(Object? json) async {
    if (json == null) {
      await _prefs.remove(_cartKey);
      return;
    }
    await _prefs.setString(
      _cartKey,
      jsonEncode({_cartVersionField: cartSchemaVersion, _cartPayloadField: json}),
    );
  }

  /// Kayıtlı sepet. Başka bir şemadan kalan kayıt okunmaz ve SİLİNİR.
  ///
  /// Silme beklenmiyor (`unawaited`): çağıran `Notifier.build()` içinde,
  /// eşzamanlı bir bağlamda. Yazma başarısız olsa bile zarar yok — bir
  /// sonraki okuma sürümü yine tanımaz ve yine `null` döner.
  Map<String, dynamic>? readCart() {
    final raw = _prefs.getString(_cartKey);
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;

      if (decoded[_cartVersionField] != cartSchemaVersion) {
        unawaited(_prefs.remove(_cartKey));
        return null;
      }

      final payload = decoded[_cartPayloadField];
      if (payload is! Map) return null;
      return Map<String, dynamic>.from(payload);
    } on Object {
      return null;
    }
  }

  // ── Bildirim ayarları ───────────────────────────────────────────────────

  /// Günlük menü hatırlatması açık mı? Varsayılan **kapalı**: izin istemeden
  /// bildirim kurmak kullanıcının kararı olmalı.
  bool readDailyReminderEnabled() => _prefs.getBool(_reminderOnKey) ?? false;

  /// Hatırlatma saati (yerel duvar saati). Kayıt yoksa çağıran varsayılanı
  /// (`AppConfig.dailyReminder*`) kullanır.
  ({int hour, int minute})? readDailyReminderTime() {
    final hour = _prefs.getInt(_reminderHourKey);
    final minute = _prefs.getInt(_reminderMinuteKey);
    if (hour == null || minute == null) return null;
    return (hour: hour, minute: minute);
  }

  Future<void> writeDailyReminder({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    await _prefs.setBool(_reminderOnKey, enabled);
    await _prefs.setInt(_reminderHourKey, hour);
    await _prefs.setInt(_reminderMinuteKey, minute);
  }

  // ── Sipariş durumu bildirimi ────────────────────────────────────────────

  /// Bu sipariş için kullanıcıya en son hangi durum bildirildi?
  ///
  /// Yoklama beş saniyede bir çalışıyor; hangi durumun bildirildiğini
  /// hatırlamazsak aynı bildirim her turda yeniden düşerdi.
  String? readNotifiedStatus(int orderId) =>
      _prefs.getString('$_seenStatusPrefix$orderId');

  Future<void> writeNotifiedStatus(int orderId, String status) =>
      _prefs.setString('$_seenStatusPrefix$orderId', status);

  // ── Kapatılan duyurular ─────────────────────────────────────────────────

  /// Kullanıcının kapattığı duyuru kimlikleri; **en eskisi başta**.
  ///
  /// Sıra korunuyor çünkü tavan aşıldığında düşecek olan en eski kayıttır
  /// ([dismissedAnnouncementLimit]); sırasız bir küme hangisinin atılacağını
  /// söyleyemezdi. Okuma tarafı yalnız üyelik soruyor, sıra ona görünmez.
  ///
  /// Bozuk kayıt (sayıya çevrilemeyen giriş) sessizce atlanır: kapatma işareti
  /// bir kolaylık, doğruluk kaynağı değil — bozulduğunda duyuru bir kez daha
  /// görünür, uygulama çökmez.
  List<int> readDismissedAnnouncements() {
    final raw = _prefs.getStringList(_dismissedAnnouncementsKey);
    if (raw == null) return <int>[];
    return [for (final entry in raw) ?int.tryParse(entry)];
  }

  /// [id]'yi kapatılanlara ekler ve **tavana budanmış** güncel listeyi döner.
  ///
  /// Zaten listede olan kimlik sona taşınır: kapatma tekrar edildiğinde o
  /// duyuru en taze işaret olur ve budanma sırasında ilk düşen o olmaz.
  Future<List<int>> writeDismissedAnnouncement(int id) async {
    final next = readDismissedAnnouncements()
      ..remove(id)
      ..add(id);
    final pruned = next.length <= dismissedAnnouncementLimit
        ? next
        : next.sublist(next.length - dismissedAnnouncementLimit);

    await _prefs.setStringList(_dismissedAnnouncementsKey, [
      for (final entry in pruned) '$entry',
    ]);
    return pruned;
  }

  // ── Hata parmak izleri ──────────────────────────────────────────────────

  /// Gönderilmiş hata raporlarının defteri: parmak izi → son gönderim anı ve
  /// toplam görülme sayısı.
  ///
  /// **NEDEN KALICI:** çökme döngüsü korumasının en kritik parçası bu
  /// (`data/crash_reporter.dart`). Açılışta çöken bir hata süreci yeniden
  /// başlatır ve raportörün bellekteki jeton kovasını sıfırlar; koruma
  /// yalnızca bellekte olsaydı kurulu tabandaki her cihaz her açılışta tam
  /// kapasiteyle rapor yollar, durum monitörü kendi müşterilerimiz
  /// tarafından yıkılırdı. Defter diskte olduğu için "bu izi altı saat önce
  /// gönderdim" bilgisi açılışı aşıyor.
  ///
  /// Bozuk kayıtta çökmek yerine boş defter dönülüyor: en kötü sonuç bir
  /// raporun fazladan gitmesi.
  Map<String, ({int lastSentEpoch, int count})> readErrorFingerprints() {
    final raw = _prefs.getString(_errorFingerprintsKey);
    if (raw == null) return {};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};

      final records = <String, ({int lastSentEpoch, int count})>{};
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final at = value[_fingerprintSentField];
        final count = value[_fingerprintCountField];
        if (at is! int || count is! int) continue;
        records['${entry.key}'] = (lastSentEpoch: at, count: count);
      }
      return records;
    } on Object {
      return {};
    }
  }

  /// Defteri yazar; [maxErrorFingerprints] sınırını aşarsa **en eski**
  /// kayıtlar atılır.
  ///
  /// Budama ölçütü "en eski gönderim": soğuma penceresi zaten zamana bağlı,
  /// yani en eski kayıt bir sonraki gönderimde nasılsa serbest kalacak olan
  /// kayıttır. Görülme sayısına göre budamak sık tekrar eden hatayı defterde
  /// tutup nadir olanı atardı — oysa seli üretenler sık olanlar.
  Future<void> writeErrorFingerprints(
    Map<String, ({int lastSentEpoch, int count})> records,
  ) async {
    final entries = records.entries.toList()
      ..sort((a, b) => b.value.lastSentEpoch.compareTo(a.value.lastSentEpoch));

    await _prefs.setString(
      _errorFingerprintsKey,
      jsonEncode({
        for (final entry in entries.take(maxErrorFingerprints))
          entry.key: {
            _fingerprintSentField: entry.value.lastSentEpoch,
            _fingerprintCountField: entry.value.count,
          },
      }),
    );
  }
}
