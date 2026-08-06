/**
 * Menü çözümleri — örnek menü kurguları.
 *
 * Burada **fiyat yoktur.** Repoda doğrulanmış birim fiyat bilgisi yok ve
 * catering fiyatı zaten kişi sayısı, hizmet sıklığı ve konuma göre değişiyor;
 * uydurma rakam yerine teklif akışına yönlendiriyoruz.
 *
 * Menü içerikleri **örnektir**: firmanın gerçekte uyguladığı menüler
 * girildiğinde bu dosya güncellenir, sayfalara dokunmak gerekmez.
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
    summary: 'Çorba, ana yemek, yardımcı yemek ve tatlı/salata düzeniyle klasik öğle menüsü.',
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
    principle:
      'Haftalık menüde aynı ana yemek tekrar etmez; et, tavuk ve baklagil öğünleri dengeli dağıtılır.',
  },
  {
    slug: 'personel-uc-kap',
    title: 'Personel üç kap',
    summary: 'Daha kısa öğün molalarına uygun, hızlı servis edilebilen düzen.',
    audience: 'Vardiyalı çalışan üretim tesisleri ve saha ekipleri',
    courses: [
      { label: 'Çorba', examples: ['Mercimek çorbası', 'Tarhana'] },
      { label: 'Ana yemek', examples: ['Etli nohut', 'Köfte', 'Tavuk haşlama'] },
      { label: 'Tamamlayıcı', examples: ['Pilav', 'Ekmek', 'Ayran'] },
    ],
    principle:
      'Servis hızı önceliklidir: porsiyonlama kolay, sıcak kalma süresi uzun yemekler seçilir.',
  },
  {
    slug: 'ogrenci-menusu',
    title: 'Öğrenci menüsü',
    summary: 'Yaş grubuna göre porsiyonlanmış, alerjen bilgisi işaretlenmiş öğünler.',
    audience: 'Anaokulu, ilkokul, ortaokul ve liseler',
    courses: [
      { label: 'Çorba veya başlangıç', examples: ['Sebze çorbası', 'Şehriye çorbası'] },
      { label: 'Ana yemek', examples: ['Fırın makarna', 'Köfte', 'Sebzeli tavuk'] },
      { label: 'Tamamlayıcı', examples: ['Pilav', 'Yoğurt', 'Meyve'] },
      { label: 'İkindi ikramı', examples: ['Süt', 'Kek', 'Kuru meyve'] },
    ],
    principle:
      'Çocukların gerçekten tükettiği biçimler tercih edilir; ağır baharat ve sos kullanılmaz.',
  },
  {
    slug: 'kahvalti-ikram',
    title: 'Kahvaltı ve ikram paketleri',
    summary: 'Toplantı, eğitim ve etkinlikler için kurulumu hızlı ikram düzenleri.',
    audience: 'Toplantı, seminer, eğitim ve lansmanlar',
    courses: [
      { label: 'Açık büfe kahvaltı', examples: ['Peynir çeşitleri', 'Zeytin', 'Yumurta', 'Reçel'] },
      { label: 'Fırın ürünleri', examples: ['Poğaça', 'Açma', 'Simit', 'Börek'] },
      { label: 'Ara ikram', examples: ['Kurabiye', 'Meyve tabağı', 'Kuruyemiş'] },
      { label: 'İçecek', examples: ['Çay', 'Filtre kahve', 'Meyve suyu'] },
    ],
    principle: 'Elde tüketilebilen, servis gerektirmeyen seçenekler öne alınır.',
  },
  {
    slug: 'davet-menusu',
    title: 'Davet menüsü',
    summary: 'Düğün, açılış ve kurumsal davetler için kapsamlı servis menüsü.',
    audience: 'Düğün, nişan, açılış ve kurumsal davetler',
    courses: [
      { label: 'Karşılama', examples: ['Soğuk mezeler', 'Kanepe', 'Limonata'] },
      { label: 'Başlangıç', examples: ['Çorba', 'Soğuk başlangıç tabağı'] },
      { label: 'Ana yemek', examples: ['Fırın et', 'Tavuk şiş', 'Sebzeli et sote'] },
      { label: 'Tamamlayıcı', examples: ['Pilav', 'Salata', 'Sıcak börek'] },
      { label: 'Tatlı', examples: ['Sütlü tatlı', 'Şerbetli tatlı', 'Meyve'] },
    ],
    principle:
      'Menü etkinliğin saatine göre kurulur; öğle davetinde daha hafif, akşam davetinde daha kapsamlı bir akış tercih edilir.',
  },
  {
    slug: 'ozel-beslenme',
    title: 'Vejetaryen ve özel beslenme',
    summary: 'Ana menüye alternatif olarak planlanan özel ihtiyaç öğünleri.',
    audience: 'Vejetaryen, alerjisi olan veya özel diyet uygulayan katılımcılar',
    courses: [
      {
        label: 'Ana yemek',
        examples: ['Sebzeli güveç', 'Nohutlu bulgur pilavı', 'Mercimek köfte'],
      },
      { label: 'Tamamlayıcı', examples: ['Yeşil salata', 'Humus', 'Yoğurt (istenirse)'] },
      { label: 'Alerjen yönetimi', examples: ['Glutensiz seçenek', 'Laktozsuz seçenek'] },
    ],
    principle:
      'Özel öğün ana menüden ayrı hazırlanır ve etiketlenir; çapraz bulaşma riskini azaltmak için ayrı kaplarda taşınır.',
  },
];

/**
 * Mevsim yaklaşımı — menü çözümleri sayfasında tek bir bant olarak gösterilir.
 */
export const SEASONAL_APPROACH: readonly { readonly season: string; readonly note: string }[] = [
  { season: 'İlkbahar', note: 'Taze sebze öğünleri ve yeşillik ağırlıklı salatalar öne alınır.' },
  { season: 'Yaz', note: 'Hafif öğünler, soğuk başlangıçlar ve ayran/limonata tüketimi artar.' },
  { season: 'Sonbahar', note: 'Baklagil ve kök sebze yemekleri menüde ağırlık kazanır.' },
  { season: 'Kış', note: 'Çorba çeşidi artırılır; doyurucu ve sıcak tutan öğünler öne çıkar.' },
];
