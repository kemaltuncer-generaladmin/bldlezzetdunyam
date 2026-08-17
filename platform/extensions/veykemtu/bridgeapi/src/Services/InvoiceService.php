<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use Igniter\Cart\Models\Order;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\Invoice;
use Veykemtu\BridgeApi\Models\InvoiceCounter;
use Veykemtu\BridgeApi\Models\Subscription;
use Veykemtu\BridgeApi\Support\BusinessTime;
use Veykemtu\BridgeApi\Support\Money;

/**
 * Fatura belgesinin tek üreticisi — `docs/control/invoices.md` (B2).
 *
 * BU BELGENİN MALİ DEĞERİ YOKTUR: e-Fatura değil, e-Arşiv değil, GİB'e
 * gitmez, KDV hesaplamaz. Yine de numarası boşluksuz ve içeriği donmuştur;
 * ikisi de bir gün gerçek entegrasyon takılacaksa bugün ödenmesi gereken
 * bedeldir.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * İKİ DEĞİŞMEZ
 *
 * 1. NUMARA SAYAÇTAN GELİR (`InvoiceCounter::allocate`), `MAX+1`'den değil.
 *    Gerekçe o sınıfın başında; özeti: eşzamanlı iki kesim aynı numarayı
 *    alır ve tekil indeks yazdır düğmesini 500'e çevirir.
 *
 * 2. İÇERİK KESİM ANINDA DONAR (`snapshot_json`). Belge canlı tablodan
 *    çizilseydi, sipariş sonradan düzenlendiğinde (K-12 revizyonları
 *    olağan) aynı belge iki farklı kâğıt üretirdi ve müşterinin elindeki
 *    kopya "yanlış" olurdu. HTML render'ı canlı tabloya HİÇ bakmaz.
 * ─────────────────────────────────────────────────────────────────────────
 *
 * KURU PROVA NUMARA ÜRETMEZ. `preview*` metotları tutarı ve satırları
 * hesaplar, sayaca dokunmaz — dokunsaydı her iptal edilen prova seride bir
 * boşluk bırakırdı.
 */
final class InvoiceService
{
    /**
     * Belgeden KALDIRILAMAZ ibare — `docs/control/invoices.md`.
     *
     * Metin sabit ve tek yerde: iki farklı yerde yazılsaydı biri
     * güncellenip öteki unutulur ve iki farklı belge iki farklı şey iddia
     * ederdi.
     */
    public const string NOTICE = 'Bu belge bilgilendirme amaçlıdır, mali değeri yoktur.';

    /** İbarenin ikinci cümlesi: belgenin ne OLMADIĞI. */
    public const string NOTICE_EXTRA = 'Fatura yerine geçmez.';

    private const string VIEW = 'veykemtu.bridgeapi::invoice.document';

    /** Bir dönem belgesinin kapsayabileceği en uzun aralık (gün). */
    public const int MAX_PERIOD_DAYS = 62;

    public function __construct(
        private readonly OrderPresenter $presenter,
        private readonly SiteContentRepository $content,
    ) {}

    // ── Var olan belgeler ────────────────────────────────────────────────

    /** Siparişin GEÇERLİ belgesi — iptal edilmişler sayılmaz. */
    public function issuedForOrder(int $orderId): ?Invoice
    {
        /** @var Invoice|null */
        return Invoice::query()
            ->issued()
            ->where('order_id', $orderId)
            ->orderByDesc('id')
            ->first();
    }

    /** Aynı aboneliğin aynı dönemi için GEÇERLİ belge. */
    public function issuedForPeriod(int $subscriptionId, string $from, string $to): ?Invoice
    {
        /** @var Invoice|null */
        return Invoice::query()
            ->issued()
            ->where('subscription_id', $subscriptionId)
            ->whereDate('period_start', $from)
            ->whereDate('period_end', $to)
            ->orderByDesc('id')
            ->first();
    }

    // ── Sipariş belgesi ──────────────────────────────────────────────────

