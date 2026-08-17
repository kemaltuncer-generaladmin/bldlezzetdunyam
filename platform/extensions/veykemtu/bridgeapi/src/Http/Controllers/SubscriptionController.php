<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers;

use Igniter\Cart\Models\Order;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Models\Subscription;
use Veykemtu\BridgeApi\Models\SubscriptionPayment;
use Veykemtu\BridgeApi\Services\DailyStock;
use Veykemtu\BridgeApi\Services\OrderStatusTransition;
use Veykemtu\BridgeApi\Services\SubscriptionLifecycle;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Müşteri abonelik uçları — `docs/openapi.yaml` §Abonelik.
 *
 * Müşteri kendi aboneliğini görür, TALEP açar (fiyatı admin belirler),
 * duraklatır/devam ettirir/iptal eder ve tek-günlük istisna girer. Anlaşmalı
 * fiyat müşteri tarafından SET EDİLEMEZ (satış kararı). Başkasının aboneliği
 * istenirse 404 (varlığını sızdırmamak için, sipariş deseni).
 */
class SubscriptionController extends ApiController
{
    public function index(Request $request): JsonResponse
    {
        /** @var ApiCustomer $customer */
        $customer = $request->user();

        $subscriptions = Subscription::query()
            ->where('customer_id', $customer->customer_id)
            ->with(['lines', 'delivery_points'])
            ->orderByDesc('id')
            ->get();

        return $this->json([
            'data' => $subscriptions->map(fn(Subscription $s): array => $this->present($s))->all(),
        ]);
    }

