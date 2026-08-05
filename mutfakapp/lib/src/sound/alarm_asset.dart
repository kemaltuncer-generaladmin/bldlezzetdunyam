/// Alarm sesini diske çıkaran yardımcı.
///
/// AYRI DOSYADA olmasının sebebi: `AlarmPlayer` Flutter bilmek zorunda
/// değil ve bilmemeli. `rootBundle` bir Flutter motoru gerektiriyor;
/// çalar mantığını ona bağlamak, sesi düz Dart'ta ya da motor kurmadan
/// sınamayı imkânsız kılardı.
library;

import 'dart:io';

import 'package:flutter/services.dart';

/// Varlığı geçici bir dosyaya kopyalar ve yolunu döner.
///
/// Sistem oynatıcısı dosya yolu ister; Flutter varlıkları ise paketin
/// içindedir. Paketleme biçimine bağlı bir yol tahmin etmek yerine
/// (`data/flutter_assets/...`) varlığı okuyup diske yazıyoruz — bu, hem
/// geliştirmede hem kurulu sürümde aynı şekilde çalışır.
///
/// Dosya zaten doğru boyuttaysa yeniden yazılmaz: alarm her çalışmada
/// 675 KB'ı diske basmamalı.
Future<String> copyAlarmAssetToTempFile(String assetPath) async {
  final bytes = await rootBundle.load(assetPath);
  final file = File(
    '${Directory.systemTemp.path}/bld_${assetPath.split('/').last}',
  );

  if (!file.existsSync() || file.lengthSync() != bytes.lengthInBytes) {
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
  }

  return file.path;
}
