/// `POST /api/kitchen/health` — çift yönlü sağlık bildirimi.
///
/// Cihaz kendi bilebildiğini gönderir (yazıcı erişilebilir mi, kuyrukta kaç
/// fiş var), sunucu cihazın bilemeyeceğini döner: **bugün kaç sipariş girdi**.
/// Mutfak listesi yalnızca aktif siparişleri taşır; teslim edilenler düşer ve
/// günlük toplam yerelde hesaplanamaz.
///
/// `heartbeat` ile karıştırılmamalı: o yalnızca "cihaz ayakta" der. İkisi de
/// kalır ve ikisi de ayrı zamanlayıcıda koşar.
///
/// > **NEDEN BURADA, `packages/api_client`'ta DEĞİL:** uç sözleşmeye yeni
/// > eklendi ve `packages/` bu görevin kapsamı dışında. İstemci geçici olarak
/// > `dart:io` ile yazıldı — `dio` mutfakapp'in doğrudan bağımlılığı değil ve
/// > öyle davranmak `depend_on_referenced_packages` ihlalidir. Uç
/// > `KitchenService`'e taşındığında bu dosyanın yalnızca [KitchenHealthApi]
/// > uygulaması değişir; monitör ve arayüz aynen kalır.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bld_api_client/bld_api_client.dart';

/// Cihazın sunucuya bildirdiği durum.
///
/// Değerlerin **gerçek** olması şart: sabit `true` göndermek göstergeyi
/// yalancı yapar ve gösterge yalan söylüyorsa hiç olmaması daha iyidir.
class KitchenHealthReport {
  const KitchenHealthReport({
    required this.printerOk,
    required this.printQueuePending,
    required this.printQueueFailed,
    this.appVersion,
    this.commandResults = const <KitchenCommandResult>[],
  });

  final bool printerOk;
  final int printQueuePending;
  final int printQueueFailed;
  final String? appVersion;

  /// Bir önceki turda teslim alınan komutların sonuçları.
  final List<KitchenCommandResult> commandResults;

  Map<String, Object?> toJson() => <String, Object?>{
    'printer_ok': printerOk,
    // Sunucu `min:0` istiyor; negatif bir sayacın buraya kadar gelmesi bir
    // hata olurdu ama isteği 422 ile geri çevirtmesine gerek yok.
    'print_queue_pending': printQueuePending < 0 ? 0 : printQueuePending,
    'print_queue_failed': printQueueFailed < 0 ? 0 : printQueueFailed,
    if (appVersion != null) 'app_version': appVersion,
    if (commandResults.isNotEmpty)
      'command_results': commandResults.map((r) => r.toJson()).toList(),
  };
}

/// Sunucudan gelen, **yöneticinin panelden yönettiği** kasa ayarları.
///
/// Alanların `null` olması "yönetici dokunmadı" demektir; o alanda kasa
/// kendi derleme varsayılanını kullanır. Sunucudan varsayılan dayatmak,
/// yazıcı yolu gibi makineye özgü bir alanda fiş basımını durdururdu.
class KitchenManagedSettings {
  const KitchenManagedSettings({
    this.pollSeconds,
    this.soundEnabled,
    this.warningAfterMinutes,
    this.lateAfterMinutes,
    this.printerDevicePath,
    this.printerCodePage,
    this.healthSeconds,
    this.connectionAlarmSeconds,
    this.alarmSilenceable,
    this.volumePercent,
    this.audioSink,
    this.ttsEnabled,
    this.ttsRatePercent,
    this.alarmRepeatSeconds,
    this.alarmMaxRepeats,
    this.touchMode,
    this.allowSettings,
    this.allowServerChange,
    this.allowWindowControls,
    this.allowOrderEdit,
    this.allowManualReprint,
    this.allowSalesControl,
    this.lockMessage,
  });

  static const KitchenManagedSettings empty = KitchenManagedSettings();

  final int? pollSeconds;
  final bool? soundEnabled;
  final int? warningAfterMinutes;
  final int? lateAfterMinutes;
  final String? printerDevicePath;
  final int? printerCodePage;
  final int? healthSeconds;
  final int? connectionAlarmSeconds;
  final bool? alarmSilenceable;

  /// Uygulama içi ses seviyesi (0–100).
  final int? volumePercent;

  /// Çıkış cihazı (PipeWire/PulseAudio sink adı).
  final String? audioSink;

