<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services\Geocoding;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Veykemtu\BridgeApi\Services\ServiceArea;
use Veykemtu\BridgeApi\Support\TurkishText;

/**
 * Adres önerisi ve ters geocoding — B-21, `docs/openapi.yaml` §Adresler.
 *
 * Sürücünün üstündeki UYGULAMA katmanı. Üç işi var ve üçü de sürücüden
 * bağımsız olmak zorunda (yarın Google Places'e geçildiğinde yeniden
 * yazılmasınlar):
 *
 *   1. **Hizmet alanı elemesi.** Kutu dışındaki aday yanıttan DÜŞÜRÜLÜR,
 *      "teslimat yok" diye işaretlenip gösterilmez. Müşteriye seçebileceğini
 *      sandığı bir satır gösterip ödeme ekranında reddetmek, o satırı hiç
 *      göstermemekten daha kötüdür.
 *   2. **Önbellek.** Aynı sorgu 24 saat sağlayıcıya bir kez gider.
 *   3. **Arıza yutma.** Sağlayıcı çökerse boş sonuç + günlük kaydı; istisna
 *      yukarı SIZMAZ. Öneri bir kolaylıktır, adres elle de yazılabiliyor;
 *      dışarıdaki bir servis kendi sipariş akışımızı durduramaz.
 */
class AddressLookup
{
    /**
     * Sözleşmedeki en kısa sorgu. Tek harfe geocoder çağırmak sağlayıcı
     * kotasını "k", "ka" gibi hiçbir şey ayırt etmeyen sorgularla yakar ve
     * önbelleği de aynı çöple doldurur.
     */
    public const int MIN_QUERY_LENGTH = 3;

    public const int MAX_QUERY_LENGTH = 120;

    public const int DEFAULT_LIMIT = 5;

    public const int MAX_LIMIT = 10;

    /**
     * Önbellek ömürleri — `docs/03` §13.5.
     *
     * ÜÇÜ FARKLI ve farkları gerekçeli:
     *
     *   - `suggest` **24 saat**: yeni açılan sokakları ve yeni numaralanan
     *     binaları görmesi gerekiyor, bir gün yeterince kısa.
     *   - `reverse` **30 gün**: var olan bir noktanın adını soruyor ve o ad
     *     ay içinde değişmiyor.
     *   - Eşleşme bulunamayan sorgu **1 saat**: yazılmasaydı aynı yazım
     *     hatası her tekrarında sağlayıcıya giderdi; uzun yazılsaydı yeni
     *     eklenen bir sokak günlerce "yok" görünürdü.
     *
     * Sağlayıcı ARIZASI hiç yazılmaz — 30 saniyelik bir kesinti, önbellek
     * ömrü boyunca donmuş bir "sonuç yok" hâline dönerdi.
     */
    private const int TTL_SUGGEST = 86400;

    private const int TTL_REVERSE = 2592000;

    private const int TTL_EMPTY = 3600;

    /**
     * Ters geocoding önbellek anahtarında koordinat kaç haneye yuvarlanır.
     *
     * 4 hane ≈ 11 metre. Tam koordinatla anahtarlamak önbelleği fiilen
     * kapatırdı: haritada iğneyi bir piksel oynatmak yeni bir anahtar üretir.
     * 11 metrelik bir kutu içinde sağlayıcının döndüreceği SOKAK METNİ
     * zaten aynı — ve yanıttaki koordinat nasılsa isteğin kendi noktasıyla
     * değiştiriliyor, yuvarlama iğneyi kaydırmıyor.
     */
    private const int REVERSE_PRECISION = 4;

    public function __construct(private readonly Geocoder $geocoder) {}

