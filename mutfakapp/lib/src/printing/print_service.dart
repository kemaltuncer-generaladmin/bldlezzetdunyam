/// `K-04` — kuyruk işçisi: fiş verisini alır, basar, `ack` gönderir.
///
/// Tek iş parçacığı gibi çalışır (aynı anda tek iş): fişler mutfağa geldikleri
/// sırayla çıkar ve bir işin iki kez basılması mümkün olmaz.
///
/// Davranış sözleşmesi `docs/05-mutfakapp.md` §5.4:
/// * Her iş önce diske yazılır, sonra basılır.
/// * Başarısızlıkta `attempts++` ve geri çekilmeli tekrar: 2s, 5s, 15s, 60s…
/// * Yazıcı yoksa iş kuyrukta bekler, sayaç durum çubuğunda görünür.
/// * Yeniden başlatmada kuyruk diskten okunur ve kaldığı yerden devam eder.
/// * Basımdan sonra `ack` gönderilir; başarısız olursa **sessizce yutulur**.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/escpos.dart';

import 'print_job.dart';
import 'print_queue.dart';
import 'printer_device.dart';
import 'receipt_mapper.dart';

/// Kuyruğu tüketen arka plan işçisi.
class PrintService {
  PrintService({
    required PrintQueue queue,
    required PrinterDevice device,
    required KitchenService kitchen,
    ReceiptStyle style = ReceiptStyle.standard,
    this.idlePollInterval = const Duration(seconds: 1),
    this.retrySchedule = defaultRetrySchedule,
    DateTime Function()? clock,
  }) : _queue = queue,
       _device = device,
       _kitchen = kitchen,
       _style = style,
       _now = clock ?? (() => DateTime.now().toUtc());

