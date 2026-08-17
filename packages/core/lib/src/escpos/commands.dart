/// ESC/POS komut seti ve fiş oluşturucu — `docs/05-mutfakapp.md` §5.2.
///
/// Buradaki komutlar dokümandaki tablonun **birebir** karşılığıdır; tabloda
/// olmayan komut eklenmemiştir. Satır beslemesi bile `0A` tekrarıyla yapılır
/// (`ESC d n` ile değil), çünkü tabloda "satır besle" olarak yalnızca `0A`
/// geçer ve yazıcı uyumluluğu tabloya göre doğrulanmıştır.
library;

import 'dart:typed_data';

import 'pc857.dart';

/// Metin hizalaması — `ESC a n`.
enum EscPosAlign {
  left(0x00),
  center(0x01),
  right(0x02);

  const EscPosAlign(this.code);

  final int code;
}

/// Ham komut baytları.
abstract final class EscPosCommands {
  /// `ESC @` — başlat/sıfırla. Önceki işten kalan biçim ayarlarını temizler.
  static const List<int> initialize = [0x1B, 0x40];

  /// Türkçe gliflerin bastığı kod sayfası numarası: **29**.
  ///
  /// **Neden 13 değil.** `ESC t n`'deki `n` bir Unicode ya da IBM numarası
  /// değildir; yazıcının kendi kod sayfası tablosundaki **sıra numarasıdır** ve
  /// üreticiden üreticiye değişir. Doküman başlangıçta PC857'nin yaygın
  /// numarası olan 13'ü söylüyordu; sahadaki yazıcıda (`0483:5720`,
  /// `aaaait Printer`, seri `11101800002`) `ESC t 13` Türkçe baytları
  /// **boşluk** bastı — o tabloda glif yok. `n = 0..47` taraması yapıldı,
  /// Türkçe harfler yalnızca `n = 29` ile doğru çıktı (04.08.2026,
  /// `docs/05-mutfakapp.md` §5.2).
  ///
  /// Bayt düzeni yine PC857'dir; değişen tek şey seçim numarasıdır — bu yüzden
  /// [Pc857] tablosu olduğu gibi geçerlidir.
  ///
  /// Yazıcı değişirse doğru numarayı `infra/kasa/kodsayfasi-tara.sh` bulur.
  static const int turkishCodePage = 29;

  /// `ESC t n` — kod sayfası seçimi. Ardından gönderilen metin [Pc857] ile
  /// çevrilmiş olmalıdır.
  static List<int> selectCodePage(int codePage) => [0x1B, 0x74, codePage];

  /// `ESC E 1` — kalın aç.
  static const List<int> boldOn = [0x1B, 0x45, 0x01];

  /// `ESC E 0` — kalın kapa.
  static const List<int> boldOff = [0x1B, 0x45, 0x00];

  /// `GS ! 0x11` — çift boy (hem en hem boy iki katı).
  static const List<int> doubleSizeOn = [0x1D, 0x21, 0x11];

  /// `GS ! 0x00` — normal boy.
  static const List<int> doubleSizeOff = [0x1D, 0x21, 0x00];

  /// `LF` — satır besle.
  static const int lineFeed = 0x0A;

  /// `GS V B 0` — kağıt kes.
  static const List<int> cut = [0x1D, 0x56, 0x42, 0x00];

  /// `ESC a n` — hizalama.
  static List<int> align(EscPosAlign alignment) => [0x1B, 0x61, alignment.code];

  // ── QR kod (`GS ( k`) ────────────────────────────────────────────────
  //
  // Dört ayrı komut gerekiyor ve SIRASI ÖNEMLİ: model → modül boyu → hata
  // düzeltme → veriyi tampona yaz → tamponu bas. Yazıcı veriyi kendi
  // tamponunda tutuyor; "bas" komutu gelmeden hiçbir şey çıkmaz.
  //
  // `pL, pH` küçük-uçlu uzunluktur ve `cn + fn + m` baytlarını DA sayar.
  // En sık yapılan hata yalnızca veri uzunluğunu yazmak: yazıcı eksik bayt
  // bekler, sonraki komutları veri sanar ve fişin geri kalanı çöp basar.

