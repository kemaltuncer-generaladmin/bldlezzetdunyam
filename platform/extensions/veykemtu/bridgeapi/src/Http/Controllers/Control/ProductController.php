<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers\Control;

use Igniter\Cart\Models\Category;
use Igniter\Cart\Models\Menu;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\ControlAudit;
use Veykemtu\BridgeApi\Models\DailyMenu;
use Veykemtu\BridgeApi\Services\MenuAvailability;
use Veykemtu\BridgeApi\Services\ProductImageService;
use Veykemtu\BridgeApi\Support\BusinessTime;
use Veykemtu\BridgeApi\Support\Money;

/**
 * Kontrol Merkezi — ürün kataloğu (`/api/control/products`).
 *
 * Sözleşme: `docs/control/products.md`. Bir ürün burada doğar, fiyatlanır,
 * görsellenir ve satıştan kaldırılır; **hangi gün satılacağı** `control/menu`
 * alanının işidir. İki alan bilinçli olarak ayrı: ürün kataloğu haftalarca
 * değişmez, günlük menü her gün değişir.
 *
 * KAYNAK TABLOLAR ÇEKİRDEĞİN: `menus`, `categories`, `menu_categories`.
 * `platform/vendor/` düzenlenmiyor; bu uçlar çekirdek modelleri yalnızca
 * okuyup yazıyor ve kolon adları modelden alınıyor (`menu_name`,
 * `menu_price`, `menu_status`, `menu_priority`).
 *
 * ## Görsel neden JSON gövdesinde base64, neden multipart DEĞİL
 *
 * `Http\Middleware\VerifyControlSignature` imzayı `$request->getContent()`
 * üzerinde, yani **ham gövdenin baytları** üzerinde doğruluyor. Multipart
 * gövde sınır dizeleri (boundary) taşır ve gövdeyi yeniden kodlayan
 * herhangi bir vekil —proxy, load balancer, gzip, WAF— baytları değiştirir.
 * Değişen tek bayt imzayı bozar ve sunucu `401 UNAUTHENTICATED` döndürür:
 * yani **görsel yükleme arızası sahada "sır yanlış" ya da "saat kaymış"
 * gibi görünür.** Kimlik doğrulama kılığına girmiş bir yükleme hatası,
 * teşhis edilmesi en zor arıza türüdür.
 *
 * Bu yüzden görsel JSON gövdesinin içinde `content_base64` alanında gider:
 * JSON gövde bayt bayt korunur ve diğer bütün yazma uçlarıyla aynı yoldan
 * geçer. Multipart teknik olarak çalışırdı — sorun çalışmaması değil,
 * bozulduğunda yalan söylemesi.
 *
 * ## İki ayrı "satılamaz" mekanizması vardır, karıştırılmamalı
 *
 * - `menu_status = 0` → yöneticinin KALICI kararı (`DELETE /{menu}`).
 * - `veykemtu_menu_soldout` → o GÜNE özel işaret (`POST /{menu}/sold-out`),
 *   ertesi gün kendiliğinden düşer. Normalde KDS koyar; merkezden de
 *   konabilmesinin sebebi somut: mutfak kasası çöktüğünde bir ürünü
 *   satıştan çekmenin başka yolu kalmıyor.
 *
 * Her yazma `ControlController::write()` kabuğundan geçer; kabuk dışında
 * yazan bir uç sözleşmeye aykırıdır (`docs/control/00-genel.md` §4).
 */
class ProductController extends ControlController
{
    /**
     * Denetim hedef tipleri — `docs/control/00-genel.md` §8.1.
     *
     * `ControlAudit` bugün yalnız `TARGET_DEVICE` ve `TARGET_ORDER`
     * sabitlerini taşıyor; `menu` ve `category` sabitleri o modele
     * eklenecek ve model bu kulvarın dışında. Değerler sözleşmeden
     * okundu, uydurulmadı; sabitler modele düştüğünde buradaki iki satır
     * silinip `ControlAudit::TARGET_MENU` ile değiştirilmelidir.
     */
    private const string TARGET_MENU = 'menu';

    private const string TARGET_CATEGORY = 'category';

    /** `veykemtu_menu_soldout.reason` sütununun boyu. */
    private const int SOLD_OUT_REASON_MAX = 160;

    public function __construct(
        private readonly MenuAvailability $availability,
        private readonly ProductImageService $images,
    ) {}

    // ── Ürünler ───────────────────────────────────────────────────────────

