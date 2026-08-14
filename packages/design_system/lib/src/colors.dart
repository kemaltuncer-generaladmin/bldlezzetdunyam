//
// ÜRETİLDİ — ELLE DÜZENLEME
//
// Bu dosya `packages/design_system/tokens/bld.tokens.json` dosyasından üretildi.
// Değişiklik oraya yazılır, sonra:
//   dart run packages/design_system/tool/gen_tokens.dart
// Buraya elle yazılan her şey bir sonraki üretimde silinir.
//
//
// Değerler `0xAARRGGBB` biçiminde `int`'tir; Flutter `Color(...)` ile,
// web `#RRGGBB` olarak tüketir. `dart:ui` KULLANILMAZ — paket saf Dart
// kalsın ki üreteç ve testler Flutter SDK'sı olmadan da koşabilsin.
library;

/// Ham palet — logodan ölçüldü.
///
/// İKİ KURAL:
///  1. brand500 ve daha AÇIĞI beyaz metin TAŞIMAZ (3,72 < 4,50).
///     Beyaz yazı brand700'den başlar.
///  2. neutral400 METİN DEĞİLDİR: kenarlık, ayraç, ikon rengidir.
abstract final class BldColors {
  // ── BRAND ──

  /// En açık marka yüzeyi — tonal buton ve accent zemini. Metin taşımaz, üstüne
  /// brand800 yazılır. Beyaz üstünde 1,10:1 · neutral50 üstünde 1,02:1 · koyu
  /// zemin (#1B120C) üstünde 16,76:1.
  static const int brand50 = 0xFFFEF2E8;

  /// Marka yüzeyinin ikinci adımı — skeleton parıltısı, seçili çip zemini.
  /// Beyaz üstünde 1,24:1 · neutral50 üstünde 1,15:1 · koyu zemin (#1B120C)
  /// üstünde 14,87:1.
  static const int brand100 = 0xFFFDE2CC;

  /// Koyu temada başlık rengi; açık temada yalnız dekoratif (kenarlık, ayraç).
  /// Beyaz üstünde 1,52:1 · neutral50 üstünde 1,41:1 · koyu zemin (#1B120C)
  /// üstünde 12,15:1.
  static const int brand200 = 0xFFFCC7A2;

  /// Koyu temanın birincil DOLGUSU (üstünde neutral950 yazı) ve görsel yer
  /// tutucusunun buğday çizgisi. Beyaz üstünde 2,00:1 · neutral50 üstünde
  /// 1,86:1 · koyu zemin (#1B120C) üstünde 9,22:1.
  static const int brand300 = 0xFFF7A470;

  /// Koyu temanın birincil METİN/bağlantı rengi. Açık temada metin taşımaz.
  /// Beyaz üstünde 2,65:1 · neutral50 üstünde 2,46:1 · koyu zemin (#1B120C)
  /// üstünde 6,95:1.
  static const int brand400 = 0xFFE8863F;

  /// LOGO gradyanının açık ucu. TUZAK: beyaz metin TAŞIMAZ — 3,72 AA
  /// altındadır. Beyaz üstünde 3,72:1 · neutral50 üstünde 3,46:1 · koyu zemin
  /// (#1B120C) üstünde 4,96:1.
  static const int brand500 = 0xFFDD5D02;

  /// Odak halkası ve açık tema ikonu. Beyaz metin için sınırda: yalnız büyük
  /// metinde kullanılır. Beyaz üstünde 4,91:1 · neutral50 üstünde 4,56:1 · koyu
  /// zemin (#1B120C) üstünde 3,75:1.
  static const int brand600 = 0xFFC24A02;

  /// Açık temanın birincil DOLGUSU ve bağlantı rengi. Beyaz metin buradan
  /// başlar. Beyaz üstünde 6,72:1 · neutral50 üstünde 6,24:1 · koyu zemin
  /// (#1B120C) üstünde 2,75:1.
  static const int brand700 = 0xFFA8320A;

  /// Birincil butonun hover adımı; tonal buton yazısı (brand50 üstünde). Beyaz
  /// üstünde 8,66:1 · neutral50 üstünde 8,04:1 · koyu zemin (#1B120C) üstünde
  /// 2,13:1.
  static const int brand800 = 0xFF941C01;

