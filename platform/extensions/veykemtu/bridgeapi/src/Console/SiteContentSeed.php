<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Console;

use Veykemtu\BridgeApi\Models\SiteContent;

/**
 * Kurumsal sitenin ilk içeriği — `website/content/*.ts` dosyalarının birebir
 * karşılığı.
 *
 * ## Neden komuttan ayrı bir dosya?
 *
 * Buradaki her şey VERİ; aktarma mantığı (atla/ezme kararı, HTML üretimi,
 * önbellek temizliği) `SiteContentImportCommand` içinde. İkisi tek dosyada
 * dursaydı, firma bir cümlesini düzelttiğinde aktarım mantığıyla aynı diff'e
 * girerdi ve gözden geçiren kişi "metin mi değişti, davranış mı" sorusunu her
 * seferinde elle ayıklardı.
 *
 * ## Uydurulmuş hiçbir değer yok
 *
 * `contact` alanları `null`, `certifications` boş. Bu bir eksiklik değil,
 * bilinçli tasarım: site `null` alanı yer tutucuyla doldurmaz, o satırı hiç
 * göstermez (gerekçe: `website/content/site.ts` başlığı ve
 * `website/content/quality.ts` §"Sertifika iddiası neden yok?"). Buraya örnek
 * bir telefon numarası yazmak, panelde onu gören yöneticiye gerçek sanılan bir
 * veri sunmak ve siteye sahte bir iletişim kanalı düşürmek olurdu.
 *
 * ## `icon` alanları
 *
 * Lucide bileşen adları (`Building2`, `Truck` …) string olarak taşınır. Site
 * bilinmeyen adı sessizce varsayılana düşürür, boş kutu göstermez.
 */
final class SiteContentSeed
{
    private function __construct() {}

    /**
     * Anahtar → JSON değeri. Anahtarlar `SiteContent` sabitlerinden gelir;
     * elle string yazılsaydı yazım hatası sessizce yeni bir satır açardı.
     *
     * @return array<string, array<string, mixed>>
     */
    public static function content(): array
    {
        return [
            SiteContent::KEY_BRAND => self::brand(),
            SiteContent::KEY_CONTACT => self::contact(),
            SiteContent::KEY_COMPANY => self::company(),
            SiteContent::KEY_FAQ => self::faq(),
            SiteContent::KEY_SECTORS => self::sectors(),
            SiteContent::KEY_MENUS => self::menus(),
            SiteContent::KEY_QUALITY => self::quality(),
        ];
    }

    /** @return array<string, mixed> */
    private static function brand(): array
    {
        return [
            'name' => 'Benim Lezzet Dünyam',
            'short_name' => 'BLD',
            'parent_group' => 'Benim Başarı Dünyam',
            'tagline' => 'Kurumlara günlük yemek, davetlere catering. Sıcak gelir, saatinde gelir.',
            'description' => 'Ofislere, fabrikalara, okullara ve davetlere yemek hazırlıyoruz. Menüyü birlikte kuruyoruz, yemeği kendi mutfağımızda pişiriyoruz, teslim saatini siz söylüyorsunuz.',
            'logo_url' => null,
            'primary_color' => '#C2410C',
        ];
    }

    /**
     * İletişim — TÜM ALANLAR BİLİNÇLİ OLARAK `null`.
     *
     * Repoda BLD adına doğrulanmış telefon, adres veya e-posta yok. Uydurulmuş
     * bir numara sahte güven yaratır ve arayanı yanlış yere yönlendirir. Panelde
     * bu alanlar boş görünecek; yönetici gerçek değeri girdiği anda sitedeki
     * ilgili blok kendiliğinden belirir.
     *
     * @return array<string, mixed>
     */
    private static function contact(): array
    {
        return [
            'phone' => null,
            'whatsapp' => null,
            'email' => null,
            'address' => null,
            'working_hours' => [],
            'social' => [],
        ];
    }

    /** @return array<string, mixed> */
    private static function company(): array
    {
        return [
            'process_steps' => [
                [
                    'title' => 'Konuşuyoruz',
                    'body' => 'Kaç kişisiniz, saat kaçta yemek yiyorsunuz, mutfağınız var mı? Çoğu zaman yarım saatlik bir telefon yetiyor.',
                    'icon' => 'Phone',
                ],
                [
                    'title' => 'Menüyü çıkarıyoruz',
                    'body' => 'Size göre bir menü ve fiyat hazırlıyoruz. İsterseniz gelip tadıyorsunuz, sonra karar veriyorsunuz.',
                    'icon' => 'ClipboardList',
                ],
                [
                    'title' => 'Pişirip getiriyoruz',
                    'body' => 'Yemek sabah mutfakta yapılır, kapalı kaplarda yola çıkar. Kapağı açtığınızda hâlâ sıcaktır.',
                    'icon' => 'Truck',
                ],
                [
                    'title' => 'Sonra soruyoruz',
                    'body' => 'Ne bitti, ne arttı, kim ne beğenmedi? Bir sonraki haftanın menüsü bu cevaplara göre değişir.',
                    'icon' => 'MessageSquare',
                ],
            ],
            'differentiators' => [
                [
                    'title' => 'Menüyü önceden görürsünüz',
                    'body' => 'Haftalık menü cuma günü elinizde olur. Salı ne çıkacağını salı sabahı öğrenmezsiniz.',
                    'icon' => 'CalendarCheck',
                ],
                [
                    'title' => 'Tek numara, tek kişi',
                    'body' => 'Sipariş, menü değişikliği, fatura — hepsi aynı kişide. Santralde sıra beklemiyorsunuz.',
                    'icon' => 'Phone',
                ],
                [
                    'title' => 'Sayı her gün değişebilir',
                    'body' => 'Bugün seksen, yarın yüz otuz. Sabah haber verirsiniz, o kadar pişer.',
                    'icon' => 'UsersRound',
                ],
                [
                    'title' => 'Tarif kalabalıkta bozulmaz',
                    'body' => 'Bin porsiyon çıkarken de aynı tarif, aynı ölçü. Yemeğin tadı sayıyla düşmüyor.',
                    'icon' => 'Soup',
                ],
            ],
            'mission' => 'Kalabalığa yemek yapmak, özenden vazgeçmek anlamına gelmesin istiyoruz. Bininci tabak da ilkiyle aynı tada sahip olsun diye uğraşıyoruz.',
            'vision' => 'Kendi bölgesinde adı iyi anılan, başka şehirlerde de aynı düzeni kurabilen bir catering mutfağı olmak.',
            'values' => [
                [
                    'title' => 'Saatinde',
                    'body' => 'Soğumuş yemeğin lezzeti tartışılmaz. Teslim saati bizim için bir söz.',
                ],
                [
                    'title' => 'Temiz mutfak',
                    'body' => 'İşler sıkıştığında da aynı temizlik. Burada pazarlık yapmıyoruz.',
                ],
                [
                    'title' => 'Ölçülü konuşmak',
                    'body' => 'Yetişmeyecek işe baştan hayır diyoruz. Sonradan mazeret aramak kimsenin işine yaramıyor.',
                ],
                [
                    'title' => 'Aynı sofra',
                    'body' => 'Servis ettiğimiz insana ne yapıyorsak, mutfaktaki ekibe de aynısını yapıyoruz.',
                ],
            ],
            'group_relation' => 'Benim Lezzet Dünyam, Benim Başarı Dünyam şirket ailesinin mutfağıdır. Kurumsal düzenini oradan alır; menüsü, ocağı ve ekibi kendisine aittir.',
        ];
    }

