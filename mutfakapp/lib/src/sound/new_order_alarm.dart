/// Yeni sipariş alarmının **ne zaman çalacağına** karar veren saf mantık.
///
/// Müşterinin kuralı tek cümle: *"onaylaya basana kadar susmuyor."* Bunun
/// altında dört ayrı davranış var ve dördü de burada, widget'sız ve
/// Riverpod'suz durur — böylece testi ucuz ve kesindir:
///
/// 1. `yeni` durumunda **en az bir** sipariş varken alarm çalar.
/// 2. Personel bir siparişi onaylayınca o sipariş listeden düşer; başka
///    `yeni` sipariş kaldıysa alarm **devam eder**.
/// 3. "Sesi sustur" yalnızca **o anki** siparişleri susturur. Sonradan
///    düşen yeni bir sipariş alarmı yeniden başlatır.
/// 4. Açılışta zaten bekleyen `yeni` sipariş varsa alarm çalar — elektrik
///    kesintisinden sonra sessiz açılmak, siparişi kaçırmak demektir.
library;

import 'package:bld_api_client/bld_api_client.dart';

import 'alarm_player.dart';
import 'tts_announcer.dart';

/// Alarmın dışarıdan görünen durumu. Arayüz bunu çizer.
class NewOrderAlarmState {
  const NewOrderAlarmState({
    required this.pendingCount,
    required this.sounding,
    required this.silenced,
    required this.muted,
    this.muteReason,
  });

  static const NewOrderAlarmState idle = NewOrderAlarmState(
    pendingCount: 0,
    sounding: false,
    silenced: false,
    muted: false,
  );

  /// Onay bekleyen (`yeni`) sipariş sayısı.
  final int pendingCount;

  /// Alarm şu an çalmalı mı?
  final bool sounding;

  /// Bekleyen sipariş var ama personel sesi susturdu.
  final bool silenced;

  /// Ses hiç çıkmıyor: ayardan kapatılmış ya da kasada oynatıcı yok.
  ///
  /// Arayüz bunu **görünür** kılmak zorundadır; sessiz bir alarm, alarm
  /// olmadığını bilmemekten iyidir.
  final bool muted;

  /// Ses neden çıkmıyor? Sessiz değilse `null`.
  ///
  /// "Ses yok" demek personele yetmiyor; ne yapacağını bilmiyor. Sebep
  /// uyarı şeridine ve tanılama ekranına kadar taşınır.
  final String? muteReason;

  /// Bekleyen sipariş varken hiç ses çıkmıyor mu? Uyarı şeridinin koşulu.
  bool get silentWhileWaiting => pendingCount > 0 && muted;

  NewOrderAlarmState copyWith({
    int? pendingCount,
    bool? sounding,
    bool? silenced,
    bool? muted,
    String? muteReason,
  }) => NewOrderAlarmState(
    pendingCount: pendingCount ?? this.pendingCount,
    sounding: sounding ?? this.sounding,
    silenced: silenced ?? this.silenced,
    muted: muted ?? this.muted,
    muteReason: muteReason ?? this.muteReason,
  );

  @override
  bool operator ==(Object other) =>
      other is NewOrderAlarmState &&
      other.pendingCount == pendingCount &&
      other.sounding == sounding &&
      other.silenced == silenced &&
      other.muted == muted &&
      other.muteReason == muteReason;

  @override
  int get hashCode =>
      Object.hash(pendingCount, sounding, silenced, muted, muteReason);

  @override
  String toString() =>
      'NewOrderAlarmState(pending: $pendingCount, sounding: $sounding, '
      'silenced: $silenced, muted: $muted, reason: $muteReason)';
}

/// Sipariş listesini alarm kararına çeviren saf durum makinesi.
///
/// Tek başına ses çalmaz; yalnızca "çalmalı mı" sorusunu cevaplar.
/// [NewOrderAlarm] bu kararı bir [AlarmPlayer]'a bağlar.
class NewOrderAlarmPolicy {
  /// Personelin elle susturduğu sipariş kimlikleri.
  ///
  /// Kimlik bazlı olması şart: "susturuldu" bayrağı tek bir `bool` olsaydı,
  /// sonradan düşen yeni sipariş de susturulmuş sayılırdı.
  final Set<int> _silenced = <int>{};

  Set<int> _pending = const <int>{};

  /// Onay bekleyen sipariş kimlikleri.
  Set<int> get pendingIds => Set<int>.unmodifiable(_pending);

  int get pendingCount => _pending.length;

  /// Susturulmamış, bekleyen bir sipariş var mı?
  bool get shouldSound => _pending.any((id) => !_silenced.contains(id));

  /// Bekleyen sipariş var ama hepsi susturulmuş.
  bool get isSilenced => _pending.isNotEmpty && !shouldSound;

  /// Yeni sipariş listesini uygular ve alarmın çalması gerekip gerekmediğini
  /// döndürür.
  ///
  /// Listeden düşen kimlikler susturma kümesinden de atılır: küme sonsuza dek
  /// büyümemeli ve bir sipariş `yeni`ye geri dönemeyeceği için kaydı tutmanın
  /// bir anlamı yok.
  bool apply(List<KitchenOrder> orders) {
    _pending = <int>{
      for (final order in orders)
        if (order.status == OrderStatus.yeni) order.id,
    };
    _silenced.retainWhere(_pending.contains);
    return shouldSound;
  }

