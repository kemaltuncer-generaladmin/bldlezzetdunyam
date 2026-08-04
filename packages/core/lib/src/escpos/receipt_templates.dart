/// Fiş şablonları — `docs/05-mutfakapp.md` §5.3.
///
/// İki şablon vardır: [buildKitchenReceipt] ve [buildCustomerReceipt]. Her ikisi
/// de **saf fonksiyondur**: aynı girdi her zaman aynı baytları verir, saat
/// okumaz, cihaza yazmaz, istisna atmaz. Golden testlerin dayanağı budur.
library;

import 'dart:typed_data';

import '../delivery_type.dart';
import '../money.dart';
import '../turkish_time.dart';
import 'commands.dart';
import 'receipt_data.dart';
import 'turkish_case.dart';

/// Fişin biçim ayarları.
///
/// Kağıt genişliği ve işletme adı üretim ortamına göre değişebildiği için
/// şablonlara gömülmez.
class ReceiptStyle {
  const ReceiptStyle({
    this.columns = EscPosBuilder.defaultColumns,
    this.codePage = EscPosCommands.turkishCodePage,
    this.businessName = 'Benim Lezzet Dünyam',
    this.footerLines = const <String>[
      'Bu belge bilgi fişidir,',
      'mali değeri yoktur.',
    ],
    this.feedBeforeCut = 4,
  }) : assert(columns >= 24, 'Fiş en az 24 karakter genişliğinde olmalı');

  static const ReceiptStyle standard = ReceiptStyle();

  /// Normal boyda satır genişliği. Çift boyda yarısı geçerlidir.
  final int columns;

  /// `ESC t n` kod sayfası numarası. Yazıcı değişirse ayarlardan güncellenir;
  /// doğru değeri `infra/kasa/kodsayfasi-tara.sh` bulur.
  final int codePage;

  /// Müşteri fişinin başlığı.
  final String businessName;

  /// Müşteri fişinin dip notu. Mali belge olmadığı yasal olarak belirtilir.
  final List<String> footerLines;

  /// Kesiciden önce beslenecek satır sayısı — kesim hattı yazı kafasının
  /// üstünde olduğu için son satırlar beslenmezse kesilir.
  final int feedBeforeCut;

  /// Çift boy metnin sığdığı karakter sayısı.
  int get doubleColumns => columns ~/ 2;
}

/// Mutfak fişi: fiyatsız, iri punto, hazırlayan personel için.
Uint8List buildKitchenReceipt(
  KitchenReceiptData data, {
  ReceiptStyle style = ReceiptStyle.standard,
}) {
  final builder =
      EscPosBuilder(columns: style.columns, codePage: style.codePage)
        ..reset()
        ..align(EscPosAlign.center);

  // ── Başlık: teslimat tipi en iri metin. Personelin ilk gördüğü şey
  //    siparişin adrese mi gideceği, gel-al mı olduğudur.
  final deliveryLabel = TurkishCase.toUpperCase(
    deliveryTypeLabelsTr[data.deliveryType]!,
  );
  builder
    ..doubleSize(on: true)
    ..bold(on: true);
  for (final line in _wrap('*** $deliveryLabel ***', style.doubleColumns)) {
    builder.line(line);
  }
  builder
    ..doubleSize(on: false)
    ..line(TurkishCase.toUpperCase('Sipariş ${data.orderNumber}'))
    ..bold(on: false)
    ..line(TurkishTime.dateTime(data.printedAt));

  if (data.requestedAt != null) {
    builder
      ..bold(on: true)
      ..line('Teslim: ${TurkishTime.shortDateTime(data.requestedAt!)}')
      ..bold(on: false);
  }

  builder
    ..align(EscPosAlign.left)
    ..rule();

  // ── Kalemler: adet ve ad çift boy, seçenek ve not normal boy.
  for (var i = 0; i < data.lines.length; i++) {
    if (i > 0) builder.feed();
    _writeKitchenLine(builder, data.lines[i], style);
  }

  builder.rule();

  if (_hasText(data.customerNote)) {
    builder.bold(on: true);
    for (final line in _wrap(
      'NOT: ${data.customerNote!.trim()}',
      style.columns,
    )) {
      builder.line(line);
    }
    builder.bold(on: false);
  }

  return _finish(builder, style);
}