    /** @return list<array<string, string>> */
    private static function faq(): array
    {
        return [
            [
                'question' => 'En az kaç kişiye yemek yapıyorsunuz?',
                'answer' => 'Düzenli hizmette ve tek günlük davette alt sınır aynı olmuyor. Kişi sayınızı söyleyin, yetişip yetişmeyeceğini o gün net söyleyelim.',
            ],
            [
                'question' => 'Menüyü siz mi seçiyorsunuz, biz mi?',
                'answer' => 'Genelde biz bir taslak çıkarıyoruz, siz üstünde oynuyorsunuz. Elinizde kendi menünüz varsa onu da uygularız.',
            ],
            [
                'question' => 'Vejetaryen ya da alerjisi olan çalışanlarımız var.',
                'answer' => 'Onlara ayrı yemek pişiriyoruz, ayrı kaba koyup etiketliyoruz. Alerjen listesini siz veriyorsunuz; liste değişince menü de değişiyor.',
            ],
            [
                'question' => 'Kişi sayımız her gün değişiyor, sorun olur mu?',
                'answer' => 'Olmaz. Sabah kaç kişi olduğunuzu bildiriyorsunuz, o kadar hazırlıyoruz. Değişken sayı bizim için olağan.',
            ],
            [
                'question' => 'Yemek sıcak geliyor mu?',
                'answer' => 'Isı tutan kapalı kaplarda taşınıyor ve teslimde sıcaklığa bakılıyor. Yol uzunsa menüyü de ona göre kuruyoruz — yolda dağılacak yemeği o güne koymuyoruz.',
            ],
            [
                'question' => 'Tabak, çatal ve servis elemanı da veriyor musunuz?',
                'answer' => 'Taşıma yemekte yemeği servise hazır bırakıyoruz. Davet ve organizasyonlarda kurulum, servis ekibi ve toplama işi de bize ait olabilir.',
            ],
            [
                'question' => 'Fiyatlar neden sitede yazmıyor?',
                'answer' => 'Kişi sayısı, öğün sayısı, kaç gün ve nereye — dördü değişince fiyat da değişiyor. Sabit bir liste yazsak yanıltıcı olurdu. Bilgileri iletin, size özel çıkaralım.',
            ],
            [
                'question' => 'Ne kadar süreyle sözleşme yapmamız gerekiyor?',
                'answer' => 'Zorunlu bir alt süre koymuyoruz. Düzenli hizmette genelde dönemsel bir çerçeve tercih ediliyor; davetler için sözleşme etkinliğe özel yazılıyor.',
            ],
        ];
    }

    /**
     * Hizmet verilen alanlar — SEKTÖR anlatır, referans firma değil.
     *
     * Repoda doğrulanmış müşteri bilgisi yok; sahte logo veya firma adı üretmek
     * yerine hangi alanlarda çalışıldığı ve o alanın neye ihtiyaç duyduğu
     * anlatılıyor.
     *
     * @return list<array<string, string>>
     */
    private static function sectors(): array
    {
        return [
            [
                'slug' => 'sanayi',
                'title' => 'Sanayi ve üretim',
                'icon' => 'Factory',
                'need' => 'Vardiya zilinde hazır olan, ağır işe yeten yemek.',
                'answer' => 'Teslim saatini vardiya değişimine bağlıyoruz. Menü doyuruyor, sayı gün gün güncelleniyor.',
                'service_slug' => 'kurumsal-toplu-yemek',
            ],
            [
                'slug' => 'egitim',
                'title' => 'Okullar ve kreşler',
                'icon' => 'GraduationCap',
                'need' => 'Yaşa uygun porsiyon, alerji takibi ve veliye gösterilebilir bir menü.',
                'answer' => 'Öğün planı yaşa göre ayrılıyor, alerjisi olana ayrı tabak çıkıyor, aylık liste paylaşıma hazır geliyor.',
                'service_slug' => 'okul-yemek-hizmeti',
            ],
            [
                'slug' => 'saglik',
                'title' => 'Sağlık kuruluşları',
                'icon' => 'HeartPulse',
                'need' => 'Hasta diyetiyle personel yemeğinin birbirine karışmaması.',
                'answer' => 'Diyet öğünleri ayrı pişiyor, hasta adına etiketleniyor. Personel menüsü vardiyaya göre ayrı planlanıyor.',
                'service_slug' => 'saglik-kuruluslari',
            ],
            [
                'slug' => 'kamu',
                'title' => 'Kamu kurumları',
                'icon' => 'Landmark',
                'need' => 'Şartnameye uyan ve belgelenebilen bir düzen.',
                'answer' => 'Menü planı, teslim kayıtları ve öğün sayıları raporlanabilir tutuluyor; hizmet şartnameye göre kuruluyor.',
                'service_slug' => 'tasima-yemek',
            ],
            [
                'slug' => 'ofis',
                'title' => 'Ofisler',
                'icon' => 'Building',
                'need' => 'Mutfak kurmadan, çalışanın memnun olacağı bir öğle yemeği.',
                'answer' => 'Yemek bizde pişiyor, servise hazır geliyor. Ofiste bir masa yeterli.',
                'service_slug' => 'tasima-yemek',
            ],
            [
                'slug' => 'insaat',
                'title' => 'İnşaat ve saha',
                'icon' => 'TrafficCone',
                'need' => 'Yolu zor sahaya, her gün değişen sayıyla teslimat.',
                'answer' => 'Teslimi saha koşullarına göre planlıyoruz. Sabah kaç kişiyseniz, öğlen o kadar tabak.',
                'service_slug' => 'santiye-yemek',
            ],
            [
                'slug' => 'organizasyon',
                'title' => 'Davet ve etkinlik',
                'icon' => 'PartyPopper',
                'need' => 'Bir kez olacak ve hatasız olması gereken bir gün.',
                'answer' => 'Menü, kurulum, servis ve toplama tek pakette. Davetli sayısı artarsa diye pay bırakıyoruz.',
                'service_slug' => 'davet-organizasyon',
            ],
        ];
    }

