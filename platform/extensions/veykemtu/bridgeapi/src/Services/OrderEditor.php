<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use Igniter\Cart\Models\Order;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\AccountLedgerEntry;
use Veykemtu\BridgeApi\Support\BusinessTime;
use Veykemtu\BridgeApi\Support\Money;
use Veykemtu\Payment\Refunds\RefundManager;

/**
 * Sipariş düzenleme motoru — `docs/05-mutfakapp.md` §12 (K-12).
 *
 * AKIŞ: mutfak personeli müşteriyle **telefonda konuşur**, anlaşır, sonra
 * değişikliği buraya yazar. Onay beklenmez; onay zaten alınmıştır. Bu
 * yüzden burası bir "talep" değil, bir **kayıt** motorudur: ne olduğu,
 * kimin yaptığı, öncesi ve sonrası saklanır.
 *
 * SIRALAMA ÖNEMLİ ve tek işlem içindedir:
 *   1. öncesi anlık görüntü alınır (revizyon belgesi için),
 *   2. satırlar sil-yeniden yaz ile güncellenir (`LineResolver`),
 *   3. toplamlar YENİDEN YAZILIR (eski kod yalnız `insert` yapıyordu),
 *   4. sipariş başlığı güncellenir ve `updated_at` **mutlaka** dokunulur,
 *   5. revizyon satırı yazılır,
 *   6. para farkı işlenir (cari defter ve/veya iade geçidi).
 *
 * 4. ADIM İŞİN EN RİSKLİ TEK DETAYI: KDS artımlı yoklaması
 * `orders.updated_at` üzerinden `since` ile çalışıyor. Yalnız
 * `order_menus` değişip `orders` dokunulmasaydı, değişiklik mutfak
 * ekranına **hiç düşmezdi** — personel eski adedi hazırlamaya devam
 * ederdi. Testi zorunlu.
 */
class OrderEditor
{
    public function __construct(
        private readonly LineResolver $lines,
        private readonly LocationGate $gate,
        private readonly AccountLedger $ledger,
        private readonly OrderStatusTransition $transitions,
        private readonly RefundManager $refunds,
    ) {}

    /**
     * Düzenlemeyi uygular ve revizyonu döndürür.
     *
     * @param  array<int, array{menu_id:int, quantity:int, option_value_ids?:list<int>, note?:string|null}>  $items
     * @return array<string, mixed>
     *
     * @throws ApiException
     */
    public function apply(
        Order $order,
        array $items,
        string $reason,
        ?string $note = null,
        ?Carbon $requestedAt = null,
        ?string $customerNote = null,
        ?int $deviceId = null,
        ?int $staffId = null,
    ): array {
        $this->assertEditable($order);

        if ($items === []) {
            // Boş kalem listesi "siparişi iptal et" demek DEĞİL: iptal ayrı
            // bir durum geçişi ve ayrı bir cari kaydı üretiyor. Sessizce
            // iptale çevirmek, personelin niyetini tahmin etmek olurdu.
            throw ApiException::validationFailed(
                'Sipariş boş bırakılamaz. Tümünü kaldırmak için siparişi iptal edin.',
                ['items' => 'En az bir kalem olmalı.'],
            );
        }

        $before = $this->snapshot($order);

        // Uygunluk zorlanmıyor: personel telefonda konuşup **adedi
        // azaltmak** isterken, o üründe stok bittiği için düzenlemenin
        // tamamen reddedilmesi saçma olurdu — kalem zaten siparişte.
        $lines = $this->lines->resolve($items, enforceAvailability: false);

        $subtotal = array_sum(array_column($lines, 'line_total'));
        $deliveryFee = $this->deliveryFeeOf($order);

        return DB::transaction(function () use (
            $order, $lines, $subtotal, $deliveryFee, $before,
            $reason, $note, $requestedAt, $customerNote, $deviceId, $staffId,
        ): array {
            $this->lines->writeLines($order, $lines, replace: true);
            $this->lines->rewriteTotals($order, $subtotal, $deliveryFee);

            $order->total_items = array_sum(array_column($lines, 'quantity'));
            $order->order_total = Money::toDecimal($subtotal + $deliveryFee);

            if ($requestedAt !== null) {
                $local = $requestedAt->copy()->setTimezone(BusinessTime::ZONE);
                $order->order_date = $local->toDateString();
                $order->order_time = $local->format('H:i:s');
                $order->order_time_is_asap = false;
            }

            if ($customerNote !== null) {
                $order->comment = $customerNote;
            }

            $revisionNo = ((int) ($order->bld_revision_no ?? 0)) + 1;
            $order->bld_revision_no = $revisionNo;

            // KDS'İN GÖREBİLMESİ İÇİN ŞART. `save()` `updated_at`'i
            // güncelliyor; başlıkta hiçbir alan değişmemiş olsa bile
            // (yalnız kalem notu düzenlendi gibi) `touch()` ile
            // garantiye alıyoruz.
            $order->save();
            $order->touch();

            $after = $this->snapshot($order->refresh());

            $totalBefore = $before['total_kurus'];
            $totalAfter = $after['total_kurus'];
            $refund = max(0, $totalBefore - $totalAfter);
            $extra = max(0, $totalAfter - $totalBefore);

            $revisionId = DB::table('veykemtu_order_revisions')->insertGetId([
                'order_id' => (int) $order->order_id,
                'revision_no' => $revisionNo,
                'reason' => $reason,
                'note' => $note,
                'before_json' => json_encode($before, JSON_UNESCAPED_UNICODE),
                'after_json' => json_encode($after, JSON_UNESCAPED_UNICODE),
                'subtotal_before_kurus' => $before['subtotal_kurus'],
                'subtotal_after_kurus' => $after['subtotal_kurus'],
                'total_before_kurus' => $totalBefore,
                'total_after_kurus' => $totalAfter,
                'refund_kurus' => $refund,
                'extra_charge_kurus' => $extra,
                'created_by_device_id' => $deviceId,
                'created_by_staff' => $staffId,
                'created_at' => BusinessTime::forStorage(BusinessTime::now()),
            ]);

            $settlement = $this->settle($order, $revisionId, $revisionNo, $refund, $extra, $reason);

            return [
                'id' => (int) $revisionId,
                'revision_no' => $revisionNo,
                'reason' => $reason,
                'refund_kurus' => $refund,
                'extra_charge_kurus' => $extra,
                'settlement' => $settlement,
                'summary_lines' => $this->summaryLines($before, $after),
            ];
        });
    }

