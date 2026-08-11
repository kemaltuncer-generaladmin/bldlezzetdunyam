<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Veykemtu\BridgeApi\Models\BbdReceipt;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * BBD Store köprüsü — `POST /api/partner/bbd/orders` (K-16).
 *
 * **BBD Store bir KİTAP e-ticaret sitesidir**, catering değil; ayrı bir
 * sunucuda ayrı bir projedir.
 *
 * **KÖPRÜNÜN TEK VARLIK SEBEBİ TERMAL YAZICIYI PAYLAŞMAK.** BBD'de bir
 * sipariş onaylandığında buradaki kasa BBD'ye özel bir ses çalıyor ve
 * aynı yazıcıdan bir **paketleme fişi** basıyor. Başka hiçbir şey yok.
 *
 * Bu siparişler BLD'nin `orders` tablosuna girmez, KDS panosunda
 * görünmez, üretim listesine / vardiya istatistiğine / `orders_today`
 * sayacına / cari hesaba karışmaz. İki sistem ayrı kalır.
 *
 * NEDEN `orders`'A YAZILMIYOR: BBD kitap satıyor. Ürünleri BLD menüsünde
 * yok, fiyatları BLD fiyat listesinde değil, müşterisi BLD müşterisi
 * değil ve iş akışı bile farklı — biri pişiriliyor, diğeri raftan alınıp
 * kutulanıyor. Zorla `orders`'a sokmak ciro raporunu, üretim listesini ve
 * cari hesabı bir gecede yanlış yapardı.
 *
 * NEDEN AYRI CONTROLLER: `KitchenController` mutfak kapsamına ait ve
 * cihaz token'ı ile korunuyor. Bu uç bir **ortak** ucudur, kimlik
 * doğrulaması HMAC imzasıyla; ikisini aynı sınıfa koymak, iki farklı
 * güvenlik modelini aynı yerde tutmak olurdu.
 */
class BbdController extends ApiController
{
    /**
     * BBD'den gelen siparişi kaydeder.
     *
     * İDEMPOTENT: aynı `external_id` ikinci kez gelirse yeni satır
     * açılmaz ve yine `200` döner. BBD ağ hatasında tekrar gönderiyor;
     * `409` dönmek onu sonsuz yeniden denemeye sokardı.
     */
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'external_id' => ['required', 'string', 'max:128'],
            'order_number' => ['nullable', 'string', 'max:64'],
            'created_at' => ['nullable', 'date'],
            'customer_label' => ['nullable', 'string', 'max:120'],
            'phone' => ['nullable', 'string', 'max:32'],
            'delivery_type' => ['nullable', 'string', 'in:delivery,pickup'],
            'address' => ['nullable', 'string', 'max:255'],
            'note' => ['nullable', 'string', 'max:500'],
            'items' => ['required', 'array', 'min:1', 'max:100'],
            // Kitap adları uzun: 200 karakter, mutfak ürün adının (120)
            // üstünde bilinçli olarak.
            'items.*.name' => ['required', 'string', 'max:200'],
            'items.*.quantity' => ['required', 'integer', 'min:1', 'max:9999'],
            // Stok kodu / ISBN — raftan bulmanın en hızlı yolu.
            'items.*.sku' => ['nullable', 'string', 'max:64'],
            // Yazar, cilt, baskı gibi ek nitelikler.
            'items.*.attributes' => ['sometimes', 'array', 'max:5'],
            'items.*.attributes.*' => ['string', 'max:80'],
            'items.*.note' => ['nullable', 'string', 'max:255'],
            'amount_kurus' => ['nullable', 'integer', 'min:0'],
            // Kitapta `delivery` kurye değil KARGO demek.
            'cargo_company' => ['nullable', 'string', 'max:60'],
            'tracking_number' => ['nullable', 'string', 'max:64'],
            // Serbest metin: BBD'nin ödeme yöntemleri bizimkilerle aynı
            // olmak zorunda değil ve bilinmeyen bir değeri "Bilinmeyen"e
            // düşürmek, paketleyene yanlış bilgi vermek olurdu.
            'payment_label' => ['nullable', 'string', 'max:60'],
        ]);

        $externalId = trim($data['external_id']);

        // `insertOrIgnore` yerine `firstOrCreate` DEĞİL: yarışta iki istek
        // aynı anda "yok" görüp ikisi de yazmaya çalışabilir. UNIQUE
        // kısıtı + `insertOrIgnore` tek satırı garanti ediyor.
        $existing = BbdReceipt::where('external_id', $externalId)->first();

        if ($existing === null) {
            BbdReceipt::insertOrIgnore([
                'external_id' => $externalId,
                'order_number' => $data['order_number'] ?? null,
                'payload_json' => json_encode($data, JSON_UNESCAPED_UNICODE),
                'received_at' => BusinessTime::forStorage(BusinessTime::now()),
            ]);
        }

        return $this->json([
            'external_id' => $externalId,
            // İkinci gönderimde `false` — BBD tarafı isterse loglar.
            'accepted' => $existing === null,
            'server_time' => Carbon::now()->utc()->toIso8601ZuluString(),
        ]);
    }
}
