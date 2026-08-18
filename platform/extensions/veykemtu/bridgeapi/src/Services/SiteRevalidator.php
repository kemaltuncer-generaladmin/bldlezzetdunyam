<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use Illuminate\Support\Facades\App;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * İçerik değiştiğinde kurumsal siteye "önbelleğini tazele" der.
 *
 * ## Neden gerekli?
 *
 * Panelde kaydet'e basmak sunucu önbelleğini düşürüyor (`SiteContentObserver`)
 * ama site kendi kopyasını Next.js ISR ile tutuyor. Haber vermezsek yönetici
 * değişikliğini beş dakikaya kadar göremez ve "kaydettim ama olmadı" diye
 * tekrar tekrar kaydeder.
 *
 * ═════════════════════════════════════════════════════════════════════════
 * ETİKET AYRIMI SONRADAN GELDİ (menü gecikmesi).
 *
 * Bu servis kurulduğunda site içeriğinin TEK etiketi vardı ve gövdesiz bir
 * `POST` yeterliydi. Sonra günün menüsü de ISR ile önbelleğe alındı
 * (`daily-menu` etiketi) ama HİÇBİR YERDEN düşürülmedi: menü panelde
 * değiştiriliyor, site eski menüyü ISR süresi dolana kadar göstermeye devam
 * ediyordu. Belirtisi "menü değişiklikleri siteye çok geç yansıyor" idi ve
 * sebebi hiçbir hata satırında görünmüyordu — çünkü hata yoktu, yalnız
 * yapılmayan bir çağrı vardı.
 *
 * Artık hangi etiketin düşürüleceği gövdeyle söyleniyor ve etiketler BEYAZ
 * LİSTE: serbest etiket kabul etmek, isteği eline geçiren birinin sitenin
 * istediği önbelleğini boşaltmasına kapı açardı.
 * ═════════════════════════════════════════════════════════════════════════
 *
 * ## SÖZLEŞME (site tarafındaki uç bunu uygular)
 *
 * ```
 * POST  {SITE_REVALIDATE_URL}
 * Authorization: Bearer {SITE_REVALIDATE_SECRET}
 * Content-Type: application/json
 * {"tag": "daily-menu"}
 * ```
 *
 * Beklenen yanıt: `2xx`. Gövdesine BAKILMAZ — bu bir "en iyi çaba"
 * bildirimidir ve dönüş değerinin hiçbir kararı etkilememesi gerekir.
 * `tag` alanı GÖNDERİLMEZSE site içeriği etiketi düşürülür (eski davranış;
 * `revalidate()` hâlâ öyle çağırıyor).
 *
 * ## Hata SESSİZ YUTULUR — bilerek
 *
 * Site kapalıysa, adres yanlışsa veya ağ kopuksa **kaydetme işlemi yine de
 * başarılı olmalı.** İçerik veritabanına yazıldı; sitenin haberi olmaması
 * yalnızca gecikme demek, veri kaybı değil. Burada istisna fırlatmak,
 * yöneticinin kaydını reddedip yazdığı metni çöpe atardı.
 *
 * Site zaten en geç ISR süresi dolduğunda kendini toparlar; bu istek sadece
 * o süreyi kısaltıyor. Yani "en iyi çaba" bir bildirim, kritik bir yol değil.
 *
 * ## Yapılandırılmadıysa sessizce atlanır
 *
 * Geliştirme makinesinde ve testlerde site ayakta olmayabilir. Adres veya sır
 * tanımsızken HER kaydetmede günlüğe uyarı basmak, gerçek hataları görünmez
 * hâle getirirdi — bu yüzden uyarı SÜREÇ BAŞINA BİR KEZ yazılıyor
 * (`$announced`): "site bağlı değil" bilgisi bir kez duyulmalı, bin kez
 * değil.
 */
final class SiteRevalidator
{
    /** Kurumsal site içeriği (hizmetler, yazılar, metin blokları). */
    public const string TAG_SITE_CONTENT = 'site-content';

    /**
     * Günün menüsü — `website/lib/api/daily-menu.ts` içindeki
     * `DAILY_MENU_TAG` ile BİREBİR AYNI OLMALIDIR.
     *
     * Ayrışırsa çağrı hatasız çalışır ve HİÇBİR ŞEY tazelenmez: site var
     * olmayan bir etiketi düşürür, gerçek etiket yerinde kalır ve belirti
     * yine "menü geç yansıyor" olur. Bu yüzden değer burada bir sabit ve
     * sözleşmesi sınıf başlığında yazılı.
     */
    public const string TAG_DAILY_MENU = 'daily-menu';

    /**
     * İzin verilen etiketler — BEYAZ LİSTE.
     *
     * Çağıranın serbest metin geçebilmesi, bir yazım hatasını sessiz bir
     * hiçliğe çevirirdi; daha kötüsü, bu servisi çağırabilen herhangi bir
     * kod yolunun sitenin istediği önbelleğini boşaltabilmesi olurdu.
     *
     * @var list<string>
     */
    public const array TAGS = [self::TAG_SITE_CONTENT, self::TAG_DAILY_MENU];