  /// LOGO kelime markasının kahvesi. Açık temada BAŞLIK rengi. Beyaz üstünde
  /// 12,75:1 · neutral50 üstünde 11,84:1 · koyu zemin (#1B120C) üstünde 1,45:1.
  static const int brand900 = 0xFF5F1B08;

  /// En koyu marka adımı — koyu tema zemini bununla aynı ailede kalsın diye
  /// tutuldu. Beyaz üstünde 16,62:1 · neutral50 üstünde 15,44:1 · koyu zemin
  /// (#1B120C) üstünde 1,11:1.
  static const int brand950 = 0xFF3D0E05;

  // ── NEUTRAL ──

  /// Kart, popover ve form alanı zemini. Beyaz üstünde 1,00:1 · neutral50
  /// üstünde 1,08:1 · koyu zemin (#1B120C) üstünde 18,45:1.
  static const int neutral0 = 0xFFFFFFFF;

  /// Uygulama zemini (açık tema). Saf beyaz değil: kart kenarı görünsün diye.
  /// Beyaz üstünde 1,08:1 · neutral50 üstünde 1,00:1 · koyu zemin (#1B120C)
  /// üstünde 17,13:1.
  static const int neutral50 = 0xFFFAF6F0;

  /// Sessiz yüzey (muted) ve skeleton tabanı. Beyaz üstünde 1,18:1 · neutral50
  /// üstünde 1,10:1 · koyu zemin (#1B120C) üstünde 15,61:1.
  static const int neutral100 = 0xFFF2EBE3;

  /// DEKORATİF kenarlık ve ayraç. Kontrol kenarlığı DEĞİL (1,38 — 1.4.11
  /// geçmez). Beyaz üstünde 1,38:1 · neutral50 üstünde 1,28:1 · koyu zemin
  /// (#1B120C) üstünde 13,40:1.
  static const int neutral200 = 0xFFE5DACE;

  /// Koyu temanın sessiz metni; açık temada devre dışı öğe kenarlığı. Beyaz
  /// üstünde 1,72:1 · neutral50 üstünde 1,60:1 · koyu zemin (#1B120C) üstünde
  /// 10,72:1.
  static const int neutral300 = 0xFFD2C3B4;

  /// İŞLEVSEL kenarlık (form alanı, checkbox). METİN DEĞİLDİR. Beyaz üstünde
  /// 3,26:1 · neutral50 üstünde 3,03:1 · koyu zemin (#1B120C) üstünde 5,66:1.
  static const int neutral400 = 0xFFA28A78;

  /// Placeholder metni. Gövde metni için kullanılmaz. Beyaz üstünde 6,20:1 ·
  /// neutral50 üstünde 5,76:1 · koyu zemin (#1B120C) üstünde 2,98:1.
  static const int neutral500 = 0xFF7A5A4A;

  /// İkincil metin (muted-foreground). Beyaz üstünde 8,22:1 · neutral50 üstünde
  /// 7,64:1 · koyu zemin (#1B120C) üstünde 2,24:1.
  static const int neutral600 = 0xFF6B4636;

  /// Vurgulu ikincil metin, ikon. Beyaz üstünde 11,07:1 · neutral50 üstünde
  /// 10,28:1 · koyu zemin (#1B120C) üstünde 1,67:1.
  static const int neutral700 = 0xFF523527;

  /// Koyu yüzey (açık temada ters bant). Beyaz üstünde 14,34:1 · neutral50
  /// üstünde 13,32:1 · koyu zemin (#1B120C) üstünde 1,29:1.
  static const int neutral800 = 0xFF3B2519;

  /// Gövde metni (açık tema). Beyaz üstünde 16,73:1 · neutral50 üstünde 15,54:1
  /// · koyu zemin (#1B120C) üstünde 1,10:1.
  static const int neutral900 = 0xFF2A1A12;

  /// Koyu temanın zemini ve açık temada en koyu ters bant. Beyaz üstünde
  /// 18,45:1 · neutral50 üstünde 17,13:1 · koyu zemin (#1B120C) üstünde 1,00:1.
  static const int neutral950 = 0xFF1B120C;

  // ── SUCCESS ──

