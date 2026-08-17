<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Admin;

use Veykemtu\BridgeApi\Admin\DashboardWidgets\BldCorporateStatus;
use Veykemtu\BridgeApi\Admin\DashboardWidgets\BldStatus;

/**
 * Eklentinin admin panel yüzeylerinin kayıt tanımları.
 *
 * `Extension.php` bu sınıfın statik metotlarını doğrudan döndürür. Tanımların
 * ayrı bir dosyada durmasının sebebi `Extension.php`'nin API tarafıyla
 * (rotalar, ara katmanlar, oran sınırları) admin tarafını aynı dosyada
 * büyütmemesi; iki taraf farklı zamanlarda ve farklı sebeplerle değişiyor.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * BU DOSYADAKİ EKRANLARIN HİÇBİRİNE BUGÜN ULAŞILAMIYOR — ve bu doğrudur.
 *
 * Admin paneli 17.08.2026'da kapatıldı (F4): Kontrol Merkezi tek yönetim
 * yüzeyi ve `/admin/*` yolları `RequireAdminPanel` ara katmanıyla `404`
 * dönüyor. Şalter `BLD_ADMIN_ENABLED` ortam değişkeni, varsayılan kapalı;
 * açma yordamı `docs/04-platform.md` §2.7.
 *
 * KAYITLAR YİNE DE SİLİNMEDİ. Sebep, kapatmanın kendisiyle aynı: panel bir
 * YEDEK yüzey olarak duruyor ve yedeğin değeri, ihtiyaç anında EKSİKSİZ
 * açılmasında. Menü girdileri, yetki kutuları ve gösterge paneli
 * parçacıkları buradan silinseydi, şalter açıldığında yalnız adresi bilinen
 * ekranlara gidilebilen, yan menüsü boş ve yetkileri personel rollerinden
 * düşmüş bir panel açılırdı — yani "geri alınabilir" dediğimiz şey geri
 * alınamaz olurdu.
 *
 * Bu yüzden aşağıdaki tanımlar, panel kapalıyken de doğru kalmak
 * zorundadır: yeni bir admin ekranı eklendiğinde girdisi ve yetkisi
 * buraya yine yazılır (`Tests\Feature\Admin*` paketleri şalteri açıp
 * hepsini doğrulamaya devam ediyor).
 * ─────────────────────────────────────────────────────────────────────────
 */
final class AdminRegistrar
{
    /** Ayarlar ekranına erişim yetkisi. */
    public const string PERMISSION = 'Veykemtu.BldSettings';

    /**
     * Mutfak kasaları ekranına erişim yetkisi — AYRI, çünkü kapsamı farklı.
     *
     * Bu yetkiyi taşıyan kişi kasaya "yeniden başlat" gönderebilir ve bir
     * cihazı iptal edip mutfağı sipariş göremez hâle getirebilir. Fiyat ve
     * şalter yetkisiyle (`PERMISSION`) aynı kutuya konsaydı, birini vermek
     * istediğinde diğerini de vermek zorunda kalınırdı.
     */
    public const string PERMISSION_DEVICES = 'Veykemtu.KitchenDevices';

    /**
     * Kurumsal site içeriği ekranlarına erişim yetkisi — ÜÇÜNCÜ bir kutu.
     *
     * İçerik yazan kişi ile işletmeyi yöneten kişi aynı kişi değil. Hizmet
     * metni veya blog yazısı girmek için panele alınan biri, `PERMISSION`
     * verilseydi asgari sepet tutarını ve sipariş alım şalterini de
     * değiştirebilirdi; `PERMISSION_DEVICES` verilseydi mutfak kasasını iptal
     * edip servisi durdurabilirdi. İçerik hatası geri alınabilir, o ikisi
     * ciro kaybettirir — bu yüzden ayrı yetki.
     */
    public const string PERMISSION_CONTENT = 'Veykemtu.SiteContent';