  final bool? ttsEnabled;
  final int? ttsRatePercent;
  final int? alarmRepeatSeconds;
  final int? alarmMaxRepeats;

  /// Dokunmatik kip — yönetici uzaktan açabilsin diye burada (K-10).
  final bool? touchMode;

  // ── Kilit politikası (K-21 §2.2) ────────────────────────────────────────
  //
  // Hepsi nullable ve `null` = "yönetici dokunmadı" = kasanın bugünkü
  // davranışı, yani SERBEST. `false` gerçek bir değerdir ve kilitler.
  // Bu ayrım olmasaydı alanın eklenmesi tüm kasaları kilitlerdi.

  /// Ayarlar ekranı açılabilir mi?
  final bool? allowSettings;

  /// Sunucu adresi değişimi + cihaz eşlemesi sıfırlama serbest mi?
  final bool? allowServerChange;

  /// Tam ekrandan çıkma / küçültme serbest mi?
  final bool? allowWindowControls;

  /// Kasadan sipariş düzenleme (revizyon) serbest mi?
  final bool? allowOrderEdit;

  /// Elle fiş yeniden basma serbest mi?
  final bool? allowManualReprint;

  /// Satış şalteri + "bugün tükendi" serbest mi?
  final bool? allowSalesControl;

  /// Kilitli eyleme basınca gösterilecek metin.
  ///
  /// `audio_sink` ile aynı istisna: BOŞ DİZE gerçek bir değerdir ve
  /// "özel metin yok, genel metne dön" demektir. `null` "dokunmadı"
  /// anlamına ayrılmış olduğundan, yöneticinin yazdığı cümleyi geri
  /// almasının başka yolu yoktur.
  final String? lockMessage;

  bool get isEmpty =>
      pollSeconds == null &&
      soundEnabled == null &&
      warningAfterMinutes == null &&
      lateAfterMinutes == null &&
      printerDevicePath == null &&
      printerCodePage == null &&
      healthSeconds == null &&
      connectionAlarmSeconds == null &&
      alarmSilenceable == null &&
      volumePercent == null &&
      audioSink == null &&
      ttsEnabled == null &&
      ttsRatePercent == null &&
      alarmRepeatSeconds == null &&
      alarmMaxRepeats == null &&
      touchMode == null &&
      allowSettings == null &&
      allowServerChange == null &&
      allowWindowControls == null &&
      allowOrderEdit == null &&
      allowManualReprint == null &&
      allowSalesControl == null &&
      lockMessage == null;

  factory KitchenManagedSettings.fromJson(Map<String, Object?> json) =>
      KitchenManagedSettings(
        pollSeconds: _asIntOrNull(json['poll_seconds']),
        soundEnabled: _asBoolOrNull(json['sound_enabled']),
        warningAfterMinutes: _asIntOrNull(json['warning_after_minutes']),
        lateAfterMinutes: _asIntOrNull(json['late_after_minutes']),
        printerDevicePath: _asStringOrNull(json['printer_device_path']),
        printerCodePage: _asIntOrNull(json['printer_code_page']),
        healthSeconds: _asIntOrNull(json['health_seconds']),
        connectionAlarmSeconds: _asIntOrNull(json['connection_alarm_seconds']),
        alarmSilenceable: _asBoolOrNull(json['alarm_silenceable']),
        volumePercent: _asIntOrNull(json['volume_percent']),
        // DAVRANIŞ DEĞİŞİKLİĞİ DEĞİL: sözleşme ve `managed_settings.dart`
        // başlığı baştan beri "boş dize = varsayılan çıkışa dön" diyordu,
        // ama burada `_asStringOrNull` boş dizeyi `null`'a çeviriyor ve
        // `null` "yönetici dokunmadı" demek olduğu için o emir tele hiç
        // çıkmıyordu. Vaat edilen davranış nihayet gerçekleşiyor.
        audioSink: _asTextOrNull(json['audio_sink']),
        ttsEnabled: _asBoolOrNull(json['tts_enabled']),
        ttsRatePercent: _asIntOrNull(json['tts_rate_percent']),
        alarmRepeatSeconds: _asIntOrNull(json['alarm_repeat_seconds']),
        alarmMaxRepeats: _asIntOrNull(json['alarm_max_repeats']),
        touchMode: _asBoolOrNull(json['touch_mode']),
        allowSettings: _asBoolOrNull(json['allow_settings']),
        allowServerChange: _asBoolOrNull(json['allow_server_change']),
        allowWindowControls: _asBoolOrNull(json['allow_window_controls']),
        allowOrderEdit: _asBoolOrNull(json['allow_order_edit']),
        allowManualReprint: _asBoolOrNull(json['allow_manual_reprint']),
        allowSalesControl: _asBoolOrNull(json['allow_sales_control']),
        lockMessage: _asTextOrNull(json['lock_message']),
      );
  // Bilinmeyen anahtarlar okunmaz ve hata da vermez: sözleşme EKLEMELİ,
  // sunucu kasadan yeni sürümde olabilir (`docs/03` §1.4).

