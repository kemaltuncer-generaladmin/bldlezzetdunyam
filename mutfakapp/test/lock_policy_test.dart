/// Kilit politikası ve KALICILIK — K-21 §2.2 / §5.
///
/// Buradaki asıl soru "kilit uygulanıyor mu" değil, **yeniden başlatmayı
/// atlatıyor mu**. Kilit yalnızca bellekte dursaydı kasayı kapatıp açmak
/// onu aşmaya yeterdi; ağsız bir kasada ilk sağlık turu bir dakika sonra
/// geliyor ve o pencerede uygulama serbest çalışırdı.
///
/// Aynı dosya, sözleşmede olup diske hiç yazılmayan dört alanı da sabitler
/// (`printerCodePage`, `healthSeconds`, `connectionAlarmSeconds`,
/// `alarmSilenceable`). Kod sayfası unutulduğunda kasa derleme değerine
/// dönüyor ve düzeltilene kadar Türkçe harfleri boşluğa çeviren fişler
/// basıyordu.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/data/kitchen_health.dart';
import 'package:mutfakapp/src/data/managed_settings.dart';
import 'package:mutfakapp/src/settings/kds_settings.dart';
import 'package:mutfakapp/src/settings/kds_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bellekte tutan `SharedPreferencesAsync`.
///
/// Gerçek depo testte platform kanalına uzanır ve kanal kurulu olmadığı
/// için her çağrı istisna atar. `implements` + [noSuchMethod]: sınıfın
/// onlarca üyesi var, [KdsSettingsStore] yalnız yedisine dokunuyor.
class FakePreferences implements SharedPreferencesAsync {
  final Map<String, Object?> values = <String, Object?>{};

  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;

  @override
  Future<int?> getInt(String key) async => values[key] as int?;

  @override
  Future<String?> getString(String key) async => values[key] as String?;

  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;

