/**
 * Hizmet kataloğu — **YEDEK / BAŞLANGIÇ DEĞERİ**.
 *
 * Tek kaynak admin panelidir; hizmet listesi ve detay sayfaları içeriği
 * `lib/api/site-content.ts` üzerinden alır. Panelden gelen hizmetler ayrıca
 * serbest bir `body_html` gövdesi taşıyabilir — yedekte böyle bir alan yok,
 * çünkü buradaki metinler zaten yapılandırılmış alanlara bölünmüş durumda.
 *
 * Metinler **yapabildiğimizi** anlatır: "şu kadar kişiye hizmet veriyoruz"
 * gibi doğrulanmamış rakam yok (bkz. `content/site.ts`).
 *
 * Ton kuralları `content/company.ts` başlığında. Özetle: mutfaktan konuş,
 * cümleyi kısa tut, "X değil Y" karşıtlığından ve soyut isim yığınından kaç.
 *
 * ## Görsel
 *
 * Her hizmetin fotoğrafı `public/gorseller/hizmet-<slug>.webp` yolundadır;
 * eşleşme `lib/site-images.ts` içinde slug üzerinden kurulur, burada görsel
 * alanı YOKTUR. Böylece API sözleşmesine alan eklemeden fotoğraf gösterebiliyor
 * ve dosyayı değiştirmek koda dokunmayı gerektirmiyor.
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
    summary: 'Ofis, fabrika ve iş yerlerine her gün tekrarlayan öğle ve akşam yemeği.',
    intro:
      'Her sabah aynı saatte pişer, aynı saatte gelir. Menüyü bir hafta önceden görürsünüz; teslim saatini vardiyanız belirler.',
    icon: Building2,
    audience: [
      'Ofisler ve iş merkezleri',
      'Vardiyalı çalışan üretim tesisleri',
      'Yemekhanesi olan da olmayan da',
      'Personeline her gün sıcak yemek veren kurumlar',
    ],
    howItWorks: [
      {
        title: 'Sayıyı ve saati konuşuyoruz',
        body: 'Günde kaç kişi, hangi saatte, kaç vardiya. Yemekhaneniz varsa gelip bakıyoruz.',
      },
      {
        title: 'Haftalık menüyü çıkarıyoruz',
        body: 'Bir haftalık liste hazırlıyoruz. Aynı yemek üst üste gelmez; onaylayınca kesinleşir.',
      },
      {
        title: 'Pişiriyoruz, getiriyoruz',
        body: 'Yemek sabah mutfakta yapılır, ısı tutan kaplarda saatinde kapınızda olur.',
      },
      {
        title: 'Sayıyor, soruyoruz',
        body: 'Ne arttı, ne bitti bakıyoruz. Kimsenin yemediği yemek bir daha menüye girmiyor.',
      },
    ],
    benefits: [
      'Mutfak kurmak, aşçı tutmak, malzeme almak yok',
      'Öğün maliyetiniz baştan belli',
      'Menü tekrarını biz takip ediyoruz',
      'Sipariş de fatura da tek kişide',
    ],
    menuPlanning:
      'Menü kimin yediğine göre değişir. Ağır işte doyuran yemekler öne çıkar, ofiste daha hafif kaplar. Vejetaryen ya da alerjisi olan varsa onlara ayrı bir kap ekleriz.',
    quoteNeeds: [
      'Günde ortalama kaç kişi',
      'Öğün ve saatleri (öğle, akşam, vardiya arası)',
      'Adres',
      'Haftada kaç gün',
    ],
  },
  {
    slug: 'tasima-yemek',
    title: 'Taşıma yemek',
    summary: 'Yemek bizim mutfakta pişer, servise hazır hâlde adresinize gelir.',
    intro:
      'Mutfağınız yoksa ya da işletmek istemiyorsanız en pratik yol bu. Bizde pişer, kapalı kapta gelir, siz yalnızca servis edersiniz.',
    icon: Truck,
    audience: [
      'Mutfağı olmayan iş yerleri',
      'Küçük ve orta ölçekli ofisler',
      'Proje bazlı, geçici çalışma alanları',
      'Yemekhanesi yalnızca servis alanı olan kurumlar',
    ],
    howItWorks: [
      {
        title: 'Sayı ve saat',
        body: 'Kaç kişi ve saat kaçta. Menüyü önden paylaşıyoruz.',
      },
      {
        title: 'Mutfakta üretim',
        body: 'Teslim saatinden geri sayarak pişiriyoruz — erken pişip bekleyen yemek yok.',
      },
      {
        title: 'Kapalı kapta yol',
        body: 'Sıcak sıcak, soğuk soğuk gider. Kapıda sıcaklığa bakılır.',
      },
      {
        title: 'Servise hazır teslim',
        body: 'İsterseniz servis alanınıza kurarız, isterseniz kapalı kapta bırakırız.',
      },
    ],
    benefits: [
      'Mutfak yatırımı ve işletme gideri yok',
      'Servis alanı dışında yer ayırmıyorsunuz',
      'Sayı değiştiğinde aynı gün uyarlanıyor',
      'Teslim saatini iş akışınız belirliyor',
    ],
    menuPlanning:
      'Yolu iyi götüren yemekleri seçiyoruz: uzun süre sıcak kalan, sarsıntıda dağılmayan kaplar. Kızartma gibi çabuk yumuşayan şeyleri teslim saatine yakın planlıyoruz.',
    quoteNeeds: [
      'Günde kaç kişi',
      'Teslim adresi ve saati',
      'Kaç kap istiyorsunuz (üç kap, dört kap)',
      'Tabak-çatal ihtiyacınız var mı',
    ],
  },
  {
    slug: 'yerinde-uretim',
    title: 'Yerinde üretim',
    summary: 'Sizin mutfağınızda, bizim ekibimizle günlük pişirme.',
    intro:
      'Mutfağınız varsa yemek orada pişsin. Yol yok, bekleme yok; tencereden tabağa geçen süre birkaç dakika.',
    icon: ChefHat,
    audience: [
      'Kendi mutfağı olan fabrika ve kampüsler',
      'Yemekhanesini dışarıya vermek isteyen kurumlar',
      'Yüksek kişi sayılı tesisler',
      'Kahvaltı, öğle ve akşamı aynı yerde veren kuruluşlar',
    ],
    howItWorks: [
      {
        title: 'Mutfağa bakıyoruz',
        body: 'Ekipman, depo, havalandırma ve kaç kişilik ekip gerektiği yerinde çıkarılıyor.',
      },
      {
        title: 'Ekibi kuruyoruz',
        body: 'Aşçı ve servis ekibi göreve başlıyor, mutfağın günlük düzeni oturuyor.',
      },
      {
        title: 'Her gün taze',
        body: 'Malzemeyi biz alıyoruz, yemek servis saatine göre yerinde pişiyor.',
      },
      {
        title: 'Servis ve rapor',
        body: 'Servisi biz yürütüyoruz; ne kadar tüketildiği ve stok durumu düzenli olarak size geliyor.',
      },
    ],
    benefits: [
      'Yemek yendiği yerde pişiyor, yolda tat kaybı yok',
      'Gün içinde menüyü esnetmek mümkün',
      'Mutfak personeli derdi sizden çıkıyor',
      'Malzeme, hijyen ve servis tek elde',
    ],
    menuPlanning:
      'Esnekliğin en yüksek olduğu düzen bu. Açık büfe kurulabilir, porsiyon gün içinde ayarlanabilir, ikinci parti pişirilebilir. Menüyü mutfağın ekipmanı belirler.',
    quoteNeeds: [
      'Günlük kişi ve öğün sayısı',
      'Mutfak alanı ve mevcut ekipman',
      'Servis düzeni (tabldot, açık büfe)',
      'Ne kadar süreli düşünüyorsunuz',
    ],
  },
  {
    slug: 'okul-yemek-hizmeti',
    title: 'Okul yemek hizmeti',
    summary: 'Yaşa göre porsiyon, alerjen takibi ve veliye gösterilebilir menü.',
    intro:
      'Anaokulundaki çocukla lise öğrencisi aynı tabağı yemiyor. Menüyü yaşa göre kuruyoruz ve çocukların gerçekten yediği yemekleri koyuyoruz.',
    icon: GraduationCap,
    audience: [
      'Anaokulu ve kreşler',
      'İlkokul, ortaokul ve liseler',
      'Özel eğitim kurumları',
      'Yurtlar ve pansiyonlar',
    ],
    howItWorks: [
      {
        title: 'Yaş grupları ve öğünler',
        body: 'Kahvaltı, öğle, ikindi — hangisi hangi yaşa, kaç kişilik.',
      },
      {
        title: 'Alerji listesi',
        body: 'Alerjisi ya da özel beslenmesi olan öğrenciler listeleniyor, onlara ayrı öğün planlanıyor.',
      },
      {
        title: 'Ders saatine göre teslim',
        body: 'Yemek teneffüse yetişecek şekilde hazırlanıp getiriliyor.',
      },
      {
        title: 'Veliye gidecek menü',
        body: 'Aylık liste, okulun paylaştığı biçimde hazır geliyor.',
      },
    ],
    benefits: [
      'Porsiyon yaş grubuna göre',
      'Alerjen bilgisi öğrenci bazında takip ediliyor',
      'Aylık menü veliyle paylaşılmaya hazır',
      'Öğün saatleri ders programına kilitli',
    ],
    menuPlanning:
      'Sebzeyi ve baklagili çocukların yediği biçimde veriyoruz. Ağır baharat, yoğun sos yok. Aylık listede aynı yemek sık sık dönmüyor; son hâlini okul yönetimi onaylıyor.',
    quoteNeeds: [
      'Öğrenci sayısı ve yaş grupları',
      'Günde kaç öğün (kahvaltı, öğle, ikindi)',
      'Alerjisi olan öğrenci sayısı',
      'Dönemde kaç gün hizmet',
    ],
  },
  {
    slug: 'saglik-kuruluslari',
    title: 'Sağlık kuruluşlarına yemek',
    summary: 'Hasta diyeti, personel öğünü ve refakatçi yemeği ayrı ayrı.',
    intro:
      'Burada tek menü iş görmüyor. Diyet tabağı, nöbetçi hemşirenin tabağı ve refakatçinin tabağı ayrı hazırlanıyor, ayrı etiketleniyor.',
    icon: Stethoscope,
    audience: [
      'Hastaneler ve tıp merkezleri',
      'Diyaliz ve rehabilitasyon merkezleri',
      'Huzurevleri ve bakım evleri',
      'Poliklinikler ve sağlık kampüsleri',
    ],
    howItWorks: [
      {
        title: 'Diyet listeleri geliyor',
        body: 'Kurumun diyetisyeni hangi diyetten kaç öğün gerektiğini bildiriyor.',
      },
      {
        title: 'Ayrı akış, ayrı etiket',
        body: 'Diyet öğünleri personel ve refakatçi yemeğinden ayrı hazırlanıyor, üzerine kimin olduğu yazılıyor.',
      },
      {
        title: 'Kata teslim',
        body: 'Öğünler servis saatinde ilgili birime, etiketleriyle çıkıyor.',
      },
      {
        title: 'Gün içi değişiklik',
        body: 'Diyet talimatı değiştiğinde o öğün için güncelleniyor.',
      },
    ],
    benefits: [
      'Hasta, personel ve refakatçi tabakları karışmıyor',
      'Her diyet öğünü etiketli çıkıyor',
      'Servis saatleri vizit düzenine göre',
      'Gün içinde değişen talimata uyum',
    ],
    menuPlanning:
      'Diyet menülerini kurumun diyetisyeni belirliyor; biz pişirip yetiştiriyoruz. Personel menüsü vardiya saatlerine göre ayrı planlanıyor.',
    quoteNeeds: [
      'Yatak kapasitesi ve ortalama doluluk',
      'Diyet tipleri ve günlük öğün sayısı',
      'Personel sayısı ve vardiya düzeni',
      'Kat/birim dağıtımı gerekiyor mu',
    ],
  },
  {
    slug: 'santiye-yemek',
    title: 'Şantiye yemek hizmeti',
    summary: 'Sahaya kadar gelen, ağır işe yeten doyurucu öğünler.',
    intro:
      'Şantiyede iş ağır, mola kısa, saat sabit değil. Menüyü karnı doyuracak şekilde kuruyor, teslimi vardiya değişimine göre ayarlıyoruz.',
    icon: HardHat,
    audience: [
      'İnşaat şantiyeleri',
      'Altyapı ve enerji projeleri',
      'Maden ve saha operasyonları',
      'Geçici işçi kampları',
    ],
    howItWorks: [
      {
        title: 'Saha ve vardiya',
        body: 'Şantiye nerede, yol nasıl, vardiyalar kaçta. Hepsi teslim planına giriyor.',
      },
      {
        title: 'Doyuran menü',
        body: 'Et ve baklagil ağırlıklı, uzun süre tok tutan yemekler.',
      },
      {
        title: 'Sahaya teslim',
        body: 'Isı tutan kaplarla, vardiya değişimine yetişecek saatte.',
      },
      {
        title: 'Sayı takibi',
        body: 'Sahada kaç kişi varsa o kadar. Sabah bildirim, öğlen yemek.',
      },
    ],
    benefits: [
      'Teslim saati vardiyaya göre',
      'Ağır iş koluna göre porsiyon',
      'Değişken personel sayısına hızlı uyum',
      'Sahada servis düzeni kurulumu',
    ],
    menuPlanning:
      'Kışın çorba çeşidi artıyor, sıcak tutan yemekler öne geçiyor. Yazın ayran ve soğuk yan ürünler devreye giriyor.',
    quoteNeeds: [
      'Şantiye konumu ve yol durumu',
      'Kaç vardiya, hangi saatlerde',
      'Günlük ortalama personel',
      'Proje ne kadar sürecek',
    ],
  },
  {
    slug: 'davet-organizasyon',
    title: 'Davet ve organizasyon',
    summary: 'Düğün, açılış ve kurumsal davetlere kurulumuyla birlikte catering.',
    intro:
      'Davette yemek kadar servisin düzeni de konuşuluyor. Menüyü, sunumu ve ekibi günün akışına göre kuruyoruz; sonunda ortalığı da biz topluyoruz.',
    icon: CalendarHeart,
    audience: [
      'Düğün, nişan ve kına',
      'Açılış ve tanıtım etkinlikleri',
      'Kurumsal yemekler ve yıl sonu davetleri',
      'Özel gün kutlamaları',
    ],
    howItWorks: [
      {
        title: 'Günü konuşuyoruz',
        body: 'Tarih, kaç davetli, mekân nerede, servis nasıl olsun — açık büfe mi, masaya mı.',
      },
      {
        title: 'Menü ve tadım',
        body: 'Saatine göre menü çıkarıyoruz. İsterseniz önceden gelip tadıyorsunuz.',
      },
      {
        title: 'Mekânı kuruyoruz',
        body: 'Büfe, servis alanı ve ekipman etkinlikten önce hazır oluyor.',
      },
      {
        title: 'Servis ve toplama',
        body: 'Ekip gün boyu sahada. Bitince masalar toplanıyor, alan teslim ediliyor.',
      },
    ],
    benefits: [
      'Menü ve servis biçimi güne göre',
      'Kurulum ve toplama dâhil',
      'Son dakika davetlisi için pay bırakılıyor',
      'Servis ekibi etkinlik boyunca yanınızda',
    ],
    menuPlanning:
      'Öğle davetinde daha hafif, akşam davetinde daha kapsamlı bir akış kuruyoruz. Vejetaryen ve alerjen alternatifleri davetli listesine göre ekleniyor.',
    quoteNeeds: [
      'Tarih ve saat',
      'Davetli sayısı',
      'Mekân adresi, mutfak ve servis imkânları',
      'Açık büfe mi, masaya servis mi',
    ],
  },
  {
    slug: 'toplanti-ikram',
    title: 'Toplantı ikramları',
    summary: 'Kahvaltı, ara ikramı ve seminer paketleri.',
    intro:
      'İkram, toplantıyı bölmeden kurulup toplanmalı. Paketi katılımcı sayısına ve program akışına göre hazırlıyoruz.',
    icon: Coffee,
    audience: [
      'Kurumsal toplantı ve eğitimler',
      'Seminer ve konferanslar',
      'Yönetim kurulu toplantıları',
      'Basın toplantıları ve lansmanlar',
    ],
    howItWorks: [
      {
        title: 'Programı alıyoruz',
        body: 'Toplantı kaçta başlıyor, aralar ne zaman, ikram nereye kurulacak.',
      },
      {
        title: 'Paketi seçiyoruz',
        body: 'Kahvaltı, ara ikramı ya da öğle paketi. Sıcak ve soğuk bir arada.',
      },
      {
        title: 'Kurulum',
        body: 'İkram alanı program başlamadan hazır oluyor.',
      },
      {
        title: 'Aralarda tazeleme',
        body: 'Her arada masa yenileniyor, program bitince alan toplanıyor.',
      },
    ],
    benefits: [
      'Program bölünmüyor',
      'Paket katılımcı sayısına göre büyüyor',
      'Sıcak ve soğuk seçenekler bir arada',
      'Aynı gün birden fazla ara',
    ],
    menuPlanning:
      'Ara ikramında elde yenen, çatal gerektirmeyen şeyler öne çıkıyor. Gün boyu süren programlarda her arada başka bir şey çıkıyor.',
    quoteNeeds: [
      'Tarih ve program saatleri',
      'Katılımcı sayısı',
      'Kaç ara, hangi tür ikram',
      'Etkinlik adresi',
    ],
  },
];
