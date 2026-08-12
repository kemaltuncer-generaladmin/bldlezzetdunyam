<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use Igniter\Cart\Models\Order;
use Illuminate\Support\Facades\DB;
use Veykemtu\BridgeApi\Models\PrintJob;
use Veykemtu\BridgeApi\Support\SignedLink;
use Veykemtu\Payment\Payments\SimulatedPos;

/**
 * Fiş verisi — `docs/openapi.yaml` `getReceipt`, `docs/05-mutfakapp.md` §5.3.
 *
 * NEDEN SUNUCUDA: fişte ne yazacağı bir iş kuralıdır, biçimleme değil.
 * KDS yalnızca bu yapıyı ESC/POS baytlarına çevirir. Kural sunucuda
 * durduğu için, "fişe şunu da yazalım" isteği kasa güncellemesi
 * gerektirmez — mutfak makinesine dokunmadan değişir.
 *
 * ÜÇ TİP VAR AMA SİPARİŞ BAŞINA İKİ KÂĞIT ÇIKAR (K-20):
 *
 * * `mutfak` — fiyatsız, iri punto; `onaylandi`da basılır.
 * * `musteri` — fiyatlı **ve kuryenin fişi**; `hazir`da basılır. Kurye
 *   kapıda okur, kâğıt sonra müşteride kalır.
 * * `kurye` — artık OTOMATİK BASILMAZ. Yalnız KDS'ten elle yeniden
 *   bastırma yolu için duruyor (kâğıt sıkıştı, kurye fişi kaybetti).
 *
 * Öncesinde adrese gönderim başına üç kâğıt, iki kez düzenlenmiş siparişte
 * yedi kâğıt çıkıyordu; tezgâhta hangisinin güncel olduğu okunamıyordu.
 */
class ReceiptBuilder
{
    public function __construct(private readonly OrderPresenter $presenter) {}

    /**
     * Mutfak fişi — fiyat **yoktur**, müşteri telefonu vardır.
     *
     * @return array<string, mixed>
     */
    public function kitchen(Order $order): array
    {
        $lines = array_map(
            static fn(array $item): array => [
                'quantity' => $item['quantity'],
                'name' => $item['name'],
                'options' => $item['options'],
                'note' => $item['note'],
            ],
            $this->presenter->kitchenItems($order),
        );

        return [
            'type' => PrintJob::TYPE_KITCHEN,
            'order_number' => $this->presenter->number($order),
            'delivery_type' => $this->presenter->deliveryType($order),
            'requested_at' => $this->presenter->requestedAt($order),
            'lines' => $lines,

            // Fiyat hâlâ yok ama TELEFON var: kurye kapıda kaldığında
            // arayacak numarayı fişte bulmalı (`OrderPresenter::customerPhone`).
            'customer_phone' => $this->presenter->customerPhone($order),
            'customer_note' => $order->comment !== null ? (string) $order->comment : null,
            'printed_at' => $this->printedAt($order, PrintJob::TYPE_KITCHEN),

            /*
             * REVİZYON MUTFAK FİŞİNE K-20 İLE GELDİ.
             *
             * Öncesinde düzenlenen sipariş için yeni bir kâğıt çıkıyor ama
             * üstünde onu öncekinden ayıran hiçbir şey yazmıyordu; tezgâhta
             * iki kâğıt yan yana durduğunda hangisinin geçerli olduğu
             * okunamıyordu. `docs/10-test-kabul.md` S9-13 bu bandı zaten
             * şart koşuyordu — kod belgeye uymuyordu.
             */
            'revision_no' => $this->revisionNo($order),
            'revision_summary' => $this->revisionSummary($this->latestRevision($order)),
        ];
    }

