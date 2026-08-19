<?php

declare(strict_types=1);

/**
 * "Site İçeriği" ekranının Türkçe metinleri.
 *
 * `default.php`'den AYRI: bu ekran ile hizmet/yazı ekranları farklı zamanlarda
 * ve çoğu zaman farklı kişilerce değişiyor; tek dosyada toplamak gereksiz
 * birleştirme çakışması üretiyordu.
 *
 * Açıklama metinleri ("comment") bilinçli olarak uzun: bu sayfayı kullanan
 * kişi geliştirici değil. Bir alanın ne işe yaradığını tahmin etmek zorunda
 * kalırsa ya boş bırakır ya da yanlış doldurur.
 */

return [
    'title' => 'Site İçeriği',

    'section_brand' => 'Marka',
    'section_brand_comment' => 'Sitenin ve mobil uygulamaların kullandığı marka bilgileri. Buradaki değişiklikler birkaç saniye içinde sitede görünür.',
    'label_brand_name' => 'Marka adı',
    'label_brand_short_name' => 'Kısa ad',
    'label_brand_tagline' => 'Slogan',
    'help_brand_tagline' => 'Altbilgide ve paylaşım önizlemelerinde görünen tek cümle.',
    'label_brand_description' => 'Kısa tanım',
    'help_brand_description' => 'Arama motorlarına ve sosyal medya paylaşımlarına giden açıklama. İki cümleyi geçmesin.',
    'label_brand_parent_group' => 'Bağlı olduğu şirket ailesi',
    'label_brand_color' => 'Ana marka rengi',
    'help_brand_color' => 'Butonların ve vurguların rengi. Üzerine beyaz yazı geldiği için kontrastı otomatik ölçülür; okunmayacak kadar açık bir renk seçilirse kaydedilmez ve sebebi söylenir.',
    'label_brand_logo' => 'Logo',
    'help_brand_logo' => 'Şeffaf zeminli PNG veya SVG önerilir. Yüklenmezse site "BLD" harf işaretini kullanmaya devam eder.',

    'section_contact' => 'İletişim',
    'section_contact_comment' => 'Boş bıraktığınız kanal sitede HİÇ GÖSTERİLMEZ — yer tutucu veya boş satır çıkmaz. Bilgi hazır olduğunda doldurun, o an görünür olur.',
    'label_phone' => 'Telefon',
    'help_phone' => 'Okunur biçimde yazın. Tıklanabilir bağlantı otomatik üretilir.',
    'label_whatsapp' => 'WhatsApp numarası',
    'help_whatsapp' => 'Doldurulursa sitede sağ altta sabit bir WhatsApp düğmesi belirir.',
    'label_email' => 'E-posta',
    'label_street' => 'Açık adres',
    'help_address' => 'Adres ancak açık adres ve il birlikte doldurulduğunda yayınlanır. Yarım adres, arama motorlarında hatalı konum bilgisi oluşturur.',
    'label_district' => 'İlçe',
    'label_city' => 'İl',
    'label_postal_code' => 'Posta kodu',
    'label_map' => 'Harita gömme adresi',
    'help_map' => 'Google Haritalar → Paylaş → Harita yerleştir bölümündeki adres. Boşsa iletişim sayfasında harita bölümü hiç görünmez.',
    'label_working_hours' => 'Çalışma saatleri',
    'label_hours_day' => 'Gün aralığı',
    'label_hours_value' => 'Saat aralığı',
    'label_social' => 'Sosyal medya',
    'label_social_name' => 'Ad',
    'label_social_url' => 'Adres',

    'section_legal' => 'Yasal kimlik',
    'section_legal_comment' => 'Mesafeli Sözleşmeler Yönetmeliği ve KVKK, satıcının kimliğini sitede yayınlamayı ZORUNLU kılar. Boş bıraktığınız alan yasal sayfalarda "Girilmesi gerekiyor" uyarısıyla görünür — uydurulmuş bir değerle DEĞİL. Bilgiler tamamlanmadan site yayına alınmamalıdır.',
    'label_trade_name' => 'Ticari unvan',
    'help_trade_name' => 'Vergi levhanızdaki "Ticaret Ünvanı" alanı. Şahıs işletmesinde bu alan boşsa ad-soyadınızı yazın.',
    'label_legal_form' => 'İşletme türü',
    'label_registered_address' => 'Merkez adresi',
    'help_registered_address' => 'Vergi levhanızdaki iş yeri adresi, tek satır. İletişim bölümündeki adresten farklı olabilir — orası müşteriye gösterilen ziyaret adresi, burası yasal merkez.',
    'label_tax_office' => 'Vergi dairesi',
    'label_tax_number' => 'Vergi kimlik no',
    'label_mersis' => 'MERSİS numarası',
    'label_kep' => 'KEP adresi',
    'help_optional_registry' => 'Yalnızca varsa doldurun. Ticaret siciline kayıtlı olmayan şahıs işletmelerinde bunlar bulunmaz; boş bırakıldığında yasal metinlerde satır hiç gösterilmez.',
    'label_payment_provider' => 'Ödeme hizmeti sağlayıcısı',
    'help_payment_provider' => 'Gizlilik metninde "kart bilgileriniz kimin altyapısında işleniyor" sorusunun cevabı. Gerçek sanal POS devreye girmeden doldurmayın.',

    'section_company' => 'Kurumsal metinler',
    'label_mission' => 'Misyon',
    'label_vision' => 'Vizyon',
    'label_group_relation' => 'Şirket ailesi ilişkisi',
    'help_group_relation' => 'Kurumsal sayfada tek paragraf olarak geçer. Site bir eğitim şirketi gibi görünmemeli; bağı belirtmek yeterli.',
    'label_values' => 'Değerler',
    'label_process' => 'Nasıl çalışıyoruz adımları',
    'help_process' => 'Ana sayfada ve kurumsal sayfada numaralandırılmış olarak görünür. Sıra buradaki sıradır.',
    'label_differentiators' => 'Neden biz? maddeleri',

    'section_faq' => 'Sık sorulan sorular',
    'section_faq_comment' => 'Ana sayfada açılır liste olarak görünür ve arama motorlarına yapılandırılmış veri olarak gönderilir.',
    'label_faq' => 'Sorular',
    'label_question' => 'Soru',
    'label_answer' => 'Cevap',

    'section_sectors' => 'Çalıştığımız alanlar',
    'section_sectors_comment' => 'Sektör kartları. Doğrulanmış müşteri referansınız yoksa firma adı veya logo eklemeyin; sektör anlatmak yeterlidir.',
    'label_sectors' => 'Sektörler',
    'label_need' => 'Bu alanın ihtiyacı',
    'label_our_answer' => 'Bizim karşılığımız',
    'label_service_slug' => 'İlgili hizmet adresi',
    'help_service_slug' => 'Hizmetler ekranındaki adres parçası. Örn. kurumsal-toplu-yemek',

    'section_menus' => 'Menü çözümleri',
    'section_menus_comment' => 'Örnek menü kurguları. FİYAT YAZMAYIN — sitede fiyat gösterilmiyor, ziyaretçi teklif formuna yönlendiriliyor.',
    'label_menu_solutions' => 'Menü kurguları',
    'label_audience' => 'Kimin için',
    'label_principle' => 'Planlama ilkesi',
    'label_courses' => 'Kaplar',
    'label_course_name' => 'Kap adı',
    'label_examples' => 'Örnekler',
    'help_examples' => 'Virgülle ayırın. Örn. Mercimek çorbası, Ezogelin, Yayla',
    'label_seasonal' => 'Mevsim yaklaşımı',
    'label_season' => 'Mevsim',
    'label_note' => 'Not',

    'section_quality' => 'Kalite ve hijyen',
    'section_quality_comment' => 'Uygulanan yöntemi anlatın. Sahip olmadığınız belgeyi yazmayın — gıda sektöründe yanlış belge beyanının yaptırımı vardır.',
    'label_quality_chain' => 'Hijyen zinciri adımları',
    'label_allergen' => 'Alerjen yaklaşımı maddeleri',
    'label_certifications' => 'Sahip olunan belgeler',
    'help_certifications' => 'BOŞ BIRAKIN eğer belge yoksa. Boşken site sertifika iddiası içermeyen bir açıklama gösterir. Buraya girilen her belge sitede yayınlanır.',
    'label_cert_name' => 'Belge adı',
    'label_cert_issuer' => 'Veren kurum',
    'label_cert_valid' => 'Geçerlilik',

    'label_title' => 'Başlık',
    'label_body' => 'Açıklama',
    'label_summary' => 'Özet',
    'label_slug' => 'Adres parçası',
    'label_icon' => 'Simge',
    'label_item' => 'Madde',

    'error_contrast' => 'Seçtiğiniz renk beyaz yazıyla %s:1 kontrast veriyor; erişilebilirlik için en az %s:1 gerekiyor. Daha koyu bir ton seçin — aksi hâlde butonlardaki yazı okunmaz.',
];
