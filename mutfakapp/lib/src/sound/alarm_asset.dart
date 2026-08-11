/// Alarm sesini diske çıkaran yardımcı.
///
/// AYRI DOSYADA olmasının sebebi: `AlarmPlayer` Flutter bilmek zorunda
/// değil ve bilmemeli. `rootBundle` bir Flutter motoru gerektiriyor;
/// çalar mantığını ona bağlamak, sesi düz Dart'ta ya da motor kurmadan
/// sınamayı imkânsız kılardı.
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Ses dosyalarının çıkarıldığı klasörün son bilinen yolu — tanılama için.
String? lastSoundDirectory;

/// Varlığı diske kopyalar ve yolunu döner.
///
/// Sistem oynatıcısı dosya yolu ister; Flutter varlıkları ise paketin
/// içindedir. Paketleme biçimine bağlı bir yol tahmin etmek yerine
/// (`data/flutter_assets/...`) varlığı okuyup diske yazıyoruz — bu, hem
/// geliştirmede hem kurulu sürümde aynı şekilde çalışır.
///
/// NEDEN `/tmp` DEĞİL (11.08.2026): kasa `mutfakapp.service` altında
/// çalışıyor. systemd birimi `PrivateTmp=true` ile açılırsa uygulamanın
/// gördüğü `/tmp` kendi özel alanıdır; disk dolduğunda ya da `/tmp`
/// `noexec`/salt-okunur bağlandığında yazma sessizce patlar ve alarm
/// hiç çalmaz. Uygulama destek klasörü (`~/.local/share/...`) kalıcı ve
/// bize ait. `/tmp` yalnızca yedek yol olarak duruyor.
///
/// Dosya zaten doğru boyuttaysa yeniden yazılmaz: alarm her çalışmada
/// 675 KB'ı diske basmamalı.
Future<String> copyAlarmAsset(String assetPath) async {
  final bytes = await rootBundle.load(assetPath);
  final name = assetPath.split('/').last;

  final file = await _target(name);
  lastSoundDirectory = file.parent.path;

  if (!file.existsSync() || file.lengthSync() != bytes.lengthInBytes) {
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
  }

  return file.path;
}

/// Eski ad — çağrı yerleri geçene kadar duruyor.
@Deprecated('copyAlarmAsset kullanın; hedef klasör /tmp değil.')
Future<String> copyAlarmAssetToTempFile(String assetPath) =>
    copyAlarmAsset(assetPath);

Future<File> _target(String name) async {
  try {
    final support = await getApplicationSupportDirectory();
    return File('${support.path}/sounds/$name');
  } on Object {
    // Destek klasörü alınamıyorsa (platform kanalı yok, test ortamı)
    // sessizce `/tmp`'ye düşüyoruz — sesi hiç çalmamaktan iyidir.
    return File('${Directory.systemTemp.path}/bld_$name');
  }
}
