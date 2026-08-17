<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers\Control;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Validation\Rule;
use Throwable;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\ControlAudit;
use Veykemtu\BridgeApi\Models\SiteContent;
use Veykemtu\BridgeApi\Models\SitePost;
use Veykemtu\BridgeApi\Models\SiteService;
use Veykemtu\BridgeApi\Services\SiteRevalidator;

/**
 * Kontrol Merkezi — kurumsal site içeriği (`docs/control/cms.md`).
 *
 * ÜÇ TABLO TEK ÖNEKTE: `veykemtu_site_content` (anahtar → JSON),
 * `veykemtu_site_services` (hizmet sayfaları), `veykemtu_site_posts`
 * (bilgi merkezi). Üçü de aynı siteyi besliyor ve aynı yeniden çizdirme
 * çağrısını paylaşıyor; ayrı önekler, panelde aynı işi yapan üç ekran
 * üretirdi.
 *
 * HTML TEMİZLİĞİ BU SINIFTA DEĞİL, MODELİN MUTATOR'INDA
 * (`SiteService::setBodyHtmlAttribute`, `SitePost::…`). İKİNCİ BİR
 * TEMİZLEYİCİ EKLENMEDİ ve eklenmemeli: temizlik mutator'da olduğu için
 * içeriğin nereden geldiği (bu uç, admin formu, içe aktarma komutu, test)
 * fark etmiyor. Denetleyicide ikinci bir `HtmlSanitizer` çağrısı, iki
 * izin listesinin zamanla ayrışması ve "panelden girince kayboluyor, admin
 * formundan girince kalıyor" gibi bir arıza demekti.
 *
 * YANIT TEMİZLENMİŞ HÂLİ DÖNER. Panel gönderdiğini geri okuyamazsa,
 * yaptığı yapıştırmanın izin listesinde olmayan etiketlerini kaybettiğini
 * hiç fark etmez.
 */
class CmsController extends ControlController
{
    /**
     * `value` alanının serileştirilmiş boyut tavanı — 256 KB.
     *
     * Şema DOĞRULANMIYOR (sözleşme kararı): bu tablonun tek amacı siteye
     * şekilsiz içerik taşımak ve şema koymak, site yeni bir alan eklediğinde
     * sunucu göçü gerektirirdi. Denetlenen tek şey geçerli JSON olması ve
     * boyutu; sınırsız bir alan, tek bir yapıştırmayla site paketini
     * megabaytlara çıkarırdı.
     */
    private const int MAX_VALUE_BYTES = 262144;

    /** Adres parçası kalıbı — küçük harf, rakam, tek tire. */
    private const string SLUG_PATTERN = '/^[a-z0-9]+(-[a-z0-9]+)*$/';

    /** Dizi alanlarının eleman ve uzunluk sınırı. */
    private const int MAX_LIST_ITEMS = 20;

    private const int MAX_LIST_ITEM_LENGTH = 300;

    /** `POST /revalidate` yol listesi tavanı. */
    private const int MAX_REVALIDATE_PATHS = 20;

    public function __construct(private readonly SiteRevalidator $revalidator) {}

    // ── İçerik anahtarları ────────────────────────────────────────────────

    /**
     * Yedi anahtarın tamamı tek istekte.
     *
     * KAYDI OLMAYAN ANAHTAR DA DÖNER (boş değer, `updated_at: null`).
     * Eksik anahtarı atlamak, panelin "bu alan yok mu, yoksa boş mu"
     * sorusunu kendi cevaplamasını gerektirirdi.
     */
    public function content(): JsonResponse
    {
        $rows = SiteContent::query()->get()->keyBy('key');

        $data = [];

        foreach (SiteContent::KEYS as $key) {
            $row = $rows->get($key);

            $data[$key] = [
                'value' => $row instanceof SiteContent ? ($row->value ?? []) : [],
                'updated_at' => $row instanceof SiteContent ? self::ts($row->updated_at) : null,
            ];
        }

        return $this->json([
            'data' => $data,
            'meta' => ['keys' => SiteContent::KEYS],
            'server_time' => $this->serverTime(),
        ]);
    }

