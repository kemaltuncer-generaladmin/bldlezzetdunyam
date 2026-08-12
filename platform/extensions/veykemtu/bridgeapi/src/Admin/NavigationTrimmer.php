<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Admin;

use Igniter\Admin\Classes\Navigation;

/**
 * Catering işine ait olmayan menü girdilerini panelden kaldırır.
 *
 * NEDEN EKLENTİYİ DEVRE DIŞI BIRAKMIYORUZ: TastyIgniter'ın eklenti
 * bağımlılıkları döngüsel. `ti-ext-local` (lokasyonlar, menüler)
 * `ti-ext-reservation`'ı ZORUNLU tutuyor, o da `ti-ext-local`'ı; aynı
 * şekilde `ti-ext-cart` → `ti-ext-coupons` → `ti-ext-cart`. Yani
 * "rezervasyonu kaldıralım" demek menü yönetimini de düşürmek demek.
 * Kod yüklü kalıyor, yalnızca arayüzden gizleniyor.
 *
 * KANCA `admin.navigation.extendItems` OLAYI, `registerCallback` DEĞİL.
 * `Navigation::loadItems()` önce callback'leri, SONRA eklenti girdilerini
 * yüklüyor; callback içinde silinen bir girdi hemen ardından yeniden
 * ekleniyordu. Bu olay ise kayıtların tamamı bittikten sonra tetikleniyor.
 *
 * GERİ ALMAK tek satır: aşağıdaki listeden kodu çıkarın.
 */
final class NavigationTrimmer
{
    /**
     * Gizlenecek menü kodları ve gerekçeleri.
     *
     * Gerekçeler kasten yazılı: altı ay sonra "bu neden yok?" diye soran
     * kişinin git geçmişini kazmasına gerek kalmasın.
     *
     * @var array<string, string>
     */
    private const HIDDEN = [
        // Masaya rezervasyon. Catering'de masa yok; sipariş ya teslim
        // edilir ya gelip alınır (`delivery_type`).
        'reservations' => 'Masa rezervasyonu — catering iş modelinde yok',
        'dining_areas' => 'Masa/salon düzeni — restoran özelliği',

        // TastyIgniter'ın kendi vitrinine ait. Müşteri yüzümüz Next.js
        // sitesi (`website/`), bu ekranların çıktısı hiçbir yerde görünmez.
        'reviews' => 'Vitrin yorumları — müşteri yüzü Next.js sitesi',
        'sliders' => 'Vitrin afişleri — müşteri yüzü Next.js sitesi',
        'pages' => 'Vitrin içerik sayfaları — müşteri yüzü Next.js sitesi',

        // Kullanılmıyor. Sipariş bildirimleri kendi kodumuzdan gidiyor.
        'automation' => 'Otomasyon kuralları — kullanılmıyor',

        // Faz 2'de (F2-07) geri gelecek; şimdi açık durması yöneticiye
        // çalışmayan bir ekran göstermek olurdu.
        'coupons' => 'Kuponlar — docs/11 F2-07 ile geri gelecek',

        // ── v2.0 sadeleştirmesi (B-11) ───────────────────────────────────
        //
        // Buradan aşağısı, panelin "kurulum" yüzeyidir: yılda birkaç kez
        // ya da hiç kullanılmaz, ama her gün menüde yer kaplar ve yanlış
        // tıklandığında zarar verir. `extensions` KASTEN LİSTEDE DEĞİL —
        // kendi ayar sayfalarımız (`BLD Ayarları`, `Site İçeriği`)
        // `admin/extensions/edit/...` adresinde duruyor ve yeni bir
        // eklentiyi açıp kapatmanın tek arayüzü orası.

        // Vitrin teması artık hiç kayıtlı değil (I-07,
        // `BridgeApi\Extension::disableStorefrontTheme`). Tema seçmek
        // görünmeyen bir siteyi biçimlendirmek olurdu.
        'themes' => 'Vitrin teması — I-07 ile vitrin tamamen kapatıldı',

        // `MAIL_MAILER=log` (docker-compose.coolify.yml). Şablon düzenleme
        // ekranı, gönderilmeyen postaların metnini düzenletirdi.
        'mail_templates' => 'E-posta şablonları — posta sürücüsü `log`, gönderim yok',

        // ti-ext-api'nin kendi anahtar yönetimi. Bizim API'miz kendi
        // token'ıyla çalışıyor (`bld.auth`); bu ekrandan üretilen anahtarın
        // hiçbir ucumuzda karşılığı yok.
        'api' => 'TastyIgniter API anahtarları — kendi token akışımız var (bld.auth)',

        // Sürüm/pazar yeri ekranı. Güncelleme imaj yeniden derlenerek
        // yapılıyor (infra/platform/Dockerfile.prod); panelden tetiklenen
        // bir güncelleme imajla veritabanını ayrıştırırdı.
        'updates' => 'Güncelleme/pazar yeri — sürüm imajla gelir, panelden değil',

        // Günlükler `docker logs` ve `storage/logs` üzerinden okunuyor;
        // panel kopyası hem eksik hem de kişisel veri sızdırabiliyor.
        'system_logs' => 'Sistem günlükleri — sunucu günlüğünden okunuyor',
    ];

    private function __construct() {}

    public static function trim(Navigation $navigation): void
    {
        $items = $navigation->getNavItems();

        foreach (array_keys(self::HIDDEN) as $code) {
            // ÜST KODU ARANIYOR, VARSAYILMIYOR. `removeNavItem` yanlış üst
            // kodla çağrılırsa sessizce hiçbir şey yapmaz ve girdi menüde
            // kalır. Üst kodları elle yazmak, çekirdek bir eklentiyi başka
            // bir başlığa taşıdığında fark edilmeden bozulurdu.
            if (array_key_exists($code, $items)) {
                $navigation->removeNavItem($code);

                continue;
            }

            foreach ($items as $parentCode => $parent) {
                if (array_key_exists($code, (array) ($parent['child'] ?? []))) {
                    $navigation->removeNavItem($code, (string) $parentCode);
                }
            }
        }

        self::removeEmptyParents($navigation);
    }

    /**
     * Tüm çocukları gizlenmiş üst başlıkları da kaldırır.
     *
     * "Tasarım" başlığı yalnızca afişler ve içerik sayfalarını taşıyordu;
     * ikisi de gidince geriye tıklanınca boş liste açan bir başlık kalırdı.
     *
     * Kendi adresi OLAN başlıklara dokunulmuyor: "Siparişler" ve
     * "Müşteriler" alt girdisi olmayan ama doğrudan tıklanan girdiler.
     *
     * ÖLÇÜT YALNIZCA `href`. İlk yazışta `class` de "kendi adresi var"
     * sayılmıştı; oysa `class` her girdide bulunan ikon sınıfı ve bu
     * yüzden hiçbir başlık boş sayılmadı — "Pazarlama" ve "Tasarım"
     * çocuklarını kaybettikleri hâlde menüde tıklanınca hiçbir şey
     * açmayan başlıklar olarak kaldı.
     */
    private static function removeEmptyParents(Navigation $navigation): void
    {
        foreach ($navigation->getNavItems() as $code => $item) {
            $hasChildren = (array) ($item['child'] ?? []) !== [];
            $hasOwnLink = ($item['href'] ?? '') !== '';

            if (!$hasChildren && !$hasOwnLink) {
                $navigation->removeNavItem((string) $code);
            }
        }
    }
}
