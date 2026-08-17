/// Yakalanmamış hataların sunucuya boşaltılması — `POST /client-errors`.
///
/// ## ASIL İŞ ÇÖKME DÖNGÜSÜ KORUMASI
///
/// Hatayı göndermek kolay kısım. Zor kısım, **göndermemeyi bilmek**. Bir
/// istemci hataya girdiğinde tek bir hata üretmez: bozuk bir çizim döngüsü
/// saniyede onlarca `FlutterError` doğurur, çevrimdışı bir cihaz her yoklamada
/// aynı ağ hatasını atar ve — en kötüsü — **açılışta çöken** bir yapı süreci
/// yeniden başlatır. Sonuncusu bellekte tutulan her sayacı sıfırlar; koruma
/// yalnızca bellekte olsaydı kurulu tabandaki her cihaz, her açılışta yeniden
/// tam kapasiteyle rapor yollar ve durum monitörünü kendi müşterilerimizle
/// DDoS'a çevirirdik. Sunucu tarafındaki oran sınırı (`bld-hata`, 60
/// istek/dakika/IP) bunu durdurmaz; yalnızca gerçek hataları da düşürür.
///
/// Dört kemer var, hepsi ayrı bir başarısızlığa karşı:
///
/// | Kemer | Neye karşı |
/// |---|---|
/// | Tekilleştirme + soğuma (kalıcı) | aynı hatanın tekrarı, açılış çökmesi |
/// | Jeton kovası (5 / oturum, ≥10 sn) | patlamalı hata seli |
/// | Örnekleme (`CLIENT_ERROR_SAMPLE_RATE`) | kurulu tabanın toplam hacmi |
/// | Tek bekleyen rapor | çevrimdışıyken sınırsız kuyruk |
///
/// ## Parmak izi yeniden yazılmadı
///
/// `bld_core`'daki [fingerprint] kullanılıyor ve web sitesindeki TypeScript
/// karşılığı (`website/lib/report-error.ts`) birebir aynı tarifi uyguluyor.
/// İkisi ayrışırsa "web'de tek satır, mobilde altmış satır" gibi kıyaslanamaz
/// iki tablo çıkar.
library;

import 'dart:async';
import 'dart:math';

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:flutter/foundation.dart';

import 'local_cache.dart';

/// Oturum başına gönderilebilecek rapor sayısı.
///
/// Beş, "bir ekranda birden çok şey bozulmuş" durumunu görmeye yetiyor;
/// altıncı rapor teşhise yeni bir şey eklemiyor, çünkü aynı oturumda üretilen
/// hatalar neredeyse her zaman aynı kökten geliyor.
const int _bucketCapacity = 5;

/// İki rapor arasındaki en kısa süre.
const Duration _minInterval = Duration(seconds: 10);

/// Aynı parmak izinin açılışlar arası soğuması.
///
/// Altı saat: aynı gün içinde iki vardiya arasına düşecek kadar uzun, bir
/// düzeltme yayınlandığında sonucu görmeyi geciktirmeyecek kadar kısa.
const Duration _cooldown = Duration(hours: 6);

/// Parmak izine giren yığın çerçevesi sayısı — Dart/TypeScript ortak tarifi.
const int _frameCount = 3;

/// Örnekleme oranının ham hâli. `--dart-define=CLIENT_ERROR_SAMPLE_RATE=0.1`.
///
/// Dart'ta `double.fromEnvironment` yok — derleme zamanı ortamından yalnızca
/// `bool`, `int` ve `String` okunabiliyor. Bu yüzden değer metin olarak alınıp
/// aşağıda bir kez çözümleniyor.
const String _sampleRateSetting = String.fromEnvironment(
  'CLIENT_ERROR_SAMPLE_RATE',
  defaultValue: '1',
);

/// Örnekleme oranı (0–1).
///
/// Varsayılan 1: teşhis bilgisini kendiliğinden kısmıyoruz. Kısma kararı
/// sahada, monitör hacmine bakılarak verilir ve yeniden derleme gerektirir —
/// çalışma anında değiştirilebilseydi bir sonraki adım onu uzaktan kapatmak
/// olurdu ve hata görünürlüğü uzaktan kapatılabilir bir şey olmamalı.
///
/// Okunamayan ya da aralık dışı bir tanım **1'e** düşer, 0'a değil: elle
/// yazılan bir `--dart-define`'daki harf hatası hata görünürlüğünü sessizce
/// kapatmamalı. Yanlış tanımın cezası "beklenenden çok rapor" olsun, "hiç
/// rapor yok" değil.
final double _defaultSampleRate = _parseSampleRate(_sampleRateSetting);

double _parseSampleRate(String raw) {
  final value = double.tryParse(raw);
  if (value == null || value.isNaN || value < 0 || value > 1) return 1;
  return value;
}

/// Yakalanmamış hataları raporlayan tek nokta.
class CrashReporter {
  CrashReporter({
    required this._cache,
    required this._send,
    required this._isOffline,
    double? sampleRate,
    Random? random,
    DateTime Function()? clock,
  }) : _sampleRate = sampleRate ?? _defaultSampleRate,
       _random = random ?? Random(),
       _clock = clock ?? DateTime.now;

  final LocalCache _cache;
  final Future<void> Function(ClientErrorReport report) _send;
  final bool Function() _isOffline;
  final double _sampleRate;
  final Random _random;
  final DateTime Function() _clock;

