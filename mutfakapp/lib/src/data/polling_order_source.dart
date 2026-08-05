/// `K-05` — artımlı polling ile beslenen [OrderSource].
///
/// Davranış sözleşmesi `docs/05-mutfakapp.md` §4:
/// * Her 5 saniyede `GET /kitchen/orders?since=<son server_time>`.
/// * Ağ hatasında üstel geri çekilme: 5 → 10 → 20 → 40 → en çok 60 saniye.
/// * Bağlantı geri gelince **tam yenileme** (kaçırılan durum değişimleri için).
/// * 60 saniyede bir `heartbeat`.
/// * Liste hiçbir zaman hataya düşmez; bağlantı koptuğunda son bilinen liste
///   ekranda kalır, uyarı [connection] akışından gelir.
library;

import 'dart:async';

import 'package:bld_api_client/bld_api_client.dart';

/// Listenin ne zaman tazelendiğini bildirebilen kaynak.
///
/// `OrderSource` `packages/api_client`'ta ve bu görevin kapsamı dışında;
/// sözleşmeye alan eklemek yerine yerel bir arayüzle genişletiyoruz. Arayüzü
/// uygulamayan bir kaynak (ör. testteki sahte) yalnızca yaş göstergesini
/// kaybeder, ekranın kalanı çalışır.
abstract interface class TimestampedOrderSource {
  /// Sunucudan en son başarıyla liste alındığı an (UTC); hiç alınmadıysa `null`.
  DateTime? get lastUpdatedAt;
}

/// Sunucudan periyodik olarak sipariş çeken [OrderSource] uygulaması.
///
/// Faz 1.5'te yerini `WebSocketOrderSource` alacak; ekran kodu değişmeyecek.
class PollingOrderSource implements OrderSource, TimestampedOrderSource {
  PollingOrderSource({
    required KitchenService kitchen,
    Duration interval = const Duration(seconds: 5),
    this.maxBackoff = const Duration(seconds: 60),
    this.heartbeatInterval = const Duration(seconds: 60),
    DateTime Function()? clock,
  }) : _kitchen = kitchen,
       _interval = interval,
       _clock = clock ?? (() => DateTime.now().toUtc());

  final KitchenService _kitchen;

  Duration _interval;

  /// Normal çekme aralığı.
  Duration get interval => _interval;

  /// Aralığı çalışırken değiştirir ve bekleyen yoklamayı yeniden planlar.
  ///
  /// DEĞİŞTİRİLEBİLİR OLMASI ŞART. Önceden ayarlar ekranındaki aralık
  /// değişikliği sağlayıcıyı yeniden kuruyordu: eski kaynak kapanıyor,
  /// yenisi **boş bir anlık görüntüyle** açılıyor ve mutfak ekranı ilk
  /// yanıt gelene kadar bomboş kalıyordu. Bir ayarı kurcalamak, ekrandaki
  /// siparişleri silmemeli.
  set interval(Duration value) {
    if (value == _interval || _disposed) return;
    _interval = value;
    // Geri çekilme sırasında araya girmeyiz: hata durumundaki bekleme yeni
    // aralıktan daha uzundur ve kısaltmak sunucuyu döverdi.
    if (_consecutiveFailures == 0) _scheduleNext(value);
  }

  /// Geri çekilmenin üst sınırı.
  final Duration maxBackoff;

  /// Canlılık bildirimi aralığı.
  final Duration heartbeatInterval;

  final StreamController<List<KitchenOrder>> _orders =
      StreamController<List<KitchenOrder>>.broadcast();
  final StreamController<OrderSourceConnection> _connection =
      StreamController<OrderSourceConnection>.broadcast();

  /// Kimliğe göre son bilinen sipariş durumu.
  final Map<int, KitchenOrder> _known = <int, KitchenOrder>{};

  List<KitchenOrder> _snapshot = const <KitchenOrder>[];
  OrderSourceConnection _connectionState = OrderSourceConnection.connecting;

  final DateTime Function() _clock;

  DateTime? _since;
  DateTime? _lastUpdatedAt;
  int _consecutiveFailures = 0;

