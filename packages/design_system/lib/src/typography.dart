/// Tipografi ölçeği.
///
/// İki ayrı ölçek vardır çünkü iki farklı okuma mesafesi vardır: müşteri
/// telefonu elinde tutar, mutfak personeli ekrana bir metreden bakar.
library;

/// Müşteriye görünen yüzeyler (web, mobil) — 15 adımlı ölçek.
///
/// **Neden bu kadar çok adım:** beş adımlık ölçek yetmediği için çağrı yerleri
/// `heading + 4`, `title + 2`, `caption + 1` gibi aritmetik yapmaya başlamıştı.
/// Ölçek o aritmetiğin yaptığı işi artık kendisi yapıyor; ara boyut isteyen
/// ekran onu uydurmak yerine adıyla çağırıyor.
///
/// **Hangi aile:** SERİF (`BldFontFamily.display`) yalnız isim ve başlıklar
/// için — `display`, `h1`, `h2`, `h3`, `title`. INTER (`BldFontFamily.body`)
/// fiyat, buton, etiket, durum gibi İŞLEVSEL her şey için. Bu ayrım tesadüfi
/// değil: serif rakamları hizasız (old-style) çizebiliyor ve fiyat sütunu
/// bozuluyor.
abstract final class BldTextScale {
  // ── SERİF: isim ve başlık ────────────────────────────────────────────────

  /// Pazarlama kahramanı — sayfa başına en fazla bir kez.
  static const double display = 44;
  static const double displayLineHeight = 56;

  /// Sayfa başlığı.
  static const double h1 = 32;
  static const double h1LineHeight = 40;

  /// Bölüm başlığı.
  static const double h2 = 26;
  static const double h2LineHeight = 30;

  /// Alt bölüm başlığı; boş/hata durumu başlığı.
  static const double h3 = 21;

  /// VARSAYIM: brief `h3` için satır yüksekliği vermedi; 1,33 oranı
  /// `h2`'nin (30/26 = 1,15) ve `body`'nin (22/15 = 1,47) arasında kalacak
  /// şekilde seçildi. Değiştirilebilir, bir şey kırmaz.
  static const double h3LineHeight = 28;

  /// Kart başlığı, ürün adı, liste satırı adı.
  static const double title = 17;

  /// VARSAYIM: bkz. [h3LineHeight].
  static const double titleLineHeight = 24;

  // ── INTER: işlevsel metin ────────────────────────────────────────────────

  /// Öne çıkan gövde metni (giriş paragrafı).
  static const double bodyLg = 17;
  static const double bodyLgLineHeight = 26;

  /// Varsayılan gövde metni.
  static const double body = 15;
  static const double bodyLineHeight = 22;

  /// Yardımcı metin, ikincil açıklama.
  static const double bodySm = 13;
  static const double bodySmLineHeight = 20;

  /// Form etiketi — HER ZAMAN alanın ÜSTÜNDE.
  static const double label = 13;
  static const double labelLineHeight = 16;
  static const int labelWeight = 600;

  /// Zaman damgası, dipnot.
  static const double caption = 12;
  static const double captionLineHeight = 16;

  /// Bölüm üstü etiket (KATEGORİ, DURUM).
  ///
  /// UYARI: `overline` stilinin büyük harfi TASARIMDA vardır ama API'den
  /// gelen metne CSS `text-transform` ile UYGULANMAZ — Türkçe'de "İ/ı"
  /// kırılır. Büyük harf gerekiyorsa metin zaten büyük yazılır.
  static const double overline = 11;
  static const double overlineLineHeight = 16;
  static const int overlineWeight = 700;

  /// `overline` harf aralığı (em). CSS'te `0.14em`, Flutter'da
  /// `letterSpacing: overline * overlineTracking`.
  static const double overlineTracking = 0.14;

  // ── PARA ─────────────────────────────────────────────────────────────────
  //
  // Para HER YERDE tabular rakamla dizilir (`FontFeature.tabularFigures` /
  // `font-variant-numeric: tabular-nums`) ve ASLA sarmalanmaz. Biçim
  // `1.234,56 ₺`; ₺ işareti rakamlarla AYNI boy ve renktedir.

  /// Liste satırındaki birim fiyat.
  static const double moneySm = 15;
  static const double moneySmLineHeight = 20;
  static const int moneySmWeight = 600;

