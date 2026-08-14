<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services\Geocoding;

use Override;

/**
 * Ağa çıkmayan sürücü — testler ve ağsız geliştirme için.
 *
 * NEDEN `src/` ALTINDA, `tests/` ALTINDA DEĞİL: iki tüketicisi var.
 * Testler bunu konteynere bağlıyor (`Http::fake()` yerine: sahte HTTP
 * yanıtı yazmak Nominatim'in gövde biçimini teste kopyalar ve sürücü
 * değiştiği gün testler sağlayıcıya göre yeniden yazılmak zorunda kalır —
 * oysa doğrulanan şey UYGULAMA davranışı: eleme, önbellek, hata yutma).
 * İkincisi, `GEOCODER_URL=fake` ile ağsız bir makinede paneli ve akışı
 * çalıştırmak.
 *
 * Sınıf `final` DEĞİL: bir testin tek bir davranışı değiştirmek için
 * türetmesi, buraya bayrak eklemekten temiz.
 */
class FakeGeocoder implements Geocoder
{
    public const string SOURCE = 'fake';

    /** Kaç kez sağlayıcıya gidildi — önbellek testleri bunu okuyor. */
    public int $suggestCalls = 0;

    public int $reverseCalls = 0;

    /** @var list<AddressCandidate> */
    private array $results = [];

    private ?AddressCandidate $reverseResult = null;

    /** Açıkken her çağrı `GeocoderUnavailable` fırlatır — sağlayıcı çöküşü. */
    private bool $broken = false;

    /** @param list<AddressCandidate> $results */
    public function willReturn(array $results): self
    {
        $this->results = $results;

        return $this;
    }

    public function willReverseTo(?AddressCandidate $candidate): self
    {
        $this->reverseResult = $candidate;

        return $this;
    }

    public function breakDown(bool $broken = true): self
    {
        $this->broken = $broken;

        return $this;
    }

    #[Override]
    public function name(): string
    {
        return self::SOURCE;
    }

    #[Override]
    public function suggest(string $query, int $limit): array
    {
        $this->suggestCalls++;
        $this->assertHealthy();

        return array_slice($this->results, 0, $limit);
    }

    #[Override]
    public function reverse(float $latitude, float $longitude): ?AddressCandidate
    {
        $this->reverseCalls++;
        $this->assertHealthy();

        return $this->reverseResult;
    }

    /**
     * Kolaylık kurucu: testler alan alan `AddressCandidate` yazmasın.
     *
     * Varsayılan nokta hizmet alanı kutusunun İÇİNDE (Konya / Selçuklu);
     * kutu dışını sınayan test koordinatı açıkça verir.
     */
    public static function candidate(
        ?string $neighbourhood = 'Feritpaşa Mah.',
        ?string $street = 'Kültür Sk.',
        ?string $buildingNo = '12',
        ?string $district = 'Selçuklu',
        ?string $city = 'Konya',
        float $latitude = 37.8851832,
        float $longitude = 32.4898714,
        string $source = self::SOURCE,
    ): AddressCandidate {
        return new AddressCandidate(
            source: $source,
            latitude: $latitude,
            longitude: $longitude,
            neighbourhood: $neighbourhood,
            street: $street,
            buildingNo: $buildingNo,
            district: $district,
            city: $city,
        );
    }

    private function assertHealthy(): void
    {
        if ($this->broken) {
            throw new GeocoderUnavailable('Sahte sürücü bilerek çökertildi.');
        }
    }
}
