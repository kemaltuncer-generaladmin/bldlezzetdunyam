/**
 * Bilgi Merkezi yazıları.
 *
 * Projede CMS yok. Yazılar burada yapılandırılmış veri olarak duruyor; ileride
 * bir CMS'e taşınacaksa `Post` tipini karşılayan bir kaynak yazmak yeterli,
 * sayfalara dokunmak gerekmez.
 *
 * Gövde serbest HTML değil, tipli bloklardan oluşuyor: hem render tarafı
 * güvenli kalıyor hem de başlık hiyerarşisi (h2/h3) yanlışlıkla bozulamıyor.
 */

export type PostBlock =
  | { readonly kind: 'paragraph'; readonly text: string }
  | { readonly kind: 'heading'; readonly text: string }
  | { readonly kind: 'list'; readonly items: readonly string[] }
  | { readonly kind: 'callout'; readonly text: string };

export interface Post {
  readonly slug: string;
  readonly title: string;
  readonly description: string;
  readonly category: string;
  /** ISO 8601. Yazının yayın tarihi. */
  readonly publishedAt: string;
  /** Ortalama okuma süresi (dakika). */
  readonly readingMinutes: number;
  readonly body: readonly PostBlock[];
}

export const POSTS: readonly Post[] = [
  {
    slug: 'toplu-yemek-firmasi-secerken',
    title: 'Toplu yemek firması seçerken nelere bakmalı?',
    description:
      'Fiyat teklifi karşılaştırmak yetmiyor. Catering firması seçerken sorulması gereken sorular ve sözleşmeden önce netleştirilmesi gereken başlıklar.',
    category: 'Karar rehberi',
    publishedAt: '2026-03-04',
    readingMinutes: 6,
    body: [
      {
        kind: 'paragraph',
        text: 'Toplu yemek hizmeti, kurumun çalışanıyla her gün temas eden az sayıdaki hizmetten biri. Yanlış seçim, kısa sürede memnuniyetsizlik olarak geri dönüyor. Buna rağmen karar çoğu zaman yalnızca birim fiyat karşılaştırmasıyla veriliyor.',
      },
      {
        kind: 'paragraph',
        text: 'Aşağıdaki başlıklar, teklif almadan önce netleştirildiğinde hem karşılaştırmayı anlamlı kılıyor hem de sonradan çıkan sürprizleri azaltıyor.',
      },
      { kind: 'heading', text: 'Fiyatın neyi kapsadığını sorun' },
      {
        kind: 'paragraph',
        text: 'İki teklif arasındaki fark çoğu zaman yemeğin kendisinden değil, kapsamdan geliyor. Aynı rakam bir firmada yalnızca öğünü, diğerinde servis personelini, ekipmanı ve tek kullanımlık malzemeyi de içeriyor olabilir.',
      },
      {
        kind: 'list',
        items: [
          'Kaç kap yemek dâhil?',
          'Ekmek, içecek ve salata fiyata dâhil mi?',
          'Servis personeli ve ekipman kimin sorumluluğunda?',
          'Tek kullanımlık malzeme (tabak, çatal, peçete) kimden?',
          'Teslimat ücreti ayrı mı hesaplanıyor?',
        ],
      },
      { kind: 'heading', text: 'Menü planının nasıl kurulduğunu öğrenin' },
      {
        kind: 'paragraph',
        text: 'İyi bir menü planı tesadüf değildir. Haftalık tekrar dengesi, et-tavuk-baklagil dağılımı ve mevsim uyumu gözetilerek kurulur. Menüyü kimin hazırladığını, ne kadar önceden paylaşıldığını ve değişiklik talep edip edemeyeceğinizi sorun.',
      },
      {
        kind: 'callout',
        text: 'Menüsünü sabahında bildiren bir firmayla planlama yapamazsınız. Menünün en az bir hafta önceden paylaşılması, hem sizin hem çalışanınız için öngörülebilirlik demektir.',
      },
      { kind: 'heading', text: 'Değişken kişi sayısını nasıl yönettiğini sorun' },
      {
        kind: 'paragraph',
        text: 'Çoğu iş yerinde günlük personel sayısı sabit değil. İzin, vardiya ve saha görevleri sayıyı değiştiriyor. Firmanın bu değişimi nasıl karşıladığı — günlük bildirim mi alıyor, sabit sayı üzerinden mi faturalıyor — hem maliyeti hem israfı doğrudan etkiliyor.',
      },
      { kind: 'heading', text: 'Hijyen yaklaşımını somut sorularla test edin' },
      {
        kind: 'paragraph',
        text: 'Herkes hijyene önem verdiğini söyler. Ayırt edici olan, sürecin nasıl işlediğidir. Sıcaklık kontrolünün nerede yapıldığı, çiğ ve pişmiş ürünün ayrı alanlarda hazırlanıp hazırlanmadığı, teslim kayıtlarının tutulup tutulmadığı gibi sorular somut cevap gerektirir.',
      },
      {
        kind: 'paragraph',
        text: 'Sertifika iddiası duyduğunuzda belgeyi görmek isteyin. Belge göstermekten çekinen bir firma, muhtemelen belgeye sahip değildir.',
      },
      { kind: 'heading', text: 'Sorun çıktığında kime ulaşacağınızı netleştirin' },
      {
        kind: 'paragraph',
        text: 'Teslimat geciktiğinde, öğün sayısı eksik geldiğinde veya bir çalışanınız yemekten şikâyet ettiğinde kimi arayacaksınız? Tek bir muhatabınızın olması, çağrı merkezine bağlanmaktan çok daha hızlı sonuç veriyor.',
      },
      { kind: 'heading', text: 'Deneme servisi isteyin' },
      {
        kind: 'paragraph',
        text: 'Tadım, menünün kâğıt üzerindeki hâliyle tabaktaki hâli arasındaki farkı gösteren en pratik yöntem. Mümkünse tadımı yalnızca yöneticilerle değil, gerçekten yemek yiyecek ekiple birlikte yapın.',
      },
    ],
  },
  {
    slug: 'kurumsal-catering-nedir',
    title: 'Kurumsal catering nedir, restorandan farkı ne?',
    description:
      'Catering ile restoran işletmeciliği aynı iş değil. Kurumsal catering hizmetinin nasıl işlediği, hangi ihtiyaçlara cevap verdiği ve neyi kapsadığı.',
    category: 'Temel bilgiler',
    publishedAt: '2026-02-18',
    readingMinutes: 5,
    body: [
      {
        kind: 'paragraph',
        text: 'Catering ve restoran, dışarıdan bakınca aynı işi yapıyor görünür: ikisi de yemek üretir. Operasyon açısından ise neredeyse zıt iki modeldir.',
      },
      { kind: 'heading', text: 'Restoran talebi bekler, catering talebi bilir' },
      {
        kind: 'paragraph',
        text: 'Restoranda kaç kişinin geleceği ve ne söyleyeceği bilinmez; mutfak belirsizliğe göre kurulur. Kurumsal cateringde ise kişi sayısı ve menü önceden bellidir. Bu, üretimin planlanabilmesi demektir: malzeme tam miktarda alınır, pişirme servis saatine göre zamanlanır, israf azalır.',
      },
      { kind: 'heading', text: 'Süreklilik farkı' },
      {
        kind: 'paragraph',
        text: 'Restorana ayda bir gidersiniz, menü tekrarı sorun olmaz. Kurumsal yemekte aynı kişiler her gün yiyor. Bu yüzden catering menüsünün en kritik özelliği çeşitlilik ve tekrar dengesidir — aynı yemeğin haftada iki kez çıkması fark edilir.',
      },
      { kind: 'heading', text: 'Kurumsal catering neleri kapsar?' },
      {
        kind: 'list',
        items: [
          'Menü planlaması ve kurum onayı',
          'Malzeme tedariği ve depolama',
          'Üretim (merkez mutfakta veya kurumun mutfağında)',
          'Sıcaklık kontrollü taşıma ve teslimat',
          'Servis düzeni ve gerektiğinde servis personeli',
          'Öğün sayısı takibi ve raporlama',
        ],
      },
      { kind: 'heading', text: 'Taşıma yemek mi, yerinde üretim mi?' },
      {
        kind: 'paragraph',
        text: 'İki temel model var. Taşıma yemekte üretim merkez mutfakta yapılır, öğün servise hazır gelir; mutfak altyapısı olmayan kurumlar için uygundur. Yerinde üretimde ise yemek kurumun kendi mutfağında pişer; taşıma süresi ortadan kalkar, menü esnekliği artar, ancak mutfak alanı ve ekipman gerekir.',
      },
      {
        kind: 'callout',
        text: 'Seçim genellikle mutfak altyapınızın olup olmadığıyla belirlenir. Mutfağınız varsa ama işletmek istemiyorsanız, yerinde üretim modeli hem tazelik hem esneklik açısından avantajlıdır.',
      },
      { kind: 'heading', text: 'Fiyat neden liste hâlinde verilmiyor?' },
      {
        kind: 'paragraph',
        text: 'Catering fiyatı kişi sayısı, öğün sayısı, hizmet sıklığı, menü kapsamı ve teslimat konumuna göre değişir. Aynı menü 50 kişiye ve 500 kişiye farklı birim maliyetle üretilir. Sabit liste vermek bu yüzden çoğu zaman yanıltıcı olur.',
      },
    ],
  },
  {
    slug: 'is-yerleri-icin-menu-planlamasi',
    title: 'İş yerleri için menü planlaması nasıl yapılır?',
    description:
      'Haftalık menü kurarken tekrar dengesi, besin çeşitliliği ve çalışan profilinin nasıl gözetildiği; işe yarayan bir menü planının kuralları.',
    category: 'Menü',
    publishedAt: '2026-01-27',
    readingMinutes: 7,
    body: [
      {
        kind: 'paragraph',
        text: 'Menü planlaması, "bu hafta ne çıkaralım" sorusuna verilen günlük cevaplardan ibaret değil. İyi kurulmuş bir plan, çalışanın memnuniyetini artırırken israfı ve maliyeti aynı anda düşürür.',
      },
      { kind: 'heading', text: 'Önce çalışan profilini tanımlayın' },
      {
        kind: 'paragraph',
        text: 'Ağır iş kolunda çalışan bir ekiple ofis çalışanının öğün ihtiyacı aynı değil. Fiziksel yükü yüksek işlerde kalori ve porsiyon öne çıkar; masa başı çalışmada ise ağır öğün öğleden sonra verimi düşürür.',
      },
      { kind: 'heading', text: 'Tekrar dengesini haftalık kurun' },
      {
        kind: 'paragraph',
        text: 'Pratik bir çerçeve: haftada iki kırmızı et, iki tavuk, bir baklagil ana yemeği. Yardımcı yemekte pilav ve makarna aynı hafta içinde dönüşümlü verilir. Aynı ana yemek iki hafta üst üste tekrar etmez.',
      },
      {
        kind: 'list',
        items: [
          'Aynı gün iki kuru baklagil öğünü koymayın (çorba + ana yemek).',
          'Ağır bir ana yemeğin yanına hafif bir tamamlayıcı seçin.',
          'Cuma günlerine daha çok tercih edilen yemekleri koymak katılımı artırır.',
          'Aynı pişirme yöntemini (fırın, kızartma) gün içinde tekrarlamayın.',
        ],
      },
      { kind: 'heading', text: 'Mevsimi gözetin' },
      {
        kind: 'paragraph',
        text: 'Mevsiminde sebze hem daha lezzetli hem daha uygun maliyetlidir. Kışın çorba çeşidini artırmak, yazın soğuk başlangıç ve ayran tüketimini öne almak hem tüketimi hem memnuniyeti yükseltir.',
      },
      { kind: 'heading', text: 'Alternatif öğünü baştan planlayın' },
      {
        kind: 'paragraph',
        text: 'Vejetaryen çalışan veya alerjisi olan kişiler için alternatif, menü kurulurken düşünülmeli — servis anında bulunacak bir çözüm değil. Alternatif öğün ayrı hazırlanır, etiketlenir ve mümkünse ayrı kapta taşınır.',
      },
      { kind: 'heading', text: 'Tüketimi ölçün, menüyü ona göre düzeltin' },
      {
        kind: 'paragraph',
        text: 'Hangi yemeğin bittiğini, hangisinin arttığını takip etmek en değerli geri bildirimdir. Sürekli artan bir yemek menüden çıkar; hızla biten yemek daha sık planlanır. Bu döngü olmadan menü planı zamanla gerçeklikten kopar.',
      },
      {
        kind: 'callout',
        text: 'Anket yapmadan önce artan yemeği ölçün. İnsanlar ne yediklerini anlatmakta değil, tabakta bırakmakta çok daha dürüsttür.',
      },
    ],
  },
  {
    slug: 'catering-hizmetinde-hijyen',
    title: 'Catering hizmetinde hijyen: zincir nerede kırılır?',
    description:
      'Toplu yemekte hijyen tek bir aşamanın değil, hammaddeden teslimata uzanan bir zincirin işi. Zincirin en kırılgan halkaları ve alınması gereken önlemler.',
    category: 'Kalite',
    publishedAt: '2026-01-09',
    readingMinutes: 6,
    body: [
      {
        kind: 'paragraph',
        text: 'Toplu yemekte hijyen sorunu genellikle mutfağın kirli olmasından çıkmaz. Zincirin görece gözden kaçan halkalarında — depolamada, soğutmada ve taşımada — ortaya çıkar.',
      },
      { kind: 'heading', text: 'Tehlikeli sıcaklık aralığı' },
      {
        kind: 'paragraph',
        text: 'Gıda güvenliğinde en kritik kavram, bakterinin hızla çoğaldığı sıcaklık aralığıdır. Yemek bu aralıkta ne kadar uzun kalırsa risk o kadar artar. Bu yüzden sıcak yemek sıcak, soğuk ürün soğuk tutulur; ikisinin arasında geçirilen süre mümkün olduğunca kısaltılır.',
      },
      {
        kind: 'callout',
        text: 'Erken pişirilip uzun süre bekletilen yemek, geç pişirilip hemen servis edilen yemekten her zaman daha risklidir. Üretim planı bu yüzden servis saatine göre kurulur.',
      },
      { kind: 'heading', text: 'Çapraz bulaşma' },
      {
        kind: 'paragraph',
        text: 'Çiğ tavuğun hazırlandığı tezgâhta salata doğranması klasik örnektir. Önlemi basit ama disiplin ister: çiğ ve pişmiş ürün için ayrı hazırlık alanı, ayrı kesme tahtası ve ayrı ekipman.',
      },
      {
        kind: 'paragraph',
        text: 'Aynı ilke alerjen yönetimi için de geçerlidir. Glutensiz bir öğün, glutenli ürünle aynı yüzeyde hazırlandığında artık glutensiz değildir.',
      },
      { kind: 'heading', text: 'Depolama sırası' },
      {
        kind: 'list',
        items: [
          'Kuru gıda, soğuk ürün ve dondurulmuş ürün ayrı alanlarda saklanır.',
          'Önce giren ürün önce kullanılır; giriş tarihi ürün üzerinde görünür olmalıdır.',
          'Çiğ ürünler, pişmiş ürünlerin altındaki raflarda tutulur (damlama riski).',
          'Açılmış ürün kapatılır ve açılış tarihi işaretlenir.',
        ],
      },
      { kind: 'heading', text: 'Taşıma: en çok gözden kaçan halka' },
      {
        kind: 'paragraph',
        text: 'Mutfakta her şey doğru yapılmış olsa bile, yalıtımsız bir kapla yapılan uzun teslimat zinciri kırar. Isı yalıtımlı kapalı kaplar, teslim öncesi ve sonrası sıcaklık kontrolü ve teslim kaydı bu yüzden hizmetin ayrılmaz parçasıdır.',
      },
      { kind: 'heading', text: 'İzlenebilirlik neden önemli?' },
      {
        kind: 'paragraph',
        text: 'Bir sorun yaşandığında "hangi gün, hangi menü, hangi tedarikçi, nereye teslim" sorularının cevabı kayıtlarda yoksa, sorunun kaynağı bulunamaz. İzlenebilirlik, sorun çıkmasını engellemez ama tekrarlanmasını engeller.',
      },
    ],
  },
  {
    slug: 'organizasyon-menusu-nasil-secilir',
    title: 'Organizasyon menüsü nasıl seçilir?',
    description:
      'Düğün, açılış ve kurumsal davetlerde menü seçimini belirleyen faktörler: etkinlik saati, servis biçimi, davetli profili ve mekân koşulları.',
    category: 'Organizasyon',
    publishedAt: '2025-12-12',
    readingMinutes: 5,
    body: [
      {
        kind: 'paragraph',
        text: 'Organizasyon menüsü, katalogdan seçilen bir liste değil; etkinliğin akışına göre kurulan bir plandır. Aynı menü öğle açılışında doğru, akşam düğününde eksik kalabilir.',
      },
      { kind: 'heading', text: 'Etkinliğin saati menüyü belirler' },
      {
        kind: 'paragraph',
        text: 'Öğle saatindeki bir açılışta davetliler genellikle kısa süre kalır; elde tüketilebilen, servis gerektirmeyen seçenekler öne çıkar. Akşam davetinde ise oturmalı servis ve daha kapsamlı bir menü beklenir.',
      },
      { kind: 'heading', text: 'Servis biçimini erken kararlaştırın' },
      {
        kind: 'list',
        items: [
          'Açık büfe: davetli sayısı yüksekken hızlıdır, alan gerektirir.',
          'Masaya servis: daha düzenli görünür, servis personeli ihtiyacını artırır.',
          'Kokteyl düzeni: ayakta dolaşımı destekler, ana yemek yerine küçük porsiyonlara dayanır.',
        ],
      },
      {
        kind: 'paragraph',
        text: 'Servis biçimi yalnızca estetik bir tercih değil; mekânın alanı, davetli sayısı ve etkinliğin süresiyle doğrudan bağlantılıdır.',
      },
      { kind: 'heading', text: 'Mekânın imkânlarını baştan öğrenin' },
      {
        kind: 'paragraph',
        text: 'Mekânda mutfak var mı, elektrik ve su erişimi yeterli mi, servis alanı ile davetli alanı arasındaki mesafe ne kadar? Bu sorular menüyü doğrudan etkiler: yerinde son hazırlık gerektiren yemekler ancak uygun altyapıda planlanabilir.',
      },
      { kind: 'heading', text: 'Davetli profilini gözetin' },
      {
        kind: 'paragraph',
        text: 'Yaş dağılımı, çocuklu davetli sayısı ve özel beslenme ihtiyaçları menüyü şekillendirir. Vejetaryen ve alerjen alternatifleri davetli listesine göre önceden planlanmalı; etkinlik günü çözülecek bir konu değildir.',
      },
      {
        kind: 'callout',
        text: 'Davetli sayısına küçük bir pay eklemek neredeyse her zaman doğru karardır. Son dakika katılımları organizasyonların istisnası değil, kuralıdır.',
      },
    ],
  },
  {
    slug: 'kalabalik-etkinliklerde-yemek-planlamasi',
    title: 'Kalabalık etkinliklerde yemek planlaması',
    description:
      'Yüksek katılımlı etkinliklerde servis kuyruğunu kısaltmak, sıcaklığı korumak ve zamanlamayı tutturmak için kullanılan planlama yöntemleri.',
    category: 'Organizasyon',
    publishedAt: '2025-11-20',
    readingMinutes: 6,
    body: [
      {
        kind: 'paragraph',
        text: 'Katılımcı sayısı arttıkça yemeğin lezzeti kadar servisin akışı da belirleyici hâle gelir. Uzun kuyruk, soğumuş yemek ve programın sarkması genellikle menüden değil planlamadan kaynaklanır.',
      },
      { kind: 'heading', text: 'Kuyruğu paralelleştirin' },
      {
        kind: 'paragraph',
        text: 'Tek bir büfe hattı, katılımcı sayısı arttığında dar boğaza dönüşür. Aynı menüyü sunan birden fazla hat kurmak, kuyruk süresini doğrudan böler. Hatların iki yönlü kullanılabilmesi kapasiteyi bir kat daha artırır.',
      },
      { kind: 'heading', text: 'Sıcaklığı dalgalar hâlinde koruyun' },
      {
        kind: 'paragraph',
        text: 'Tüm yemeği en başta ortaya çıkarmak, son katılımcının soğumuş yemek almasına yol açar. Bunun yerine servis, tazeleme dalgaları hâlinde planlanır: büfe belirli aralıklarla yenilenir.',
      },
      { kind: 'heading', text: 'Programla senkron çalışın' },
      {
        kind: 'list',
        items: [
          'Konuşma ve sunum saatlerini önceden alın; servisi araya değil, aranın başına kurun.',
          'Ara süresini gerçekçi belirleyin: 200 kişilik bir grup 15 dakikada yemek yiyemez.',
          'İçecek noktalarını yemek hattından ayırın; kuyruk hızını en çok bu düşürür.',
          'Toplama işlemini program devam ederken sessizce yürütecek şekilde planlayın.',
        ],
      },
      { kind: 'heading', text: 'Menüyü servis hızına göre seçin' },
      {
        kind: 'paragraph',
        text: 'Porsiyonlanması zaman alan yemekler kalabalıkta kuyruğu uzatır. Önceden porsiyonlanabilen, servis kaşığıyla hızlı alınabilen seçenekler tercih edilir. Görsel olarak etkileyici ama servis hızını düşüren kaplar, ana hat yerine ayrı bir istasyona alınabilir.',
      },
      {
        kind: 'callout',
        text: 'Kalabalık etkinliklerde en sık yapılan hata, menüyü küçük bir davet gibi kurup servis düzenini sonradan çözmeye çalışmak. Sıralama tersi olmalı: önce servis akışı, sonra ona uyan menü.',
      },
    ],
  },
];

export function findPost(slug: string): Post | undefined {
  return POSTS.find((post) => post.slug === slug);
}

/** Yayın tarihine göre yeniden eskiye. */
export const POSTS_BY_DATE: readonly Post[] = [...POSTS].sort((a, b) =>
  b.publishedAt.localeCompare(a.publishedAt),
);