    /**
     * Teklif talepleri ekranına erişim yetkisi — DÖRDÜNCÜ kutu.
     *
     * `PERMISSION_CONTENT` yeniden kullanılmadı ve gerekçesi tek kelime:
     * KİŞİSEL VERİ. İçerik yetkisi, herkese açık pazarlama metinlerini
     * yazma yetkisidir — o metinlerin tamamı zaten sitede yayında, yani
     * yetkiyi vermek hiçbir mahremiyet kararı içermez. Teklif talepleri ise
     * ad, telefon ve e-posta taşıyor: sistemdeki tek "müşteri olmayan kişi"
     * havuzu. İki ekranı aynı kutuya koymak, blog yazısı girmesi için panele
     * alınan serbest çalışan bir metin yazarına firmanın bütün satış
     * adaylarının iletişim listesini açmak olurdu; KVKK'nın "erişim en dar
     * çevreyle sınırlanır" ilkesi bunun tersini söylüyor.
     *
     * Menüde yine de İçerikler grubunun altında duruyor: kaynağı sitedir ve
     * yöneticinin onu arayacağı yer orasıdır. Menü YERİ ile erişim KUTUSU
     * ayrı sorular.
     */
    public const string PERMISSION_QUOTES = 'Veykemtu.QuoteRequests';

    /**
     * İade takibi ekranına erişim yetkisi — BEŞİNCİ kutu.
     *
     * PARA HAREKETİ. Hangi siparişin parası kime, ne zaman geri gitti —
     * ticari olarak hassas veri. İçerik veya teklif yetkisiyle aynı kutuya
     * konsaydı, blog yazan birine iade defteri açılırdı. Ayrı yetki, "en
     * dar çevre" ilkesinin gereği.
     *
     * ESKİ ADI `PERMISSION_ACCOUNT` (`Veykemtu.AccountLedger`) İDİ ve cari
     * hesap ekranlarıyla paylaşılıyordu. Cari kalkınca kutuda tek ekran
     * kaldı; adı da o ekranı anlatıyor. **Yetki dizesi değişti** — mevcut
     * personel rollerinde iade yetkisi bir kez yeniden işaretlenmelidir
     * (`docs/RUNBOOK.md` §9).
     */
    public const string PERMISSION_REFUNDS = 'Veykemtu.Refunds';

    /**
     * Abonelik ekranlarına erişim yetkisi — ALTINCI kutu.
     *
     * İade (gerçekleşmiş para hareketi) ile abonelik (sipariş üreten kural +
     * fiyatlandırma) farklı işler: satış ekibi aboneliği fiyatlandırır,
     * muhasebe iadeyi kapatır. Ayrı yetki, "en dar çevre" ilkesi.
     */
    public const string PERMISSION_SUBSCRIPTIONS = 'Veykemtu.Subscriptions';

    /**
     * Telefon siparişi ekranına erişim yetkisi — YEDİNCİ kutu (B-13).
     *
     * Bu ekran SİPARİŞ YARATIR ve müşteri kaydı açar; üstelik vitrin
     * kapılarını (şalter, kesim saati, asgari tutar) atlar. Yani panelde
     * sipariş listesini görüntülemekten çok daha geniş bir yetki. Sipariş
     * görüntüleme yetkisiyle aynı kutuya konsaydı, telefonu açan herkes
     * kapalı saatte sipariş açabilir ve cari hesaba borç yazabilirdi.
     */
    public const string PERMISSION_PHONE_ORDERS = 'Veykemtu.PhoneOrders';

    /**
     * Aylık menü takvimi ekranına erişim yetkisi — SEKİZİNCİ kutu (B-19).
     *
     * Bu ekran ŞİRKETİN NE SATACAĞINA VE HANGİ FİYATA SATACAĞINA karar
     * veriyor: bir güne menü girilmemişse o gün hiçbir şey satılmaz, paket
     * fiyatı buradan gelir ve kalemlerin gün fiyatı ürünün kendi fiyatını
     * ezer. Yani ciro doğrudan bu ekrandan çıkıyor.
     *
     * SİPARİŞ GÖRÜNTÜLEME YETKİSİYLE AYNI KUTUYA KONMADI. Konsaydı,
     * siparişlere bakabilen herkes gelecek ayı yeniden fiyatlandırabilirdi
     * — üstelik değişikliğin belirtisi anında görünmez, ancak o gün gelip
     * yanlış fiyattan satış yapıldığında fark edilirdi.
     *
     * `PERMISSION` (BLD Ayarları) ile de birleştirilmedi: o kutu şalter ve
     * kesim saati gibi GÜNLÜK İŞLETME anahtarlarını taşıyor ve mutfak
     * sorumlusuna verilebilmeli. Menü fiyatlaması ise satın alma/işletme
     * sahibi kararı; ikisi farklı kişiler.
     */
    public const string PERMISSION_DAILY_MENU = 'Veykemtu.DailyMenu';

