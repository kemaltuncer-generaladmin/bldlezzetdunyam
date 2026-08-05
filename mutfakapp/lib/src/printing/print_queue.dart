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
  PrintQueue._(this._db);

  /// [path] dosyasını açar; yoksa oluşturur. Bellek içi kuyruk için
  /// [inMemory] kullanılır (testler).
  factory PrintQueue.open(String path) {
    _prepareLibrary();
    return PrintQueue._(sqlite3.open(path)).._createSchema();
  }

  factory PrintQueue.inMemory() {
    _prepareLibrary();
    return PrintQueue._(sqlite3.openInMemory()).._createSchema();
  }

  final Database _db;

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
          payload    BLOB,
          attempts   INTEGER NOT NULL DEFAULT 0,
          created_at TEXT    NOT NULL,
          printed_at TEXT,
          UNIQUE (order_id, type)
        )
      ''')
      // Sıradaki işi bulmak her döngüde yapılır; tarama yerine dizin.
      ..execute('''
        CREATE INDEX IF NOT EXISTS print_queue_pending
          ON print_queue (printed_at, id)
      ''');
  }

  /// İş ekler. Aynı `(orderId, type)` çifti zaten varsa **hiçbir şey yapmaz**
  /// ve `false` döner — fişin ikinci kez basılmasını engelleyen kural budur.
  bool enqueue({
    required int orderId,
    required ReceiptType type,
    required DateTime createdAt,
    Uint8List? payload,
  }) {
    _db.execute(
      '''
      INSERT OR IGNORE INTO print_queue (order_id, type, payload, created_at)
      VALUES (?, ?, ?, ?)
      ''',
      [orderId, type.wireName, payload, createdAt.toUtc().toIso8601String()],
    );
    return _db.updatedRows > 0;
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
  bool requeue({required int orderId, required ReceiptType type}) {
    _db.execute(
      'UPDATE print_queue SET printed_at = NULL, attempts = 0 '
      'WHERE order_id = ? AND type = ?',
      [orderId, type.wireName],
    );
    if (_db.updatedRows > 0) return true;

    return enqueue(orderId: orderId, type: type, createdAt: DateTime.now());
  }

  void close() => _db.dispose();

  static PrintJob _fromRow(Row row) => PrintJob(
    id: row['id'] as int,
    orderId: row['order_id'] as int,
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
