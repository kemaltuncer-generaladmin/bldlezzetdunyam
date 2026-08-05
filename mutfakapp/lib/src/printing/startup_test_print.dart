/// Açılışta otomatik test fişi.
///
/// NEDEN: kasa sabah açıldığında yazıcının çalıştığı **kâğıt üzerinde**
/// görülmeli. Kâğıt bittiğini, kapağın açık kaldığını ya da USB'nin
/// çıktığını ilk siparişte öğrenmek geç: o sipariş basılmadan mutfağa
/// düşer ve kimse fark etmez.
///
/// ÇÖKME DÖNGÜSÜ KORUMASI: `mutfakapp.service` `Restart=always` ve
/// `RestartSec=5` ile koşuyor. Uygulama açılışta çökerse servis onu her
/// beş saniyede yeniden başlatır; korumasız her denemede bir fiş basar ve
/// rulo dakikalar içinde biter. Bu yüzden son açılış fişinin zamanı
/// saklanıyor ve [cooldown] içindeki tekrarlar atlanıyor.
///
/// Süre kasten kısa: gerçek bir yeniden başlatma (güncelleme, elektrik,
/// personelin kapatıp açması) fişi görmeli. Engellenmesi gereken tek şey
/// saniyeler içinde tekrarlanan çökme.
library;

import 'dart:typed_data';

import 'package:bld_core/escpos.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_receipt.dart';

/// İki açılış fişi arasındaki en kısa süre.
const Duration startupPrintCooldown = Duration(minutes: 3);

/// Açılış fişinin en son ne zaman basıldığı — epoch milisaniye.
const String startupPrintKey = 'kitchen_last_startup_print';

/// Son açılış fişinin zamanını tutan depo.
///
/// Arayüz olmasının sebebi `TokenStore` ile aynı: testin platform
/// eklentisi sahtelemesi gerekmesin. Buradaki mantık kalıcılığın nasıl
/// yapıldığını bilmek zorunda değil.
abstract interface class StartupPrintLog {
  Future<DateTime?> lastPrintedAt();

  Future<void> record(DateTime at);
}

/// `shared_preferences` üzerinde saklayan [StartupPrintLog].
class SharedPreferencesStartupPrintLog implements StartupPrintLog {
  SharedPreferencesStartupPrintLog({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<DateTime?> lastPrintedAt() async {
    final value = await _preferences.getInt(startupPrintKey);

    return value == null ? null : DateTime.fromMillisecondsSinceEpoch(value);
  }

  @override
  Future<void> record(DateTime at) =>
      _preferences.setInt(startupPrintKey, at.millisecondsSinceEpoch);
}

/// Açılışta test fişi basar. Basıldıysa `true` döner.
///
/// HİÇBİR HATAYI YUKARI ATMAZ — yalnızca yazıcı hatasını değil, hiçbirini.
/// Bu işlev uygulamanın açılış yolunda duruyor ve mutfak, yazıcı arızalı
/// ya da bir depo erişilemez diye sipariş göremez hâle gelemez. Durum
/// çubuğundaki yazıcı göstergesi sorunu zaten bildiriyor.
///
/// Bu yüzden `Object` yakalanıyor: `Exception` yetmiyor. Ön bellek
/// platformu kurulu değilken atılan `StateError` bir `Error`'dur ve
/// `Exception` filtresinden geçip açılışı kırıyordu.
Future<bool> printStartupTestReceipt({
  // Somut `PrintService` yerine işlevin kendisini alıyoruz: sınıf bir
  // kuyruk döngüsü ve zamanlayıcı taşıyor, testte kurmak pahalı ve
  // buradaki mantığın onunla hiç işi yok.
  required Future<void> Function(Uint8List bytes) print,
  required String devicePath,
  required DateTime now,
  ReceiptStyle style = ReceiptStyle.standard,
  StartupPrintLog? log,
  Duration cooldown = startupPrintCooldown,
}) async {
  try {
    final kayit = log ?? SharedPreferencesStartupPrintLog();

    if (await _withinCooldown(kayit, now, cooldown)) return false;

    // Damgayı BASMADAN ÖNCE yazıyoruz. Sonraya bırakılsaydı, yazma
    // sırasında çöken bir uygulama damgayı hiç yazamaz ve yeniden başlayıp
    // tekrar basardı — korumanın engellemesi gereken döngünün ta kendisi.
    await kayit.record(now);

    await print(
      buildTestReceipt(devicePath: devicePath, printedAt: now, style: style),
    );

    return true;
  } on Object {
    // Damga yazılamadıysa çökme döngüsü koruması da yok demektir; bu
    // durumda basmamak doğru olan. Basmak, korumasız bir döngüde ruloyu
    // bitirirdi.
    return false;
  }
}

Future<bool> _withinCooldown(
  StartupPrintLog log,
  DateTime now,
  Duration cooldown,
) async {
  final last = await log.lastPrintedAt();
  if (last == null) return false;

  final gecen = now.difference(last).inMilliseconds;

  // Negatif fark = sistem saati geri alınmış. Bunu "bekleme süresi
  // dolmadı" saymak, saat düzelene kadar fişi tamamen susturur; basmak
  // daha güvenli.
  return gecen >= 0 && gecen < cooldown.inMilliseconds;
}