    /** Mutfak kasaları ekranının admin paneldeki adresi. */
    public const string DEVICES_URI = 'veykemtu/bridgeapi/kitchen_devices';

    /** Aylık menü takvimi ekranının admin paneldeki adresi. */
    public const string DAILY_MENUS_URI = 'veykemtu/bridgeapi/daily_menus';

    /** Telefon siparişi ekranının admin paneldeki adresi. */
    public const string PHONE_ORDERS_URI = 'veykemtu/bridgeapi/phone_orders';

    /** Sipariş düzenleme geçmişi ekranının admin paneldeki adresi. */
    public const string REVISIONS_URI = 'veykemtu/bridgeapi/order_revisions';

    /** Tükenen ürünler geçmişi ekranının admin paneldeki adresi. */
    public const string SOLDOUT_URI = 'veykemtu/bridgeapi/menu_sold_outs';

    /** Hizmetler ekranının admin paneldeki adresi. */
    public const string SERVICES_URI = 'veykemtu/bridgeapi/site_services';

    /** Bilgi merkezi yazıları ekranının admin paneldeki adresi. */
    public const string POSTS_URI = 'veykemtu/bridgeapi/site_posts';

    /** Teklif talepleri ekranının admin paneldeki adresi. */
    public const string QUOTES_URI = 'veykemtu/bridgeapi/quote_requests';

    /** İçerik ekranlarının ortak üst menü grubu kodu. */
    public const string CONTENT_MENU = 'bld_content';

    /** Abonelikler ekranının admin paneldeki adresi. */
    public const string SUBSCRIPTIONS_URI = 'veykemtu/bridgeapi/subscriptions';

    /** Kapalı günler ekranının admin paneldeki adresi. */
    public const string CLOSED_DAYS_URI = 'veykemtu/bridgeapi/closed_days';

    /** İade takibi ekranının admin paneldeki adresi. */
    public const string REFUNDS_URI = 'veykemtu/bridgeapi/refunds';

    /** Kurumsal (abonelik/iade/kapalı gün) ekranların ortak menü grubu kodu. */
    public const string CORPORATE_MENU = 'bld_corporate';

    private function __construct() {}

    /**
     * Ayarlar → Eklentiler altındaki "BLD Ayarları" girdisi.
     *
     * Sayfayı çekirdeğin `Extensions::edit` ucu çizer; kendi denetleyicimizi
     * yazmıyoruz. Adres: `admin/extensions/edit/veykemtu/bridgeapi/settings`.
     *
     * @return array<string, array<string, mixed>>
     */
    public static function registerSettings(): array
    {
        return [
            BldSettings::SETTINGS_CODE => [
                'label' => 'lang:veykemtu.bridgeapi::default.settings.label',
                'description' => 'lang:veykemtu.bridgeapi::default.settings.description',
                'icon' => 'fa fa-sliders',
                'priority' => 10,
                'permissions' => [self::PERMISSION],
                'model' => BldSettings::class,
            ],
            /*
             * Site İçeriği de bir "ayar sayfası" olarak kaydediliyor çünkü
             * kayıt değil, sınırlı sayıda alanın tek formda düzenlenmesi —
             * hizmet ve yazılar gibi liste ekranı gerektirmiyor. Yetkisi
             * `PERMISSION_CONTENT`: içerik yazan kişi fiyat ve şaltere
             * dokunamamalı.
             */
            SiteContentSettings::SETTINGS_CODE => [
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.title',
                'description' => 'lang:veykemtu.bridgeapi::sitecontent.section_brand_comment',
                'icon' => 'fa fa-newspaper',
                'priority' => 20,
                'permissions' => [self::PERMISSION_CONTENT],
                'model' => SiteContentSettings::class,
            ],
        ];
    }

