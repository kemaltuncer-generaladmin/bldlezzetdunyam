/**
 * Menü çözümleri — örnek menü kurguları.
 *
 * Burada **fiyat yoktur.** Repoda doğrulanmış birim fiyat bilgisi yok ve
 * catering fiyatı zaten kişi sayısı, hizmet sıklığı ve konuma göre değişiyor;
 * uydurma rakam yerine teklif akışına yönlendiriyoruz.
 *
 * **YEDEK / BAŞLANGIÇ DEĞERİ.** Tek kaynak admin panelidir; sayfa menüleri
 * `lib/api/site-content.ts` üzerinden okur. Panelde bir kabın örnekleri
 * virgülle ayrılmış TEK METİN olarak giriliyor, siteye gelirken diziye
 * çevriliyor — burada zaten dizi olarak duruyorlar.
 *
 * Menü içerikleri **örnektir**: firmanın gerçekte uyguladığı menüler panele
 * girildiğinde bu dosyaya dokunmak gerekmez.
 */

export interface MenuCourse {
  readonly label: string;
  readonly examples: readonly string[];
}

export interface MenuSolution {
  readonly slug: string;
  readonly title: string;
  readonly summary: string;
  /** Kimin için kurgulandığı. */
  readonly audience: string;
  readonly courses: readonly MenuCourse[];
  /** Bu menünün planlanmasında öne çıkan ilke. */
  readonly principle: string;
}