  /// `docs/05` §5.4'teki geri çekilme basamakları. Son değer tekrarlanır.
  static const List<Duration> defaultRetrySchedule = [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 60),
  ];

  final PrintQueue _queue;
  final PrinterDevice _device;
  final KitchenService _kitchen;
  final ReceiptStyle _style;
  final DateTime Function() _now;

  /// Kuyruk boşken ne sıklıkla bakılacağı.
  final Duration idlePollInterval;

  final List<Duration> retrySchedule;

  final StreamController<int> _pending = StreamController<int>.broadcast();

  Future<void>? _loop;

  /// Süren beklemeyi erken bitirir. Yeni iş gelince ya da kapanırken çağrılır.
  void Function()? _wakeUp;

  bool _disposed = false;

  /// Bekleyen iş sayısı akışı — durum çubuğu bunu dinler.
  Stream<int> get pendingCount async* {
    yield _queue.pendingCount();
    yield* _pending.stream;
  }

  /// [attempts] başarısız denemeden sonra beklenecek süre.
  Duration retryDelay(int attempts) {
    if (attempts <= 0) return Duration.zero;
    final index = attempts - 1;
    return index < retrySchedule.length
        ? retrySchedule[index]
        : retrySchedule.last;
  }

  /// Basılmış işlerin diskte tutulma süresi.
  ///
  /// Tekillik kısıtı basılmış satırlara da dayandığı için silmek, o siparişin
  /// fişini yeniden basılabilir kılar. Bir haftadan eski siparişin mutfağa
  /// geri dönmesi mümkün değildir; tablo sonsuza dek büyümesin.
  static const Duration keepPrintedFor = Duration(days: 7);

  /// İşçiyi başlatır. Yeniden başlatmada diskteki işler kaldığı yerden sürer.
  void start() {
    if (_disposed || _loop != null) return;
    _queue.purgePrinted(olderThan: _now().subtract(keepPrintedFor));
    _loop = _run();
    _emitPending();
  }

  /// Kuyruğa iş ekler ve işçiyi uyandırır.
  ///
  /// Aynı `(orderId, type)` çifti zaten kayıtlıysa `false` döner ve hiçbir şey
  /// olmaz — fiş iki kez basılmaz.
  bool enqueue(int orderId, ReceiptType type) {
    final added = _queue.enqueue(
      orderId: orderId,
      type: type,
      createdAt: _now(),
    );
    if (added) {
      _emitPending();
      _wake();
    }
    return added;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _wake();
    await _loop;
    await _pending.close();
  }

  // ─────────────────────────── İç işleyiş ───────────────────────────

  Future<void> _run() async {
    while (!_disposed) {
      final job = _queue.nextPending();

      if (job == null) {
        await _sleep(idlePollInterval);
        continue;
      }

      final failed = await _process(job);
      _emitPending();

      if (failed) {
        // Aynı iş sırayı tıkar ama bu bilinçlidir: fişler sırayla basılmalı
        // ve yazıcı yokken sonraki işi denemenin anlamı yok.
        await _sleep(retryDelay(job.attempts + 1));
      }
    }
  }

  /// İşi işler; başarısızsa `true` döner.
  Future<bool> _process(PrintJob job) async {
    try {
      final payload = job.payload ?? await _materialize(job);
      await _device.write(payload);

      final printedAt = _now();
      _queue.markPrinted(job.id, printedAt);
      // Fişin basılmış olması `ack`'e bağlı değildir; bu yüzden beklenmez.
      unawaited(_ack(job, printedAt));
      return false;
    } on Object {
      // Ağ hatası, yazıcı yok, kağıt bitti — hepsi aynı sonucu doğurur:
      // iş kuyrukta kalır ve geri çekilmeyle tekrar denenir.
      _queue.incrementAttempts(job.id);
      return true;
    }
  }

  /// Fiş verisini sunucudan alıp ESC/POS baytlarına çevirir ve diske yazar.
  ///
  /// Metnin ne yazacağına sunucu karar verir (`docs/05` §5.3); istemci
  /// yalnızca biçimlendirir.
  Future<Uint8List> _materialize(PrintJob job) async {
    final printedAt = _now();

    final bytes = switch (job.type) {
      ReceiptType.mutfak => buildKitchenReceipt(
        toKitchenReceiptData(
          await _kitchen.kitchenReceipt(job.orderId),
          printedAt: printedAt,
        ),
        style: _style,
      ),
      ReceiptType.musteri => buildCustomerReceipt(
        toCustomerReceiptData(
          await _kitchen.customerReceipt(job.orderId),
          printedAt: printedAt,
        ),
        style: _style,
      ),
    };

    _queue.savePayload(job.id, bytes);
    return bytes;
  }

  Future<void> _ack(PrintJob job, DateTime printedAt) async {
    try {
      await _kitchen.ackPrint(
        job.orderId,
        PrintAckRequest(type: job.type, printedAt: printedAt),
      );
    } on Object {
      // Bilinçli sessizlik (`docs/05` §5.4): ack denetim içindir, fiş elde.
    }
  }

  void _emitPending() {
    if (_pending.isClosed) return;
    _pending.add(_queue.pendingCount());
  }

  /// Uyandırılabilir bekleme: yeni iş gelince ya da kapanınca hemen döner.
  ///
  /// Zamanlayıcı erken uyanışta **iptal edilir**. `Future.any` ile beklemek
  /// yeterli değildi: kazanan taraf uyandırma olsa bile gecikme zamanlayıcısı
  /// arkada asılı kalıyordu.
  Future<void> _sleep(Duration duration) {
    if (_disposed || duration <= Duration.zero) return Future<void>.value();

    final completer = Completer<void>();
    final timer = Timer(duration, () {
      if (!completer.isCompleted) completer.complete();
    });

    _wakeUp = () {
      timer.cancel();
      if (!completer.isCompleted) completer.complete();
    };

    return completer.future.whenComplete(() {
      timer.cancel();
      _wakeUp = null;
    });
  }

  void _wake() => _wakeUp?.call();
}