  /// QR modelini seçer. `49` = Model 1, `50` = Model 2.
  ///
  /// Model 2 varsayılan: neredeyse tüm okuyucular destekliyor ve aynı veri
  /// için daha küçük sembol üretiyor.
  static const List<int> qrModel = [
    0x1D,
    0x28,
    0x6B,
    0x04,
    0x00,
    0x31,
    0x41,
    50,
    0x00,
  ];

  /// Modül (nokta) boyu — `1..16`.
  ///
  /// 6 seçildi: 80 mm kağıtta yaklaşık 3 cm'lik bir kare veriyor. Daha
  /// küçüğü telefon kamerasıyla loş mutfak ışığında okunmuyor, daha büyüğü
  /// fişi gereksiz uzatıyor.
  static List<int> qrModuleSize(int size) => [
    0x1D,
    0x28,
    0x6B,
    0x03,
    0x00,
    0x31,
    0x43,
    size,
  ];

  /// Hata düzeltme düzeyi — `48`=L, `49`=M, `50`=Q, `51`=H.
  ///
  /// M (%15) seçildi: termal fiş buruşuyor, ıslanıyor ve kuryenin cebinde
  /// eziliyor. L bu koşullarda okunamaz hâle geliyor; H ise sembolü
  /// gereksiz büyütüyor.
  static List<int> qrErrorCorrection(int level) => [
    0x1D,
    0x28,
    0x6B,
    0x03,
    0x00,
    0x31,
    0x45,
    level,
  ];

  /// Veriyi yazıcının QR tamponuna yazar.
  static List<int> qrStore(List<int> data) {
    // +3: `cn` (0x31), `fn` (0x50) ve `m` (0x30) baytları da uzunluğa dahil.
    final length = data.length + 3;
    return [
      0x1D,
      0x28,
      0x6B,
      length & 0xFF,
      (length >> 8) & 0xFF,
      0x31,
      0x50,
      0x30,
      ...data,
    ];
  }

  /// Tamponu basar.
  static const List<int> qrPrint = [
    0x1D,
    0x28,
    0x6B,
    0x03,
    0x00,
    0x31,
    0x51,
    0x30,
  ];

  // ── Raster görsel (`GS v 0`) ──────────────────────────────────────────
  //
  // NEDEN VAR: yerleşik QR komutu (`GS ( k`) isteğe bağlı bir ESC/POS
  // eklentisidir ve ucuz klonların bir bölümü onu sessizce yutar — hiçbir
  // hata vermez, kağıda hiçbir şey basmaz. Raster görsel ise logo basımı
  // için kullanıldığından pratikte her yazıcıda vardır. Yerleşik QR'ın
  // çalışmadığı yazıcıda QR'ı nokta nokta çizip buradan basmak tek yoldur.

  /// `GS v 0 m xL xH yL yH` başlığı.
  ///
  /// [widthBytes] satır başına **bayt** sayısıdır (piksel değil): her bayt
  /// soldan sağa 8 piksel taşır, en anlamlı bit en soldaki noktadır.
  static List<int> rasterHeader({
    required int widthBytes,
    required int height,
    int mode = 0,
  }) => [
    0x1D,
    0x76,
    0x30,
    mode,
    widthBytes & 0xFF,
    (widthBytes >> 8) & 0xFF,
    height & 0xFF,
    (height >> 8) & 0xFF,
  ];
}

/// ESC/POS bayt dizisi oluşturucu.
///
/// Yan etkisizdir: cihaza yazmaz, yalnızca bayt üretir. Cihaza yazmak
/// yazdırma kuyruğunun işidir (`docs/05` §5.4).
class EscPosBuilder {
  EscPosBuilder({
    this.columns = defaultColumns,
    this.codePage = EscPosCommands.turkishCodePage,
  }) : assert(columns > 0, 'Satır genişliği pozitif olmalı'),
       assert(codePage >= 0 && codePage <= 255, 'Kod sayfası tek bayttır');

  /// 80 mm termal yazıcı, Font A: 48 karakter (`docs/05` §1).
  static const int defaultColumns = 48;

  /// Normal boyda bir satıra sığan karakter sayısı.
  final int columns;

  /// `ESC t n` değeri. Yazıcıya göre değişir; bkz.
  /// [EscPosCommands.turkishCodePage].
  final int codePage;