    /**
     * Yan menüde "Restoran" altına kısayol.
     *
     * NEDEN SİSTEM ALTINA DEĞİL: bunlar günlük işletme anahtarlarıdır
     * (yoğunluk, kesim saati), kurulum ayarı değil. Ayarlar → Eklentiler
     * yolundan geçmek zorunda kalan yönetici, yoğun bir öğle servisinde
     * yoğunluk anahtarını bulamaz.
     *
     * @return array<string, array<string, mixed>>
     */
    public static function registerNavigation(): array
    {
        return [
            'restaurant' => [
                'child' => [
                    /*
                     * TELEFON SİPARİŞİNİN DE ÜSTÜNDE (88) — B-19.
                     *
                     * Yeni rejimde günün işi bu: menü girilmemiş bir güne
                     * hiçbir kanaldan sipariş alınamıyor, telefon dahil.
                     * Telefon siparişinin altında dursaydı, sıralama hâlâ
                     * kataloğun satıldığı eski dünyayı anlatırdı.
                     */
                    'bld_daily_menus' => [
                        'priority' => 88,
                        'class' => 'bld_daily_menus',
                        'href' => admin_url(self::DAILY_MENUS_URI),
                        'title' => lang('veykemtu.bridgeapi::dailymenu.side_menu'),
                        'permission' => self::PERMISSION_DAILY_MENU,
                    ],
                    /*
                     * EN ÜSTTE (89) VE "Restoran" ALTINDA: telefon siparişi
                     * günün en sık yapılan işlerinden biri ve müşteri hatta
                     * beklerken açılıyor. Kendi grubuna konsaydı bir tık
                     * daha uzakta olurdu; ayarların altında kalsaydı hiç
                     * bulunamazdı.
                     */
                    'bld_phone_orders' => [
                        'priority' => 89,
                        'class' => 'bld_phone_orders',
                        'href' => admin_url(self::PHONE_ORDERS_URI),
                        'title' => lang('veykemtu.bridgeapi::phoneorder.side_menu'),
                        'permission' => self::PERMISSION_PHONE_ORDERS,
                    ],
                    'bld_settings' => [
                        'priority' => 90,
                        'class' => 'bld_settings',
                        'href' => admin_url('extensions/edit/veykemtu/bridgeapi/'.BldSettings::SETTINGS_CODE),
                        'title' => lang('veykemtu.bridgeapi::default.side_menu.settings'),
                        'permission' => self::PERMISSION,
                    ],
                    // Kasa yönetimi de günlük işletme işidir: yazıcı sustuğunda
                    // veya alarm çalmaya devam ettiğinde yöneticinin bu sayfayı
                    // Ayarlar → Eklentiler yolunu izleyerek araması gerekmemeli.
                    'bld_kitchen_devices' => [
                        'priority' => 91,
                        'class' => 'bld_kitchen_devices',
                        'href' => admin_url(self::DEVICES_URI),
                        'title' => lang('veykemtu.bridgeapi::default.side_menu_devices'),
                        'permission' => self::PERMISSION_DEVICES,
                    ],
                    /*
                     * İZLEME EKRANLARI EN ALTTA (92-93) VE BİLEREK.
                     *
                     * İkisi de salt okunur ve günlük işin parçası değil:
                     * bir şey ters gittiğinde ("tutar neden değişmiş",
                     * "humus yine mi bitti") bakılıyorlar. Sipariş girme ve
                     * ayar ekranlarının üstünde dursalardı, her gün
                     * kullanılan iki girdiyi aşağı iterlerdi.
                     */
                    'bld_order_revisions' => [
                        'priority' => 92,
                        'class' => 'bld_order_revisions',
                        'href' => admin_url(self::REVISIONS_URI),
                        'title' => lang('veykemtu.bridgeapi::monitor.revisions_side_menu'),
                        'permission' => self::PERMISSION,
                    ],
                    'bld_menu_soldout' => [
                        'priority' => 93,
                        'class' => 'bld_menu_soldout',
                        'href' => admin_url(self::SOLDOUT_URI),
                        'title' => lang('veykemtu.bridgeapi::monitor.soldout_side_menu'),
                        'permission' => self::PERMISSION,
                    ],
                ],
            ],

            /*
             * KENDİ ÜST GRUBU — "Restoran"ın altına DEĞİL.
             *
             * "Restoran" başlığı işletmenin günlük işini taşıyor (menüler,
             * konumlar, kasalar, şalterler). Kurumsal sitenin metinleri o işin
             * parçası değil: farklı kişi girer, farklı sıklıkta değişir ve
             * yanlış girildiğinde servis durmaz. Aynı başlığa konsalardı hem
             * liste on maddeye çıkardı hem de içerik yetkisi olan kişiye
             * dokunamayacağı beş ekran gösterilmiş olurdu.
             *
             * ÇOCUKLARIN HEPSİNDE `priority` VAR, ÇÜNKÜ ZORUNLU: çekirdek
             * hem `child` hem de kendi anahtarları olan bir grup tanımında
             * üst girdiyi ham diziyle EZİYOR (`Navigation::registerNavItems`
             * → `addNavItem`), yani çocuklar `$navItemDefaults` ile
             * birleştirilmeden saklanıyor. `getVisibleNavItems` çocukları
             * `priority` alanına göre sıralıyor; alan yazılmasaydı menü
             * çizilirken tanımsız anahtar hatası verirdi.
             */
            self::CONTENT_MENU => [
                // 40 "Restoran", 50 "Pazarlama". İçerik ikisinin arasına
                // giriyor: sipariş akışından sonra, kampanyalardan önce.
                'priority' => 45,
                'class' => self::CONTENT_MENU,
                'icon' => 'fa-newspaper',
                'title' => lang('veykemtu.bridgeapi::default.side_menu.content'),
                'child' => [
                    /*
                     * En üstte: marka ve iletişim en sık aranan bilgi. Hizmet
                     * ve yazı ekranlarının altında kalsaydı, telefon numarasını
                     * güncellemek isteyen yönetici önce blog listesini görürdü.
                     */
                    'bld_site_content' => [
                        'priority' => 5,
                        'class' => 'bld_site_content',
                        'href' => admin_url(
                            'extensions/edit/veykemtu/bridgeapi/'.SiteContentSettings::SETTINGS_CODE,
                        ),
                        'title' => lang('veykemtu.bridgeapi::sitecontent.title'),
                        'permission' => self::PERMISSION_CONTENT,
                    ],
                    'bld_site_services' => [
                        'priority' => 10,
                        'class' => 'bld_site_services',
                        'href' => admin_url(self::SERVICES_URI),
                        'title' => lang('veykemtu.bridgeapi::default.side_menu.services'),
                        'permission' => self::PERMISSION_CONTENT,
                    ],
                    /*
                     * BİLGİ MERKEZİ (blog) MENÜDEN ÇIKARILDI — W-08.
                     *
                     * Site v2.0'da `/bilgi-merkezi` kaldırıldı: yazıların
                     * hiçbiri artık yayınlanmıyor. Menüde kalsaydı, girilen
                     * her yazı hiçbir yerde görünmediği hâlde emek isteyen
                     * bir ekran olurdu.
                     *
                     * DENETLEYİCİ, MODEL VE TABLO DURUYOR (`SitePosts`,
                     * `SitePost`, `veykemtu_site_posts`): eklemeli şema
                     * kuralı gereği veri silinmez ve blog geri gelirse
                     * yalnızca bu girdinin geri konması yeter. Adres hâlâ
                     * çalışıyor: admin/veykemtu/bridgeapi/site_posts
                     */

                    /*
                     * EN ALTTA VE AYRI YETKİYLE. Üstündeki üç girdi içerik
                     * ÜRETİR, bu girdi içeriğin GETİRDİĞİNİ toplar; yönü
                     * ters olduğu için listenin sonunda duruyor. Yetkisi de
                     * ayrı: gerekçe `PERMISSION_QUOTES` üzerinde.
                     */
                    'bld_quote_requests' => [
                        'priority' => 30,
                        'class' => 'bld_quote_requests',
                        'href' => admin_url(self::QUOTES_URI),
                        'title' => lang('veykemtu.bridgeapi::quoterequest.side_menu'),
                        'permission' => self::PERMISSION_QUOTES,
                    ],
                ],
            ],

            /*
             * KURUMSAL üst grubu — abonelik, iade ve kapalı gün ekranları.
             *
             * "İçerikler"in (45) hemen ardında (46): sipariş/içerik akışından
             * sonra, sözleşme ve para yüzeyi. Çocukların hepsinde `priority`
             * zorunlu (CONTENT_MENU gerekçesi).
             *
             * Cari hesap ekranları (`bld_customer_accounts`,
             * `bld_account_entries`) kaldırıldı. Grup KALDI: içinde üç ekran
             * daha var ve grubu dağıtmak, alışılmış menü yerlerini boşuna
             * değiştirmek olurdu.
             */
            self::CORPORATE_MENU => [
                'priority' => 46,
                'class' => self::CORPORATE_MENU,
                'icon' => 'fa-building',
                'title' => lang('veykemtu.bridgeapi::default.side_menu_corporate'),
                'child' => [
                    'bld_subscriptions' => [
                        'priority' => 5,
                        'class' => 'bld_subscriptions',
                        'href' => admin_url(self::SUBSCRIPTIONS_URI),
                        'title' => lang('veykemtu.bridgeapi::subscription.side_menu'),
                        'permission' => self::PERMISSION_SUBSCRIPTIONS,
                    ],
                    /*
                     * İADELER bir gelen kutusudur: `manual` durumdaki her
                     * satır birinin para göndermesini bekliyor. Bekleyen iş,
                     * takvim gibi arka plan ekranlarının altında kalmamalı —
                     * bu yüzden kapalı günlerden önce (15 < 30).
                     */
                    'bld_refunds' => [
                        'priority' => 15,
                        'class' => 'bld_refunds',
                        'href' => admin_url(self::REFUNDS_URI),
                        'title' => lang('veykemtu.bridgeapi::refund.side_menu'),
                        'permission' => self::PERMISSION_REFUNDS,
                    ],
                    'bld_closed_days' => [
                        'priority' => 30,
                        'class' => 'bld_closed_days',
                        'href' => admin_url(self::CLOSED_DAYS_URI),
                        'title' => lang('veykemtu.bridgeapi::subscription.closed_side_menu'),
                        'permission' => self::PERMISSION_SUBSCRIPTIONS,
                    ],
                ],
            ],
        ];
    }