    /**
     * Menü çözümleri — ÖRNEK kurgular, FİYAT YOK.
     *
     * Catering fiyatı kişi sayısı, sıklık ve konuma göre değişiyor; sabit rakam
     * yazmak yanıltıcı olurdu. Firma gerçek menülerini girdiğinde bu kayıtlar
     * panelden güncellenir.
     *
     * `courses[].examples` VİRGÜLLE AYRILMIŞ TEK METİN, dizi değil: panelde bu
     * alan tek satırlık bir kutu (`resources/models/sitecontentsettings.php`).
     * Dizi yazsaydık form kutusuna dizi basmaya çalışır ve ekran patlardı;
     * kaynak dosyadaki dizi bu yüzden burada birleştirildi.
     *
     * @return array<string, mixed>
     */
    private static function menus(): array
    {
        return [
            'solutions' => [
                [
                    'slug' => 'kurumsal-dort-kap',
                    'title' => 'Kurumsal dört kap',
                    'summary' => 'Çorba, ana yemek, pilav ve yanına bir salata. Klasik öğle sofrası.',
                    'audience' => 'Ofis, fabrika ve kurumsal yemekhaneler',
                    'courses' => [
                        [
                            'label' => 'Çorba',
                            'examples' => 'Mercimek çorbası, Ezogelin, Yayla çorbası',
                        ],
                        [
                            'label' => 'Ana yemek',
                            'examples' => 'Etli kuru fasulye, Tavuk sote, Fırın tavuk but, Etli türlü',
                        ],
                        [
                            'label' => 'Yardımcı yemek',
                            'examples' => 'Pirinç pilavı, Bulgur pilavı, Makarna',
                        ],
                        [
                            'label' => 'Tamamlayıcı',
                            'examples' => 'Mevsim salata, Cacık, Ayran, Mevsim meyvesi',
                        ],
                    ],
                    'principle' => 'Aynı ana yemek hafta içinde iki kez çıkmaz. Et, tavuk ve baklagil güne dağıtılır.',
                ],
                [
                    'slug' => 'personel-uc-kap',
                    'title' => 'Personel üç kap',
                    'summary' => 'Molası kısa olan yerler için. Çabuk servis edilir, çabuk yenir.',
                    'audience' => 'Vardiyalı çalışan üretim tesisleri ve saha ekipleri',
                    'courses' => [
                        [
                            'label' => 'Çorba',
                            'examples' => 'Mercimek çorbası, Tarhana',
                        ],
                        [
                            'label' => 'Ana yemek',
                            'examples' => 'Etli nohut, Köfte, Tavuk haşlama',
                        ],
                        [
                            'label' => 'Tamamlayıcı',
                            'examples' => 'Pilav, Ekmek, Ayran',
                        ],
                    ],
                    'principle' => 'Kepçeyle kolay dağılan, uzun süre sıcak kalan yemekleri seçiyoruz. Sıra hızlı akıyor.',
                ],
                [
                    'slug' => 'ogrenci-menusu',
                    'title' => 'Öğrenci menüsü',
                    'summary' => 'Yaşa göre porsiyon, tabakta alerjen işareti.',
                    'audience' => 'Anaokulu, ilkokul, ortaokul ve liseler',
                    'courses' => [
                        [
                            'label' => 'Çorba veya başlangıç',
                            'examples' => 'Sebze çorbası, Şehriye çorbası',
                        ],
                        [
                            'label' => 'Ana yemek',
                            'examples' => 'Fırın makarna, Köfte, Sebzeli tavuk',
                        ],
                        [
                            'label' => 'Tamamlayıcı',
                            'examples' => 'Pilav, Yoğurt, Meyve',
                        ],
                        [
                            'label' => 'İkindi ikramı',
                            'examples' => 'Süt, Kek, Kuru meyve',
                        ],
                    ],
                    'principle' => 'Çocuğun yediği biçimde veriyoruz. Ağır baharat ve yoğun sos yok.',
                ],
                [
                    'slug' => 'kahvalti-ikram',
                    'title' => 'Kahvaltı ve ikram paketleri',
                    'summary' => 'Toplantı ve eğitimlere, kurulumu on dakika süren ikram masaları.',
                    'audience' => 'Toplantı, seminer, eğitim ve lansmanlar',
                    'courses' => [
                        [
                            'label' => 'Açık büfe kahvaltı',
                            'examples' => 'Peynir çeşitleri, Zeytin, Yumurta, Reçel',
                        ],
                        [
                            'label' => 'Fırın ürünleri',
                            'examples' => 'Poğaça, Açma, Simit, Börek',
                        ],
                        [
                            'label' => 'Ara ikram',
                            'examples' => 'Kurabiye, Meyve tabağı, Kuruyemiş',
                        ],
                        [
                            'label' => 'İçecek',
                            'examples' => 'Çay, Filtre kahve, Meyve suyu',
                        ],
                    ],
                    'principle' => 'Ayakta, elde yenen şeyler öne çıkıyor. Çatal aramak gerekmiyor.',
                ],
                [
                    'slug' => 'davet-menusu',
                    'title' => 'Davet menüsü',
                    'summary' => 'Düğün, açılış ve kurumsal davetlere karşılamadan tatlıya kadar.',
                    'audience' => 'Düğün, nişan, açılış ve kurumsal davetler',
                    'courses' => [
                        [
                            'label' => 'Karşılama',
                            'examples' => 'Soğuk mezeler, Kanepe, Limonata',
                        ],
                        [
                            'label' => 'Başlangıç',
                            'examples' => 'Çorba, Soğuk başlangıç tabağı',
                        ],
                        [
                            'label' => 'Ana yemek',
                            'examples' => 'Fırın et, Tavuk şiş, Sebzeli et sote',
                        ],
                        [
                            'label' => 'Tamamlayıcı',
                            'examples' => 'Pilav, Salata, Sıcak börek',
                        ],
                        [
                            'label' => 'Tatlı',
                            'examples' => 'Sütlü tatlı, Şerbetli tatlı, Meyve',
                        ],
                    ],
                    'principle' => 'Menüyü saat belirliyor: öğle davetinde daha hafif, akşamda daha uzun bir sofra.',
                ],
                [
                    'slug' => 'ozel-beslenme',
                    'title' => 'Vejetaryen ve özel beslenme',
                    'summary' => 'Ana menü uymayanlar için ayrı pişen, ayrı gelen tabak.',
                    'audience' => 'Vejetaryen, alerjisi olan veya özel diyet uygulayan katılımcılar',
                    'courses' => [
                        [
                            'label' => 'Ana yemek',
                            'examples' => 'Sebzeli güveç, Nohutlu bulgur pilavı, Mercimek köfte',
                        ],
                        [
                            'label' => 'Tamamlayıcı',
                            'examples' => 'Yeşil salata, Humus, Yoğurt (istenirse)',
                        ],
                        [
                            'label' => 'Alerjen yönetimi',
                            'examples' => 'Glutensiz seçenek, Laktozsuz seçenek',
                        ],
                    ],
                    'principle' => 'Ayrı tezgâhta hazırlanıyor, üzerine adı yazılıyor, ayrı kapta yola çıkıyor.',
                ],
            ],
            'seasonal' => [
                [
                    'season' => 'İlkbahar',
                    'note' => 'Taze sebze ve yeşillik menüye giriyor; salata tabağı büyüyor.',
                ],
                [
                    'season' => 'Yaz',
                    'note' => 'Yemek hafifliyor, soğuk başlangıçlar ve ayran öne geçiyor.',
                ],
                [
                    'season' => 'Sonbahar',
                    'note' => 'Kuru fasulye, nohut ve kök sebzelerin sırası geliyor.',
                ],
                [
                    'season' => 'Kış',
                    'note' => 'Çorba çeşidi artıyor; sıcak tutan, doyuran yemekler öne çıkıyor.',
                ],
            ],
        ];
    }

    /** @return array<string, mixed> */
    private static function quality(): array
    {
        return [
            'chain' => [
                [
                    'title' => 'Mal girişi',
                    'body' => 'Malzemeyi hep aynı yerlerden alıyoruz. Kapıda kasa kasa bakılır; beğenilmeyen geri gider.',
                    'icon' => 'Sprout',
                ],
                [
                    'title' => 'Depo',
                    'body' => 'Kuru gıda, soğuk ve dondurulmuş ayrı yerlerde durur. Rafta önce giren önce çıkar.',
                    'icon' => 'Refrigerator',
                ],
                [
                    'title' => 'Tezgâh',
                    'body' => 'Tezgâh ve ekipman iş öncesi ve sonrası temizlenir. Çiğ etin bıçağı salatanın bıçağı olmaz.',
                    'icon' => 'UtensilsCrossed',
                ],
                [
                    'title' => 'Ekip',
                    'body' => 'Mutfakta bone, maske ve iş kıyafeti var. El yıkamak işin adımlarından biri.',
                    'icon' => 'ShieldCheck',
                ],
                [
                    'title' => 'Ocak',
                    'body' => 'Pişirme saati servis saatinden geri sayılarak belirlenir. Sabahtan pişip öğlene kadar bekleyen yemek yok.',
                    'icon' => 'ClipboardCheck',
                ],
                [
                    'title' => 'Sıcaklık',
                    'body' => 'Sıcak sıcakta, soğuk soğukta durur. Termometre hem çıkışta hem teslimde giriyor.',
                    'icon' => 'ThermometerSnowflake',
                ],
                [
                    'title' => 'Yol',
                    'body' => 'Yemek ısı tutan kapalı kaplarla gider. Kaç kap, kaçta teslim edildi — hepsi yazılır.',
                    'icon' => 'Truck',
                ],
                [
                    'title' => 'Kayıt',
                    'body' => 'Hangi gün ne pişti, nereye gitti — hepsi duruyor. Geriye dönüp bakmak gerekirse kayıt orada.',
                    'icon' => 'PackageCheck',
                ],
            ],
            'allergen' => [
                [
                    'text' => 'Menüdeki yemeklerin bilinen alerjenlerini önden yazılı veriyoruz.',
                ],
                [
                    'text' => 'Alerjisi olana ayrı yemek pişiyor, kabın üzerine adı yazılıyor.',
                ],
                [
                    'text' => 'O kaplar ayrı taşınıyor — yolda diğerlerine değmiyor.',
                ],
                [
                    'text' => 'Listeyi siz veriyorsunuz. Yeni bir isim eklendiğinde menü planı da değişiyor.',
                ],
            ],
            'certifications' => [],
        ];
    }

