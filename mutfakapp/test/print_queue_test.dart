/// `K-04` kuyruk testleri — `docs/05-mutfakapp.md` §5.4,
/// `docs/10-test-kabul.md` S4 (yazıcı yokken iş birikir, gelince sırayla
/// basılır, idempotentlik korunur).
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mutfakapp/src/printing/print_queue.dart';
import 'package:mutfakapp/src/printing/print_service.dart';
import 'package:mutfakapp/src/printing/printer_device.dart';

import 'fake_kitchen_service.dart';

/// Baytları belleğe yazan sahte yazıcı; istenirse arızalı davranır.
class FakePrinter implements PrinterDevice {
  final List<Uint8List> written = <Uint8List>[];

  /// `true` iken her yazma başarısız olur — "yazıcı kapalı".
  bool broken = false;

  @override
  Future<void> write(Uint8List bytes) async {
    if (broken) throw const FileSystemException('yazıcı yok', '/dev/thermal0');
    written.add(bytes);
  }
}

KitchenReceipt receiptFor(int orderId) => KitchenReceipt(
  orderNumber: 'S-$orderId',
  deliveryType: DeliveryType.delivery,
  lines: const [ReceiptLine(quantity: 1, name: 'Tavuk Sote')],
);

Future<void> settle([int milliseconds = 60]) =>
    Future<void>.delayed(Duration(milliseconds: milliseconds));

/// Müşteri fişi — kuyruk testlerinde ikinci bir fiş tipine ihtiyaç var.
CustomerReceipt customerReceiptFor(int orderId) => CustomerReceipt(
  orderNumber: 'S-$orderId',
  deliveryType: DeliveryType.delivery,
  items: const [
    OrderItem(
      menuId: 1,
      name: 'Tavuk Sote',
      quantity: 1,
      unitPrice: 18500,
      lineTotal: 18500,
    ),
  ],
  subtotal: 18500,
  deliveryFee: 4000,
  total: 22500,
  currency: 'TRY',
  payment: const Payment(
    method: PaymentMethod.cash,
    status: PaymentStatus.pending,
  ),
);