    /**
     * Kesmeden önce ne yazacağını gösterir — kuru prova.
     *
     * @return array{lines: list<array<string, mixed>>, subtotal_kurus: int, delivery_kurus: int, total_kurus: int}
     */
    public function previewOrder(Order $order): array
    {
        $lines = $this->orderLines($order);
        $totals = $this->presenter->totals($order);

        return [
            'lines' => $lines,
            'subtotal_kurus' => $totals['subtotal'],
            'delivery_kurus' => $totals['delivery'],
            'total_kurus' => $totals['total'],
        ];
    }

    /**
     * Sipariş belgesini keser.
     *
     * NUMARA AYIRMA VE SATIR YAZMA AYNI İŞLEMDE: sayaç ilerleyip belge
     * yazılamazsa seride bir boşluk kalırdı ve "44 nerede" sorusunun
     * cevabı olmazdı.
     */
    public function issueForOrder(Order $order, string $actor): Invoice
    {
        $preview = $this->previewOrder($order);
        $customerId = (int) ($order->customer_id ?? 0);

        $snapshot = [
            'issuer' => $this->issuer(),
            'customer' => $this->orderCustomer($order),
            'document' => [
                'kind' => Invoice::TYPE_ORDER,
                'order_number' => $this->presenter->number($order),
                'service_date' => $this->presenter->serviceDate($order),
                'delivery_type' => $this->presenter->deliveryType($order),
            ],
            'lines' => $preview['lines'],
            'totals' => [
                'subtotal_kurus' => $preview['subtotal_kurus'],
                'delivery_fee_kurus' => $preview['delivery_kurus'],
                'total_kurus' => $preview['total_kurus'],
                'currency' => 'TRY',
            ],
            'payment' => $this->orderPayment($order),
            'notice' => self::NOTICE,
        ];

        return $this->persist([
            'type' => Invoice::TYPE_ORDER,
            'order_id' => (int) $order->order_id,
            'customer_id' => $customerId,
            'subtotal_kurus' => $preview['subtotal_kurus'],
            'delivery_kurus' => $preview['delivery_kurus'],
            'total_kurus' => $preview['total_kurus'],
            'snapshot_json' => $snapshot,
            'created_by_actor' => $actor,
        ]);
    }

    // ── Abonelik dönem belgesi ───────────────────────────────────────────

    /**
     * Dönemin dökümü — kesmeden.
     *
     * PLANLANAN İLE TESLİM EDİLEN AYRI SAYILIR. Abone gün atlayabiliyor
     * (iş kuralı: atlanan porsiyon serbest satışa döner) ve atladığı günün
     * parasını ödememeli. Belge ikisini de yazar: müşteri "neden bu kadar"
     * sorusunun cevabını kâğıdın üstünde görmeli, bizi aramak zorunda
     * kalmamalı.
     *
     * TESLİM EDİLEN, ÜRETİM DEFTERİNDEN OKUNUR (`veykemtu_subscription_runs`
     * ⋈ iptal olmayan siparişler). Kuralın kendisinden hesaplansaydı, iptal
     * edilmiş bir günün porsiyonu da faturaya girerdi.
     *
     * @return array{unit_price_kurus: int, planned_days: list<string>, planned_portions: int, delivered_days: list<string>, delivered_portions: int, skipped_days: list<string>, total_kurus: int}
     */
    public function previewPeriod(Subscription $subscription, string $from, string $to): array
    {
        $start = Carbon::parse($from)->startOfDay();
        $end = Carbon::parse($to)->startOfDay();

        if ($end->lt($start)) {
            throw ApiException::validationFailed('Dönem sonu, dönem başından önce olamaz.');
        }

        // 62 GÜN TAVANI: dönem belgesi bir aylık peşin ödemenin dökümüdür
        // (30 gün + ay taşması payı). Sınırsız bir aralık, bir yılın
        // siparişlerini tek kâğıda basmayı ve o kâğıdın hangi ödemeye ait
        // olduğunu belirsiz kılmayı mümkün kılardı.
        if ($start->diffInDays($end) + 1 > self::MAX_PERIOD_DAYS) {
            throw ApiException::validationFailed(
                'Dönem aralığı en çok '.self::MAX_PERIOD_DAYS.' gün olabilir.',
            );
        }

        $unitPrice = $subscription->agreed_unit_price_kurus;

        if ($unitPrice === null) {
            // Fiyatsız (`pending`) bir abonelik için belge kesmek, toplamı
            // sıfır olan bir kâğıt basmak demekti; sessiz sıfır, açık
            // hatadan kötüdür.
            throw ApiException::validationFailed(
                'Aboneliğin anlaşılan birim fiyatı yok; önce fiyatlandırılmalı.',
            );
        }

        $unitPrice = (int) $unitPrice;

        [$plannedDays, $plannedPortions] = $this->plannedOf($subscription, $start, $end);
        $delivered = $this->deliveredOf((int) $subscription->id, $start, $end);

        $deliveredPortions = array_sum($delivered);
        $deliveredDays = array_keys($delivered);
        sort($deliveredDays);

        return [
            'unit_price_kurus' => $unitPrice,
            'planned_days' => $plannedDays,
            'planned_portions' => $plannedPortions,
            'delivered_days' => $deliveredDays,
            'delivered_portions' => $deliveredPortions,
            // ATLANAN GÜN = planlanmış ama teslim edilmemiş gün. Duraklatma,
            // tek-günlük istisna ve iptal edilmiş sipariş burada birleşir;
            // müşteri için üçü de aynı şeydir: "o gün yemek gelmedi".
            'skipped_days' => array_values(array_diff($plannedDays, $deliveredDays)),
            'total_kurus' => $unitPrice * $deliveredPortions,
        ];
    }