    /**
     * Müşteri fişi — fiyatlı **ve K-20'den beri kuryenin de fişi**.
     *
     * NEDEN BİRLEŞTİ: kurye üç bilgiye ihtiyaç duyuyor (kime, nereye, ne
     * kadar tahsil edilecek) ve bunlar ayrı bir kâğıttaydı. Adrese gönderim
     * başına üç kâğıt çıkıyor, sipariş iki kez düzenlenirse yedi oluyordu;
     * tezgâhta hangisinin güncel olduğu okunamıyordu. Artık tek kâğıt:
     * kurye kapıda okuyor, sonra müşteride kalıyor.
     *
     * Gel-al siparişte ad/telefon/adres bloğu ve tahsilat satırı basılmaz —
     * kurye yok, o satırlar boş bir teslimatı arattırırdı.
     *
     * @return array<string, mixed>
     */
    public function customer(Order $order): array
    {
        $totals = $this->presenter->totals($order);
        $payment = $this->presenter->payment($order);
        $isDelivery = $this->presenter->deliveryType($order) === 'delivery';

        return [
            'type' => PrintJob::TYPE_CUSTOMER,
            'order_number' => $this->presenter->number($order),
            'delivery_type' => $this->presenter->deliveryType($order),
            'requested_at' => $this->presenter->requestedAt($order),
            'items' => $this->presenter->pricedItems($order),
            'subtotal' => $totals['subtotal'],
            'delivery_fee' => $totals['delivery'],
            'total' => $totals['total'],
            'currency' => 'TRY',
            'payment' => $payment,
            'address' => $isDelivery ? $this->presenter->address($order) : null,
            'customer_label' => $this->presenter->customerLabel($order),
            'printed_at' => $this->printedAt($order, PrintJob::TYPE_CUSTOMER),
            'track_url' => $this->trackUrl($order),
            'pay_url' => $this->payUrl($order),

            // ── K-20: kurye fişinden devralınan alanlar ───────────────────
            //
            // AD VE TELEFON YALNIZ ADRESE GÖNDERİMDE. Gel-al fişini müşteri
            // tezgâhtan alıyor; kendi adını ve numarasını kâğıda basmak
            // kimseye bir şey söylemez, sızma yüzeyini büyütür.
            'customer_name' => $isDelivery ? $this->presenter->customerName($order) : null,
            'customer_phone' => $isDelivery ? $this->presenter->customerPhone($order) : null,

            /*
             * MÜŞTERİ NOTU BU FİŞE TAŞINDI VE TARTIŞMAYA AÇIK DEĞİL.
             * "Zili çalmayın" gibi kapı talimatı kuryeye bugüne kadar
             * yalnız kurye fişiyle ulaşıyordu. O fişi otomatik basmaktan
             * vazgeçip notu taşımasaydık, kuryenin elinden bir kapı
             * talimatını silmiş olurduk.
             */
            'customer_note' => $order->comment !== null ? (string) $order->comment : null,

            'collect_amount' => $this->collectAmount($payment, $totals, $isDelivery),
            'revision_no' => $this->revisionNo($order),
            'revision_summary' => $this->revisionSummary($this->latestRevision($order)),
            'deliver_url' => $isDelivery ? $this->deliverUrl($order) : null,
        ];
    }

    /**
     * Sipariş takip bağlantısı — müşteri fişindeki QR (K-18).
     *
     * Müşteri fişi elden veriliyor ve üstünde sipariş numarası yazıyor; ama
     * durumu görmek için o numarayı siteye elle yazmak gerekiyordu. QR o
     * adımı kaldırıyor.
     *
     * `FRONTEND_URL` TANIMSIZSA null döner ve QR HİÇ BASILMAZ. Çalışmayan
     * bir kare basmak, okutup boş sayfa gören müşteri üretmekten iyi
     * değil — üstelik kâğıt ve mürekkep harcıyor.
     *
     * ADRES K-20 İLE DEĞİŞTİ — ÖNCEKİ HÂLİ ÇALIŞMIYORDU. Bağlantı
     * `/siparis/{id}` idi ve o sayfa oturum istiyor (`requireSession` +
     * `middleware.ts`): fişteki kareyi okutan müşteri sipariş durumunu
     * değil **giriş ekranını** görüyordu. Kâğıda basılan bir QR'ın giriş
     * istememesi gerekir; yeni adres imzalı ve girişsiz.
     *
     * Girişli `/siparis/{id}` sayfası olduğu gibi duruyor.
     */
    private function trackUrl(Order $order): ?string
    {
        $base = $this->frontendUrl();
        if ($base === null || !SignedLink::isConfigured()) {
            return null;
        }

        $orderId = (int) $order->order_id;
        $expires = $this->expiresAt($order, SignedLink::TRACK_TTL_DAYS);

        return $base.'/takip/'.$orderId.'?e='.$expires
            .'&s='.SignedLink::sign(SignedLink::PURPOSE_TRACK, $orderId, $expires);
    }