  /// O anki bekleyen siparişleri susturur.
  ///
  /// Kalıcı susturma DEĞİLDİR — ayarlar ekranındaki ses şalteri odur. Buradaki
  /// susturma yalnızca şu an bekleyen kimlikleri kapsar.
  bool silence() {
    _silenced.addAll(_pending);
    return shouldSound;
  }
}

/// [NewOrderAlarmPolicy] kararını bir [AlarmPlayer]'a bağlar.
///
/// Ayrı bir sınıf olması bilinçli: karar (saf, senkron) ile çalma (asenkron,
/// süreç açan) birbirine karışmasın. Riverpod bu sınıfı sarar, mantığı değil.
class NewOrderAlarm {
  NewOrderAlarm(
    this._player, {
    TtsAnnouncer? announcer,
    String Function(KitchenOrder order)? announcementFor,
  }) : _announcer = announcer,
       _announcementFor = announcementFor ?? defaultAnnouncement;

  final AlarmPlayer _player;
  final TtsAnnouncer? _announcer;
  final String Function(KitchenOrder order) _announcementFor;
  final NewOrderAlarmPolicy _policy = NewOrderAlarmPolicy();

  /// Anonsu yapılmış sipariş kimlikleri — aynı sipariş iki kez okunmasın.
  final Set<int> _announced = <int>{};

  /// İlk sipariş listesi geldi mi?
  ///
  /// Açılışta bekleyen siparişlerin hepsini arka arkaya okumak (elektrik
  /// kesintisinden sonra 12 sipariş) anons değil gürültüdür. İlk liste
  /// yalnızca "biliniyor" olarak işaretlenir; alarm sesi yine çalar.
  bool _primed = false;

  NewOrderAlarmState _state = NewOrderAlarmState.idle;

  NewOrderAlarmState get state => _state;

  /// Sipariş listesi değişti. Dönen değer yeni durumdur.
  NewOrderAlarmState onOrders(List<KitchenOrder> orders) {
    final sound = _policy.apply(orders);
    _announce(orders);
    _sync(sound);
    return _state;
  }

  /// Yeni düşen siparişleri sesli okur.
  void _announce(List<KitchenOrder> orders) {
    final pending = orders.where((order) => order.status == OrderStatus.yeni);

    if (!_primed) {
      _primed = true;
      _announced.addAll(pending.map((order) => order.id));
      return;
    }

    final announcer = _announcer;
    for (final order in pending) {
      if (!_announced.add(order.id)) continue;
      if (announcer == null) continue;

      announcer.announce(_announcementFor(order)).ignore();
    }

    // Küme sonsuza dek büyümesin: `yeni`den çıkan sipariş geri dönemez.
    _announced.retainWhere(_policy.pendingIds.contains);
  }

  /// "Sesi sustur" düğmesi.
  NewOrderAlarmState silence() {
    final sound = _policy.silence();
    _sync(sound);
    return _state;
  }

  /// Oynatıcının durumunu yeniden okur; sipariş listesi değişmez.
  ///
  /// GEREKLİ: `ProcessAlarmPlayer` "oynatıcı bulunamadı" kararını `start()`
  /// döndükten **sonra**, kendi döngüsünde verir. Çalmayı başlattığımız anda
  /// `isMuted` hâlâ `false` görünür ve arayüz sessizliği bildiremez. Pano
  /// saati bunu saniyeler içinde yakalar.
  NewOrderAlarmState refresh() {
    _sync(_policy.shouldSound);
    return _state;
  }

  /// Ekran kapanırken sesi kesmek zorunludur: ölmüş bir arayüzün arkasında
  /// çalmaya devam eden bir süreç, kasayı ancak yeniden başlatmakla susar.
  Future<void> dispose() => _player.stop();

  void _sync(bool shouldSound) {
    // Başlatma/durdurma hatası arayüzü çökertmemeli; `AlarmPlayer` hataları
    // kendi içinde yutuyor ve `isMuted` ile bildiriyor.
    if (shouldSound) {
      _player.start().ignore();
    } else if (_player.isPlaying) {
      _player.stop().ignore();
    }

    _state = NewOrderAlarmState(
      pendingCount: _policy.pendingCount,
      sounding: shouldSound && !_player.isMuted,
      silenced: _policy.isSilenced,
      muted: _player.isMuted,
      muteReason: _player.muteReason,
    );
  }
}

/// Sipariş için varsayılan Türkçe anons metni.
///
/// KISA TUTULUYOR: mutfakta anons ne kadar uzunsa, ikinci sipariş
/// düştüğünde birincinin üstüne binme ihtimali o kadar yüksek. Sipariş
/// numarası ve kalem sayısı, ekrana bakma kararını vermeye yeter.
String defaultAnnouncement(KitchenOrder order) {
  final items = order.items.fold<int>(0, (sum, item) => sum + item.quantity);
  final number = order.orderNumber.replaceAll(RegExp(r'^[A-Za-z]-'), '');

  return '$number numaralı yeni sipariş, $items ürün';
}
