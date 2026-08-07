// Yazıcı teşhis fişi — hangi QR yönteminin bu yazıcıda çalıştığını bulur.
//
// NEDEN VAR: müşteri fişinde QR çıkmıyor. Veri yolu (sunucu → KDS →
// ESC/POS) kodda eksiksiz ve golden test QR baytlarının fişte bulunduğunu
// doğruluyor. Geriye iki olasılık kalıyor:
//
//   1. Siparişin adresinde harita iğnesi yok — QR basılacak veri hiç yok.
//   2. Yazıcı yerleşik QR komutunu (`GS ( k`) yok sayıyor. Bu komut ESC/POS'un
//      isteğe bağlı bir eklentisidir; desteklemeyen yazıcı hata vermez,
//      sessizce hiçbir şey basmaz.
//
// Bu fiş ikinci olasılığı kesin olarak ayırır: aynı kağıda hem yerleşik QR
// (iki ayrı model/boy ile) hem de raster nokta görseli basar. Hangi bölümün
// kağıtta göründüğü hangi yolun çalıştığını söyler.
//
// KULLANIM:
//   cd mutfakapp && dart run tool/yazici_teshis.dart [/dev/usb/lp0]
//
// Aygıt verilmezse `/dev/usb/lp0` denenir (`docs/05-mutfakapp.md` §5.1).
import 'dart:io';

import 'package:bld_core/escpos.dart';

/// Sahadaki yazıcı: `0483:5720`, 80 mm, Font A'da 48 sütun.
const int _columns = 48;

/// QR'a gömülen örnek bağlantı — gerçek fişteki `mapUrl` ile aynı biçimde.
/// Okutulunca Konya merkezinde bir nokta açmalı.
const String _sampleUrl = 'https://www.google.com/maps?q=37.8746000,32.4932000';

void main(List<String> args) {
  final device = args.isEmpty ? '/dev/usb/lp0' : args.first;
  final builder = EscPosBuilder(columns: _columns)..reset();

  _heading(builder, 'YAZICI TESHIS FISI');
  builder
    ..line('Her bolumun altinda ne gorunmesi')
    ..line('gerektigi yaziyor. Bos kalan bolum,')
    ..line('yazicinin o komutu desteklemedigi')
    ..line('anlamina gelir.')
    ..rule();

  // ── A: yerleşik QR, üretimdeki ayarların birebir aynısı.
  _heading(builder, 'A - YERLESIK QR (Model 2, modul 6)');
  builder.align(EscPosAlign.center);
  builder.qr(_sampleUrl);
  builder
    ..align(EscPosAlign.left)
    ..line('Beklenen: ~3 cm kare QR.')
    ..line('Uretimde kullanilan ayar budur.')
    ..rule();

  // ── B: aynı komut, farklı model ve daha küçük modül. Yazıcı Model 2'yi
  //    tanımayıp Model 1'i tanıyorsa ayrımı burası gösterir.
  _heading(builder, 'B - YERLESIK QR (Model 1, modul 4)');
  builder
    ..align(EscPosAlign.center)
    ..raw(const [0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 49, 0x00])
    ..raw(EscPosCommands.qrModuleSize(4))
    ..raw(EscPosCommands.qrErrorCorrection(EscPosBuilder.qrErrorCorrectionM))
    ..raw(EscPosCommands.qrStore(_sampleUrl.codeUnits))
    ..raw(EscPosCommands.qrPrint)
    ..align(EscPosAlign.left)
    ..line('Beklenen: ~2 cm kare QR.')
    ..line('A bos, B doluysa model destegi sinirli.')
    ..rule();

  // ── C: raster görsel. QR ile ilgisi yok; yalnızca "bu yazıcı nokta
  //    görseli basabiliyor mu?" sorusunu yanıtlar. Basabiliyorsa QR'ı
  //    nokta nokta çizip basmak kesin çözümdür.
  _heading(builder, 'C - RASTER GORSEL (GS v 0)');
  builder
    ..align(EscPosAlign.center)
    ..bitImage(_testPattern(), width: _patternWidth)
    ..align(EscPosAlign.left)
    ..line('Beklenen: icinde capraz olan')
    ..line('cerceveli siyah kare.')
    ..rule();

  builder
    ..line('A veya B doluysa: yerlesik QR calisiyor,')
    ..line('sorun siparis verisinde (igne yok).')
    ..line('Ikisi de bos, C doluysa: QR gorsel')
    ..line('olarak basilmali.')
    ..feed(4)
    ..cut();

  final bytes = builder.build();
  stdout
    ..writeln('QR bağlantısı : $_sampleUrl')
    ..writeln('Bayt sayısı   : ${bytes.length}')
    ..writeln('Aygıt         : $device');

  final file = File(device);
  // `flush: false` — karakter aygıtında fsync geçersiz (printer_device.dart).
  file.writeAsBytesSync(bytes, mode: FileMode.writeOnlyAppend, flush: false);
  stdout.writeln('Teşhis fişi gönderildi.');
}

void _heading(EscPosBuilder builder, String title) {
  builder
    ..bold(on: true)
    ..line(title)
    ..bold(on: false);
}

/// Görselin genişliği — 8'in katı seçildi ki dolgu davranışı teşhisi
/// gölgelemesin; burada aranan cevap "raster çalışıyor mu", "dolgu doğru mu"
/// değil.
const int _patternWidth = 128;
const int _patternHeight = 128;

/// Çerçeve + çapraz: her ikisi de kaymayı ele verir. Düz siyah kare
/// basılsaydı satır genişliği yanlış olsa bile "çalışıyor" görünürdü.
List<bool> _testPattern() {
  final pixels = List<bool>.filled(_patternWidth * _patternHeight, false);

  for (var y = 0; y < _patternHeight; y++) {
    for (var x = 0; x < _patternWidth; x++) {
      final onBorder = x < 8 ||
          y < 8 ||
          x >= _patternWidth - 8 ||
          y >= _patternHeight - 8;
      final onDiagonal = (x - y).abs() < 6;
      pixels[y * _patternWidth + x] = onBorder || onDiagonal;
    }
  }

  return pixels;
}