  /// Bir sonraki başarılı çekme tam liste mi olsun?
  ///
  /// İlk çekmede ve her kopma sonrasında `true`'dur: artımlı istek yalnızca
  /// değişenleri getirdiği için kopukluk sırasında kaçan her şey ancak tam
  /// yenilemeyle toparlanır.
  bool _needsFullRefresh = true;

  Timer? _pollTimer;
  Timer? _heartbeatTimer;
  Future<void>? _inFlight;
  bool _started = false;
  bool _hasSucceeded = false;
  bool _disposed = false;

  @override
  Stream<List<KitchenOrder>> watch() =>
      _withCurrentValue(_orders.stream, () => _snapshot);

  @override
  Stream<OrderSourceConnection> get connection =>
      _withCurrentValue(_connection.stream, () => _connectionState);

  /// Son yayımlanan liste. Yeniden çizim gerektirmeyen okumalar için.
  List<KitchenOrder> get snapshot => _snapshot;

  /// Son bağlantı durumu.
  OrderSourceConnection get connectionState => _connectionState;

  /// Sunucudan en son başarıyla liste alındığı an (UTC); hiç alınmadıysa `null`.
  ///
  /// Bağlantı koptuğunda ekranda duran liste "son bilinen durum"dur ve
  /// personelin ona ne kadar güvenebileceği tek bir sayıya bağlıdır: yaşı.
  @override
  DateTime? get lastUpdatedAt => _lastUpdatedAt;