    /** Dönem belgesini keser. */
    public function issueForPeriod(
        Subscription $subscription,
        string $from,
        string $to,
        ?int $paymentId,
        string $actor,
    ): Invoice {
        $preview = $this->previewPeriod($subscription, $from, $to);

        $lines = [[
            'description' => 'Abonelik — teslim edilen porsiyon',
            'service_date' => null,
            'order_number' => null,
            'role' => 'item',
            'quantity' => $preview['delivered_portions'],
            'unit_price_kurus' => $preview['unit_price_kurus'],
            'line_total_kurus' => $preview['total_kurus'],
        ]];

        $snapshot = [
            'issuer' => $this->issuer(),
            'customer' => $this->customerBlock((int) $subscription->customer_id),
            'document' => [
                'kind' => Invoice::TYPE_SUBSCRIPTION,
                'subscription_id' => (int) $subscription->id,
                'period_start' => Carbon::parse($from)->toDateString(),
                'period_end' => Carbon::parse($to)->toDateString(),
                'unit_price_kurus' => $preview['unit_price_kurus'],
                'planned_portions' => $preview['planned_portions'],
                'delivered_portions' => $preview['delivered_portions'],
                'planned_days' => $preview['planned_days'],
                'skipped_days' => $preview['skipped_days'],
            ],
            'lines' => $lines,
            'totals' => [
                'subtotal_kurus' => $preview['total_kurus'],
                'delivery_fee_kurus' => 0,
                'total_kurus' => $preview['total_kurus'],
                'currency' => 'TRY',
            ],
            'payment' => [
                'method' => Subscription::PAYMENT_PREPAID,
                'status' => $paymentId !== null ? 'paid' : 'pending',
                'reference' => $paymentId !== null ? (string) $paymentId : null,
            ],
            'notice' => self::NOTICE,
        ];

        return $this->persist([
            'type' => Invoice::TYPE_SUBSCRIPTION,
            'subscription_id' => (int) $subscription->id,
            'subscription_payment_id' => $paymentId,
            'customer_id' => (int) $subscription->customer_id,
            'period_start' => Carbon::parse($from)->toDateString(),
            'period_end' => Carbon::parse($to)->toDateString(),
            'subtotal_kurus' => $preview['total_kurus'],
            'delivery_kurus' => 0,
            'total_kurus' => $preview['total_kurus'],
            'snapshot_json' => $snapshot,
            'created_by_actor' => $actor,
        ]);
    }