    public function updateContent(Request $request, string $key): JsonResponse
    {
        // LİSTEDE OLMAYAN ANAHTAR 404. Anahtarlar sabittir ve yeni bir
        // anahtar uydurulamaz: site onları sabit adlarla okuyor, uydurulan
        // anahtar hiçbir yerde görünmeyen bir kayıt olurdu.
        if (!in_array($key, SiteContent::KEYS, true)) {
            throw ApiException::notFound('Bilinmeyen içerik anahtarı: '.$key);
        }

        $request->validate([
            'value' => ['required'],
            'revalidate' => ['sometimes', 'boolean'],
        ]);

        $value = $request->input('value');

        if (!is_array($value)) {
            throw ApiException::validationFailed(
                'İçerik değeri bir nesne ya da dizi olmalı.',
                ['field' => 'value'],
            );
        }

        $bytes = strlen((string) json_encode($value, JSON_UNESCAPED_UNICODE));

        if ($bytes > self::MAX_VALUE_BYTES) {
            throw ApiException::validationFailed(
                'İçerik 256 KB sınırını aşıyor.',
                ['field' => 'value', 'bytes' => $bytes, 'max_bytes' => self::MAX_VALUE_BYTES],
            );
        }

        $revalidate = $request->boolean('revalidate', true);
        $existing = SiteContent::find($key);

        return $this->write(
            $request,
            'cms.content.update',
            ControlAudit::TARGET_SITE_CONTENT,
            // `target_id` YOK: birincil anahtar bir metin, anahtar yükte.
            null,
            /*
             * YÜKE İÇERİĞİN TAMAMI YAZILMAZ. Eski ve yeni değeri saklamak,
             * denetim tablosunu bir sürüm deposuna çevirirdi — hem boyut
             * hem de kişisel veri açısından (iletişim bloğunda telefon ve
             * adres var).
             */
            [
                'key' => $key,
                'bytes' => $bytes,
                'changed_top_level_keys' => $this->changedTopLevelKeys($existing?->value, $value),
            ],
            static fn(): array => [
                'action' => 'cms.content.update',
                'key' => $key,
                'bytes' => $bytes,
                'revalidate' => $revalidate,
            ],
            function () use ($key, $value, $revalidate): array {
                $row = SiteContent::firstOrNew(['key' => $key]);
                // TAM DEĞER YAZILIR, BİRLEŞTİRİLMEZ. Kısmi yazma, iç içe
                // geçmiş JSON'da "hangi seviyede birleştiriliyor" sorusunu
                // doğururdu ve iki farklı cevabı olan bir kural sessizce
                // veri kaybettirir.
                $row->value = $value;
                $row->save();

                return [
                    'data' => ['key' => $key, 'updated_at' => self::ts($row->updated_at)],
                    ...$this->runRevalidate($revalidate),
                ];
            },
        );
    }

    // ── Hizmetler ─────────────────────────────────────────────────────────

    /** Sayfalanmaz: hizmet sayısı onlarla ifade edilir. */
    public function services(Request $request): JsonResponse
    {
        $query = SiteService::query()->orderBy('sort_order')->orderBy('id');

        $published = (string) $request->query('published', 'all');

        if ($published === 'true') {
            $query->where('is_published', true);
        } elseif ($published === 'false') {
            $query->where('is_published', false);
        }

        return $this->json([
            'data' => $query->get()->map($this->serviceRow(...))->values()->all(),
            'server_time' => $this->serverTime(),
        ]);
    }

    public function storeService(Request $request): JsonResponse
    {
        $data = $this->validateService($request, creating: true);
        $slug = (string) $data['slug'];

        if (SiteService::where('slug', $slug)->exists()) {
            throw $this->conflict('Bu adres parçası zaten kullanılıyor.', [
                'conflict' => 'slug',
                'slug' => $slug,
            ]);
        }

        $revalidate = $request->boolean('revalidate', true);

        return $this->write(
            $request,
            'cms.service.create',
            ControlAudit::TARGET_SITE_SERVICE,
            null,
            ['slug' => $slug, 'title' => $data['title'], 'is_published' => $data['is_published'] ?? false],
            static fn(): array => [
                'action' => 'cms.service.create',
                'slug' => $slug,
                'title' => $data['title'],
            ],
            function () use ($data, $revalidate): array {
                $service = new SiteService;
                $this->fillService($service, $data);
                $service->save();

                return [
                    'data' => $this->serviceRow($service->refresh()),
                    ...$this->runRevalidate($revalidate),
                ];
            },
        );
    }