  /// Başarı tinti — açık tema. Beyaz üstünde 1,10:1 · neutral50 üstünde 1,02:1
  /// · koyu zemin (#1B120C) üstünde 16,75:1.
  static const int success50 = 0xFFECF7EB;

  /// Koyu temanın başarı METNİ. Beyaz üstünde 2,55:1 · neutral50 üstünde 2,37:1
  /// · koyu zemin (#1B120C) üstünde 7,24:1.
  static const int success400 = 0xFF6FB268;

  /// Beyaz metin taşıyan başarı dolgusu. Beyaz üstünde 4,72:1 · neutral50
  /// üstünde 4,38:1 · koyu zemin (#1B120C) üstünde 3,91:1.
  static const int success600 = 0xFF3E8237;

  /// Açık temanın başarı METNİ. 600 zemin üstünde AA altında kalıyor, o yüzden
  /// metin 700. Beyaz üstünde 6,53:1 · neutral50 üstünde 6,07:1 · koyu zemin
  /// (#1B120C) üstünde 2,82:1.
  static const int success700 = 0xFF2F6A2A;

  // ── WARNING ──

  /// Uyarı tinti — açık tema (çevrimdışı durumu). Beyaz üstünde 1,10:1 ·
  /// neutral50 üstünde 1,03:1 · koyu zemin (#1B120C) üstünde 16,70:1.
  static const int warning50 = 0xFFFAF3E5;

  /// Koyu temanın uyarı METNİ. Beyaz üstünde 1,94:1 · neutral50 üstünde 1,80:1
  /// · koyu zemin (#1B120C) üstünde 9,51:1.
  static const int warning300 = 0xFFD8B66D;

  /// Beyaz metin taşıyan uyarı dolgusu. Beyaz üstünde 5,00:1 · neutral50
  /// üstünde 4,64:1 · koyu zemin (#1B120C) üstünde 3,69:1.
  static const int warning600 = 0xFF926800;

  /// Açık temanın uyarı METNİ. Beyaz üstünde 6,85:1 · neutral50 üstünde 6,36:1
  /// · koyu zemin (#1B120C) üstünde 2,69:1.
  static const int warning700 = 0xFF785400;

  // ── DANGER ──

  /// Hata tinti — açık tema. Beyaz üstünde 1,15:1 · neutral50 üstünde 1,07:1 ·
  /// koyu zemin (#1B120C) üstünde 15,99:1.
  static const int danger50 = 0xFFFFEAEA;

  /// Koyu temanın hata METNİ ve yıkıcı dolgusu (üstünde neutral950). Beyaz
  /// üstünde 2,40:1 · neutral50 üstünde 2,23:1 · koyu zemin (#1B120C) üstünde
  /// 7,70:1.
  static const int danger300 = 0xFFF08A93;

  /// Onay diyaloğunun yıkıcı dolgusu (beyaz metin). Beyaz üstünde 5,84:1 ·
  /// neutral50 üstünde 5,43:1 · koyu zemin (#1B120C) üstünde 3,16:1.
  static const int danger600 = 0xFFC12440;

  /// Açık temanın hata METNİ ve yerinde yıkıcı eylem yazısı. Beyaz üstünde
  /// 7,46:1 · neutral50 üstünde 6,93:1 · koyu zemin (#1B120C) üstünde 2,47:1.
  static const int danger700 = 0xFFA51C34;

  // ── INFO ──

  /// Bilgi tinti — açık tema. Beyaz üstünde 1,11:1 · neutral50 üstünde 1,03:1 ·
  /// koyu zemin (#1B120C) üstünde 16,69:1.
  static const int info50 = 0xFFEAF5FF;

  /// Koyu temanın bilgi METNİ. Beyaz üstünde 1,92:1 · neutral50 üstünde 1,79:1
  /// · koyu zemin (#1B120C) üstünde 9,59:1.
  static const int info300 = 0xFF8BBFF9;

  /// Beyaz metin taşıyan bilgi dolgusu. Beyaz üstünde 4,97:1 · neutral50
  /// üstünde 4,62:1 · koyu zemin (#1B120C) üstünde 3,71:1.
  static const int info600 = 0xFF2E72B9;