    /**
     * Serbest metinden öneri listesi.
     *
     * @return list<array<string, mixed>> Sözleşmedeki `AddressSuggestion` listesi.
     */
    public function suggest(string $query, int $limit = self::DEFAULT_LIMIT): array
    {
        $query = trim(preg_replace('/\s+/u', ' ', $query) ?? '');
        $limit = max(1, min($limit, self::MAX_LIMIT));

        if (mb_strlen($query) < self::MIN_QUERY_LENGTH) {
            return [];
        }

        // Normalizasyon TÜRKÇEYE DUYARLI küçültmeyle: `mb_strtolower` `I`'yı
        // `i`'ye düşürür ve "İSTASYON" ile "istasyon" iki ayrı önbellek
        // satırı açar — ikisi de sağlayıcıya gider.
        $key = $this->key('suggest', TurkishText::lower($query));
        $cached = Cache::get($key);

        if (is_array($cached)) {
            return array_slice($cached, 0, $limit);
        }

        try {
            /*
             * SAĞLAYICIYA HER ZAMAN ÜST SINIR KADAR SORULUYOR, istemcinin
             * istediği kadar değil.
             *
             * `docs/03` §13.5 anahtarı "sürücü + normalize `q` + `limit`"
             * diye tarif ediyor; `limit` BİLEREK KONMADI. Konsaydı aynı metin
             * 5'lik ve 10'luk iki ayrı satır olarak önbelleğe düşer ve
             * sağlayıcıya iki kez gidilirdi — oysa 10 sonuç 5'i zaten
             * kapsıyor ve bölümün amacı tam olarak kota korumak. Kırpma
             * okuma tarafında yapılıyor; dışarıdan görünen davranış aynı.
             */
            $candidates = $this->geocoder->suggest($query, self::MAX_LIMIT);
        } catch (GeocoderUnavailable $e) {
            $this->reportOutage('suggest', $e);

            // ÖNBELLEĞE YAZILMIYOR: arızayı 24 saat saklamak, sağlayıcı
            // ayağa kalktıktan sonra da öneri vermemek demek olurdu.
            return [];
        }

        $payload = [];

        foreach ($candidates as $candidate) {
            $inArea = $this->inServiceArea($candidate);

            if ($inArea === null) {
                continue;
            }

            $row = $inArea->toArray();

            // Aynı sokak Nominatim'de hem yol (`way`) hem sınır (`relation`)
            // olarak durabiliyor ve liste birebir aynı iki satır gösteriyor.
            // Kullanıcı için ikisi de aynı yer; ikinci satır yalnızca
            // güveni sarsıyor.
            if (isset($payload[$row['label']])) {
                continue;
            }

            $payload[$row['label']] = $row;
        }

        $payload = array_values($payload);

        // BOŞ SONUÇ DA ÖNBELLEĞE GİRER — ama KISA ömürle. Yazılmasaydı
        // yanlış yazılmış bir mahalle adı her tuşta sağlayıcıya yeniden
        // sorulurdu; uzun yazılsaydı yeni eklenen bir sokak bir gün boyunca
        // "yok" görünürdü.
        Cache::put($key, $payload, $payload === [] ? self::TTL_EMPTY : self::TTL_SUGGEST);

        return array_slice($payload, 0, $limit);
    }

    /**
     * Koordinattan adres.
     *
     * Kutu denetimi ÇAĞIRANIN işi (`AddressController` 422 döndürüyor);
     * buraya gelen nokta hizmet alanının içindedir. Yine de sağlayıcının
     * döndürdüğü ilçe hizmet alanında değilse `null` dönüyoruz: sözleşme
     * `AddressSuggestion.district` için "her zaman hizmet alanındaki
     * ilçelerden biri" diyor ve kutu, üç ilçeyi birden içine alan kaba bir
     * dikdörtgen.
     *
     * @return array<string, mixed>|null
     */
    public function reverse(float $latitude, float $longitude): ?array
    {
        $key = $this->key('reverse', implode(',', [
            number_format($latitude, self::REVERSE_PRECISION, '.', ''),
            number_format($longitude, self::REVERSE_PRECISION, '.', ''),
        ]));

        $cached = Cache::get($key);

        if (is_array($cached)) {
            // Boş dizi = "sağlayıcı burayı bilmiyor". `null`'ı doğrudan
            // önbelleğe yazsaydık `Cache::get` onu ISKA'dan ayırt edemez ve
            // bilinmeyen her nokta her seferinde sağlayıcıya sorulurdu.
            return $cached === [] ? null : $this->atRequestedPoint($cached, $latitude, $longitude);
        }

        try {
            $candidate = $this->geocoder->reverse($latitude, $longitude);
        } catch (GeocoderUnavailable $e) {
            $this->reportOutage('reverse', $e);

            return null;
        }

        $inArea = $candidate === null ? null : $this->inServiceArea($candidate);
        $payload = $inArea?->toArray() ?? [];

        Cache::put($key, $payload, $payload === [] ? self::TTL_EMPTY : self::TTL_REVERSE);

        return $payload === [] ? null : $this->atRequestedPoint($payload, $latitude, $longitude);
    }

