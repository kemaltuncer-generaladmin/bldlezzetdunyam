<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services\Geocoding;

use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\RateLimiter;
use Override;
use Throwable;
use Veykemtu\BridgeApi\Services\ServiceArea;

/**
 * OpenStreetMap / Nominatim sürücüsü — B-21.
 *
 * NEDEN NOMINATIM: anahtar istemiyor, faturası yok ve Konya'da mahalle +
 * sokak kapsaması yeterli. Google Places daha iyi eşleşiyor ama bir
 * sözleşme, bir fatura ve bir gizli anahtar demek; öneri gibi bir kolaylık
 * için sipariş akışını o kuruluma bağlamak yanlış sıralama olurdu
 * (`docs/11-yol-haritasi.md` §F2-01 geçişi planlıyor — `Geocoder` arayüzü
 * o gün için duruyor).
 *
 * ## KULLANIM ŞARTLARI — silmeden önce oku
 *
 * Nominatim'in genel sunucusu (`nominatim.openstreetmap.org`) saniyede **1
 * istek** ve **kimliklendirilmiş User-Agent** şart koşuyor; ikisinden biri
 * ihlal edildiğinde IP engelleniyor ve ENGEL SESSİZ OLUYOR — öneri kutusu
 * boş açılıyor, hata yok, sebep yok.
 *
 *   - `User-Agent` `GEOCODER_USER_AGENT` ile kuruluyor ve içinde bir iletişim
 *     adresi taşıyor (şart tam olarak bunu istiyor).
 *   - Saniyede 1 istek kapısı `call()` içinde, SUNUCU GENELİNDE. Hesap başına
 *     `bld-adres` sınırı bunu karşılamaz: yirmi müşteri aynı anda yazarken
 *     hiçbirinin sınırı dolmaz ama sağlayıcıya saniyede yirmi istek gider.
 *   - Yük ayrıca `AddressLookup`'taki önbellekle tutuluyor.
 *   - Trafik büyüdüğünde doğru hamle sınırı yükseltmek değil,
 *     `GEOCODER_BASE_URL` ile kendi Nominatim örneğimize geçmek.
 *
 * ## Yanıttan alan çıkarma — Türkiye'ye özgü tuzak
 *
 * Konya için gerçek yanıt (13.08.2026'da ölçüldü):
 *
 *   {"suburb":"Feritpaşa Mahallesi","city":"Konya","town":"Selçuklu",
 *    "province":"Konya", ...}
 *
 * Yani MAHALLE `suburb`'te, İLÇE `town`'da ve `city` büyükşehrin kendisi.
 * "city = şehir, suburb = ilçe" diye okuyan sezgisel eşleme burada tam ters
 * sonuç verir: her öneri "Feritpaşa Mahallesi" ilçesine düşer, hizmet alanı
 * elemesinden geçemez ve liste hep boş görünür. Anahtar sıraları bu yüzden
 * ölçülmüş değerlere göre yazıldı, tahminle değil.
 */
final class NominatimGeocoder implements Geocoder
{
    public const string SOURCE = 'osm_nominatim';

    /**
     * Zaman aşımları KISA.
     *
     * Bu uç bir metin kutusunun altında açılıyor: 10 saniye bekleyen bir
     * öneri listesi, hiç açılmayan bir listeden daha kötüdür — kullanıcı o
     * sırada zaten yazmaya devam etmiştir. Ayrıca yeniden deneme YOK:
     * `retry(2)` gecikmeyi ikiye katlar ve elde edilen şey yalnızca bir
     * kolaylık.
     */
    private const int TIMEOUT_SECONDS = 4;

    private const int CONNECT_TIMEOUT_SECONDS = 2;

    /**
     * Nominatim politikası: SUNUCU GENELİNDE saniyede en fazla 1 istek.
     *
     * Sınır hesap başına oran sınırının (`bld-adres`, 30/dk) ÜSTÜNDE ayrı
     * bir kapı: yirmi müşteri aynı anda yazarken hesap sınırlarının hiçbiri
     * dolmaz ama sağlayıcıya saniyede yirmi istek gider ve IP'miz engellenir.
     */
    private const string GATE_KEY = 'bld:geo:nominatim-gate';

    public function __construct(
        private readonly string $baseUrl,
        private readonly string $userAgent,
    ) {}

    #[Override]
    public function name(): string
    {
        return self::SOURCE;
    }

    #[Override]
    public function suggest(string $query, int $limit): array
    {
        $payload = $this->call('search', [
            'q' => $query,
            'format' => 'jsonv2',
            'addressdetails' => 1,
            'limit' => $limit,
            // Ülke kilidi + kutu kilidi: sağlayıcıya baştan dar bir alan
            // vermek, elemeyi bize bırakmaktan ucuz. `bounded=1` olmadan
            // `viewbox` yalnızca SIRALAMAYI etkiler, sonucu daraltmaz.
            'countrycodes' => 'tr',
            'bounded' => 1,
            'viewbox' => implode(',', [
                ServiceArea::WEST,
                ServiceArea::NORTH,
                ServiceArea::EAST,
                ServiceArea::SOUTH,
            ]),
            'accept-language' => 'tr',
        ]);

        if (!is_array($payload)) {
            throw new GeocoderUnavailable('Nominatim beklenmeyen bir gövde döndü.');
        }

        $candidates = [];

        foreach ($payload as $row) {
            $candidate = is_array($row) ? $this->candidate($row) : null;

            if ($candidate !== null) {
                $candidates[] = $candidate;
            }
        }

        return $candidates;
    }

