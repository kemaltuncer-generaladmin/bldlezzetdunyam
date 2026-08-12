/// `K-04` — kalıcı yazdırma kuyruğu (`docs/05-mutfakapp.md` §5.4).
///
/// **Neden SQLite ve neden veritabanı düzeyinde tekillik:** mutfakta iki kez
/// basılan fiş, iki kez hazırlanan yemek demektir. İdempotentliği yalnızca
/// uygulama mantığına bırakmak yetmez — uygulama çöker, iki tetik aynı anda
/// çalışır, yeniden başlatma sırasında liste baştan gelir. `UNIQUE(order_id,
/// type)` kısıtı bu üç durumun üçünü de tek yerde kapatır: ikinci kayıt
/// denemesi veritabanı tarafından sessizce reddedilir.
library;

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:bld_api_client/bld_api_client.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

import 'print_job.dart';

/// `print_queue` tablosunu yöneten kalıcı kuyruk.
class PrintQueue {
  PrintQueue._(this._db, DateTime Function()? clock)
    : _now = clock ?? (() => DateTime.now().toUtc());

  /// [path] dosyasını açar; yoksa oluşturur. Bellek içi kuyruk için
  /// [inMemory] kullanılır (testler).
  ///
  /// [clock] enjekte edilebilir — `PrintService` ile aynı desen. Elle
  /// yeniden basımda açılan yeni satırın zamanı buradan geliyor ve testin
  /// gerçek saate bağlı kalmaması gerekiyor.
  factory PrintQueue.open(String path, {DateTime Function()? clock}) {
    _prepareLibrary();
    return PrintQueue._(sqlite3.open(path), clock).._createSchema();
  }

  factory PrintQueue.inMemory({DateTime Function()? clock}) {
    _prepareLibrary();
    return PrintQueue._(sqlite3.openInMemory(), clock).._createSchema();
  }

  final Database _db;
  final DateTime Function() _now;

  static bool _libraryPrepared = false;

  /// Ubuntu'da yalnızca `libsqlite3.so.0` kuruludur; geliştirme paketi
  /// (`libsqlite3-dev`) olmadan `libsqlite3.so` bağı bulunmaz ve paketin
  /// varsayılan açılışı başarısız olur. Kasada `-dev` paketi olmayacağı için
  /// sürümlü adı da deniyoruz.
  static void _prepareLibrary() {
    if (_libraryPrepared) return;
    _libraryPrepared = true;
    if (!Platform.isLinux) return;

    open.overrideFor(OperatingSystem.linux, () {
      for (final name in const [
        'libsqlite3.so',
        'libsqlite3.so.0',
        'libsqlite3.so.3',
      ]) {
        try {
          return DynamicLibrary.open(name);
        } on ArgumentError {
          continue;
        }
      }
      throw StateError(
        'libsqlite3 bulunamadı. Kasada `libsqlite3-0` paketi kurulu olmalı.',
      );
    });
  }

  void _createSchema() {
    _db
      ..execute('PRAGMA journal_mode = WAL')
      ..execute('''
        CREATE TABLE IF NOT EXISTS print_queue (
          id         INTEGER PRIMARY KEY AUTOINCREMENT,
          order_id   INTEGER NOT NULL,
          type       TEXT    NOT NULL,
          revision   INTEGER NOT NULL DEFAULT 0,
          payload    BLOB,
          attempts   INTEGER NOT NULL DEFAULT 0,
          created_at TEXT    NOT NULL,
          printed_at TEXT,
          UNIQUE (order_id, type, revision)
        )
      ''')
      // Sıradaki işi bulmak her döngüde yapılır; tarama yerine dizin.
      ..execute('''
        CREATE INDEX IF NOT EXISTS print_queue_pending
          ON print_queue (printed_at, id)
      ''');

    _migrateRevisionColumn();
  }