void main() {
  group('Kuyruk tablosu', () {
    late PrintQueue queue;

    setUp(() => queue = PrintQueue.inMemory());
    tearDown(() => queue.close());

    test('iş eklenir ve bekleyen sayılır', () {
      expect(
        queue.enqueue(
          orderId: 5012,
          type: ReceiptType.mutfak,
          createdAt: DateTime.utc(2026, 8, 4),
        ),
        isTrue,
      );
      expect(queue.pendingCount(), 1);
    });

    test('aynı (order_id, type) çifti ikinci kez eklenmez', () {
      for (var i = 0; i < 3; i++) {
        queue.enqueue(
          orderId: 5012,
          type: ReceiptType.mutfak,
          createdAt: DateTime.utc(2026, 8, 4),
        );
      }
      expect(queue.all(), hasLength(1));
      expect(queue.pendingCount(), 1);
    });

    test('aynı sipariş için iki farklı fiş tipi ayrı işlerdir', () {
      queue
        ..enqueue(
          orderId: 5012,
          type: ReceiptType.mutfak,
          createdAt: DateTime.utc(2026, 8, 4),
        )
        ..enqueue(
          orderId: 5012,
          type: ReceiptType.musteri,
          createdAt: DateTime.utc(2026, 8, 4),
        );
      expect(queue.all(), hasLength(2));
    });

    test('basılmış iş yeniden eklenemez — fiş iki kez çıkmaz', () {
      queue.enqueue(
        orderId: 1,
        type: ReceiptType.mutfak,
        createdAt: DateTime.utc(2026, 8, 4),
      );
      queue.markPrinted(queue.nextPending()!.id, DateTime.utc(2026, 8, 4, 1));

      expect(
        queue.enqueue(
          orderId: 1,
          type: ReceiptType.mutfak,
          createdAt: DateTime.utc(2026, 8, 4, 2),
        ),
        isFalse,
      );
      expect(queue.pendingCount(), isZero);
      expect(queue.all(), hasLength(1));
    });

    /// ESKİ FİŞ ASLA ÇIKMAZ — sahada bulunan hata.
    ///
    /// Tetikleyici revizyon artınca yeni iş ekliyordu ama eskisi kuyrukta
    /// duruyordu. Yazıcı bir süre kapalı kalınca (kâğıt bitti, kablo çıktı)
    /// kuyruk açıldığında ÖNCE eski fiş basılıyor, mutfak iki kâğıt alıyor
    /// ve hangisinin güncel olduğunu anlayamıyordu.
    test('revizyon artınca eski basılmamış iş düşer', () {
      queue.enqueue(
        orderId: 5012,
        type: ReceiptType.mutfak,
        revision: 0,
        createdAt: DateTime.utc(2026, 8, 4),
      );
      queue.enqueue(
        orderId: 5012,
        type: ReceiptType.mutfak,
        revision: 1,
        createdAt: DateTime.utc(2026, 8, 4, 0, 5),
      );
      expect(queue.pendingCount(), 2, reason: 'düşürmeden önce ikisi de var');

      final dropped = queue.dropSuperseded(
        orderId: 5012,
        type: ReceiptType.mutfak,
        keepRevision: 1,
      );

      expect(dropped, 1);
      expect(queue.pendingCount(), 1);
      expect(queue.nextPending()!.revision, 1, reason: 'kalan en güncel olan');
    });

    /// Basılmış iş bir OLAYIN KAYDI; sunucudaki `ack` de onu görmüş.
    /// Silinirse "bu fiş basıldı mı" sorusu cevapsız kalır.
    test('basılmış eski iş düşürülmez', () {
      queue.enqueue(
        orderId: 5012,
        type: ReceiptType.mutfak,
        revision: 0,
        createdAt: DateTime.utc(2026, 8, 4),
      );
      queue.markPrinted(queue.nextPending()!.id, DateTime.utc(2026, 8, 4));

      queue.enqueue(
        orderId: 5012,
        type: ReceiptType.mutfak,
        revision: 1,
        createdAt: DateTime.utc(2026, 8, 4, 0, 5),
      );

      expect(
        queue.dropSuperseded(
          orderId: 5012,
          type: ReceiptType.mutfak,
          keepRevision: 1,
        ),
        0,
      );
    });

    /// Fiş tipleri birbirini etkilemez. Müşteri fişi revizyonda yeniden
    /// basılmıyor (`PrintTriggers`); onun bekleyen işi düşürülseydi hiç
    /// basılmamış bir müşteri fişi sessizce kaybolurdu.
    test('bir tipin düşmesi diğer tipi etkilemez', () {
      queue.enqueue(
        orderId: 5012,
        type: ReceiptType.musteri,
        revision: 0,
        createdAt: DateTime.utc(2026, 8, 4),
      );
      queue.enqueue(
        orderId: 5012,
        type: ReceiptType.mutfak,
        revision: 0,
        createdAt: DateTime.utc(2026, 8, 4),
      );
      queue.enqueue(
        orderId: 5012,
        type: ReceiptType.mutfak,
        revision: 1,
        createdAt: DateTime.utc(2026, 8, 4, 0, 5),
      );

      queue.dropSuperseded(
        orderId: 5012,
        type: ReceiptType.mutfak,
        keepRevision: 1,
      );

      expect(queue.pendingCount(), 2, reason: 'müşteri fişi + revize mutfak');
    });

    /// Başka siparişin fişine dokunulmaz.
    test('başka siparişin işi düşmez', () {
      queue.enqueue(
        orderId: 5012,
        type: ReceiptType.mutfak,
        revision: 0,
        createdAt: DateTime.utc(2026, 8, 4),
      );
      queue.enqueue(
        orderId: 5013,
        type: ReceiptType.mutfak,
        revision: 0,
        createdAt: DateTime.utc(2026, 8, 4),
      );
      queue.enqueue(
        orderId: 5013,
        type: ReceiptType.mutfak,
        revision: 1,
        createdAt: DateTime.utc(2026, 8, 4, 0, 5),
      );

      queue.dropSuperseded(
        orderId: 5013,
        type: ReceiptType.mutfak,
        keepRevision: 1,
      );

      expect(queue.pendingCount(), 2);
    });

    test('sıra ekleme sırasını korur', () {
      for (final id in [7, 3, 9]) {
        queue.enqueue(
          orderId: id,
          type: ReceiptType.mutfak,
          createdAt: DateTime.utc(2026, 8, 4),
        );
      }
      expect(queue.nextPending()!.orderId, 7);
    });

    test('attempts artırılır', () {
      queue.enqueue(
        orderId: 1,
        type: ReceiptType.mutfak,
        createdAt: DateTime.utc(2026, 8, 4),
      );
      final id = queue.nextPending()!.id;
      queue
        ..incrementAttempts(id)
        ..incrementAttempts(id);
      expect(queue.nextPending()!.attempts, 2);
    });

    test('payload saklanır ve geri okunur', () {
      queue.enqueue(
        orderId: 1,
        type: ReceiptType.mutfak,
        createdAt: DateTime.utc(2026, 8, 4),
      );
      final id = queue.nextPending()!.id;
      queue.savePayload(id, Uint8List.fromList([0x1B, 0x40, 0x9E]));

      expect(queue.nextPending()!.payload, [0x1B, 0x40, 0x9E]);
    });

    test('basılmış eski işler temizlenir, bekleyenler kalır', () {
      queue
        ..enqueue(
          orderId: 1,
          type: ReceiptType.mutfak,
          createdAt: DateTime.utc(2026, 8, 1),
        )
        ..enqueue(
          orderId: 2,
          type: ReceiptType.mutfak,
          createdAt: DateTime.utc(2026, 8, 1),
        );
      queue.markPrinted(1, DateTime.utc(2026, 8, 1));

      expect(queue.purgePrinted(olderThan: DateTime.utc(2026, 8, 4)), 1);
      expect(queue.all(), hasLength(1));
      expect(queue.pendingCount(), 1);
    });
  });

  /// "Yeniden bas" — revizyon körlüğü hatası (K-20).
  ///
  /// Eski `requeue` `(order_id, type)` eşleştiriyordu; ne revizyon süzgeci
  /// ne satır sınırı vardı. Düzenlenmiş bir siparişte tek dokunuş, o tipin
  /// HER revizyon satırını basılmamışa çeviriyor ve hem eski hem yeni sürüm
  /// kâğıda dökülüyordu — tam da `dropSuperseded`'in engellediği hata.
  group('Yeniden bas revizyona duyarlıdır', () {
    late PrintQueue queue;

    setUp(() => queue = PrintQueue.inMemory(clock: () => DateTime.utc(2026, 8, 14)));
    tearDown(() => queue.close());

    /// İki revizyonu da basılmış bir sipariş kurar.
    void seedPrintedRevisions() {
      for (final revision in [0, 1]) {
        queue.enqueue(
          orderId: 5012,
          type: ReceiptType.mutfak,
          revision: revision,
          createdAt: DateTime.utc(2026, 8, 4),
        );
      }
      for (final job in queue.all()) {
        queue.markPrinted(job.id, DateTime.utc(2026, 8, 4, 12));
      }
      expect(queue.pendingCount(), 0);
    }

    test('YALNIZ EN GÜNCEL revizyon kuyruğa geri konur', () {
      seedPrintedRevisions();

      expect(
        queue.requeue(orderId: 5012, type: ReceiptType.mutfak),
        isTrue,
      );

      expect(queue.pendingCount(), 1, reason: 'iki kâğıt birden çıkmamalı');
      expect(
        queue.all().where((job) => job.printedAt == null).single.revision,
        1,
      );
    });

    test('eski revizyonun basılmışlığı bozulmaz', () {
      seedPrintedRevisions();
      queue.requeue(orderId: 5012, type: ReceiptType.mutfak);

      final eski = queue.all().firstWhere((job) => job.revision == 0);
      expect(eski.printedAt, isNotNull, reason: 'denetim izi silinmemeli');
    });

    test('istenen revizyon açıkça verilebilir', () {
      seedPrintedRevisions();

      queue.requeue(orderId: 5012, type: ReceiptType.mutfak, revision: 0);

      expect(
        queue.all().where((job) => job.printedAt == null).single.revision,
        0,
      );
    });

    test('satır hiç yoksa İSTENEN revizyonla yeni iş açılır', () {
      // Sıfırıncı revizyonla açılsaydı, bir sonraki otomatik tetiğin
      // `dropSuperseded` çağrısı onu "eskimiş" sayıp siler ve elle
      // istenen fiş sessizce kaybolurdu.
      expect(
        queue.requeue(orderId: 7777, type: ReceiptType.musteri, revision: 3),
        isTrue,
      );

      expect(queue.all().single.revision, 3);
    });
  });

  group('Kuyruk diskte kalıcıdır', () {
    test('uygulama yeniden başlarsa iş kaybolmaz', () async {
      final dir = await Directory.systemTemp.createTemp('bld_kuyruk');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/print_queue.sqlite';

      PrintQueue.open(path)
        ..enqueue(
          orderId: 5012,
          type: ReceiptType.mutfak,
          createdAt: DateTime.utc(2026, 8, 4),
        )
        ..close();

      // "kill -9" sonrası yeniden açılış.
      final reopened = PrintQueue.open(path);
      addTearDown(reopened.close);

      expect(reopened.pendingCount(), 1);
      expect(reopened.nextPending()!.orderId, 5012);
    });

    test('yeniden açılışta idempotentlik korunur', () async {
      final dir = await Directory.systemTemp.createTemp('bld_kuyruk');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/print_queue.sqlite';

      final first = PrintQueue.open(path)
        ..enqueue(
          orderId: 1,
          type: ReceiptType.mutfak,
          createdAt: DateTime.utc(2026, 8, 4),
        );
      first
        ..markPrinted(first.nextPending()!.id, DateTime.utc(2026, 8, 4))
        ..close();

      final reopened = PrintQueue.open(path);
      addTearDown(reopened.close);

      expect(
        reopened.enqueue(
          orderId: 1,
          type: ReceiptType.mutfak,
          createdAt: DateTime.utc(2026, 8, 5),
        ),
        isFalse,
        reason: 'yeniden başlatma basılmış fişi tekrar bastıramaz',
      );
    });
  });

  group('Geri çekilme takvimi', () {
    test('2s → 5s → 15s → 60s ve orada kalır', () {
      final service = PrintService(
        queue: PrintQueue.inMemory(),
        device: FakePrinter(),
        kitchen: FakeKitchenService(),
      );
      addTearDown(service.dispose);

      expect(service.retryDelay(1), const Duration(seconds: 2));
      expect(service.retryDelay(2), const Duration(seconds: 5));
      expect(service.retryDelay(3), const Duration(seconds: 15));
      expect(service.retryDelay(4), const Duration(seconds: 60));
      expect(service.retryDelay(12), const Duration(seconds: 60));
    });
  });

  group('Kuyruk işçisi', () {
    late PrintQueue queue;
    late FakePrinter printer;
    late FakeKitchenService kitchen;
    late PrintService service;

    setUp(() {
      queue = PrintQueue.inMemory();
      printer = FakePrinter();
      kitchen = FakeKitchenService();
    });

    tearDown(() async {
      await service.dispose();
      queue.close();
    });

    PrintService build({Duration settle = const Duration(milliseconds: 5)}) =>
        service = PrintService(
          queue: queue,
          device: printer,
          kitchen: kitchen,
          idlePollInterval: const Duration(milliseconds: 5),
          settleBetweenReceipts: settle,
          retrySchedule: const [Duration(milliseconds: 10)],
        );

    /// SAHADAKİ ŞİKÂYETİN UÇTAN UCA KARŞILIĞI: "eski fişler çıkıyor".
    ///
    /// Yazıcı kapalıyken sipariş düzenleniyor; kuyrukta iki revizyon
    /// birikiyor. Yazıcı açılınca YALNIZ en güncel fiş çıkmalı — mutfağın
    /// eline iki kâğıt geçip hangisinin geçerli olduğunu tahmin etmesi
    /// gerekmemeli.
    test('yazıcı kapalıyken düzenlenen sipariş tek fiş basar', () async {
      kitchen.kitchenReceipts[5012] = receiptFor(5012);

      printer.broken = true;
      build().start();

      service.enqueue(5012, ReceiptType.mutfak);
      await settle(60);
      expect(printer.written, isEmpty, reason: 'yazıcı kapalı');

      // Mutfak siparişi düzenledi: revizyon 1.
      service.enqueue(5012, ReceiptType.mutfak, revision: 1);

      printer.broken = false;
      await settle(400);

      expect(
        printer.written.length,
        1,
        reason: 'iki revizyon birikti ama yalnız en güncel basılmalı',
      );
      expect(queue.pendingCount(), 0);
    });

    /// Müşteri fişi revizyonda yeniden basılmıyor; bekleyen işi de
    /// düşürülmemeli. Düşürülseydi hiç basılmamış bir müşteri fişi
    /// sessizce kaybolurdu.
    test('revizyon, bekleyen müşteri fişini düşürmez', () async {
      kitchen.kitchenReceipts[5012] = receiptFor(5012);
      kitchen.customerReceipts[5012] = customerReceiptFor(5012);

      printer.broken = true;
      build().start();

      service
        ..enqueue(5012, ReceiptType.musteri)
        ..enqueue(5012, ReceiptType.mutfak);
      await settle(60);

      service.enqueue(5012, ReceiptType.mutfak, revision: 1);

      printer.broken = false;
      await settle(500);

      expect(
        printer.written.length,
        2,
        reason: 'müşteri fişi + revize mutfak fişi',
      );
    });

    test('arka arkaya fişler yazıcıyı yormadan basılır', () async {
      // SAHADA YAŞANDI: kuyrukta 28 iş birikmişti ve döngü hepsini yazıcı
      // baytları kabul ettiği hızda gönderdi. Kesici hâlâ hareket ederken
      // sonraki fiş akmaya başlıyor; takılma ve bozuk çıktı böyle oluyor.
      for (final id in [1, 2, 3]) {
        kitchen.kitchenReceipts[id] = receiptFor(id);
      }

      build(settle: const Duration(milliseconds: 60)).start();
      for (final id in [1, 2, 3]) {
        service.enqueue(id, ReceiptType.mutfak);
      }

      final basladi = DateTime.now();
      await settle(400);
      final gecen = DateTime.now().difference(basladi);

      expect(printer.written, hasLength(3));
      // Üç fiş arasında İKİ bekleme var, üç değil: son fişten sonra
      // beklemek yalnızca mutfağı geciktirirdi.
      expect(
        gecen,
        greaterThanOrEqualTo(const Duration(milliseconds: 110)),
        reason: 'Fişler arasında soluklanma payı olmalı.',
      );
    });

    test('yalnızca HATA ALMIŞ işler temizlenir', () async {
      // Hepsini silmek, yazıcı sırayı yetiştiremediği için bekleyen sağlam
      // fişleri de çöpe atardı. Bu bir son çare: kâğıt bittiği için biriken
      // on fişi tek tek uğraşmak yerine yönetici hepsini düşürür.
      printer.broken = true;
      kitchen.kitchenReceipts[1] = receiptFor(1);
      build().start();
      service.enqueue(1, ReceiptType.mutfak);
      await settle(150);

      expect(service.failedCount(), greaterThan(0));

      printer.broken = false;
      queue.enqueue(
        orderId: 2,
        type: ReceiptType.mutfak,
        createdAt: DateTime.utc(2026, 8, 5),
      );

      final silinen = service.clearFailed();

      expect(silinen, 1);
      expect(service.failedCount(), 0);
      expect(
        queue.nextPending()?.orderId,
        2,
        reason: 'Denenmemiş iş kuyrukta kalmalı.',
      );
    });

    // ── K-22 §2/§3 — `clear_queue` ve telemetri ───────────────────────

    test('KUYRUĞU BOŞALT denenmemiş işi de düşürür', () async {
      // `clear_failed`'den ayrı olmasının sebebi tam da bu: bu komut
      // bekleyen sağlam fişleri de siler ve yıkıcı olduğu için ayrı bir
      // düğmede duruyor.
      printer.broken = true;
      kitchen.kitchenReceipts[1] = receiptFor(1);
      build().start();
      service.enqueue(1, ReceiptType.mutfak);
      await settle(150);

      queue.enqueue(
        orderId: 2,
        type: ReceiptType.mutfak,
        createdAt: DateTime.utc(2026, 8, 18),
      );

      final silinen = service.clearQueue();

      expect(silinen, 2, reason: 'Hem hatalı hem denenmemiş iş düşmeli.');
      expect(queue.nextPending(), isNull);
      expect(service.failedCount(), 0);
    });

    test('KUYRUĞU BOŞALT basılmış işlere DOKUNMAZ', () async {
      // Basılmış satırlar tekillik kısıtının dayanağı; silinirlerse aynı
      // siparişin fişi bir sonraki tetikte YENİDEN basılır.
      kitchen.kitchenReceipts[5] = receiptFor(5);
      build().start();
      service.enqueue(5, ReceiptType.mutfak);
      await settle(200);

      expect(printer.written, hasLength(1));

      service.clearQueue();

      expect(queue.all(), hasLength(1));
      expect(queue.all().single.printedAt, isNotNull);
    });

    test('EN ESKİ BEKLEYEN İŞİN zamanı bildirilir', () async {
      // "Kuyrukta 3 iş var" ile "en eskisi 40 dakikadır bekliyor"
      // arasındaki fark, sahaya gitme kararını değiştirir.
      build();

      expect(service.oldestPendingAt(), isNull, reason: 'Boş kuyruk.');

      queue.enqueue(
        orderId: 1,
        type: ReceiptType.mutfak,
        createdAt: DateTime.utc(2026, 8, 18, 7),
      );
      queue.enqueue(
        orderId: 2,
        type: ReceiptType.mutfak,
        createdAt: DateTime.utc(2026, 8, 18, 9),
      );

      expect(service.oldestPendingAt(), DateTime.utc(2026, 8, 18, 7));
    });

    test('SON HATA METNİ saklanır ve başarıda temizlenir', () async {
      // Hata metni olmadan yöneticinin yapabileceği tek şey mutfağa
      // gitmekti; "kuyrukta 3 hata var" ne olduğunu söylemiyor.
      printer.broken = true;
      kitchen.kitchenReceipts[3] = receiptFor(3);
      build().start();
      service.enqueue(3, ReceiptType.mutfak);
      await settle(150);

      expect(service.lastError, isNotNull);
      expect(service.lastError, contains('#3'));

      printer.broken = false;
      await settle(400);

      expect(
        service.lastError,
        isNull,
        reason: 'Çözülmüş arıza panelde asılı kalmamalı.',
      );
    });

    test('tek fiş basılırken bekleme eklenmez', () async {
      kitchen.kitchenReceipts[7] = receiptFor(7);

      build(settle: const Duration(seconds: 30)).start();
      service.enqueue(7, ReceiptType.mutfak);

      final basladi = DateTime.now();
      await settle(200);

      expect(printer.written, hasLength(1));
      expect(
        DateTime.now().difference(basladi),
        lessThan(const Duration(seconds: 5)),
        reason: 'Sıradaki iş yokken beklemek mutfağı geciktirir.',
      );
    });

    test('fiş verisi sunucudan alınır ve basılır', () async {
      kitchen.kitchenReceipts[5012] = receiptFor(5012);
      build().start();
      service.enqueue(5012, ReceiptType.mutfak);
      await settle();

      expect(printer.written, hasLength(1));
      // Fiş sıfırlama komutuyla başlar, kesme komutuyla biter.
      expect(printer.written.single.sublist(0, 2), [0x1B, 0x40]);
      expect(queue.pendingCount(), isZero);
    });

    test('basımdan sonra ack gönderilir', () async {
      kitchen.kitchenReceipts[5012] = receiptFor(5012);
      build().start();
      service.enqueue(5012, ReceiptType.mutfak);
      await settle();

      expect(kitchen.ackCalls, hasLength(1));
      expect(kitchen.ackCalls.single.$1, 5012);
      expect(kitchen.ackCalls.single.$2, ReceiptType.mutfak);
    });

    test('ack başarısız olsa da fiş basılmış sayılır', () async {
      kitchen
        ..kitchenReceipts[5012] = receiptFor(5012)
        ..ackFails = true;
      build().start();
      service.enqueue(5012, ReceiptType.mutfak);
      await settle();

      expect(printer.written, hasLength(1));
      expect(queue.pendingCount(), isZero);
    });

    test('yazıcı yokken iş kuyrukta birikir', () async {
      printer.broken = true;
      kitchen
        ..kitchenReceipts[1] = receiptFor(1)
        ..kitchenReceipts[2] = receiptFor(2);

      build().start();
      service
        ..enqueue(1, ReceiptType.mutfak)
        ..enqueue(2, ReceiptType.mutfak);
      await settle();

      expect(printer.written, isEmpty);
      expect(queue.pendingCount(), 2);
      expect(queue.nextPending()!.attempts, greaterThan(0));
    });

    test('yazıcı gelince kaldığı yerden ve TEK KOPYA basar', () async {
      printer.broken = true;
      kitchen
        ..kitchenReceipts[1] = receiptFor(1)
        ..kitchenReceipts[2] = receiptFor(2);

      build().start();
      service
        ..enqueue(1, ReceiptType.mutfak)
        ..enqueue(2, ReceiptType.mutfak);
      await settle();
      expect(queue.pendingCount(), 2);

      printer.broken = false;
      await settle(120);

      // S4 adım 2: kaldığı yerden basıldı, tek kez.
      expect(printer.written, hasLength(2));
      expect(queue.pendingCount(), isZero);
    });

    test('fiş verisi bir kez çekilir, tekrar denemede ağ gerekmez', () async {
      kitchen.kitchenReceipts[1] = receiptFor(1);
      printer.broken = true;

      build().start();
      service.enqueue(1, ReceiptType.mutfak);
      await settle();

      final fetchesWhileBroken = kitchen.receiptCalls;
      expect(fetchesWhileBroken, 1);

      printer.broken = false;
      await settle(80);

      expect(kitchen.receiptCalls, fetchesWhileBroken);
      expect(printer.written, hasLength(1));
    });

    test('fiş verisi alınamazsa iş kaybolmaz, tekrar denenir', () async {
      build().start();
      service.enqueue(999, ReceiptType.mutfak); // sunucuda yok → hata
      await settle();

      expect(queue.pendingCount(), 1);
      expect(queue.nextPending()!.attempts, greaterThan(0));

      kitchen.kitchenReceipts[999] = receiptFor(999);
      await settle(80);

      expect(printer.written, hasLength(1));
    });

    test('bekleyen sayısı akışa yansır', () async {
      printer.broken = true;
      kitchen.kitchenReceipts[1] = receiptFor(1);

      build().start();
      final counts = <int>[];
      final subscription = service.pendingCount.listen(counts.add);
      addTearDown(subscription.cancel);

      service.enqueue(1, ReceiptType.mutfak);
      await settle();

      expect(counts, contains(1));
    });

    test('aynı işi iki kez sıraya koymak ikinci fiş üretmez', () async {
      kitchen.kitchenReceipts[1] = receiptFor(1);
      build().start();

      expect(service.enqueue(1, ReceiptType.mutfak), isTrue);
      expect(service.enqueue(1, ReceiptType.mutfak), isFalse);
      await settle();

      expect(printer.written, hasLength(1));
    });

    test('yeniden basma idempotentliği bilerek kırar', () async {
      // Kâğıt sıkıştı, fiş yırtıldı — yazılımın göremediği, personelin
      // gördüğü durumlar. `enqueue` burada `false` derdi, `reprint` basar.
      kitchen.kitchenReceipts[1] = receiptFor(1);
      build().start();
      service.enqueue(1, ReceiptType.mutfak);
      await settle();
      expect(printer.written, hasLength(1));

      expect(service.reprint(1, ReceiptType.mutfak), isTrue);
      await settle();

      expect(printer.written, hasLength(2));
      expect(printer.written[0], printer.written[1]);
    });

    test('yeniden basma saklanan baytları kullanır, sunucuya sormaz', () async {
      kitchen.kitchenReceipts[1] = receiptFor(1);
      build().start();
      service.enqueue(1, ReceiptType.mutfak);
      await settle();
      final callsAfterFirstPrint = kitchen.receiptCalls;

      service.reprint(1, ReceiptType.mutfak);
      await settle();

      // Fiş içeriği olayın anındaki hâliyle donar ve ağ yokken de basılır.
      expect(kitchen.receiptCalls, callsAfterFirstPrint);
    });

    test('hiç basılmamış bir siparişin fişi yeniden basılabilir', () async {
      // Bir haftalık temizlik satırı silmiş olabilir; yine de basabilmeliyiz.
      kitchen.kitchenReceipts[7] = receiptFor(7);
      build().start();

      expect(service.reprint(7, ReceiptType.mutfak), isTrue);
      await settle();

      expect(printer.written, hasLength(1));
    });

    test('yeniden basma deneme sayacını sıfırlar', () async {
      kitchen.kitchenReceipts[1] = receiptFor(1);
      printer.broken = true;
      build().start();
      service.enqueue(1, ReceiptType.mutfak);
      await settle();
      expect(queue.all().single.attempts, greaterThan(0));

      printer.broken = false;
      service.reprint(1, ReceiptType.mutfak);
      await settle();

      expect(queue.all().single.attempts, isZero);
      expect(queue.all().single.isPrinted, isTrue);
    });

    test('teşhis basımı kuyruğa girmez ve hatayı çağırana verir', () async {
      build().start();
      final bytes = Uint8List.fromList([0x1B, 0x40]);

      await service.printDiagnostic(bytes);
      expect(printer.written, hasLength(1));
      expect(queue.all(), isEmpty);

      // Test fişi yeniden DENENMEZ: yazıcı yoksa personel bunu hemen
      // görmeli, "eninde sonunda çıkar" davranışı burada yanlış olurdu.
      printer.broken = true;
      await expectLater(service.printDiagnostic(bytes), throwsA(anything));
      expect(queue.all(), isEmpty);
    });

    test('başarısız teşhis basımı sonraki basımları bozmaz', () async {
      // Yazma zinciri hatayla kırılırsa ondan sonraki her fiş aynı eski
      // hatayla düşerdi.
      build().start();
      printer.broken = true;
      await expectLater(
        service.printDiagnostic(Uint8List.fromList([0x00])),
        throwsA(anything),
      );

      printer.broken = false;
      await service.printDiagnostic(Uint8List.fromList([0x01]));

      expect(printer.written, hasLength(1));
    });

    test('hata alan iş sayısı ayrıca sayılır', () async {
      kitchen.kitchenReceipts[1] = receiptFor(1);
      printer.broken = true;
      build().start();

      expect(service.failedCount(), isZero);
      service.enqueue(1, ReceiptType.mutfak);
      await settle();

      // Bekleyen 1, hata alan 1: durum çubuğu ikisini ayrı gösterir çünkü
      // "yazıcı yetişemiyor" ile "kâğıt bitmiş" farklı sorunlardır.
      expect(queue.pendingCount(), 1);
      expect(service.failedCount(), 1);
    });

    test('son işler en yeniden eskiye listelenir', () async {
      kitchen
        ..kitchenReceipts[1] = receiptFor(1)
        ..kitchenReceipts[2] = receiptFor(2);
      build().start();
      service
        ..enqueue(1, ReceiptType.mutfak)
        ..enqueue(2, ReceiptType.mutfak);
      await settle();

      expect(service.recentJobs().map((job) => job.orderId), [2, 1]);
    });
  });
}
