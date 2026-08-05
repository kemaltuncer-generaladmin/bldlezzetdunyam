/// Sunucuya ulaşılamadığında çalan uyarı.
///
/// NEDEN GEREKLİ: bağlantı koptuğunda mutfak **kör** kalır. Ekrandaki liste
/// son bilinen hâlini gösterir ve doğru görünür; yeni siparişler hiç
/// gelmez. Sessiz kalırsa kimse fark etmez — en tehlikeli arıza türü,
/// hiçbir şeyin bozuk görünmediği arızadır.
///
/// YENİ SİPARİŞ ALARMINDAN İKİ FARKI VAR, ikisi de bilinçli:
///
/// 1. **Sesi farklıdır** (`baglanti_yok.wav`, alçalan iki ton). Aynı sesi
///    kullansaydık personel hangisinin çaldığını ayırt edemez, yeni sipariş
///    sanıp ekrana koşar ve orada bir şey bulamazdı.
///
/// 2. **Kesintisiz değil, ARALIKLI çalar.** Yeni sipariş alarmı onaylanana
///    kadar susmaz çünkü personel onu bir tuşla çözebilir. Bağlantı
///    kopmasını personel çözemez; ağ gelene kadar kesintisiz ses çalmak,
///    yapabilecekleri bir şey olmadığı hâlde onları cezalandırmaktır ve
///    sonu hoparlörün fişini çekmektir. Aralıklı uyarı fark edilir kalır,
///    dayanılmaz olmaz.
library;

import 'dart:async';

import 'alarm_player.dart';

/// Bağlantı uyarı sesinin varlık yolu.
const String connectionAlarmAssetPath = 'assets/sounds/baglanti_yok.wav';

/// İki uyarı arasındaki süre.
///
/// 45 saniye: geçici bir ağ hıçkırığı (tek kaçırılmış istek) uyarıya hiç
/// dönüşmeden geçer, gerçek bir kesinti ise vardiya boyunca unutulmaz.
const Duration connectionAlarmInterval = Duration(seconds: 45);

/// Bağlantı uyarısının dışarıdan görünen durumu.
class ConnectionAlarmState {
  const ConnectionAlarmState({
    required this.disconnected,
    required this.silenced,
    required this.muted,
  });

  static const ConnectionAlarmState idle = ConnectionAlarmState(
    disconnected: false,
    silenced: false,
    muted: false,
  );

  /// Sunucuya ulaşılamıyor mu?
  final bool disconnected;

  /// Kopukluk sürüyor ama personel sesi susturdu.
  final bool silenced;

  /// Ses hiç çıkmıyor: ayardan kapalı ya da kasada oynatıcı yok.
  final bool muted;

  /// Kopukken hiç ses çıkmıyor mu? Uyarı şeridinin koşulu.
  bool get silentWhileDisconnected => disconnected && muted;

  @override
  bool operator ==(Object other) =>
      other is ConnectionAlarmState &&
      other.disconnected == disconnected &&
      other.silenced == silenced &&
      other.muted == muted;

  @override
  int get hashCode => Object.hash(disconnected, silenced, muted);

  @override
  String toString() =>
      'ConnectionAlarmState(disconnected: $disconnected, '
      'silenced: $silenced, muted: $muted)';
}

/// Bağlantı durumunu aralıklı uyarıya çeviren denetleyici.
class ConnectionAlarm {
  ConnectionAlarm(
    this._player, {
    this.interval = connectionAlarmInterval,
    Timer Function(Duration, void Function(Timer))? scheduler,
  }) : _schedule = scheduler ?? Timer.periodic;

  final AlarmPlayer _player;
  final Duration interval;
  final Timer Function(Duration, void Function(Timer)) _schedule;

  Timer? _timer;
  bool _disconnected = false;
  bool _silenced = false;

  ConnectionAlarmState get state => ConnectionAlarmState(
    disconnected: _disconnected,
    silenced: _silenced,
    muted: _player.isMuted,
  );

  /// Bağlantı durumu değişti.
  ///
  /// Aynı durum tekrar bildirilirse hiçbir şey yapılmaz: yoklama saniyede
  /// bir "hâlâ kopuk" diyor ve her seferinde yeniden ses başlatmak, aralık
  /// ayarını anlamsız kılardı.
  ConnectionAlarmState onConnectionChanged({required bool disconnected}) {
    if (disconnected == _disconnected) return state;

    _disconnected = disconnected;

    if (!disconnected) {
      // Bağlantı geri geldi. Susturma da sıfırlanır: bir sonraki kopma
      // yeniden uyarmalı, "bir kez susturdum" kalıcı olmamalı.
      _silenced = false;
      _stop();
      return state;
    }

    _start();

    return state;
  }

  /// "Sesi sustur" düğmesi.
  ///
  /// Yalnızca **bu** kopmayı susturur. Bağlantı geri gelip yeniden koparsa
  /// uyarı tekrar çalar.
  ConnectionAlarmState silence() {
    _silenced = true;
    _stop();

    return state;
  }

  /// Oynatıcının `isMuted` durumunu yeniden okur.
  ///
  /// `ProcessAlarmPlayer` "oynatıcı bulunamadı" kararını `start()` döndükten
  /// sonra, kendi döngüsünde verir; çalmayı başlattığımız anda `isMuted`
  /// hâlâ `false` görünür.
  ConnectionAlarmState refresh() => state;

  void dispose() => _stop();

  void _start() {
    // İlk uyarı HEMEN çalar, aralık kadar beklemez: kopmayı 45 saniye
    // sonra duyurmak, kopmanın kendisi kadar zararlı.
    unawaited(_beep());

    _timer?.cancel();
    _timer = _schedule(interval, (_) => unawaited(_beep()));
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    unawaited(_player.stop());
  }

  Future<void> _beep() async {
    if (!_disconnected || _silenced) return;

    // `start()` DEĞİL: o döngüye sokar ve kesintisiz çalar. Bağlantı
    // kopmasını personel çözemez; kesintisiz ses onları cezalandırır.
    await _player.playOnce();
  }
}