    /**
     * Kısa zaman aşımı: yönetici kaydet'e bastığında panelin kilitlenmemesi
     * gerekiyor. Site yavaşsa beklemek yerine vazgeçip ISR'a bırakıyoruz.
     *
     * `afterResponse()` ile çağrıldığında istek zaten dönmüş oluyor ve bu
     * süre kullanıcıyı hiç bekletmiyor; yine de kısa kalıyor ki php-fpm
     * işçisi ölü bir adrese takılıp havuzdan düşmesin.
     */
    private const int TIMEOUT_SECONDS = 3;

    /**
     * "Yapılandırılmadı" bilgisi bu süreçte yazıldı mı.
     *
     * STATİK, ÖRNEK ALANI DEĞİL: bu servis konteynere tekil olarak bağlı
     * değil ve her enjeksiyonda yeni bir örnek doğuyor. Örnek alanı olsaydı
     * bayrak hiçbir zaman tutmaz, tek bir istekte on kalem eklerken on satır
     * yazılırdı.
     */
    private static bool $announced = false;

    /**
     * Site içeriğini tazeler — ESKİ ÇAĞIRANLARIN YOLU.
     *
     * Gövdesiz gider (`tag` yok) ve site tarafı bunu "site içeriği" olarak
     * yorumlar. İmza değiştirilmedi: `SiteContentObserver` ve `CmsController`
     * bu metodu çağırıyor ve ikisini de aynı anda değiştirmek, sözleşmenin
     * iki ucunu birden hareket ettirmek olurdu.
     */
    public function revalidate(): void
    {
        $this->send(null);
    }

    /**
     * Belirli bir etiketi tazeler.
     *
     * @param  string  $tag  `self::TAGS` içinden biri; değilse HİÇBİR ŞEY
     *                       yapılmaz ve günlüğe yazılır (sessiz bir yazım
     *                       hatası, hiç tazelenmeyen bir önbellek demekti).
     */
    public function revalidateTag(string $tag): void
    {
        if (!in_array($tag, self::TAGS, true)) {
            Log::warning('Bilinmeyen tazeleme etiketi — istek gönderilmedi.', [
                'tag' => $tag,
                'allowed' => self::TAGS,
            ]);

            return;
        }

        $this->send($tag);
    }

    /**
     * Etiketi YANIT GÖNDERİLDİKTEN SONRA tazeler.
     *
     * ═════════════════════════════════════════════════════════════════════
     * NEDEN İSTEK İÇİNDE DEĞİL: YAZMA İŞİ BU ÇAĞRIYI BEKLEMEMELİ.
     *
     * Menü kaydetmek bir mutfak işidir; siteye haber vermek bir kolaylıktır.
     * Site yavaşladığında panelin de yavaşlaması, ikisini yanlış sıraya
     * koymaktır — üstelik üç saniyelik zaman aşımı bile bir günde onlarca
     * kez toplanır (bir gün için on kalem eklemek on çağrı demek).
     *
     * `App::terminating()` kuyruk altyapısı GEREKTİRMEZ. Kuyruğa almak daha
     * temiz görünürdü ama `QUEUE_CONNECTION` bu kurulumda `sync` ve `sync`
     * kuyruğu işi İSTEĞİN İÇİNDE koşturur — yani hiçbir şey kazanmadan bir
     * katman eklerdik.
     * ═════════════════════════════════════════════════════════════════════
     */
    public function afterResponse(string $tag): void
    {
        App::terminating(function () use ($tag): void {
            $this->revalidateTag($tag);
        });
    }

    /** Asıl çağrı. `$tag` `null` ise gövde gönderilmez (eski davranış). */
    private function send(?string $tag): void
    {
        $url = trim((string) config('veykemtu.site_revalidate_url', env('SITE_REVALIDATE_URL', '')));
        $secret = trim((string) config('veykemtu.site_revalidate_secret', env('SITE_REVALIDATE_SECRET', '')));

        if ($url === '' || $secret === '') {
            if (!self::$announced) {
                self::$announced = true;
                // BİLGİ, UYARI DEĞİL: site bağlı olmayan bir kurulum
                // (geliştirme makinesi, test) bozuk değildir. Ama tamamen
                // sessiz kalmak, canlıda değişkeni koymayı unutan kişiye
                // hiçbir ipucu bırakmazdı.
                Log::info(
                    'Site tazeleme yapılandırılmamış (SITE_REVALIDATE_URL/SECRET boş) — '
                    .'menü ve içerik değişiklikleri siteye ancak ISR süresi dolunca yansır.',
                );
            }

            return;
        }

        try {
            $request = Http::timeout(self::TIMEOUT_SECONDS)->withToken($secret);

            // GÖVDE YALNIZ ETİKET VARKEN. Boş bir `{}` göndermek, site
            // tarafındaki "gövde yoksa site içeriği" dalını belirsizleştirirdi.
            $tag === null ? $request->post($url) : $request->post($url, ['tag' => $tag]);
        } catch (Throwable $exception) {
            // Günlüğe yazılıyor ama yukarı fırlatılmıyor: gerekçe sınıf başlığında.
            report($exception);
        }
    }
}