  @override
  bool operator ==(Object other) =>
      other is KitchenManagedSettings &&
      other.pollSeconds == pollSeconds &&
      other.soundEnabled == soundEnabled &&
      other.warningAfterMinutes == warningAfterMinutes &&
      other.lateAfterMinutes == lateAfterMinutes &&
      other.printerDevicePath == printerDevicePath &&
      other.printerCodePage == printerCodePage &&
      other.healthSeconds == healthSeconds &&
      other.connectionAlarmSeconds == connectionAlarmSeconds &&
      other.alarmSilenceable == alarmSilenceable &&
      other.volumePercent == volumePercent &&
      other.audioSink == audioSink &&
      other.ttsEnabled == ttsEnabled &&
      other.ttsRatePercent == ttsRatePercent &&
      other.alarmRepeatSeconds == alarmRepeatSeconds &&
      other.alarmMaxRepeats == alarmMaxRepeats &&
      other.touchMode == touchMode &&
      other.allowSettings == allowSettings &&
      other.allowServerChange == allowServerChange &&
      other.allowWindowControls == allowWindowControls &&
      other.allowOrderEdit == allowOrderEdit &&
      other.allowManualReprint == allowManualReprint &&
      other.allowSalesControl == allowSalesControl &&
      other.lockMessage == lockMessage;

  // `Object.hash` en fazla 20 bağımsız değişken alıyor; sözleşmedeki 23
  // anahtar buna sığmıyor, bu yüzden `hashAll`.
  @override
  int get hashCode => Object.hashAll(<Object?>[
    pollSeconds,
    soundEnabled,
    warningAfterMinutes,
    lateAfterMinutes,
    printerDevicePath,
    printerCodePage,
    healthSeconds,
    connectionAlarmSeconds,
    alarmSilenceable,
    volumePercent,
    audioSink,
    ttsEnabled,
    ttsRatePercent,
    alarmRepeatSeconds,
    alarmMaxRepeats,
    touchMode,
    allowSettings,
    allowServerChange,
    allowWindowControls,
    allowOrderEdit,
    allowManualReprint,
    allowSalesControl,
    lockMessage,
  ]);
}

/// Sunucudan gelen tek seferlik komut.
class KitchenCommand {
  const KitchenCommand({
    required this.id,
    required this.command,
    this.payload = const <String, Object?>{},
  });

  static const String testReceipt = 'test_receipt';
  static const String reprint = 'reprint';
  static const String clearFailed = 'clear_failed';
  static const String silenceAlarm = 'silence_alarm';
  static const String restart = 'restart';

  final int id;
  final String command;
  final Map<String, Object?> payload;

  factory KitchenCommand.fromJson(Map<String, Object?> json) => KitchenCommand(
    id: _asInt(json['id']),
    command: '${json['command']}',
    payload: json['payload'] is Map
        ? Map<String, Object?>.from(json['payload']! as Map)
        : const <String, Object?>{},
  );
}

/// Bir komutun çalıştırılma sonucu.
class KitchenCommandResult {
  const KitchenCommandResult({
    required this.id,
    required this.ok,
    this.message,
  });

  final int id;
  final bool ok;
  final String? message;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'ok': ok,
    if (message != null) 'message': message,
  };
}

int? _asIntOrNull(Object? v) => switch (v) {
  final int x => x,
  final num x => x.toInt(),
  final String x => int.tryParse(x),
  _ => null,
};

bool? _asBoolOrNull(Object? v) => switch (v) {
  final bool x => x,
  1 => true,
  0 => false,
  _ => null,
};