  int _tokensLeft = _bucketCapacity;
  DateTime? _lastSentAt;

  /// Çevrimdışıyken bekleyen **tek** rapor.
  ///
  /// Kuyruk YOK. Çevrimdışı bir cihazda döngüye girmiş bir ekran, sınırsız
  /// kuyruğu dakikalar içinde şişirir ve bağlantı geldiği anda hepsini birden
  /// yollar — yani kuyruk, korumaya çalıştığımız seli erteleyip büyüterek
  /// geri veriyor. Elde tutulacak tek şey en son hata; öncekiler zaten aynı
  /// parmak izini taşıyor ve sayaçları kalıcı deftere yazıldı.
  ClientErrorReport? _pending;

  /// Hatayı bildirir. **Asla fırlatmaz ve beklenmez.**
  ///
  /// Dönüş tipi `void`: raportör kendini raporlamamalı. Buradan çıkan bir
  /// istisna `FlutterError.onError` içinde yakalanır, o da yeniden buraya
  /// gelir ve döngü kapanır. Gövdenin tamamı `try/catch` içinde.
  void report(
    Object error,
    StackTrace? stack, {
    String kind = ClientErrorKind.unhandled,
    String? route,
    Map<String, dynamic>? context,
  }) {
    try {
      unawaited(
        _report(error, stack, kind: kind, route: route, context: context),
      );
    } on Object {
      // Sessiz. Rapor kaybı kabul edilmiş bir kayıptır; ikinci bir hata değil.
    }
  }

  Future<void> _report(
    Object error,
    StackTrace? stack, {
    required String kind,
    String? route,
    Map<String, dynamic>? context,
  }) async {
    try {
      final now = _clock();
      final message = error.toString();
      final trace = stack?.toString();
      final print = fingerprint(kind, message, _framesOf(trace));

      final records = _cache.readErrorFingerprints();
      final seen = records[print];
      final count = (seen?.count ?? 0) + 1;

      // Soğuma: aynı iz altı saat içinde ikinci kez gitmez. Sayaç yine de
      // artıyor ve bir sonraki gerçek gönderimde bağlama yazılıyor.
      if (seen != null &&
          now.millisecondsSinceEpoch - seen.lastSentEpoch <
              _cooldown.inMilliseconds) {
        records[print] = (lastSentEpoch: seen.lastSentEpoch, count: count);
        await _cache.writeErrorFingerprints(records);
        return;
      }

      // Örnekleme kovadan ÖNCE: kovayı örneklenmeyecek bir raporla harcamak,
      // aynı oturumda gelecek gerçek bir raporu düşürmek olurdu.
      if (_sampleRate < 1 && _random.nextDouble() >= _sampleRate) return;

      // Jeton kovası. Dolduğunda SESSİZCE DÜŞÜLÜR.
      if (_tokensLeft <= 0) return;
      final last = _lastSentAt;
      if (last != null && now.difference(last) < _minInterval) return;

      _tokensLeft -= 1;
      _lastSentAt = now;
      records[print] = (
        lastSentEpoch: now.millisecondsSinceEpoch,
        count: count,
      );
      await _cache.writeErrorFingerprints(records);

      final report = ClientErrorReport(
        message: message,
        kind: kind,
        stack: trace,
        route: _cleanRoute(route),
        occurredAt: now.toUtc(),
        device: _device(),
        context: {
          ...?context,
          // Bastırılan tekrarların sayısı. Parmak izinin KENDİSİ gövdeye
          // konmuyor: sözleşmede karşılığı yok ve sunucu kendi birleştirme
          // anahtarını ayrı hesaplıyor (`docs/control/monitor.md`).
          'occurrence': count,
        },
      );

      // Çevrimdışıysa tele hiç çıkmıyoruz: `BldApi` hatayı yutuyor, yani
      // başarısız bir denemeyi fark etmenin başka yolu yok.
      if (_isOffline()) {
        _pending = report;
        return;
      }

      final waiting = _pending;
      _pending = null;
      if (waiting != null) await _send(waiting);
      await _send(report);
    } on Object {
      // RAPORTÖR KENDİNİ RAPORLAMAZ.
    }
  }

  /// Yığın izinin ilk [_frameCount] satırı.
  static List<String> _framesOf(String? stack) {
    if (stack == null) return const [];
    return stack
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(_frameCount)
        .toList();
  }

  /// Rotadan sorgu dizesini atar.
  ///
  /// Sözleşme bunu açıkça istiyor: adres parametreleri zaman zaman kişisel
  /// veri taşır ve hata kaydı onları saklamak için yanlış yerdir.
  static String? _cleanRoute(String? route) {
    if (route == null || route.isEmpty) return null;
    final cut = route.split(RegExp('[?#]')).first;
    return cut.isEmpty ? null : cut;
  }

  /// Cihaz özeti — serbest metin.
  ///
  /// `dart:io` KULLANILMIYOR: uygulama web hedefinde de derlenebiliyor
  /// (`AppConfig.apiBaseUrl` `kIsWeb` dallanması) ve `dart:io` içe aktarımı o
  /// derlemeyi kırar. `defaultTargetPlatform` her hedefte çalışıyor; işletim
  /// sistemi sürümü için ek bir eklenti almak, bir teşhis satırı uğruna
  /// bağımlılık eklemek olurdu.
  static String _device() => kIsWeb ? 'web' : defaultTargetPlatform.name;
}