  /// Yayına, dinlemeye başlayanın kaçırdığı **güncel değeri** önekler.
  ///
  /// `async*` içinde `yield mevcut; yield* akış;` yazmak yetmiyordu: iki adım
  /// arasında yayın akışına düşen bir olay hiçbir dinleyiciye ulaşmadan
  /// kayboluyor. Burada abonelik ÖNCE kurulur, güncel değer sonra yazılır;
  /// arada boşluk kalmaz.
  static Stream<T> _withCurrentValue<T>(
    Stream<T> source,
    T Function() current,
  ) {
    late final StreamController<T> controller;
    StreamSubscription<T>? subscription;

    controller = StreamController<T>(
      onListen: () {
        subscription = source.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
        controller.add(current());
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () => subscription?.cancel(),
    );

    return controller.stream;
  }

  /// Zamanlayıcıları başlatır. Yapıcıda değil ayrı bir çağrıda olması
  /// bilinçlidir: nesne kurmak ağ trafiği başlatmamalı, testler kontrolü
  /// elinde tutmalı.
  void start() {
    if (_disposed || _started) return;
    _started = true;
    _heartbeatTimer = Timer.periodic(
      heartbeatInterval,
      (_) => unawaited(_sendHeartbeat()),
    );
    unawaited(_tick());
  }

  @override
  Future<void> refresh() async {
    // Süren bir istek varsa o eski `since` ile başlamıştır; tam yenileme onun
    // ardından yapılmalı, yoksa çağrı yenileme yapmadan döner.
    //
    // BAYRAK BEKLEMEDEN SONRA KURULUR. Önce kurulsaydı, o sırada tamamlanan
    // istek başarıyla bitip bayrağı `false`'a çekiyor ve elle yenileme sessizce
    // artımlı bir çekmeye dönüşüyordu — kaçırılmış durum değişimleri de
    // toparlanmıyordu.
    await _inFlight;
    if (_disposed) return;
    _needsFullRefresh = true;
    await _tick();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _pollTimer?.cancel();
    _heartbeatTimer?.cancel();
    _pollTimer = null;
    _heartbeatTimer = null;
    await _inFlight;
    await _orders.close();
    await _connection.close();
  }

  /// [consecutiveFailures] ardışık hatadan sonra beklenecek süre.
  ///
  /// `1 → base`, `2 → 2×base`, `3 → 4×base` … [max] ile sınırlıdır.
  /// Varsayılan 5 saniyelik aralıkta bu 5 → 10 → 20 → 40 → 60 verir.
  static Duration backoffDelay({
    required Duration base,
    required int consecutiveFailures,
    required Duration max,
  }) {
    if (consecutiveFailures <= 0) return base;
    // 2^30'dan sonrası taşar; her hâlükârda max'a çarpar.
    final exponent = (consecutiveFailures - 1).clamp(0, 30);
    final micros = base.inMicroseconds * (1 << exponent);
    return micros >= max.inMicroseconds || micros < 0
        ? max
        : Duration(microseconds: micros);
  }

  // ─────────────────────────── İç işleyiş ───────────────────────────

  Future<void> _tick() {
    // Yavaş bir istek sürerken ikincisini başlatmak sunucuyu gereksiz yorar
    // ve yanıtların sırası bozulur.
    final running = _inFlight;
    if (running != null) return running;

    final attempt = _fetch().whenComplete(() => _inFlight = null);
    _inFlight = attempt;
    return attempt;
  }

  Future<void> _fetch() async {
    if (_disposed) return;
    if (_connectionState == OrderSourceConnection.revoked) return;

    final fullRefresh = _needsFullRefresh;
    if (!_hasSucceeded) _emitConnection(OrderSourceConnection.connecting);

    try {
      final page = await _kitchen.orders(
        since: fullRefresh ? null : _since,
        // Artımlı çekmede tamamlananlar da istenir: bir sipariş
        // `teslim_edildi` olduğunda sunucu onu aktif listeden düşürür ve
        // `since` filtresi bunu bir daha göndermez. O zaman kart ekranda
        // sonsuza dek kalırdı. Tamamlananları alıp yerelde eleriz.
        includeCompleted: !fullRefresh,
      );
      if (_disposed) return;

      _applyPage(page, replaceAll: fullRefresh);
      _needsFullRefresh = false;
      _hasSucceeded = true;
      _lastUpdatedAt = _clock();
      _consecutiveFailures = 0;
      _emitConnection(OrderSourceConnection.connected);
      _scheduleNext(_interval);
    } on Object catch (error) {
      if (_disposed) return;

      if (error is ApiException &&
          (error.isDeviceRevoked || error.isUnauthenticated)) {
        // Yeniden denemek anlamsız: eşleme ekranına dönülmeli (§7 adım 5).
        _emitConnection(OrderSourceConnection.revoked);
        _heartbeatTimer?.cancel();
        _heartbeatTimer = null;
        return;
      }

      // Beklenmeyen tipteki hatalar da geri çekilmeye düşer. Mutfak ekranı
      // hiçbir sebeple sipariş çekmeyi bırakmamalıdır.
      _consecutiveFailures++;
      _needsFullRefresh = true;
      _emitConnection(OrderSourceConnection.disconnected);
      _scheduleNext(
        backoffDelay(
          base: _interval,
          consecutiveFailures: _consecutiveFailures,
          max: maxBackoff,
        ),
      );
    }
  }

  void _applyPage(KitchenOrderPage page, {required bool replaceAll}) {
    if (replaceAll) _known.clear();

    for (final order in page.data) {
      if (order.status.isActiveInKitchen) {
        _known[order.id] = order;
      } else {
        // Teslim edilen ya da iptal edilen sipariş ekrandan kalkar.
        _known.remove(order.id);
      }
    }

    _since = page.serverTime;

    final ordered = _known.values.toList()
      ..sort((a, b) {
        final byCreation = a.createdAt.compareTo(b.createdAt);
        return byCreation != 0 ? byCreation : a.id.compareTo(b.id);
      });

    _snapshot = List<KitchenOrder>.unmodifiable(ordered);
    if (!_orders.isClosed) _orders.add(_snapshot);
  }

  void _scheduleNext(Duration delay) {
    _pollTimer?.cancel();
    if (_disposed) return;
    _pollTimer = Timer(delay, () => unawaited(_tick()));
  }

  void _emitConnection(OrderSourceConnection state) {
    if (_connectionState == state) return;
    _connectionState = state;
    if (!_connection.isClosed) _connection.add(state);
  }

  Future<void> _sendHeartbeat() async {
    if (_disposed || _connectionState == OrderSourceConnection.revoked) return;
    try {
      await _kitchen.heartbeat();
    } on ApiException {
      // Canlılık bildirimi en iyi çabadır: başarısızlığı zaten sipariş
      // çekmesi de görür ve bağlantı durumunu oradan bildirir.
    }
  }
}