String? _asStringOrNull(Object? v) {
  if (v is! String) return null;
  final trimmed = v.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// BOŞ DİZEYİ KORUYAN dize okuyucu.
///
/// [_asStringOrNull] boş dizeyi `null`'a çeviriyor ve `null` bu modelde
/// "yönetici dokunmadı" demek. Boş dizenin kendisi bir emir olduğu
/// alanlarda — `audio_sink` ("varsayılan çıkışa dön") ve `lock_message`
/// ("özel metni kaldır") — o çevrim emri yutar ve yönetici seçimini geri
/// alamaz. Anahtar hiç gelmediğinde değer `null` kalır, yani "dokunulmadı"
/// ayrımı bozulmaz.
///
/// `printer_device_path` bilerek [_asStringOrNull] kullanmaya devam ediyor:
/// orada boş dize bir emir değil, bozuk bir değerdir.
String? _asTextOrNull(Object? v) => v is String ? v.trim() : null;

int _asInt(Object? v) => _asIntOrNull(v) ?? 0;

/// Sunucunun döndüğü durum.
class KitchenHealthStatus {
  const KitchenHealthStatus({
    required this.serverTime,
    required this.ordersToday,
    required this.ordersActive,
    this.settings = KitchenManagedSettings.empty,
    this.commands = const <KitchenCommand>[],
  });

  /// Sunucu saati (UTC).
  final DateTime serverTime;

  /// Bugün girilen sipariş sayısı — **iptaller hariç**, gün sınırı
  /// Europe/Istanbul.
  final int ordersToday;

  /// Sunucudaki aktif sipariş sayısı.
  final int ordersActive;

  /// Yöneticinin panelden yönettiği ayarlar.
  final KitchenManagedSettings settings;

  /// Çalıştırılacak tek seferlik komutlar.
  final List<KitchenCommand> commands;

  factory KitchenHealthStatus.fromJson(Map<String, Object?> json) =>
      KitchenHealthStatus(
        serverTime:
            DateTime.tryParse('${json['server_time']}')?.toUtc() ??
            DateTime.now().toUtc(),
        ordersToday: _asInt(json['orders_today']),
        ordersActive: _asInt(json['orders_active']),
        settings: json['settings'] is Map
            ? KitchenManagedSettings.fromJson(
                Map<String, Object?>.from(json['settings']! as Map),
              )
            : KitchenManagedSettings.empty,
        commands: json['commands'] is List
            ? (json['commands']! as List)
                  .whereType<Map<Object?, Object?>>()
                  .map(
                    (c) =>
                        KitchenCommand.fromJson(Map<String, Object?>.from(c)),
                  )
                  .toList()
            : const <KitchenCommand>[],
      );

  @override
  bool operator ==(Object other) =>
      other is KitchenHealthStatus &&
      other.serverTime == serverTime &&
      other.ordersToday == ordersToday &&
      other.ordersActive == ordersActive;

  @override
  int get hashCode => Object.hash(serverTime, ordersToday, ordersActive);

  @override
  String toString() =>
      'KitchenHealthStatus(today: $ordersToday, active: $ordersActive)';
}

/// Sağlık ucunun soyutlaması. Testte sahtelenir.
abstract interface class KitchenHealthApi {
  Future<KitchenHealthStatus> report(KitchenHealthReport report);
}

/// `dart:io` ile yazılmış istemci.
class HttpKitchenHealthApi implements KitchenHealthApi {
  HttpKitchenHealthApi({
    required this.baseUrl,
    required this.appId,
    required this.appVersion,
    required Future<String?> Function() readToken,
    HttpClient? client,
    this.timeout = const Duration(seconds: 10),
  }) : _readToken = readToken,
       _client = client ?? (HttpClient()..connectionTimeout = timeout);

  /// `/api` dahil taban adres.
  final String baseUrl;
  final String appId;
  final String appVersion;
  final Duration timeout;

  final Future<String?> Function() _readToken;
  final HttpClient _client;

  void close() => _client.close(force: true);

  @override
  Future<KitchenHealthStatus> report(KitchenHealthReport report) async {
    final uri = Uri.parse('$baseUrl/kitchen/health');

    try {
      final request = await _client.postUrl(uri).timeout(timeout);
      request.headers
        ..contentType = ContentType('application', 'json', charset: 'utf-8')
        // Sözleşmenin zorunlu başlıkları (`docs/03` §1.1).
        ..set('X-App-Id', appId)
        ..set('X-App-Version', appVersion)
        ..set('Accept-Language', 'tr');

      final token = await _readToken();
      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }

      request.write(jsonEncode(report.toJson()));
      final response = await request.close().timeout(timeout);
      final body = await utf8.decoder.bind(response).join().timeout(timeout);

      final decoded = body.isEmpty ? null : jsonDecode(body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException.fromResponse(decoded, response.statusCode);
      }
      if (decoded is! Map) {
        throw const ApiException(
          code: ApiErrorCode.unknown,
          message: 'Sunucu beklenmeyen bir yanıt döndü.',
        );
      }

      return KitchenHealthStatus.fromJson(Map<String, Object?>.from(decoded));
    } on ApiException {
      rethrow;
    } on Object catch (error) {
      // Soket hatası, DNS, zaman aşımı, bozuk JSON — hepsi çağıran için aynı:
      // sunucuya ulaşılamadı.
      throw ApiException.network('$error');
    }
  }
}

