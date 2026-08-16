<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers\Control;

use Igniter\Cart\Models\Order;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\Rule;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\ControlAudit;
use Veykemtu\BridgeApi\Models\PaymentRefund;
use Veykemtu\BridgeApi\Services\OrderEditor;
use Veykemtu\BridgeApi\Services\OrderPresenter;
use Veykemtu\BridgeApi\Services\OrderStatusTransition;
use Veykemtu\BridgeApi\Support\BusinessTime;
use Veykemtu\BridgeApi\Support\Money;

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

    /**
     * Panel sipariş listesi — GEÇMİŞE BAKAR, SAYFALANIR, SÜZÜLÜR.
     *
     * `index()` İLE AYRI METOT OLMASI ZORUNLU. `index()` mutfak panosuyla
     * aynı kümeyi döner (bugün + terminal olmayanlar) ve KDS ekranı ona
     * bağlı; tek metot olsaydı panelin süzgeçleri KDS'in gördüğü kümeyi
     * değiştirirdi. İki uç iki yolda: `control/kds/orders` mutfağın gözü,
     * `control/orders` yönetimin gözü.
     *
     * LİSTEDE FİYAT VARDIR. ADR-08 **mutfak kapsamını** para görmekten men
     * ediyor çünkü kasa ekranı gün boyu mutfakta açık duruyor; Kontrol
     * Merkezi bir yönetim yüzeyi ve ciro sorusuna cevap vermek zorunda.
     * Kural kaldırılmadı, daraltıldı.
     */
    public function panelIndex(Request $request): JsonResponse
    {
        $this->validateFilters($request);

        [$from, $to] = $this->filterWindow($request);
        $query = $this->filteredQuery($request, $from, $to);

        $perPage = min(100, max(1, (int) $request->query('per_page', '25')));
        $page = max(1, (int) $request->query('page', '1'));

        $total = (int) $query->count();

        $orders = $query
            ->orderByDesc('order_id')
            ->forPage($page, $perPage)
            ->get();

        return $this->json([
            'data' => $this->rows($orders),
            'meta' => [
                'page' => $page,
                'per_page' => $perPage,
                'total' => $total,
                // Toplam sıfırken bile en az bir sayfa vardır; `0` dönmek
                // istemciye "sayfa yok" dedirtip boş durumu çizdirmezdi.
                'last_page' => max(1, (int) ceil($total / $perPage)),
            ],
            'server_time' => $this->serverTime(),
        ]);
    }

    /**
     * CSV dışa aktarım — muhasebe ve tedarik planlaması için.
     *
     * YANIT JSON DEĞİL. Sütun başlıkları Türkçe, veri makine okunur;
     * para sütunları KURUŞ TAM SAYIDIR — TL'ye çevirmek, ondalık ayracının
     * Excel yerel ayarına bağlı olması demekti.
     *
     * DOSYA UTF-8 BOM İLE BAŞLAR. BOM olmadan Excel Türkçe karakterleri
     * bozuyor ve dosyayı açan muhasebeci "ğ" yerine kutu görüyor.
     *
     * Bu uç OKUMA olduğu için denetim izine düşmez; kararın gerekçesi ve
     * bilinçli eksikliği `docs/control/orders.md` içinde yazılı.
     */
    public function export(Request $request): Response
    {
        $this->validateFilters($request);

        $request->validate([
            'format' => ['sometimes', Rule::in(['csv'])],
            'max_rows' => ['sometimes', 'integer', 'min:1', 'max:20000'],
        ]);

        [$from, $to] = $this->filterWindow($request);
        $limit = min(20000, max(1, (int) $request->query('max_rows', '5000')));

        $query = $this->filteredQuery($request, $from, $to);
        $total = (int) $query->count();

        $orders = $query->orderByDesc('order_id')->limit($limit)->get();
        $rows = $this->rows($orders);

        // UTF-8 BOM + CRLF: ikisi de Excel içindir, tarayıcı için değil.
        $csv = "\u{FEFF}".$this->csvLine([
            'siparis_no', 'servis_gunu', 'olusturulma', 'durum', 'teslimat_turu',
            'musteri_id', 'musteri', 'telefon', 'kalem_sayisi', 'ara_toplam_kurus',
            'teslimat_ucreti_kurus', 'toplam_kurus', 'odeme_yontemi', 'odeme_durumu',
            'abonelik_id', 'revizyon_no', 'fatura_no',
        ]);

        foreach ($rows as $row) {
            $csv .= $this->csvLine([
                $row['order_number'],
                $row['service_date'],
                $row['created_at'],
                $row['status'],
                $row['delivery_type'],
                $row['customer_id'],
                $row['customer_name'],
                $row['customer_phone'],
                $row['item_count'],
                $row['subtotal_kurus'],
                $row['delivery_fee_kurus'],
                $row['total_kurus'],
                $row['payment_method'],
                $row['payment_status'],
                $row['subscription_id'],
                $row['revision_no'],
                $row['invoice_no'],
            ]);
        }

        return new Response($csv, 200, [
            'Content-Type' => 'text/csv; charset=utf-8',
            'Content-Disposition' => 'attachment; filename="bld-siparisler-'
                .$from->toDateString().'_'.$to->toDateString().'.csv"',
            'X-Total-Rows' => (string) $total,
            // KESİLMİŞ DOSYA, HİÇ DOSYA OLMAMASINDAN İYİDİR. Hata dönmek
            // yerine başlıkla söylüyoruz; ekran uyarıyı gösterir.
            'X-Truncated' => $total > count($rows) ? 'true' : 'false',
        ]);
    }

    /** Tek sipariş, düzenlenebilir görünüm — fiyatsız (ADR-08). */
    public function show(int $order): JsonResponse
    {
        $model = $this->findOrder($order);
        $status = $this->transitions->codeOf($model);
        $totals = $this->presenter->totals($model);

        return $this->json([
            'data' => [
                ...$this->presenter->editable($model),
                'service_date' => $this->presenter->serviceDate($model),
                // `editable` ADI ALTINDA BİR BAYRAK: `OrderEditor` aynı
                // kararı istisna atarak veriyor ve ekranın kaydet düğmesini
                // gizlemek için istisna yakalaması saçma olurdu.
                'editable' => !in_array($status, [
                    OrderStatusTransition::DELIVERED,
                    OrderStatusTransition::CANCELLED,
                ], true),
                'not_editable_reason' => match ($status) {
                    OrderStatusTransition::DELIVERED => 'delivered',
                    OrderStatusTransition::CANCELLED => 'cancelled',
                    default => null,
                },
                /*
                 * PANEL FİYATI GÖRÜR — `editable()` çıktısı fiyatsız
                 * kalıyor (ADR-08, mutfak kapsamı), tutarlar onun YANINA
                 * ekleniyor. Anahtar adı `totals`; mutfak testinin
                 * sabitlediği `total` anahtarı hiçbir yerde doğmuyor.
                 */
                'totals' => [
                    'subtotal_kurus' => $totals['subtotal'],
                    'delivery_fee_kurus' => $totals['delivery'],
                    'total_kurus' => $totals['total'],
                    'currency' => 'TRY',
                ],
                'payment' => [
                    'method' => (string) ($model->payment ?? 'cash'),
                    'status' => $this->paymentStatus($model, $this->refundedOrderIds([$model])),
                ],
                'invoice' => $this->invoiceOf((int) $model->order_id)
                    ?? ['id' => null, 'invoice_no' => null],
                // Sunucunun geri alma penceresi YÜZEYE ÇIKIYOR: ekran
                // kendi 120 saniyesini saymamalı, sunucununkini
                // göstermeli (istemcinin saati kaymış olabilir).
                'transitions' => $this->transitionState($model),
            ],
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

                return [
                    'order' => $this->presenter->kitchen($updated),
                    // GERİ ALMA PENCERESİ SUNUCUDAN OKUNUR. Ekran kendi
                    // 120 saniyesini saysaydı, saati kaymış bir istemci ya
                    // erken kapatır ya da kapanmış bir kapıyı açık gösterip
                    // kullanıcıya 422 aldırırdı.
                    'transitions' => $this->transitionState($updated),
                ];
            },
        );
    }

    /**
     * Sipariş iptali.
     *
     * `status` UCUNA `iptal` GÖNDERMEKTEN FARKLI ve ayrı bir uç olması
     * bunun içindir: iptal PARA HAREKETİ üretir (ödenmiş siparişin iadesi)
     * ve o gün için satılmış porsiyonları serbest bırakır. Aynı gövdeyle
     * aynı yerden yapılsaydı, "durumu ilerlet" ile "parayı geri ver" tek
     * bir düğmenin arkasında birleşirdi.
     */
    public function cancel(Request $request, int $order): JsonResponse
    {
        $model = $this->findOrder($order);

        $data = $request->validate([
            'reason' => $this->orderReasonRules(),
            'refund' => ['sometimes', 'boolean'],
            'notify_customer' => ['sometimes', 'boolean'],
        ]);

        $from = $this->transitions->codeOf($model);

        // ZATEN İPTAL → 409, "geçersiz geçiş" değil. Ekranın yapacağı şey
        // farklı: tazele ve tekrar sor (`00-genel.md` §7.2).
        if ($from === OrderStatusTransition::CANCELLED) {
            throw new ApiException(
                'CONFLICT',
                'Sipariş zaten iptal edilmiş.',
                409,
                ['conflict' => 'status', 'status' => $from],
            );
        }

        // TESLİM EDİLMİŞ SİPARİŞ İPTAL EDİLEMEZ — olmuş bir şeyi olmamış
        // saymaktır. İade gerekiyorsa revizyon yolu kullanılır ve orada
        // tutar açıkça yazılır. Kararı yine matris veriyor.
        $this->transitions->assertAllowed($model, $from, OrderStatusTransition::CANCELLED);

        $wantsRefund = $request->boolean('refund', true);
        $wantsNotify = $request->boolean('notify_customer', true);

        $paid = (bool) $model->processed;
        $refundKurus = $paid ? Money::toKurus($model->order_total) : 0;
        $released = $this->stockRelease($model);

        return $this->write(
            $request,
            'order.cancel',
            ControlAudit::TARGET_ORDER,
            (int) $model->order_id,
            [
                'from' => $from,
                'refund_requested' => $wantsRefund,
                'refund_kurus' => $refundKurus,
                'notify_requested' => $wantsNotify,
            ],
            static fn(): array => [
                'action' => 'order.cancel',
                'order_id' => (int) $model->order_id,
                'from' => $from,
                'refund_kurus' => $refundKurus,
                'would_refund' => $wantsRefund && $refundKurus > 0,
                'would_notify' => $wantsNotify,
                'stock_would_release' => $released,
            ],
            function (array $intent) use (
                $model,
                $data,
                $wantsRefund,
                $wantsNotify,
                $refundKurus,
                $released,
            ): array {
                $before = $this->refundRowCount((int) $model->order_id);

                $updated = $this->transitions->apply(
                    $model,
                    OrderStatusTransition::CANCELLED,
                    null,
                    $this->actorLabel($intent['actor']).': '.$data['reason'],
                );

                $refundCreated = $this->refundRowCount((int) $model->order_id) > $before;

                return [
                    'order' => $this->presenter->kitchen($updated),
                    'data' => [
                        'refund_kurus' => $refundKurus,
                        'refund_created' => $refundCreated,
                        // SMS KATMANI HENÜZ BAĞLI DEĞİL; alan yalan
                        // söylemesin diye gerçek durum dönüyor ve
                        // aşağıdaki uyarı bunu açıkça yazıyor.
                        'sms_sent' => false,
                        /*
                         * İPTALİN EN ÖNEMLİ YAN ETKİSİ. İptal edilen
                         * porsiyonlar gün toplamından ve ürün tavanından
                         * düşer, yani o kadar sipariş yeniden alınabilir
                         * hâle gelir. Ekran bunu göstermezse yönetici
                         * "neden birden 12 yer açıldı" diye sorar.
                         */
                        'stock_released' => $released,
                    ],
                    'warnings' => $this->cancelWarnings(
                        $wantsRefund,
                        $wantsNotify,
                        $refundCreated,
                        $refundKurus,
                    ),
                ];
            },
        );
    }

    /**
     * Siparişin fatura belgesi.
     *
     * BELGE YOKSA ÜRETMEZ — üretim `POST /api/control/invoices` işidir.
     * Burada yalnız var olana bakılır; bir GET'in belge doğurması,
     * yoklayan bir ekranın her turda yeni fatura kesmesi demekti.
     */
    public function invoice(int $order): JsonResponse
    {
        $this->findOrder($order);

        $invoice = $this->invoiceOf($order);

        if ($invoice === null) {
            throw ApiException::notFound('Bu siparişe ait fatura belgesi oluşturulmamış.');
        }

        return $this->json([
            'data' => $invoice,
            'server_time' => $this->serverTime(),
        ]);
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

    /** Liste ve dışa aktarımın ORTAK süzgeç doğrulaması. */
    private function validateFilters(Request $request): void
    {
        $request->validate([
            'service_date' => ['sometimes', 'date_format:Y-m-d'],
            'from' => ['sometimes', 'date_format:Y-m-d'],
            'to' => ['sometimes', 'date_format:Y-m-d'],
            'status' => ['sometimes', 'string'],
            'delivery_type' => ['sometimes', Rule::in(['delivery', 'pickup'])],
            'customer_id' => ['sometimes', 'integer', 'min:1'],
            'subscription_id' => ['sometimes', 'integer', 'min:1'],
            'source' => ['sometimes', Rule::in(['all', 'manual', 'subscription'])],
            'q' => ['sometimes', 'string', 'max:120'],
            'page' => ['sometimes', 'integer', 'min:1'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:100'],
        ]);
    }

    /**
     * Süzgeç penceresi.
     *
     * SÜZGEÇ VERİLMEZSE SON 7 GÜN. Sınırsız bir varsayılan, ilk sayfada
     * bir yılın verisini saydırırdı ve `total` sorgusu her yoklamada
     * bütün tabloyu tarardı.
     *
     * @return array{0: Carbon, 1: Carbon}
     */
    private function filterWindow(Request $request): array
    {
        if ($request->filled('service_date')) {
            $day = Carbon::parse((string) $request->query('service_date'))->startOfDay();

            return [$day, $day->copy()];
        }

        $to = $request->filled('to')
            ? Carbon::parse((string) $request->query('to'))->startOfDay()
            : BusinessTime::now()->startOfDay();

        $from = $request->filled('from')
            ? Carbon::parse((string) $request->query('from'))->startOfDay()
            : $to->copy()->subDays(6);

        return $from->greaterThan($to) ? [$to, $from] : [$from, $to];
    }

    /**
     * Süzülmüş sipariş sorgusu.
     *
     * SERVİS GÜNÜNE göre süzülüyor (`bld_service_date`), `created_at`'e
     * göre değil: yönetici "yarın kaç kişilik yemek çıkacak" diye soruyor,
     * "dün kaç sipariş girildi" diye değil.
     */
    private function filteredQuery(Request $request, Carbon $from, Carbon $to): Builder
    {
        $query = Order::query()
            ->whereDate('bld_service_date', '>=', $from->toDateString())
            ->whereDate('bld_service_date', '<=', $to->toDateString());

        if ($request->filled('status')) {
            $codes = array_values(array_intersect(
                array_map(trim(...), explode(',', (string) $request->query('status'))),
                OrderStatusTransition::CODES,
            ));

            // Tanınmayan kod SESSİZCE ELENMEZ, boş sonuç üretir: eksik
            // eşleşmeyi "hiç sipariş yok" diye göstermek, yanlış koda
            // rağmen dolu bir liste göstermekten dürüsttür.
            $query->whereIn(
                'status_id',
                DB::table('statuses')->whereIn('status_code', $codes)->pluck('status_id'),
            );
        }

        if ($request->filled('delivery_type')) {
            $query->where(
                'order_type',
                $request->query('delivery_type') === 'delivery' ? Order::DELIVERY : Order::COLLECTION,
            );
        }

        if ($request->filled('customer_id')) {
            $query->where('customer_id', (int) $request->query('customer_id'));
        }

        if ($request->filled('subscription_id')) {
            $query->where('bld_subscription_id', (int) $request->query('subscription_id'));
        }

        $source = (string) $request->query('source', 'all');
        if ($source === 'subscription') {
            $query->whereNotNull('bld_subscription_id');
        } elseif ($source === 'manual') {
            $query->whereNull('bld_subscription_id');
        }

        if ($request->filled('q')) {
            $term = trim((string) $request->query('q'));

            $query->where(function (Builder $inner) use ($term): void {
                // Sipariş numarası "S-8421" biçiminde gösteriliyor ama
                // sütun sayısal; öneki atıp kimlik olarak arıyoruz.
                $digits = preg_replace('/\D+/', '', $term) ?? '';

                if ($digits !== '') {
                    $inner->orWhere('order_id', (int) $digits);
                    $inner->orWhere('telephone', 'like', '%'.$digits.'%');
                }

                $inner->orWhere('first_name', 'like', '%'.$term.'%');
                $inner->orWhere('last_name', 'like', '%'.$term.'%');
            });
        }

        return $query;
    }

    /**
     * Sipariş satırları — liste ve CSV aynı üreticiden beslenir.
     *
     * İADE VE FATURA TEK SORGUDA toplanıyor, satır başına bir tane değil:
     * yirmi beş satırlık bir sayfa elli ek sorgu demek olurdu ve liste
     * on beş saniyede bir yokleniyor.
     *
     * @param  \Illuminate\Database\Eloquent\Collection<int, Order>  $orders
     * @return list<array<string, mixed>>
     */
    private function rows($orders): array
    {
        $refunded = $this->refundedOrderIds($orders);
        $invoices = $this->invoiceNumbers($orders);

        return $orders
            ->map(function (Order $order) use ($refunded, $invoices): array {
                $totals = $this->presenter->totals($order);
                $id = (int) $order->order_id;

                return [
                    'id' => $id,
                    'order_number' => $this->presenter->number($order),
                    'status' => $this->transitions->codeOf($order),
                    'service_date' => $this->presenter->serviceDate($order),
                    'requested_at' => $this->presenter->requestedAt($order),
                    'delivery_type' => $this->presenter->deliveryType($order),
                    'customer_id' => $order->customer_id !== null ? (int) $order->customer_id : null,
                    'customer_name' => $this->presenter->customerName($order),
                    'customer_phone' => $this->presenter->customerPhone($order),
                    'item_count' => (int) ($order->total_items ?? 0),
                    'subtotal_kurus' => $totals['subtotal'],
                    'delivery_fee_kurus' => $totals['delivery'],
                    'total_kurus' => $totals['total'],
                    'payment_method' => (string) ($order->payment ?? 'cash'),
                    'payment_status' => $this->paymentStatus($order, $refunded),
                    'is_subscription' => $order->bld_subscription_id !== null,
                    'subscription_id' => $order->bld_subscription_id !== null
                        ? (int) $order->bld_subscription_id
                        : null,
                    'revision_no' => (int) ($order->bld_revision_no ?? 0),
                    'has_invoice' => isset($invoices[$id]),
                    'invoice_no' => $invoices[$id] ?? null,
                    'created_at' => self::ts($order->created_at),
                    'updated_at' => self::ts($order->updated_at),
                ];
            })
            ->values()
            ->all();
    }

    /**
     * İadesi tamamlanmış sipariş kimlikleri.
     *
     * @param  iterable<int, Order>  $orders
     * @return array<int, true>
     */
    private function refundedOrderIds(iterable $orders): array
    {
        $ids = [];
        foreach ($orders as $order) {
            $ids[] = (int) $order->order_id;
        }

        if ($ids === []) {
            return [];
        }

        $rows = DB::table('veykemtu_payment_refunds')
            ->whereIn('order_id', $ids)
            ->where('status', PaymentRefund::STATUS_SUCCEEDED)
            ->pluck('order_id');

        $map = [];
        foreach ($rows as $id) {
            $map[(int) $id] = true;
        }

        return $map;
    }

    /**
     * `pending` · `paid` · `refunded`.
     *
     * `failed` SÖZLEŞMEDE VAR AMA BURADA DOĞMUYOR: başarısız tahsilat
     * siparişi `processed = 0` bırakıyor, yani `pending`'den ayırt
     * edilebilir bir izi yok. Uydurulmuş bir `failed`, panelde asla
     * doğrulanamayacak bir rozet olurdu.
     *
     * @param  array<int, true>  $refunded
     */
    private function paymentStatus(Order $order, array $refunded): string
    {
        if (isset($refunded[(int) $order->order_id])) {
            return 'refunded';
        }

        return (bool) $order->processed ? 'paid' : 'pending';
    }

    /**
     * Sipariş kimliği → fatura numarası.
     *
     * TABLO HENÜZ YOKSA BOŞ DÖNER. Fatura alanı ayrı bir fazda geliyor;
     * `has_invoice` alanını sözleşmeden çıkarmak yerine "belge yok" demek,
     * panelin bugünden çalışmasını sağlıyor ve tablo geldiği gün tek satır
     * bile değişmiyor.
     *
     * @param  iterable<int, Order>  $orders
     * @return array<int, string>
     */
    private function invoiceNumbers(iterable $orders): array
    {
        if (!Schema::hasTable('veykemtu_invoices')) {
            return [];
        }

        $ids = [];
        foreach ($orders as $order) {
            $ids[] = (int) $order->order_id;
        }

        if ($ids === []) {
            return [];
        }

        $map = [];
        foreach (DB::table('veykemtu_invoices')->whereIn('order_id', $ids)->get() as $row) {
            $map[(int) $row->order_id] = (string) $row->invoice_no;
        }

        return $map;
    }

    /**
     * Siparişin fatura belgesi — yoksa `null`.
     *
     * @return array<string, mixed>|null
     */
    private function invoiceOf(int $orderId): ?array
    {
        if (!Schema::hasTable('veykemtu_invoices')) {
            return null;
        }

        $row = DB::table('veykemtu_invoices')->where('order_id', $orderId)->first();

        if ($row === null) {
            return null;
        }

        return [
            'id' => (int) $row->id,
            'invoice_no' => (string) $row->invoice_no,
            'order_id' => $orderId,
            'status' => (string) $row->status,
            'issued_at' => self::ts($row->issued_at ?? null),
            'total_kurus' => (int) ($row->total_kurus ?? 0),
            'html_url' => '/api/control/invoices/'.((int) $row->id).'/html',
        ];
    }

    private function refundRowCount(int $orderId): int
    {
        return (int) DB::table('veykemtu_payment_refunds')->where('order_id', $orderId)->count();
    }

    /**
     * İptalde serbest kalan porsiyonlar.
     *
     * BİLEŞEN SATIRLARI SAYILMAZ (B-19): günün menüsü bir paket satırı +
     * sıfır fiyatlı bileşenler olarak yazılıyor ve stoku tüketen şey
     * PAKETİN kendisi. Bileşenler de sayılsaydı iptal, gün toplamına
     * olduğundan kat kat fazla yer açmış gibi görünürdü.
     *
     * @return array{day:int, items: list<array{menu_id:int, quantity:int}>}
     */
    private function stockRelease(Order $order): array
    {
        $items = [];
        $day = 0;

        foreach ($this->presenter->editable($order)['items'] as $line) {
            $quantity = (int) $line['quantity'];
            $day += $quantity;
            $items[] = ['menu_id' => (int) $line['menu_id'], 'quantity' => $quantity];
        }

        return ['day' => $day, 'items' => $items];
    }

    /**
     * İptalin dürüst uyarıları.
     *
     * @return list<string>
     */
    private function cancelWarnings(
        bool $wantsRefund,
        bool $wantsNotify,
        bool $refundCreated,
        int $refundKurus,
    ): array {
        $warnings = [];

        /*
         * `refund: false` ÖDENMİŞ BİR SİPARİŞTE SERBESTTİR — bazen para
         * elden iade edilir ve sistemin ikinci kez iade üretmemesi
         * gerekir. Ne var ki iade kaydını `OrderStatusTransition::apply()`
         * açıyor ve o sınıf bu kulvarın dışında; bugün kaydı bastıramıyoruz.
         * SESSİZ KALMAK YERİNE SÖYLÜYORUZ: panel kaydı görüp elle
         * kapatabilir. Eksik rapora düşürüldü.
         */
        if (!$wantsRefund && $refundCreated) {
            $warnings[] = 'İade istenmedi ama otomatik iade kaydı açıldı;'
                .' elden iade yapıldıysa panelden kapatılmalı.';
        }

        if ($wantsRefund && $refundKurus === 0) {
            $warnings[] = 'Sipariş tahsil edilmemişti; iade edilecek tutar yok.';
        }

        if ($wantsNotify) {
            $warnings[] = 'İptal SMS\'i gönderilmedi: SMS şablon altyapısı henüz bağlı değil.';
        }

        return $warnings;
    }

    /**
     * Sunucunun durum makinesi yüzeye çıkıyor — YENİDEN UYGULANMIYOR.
     *
     * `allowed` matristen, `can_undo` ve `undo_until` geri alma
     * penceresinden geliyor (`OrderStatusTransition::UNDO_WINDOW_SECONDS`).
     * Ekranın kendi sayacını tutması, saati kaymış bir istemcide kapıyı
     * ya erken kapatır ya da kapanmış bir kapıyı açık gösterirdi.
     *
     * @return array<string, mixed>
     */
    private function transitionState(Order $order): array
    {
        $undoTo = $this->transitions->undoTargetFor($order);
        $changedAt = $order->status_updated_at;

        return [
            'current' => $this->transitions->codeOf($order),
            'allowed' => $this->transitions->allowedFrom($order),
            'can_undo' => $undoTo !== null,
            'undo_to' => $undoTo,
            'undo_until' => $undoTo !== null && $changedAt !== null
                ? Carbon::parse($changedAt)
                    ->addSeconds(OrderStatusTransition::UNDO_WINDOW_SECONDS)
                    ->utc()
                    ->toIso8601ZuluString()
                : null,
            'undo_window_seconds' => OrderStatusTransition::UNDO_WINDOW_SECONDS,
        ];
    }

    /**
     * Tek CSV satırı — virgül ayraç, çift tırnak sınırlayıcı, `\r\n` son.
     *
     * `fputcsv()` KULLANILMIYOR: satır sonunu `\n` yazıyor ve Excel'in
     * beklediği `\r\n` değil. Bir dosya tanıtıcısı açıp sonra satır
     * sonlarını değiştirmek, elle birleştirmekten daha çok kod olurdu.
     *
     * @param  list<mixed>  $values
     */
    private function csvLine(array $values): string
    {
        $cells = array_map(
            static fn(mixed $value): string => '"'.str_replace(
                '"',
                '""',
                $value === null ? '' : (string) $value,
            ).'"',
            $values,
        );

        return implode(',', $cells)."\r\n";
    }
}