    public function updateService(Request $request, int $service): JsonResponse
    {
        $model = SiteService::find($service);

        if ($model === null) {
            throw ApiException::notFound('Hizmet kaydı bulunamadı.');
        }

        $data = $this->validateService($request, creating: false);
        $warnings = [];

        if (isset($data['slug']) && (string) $data['slug'] !== (string) $model->slug) {
            $slug = (string) $data['slug'];

            if (SiteService::where('slug', $slug)->where('id', '!=', $model->id)->exists()) {
                throw $this->conflict('Bu adres parçası zaten kullanılıyor.', [
                    'conflict' => 'slug',
                    'slug' => $slug,
                ]);
            }

            /*
             * SLUG YAZILABİLİR AMA UYARI ÜRETİR. Engellemek, yazım hatasıyla
             * yayına çıkmış bir adresi ömür boyu taşımak demekti; sessizce
             * değiştirmek ise dışarıdan verilmiş bağlantıları haber vermeden
             * kırardı.
             */
            $warnings[] = [
                'code' => 'slug_changed',
                'from' => (string) $model->slug,
                'to' => $slug,
                'note' => 'Eski adrese verilen bağlantılar kırılacak.',
            ];
        }

        $revalidate = $request->boolean('revalidate', true);

        return $this->write(
            $request,
            'cms.service.update',
            ControlAudit::TARGET_SITE_SERVICE,
            (int) $model->id,
            ['slug' => (string) $model->slug, 'fields' => array_keys($data)],
            static fn(): array => [
                'action' => 'cms.service.update',
                'id' => (int) $model->id,
                'fields' => array_keys($data),
                'warnings' => $warnings,
            ],
            function () use ($model, $data, $warnings, $revalidate): array {
                $this->fillService($model, $data);
                $model->save();

                return [
                    'data' => $this->serviceRow($model->refresh()),
                    'warnings' => $warnings,
                    ...$this->runRevalidate($revalidate),
                ];
            },
        );
    }

    /**
     * GERÇEK SİLME.
     *
     * Hizmet kayıtları başka hiçbir tabloya bağlı değil; yumuşak silme için
     * `is_published = false` zaten var ve gerçekten silmek isteyen yönetici
     * onu değil bunu kastediyor.
     */
    public function destroyService(Request $request, int $service): JsonResponse
    {
        $model = SiteService::find($service);

        if ($model === null) {
            throw ApiException::notFound('Hizmet kaydı bulunamadı.');
        }

        $revalidate = $request->boolean('revalidate', true);
        $slug = (string) $model->slug;

        return $this->write(
            $request,
            'cms.service.delete',
            ControlAudit::TARGET_SITE_SERVICE,
            (int) $model->id,
            ['slug' => $slug, 'title' => (string) $model->title],
            static fn(): array => [
                'action' => 'cms.service.delete',
                'id' => (int) $model->id,
                'slug' => $slug,
            ],
            function () use ($model, $slug, $revalidate): array {
                $id = (int) $model->id;
                $model->delete();

                return [
                    'data' => ['id' => $id, 'slug' => $slug, 'deleted' => true],
                    ...$this->runRevalidate($revalidate),
                ];
            },
        );
    }

    // ── Yazılar ───────────────────────────────────────────────────────────

