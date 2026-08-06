/**
 * Hizmet kataloğu — **YEDEK / BAŞLANGIÇ DEĞERİ**.
 *
 * Tek kaynak admin panelidir; hizmet listesi ve detay sayfaları içeriği
 * `lib/api/site-content.ts` üzerinden alır. Panelden gelen hizmetler ayrıca
 * serbest bir `body_html` gövdesi taşıyabilir — yedekte böyle bir alan yok,
 * çünkü buradaki metinler zaten yapılandırılmış alanlara bölünmüş durumda.
 *
 * Metinler bilinçli olarak **yeteneği** anlatır, **iddiayı** değil: "şu kadar
 * kişiye hizmet veriyoruz" gibi doğrulanmamış rakamlar yok, çünkü repoda böyle
 * bir veri yok (bkz. `content/site.ts`).
 */

import type { LucideIcon } from 'lucide-react';
import {
  Building2,
  CalendarHeart,
  ChefHat,
  Coffee,
  GraduationCap,
  HardHat,
  Stethoscope,
  Truck,
} from 'lucide-react';

export interface Service {
  readonly slug: string;
  readonly title: string;
  /** Kart üzerinde görünen tek cümlelik özet. */
  readonly summary: string;
  /** Detay sayfası hero açıklaması. */
  readonly intro: string;
  readonly icon: LucideIcon;
  /** Kimler için uygun? */
  readonly audience: readonly string[];
  /** Hizmet nasıl işler? Sıralı adımlar. */
  readonly howItWorks: readonly { readonly title: string; readonly body: string }[];
  /** Müşteriye ne kazandırır? */
  readonly benefits: readonly string[];
  /** Menü nasıl planlanır? */
  readonly menuPlanning: string;
  /** Teklif almak için ne gerekir? */
  readonly quoteNeeds: readonly string[];
}

