<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers\Control;

use Igniter\Cart\Models\Order;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\ControlAudit;
use Veykemtu\BridgeApi\Models\DailyMenu;
use Veykemtu\BridgeApi\Models\KitchenDevice;

/**
 * Kontrol Merkezi — denetim izi (`docs/control/audit.md`).
 *
 * SALT OKUNUR. Bu sınıfta `POST`/`PATCH`/`PUT`/`DELETE` yok ve olmayacak;
 * rota dosyası da üç `GET` dışında bir şey kaydetmiyor. Denetim izini
 * silebilen bir denetim izi, denetim izi değildir.
 *
 * BU UCUN VARLIK SEBEBİ: `veykemtu_control_audit` bugüne kadar yalnız
 * YAZILAN bir tabloydu. Okuma yüzeyi olmadan, "kim ne zaman ne yaptı"
 * sorusunun cevabı ancak veritabanına elle bağlanarak alınabilirdi — yani
 * pratikte alınamazdı ve tablo, tutulduğu hâlde hiç bakılmayan bir deftere
 * dönerdi.
 *
 * `GET /audit` KENDİSİ DENETLENMEZ. Denetim izini okumayı denetlemek, her
 * okumanın yeni bir satır ürettiği ve o satırın okunmasının bir satır daha
 * ürettiği bir döngü kurardı. (`control/customers/*` okumalarının
 * denetlenmesi ayrı bir karardır ve gerekçesi `00-genel.md` §9'dadır.)
 */
class AuditController extends ControlController
{
    /**
     * Liste yükünün kırpma sınırı — 2 KB.
     *
     * Elli satırlık bir sayfada tam yükleri taşımak yanıtı megabaytlara
     * çıkarırdı; sipariş revizyonu yükleri tek başına kalem listesi taşıyor.
     * Kırpılan satır `payload_truncated: true` ile işaretlenir ve tam hâli
     * `GET /{id}` ile okunur.
     */
    private const int PAYLOAD_PREVIEW_BYTES = 2048;

    /**
     * Varsayılan pencere — son 30 gün.
     *
     * Sınırsız bir varsayılan, ilk sayfayı göstermek için tablonun tamamını
     * saydırırdı (`meta.total` bir `COUNT` istiyor ve tablo yıllarca
     * büyüyecek).
     */
    private const int DEFAULT_WINDOW_DAYS = 30;

    /** `/actions` sayaçlarının penceresi. */
    private const int ACTION_COUNT_DAYS = 90;

    /**
     * Sayfalama varsayılanı burada 50 — sözleşmedeki TEK istisna.
     *
     * Denetim izi bir tarama ekranıdır: "dün ne oldu" sorusu yirmi beşer
     * satırla sekiz kez sayfa çevirmek demekti. Tavan yine 100.
     */
    private const int DEFAULT_PER_PAGE = 50;