    /**
     * `GET /` — ürün listesi (sayfalı).
     *
     * `status` VARSAYILANI `all`, `active` DEĞİL. Yönetimin ilk sorusu çoğu
     * zaman "bu ürün nerede" biçiminde gelir ve cevabı "satıştan
     * kaldırılmış"tır; varsayılan süzgeç onu gizleseydi ürün kaybolmuş
     * görünürdü.
     *
     * `options` LİSTEDE BOŞ DÖNER. Seksen ürünün seçeneklerini her sayfada
     * taşımak, ekranın göstermediği veriyi yollamak olurdu; dolu hâli
     * yalnız [show] yanıtındadır.
     */
    public function index(Request $request): JsonResponse
    {
        $request->validate([
            'q' => ['sometimes', 'string', 'min:2', 'max:120'],
            'category_id' => ['sometimes', 'integer', 'min:1'],
            'status' => ['sometimes', Rule::in(['active', 'inactive', 'all'])],
            // `boolean` KURALI KULLANILMAZ: sorgu dizesinde boolean ancak
            // metin olarak ifade edilebilir ve Laravel'in `boolean` kuralı
            // `"true"` dizgesini reddeder (aynı hata KDS'i bir kez kör
            // etmişti). `$request->boolean()` hepsini doğru okur.
            'sold_out' => ['sometimes', Rule::in(['1', '0', 'true', 'false'])],
            'sort' => ['sometimes', Rule::in(['name', 'price', 'priority', 'updated'])],
            'direction' => ['sometimes', Rule::in(['asc', 'desc'])],
            'page' => ['sometimes', 'integer', 'min:1'],
            'per_page' => ['sometimes', 'integer', 'min:1'],
        ]);

        // Sayfa boyu KIRPILIR, reddedilmez — sözleşmenin tek sayfalama
        // biçimi `Http\Controllers\OrderController::index` ile aynıdır.
        $perPage = min(100, max(1, (int) $request->query('per_page', '25')));
        $page = max(1, (int) $request->query('page', '1'));

        $soldOut = $this->availability->soldOutReasons();

        $query = Menu::query()->with('media');

        match ((string) $request->query('status', 'all')) {
            'active' => $query->where('menu_status', true),
            'inactive' => $query->where('menu_status', false),
            default => null,
        };

        if ($request->filled('q')) {
            $term = $this->likeTerm((string) $request->query('q'));

            $query->where(static function($builder) use ($term): void {
                $builder
                    ->where('menu_name', 'like', $term)
                    ->orWhere('menu_description', 'like', $term);
            });
        }

        if ($request->filled('category_id')) {
            /*
             * Pivot ALT SORGUYLA süzülüyor, `whereHas` ile değil: aynı ürün
             * birden çok kategoride olabildiği için ilişkisel bir `join`
             * satırı çoğaltır ve `total` gerçekte olduğundan büyük çıkardı.
             */
            $query->whereIn('menu_id', DB::table('menu_categories')
                ->where('category_id', (int) $request->query('category_id'))
                ->select('menu_id'));
        }

        if ($request->has('sold_out')) {
            $ids = array_map(intval(...), array_keys($soldOut));

            $request->boolean('sold_out')
                ? $query->whereIn('menu_id', $ids)
                : $query->whereNotIn('menu_id', $ids);
        }

        $column = match ((string) $request->query('sort', 'name')) {
            'price' => 'menu_price',
            'priority' => 'menu_priority',
            'updated' => 'updated_at',
            default => 'menu_name',
        };

        $direction = (string) $request->query('direction', 'asc') === 'desc' ? 'desc' : 'asc';

        // İKİNCİ ANAHTAR BERABERLİĞİ BOZAR. Eşit adlı ya da eşit öncelikli
        // iki ürün sayfadan sayfaya yer değiştirirse aynı ürün iki sayfada
        // görünür, bir başkası hiç görünmez.
        $paginator = $query->orderBy($column, $direction)
            ->orderBy('menu_id')
            ->paginate(perPage: $perPage, page: $page);

        /** @var list<Menu> $rows */
        $rows = $paginator->items();
        $ids = array_map(static fn(Menu $menu): int => (int) $menu->menu_id, $rows);

        $categories = $this->categoryIdsFor($ids);
        $packages = $this->packageMenuIds();

        return $this->json([
            'data' => array_map(
                fn(Menu $menu): array => $this->productPayload(
                    $menu,
                    $soldOut,
                    $categories[(int) $menu->menu_id] ?? [],
                    $packages,
                    withOptions: false,
                ),
                $rows,
            ),
            'meta' => [
                'page' => $paginator->currentPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
                'last_page' => max(1, $paginator->lastPage()),
            ],
            'server_time' => $this->serverTime(),
        ]);
    }

    /** `GET /{menu}` — tek ürün, seçenekleri DÂHİL (salt okunur). */
    public function show(int $menu): JsonResponse
    {
        $model = $this->findMenu($menu, withOptions: true);

        return $this->json([
            'data' => $this->productPayload(
                $model,
                $this->availability->soldOutReasons(),
                $this->categoryIdsFor([(int) $model->menu_id])[(int) $model->menu_id] ?? [],
                $this->packageMenuIds(),
                withOptions: true,
            ),
            'server_time' => $this->serverTime(),
        ]);
    }