/// Sağlık göstergesinin arayüze verdiği durum.
class KitchenHealthState {
  const KitchenHealthState({
    this.status,
    this.lastSuccessAt,
    this.reachable = false,
    this.everTried = false,
  });

  static const KitchenHealthState initial = KitchenHealthState();

  /// Sunucudan gelen son sayılar. Bağlantı koptuysa **eskir ama silinmez**:
  /// "bugün 12 sipariş (3 dk önce)" bilgisi, hiç sayı görmemekten iyidir.
  final KitchenHealthStatus? status;

  /// Son başarılı bildirim anı (UTC).
  final DateTime? lastSuccessAt;

  /// Son deneme başarılı mıydı?
  final bool reachable;

  /// Hiç denendi mi? Açılışta "sunucu yok" demeden önce bir deneme beklenir.
  final bool everTried;

  KitchenHealthState copyWith({
    KitchenHealthStatus? status,
    DateTime? lastSuccessAt,
    bool? reachable,
    bool? everTried,
  }) => KitchenHealthState(
    status: status ?? this.status,
    lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
    reachable: reachable ?? this.reachable,
    everTried: everTried ?? this.everTried,
  );

  @override
  bool operator ==(Object other) =>
      other is KitchenHealthState &&
      other.status == status &&
      other.lastSuccessAt == lastSuccessAt &&
      other.reachable == reachable &&
      other.everTried == everTried;

  @override
  int get hashCode => Object.hash(status, lastSuccessAt, reachable, everTried);
}

/// Sağlık bildirimini yapan ve sonucu durumda tutan saf mantık.
///
/// Zamanlayıcı burada DEĞİL: [poll] dışarıdan çağrılır, böylece test sahte
/// saat ya da `FakeAsync` kurmadan davranışı doğrulayabilir.
class KitchenHealthMonitor {
  KitchenHealthMonitor({
    required KitchenHealthApi api,
    required Future<KitchenHealthReport> Function() collect,
    DateTime Function()? clock,
  }) : _api = api,
       _collect = collect,
       _clock = clock ?? (() => DateTime.now().toUtc());

  final KitchenHealthApi _api;

  /// Toplayıcı ASENKRON.
  ///
  /// Yazıcı durumu önbellekten değil, cihazın kendisinden okunmalı; bu da
  /// bir dosya sistemi çağrısı demek. Senkron bir imza, çağıranı önbelleğe
  /// bakmaya zorluyordu ve önbellek açılışta boştu — sonuç, her açılışta
  /// "yazıcı arızalı" diye yalan bildirim.
  final Future<KitchenHealthReport> Function() _collect;
  final DateTime Function() _clock;

  KitchenHealthState _state = KitchenHealthState.initial;

  KitchenHealthState get state => _state;

  /// Bir bildirim gönderir ve durumu günceller.
  ///
  /// Hata YUKARI ATILMAZ. Sağlık bildirimi bir yan işlevdir; başarısızlığı
  /// mutfağın sipariş görmesini engellememeli. Başarısızlığın kendisi zaten
  /// bilgidir: "sunucu" göstergesi kırmızıya döner ve son başarılı iletişimin
  /// üzerinden geçen süre görünür kalır.
  Future<KitchenHealthState> poll() async {
    try {
      final status = await _api.report(await _collect());
      _state = KitchenHealthState(
        status: status,
        lastSuccessAt: _clock(),
        reachable: true,
        everTried: true,
      );
    } on Object {
      _state = _state.copyWith(reachable: false, everTried: true);
    }
    return _state;
  }
}