    // ── İptal ────────────────────────────────────────────────────────────

    /**
     * Belgeyi iptal eder — SİLMEZ.
     *
     * Numara serbest kalmaz: boşluk yok, geri kullanım yok. İptal edilmiş
     * numara listede `void` olarak görünür ve belgenin üstüne çapraz
     * "İPTAL" filigranı basılır; temiz basılabilen bir iptal, elindeki
     * kâğıdın geçerli olduğunu sanan bir müşteri üretirdi.
     */
    public function void(Invoice $invoice, string $reason): Invoice
    {
        if ($invoice->isVoid()) {
            throw ApiException::validationFailed('Belge zaten iptal edilmiş.');
        }

        $invoice->status = Invoice::STATUS_VOID;
        $invoice->void_at = BusinessTime::forStorage(Carbon::now());
        $invoice->void_reason = mb_substr(trim($reason), 0, 255);
        $invoice->save();

        return $invoice->refresh();
    }

    // ── Çizim ────────────────────────────────────────────────────────────

    /**
     * Yazdırmaya hazır A4 HTML — TEK DOSYA, dış bağımlılık yok.
     *
     * Şablon adı tek yerde: denetleyici (`GET /{id}/html`) bu metodu
     * çağırır, kendi `view()` adını yazmaz. Rota ile şablon adının
     * ayrışması, ancak uç çağrıldığında patlayan sessiz bir hatadır.
     */
    public function html(Invoice $invoice): string
    {
        return (string) view(self::VIEW, ['invoice' => $invoice])->render();
    }

    // ── İç işler ─────────────────────────────────────────────────────────

    /**
     * Numarayı ayırır ve satırı yazar — TEK İŞLEMDE.
     *
     * @param  array<string, mixed>  $attributes
     */
    private function persist(array $attributes): Invoice
    {
        /** @var Invoice */
        return DB::transaction(function () use ($attributes): Invoice {
            $issuedAt = Carbon::now();

            // YIL, İŞLETME TAKVİMİNDEN: sıra "yıl başında" sıfırlanıyor ve o
            // yılbaşı Türkiye duvar saatininki. UTC'ye göre seçilseydi 31
            // Aralık 21:00–24:00 arasında kesilen belgeler bir önceki yılın
            // serisine düşerdi.
            $year = (int) BusinessTime::at($issuedAt)->year;

            [$sequence, $number] = InvoiceCounter::allocate($year);

            $invoice = new Invoice;
            $invoice->fill([
                ...$attributes,
                'invoice_no' => $number,
                'series' => InvoiceCounter::SERIES,
                'year' => $year,
                'sequence' => $sequence,
                'status' => Invoice::STATUS_ISSUED,
                'currency' => 'TRY',
                'issued_at' => BusinessTime::forStorage($issuedAt),
            ]);
            $invoice->save();

            return $invoice;
        });
    }

    /**
     * Sipariş kalemleri — paket satırı ve altındaki sıfır fiyatlı
     * bileşenler DAHİL.
     *
     * BİLEŞENLER BELGEDE GÖRÜNÜR (mutfak yanıtının aksine). Müşteri
     * "Günün Menüsü ×12" satırının içinde ne olduğunu görmeli; şeffaflık
     * belgenin tek işi. Çizim tarafı `role = component` satırlarını
     * girintili basar ve fiyatları zaten sıfırdır, toplam şişmez.
     *
     * @return list<array<string, mixed>>
     */
    private function orderLines(Order $order): array
    {
        $serviceDate = $this->presenter->serviceDate($order);
        $orderNumber = $this->presenter->number($order);

        return DB::table('order_menus')
            ->where('order_id', $order->order_id)
            ->orderBy('order_menu_id')
            ->get()
            ->map(static fn(object $row): array => [
                'description' => (string) $row->name,
                'service_date' => $serviceDate,
                'order_number' => $orderNumber,
                // Eski satırlarda kolon boş; `item` varsayılanı çizimde
                // girintisiz normal satır demek.
                'role' => $row->bld_line_role !== null
                    ? (string) $row->bld_line_role
                    : 'item',
                'quantity' => (int) $row->quantity,
                'unit_price_kurus' => Money::toKurus($row->price),
                'line_total_kurus' => Money::toKurus($row->subtotal),
            ])
            ->all();
    }

