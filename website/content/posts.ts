/**
 * Bilgi Merkezi yazıları — **YEDEK / BAŞLANGIÇ DEĞERİ**.
 *
 * Tek kaynak admin panelidir; yazılar `lib/api/site-content.ts` üzerinden
 * gelir ve gövdeleri sunucuda temizlenmiş `body_html` olarak taşınır.
 *
 * Buradaki yedek gövdeler ise serbest HTML değil, tipli bloklardan oluşuyor:
 * repoya yazılan içerikte enjeksiyon yüzeyi hiç açılmıyor ve başlık
 * hiyerarşisi (h2/h3) yanlışlıkla bozulamıyor. Yazı sayfası hangisi doluysa
 * onu basar — böylece API kapalıyken de yazılar okunabilir kalır.
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
      'İki teklifin arasındaki fark çoğu zaman yemekte değil, kapsamda. İmzadan önce sormanız gereken sorular.',
    category: 'Karar rehberi',
    publishedAt: '2026-03-04',
    readingMinutes: 6,
    body: [
      {
        kind: 'paragraph',
        text: 'Yemek, çalışanınızın sizinle her gün temas ettiği birkaç şeyden biri. Yanlış firma seçilirse bunu üç hafta içinde koridorda duyarsınız. Buna rağmen karar çoğu zaman tek bir rakama bakılarak veriliyor.',
      },
      {
        kind: 'paragraph',
        text: 'Aşağıdakileri teklif istemeden önce netleştirin. Hem teklifleri yan yana koyabilirsiniz hem de üçüncü ay sürprizi çıkmaz.',
      },
      { kind: 'heading', text: 'Fiyatın neyi kapsadığını sorun' },
      {
        kind: 'paragraph',
        text: 'Aynı rakam bir yerde sadece yemeği, başka bir yerde servis elemanını, ekipmanı ve tabak çatalı da kapsıyor olabilir. Farkı yaratan çoğu zaman tencere değil, listenin altındaki satırlar.',
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
        text: 'İyi menü tesadüfen çıkmaz. Et, tavuk ve baklagil güne dağılır; mevsim gözetilir; aynı yemek üst üste gelmez. Kim hazırlıyor, kaç gün önce elinize geçiyor, üstünde değişiklik isteyebiliyor musunuz — bunları sorun.',
      },
      {
        kind: 'callout',
        text: 'Menüyü sabahında bildiren bir firmayla plan yapamazsınız. En az bir hafta önceden elinizde olmalı.',
      },
      { kind: 'heading', text: 'Değişken kişi sayısını nasıl yönettiğini sorun' },
      {
        kind: 'paragraph',
        text: 'Hiçbir iş yerinde her gün aynı sayıda insan yoktur. İzin var, vardiya var, sahaya giden var. Firma sabah bildirim mi alıyor yoksa sabit sayıdan mı faturalıyor? Cevap hem faturanızı hem çöpe giden yemeği değiştiriyor.',
      },
      { kind: 'heading', text: 'Hijyen yaklaşımını somut sorularla test edin' },
      {
        kind: 'paragraph',
        text: 'Hijyene önem verdiğini söylemeyen firma yok. Somut sorun: sıcaklık nerede ölçülüyor, çiğ tavuğun tezgâhı ayrı mı, teslim kaydı tutuluyor mu? Bunların cevabı ya vardır ya yoktur.',
      },
      {
        kind: 'paragraph',
        text: 'Belge iddiası duyduğunuzda belgeyi isteyin. Göstermekten kaçınan firmada o belge büyük ihtimalle yoktur.',
      },
      { kind: 'heading', text: 'Sorun çıktığında kime ulaşacağınızı netleştirin' },
      {
        kind: 'paragraph',
        text: 'Yemek geç kaldığında, on porsiyon eksik geldiğinde ya da biri şikâyet ettiğinde kimi arayacaksınız? Bir isim ve bir numara, çağrı merkezinden çok daha hızlı iş görüyor.',
      },
      { kind: 'heading', text: 'Deneme servisi isteyin' },
      {
        kind: 'paragraph',
        text: 'Kâğıttaki menüyle tabaktaki yemek arasındaki farkı tadım gösterir. Tadıma yöneticileri değil, o yemeği her gün yiyecek insanları götürün.',
      },
    ],
  },
  {
    slug: 'kurumsal-catering-nedir',
    title: 'Kurumsal catering nedir, restorandan farkı ne?',
    description:
      'İkisi de yemek yapar ama mutfakları zıt kurulur. Kurumsal catering nasıl işler, neyi kapsar?',
    category: 'Temel bilgiler',
    publishedAt: '2026-02-18',
    readingMinutes: 5,
    body: [
      {
        kind: 'paragraph',
        text: 'Dışarıdan bakınca ikisi de yemek yapıyor. Mutfağa girince iki ayrı iş olduğu anlaşılıyor.',
      },
      { kind: 'heading', text: 'Restoran talebi bekler, catering talebi bilir' },
      {
        kind: 'paragraph',
        text: 'Restoranda kaç kişi gelecek, ne söyleyecek belli değildir; mutfak her ihtimale hazır durur. Cateringde sayı da menü de önceden bellidir. Bu yüzden malzeme tam alınır, ocak servis saatine göre yanar, çöpe giden azalır.',
      },
      { kind: 'heading', text: 'Süreklilik farkı' },
      {
        kind: 'paragraph',
        text: 'Restorana ayda bir gidersiniz; aynı yemeği yemeniz sorun olmaz. Burada aynı insanlar her gün yiyor. Salı çıkan yemek perşembe yine çıkarsa herkes fark eder.',
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
        text: 'İki yol var. Taşıma yemekte yemek bizim mutfakta pişer, servise hazır gelir — mutfağı olmayan yerler için. Yerinde üretimde yemek sizin mutfağınızda pişer; yol yoktur, menü esner, ama alan ve ekipman ister.',
      },
      {
        kind: 'callout',
        text: 'Kararı çoğunlukla mutfağınızın olup olmaması veriyor. Mutfak var ama uğraşmak istemiyorsanız yerinde üretim en tazesini verir.',
      },
      { kind: 'heading', text: 'Fiyat neden liste hâlinde verilmiyor?' },
      {
        kind: 'paragraph',
        text: 'Aynı menü elli kişiye başka, beş yüz kişiye başka maliyete çıkıyor. Buna sıklık ve mesafe de eklenince tek bir liste yazmak yanıltmak oluyor.',
      },
    ],
  },
  {
    slug: 'is-yerleri-icin-menu-planlamasi',
    title: 'İş yerleri için menü planlaması nasıl yapılır?',
    description: 'Haftalık menü nasıl kurulur: kim yiyecek, ne sıklıkla dönecek, mevsim ne diyor?',
    category: 'Menü',
    publishedAt: '2026-01-27',
    readingMinutes: 7,
    body: [
      {
        kind: 'paragraph',
        text: '"Bu hafta ne çıkaralım?" sorusuna her pazartesi yeniden cevap aranıyorsa ortada plan yok demektir. Doğru kurulmuş bir liste hem tabakları boşaltır hem çöpü azaltır.',
      },
      { kind: 'heading', text: 'Önce çalışan profilini tanımlayın' },
      {
        kind: 'paragraph',
        text: 'Sekiz saat beton döken adamla bilgisayar başındaki insan aynı tabağı istemez. Birinde porsiyon ve kalori konuşulur, diğerinde ağır yemek öğleden sonrayı yatırır.',
      },
      { kind: 'heading', text: 'Tekrar dengesini haftalık kurun' },
      {
        kind: 'paragraph',
        text: 'İşe yarayan basit bir ölçü: haftada iki kırmızı et, iki tavuk, bir baklagil. Pilavla makarna dönüşümlü gider. Aynı ana yemek iki hafta üst üste çıkmaz.',
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
        text: 'Mevsiminde sebze hem daha lezzetli hem daha ucuz. Kışın çorba çeşidini artırın, yazın soğuk başlangıç ve ayrana yer açın.',
      },
      { kind: 'heading', text: 'Alternatif öğünü baştan planlayın' },
      {
        kind: 'paragraph',
        text: 'Vejetaryen ya da alerjisi olan biri varsa onun tabağı menü kurulurken düşünülür. Servis saatinde akla gelirse iş işten geçmiştir. Ayrı pişer, etiketlenir, mümkünse ayrı kapta gelir.',
      },
      { kind: 'heading', text: 'Tüketimi ölçün, menüyü ona göre düzeltin' },
      {
        kind: 'paragraph',
        text: 'En doğru geri bildirim tencerenin dibinde. Sürekli artan yemek listeden çıkar, çabuk biten daha sık gelir. Bunu yapmayan menü zamanla kâğıt üstünde kalır.',
      },
      {
        kind: 'callout',
        text: 'Anket yapmadan önce artanı tartın. İnsanlar anket doldururken kibar, tabak bırakırken dürüst oluyor.',
      },
    ],
  },
  {
    slug: 'catering-hizmetinde-hijyen',
    title: 'Catering hizmetinde hijyen: zincir nerede kırılır?',
    description: 'Sorun genelde kirli mutfaktan çıkmaz. Depoda, soğutmada ve yolda çıkar.',
    category: 'Kalite',
    publishedAt: '2026-01-09',
    readingMinutes: 6,
    body: [
      {
        kind: 'paragraph',
        text: 'Toplu yemekte hijyen sorunu neredeyse hiç pis bir tezgâhtan çıkmaz. Depoda, soğutmada ve yolda çıkar — yani kimsenin bakmadığı yerlerde.',
      },
      { kind: 'heading', text: 'Tehlikeli sıcaklık aralığı' },
      {
        kind: 'paragraph',
        text: 'Bakterinin en hızlı ürediği bir sıcaklık aralığı var. Yemek orada ne kadar kalırsa risk o kadar büyüyor. Bu yüzden sıcak sıcakta, soğuk soğukta durur; arada geçen süre elden geldiğince kısaltılır.',
      },
      {
        kind: 'callout',
        text: 'Sabah pişip öğlene kadar bekleyen yemek, on birde pişip on ikide servis edilenden her zaman daha risklidir. Ocağın saatini servis saati belirler.',
      },
      { kind: 'heading', text: 'Çapraz bulaşma' },
      {
        kind: 'paragraph',
        text: 'Çiğ tavuğun doğrandığı tahtada salata doğramak, kitaptaki ilk örnektir. Çözümü kolay, sürdürmesi disiplin ister: ayrı tezgâh, ayrı tahta, ayrı bıçak.',
      },
      {
        kind: 'paragraph',
        text: 'Alerjende de aynı kural. Glutensiz yemek, unlu tezgâhta hazırlandıysa artık glutensiz değildir.',
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
        text: 'Mutfakta her şey kitabına uygun gitse bile, yalıtımsız bir kapla çıkılan uzun yol zinciri kırar. Isı tutan kapalı kap, çıkışta ve varışta sıcaklık ölçümü, teslim kaydı — üçü de işin parçası.',
      },
      { kind: 'heading', text: 'İzlenebilirlik neden önemli?' },
      {
        kind: 'paragraph',
        text: 'Bir sorun çıktığında hangi gün, hangi menü, hangi tedarikçi ve nereye — dördünün cevabı kayıtta yoksa kaynağı bulamazsınız. Kayıt sorunu önlemez; tekrarını önler.',
      },
    ],
  },
  {
    slug: 'organizasyon-menusu-nasil-secilir',
    title: 'Organizasyon menüsü nasıl seçilir?',
    description:
      'Menüyü katalogdan değil, günün akışından seçersiniz: saat kaç, kaç kişi, mekân ne veriyor?',
    category: 'Organizasyon',
    publishedAt: '2025-12-12',
    readingMinutes: 5,
    body: [
      {
        kind: 'paragraph',
        text: 'Organizasyon menüsü katalogdan seçilmez, günün akışına göre kurulur. Öğle açılışında tam yerinde olan bir liste, akşam düğününde cılız kalır.',
      },
      { kind: 'heading', text: 'Etkinliğin saati menüyü belirler' },
      {
        kind: 'paragraph',
        text: 'Öğle açılışında insanlar yarım saat durur; elde yenen şeyler işe yarar. Akşam davetinde oturulur, sofra uzun kurulur.',
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
        text: 'Servis biçimi görüntüyle ilgili bir tercih gibi görünür ama asıl belirleyeni mekânın metrekaresi, davetli sayısı ve programın uzunluğudur.',
      },
      { kind: 'heading', text: 'Mekânın imkânlarını baştan öğrenin' },
      {
        kind: 'paragraph',
        text: 'Mutfak var mı, priz nerede, su nereden geliyor, servis alanıyla masalar arası kaç adım? Bunlar menüyü doğrudan değiştirir — son hazırlığı yerinde yapılan yemekler ancak altyapı varsa listeye girer.',
      },
      { kind: 'heading', text: 'Davetli profilini gözetin' },
      {
        kind: 'paragraph',
        text: 'Kaç çocuk var, yaş ortalaması ne, özel beslenen kaç kişi? Vejetaryen ve alerjen alternatifi davetli listesiyle birlikte planlanır. O gün akla gelirse çözülmez.',
      },
      {
        kind: 'callout',
        text: 'Davetli sayısına biraz pay bırakın. Son dakika gelen misafir her davette çıkıyor.',
      },
    ],
  },
  {
    slug: 'kalabalik-etkinliklerde-yemek-planlamasi',
    title: 'Kalabalık etkinliklerde yemek planlaması',
    description:
      'Uzun kuyruk ve soğumuş yemek menüden değil, servis düzeninden çıkar. Kalabalıkta işleyen yöntemler.',
    category: 'Organizasyon',
    publishedAt: '2025-11-20',
    readingMinutes: 6,
    body: [
      {
        kind: 'paragraph',
        text: 'Kalabalıkta yemeğin tadı kadar sıranın hızı da konuşuluyor. Uzayan kuyruk, soğumuş tabak ve sarkan program genelde menüden değil, servis düzeninden çıkıyor.',
      },
      { kind: 'heading', text: 'Kuyruğu paralelleştirin' },
      {
        kind: 'paragraph',
        text: 'Tek büfe hattı kalabalıkta tıkanır. Aynı menüyü veren ikinci hat, sırayı ikiye böler. Hattın iki tarafından da alınabiliyorsa kapasite bir kat daha artar.',
      },
      { kind: 'heading', text: 'Sıcaklığı dalgalar hâlinde koruyun' },
      {
        kind: 'paragraph',
        text: 'Bütün yemeği başta ortaya çıkarırsanız sıranın sonundaki soğuk yemek alır. Onun yerine büfe belirli aralıklarla tazelenir; yemek dalga dalga çıkar.',
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
        text: 'Tabağa koyması uzun süren yemek sırayı uzatır. Önceden porsiyonlanan ya da tek kaşıkta alınan şeyler tercih edilir. Gösterişli ama yavaş kaplar ana hattan çıkarılıp ayrı bir istasyona alınabilir.',
      },
      {
        kind: 'callout',
        text: 'En sık yapılan hata, menüyü küçük bir davet gibi kurup servisi sonra düşünmek. Sıra tersine dönmeli: önce insanlar nasıl akacak, sonra o akışa uyan menü.',
      },
    ],
  },
];

/*
 * Not: `findPost` ve tarihe göre sıralama artık burada değil. Yedek listeyle
 * panelden gelen listeyi ayrı ayrı sıralamak/aramak iki farklı doğruluk
 * kaynağı yaratıyordu; ikisi de birleştirilmiş içerik üzerinde çalışıyor
 * (`lib/api/site-content.ts`).
 */