  /// Açık temanın bilgi METNİ. Beyaz üstünde 6,80:1 · neutral50 üstünde 6,31:1
  /// · koyu zemin (#1B120C) üstünde 2,71:1.
  static const int info700 = 0xFF215D99;

  // ── ÇIPLAK TAKMA ADLAR ──

  /// Çıplak ad = METİN adımı. `text-success` / `BldColors.success` çağrı
  /// yerlerinin tamamı metin ve tint için kullanıyor; dolgu isteyen yer
  /// numaralı adımı açıkça yazar.
  static const int success = success700;

  /// Çıplak ad = METİN adımı.
  static const int warning = warning700;

  /// Çıplak ad = METİN adımı.
  static const int danger = danger700;

  /// Çıplak ad = METİN adımı.
  static const int info = info700;
}

/// Açık tema rol tablosu — müşteri yüzeylerinin (web, mobil) varsayılanı.
abstract final class BldLightColors {
  /// Uygulama zemini. Saf beyaz DEĞİL: kart beyazı zeminin üstünde kendi
  /// kenarını gösterebilsin diye.
  static const int background = BldColors.neutral50;

  /// Birinci yükseltme. AÇIK temada yükseltme GÖLGEDİR, açıklık adımı değil —
  /// bu yüzden card ile aynı değer.
  static const int surface1 = BldColors.neutral0;

  /// İkinci yükseltme (sheet, dialog). Yine gölge ile ayrışır, renkle değil.
  static const int surface2 = BldColors.neutral0;

  /// Gövde metni. background üstünde 15,54:1 (metin eşiği 4,50).
  static const int foreground = BldColors.neutral900;

  /// Başlıklar marka kahvesi — web, mobil ve panelin tek ürün gibi okunmasını
  /// sağlayan en ucuz hamle. background üstünde 11,84:1 (metin eşiği 4,50).
  static const int heading = BldColors.brand900;

  /// Sessiz yüzey — bölüm ayracı, sekme zemini.
  static const int muted = BldColors.neutral100;

  /// İkincil metin. background üstünde 7,64:1 (metin eşiği 4,50).
  static const int mutedForeground = BldColors.neutral600;

  /// Form alanı yer tutucu metni. muted-foreground ile aynı değil: placeholder
  /// daha sessiz olmalı ama okunur kalmalı. surface-1 üstünde 6,20:1 (metin
  /// eşiği 4,50).
  static const int placeholder = BldColors.neutral500;

  /// Kart ve liste satırı zemini.
  static const int card = BldColors.neutral0;

  /// Kart içi metin. card üstünde 16,73:1 (metin eşiği 4,50).
  static const int cardForeground = BldColors.neutral900;

  /// Açılır katman zemini.
  static const int popover = BldColors.neutral0;

  /// Açılır katman metni. popover üstünde 16,73:1 (metin eşiği 4,50).
  static const int popoverForeground = BldColors.neutral900;

  /// Birincil buton dolgusu. brand600 DEĞİL: beyaz etiket 4,91 ile sınırda
  /// kalıyordu. Etiketi (primary-foreground) ile 6,72:1 (metin eşiği 4,50).
  static const int primary = BldColors.brand700;

  /// Birincil buton etiketi.
  static const int primaryForeground = BldColors.neutral0;

  /// Birincil butonun hover adımı. Etiketi (primary-foreground) ile 8,66:1
  /// (metin eşiği 4,50).
  static const int primaryHover = BldColors.brand800;

  /// Ghost buton ve marka vurgulu metin. background üstünde 6,24:1 (metin eşiği
  /// 4,50).
  static const int primaryText = BldColors.brand700;

  /// Tonal buton dolgusu. Etiketi (secondary-foreground) ile 7,87:1 (metin
  /// eşiği 4,50).
  static const int secondary = BldColors.brand50;

  /// Tonal buton etiketi.
  static const int secondaryForeground = BldColors.brand800;

  /// Vurgu yüzeyi — seçili satır, hover zemini. Etiketi (accent-foreground) ile
  /// 7,87:1 (metin eşiği 4,50).
  static const int accent = BldColors.brand50;

  /// Vurgu yüzeyi metni.
  static const int accentForeground = BldColors.brand800;

