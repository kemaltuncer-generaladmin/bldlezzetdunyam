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
use Illuminate\Validation\Rule;
use Throwable;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\ControlAudit;
use Veykemtu\BridgeApi\Models\Invoice;
use Veykemtu\BridgeApi\Models\Subscription;
use Veykemtu\BridgeApi\Services\InvoiceService;
use Veykemtu\BridgeApi\Services\OrderStatusTransition;

/**
 * Kontrol Merkezi — fatura belgesi (`docs/control/invoices.md`).
 *
 * ## BU BELGENİN MALİ DEĞERİ YOKTUR
 *
 * İş kararı 10: fatura, YAZDIRILABİLİR BİR A4 BELGEDİR. Resmî fatura
 * değildir, e-Fatura / e-Arşiv değildir, GİB'e gitmez, VERGİ HESAPLAMAZ.
 *
 * ## BU SINIF İŞ MANTIĞI TAŞIMAZ
 *
 * Numara ayırma, anlık görüntü (`snapshot_json`), dönem dökümü ve HTML
 * çizimi `Services\InvoiceService` içindedir ve BURADA TEKRARLANMAZ.
 * Sebep somut: belgeyi kesen ikinci bir yol daha var — `auto_invoice`
 * açıkken sipariş teslim edildiğinde sunucu kendisi kesiyor. İki yol iki
 * ayrı numaralandırma yazsaydı seri boşluk verir ya da aynı numarayı iki
 * kez üretirdi. Denetleyicinin işi yalnızca "kim yaptığını iste, denetime
 * yaz, kuru provada yazma" kabuğu.
 *
 * `PATCH` YOKTUR: kesilmiş bir belgenin içeriği değiştirilemez; yanlışsa
 * iptal edilir ve yenisi kesilir. `DELETE` YOKTUR: numara boşluğu bırakan
 * bir seri, "44 nerede" sorusunu cevapsız bırakır.
 */
class InvoiceController extends ControlController
{
    public function __construct(
        private readonly InvoiceService $invoices,
        private readonly OrderStatusTransition $transitions,
    ) {}

    // ── GET / ─────────────────────────────────────────────────────────────

    public function index(Request $request): JsonResponse
    {
        $request->validate([
            'customer_id' => ['sometimes', 'integer'],
            'subscription_id' => ['sometimes', 'integer'],
            'order_id' => ['sometimes', 'integer'],
            'status' => ['sometimes', Rule::in([Invoice::STATUS_ISSUED, Invoice::STATUS_VOID])],
            'from' => ['sometimes', 'string', 'max:40'],
            'to' => ['sometimes', 'string', 'max:40'],
            'q' => ['sometimes', 'string', 'max:200'],
            'page' => ['sometimes', 'integer', 'min:1'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:100'],
        ]);

        $query = Invoice::query();

        foreach (['customer_id', 'subscription_id', 'order_id'] as $field) {
            if ($request->filled($field)) {
                $query->where($field, (int) $request->query($field));
            }
        }

        if ($request->filled('status')) {
            $query->where('status', (string) $request->query('status'));
        }

        if ($request->filled('from')) {
            $query->where('issued_at', '>=', $this->moment((string) $request->query('from'), 'from'));
        }

        if ($request->filled('to')) {
            $query->where('issued_at', '<=', $this->moment((string) $request->query('to'), 'to'));
        }

        if ($request->filled('q')) {
            $term = '%'.str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], trim((string) $request->query('q'))).'%';
            $customerIds = $this->customerIdsMatching($term);

            $query->where(function (Builder $inner) use ($term, $customerIds): void {
                $inner->where('invoice_no', 'like', $term);

                if ($customerIds !== []) {
                    $inner->orWhereIn('customer_id', $customerIds);
                }
            });
        }

        $page = max(1, (int) $request->query('page', '1'));
        $perPage = min(100, max(1, (int) $request->query('per_page', '25')));
        $total = (int) $query->clone()->count();

        $rows = $query->clone()
            ->orderByDesc('issued_at')
            ->orderByDesc('id')
            ->forPage($page, $perPage)
            ->get();

        $labels = $this->customerLabels(
            $rows->pluck('customer_id')->map(intval(...))->unique()->values()->all(),
        );