    /**
     * Bilinen eylem sözlüğü — `GET /actions` bunu döndürür.
     *
     * SUNUCUDA DURUYOR, PANELDE DEĞİL. Panelin kendi çeviri tablosunu
     * tutması, sunucuya yeni bir eylem eklendiğinde ekranda ham
     * `snake_case` bir ad görünmesiyle biterdi; süzgeç açılır listesi de
     * o eylemi hiç göstermezdi.
     *
     * HİÇ KULLANILMAMIŞ EYLEM DE LİSTEDE DURUR (`count: 0`). Yalnız
     * kullanılanları döndürmek, yeni bir eylemi ilk kez kullanılana kadar
     * süzgeçte göstermemek demekti.
     *
     * @var array<string, string>
     */
    private const array ACTION_LABELS = [
        // ── Günlük menü takvimi ───────────────────────────────────────
        'menu.day.create' => 'Menü günü oluşturuldu',
        'menu.day.update' => 'Menü günü güncellendi',
        'menu.day.delete' => 'Menü günü silindi',
        'menu.publish' => 'Menü yayınlandı',
        'menu.unpublish' => 'Menü yayından kaldırıldı',
        'menu.duplicate' => 'Menü kopyalandı',
        'menu.stock' => 'Gün kapasitesi yazıldı',
        'menu.item.create' => 'Menüye kalem eklendi',
        'menu.item.update' => 'Menü kalemi güncellendi',
        'menu.item.delete' => 'Menü kalemi silindi',

        // ── Ürün kataloğu ─────────────────────────────────────────────
        'product.create' => 'Ürün oluşturuldu',
        'product.update' => 'Ürün güncellendi',
        'product.delete' => 'Ürün kaldırıldı',
        'product.image' => 'Ürün görseli yüklendi',
        'product.image.delete' => 'Ürün görseli silindi',
        'product.sold_out' => 'Ürün tükendi işaretlendi',
        'product.sold_out.clear' => 'Ürün tükendi işareti kaldırıldı',
        'category.create' => 'Kategori oluşturuldu',
        'category.update' => 'Kategori güncellendi',

        // ── Satış ayarları ────────────────────────────────────────────
        'settings.sales' => 'Satış ayarları değiştirildi',
        'settings.ordering.pause' => 'Satış durduruldu',
        'settings.ordering.resume' => 'Satış yeniden açıldı',
        'settings.closed_day.create' => 'Kapalı gün eklendi',
        'settings.closed_day.delete' => 'Kapalı gün silindi',

        // ── Siparişler ────────────────────────────────────────────────
        'order.revise' => 'Sipariş revize edildi',
        'order.status' => 'Sipariş durumu değiştirildi',
        'order.cancel' => 'Sipariş iptal edildi',

        // ── Abonelik ailesi ───────────────────────────────────────────
        'subscription.create' => 'Abonelik oluşturuldu',
        'subscription.update' => 'Abonelik güncellendi',
        'subscription.activate' => 'Abonelik etkinleştirildi',
        'subscription.pause' => 'Abonelik donduruldu',
        'subscription.resume' => 'Abonelik sürdürüldü',
        'subscription.cancel' => 'Abonelik iptal edildi',
        'subscription.generate' => 'Abonelik siparişleri üretildi',
        'subscription.exception.create' => 'Abonelik istisnası eklendi',
        'subscription.exception.delete' => 'Abonelik istisnası silindi',
        'subscription.contract.create' => 'Sözleşme oluşturuldu',
        'subscription.contract.resend' => 'Sözleşme yeniden gönderildi',
        'subscription.contract.cancel' => 'Sözleşme iptal edildi',
        'subscription.payment.create' => 'Dönem ödemesi kaydedildi',
        'subscription.payment.mark_paid' => 'Dönem ödemesi ödendi işaretlendi',
        'subscription.order.release' => 'Abonelik siparişi KDS\'e bırakıldı',
        'subscription.request.update' => 'Abonelik talebi güncellendi',
        'subscription.request.convert' => 'Talep aboneliğe çevrildi',

        // ── Müşteriler (KVKK) ─────────────────────────────────────────
        ControlAudit::ACTION_CUSTOMER_READ => 'Kişisel veri görüntülendi',
        'customer.update' => 'Müşteri kaydı güncellendi',
        'customer.disable' => 'Müşteri hesabı kapatıldı',
        'customer.enable' => 'Müşteri hesabı açıldı',

        // ── Fatura belgesi ────────────────────────────────────────────
        'invoice.create' => 'Fatura belgesi kesildi',
        'invoice.void' => 'Fatura belgesi iptal edildi',

        // ── Site içeriği ──────────────────────────────────────────────
        'cms.content.update' => 'Site içeriği güncellendi',
        'cms.service.create' => 'Hizmet sayfası eklendi',
        'cms.service.update' => 'Hizmet sayfası güncellendi',
        'cms.service.delete' => 'Hizmet sayfası silindi',
        'cms.post.create' => 'Yazı eklendi',
        'cms.post.update' => 'Yazı güncellendi',
        'cms.post.delete' => 'Yazı silindi',
        'cms.revalidate' => 'Site yeniden çizdirildi',

        // ── SMS ───────────────────────────────────────────────────────
        'sms.template.update' => 'SMS şablonu güncellendi',
        'sms.template.preview' => 'SMS şablonu önizlendi',
        'sms.send_test' => 'Deneme SMS\'i gönderildi',
        'sms.announcement.update' => 'SMS duyurusu yazıldı',
        'sms.announcement.run' => 'SMS duyurusu gönderildi',
        'sms.netgsm.update' => 'SMS gönderici başlığı değiştirildi',

        // ── Uygulama içi duyuru ───────────────────────────────────────
        'notification.create' => 'Duyuru oluşturuldu',
        'notification.update' => 'Duyuru güncellendi',
        'notification.publish' => 'Duyuru yayınlandı',
        'notification.archive' => 'Duyuru arşivlendi',

        // ── İzleme ────────────────────────────────────────────────────
        'monitor.resolve' => 'Hata olayı çözüldü işaretlendi',

        // ── KDS kasaları (K-21, mevcut aile) ──────────────────────────
        'device.create' => 'Kasa tanımlandı',
        'device.rename' => 'Kasa yeniden adlandırıldı',
        'device.revoke' => 'Kasa yetkisi iptal edildi',
        'device.settings' => 'Kasa ayarları değiştirildi',
        'device.command' => 'Kasaya komut gönderildi',
        'device.pairing_code' => 'Kasa eşleme kodu yenilendi',
    ];