  /// Sıcak anlatım bandı (hero, öne çıkan bölüm).
  static const int surfaceWarm = BldColors.brand50;

  /// Sıcak bant metni. surface-warm üstünde 15,20:1 (metin eşiği 4,50).
  static const int surfaceWarmForeground = BldColors.neutral900;

  /// DEKORATİF ayraç. Kontrol kenarlığı olarak KULLANILMAZ — 1.4.11 eşiğini
  /// geçmez, input rolü onun içindir.
  static const int border = BldColors.neutral200;

  /// İŞLEVSEL kontrol kenarlığı (form alanı, checkbox, radio). WCAG 1.4.11 için
  /// >= 3,0 olmak zorunda. card üstünde 3,26:1 (kontrol eşiği 3,00).
  static const int input = BldColors.neutral400;

  /// Odak halkası. 2px + 2px offset ile çizilir. background üstünde 4,56:1
  /// (kontrol eşiği 3,00).
  static const int ring = BldColors.brand600;

  /// Bağlantı metni. background üstünde 6,24:1 (metin eşiği 4,50).
  static const int link = BldColors.brand700;

  /// Onay diyaloğundaki dolu yıkıcı buton. Etiketi (destructive-foreground) ile
  /// 5,84:1 (metin eşiği 4,50).
  static const int destructive = BldColors.danger600;

  /// Yıkıcı buton etiketi.
  static const int destructiveForeground = BldColors.neutral0;

  /// Başarı METNİ. 600 adımı neutral50 zemininde 4,38 veriyor — AA altı, o
  /// yüzden metin 700. background üstünde 6,07:1 (metin eşiği 4,50).
  static const int success = BldColors.success700;

  /// Başarı tinti.
  static const int successSurface = BldColors.success50;

  /// Tint üstündeki başarı metni. success-surface üstünde 5,93:1 (metin eşiği
  /// 4,50).
  static const int successForeground = BldColors.success700;

  /// Uyarı METNİ (çevrimdışı durumu). background üstünde 6,36:1 (metin eşiği
  /// 4,50).
  static const int warning = BldColors.warning700;

  /// Uyarı tinti.
  static const int warningSurface = BldColors.warning50;

  /// Tint üstündeki uyarı metni. warning-surface üstünde 6,20:1 (metin eşiği
  /// 4,50).
  static const int warningForeground = BldColors.warning700;

  /// Hata METNİ ve yerinde yıkıcı eylem yazısı. background üstünde 6,93:1
  /// (metin eşiği 4,50).
  static const int danger = BldColors.danger700;

  /// Hata tinti.
  static const int dangerSurface = BldColors.danger50;

  /// Tint üstündeki hata metni. danger-surface üstünde 6,47:1 (metin eşiği
  /// 4,50).
  static const int dangerForeground = BldColors.danger700;

  /// Bilgi METNİ. background üstünde 6,31:1 (metin eşiği 4,50).
  static const int info = BldColors.info700;

  /// Bilgi tinti.
  static const int infoSurface = BldColors.info50;

  /// Tint üstündeki bilgi metni. info-surface üstünde 6,15:1 (metin eşiği
  /// 4,50).
  static const int infoForeground = BldColors.info700;

  /// Skeleton tabanı.
  static const int skeletonBase = BldColors.neutral100;

  /// Skeleton parıltısı — 1200 ms.
  static const int skeletonSheen = BldColors.neutral200;
}

/// Koyu tema rol tablosu.
///
/// KOYU temada yükseltme AÇIKLIK adımıdır, gölge değil; bu yüzden
/// `surface1`/`surface2` gerçek renk taşır, açık temada ikisi de karttır.
abstract final class BldDarkColors {
  /// Koyu tema zemini. Nötr siyah değil: marka ailesinin en koyu kahvesi.
  static const int background = BldColors.neutral950;

  /// Birinci yükseltme. KOYU temada yükseltme AÇIKLIK adımıdır, gölge değil.
  static const int surface1 = 0xFF261B14;

  /// İkinci yükseltme (sheet, dialog, popover).
  static const int surface2 = 0xFF32261E;

  /// Gövde metni. background üstünde 15,61:1 (metin eşiği 4,50).
  static const int foreground = BldColors.neutral100;