    /**
     * Hizmet alanı kilidi — kutu VE ilçe/il adı.
     *
     * İkisi birden gerekiyor: kutu (37.80–38.10 / 32.35–32.75) Selçuklu ve
     * Karatay'ın yanında Meram'ı da içine alan kaba bir dikdörtgen, ilçe adı
     * ise sağlayıcıdan serbest metin geliyor. Yalnız kutuya bakılsaydı
     * Meram'daki bir adres öneri listesine girer, müşteri seçer ve ödeme
     * ekranında `ServiceArea::districtRule()` tarafından reddedilirdi.
     */
    private function inServiceArea(AddressCandidate $candidate): ?AddressCandidate
    {
        if (!ServiceArea::containsPoint($candidate->latitude, $candidate->longitude)) {
            return null;
        }

        $district = ServiceArea::canonicalDistrict($candidate->district);
        $city = ServiceArea::canonicalCity($candidate->city);

        if ($district === null || $city === null) {
            return null;
        }

        return $candidate->inServiceArea($district, $city);
    }

    /**
     * @param  array<string, mixed>  $payload
     * @return array<string, mixed>
     */
    private function atRequestedPoint(array $payload, float $latitude, float $longitude): array
    {
        // Sözleşme: ters geocoding yanıtındaki nokta İSTEĞİN KENDİ noktası.
        // Sağlayıcının oturttuğu (snap) nokta yazılsaydı iğne kullanıcının
        // parmağının altından kayardı — kapıyı müşteri biliyor.
        $payload['latitude'] = $latitude;
        $payload['longitude'] = $longitude;

        return $payload;
    }

    private function key(string $kind, string $value): string
    {
        // Sürücü adı anahtarın içinde: Google Places'e geçildiğinde eski
        // sürücünün önbelleği kendiliğinden devre dışı kalır. Olmasaydı
        // geçişten sonra 24 saat boyunca Nominatim cevapları servis
        // edilirdi ve "yeni sağlayıcı da aynı sonucu veriyor" sanılırdı.
        return 'bld:geo:'.$this->geocoder->name().':'.$kind.':'.sha1($value);
    }

    private function reportOutage(string $kind, GeocoderUnavailable $e): void
    {
        /*
         * Kullanıcı boş liste görüyor ve iki durumu ayırt etmiyor: "adres
         * yok" ile "öneri veremiyoruz". AYRIM BURADA YAZILI KALIYOR —
         * yazılmasaydı çöken bir sağlayıcı haftalarca fark edilmezdi.
         *
         * ARANAN METİN GÜNLÜĞE YAZILMAZ (`docs/03` §13.5): adres aramaları
         * KVKK kapsamında kişisel veri ve uygulama günlükleri sipariş
         * verisiyle aynı saklama kurallarına tabi değil. Teşhis için
         * gereken şey zaten sorgunun kendisi değil, hangi sürücünün ne
         * hatasıyla düştüğü.
         */
        Log::warning('Geocoder arızası — öneri verilemedi.', [
            'driver' => $this->geocoder->name(),
            'kind' => $kind,
            // Asıl sınıf sarmalayıcının altında: `ConnectionException` ile
            // `RequestException` sahada bambaşka iki arızadır (ağ / kota).
            'exception' => ($e->getPrevious() ?? $e)::class,
            'message' => $e->getMessage(),
        ]);
    }
}