export const SERVICES: readonly Service[] = [
  {
    slug: 'kurumsal-toplu-yemek',
    title: 'Kurumsal toplu yemek',
    summary: 'Ofis, fabrika ve iş yerleri için her gün tekrarlayan öğün hizmeti.',
    intro:
      'Çalışanlarınızın öğle ve akşam öğünlerini, iş temponuzu aksatmayacak bir düzende planlıyoruz. Menü haftalık olarak önceden paylaşılır, üretim ve teslimat saatleri vardiyanıza göre belirlenir.',
    icon: Building2,
    audience: [
      'Beyaz ve mavi yaka çalışanı olan iş yerleri',
      'Vardiyalı çalışan üretim tesisleri',
      'Yemekhanesi olan veya olmayan ofisler',
      'Personeline düzenli öğün sağlamak isteyen kurumlar',
    ],
    howItWorks: [
      {
        title: 'İhtiyaç görüşmesi',
        body: 'Günlük kişi sayısı, öğün saatleri, vardiya düzeni ve varsa mevcut yemekhane altyapınız konuşulur.',
      },
      {
        title: 'Menü planı',
        body: 'Haftalık veya aylık menü hazırlanır. Mevsim, tekrar dengesi ve besin çeşitliliği gözetilir; onayınıza sunulur.',
      },
      {
        title: 'Üretim ve teslimat',
        body: 'Öğünler merkez mutfakta hazırlanır, sıcaklık kontrollü kaplarda belirlenen saatte teslim edilir.',
      },
      {
        title: 'Servis ve geri bildirim',
        body: 'Servis düzeni kurulur, artan-eksilen takip edilir ve menü geri bildirime göre güncellenir.',
      },
    ],
    benefits: [
      'Mutfak kurma ve personel istihdam etme yükü ortadan kalkar',
      'Öğün maliyeti öngörülebilir hâle gelir',
      'Menü tekrarı ve besin dengesi takip edilir',
      'Tek muhatapla çalışırsınız; sipariş, teslimat ve faturalama tek akışta ilerler',
    ],
    menuPlanning:
      'Menü, çalışan profilinize göre kurgulanır. Ağır iş kolunda kalori ihtiyacı yüksek öğünler, ofis ortamında daha hafif seçenekler öne alınır. Vejetaryen ve özel beslenme ihtiyaçları için alternatif kap eklenebilir.',
    quoteNeeds: [
      'Günlük ortalama kişi sayısı',
      'Öğün türü ve saatleri (öğle, akşam, vardiya arası)',
      'Hizmet konumu',
      'Haftalık hizmet günü sayısı',
    ],
  },
  {
    slug: 'tasima-yemek',
    title: 'Taşıma yemek',
    summary: 'Merkez mutfakta üretim, sıcaklık kontrollü kaplarda yerinde teslim.',
    intro:
      'Kendi mutfağı bulunmayan veya mutfağını işletmek istemeyen kurumlar için yemek merkez mutfağımızda hazırlanır ve servise hazır biçimde adresinize ulaştırılır.',
    icon: Truck,
    audience: [
      'Mutfak altyapısı olmayan iş yerleri',
      'Küçük ve orta ölçekli ofisler',
      'Geçici veya proje bazlı çalışma alanları',
      'Yemekhanesi yalnızca servis alanı olan kurumlar',
    ],
    howItWorks: [
      {
        title: 'Sipariş ve planlama',
        body: 'Günlük kişi sayısı ve teslim saati belirlenir; menü önceden paylaşılır.',
      },
      {
        title: 'Merkez mutfakta üretim',
        body: 'Öğünler teslim saatine göre planlanan üretim akışıyla hazırlanır.',
      },
      {
        title: 'Sıcaklık kontrollü taşıma',
        body: 'Yemek, sıcak ve soğuk zinciri koruyan kaplarla taşınır; teslimde sıcaklık kontrol edilir.',
      },
      {
        title: 'Servise hazır teslim',
        body: 'Öğünler servis alanınıza kurulur veya kapalı kaplarda teslim edilir.',
      },
    ],
    benefits: [
      'Mutfak yatırımı ve işletme gideri gerekmez',
      'Servis alanı dışında yer ayırmanız gerekmez',
      'Kişi sayısı değişken olduğunda hızlı uyarlanır',
      'Teslimat saati iş akışınıza göre sabitlenir',
    ],
    menuPlanning:
      'Taşımaya uygun yemekler öne alınır: uzun süre sıcak kalabilen, taşıma sırasında yapısı bozulmayan seçenekler. Kızartma gibi çabuk yumuşayan kaplar teslim saatine yakın planlanır.',
    quoteNeeds: [
      'Günlük kişi sayısı',
      'Teslim adresi ve teslim saati',
      'Kap sayısı tercihi (üç kap, dört kap)',
      'Servis malzemesi ihtiyacınız olup olmadığı',
    ],
  },
  {
    slug: 'yerinde-uretim',
    title: 'Yerinde üretim',
    summary: 'Kurumun kendi mutfağında, bizim ekibimizle günlük üretim.',
    intro:
      'Mutfak altyapısı bulunan kurumlarda üretimi yerinde yapıyoruz. Yemek servis edileceği yerde pişer; taşıma süresi ortadan kalkar, tazelik en üst düzeyde kalır.',
    icon: ChefHat,
    audience: [
      'Kendi mutfağı olan fabrika ve kampüsler',
      'Yemekhane işletmesini dışarıya vermek isteyen kurumlar',
      'Yüksek kişi sayısına düzenli hizmet veren tesisler',
      'Kahvaltı, öğle ve akşam öğünlerini aynı yerde veren kuruluşlar',
    ],
    howItWorks: [
      {
        title: 'Mutfak değerlendirmesi',
        body: 'Mevcut ekipman, depolama alanı, havalandırma ve personel ihtiyacı yerinde incelenir.',
      },
      {
        title: 'Ekip ve düzen kurulumu',
        body: 'Aşçı ve servis ekibi görevlendirilir, üretim akışı ve hijyen düzeni kurulur.',
      },
      {
        title: 'Günlük üretim',
        body: 'Malzeme tedariği bize aittir; öğünler servis saatine göre yerinde hazırlanır.',
      },
      {
        title: 'Servis ve raporlama',
        body: 'Servis yürütülür, tüketim ve stok takibi düzenli olarak paylaşılır.',
      },
    ],
    benefits: [
      'Yemek servis edildiği yerde pişer, taşıma kaybı olmaz',
      'Menü gün içinde ihtiyaca göre esnetilebilir',
      'Mutfak personeli yönetimi sizin üzerinizden kalkar',
      'Tedarik, hijyen ve servis tek elden yürütülür',
    ],
    menuPlanning:
      'Yerinde üretimde menü esnekliği en yüksek seviyededir. Günlük taze pişirme, açık büfe düzeni ve talebe göre porsiyon ayarı mümkündür. Menü, mutfağın ekipman kapasitesine göre planlanır.',
    quoteNeeds: [
      'Günlük kişi sayısı ve öğün sayısı',
      'Mutfak alanı ve mevcut ekipman bilgisi',
      'Servis düzeni (tabldot, açık büfe)',
      'Sözleşme süresi beklentiniz',
    ],
  },
  {
    slug: 'okul-yemek-hizmeti',
    title: 'Okul yemek hizmeti',
    summary: 'Yaş grubuna göre planlanmış öğünler ve alerjen takibi.',
    intro:
      'Okul öncesinden liseye kadar farklı yaş gruplarının beslenme ihtiyacı aynı değildir. Menüleri porsiyon, besin dengesi ve çocukların gerçekten yediği yemekler gözetilerek planlıyoruz.',
    icon: GraduationCap,
    audience: [
      'Anaokulu ve kreşler',
      'İlkokul, ortaokul ve liseler',
      'Özel eğitim kurumları',
      'Yurtlar ve pansiyonlar',
    ],
    howItWorks: [
      {
        title: 'Yaş grubu ve öğün planı',
        body: 'Kahvaltı, öğle ve ikindi ikramı ihtiyacı yaş grubuna göre belirlenir.',
      },
      {
        title: 'Alerjen ve özel durum kaydı',
        body: 'Alerjisi veya özel beslenme ihtiyacı olan öğrenciler listelenir; alternatif öğün planlanır.',
      },
      {
        title: 'Üretim ve teslim',
        body: 'Öğünler ders saatlerine göre planlanan zamanda hazırlanır ve teslim edilir.',
      },
      {
        title: 'Veli bilgilendirme',
        body: 'Aylık menü, kurumun tercih ettiği kanaldan velilerle paylaşılabilecek biçimde hazırlanır.',
      },
    ],
    benefits: [
      'Menü yaş grubuna göre porsiyonlanır',
      'Alerjen bilgisi öğrenci bazında takip edilir',
      'Aylık menü velilerle paylaşılabilir biçimde hazırlanır',
      'Öğün saatleri ders programına göre sabitlenir',
    ],
    menuPlanning:
      'Menüde sebze ve baklagil öğünleri, çocukların tükettiği biçimlerle sunulur. Aşırı baharat ve ağır soslardan kaçınılır. Aylık menü tekrar dengesi gözetilerek kurulur ve okul yönetiminin onayına sunulur.',
    quoteNeeds: [
      'Öğrenci sayısı ve yaş grupları',
      'Günlük öğün sayısı (kahvaltı, öğle, ikindi)',
      'Alerjisi olan öğrenci sayısı',
      'Eğitim döneminde hizmet verilecek gün sayısı',
    ],
  },
  {
    slug: 'saglik-kuruluslari',
    title: 'Sağlık kuruluşlarına yemek hizmeti',
    summary: 'Hasta, personel ve refakatçi öğünlerinin ayrı planlanması.',
    intro:
      'Sağlık kuruluşlarında tek bir menü yeterli olmaz: hasta diyetleri, personel öğünleri ve refakatçi yemekleri farklı planlanır. Üçünü ayrı akışlarda yürütecek biçimde çalışıyoruz.',
    icon: Stethoscope,
    audience: [
      'Hastaneler ve tıp merkezleri',
      'Diyaliz ve rehabilitasyon merkezleri',
      'Huzurevleri ve bakım evleri',
      'Poliklinik ve sağlık kampüsleri',
    ],
    howItWorks: [
      {
        title: 'Diyet listelerinin alınması',
        body: 'Kurumun diyetisyeni tarafından belirlenen diyet tipleri ve öğün sayıları alınır.',
      },
      {
        title: 'Ayrı üretim akışı',
        body: 'Diyet öğünleri, personel ve refakatçi öğünlerinden ayrı hazırlanır ve etiketlenir.',
      },
      {
        title: 'Kat ve birim dağıtımı',
        body: 'Öğünler servis saatinde ilgili birime, hasta bazlı etiketiyle ulaştırılır.',
      },
      {
        title: 'Takip ve düzeltme',
        body: 'Değişen diyet talimatları gün içinde güncellenebilecek şekilde işlenir.',
      },
    ],
    benefits: [
      'Hasta, personel ve refakatçi öğünleri karışmaz',
      'Diyet talimatları öğün bazında etiketlenir',
      'Servis saatleri vizit ve tedavi düzenine göre ayarlanır',
      'Gün içi değişikliklere uyarlanabilir bir akış kurulur',
    ],
    menuPlanning:
      'Diyet menüleri kurumun diyetisyeninin belirlediği listelere göre uygulanır; biz üretim ve teslimat tarafını yürütürüz. Personel menüsü ise vardiya saatlerine göre planlanır.',
    quoteNeeds: [
      'Yatak kapasitesi ve ortalama doluluk',
      'Diyet tipleri ve günlük öğün sayısı',
      'Personel sayısı ve vardiya düzeni',
      'Birim/kat dağıtım gereksinimi',
    ],
  },
  {
    slug: 'santiye-yemek',
    title: 'Şantiye yemek hizmeti',
    summary: 'Vardiyalı çalışmaya uygun, sahada teslim edilen doyurucu öğünler.',
    intro:
      'Şantiyede öğün saati sabit değildir ve iş ağırdır. Menüyü kalori ihtiyacına göre kuruyor, teslimatı vardiya değişimine göre planlıyoruz.',
    icon: HardHat,
    audience: [
      'İnşaat şantiyeleri',
      'Altyapı ve enerji projeleri',
      'Maden ve saha operasyonları',
      'Geçici işçi kampları',
    ],
    howItWorks: [
      {
        title: 'Saha ve vardiya bilgisi',
        body: 'Şantiye konumu, ulaşım koşulları ve vardiya saatleri belirlenir.',
      },
      {
        title: 'Kalori odaklı menü',
        body: 'Ağır işe uygun, doyurucu ve dengeli menü kurulur.',
      },
      {
        title: 'Sahaya teslimat',
        body: 'Öğünler sıcaklık kontrollü kaplarla, vardiya değişimine yetişecek şekilde ulaştırılır.',
      },
      {
        title: 'Sayı takibi',
        body: 'Değişken personel sayısına göre günlük öğün adedi güncellenir.',
      },
    ],
    benefits: [
      'Vardiya saatlerine göre teslimat',
      'Ağır iş koluna uygun kalori planlaması',
      'Değişken personel sayısına hızlı uyum',
      'Sahada servis düzeni kurulumu',
    ],
    menuPlanning:
      'Menüde et ve baklagil ağırlıklı, uzun süre tok tutan yemekler öne alınır. Yaz aylarında ayran ve soğuk yan ürünler, kış aylarında çorba öne çıkarılır.',
    quoteNeeds: [
      'Şantiye konumu ve ulaşım koşulları',
      'Vardiya sayısı ve saatleri',
      'Ortalama günlük personel sayısı',
      'Projenin tahmini süresi',
    ],
  },
  {
    slug: 'davet-organizasyon',
    title: 'Davet ve organizasyon catering',
    summary: 'Düğün, açılış ve kurumsal etkinlikler için kurulumlu catering.',
    intro:
      'Davetlerde yemek kadar servis düzeni de önemlidir. Menü, sunum ve servis ekibini etkinliğin akışına göre planlıyoruz.',
    icon: CalendarHeart,
    audience: [
      'Düğün, nişan ve kına organizasyonları',
      'Açılış ve tanıtım etkinlikleri',
      'Kurumsal yemekler ve yıl sonu davetleri',
      'Özel gün kutlamaları',
    ],
    howItWorks: [
      {
        title: 'Etkinlik görüşmesi',
        body: 'Tarih, davetli sayısı, mekân ve servis biçimi (açık büfe, masaya servis) belirlenir.',
      },
      {
        title: 'Menü seçimi',
        body: 'Etkinliğin saatine ve karakterine göre menü kurgulanır, tadım planlanabilir.',
      },
      {
        title: 'Mekân kurulumu',
        body: 'Servis alanı, büfe düzeni ve ekipman etkinlikten önce kurulur.',
      },
      {
        title: 'Servis ve toplama',
        body: 'Servis ekibi etkinlik boyunca görev alır; sonrasında alan toplanır.',
      },
    ],
    benefits: [
      'Menü ve servis biçimi etkinliğe göre kurgulanır',
      'Kurulum ve toplama dâhil tek paket',
      'Davetli sayısındaki son dakika değişiklikleri için pay bırakılır',
      'Servis ekibi etkinlik boyunca sahada kalır',
    ],
    menuPlanning:
      'Menü etkinliğin saatine göre değişir: öğle davetinde daha hafif, akşam davetinde daha kapsamlı bir kurgu tercih edilir. Vejetaryen ve alerjen alternatifleri davetli listesine göre eklenir.',
    quoteNeeds: [
      'Etkinlik tarihi ve saati',
      'Davetli sayısı',
      'Mekân adresi ve mutfak/servis imkânları',
      'Servis biçimi tercihi',
    ],
  },
  {
    slug: 'toplanti-ikram',
    title: 'Toplantı ve etkinlik ikramları',
    summary: 'Kahvaltı, coffee break ve seminer ikram paketleri.',
    intro:
      'Toplantı ve eğitimlerde ikram, programı bölmeden kurulup toplanmalıdır. Paketleri katılımcı sayısına ve program akışına göre hazırlıyoruz.',
    icon: Coffee,
    audience: [
      'Kurumsal toplantı ve eğitimler',
      'Seminer ve konferanslar',
      'Kurul ve yönetim toplantıları',
      'Basın toplantıları ve lansmanlar',
    ],
    howItWorks: [
      {
        title: 'Program akışı',
        body: 'Toplantı saatleri ve ara zamanları alınır; ikram noktaları belirlenir.',
      },
      {
        title: 'Paket seçimi',
        body: 'Kahvaltı, ara ikram veya öğle paketi arasından ihtiyaca uygun olan seçilir.',
      },
      {
        title: 'Kurulum',
        body: 'İkram alanı program başlamadan önce hazırlanır.',
      },
      {
        title: 'Ara servisi',
        body: 'Aralarda tazeleme yapılır, program sonunda alan toplanır.',
      },
    ],
    benefits: [
      'İkram programı bölmeden kurulur ve toplanır',
      'Katılımcı sayısına göre paket ölçeklenir',
      'Sıcak ve soğuk seçenekler bir arada sunulur',
      'Aynı gün içinde birden fazla ara desteklenir',
    ],
    menuPlanning:
      'Ara ikramlarda elde tüketilebilen, servis gerektirmeyen seçenekler öne alınır. Uzun programlarda ara menüsü tekrar etmeyecek biçimde çeşitlendirilir.',
    quoteNeeds: [
      'Etkinlik tarihi ve program saatleri',
      'Katılımcı sayısı',
      'Ara sayısı ve ikram türü',
      'Etkinlik adresi',
    ],
  },
];