export const MENU_SOLUTIONS: readonly MenuSolution[] = [
  {
    slug: 'kurumsal-dort-kap',
    title: 'Kurumsal dört kap',
    summary: 'Çorba, ana yemek, pilav ve yanına bir salata. Klasik öğle sofrası.',
    audience: 'Ofis, fabrika ve kurumsal yemekhaneler',
    courses: [
      { label: 'Çorba', examples: ['Mercimek çorbası', 'Ezogelin', 'Yayla çorbası'] },
      {
        label: 'Ana yemek',
        examples: ['Etli kuru fasulye', 'Tavuk sote', 'Fırın tavuk but', 'Etli türlü'],
      },
      { label: 'Yardımcı yemek', examples: ['Pirinç pilavı', 'Bulgur pilavı', 'Makarna'] },
      { label: 'Tamamlayıcı', examples: ['Mevsim salata', 'Cacık', 'Ayran', 'Mevsim meyvesi'] },
    ],
    principle: 'Aynı ana yemek hafta içinde iki kez çıkmaz. Et, tavuk ve baklagil güne dağıtılır.',
  },
  {
    slug: 'personel-uc-kap',
    title: 'Personel üç kap',
    summary: 'Molası kısa olan yerler için. Çabuk servis edilir, çabuk yenir.',
    audience: 'Vardiyalı çalışan üretim tesisleri ve saha ekipleri',
    courses: [
      { label: 'Çorba', examples: ['Mercimek çorbası', 'Tarhana'] },
      { label: 'Ana yemek', examples: ['Etli nohut', 'Köfte', 'Tavuk haşlama'] },
      { label: 'Tamamlayıcı', examples: ['Pilav', 'Ekmek', 'Ayran'] },
    ],
    principle:
      'Kepçeyle kolay dağılan, uzun süre sıcak kalan yemekleri seçiyoruz. Sıra hızlı akıyor.',
  },
  {
    slug: 'ogrenci-menusu',
    title: 'Öğrenci menüsü',
    summary: 'Yaşa göre porsiyon, tabakta alerjen işareti.',
    audience: 'Anaokulu, ilkokul, ortaokul ve liseler',
    courses: [
      { label: 'Çorba veya başlangıç', examples: ['Sebze çorbası', 'Şehriye çorbası'] },
      { label: 'Ana yemek', examples: ['Fırın makarna', 'Köfte', 'Sebzeli tavuk'] },
      { label: 'Tamamlayıcı', examples: ['Pilav', 'Yoğurt', 'Meyve'] },
      { label: 'İkindi ikramı', examples: ['Süt', 'Kek', 'Kuru meyve'] },
    ],
    principle: 'Çocuğun yediği biçimde veriyoruz. Ağır baharat ve yoğun sos yok.',
  },
  {
    slug: 'kahvalti-ikram',
    title: 'Kahvaltı ve ikram paketleri',
    summary: 'Toplantı ve eğitimlere, kurulumu on dakika süren ikram masaları.',
    audience: 'Toplantı, seminer, eğitim ve lansmanlar',
    courses: [
      { label: 'Açık büfe kahvaltı', examples: ['Peynir çeşitleri', 'Zeytin', 'Yumurta', 'Reçel'] },
      { label: 'Fırın ürünleri', examples: ['Poğaça', 'Açma', 'Simit', 'Börek'] },
      { label: 'Ara ikram', examples: ['Kurabiye', 'Meyve tabağı', 'Kuruyemiş'] },
      { label: 'İçecek', examples: ['Çay', 'Filtre kahve', 'Meyve suyu'] },
    ],
    principle: 'Ayakta, elde yenen şeyler öne çıkıyor. Çatal aramak gerekmiyor.',
  },
  {
    slug: 'davet-menusu',
    title: 'Davet menüsü',
    summary: 'Düğün, açılış ve kurumsal davetlere karşılamadan tatlıya kadar.',
    audience: 'Düğün, nişan, açılış ve kurumsal davetler',
    courses: [
      { label: 'Karşılama', examples: ['Soğuk mezeler', 'Kanepe', 'Limonata'] },
      { label: 'Başlangıç', examples: ['Çorba', 'Soğuk başlangıç tabağı'] },
      { label: 'Ana yemek', examples: ['Fırın et', 'Tavuk şiş', 'Sebzeli et sote'] },
      { label: 'Tamamlayıcı', examples: ['Pilav', 'Salata', 'Sıcak börek'] },
      { label: 'Tatlı', examples: ['Sütlü tatlı', 'Şerbetli tatlı', 'Meyve'] },
    ],
    principle: 'Menüyü saat belirliyor: öğle davetinde daha hafif, akşamda daha uzun bir sofra.',
  },
  {
    slug: 'ozel-beslenme',
    title: 'Vejetaryen ve özel beslenme',
    summary: 'Ana menü uymayanlar için ayrı pişen, ayrı gelen tabak.',
    audience: 'Vejetaryen, alerjisi olan veya özel diyet uygulayan katılımcılar',
    courses: [
      {
        label: 'Ana yemek',
        examples: ['Sebzeli güveç', 'Nohutlu bulgur pilavı', 'Mercimek köfte'],
      },
      { label: 'Tamamlayıcı', examples: ['Yeşil salata', 'Humus', 'Yoğurt (istenirse)'] },
      { label: 'Alerjen yönetimi', examples: ['Glutensiz seçenek', 'Laktozsuz seçenek'] },
    ],
    principle: 'Ayrı tezgâhta hazırlanıyor, üzerine adı yazılıyor, ayrı kapta yola çıkıyor.',
  },
];

/**
 * Mevsim yaklaşımı — menü çözümleri sayfasında tek bir bant olarak gösterilir.
 */
export const SEASONAL_APPROACH: readonly { readonly season: string; readonly note: string }[] = [
  { season: 'İlkbahar', note: 'Taze sebze ve yeşillik menüye giriyor; salata tabağı büyüyor.' },
  { season: 'Yaz', note: 'Yemek hafifliyor, soğuk başlangıçlar ve ayran öne geçiyor.' },
  { season: 'Sonbahar', note: 'Kuru fasulye, nohut ve kök sebzelerin sırası geliyor.' },
  { season: 'Kış', note: 'Çorba çeşidi artıyor; sıcak tutan, doyuran yemekler öne çıkıyor.' },
];