    /**
     * "Teslim ettim" bağlantısı — kuryenin okuttuğu QR (K-20).
     *
     * Kurye okutuyor, tek düğmeli bir onay sayfası açılıyor, onaylayınca
     * sipariş `teslim_edildi` oluyor. Kurye girişi yok; yetki imzada.
     *
     * TEK KULLANIMLIK OLMASI İÇİN AYRI BİR BAYRAK YOK: `teslim_edildi`
     * durum makinesinde terminal (`OrderStatusTransition::MATRIX`), yani
     * ikinci okutma geçerli bir geçiş bulamıyor. Ayrı bir "kullanıldı"
     * sütunu aynı gerçeği ikinci kez kodlar ve ikisinin ayrışabildiği bir
     * durum yaratırdı.
     */
    private function deliverUrl(Order $order): ?string
    {
        if (!SignedLink::isConfigured()) {
            return null;
        }

        $orderId = (int) $order->order_id;
        $expires = $this->expiresAt($order, SignedLink::DELIVER_TTL_DAYS);

        return rtrim((string) config('app.url'), '/').'/teslimat/'.$orderId
            .'?e='.$expires
            .'&s='.SignedLink::sign(SignedLink::PURPOSE_DELIVER, $orderId, $expires);
    }

    /**
     * İmza süresinin çıpası — `OrderPresenter::requestedAt` yeniden kullanılıyor.
     *
     * Tarih ayrıştırma mantığı orada duruyor ve tek kaynak kalmalı; burada
     * ikinci bir `order_date` + `order_time` birleştirmesi yazmak, ikisinin
     * ayrışabildiği bir gelecek demekti.
     */
    private function expiresAt(Order $order, int $days): int
    {
        $requestedIso = $this->presenter->requestedAt($order);
        $requested = $requestedIso === null ? false : strtotime($requestedIso);

        return SignedLink::expiresAt(
            $order->created_at?->getTimestamp() ?? time(),
            $requested === false ? null : $requested,
            $days,
        );
    }

    /**
     * Ödeme bağlantısı — yalnızca ÖDENMEMİŞ siparişte (K-19).
     *
     * Kapıda ödeme seçen müşteri kapıda nakit bulundurmak zorunda
     * kalmasın diye: fişteki QR'ı okutup karttan ödeyebiliyor.
     *
     * ÖDENMİŞ SİPARİŞTE null: ödenmiş bir siparişin fişine ödeme QR'ı
     * basmak, ikinci kez ödemeye davet etmek olurdu.
     *
     * Bağlantı sanal POS sayfasına gidiyor ve `app.url` üzerinden
     * kuruluyor (`OrderPresenter::redirectUrl` ile aynı yer); `?return=`
     * ile müşteri ödeme sonrası kendi sipariş takip sayfasına dönüyor.
     *
     * SİMÜLASYON KAPALIYSA null (K-20). `Veykemtu\Payment\Extension`
     * simülasyon rotalarını `SimulatedPos::isAllowed()` yanlışken **hiç
     * kaydetmiyor**; bu kontrol olmadan üretimde `POS_ALLOW_SIMULATION`
     * tanımsızken fişe ölü bir adrese giden kare basılıyordu. Okutan
     * müşteri, Caddy'nin 308'i sayesinde ana sayfaya düşüyordu.
     */
    private function payUrl(Order $order): ?string
    {
        if ((bool) $order->processed) {
            return null;
        }

        if (!SimulatedPos::isAllowed()) {
            return null;
        }

        $hash = (string) ($order->hash ?? '');
        if ($hash === '') {
            return null;
        }

        $url = rtrim((string) config('app.url'), '/').'/odeme-simulasyon/'.$hash;
        $track = $this->trackUrl($order);

        return $track === null ? $url : $url.'?return='.rawurlencode($track);
    }

    /**
     * Müşteri sitesinin kökü. Tanımsızsa `null` — çağıranlar QR basmıyor.
     *
     * Aynı değeri ödeme dönüşü de kullanıyor
     * (`SimulationController::returnUrl`); tek kaynak olması, fişteki
     * bağlantı ile dönüş adresinin ayrışmamasını sağlıyor.
     */
    private function frontendUrl(): ?string
    {
        $raw = trim((string) config('app.frontend_url', env('FRONTEND_URL', '')));

        return $raw === '' ? null : rtrim($raw, '/');
    }

