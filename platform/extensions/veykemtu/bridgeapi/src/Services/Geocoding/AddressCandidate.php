<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services\Geocoding;

use Veykemtu\BridgeApi\Services\StructuredAddress;

/**
 * Geocoder'dan gelen tek bir adres adayı — `docs/openapi.yaml`
 * §AddressSuggestion.
 *
 * BU BİR KAYIT DEĞİL, ÖNERİDİR: hiçbir yerde saklanmaz ve kimliği yoktur.
 * Kimlik verilip `SavedAddress`'e bağlansaydı, sağlayıcı o kimliği
 * değiştirdiği ya da sürücü Google Places'e geçtiği gün defterdeki adresler
 * kırılırdı.
 *
 * Sürücüler bu nesneyi HAM hâliyle üretir: `district`/`city` sağlayıcının
 * yazımıyla ve `null` olabilir. Hizmet alanı elemesini ve kanonik yazıma
 * indirgemeyi `AddressLookup` yapar — sürücü "orada ne var" sorusunu,
 * uygulama "oraya gidiyor muyuz" sorusunu cevaplar ve ikisi karışmamalı:
 * karışsaydı her yeni sürücü hizmet alanı kuralını baştan uygulamak
 * zorunda kalırdı.
 */
final readonly class AddressCandidate
{
    public function __construct(
        /** Öneriyi üreten sürücü — sözleşmedeki `source`. Kapalı enum DEĞİL. */
        public string $source,
        public float $latitude,
        public float $longitude,
        public ?string $neighbourhood = null,
        public ?string $street = null,
        /**
         * Bina / dış kapı no. Sözleşmedeki `AddressSuggestion` bunu AYRI BİR
         * ALAN OLARAK TAŞIMAZ; yalnızca `line1`'in içine giriyor. Burada
         * tutuluyor ki cümleyi kuran tek yer `AddressLine` olsun.
         */
        public ?string $buildingNo = null,
        public ?string $district = null,
        public ?string $city = null,
    ) {}

    /** Hizmet alanı elemesinden geçen adayı kanonik ilçe/il yazımıyla kopyalar. */
    public function inServiceArea(string $district, string $city): self
    {
        return new self(
            source: $this->source,
            latitude: $this->latitude,
            longitude: $this->longitude,
            neighbourhood: $this->neighbourhood,
            street: $this->street,
            buildingNo: $this->buildingNo,
            district: $district,
            city: $city,
        );
    }

    /**
     * Koordinatı değiştirir — YALNIZCA ters geocoding'de kullanılır.
     *
     * Sözleşme: `/addresses/reverse` yanıtındaki nokta İSTEĞİN KENDİ
     * noktasıdır, sağlayıcının oturttuğu (snap) nokta değil. Geocoder tipik
     * olarak sokak ya da bina merkezine oturtur; o nokta iğneye yazılsaydı
     * iğne kullanıcının parmağının altından birkaç on metre kayardı. Kapıyı
     * müşteri biliyor, geocoder değil.
     */
    public function atPoint(float $latitude, float $longitude): self
    {
        return new self(
            source: $this->source,
            latitude: $latitude,
            longitude: $longitude,
            neighbourhood: $this->neighbourhood,
            street: $this->street,
            buildingNo: $this->buildingNo,
            district: $this->district,
            city: $this->city,
        );
    }

    /** Doğrudan `SavedAddressInput.line1`'e yazılabilen tek satır. */
    public function line1(): string
    {
        // Kat/daire YOK: sağlayıcı bina içini bilmez, onları müşteri yazar.
        return StructuredAddress::compose($this->neighbourhood, $this->street, $this->buildingNo);
    }

    /**
     * Listede gösterilecek satır. `line1`'den farkı: ilçe ve ili de içerir.
     *
     * SUNUCU KURAR, istemci parçaları kendisi birleştirmez — aynı öneri
     * web'de ve mobilde farklı görünmesin.
     */
    public function label(): string
    {
        // Biçim `docs/03` §13.1'deki örnekten: parçalar VİRGÜLLE ayrılıyor
        // ("Feritpaşa Mah., Kültür Sk. No:12, Selçuklu / Konya"), oysa
        // `line1` boşlukla birleşiyor. Fark kasıtlı: label okunacak bir
        // satır, `line1` ise fişe basılacak bir adres.
        $parts = array_filter([
            (string) $this->neighbourhood,
            StructuredAddress::compose(null, $this->street, $this->buildingNo),
            trim((string) $this->district).' / '.trim((string) $this->city),
        ], static fn(string $part): bool => trim($part) !== '');

        return implode(', ', $parts);
    }

    /**
     * Sözleşmedeki `AddressSuggestion` gövdesi.
     *
     * Anahtar adları `SavedAddress` ile birebir aynı: istemci öneriyi forma
     * alan alan kopyalıyor, arada eşleme tablosu tutmuyor.
     *
     * @return array<string, mixed>
     */
    public function toArray(): array
    {
        return [
            'label' => $this->label(),
            'line1' => $this->line1(),
            'neighbourhood' => $this->neighbourhood,
            'street' => $this->street,
            'district' => (string) $this->district,
            'city' => (string) $this->city,
            // Sözleşme: bu ikisi ÖNERİDE ASLA null olamaz — eleme zaten
            // koordinat üzerinden yapılıyor, koordinatsız aday listeye
            // giremiyor. İstemci her öneride iğneyi güvenle yerleştirir.
            'latitude' => $this->latitude,
            'longitude' => $this->longitude,
            'source' => $this->source,
        ];
    }
}
