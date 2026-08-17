<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Throwable;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Models\ErrorEvent;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * İstemci hata bildirimi — `POST /api/client-errors` (`docs/openapi.yaml`).
 *
 * ─────────────────────────────────────────────────────────────────────────
 * `source` GÖVDEDEN OKUNMAZ, `X-App-Id` BAŞLIĞINDAN TÜRETİLİR.
 *
 * Gövdeye bırakılsaydı web sitesi (ya da adresi bilen herhangi biri)
 * `mutfakapp` yazan bir rapor üretebilir ve mutfağın güvendiği hata
 * monitörüne sahte KDS alarmı düşürebilirdi. O monitör sahada "kasada bir
 * sorun var mı" sorusunun TEK cevabı; zehirlendiğinde mutfak kör kalır ve
 * gerçek bir yazıcı arızası sahte alarmların arasında kaybolur.
 *
 * Gövdede `source` gelirse SESSİZCE YOK SAYILIR — istek reddedilmez.
 * Reddetmek, eski bir istemci sürümünün bütün hata raporlarını kaybetmek
 * olurdu.
 * ─────────────────────────────────────────────────────────────────────────
 *
 * ## YANIT HER ZAMAN 204
 *
 * Doğrulama hatası bile dönmez. Bu ucun bir hata döndürmesi, hata
 * bildirmeye çalışan istemcinin İKİNCİ bir hata üretmesi demektir ve
 * kendini besleyen bir döngü doğar: hata → rapor → 422 → hata → rapor…
 * Ayrıştırılamayan alanlar boş bırakılır, sınırı aşan metin kesilir, rapor
 * yine kaydedilir. Tek istisna oran sınırı (`bld-hata`); onu da yönlendirici
 * uyguluyor ve sözleşme istemciye "429'da sessizce düş" diyor.
 *
 * ## KİMLİK OPSİYONEL
 *
 * Rota müşteri kapsamının DIŞINDA. Hataların önemli bir kısmı tam da
 * oturum açılamadığı için doğuyor; orada token istemek, en çok ihtiyaç
 * duyulan kaydı kaybettirirdi. Token varsa rapor müşteriye bağlanır
 * (`context.customer_id`).
 */
class ClientErrorController extends ApiController
{
    /**
     * Tek istekte kabul edilen en fazla olay.
     *
     * Toplu gönderim ŞART: çevrimdışı kalan bir istemci hataları
     * biriktirir ve bağlantı gelince hepsini birden yollar. Tavan da şart:
     * tavansız bir toplu uç, tek istekle on bin satır yazdırıp oran
     * sınırını anlamsız kılardı. AŞAN OLAYLAR REDDEDİLMEZ, ilk 20'si
     * alınır — 21. olay yüzünden ilk 20'yi de kaybetmek en kötü sonuç.
     */
    private const int MAX_EVENTS = 20;

    /** `context` için tavan (sözleşme: en çok 8 KB). */
    private const int CONTEXT_LIMIT = 8000;

    private const int ROUTE_LIMIT = 200;

    private const int DEVICE_LIMIT = 120;

    private const int BUILD_LIMIT = 40;

    /**
     * Metot adı ROTA DOSYASINDAN gelir (`routes/api.php`: `store`). Rota
     * ile denetleyici arasındaki ad ayrışması ne açılışta ne `route:list`
     * ile görünür; yalnız uç çağrılınca patlar.
     */
    public function store(Request $request): JsonResponse
    {
        $source = self::sourceFrom((string) $request->header('X-App-Id'));
        $customerId = $this->customerId($request);

        foreach ($this->eventsFrom($request) as $event) {
            $this->record($source, $customerId, $event);
        }

        return $this->noContent();
    }