  /// K-14 göçü: eski kasalarda `revision` sütunu ve yeni tekillik yok.
  ///
  /// NEDEN GÖÇ GEREKİYOR: tekillik `(order_id, type)` idi; sipariş
  /// düzenlendiğinde revize fiş **sessizce yutuluyordu** (`INSERT OR
  /// IGNORE`) ve mutfak eski adedi hazırlamaya devam ediyordu.
  ///
  /// NEDEN TABLO YENİDEN KURULUYOR: SQLite `ALTER TABLE` ile tekilliği
  /// değiştiremiyor. Veri kopyalanıyor — kuyrukta bekleyen fiş kaybolmaz.
  void _migrateRevisionColumn() {
    final columns = _db
        .select('PRAGMA table_info(print_queue)')
        .map((row) => row['name'] as String)
        .toSet();

    if (columns.contains('revision')) return;

    _db
      ..execute('BEGIN')
      ..execute('ALTER TABLE print_queue RENAME TO print_queue_eski')
      ..execute('''
        CREATE TABLE print_queue (
          id         INTEGER PRIMARY KEY AUTOINCREMENT,
          order_id   INTEGER NOT NULL,
          type       TEXT    NOT NULL,
          revision   INTEGER NOT NULL DEFAULT 0,
          payload    BLOB,
          attempts   INTEGER NOT NULL DEFAULT 0,
          created_at TEXT    NOT NULL,
          printed_at TEXT,
          UNIQUE (order_id, type, revision)
        )
      ''')
      ..execute('''
        INSERT INTO print_queue
          (id, order_id, type, revision, payload, attempts, created_at, printed_at)
        SELECT id, order_id, type, 0, payload, attempts, created_at, printed_at
        FROM print_queue_eski
      ''')
      ..execute('DROP TABLE print_queue_eski')
      ..execute('''
        CREATE INDEX IF NOT EXISTS print_queue_pending
          ON print_queue (printed_at, id)
      ''')
      ..execute('COMMIT');
  }

  /// İş ekler. Aynı `(orderId, type, revision)` üçlüsü zaten varsa
  /// **hiçbir şey yapmaz** ve `false` döner — fişin ikinci kez basılmasını
  /// engelleyen kural budur.
  ///
  /// [revision] K-14 ile eklendi: sipariş düzenlendiğinde revize fiş yeni
  /// bir satır olarak girer. Revizyon tekilliğe dahil olmasaydı, revize
  /// fiş sessizce yutulur ve mutfak eski adedi hazırlamaya devam ederdi.
  bool enqueue({
    required int orderId,
    required ReceiptType type,
    required DateTime createdAt,
    Uint8List? payload,
    int revision = 0,
  }) {
    _db.execute(
      '''
      INSERT OR IGNORE INTO print_queue
        (order_id, type, revision, payload, created_at)
      VALUES (?, ?, ?, ?, ?)
      ''',
      [
        orderId,
        type.wireName,
        revision,
        payload,
        createdAt.toUtc().toIso8601String(),
      ],
    );
    return _db.updatedRows > 0;
  }

  /// Bir siparişin ESKİMİŞ, henüz basılmamış fişlerini kuyruktan düşürür.
  ///
  /// ## Neden gerekli
  ///
  /// Sipariş düzenlendiğinde tetikleyici yeni revizyon için yeni bir iş
  /// ekliyor, ama eski revizyonun işi kuyrukta duruyordu. Yazıcı bir süre
  /// kapalı kalırsa (kâğıt bitti, kablo çıktı) ya da düzenleme hızlı
  /// gelirse, kuyruk açıldığında ÖNCE eski fiş basılıyordu: mutfak iki
  /// kâğıt alıyor ve hangisinin güncel olduğunu kâğıda bakarak
  /// anlayamıyordu.
  ///
  /// Kural: **her aşamada yalnız en güncel fiş çıkar.** Basılmış işlere
  /// dokunulmuyor — onlar olmuş bitmiş bir olayın kaydı ve sunucudaki
  /// `ack` de onları görmüş durumda.
  ///
  /// [keepRevision] KORUNAN revizyondur, silinen değil: çağıran taraf "şu
  /// an geçerli olan bu" diyor ve ondan küçük her şey düşüyor. Eşitler
  /// kalıyor, yoksa yeni eklenen işi kendimiz silerdik.
  ///
  /// Tip bazında çalışıyor: müşteri fişi revizyonda yeniden basılmıyor
  /// (`PrintTriggers`), yani onun eski işi de düşürülmemeli — düşürülseydi
  /// hiç basılmamış bir müşteri fişi sessizce kaybolurdu.
  int dropSuperseded({
    required int orderId,
    required ReceiptType type,
    required int keepRevision,
  }) {
    _db.execute(
      '''
      DELETE FROM print_queue
      WHERE order_id = ?
        AND type = ?
        AND revision < ?
        AND printed_at IS NULL
      ''',
      [orderId, type.wireName, keepRevision],
    );
    return _db.updatedRows;
  }