    public function show(Request $request, int $subscription): JsonResponse
    {
        return $this->json($this->present($this->owned($request, $subscription)));
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'location_id' => ['required', 'integer'],
            'delivery_type' => ['required', Rule::in(['delivery', 'pickup'])],
            'start_date' => ['required', 'date'],
            'end_date' => ['sometimes', 'nullable', 'date', 'after_or_equal:start_date'],
            'service_days' => ['required', 'array', 'min:1'],
            'service_days.*' => ['integer', 'between:1,7'],
            'default_quantity' => ['required', 'integer', 'min:1', 'max:9999'],
            'delivery_time_from' => ['sometimes', 'nullable', 'date_format:H:i'],
            'delivery_time_to' => ['sometimes', 'nullable', 'date_format:H:i'],
            /*
             * MENÜ MODU — sözleşmeye ADDITIVE (`docs/openapi.yaml`
             * `SubscriptionCreate.menu_mode`). Gönderilmezse `fixed_list`:
             * bugüne kadar istemcilerin gönderemediği bir alan, yokluğunda
             * eski davranışı birebir korumalı.
             */
            'menu_mode' => [
                'sometimes',
                Rule::in([Subscription::MENU_FIXED_LIST, Subscription::MENU_DAILY]),
            ],
            'lines' => ['sometimes', 'array'],
            'lines.*.menu_id' => ['required_with:lines', 'integer'],
            'lines.*.quantity' => ['required_with:lines', 'integer', 'min:1'],
            'lines.*.label' => ['sometimes', 'nullable', 'string', 'max:120'],
            'delivery_points' => ['sometimes', 'array'],
            'delivery_points.*.address_id' => ['required_with:delivery_points', 'integer'],
            'delivery_points.*.quantity' => ['sometimes', 'nullable', 'integer', 'min:1'],
            'delivery_points.*.note' => ['sometimes', 'nullable', 'string', 'max:255'],
            'customer_note' => ['sometimes', 'nullable', 'string', 'max:500'],
        ]);

        /** @var ApiCustomer $customer */
        $customer = $request->user();

        $menuMode = (string) ($data['menu_mode'] ?? Subscription::MENU_FIXED_LIST);

        /*
         * GÜNÜN MENÜSÜ MODUNDA ÜRÜN SATIRI OLMAZ.
         *
         * O aboneliğin içeriği her gün `veykemtu_daily_menus`'ten geliyor.
         * Talebe ayrıca satır yazmak, hiçbir zaman okunmayacak ikinci bir
         * "içerik" kaynağı yaratır; yönetici panelde onu görür, gerçekte
         * pişen başka olur. Sessizce atmak yerine söylüyoruz — sessiz
         * atma, istemci hatasını sahaya taşır.
         */
        if ($menuMode === Subscription::MENU_DAILY && ($data['lines'] ?? []) !== []) {
            throw ApiException::validationFailed(
                'Günün menüsü aboneliğinde ürün satırı gönderilmez; '
                    .'içerik o günün yayınlanmış menüsünden gelir.',
                ['menu_mode' => $menuMode],
            );
        }

        $subscription = DB::transaction(function () use ($data, $customer, $menuMode): Subscription {
            // TALEP: fiyatsız, `pending`. Admin fiyatlandırıp aktifleştirir.
            $subscription = new Subscription;
            $subscription->customer_id = $customer->customer_id;
            $subscription->location_id = $data['location_id'];
            $subscription->status = Subscription::STATUS_PENDING;
            $subscription->start_date = $data['start_date'];
            $subscription->end_date = $data['end_date'] ?? null;
            $subscription->delivery_type = $data['delivery_type'];
            $subscription->delivery_time_from = $data['delivery_time_from'] ?? null;
            $subscription->delivery_time_to = $data['delivery_time_to'] ?? null;
            $subscription->service_days = array_values(array_unique(
                array_map('intval', $data['service_days']),
            ));
            $subscription->menu_mode = $menuMode;
            $subscription->default_quantity = $data['default_quantity'];
            $subscription->agreed_unit_price_kurus = null; // admin belirler
            // Cari ödeme modu kaldırıldı; tek mod peşin aylık.
            $subscription->payment_mode = Subscription::PAYMENT_PREPAID;
            $subscription->save();

            foreach ($data['lines'] ?? [] as $line) {
                DB::table('veykemtu_subscription_lines')->insert([
                    'subscription_id' => $subscription->id,
                    'menu_id' => (int) $line['menu_id'],
                    'quantity' => (int) $line['quantity'],
                    'agreed_unit_price_kurus' => null,
                    'label' => $line['label'] ?? null,
                ]);
            }

            foreach ($data['delivery_points'] ?? [] as $point) {
                DB::table('veykemtu_subscription_delivery_points')->insert([
                    'subscription_id' => $subscription->id,
                    'address_id' => (int) $point['address_id'],
                    'quantity' => isset($point['quantity']) ? (int) $point['quantity'] : null,
                    'note' => $point['note'] ?? null,
                ]);
            }

            return $subscription;
        });

        return $this->json($this->present($subscription->refresh()), 201);
    }

    public function pause(Request $request, int $subscription): JsonResponse
    {
        $model = $this->owned($request, $subscription);
        $this->assertStatus($model, [Subscription::STATUS_ACTIVE], 'Yalnızca aktif abonelik duraklatılabilir.');
        $model->status = Subscription::STATUS_PAUSED;
        $model->save();

        return $this->json($this->present($model));
    }

    public function resume(Request $request, int $subscription): JsonResponse
    {
        $model = $this->owned($request, $subscription);
        $this->assertStatus($model, [Subscription::STATUS_PAUSED], 'Yalnızca duraklatılmış abonelik devam ettirilebilir.');
        $model->status = Subscription::STATUS_ACTIVE;
        $model->save();

        return $this->json($this->present($model));
    }

    public function cancel(Request $request, int $subscription): JsonResponse
    {
        $model = $this->owned($request, $subscription);
        if ($model->status === Subscription::STATUS_CANCELLED) {
            throw ApiException::validationFailed('Abonelik zaten iptal.', ['status' => $model->status]);
        }
        $model->status = Subscription::STATUS_CANCELLED;
        $model->save();

        return $this->json($this->present($model));
    }

    public function storeException(Request $request, int $subscription): JsonResponse
    {
        $model = $this->owned($request, $subscription);

        $data = $request->validate([
            'service_date' => ['required', 'date'],
            'skip' => ['sometimes', 'boolean'],
            'quantity_override' => ['sometimes', 'nullable', 'integer', 'min:1', 'max:9999'],
        ]);

        $date = Carbon::parse((string) $data['service_date'])->startOfDay();
        $skip = (bool) ($data['skip'] ?? false);

        DB::transaction(function () use ($model, $data, $date, $skip): void {
            // Tek-günlük istisna: aynı gün için tek satır (idempotent).
            DB::table('veykemtu_subscription_exceptions')->updateOrInsert(
                ['subscription_id' => $model->id, 'service_date' => $data['service_date']],
                [
                    'skip' => $skip,
                    'quantity_override' => $data['quantity_override'] ?? null,
                ],
            );

            /*
             * STOK, İSTİSNA YAZILDIKTAN SONRA HESAPLANIR ve aynı işlemin
             * içindedir. Hesap abonelikleri veritabanından yeniden okuyor
             * (`DailyStock::syncReservedFor`), yani az önce yazılan istisnayı
             * görür — aynı bağlantıdaki işlemin içinden. Sıra ters olsaydı
             * atlanan gün stokta ayrılmış kalırdı; işlem ayrı olsaydı
             * istisnası yazılmış ama rezervasyonu düşmemiş bir gün kalabilirdi.
             */
            $this->applyExceptionToStock($model, $date, $skip);
        });

        return $this->json($this->present($model->refresh()));
    }

    /**
     * Gün atlamanın stok karşılığı — ÜRETİMDEN ÖNCE Mİ, SONRA MI.
     *
     * ÖNCE: ortada sipariş yok, yalnız bir rezervasyon var. Gün yeniden
     * hesaplanınca o abonelik artık `runsOnDate()` değil, rezervasyon
     * düşer ve porsiyon SERBEST SATIŞA döner — abonenin atladığı gün
     * kapasitenin kilitli kalması, mutfağın boş yere pişirmesi ya da
     * satılabilecek porsiyonun satılamaması demekti.
     *
     * SONRA: rezervasyon çoktan satışa çevrildi ve mutfakta gerçek bir
     * sipariş var. Porsiyon ancak o siparişin İPTALİYLE geri döner ve
     * iptal NORMAL YOLUNDAN geçer (`OrderStatusTransition::apply`):
     * stok kredisi, iade kaydı, `status_history` ve abonelik defteri
     * kancası orada birlikte yürüyor. Burada elle `release()` çağırmak,
     * mutfakta duran bir siparişi görünmez biçimde yok saymak olurdu.
     *
     * GEÇMİŞ GÜN DOKUNULMAZ: ne rezervasyonu ne de pişmiş bir siparişi
     * geri almanın anlamı var; müşteri geçmişe istisna girerse kayıt
     * yazılır, stok kımıldamaz.
     */
    private function applyExceptionToStock(Subscription $model, Carbon $date, bool $skip): void
    {
        if ($date->lt(BusinessTime::now()->startOfDay())) {
            return;
        }

        if ($skip) {
            $this->cancelGeneratedOrders($model, $date);
        }

        // Atlama da, atlamanın geri alınması da, adet değişikliği de aynı
        // cevabı istiyor: "o günün rezervasyonu artık başka". Üçü için üç
        // ayrı delta yazmak yerine gün sıfırdan hesaplanıyor — gecelik
        // uzlaştırmayla BİREBİR aynı kod yolu.
        app(DailyStock::class)->syncReservedFor((int) $model->location_id, $date);
    }

    /** Bu abonelikten o gün için ÜRETİLMİŞ siparişleri iptal eder. */
    private function cancelGeneratedOrders(Subscription $model, Carbon $date): void
    {
        $transitions = app(OrderStatusTransition::class);

        $orders = Order::query()
            ->where('bld_subscription_id', $model->id)
            ->whereDate('bld_service_date', $date->toDateString())
            ->get();

        foreach ($orders as $order) {
            // Teslim edilmiş ya da zaten iptal edilmiş siparişte geri
            // alınacak porsiyon yok; matris kararı tek yerde kalsın diye
            // durum listesi burada yeniden yazılmıyor.
            if (!in_array(
                OrderStatusTransition::CANCELLED,
                $transitions->allowedFrom($order),
                true,
            )) {
                continue;
            }

            $transitions->apply(
                $order,
                OrderStatusTransition::CANCELLED,
                null,
                'Abone bu günü atladı.',
            );
        }
    }

    /**
     * Aboneliği getirir; başkasınınsa "yok" der (404).
     */
    private function owned(Request $request, int $id): Subscription
    {
        /** @var ApiCustomer $customer */
        $customer = $request->user();

        $subscription = Subscription::query()
            ->where('id', $id)
            ->where('customer_id', $customer->customer_id)
            ->with(['lines', 'delivery_points'])
            ->first();

        if ($subscription === null) {
            throw ApiException::notFound('Abonelik bulunamadı.');
        }

        return $subscription;
    }

    /** @param list<string> $allowed */
    private function assertStatus(Subscription $subscription, array $allowed, string $message): void
    {
        if (!in_array($subscription->status, $allowed, true)) {
            throw ApiException::validationFailed($message, ['status' => $subscription->status]);
        }
    }

    /** @return array<string, mixed> */
    private function present(Subscription $subscription): array
    {
        return [
            'id' => (int) $subscription->id,
            'status' => (string) $subscription->status,
            'location_id' => (int) $subscription->location_id,
            'delivery_type' => (string) $subscription->delivery_type,
            'start_date' => $subscription->start_date?->toDateString(),
            'end_date' => $subscription->end_date?->toDateString(),
            'service_days' => array_map('intval', $subscription->service_days ?? []),
            'delivery_time_from' => $this->time($subscription->delivery_time_from),
            'delivery_time_to' => $this->time($subscription->delivery_time_to),
            'default_quantity' => (int) $subscription->default_quantity,
            'agreed_unit_price' => $subscription->agreed_unit_price_kurus !== null
                ? (int) $subscription->agreed_unit_price_kurus
                : null,
            'payment_mode' => (string) $subscription->payment_mode,
            'menu_mode' => (string) $subscription->menu_mode,
            'lines' => $subscription->lines->map(static fn($l): array => [
                'menu_id' => $l->menu_id !== null ? (int) $l->menu_id : null,
                'quantity' => (int) $l->quantity,
                'agreed_unit_price' => $l->agreed_unit_price_kurus !== null
                    ? (int) $l->agreed_unit_price_kurus
                    : null,
                'label' => $l->label,
            ])->all(),
            'delivery_points' => $subscription->delivery_points->map(static fn($p): array => [
                'id' => (int) $p->id,
                'address_id' => (int) $p->address_id,
                'quantity' => $p->quantity !== null ? (int) $p->quantity : null,
                'note' => $p->note,
            ])->all(),
            'payment' => $this->paymentSummary($subscription),
            'created_at' => self::ts($subscription->created_at),
        ];
    }

    /**
     * Yürürlükteki dönemin ödeme özeti — `docs/openapi.yaml`
     * `SubscriptionPaymentSummary`.
     *
     * TEK DÖNEM, LİSTE DEĞİL: bu alan "şu an ne bekleniyor" sorusunu
     * yanıtlar. Ödemelerin geçmişini gömseydik abonelik listesi ekranı her
     * satır için aylarca geriye giden bir dizi taşırdı.
     *
     * FİYATLANMAMIŞ TALEPTE `null`: ödenecek bir tutar henüz yok ve sıfır
     * göstermek "bedava" demek olurdu.
     *
     * TUTAR KAYITLI ÖDEMEDEN OKUNUR, YENİDEN HESAPLANMAZ (ödeme varsa):
     * abone 4.500 TL'lik bir niyet açtıktan sonra bir gün atlarsa, ödeme
     * sayfasındaki tutar ile listedeki tutar ayrışmamalı. Henüz niyet yoksa
     * sıradaki dönemin önizlemesi hesaplanır.
     *
     * @return array<string, mixed>|null
     */
    private function paymentSummary(Subscription $subscription): ?array
    {
        if ($subscription->agreed_unit_price_kurus === null) {
            return null;
        }

        /** @var SubscriptionPayment|null $payment */
        $payment = SubscriptionPayment::query()
            ->where('subscription_id', $subscription->id)
            ->orderByDesc('period_start')
            ->first();

        // Açık niyet ya da BUGÜNÜ KAPSAYAN ödenmiş dönem: yürürlükte olan
        // budur. Kapsamı geçmiş bir ödeme "şu an ne bekleniyor" sorusunu
        // yanıtlamaz; onun yerine sıradaki dönemin önizlemesi dönüyor.
        if ($payment !== null
            && ($payment->isPending() || ($payment->isSucceeded() && $payment->covers(BusinessTime::now())))
        ) {
            return [
                'payment_id' => (int) $payment->id,
                'period' => $payment->period(),
                'amount' => (int) $payment->amount_kurus,
                'currency' => 'TRY',
                'status' => SubscriptionPaymentController::wireStatus((string) $payment->status),
                'due_date' => $payment->period_start->toDateString(),
            ];
        }

        // Henüz açılmamış dönem: `payment_id` NULL. Sözleşme `null` ile `0`'ı
        // ayırmayı özellikle şart koşuyor — `0` diye bir kayıt yoktur.
        $lifecycle = app(SubscriptionLifecycle::class);
        $quote = $lifecycle->quote($subscription, $lifecycle->nextPeriodStart($subscription));

        return [
            'payment_id' => null,
            'period' => $quote['start']->format('Y-m'),
            'amount' => $quote['amount'],
            'currency' => 'TRY',
            'status' => SubscriptionPayment::STATUS_PENDING,
            'due_date' => $quote['start']->toDateString(),
        ];
    }

    private function time(mixed $value): ?string
    {
        if ($value === null || $value === '') {
            return null;
        }

        return substr((string) $value, 0, 5); // HH:MM
    }
}
