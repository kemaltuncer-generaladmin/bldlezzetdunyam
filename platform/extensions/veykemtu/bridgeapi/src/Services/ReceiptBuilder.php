<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use Igniter\Cart\Models\Order;
use Illuminate\Support\Facades\DB;
use Veykemtu\BridgeApi\Models\PrintJob;

/**
 * Fiş verisi — `docs/openapi.yaml` `getReceipt`, `docs/05-mutfakapp.md` §5.3.
 *
 * NEDEN SUNUCUDA: fişte ne yazacağı bir iş kuralıdır, biçimleme değil.
 * KDS yalnızca bu yapıyı ESC/POS baytlarına çevirir. Kural sunucuda
 * durduğu için, "fişe şunu da yazalım" isteği kasa güncellemesi
 * gerektirmez — mutfak makinesine dokunmadan değişir.
 *
 * İki tip vardır: `mutfak` (fiyatsız, iri punto) ve `musteri` (fiyatlı).
 * Teslim fişi, öğrenci kanalıyla birlikte iptal edilmiştir.
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
        ];
    }

    /**
     * Müşteri fişi — fiyatlı; adres yalnızca adrese gönderimde.
     *
     * Bu, mutfak kapsamının müşteri adresini gördüğü **tek** yerdir; kurye
     * fişi elinde götürecek. Gel-al siparişte adres bloğu basılmaz.
     *
     * @return array<string, mixed>
     */
    public function customer(Order $order): array
    {
        $totals = $this->presenter->totals($order);
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
            'payment' => $this->presenter->payment($order),
            'address' => $isDelivery ? $this->presenter->address($order) : null,
            'customer_label' => $this->presenter->customerLabel($order),
            'printed_at' => $this->printedAt($order, PrintJob::TYPE_CUSTOMER),
        ];
    }

    /**
     * Kurye fişi (K-14) — kime, nereye, ne kadar tahsil edilecek.
     *
     * MÜŞTERİ FİŞİNDEN FARKI: kalem fiyatları ve ara toplam yok, buna
     * karşılık ad + telefon, revizyon özeti ve **tahsil edilecek tutar**
     * var. Kurye fiyat kırılımına bakmıyor; tek soru "ne kadar alacağım".
     *
     * `collect_amount` ödenmiş siparişte 0'dır ve fişe satır basılmaz:
     * sıfırlık bir "tahsil edilecek" satırı, kuryenin bir sonraki fişte
     * gerçek tutarı gözden kaçırmasına yol açıyor.
     *
     * @return array<string, mixed>
     */
    public function courier(Order $order): array
    {
        $totals = $this->presenter->totals($order);
        $payment = $this->presenter->payment($order);
        $isDelivery = $this->presenter->deliveryType($order) === 'delivery';

        $revisions = DB::table('veykemtu_order_revisions')
            ->where('order_id', $order->order_id)
            ->orderByDesc('revision_no')
            ->first();

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
            'revision_no' => (int) ($order->bld_revision_no ?? 0),
            'revision_summary' => $this->revisionSummary($revisions),
            // Ödenmemişse tamamı kapıda tahsil edilecek.
            'collect_amount' => ($payment['status'] ?? 'pending') === 'paid'
                ? 0
                : $totals['total'],
            'printed_at' => $this->printedAt($order, PrintJob::TYPE_COURIER),
        ];
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

    private function printedAt(Order $order, string $type): ?string
    {
        return PrintJob::printedAtFor((int) $order->order_id, $type)
            ?->utc()->toIso8601ZuluString();
    }
}