    /**
     * `Operatör` rolü bu yetkiyi ALMAZ (`docs/04-platform.md` §2.4): sipariş
     * görüntüleyip durum ilerletebilir, ama fiyat ve şalterlere dokunamaz.
     *
     * @return array<string, array<string, string>>
     */
    public static function registerPermissions(): array
    {
        return [
            self::PERMISSION => [
                'label' => 'lang:veykemtu.bridgeapi::default.permission_settings',
                'group' => 'igniter::admin.permissions.name',
            ],
            self::PERMISSION_DEVICES => [
                'label' => 'lang:veykemtu.bridgeapi::default.permission_devices',
                'group' => 'igniter::admin.permissions.name',
            ],
            self::PERMISSION_CONTENT => [
                'label' => 'lang:veykemtu.bridgeapi::default.permission_content',
                'group' => 'igniter::admin.permissions.name',
            ],
            self::PERMISSION_QUOTES => [
                'label' => 'lang:veykemtu.bridgeapi::quoterequest.permission',
                'group' => 'igniter::admin.permissions.name',
            ],
            self::PERMISSION_REFUNDS => [
                'label' => 'lang:veykemtu.bridgeapi::default.permission_refunds',
                'group' => 'igniter::admin.permissions.name',
            ],
            self::PERMISSION_SUBSCRIPTIONS => [
                'label' => 'lang:veykemtu.bridgeapi::subscription.permission',
                'group' => 'igniter::admin.permissions.name',
            ],
            self::PERMISSION_PHONE_ORDERS => [
                'label' => 'lang:veykemtu.bridgeapi::phoneorder.permission',
                'group' => 'igniter::admin.permissions.name',
            ],
            self::PERMISSION_DAILY_MENU => [
                'label' => 'lang:veykemtu.bridgeapi::dailymenu.permission',
                'group' => 'igniter::admin.permissions.name',
            ],
        ];
    }

    /**
     * @return array<class-string, array<string, mixed>>
     */
    public static function registerDashboardWidgets(): array
    {
        return [
            BldStatus::class => [
                'label' => 'lang:veykemtu.bridgeapi::default.dashboard.label',
                'context' => 'dashboard',
            ],
            BldCorporateStatus::class => [
                'label' => 'lang:veykemtu.bridgeapi::subscription.dashboard_label',
                'context' => 'dashboard',
            ],
        ];
    }
}
