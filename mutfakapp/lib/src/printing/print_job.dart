/// Yazdırma kuyruğundaki tek iş — `docs/05-mutfakapp.md` §5.4.
library;

import 'dart:typed_data';

import 'package:bld_api_client/bld_api_client.dart';

/// Kuyruk satırı.
///
/// İş kimliği `(orderId, type)` çiftidir; [id] yalnızca satır numarasıdır.
class PrintJob {
  const PrintJob({
    required this.id,
    required this.orderId,
    required this.type,
    required this.attempts,
    required this.createdAt,
    this.payload,
    this.printedAt,
  });

  final int id;
  final int orderId;
  final ReceiptType type;

  /// Basılacak ESC/POS baytları.
  ///
  /// İş **önce** kaydedilir, fiş verisi **sonra** çekilir: sipariş düştüğü an
  /// uygulama çökerse ya da ağ giderse fişin basılması gerektiği bilgisi
  /// diskte durur. `null` ise kuyruk işçisi önce sunucudan fiş verisini alıp
  /// bu alanı doldurur.
  final Uint8List? payload;

  /// Kaç kez denendi. Geri çekilme süresi buna bağlıdır.
  final int attempts;

  final DateTime createdAt;

  /// Doluysa iş bitmiştir; bir daha basılmaz.
  final DateTime? printedAt;

  bool get isPrinted => printedAt != null;
}