        return $this->json([
            'data' => $rows->map(fn(Invoice $row): array => $this->summaryRow($row, $labels))->values()->all(),
            'meta' => [
                'page' => $page,
                'per_page' => $perPage,
                'total' => $total,
                'last_page' => max(1, (int) ceil($total / $perPage)),
                /*
                 * SÜZGEÇLENMİŞ KÜMENİN toplamı, sayfanın değil — ekranın alt
                 * satırındaki toplam, sayfa değiştirince değişmemeli. İPTAL
                 * EDİLMİŞ BELGELER GİRMEZ: iptal edilmiş bir belgeyi toplama
                 * saymak, olmamış bir hizmeti saymaktır.
                 */
                'issued_total_kurus' => (int) $query->clone()
                    ->where('status', Invoice::STATUS_ISSUED)
                    ->sum('total_kurus'),
            ],
            'server_time' => $this->serverTime(),
        ]);
    }

    // ── GET /{id} ─────────────────────────────────────────────────────────

    public function show(int $invoice): JsonResponse
    {
        $row = $this->find($invoice);

        return $this->json([
            'data' => [
                ...$this->summaryRow($row, $this->customerLabels([(int) $row->customer_id])),
                'snapshot_json' => $row->snapshot(),
                'void_reason' => $row->void_reason,
                'created_at' => self::ts($row->created_at),
            ],
            'server_time' => $this->serverTime(),
        ]);
    }

    // ── GET /{id}/html ────────────────────────────────────────────────────

    /**
     * Yazdırılabilir A4 belge — YANIT JSON DEĞİLDİR.
     *
     * İçerik `snapshot_json`'dan üretilir, CANLI TABLODAN DEĞİL: aksi hâlde
     * aynı belge iki farklı zamanda iki farklı kâğıt üretirdi. Şablon adı
     * `InvoiceService::html()` içinde tek yerde duruyor; buradan `view()`
     * çağırmak, rota ile şablon adının ayrışabildiği ikinci bir yer açardı.
     *
     * BU UÇ DENETİM İZİNE DÜŞMEZ: belge zaten `GET /{id}` ile de okunabiliyor
     * ve yalnız basılabilir hâlini denetlemek izi eksik ve yanıltıcı kılardı.
     */
    public function html(int $invoice): Response
    {
        $row = $this->find($invoice);

        return new Response($this->invoices->html($row), 200, [
            'Content-Type' => 'text/html; charset=utf-8',
            'Content-Disposition' => 'inline; filename="'.$row->invoice_no.'.html"',
            // Belge kişisel veri taşıyor ve panel paylaşılan bir makinede
            // açılabiliyor; ara önbellekte kalması istenmiyor.
            'Cache-Control' => 'no-store',
        ]);
    }

    // ── POST / ────────────────────────────────────────────────────────────

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'order_id' => ['sometimes', 'integer'],
            'subscription_id' => ['sometimes', 'integer'],
            'period_start' => ['sometimes', 'date_format:Y-m-d'],
            'period_end' => ['sometimes', 'date_format:Y-m-d'],
            'subscription_payment_id' => ['sometimes', 'nullable', 'integer'],
        ]);

        $hasOrder = array_key_exists('order_id', $data);
        $hasSubscription = array_key_exists('subscription_id', $data);

        // İKİ KİP VAR VE BİRİ SEÇİLMELİ. İkisi birden gönderilirse hangi
        // belgenin kesileceği belirsiz; hiçbiri gönderilmezse kesilecek bir
        // şey yok.
        if ($hasOrder === $hasSubscription) {
            throw ApiException::validationFailed(
                $hasOrder
                    ? 'Sipariş ve abonelik belgesi aynı istekte kesilemez.'
                    : 'Sipariş kimliği ya da abonelik kimliği gönderilmeli.',
                ['field' => 'order_id'],
            );
        }

        return $hasOrder
            ? $this->storeOrderInvoice($request, (int) $data['order_id'])
            : $this->storePeriodInvoice($request, $data);
    }

    private function storeOrderInvoice(Request $request, int $orderId): JsonResponse
    {
        $order = Order::find($orderId);

        if ($order === null) {
            throw ApiException::notFound('Sipariş bulunamadı.');
        }

        // İPTAL EDİLMİŞ SİPARİŞE BELGE KESİLMEZ: olmamış bir hizmetin
        // belgesi olurdu.
        if ($this->transitions->codeOf($order) === OrderStatusTransition::CANCELLED) {
            throw ApiException::validationFailed(
                'İptal edilmiş siparişe belge kesilemez.',
                ['field' => 'order_id', 'reason' => 'order_cancelled'],
            );
        }

        $existing = $this->invoices->issuedForOrder($orderId);

        if ($existing !== null) {
            throw $this->existingInvoice($existing);
        }

        // ÖN GÖRÜNÜM BİR KEZ ÇIKARILIYOR ve hem kuru prova hem gerçek yazma
        // aynı hesaba bakıyor: "prova geçti ama gönderim başka şey yaptı"
        // hâli böylece oluşamaz.
        $preview = $this->invoices->previewOrder($order);

        return $this->write(
            $request,
            'invoice.create',
            ControlAudit::TARGET_INVOICE,
            null,
            // `snapshot_json` DENETİME YAZILMAZ: kişisel veriyi ve adresi
            // ikinci kez çoğaltırdı (`00-genel.md` §8.2).
            [
                'mode' => 'order',
                'order_id' => $orderId,
                'line_count' => count($preview['lines']),
                'total_kurus' => $preview['total_kurus'],
            ],
            static fn(): array => [
                'action' => 'invoice.create',
                'mode' => 'order',
                'order_id' => $orderId,
                'line_count' => count($preview['lines']),
                'total_kurus' => $preview['total_kurus'],
                // KURU PROVA NUMARA ÜRETMEZ — seride boşluk açardı.
                'existing_invoice_id' => null,
            ],
            fn(array $intent): array => [
                'data' => $this->createdRow($this->invoices->issueForOrder($order, $intent['actor'])),
            ],
        );
    }

    /** @param  array<string, mixed>  $data */
    private function storePeriodInvoice(Request $request, array $data): JsonResponse
    {
        $subscriptionId = (int) $data['subscription_id'];

        foreach (['period_start', 'period_end'] as $field) {
            if (!array_key_exists($field, $data)) {
                throw ApiException::validationFailed(
                    'Dönem belgesinde başlangıç ve bitiş tarihi zorunlu.',
                    ['field' => $field],
                );
            }
        }

        $subscription = Subscription::find($subscriptionId);

        if ($subscription === null) {
            throw ApiException::notFound('Abonelik bulunamadı.');
        }

        $from = (string) $data['period_start'];
        $to = (string) $data['period_end'];

        $existing = $this->invoices->issuedForPeriod($subscriptionId, $from, $to);

        if ($existing !== null) {
            throw $this->existingInvoice($existing);
        }

        // Aralık ve fiyat denetimleri `previewPeriod()` içinde; kuru provada
        // da koşsun diye BURADA, `write()` kabuğundan önce çağrılıyor.
        $preview = $this->invoices->previewPeriod($subscription, $from, $to);

        if ($preview['delivered_portions'] === 0) {
            // BOŞ BİR BELGE BASMAK ANLAMSIZ: müşteri elinde kalem taşımayan
            // bir kâğıtla kalırdı.
            throw ApiException::validationFailed(
                'Bu dönemde teslim edilmiş porsiyon yok.',
                ['reason' => 'no_lines'],
            );
        }

        $paymentId = isset($data['subscription_payment_id'])
            ? (int) $data['subscription_payment_id']
            : null;

        return $this->write(
            $request,
            'invoice.create',
            ControlAudit::TARGET_INVOICE,
            null,
            [
                'mode' => 'period',
                'subscription_id' => $subscriptionId,
                'period_start' => $from,
                'period_end' => $to,
                'delivered_portions' => $preview['delivered_portions'],
                'total_kurus' => $preview['total_kurus'],
            ],
            static fn(): array => [
                'action' => 'invoice.create',
                'mode' => 'period',
                'subscription_id' => $subscriptionId,
                'period_start' => $from,
                'period_end' => $to,
                'line_count' => 1,
                'planned_portions' => $preview['planned_portions'],
                'delivered_portions' => $preview['delivered_portions'],
                'skipped_days' => $preview['skipped_days'],
                'total_kurus' => $preview['total_kurus'],
                'existing_invoice_id' => null,
            ],
            fn(array $intent): array => [
                'data' => $this->createdRow($this->invoices->issueForPeriod(
                    $subscription,
                    $from,
                    $to,
                    $paymentId,
                    $intent['actor'],
                )),
            ],
        );
    }

    // ── POST /{id}/void ───────────────────────────────────────────────────

    public function void(Request $request, int $invoice): JsonResponse
    {
        $row = $this->find($invoice);

        if ($row->isVoid()) {
            throw new ApiException(
                'CONFLICT',
                'Bu belge zaten iptal edilmiş.',
                409,
                ['conflict' => 'already_void', 'invoice_no' => (string) $row->invoice_no],
            );
        }

        return $this->write(
            $request,
            'invoice.void',
            ControlAudit::TARGET_INVOICE,
            (int) $row->id,
            [
                'invoice_no' => (string) $row->invoice_no,
                'total_kurus' => (int) $row->total_kurus,
                'order_id' => $row->order_id === null ? null : (int) $row->order_id,
                'subscription_id' => $row->subscription_id === null ? null : (int) $row->subscription_id,
            ],
            static fn(): array => [
                'action' => 'invoice.void',
                'id' => (int) $row->id,
                'invoice_no' => (string) $row->invoice_no,
            ],
            function (array $intent) use ($row): array {
                /*
                 * `void_reason` ORTAK `reason` METNİDİR; ayrı bir alan
                 * istenmez. Gerekçe belgenin üzerinde basılacak ve zaten
                 * zorunlu bir alan olarak isteniyor; ikinci bir metin alanı,
                 * ikisinin çelişmesine yol açardı.
                 *
                 * BAĞLI TAHSİLAT DEĞİŞMEZ. Belge ile para ayrı şeylerdir;
                 * belgeyi iptal etmek parayı geri vermez.
                 */
                $voided = $this->invoices->void($row, $intent['reason']);

                return [
                    'data' => [
                        'id' => (int) $voided->id,
                        'invoice_no' => (string) $voided->invoice_no,
                        'status' => (string) $voided->status,
                        'void_at' => self::ts($voided->void_at),
                        'void_reason' => $voided->void_reason,
                    ],
                ];
            },
        );
    }

    // ── Yardımcılar ───────────────────────────────────────────────────────

    private function find(int $id): Invoice
    {
        $row = Invoice::find($id);

        if ($row === null) {
            throw ApiException::notFound('Belge bulunamadı.');
        }

        return $row;
    }

    /**
     * Aynı kaynağa geçerli bir belge varsa `409`.
     *
     * İkinci bir belge kesmek isteyen önce eskisini iptal eder; aksi hâlde
     * müşterinin elinde aynı hizmetin iki belgesi olurdu.
     */
    private function existingInvoice(Invoice $existing): ApiException
    {
        return new ApiException(
            'CONFLICT',
            'Bu kayıt için zaten geçerli bir belge var.',
            409,
            [
                'conflict' => 'existing_invoice',
                'invoice_id' => (int) $existing->id,
                'invoice_no' => (string) $existing->invoice_no,
            ],
        );
    }

    /** @return array<string, mixed> */
    private function createdRow(Invoice $invoice): array
    {
        $snapshot = $invoice->snapshot();

        return [
            'id' => (int) $invoice->id,
            'invoice_no' => (string) $invoice->invoice_no,
            'status' => (string) $invoice->status,
            'total_kurus' => (int) $invoice->total_kurus,
            'line_count' => count($snapshot['lines'] ?? []),
            'issued_at' => self::ts($invoice->issued_at),
            'html_url' => $invoice->htmlUrl(),
        ];
    }

    /**
     * @param  array<int, string>  $labels
     * @return array<string, mixed>
     */
    private function summaryRow(Invoice $row, array $labels): array
    {
        return [
            'id' => (int) $row->id,
            'invoice_no' => (string) $row->invoice_no,
            'status' => (string) $row->status,
            'customer_id' => (int) $row->customer_id,
            'customer_label' => $labels[(int) $row->customer_id] ?? null,
            'order_id' => $row->order_id === null ? null : (int) $row->order_id,
            'subscription_id' => $row->subscription_id === null ? null : (int) $row->subscription_id,
            'subscription_payment_id' => $row->subscription_payment_id === null
                ? null
                : (int) $row->subscription_payment_id,
            'period_start' => $row->period_start === null
                ? null
                : Carbon::parse((string) $row->period_start)->toDateString(),
            'period_end' => $row->period_end === null
                ? null
                : Carbon::parse((string) $row->period_end)->toDateString(),
            'issued_at' => self::ts($row->issued_at),
            'total_kurus' => (int) $row->total_kurus,
            'void_at' => self::ts($row->void_at),
            'html_url' => $row->htmlUrl(),
        ];
    }

    /**
     * @param  list<int>  $ids
     * @return array<int, string>
     */
    private function customerLabels(array $ids): array
    {
        if ($ids === []) {
            return [];
        }

        $labels = [];

        foreach (DB::table('customers')->whereIn('customer_id', $ids)->get() as $row) {
            // KURUM ADI ÖNCE: bu bir catering sistemi ve kayıtların çoğu bir
            // şirkete ait; kişi adı orada irtibat kişisidir.
            $org = trim((string) ($row->bld_org_name ?? ''));

            $labels[(int) $row->customer_id] = $org !== ''
                ? $org
                : trim(((string) $row->first_name).' '.((string) $row->last_name));
        }

        return $labels;
    }

    /** @return list<int> */
    private function customerIdsMatching(string $term): array
    {
        return DB::table('customers')
            ->where('bld_org_name', 'like', $term)
            ->orWhere('first_name', 'like', $term)
            ->orWhere('last_name', 'like', $term)
            ->pluck('customer_id')
            ->map(intval(...))
            ->values()
            ->all();
    }

    private function moment(string $value, string $field): Carbon
    {
        try {
            return Carbon::parse($value)->utc();
        } catch (Throwable) {
            throw ApiException::validationFailed(
                'Zaman damgası ISO 8601 (UTC) biçiminde olmalı.',
                ['field' => $field],
            );
        }
    }
}
