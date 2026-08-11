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

  // Telefon başlıkta, kalemlerin üstünde: kurye ya da mutfak numaraya
  // bakacağı zaman fişin tamamını okumak zorunda kalmasın.
  //
  // ÇİFT BOY: numara mutfağın ışığında, kâğıdı eline almadan, bir metre
  // öteden okunabilmeli. Normal puntoda basıldığında ancak fişi kaldırıp
  // yakından bakarak okunuyordu.
  if (_hasText(data.customerPhone)) {
    builder
      ..doubleSize(on: true)
      ..bold(on: true);
    for (final line in _wrap(
      'Tel: ${data.customerPhone!.trim()}',
      style.doubleColumns,
    )) {
      builder.line(line);
    }
    builder
      ..doubleSize(on: false)
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

    // Haritadan seçilen nokta varsa QR.
    //
    // Serbest metin adres KALDIRILMIYOR, QR onun ÜSTÜNE ekleniyor: kuryenin
    // telefonu bitmiş, kamerası bozuk ya da fiş buruşmuş olabilir. Fiş tek
    // başına da adrese götürmeye yetmeli — QR son yüz metreyi kısaltan bir
    // kolaylık, tek bilgi kaynağı değil.
    if (address.hasPin) {
      builder
        ..feed()
        ..align(EscPosAlign.center)
        ..qr(address.mapUrl)
        ..line('Haritada aç')
        ..align(EscPosAlign.left);
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

/// Kurye fişi (K-14) — kime, nereye, ne kadar tahsil edilecek.
///
/// NEDEN AYRI ŞABLON: kurye üç bilgiye ihtiyaç duyuyor ve hiçbiri tek bir
/// mevcut fişte birlikte yok. Mutfak fişinde adres yok (mutfak teslimat
/// yapmıyor); müşteri fişi ise müşteride kalıyor ve kuryenin elinde bir
/// kopya bırakmıyor.
///
/// SIRALAMA ADRES ÖNCELİKLİ, fiyat değil: kurye önce nereye gideceğine
/// bakıyor. Tahsilat satırı en altta ve **çift boy** — yanlış tutar
/// tahsil etmek en pahalı hata.
Uint8List buildCourierReceipt(
  CourierReceiptData data, {
  ReceiptStyle style = ReceiptStyle.standard,
}) {
  final builder =
      EscPosBuilder(columns: style.columns, codePage: style.codePage)
        ..reset()
        ..align(EscPosAlign.center)
        ..doubleSize(on: true)
        ..bold(on: true)
        ..line('KURYE');

  builder
    ..doubleSize(on: false)
    ..line('Sipariş: ${data.orderNumber}');

  // REVİZE BAŞLIĞI ÇİFT BOY: kuryenin elinde eski bir fiş olabilir ve
  // yanlış tutar tahsil edilmesinin önündeki tek engel bu satır.
  if (data.isRevised) {
    builder
      ..doubleSize(on: true)
      ..line('REVİZE #${data.revisionNo}')
      ..doubleSize(on: false);
  }

  builder
    ..bold(on: false)
    ..line(TurkishTime.dateTime(data.printedAt));

  if (data.requestedAt != null) {
    builder.line('Teslim: ${TurkishTime.shortDateTime(data.requestedAt!)}');
  }

  builder
    ..align(EscPosAlign.left)
    ..rule();

  // ── Kime ────────────────────────────────────────────────────────────
  if (_hasText(data.customerName)) {
    builder.bold(on: true);
    for (final row in _wrap(
      TurkishCase.toUpperCase(data.customerName!.trim()),
      style.columns,
    )) {
      builder.line(row);
    }
    builder.bold(on: false);
  }

  // TELEFON ÇİFT GENİŞLİK: kurye onu araçta, kötü ışıkta, tek elle
  // okuyor. Mutfak fişindeki kararın aynısı (`docs/05` §5.3).
  if (_hasText(data.customerPhone)) {
    builder
      ..doubleSize(on: true)
      ..bold(on: true);
    for (final row in _wrap(
      'Tel: ${data.customerPhone!.trim()}',
      style.doubleColumns,
    )) {
      builder.line(row);
    }
    builder
      ..doubleSize(on: false)
      ..bold(on: false);
  }

  // ── Nereye ──────────────────────────────────────────────────────────
  final address = data.address;
  if (address != null) {
    builder.rule();
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

    // QR serbest metin adresin YERİNE GEÇMEZ, üstüne eklenir: telefon
    // bitmiş, kamera bozuk ya da fiş buruşmuş olabilir.
    if (address.hasPin) {
      builder
        ..feed()
        ..align(EscPosAlign.center)
        ..qr(address.mapUrl)
        ..line('Haritada aç')
        ..align(EscPosAlign.left);
    }
  }

  // ── Ne var ──────────────────────────────────────────────────────────
  builder.rule();
  for (final line in data.lines) {
    for (final row in _wrap('${line.quantity}× ${line.name}', style.columns)) {
      builder.line(row);
    }
  }

  // ── Ne değişti ──────────────────────────────────────────────────────
  if (data.revisionSummary.isNotEmpty) {
    builder
      ..rule()
      ..bold(on: true)
      ..line('DEĞİŞİKLİKLER')
      ..bold(on: false);

    for (final change in data.revisionSummary) {
      for (final row in _wrap('* $change', style.columns)) {
        builder.line(row);
      }
    }
  }

  if (_hasText(data.customerNote)) {
    builder.rule();
    for (final row in _wrap('NOT: ${data.customerNote!.trim()}', style.columns)) {
      builder.line(row);
    }
  }

  // ── Ne kadar ────────────────────────────────────────────────────────
  builder.rule();
  builder.line('Ödeme: ${data.paymentMethod.label} (${data.paymentStatus.label})');

  // TAHSİLAT SATIRI EN ALTTA VE ÇİFT BOY. Ödenmiş siparişte hiç
  // basılmaz: sıfırlık bir "tahsil edilecek" satırı, kuryenin bir
  // sonraki fişte gerçek tutarı gözden kaçırmasına yol açıyor.
  if (data.collectAmount > 0) {
    builder
      ..feed()
      ..align(EscPosAlign.center)
      ..doubleSize(on: true)
      ..bold(on: true)
      ..line('TAHSİL: ${Money.formatForReceipt(data.collectAmount)}')
      ..doubleSize(on: false)
      ..bold(on: false)
      ..align(EscPosAlign.left);
  } else {
    builder
      ..align(EscPosAlign.center)
      ..bold(on: true)
      ..line('TAHSİLAT YOK')
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

/// Üretim planı fişi (K-15) — "yarın ne kadar pişecek".
///
/// NEDEN KUYRUĞA GİRMEZ: bu bir sipariş fişi değil, personelin istediği
/// anda bastığı bir rapor. Kuyruğa girseydi `UNIQUE(order_id, type)`
/// kısıtına takılırdı (sipariş kimliği yok) ve ikinci kez basılamazdı.
/// Açılış test fişiyle aynı yol: `printDiagnostic`.
///
/// UYARILAR DA BASILIR: ekranda görünüp kâğıtta görünmezse, tezgâhtaki
/// kâğıda bakan kişi "üretim koşmamış" bilgisini hiç görmez.
Uint8List buildProductionPlanReceipt(
  ProductionPlanData data, {
  ReceiptStyle style = ReceiptStyle.standard,
}) {
  final builder =
      EscPosBuilder(columns: style.columns, codePage: style.codePage)
        ..reset()
        ..align(EscPosAlign.center)
        ..doubleSize(on: true)
        ..bold(on: true)
        ..line('ÜRETİM PLANI')
        ..line(TurkishTime.date(data.date))
        ..doubleSize(on: false)
        ..bold(on: false)
        ..line('Basım: ${TurkishTime.dateTime(data.printedAt)}')
        ..align(EscPosAlign.left)
        ..rule();

  // ── Uyarılar EN ÜSTTE ───────────────────────────────────────────────
  //
  // Alta konsaydı, listeyi okuyup üstünü çizen personel oraya hiç
  // bakmazdı. "Üretim koşmamış" bilgisi listenin kendisinden önce gelir.
  if (data.warnings.isNotEmpty) {
    builder
      ..bold(on: true)
      ..line('!! DİKKAT')
      ..bold(on: false);

    for (final warning in data.warnings) {
      for (final row in _wrap('* $warning', style.columns)) {
        builder.line(row);
      }
    }
    builder.rule();
  }

  // ── Ürün toplamları ─────────────────────────────────────────────────
  if (data.totals.isEmpty) {
    builder
      ..align(EscPosAlign.center)
      ..bold(on: true)
      ..line('ÜRETİM YOK')
      ..bold(on: false)
      ..align(EscPosAlign.left);
  } else {
    for (final total in data.totals) {
      // Adet ÇİFT GENİŞLİK: mutfak listeye bir metreden bakıyor ve
      // okuduğu tek şey sayı.
      builder
        ..doubleSize(on: true)
        ..bold(on: true);
      for (final row in _wrap(
        '${total.quantity}x ${TurkishCase.toUpperCase(total.name)}',
        style.doubleColumns,
      )) {
        builder.line(row);
      }
      builder
        ..doubleSize(on: false)
        ..bold(on: false);
    }
  }

  // ── Teslimat çizelgesi ──────────────────────────────────────────────
  if (data.deliveries.isNotEmpty) {
    builder
      ..rule()
      ..bold(on: true)
      ..line('TESLİMAT')
      ..bold(on: false);

    for (final delivery in data.deliveries) {
      final time = delivery.time ?? '--:--';
      final count = delivery.itemCount > 0 ? ' (${delivery.itemCount})' : '';

      for (final row in _wrap(
        '$time  ${delivery.label}$count',
        style.columns,
      )) {
        builder.line(row);
      }
    }
  }

  builder.rule();
  for (final footer in style.footerLines) {
    for (final row in _wrap(footer, style.columns)) {
      builder.line(row);
    }
  }

  return _finish(builder, style);
}

/// BBD Store fişi (K-16) — **kitap siparişi paketleme fişi**.
///
/// BBD Store bir kitap e-ticaret sitesidir, catering değil. Bu kâğıt
/// mutfak fişi değil; raftan kitap toplayıp kutulayan kişinin elinde
/// duran bir **sevkiyat fişi**. Aynı yazıcıdan çıkıyor çünkü işletme tek
/// mekânda ve tek termal yazıcı var.
///
/// MUTFAK FİŞİNDEN ÜÇ TASARIM FARKI, üçü de iş akışından:
///
/// 1. **Ürün adı ÇİFT BOY BASILMAZ.** Mutfak fişinde "12x KARNIYARIK"
///    bir metreden okunmak için çift boydur. Kitap adları uzun
///    ("Türkiye'nin Yakın Tarihi — Cilt II") ve 80 mm kâğıtta çift boy
///    24 sütun demek; başlık üç satıra bölünür, fiş uzar, okunmaz.
///    Burada **adet** çift boy, ad normal ve satıra sarılıyor.
/// 2. **Stok kodu / ISBN basılıyor.** Raftan bulmanın en hızlı yolu ad
///    değil koddur; mutfakta böyle bir şey yok.
/// 3. **Kargo bloğu var.** Kitapta `delivery` kurye değil **kargo**
///    demek: firma ve takip numarası, paketi doğru poşete koymak için
///    gerekiyor.
///
/// BLD FİŞLERİYLE KARIŞMAMALI: bu sipariş KDS panosunda **yok**. Kâğıdı
/// BLD fişiyle karıştıran personel, panoda olmayan bir siparişi arar ve
/// bulamaz. Başlık bu yüzden çift boy "BBD STORE" ve altında ayırıcı bir
/// satır var.
Uint8List buildBbdReceipt(
  BbdReceiptData data, {
  ReceiptStyle style = ReceiptStyle.standard,
}) {
  final builder =
      EscPosBuilder(columns: style.columns, codePage: style.codePage)
        ..reset()
        ..align(EscPosAlign.center)
        ..doubleSize(on: true)
        ..bold(on: true)
        ..line('BBD STORE')
        ..doubleSize(on: false)
        ..line('KİTAP SİPARİŞİ')
        ..bold(on: false)
        ..line('Sipariş: ${data.orderNumber}')
        ..line(TurkishTime.dateTime(data.createdAt ?? data.printedAt))
        ..align(EscPosAlign.left)
        ..rule();

  // ── Ne paketlenecek ──────────────────────────────────────────────────
  //
  // EN ÜSTTE: paketleyen kişinin ilk işi kitapları raftan toplamak.
  // Adres ve kargo, kutu kapandıktan sonra lazım olan bilgiler.
  for (final line in data.lines) {
    // Adet çift boy, ad normal: uzun kitap adı çift boyda üç satıra
    // bölünür ve fiş okunmaz hâle gelir.
    builder
      ..doubleSize(on: true)
      ..bold(on: true)
      ..line('${line.quantity}x')
      ..doubleSize(on: false);

    for (final row in _wrap(line.name, style.columns)) {
      builder.line(row);
    }
    builder.bold(on: false);

    if (_hasText(line.sku)) {
      builder.line('   Kod: ${line.sku!.trim()}');
    }
    for (final attribute in line.attributes) {
      for (final row in _wrap('   $attribute', style.columns)) {
        builder.line(row);
      }
    }
    if (_hasText(line.note)) {
      for (final row in _wrap('   >> ${line.note!.trim()}', style.columns)) {
        builder.line(row);
      }
    }

    builder.feed();
  }

  builder.rule();

  // ── Kime ─────────────────────────────────────────────────────────────
  if (_hasText(data.customerLabel)) {
    builder.bold(on: true);
    for (final row in _wrap(data.customerLabel!.trim(), style.columns)) {
      builder.line(row);
    }
    builder.bold(on: false);
  }

  if (_hasText(data.customerPhone)) {
    builder.line('Tel: ${data.customerPhone!.trim()}');
  }

  // ── Nereye ───────────────────────────────────────────────────────────
  //
  // GEL-AL ise adres blogu hiç basılmaz: müşteri kendisi alıyor ve
  // basılan adres, paketin yanlışlıkla kargoya verilmesine yol açar.
  if (data.isPickup) {
    builder
      ..align(EscPosAlign.center)
      ..bold(on: true)
      ..line('MAĞAZADAN TESLİM')
      ..bold(on: false)
      ..align(EscPosAlign.left);
  } else if (_hasText(data.address)) {
    builder.line('Adres:');
    for (final row in _wrap(data.address!.trim(), style.columns)) {
      builder.line(row);
    }
  }

  // ── Kargo ────────────────────────────────────────────────────────────
  //
  // Yalnız kargolu siparişte ve yalnız bilgi geldiyse. Boş bir "Kargo:"
  // satırı, paketleyene bir şeyin eksik olduğunu düşündürür.
  if (!data.isPickup &&
      (_hasText(data.cargoCompany) || _hasText(data.trackingNumber))) {
    builder.rule();

    if (_hasText(data.cargoCompany)) {
      builder
        ..bold(on: true)
        ..line('Kargo: ${data.cargoCompany!.trim()}')
        ..bold(on: false);
    }

    // Takip numarası ÇİFT GENİŞLİK: paketin üstündeki etiketle elle
    // karşılaştırılıyor ve tek bir yanlış hane yanlış pakete gider.
    if (_hasText(data.trackingNumber)) {
      builder.doubleSize(on: true);
      for (final row in _wrap(
        data.trackingNumber!.trim(),
        style.doubleColumns,
      )) {
        builder.line(row);
      }
      builder.doubleSize(on: false);
    }
  }

  if (_hasText(data.note)) {
    builder.rule();
    for (final row in _wrap('NOT: ${data.note!.trim()}', style.columns)) {
      builder.line(row);
    }
  }

  // ── Ödeme ────────────────────────────────────────────────────────────
  builder.rule();

  if (_hasText(data.paymentLabel)) {
    builder.line('Ödeme: ${data.paymentLabel!.trim()}');
  }

  // Tutar YALNIZCA BBD gönderdiyse. Uydurulmuş ya da sıfır bir tutar,
  // kapıda ödemede yanlış tahsilata yol açar.
  final amount = data.amount;
  if (amount != null) {
    builder
      ..align(EscPosAlign.center)
      ..doubleSize(on: true)
      ..bold(on: true)
      ..line('TUTAR: ${Money.formatForReceipt(amount)}')
      ..doubleSize(on: false)
      ..bold(on: false)
      ..align(EscPosAlign.left);
  }

  builder.rule();
  // ALT BİLGİ BLD'NİNKİ DEĞİL: bu fiş BLD'nin belgesi değil, başka bir
  // sistemin siparişinin buraya iletilmiş kopyası.
  for (final row in _wrap(
    'BBD Store siparişi — BLD panosunda görünmez.',
    style.columns,
  )) {
    builder.line(row);
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