    public function posts(Request $request): JsonResponse
    {
        $request->validate([
            'q' => ['sometimes', 'string', 'max:200'],
            'category' => ['sometimes', 'string', 'max:64'],
            'published' => ['sometimes', Rule::in(['true', 'false', 'all'])],
            'page' => ['sometimes', 'integer', 'min:1'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:100'],
        ]);

        $query = SitePost::query();

        $published = (string) $request->query('published', 'all');

        if ($published === 'true') {
            $query->where('is_published', true);
        } elseif ($published === 'false') {
            $query->where('is_published', false);
        }

        if ($request->filled('category')) {
            $query->where('category', trim((string) $request->query('category')));
        }

        if ($request->filled('q')) {
            $term = '%'.str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], trim((string) $request->query('q'))).'%';

            $query->where(function ($inner) use ($term): void {
                $inner->where('title', 'like', $term)
                    ->orWhere('description', 'like', $term)
                    ->orWhere('slug', 'like', $term);
            });
        }

        $page = max(1, (int) $request->query('page', '1'));
        $perPage = min(100, max(1, (int) $request->query('per_page', '25')));
        $total = (int) $query->clone()->count();

        $rows = $query->clone()
            ->orderByDesc('published_at')
            ->orderByDesc('id')
            ->forPage($page, $perPage)
            ->get();