  /// TÜRETİLDİ: açık temada başlık brand900 (marka kahvesi). Koyu temada aynı
  /// rolün aynadaki karşılığı marka ailesinin açık ucudur; brand200 seçildi.
  /// background üstünde 12,15:1 (metin eşiği 4,50).
  static const int heading = BldColors.brand200;

  /// Sessiz yüzey.
  static const int muted = 0xFF32261E;

  /// İkincil metin. muted üstünde 8,53:1 (metin eşiği 4,50).
  static const int mutedForeground = BldColors.neutral300;

  /// Form alanı yer tutucusu. card üstünde 5,16:1 (metin eşiği 4,50).
  static const int placeholder = BldColors.neutral400;

  /// Kart zemini = surface-1.
  static const int card = 0xFF261B14;

  /// Kart içi metin. card üstünde 14,22:1 (metin eşiği 4,50).
  static const int cardForeground = BldColors.neutral100;

  /// Açılır katman = surface-2.
  static const int popover = 0xFF32261E;

  /// Açılır katman metni. popover üstünde 12,41:1 (metin eşiği 4,50).
  static const int popoverForeground = BldColors.neutral100;

  /// Koyu temanın birincil DOLGUSU. İlişki tersine döner: açık dolgu + koyu
  /// etiket. Etiketi (primary-foreground) ile 9,22:1 (metin eşiği 4,50).
  static const int primary = BldColors.brand300;

  /// Birincil buton etiketi (koyu).
  static const int primaryForeground = BldColors.neutral950;

  /// Birincil butonun hover adımı — koyu temada hover DAHA AÇIK olur. Etiketi
  /// (primary-foreground) ile 12,15:1 (metin eşiği 4,50).
  static const int primaryHover = BldColors.brand200;

  /// Ghost buton ve marka vurgulu METİN. Dolgudan farklı ton: brand300 metin
  /// olarak fazla parlak. background üstünde 6,95:1 (metin eşiği 4,50).
  static const int primaryText = BldColors.brand400;

  /// Tonal buton dolgusu. Etiketi (secondary-foreground) ile 6,95:1 (metin
  /// eşiği 4,50).
  static const int secondary = 0xFF462314;

  /// Tonal buton etiketi.
  static const int secondaryForeground = BldColors.brand300;

  /// Vurgu yüzeyi. Etiketi (accent-foreground) ile 6,95:1 (metin eşiği 4,50).
  static const int accent = 0xFF462314;

  /// Vurgu yüzeyi metni.
  static const int accentForeground = BldColors.brand300;

  /// Sıcak anlatım bandı.
  static const int surfaceWarm = 0xFF462314;

  /// Sıcak bant metni. surface-warm üstünde 11,76:1 (metin eşiği 4,50).
  static const int surfaceWarmForeground = BldColors.neutral100;

  /// DEKORATİF ayraç.
  static const int border = 0xFF43352B;

  /// İŞLEVSEL kontrol kenarlığı. surface-2 üstünde 2,63 kalıyor — form alanı
  /// surface-2 üstüne KOYULMAZ. background üstünde 3,31:1 (kontrol eşiği 3,00).
  static const int input = 0xFF75655A;

  /// Odak halkası. background üstünde 6,95:1 (kontrol eşiği 3,00).
  static const int ring = BldColors.brand400;

  /// Bağlantı metni. background üstünde 6,95:1 (metin eşiği 4,50).
  static const int link = BldColors.brand400;

  /// Dolu yıkıcı buton — açık dolgu + koyu etiket. Etiketi
  /// (destructive-foreground) ile 7,70:1 (metin eşiği 4,50).
  static const int destructive = BldColors.danger300;

  /// Yıkıcı buton etiketi.
  static const int destructiveForeground = BldColors.neutral950;

  /// Başarı METNİ. background üstünde 7,24:1 (metin eşiği 4,50).
  static const int success = BldColors.success400;

  /// Başarı tinti.
  static const int successSurface = 0xFF1F341C;

  /// Tint üstündeki başarı metni. success-surface üstünde 5,26:1 (metin eşiği
  /// 4,50).
  static const int successForeground = BldColors.success400;