    /**
     * Para farkını işler: cari defter ve/veya iade geçidi.
     *
     * @return array<string, mixed>
     */
    private function settle(
        Order $order,
        int $revisionId,
        int $revisionNo,
        int $refund,
        int $extra,
        string $reason,
    ): array {
        $isAccount = (string) $order->payment === 'account';

        // CARİ HESAP: para hareketi yok, defter düzeltilir.
        //
        // Referans REVİZYONA bağlanıyor, siparişe değil. Defterdeki
        // `UNIQUE(source, reference_type, reference_id, entry_type)`
        // kısıtı sipariş kimliğine bağlansaydı, aynı siparişin ikinci
        // düzenlemesi `insertOrIgnore` tarafından sessizce yutulur ve
        // müşteri fazla borçlu kalırdı.
        if ($isAccount && ($refund > 0 || $extra > 0)) {
            $this->ledger->record(
                customerId: (int) $order->customer_id,
                type: $refund > 0
                    ? AccountLedgerEntry::TYPE_CREDIT
                    : AccountLedgerEntry::TYPE_DEBIT,
                amountKurus: $refund > 0 ? $refund : $extra,
                source: AccountLedgerEntry::SOURCE_ADJUSTMENT,
                referenceType: 'order_revision',
                referenceId: $revisionId,
                description: 'Sipariş #'.$order->order_id.' revizyon #'.$revisionNo
                    .' ('.$reason.')',
                effectiveDate: BusinessTime::now(),
            );
        }

        if ($refund > 0) {
            $result = $this->refunds->refund(
                $order,
                $refund,
                'Revizyon #'.$revisionNo.': '.$reason,
                $revisionId,
            );

            return ['kind' => 'refund', 'status' => $result->status, 'message' => $result->message];
        }

        if ($extra > 0) {
            // EK TAHSİLAT ONLINE/NAKİTTE OTOMATİK ALINMAZ. Müşterinin
            // kartından habersiz ek çekim yapmak kabul edilemez; kapıda
            // ödemede de tahsilat kuryenin işi. Fark kurye fişine
            // yazılıyor (K-14) ve kayıtta duruyor.
            return [
                'kind' => 'extra_charge',
                'status' => $isAccount ? 'succeeded' : 'manual',
                'message' => $isAccount
                    ? null
                    : 'Fark teslimatta tahsil edilecek; kurye fişine yazıldı.',
            ];
        }

        return ['kind' => 'none', 'status' => 'succeeded', 'message' => null];
    }