        return $this->json([
            'data' => $rows->map($this->postRow(...))->values()->all(),
            'meta' => [
                'page' => $page,
                'per_page' => $perPage,
                'total' => $total,
                'last_page' => max(1, (int) ceil($total / $perPage)),
                /*
                 * KATEGORİ AYRI BİR TABLO DEĞİL, serbest bir metin alanı.
                 * Panel açılır listeyi bu damıtılmış listeden dolduruyor;
                 * olmasaydı yönetici her yazıda yeni bir kategori uydurur
                 * ve süzgeç işe yaramaz hâle gelirdi. Liste SÜZGEÇTEN
                 * BAĞIMSIZ — süzgeçlenmiş kümeye göre daralan bir açılır
                 * liste, seçili kategoriden çıkmayı imkânsız kılardı.
                 */
                'categories' => SitePost::query()
                    ->whereNotNull('category')
                    ->distinct()
                    ->orderBy('category')
                    ->pluck('category')
                    ->map(strval(...))
                    ->values()
                    ->all(),
            ],
            'server_time' => $this->serverTime(),
        ]);
    }

    public function storePost(Request $request): JsonResponse
    {
        $data = $this->validatePost($request, creating: true);
        $slug = (string) $data['slug'];

        if (SitePost::where('slug', $slug)->exists()) {
            throw $this->conflict('Bu adres parçası zaten kullanılıyor.', [
                'conflict' => 'slug',
                'slug' => $slug,
            ]);
        }

        $revalidate = $request->boolean('revalidate', true);

        return $this->write(
            $request,
            'cms.post.create',
            ControlAudit::TARGET_SITE_POST,
            null,
            ['slug' => $slug, 'title' => $data['title'], 'category' => $data['category']],
            static fn(): array => [
                'action' => 'cms.post.create',
                'slug' => $slug,
                'title' => $data['title'],
            ],
            function () use ($data, $revalidate): array {
                $post = new SitePost;
                $this->fillPost($post, $data);
                $post->save();

                return [
                    'data' => $this->postRow($post->refresh()),
                    ...$this->runRevalidate($revalidate),
                ];
            },
        );
    }

    public function updatePost(Request $request, int $post): JsonResponse
    {
        $model = SitePost::find($post);

        if ($model === null) {
            throw ApiException::notFound('Yazı bulunamadı.');
        }

        $data = $this->validatePost($request, creating: false);
        $warnings = [];

        if (isset($data['slug']) && (string) $data['slug'] !== (string) $model->slug) {
            $slug = (string) $data['slug'];

            if (SitePost::where('slug', $slug)->where('id', '!=', $model->id)->exists()) {
                throw $this->conflict('Bu adres parçası zaten kullanılıyor.', [
                    'conflict' => 'slug',
                    'slug' => $slug,
                ]);
            }

            $warnings[] = [
                'code' => 'slug_changed',
                'from' => (string) $model->slug,
                'to' => $slug,
                'note' => 'Eski adrese verilen bağlantılar kırılacak.',
            ];
        }

        $revalidate = $request->boolean('revalidate', true);

        return $this->write(
            $request,
            'cms.post.update',
            ControlAudit::TARGET_SITE_POST,
            (int) $model->id,
            ['slug' => (string) $model->slug, 'fields' => array_keys($data)],
            static fn(): array => [
                'action' => 'cms.post.update',
                'id' => (int) $model->id,
                'fields' => array_keys($data),
                'warnings' => $warnings,
            ],
            function () use ($model, $data, $warnings, $revalidate): array {
                $this->fillPost($model, $data);
                $model->save();

                return [
                    'data' => $this->postRow($model->refresh()),
                    'warnings' => $warnings,
                    ...$this->runRevalidate($revalidate),
                ];
            },
        );
    }

    public function destroyPost(Request $request, int $post): JsonResponse
    {
        $model = SitePost::find($post);

        if ($model === null) {
            throw ApiException::notFound('Yazı bulunamadı.');
        }

        $revalidate = $request->boolean('revalidate', true);
        $slug = (string) $model->slug;

        return $this->write(
            $request,
            'cms.post.delete',
            ControlAudit::TARGET_SITE_POST,
            (int) $model->id,
            ['slug' => $slug, 'title' => (string) $model->title],
            static fn(): array => [
                'action' => 'cms.post.delete',
                'id' => (int) $model->id,
                'slug' => $slug,
            ],
            function () use ($model, $slug, $revalidate): array {
                $id = (int) $model->id;
                $model->delete();

                return [
                    'data' => ['id' => $id, 'slug' => $slug, 'deleted' => true],
                    ...$this->runRevalidate($revalidate),
                ];
            },
        );
    }

    // ── Yeniden çizdirme ──────────────────────────────────────────────────

    /**
     * Siteyi elle yeniden çizdirir.
     *
     * Diğer uçlardaki `revalidate: true` bayrağı bunun AYNISINI çağırıyor;
     * bu uç, bayrağı `false` bırakıp art arda birkaç kayıt yazan ve sonunda
     * tek seferde çizdirmek isteyen yönetici içindir.
     */
    public function revalidate(Request $request): JsonResponse
    {
        $request->validate([
            'paths' => ['sometimes', 'nullable', 'array', 'max:'.self::MAX_REVALIDATE_PATHS],
            'paths.*' => ['string', 'max:255', 'regex:/^\//'],
        ]);

        /** @var list<string>|null $paths */
        $paths = $request->input('paths');
        $paths = is_array($paths) && $paths !== [] ? array_values($paths) : null;

        return $this->write(
            $request,
            'cms.revalidate',
            null,
            null,
            ['requested' => $paths ?? 'all'],
            static fn(): array => [
                'action' => 'cms.revalidate',
                'requested' => $paths ?? 'all',
            ],
            function () use ($paths): array {
                $result = $this->runRevalidate(true, $paths);

                return [
                    'data' => $result['revalidation'],
                    ...(isset($result['warnings']) ? ['warnings' => $result['warnings']] : []),
                ];
            },
        );
    }

    // ── Yardımcılar ───────────────────────────────────────────────────────

    /**
     * Yeniden çizdirmeyi çağırır ve sonucunu yanıt parçası olarak döndürür.
     *
     * ÇİZDİRME HATASI İSTEĞİ BAŞARISIZ YAPMAZ. İçerik zaten yazıldı; hata
     * yüzünden `500` dönmek yöneticiye "kaydedilmedi" dedirtir ve o kaydı
     * ikinci kez yazar. Tek eksik, sitenin birkaç dakika sonra kendiliğinden
     * tazelenecek olması.
     *
     * `SiteRevalidator` HATAYI KENDİ YUTUYOR (sınıf yorumunda gerekçesi
     * var), yani bu `try/catch` bugün hiç tetiklenmiyor. Yine de duruyor:
     * servis bir gün istisna fırlatır hâle gelirse, o gün içerik yazması
     * sessizce `500`'e dönmesin.
     *
     * @param  list<string>|null  $paths
     * @return array<string, mixed>
     */
    private function runRevalidate(bool $enabled, ?array $paths = null): array
    {
        if (!$enabled) {
            return ['revalidated' => false];
        }

        $started = microtime(true);
        $error = null;

        try {
            $this->revalidator->revalidate();
        } catch (Throwable $exception) {
            $error = $exception->getMessage();
        }

        $duration = (int) round((microtime(true) - $started) * 1000);

        $block = [
            'requested' => $paths ?? 'all',
            'status' => $error === null ? 'ok' : 'failed',
            'duration_ms' => $duration,
        ];

        if ($error !== null) {
            $block['error'] = mb_strimwidth($error, 0, 200, '…', 'UTF-8');

            return [
                'revalidated' => false,
                'revalidation' => $block,
                'warnings' => [['code' => 'revalidate_failed']],
            ];
        }

        return ['revalidated' => true, 'revalidation' => $block];
    }

    /**
     * Hangi üst düzey anahtarların değiştiği — denetim yükü için.
     *
     * Değerin tamamı yazılmadığı için "ne değişti" sorusunun tek cevabı bu
     * liste. İçerik bir dizi ise (SSS, sektörler) anahtar kavramı yok;
     * o durumda liste boş döner ve `bytes` tek ipucu olur.
     *
     * @param  array<mixed>|null  $old
     * @param  array<mixed>  $new
     * @return list<string>
     */
    private function changedTopLevelKeys(?array $old, array $new): array
    {
        $old ??= [];

        if (array_is_list($old) || array_is_list($new)) {
            return [];
        }

        $changed = [];

        foreach (array_unique([...array_keys($old), ...array_keys($new)]) as $key) {
            if (!is_string($key)) {
                continue;
            }

            if (($old[$key] ?? null) !== ($new[$key] ?? null)) {
                $changed[] = $key;
            }
        }

        return array_values($changed);
    }

    /**
     * @return array<string, mixed>
     */
    private function validateService(Request $request, bool $creating): array
    {
        $required = $creating ? 'required' : 'sometimes';

        return $request->validate([
            'slug' => [$required, 'string', 'min:2', 'max:96', 'regex:'.self::SLUG_PATTERN],
            'title' => [$required, 'string', 'max:160'],
            'summary' => [$required, 'string', 'max:400'],
            'intro' => [$required, 'string', 'max:5000'],
            // İKON DOĞRULANMAZ: liste sitede yaşıyor ve sunucuya kopyalamak
            // iki yerde iki gerçek üretirdi. Site bilinmeyen adı sessizce
            // varsayılana düşürüyor ve boş kutu göstermiyor.
            'icon' => [$required, 'string', 'max:48'],
            'body_html' => ['sometimes', 'nullable', 'string', 'max:'.self::MAX_VALUE_BYTES],
            'menu_planning' => [$required, 'string', 'max:5000'],
            'sort_order' => ['sometimes', 'integer', 'min:0', 'max:10000'],
            'is_published' => ['sometimes', 'boolean'],
            'audience' => ['sometimes', 'array', 'max:'.self::MAX_LIST_ITEMS],
            'audience.*' => ['string', 'max:'.self::MAX_LIST_ITEM_LENGTH],
            'how_it_works' => ['sometimes', 'array', 'max:'.self::MAX_LIST_ITEMS],
            'how_it_works.*' => ['string', 'max:'.self::MAX_LIST_ITEM_LENGTH],
            'benefits' => ['sometimes', 'array', 'max:'.self::MAX_LIST_ITEMS],
            'benefits.*' => ['string', 'max:'.self::MAX_LIST_ITEM_LENGTH],
            'quote_needs' => ['sometimes', 'array', 'max:'.self::MAX_LIST_ITEMS],
            'quote_needs.*' => ['string', 'max:'.self::MAX_LIST_ITEM_LENGTH],
        ]);
    }

    /** @param  array<string, mixed>  $data */
    private function fillService(SiteService $service, array $data): void
    {
        foreach ([
            'slug', 'title', 'summary', 'intro', 'icon', 'body_html',
            'menu_planning', 'sort_order', 'is_published',
            'audience', 'how_it_works', 'benefits', 'quote_needs',
        ] as $field) {
            if (array_key_exists($field, $data)) {
                $service->{$field} = $data[$field];
            }
        }

        // Yeni kayıtta dizi alanları `null` kalmasın: site onları `foreach`
        // ile dolaşıyor ve `null` orada ölümcül hataya dönüşür.
        foreach (['audience', 'how_it_works', 'benefits', 'quote_needs'] as $field) {
            $service->{$field} ??= [];
        }

        $service->sort_order ??= 0;
        $service->is_published ??= false;
    }

    /**
     * @return array<string, mixed>
     */
    private function validatePost(Request $request, bool $creating): array
    {
        $required = $creating ? 'required' : 'sometimes';

        return $request->validate([
            'slug' => [$required, 'string', 'min:2', 'max:96', 'regex:'.self::SLUG_PATTERN],
            'title' => [$required, 'string', 'max:200'],
            'description' => [$required, 'string', 'max:400'],
            'category' => [$required, 'string', 'max:64'],
            // BOŞ GÖVDE YASAK: kolon `NOT NULL` ve boş gövdeli bir yazı,
            // sitede başlığı olan boş bir sayfa üretirdi.
            'body_html' => [$required, 'string', 'min:1', 'max:'.self::MAX_VALUE_BYTES],
            // TARİH, AN DEĞİL: yayın günü yazarın kararıdır ve `created_at`
            // ile aynı olmak zorunda değil (geçmişe tarihli yazı, ileri
            // tarihli planlama).
            'published_at' => [$required, 'date_format:Y-m-d'],
            'reading_minutes' => ['sometimes', 'nullable', 'integer', 'min:1', 'max:600'],
            'is_published' => ['sometimes', 'boolean'],
        ]);
    }

    /** @param  array<string, mixed>  $data */
    private function fillPost(SitePost $post, array $data): void
    {
        foreach ([
            'slug', 'title', 'description', 'category', 'body_html',
            'published_at', 'reading_minutes', 'is_published',
        ] as $field) {
            if (array_key_exists($field, $data)) {
                $post->{$field} = $data[$field];
            }
        }

        $post->is_published ??= false;
    }

    /** @return array<string, mixed> */
    private function serviceRow(SiteService $service): array
    {
        return [
            'id' => (int) $service->id,
            'slug' => (string) $service->slug,
            'title' => (string) $service->title,
            'summary' => (string) $service->summary,
            'intro' => (string) $service->intro,
            'icon' => (string) $service->icon,
            // TEMİZLENMİŞ HÂLİ DÖNER (mutator kayıt anında temizledi).
            'body_html' => $service->body_html,
            'audience' => $service->audience ?? [],
            'how_it_works' => $service->how_it_works ?? [],
            'benefits' => $service->benefits ?? [],
            'menu_planning' => (string) $service->menu_planning,
            'quote_needs' => $service->quote_needs ?? [],
            'sort_order' => (int) $service->sort_order,
            'is_published' => (bool) $service->is_published,
            'created_at' => self::ts($service->created_at),
            'updated_at' => self::ts($service->updated_at),
        ];
    }

    /** @return array<string, mixed> */
    private function postRow(SitePost $post): array
    {
        return [
            'id' => (int) $post->id,
            'slug' => (string) $post->slug,
            'title' => (string) $post->title,
            'description' => (string) $post->description,
            'category' => (string) $post->category,
            'body_html' => (string) $post->body_html,
            'published_at' => $post->published_at instanceof Carbon
                ? $post->published_at->toDateString()
                : null,
            'reading_minutes' => $post->reading_minutes,
            // İKİSİ AYRI VERİLİYOR: panel "hesaplandı" ipucunu ancak elle
            // girilenin boş olduğunu görerek gösterebilir.
            'reading_minutes_effective' => $post->readingMinutes(),
            'is_published' => (bool) $post->is_published,
            'created_at' => self::ts($post->created_at),
            'updated_at' => self::ts($post->updated_at),
        ];
    }

    /** @param  array<string, mixed>  $details */
    private function conflict(string $message, array $details): ApiException
    {
        // `CONFLICT` bilinçli olarak geniş (`00-genel.md` §7.2): ekranın
        // yapacağı şey her hâlde aynı — tazele ve tekrar sor. Ayrımı
        // `details.conflict` taşıyor.
        return new ApiException('CONFLICT', $message, 409, $details);
    }
}