    /**
     * Hizmet kataloğu — sekiz hizmet.
     *
     * Metinler bilinçli olarak YETENEĞİ anlatır, İDDİAYI değil: "şu kadar kişiye
     * hizmet veriyoruz" gibi doğrulanmamış rakam yok.
     *
     * `sort_order` dizideki sıradan üretilir (bkz. komut); burada yazılmıyor ki
     * araya bir hizmet eklendiğinde sekiz satırın numarası elle kaydırılmasın.
     *
     * @return list<array<string, mixed>>
     */
    public static function services(): array
    {
        return [
            [
                'slug' => 'kurumsal-toplu-yemek',
                'title' => 'Kurumsal toplu yemek',
                'summary' => 'Ofis, fabrika ve iş yerlerine her gün tekrarlayan öğle ve akşam yemeği.',
                'intro' => 'Her sabah aynı saatte pişer, aynı saatte gelir. Menüyü bir hafta önceden görürsünüz; teslim saatini vardiyanız belirler.',
                'icon' => 'Building2',
                'audience' => [
                    'Ofisler ve iş merkezleri',
                    'Vardiyalı çalışan üretim tesisleri',
                    'Yemekhanesi olan da olmayan da',
                    'Personeline her gün sıcak yemek veren kurumlar',
                ],
                'how_it_works' => [
                    [
                        'title' => 'Sayıyı ve saati konuşuyoruz',
                        'body' => 'Günde kaç kişi, hangi saatte, kaç vardiya. Yemekhaneniz varsa gelip bakıyoruz.',
                    ],
                    [
                        'title' => 'Haftalık menüyü çıkarıyoruz',
                        'body' => 'Bir haftalık liste hazırlıyoruz. Aynı yemek üst üste gelmez; onaylayınca kesinleşir.',
                    ],
                    [
                        'title' => 'Pişiriyoruz, getiriyoruz',
                        'body' => 'Yemek sabah mutfakta yapılır, ısı tutan kaplarda saatinde kapınızda olur.',
                    ],
                    [
                        'title' => 'Sayıyor, soruyoruz',
                        'body' => 'Ne arttı, ne bitti bakıyoruz. Kimsenin yemediği yemek bir daha menüye girmiyor.',
                    ],
                ],
                'benefits' => [
                    'Mutfak kurmak, aşçı tutmak, malzeme almak yok',
                    'Öğün maliyetiniz baştan belli',
                    'Menü tekrarını biz takip ediyoruz',
                    'Sipariş de fatura da tek kişide',
                ],
                'menu_planning' => 'Menü kimin yediğine göre değişir. Ağır işte doyuran yemekler öne çıkar, ofiste daha hafif kaplar. Vejetaryen ya da alerjisi olan varsa onlara ayrı bir kap ekleriz.',
                'quote_needs' => [
                    'Günde ortalama kaç kişi',
                    'Öğün ve saatleri (öğle, akşam, vardiya arası)',
                    'Adres',
                    'Haftada kaç gün',
                ],
            ],
            [
                'slug' => 'tasima-yemek',
                'title' => 'Taşıma yemek',
                'summary' => 'Yemek bizim mutfakta pişer, servise hazır hâlde adresinize gelir.',
                'intro' => 'Mutfağınız yoksa ya da işletmek istemiyorsanız en pratik yol bu. Bizde pişer, kapalı kapta gelir, siz yalnızca servis edersiniz.',
                'icon' => 'Truck',
                'audience' => [
                    'Mutfağı olmayan iş yerleri',
                    'Küçük ve orta ölçekli ofisler',
                    'Proje bazlı, geçici çalışma alanları',
                    'Yemekhanesi yalnızca servis alanı olan kurumlar',
                ],
                'how_it_works' => [
                    [
                        'title' => 'Sayı ve saat',
                        'body' => 'Kaç kişi ve saat kaçta. Menüyü önden paylaşıyoruz.',
                    ],
                    [
                        'title' => 'Mutfakta üretim',
                        'body' => 'Teslim saatinden geri sayarak pişiriyoruz — erken pişip bekleyen yemek yok.',
                    ],
                    [
                        'title' => 'Kapalı kapta yol',
                        'body' => 'Sıcak sıcak, soğuk soğuk gider. Kapıda sıcaklığa bakılır.',
                    ],
                    [
                        'title' => 'Servise hazır teslim',
                        'body' => 'İsterseniz servis alanınıza kurarız, isterseniz kapalı kapta bırakırız.',
                    ],
                ],
                'benefits' => [
                    'Mutfak yatırımı ve işletme gideri yok',
                    'Servis alanı dışında yer ayırmıyorsunuz',
                    'Sayı değiştiğinde aynı gün uyarlanıyor',
                    'Teslim saatini iş akışınız belirliyor',
                ],
                'menu_planning' => 'Yolu iyi götüren yemekleri seçiyoruz: uzun süre sıcak kalan, sarsıntıda dağılmayan kaplar. Kızartma gibi çabuk yumuşayan şeyleri teslim saatine yakın planlıyoruz.',
                'quote_needs' => [
                    'Günde kaç kişi',
                    'Teslim adresi ve saati',
                    'Kaç kap istiyorsunuz (üç kap, dört kap)',
                    'Tabak-çatal ihtiyacınız var mı',
                ],
            ],
            [
                'slug' => 'yerinde-uretim',
                'title' => 'Yerinde üretim',
                'summary' => 'Sizin mutfağınızda, bizim ekibimizle günlük pişirme.',
                'intro' => 'Mutfağınız varsa yemek orada pişsin. Yol yok, bekleme yok; tencereden tabağa geçen süre birkaç dakika.',
                'icon' => 'ChefHat',
                'audience' => [
                    'Kendi mutfağı olan fabrika ve kampüsler',
                    'Yemekhanesini dışarıya vermek isteyen kurumlar',
                    'Yüksek kişi sayılı tesisler',
                    'Kahvaltı, öğle ve akşamı aynı yerde veren kuruluşlar',
                ],
                'how_it_works' => [
                    [
                        'title' => 'Mutfağa bakıyoruz',
                        'body' => 'Ekipman, depo, havalandırma ve kaç kişilik ekip gerektiği yerinde çıkarılıyor.',
                    ],
                    [
                        'title' => 'Ekibi kuruyoruz',
                        'body' => 'Aşçı ve servis ekibi göreve başlıyor, mutfağın günlük düzeni oturuyor.',
                    ],
                    [
                        'title' => 'Her gün taze',
                        'body' => 'Malzemeyi biz alıyoruz, yemek servis saatine göre yerinde pişiyor.',
                    ],
                    [
                        'title' => 'Servis ve rapor',
                        'body' => 'Servisi biz yürütüyoruz; ne kadar tüketildiği ve stok durumu düzenli olarak size geliyor.',
                    ],
                ],
                'benefits' => [
                    'Yemek yendiği yerde pişiyor, yolda tat kaybı yok',
                    'Gün içinde menüyü esnetmek mümkün',
                    'Mutfak personeli derdi sizden çıkıyor',
                    'Malzeme, hijyen ve servis tek elde',
                ],
                'menu_planning' => 'Esnekliğin en yüksek olduğu düzen bu. Açık büfe kurulabilir, porsiyon gün içinde ayarlanabilir, ikinci parti pişirilebilir. Menüyü mutfağın ekipmanı belirler.',
                'quote_needs' => [
                    'Günlük kişi ve öğün sayısı',
                    'Mutfak alanı ve mevcut ekipman',
                    'Servis düzeni (tabldot, açık büfe)',
                    'Ne kadar süreli düşünüyorsunuz',
                ],
            ],
            [
                'slug' => 'okul-yemek-hizmeti',
                'title' => 'Okul yemek hizmeti',
                'summary' => 'Yaşa göre porsiyon, alerjen takibi ve veliye gösterilebilir menü.',
                'intro' => 'Anaokulundaki çocukla lise öğrencisi aynı tabağı yemiyor. Menüyü yaşa göre kuruyoruz ve çocukların gerçekten yediği yemekleri koyuyoruz.',
                'icon' => 'GraduationCap',
                'audience' => [
                    'Anaokulu ve kreşler',
                    'İlkokul, ortaokul ve liseler',
                    'Özel eğitim kurumları',
                    'Yurtlar ve pansiyonlar',
                ],
                'how_it_works' => [
                    [
                        'title' => 'Yaş grupları ve öğünler',
                        'body' => 'Kahvaltı, öğle, ikindi — hangisi hangi yaşa, kaç kişilik.',
                    ],
                    [
                        'title' => 'Alerji listesi',
                        'body' => 'Alerjisi ya da özel beslenmesi olan öğrenciler listeleniyor, onlara ayrı öğün planlanıyor.',
                    ],
                    [
                        'title' => 'Ders saatine göre teslim',
                        'body' => 'Yemek teneffüse yetişecek şekilde hazırlanıp getiriliyor.',
                    ],
                    [
                        'title' => 'Veliye gidecek menü',
                        'body' => 'Aylık liste, okulun paylaştığı biçimde hazır geliyor.',
                    ],
                ],
                'benefits' => [
                    'Porsiyon yaş grubuna göre',
                    'Alerjen bilgisi öğrenci bazında takip ediliyor',
                    'Aylık menü veliyle paylaşılmaya hazır',
                    'Öğün saatleri ders programına kilitli',
                ],
                'menu_planning' => 'Sebzeyi ve baklagili çocukların yediği biçimde veriyoruz. Ağır baharat, yoğun sos yok. Aylık listede aynı yemek sık sık dönmüyor; son hâlini okul yönetimi onaylıyor.',
                'quote_needs' => [
                    'Öğrenci sayısı ve yaş grupları',
                    'Günde kaç öğün (kahvaltı, öğle, ikindi)',
                    'Alerjisi olan öğrenci sayısı',
                    'Dönemde kaç gün hizmet',
                ],
            ],
            [
                'slug' => 'saglik-kuruluslari',
                'title' => 'Sağlık kuruluşlarına yemek',
                'summary' => 'Hasta diyeti, personel öğünü ve refakatçi yemeği ayrı ayrı.',
                'intro' => 'Burada tek menü iş görmüyor. Diyet tabağı, nöbetçi hemşirenin tabağı ve refakatçinin tabağı ayrı hazırlanıyor, ayrı etiketleniyor.',
                'icon' => 'Stethoscope',
                'audience' => [
                    'Hastaneler ve tıp merkezleri',
                    'Diyaliz ve rehabilitasyon merkezleri',
                    'Huzurevleri ve bakım evleri',
                    'Poliklinikler ve sağlık kampüsleri',
                ],
                'how_it_works' => [
                    [
                        'title' => 'Diyet listeleri geliyor',
                        'body' => 'Kurumun diyetisyeni hangi diyetten kaç öğün gerektiğini bildiriyor.',
                    ],
                    [
                        'title' => 'Ayrı akış, ayrı etiket',
                        'body' => 'Diyet öğünleri personel ve refakatçi yemeğinden ayrı hazırlanıyor, üzerine kimin olduğu yazılıyor.',
                    ],
                    [
                        'title' => 'Kata teslim',
                        'body' => 'Öğünler servis saatinde ilgili birime, etiketleriyle çıkıyor.',
                    ],
                    [
                        'title' => 'Gün içi değişiklik',
                        'body' => 'Diyet talimatı değiştiğinde o öğün için güncelleniyor.',
                    ],
                ],
                'benefits' => [
                    'Hasta, personel ve refakatçi tabakları karışmıyor',
                    'Her diyet öğünü etiketli çıkıyor',
                    'Servis saatleri vizit düzenine göre',
                    'Gün içinde değişen talimata uyum',
                ],
                'menu_planning' => 'Diyet menülerini kurumun diyetisyeni belirliyor; biz pişirip yetiştiriyoruz. Personel menüsü vardiya saatlerine göre ayrı planlanıyor.',
                'quote_needs' => [
                    'Yatak kapasitesi ve ortalama doluluk',
                    'Diyet tipleri ve günlük öğün sayısı',
                    'Personel sayısı ve vardiya düzeni',
                    'Kat/birim dağıtımı gerekiyor mu',
                ],
            ],
            [
                'slug' => 'santiye-yemek',
                'title' => 'Şantiye yemek hizmeti',
                'summary' => 'Sahaya kadar gelen, ağır işe yeten doyurucu öğünler.',
                'intro' => 'Şantiyede iş ağır, mola kısa, saat sabit değil. Menüyü karnı doyuracak şekilde kuruyor, teslimi vardiya değişimine göre ayarlıyoruz.',
                'icon' => 'HardHat',
                'audience' => [
                    'İnşaat şantiyeleri',
                    'Altyapı ve enerji projeleri',
                    'Maden ve saha operasyonları',
                    'Geçici işçi kampları',
                ],
                'how_it_works' => [
                    [
                        'title' => 'Saha ve vardiya',
                        'body' => 'Şantiye nerede, yol nasıl, vardiyalar kaçta. Hepsi teslim planına giriyor.',
                    ],
                    [
                        'title' => 'Doyuran menü',
                        'body' => 'Et ve baklagil ağırlıklı, uzun süre tok tutan yemekler.',
                    ],
                    [
                        'title' => 'Sahaya teslim',
                        'body' => 'Isı tutan kaplarla, vardiya değişimine yetişecek saatte.',
                    ],
                    [
                        'title' => 'Sayı takibi',
                        'body' => 'Sahada kaç kişi varsa o kadar. Sabah bildirim, öğlen yemek.',
                    ],
                ],
                'benefits' => [
                    'Teslim saati vardiyaya göre',
                    'Ağır iş koluna göre porsiyon',
                    'Değişken personel sayısına hızlı uyum',
                    'Sahada servis düzeni kurulumu',
                ],
                'menu_planning' => 'Kışın çorba çeşidi artıyor, sıcak tutan yemekler öne geçiyor. Yazın ayran ve soğuk yan ürünler devreye giriyor.',
                'quote_needs' => [
                    'Şantiye konumu ve yol durumu',
                    'Kaç vardiya, hangi saatlerde',
                    'Günlük ortalama personel',
                    'Proje ne kadar sürecek',
                ],
            ],
            [
                'slug' => 'davet-organizasyon',
                'title' => 'Davet ve organizasyon',
                'summary' => 'Düğün, açılış ve kurumsal davetlere kurulumuyla birlikte catering.',
                'intro' => 'Davette yemek kadar servisin düzeni de konuşuluyor. Menüyü, sunumu ve ekibi günün akışına göre kuruyoruz; sonunda ortalığı da biz topluyoruz.',
                'icon' => 'CalendarHeart',
                'audience' => [
                    'Düğün, nişan ve kına',
                    'Açılış ve tanıtım etkinlikleri',
                    'Kurumsal yemekler ve yıl sonu davetleri',
                    'Özel gün kutlamaları',
                ],
                'how_it_works' => [
                    [
                        'title' => 'Günü konuşuyoruz',
                        'body' => 'Tarih, kaç davetli, mekân nerede, servis nasıl olsun — açık büfe mi, masaya mı.',
                    ],
                    [
                        'title' => 'Menü ve tadım',
                        'body' => 'Saatine göre menü çıkarıyoruz. İsterseniz önceden gelip tadıyorsunuz.',
                    ],
                    [
                        'title' => 'Mekânı kuruyoruz',
                        'body' => 'Büfe, servis alanı ve ekipman etkinlikten önce hazır oluyor.',
                    ],
                    [
                        'title' => 'Servis ve toplama',
                        'body' => 'Ekip gün boyu sahada. Bitince masalar toplanıyor, alan teslim ediliyor.',
                    ],
                ],
                'benefits' => [
                    'Menü ve servis biçimi güne göre',
                    'Kurulum ve toplama dâhil',
                    'Son dakika davetlisi için pay bırakılıyor',
                    'Servis ekibi etkinlik boyunca yanınızda',
                ],
                'menu_planning' => 'Öğle davetinde daha hafif, akşam davetinde daha kapsamlı bir akış kuruyoruz. Vejetaryen ve alerjen alternatifleri davetli listesine göre ekleniyor.',
                'quote_needs' => [
                    'Tarih ve saat',
                    'Davetli sayısı',
                    'Mekân adresi, mutfak ve servis imkânları',
                    'Açık büfe mi, masaya servis mi',
                ],
            ],
            [
                'slug' => 'toplanti-ikram',
                'title' => 'Toplantı ikramları',
                'summary' => 'Kahvaltı, ara ikramı ve seminer paketleri.',
                'intro' => 'İkram, toplantıyı bölmeden kurulup toplanmalı. Paketi katılımcı sayısına ve program akışına göre hazırlıyoruz.',
                'icon' => 'Coffee',
                'audience' => [
                    'Kurumsal toplantı ve eğitimler',
                    'Seminer ve konferanslar',
                    'Yönetim kurulu toplantıları',
                    'Basın toplantıları ve lansmanlar',
                ],
                'how_it_works' => [
                    [
                        'title' => 'Programı alıyoruz',
                        'body' => 'Toplantı kaçta başlıyor, aralar ne zaman, ikram nereye kurulacak.',
                    ],
                    [
                        'title' => 'Paketi seçiyoruz',
                        'body' => 'Kahvaltı, ara ikramı ya da öğle paketi. Sıcak ve soğuk bir arada.',
                    ],
                    [
                        'title' => 'Kurulum',
                        'body' => 'İkram alanı program başlamadan hazır oluyor.',
                    ],
                    [
                        'title' => 'Aralarda tazeleme',
                        'body' => 'Her arada masa yenileniyor, program bitince alan toplanıyor.',
                    ],
                ],
                'benefits' => [
                    'Program bölünmüyor',
                    'Paket katılımcı sayısına göre büyüyor',
                    'Sıcak ve soğuk seçenekler bir arada',
                    'Aynı gün birden fazla ara',
                ],
                'menu_planning' => 'Ara ikramında elde yenen, çatal gerektirmeyen şeyler öne çıkıyor. Gün boyu süren programlarda her arada başka bir şey çıkıyor.',
                'quote_needs' => [
                    'Tarih ve program saatleri',
                    'Katılımcı sayısı',
                    'Kaç ara, hangi tür ikram',
                    'Etkinlik adresi',
                ],
            ],
        ];
    }