  /// Basılmayı bekleyen en eski iş; yoksa `null`.
  ///
  /// Sıra `id`'ye göredir: siparişler mutfağa geldikleri sırayla basılır.
  PrintJob? nextPending() {
    final rows = _db.select(
      'SELECT * FROM print_queue WHERE printed_at IS NULL ORDER BY id LIMIT 1',
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  /// Bekleyen iş sayısı — durum çubuğundaki "Kuyruk: n".
  int pendingCount() =>
      _db
              .select(
                'SELECT COUNT(*) AS c FROM print_queue WHERE printed_at IS NULL',
              )
              .first['c']
          as int;

  /// Fiş verisi sunucudan alındıktan sonra baytları kalıcılaştırır.
  ///
  /// Böylece bir sonraki denemede ağ gerekmez ve fişin içeriği olayın olduğu
  /// andaki hâliyle donar.
  void savePayload(int id, Uint8List payload) => _db.execute(
    'UPDATE print_queue SET payload = ? WHERE id = ?',
    [payload, id],
  );

  void incrementAttempts(int id) => _db.execute(
    'UPDATE print_queue SET attempts = attempts + 1 WHERE id = ?',
    [id],
  );

  void markPrinted(int id, DateTime printedAt) => _db.execute(
    'UPDATE print_queue SET printed_at = ? WHERE id = ?',
    [printedAt.toUtc().toIso8601String(), id],
  );

  /// Basılmış işleri temizler. Kuyruk tablosu denetim kaydı değildir; sunucu
  /// tarafındaki `ack` o işi görüyor.
  int purgePrinted({required DateTime olderThan}) {
    _db.execute(
      'DELETE FROM print_queue WHERE printed_at IS NOT NULL AND printed_at < ?',
      [olderThan.toUtc().toIso8601String()],
    );
    return _db.updatedRows;
  }

  /// Yalnızca testler ve teşhis için: tüm satırlar.
  List<PrintJob> all() => _db
      .select('SELECT * FROM print_queue ORDER BY id')
      .map(_fromRow)
      .toList(growable: false);

  /// Ayarlar ekranındaki kuyruk listesi: en yeni iş en üstte.
  ///
  /// Basılmışlar da döner — personelin görmek istediği şey "hangi fiş
  /// çıkmadı" kadar "bu siparişin fişi çıkmış mıydı" sorusudur da.
  List<PrintJob> recent({int limit = 50}) => _db
      .select('SELECT * FROM print_queue ORDER BY id DESC LIMIT ?', [limit])
      .map(_fromRow)
      .toList(growable: false);

  /// Bekleyen ama en az bir kez başarısız olmuş iş sayısı.
  ///
  /// "Kuyruk: 3" ile "Kuyruk: 3, hepsi hata veriyor" mutfakta çok farklı iki
  /// durumdur: ilki yazıcı sırayı yetiştiremiyor, ikincisi kâğıt bitmiş.
  int failedCount() =>
      _db
              .select(
                'SELECT COUNT(*) AS c FROM print_queue '
                'WHERE printed_at IS NULL AND attempts > 0',
              )
              .first['c']
          as int;

  /// Basılamamış ve vazgeçilmiş işleri kuyruktan düşürür.
  ///
  /// YALNIZCA HATA ALMIŞ işler silinir (`attempts > 0`); henüz denenmemiş
  /// bekleyenler kalır. Hepsini silmek, yazıcı sırayı yetiştiremediği için
  /// bekleyen sağlam fişleri de çöpe atardı.
  ///
  /// Bu bir SON ÇARE: kâğıt bittiği için biriken on fişi tek tek yeniden
  /// bastırmak yerine yönetici hepsini düşürüp baştan başlayabilir.
  /// Silinen fiş geri gelmez.
  int clearFailed() {
    _db.execute(
      'DELETE FROM print_queue WHERE printed_at IS NULL AND attempts > 0',
    );

    return _db.updatedRows;
  }

  /// Bir fişi elle yeniden bastırmak için işi tekrar bekler hâle getirir
  /// (`docs/05-mutfakapp.md` §5.4 "Yeniden bas").
  ///
  /// `payload` KORUNUR: fişin içeriği olayın olduğu andaki hâliyle donmuştur
  /// ve yeniden basım aynı kâğıdı üretmelidir — ayrıca ağ yokken de çalışır.
  /// Deneme sayacı sıfırlanır; eski başarısızlıklar yeni denemeyi geri
  /// çekilmeye sokmasın.
  ///
  /// İş hiç yoksa (bir haftalık temizlik silmişse) yenisi açılır; bu durumda
  /// fiş verisi sunucudan yeniden çekilir.
  ///
  /// ## YALNIZ TEK SATIR — revizyon körlüğü hatası (K-20)
  ///
  /// Eski sorgu `(order_id, type)` eşleştiriyordu; ne revizyon süzgeci ne de
  /// satır sınırı vardı. Düzenlenmiş bir siparişte o tipin **her** revizyon
  /// satırı basılmamışa dönüyor ve "Yeniden bas" tek dokunuşta hem eski hem
  /// yeni sürümü kâğıda döküyordu — tam da `dropSuperseded`'in engellemek
  /// için yazıldığı hata.
  ///
  /// [revision] verilmezse **en güncel** satır seçilir; personel karttan
  /// "yeniden bas" derken hangi sürümü istediğini söylemiyor, kastettiği
  /// her zaman elindeki güncel siparişin fişi.
  ///
  /// `UPDATE ... LIMIT 1` KULLANILMIYOR: o sözdizimi SQLite'ın isteğe bağlı
  /// `SQLITE_ENABLE_UPDATE_DELETE_LIMIT` derleme bayrağını gerektiriyor ve
  /// uygulama Ubuntu'nun sistem `libsqlite3`'ünü yüklüyor — orada bayrağın
  /// açık olduğu garanti değil. Alt sorgu her yapılandırmada çalışır.
  bool requeue({
    required int orderId,
    required ReceiptType type,
    int? revision,
  }) {
    _db.execute(
      '''
      UPDATE print_queue SET printed_at = NULL, attempts = 0
      WHERE id = (
        SELECT id FROM print_queue
        WHERE order_id = ? AND type = ?
          AND (? IS NULL OR revision = ?)
        ORDER BY revision DESC, id DESC
        LIMIT 1
      )
      ''',
      [orderId, type.wireName, revision, revision],
    );
    if (_db.updatedRows > 0) return true;

    // ÇAĞIRANIN REVİZYONUYLA AÇILIYOR, `0` ile değil: düzenlenmiş bir
    // siparişte sıfırıncı revizyonla açılan satır, bir sonraki otomatik
    // tetiğin `dropSuperseded` çağrısında "eskimiş" sayılıp silinirdi ve
    // elle istenen fiş sessizce kaybolurdu.
    return enqueue(
      orderId: orderId,
      type: type,
      revision: revision ?? 0,
      createdAt: _now(),
    );
  }

  void close() => _db.dispose();

  static PrintJob _fromRow(Row row) => PrintJob(
    id: row['id'] as int,
    orderId: row['order_id'] as int,
    revision: (row['revision'] as int?) ?? 0,
    type:
        ReceiptType.tryParse(row['type'] as String) ??
        // Tabloya sözleşme dışı bir tip girmesi imkânsıza yakın; girerse
        // mutfak fişi varsaymak, basmamaktan iyidir.
        ReceiptType.mutfak,
    payload: row['payload'] as Uint8List?,
    attempts: row['attempts'] as int,
    createdAt: DateTime.parse(row['created_at'] as String),
    printedAt: row['printed_at'] == null
        ? null
        : DateTime.parse(row['printed_at'] as String),
  );
}