    /**
     * Satıcı bloğu — site içeriğinden KOPYALANIR, bağlanmaz.
     *
     * Şirket adresi değişince eski belge eski adresi göstermeli; canlı
     * okunsaydı, iki yıl önceki bir belgeyi yeniden basmak bugünkü adresi
     * yazardı ve iki kopya birbirini tutmazdı.
     *
     * @return array<string, mixed>
     */
    private function issuer(): array
    {
        $bundle = $this->content->bundle();

        /** @var array<string, mixed> $brand */
        $brand = is_array($bundle['brand'] ?? null) ? $bundle['brand'] : [];
        /** @var array<string, mixed> $contact */
        $contact = is_array($bundle['contact'] ?? null) ? $bundle['contact'] : [];

        return [
            'name' => self::text($brand['name'] ?? null),
            'address' => self::text($contact['address'] ?? null),
            'phone' => self::text($contact['phone'] ?? null),
            'email' => self::text($contact['email'] ?? null),
        ];
    }

    /**
     * Alıcı bloğu — siparişteki KOPYA ad/telefon önce gelir.
     *
     * `orders` tablosundaki ad ve telefon sipariş anının kopyasıdır;
     * müşteri kartı sonradan güncellense bile belge o günkü muhatabı
     * göstermeli. Kurumsal kimlik (unvan, vergi) müşteri kartından okunur
     * çünkü siparişte kopyası yok.
     *
     * @return array<string, mixed>
     */
    private function orderCustomer(Order $order): array
    {
        $block = $this->customerBlock((int) ($order->customer_id ?? 0));

        $orderName = $this->presenter->customerName($order);
        $orderPhone = $this->presenter->customerPhone($order);

        // Kurum unvanı varsa etiket odur (`bld_org_name`); yoksa siparişteki
        // ad soyad. `docs/control/invoices.md` → `customer_label`.
        if (self::text($block['label'] ?? null) === null) {
            $block['label'] = $orderName;
        }

        $block['phone'] = $orderPhone ?? $block['phone'];
        $block['address'] = $this->addressText($order) ?? $block['address'];

        return $block;
    }

    /**
     * Müşteri kartından alıcı bilgisi.
     *
     * @return array<string, mixed>
     */
    private function customerBlock(int $customerId): array
    {
        $row = $customerId > 0
            ? DB::table('customers')->where('customer_id', $customerId)->first()
            : null;

        if ($row === null) {
            return [
                'label' => null,
                'contact_person' => null,
                'tax_office' => null,
                'tax_no' => null,
                'address' => null,
                'phone' => null,
            ];
        }

        $person = trim(((string) ($row->first_name ?? '')).' '.((string) ($row->last_name ?? '')));

        return [
            'label' => self::text($row->bld_org_name ?? null) ?? self::text($person),
            'contact_person' => self::text($row->bld_contact_person ?? null) ?? self::text($person),
            'tax_office' => self::text($row->bld_tax_office ?? null),
            'tax_no' => self::text($row->bld_tax_no ?? null),
            'address' => null,
            'phone' => self::text($row->telephone ?? null),
        ];
    }

    /** Siparişin teslimat adresi, tek satırlık okunur metin. */
    private function addressText(Order $order): ?string
    {
        $address = $this->presenter->address($order);

        if ($address === null) {
            return null;
        }

        $parts = array_filter([
            self::text($address['line1'] ?? null),
            trim(
                (self::text($address['district'] ?? null) ?? '')
                .' / '
                .(self::text($address['city'] ?? null) ?? ''),
                ' /',
            ),
        ], static fn(?string $part): bool => $part !== null && $part !== '');

        return $parts === [] ? null : implode(', ', $parts);
    }