    /**
     * Kurye fişi (K-14) — kime, nereye, ne kadar tahsil edilecek.
     *
     * K-20'DEN BERİ OTOMATİK BASILMIYOR. İçeriği müşteri fişine taşındı ve
     * sipariş başına iki kâğıt çıkıyor. Bu yol, KDS'ten **elle yeniden
     * bastırma** kaçış kapısı için duruyor: kâğıt sıkışırsa ya da kurye
     * fişi kaybederse personelin onu geri getirecek bir yolu olmalı.
     *
     * MÜŞTERİ FİŞİNDEN FARKI: kalem fiyatları ve ara toplam yok, buna
     * karşılık ad + telefon, revizyon özeti ve **tahsil edilecek tutar**
     * var. Kurye fiyat kırılımına bakmıyor; tek soru "ne kadar alacağım".
     *
     * @return array<string, mixed>
     */
    public function courier(Order $order): array
    {
        $totals = $this->presenter->totals($order);
        $payment = $this->presenter->payment($order);
        $isDelivery = $this->presenter->deliveryType($order) === 'delivery';

        return [
            'type' => PrintJob::TYPE_COURIER,
            'order_number' => $this->presenter->number($order),
            'delivery_type' => $this->presenter->deliveryType($order),
            'requested_at' => $this->presenter->requestedAt($order),
            'items' => $this->presenter->pricedItems($order),
            'total' => $totals['total'],
            'currency' => 'TRY',
            'payment' => $payment,
            'address' => $isDelivery ? $this->presenter->address($order) : null,
            'customer_name' => $this->presenter->customerName($order),
            'customer_phone' => $this->presenter->customerPhone($order),
            'customer_note' => $order->comment !== null ? (string) $order->comment : null,
            'revision_no' => $this->revisionNo($order),
            'revision_summary' => $this->revisionSummary($this->latestRevision($order)),
            'collect_amount' => $this->collectAmount($payment, $totals, $isDelivery),
            'printed_at' => $this->printedAt($order, PrintJob::TYPE_COURIER),
        ];
    }

    /**
     * Kapıda tahsil edilecek tutar — **tek kural, iki fiş.**
     *
     * Müşteri fişi de kurye fişi de aynı rakamı basıyor; iki ayrı yerde
     * hesaplansaydı biri güncellendiğinde diğeri sessizce ayrışır ve iki
     * kâğıt farklı tutar söylerdi.
     *
     * Ödenmiş siparişte `0` ve KDS satırı hiç basmıyor: sıfırlık bir
     * "tahsil edilecek" satırı, kuryenin bir sonraki fişte gerçek tutarı
     * gözden kaçırmasına yol açıyordu.
     *
     * Gel-al'da da `0` — kapıda kimse yok.
     *
     * @param array<string, mixed> $payment
     * @param array<string, int>   $totals
     */
    private function collectAmount(array $payment, array $totals, bool $isDelivery): int
    {
        if (!$isDelivery) {
            return 0;
        }

        return ($payment['status'] ?? 'pending') === 'paid' ? 0 : (int) $totals['total'];
    }

    private function revisionNo(Order $order): int
    {
        return (int) ($order->bld_revision_no ?? 0);
    }

    /**
     * Siparişin en son revizyon kaydı; hiç düzenlenmediyse `null`.
     *
     * Üç fiş de aynı sorguyu soruyor; tek yerde durması, birinde eklenen
     * bir koşulun diğerlerine uğramaması riskini kaldırıyor.
     */
    private function latestRevision(Order $order): ?object
    {
        return DB::table('veykemtu_order_revisions')
            ->where('order_id', $order->order_id)
            ->orderByDesc('revision_no')
            ->first();
    }

    /** @return list<string> */
    private function revisionSummary(?object $revision): array
    {
        if ($revision === null) {
            return [];
        }

        $before = json_decode((string) $revision->before_json, true);
        $after = json_decode((string) $revision->after_json, true);

        if (!is_array($before) || !is_array($after)) {
            return [];
        }

        return app(OrderEditor::class)->summaryLines($before, $after);
    }

    /**
     * Bu fişin **bu revizyonu** ilk ne zaman basıldı?
     *
     * REVİZYONA BAKMASI ŞART (K-20): revizyondan bağımsız sorulunca hep ilk
     * basımın saati dönüyordu ve yeniden basılan kâğıt, yerini aldığı eski
     * kâğıdın saatiyle damgalanıyordu. Elinde iki kâğıt olan kurye
     * hangisinin yeni olduğunu kâğıttaki tek zaman damgasından
     * anlayamıyordu — tam da "GÜNCEL FİŞ" bandının çözdüğü sorun.
     *
     * Düzenlenen sipariş için `null` dönmesi doğru: o revizyon henüz
     * basılmadı.
     */
    private function printedAt(Order $order, string $type): ?string
    {
        return PrintJob::printedAtFor(
            (int) $order->order_id,
            $type,
            $this->revisionNo($order),
        )?->utc()->toIso8601ZuluString();
    }
}