    /**
     * `POST /` — yeni ürün.
     *
     * AYNI ADDA ÜRÜN ENGELLENMEZ. "Tavuk Sote" iki farklı tarifle iki ürün
     * olabilir; adı tekilleştirmek gerçek bir işi bloke ederdi. Panel uyarı
     * gösterir, sunucu engellemez.
     */
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'min:2', 'max:128'],
            'description' => ['sometimes', 'nullable', 'string', 'max:5000'],
            // Sıfır GEÇERLİDİR: paket bileşeni olarak satılan ekmek, ayran.
            'price_kurus' => ['required', 'integer', 'min:0'],
            'minimum_qty' => ['sometimes', 'integer', 'min:1'],
            'priority' => ['sometimes', 'integer', 'min:0'],
            'status' => ['sometimes', 'boolean'],
            'category_ids' => ['sometimes', 'array'],
            'category_ids.*' => ['integer', 'exists:categories,category_id'],
        ]);

        $categoryIds = $this->uniqueIds($data['category_ids'] ?? []);

        $created = null;

        $response = $this->write(
            $request,
            'product.create',
            self::TARGET_MENU,
            // Denetim satırı işlemden ÖNCE açılıyor ve ürünün kimliği o an
            // henüz yok; satır uygulandıktan sonra tamamlanıyor
            // ([stampAuditTarget]).
            null,
            [
                'name' => $data['name'],
                'price_kurus' => (int) $data['price_kurus'],
                'category_ids' => $categoryIds,
            ],
            would: static fn(): array => [
                'action' => 'product.create',
                'name' => $data['name'],
                'price_kurus' => (int) $data['price_kurus'],
                'category_ids' => $categoryIds,
            ],
            apply: function() use ($data, $categoryIds, &$created): array {
                $menu = new Menu;
                $menu->menu_name = $data['name'];
                $menu->menu_description = $this->normalizeText($data['description'] ?? null);
                $menu->menu_price = Money::toDecimal((int) $data['price_kurus']);
                $menu->minimum_qty = (int) ($data['minimum_qty'] ?? 1);
                $menu->menu_priority = (int) ($data['priority'] ?? 0);
                $menu->menu_status = (bool) ($data['status'] ?? true);
                $menu->save();

                $this->syncCategories((int) $menu->menu_id, $categoryIds);

                $created = $menu;

                return ['data' => $this->freshPayload((int) $menu->menu_id)];
            },
        );

        if ($created !== null) {
            $this->stampAuditTarget($response, (int) $created->menu_id);

            // Sözleşme yaratma yanıtını `201` olarak tanımlıyor. Kuru
            // provada `200` kalıyor: yaratılmış bir kaynak yok.
            $response->setStatusCode(201);
        }

        return $response;
    }

    /**
     * `PATCH /{menu}` — kısmi güncelleme.
     *
     * `category_ids` gönderilirse TAM LİSTEDİR; pivot o listeye eşitlenir.
     * Fark göndermek, iki kategoriden birini kaldırmanın ayrı bir adını
     * gerektirirdi.
     */
    public function update(Request $request, int $menu): JsonResponse
    {
        $model = $this->findMenu($menu);

        $data = $request->validate([
            'name' => ['sometimes', 'string', 'min:2', 'max:128'],
            'description' => ['sometimes', 'nullable', 'string', 'max:5000'],
            'price_kurus' => ['sometimes', 'integer', 'min:0'],
            'minimum_qty' => ['sometimes', 'integer', 'min:1'],
            'priority' => ['sometimes', 'integer', 'min:0'],
            'status' => ['sometimes', 'boolean'],
            'category_ids' => ['sometimes', 'array'],
            'category_ids.*' => ['integer', 'exists:categories,category_id'],
        ]);

        $menuId = (int) $model->menu_id;

        $guard = function() use ($data, $menuId): void {
            /*
             * PAKET ÜRÜNÜNÜN FİYATI YAZILAMAZ. "Günün Menüsü" ürününün
             * kendi fiyatı 0,00'dır ve gerçek fiyat o günün paket
             * fiyatıdır (`DailyMenu::isPackageProduct`, `LineResolver`).
             * Buraya bir tutar yazmak, günün menüsünü yanlış fiyata
             * satmak demekti — ve fark ancak fatura kesilirken görülürdü.
             */
            if (array_key_exists('price_kurus', $data) && DailyMenu::isPackageProduct($menuId)) {
                throw ApiException::validationFailed(
                    'Bu ürün "Günün Menüsü" paketidir; fiyatı günün menüsünde belirlenir.',
                    ['field' => 'price_kurus', 'reason' => 'package_product'],
                );
            }
        };

        return $this->write(
            $request,
            'product.update',
            self::TARGET_MENU,
            $menuId,
            ['menu_id' => $menuId, 'changes' => $data, 'before' => $this->snapshot($model, $data)],
            would: static function() use ($guard, $menuId, $data): array {
                // KURU PROVA GERÇEKTEN DENETLER: yalnız isteği yankılasaydı
                // "prova geçti" diyen ekran gerçek gönderimde patlardı.
                $guard();

                return ['action' => 'product.update', 'menu_id' => $menuId, 'changes' => $data];
            },
            apply: function() use ($guard, $model, $menuId, $data): array {
                $guard();

                if (array_key_exists('name', $data)) {
                    $model->menu_name = $data['name'];
                }

                if (array_key_exists('description', $data)) {
                    $model->menu_description = $this->normalizeText($data['description']);
                }

                if (array_key_exists('price_kurus', $data)) {
                    $model->menu_price = Money::toDecimal((int) $data['price_kurus']);
                }

                if (array_key_exists('minimum_qty', $data)) {
                    $model->minimum_qty = (int) $data['minimum_qty'];
                }

                if (array_key_exists('priority', $data)) {
                    $model->menu_priority = (int) $data['priority'];
                }

                if (array_key_exists('status', $data)) {
                    $model->menu_status = (bool) $data['status'];
                }

                $model->save();

                if (array_key_exists('category_ids', $data)) {
                    $this->syncCategories($menuId, $this->uniqueIds($data['category_ids']));
                }

                return ['data' => $this->freshPayload($menuId)];
            },
        );
    }

    /**
     * `DELETE /{menu}` — YUMUŞAK kaldırma (`menu_status = 0`).
     *
     * SATIR SİLİNMEZ. Gerçek silme, geçmiş siparişlerin `order_menus`
     * satırlarındaki ürün bağını kırar ve "bu sipariş neydi" sorusunu
     * cevapsız bırakır.
     *
     * Geri açmak `PATCH {menu}` ile `status: true` yazmaktır; ayrı bir
     * "restore" ucu yoktur — iki yol olsaydı biri denetim izinde farklı
     * bir eylem adıyla görünürdü.
     */
    public function destroy(Request $request, int $menu): JsonResponse
    {
        $model = $this->findMenu($menu);
        $menuId = (int) $model->menu_id;

        $guard = function() use ($menuId): void {
            $dates = $this->publishedMenuDates($menuId);

            /*
             * YAYINDAKİ BİR MENÜNÜN KALEMİ SESSİZCE KALDIRILAMAZ: o menü
             * sepete eklenemez hâle gelir ve arıza müşteri tarafında,
             * "sipariş veremiyorum" olarak görünür. Yönetici önce günü
             * düzenler, sonra ürünü kaldırır.
             */
            if ($dates !== []) {
                throw new ApiException(
                    'CONFLICT',
                    'Ürün yayınlanmış bir günlük menüde kullanılıyor; önce menüden çıkarın.',
                    409,
                    ['conflict' => 'daily_menu', 'dates' => $dates],
                );
            }
        };

        return $this->write(
            $request,
            'product.delete',
            self::TARGET_MENU,
            $menuId,
            ['menu_id' => $menuId, 'name' => (string) $model->menu_name],
            would: static function() use ($guard, $menuId): array {
                $guard();

                return ['action' => 'product.delete', 'menu_id' => $menuId, 'status' => false];
            },
            apply: function() use ($guard, $model, $menuId): array {
                $guard();

                $model->menu_status = false;
                $model->save();

                return ['data' => [
                    'menu_id' => $menuId,
                    'status' => false,
                    'soft_deleted' => true,
                ]];
            },
        );
    }

    // ── Görsel ────────────────────────────────────────────────────────────

    /**
     * `PUT /{menu}/image` — görsel yükleme (JSON gövdesinde base64).
     *
     * Çözme ve denetim `ProductImageService::decode()` içinde ve
     * `write()`'tan ÖNCE koşuyor. Sebep sözleşmede: denetim satırının
     * `payload_json` alanı yalnız `{"mime": ..., "bytes": ...}` taşımalı ve
     * bu iki değer ancak içerik çözüldükten sonra biliniyor. Denetim
     * tablosunu megabaytlık base64 dizeleriyle doldurmak, izi okunamaz ve
     * tabloyu yönetilemez kılardı.
     *
     * Geçersiz bir görsel bu yüzden denetim satırı BIRAKMAZ — geçersiz
     * gerekçeyle aynı sınıfta: geçerli bir istek hiç oluşmadı.
     */
    public function setImage(Request $request, int $menu): JsonResponse
    {
        $model = $this->findMenu($menu);
        $menuId = (int) $model->menu_id;

        $data = $request->validate([
            // `actor`/`reason` `write()` içinde de doğrulanıyor; burada
            // tekrar edilmelerinin sebebi SIRA: gerekçesiz bir istek,
            // görsel çözülmeden önce reddedilmeli (00-genel §8).
            'actor' => ['required', 'string', 'min:2', 'max:120'],
            'reason' => ['required', 'string', 'min:'.self::REASON_MIN, 'max:'.self::REASON_MAX],
            'filename' => ['required', 'string', 'max:255'],
            'content_base64' => ['required', 'string'],
        ]);

        $decoded = $this->images->decode(
            (string) $data['content_base64'],
            (string) $data['filename'],
            $menuId,
        );

        return $this->write(
            $request,
            'product.image',
            self::TARGET_MENU,
            $menuId,
            // BASE64 İÇERİK YAZILMAZ.
            ['menu_id' => $menuId, 'mime' => $decoded['mime'], 'bytes' => $decoded['bytes']],
            would: static fn(): array => [
                'action' => 'product.image',
                'menu_id' => $menuId,
                'mime' => $decoded['mime'],
                'bytes' => $decoded['bytes'],
                // Kuru prova görseli ÇÖZDÜ ve DENETLEDİ, diske yazmadı.
                'valid' => true,
            ],
            apply: fn(): array => ['data' => [
                'menu_id' => $menuId,
                'image_url' => $this->images->attach($model, $decoded),
                'mime' => $decoded['mime'],
                'bytes' => $decoded['bytes'],
            ]],
        );
    }

    /**
     * `DELETE /{menu}/image` — görseli kaldırır.
     *
     * Görseli olmayan üründen görsel silmek HATA DEĞİLDİR: işlem sonuç
     * odaklıdır ve istenen son hâl zaten geçerli.
     */
    public function destroyImage(Request $request, int $menu): JsonResponse
    {
        $model = $this->findMenu($menu);
        $menuId = (int) $model->menu_id;

        return $this->write(
            $request,
            'product.image.delete',
            self::TARGET_MENU,
            $menuId,
            ['menu_id' => $menuId],
            would: static fn(): array => [
                'action' => 'product.image.delete',
                'menu_id' => $menuId,
                'image_url' => null,
            ],
            apply: function() use ($model, $menuId): array {
                $this->images->detach($model);

                return ['data' => ['menu_id' => $menuId, 'image_url' => null]];
            },
        );
    }

    // ── Kategoriler ───────────────────────────────────────────────────────

    /**
     * `GET /categories` — SAYFALANMAZ.
     *
     * Kategori sayısı onlarla ifade edilir ve ekran hepsini bir ağaç olarak
     * çizer; sayfalanmış bir ağaç, ikinci sayfadaki dalın kökünü
     * göstermezdi.
     */
    public function categories(): JsonResponse
    {
        $counts = DB::table('menu_categories')
            ->select('category_id', DB::raw('count(*) as total'))
            ->groupBy('category_id')
            ->pluck('total', 'category_id');

        $rows = Category::query()
            ->orderBy('priority')
            ->orderBy('category_id')
            ->get()
            ->map(fn(Category $category): array => $this->categoryPayload(
                $category,
                (int) ($counts[$category->category_id] ?? 0),
            ))
            ->all();

        return $this->json(['data' => $rows, 'server_time' => $this->serverTime()]);
    }

    /**
     * `POST /categories` — yeni kategori.
     *
     * `slug` GÖNDERİLMEZ: `permalink_slug` çekirdeğin `HasPermalink`
     * özelliğiyle addan üretilir. Elle slug yazdırmak, sitedeki adresin
     * yönetici yazım hatasına bağlı olması demekti.
     */
    public function storeCategory(Request $request): JsonResponse
    {
        $data = $request->validate([
            // `categories.name` sütunu `varchar(255)`; sınır sütundan
            // okundu, uydurulmadı.
            'name' => ['required', 'string', 'min:2', 'max:255'],
            'description' => ['sometimes', 'nullable', 'string', 'max:5000'],
            'parent_id' => ['sometimes', 'nullable', 'integer', 'exists:categories,category_id'],
            'priority' => ['sometimes', 'integer', 'min:0'],
            'status' => ['sometimes', 'boolean'],
        ]);

        $created = null;

        $response = $this->write(
            $request,
            'category.create',
            self::TARGET_CATEGORY,
            null,
            ['name' => $data['name'], 'parent_id' => $data['parent_id'] ?? null],
            would: static fn(): array => [
                'action' => 'category.create',
                'name' => $data['name'],
                'parent_id' => $data['parent_id'] ?? null,
            ],
            apply: function() use ($data, &$created): array {
                $category = new Category;
                $category->name = $data['name'];
                $category->description = $this->normalizeText($data['description'] ?? null);
                $category->parent_id = $this->normalizeParentId($data['parent_id'] ?? null);
                $category->priority = (int) ($data['priority'] ?? 0);
                $category->status = (bool) ($data['status'] ?? true);
                $category->save();

                $created = $category;

                return ['data' => $this->categoryPayload($category->refresh(), 0)];
            },
        );

        if ($created !== null) {
            $this->stampAuditTarget($response, (int) $created->category_id);
            $response->setStatusCode(201);
        }

        return $response;
    }

    /**
     * `PATCH /categories/{id}` — kısmi güncelleme.
     *
     * `DELETE` ucu YOKTUR ve olmayacaktır: kategori silmek altındaki
     * ürünleri kategorisiz bırakır ve site menüsünü sessizce boşaltır.
     * Gizlemek `status: false` yazmaktır.
     */
    public function updateCategory(Request $request, int $id): JsonResponse
    {
        $category = Category::find($id);

        if ($category === null) {
            throw ApiException::notFound('Kategori bulunamadı.');
        }

        $data = $request->validate([
            'name' => ['sometimes', 'string', 'min:2', 'max:255'],
            'description' => ['sometimes', 'nullable', 'string', 'max:5000'],
            'parent_id' => ['sometimes', 'nullable', 'integer', 'exists:categories,category_id'],
            'priority' => ['sometimes', 'integer', 'min:0'],
            'status' => ['sometimes', 'boolean'],
        ]);

        $categoryId = (int) $category->category_id;

        $guard = function() use ($data, $categoryId): void {
            if (array_key_exists('parent_id', $data)) {
                $this->assertNoCycle($categoryId, $this->normalizeParentId($data['parent_id']));
            }
        };

        return $this->write(
            $request,
            'category.update',
            self::TARGET_CATEGORY,
            $categoryId,
            ['category_id' => $categoryId, 'changes' => $data],
            would: static function() use ($guard, $categoryId, $data): array {
                $guard();

                return [
                    'action' => 'category.update',
                    'category_id' => $categoryId,
                    'changes' => $data,
                ];
            },
            apply: function() use ($guard, $category, $categoryId, $data): array {
                $guard();

                if (array_key_exists('name', $data)) {
                    $category->name = $data['name'];
                }

                if (array_key_exists('description', $data)) {
                    $category->description = $this->normalizeText($data['description']);
                }

                if (array_key_exists('parent_id', $data)) {
                    $category->parent_id = $this->normalizeParentId($data['parent_id']);
                }

                if (array_key_exists('priority', $data)) {
                    $category->priority = (int) $data['priority'];
                }

                if (array_key_exists('status', $data)) {
                    $category->status = (bool) $data['status'];
                }

                $category->save();

                $count = (int) DB::table('menu_categories')
                    ->where('category_id', $categoryId)
                    ->count();

                return ['data' => $this->categoryPayload($category->refresh(), $count)];
            },
        );
    }

    // ── Tükendi işareti ───────────────────────────────────────────────────

    /**
     * `POST /{menu}/sold-out` — bugün için tükendi işaretle.
     *
     * ZATEN İŞARETLİYSE `409` VERİLMEZ: `ok: true` döner ve gerekçe
     * güncellenir. İkinci bir gerekçe yazmak isteyen yöneticiyi hata
     * ekranına düşürmek anlamsız.
     *
     * `MenuAvailability::markSoldOut()` KULLANILMIYOR çünkü o metot
     * `insertOrIgnore` ile yazıyor ve var olan satırın gerekçesini
     * bilerek ezmiyor (mutfağın yazdığı ilk sebep korunsun diye). Bu uç
     * ise sözleşme gereği gerekçeyi güncellemek zorunda; iki davranış tek
     * metoda sığmıyor ve mutfak tarafının kararını değiştirmek bu
     * kulvarın dışı.
     */
    public function soldOut(Request $request, int $menu): JsonResponse
    {
        $model = $this->findMenu($menu);
        $menuId = (int) $model->menu_id;

        $data = $request->validate([
            'note' => ['sometimes', 'nullable', 'string', 'max:500'],
        ]);

        $today = BusinessTime::today();

        return $this->write(
            $request,
            'product.sold_out',
            self::TARGET_MENU,
            $menuId,
            array_filter([
                'menu_id' => $menuId,
                'sold_out_on' => $today,
                'note' => $this->normalizeText($data['note'] ?? null),
            ], static fn($value): bool => $value !== null),
            would: static fn(array $intent): array => [
                'action' => 'product.sold_out',
                'menu_id' => $menuId,
                'sold_out_on' => $today,
                'sold_out_reason' => $intent['reason'],
            ],
            apply: function(array $intent) use ($menuId, $today): array {
                $reason = $this->soldOutReason($intent['reason']);

                $exists = DB::table('veykemtu_menu_soldout')
                    ->where('menu_id', $menuId)
                    ->whereDate('sold_out_on', $today)
                    ->exists();

                if ($exists) {
                    /*
                     * YALNIZ GEREKÇE GÜNCELLENİR. `device_id` ve
                     * `created_at` korunuyor: işareti mutfak kasası
                     * koyduysa "kim, ne zaman" bilgisi onundur ve merkezden
                     * gelen bir gerekçe düzeltmesi o izi silmemeli. Kimin
                     * güncellediği denetim satırında duruyor.
                     */
                    DB::table('veykemtu_menu_soldout')
                        ->where('menu_id', $menuId)
                        ->whereDate('sold_out_on', $today)
                        ->update(['reason' => $reason]);
                } else {
                    DB::table('veykemtu_menu_soldout')->insert([
                        'menu_id' => $menuId,
                        'sold_out_on' => $today,
                        'reason' => $reason,
                        // Kasa yok: işaret Kontrol Merkezi'nden geldi.
                        'device_id' => null,
                        'created_by' => null,
                        'created_at' => BusinessTime::forStorage(BusinessTime::now()),
                    ]);
                }

                return ['data' => [
                    'menu_id' => $menuId,
                    'sold_out_today' => true,
                    'sold_out_on' => $today,
                    'sold_out_reason' => $reason,
                ]];
            },
        );
    }

    /**
     * `DELETE /{menu}/sold-out` — işareti kaldırır.
     *
     * İşaret yoksa `ok: true`, `sold_out_today: false`. Yalnız BUGÜNÜN
     * satırı siliniyor: geçmiş günlerin kaydı "hangi ürün hangi gün bitti"
     * sorusunun cevabıdır ve silinmemeli.
     */
    public function clearSoldOut(Request $request, int $menu): JsonResponse
    {
        $model = $this->findMenu($menu);
        $menuId = (int) $model->menu_id;

        return $this->write(
            $request,
            'product.sold_out.clear',
            self::TARGET_MENU,
            $menuId,
            ['menu_id' => $menuId, 'sold_out_on' => BusinessTime::today()],
            would: static fn(): array => [
                'action' => 'product.sold_out.clear',
                'menu_id' => $menuId,
                'sold_out_today' => false,
            ],
            apply: function() use ($menuId): array {
                $this->availability->clearSoldOut($menuId);

                return ['data' => [
                    'menu_id' => $menuId,
                    'sold_out_today' => false,
                    'sold_out_reason' => null,
                ]];
            },
        );
    }

    // ── Yardımcılar ───────────────────────────────────────────────────────

    /**
     * Ürünü bulur; yoksa sözleşmedeki 404'ü verir.
     *
     * `ApiException::notFound()` ŞART: Laravel'in kendi 404'ü `error`
     * alanını sözleşmenin biçiminde taşımıyor ve Kontrol Merkezi bu farkı
     * "uç yayında değil" ile "kayıt yok"u ayırmak için kullanıyor
     * (`00-genel.md` §7).
     */
    private function findMenu(int $menu, bool $withOptions = false): Menu
    {
        $query = Menu::query()->with('media');

        if ($withOptions) {
            // Bağıntı adları kurulu sürümden doğrulandı (B-02):
            // `MenuItemOption`'ın değerleri `menu_option_values`'tır.
            $query->with(['menu_options.option', 'menu_options.menu_option_values.option_value']);
        }

        $model = $query->find($menu);

        if ($model === null) {
            throw ApiException::notFound('Ürün bulunamadı.');
        }

        return $model;
    }

    /**
     * Sözleşmedeki `Product` gövdesi.
     *
     * @param  array<int|string, string|null>  $soldOut  menu_id => sebep
     * @param  list<int>  $categoryIds
     * @param  list<int>  $packageIds
     * @return array<string, mixed>
     */
    private function productPayload(
        Menu $menu,
        array $soldOut,
        array $categoryIds,
        array $packageIds,
        bool $withOptions,
    ): array {
        $menuId = (int) $menu->menu_id;
        $isSoldOut = array_key_exists($menuId, $soldOut);

        return [
            'menu_id' => $menuId,
            'name' => (string) $menu->menu_name,
            'description' => $this->normalizeText($menu->menu_description),
            // `Support\Money` kuruş ↔ TL arasındaki TEK geçit; dönüşümü
            // burada elle yapmak, bir yerde `round` unutulduğunda
            // toplamların kalemleri tutmamasıyla biterdi.
            'price_kurus' => Money::toKurus($menu->menu_price),
            'minimum_qty' => (int) $menu->minimum_qty,
            'priority' => (int) $menu->menu_priority,
            'status' => (bool) $menu->menu_status,
            'category_ids' => $categoryIds,
            'image_url' => $this->images->url($menu),
            'sold_out_today' => $isSoldOut,
            'sold_out_reason' => $isSoldOut ? $this->normalizeText($soldOut[$menuId]) : null,
            /*
             * UYARI ALANIDIR: "Günün Menüsü" paket ürününün kendi fiyatı
             * 0,00'dır. Panel bu ürünü listede işaretler ve fiyat alanını
             * düzenlemeye kapatır; fiyat yazmak günün menüsünü yanlış
             * tutara satardı.
             */
            'is_package_product' => in_array($menuId, $packageIds, true),
            'options' => $withOptions ? $this->options($menu) : [],
            'created_at' => self::ts($menu->created_at),
            'updated_at' => self::ts($menu->updated_at),
        ];
    }

    /**
     * Yazmadan sonra ürünü diskten TEKRAR okuyup sözleşme gövdesini üretir.
     *
     * @return array<string, mixed>
     */
    private function freshPayload(int $menuId): array
    {
        return $this->productPayload(
            $this->findMenu($menuId),
            $this->availability->soldOutReasons(),
            $this->categoryIdsFor([$menuId])[$menuId] ?? [],
            $this->packageMenuIds(),
            withOptions: false,
        );
    }

    /**
     * Ürün seçenekleri — SALT OKUNUR.
     *
     * `values[].id` = `menu_option_value_id`, yani sipariş revizyonundaki
     * `option_value_ids` alanına doğrudan konabilecek kimlik. Yalnız adı
     * döndürmek, seçeneğin kaydedilirken sessizce düşmesine yol açardı.
     *
     * Seçenek YAZAN bir uç yok: `menu_options`, `menu_option_values` ve
     * `options` üçlüsünü sözleşmeye taşımak gerekirdi. Düzenleme
     * TastyIgniter admin panelindedir.
     *
     * @return list<array<string, mixed>>
     */
    private function options(Menu $menu): array
    {
        $options = [];

        foreach ($menu->menu_options as $menuOption) {
            $option = $menuOption->option;

            if ($option === null) {
                continue;
            }

            $values = [];

            foreach ($menuOption->menu_option_values as $menuOptionValue) {
                $values[] = [
                    'id' => (int) $menuOptionValue->menu_option_value_id,
                    'name' => (string) ($menuOptionValue->option_value->value ?? ''),
                    'price_delta_kurus' => Money::toKurus($menuOptionValue->price ?? 0),
                ];
            }

            $options[] = [
                'id' => (int) $menuOption->menu_option_id,
                'name' => (string) $option->option_name,
                'type' => (string) $option->display_type,
                'required' => (bool) $menuOption->is_required,
                'values' => $values,
            ];
        }

        return $options;
    }

    /** @return array<string, mixed> */
    private function categoryPayload(Category $category, int $menuCount): array
    {
        return [
            'category_id' => (int) $category->category_id,
            'name' => (string) $category->name,
            'description' => $this->normalizeText($category->description),
            'parent_id' => $this->normalizeParentId($category->parent_id),
            'priority' => (int) $category->priority,
            'status' => (bool) $category->status,
            'slug' => $this->normalizeText($category->permalink_slug),
            'menu_count' => $menuCount,
        ];
    }

    /**
     * Sayfadaki ürünlerin kategori kimlikleri — TEK SORGU.
     *
     * Ürün başına ayrı sorgu, yirmi beş satırlık bir sayfada yirmi beş
     * sorgu demekti.
     *
     * @param  list<int>  $menuIds
     * @return array<int, list<int>>
     */
    private function categoryIdsFor(array $menuIds): array
    {
        if ($menuIds === []) {
            return [];
        }

        $map = [];

        foreach (DB::table('menu_categories')->whereIn('menu_id', $menuIds)->get() as $row) {
            $map[(int) $row->menu_id][] = (int) $row->category_id;
        }

        foreach ($map as $menuId => $ids) {
            sort($ids);
            $map[$menuId] = $ids;
        }

        return $map;
    }

    /**
     * Ürünün kategori bağlarını verilen listeye EŞİTLER.
     *
     * Pivot doğrudan yazılıyor (`DemoMenuCommand` ile aynı kalıp): tablo
     * yalnız iki kolon taşıyor ve `sync()` yerine açık yazma, hangi
     * satırın silindiğini okunur kılıyor.
     *
     * @param  list<int>  $categoryIds
     */
    private function syncCategories(int $menuId, array $categoryIds): void
    {
        $stale = DB::table('menu_categories')->where('menu_id', $menuId);

        if ($categoryIds !== []) {
            $stale->whereNotIn('category_id', $categoryIds);
        }

        $stale->delete();

        foreach ($categoryIds as $categoryId) {
            DB::table('menu_categories')->updateOrInsert([
                'menu_id' => $menuId,
                'category_id' => $categoryId,
            ]);
        }
    }

    /**
     * Herhangi bir vitrinin paket ürünü olan kimlikler.
     *
     * `DailyMenu::isPackageProduct()` TEK ürün için tasarlanmış ve her
     * çağrıda `location_options` tablosunu okuyor; listede ürün başına
     * çağırmak sayfa başına yirmi beş sorgu ederdi. Anahtar ve çözme
     * biçimi o metottan birebir alındı, ikinci bir tanım uydurulmadı.
     *
     * @return list<int>
     */
    private function packageMenuIds(): array
    {
        $ids = [];

        foreach (DB::table('location_options')
            ->where('item', DailyMenu::PACKAGE_OPTION_KEY)
            ->pluck('value') as $raw) {
            $menuId = (int) json_decode((string) $raw, true);

            if ($menuId > 0) {
                $ids[] = $menuId;
            }
        }

        return array_values(array_unique($ids));
    }

    /**
     * Ürünün kullanıldığı, BUGÜN VE SONRASINA yayınlanmış menü günleri.
     *
     * GEÇMİŞ GÜNLER SAYILMIYOR ve bu bilinçli: üç ay önce yayınlanmış bir
     * menüde geçen ürün, aksi hâlde bir daha asla satıştan kaldırılamazdı.
     * Engellemenin amacı satılabilir durumdaki bir günü korumak; geçmiş
     * bir gün zaten satılamıyor.
     *
     * @return list<string>
     */
    private function publishedMenuDates(int $menuId): array
    {
        return DB::table('veykemtu_daily_menu_items as i')
            ->join('veykemtu_daily_menus as m', 'm.id', '=', 'i.daily_menu_id')
            ->where('i.menu_id', $menuId)
            ->where('m.status', DailyMenu::STATUS_PUBLISHED)
            ->whereDate('m.menu_date', '>=', BusinessTime::today())
            ->orderBy('m.menu_date')
            ->pluck('m.menu_date')
            ->map(static fn($value): string => substr((string) $value, 0, 10))
            ->unique()
            ->values()
            ->all();
    }

    /**
     * Kategori ağacında çevrim var mı?
     *
     * ÇEVRİM DENETİMİ `parent_id` ZİNCİRİNİ YÜRÜYOR, `nest_left`/
     * `nest_right` OKUMUYOR: iç içe küme sütunları zaten bozulmuşsa
     * (elle düzeltme, yarım kalan bir taşıma) onlara bakan bir denetim
     * bozukluğu onaylardı. `parent_id` tek gerçektir.
     *
     * Çekirdek `NestedTree` böyle bir kaydı kabul edip ağacı bozar; ağaç
     * bozulunca site menüsü boş çizilir ve sebebi görünmez.
     */
    private function assertNoCycle(int $categoryId, ?int $parentId): void
    {
        $cursor = $parentId;
        $seen = [];

        while ($cursor !== null) {
            if ($cursor === $categoryId) {
                throw ApiException::validationFailed(
                    'Kategori kendisinin ya da kendi alt dalının altına taşınamaz.',
                    ['field' => 'parent_id', 'reason' => 'cycle'],
                );
            }

            // Bozuk veride sonsuz döngüye girmemek için: aynı düğüme ikinci
            // kez uğradıysak zincir zaten kendi içinde kapalı.
            if (isset($seen[$cursor])) {
                return;
            }

            $seen[$cursor] = true;

            $cursor = $this->normalizeParentId(
                DB::table('categories')->where('category_id', $cursor)->value('parent_id'),
            );
        }
    }

    /**
     * Denetim satırının hedefini yazma UYGULANDIKTAN sonra tamamlar.
     *
     * `ControlController::write()` satırı işlemden önce açıyor — ki yarıda
     * kalan bir yazma da iz bıraksın — ve yeni kaydın kimliği o an henüz
     * yok. Sözleşme (`00-genel.md` §8.1) `target_id`'nin yeni kimlik
     * olmasını istiyor; kabuğu değiştirmek yerine satır burada
     * tamamlanıyor.
     */
    private function stampAuditTarget(JsonResponse $response, int $targetId): void
    {
        /** @var array<string, mixed> $body */
        $body = $response->getData(true);

        $auditId = (int) ($body['audit_id'] ?? 0);

        if ($auditId > 0) {
            ControlAudit::whereKey($auditId)->update(['target_id' => $targetId]);
        }
    }

    /**
     * Değişen alanların ÖNCEKİ değerleri — denetim izi için.
     *
     * "Eski ve yeni değer" (`00-genel.md` §8.2) olmadan bir güncelleme
     * satırı "fiyat değişti" der ama "neyden neye" demez.
     *
     * @param  array<string, mixed>  $changes
     * @return array<string, mixed>
     */
    private function snapshot(Menu $menu, array $changes): array
    {
        $before = [];

        foreach (array_keys($changes) as $field) {
            $before[$field] = match ($field) {
                'name' => (string) $menu->menu_name,
                'description' => $this->normalizeText($menu->menu_description),
                'price_kurus' => Money::toKurus($menu->menu_price),
                'minimum_qty' => (int) $menu->minimum_qty,
                'priority' => (int) $menu->menu_priority,
                'status' => (bool) $menu->menu_status,
                'category_ids' => $this->categoryIdsFor([(int) $menu->menu_id])[(int) $menu->menu_id] ?? [],
                default => null,
            };
        }

        return $before;
    }

    /**
     * `LIKE` terimi — joker karakterler KAÇIRILIR.
     *
     * Kaçırılmasaydı `%` yazan bir arama bütün tabloyu tarar ve `_` yazan
     * bir arama beklenmedik satırlar getirirdi; kullanıcı bunu bir arıza
     * olarak görürdü.
     */
    private function likeTerm(string $raw): string
    {
        return '%'.str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], trim($raw)).'%';
    }

    /** Boş metni `null`'a indirger — "" ile `null` iki ayrı şey gibi görünmesin. */
    private function normalizeText(mixed $value): ?string
    {
        if ($value === null) {
            return null;
        }

        $text = trim((string) $value);

        return $text === '' ? null : $text;
    }

    /** Eski kayıtlarda `parent_id` 0 olabiliyor; kök demek. */
    private function normalizeParentId(mixed $value): ?int
    {
        return is_numeric($value) && (int) $value > 0 ? (int) $value : null;
    }

    /**
     * Mutfak ekranında görünecek gerekçe.
     *
     * `veykemtu_menu_soldout.reason` sütunu 160 karakter; ortak gerekçe
     * sınırı 500. Taşan metin burada KIRPILIYOR, istek reddedilmiyor:
     * gerekçenin tamamı zaten denetim satırında duruyor ve hiçbir şey
     * kaybolmuyor. Reddetmek, sözleşmede yazmayan bir 422 üretirdi;
     * kırpmamak ise veritabanı hatasını 500 olarak döndürürdü.
     */
    private function soldOutReason(string $reason): string
    {
        return mb_substr(trim($reason), 0, self::SOLD_OUT_REASON_MAX);
    }

    /**
     * @param  array<int, mixed>  $ids
     * @return list<int>
     */
    private function uniqueIds(array $ids): array
    {
        $clean = array_values(array_unique(array_map(intval(...), $ids)));

        sort($clean);

        return $clean;
    }
}
