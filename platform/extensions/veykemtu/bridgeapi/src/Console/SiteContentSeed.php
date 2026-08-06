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
            // Şirket ailesi bağı: site bir eğitim şirketi gibi görünmemeli,
            // bu yüzden yalnızca Kurumsal sayfasında ve altbilgide geçer.
            'parent_group' => 'Benim Başarı Dünyam',
            'tagline' => 'Kalabalık sofralar için planlı, hijyenik ve lezzetli catering çözümleri.',
            'description' => 'Kurumlara, okullara, sağlık kuruluşlarına ve organizasyonlara toplu yemek ve catering hizmeti.',
            /*
             * Kurumsal logo dosyası repoda YOK. Elimizdeki tek görsel uygulama
             * simgesi olarak üretilmiş genel bir servis kapağı. Logoyu yeniden
             * çizmek marka kimliğini uydurmak olurdu; site alan boşken "BLD"
             * harf işaretine düşer. Yönetici dosyayı panelden yükler.
             */
            'logo_url' => null,
            // Sitenin bugün kullandığı birincil renk
            // (`website/app/globals.css` → `--color-brand-700`). Uydurulmuş
            // değil, yayındaki değerin kendisi; beyaz yazıyla 5,18:1 veriyor
            // ve `BrandGuard` eşiğini (4,5:1) geçiyor.
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
            // "Nasıl çalışıyoruz" — ilk temastan düzenli hizmete kadar.
            'process_steps' => [
                [
                    'title' => 'İhtiyacı dinliyoruz',
                    'body' => 'Kişi sayısı, öğün saatleri, hizmet konumu ve varsa mevcut mutfak altyapınızı konuşuyoruz.',
                    'icon' => 'MessageSquare',
                ],
                [
                    'title' => 'Menü ve teklif hazırlıyoruz',
                    'body' => 'İhtiyacınıza uygun menü kurgusu ve fiyatlandırma çıkarılıyor; gerekirse tadım planlanıyor.',
                    'icon' => 'ClipboardList',
                ],
                [
                    'title' => 'Planı sabitliyoruz',
                    'body' => 'Teslimat saatleri, servis düzeni ve haftalık menü onayınızla kesinleşiyor.',
                    'icon' => 'CalendarCheck',
                ],
                [
                    'title' => 'Üretip teslim ediyoruz',
                    'body' => 'Öğünler planlanan saatte hazırlanıp sıcaklık kontrollü biçimde teslim ediliyor.',
                    'icon' => 'Truck',
                ],
                [
                    'title' => 'Takip edip düzeltiyoruz',
                    'body' => 'Tüketim ve geri bildirim izleniyor; menü ve porsiyonlar buna göre güncelleniyor.',
                    'icon' => 'Sparkles',
                ],
            ],
            // "Neden BLD?" — vaat değil, çalışma biçimi.
            'differentiators' => [
                [
                    'title' => 'Menü planı önceden belli',
                    'body' => 'Haftalık menü önden paylaşılır. Ne çıkacağını sabahında öğrenmezsiniz; planlama yapabilirsiniz.',
                    'icon' => 'ClipboardList',
                ],
                [
                    'title' => 'Tek muhatap',
                    'body' => 'Sipariş, teslimat, menü değişikliği ve faturalama tek kişiyle yürür. Sorun için sıraya girmezsiniz.',
                    'icon' => 'HandshakeIcon',
                ],
                [
                    'title' => 'Değişken sayıya uyum',
                    'body' => 'Personel sayısı gün gün değişen iş yerlerinde öğün adedi günlük olarak güncellenir.',
                    'icon' => 'UsersRound',
                ],
                [
                    'title' => 'Yemek yemek gibi',
                    'body' => 'Toplu üretimde de tarif ve porsiyon disiplini korunur. Menü, insanların gerçekten yediği yemeklerden kurulur.',
                    'icon' => 'Soup',
                ],
            ],
            'mission' => 'Kalabalık için yemek üretmenin, evdeki özenden ödün vermeyi gerektirmediğini göstermek. Her öğünü, servis edeceğimiz insanların masasına kendi masamıza koyar gibi hazırlamak.',
            'vision' => 'Yerel bağını koruyan, ulusal ölçekte kurumlara hizmet verebilecek düzende çalışan; planlaması, hijyeni ve lezzetiyle tercih edilen bir catering markası olmak.',
            'values' => [
                [
                    'title' => 'Söz verdiğimiz saatte',
                    'body' => 'Yemeğin lezzeti kadar zamanında gelmesi de hizmetin parçasıdır. Teslim saati taahhüttür.',
                ],
                [
                    'title' => 'Hijyen tartışma konusu değil',
                    'body' => 'Temizlik, işler sıkıştığında esnetilen bir başlık değil; üretim akışının kendisidir.',
                ],
                [
                    'title' => 'Abartmadan konuşmak',
                    'body' => 'Yapabileceğimizi söyler, yapamayacağımıza hayır deriz. Beklentiyi baştan doğru kurmak sonradan özür dilemekten iyidir.',
                ],
                [
                    'title' => 'İnsan önce gelir',
                    'body' => 'Servis ettiğimiz kişi de, mutfakta çalışan ekip de aynı özeni hak eder.',
                ],
            ],
            'group_relation' => 'Benim Lezzet Dünyam, Benim Başarı Dünyam şirket ailesinin yemek ve catering markasıdır. Aynı kurumsal disiplinle çalışır; kendi alanında bağımsız bir yapı olarak yönetilir.',
        ];
    }

    /** @return list<array<string, string>> */
    private static function faq(): array
    {
        return [
            [
                'question' => 'Minimum kaç kişilik hizmet veriyorsunuz?',
                'answer' => 'Alt sınır hizmet türüne göre değişir. Düzenli kurumsal yemekte ve tek seferlik organizasyonlarda ölçek farklıdır; kişi sayınızı ilettiğinizde uygun olup olmadığını net biçimde söylüyoruz.',
            ],
            [
                'question' => 'Menüyü biz mi seçiyoruz, siz mi hazırlıyorsunuz?',
                'answer' => 'İkisi de mümkün. Genellikle ihtiyacınıza göre bir menü planı hazırlayıp onayınıza sunuyoruz; üzerinde değişiklik yapabilir, kendi menünüzü de verebilirsiniz.',
            ],
            [
                'question' => 'Vejetaryen veya alerjisi olan çalışanlarımız için ne yapılıyor?',
                'answer' => 'Ana menüye alternatif öğün planlanır, ayrı hazırlanır ve etiketlenir. Alerjen bilgisi kurumdan gelen listeye göre takip edilir; liste değiştiğinde menü planı da güncellenir.',
            ],
            [
                'question' => 'Kişi sayımız her gün değişiyor, bu sorun olur mu?',
                'answer' => 'Olmaz. Değişken sayıyla çalışan iş yerleri için günlük bildirim düzeni kuruyoruz; öğün adedi sabahtan gelen sayıya göre güncellenir.',
            ],
            [
                'question' => 'Yemek nasıl taşınıyor, sıcak geliyor mu?',
                'answer' => 'Öğünler ısı yalıtımlı kapalı kaplarda taşınır ve teslimde sıcaklık kontrol edilir. Uzun bekleme gerektiren teslimatlarda menü, taşımaya uygun yemeklerden kurulur.',
            ],
            [
                'question' => 'Servis malzemesi ve personeli siz mi sağlıyorsunuz?',
                'answer' => 'Hizmet türüne göre değişir. Taşıma yemekte servise hazır teslim yapılır; yerinde üretim ve organizasyon catering hizmetlerinde servis ekibi ve ekipman kurulumu dâhil planlanabilir.',
            ],
            [
                'question' => 'Fiyatları neden sitede göremiyorum?',
                'answer' => 'Catering fiyatı kişi sayısı, öğün sayısı, hizmet sıklığı ve konuma göre değişiyor. Sabit bir liste vermek yanıltıcı olurdu; ihtiyacınızı ilettiğinizde size özel teklif hazırlıyoruz.',
            ],
            [
                'question' => 'Sözleşme süresi ne kadar olmak zorunda?',
                'answer' => 'Zorunlu bir alt süre dayatmıyoruz. Düzenli hizmetlerde genellikle dönemsel bir çerçeve tercih ediliyor; tek seferlik organizasyonlar için sözleşme etkinliğe özel hazırlanıyor.',
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
                'need' => 'Vardiya saatlerine dakikası dakikasına uyan, ağır işe yetecek öğünler.',
                'answer' => 'Teslimat vardiya değişimine kilitlenir; menü kalori ihtiyacına göre kurulur ve personel sayısındaki dalgalanma günlük olarak güncellenir.',
                'service_slug' => 'kurumsal-toplu-yemek',
            ],
            [
                'slug' => 'egitim',
                'title' => 'Eğitim kurumları',
                'icon' => 'GraduationCap',
                'need' => 'Yaş grubuna uygun porsiyon, alerjen takibi ve velinin görebileceği menü.',
                'answer' => 'Öğün planı yaş grubuna göre ayrılır, alerjisi olan öğrenciler için alternatif hazırlanır, aylık menü paylaşıma hazır biçimde verilir.',
                'service_slug' => 'okul-yemek-hizmeti',
            ],
            [
                'slug' => 'saglik',
                'title' => 'Sağlık kuruluşları',
                'icon' => 'HeartPulse',
                'need' => 'Hasta diyetleriyle personel öğünlerinin birbirine karışmaması.',
                'answer' => 'Diyet öğünleri ayrı akışta üretilir ve hasta bazlı etiketlenir; personel menüsü vardiyaya göre ayrı planlanır.',
                'service_slug' => 'saglik-kuruluslari',
            ],
            [
                'slug' => 'kamu',
                'title' => 'Kamu kurumları',
                'icon' => 'Landmark',
                'need' => 'Şartnameye uygun, belgelenebilir ve düzenli bir hizmet akışı.',
                'answer' => 'Menü planı, teslimat kayıtları ve öğün sayıları raporlanabilir biçimde tutulur; hizmet şartname koşullarına göre kurgulanır.',
                'service_slug' => 'tasima-yemek',
            ],
            [
                'slug' => 'ofis',
                'title' => 'Kurumsal ofisler',
                'icon' => 'Building',
                'need' => 'Mutfak kurmadan, çalışanı memnun eden düzenli bir öğün çözümü.',
                'answer' => 'Yemek merkez mutfakta hazırlanıp servise hazır teslim edilir; ofiste yalnızca servis alanı yeterlidir.',
                'service_slug' => 'tasima-yemek',
            ],
            [
                'slug' => 'insaat',
                'title' => 'İnşaat ve saha',
                'icon' => 'TrafficCone',
                'need' => 'Ulaşımı zor sahalara, değişken personel sayısıyla teslimat.',
                'answer' => 'Saha koşullarına göre teslimat planlanır, günlük öğün adedi sahadan gelen sayıya göre güncellenir.',
                'service_slug' => 'santiye-yemek',
            ],
            [
                'slug' => 'organizasyon',
                'title' => 'Organizasyon ve etkinlik',
                'icon' => 'PartyPopper',
                'need' => 'Tek seferlik ama hatasız olması gereken bir servis düzeni.',
                'answer' => 'Menü, kurulum, servis ekibi ve toplama tek pakette planlanır; davetli sayısındaki değişiklik için pay bırakılır.',
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
                    'summary' => 'Çorba, ana yemek, yardımcı yemek ve tatlı/salata düzeniyle klasik öğle menüsü.',
                    'audience' => 'Ofis, fabrika ve kurumsal yemekhaneler',
                    'courses' => [
                        ['label' => 'Çorba', 'examples' => 'Mercimek çorbası, Ezogelin, Yayla çorbası'],
                        ['label' => 'Ana yemek', 'examples' => 'Etli kuru fasulye, Tavuk sote, Fırın tavuk but, Etli türlü'],
                        ['label' => 'Yardımcı yemek', 'examples' => 'Pirinç pilavı, Bulgur pilavı, Makarna'],
                        ['label' => 'Tamamlayıcı', 'examples' => 'Mevsim salata, Cacık, Ayran, Mevsim meyvesi'],
                    ],
                    'principle' => 'Haftalık menüde aynı ana yemek tekrar etmez; et, tavuk ve baklagil öğünleri dengeli dağıtılır.',
                ],
                [
                    'slug' => 'personel-uc-kap',
                    'title' => 'Personel üç kap',
                    'summary' => 'Daha kısa öğün molalarına uygun, hızlı servis edilebilen düzen.',
                    'audience' => 'Vardiyalı çalışan üretim tesisleri ve saha ekipleri',
                    'courses' => [
                        ['label' => 'Çorba', 'examples' => 'Mercimek çorbası, Tarhana'],
                        ['label' => 'Ana yemek', 'examples' => 'Etli nohut, Köfte, Tavuk haşlama'],
                        ['label' => 'Tamamlayıcı', 'examples' => 'Pilav, Ekmek, Ayran'],
                    ],
                    'principle' => 'Servis hızı önceliklidir: porsiyonlama kolay, sıcak kalma süresi uzun yemekler seçilir.',
                ],
                [
                    'slug' => 'ogrenci-menusu',
                    'title' => 'Öğrenci menüsü',
                    'summary' => 'Yaş grubuna göre porsiyonlanmış, alerjen bilgisi işaretlenmiş öğünler.',
                    'audience' => 'Anaokulu, ilkokul, ortaokul ve liseler',
                    'courses' => [
                        ['label' => 'Çorba veya başlangıç', 'examples' => 'Sebze çorbası, Şehriye çorbası'],
                        ['label' => 'Ana yemek', 'examples' => 'Fırın makarna, Köfte, Sebzeli tavuk'],
                        ['label' => 'Tamamlayıcı', 'examples' => 'Pilav, Yoğurt, Meyve'],
                        ['label' => 'İkindi ikramı', 'examples' => 'Süt, Kek, Kuru meyve'],
                    ],
                    'principle' => 'Çocukların gerçekten tükettiği biçimler tercih edilir; ağır baharat ve sos kullanılmaz.',
                ],
                [
                    'slug' => 'kahvalti-ikram',
                    'title' => 'Kahvaltı ve ikram paketleri',
                    'summary' => 'Toplantı, eğitim ve etkinlikler için kurulumu hızlı ikram düzenleri.',
                    'audience' => 'Toplantı, seminer, eğitim ve lansmanlar',
                    'courses' => [
                        ['label' => 'Açık büfe kahvaltı', 'examples' => 'Peynir çeşitleri, Zeytin, Yumurta, Reçel'],
                        ['label' => 'Fırın ürünleri', 'examples' => 'Poğaça, Açma, Simit, Börek'],
                        ['label' => 'Ara ikram', 'examples' => 'Kurabiye, Meyve tabağı, Kuruyemiş'],
                        ['label' => 'İçecek', 'examples' => 'Çay, Filtre kahve, Meyve suyu'],
                    ],
                    'principle' => 'Elde tüketilebilen, servis gerektirmeyen seçenekler öne alınır.',
                ],
                [
                    'slug' => 'davet-menusu',
                    'title' => 'Davet menüsü',
                    'summary' => 'Düğün, açılış ve kurumsal davetler için kapsamlı servis menüsü.',
                    'audience' => 'Düğün, nişan, açılış ve kurumsal davetler',
                    'courses' => [
                        ['label' => 'Karşılama', 'examples' => 'Soğuk mezeler, Kanepe, Limonata'],
                        ['label' => 'Başlangıç', 'examples' => 'Çorba, Soğuk başlangıç tabağı'],
                        ['label' => 'Ana yemek', 'examples' => 'Fırın et, Tavuk şiş, Sebzeli et sote'],
                        ['label' => 'Tamamlayıcı', 'examples' => 'Pilav, Salata, Sıcak börek'],
                        ['label' => 'Tatlı', 'examples' => 'Sütlü tatlı, Şerbetli tatlı, Meyve'],
                    ],
                    'principle' => 'Menü etkinliğin saatine göre kurulur; öğle davetinde daha hafif, akşam davetinde daha kapsamlı bir akış tercih edilir.',
                ],
                [
                    'slug' => 'ozel-beslenme',
                    'title' => 'Vejetaryen ve özel beslenme',
                    'summary' => 'Ana menüye alternatif olarak planlanan özel ihtiyaç öğünleri.',
                    'audience' => 'Vejetaryen, alerjisi olan veya özel diyet uygulayan katılımcılar',
                    'courses' => [
                        ['label' => 'Ana yemek', 'examples' => 'Sebzeli güveç, Nohutlu bulgur pilavı, Mercimek köfte'],
                        ['label' => 'Tamamlayıcı', 'examples' => 'Yeşil salata, Humus, Yoğurt (istenirse)'],
                        ['label' => 'Alerjen yönetimi', 'examples' => 'Glutensiz seçenek, Laktozsuz seçenek'],
                    ],
                    'principle' => 'Özel öğün ana menüden ayrı hazırlanır ve etiketlenir; çapraz bulaşma riskini azaltmak için ayrı kaplarda taşınır.',
                ],
            ],
            'seasonal' => [
                ['season' => 'İlkbahar', 'note' => 'Taze sebze öğünleri ve yeşillik ağırlıklı salatalar öne alınır.'],
                ['season' => 'Yaz', 'note' => 'Hafif öğünler, soğuk başlangıçlar ve ayran/limonata tüketimi artar.'],
                ['season' => 'Sonbahar', 'note' => 'Baklagil ve kök sebze yemekleri menüde ağırlık kazanır.'],
                ['season' => 'Kış', 'note' => 'Çorba çeşidi artırılır; doyurucu ve sıcak tutan öğünler öne çıkar.'],
            ],
        ];
    }

    /** @return array<string, mixed> */
    private static function quality(): array
    {
        return [
            // Hammadde girişinden teslimata kadar zincir — sıralı okunacak.
            'chain' => [
                [
                    'title' => 'Hammadde seçimi',
                    'body' => 'Malzeme, düzenli çalışılan tedarikçilerden alınır. Girişte görsel kontrol yapılır; uygun bulunmayan ürün kabul edilmez.',
                    'icon' => 'Sprout',
                ],
                [
                    'title' => 'Depolama koşulları',
                    'body' => 'Kuru gıda, soğuk ve dondurulmuş ürünler ayrı alanlarda saklanır. Ürünler giriş tarihine göre sıraya konur; önce giren önce kullanılır.',
                    'icon' => 'Refrigerator',
                ],
                [
                    'title' => 'Mutfak hijyeni',
                    'body' => 'Hazırlık yüzeyleri ve ekipman, kullanım öncesi ve sonrası temizlenir. Çiğ ve pişmiş ürün için ayrı hazırlık alanı ve ekipman kullanılır.',
                    'icon' => 'UtensilsCrossed',
                ],
                [
                    'title' => 'Personel hijyeni',
                    'body' => 'Mutfak ekibi bone, maske ve iş kıyafetiyle çalışır. El hijyeni kuralları üretim akışının bir parçası olarak uygulanır.',
                    'icon' => 'ShieldCheck',
                ],
                [
                    'title' => 'Üretim ve pişirme',
                    'body' => 'Öğünler servis saatine göre planlanan zamanda pişirilir. Uzun süre bekleyecek biçimde erken üretim yapılmaz.',
                    'icon' => 'ClipboardCheck',
                ],
                [
                    'title' => 'Sıcaklık kontrolü',
                    'body' => 'Sıcak yemek sıcak, soğuk ürün soğuk zincirde tutulur. Sıcaklık, sevkiyat öncesi ve teslimde kontrol edilir.',
                    'icon' => 'ThermometerSnowflake',
                ],
                [
                    'title' => 'Taşıma ve teslimat',
                    'body' => 'Yemek, ısı yalıtımlı kapalı kaplarla taşınır. Teslim edilen öğün, sayı ve saat bilgisiyle kayda geçer.',
                    'icon' => 'Truck',
                ],
                [
                    'title' => 'İzlenebilirlik',
                    'body' => 'Hangi gün hangi menünün üretildiği ve nereye teslim edildiği kayıt altındadır. Geriye dönük inceleme gerektiğinde bu kayıtlar kullanılır.',
                    'icon' => 'PackageCheck',
                ],
            ],
            /*
             * Alerjen yönetimi ayrı bölüm: sorumluluk kurumla paylaşılıyor.
             *
             * Satırlar düz metin değil `{text: ...}`: paneldeki tekrarlayıcı
             * her satırı `text` alanlı bir kayıt olarak yazıyor. Düz dizi
             * seedlersek yönetici ilk kaydetmede maddelerin biçim değiştirdiğini
             * görürdü.
             */
            'allergen' => [
                ['text' => 'Menüdeki öğünlerin içerdiği bilinen alerjenler kurumla paylaşılır.'],
                ['text' => 'Alerjisi olan kişiler için alternatif öğün ayrı hazırlanır ve etiketlenir.'],
                ['text' => 'Özel öğünler, çapraz bulaşma riskini azaltmak için ayrı kaplarda taşınır.'],
                ['text' => 'Alerjen listesi kurumdan gelen bilgiye dayanır; liste güncellendiğinde menü planı da güncellenir.'],
            ],
            /*
             * BOŞ BIRAKILDI — repoda BLD adına düzenlenmiş ISO, HACCP, TSE veya
             * gıda üretim izni belgesi yok. Sahip olunmayan bir belgeyi varmış
             * gibi göstermek gıda sektöründe yaptırımı olan bir beyandır. Firma
             * belge bilgisini verdiğinde panelden eklenir ve Kalite sayfasındaki
             * sertifika bölümü kendiliğinden görünür.
             */
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
                'summary' => 'Ofis, fabrika ve iş yerleri için her gün tekrarlayan öğün hizmeti.',
                'intro' => 'Çalışanlarınızın öğle ve akşam öğünlerini, iş temponuzu aksatmayacak bir düzende planlıyoruz. Menü haftalık olarak önceden paylaşılır, üretim ve teslimat saatleri vardiyanıza göre belirlenir.',
                'icon' => 'Building2',
                'audience' => [
                    'Beyaz ve mavi yaka çalışanı olan iş yerleri',
                    'Vardiyalı çalışan üretim tesisleri',
                    'Yemekhanesi olan veya olmayan ofisler',
                    'Personeline düzenli öğün sağlamak isteyen kurumlar',
                ],
                'how_it_works' => [
                    [
                        'title' => 'İhtiyaç görüşmesi',
                        'body' => 'Günlük kişi sayısı, öğün saatleri, vardiya düzeni ve varsa mevcut yemekhane altyapınız konuşulur.',
                    ],
                    [
                        'title' => 'Menü planı',
                        'body' => 'Haftalık veya aylık menü hazırlanır. Mevsim, tekrar dengesi ve besin çeşitliliği gözetilir; onayınıza sunulur.',
                    ],
                    [
                        'title' => 'Üretim ve teslimat',
                        'body' => 'Öğünler merkez mutfakta hazırlanır, sıcaklık kontrollü kaplarda belirlenen saatte teslim edilir.',
                    ],
                    [
                        'title' => 'Servis ve geri bildirim',
                        'body' => 'Servis düzeni kurulur, artan-eksilen takip edilir ve menü geri bildirime göre güncellenir.',
                    ],
                ],
                'benefits' => [
                    'Mutfak kurma ve personel istihdam etme yükü ortadan kalkar',
                    'Öğün maliyeti öngörülebilir hâle gelir',
                    'Menü tekrarı ve besin dengesi takip edilir',
                    'Tek muhatapla çalışırsınız; sipariş, teslimat ve faturalama tek akışta ilerler',
                ],
                'menu_planning' => 'Menü, çalışan profilinize göre kurgulanır. Ağır iş kolunda kalori ihtiyacı yüksek öğünler, ofis ortamında daha hafif seçenekler öne alınır. Vejetaryen ve özel beslenme ihtiyaçları için alternatif kap eklenebilir.',
                'quote_needs' => [
                    'Günlük ortalama kişi sayısı',
                    'Öğün türü ve saatleri (öğle, akşam, vardiya arası)',
                    'Hizmet konumu',
                    'Haftalık hizmet günü sayısı',
                ],
            ],
            [
                'slug' => 'tasima-yemek',
                'title' => 'Taşıma yemek',
                'summary' => 'Merkez mutfakta üretim, sıcaklık kontrollü kaplarda yerinde teslim.',
                'intro' => 'Kendi mutfağı bulunmayan veya mutfağını işletmek istemeyen kurumlar için yemek merkez mutfağımızda hazırlanır ve servise hazır biçimde adresinize ulaştırılır.',
                'icon' => 'Truck',
                'audience' => [
                    'Mutfak altyapısı olmayan iş yerleri',
                    'Küçük ve orta ölçekli ofisler',
                    'Geçici veya proje bazlı çalışma alanları',
                    'Yemekhanesi yalnızca servis alanı olan kurumlar',
                ],
                'how_it_works' => [
                    [
                        'title' => 'Sipariş ve planlama',
                        'body' => 'Günlük kişi sayısı ve teslim saati belirlenir; menü önceden paylaşılır.',
                    ],
                    [
                        'title' => 'Merkez mutfakta üretim',
                        'body' => 'Öğünler teslim saatine göre planlanan üretim akışıyla hazırlanır.',
                    ],
                    [
                        'title' => 'Sıcaklık kontrollü taşıma',
                        'body' => 'Yemek, sıcak ve soğuk zinciri koruyan kaplarla taşınır; teslimde sıcaklık kontrol edilir.',
                    ],
                    [
                        'title' => 'Servise hazır teslim',
                        'body' => 'Öğünler servis alanınıza kurulur veya kapalı kaplarda teslim edilir.',
                    ],
                ],
                'benefits' => [
                    'Mutfak yatırımı ve işletme gideri gerekmez',
                    'Servis alanı dışında yer ayırmanız gerekmez',
                    'Kişi sayısı değişken olduğunda hızlı uyarlanır',
                    'Teslimat saati iş akışınıza göre sabitlenir',
                ],
                'menu_planning' => 'Taşımaya uygun yemekler öne alınır: uzun süre sıcak kalabilen, taşıma sırasında yapısı bozulmayan seçenekler. Kızartma gibi çabuk yumuşayan kaplar teslim saatine yakın planlanır.',
                'quote_needs' => [
                    'Günlük kişi sayısı',
                    'Teslim adresi ve teslim saati',
                    'Kap sayısı tercihi (üç kap, dört kap)',
                    'Servis malzemesi ihtiyacınız olup olmadığı',
                ],
            ],
            [
                'slug' => 'yerinde-uretim',
                'title' => 'Yerinde üretim',
                'summary' => 'Kurumun kendi mutfağında, bizim ekibimizle günlük üretim.',
                'intro' => 'Mutfak altyapısı bulunan kurumlarda üretimi yerinde yapıyoruz. Yemek servis edileceği yerde pişer; taşıma süresi ortadan kalkar, tazelik en üst düzeyde kalır.',
                'icon' => 'ChefHat',
                'audience' => [
                    'Kendi mutfağı olan fabrika ve kampüsler',
                    'Yemekhane işletmesini dışarıya vermek isteyen kurumlar',
                    'Yüksek kişi sayısına düzenli hizmet veren tesisler',
                    'Kahvaltı, öğle ve akşam öğünlerini aynı yerde veren kuruluşlar',
                ],
                'how_it_works' => [
                    [
                        'title' => 'Mutfak değerlendirmesi',
                        'body' => 'Mevcut ekipman, depolama alanı, havalandırma ve personel ihtiyacı yerinde incelenir.',
                    ],
                    [
                        'title' => 'Ekip ve düzen kurulumu',
                        'body' => 'Aşçı ve servis ekibi görevlendirilir, üretim akışı ve hijyen düzeni kurulur.',
                    ],
                    [
                        'title' => 'Günlük üretim',
                        'body' => 'Malzeme tedariği bize aittir; öğünler servis saatine göre yerinde hazırlanır.',
                    ],
                    [
                        'title' => 'Servis ve raporlama',
                        'body' => 'Servis yürütülür, tüketim ve stok takibi düzenli olarak paylaşılır.',
                    ],
                ],
                'benefits' => [
                    'Yemek servis edildiği yerde pişer, taşıma kaybı olmaz',
                    'Menü gün içinde ihtiyaca göre esnetilebilir',
                    'Mutfak personeli yönetimi sizin üzerinizden kalkar',
                    'Tedarik, hijyen ve servis tek elden yürütülür',
                ],
                'menu_planning' => 'Yerinde üretimde menü esnekliği en yüksek seviyededir. Günlük taze pişirme, açık büfe düzeni ve talebe göre porsiyon ayarı mümkündür. Menü, mutfağın ekipman kapasitesine göre planlanır.',
                'quote_needs' => [
                    'Günlük kişi sayısı ve öğün sayısı',
                    'Mutfak alanı ve mevcut ekipman bilgisi',
                    'Servis düzeni (tabldot, açık büfe)',
                    'Sözleşme süresi beklentiniz',
                ],
            ],
            [
                'slug' => 'okul-yemek-hizmeti',
                'title' => 'Okul yemek hizmeti',
                'summary' => 'Yaş grubuna göre planlanmış öğünler ve alerjen takibi.',
                'intro' => 'Okul öncesinden liseye kadar farklı yaş gruplarının beslenme ihtiyacı aynı değildir. Menüleri porsiyon, besin dengesi ve çocukların gerçekten yediği yemekler gözetilerek planlıyoruz.',
                'icon' => 'GraduationCap',
                'audience' => [
                    'Anaokulu ve kreşler',
                    'İlkokul, ortaokul ve liseler',
                    'Özel eğitim kurumları',
                    'Yurtlar ve pansiyonlar',
                ],
                'how_it_works' => [
                    [
                        'title' => 'Yaş grubu ve öğün planı',
                        'body' => 'Kahvaltı, öğle ve ikindi ikramı ihtiyacı yaş grubuna göre belirlenir.',
                    ],
                    [
                        'title' => 'Alerjen ve özel durum kaydı',
                        'body' => 'Alerjisi veya özel beslenme ihtiyacı olan öğrenciler listelenir; alternatif öğün planlanır.',
                    ],
                    [
                        'title' => 'Üretim ve teslim',
                        'body' => 'Öğünler ders saatlerine göre planlanan zamanda hazırlanır ve teslim edilir.',
                    ],
                    [
                        'title' => 'Veli bilgilendirme',
                        'body' => 'Aylık menü, kurumun tercih ettiği kanaldan velilerle paylaşılabilecek biçimde hazırlanır.',
                    ],
                ],
                'benefits' => [
                    'Menü yaş grubuna göre porsiyonlanır',
                    'Alerjen bilgisi öğrenci bazında takip edilir',
                    'Aylık menü velilerle paylaşılabilir biçimde hazırlanır',
                    'Öğün saatleri ders programına göre sabitlenir',
                ],
                'menu_planning' => 'Menüde sebze ve baklagil öğünleri, çocukların tükettiği biçimlerle sunulur. Aşırı baharat ve ağır soslardan kaçınılır. Aylık menü tekrar dengesi gözetilerek kurulur ve okul yönetiminin onayına sunulur.',
                'quote_needs' => [
                    'Öğrenci sayısı ve yaş grupları',
                    'Günlük öğün sayısı (kahvaltı, öğle, ikindi)',
                    'Alerjisi olan öğrenci sayısı',
                    'Eğitim döneminde hizmet verilecek gün sayısı',
                ],
            ],
            [
                'slug' => 'saglik-kuruluslari',
                'title' => 'Sağlık kuruluşlarına yemek hizmeti',
                'summary' => 'Hasta, personel ve refakatçi öğünlerinin ayrı planlanması.',
                'intro' => 'Sağlık kuruluşlarında tek bir menü yeterli olmaz: hasta diyetleri, personel öğünleri ve refakatçi yemekleri farklı planlanır. Üçünü ayrı akışlarda yürütecek biçimde çalışıyoruz.',
                'icon' => 'Stethoscope',
                'audience' => [
                    'Hastaneler ve tıp merkezleri',
                    'Diyaliz ve rehabilitasyon merkezleri',
                    'Huzurevleri ve bakım evleri',
                    'Poliklinik ve sağlık kampüsleri',
                ],
                'how_it_works' => [
                    [
                        'title' => 'Diyet listelerinin alınması',
                        'body' => 'Kurumun diyetisyeni tarafından belirlenen diyet tipleri ve öğün sayıları alınır.',
                    ],
                    [
                        'title' => 'Ayrı üretim akışı',
                        'body' => 'Diyet öğünleri, personel ve refakatçi öğünlerinden ayrı hazırlanır ve etiketlenir.',
                    ],
                    [
                        'title' => 'Kat ve birim dağıtımı',
                        'body' => 'Öğünler servis saatinde ilgili birime, hasta bazlı etiketiyle ulaştırılır.',
                    ],
                    [
                        'title' => 'Takip ve düzeltme',
                        'body' => 'Değişen diyet talimatları gün içinde güncellenebilecek şekilde işlenir.',
                    ],
                ],
                'benefits' => [
                    'Hasta, personel ve refakatçi öğünleri karışmaz',
                    'Diyet talimatları öğün bazında etiketlenir',
                    'Servis saatleri vizit ve tedavi düzenine göre ayarlanır',
                    'Gün içi değişikliklere uyarlanabilir bir akış kurulur',
                ],
                'menu_planning' => 'Diyet menüleri kurumun diyetisyeninin belirlediği listelere göre uygulanır; biz üretim ve teslimat tarafını yürütürüz. Personel menüsü ise vardiya saatlerine göre planlanır.',
                'quote_needs' => [
                    'Yatak kapasitesi ve ortalama doluluk',
                    'Diyet tipleri ve günlük öğün sayısı',
                    'Personel sayısı ve vardiya düzeni',
                    'Birim/kat dağıtım gereksinimi',
                ],
            ],
            [
                'slug' => 'santiye-yemek',
                'title' => 'Şantiye yemek hizmeti',
                'summary' => 'Vardiyalı çalışmaya uygun, sahada teslim edilen doyurucu öğünler.',
                'intro' => 'Şantiyede öğün saati sabit değildir ve iş ağırdır. Menüyü kalori ihtiyacına göre kuruyor, teslimatı vardiya değişimine göre planlıyoruz.',
                'icon' => 'HardHat',
                'audience' => [
                    'İnşaat şantiyeleri',
                    'Altyapı ve enerji projeleri',
                    'Maden ve saha operasyonları',
                    'Geçici işçi kampları',
                ],
                'how_it_works' => [
                    [
                        'title' => 'Saha ve vardiya bilgisi',
                        'body' => 'Şantiye konumu, ulaşım koşulları ve vardiya saatleri belirlenir.',
                    ],
                    [
                        'title' => 'Kalori odaklı menü',
                        'body' => 'Ağır işe uygun, doyurucu ve dengeli menü kurulur.',
                    ],
                    [
                        'title' => 'Sahaya teslimat',
                        'body' => 'Öğünler sıcaklık kontrollü kaplarla, vardiya değişimine yetişecek şekilde ulaştırılır.',
                    ],
                    [
                        'title' => 'Sayı takibi',
                        'body' => 'Değişken personel sayısına göre günlük öğün adedi güncellenir.',
                    ],
                ],
                'benefits' => [
                    'Vardiya saatlerine göre teslimat',
                    'Ağır iş koluna uygun kalori planlaması',
                    'Değişken personel sayısına hızlı uyum',
                    'Sahada servis düzeni kurulumu',
                ],
                'menu_planning' => 'Menüde et ve baklagil ağırlıklı, uzun süre tok tutan yemekler öne alınır. Yaz aylarında ayran ve soğuk yan ürünler, kış aylarında çorba öne çıkarılır.',
                'quote_needs' => [
                    'Şantiye konumu ve ulaşım koşulları',
                    'Vardiya sayısı ve saatleri',
                    'Ortalama günlük personel sayısı',
                    'Projenin tahmini süresi',
                ],
            ],
            [
                'slug' => 'davet-organizasyon',
                'title' => 'Davet ve organizasyon catering',
                'summary' => 'Düğün, açılış ve kurumsal etkinlikler için kurulumlu catering.',
                'intro' => 'Davetlerde yemek kadar servis düzeni de önemlidir. Menü, sunum ve servis ekibini etkinliğin akışına göre planlıyoruz.',
                'icon' => 'CalendarHeart',
                'audience' => [
                    'Düğün, nişan ve kına organizasyonları',
                    'Açılış ve tanıtım etkinlikleri',
                    'Kurumsal yemekler ve yıl sonu davetleri',
                    'Özel gün kutlamaları',
                ],
                'how_it_works' => [
                    [
                        'title' => 'Etkinlik görüşmesi',
                        'body' => 'Tarih, davetli sayısı, mekân ve servis biçimi (açık büfe, masaya servis) belirlenir.',
                    ],
                    [
                        'title' => 'Menü seçimi',
                        'body' => 'Etkinliğin saatine ve karakterine göre menü kurgulanır, tadım planlanabilir.',
                    ],
                    [
                        'title' => 'Mekân kurulumu',
                        'body' => 'Servis alanı, büfe düzeni ve ekipman etkinlikten önce kurulur.',
                    ],
                    [
                        'title' => 'Servis ve toplama',
                        'body' => 'Servis ekibi etkinlik boyunca görev alır; sonrasında alan toplanır.',
                    ],
                ],
                'benefits' => [
                    'Menü ve servis biçimi etkinliğe göre kurgulanır',
                    'Kurulum ve toplama dâhil tek paket',
                    'Davetli sayısındaki son dakika değişiklikleri için pay bırakılır',
                    'Servis ekibi etkinlik boyunca sahada kalır',
                ],
                'menu_planning' => 'Menü etkinliğin saatine göre değişir: öğle davetinde daha hafif, akşam davetinde daha kapsamlı bir kurgu tercih edilir. Vejetaryen ve alerjen alternatifleri davetli listesine göre eklenir.',
                'quote_needs' => [
                    'Etkinlik tarihi ve saati',
                    'Davetli sayısı',
                    'Mekân adresi ve mutfak/servis imkânları',
                    'Servis biçimi tercihi',
                ],
            ],
            [
                'slug' => 'toplanti-ikram',
                'title' => 'Toplantı ve etkinlik ikramları',
                'summary' => 'Kahvaltı, coffee break ve seminer ikram paketleri.',
                'intro' => 'Toplantı ve eğitimlerde ikram, programı bölmeden kurulup toplanmalıdır. Paketleri katılımcı sayısına ve program akışına göre hazırlıyoruz.',
                'icon' => 'Coffee',
                'audience' => [
                    'Kurumsal toplantı ve eğitimler',
                    'Seminer ve konferanslar',
                    'Kurul ve yönetim toplantıları',
                    'Basın toplantıları ve lansmanlar',
                ],
                'how_it_works' => [
                    [
                        'title' => 'Program akışı',
                        'body' => 'Toplantı saatleri ve ara zamanları alınır; ikram noktaları belirlenir.',
                    ],
                    [
                        'title' => 'Paket seçimi',
                        'body' => 'Kahvaltı, ara ikram veya öğle paketi arasından ihtiyaca uygun olan seçilir.',
                    ],
                    [
                        'title' => 'Kurulum',
                        'body' => 'İkram alanı program başlamadan önce hazırlanır.',
                    ],
                    [
                        'title' => 'Ara servisi',
                        'body' => 'Aralarda tazeleme yapılır, program sonunda alan toplanır.',
                    ],
                ],
                'benefits' => [
                    'İkram programı bölmeden kurulur ve toplanır',
                    'Katılımcı sayısına göre paket ölçeklenir',
                    'Sıcak ve soğuk seçenekler bir arada sunulur',
                    'Aynı gün içinde birden fazla ara desteklenir',
                ],
                'menu_planning' => 'Ara ikramlarda elde tüketilebilen, servis gerektirmeyen seçenekler öne alınır. Uzun programlarda ara menüsü tekrar etmeyecek biçimde çeşitlendirilir.',
                'quote_needs' => [
                    'Etkinlik tarihi ve program saatleri',
                    'Katılımcı sayısı',
                    'Ara sayısı ve ikram türü',
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
                'description' => 'Fiyat teklifi karşılaştırmak yetmiyor. Catering firması seçerken sorulması gereken sorular ve sözleşmeden önce netleştirilmesi gereken başlıklar.',
                'category' => 'Karar rehberi',
                'published_at' => '2026-03-04',
                'reading_minutes' => 6,
                'body' => [
                    ['kind' => 'paragraph', 'text' => 'Toplu yemek hizmeti, kurumun çalışanıyla her gün temas eden az sayıdaki hizmetten biri. Yanlış seçim, kısa sürede memnuniyetsizlik olarak geri dönüyor. Buna rağmen karar çoğu zaman yalnızca birim fiyat karşılaştırmasıyla veriliyor.'],
                    ['kind' => 'paragraph', 'text' => 'Aşağıdaki başlıklar, teklif almadan önce netleştirildiğinde hem karşılaştırmayı anlamlı kılıyor hem de sonradan çıkan sürprizleri azaltıyor.'],
                    ['kind' => 'heading', 'text' => 'Fiyatın neyi kapsadığını sorun'],
                    ['kind' => 'paragraph', 'text' => 'İki teklif arasındaki fark çoğu zaman yemeğin kendisinden değil, kapsamdan geliyor. Aynı rakam bir firmada yalnızca öğünü, diğerinde servis personelini, ekipmanı ve tek kullanımlık malzemeyi de içeriyor olabilir.'],
                    ['kind' => 'list', 'items' => [
                        'Kaç kap yemek dâhil?',
                        'Ekmek, içecek ve salata fiyata dâhil mi?',
                        'Servis personeli ve ekipman kimin sorumluluğunda?',
                        'Tek kullanımlık malzeme (tabak, çatal, peçete) kimden?',
                        'Teslimat ücreti ayrı mı hesaplanıyor?',
                    ]],
                    ['kind' => 'heading', 'text' => 'Menü planının nasıl kurulduğunu öğrenin'],
                    ['kind' => 'paragraph', 'text' => 'İyi bir menü planı tesadüf değildir. Haftalık tekrar dengesi, et-tavuk-baklagil dağılımı ve mevsim uyumu gözetilerek kurulur. Menüyü kimin hazırladığını, ne kadar önceden paylaşıldığını ve değişiklik talep edip edemeyeceğinizi sorun.'],
                    ['kind' => 'callout', 'text' => 'Menüsünü sabahında bildiren bir firmayla planlama yapamazsınız. Menünün en az bir hafta önceden paylaşılması, hem sizin hem çalışanınız için öngörülebilirlik demektir.'],
                    ['kind' => 'heading', 'text' => 'Değişken kişi sayısını nasıl yönettiğini sorun'],
                    ['kind' => 'paragraph', 'text' => 'Çoğu iş yerinde günlük personel sayısı sabit değil. İzin, vardiya ve saha görevleri sayıyı değiştiriyor. Firmanın bu değişimi nasıl karşıladığı — günlük bildirim mi alıyor, sabit sayı üzerinden mi faturalıyor — hem maliyeti hem israfı doğrudan etkiliyor.'],
                    ['kind' => 'heading', 'text' => 'Hijyen yaklaşımını somut sorularla test edin'],
                    ['kind' => 'paragraph', 'text' => 'Herkes hijyene önem verdiğini söyler. Ayırt edici olan, sürecin nasıl işlediğidir. Sıcaklık kontrolünün nerede yapıldığı, çiğ ve pişmiş ürünün ayrı alanlarda hazırlanıp hazırlanmadığı, teslim kayıtlarının tutulup tutulmadığı gibi sorular somut cevap gerektirir.'],
                    ['kind' => 'paragraph', 'text' => 'Sertifika iddiası duyduğunuzda belgeyi görmek isteyin. Belge göstermekten çekinen bir firma, muhtemelen belgeye sahip değildir.'],
                    ['kind' => 'heading', 'text' => 'Sorun çıktığında kime ulaşacağınızı netleştirin'],
                    ['kind' => 'paragraph', 'text' => 'Teslimat geciktiğinde, öğün sayısı eksik geldiğinde veya bir çalışanınız yemekten şikâyet ettiğinde kimi arayacaksınız? Tek bir muhatabınızın olması, çağrı merkezine bağlanmaktan çok daha hızlı sonuç veriyor.'],
                    ['kind' => 'heading', 'text' => 'Deneme servisi isteyin'],
                    ['kind' => 'paragraph', 'text' => 'Tadım, menünün kâğıt üzerindeki hâliyle tabaktaki hâli arasındaki farkı gösteren en pratik yöntem. Mümkünse tadımı yalnızca yöneticilerle değil, gerçekten yemek yiyecek ekiple birlikte yapın.'],
                ],
            ],
            [
                'slug' => 'kurumsal-catering-nedir',
                'title' => 'Kurumsal catering nedir, restorandan farkı ne?',
                'description' => 'Catering ile restoran işletmeciliği aynı iş değil. Kurumsal catering hizmetinin nasıl işlediği, hangi ihtiyaçlara cevap verdiği ve neyi kapsadığı.',
                'category' => 'Temel bilgiler',
                'published_at' => '2026-02-18',
                'reading_minutes' => 5,
                'body' => [
                    ['kind' => 'paragraph', 'text' => 'Catering ve restoran, dışarıdan bakınca aynı işi yapıyor görünür: ikisi de yemek üretir. Operasyon açısından ise neredeyse zıt iki modeldir.'],
                    ['kind' => 'heading', 'text' => 'Restoran talebi bekler, catering talebi bilir'],
                    ['kind' => 'paragraph', 'text' => 'Restoranda kaç kişinin geleceği ve ne söyleyeceği bilinmez; mutfak belirsizliğe göre kurulur. Kurumsal cateringde ise kişi sayısı ve menü önceden bellidir. Bu, üretimin planlanabilmesi demektir: malzeme tam miktarda alınır, pişirme servis saatine göre zamanlanır, israf azalır.'],
                    ['kind' => 'heading', 'text' => 'Süreklilik farkı'],
                    ['kind' => 'paragraph', 'text' => 'Restorana ayda bir gidersiniz, menü tekrarı sorun olmaz. Kurumsal yemekte aynı kişiler her gün yiyor. Bu yüzden catering menüsünün en kritik özelliği çeşitlilik ve tekrar dengesidir — aynı yemeğin haftada iki kez çıkması fark edilir.'],
                    ['kind' => 'heading', 'text' => 'Kurumsal catering neleri kapsar?'],
                    ['kind' => 'list', 'items' => [
                        'Menü planlaması ve kurum onayı',
                        'Malzeme tedariği ve depolama',
                        'Üretim (merkez mutfakta veya kurumun mutfağında)',
                        'Sıcaklık kontrollü taşıma ve teslimat',
                        'Servis düzeni ve gerektiğinde servis personeli',
                        'Öğün sayısı takibi ve raporlama',
                    ]],
                    ['kind' => 'heading', 'text' => 'Taşıma yemek mi, yerinde üretim mi?'],
                    ['kind' => 'paragraph', 'text' => 'İki temel model var. Taşıma yemekte üretim merkez mutfakta yapılır, öğün servise hazır gelir; mutfak altyapısı olmayan kurumlar için uygundur. Yerinde üretimde ise yemek kurumun kendi mutfağında pişer; taşıma süresi ortadan kalkar, menü esnekliği artar, ancak mutfak alanı ve ekipman gerekir.'],
                    ['kind' => 'callout', 'text' => 'Seçim genellikle mutfak altyapınızın olup olmadığıyla belirlenir. Mutfağınız varsa ama işletmek istemiyorsanız, yerinde üretim modeli hem tazelik hem esneklik açısından avantajlıdır.'],
                    ['kind' => 'heading', 'text' => 'Fiyat neden liste hâlinde verilmiyor?'],
                    ['kind' => 'paragraph', 'text' => 'Catering fiyatı kişi sayısı, öğün sayısı, hizmet sıklığı, menü kapsamı ve teslimat konumuna göre değişir. Aynı menü 50 kişiye ve 500 kişiye farklı birim maliyetle üretilir. Sabit liste vermek bu yüzden çoğu zaman yanıltıcı olur.'],
                ],
            ],
            [
                'slug' => 'is-yerleri-icin-menu-planlamasi',
                'title' => 'İş yerleri için menü planlaması nasıl yapılır?',
                'description' => 'Haftalık menü kurarken tekrar dengesi, besin çeşitliliği ve çalışan profilinin nasıl gözetildiği; işe yarayan bir menü planının kuralları.',
                'category' => 'Menü',
                'published_at' => '2026-01-27',
                'reading_minutes' => 7,
                'body' => [
                    ['kind' => 'paragraph', 'text' => 'Menü planlaması, "bu hafta ne çıkaralım" sorusuna verilen günlük cevaplardan ibaret değil. İyi kurulmuş bir plan, çalışanın memnuniyetini artırırken israfı ve maliyeti aynı anda düşürür.'],
                    ['kind' => 'heading', 'text' => 'Önce çalışan profilini tanımlayın'],
                    ['kind' => 'paragraph', 'text' => 'Ağır iş kolunda çalışan bir ekiple ofis çalışanının öğün ihtiyacı aynı değil. Fiziksel yükü yüksek işlerde kalori ve porsiyon öne çıkar; masa başı çalışmada ise ağır öğün öğleden sonra verimi düşürür.'],
                    ['kind' => 'heading', 'text' => 'Tekrar dengesini haftalık kurun'],
                    ['kind' => 'paragraph', 'text' => 'Pratik bir çerçeve: haftada iki kırmızı et, iki tavuk, bir baklagil ana yemeği. Yardımcı yemekte pilav ve makarna aynı hafta içinde dönüşümlü verilir. Aynı ana yemek iki hafta üst üste tekrar etmez.'],
                    ['kind' => 'list', 'items' => [
                        'Aynı gün iki kuru baklagil öğünü koymayın (çorba + ana yemek).',
                        'Ağır bir ana yemeğin yanına hafif bir tamamlayıcı seçin.',
                        'Cuma günlerine daha çok tercih edilen yemekleri koymak katılımı artırır.',
                        'Aynı pişirme yöntemini (fırın, kızartma) gün içinde tekrarlamayın.',
                    ]],
                    ['kind' => 'heading', 'text' => 'Mevsimi gözetin'],
                    ['kind' => 'paragraph', 'text' => 'Mevsiminde sebze hem daha lezzetli hem daha uygun maliyetlidir. Kışın çorba çeşidini artırmak, yazın soğuk başlangıç ve ayran tüketimini öne almak hem tüketimi hem memnuniyeti yükseltir.'],
                    ['kind' => 'heading', 'text' => 'Alternatif öğünü baştan planlayın'],
                    ['kind' => 'paragraph', 'text' => 'Vejetaryen çalışan veya alerjisi olan kişiler için alternatif, menü kurulurken düşünülmeli — servis anında bulunacak bir çözüm değil. Alternatif öğün ayrı hazırlanır, etiketlenir ve mümkünse ayrı kapta taşınır.'],
                    ['kind' => 'heading', 'text' => 'Tüketimi ölçün, menüyü ona göre düzeltin'],
                    ['kind' => 'paragraph', 'text' => 'Hangi yemeğin bittiğini, hangisinin arttığını takip etmek en değerli geri bildirimdir. Sürekli artan bir yemek menüden çıkar; hızla biten yemek daha sık planlanır. Bu döngü olmadan menü planı zamanla gerçeklikten kopar.'],
                    ['kind' => 'callout', 'text' => 'Anket yapmadan önce artan yemeği ölçün. İnsanlar ne yediklerini anlatmakta değil, tabakta bırakmakta çok daha dürüsttür.'],
                ],
            ],
            [
                'slug' => 'catering-hizmetinde-hijyen',
                'title' => 'Catering hizmetinde hijyen: zincir nerede kırılır?',
                'description' => 'Toplu yemekte hijyen tek bir aşamanın değil, hammaddeden teslimata uzanan bir zincirin işi. Zincirin en kırılgan halkaları ve alınması gereken önlemler.',
                'category' => 'Kalite',
                'published_at' => '2026-01-09',
                'reading_minutes' => 6,
                'body' => [
                    ['kind' => 'paragraph', 'text' => 'Toplu yemekte hijyen sorunu genellikle mutfağın kirli olmasından çıkmaz. Zincirin görece gözden kaçan halkalarında — depolamada, soğutmada ve taşımada — ortaya çıkar.'],
                    ['kind' => 'heading', 'text' => 'Tehlikeli sıcaklık aralığı'],
                    ['kind' => 'paragraph', 'text' => 'Gıda güvenliğinde en kritik kavram, bakterinin hızla çoğaldığı sıcaklık aralığıdır. Yemek bu aralıkta ne kadar uzun kalırsa risk o kadar artar. Bu yüzden sıcak yemek sıcak, soğuk ürün soğuk tutulur; ikisinin arasında geçirilen süre mümkün olduğunca kısaltılır.'],
                    ['kind' => 'callout', 'text' => 'Erken pişirilip uzun süre bekletilen yemek, geç pişirilip hemen servis edilen yemekten her zaman daha risklidir. Üretim planı bu yüzden servis saatine göre kurulur.'],
                    ['kind' => 'heading', 'text' => 'Çapraz bulaşma'],
                    ['kind' => 'paragraph', 'text' => 'Çiğ tavuğun hazırlandığı tezgâhta salata doğranması klasik örnektir. Önlemi basit ama disiplin ister: çiğ ve pişmiş ürün için ayrı hazırlık alanı, ayrı kesme tahtası ve ayrı ekipman.'],
                    ['kind' => 'paragraph', 'text' => 'Aynı ilke alerjen yönetimi için de geçerlidir. Glutensiz bir öğün, glutenli ürünle aynı yüzeyde hazırlandığında artık glutensiz değildir.'],
                    ['kind' => 'heading', 'text' => 'Depolama sırası'],
                    ['kind' => 'list', 'items' => [
                        'Kuru gıda, soğuk ürün ve dondurulmuş ürün ayrı alanlarda saklanır.',
                        'Önce giren ürün önce kullanılır; giriş tarihi ürün üzerinde görünür olmalıdır.',
                        'Çiğ ürünler, pişmiş ürünlerin altındaki raflarda tutulur (damlama riski).',
                        'Açılmış ürün kapatılır ve açılış tarihi işaretlenir.',
                    ]],
                    ['kind' => 'heading', 'text' => 'Taşıma: en çok gözden kaçan halka'],
                    ['kind' => 'paragraph', 'text' => 'Mutfakta her şey doğru yapılmış olsa bile, yalıtımsız bir kapla yapılan uzun teslimat zinciri kırar. Isı yalıtımlı kapalı kaplar, teslim öncesi ve sonrası sıcaklık kontrolü ve teslim kaydı bu yüzden hizmetin ayrılmaz parçasıdır.'],
                    ['kind' => 'heading', 'text' => 'İzlenebilirlik neden önemli?'],
                    ['kind' => 'paragraph', 'text' => 'Bir sorun yaşandığında "hangi gün, hangi menü, hangi tedarikçi, nereye teslim" sorularının cevabı kayıtlarda yoksa, sorunun kaynağı bulunamaz. İzlenebilirlik, sorun çıkmasını engellemez ama tekrarlanmasını engeller.'],
                ],
            ],
            [
                'slug' => 'organizasyon-menusu-nasil-secilir',
                'title' => 'Organizasyon menüsü nasıl seçilir?',
                'description' => 'Düğün, açılış ve kurumsal davetlerde menü seçimini belirleyen faktörler: etkinlik saati, servis biçimi, davetli profili ve mekân koşulları.',
                'category' => 'Organizasyon',
                'published_at' => '2025-12-12',
                'reading_minutes' => 5,
                'body' => [
                    ['kind' => 'paragraph', 'text' => 'Organizasyon menüsü, katalogdan seçilen bir liste değil; etkinliğin akışına göre kurulan bir plandır. Aynı menü öğle açılışında doğru, akşam düğününde eksik kalabilir.'],
                    ['kind' => 'heading', 'text' => 'Etkinliğin saati menüyü belirler'],
                    ['kind' => 'paragraph', 'text' => 'Öğle saatindeki bir açılışta davetliler genellikle kısa süre kalır; elde tüketilebilen, servis gerektirmeyen seçenekler öne çıkar. Akşam davetinde ise oturmalı servis ve daha kapsamlı bir menü beklenir.'],
                    ['kind' => 'heading', 'text' => 'Servis biçimini erken kararlaştırın'],
                    ['kind' => 'list', 'items' => [
                        'Açık büfe: davetli sayısı yüksekken hızlıdır, alan gerektirir.',
                        'Masaya servis: daha düzenli görünür, servis personeli ihtiyacını artırır.',
                        'Kokteyl düzeni: ayakta dolaşımı destekler, ana yemek yerine küçük porsiyonlara dayanır.',
                    ]],
                    ['kind' => 'paragraph', 'text' => 'Servis biçimi yalnızca estetik bir tercih değil; mekânın alanı, davetli sayısı ve etkinliğin süresiyle doğrudan bağlantılıdır.'],
                    ['kind' => 'heading', 'text' => 'Mekânın imkânlarını baştan öğrenin'],
                    ['kind' => 'paragraph', 'text' => 'Mekânda mutfak var mı, elektrik ve su erişimi yeterli mi, servis alanı ile davetli alanı arasındaki mesafe ne kadar? Bu sorular menüyü doğrudan etkiler: yerinde son hazırlık gerektiren yemekler ancak uygun altyapıda planlanabilir.'],
                    ['kind' => 'heading', 'text' => 'Davetli profilini gözetin'],
                    ['kind' => 'paragraph', 'text' => 'Yaş dağılımı, çocuklu davetli sayısı ve özel beslenme ihtiyaçları menüyü şekillendirir. Vejetaryen ve alerjen alternatifleri davetli listesine göre önceden planlanmalı; etkinlik günü çözülecek bir konu değildir.'],
                    ['kind' => 'callout', 'text' => 'Davetli sayısına küçük bir pay eklemek neredeyse her zaman doğru karardır. Son dakika katılımları organizasyonların istisnası değil, kuralıdır.'],
                ],
            ],
            [
                'slug' => 'kalabalik-etkinliklerde-yemek-planlamasi',
                'title' => 'Kalabalık etkinliklerde yemek planlaması',
                'description' => 'Yüksek katılımlı etkinliklerde servis kuyruğunu kısaltmak, sıcaklığı korumak ve zamanlamayı tutturmak için kullanılan planlama yöntemleri.',
                'category' => 'Organizasyon',
                'published_at' => '2025-11-20',
                'reading_minutes' => 6,
                'body' => [
                    ['kind' => 'paragraph', 'text' => 'Katılımcı sayısı arttıkça yemeğin lezzeti kadar servisin akışı da belirleyici hâle gelir. Uzun kuyruk, soğumuş yemek ve programın sarkması genellikle menüden değil planlamadan kaynaklanır.'],
                    ['kind' => 'heading', 'text' => 'Kuyruğu paralelleştirin'],
                    ['kind' => 'paragraph', 'text' => 'Tek bir büfe hattı, katılımcı sayısı arttığında dar boğaza dönüşür. Aynı menüyü sunan birden fazla hat kurmak, kuyruk süresini doğrudan böler. Hatların iki yönlü kullanılabilmesi kapasiteyi bir kat daha artırır.'],
                    ['kind' => 'heading', 'text' => 'Sıcaklığı dalgalar hâlinde koruyun'],
                    ['kind' => 'paragraph', 'text' => 'Tüm yemeği en başta ortaya çıkarmak, son katılımcının soğumuş yemek almasına yol açar. Bunun yerine servis, tazeleme dalgaları hâlinde planlanır: büfe belirli aralıklarla yenilenir.'],
                    ['kind' => 'heading', 'text' => 'Programla senkron çalışın'],
                    ['kind' => 'list', 'items' => [
                        'Konuşma ve sunum saatlerini önceden alın; servisi araya değil, aranın başına kurun.',
                        'Ara süresini gerçekçi belirleyin: 200 kişilik bir grup 15 dakikada yemek yiyemez.',
                        'İçecek noktalarını yemek hattından ayırın; kuyruk hızını en çok bu düşürür.',
                        'Toplama işlemini program devam ederken sessizce yürütecek şekilde planlayın.',
                    ]],
                    ['kind' => 'heading', 'text' => 'Menüyü servis hızına göre seçin'],
                    ['kind' => 'paragraph', 'text' => 'Porsiyonlanması zaman alan yemekler kalabalıkta kuyruğu uzatır. Önceden porsiyonlanabilen, servis kaşığıyla hızlı alınabilen seçenekler tercih edilir. Görsel olarak etkileyici ama servis hızını düşüren kaplar, ana hat yerine ayrı bir istasyona alınabilir.'],
                    ['kind' => 'callout', 'text' => 'Kalabalık etkinliklerde en sık yapılan hata, menüyü küçük bir davet gibi kurup servis düzenini sonradan çözmeye çalışmak. Sıralama tersi olmalı: önce servis akışı, sonra ona uyan menü.'],
                ],
            ],
        ];
    }
}
