<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers\Control;

use Igniter\Cart\Models\Order;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\ControlAudit;
use Veykemtu\BridgeApi\Services\OrderEditor;
use Veykemtu\BridgeApi\Services\OrderPresenter;
use Veykemtu\BridgeApi\Services\OrderStatusTransition;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Kontrol Merkezi — siparişler ve revizyon (`/api/control/kds/orders`).
 *
 * İŞ MANTIĞI BURADA YOK. Revizyonu `OrderEditor` yazıyor (kalem
 * çözümleme, toplam düzeltme, cari kayıt, iade), durum geçişini
 * `OrderStatusTransition` yönetiyor (matris, geri alma penceresi, iptal
 * ters kaydı). İkisi de mutfak kasasının kullandığı sınıfların TA
 * KENDİSİ — ayrı bir kopya yazılsaydı, sipariş merkezden düzenlendiğinde
 * cari hesap ya da iade kaydı sessizce oluşmayabilirdi.
 *
 * ÇAĞIRAN AYRIMI: `created_by_device_id` NULL kalıyor (kasa yok) ve
 * revizyon notuna "Kontrol Merkezi · <actor>" etiketi yazılıyor
 * (gerekçe `ControlController::actorLabel()`).
 */
class OrderController extends ControlController
{
    public function __construct(
        private readonly OrderPresenter $presenter,
        private readonly OrderStatusTransition $transitions,
    ) {}

    /**
     * Aktif siparişler.
     *
     * KAPSAM MUTFAK PANOSUYLA AYNI (`GET /api/kitchen/orders`): işletme
     * gününe ait siparişler, terminal olanlar hariç. Kontrol Merkezi'ndeki
     * ekran mutfağın gördüğünü göstermek için var; iki uç farklı bir küme
     * dönseydi "bende görünüyor, mutfakta yok" tartışması çözülemezdi.
     *
     * `since` durum değişimlerini de yakalar (`updated_at`); yalnız yeni
     * siparişleri isteyen bir imleç, düzenlenmiş bir siparişi kaçırırdı.
     */
    public function index(Request $request): JsonResponse
    {
        $request->validate([
            'since' => ['sometimes', 'date'],
            // `boolean` KURALI KULLANILMAZ: sorgu dizesinde boolean ancak
            // metin olarak ifade edilebilir ve Laravel'in `boolean` kuralı
            // `"true"` dizgesini reddeder. Aynı hata mutfak ucunda KDS'i
            // kör etmişti; `$request->boolean()` hepsini doğru okur.
            'include_completed' => ['sometimes', Rule::in(['1', '0', 'true', 'false'])],
        ]);

        $query = Order::query()->orderBy('order_id');

        if (!$request->boolean('include_completed')) {
            $query->whereNotIn('status_id', $this->terminalStatusIds());
        }

        $query->whereDate('order_date', BusinessTime::now()->toDateString());

        if ($request->filled('since')) {
            // Gelen değer UTC; `updated_at` depolama zaman diliminde
            // saklanıyor. Dönüştürmeden karşılaştırmak saat farkı kadar
            // geçmişteki her siparişi "yeni güncellenmiş" gösterirdi.
            $query->where('updated_at', '>', BusinessTime::forStorage(
                Carbon::parse((string) $request->query('since')),
            ));
        }

        return $this->json([
            'data' => $query->get()
                ->map(fn(Order $order): array => $this->presenter->kitchen($order))
                ->all(),
            'server_time' => $this->serverTime(),
        ]);
    }

    /** Tek sipariş, düzenlenebilir görünüm — fiyatsız (ADR-08). */
    public function show(int $order): JsonResponse
    {
        return $this->json([
            'data' => $this->presenter->editable($this->findOrder($order)),
            'server_time' => $this->serverTime(),
        ]);
    }

    /** Revizyon geçmişi — "ne oldu" sorusunun cevabı. */
    public function revisions(int $order): JsonResponse
    {
        $this->findOrder($order);

        $rows = DB::table('veykemtu_order_revisions')
            ->where('order_id', $order)
            ->orderBy('revision_no')
            ->get()
            ->map(static fn($row): array => [
                'revision_no' => (int) $row->revision_no,
                'reason' => (string) $row->reason,
                'note' => $row->note,
                'refund_kurus' => (int) $row->refund_kurus,
                'extra_charge_kurus' => (int) $row->extra_charge_kurus,
                'created_by_device_id' => $row->created_by_device_id !== null
                    ? (int) $row->created_by_device_id
                    : null,
                'created_at' => $row->created_at,
            ])
            ->all();

        return $this->json(['data' => $rows]);
    }

