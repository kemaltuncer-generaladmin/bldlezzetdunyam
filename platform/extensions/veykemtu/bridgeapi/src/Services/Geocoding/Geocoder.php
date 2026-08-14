<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services\Geocoding;

/**
 * Adres sağlayıcısı sürücüsü — B-21.
 *
 * ARAYÜZ, SAĞLAYICI DEĞİŞİMİ İÇİN VAR. Bugünkü sürücü OpenStreetMap
 * Nominatim: anahtar gerektirmiyor, faturası yok ve hemen çalışıyor.
 * `docs/11-yol-haritasi.md` §F2-01 Google Places'e geçmeyi planlıyor —
 * o gün değişecek tek şey bu arayüzün bir başka gerçeklemesi ve
 * `Extension::registerGeocoder()` içindeki tek satır olmalı; denetleyici,
 * önbellek, hizmet alanı elemesi ve oran sınırı olduğu yerde kalmalı.
 *
 * ## Sürücü hizmet alanını BİLMEZ
 *
 * Sürücünün tek işi "sağlayıcı ne diyor" sorusunu cevaplamak. Kutuya göre
 * eleme ve kanonik ilçe yazımı `AddressLookup`'ta; sürücüye konsaydı her
 * yeni sağlayıcı aynı kuralı baştan uygulamak zorunda kalır ve biri onu
 * eksik uyguladığında hizmet vermediğimiz bir ilçe öneri listesine sızardı.
 *
 * ## Arıza SESSİZ DEĞİL, ama akışı da durdurmaz
 *
 * Sağlayıcıya ulaşılamadığında sürücü `GeocoderUnavailable` fırlatır —
 * boş dizi DÖNMEZ. İkisi ayrı şeydir: "bu metne uyan adres yok" bir
 * cevaptır, "sağlayıcı çöktü" bir arızadır ve günlüğe yazılması gerekir.
 * İstemciye ikisi de aynı görünür (boş liste) ama sunucu ayrımı bilmek
 * zorunda, yoksa çöken bir sağlayıcı haftalarca fark edilmez.
 */
interface Geocoder
{
    /**
     * Serbest metinden adres adayları.
     *
     * @param  positive-int  $limit
     * @return list<AddressCandidate>
     *
     * @throws GeocoderUnavailable Sağlayıcıya ulaşılamadı / bozuk yanıt döndü.
     */
    public function suggest(string $query, int $limit): array;

    /**
     * Koordinattan adres. Sağlayıcı o noktayı bilmiyorsa `null`.
     *
     * @throws GeocoderUnavailable
     */
    public function reverse(float $latitude, float $longitude): ?AddressCandidate;

    /**
     * Sözleşmedeki `AddressSuggestion.source` değeri — `osm_nominatim`.
     *
     * Sürücünün kendisi söyler: `AddressLookup` hangi sürücüyle konuştuğunu
     * bilmek zorunda kalmasın diye.
     */
    public function name(): string;
}
