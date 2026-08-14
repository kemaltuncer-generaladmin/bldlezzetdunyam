<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Middleware;

use Closure;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Symfony\Component\HttpFoundation\Response;

/**
 * Kontrol Merkezi imzası — `X-Control-Signature` (K-21).
 *
 * NEDEN CİHAZ TOKEN'I DEĞİL: `/api/kitchen/*` uçları bir KASANIN token'ıyla
 * korunuyor ve `RequireScope` her istekte o kasanın `last_seen_at`'ini
 * tazeliyor. Kontrol Merkezi oraya eşleşerek girseydi, panelde açık duran
 * bir ekran mutfakta olmayan bir kasayı "çevrimiçi" gösterirdi ve
 * yöneticinin gördüğü tablo kendi kendini doğrulardı.
 *
 * NEDEN `bbd.signature` YENİDEN KULLANILMADI: o şema BBD Store'la
 * paylaşılan bir sözleşme ve dokunulmaması istendi. Ayrıca yönü ters —
 * BBD bize sipariş YAZIYOR, Kontrol Merkezi ise yönetiyor: cihaz iptal
 * ediyor, ayar itiyor, sipariş revize ediyor. Aynı sırrı iki farklı yetki
 * seviyesi için kullanmak, BBD'nin sırrını ele geçiren birine mutfağı
 * yönetme hakkı da verirdi.
 *
 * ## Tekrar (replay) saldırısına kapalı
 *
 * `bbd.signature` yalnız gövdeyi imzalıyor: zaman damgası ve nonce yok,
 * yani ağı dinleyen biri geçerli bir isteği sınırsız kez oynatabilir.
 * Orada etki `external_id` tekilliğiyle sınırlı kalıyor. BURADA KALMAZDI:
 * "cihazı iptal et" isteğini tekrar oynatmak mutfağı sipariş göremez hâle
 * getirir. Bu yüzden imza dört şeyi birden kapsıyor:
 *
 *     METOT \n YOL \n ZAMAN \n NONCE \n sha256(gövde)
 *
 * - **Metot ve yol**: `POST .../revoke` imzası `GET .../devices` olarak
 *   yeniden kullanılamaz. Yalnız gövde imzalansaydı, boş gövdeli iki
 *   farklı uç aynı imzayı paylaşırdı — ki iptal ucunun gövdesi boş.
 * - **Zaman**: ±[self::WINDOW_SECONDS] saniyelik pencere.
 * - **Nonce**: pencerenin iki katı kadar önbellekte tutulur; aynı nonce
 *   ikinci kez kabul edilmez. Tek başına zaman penceresi yetmez — pencere
 *   içinde tekrar oynatmak hâlâ mümkün olurdu.
 *
 * Nonce deposu `Cache`: sunucu tek düğüm (Coolify, tek konteyner) ve
 * kalıcı bir tablo açmak, her istekte bir yazma daha demekti. Önbellek
 * uçarsa en kötü ihtimalle pencere kadar bir tekrar penceresi açılır.
 */
class VerifyControlSignature
{
    /** İstek bu kadar eski/ileri olabilir. Saat kayması payı dâhil. */
    public const int WINDOW_SECONDS = 300;

    /**
     * Nonce bu kadar hatırlanır — pencerenin iki katı.
     *
     * Pencere kadar tutmak yetmez: pencerenin son saniyesinde imzalanmış
     * bir istek, unutulduktan sonra hâlâ zaman denetiminden geçebilirdi.
     */
    public const int NONCE_TTL_SECONDS = self::WINDOW_SECONDS * 2;

    public function handle(Request $request, Closure $next): Response
    {
        $secret = (string) env('BLD_CONTROL_SECRET', '');

        // SIR TANIMLI DEĞİLSE UÇ KAPALIDIR. `bbd.signature` ile aynı
        // gerekçe: boş sırla imza doğrulamak herkesin geçtiği bir kapıdır.
        if ($secret === '') {
            return $this->reject('Kontrol Merkezi entegrasyonu yapılandırılmamış.');
        }

        $timestamp = (string) $request->header('X-Control-Timestamp', '');
        $nonce = (string) $request->header('X-Control-Nonce', '');
        $provided = (string) $request->header('X-Control-Signature', '');

        if ($timestamp === '' || $nonce === '' || $provided === '') {
            return $this->reject('İmza başlıkları eksik.');
        }

        // Nonce uzunluk sınırı: önbellek anahtarını şişiren bir istemci
        // deposu doldurabilirdi. 16-128 karakter, rastgele hex için bol.
        $length = strlen($nonce);
        if ($length < 16 || $length > 128) {
            return $this->reject('İmza doğrulanamadı.');
        }

        if (!ctype_digit($timestamp)) {
            return $this->reject('İmza doğrulanamadı.');
        }

        if (abs(time() - (int) $timestamp) > self::WINDOW_SECONDS) {
            return $this->reject('İstek zaman penceresinin dışında.');
        }

        // ÖNCE İMZA, SONRA NONCE. Tersi olsaydı imzasız bir istemci
        // rastgele nonce'lar göndererek meşru istemcinin nonce'unu
        // "kullanılmış" işaretleyip onu kilitleyebilirdi.
        $canonical = implode("\n", [
            strtoupper($request->getMethod()),
            // Sorgu dizesi HARİÇ yol: Laravel `?` sonrasını ayrı taşıyor ve
            // iki taraf sıralamayı tutturamazdı. Süzgeçler yalnız okuma
            // uçlarında kullanılıyor; yazma uçlarının tamamı gövdeli.
            '/'.ltrim($request->getPathInfo(), '/'),
            $timestamp,
            $nonce,
            hash('sha256', $request->getContent()),
        ]);

        $expected = 'sha256='.hash_hmac('sha256', $canonical, $secret);

        if (!hash_equals($expected, $provided)) {
            return $this->reject('İmza doğrulanamadı.');
        }

        $key = 'bld:control:nonce:'.hash('sha256', $nonce);

        // `add` atomiktir: aynı nonce ile eşzamanlı iki istek gelirse
        // yalnız biri geçer. `has` + `put` ikilisi arada yarış bırakırdı.
        if (!Cache::add($key, true, self::NONCE_TTL_SECONDS)) {
            return $this->reject('Bu istek daha önce işlendi.');
        }

        return $next($request);
    }

    private function reject(string $message): JsonResponse
    {
        // Sözleşmedeki hata biçimi (`docs/03` §1.3). Hangi sebepten
        // reddedildiği `bbd.signature`'ın aksine AYRILIYOR: bu uç bir
        // saldırgana değil, bakımını yaptığımız tek bir istemciye
        // hizmet ediyor ve "saat kaymış" ile "sır yanlış" ayrımı
        // olmadan sahada teşhis imkânsız. Yine de sırra dair hiçbir
        // şey sızmıyor — mesajların hiçbiri sırrın varlığını ya da
        // uzunluğunu ele vermiyor.
        return new JsonResponse([
            'error' => [
                'code' => 'UNAUTHENTICATED',
                'message' => $message,
                'details' => new \stdClass(),
            ],
        ], 401);
    }
}