    /**
     * Yeni revizyon — gövde `/api/kitchen/orders/{id}/revisions` ile
     * BİREBİR AYNI, üstüne `actor` + `dry_run`.
     *
     * `items` TAM LİSTEDİR, delta değil. Fark göndermek, iki tarafın
     * "şu anki hâl" konusunda anlaşmasını gerektirirdi; eşzamanlı bir
     * kasa düzenlemesiyle yarışan bir merkez isteği sessizce yanlış
     * sipariş üretirdi. Boş liste REDDEDİLİR — siparişi boşaltmak iptal
     * DEĞİLDİR ve iptalin kendi durumu, kendi cari kaydı vardır
     * (`OrderEditor::apply()`).
     */
    public function storeRevision(
        Request $request,
        int $order,
        OrderEditor $editor,
    ): JsonResponse {
        $model = $this->findOrder($order);

        $data = $request->validate([
            'reason' => $this->orderReasonRules(),
            'note' => ['nullable', 'string', 'max:1000'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.menu_id' => ['required', 'integer', 'min:1'],
            'items.*.quantity' => ['required', 'integer', 'min:1', 'max:999'],
            'items.*.option_value_ids' => ['sometimes', 'array'],
            'items.*.option_value_ids.*' => ['integer', 'min:1'],
            'items.*.note' => ['nullable', 'string', 'max:255'],
            'requested_at' => ['nullable', 'date'],
            'customer_note' => ['nullable', 'string', 'max:1000'],
        ]);

        return $this->write(
            $request,
            'order.revise',
            ControlAudit::TARGET_ORDER,
            (int) $model->order_id,
            [
                'item_count' => count($data['items']),
                'items' => $data['items'],
                'requested_at' => $data['requested_at'] ?? null,
            ],
            function () use ($editor, $model, $data): array {
                // KURU PROVA GERÇEKTEN DENETLER: teslim edilmiş ya da
                // iptal edilmiş sipariş burada da 422 alır. Yalnız isteği
                // yankılasaydı, "kuru prova geçti" diyen bir ekran gerçek
                // gönderimde patlardı.
                $editor->assertEditable($model);

                return [
                    'action' => 'order.revise',
                    'order_id' => (int) $model->order_id,
                    'next_revision_no' => ((int) ($model->bld_revision_no ?? 0)) + 1,
                    'items' => $data['items'],
                ];
            },
            function (array $intent) use ($editor, $model, $data): array {
                $revision = $editor->apply(
                    $model,
                    $data['items'],
                    $data['reason'],
                    $this->revisionNote($intent['actor'], $data['note'] ?? null),
                    isset($data['requested_at']) ? Carbon::parse($data['requested_at']) : null,
                    $data['customer_note'] ?? null,
                    // KASA KİMLİĞİ YOK: bu revizyon mutfaktan değil
                    // merkezden geldi ve denetim izinde ayrılması gereken
                    // tek şey bu.
                    deviceId: null,
                );

                return [
                    // `refresh()` ŞART: `OrderEditor` toplamları ve
                    // `updated_at`'i işlem içinde yeniden yazıyor.
                    'order' => $this->presenter->kitchen($model->refresh()),
                    'revision' => $revision,
                ];
            },
        );
    }

    /**
     * Durum geçişi. Kararı `OrderStatusTransition` verir.
     *
     * Gerekçe `status_history`'ye yorum olarak da düşüyor: "bu sipariş
     * neden iptal edildi" sorusunun cevabı siparişin kendi geçmişinde
     * durmalı, yalnız ayrı bir denetim tablosunda değil.
     */
    public function setStatus(Request $request, int $order): JsonResponse
    {
        $model = $this->findOrder($order);

        $data = $request->validate([
            'status' => ['required', 'string', Rule::in(OrderStatusTransition::CODES)],
            'reason' => $this->orderReasonRules(),
        ]);

        $to = (string) $data['status'];
        $from = $this->transitions->codeOf($model);

        return $this->write(
            $request,
            'order.status',
            ControlAudit::TARGET_ORDER,
            (int) $model->order_id,
            ['from' => $from, 'to' => $to],
            function () use ($model, $from, $to): array {
                // Kuru provada da gerçek matris çalışıyor: geçersiz geçiş
                // burada da `422 INVALID_TRANSITION` döner.
                $this->transitions->assertAllowed($model, $from, $to);

                return [
                    'action' => 'order.status',
                    'order_id' => (int) $model->order_id,
                    'from' => $from,
                    'to' => $to,
                ];
            },
            function (array $intent) use ($model, $to, $data): array {
                $updated = $this->transitions->apply(
                    $model,
                    $to,
                    // `user_id` YOK: geçiş bir admin kullanıcısı değil,
                    // Kontrol Merkezi tarafından yapıldı ve o kişinin
                    // BLD'de hesabı yok.
                    null,
                    $this->actorLabel($intent['actor']).': '.$data['reason'],
                );

                return ['order' => $this->presenter->kitchen($updated)];
            },
        );
    }

    // ── Yardımcılar ───────────────────────────────────────────────────────

    /**
     * Revizyon notunun başına aktör etiketi düşer.
     *
     * NEDEN NOTA: gerekçesi `ControlController::actorLabel()` sınıf
     * yorumunda — `created_by_staff` sütunu tamsayı ve `OrderEditor` onu
     * `?int` alıyor.
     */
    private function revisionNote(string $actor, ?string $note): string
    {
        $label = $this->actorLabel($actor);

        return $note === null || trim($note) === ''
            ? $label
            : $label."\n".trim($note);
    }

    /** @throws ApiException */
    private function findOrder(int $orderId): Order
    {
        $order = Order::where('order_id', $orderId)->first();

        if ($order === null) {
            throw ApiException::notFound('Sipariş bulunamadı.');
        }

        return $order;
    }
}