    /**
     * Süzgeç açılır listesinin grup sırası.
     *
     * Grup, eylem adının ilk noktadan önceki parçasıdır — tek istisna
     * `settings.ordering.*` ve benzeri üç parçalı adlardır ve onlarda da
     * ilk parça doğru grubu veriyor.
     *
     * @var list<string>
     */
    private const array GROUPS = [
        'menu', 'product', 'category', 'settings', 'order', 'subscription',
        'customer', 'invoice', 'cms', 'sms', 'notification', 'monitor', 'device',
    ];

    // ── GET / ─────────────────────────────────────────────────────────────

    public function index(Request $request): JsonResponse
    {
        $request->validate([
            'actor' => ['sometimes', 'string', 'max:120'],
            'action' => ['sometimes', 'string', 'max:400'],
            'target_type' => ['sometimes', 'string', 'max:32'],
            'target_id' => ['sometimes', 'integer'],
            'result' => ['sometimes', 'string', 'max:64'],
            'from' => ['sometimes', 'string', 'max:40'],
            'to' => ['sometimes', 'string', 'max:40'],
            'q' => ['sometimes', 'string', 'max:200'],
            'page' => ['sometimes', 'integer', 'min:1'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:100'],
        ]);

        $query = $this->filtered($request);

        $page = max(1, (int) $request->query('page', '1'));
        $perPage = min(100, max(1, (int) $request->query('per_page', (string) self::DEFAULT_PER_PAGE)));

        $total = (int) $query->clone()->count();

        $rows = $query->clone()
            // "En son ne yapıldı" en sık sorulan soru; `id` azalan sıra
            // `created_at`'ten daha kararlı (aynı saniyede yazılan iki
            // satırın sırası da belirli olur).
            ->orderByDesc('id')
            ->forPage($page, $perPage)
            ->get();

        return $this->json([
            'data' => $this->rows($rows, preview: true),
            'meta' => [
                'page' => $page,
                'per_page' => $perPage,
                'total' => $total,
                'last_page' => max(1, (int) ceil($total / $perPage)),
                // SÜZGEÇLENMİŞ KÜMENİN dağılımı, sayfanın değil: ekranın
                // altındaki sayı sayfa değiştirince değişmemeli.
                'counts_by_result' => $this->countsByResult($query),
            ],
            'server_time' => $this->serverTime(),
        ]);
    }

    // ── GET /{id} ─────────────────────────────────────────────────────────

    public function show(int $audit): JsonResponse
    {
        $row = ControlAudit::find($audit);

        if ($row === null) {
            throw ApiException::notFound('Denetim satırı bulunamadı.');
        }

        return $this->json([
            'data' => $this->row($row, preview: false),
            'server_time' => $this->serverTime(),
        ]);
    }

    // ── GET /actions ──────────────────────────────────────────────────────

    /**
     * Bilinen eylem adları — panelin süzgeç sözlüğü.
     *
     * SAYAÇLAR TEK SORGUDA toplanıyor; eylem başına bir `COUNT` seksen
     * sorgu demekti ve bu uç panel açılışında çağrılıyor.
     */
    public function actions(): JsonResponse
    {
        $since = Carbon::now()->subDays(self::ACTION_COUNT_DAYS);

        /** @var array<string, int> $counts */
        $counts = ControlAudit::query()
            ->where('created_at', '>=', $since)
            ->groupBy('action')
            ->selectRaw('action, COUNT(*) AS toplam')
            ->pluck('toplam', 'action')
            ->map(intval(...))
            ->all();

        $data = [];

        foreach (self::ACTION_LABELS as $action => $label) {
            $data[] = [
                'action' => $action,
                'group' => $this->groupOf($action),
                'label' => $label,
                'count' => $counts[$action] ?? 0,
            ];
            unset($counts[$action]);
        }

        /*
         * SÖZLÜKTE OLMAYAN AMA TABLODA BULUNAN eylem de dönüyor. Sözlük
         * elle tutuluyor ve bir gün geride kalacak; o gün süzgeç, gerçekte
         * yazılmış bir eylemi hiç göstermemek yerine ham adıyla gösterir.
         * Ekranda `snake_case` bir ad görmek, eylemi hiç görememekten
         * iyidir.
         */
        foreach ($counts as $action => $count) {
            $data[] = [
                'action' => (string) $action,
                'group' => $this->groupOf((string) $action),
                'label' => (string) $action,
                'count' => $count,
            ];
        }

        return $this->json([
            'data' => $data,
            'meta' => ['groups' => self::GROUPS],
            'server_time' => $this->serverTime(),
        ]);
    }

    // ── Yardımcılar ───────────────────────────────────────────────────────

    /** @return Builder<ControlAudit> */
    private function filtered(Request $request): Builder
    {
        $query = ControlAudit::query();

        [$from, $to] = $this->window($request);
        $query->where('created_at', '>=', $from)->where('created_at', '<=', $to);

        if ($request->filled('actor')) {
            // KISMİ EŞLEŞME: aktör serbest metin ve "Ayşe Yılmaz" ile
            // "ayse.yilmaz" aynı kişinin iki yazımı olabiliyor.
            $query->where('actor', 'like', '%'.trim((string) $request->query('actor')).'%');
        }

        if ($request->filled('action')) {
            $query->where(function (Builder $inner) use ($request): void {
                foreach (explode(',', (string) $request->query('action')) as $raw) {
                    $action = trim($raw);

                    if ($action === '') {
                        continue;
                    }

                    /*
                     * ÖNEK KABUL EDİLİYOR (`menu.*`). Otuz küsur eylem
                     * adını tek tek seçtirmek, panelin kullanılamaz bir
                     * süzgeç çizmesi demekti. `%` ve `_` kaçırılıyor:
                     * kaçırılmasaydı `menu_%` gibi bir metin süzgeci
                     * sessizce genişletirdi.
                     */
                    if (str_ends_with($action, '.*')) {
                        $inner->orWhere('action', 'like', $this->escapeLike(substr($action, 0, -1)).'%');

                        continue;
                    }

                    $inner->orWhere('action', $action);
                }
            });
        }

        if ($request->filled('target_type')) {
            $query->where('target_type', trim((string) $request->query('target_type')));
        }

        if ($request->filled('target_id')) {
            $query->where('target_id', (int) $request->query('target_id'));
        }

        if ($request->filled('result')) {
            $results = array_values(array_filter(
                array_map(trim(...), explode(',', (string) $request->query('result'))),
            ));

            // Tanınmayan değer SESSİZCE ELENMEZ, boş sonuç üretir: yanlış
            // süzgece rağmen dolu bir liste göstermek yanıltıcı olurdu.
            $query->whereIn('result', $results);
        }

        if ($request->filled('q')) {
            $query->where('reason', 'like', '%'.$this->escapeLike(trim((string) $request->query('q'))).'%');
        }

        return $query;
    }

    /** @return array{0: Carbon, 1: Carbon} */
    private function window(Request $request): array
    {
        $from = $request->filled('from')
            ? $this->moment((string) $request->query('from'), 'from')
            : Carbon::now()->subDays(self::DEFAULT_WINDOW_DAYS);

        $to = $request->filled('to')
            ? $this->moment((string) $request->query('to'), 'to')
            : Carbon::now();

        if ($from->greaterThan($to)) {
            throw ApiException::validationFailed(
                'Başlangıç anı bitişten sonra olamaz.',
                ['field' => 'from'],
            );
        }

        return [$from, $to];
    }

    private function moment(string $value, string $field): Carbon
    {
        try {
            return Carbon::parse($value)->utc();
        } catch (\Throwable) {
            throw ApiException::validationFailed(
                'Zaman damgası ISO 8601 (UTC) biçiminde olmalı.',
                ['field' => $field],
            );
        }
    }

    /**
     * `LIKE` joker karakterlerini kaçırır.
     *
     * Kaçırılmasaydı `%` içeren bir arama terimi süzgeci sessizce
     * genişletir ve yönetici aradığından fazlasını görürdü.
     */
    private function escapeLike(string $value): string
    {
        return str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], $value);
    }

    /**
     * @param  Builder<ControlAudit>  $query
     * @return array<string, int>
     */
    private function countsByResult(Builder $query): array
    {
        $counts = array_fill_keys([
            ControlAudit::RESULT_APPLIED,
            ControlAudit::RESULT_FAILED,
            ControlAudit::RESULT_DRY_RUN,
            ControlAudit::RESULT_PENDING,
        ], 0);

        $rows = $query->clone()
            ->groupBy('result')
            ->selectRaw('result, COUNT(*) AS toplam')
            ->pluck('toplam', 'result');

        foreach ($rows as $result => $total) {
            $counts[(string) $result] = (int) $total;
        }

        return $counts;
    }

    /**
     * @param  iterable<ControlAudit>  $rows
     * @return list<array<string, mixed>>
     */
    private function rows(iterable $rows, bool $preview): array
    {
        $labels = $this->labelsFor($rows);

        $out = [];

        foreach ($rows as $row) {
            $out[] = $this->row($row, $preview, $labels);
        }

        return $out;
    }

    /**
     * @param  array<string, array<int, string>>|null  $labels  önceden toplanmış etiketler
     * @return array<string, mixed>
     */
    private function row(ControlAudit $row, bool $preview, ?array $labels = null): array
    {
        $payload = $row->payload_json;
        $truncated = false;

        if ($preview && $payload !== null) {
            $encoded = (string) json_encode($payload, JSON_UNESCAPED_UNICODE);

            if (strlen($encoded) > self::PAYLOAD_PREVIEW_BYTES) {
                /*
                 * KIRPILAN YÜK BİR NESNE OLARAK KALIR, kesilmiş bir metin
                 * olarak değil: istemci `payload_json`'ı nesne bekliyor ve
                 * yarım bir JSON dizesi orada ayrıştırma hatası üretirdi.
                 * Tam hâli `GET /{id}` ile okunuyor.
                 */
                $payload = [
                    'truncated' => true,
                    'bytes' => strlen($encoded),
                    'preview' => mb_strimwidth($encoded, 0, self::PAYLOAD_PREVIEW_BYTES, '…', 'UTF-8'),
                ];
                $truncated = true;
            }
        }

        return [
            'id' => (int) $row->id,
            'actor' => (string) $row->actor,
            'action' => (string) $row->action,
            'target_type' => $row->target_type,
            'target_id' => $row->target_id === null ? null : (int) $row->target_id,
            'target_label' => $this->labelOf($row, $labels),
            'reason' => (string) $row->reason,
            'payload_json' => $payload,
            'payload_truncated' => $truncated,
            'result' => (string) $row->result,
            'created_at' => self::ts($row->created_at),
        ];
    }

    /**
     * Sayfadaki bütün hedeflerin etiketlerini TEK SORGUDA toplar.
     *
     * Satır başına bir sorgu, elli satırlık bir sayfada elli ek sorgu
     * demekti. Etiket yalnız gösterim içindir ve satırın kendisi hedefine
     * bağımlı değil — bu yüzden toplu ve hoşgörülü okunuyor.
     *
     * @param  iterable<ControlAudit>  $rows
     * @return array<string, array<int, string>>
     */
    private function labelsFor(iterable $rows): array
    {
        /** @var array<string, list<int>> $ids */
        $ids = [];

        foreach ($rows as $row) {
            if ($row->target_type === null || $row->target_id === null) {
                continue;
            }

            $ids[$row->target_type][] = (int) $row->target_id;
        }

        $labels = [];

        foreach ($ids as $type => $list) {
            $labels[$type] = $this->labelsOfType($type, array_values(array_unique($list)));
        }

        return $labels;
    }

    /**
     * @param  list<int>  $ids
     * @return array<int, string>
     */
    private function labelsOfType(string $type, array $ids): array
    {
        return match ($type) {
            ControlAudit::TARGET_DEVICE => KitchenDevice::query()
                ->whereIn('id', $ids)->pluck('name', 'id')
                ->map(strval(...))->all(),

            ControlAudit::TARGET_ORDER => Order::query()
                ->whereIn('order_id', $ids)->pluck('order_id', 'order_id')
                ->map(static fn($id): string => 'S-'.$id)->all(),

            ControlAudit::TARGET_DAILY_MENU => DailyMenu::query()
                ->whereIn('id', $ids)->pluck('menu_date', 'id')
                ->map(static fn($date): string => Carbon::parse($date)->format('d.m.Y').' menüsü')
                ->all(),

            ControlAudit::TARGET_MENU => DB::table('menus')
                ->whereIn('menu_id', $ids)->pluck('menu_name', 'menu_id')
                ->map(strval(...))->all(),

            ControlAudit::TARGET_CATEGORY => DB::table('categories')
                ->whereIn('category_id', $ids)->pluck('name', 'category_id')
                ->map(strval(...))->all(),

            ControlAudit::TARGET_SETTINGS => DB::table('locations')
                ->whereIn('location_id', $ids)->pluck('location_name', 'location_id')
                ->map(strval(...))->all(),

            ControlAudit::TARGET_CUSTOMER => $this->customerLabels($ids),

            ControlAudit::TARGET_SUBSCRIPTION => $this->subscriptionLabels($ids),

            ControlAudit::TARGET_INVOICE => $this->invoiceLabels($ids),

            // Etiketi olmayan hedefler (`site_service`, `notification`,
            // `monitor_event` …) `null` döner. Sözleşme yalnız yukarıdaki
            // sekiz tip için etiket istiyor; uydurulmuş bir etiket, panelde
            // gerçek sanılan bir metin olurdu.
            default => [],
        };
    }

    /**
     * @param  list<int>  $ids
     * @return array<int, string>
     */
    private function customerLabels(array $ids): array
    {
        $labels = [];

        foreach (DB::table('customers')->whereIn('customer_id', $ids)->get() as $row) {
            // KURUM ADI ÖNCE: bu bir catering sistemi ve kayıtların çoğu
            // bir şirkete ait; kişi adı orada irtibat kişisidir.
            $company = trim((string) ($row->bld_org_name ?? ''));

            $labels[(int) $row->customer_id] = $company !== ''
                ? $company
                : trim(((string) $row->first_name).' '.((string) $row->last_name));
        }

        return $labels;
    }

    /**
     * @param  list<int>  $ids
     * @return array<int, string>
     */
    private function subscriptionLabels(array $ids): array
    {
        $labels = [];

        $rows = DB::table('veykemtu_subscriptions')
            ->whereIn('id', $ids)
            ->get(['id', 'customer_id']);

        $customers = $this->customerLabels(
            array_values(array_unique(array_map(static fn($r): int => (int) $r->customer_id, $rows->all()))),
        );

        foreach ($rows as $row) {
            $id = (int) $row->id;
            $labels[$id] = '#'.$id.' — '.($customers[(int) $row->customer_id] ?? 'bilinmeyen müşteri');
        }

        return $labels;
    }

    /**
     * @param  list<int>  $ids
     * @return array<int, string>
     */
    private function invoiceLabels(array $ids): array
    {
        // TABLO HENÜZ YOKSA ETİKET DE YOK. Denetim satırı hedefine bağımlı
        // değildir ve fatura tablosu ayrı bir kulvarda açılıyor; olmayan
        // bir tabloya sorgu atmak bütün listeyi 500 ile düşürürdü.
        if (!Schema::hasTable('veykemtu_invoices')) {
            return [];
        }

        return DB::table('veykemtu_invoices')
            ->whereIn('id', $ids)
            ->pluck('invoice_no', 'id')
            ->map(strval(...))
            ->all();
    }

    /** @param  array<string, array<int, string>>|null  $labels */
    private function labelOf(ControlAudit $row, ?array $labels): ?string
    {
        if ($row->target_type === null || $row->target_id === null) {
            return null;
        }

        $labels ??= $this->labelsFor([$row]);

        // HEDEF SİLİNMİŞSE `null` DÖNER ve satır yerinde kalır. Denetim
        // satırı hedefine bağımlı değildir; silinmiş bir ürünün izini
        // kaybetmek, silmeyi denetimsiz bırakmak olurdu.
        return $labels[$row->target_type][(int) $row->target_id] ?? null;
    }

    private function groupOf(string $action): string
    {
        $group = strstr($action, '.', true);

        return $group === false ? $action : $group;
    }
}