    /**
     * Gövdeden olay listesini çıkarır.
     *
     * İKİ BİÇİM DE KABUL EDİLİR: sözleşmedeki tek nesne ve `events` dizisi.
     * Tek biçim dayatmak, çevrimdışı biriktiren istemciyi her hata için
     * ayrı istek atmaya zorlardı — bağlantı gelince yüz istek, oran sınırı
     * ve kaybolan raporlar.
     *
     * @return list<array<string, mixed>>
     */
    private function eventsFrom(Request $request): array
    {
        $batch = $request->input('events');

        $events = is_array($batch) ? $batch : [$request->all()];

        return array_values(array_filter(
            array_slice($events, 0, self::MAX_EVENTS),
            static fn(mixed $event): bool => is_array($event),
        ));
    }

    /** @param array<string, mixed> $event */
    private function record(string $source, ?int $customerId, array $event): void
    {
        $message = self::text($event['message'] ?? null, ErrorEvent::MESSAGE_LIMIT);

        /*
         * MESAJSIZ RAPOR SESSİZCE DÜŞER — 422 DEĞİL.
         *
         * Mesajı olmayan bir satır monitörde okunamaz ve hiçbir şey
         * anlatmaz; onu kaydetmek tabloyu boş satırlarla doldurmaktan
         * ibaret. Reddetmek ise sözleşmenin "yanıt her zaman 204" kuralını
         * çiğner ve istemcide ikinci bir hata doğururdu.
         */
        if ($message === null) {
            return;
        }

        $type = self::text($event['kind'] ?? null, ErrorEvent::TYPE_LIMIT);

        try {
            ErrorEvent::record(
                source: $source,
                level: self::levelFor($type),
                type: $type,
                message: $message,
                stack: self::text($event['stack'] ?? null, ErrorEvent::STACK_LIMIT),
                context: $this->contextFrom($event, $customerId),
                occurredAt: self::moment($event['occurred_at'] ?? null),
            );
        } catch (Throwable $e) {
            /*
             * HATA KAYDEDİLEMEDİ — İSTEK YİNE 204.
             *
             * Bu ucun 500 dönmesi, hata bildirmeye çalışan istemcide
             * yeni bir hata doğurur ve döngü kapanır. Sunucu tarafındaki
             * arıza `report()` ile günlüğe düşer; istemcinin bilmesi
             * gereken bir şey değil.
             */
            report($e);
        }
    }

    /**
     * Raporun bağlamı: sözleşmedeki yan alanlar + istemcinin serbest
     * `context` nesnesi.
     *
     * `route`, `app_build` ve `device` neden AYRI KOLON DEĞİL: üç
     * bileşenin üçü de farklı şeyler biliyor (tarayıcı dizesi, Android
     * sürümü, kasa modeli) ve hepsini kolona açmak çoğu satırda boş duran
     * bir tablo demekti.
     *
     * @param array<string, mixed> $event
     * @return array<string, mixed>|null
     */
    private function contextFrom(array $event, ?int $customerId): ?array
    {
        $context = array_filter([
            // Sorgu dizesi TAŞINMAZ: adres çubuğundaki parametreler zaman
            // zaman kişisel veri taşır ve hata kaydı onları saklamak için
            // yanlış yer. Sözleşme istemciden zaten sorgusuz yol bekliyor;
            // yine de gelirse burada kesiliyor.
            'route' => self::pathOnly(self::text($event['route'] ?? null, self::ROUTE_LIMIT)),
            'app_build' => self::text($event['app_build'] ?? null, self::BUILD_LIMIT),
            'device' => self::text($event['device'] ?? null, self::DEVICE_LIMIT),
            'customer_id' => $customerId,
        ], static fn(mixed $value): bool => $value !== null);

        $client = $event['context'] ?? null;

        if (is_array($client) && $client !== []) {
            $encoded = json_encode($client, JSON_UNESCAPED_UNICODE);

            /*
             * TAVANI AŞAN BAĞLAM ATILIR, RAPOR KALIR. Sekiz kilobaytlık
             * sınır tabloyu koruyor; onu aşan bir bağlam yüzünden hatanın
             * kendisini kaybetmek, korumayı amacının tersine çevirirdi.
             * İşaret bırakılıyor ki panelde "bağlam neden boş" sorusu
             * cevapsız kalmasın.
             */
            $context['client'] = $encoded !== false && strlen($encoded) <= self::CONTEXT_LIMIT
                ? $client
                : ['_truncated' => true];
        }

        return $context === [] ? null : $context;
    }