  /// Uyarı METNİ. background üstünde 9,51:1 (metin eşiği 4,50).
  static const int warning = BldColors.warning300;

  /// Uyarı tinti.
  static const int warningSurface = 0xFF392C0C;

  /// Tint üstündeki uyarı metni. warning-surface üstünde 7,04:1 (metin eşiği
  /// 4,50).
  static const int warningForeground = BldColors.warning300;

  /// Hata METNİ. background üstünde 7,70:1 (metin eşiği 4,50).
  static const int danger = BldColors.danger300;

  /// Hata tinti.
  static const int dangerSurface = 0xFF4B1D20;

  /// Tint üstündeki hata metni. danger-surface üstünde 5,86:1 (metin eşiği
  /// 4,50).
  static const int dangerForeground = BldColors.danger300;

  /// Bilgi METNİ. background üstünde 9,59:1 (metin eşiği 4,50).
  static const int info = BldColors.info300;

  /// Bilgi tinti.
  static const int infoSurface = 0xFF1A2F46;

  /// Tint üstündeki bilgi metni. info-surface üstünde 7,09:1 (metin eşiği
  /// 4,50).
  static const int infoForeground = BldColors.info300;

  /// Skeleton tabanı.
  static const int skeletonBase = 0xFF32261E;

  /// Skeleton parıltısı.
  static const int skeletonSheen = 0xFF43352B;
}

// ═══ ÜRETİM SONU — AŞAĞISI ELLE YAZILIR ═══

/// Mutfak ekranı renkleri — `docs/05-mutfakapp.md` §3.
///
/// KDS uzaktan okunur; bu yüzden koyu zemin ve yüksek kontrast kullanılır,
/// müşteri arayüzünün açık temasından ayrışır. Bu sınıf ÜRETİLMEZ: mutfak
/// ekranının okuma mesafesi (bir metre) müşteri yüzeylerinin rol tablosuyla
/// aynı kurallara tabi değil, kendi kararları var.
abstract final class KdsColors {
  static const int background = 0xFF16130F;
  static const int surface = 0xFF241E18;
  static const int surfaceRaised = 0xFF332A21;
  static const int onSurface = 0xFFF5F5F4;
  static const int onSurfaceMuted = 0xFFA8A29E;

  /// Sipariş notu vurgusu — asla gizlenmez, kırmızı zeminde basılır.
  static const int noteBackground = 0xFF7F1D1D;
  static const int noteForeground = 0xFFFFF1F2;

  /// Adrese gönderim rozeti.
  ///
  /// **Neden `brand500` değil `brand400`:** terrakota palete geçince eski
  /// turuncu (#F97316, KDS zemininde 6,61:1) yerini #DD5D02'ye bıraktı ve
  /// rozet 4,97:1'e düştü. AA'yı geçiyor ama KDS bir metre öteden, mutfak
  /// ışığında okunuyor — telefon ekranıyla aynı eşiğe razı olamaz. `brand400`
  /// (#E8863F) 6,98:1 veriyor ve eski okunaklılığı geri getiriyor.
  static const int badgeDelivery = BldColors.brand400;

  /// Gel-al rozeti.
  ///
  /// Bir adım YUKARI kaydı çünkü nötr rampanın kendisi kaydı: eski
  /// `neutral400` soğuk gri #A8A29E idi (bu zeminde 7,34:1), yenisi sıcak
  /// #A28A78 ve 5,68:1'e düşüyor. Eski tonun görsel ağırlığı artık
  /// `neutral300`'de (#D2C3B4, 10,76:1) yaşıyor.
  static const int badgePickup = BldColors.neutral300;

  /// Bağlantı ve yazıcı göstergeleri (durum çubuğu).
  ///
  /// **Neden çıplak `BldColors.success` değil:** çıplak takma adlar METİN
  /// adımına (700) işaret ediyor ve o adım AÇIK zemin içindir. KDS'in zemini
  /// `background` (#16130F); orada 700 tonu 2,8:1'e düşüyordu. Koyu yüzeyin
  /// metin adımları (success400 / warning300 / danger300) 7:1 üstü veriyor.
  static const int statusOk = BldColors.success400;
  static const int statusWarn = BldColors.warning300;
  static const int statusDown = BldColors.danger300;
}