/// Müşteri fişi: fiyatlı; adrese gönderimde adresli, gel-al'da `GEL-AL` yazar.
Uint8List buildCustomerReceipt(
  CustomerReceiptData data, {
  ReceiptStyle style = ReceiptStyle.standard,
}) {
  final builder =
      EscPosBuilder(columns: style.columns, codePage: style.codePage)
        ..reset()
        ..align(EscPosAlign.center)
        ..doubleSize(on: true)
        ..bold(on: true);

  for (final line in _wrap(
    TurkishCase.toUpperCase(style.businessName),
    style.doubleColumns,
  )) {
    builder.line(line);
  }

  builder
    ..doubleSize(on: false)
    ..line('Sipariş: ${data.orderNumber}')
    ..bold(on: false)
    ..line(TurkishTime.dateTime(data.printedAt));

  if (data.requestedAt != null) {
    builder.line('Teslim: ${TurkishTime.shortDateTime(data.requestedAt!)}');
  }

  builder
    ..align(EscPosAlign.left)
    ..rule();

  for (final line in data.lines) {
    for (final row in _amountRows(
      '${line.quantity}× ${line.name}',
      Money.formatForReceipt(line.lineTotal),
      style.columns,
    )) {
      builder.line(row);
    }
    for (final option in line.options) {
      for (final row in _wrap('   ($option)', style.columns)) {
        builder.line(row);
      }
    }
  }

  builder.rule();

  for (final row in _amountRows(
    'Ara Toplam',
    Money.formatForReceipt(data.subtotal),
    style.columns,
  )) {
    builder.line(row);
  }

  // Gel-al siparişte teslimat ücreti satırı hiç basılmaz (`docs/05` §5.3).
  if (data.deliveryType == DeliveryType.delivery) {
    for (final row in _amountRows(
      'Teslimat',
      Money.formatForReceipt(data.deliveryFee),
      style.columns,
    )) {
      builder.line(row);
    }
  }

  builder.bold(on: true);
  for (final row in _amountRows(
    'TOPLAM',
    Money.formatForReceipt(data.total),
    style.columns,
  )) {
    builder.line(row);
  }
  builder
    ..bold(on: false)
    ..line('Ödeme: ${data.paymentMethod.label} (${data.paymentStatus.label})')
    ..rule();

  final address = data.address;
  if (data.deliveryType == DeliveryType.delivery && address != null) {
    builder.line('Teslimat:');
    for (final row in _wrap(address.line1, style.columns)) {
      builder.line(row);
    }
    for (final row in _wrap(
      '${address.district} / ${address.city}',
      style.columns,
    )) {
      builder.line(row);
    }
    if (_hasText(address.note)) {
      for (final row in _wrap(address.note!.trim(), style.columns)) {
        builder.line(row);
      }
    }
  } else {
    builder
      ..align(EscPosAlign.center)
      ..bold(on: true)
      ..line('GEL-AL')
      ..bold(on: false)
      ..align(EscPosAlign.left);
  }

  builder.rule();
  for (final footer in style.footerLines) {
    for (final row in _wrap(footer, style.columns)) {
      builder.line(row);
    }
  }

  return _finish(builder, style);
}

// ───────────────────────────── Yardımcılar ─────────────────────────────

void _writeKitchenLine(
  EscPosBuilder builder,
  KitchenReceiptLine line,
  ReceiptStyle style,
) {
  // Adet sütunu sabit genişlikte: 1 ile 999 arası hizalı kalır.
  final prefix = '${line.quantity}×'.padRight(4);
  final name = TurkishCase.toUpperCase(line.name);

  builder
    ..doubleSize(on: true)
    ..bold(on: true);
  final wrapped = _wrap(name, style.doubleColumns - prefix.length);
  for (var i = 0; i < wrapped.length; i++) {
    builder.line(i == 0 ? '$prefix${wrapped[i]}' : '    ${wrapped[i]}');
  }
  builder
    ..doubleSize(on: false)
    ..bold(on: false);

  if (line.options.isNotEmpty) {
    for (final row in _wrap(
      '    (${line.options.join(', ')})',
      style.columns,
    )) {
      builder.line(row);
    }
  }

  if (_hasText(line.note)) {
    builder.bold(on: true);
    for (final row in _wrap('    >> ${line.note!.trim()} <<', style.columns)) {
      builder.line(row);
    }
    builder.bold(on: false);
  }
}

Uint8List _finish(EscPosBuilder builder, ReceiptStyle style) {
  builder
    ..feed(style.feedBeforeCut)
    ..cut();
  return builder.build();
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

/// Metni [width] karaktere sığacak şekilde kelime sınırından böler.
///
/// Baştaki girinti korunur ve alt satırlara da uygulanır — kalem altındaki
/// seçenek ve not satırları taşsa bile hizada kalır. Tek başına sığmayan
/// kelime (uzun ürün kodu) sert bölünür; bölünmezse yazıcı kendi kendine
/// kaydırır ve hizayı bozar.
List<String> _wrap(String text, int width) {
  if (width <= 0) return <String>[text];

  final trimmed = text.trimLeft();
  final indent = text.substring(0, text.length - trimmed.length);
  final bodyWidth = width - indent.length;
  if (bodyWidth <= 0) return <String>[text];

  final lines = <String>[];
  final buffer = StringBuffer();

  void flush() {
    lines.add('$indent$buffer');
    buffer.clear();
  }

  for (final word in trimmed.split(RegExp(r'\s+'))) {
    var remaining = word;

    while (remaining.length > bodyWidth) {
      if (buffer.isNotEmpty) flush();
      lines.add('$indent${remaining.substring(0, bodyWidth)}');
      remaining = remaining.substring(bodyWidth);
    }
    if (remaining.isEmpty) continue;

    final separator = buffer.isEmpty ? '' : ' ';
    if (buffer.length + separator.length + remaining.length > bodyWidth) {
      flush();
      buffer.write(remaining);
    } else {
      buffer
        ..write(separator)
        ..write(remaining);
    }
  }

  if (buffer.isNotEmpty || lines.isEmpty) flush();
  return lines;
}

/// Solda açıklama, sağda tutar olan satır(lar)ı üretir.
///
/// Açıklama sığmazsa alt satıra taşar; tutar her zaman **son satırın** sağına
/// yaslanır, böylece sütun hizası bozulmaz.
List<String> _amountRows(String left, String right, int columns) {
  final leftWidth = columns - right.length - 1;
  if (leftWidth < 1) return <String>[left, right.padLeft(columns)];

  final wrapped = _wrap(left, leftWidth);
  final rows = wrapped.sublist(0, wrapped.length - 1);
  final last = wrapped.last;
  rows.add('$last${right.padLeft(columns - last.length)}');
  return rows;
}