    /**
     * `X-App-Id` → monitör kaynağı.
     *
     * İki ad kümesi AYRI: başlık uygulamayı adlandırıyor (`mutfakapp`),
     * monitör bileşeni adlandırıyor (`kds`). Aynı olsalardı, kasa
     * uygulamasının adı değiştiği gün monitördeki bütün geçmiş satırlar
     * bilinmeyen bir kaynağa düşerdi.
     */
    public static function sourceFrom(string $appId): string
    {
        return match ($appId) {
            'mutfakapp' => ErrorEvent::SOURCE_KDS,
            'musteriapp' => ErrorEvent::SOURCE_MOBILE,
            'website' => ErrorEvent::SOURCE_WEBSITE,
            // Buraya düşmek için başlık doğrulamasını (`bld.headers`)
            // atlatmak gerekir; yani olay bizim tarafımızdaki bir
            // arızadır ve sunucuya yazılması doğrudur.
            default => ErrorEvent::SOURCE_SERVER,
        };
    }

    /**
     * Seviye TÜRDEN türetilir, gövdeden okunmaz.
     *
     * `network` UYARI, HATA DEĞİL: istemcinin isteği başarısız oldu ve
     * bunun en yaygın sebebi müşterinin bağlantısı — bizim kodumuz değil.
     * Hepsini `error` saymak, monitörün kırmızı sayacını metroda tünele
     * giren telefonlarla doldurur ve gerçek çökmeleri görünmez kılardı.
     */
    private static function levelFor(?string $type): string
    {
        return $type === 'network' ? ErrorEvent::LEVEL_WARNING : ErrorEvent::LEVEL_ERROR;
    }

    /**
     * Token varsa müşteri kimliği, yoksa `null`.
     *
     * Kimlik doğrulama bu rotada ÇALIŞMIYOR (`bld.auth` yok); Sanctum'un
     * guard'ı elle sorulmuyor da. `$request->user()` yalnızca başka bir
     * ara katman kullanıcıyı çözdüyse dolu döner — burada normalde `null`
     * olur ve bu beklenen hâldir.
     */
    private function customerId(Request $request): ?int
    {
        $user = $request->user();

        return $user instanceof ApiCustomer ? (int) $user->getKey() : null;
    }

    /**
     * Metin alanı: kırpar, boşu `null` yapar, SINIRDA KESER.
     *
     * Dizi/nesne gelirse `null` döner — düzleştirmeye çalışmak "Array to
     * string conversion" ile 500 üretir ve rapor kaybolurdu.
     */
    private static function text(mixed $value, int $limit): ?string
    {
        if (is_bool($value) || (!is_string($value) && !is_numeric($value))) {
            return null;
        }

        $trimmed = trim((string) $value);

        return $trimmed === '' ? null : mb_substr($trimmed, 0, $limit);
    }

    /** Sorgu dizesini ve çapayı atar; kişisel veri hata kaydında durmamalı. */
    private static function pathOnly(?string $route): ?string
    {
        if ($route === null) {
            return null;
        }

        $path = trim((string) preg_replace('/[?#].*$/', '', $route));

        return $path === '' ? null : $path;
    }

    /**
     * İstemcinin bildirdiği an; çözümlenemezse `null`.
     *
     * `Carbon::parse` geçersiz metinde istisna atar; yakalanmasaydı
     * saatini yanlış biçimde gönderen bir istemci sürümü BÜTÜN hata
     * raporlarını kaybederdi.
     *
     * `BusinessTime::forStorage` ŞART: Eloquent bir `datetime` alanını
     * yazarken Carbon'un kendi zaman dilimini, okurken PHP varsayılanını
     * kullanıyor ve damga üç saat kayardı.
     */
    private static function moment(mixed $value): ?Carbon
    {
        if (!is_string($value) || trim($value) === '') {
            return null;
        }

        try {
            return BusinessTime::forStorage(Carbon::parse($value));
        } catch (Throwable) {
            return null;
        }
    }
}