    /** @throws ApiException */
    public function assertEditable(Order $order): void
    {
        $status = $this->transitions->codeOf($order);

        if (in_array($status, [
            OrderStatusTransition::DELIVERED,
            OrderStatusTransition::CANCELLED,
        ], true)) {
            throw ApiException::validationFailed(
                'Teslim edilmiş ya da iptal edilmiş sipariş düzenlenemez.',
                ['status' => $status],
            );
        }
    }

    /**
     * Siparişin düzenlenebilir anlık görüntüsü — **fiyatsız değil**.
     *
     * Revizyon belgesi tutarları içermek zorunda: "ne kadar iade edildi"
     * sorusunun cevabı burada. Mutfağa GÖNDERİLEN görünüm ayrıdır
     * (`OrderPresenter::editable`) ve orada fiyat yoktur (ADR-08).
     *
     * @return array<string, mixed>
     */
    public function snapshot(Order $order): array
    {
        $rows = DB::table('order_menus')
            ->where('order_id', $order->order_id)
            ->orderBy('order_menu_id')
            ->get();

        $items = [];
        $subtotal = 0;

        foreach ($rows as $row) {
            $lineTotal = Money::toKurus($row->subtotal);
            $subtotal += $lineTotal;

            $items[] = [
                'menu_id' => (int) $row->menu_id,
                'name' => (string) $row->name,
                'quantity' => (int) $row->quantity,
                'unit_price_kurus' => Money::toKurus($row->price),
                'line_total_kurus' => $lineTotal,
                'options' => $this->unserializeOptions($row->option_values),
                'note' => $row->comment,
            ];
        }

        return [
            'items' => $items,
            'subtotal_kurus' => $subtotal,
            'total_kurus' => Money::toKurus($order->order_total),
            'requested_at' => $this->requestedAtOf($order),
            'customer_note' => $order->comment,
        ];
    }

    /**
     * İnsan okuyabilir değişiklik özeti — fişe ve arayüze gider.
     *
     * @param  array<string, mixed>  $before
     * @param  array<string, mixed>  $after
     * @return list<string>
     */
    public function summaryLines(array $before, array $after): array
    {
        $index = static function (array $snapshot): array {
            $map = [];
            foreach ($snapshot['items'] as $item) {
                $key = $item['menu_id'].'|'.($item['note'] ?? '');
                $map[$key] = ($map[$key] ?? 0) + $item['quantity'];
            }

            return $map;
        };

        $names = [];
        foreach ([...$before['items'], ...$after['items']] as $item) {
            $names[$item['menu_id'].'|'.($item['note'] ?? '')] = $item['name'];
        }

        $old = $index($before);
        $new = $index($after);

        $lines = [];
        foreach (array_keys($names) as $key) {
            $from = $old[$key] ?? 0;
            $to = $new[$key] ?? 0;

            if ($from === $to) {
                continue;
            }

            $lines[] = match (true) {
                $from === 0 => 'EKLENDİ: '.$names[$key].' ×'.$to,
                $to === 0 => 'ÇIKARILDI: '.$names[$key].' ×'.$from,
                default => $names[$key].': '.$from.' → '.$to,
            };
        }

        if (($before['requested_at'] ?? null) !== ($after['requested_at'] ?? null)) {
            $lines[] = 'Teslimat saati değişti.';
        }

        return $lines;
    }

    /** @return list<string> */
    private function unserializeOptions(mixed $value): array
    {
        if (!is_string($value) || $value === '') {
            return [];
        }

        // `unserialize` bozuk veride uyarı basıp `false` döner; sipariş
        // görüntüsü bunun yüzünden patlamamalı.
        $decoded = @unserialize($value, ['allowed_classes' => false]);

        return is_array($decoded) ? array_values(array_map(strval(...), $decoded)) : [];
    }

    private function requestedAtOf(Order $order): ?string
    {
        if ($order->order_date === null || $order->order_time === null) {
            return null;
        }

        try {
            return Carbon::parse($order->order_date->toDateString().' '.$order->order_time,
                BusinessTime::ZONE)->utc()->toIso8601ZuluString();
        } catch (\Throwable) {
            return null;
        }
    }

    /**
     * Siparişin teslimat ücreti — mevcut toplamlardan okunur.
     *
     * Vitrinden YENİDEN HESAPLANMAZ: ücret sipariş verildiği anda
     * dondurulmuş bir taahhüt. Düzenleme sırasında güncel tarifeye
     * geçmek, müşterinin onaylamadığı bir zammı sessizce uygulamak olurdu.
     */
    private function deliveryFeeOf(Order $order): int
    {
        $value = DB::table('order_totals')
            ->where('order_id', $order->order_id)
            ->where('code', 'delivery')
            ->value('value');

        return $value === null ? 0 : Money::toKurus($value);
    }
}