    #[Override]
    public function reverse(float $latitude, float $longitude): ?AddressCandidate
    {
        $payload = $this->call('reverse', [
            'lat' => $latitude,
            'lon' => $longitude,
            'format' => 'jsonv2',
            'addressdetails' => 1,
            // zoom=18 bina/sokak seviyesi. Daha küçük bir değer mahalleyi
            // döndürür ve sokak adı hiç gelmez.
            'zoom' => 18,
            'accept-language' => 'tr',
        ]);

        if (!is_array($payload)) {
            throw new GeocoderUnavailable('Nominatim beklenmeyen bir gövde döndü.');
        }

        // Sağlayıcı bilmediği noktada `{"error": "Unable to geocode"}` döner —
        // HTTP 200 ile. Bu bir ARIZA DEĞİL, bir cevaptır: arazi, yeni açılmış
        // yol. `null` dönüyoruz ki istemci iğneyi korusun ve alanları elle
        // doldurtsun.
        if (isset($payload['error'])) {
            return null;
        }

        return $this->candidate($payload);
    }

    /**
     * @param  array<string, mixed>  $query
     * @return array<mixed>|null
     *
     * @throws GeocoderUnavailable
     */
    private function call(string $path, array $query): ?array
    {
        /*
         * Slot alamayan istek BEKLEMEZ, arıza yoluna düşer ve çağıran boş
         * sonuç döndürür (`docs/03` §13.5). Müşteriyi öneri listesi için
         * bekletmek, öneriyi hiç vermemekten kötüdür — üstelik bekleyen
         * istekler php-fpm işçilerini tutar ve yoğun bir dakikada bütün
         * API'yi yavaşlatır.
         */
        if (!RateLimiter::attempt(self::GATE_KEY, 1, static fn(): bool => true, 1)) {
            throw new GeocoderUnavailable('Nominatim hız kapısı dolu (saniyede 1 istek).');
        }

        try {
            $response = Http::withHeaders([
                // OSM kullanım şartı: uygulamayı tanıtan ve iletişim bilgisi
                // taşıyan bir User-Agent. Varsayılan `GuzzleHttp/7` ile
                // gönderilen istekler engelleniyor.
                'User-Agent' => $this->userAgent,
                'Accept' => 'application/json',
            ])
                ->timeout(self::TIMEOUT_SECONDS)
                ->connectTimeout(self::CONNECT_TIMEOUT_SECONDS)
                ->get(rtrim($this->baseUrl, '/').'/'.$path, $query);
        } catch (Throwable $e) {
            throw new GeocoderUnavailable('Nominatim\'e ulaşılamadı: '.$e->getMessage(), 0, $e);
        }

        return $this->decode($response);
    }

    /**
     * @return array<mixed>|null
     *
     * @throws GeocoderUnavailable
     */
    private function decode(Response $response): ?array
    {
        if (!$response->successful()) {
            throw new GeocoderUnavailable('Nominatim HTTP '.$response->status().' döndü.');
        }

        $payload = $response->json();

        // Engellenen bir istemciye Nominatim bazen 200 ile HTML bir uyarı
        // sayfası döndürüyor; `json()` o gövdede `null` verir. Sessizce boş
        // liste saymak, engellendiğimizi haftalarca gizlerdi.
        if (!is_array($payload)) {
            throw new GeocoderUnavailable('Nominatim JSON olmayan bir gövde döndü.');
        }

        return $payload;
    }

    /** @param array<mixed> $row */
    private function candidate(array $row): ?AddressCandidate
    {
        $latitude = $this->float($row['lat'] ?? null);
        $longitude = $this->float($row['lon'] ?? null);

        // Koordinatsız aday YOK SAYILIR: sözleşme öneride `latitude`/
        // `longitude` alanlarının asla null olamayacağını söylüyor ve
        // hizmet alanı elemesi de zaten koordinat üzerinden yapılıyor.
        if ($latitude === null || $longitude === null) {
            return null;
        }

        /** @var array<string, mixed> $address */
        $address = is_array($row['address'] ?? null) ? $row['address'] : [];

        return new AddressCandidate(
            source: self::SOURCE,
            latitude: $latitude,
            longitude: $longitude,
            // Sıralı geri düşme zinciri — `docs/03` §13.4'teki tablo.
            // Konya'da mahalleyi `suburb` taşıyor; ilk iki anahtar başka
            // illerdeki karşılıkları için.
            neighbourhood: $this->pick($address, ['neighbourhood', 'quarter', 'suburb']),
            street: $this->pick($address, ['road', 'pedestrian', 'residential']),
            buildingNo: $this->pick($address, ['house_number']),
            // İlçe: Konya'da `town`. `suburb` BU ZİNCİRDE YOK — orada mahalle
            // var ve eklenseydi her öneri "Feritpaşa Mahallesi" ilçesine
            // düşer, hizmet alanı elemesinden geçemez ve liste hep boş
            // görünürdü.
            district: $this->pick($address, ['town', 'city_district', 'municipality']),
            // İl: `province`. Konya'da `city` de "Konya" ama küçük illerde
            // `city` ilçe adını taşıyor; sıra bu yüzden `province` ile başlar.
            city: $this->pick($address, ['province', 'city', 'state']),
        );
    }

    /**
     * @param  array<string, mixed>  $address
     * @param  list<string>  $keys
     */
    private function pick(array $address, array $keys): ?string
    {
        foreach ($keys as $key) {
            $value = $address[$key] ?? null;

            if (is_string($value) && trim($value) !== '') {
                return trim($value);
            }
        }

        return null;
    }

    private function float(mixed $value): ?float
    {
        // Nominatim koordinatları METİN olarak veriyor ("37.8851832").
        return is_numeric($value) ? (float) $value : null;
    }
}