  final BytesBuilder _buffer = BytesBuilder(copy: false);

  /// `ESC @` + `ESC t <codePage>`. Her fişin ilk komutu budur.
  void reset() {
    _buffer
      ..add(EscPosCommands.initialize)
      ..add(EscPosCommands.selectCodePage(codePage));
  }

  void align(EscPosAlign alignment) =>
      _buffer.add(EscPosCommands.align(alignment));

  void bold({required bool on}) =>
      _buffer.add(on ? EscPosCommands.boldOn : EscPosCommands.boldOff);

  void doubleSize({required bool on}) => _buffer.add(
    on ? EscPosCommands.doubleSizeOn : EscPosCommands.doubleSizeOff,
  );

  /// Satır sonu **eklemeden** metin basar.
  void text(String value) => _buffer.add(Pc857.encode(value));

  /// Metni basıp satır besler. Boş çağrı tek satır boşluk bırakır.
  void line([String value = '']) {
    if (value.isNotEmpty) text(value);
    _buffer.addByte(EscPosCommands.lineFeed);
  }

  /// [count] adet boş satır besler.
  void feed([int count = 1]) {
    for (var i = 0; i < count; i++) {
      _buffer.addByte(EscPosCommands.lineFeed);
    }
  }

  /// Satır genişliğinde ayraç çizgisi.
  void rule([String character = '-']) => line(character * columns);

  /// Kağıdı keser. Kesiciden önce beslenmesi gereken kağıt çağıranın işidir.
  void cut() => _buffer.add(EscPosCommands.cut);

  /// Ham bayt ekler — komut tablosunda olmayan bir şeye ihtiyaç duyan
  /// (ör. yazıcıya özel) durumlar için tek kaçış kapısı.
  void raw(List<int> bytes) => _buffer.add(bytes);

  /// QR kod basar.
  ///
  /// [data] **ASCII** olmalıdır. Türkçe karakter içeren bir metin PC857 ile
  /// kodlanır ve okuyucu bunu çözemez; bu yüzden burada `Pc857.encode`
  /// KULLANILMIYOR, bayta doğrudan çevriliyor. Çağıran zaten bir URL
  /// geçiriyor.
  void qr(
    String data, {
    int moduleSize = defaultQrModuleSize,
    int errorCorrection = qrErrorCorrectionM,
  }) {
    _buffer
      ..add(EscPosCommands.qrModel)
      ..add(EscPosCommands.qrModuleSize(moduleSize))
      ..add(EscPosCommands.qrErrorCorrection(errorCorrection))
      ..add(EscPosCommands.qrStore(data.codeUnits))
      ..add(EscPosCommands.qrPrint);
  }

  /// Tek renkli bir nokta ızgarasını raster görsel olarak basar.
  ///
  /// [pixels] satır satır dizilmiş, `true` = siyah nokta olan bir ızgaradır;
  /// genişliği [width] belirler. Genişlik 8'in katı değilse satırın sonu
  /// beyazla tamamlanır — yazıcı eksik bit kabul etmez, satır kayarsa
  /// görselin tamamı çapraz çizgiye döner.
  void bitImage(List<bool> pixels, {required int width}) {
    assert(width > 0, 'Görsel genişliği pozitif olmalı');
    assert(
      pixels.length % width == 0,
      'Nokta sayısı satır genişliğinin katı olmalı',
    );

    final widthBytes = (width + 7) ~/ 8;
    final height = pixels.length ~/ width;
    final data = Uint8List(widthBytes * height);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (!pixels[y * width + x]) continue;
        // En anlamlı bit soldaki nokta: `7 - (x % 8)`.
        data[y * widthBytes + (x >> 3)] |= 0x80 >> (x & 7);
      }
    }

    _buffer
      ..add(EscPosCommands.rasterHeader(widthBytes: widthBytes, height: height))
      ..add(data);
  }

  /// Gerekçesi [EscPosCommands.qrModuleSize] üzerinde.
  static const int defaultQrModuleSize = 6;

  /// Gerekçesi [EscPosCommands.qrErrorCorrection] üzerinde.
  static const int qrErrorCorrectionM = 49;

  Uint8List build() => _buffer.toBytes();
}