  /// Kart üzerindeki fiyat.
  static const double moneyMd = 17;
  static const double moneyMdLineHeight = 24;
  static const int moneyMdWeight = 700;

  /// Sepet ara toplamı.
  static const double moneyLg = 22;
  static const double moneyLgLineHeight = 28;
  static const int moneyLgWeight = 700;

  /// Ödenecek tutar — ekranda tek bir kez.
  static const double moneyXl = 28;
  static const double moneyXlLineHeight = 34;
  static const int moneyXlWeight = 700;

  // ── ESKİ ADLAR ───────────────────────────────────────────────────────────
  //
  // Beş adımlık ölçeğin adları KALDIRILMADI, yeni adımlara bağlandı.
  // `@Deprecated` bilinçli olarak KULLANILMIYOR: musteriapp'te
  // `flutter analyze` sıfır uyarı istiyor ve bu paket uyarıyı oraya
  // taşıyıp başka bir hattın kapısını düşürürdü. Yeni kod yukarıdaki
  // adları kullanır; eski çağrı yerleri dokundukça taşınır.

  /// ESKİ AD → [h2].
  static const double heading = h2;
}

/// Yazı tipi aileleri.
///
/// Türkçe tam destek (Latin Extended-A: ş/ğ/İ/ı/ç/ö/ü) şart; ikisi de OFL.
/// **Asset olarak bundle edilir** — çalışma anında Google Fonts indirme YOK;
/// aksi çevrimdışı menü kararıyla çelişirdi. Aileler tek yerde tanımlıdır ki
/// marka fontu değişince tek satır güncellensin.
abstract final class BldFontFamily {
  /// Başlık/marka — Source Serif 4.
  ///
  /// **Neden Playfair Display ya da Sora DEĞİL:** logonun harf biçimi dirsekli
  /// (bracketed) tırnaklı, kalın-ince farkı DÜŞÜK bir hümanist serif. Playfair
  /// bir Didone: kalın-ince farkı çok yüksek, tırnakları saç inceliğinde —
  /// küçük boyutta kayboluyor ve logoyla aynı ailedenmiş gibi durmuyor. Sora
  /// ise geometrik sans; logonun tırnaklı yapısıyla hiç ilgisi yok.
  ///
  /// Source Serif 4'ün optik boyut (`opsz`) ekseni var: aynı dosya 11 punto
  /// etikette de 44 punto kahramanda da doğru kalınlıkta çiziliyor. Türkçe
  /// kapsaması tam (İ/ı dahil) ve OFL.
  ///
  /// Web tarafındaki karşılığı `--font-display` (next/font `Source_Serif_4`).
  static const String display = 'SourceSerif4';

  /// Gövde/arayüz — yüksek okunabilirlik, tabular rakam (para hizası).
  static const String body = 'Inter';

  /// Display metinlerde sıkı harf aralığı (başlıklar toplu görünsün).
  static const double displayLetterSpacing = -0.5;
}

/// "BLD" monogramı bir YAZI DEĞİLDİR.
///
/// Logodaki BLD özel çizimdir (bağlı, süslü el yazısı); hiçbir font onu
/// üretmez. Metin olarak dizmeye çalışan her deneme markayı bozar — monogram
/// gerektiğinde `website/app/icon.svg` ya da `musteriapp/assets/icon/*`
/// altındaki varlık kullanılır.
const String kBldMonogramIsArtworkNotType =
    'BLD monogramı özel çizimdir; fontla dizilmez.';

/// Mutfak ekranı — `docs/05-mutfakapp.md` §3'teki asgari boyutlar.
///
/// Bunlar tavsiye değil **alt sınırdır**: ürün adı en az 20, adet en az 28.
abstract final class KdsTextScale {
  /// Durum çubuğu, ikincil bilgi.
  static const double statusBar = 16;

  /// Sipariş numarası ve rozet.
  static const double orderNumber = 22;

  /// Ürün adı — asgari 20.
  static const double itemName = 24;

  /// Adet — asgari 28, kalın.
  static const double quantity = 32;

  /// Sütun başlığı (YENİ / HAZIRLANIYOR / HAZIR).
  static const double columnHeader = 26;

  /// Sipariş notu — gizlenmez, büyük basılır.
  static const double note = 22;
}