    /** @return array<string, mixed> */
    private function orderPayment(Order $order): array
    {
        $payment = $this->presenter->payment($order);

        return [
            'method' => (string) $payment['method'],
            'status' => (string) $payment['status'],
            // Ödeme anı: `processed` bayrağı doğruysa siparişin güncellenme
            // anı en yakın bilgi. Ayrı bir "ödendi" damgası yok.
            'paid_at' => ((string) $payment['status']) === 'paid' && $order->updated_at !== null
                ? Carbon::parse($order->updated_at)->utc()->toIso8601ZuluString()
                : null,
        ];
    }

    /**
     * Dönemdeki planlanmış günler ve porsiyon toplamı.
     *
     * TAKVİM KURALI, DURAKLATMA/İSTİSNA DEĞİL. `runsOnDate()` atlanan günü
     * zaten eler; burada onu kullansaydık "planlanan" ile "teslim edilen"
     * eşitlenir ve atlanan günler belgede hiç görünmezdi — oysa belgenin
     * anlattığı tam olarak o fark.
     *
     * @return array{0: list<string>, 1: int}
     */
    private function plannedOf(Subscription $subscription, Carbon $start, Carbon $end): array
    {
        $days = array_map('intval', $subscription->service_days ?? []);
        $subStart = $subscription->start_date->copy()->startOfDay();
        $subEnd = $subscription->end_date?->copy()->startOfDay();

        $dates = [];
        $portions = 0;
        $cursor = $start->copy();

        while ($cursor->lte($end)) {
            $inRange = $cursor->gte($subStart) && ($subEnd === null || $cursor->lte($subEnd));

            if ($inRange && in_array($cursor->dayOfWeekIso, $days, true)) {
                $dates[] = $cursor->toDateString();
                $portions += $subscription->quantityForDate($cursor);
            }

            $cursor->addDay();
        }

        return [$dates, $portions];
    }

    /**
     * Gerçekten teslim edilen porsiyonlar — `gün => porsiyon`.
     *
     * İPTAL EDİLMİŞ SİPARİŞ SAYILMAZ: mutfak o gün yemek göndermedi,
     * müşteri o günün parasını ödemez.
     *
     * PORSİYON = paket/kalem satırlarının adedi. `component` satırları
     * elenir; menü paketinin içindeki üç yemek üç porsiyon değil, bir
     * porsiyondur (`OrderPresenter::editable()` ile aynı süzgeç).
     *
     * @return array<string, int>
     */
    private function deliveredOf(int $subscriptionId, Carbon $start, Carbon $end): array
    {
        $cancelledIds = DB::table('statuses')
            ->where('status_code', OrderStatusTransition::CANCELLED)
            ->pluck('status_id')
            ->map(intval(...))
            ->all();

        $rows = DB::table('veykemtu_subscription_runs as r')
            ->join('orders as o', 'o.order_id', '=', 'r.order_id')
            ->join('order_menus as om', 'om.order_id', '=', 'o.order_id')
            ->where('r.subscription_id', $subscriptionId)
            ->whereBetween('r.service_date', [$start->toDateString(), $end->toDateString()])
            ->when(
                $cancelledIds !== [],
                static fn($query) => $query->whereNotIn('o.status_id', $cancelledIds),
            )
            ->where(function ($query): void {
                $query->whereNull('om.bld_line_role')
                    ->orWhere('om.bld_line_role', '!=', 'component');
            })
            ->groupBy('r.service_date')
            ->selectRaw('r.service_date as service_date, SUM(om.quantity) as portions')
            ->get();

        $map = [];

        foreach ($rows as $row) {
            $map[Carbon::parse($row->service_date)->toDateString()] = (int) $row->portions;
        }

        return $map;
    }

    /** Boş dizeyi `null` sayar — belge boş satır basmasın. */
    private static function text(mixed $value): ?string
    {
        if (!is_string($value)) {
            return null;
        }

        $trimmed = trim($value);

        return $trimmed === '' ? null : $trimmed;
    }
}