  @override
  Future<void> setInt(String key, int value) async => values[key] = value;

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const KdsSettings varsayilan = KdsSettings(
  soundEnabled: true,
  pollSeconds: 5,
  printerDevicePath: '/dev/thermal0',
  warningAfterMinutes: 10,
  lateAfterMinutes: 20,
);

void main() {
  late FakePreferences prefs;
  late KdsSettingsStore store;

  setUp(() {
    prefs = FakePreferences();
    store = KdsSettingsStore(preferences: prefs);
  });

  group('sunucudan gelen JSON', () {
    test('yedi kilit anahtarı da ayrıştırılır', () {
      final ayarlar = KitchenManagedSettings.fromJson(const <String, Object?>{
        'allow_settings': false,
        'allow_server_change': false,
        'allow_window_controls': false,
        'allow_order_edit': false,
        'allow_manual_reprint': false,
        'allow_sales_control': false,
        'lock_message': 'Yönetim Kontrol Merkezi\'nde.',
      });

      expect(ayarlar.allowSettings, isFalse);
      expect(ayarlar.allowServerChange, isFalse);
      expect(ayarlar.allowWindowControls, isFalse);
      expect(ayarlar.allowOrderEdit, isFalse);
      expect(ayarlar.allowManualReprint, isFalse);
      expect(ayarlar.allowSalesControl, isFalse);
      expect(ayarlar.lockMessage, 'Yönetim Kontrol Merkezi\'nde.');
      expect(ayarlar.isEmpty, isFalse);
    });

    test('gönderilmeyen anahtar `null` kalır — "dokunmadı"', () {
      final ayarlar = KitchenManagedSettings.fromJson(const <String, Object?>{
        'allow_settings': false,
      });

      expect(ayarlar.allowSettings, isFalse);
      expect(ayarlar.allowServerChange, isNull);
      expect(ayarlar.lockMessage, isNull);
    });

    test('boş kilit metni `null` DEĞİL boş dize olarak okunur', () {
      // `null`'a çevrilseydi "dokunmadı" anlamına gelir ve yönetici
      // yazdığı cümleyi bir daha silemezdi.
      final ayarlar = KitchenManagedSettings.fromJson(const <String, Object?>{
        'lock_message': '   ',
      });

      expect(ayarlar.lockMessage, '');
      expect(ayarlar.isEmpty, isFalse);
    });

    test('BİLİNMEYEN anahtar yok sayılır — sözleşme eklemeli', () {
      // Sunucu kasadan yeni bir sürümde olabilir; tanımadığı bir alan
      // yüzünden ayrıştırmanın patlaması, mutfağın tüm yönetilen
      // ayarlarını kaybetmesi demek olurdu.
      final ayarlar = KitchenManagedSettings.fromJson(const <String, Object?>{
        'allow_order_edit': false,
        'allow_time_travel': true,
        'gelecekteki_alan': <String, Object?>{'ic': 1},
      });

      expect(ayarlar.allowOrderEdit, isFalse);
      expect(ayarlar.allowSettings, isNull);
    });

    test('tümüyle boş nesne hiçbir şeyi değiştirmez', () {
      final ayarlar = KitchenManagedSettings.fromJson(
        const <String, Object?>{},
      );

      expect(ayarlar.isEmpty, isTrue);
      expect(applyManagedSettings(varsayilan, ayarlar), varsayilan);
    });
  });

  group('diske yazma — 4 unutulmuş + 7 kilit alanı', () {
    test('on bir alan yazılıp geri okunur', () async {
      final yazilan = varsayilan.copyWith(
        printerCodePage: 29,
        healthSeconds: 120,
        connectionAlarmSeconds: 90,
        alarmSilenceable: false,
        allowSettings: false,
        allowServerChange: false,
        allowWindowControls: false,
        allowOrderEdit: false,
        allowManualReprint: false,
        allowSalesControl: false,
        lockMessage: 'Kilitli. Müdüre haber verin.',
      );

      await store.write(yazilan);
      final okunan = await store.read(varsayilan);

      expect(okunan.printerCodePage, 29);
      expect(okunan.healthSeconds, 120);
      expect(okunan.connectionAlarmSeconds, 90);
      expect(okunan.alarmSilenceable, isFalse);
      expect(okunan.allowSettings, isFalse);
      expect(okunan.allowServerChange, isFalse);
      expect(okunan.allowWindowControls, isFalse);
      expect(okunan.allowOrderEdit, isFalse);
      expect(okunan.allowManualReprint, isFalse);
      expect(okunan.allowSalesControl, isFalse);
      expect(okunan.lockMessage, 'Kilitli. Müdüre haber verin.');
      expect(okunan, yazilan);
    });

    test('anahtar adları yayımlanmış adlardır', () {
      // Anahtar bir kez yayımlandıktan sonra değişmez: değişirse sahadaki
      // kasaların ayarı sessizce varsayılana döner.
      expect(KdsSettingsStore.printerCodePageKey, 'kds_printer_code_page');
      expect(KdsSettingsStore.healthSecondsKey, 'kds_health_seconds');
      expect(
        KdsSettingsStore.connectionAlarmKey,
        'kds_connection_alarm_seconds',
      );
      expect(KdsSettingsStore.alarmSilenceableKey, 'kds_alarm_silenceable');
      expect(KdsSettingsStore.allowSettingsKey, 'kds_allow_settings');
      expect(KdsSettingsStore.allowServerChangeKey, 'kds_allow_server_change');
      expect(
        KdsSettingsStore.allowWindowControlsKey,
        'kds_allow_window_controls',
      );
      expect(KdsSettingsStore.allowOrderEditKey, 'kds_allow_order_edit');
      expect(
        KdsSettingsStore.allowManualReprintKey,
        'kds_allow_manual_reprint',
      );
      expect(KdsSettingsStore.allowSalesControlKey, 'kds_allow_sales_control');
      expect(KdsSettingsStore.lockMessageKey, 'kds_lock_message');
    });

    test('kod sayfası `null` ise anahtar SİLİNİR', () async {
      // `null` "derleme değerini kullan" demek. 0 yazmak, donanıma özgü
      // doğru değerin (sahada 29) üstüne yanlış bir kod sayfası dayatırdı.
      await store.write(varsayilan.copyWith(printerCodePage: 29));
      expect(prefs.values, contains(KdsSettingsStore.printerCodePageKey));

      await store.write(varsayilan);
      expect(
        prefs.values,
        isNot(contains(KdsSettingsStore.printerCodePageKey)),
      );
      expect((await store.read(varsayilan)).printerCodePage, isNull);
    });

    test('boş kilit metni de yazılır', () async {
      await store.write(varsayilan.copyWith(lockMessage: 'Kilitli.'));
      await store.write(varsayilan.copyWith(lockMessage: ''));

      expect(prefs.values[KdsSettingsStore.lockMessageKey], '');
      expect((await store.read(varsayilan)).lockMessage, isEmpty);
    });

    test('hiç yazılmamış disk SERBEST okunur', () async {
      // Sürüm yükselten kasada bu anahtarlar yok. Eksik anahtarın
      // "kilitli" sayılması, mutfağın ayarlara hiç giremediği bir sabah
      // demek olurdu.
      final okunan = await store.read(varsayilan);

      expect(okunan.hasLock, isFalse);
      expect(okunan.lockMessage, isEmpty);
      expect(okunan.alarmSilenceable, isTrue);
      expect(okunan.healthSeconds, KdsSettings.defaultHealthSeconds);
    });

    test('bozuk disk değeri okumada sınırına çekilir', () async {
      prefs.values[KdsSettingsStore.healthSecondsKey] = 99999;
      prefs.values[KdsSettingsStore.printerCodePageKey] = 900;

      final okunan = await store.read(varsayilan);

      expect(okunan.healthSeconds, KdsSettings.maxHealthSeconds);
      expect(okunan.printerCodePage, 255);
    });
  });

  group('ağsız yeniden başlatma', () {
    test('kilit sunucuya sorulmadan geçerlidir', () async {
      // K-21 §5.3'ün asıl gerekçesi: sunucu ilk sağlık turunu
      // `healthSeconds` (varsayılan 60 sn) sonra döner. Kilit diske
      // yazılmasaydı kasa o pencerede serbest açılır ve kilidi aşmak
      // isteyenin tek yapması gereken kasayı kapatıp açmak olurdu.
      final kilitli = applyManagedSettings(
        varsayilan,
        const KitchenManagedSettings(
          allowSettings: false,
          allowWindowControls: false,
          lockMessage: 'Yönetim Kontrol Merkezi\'nde.',
        ),
      );
      await store.write(kilitli);

      // Yeni süreç: yeni depo örneği, sunucu YOK.
      final acilis = await KdsSettingsStore(
        preferences: prefs,
      ).read(varsayilan);

      expect(acilis.allowSettings, isFalse);
      expect(acilis.allowWindowControls, isFalse);
      expect(acilis.lockMessage, 'Yönetim Kontrol Merkezi\'nde.');
      // Yönetici dokunmadıkları serbest kalmalı.
      expect(acilis.allowOrderEdit, isTrue);
    });

    test('kod sayfası ilk fişten ÖNCE hazırdır', () async {
      // Şikâyetin kaynağı: kasa açılışta derleme değerine dönüyor,
      // sunucu bir tur sonra düzeltiyor, aradaki fişlerde Türkçe harfler
      // boşluğa dönüyordu.
      await store.write(
        applyManagedSettings(
          varsayilan,
          const KitchenManagedSettings(printerCodePage: 29),
        ),
      );

      expect((await store.read(varsayilan)).printerCodePage, 29);
    });
  });
}