    /**
     * Bilgi merkezi yazıları — altı yazı.
     *
     * `body` HAM HTML DEĞİL, tipli bloklardan oluşuyor (`paragraph`, `heading`,
     * `list`, `callout`). Sebebi kaynak dosyadakiyle aynı: başlık hiyerarşisi
     * (h2/h3) yanlışlıkla bozulamaz ve buraya `<div style=...>` sızamaz.
     * Bloklar komut tarafında HTML'e çevrilir.
     *
     * @return list<array<string, mixed>>
     */
    public static function posts(): array
    {
        return [
            [
                'slug' => 'toplu-yemek-firmasi-secerken',
                'title' => 'Toplu yemek firması seçerken nelere bakmalı?',
                'description' => 'İki teklifin arasındaki fark çoğu zaman yemekte değil, kapsamda. İmzadan önce sormanız gereken sorular.',
                'category' => 'Karar rehberi',
                'published_at' => '2026-03-04',
                'reading_minutes' => 6,
                'body' => [
                    [
                        'kind' => 'paragraph',
                        'text' => 'Yemek, çalışanınızın sizinle her gün temas ettiği birkaç şeyden biri. Yanlış firma seçilirse bunu üç hafta içinde koridorda duyarsınız. Buna rağmen karar çoğu zaman tek bir rakama bakılarak veriliyor.',
                    ],
                    [
                        'kind' => 'paragraph',
                        'text' => 'Aşağıdakileri teklif istemeden önce netleştirin. Hem teklifleri yan yana koyabilirsiniz hem de üçüncü ay sürprizi çıkmaz.',
                    ],
                    [
                        'kind' => 'heading',
                        'text' => 'Fiyatın neyi kapsadığını sorun',
                    ],
                    [
                        'kind' => 'paragraph',
                        'text' => 'Aynı rakam bir yerde sadece yemeği, başka bir yerde servis elemanını, ekipmanı ve tabak çatalı da kapsıyor olabilir. Farkı yaratan çoğu zaman tencere değil, listenin altındaki satırlar.',
                    ],
                    [
                        'kind' => 'list',
                        'items' => [
                            'Kaç kap yemek dâhil?',
                            'Ekmek, içecek ve salata fiyata dâhil mi?',
                            'Servis personeli ve ekipman kimin sorumluluğunda?',
                            'Tek kullanımlık malzeme (tabak, çatal, peçete) kimden?',
                            'Teslimat ücreti ayrı mı hesaplanıyor?',
                        ],
                    ],
                    [
                        'kind' => 'heading',
                        'text' => 'Menü planının nasıl kurulduğunu öğrenin',
                    ],
                    [
                        'kind' => 'paragraph',
                        'text' => 'İyi menü tesadüfen çıkmaz. Et, tavuk ve baklagil güne dağılır; mevsim gözetilir; aynı yemek üst üste gelmez. Kim hazırlıyor, kaç gün önce elinize geçiyor, üstünde değişiklik isteyebiliyor musunuz — bunları sorun.',
                    ],
                    [
                        'kind' => 'callout',
                        'text' => 'Menüyü sabahında bildiren bir firmayla plan yapamazsınız. En az bir hafta önceden elinizde olmalı.',
                    ],
                    [
                        'kind' => 'heading',
                        'text' => 'Değişken kişi sayısını nasıl yönettiğini sorun',
                    ],
                    [
                        'kind' => 'paragraph',
                        'text' => 'Hiçbir iş yerinde her gün aynı sayıda insan yoktur. İzin var, vardiya var, sahaya giden var. Firma sabah bildirim mi alıyor yoksa sabit sayıdan mı faturalıyor? Cevap hem faturanızı hem çöpe giden yemeği değiştiriyor.',
                    ],
                    [
                        'kind' => 'heading',
                        'text' => 'Hijyen yaklaşımını somut sorularla test edin',
                    ],
                    [
                        'kind' => 'paragraph',
                        'text' => 'Hijyene önem verdiğini söylemeyen firma yok. Somut sorun: sıcaklık nerede ölçülüyor, çiğ tavuğun tezgâhı ayrı mı, teslim kaydı tutuluyor mu? Bunların cevabı ya vardır ya yoktur.',
                    ],
                    [
                        'kind' => 'paragraph',
                        'text' => 'Belge iddiası duyduğunuzda belgeyi isteyin. Göstermekten kaçınan firmada o belge büyük ihtimalle yoktur.',
                    ],
                    [
                        'kind' => 'heading',
                        'text' => 'Sorun çıktığında kime ulaşacağınızı netleştirin',
                    ],
                    [
                        'kind' => 'paragraph',
                        'text' => 'Yemek geç kaldığında, on porsiyon eksik geldiğinde ya da biri şikâyet ettiğinde kimi arayacaksınız? Bir isim ve bir numara, çağrı merkezinden çok daha hızlı iş görüyor.',
                    ],
                    [
                        'kind' => 'heading',
                        'text' => 'Deneme servisi isteyin',
                    ],
                    [
                        'kind' => 'paragraph',
                        'text' => 'Kâğıttaki menüyle tabaktaki yemek arasındaki farkı tadım gösterir. Tadıma yöneticileri değil, o yemeği her gün yiyecek insanları götürün.',
                    ],
                ],
            ],
            [
                'slug' => 'kurumsal-catering-nedir',
                'title' => 'Kurumsal catering nedir, restorandan farkı ne?',
                'description' => 'İkisi de yemek yapar ama mutfakları zıt kurulur. Kurumsal catering nasıl işler, neyi kapsar?',
                'category' => 'Temel bilgiler',
                'published_at' => '2026-02-18',
                'reading_minutes' => 5,
                'body' => [
                    [
                        'kind' => 'paragraph',
                        'text' => 'Dışarıdan bakınca ikisi de yemek yapıyor. Mutfağa girince iki ayrı iş olduğu anlaşılıyor.',
                    ],
                    [
                        'kind' => 'heading',
                        'text' => 'Restoran talebi bekler, catering talebi bilir',
                    ],
                    [
                        'kind' => 'paragraph',
                        'text' => 'Restoranda kaç kişi gelecek, ne söyleyecek belli değildir; mutfak her ihtimale hazır durur. Cateringde sayı da menü de önceden bellidir. Bu yüzden malzeme tam alınır, ocak servis saatine göre yanar, çöpe giden azalır.',
                    ],
                    [
                        'kind' => 'heading',
                        'text' => 'Süreklilik farkı',
                    ],
                    [
                        'kind' => 'paragraph',
                        'text' => 'Restorana ayda bir gidersiniz; aynı yemeği yemeniz sorun olmaz. Burada aynı insanlar her gün yiyor. Salı çıkan yemek perşembe yine çıkarsa herkes fark eder.',
                    ],
                    [
                        'kind' => 'heading',
                        'text' => 'Kurumsal catering neleri kapsar?',
                    ],
                    [
                        'kind' => 'list',
                        'items' => [
                            'Menü planlaması ve kurum onayı',
                            'Malzeme tedariği ve depolama',
                            'Üretim (merkez mutfakta veya kurumun mutfağında)',
                            'Sıcaklık kontrollü taşıma ve teslimat',
                            'Servis düzeni ve gerektiğinde servis personeli',
                            'Öğün sayısı takibi ve raporlama',
                        ],
                    ],
                    [
                        'kind' => 'heading',
                        'text' => 'Taşıma yemek mi, yerinde üretim mi?',
                    ],
                    [
                        'kind' => 'paragraph',
                        'text' => 'İki yol var. Taşıma yemekte yemek bizim mutfakta pişer, servise hazır gelir — mutfağı olmayan yerler için. Yerinde üretimde yemek sizin mutfağınızda pişer; yol yoktur, menü esner, ama alan ve ekipman ister.',
                    ],
                    [
                        'kind' => 'callout',
                        'text' => 'Kararı çoğunlukla mutfağınızın olup olmaması veriyor. Mutfak var ama uğraşmak istemiyorsanız yerinde üretim en tazesini verir.',
                    ],
                    [
                        'kind' => 'heading',
                        'text' => 'Fiyat neden liste hâlinde verilmiyor?',
                    ],
                    [
                        'kind' => 'paragraph',
                        'text' => 'Aynı menü elli kişiye başka, beş yüz kişiye başka maliyete çıkıyor. Buna sıklık ve mesafe de eklenince tek bir liste yazmak yanıltmak oluyor.',
                    ],
                ],
            ],
            [
                'slug' => 'is-yerleri-icin-menu-planlamasi',
                'title' => 'İş yerleri için menü planlaması nasıl yapılır?',
                'description' => 'Haftalık menü nasıl kurulur: kim yiyecek, ne sıklıkla dönecek, mevsim ne diyor?',
                'category' => 'Menü',
                'published_at' => '2026-01-27',
                'reading_minutes' => 7,
                'body' => [
                    [
                        'kind' => 'paragraph',
                        'text' => '"Bu hafta ne çıkaralım?" sorusuna her pazartesi yeniden cevap aranıyorsa ortada plan yok demektir. Doğru kurulmuş bir liste hem tabakları boşaltır hem çöpü azaltır.',
                    ],
                    [
                        'kind' => 'heading',
                        'text' => 'Önce çalışan profilini tanımlayın',
                    ],
                    [
                        'kind' => 'paragraph',
                        'text' => 'Sekiz saat beton döken adamla bilgisayar başındaki insan aynı tabağı istemez. Birinde porsiyon ve kalori konuşulur, diğerinde ağır yemek öğleden sonrayı yatırır.',
                    ],
                    [
                        'kind' => 'heading',
                        'text' => 'Tekrar dengesini haftalık kurun',
                    ],
                    [
                        'kind' => 'paragraph',
                        'text' => 'İşe yarayan basit bir ölçü: haftada iki kırmızı et, iki tavuk, bir baklagil. Pilavla makarna dönüşümlü gider. Aynı ana yemek iki hafta üst üste çıkmaz.',
                    ],
                    [
                        'kind' => 'list',
                        'items' => [
                            'Aynı gün iki kuru baklagil öğünü koymayın (çorba + ana yemek).',
                            'Ağır bir ana yemeğin yanına hafif bir tamamlayıcı seçin.',
                            'Cuma günlerine daha çok tercih edilen yemekleri koymak katılımı artırır.',
                            'Aynı pişirme yöntemini (fırın, kızartma) gün içinde tekrarlamayın.',
                        ],
                    ],
                    [
                        'kind' => 'heading',
                        'text' => 'Mevsimi gözetin',
                    ],
                    [
                        'kind' => 'paragraph',
                        'text' => 'Mevsiminde sebze hem daha lezzetli hem daha ucuz. Kışın çorba çeşidini artırın, yazın soğuk başlangıç ve ayrana yer açın.',
                    ],
                    [
                        'kind' => 'heading',
                        'text' => 'Alternatif öğünü baştan planlayın',
                    ],
                    [
                        'kind' => 'paragraph',
                        'text' => 'Vejetaryen ya da alerjisi olan biri varsa onun tabağı menü kurulurken düşünülür. Servis saatinde akla gelirse iş işten geçmiştir. Ayrı pişer, etiketlenir, mümkünse ayrı kapta gelir.',
                    ],
                    [
                        'kind' => 'heading',
                        'text' => 'Tüketimi ölçün, menüyü ona göre düzeltin',
                    ],
                    [
                        'kind' => 'paragraph',
                        'text' => 'En doğru geri bildirim tencerenin dibinde. Sürekli artan yemek listeden çıkar, çabuk biten daha sık gelir. Bunu yapmayan menü zamanla kâğıt üstünde kalır.',
                    ],
                    [
                        'kind' => 'callout',
                        'text' => 'Anket yapmadan önce artanı tartın. İnsanlar anket doldururken kibar, tabak bırakırken dürüst oluyor.',
                    ],
                ],
            ],
            [
                'slug' => 'catering-hizmetinde-hijyen',
                'title' => 'Catering hizmetinde hijyen: zincir nerede kırılır?',
                'description' => 'Sorun genelde kirli mutfaktan çıkmaz. Depoda, soğutmada ve yolda çıkar.',
                'category' => 'Kalite',
                'published_at' => '2026-01-09',
                'reading_minutes' => 6,
                'body' => [
                    [
                        'kind' => 'paragraph',
                        'text' => 'Toplu yemekte hijyen sorunu neredeyse hiç pis bir tezgâhtan çıkmaz. Depoda, soğutmada ve yolda çıkar — yani kimsenin bakmadığı yerlerde.',
                    ],
                    [
                        'kind' => 'heading',
                        'text' => 'Tehlikeli sıcaklık aralığı',
                    ],
                    [
                        'kind' => 'paragraph',
                        'text' => 'Bakterinin en hızlı ürediği bir sıcaklık aralığı var. Yemek orada ne kadar kalırsa risk o kadar büyüyor. Bu yüzden sıcak sıcakta, soğuk soğukta durur; arada geçen süre elden geldiğince kısaltılır.',
                    ],
                    [
                        'kind' => 'callout',
                        'text' => 'Sabah pişip öğlene kadar bekleyen yemek, on birde pişip on ikide servis edilenden her zaman daha risklidir. Ocağın saatini servis saati belirler.',
                    ],
                    [
                        'kind' => 'heading',
                        'text' => 'Çapraz bulaşma',
                    ],
                    [
                        'kind' => 'paragraph',
                        'text' => 'Çiğ tavuğun doğrandığı tahtada salata doğramak, kitaptaki ilk örnektir. Çözümü kolay, sürdürmesi disiplin ister: ayrı tezgâh, ayrı tahta, ayrı bıçak.',
                    ],
                    [
                        'kind' => 'paragraph',
                        'text' => 'Alerjende de aynı kural. Glutensiz yemek, unlu tezgâhta hazırlandıysa artık glutensiz değildir.',
                    ],
                    [
                        'kind' => 'heading',
                        'text' => 'Depolama sırası',
                    ],
                    [
                        'kind' => 'list',
                        'items' => [
                            'Kuru gıda, soğuk ürün ve dondurulmuş ürün ayrı alanlarda saklanır.',
                            'Önce giren ürün önce kullanılır; giriş tarihi ürün üzerinde görünür olmalıdır.',
                            'Çiğ ürünler, pişmiş ürünlerin altındaki raflarda tutulur (damlama riski).',
                            'Açılmış ürün kapatılır ve açılış tarihi işaretlenir.',
                        ],
                    ],
                    [
                        'kind' => 'heading',
                        'text' => 'Taşıma: en çok gözden kaçan halka',
                    ],
                    [
                        'kind' => 'paragraph',
                        'text' => 'Mutfakta her şey kitabına uygun gitse bile, yalıtımsız bir kapla çıkılan uzun yol zinciri kırar. Isı tutan kapalı kap, çıkışta ve varışta sıcaklık ölçümü, teslim kaydı — üçü de işin parçası.',
                    ],
                    [
                        'kind' => 'heading',
                        'text' => 'İzlenebilirlik neden önemli?',
                    ],
                    [
                        'kind' => 'paragraph',
                        'text' => 'Bir sorun çıktığında hangi gün, hangi menü, hangi tedarikçi ve nereye — dördünün cevabı kayıtta yoksa kaynağı bulamazsınız. Kayıt sorunu önlemez; tekrarını önler.',
                    ],
                ],
            ],
            [
                'slug' => 'organizasyon-menusu-nasil-secilir',
                'title' => 'Organizasyon menüsü nasıl seçilir?',
                'description' => 'Menüyü katalogdan değil, günün akışından seçersiniz: saat kaç, kaç kişi, mekân ne veriyor?',
                'category' => 'Organizasyon',
                'published_at' => '2025-12-12',
                'reading_minutes' => 5,
                'body' => [
                    [
                        'kind' => 'paragraph',
                        'text' => 'Organizasyon menüsü katalogdan seçilmez, günün akışına göre kurulur. Öğle açılışında tam yerinde olan bir liste, akşam düğününde cılız kalır.',
                    ],
                    [
                        'kind' => 'heading',
                        'text' => 'Etkinliğin saati menüyü belirler',
                    ],
                    [
                        'kind' => 'paragraph',
                        'text' => 'Öğle açılışında insanlar yarım saat durur; elde yenen şeyler işe yarar. Akşam davetinde oturulur, sofra uzun kurulur.',
                    ],
                    [
                        'kind' => 'heading',
                        'text' => 'Servis biçimini erken kararlaştırın',
                    ],
                    [
                        'kind' => 'list',
                        'items' => [
                            'Açık büfe: davetli sayısı yüksekken hızlıdır, alan gerektirir.',
                            'Masaya servis: daha düzenli görünür, servis personeli ihtiyacını artırır.',
                            'Kokteyl düzeni: ayakta dolaşımı destekler, ana yemek yerine küçük porsiyonlara dayanır.',
                        ],
                    ],
                    [
                        'kind' => 'paragraph',
                        'text' => 'Servis biçimi görüntüyle ilgili bir tercih gibi görünür ama asıl belirleyeni mekânın metrekaresi, davetli sayısı ve programın uzunluğudur.',
                    ],
                    [
                        'kind' => 'heading',
                        'text' => 'Mekânın imkânlarını baştan öğrenin',
                    ],
                    [
                        'kind' => 'paragraph',
                        'text' => 'Mutfak var mı, priz nerede, su nereden geliyor, servis alanıyla masalar arası kaç adım? Bunlar menüyü doğrudan değiştirir — son hazırlığı yerinde yapılan yemekler ancak altyapı varsa listeye girer.',
                    ],
                    [
                        'kind' => 'heading',
                        'text' => 'Davetli profilini gözetin',
                    ],
                    [
                        'kind' => 'paragraph',
                        'text' => 'Kaç çocuk var, yaş ortalaması ne, özel beslenen kaç kişi? Vejetaryen ve alerjen alternatifi davetli listesiyle birlikte planlanır. O gün akla gelirse çözülmez.',
                    ],
                    [
                        'kind' => 'callout',
                        'text' => 'Davetli sayısına biraz pay bırakın. Son dakika gelen misafir her davette çıkıyor.',
                    ],
                ],
            ],
            [
                'slug' => 'kalabalik-etkinliklerde-yemek-planlamasi',
                'title' => 'Kalabalık etkinliklerde yemek planlaması',
                'description' => 'Uzun kuyruk ve soğumuş yemek menüden değil, servis düzeninden çıkar. Kalabalıkta işleyen yöntemler.',
                'category' => 'Organizasyon',
                'published_at' => '2025-11-20',
                'reading_minutes' => 6,
                'body' => [
                    [
                        'kind' => 'paragraph',
                        'text' => 'Kalabalıkta yemeğin tadı kadar sıranın hızı da konuşuluyor. Uzayan kuyruk, soğumuş tabak ve sarkan program genelde menüden değil, servis düzeninden çıkıyor.',
                    ],
                    [
                        'kind' => 'heading',
                        'text' => 'Kuyruğu paralelleştirin',
                    ],
                    [
                        'kind' => 'paragraph',
                        'text' => 'Tek büfe hattı kalabalıkta tıkanır. Aynı menüyü veren ikinci hat, sırayı ikiye böler. Hattın iki tarafından da alınabiliyorsa kapasite bir kat daha artar.',
                    ],
                    [
                        'kind' => 'heading',
                        'text' => 'Sıcaklığı dalgalar hâlinde koruyun',
                    ],
                    [
                        'kind' => 'paragraph',
                        'text' => 'Bütün yemeği başta ortaya çıkarırsanız sıranın sonundaki soğuk yemek alır. Onun yerine büfe belirli aralıklarla tazelenir; yemek dalga dalga çıkar.',
                    ],
                    [
                        'kind' => 'heading',
                        'text' => 'Programla senkron çalışın',
                    ],
                    [
                        'kind' => 'list',
                        'items' => [
                            'Konuşma ve sunum saatlerini önceden alın; servisi araya değil, aranın başına kurun.',
                            'Ara süresini gerçekçi belirleyin: 200 kişilik bir grup 15 dakikada yemek yiyemez.',
                            'İçecek noktalarını yemek hattından ayırın; kuyruk hızını en çok bu düşürür.',
                            'Toplama işlemini program devam ederken sessizce yürütecek şekilde planlayın.',
                        ],
                    ],
                    [
                        'kind' => 'heading',
                        'text' => 'Menüyü servis hızına göre seçin',
                    ],
                    [
                        'kind' => 'paragraph',
                        'text' => 'Tabağa koyması uzun süren yemek sırayı uzatır. Önceden porsiyonlanan ya da tek kaşıkta alınan şeyler tercih edilir. Gösterişli ama yavaş kaplar ana hattan çıkarılıp ayrı bir istasyona alınabilir.',
                    ],
                    [
                        'kind' => 'callout',
                        'text' => 'En sık yapılan hata, menüyü küçük bir davet gibi kurup servisi sonra düşünmek. Sıra tersine dönmeli: önce insanlar nasıl akacak, sonra o akışa uyan menü.',
                    ],
                ],
            ],
        ];
    }
}
