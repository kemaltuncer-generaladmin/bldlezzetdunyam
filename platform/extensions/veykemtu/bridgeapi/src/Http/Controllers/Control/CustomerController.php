<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers\Control;

use Igniter\User\Models\Address;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Veykemtu\BridgeApi\Exceptions\ApiException;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Models\ControlAudit;
use Veykemtu\BridgeApi\Models\Subscription;
use Veykemtu\BridgeApi\Models\SubscriptionPayment;
use Veykemtu\BridgeApi\Services\OrderStatusTransition;
use Veykemtu\BridgeApi\Services\StructuredAddress;
use Veykemtu\BridgeApi\Support\BusinessTime;
use Veykemtu\BridgeApi\Support\Money;

/**
 * Kontrol Merkezi — müşteriler (`docs/control/customers.md`).
 *
 * ## OKUMALAR DA DENETLENİR — bu alanın ayırt edici kuralı
 *
 * Diğer bütün alanlarda yalnız YAZMALAR denetim izine düşer; burada
 * okumalar da düşer (`00-genel.md` §9). Sebep, bu uçların sistemdeki en
 * geniş kişisel veri yüzeyi olması: ad, telefon, e-posta, kurum bilgisi,
 * adres defteri ve sipariş geçmişi tek ekranda birleşiyor. Sızıntı çoğu
 * zaman bir yazma değil bir OKUMADIR; yazma izi tek başına "kim, ne
 * zaman, kimin kaydını açtı" sorusuna cevap vermiyor.
 *
 * Satırı `ControlAudit::readAudit()` yazıyor — YENİSİ YAZILMADI, çünkü
 * `action` dizesi (`customer.read`) hem burada hem denetim ekranının
 * süzgecinde geçiyor ve elle yazılan ikinci bir kopya harf farkıyla
 * ayrıştığında KVKK erişimleri ekranda hiç görünmezdi.
 *
 * DENETİM SATIRI VERİ ELDE EDİLDİKTEN SONRA, YANIT DÖNMEDEN ÖNCE
 * AÇILIYOR — yazma kabuğunun tersine. `write()` satırı işlemden önce
 * açar çünkü "denedim ve olmadı" soruşturulması gereken bir hâldir;
 * okumada öyle bir hâl yok: doğrulaması düşen ya da `404` alan bir istek
 * hiçbir kişisel veri göstermedi. Satırı önce açsaydık, var olmayan
 * kimliklere atılan istekler izi anlamsız satırlarla doldurup içindeki
 * gerçek erişimi görünmez kılardı — yani sözleşmenin yoklama yasağıyla
 * (`00-genel.md` §9) engellemek istediği şeyin ta kendisini üretirdi.
 *
 * ## SİLME YOK
 *
 * Hesap kapatmak veri silmez ve silme ucu yoktur. Geçmiş siparişlerin
 * müşterisi olmayan kayıtlara dönüşmesi, muhasebe ve denetim açısından
 * geri alınamaz bir kayıptır.
 *
 * ## PAROLA VE E-POSTA YAZILMAZ
 *
 * Parola hiçbir uçta geçmez: ne okunur, ne yazılır, ne sıfırlanır. Bir
 * yönetim panelinden parola yazabilmek, panele erişen herkesin her
 * müşterinin hesabına girebilmesi demektir. E-posta giriş kimliğidir;
 * değiştirmek hesabı devretmektir ve doğrulama akışı gerektirir.
 * İkisi de `update()` içinde SESSİZCE YOK SAYILMAZ, isteği tümüyle
 * reddeder — e-posta değiştirdiğini sanan bir yöneticiye "başarılı"
 * demek, yok saymanın en pahalı hâlidir.
 *
 * ## SİPARİŞ VE ABONELİK SATIRLARI BURADA ÜRETİLMEZ
 *
 * `orders()` ve `subscriptions()` kardeş denetleyicilere devrediyor.
 * Sözleşme "gövde `orders.md` → `GET /` ile aynı satır biçimini
 * kullanır" diyor ve gerekçesini de yazıyor: iki farklı sipariş şekli,
 * panelin iki ayrı tablo bileşeni yazması demekti. İkinci bir üretici
 * yazsaydık, iade/fatura/ödeme durumu gibi türetilmiş alanlar bir gün
 * ayrışır ve müşteri kartı sipariş ekranından farklı bir gerçeklik
 * gösterirdi.
 */
class CustomerController extends ControlController
{
    /** Arama teriminin en kısa hâli — tek harf bütün tabloyu tarardı. */
    private const int Q_MIN = 2;

    /**
     * Yazılabilir alanlar → veritabanı sütunu.
     *
     * LİSTE KAPALI BİR SÖZLEŞMEDİR: burada olmayan her alan reddedilir.
     * `email`, `password`, `status`, `account_type` ve `is_activated`
     * bilerek yok; gerekçeleri sınıf yorumunda ve `customers.md` şema
     * tablosunda.
     *
     * @var array<string, string>
     */
    private const array COLUMNS = [
        'first_name' => 'first_name',
        'last_name' => 'last_name',
        'telephone' => 'telephone',
        'org_name' => 'bld_org_name',
        'tax_office' => 'bld_tax_office',
        'tax_no' => 'bld_tax_no',
        'contact_person' => 'bld_contact_person',
        'org_phone' => 'bld_org_phone',
    ];

    /**
     * Sütun genişlikleri — göçtekiyle birebir.
     *
     * Doğrulamayı sütundan geniş bırakmak, kabul edilen bir değerin
     * veritabanında SESSİZCE kırpılması demekti (`StructuredAddress`
     * ile aynı gerekçe).
     *
     * @var array<string, int>
     */
    private const array MAX_LENGTHS = [
        'first_name' => 255,
        'last_name' => 255,
        'telephone' => 32,
        'org_name' => 160,
        'tax_office' => 120,
        'tax_no' => 32,
        'contact_person' => 120,
        'org_phone' => 32,
    ];

    /** Boş bırakılamayan alanlar — müşterinin adı sistemde her yerde görünüyor. */
    private const array NAME_FIELDS = ['first_name', 'last_name'];

    /** Telefon biçimi denetlenen alanlar. */
    private const array PHONE_FIELDS = ['telephone', 'org_phone'];

    /** Yazma kabuğunun kendi alanları; "bilinmeyen alan" sayılmazlar. */
    private const array ENVELOPE = ['actor', 'reason', 'dry_run'];

    public function __construct(
        /*
         * KARDEŞ DENETLEYİCİLER, SERVİS DEĞİL. Sipariş ve abonelik satırı
         * üreten kod o sınıfların `private` yardımcılarında duruyor ve
         * oradan bir servise çıkarmak iki dosyayı birden değiştirmeyi
         * gerektirirdi — bu kulvarın dışı. Devretmek, satır biçiminin tek
         * kaynakta kalmasını sağlayan en küçük çözüm.
         *
         * ADLAR `$orders` / `$subscriptions` DEĞİL: bu sınıfta aynı adı
         * taşıyan iki uç metodu var ve `$this->orders` ile
         * `$this->orders()` yan yana duran iki farklı şey olurdu
         * (`SubscriptionController::$contractService` ile aynı gerekçe).
         */
        private readonly OrderController $orderScreen,
        private readonly SubscriptionController $subscriptionScreen,
    ) {}

    // ── GET / ─────────────────────────────────────────────────────────────

    /**
     * Müşteri arama — sayfalı.
     *
     * SAYFALAMA `page` / `per_page` (tavan 100). `limit`/`offset`
     * sözleşmede yok (`00-genel.md` §5); tek istisnası yayınlanmış
     * `kds/print-jobs` ucudur ve bu uç o değil.
     *
     * SÜZGEÇSİZ İSTEK SERBEST ve ilk sayfayı döndürür. Listeyi tamamen
     * kapatmak "kaç müşterimiz var" gibi meşru bir soruyu cevapsız
     * bırakırdı; asıl koruma denetim izidir.
     *
     * LİSTE MASKELENMEZ. Yönetici müşteriyi telefonundan tanır; maskeli
     * bir listede doğru kaydı seçemez ve hepsini tek tek açmak zorunda
     * kalır — yani her arama bir düzine denetim satırı doğururdu.
     * Maskeleme burada gizliliği artırmaz, izi bozar.
     */
    public function index(Request $request): JsonResponse
    {
        $actor = $this->actor($request);
        $this->validateSearch($request);

        $query = ApiCustomer::query();

        if ($request->filled('q')) {
            $term = self::like(trim($this->queryText($request, 'q')));

            $query->where(static function (Builder $inner) use ($term): void {
                // KURUM ADI DA ARANIYOR: bu bir catering sistemi ve
                // kayıtların çoğu bir şirkete ait; yönetici "Acme" diye
                // arıyor, "Mehmet" diye değil.
                foreach (['first_name', 'last_name', 'telephone', 'email', 'bld_org_name'] as $column) {
                    $inner->orWhere($column, 'like', $term);
                }
            });
        }

        $status = $this->queryText($request, 'status', 'all');

        if ($status === 'active') {
            $query->where('status', true);
        } elseif ($status === 'disabled') {
            // `!= true` — sütun `tinyint(1)` ve eski kayıtlarda `0`;
            // `= false` yazmak sürücüye göre `NULL` satırları eleyebilirdi.
            $query->where('status', '!=', true);
        }

        if ($request->filled('has_subscription')) {
            $exists = DB::table('veykemtu_subscriptions')
                ->select(DB::raw('1'))
                ->whereColumn('veykemtu_subscriptions.customer_id', 'customers.customer_id');

            $request->boolean('has_subscription')
                ? $query->whereExists($exists)
                : $query->whereNotExists($exists);
        }

        // TOPLAM SIRALAMADAN ÖNCE sayılıyor: `last_order` sıralaması bir
        // alt sorgu ve sayım sorgusuna taşınması gereksiz bir tarama olurdu.
        $total = (int) $query->clone()->count();

        $this->applySort($query, $request);

        $page = max(1, (int) $request->query('page', '1'));
        $perPage = min(100, max(1, (int) $request->query('per_page', '25')));

        $rows = $query->forPage($page, $perPage)->get();
        $ids = $rows->pluck('customer_id')->map(intval(...))->values()->all();

        $orderStats = $this->orderStats($ids);
        $subscriptionCounts = $this->subscriptionCounts($ids);

        $body = [
            'data' => $rows->map(fn(ApiCustomer $row): array => [
                'customer_id' => (int) $row->customer_id,
                'first_name' => (string) $row->first_name,
                'last_name' => (string) $row->last_name,
                'email' => (string) $row->email,
                'telephone' => self::nullText($row->telephone),
                'status' => (bool) $row->status,
                'is_activated' => (bool) $row->is_activated,
                'account_type' => self::accountType($row),
                'org_name' => self::nullText($row->bld_org_name),
                'order_count' => $orderStats[(int) $row->customer_id]['count'] ?? 0,
                'last_order_at' => $orderStats[(int) $row->customer_id]['last_at'] ?? null,
                'subscription_count' => $subscriptionCounts[(int) $row->customer_id] ?? 0,
                'created_at' => self::ts($row->created_at),
            ])->values()->all(),
            'meta' => [
                'page' => $page,
                'per_page' => $perPage,
                'total' => $total,
                // Toplam sıfırken bile en az bir sayfa vardır; `0` dönmek
                // istemciye "sayfa yok" dedirtip boş durumu çizdirmezdi.
                'last_page' => max(1, (int) ceil($total / $perPage)),
            ],
            'server_time' => $this->serverTime(),
        ];

        $this->readAudit($request, $actor, null);

        return $this->json($body);
    }

    // ── GET /{id} ─────────────────────────────────────────────────────────

    /**
     * Tek müşteri — `stats` BURADA döner, ayrı bir uçta değil.
     *
     * Müşteri kartını açan yönetici zaten bu sayıları görmek istiyor ve
     * ayrı bir çağrı İKİNCİ BİR DENETİM SATIRI yazardı; iz, tek bir
     * bakışı iki erişim gibi gösterirdi.
     */
    public function show(Request $request, int $customer): JsonResponse
    {
        $actor = $this->actor($request);
        $row = $this->find($customer);

        $body = [
            'data' => [
                ...$this->detail($row),
                'stats' => $this->stats((int) $row->customer_id),
            ],
            'server_time' => $this->serverTime(),
        ];

        $this->readAudit($request, $actor, (int) $row->customer_id);

        return $this->json($body);
    }

    // ── PATCH /{id} ───────────────────────────────────────────────────────

    /**
     * İletişim bilgileri + serbest metin kurum etiketleri.
     *
     * KISMİ YAZAR: gönderilmeyen alan korunur. Gönderilen ama listede
     * olmayan alan isteği TÜMÜYLE düşürür (`read_only`).
     *
     * `account_type` YAZILMAZ. Kurumsal sipariş kapısı (`CustomerGate`)
     * kalktığı için bu alan artık bir yetki belirlemiyor, yalnız geçmiş
     * kayıtların etiketi; yazılabilir yapmak, kalkmış bir kapının
     * anahtarını panelde tutmak olurdu.
     */
    public function update(Request $request, int $customer): JsonResponse
    {
        $row = $this->find($customer);
        $values = $this->validateUpdate($request);
        $changes = $this->changes($row, $values);
        $changed = array_map(static fn(array $c): string => $c['field'], $changes);

        return $this->write(
            $request,
            'customer.update',
            ControlAudit::TARGET_CUSTOMER,
            (int) $row->customer_id,
            /*
             * ESKİ VE YENİ DEĞER BİRLİKTE, AMA TELEFONLAR MASKELİ. Denetim
             * izi "ne değişti" sorusuna cevap vermeli, kişisel verinin
             * ikinci bir kopyasını tutmamalı — yoksa veriyi korumak için
             * tutulan defter, koruduğu veriyi çoğaltırdı.
             */
            ['changes' => $this->maskChanges($changes)],
            static fn(): array => [
                'action' => 'customer.update',
                'customer_id' => (int) $row->customer_id,
                // KURU PROVA DEĞERLERİ YANKILAMAZ: panel gönderdiği gövdeyi
                // zaten biliyor, tekrarı yalnız kişisel veriyi bir kez daha
                // telde taşırdı.
                'changed' => $changed,
            ],
            function () use ($row, $values, $changed): array {
                foreach ($values as $field => $value) {
                    $row->{self::COLUMNS[$field]} = $value;
                }

                $row->save();

                return [
                    // `stats` YOK: kart zaten açıkken düzenleniyor ve dört
                    // ek toplam sorgusu, değişmeyen sayıları yeniden
                    // hesaplamak olurdu.
                    'data' => $this->detail($row),
                    'changed' => $changed,
                ];
            },
        );
    }

    // ── GET /{id}/orders ──────────────────────────────────────────────────

    /**
     * Müşterinin sipariş geçmişi — sayfalı.
     *
     * SATIRLARI `Control\OrderController::panelIndex()` ÜRETİYOR. İade,
     * fatura numarası ve ödeme durumu gibi türetilmiş alanlar orada tek
     * toplu sorguyla toplanıyor; ikinci bir üretici yazmak, aynı siparişin
     * iki ekranda iki farklı ödeme durumu göstermesine giden yol olurdu.
     *
     * PENCERE AÇIKÇA GENİŞLETİLİYOR. O uç süzgeçsiz istekte SON 7 GÜNE
     * düşüyor (liste ekranı yoklanıyor, sınırsız varsayılan her yoklamada
     * bütün tabloyu saydırırdı). Müşteri kartında soru başka: "bu müşteri
     * bize ne zaman ne sipariş etti". Bu yüzden `from`/`to` verilmediyse
     * müşterinin kendi ilk ve son servis günü konuluyor — sabit bir
     * "çok eski" tarih yazmak, bir gün eskiyecek bir sayı gömmek olurdu.
     */
    public function orders(Request $request, int $customer): JsonResponse
    {
        $actor = $this->actor($request);
        $row = $this->find($customer);
        $id = (int) $row->customer_id;

        $response = $this->orderScreen->panelIndex(
            $this->forward($request, ['customer_id' => $id, ...$this->orderWindow($request, $id)]),
        );

        $this->readAudit($request, $actor, $id);

        return $response;
    }

    // ── GET /{id}/subscriptions ───────────────────────────────────────────

    /**
     * Müşterinin abonelikleri — SAYFALANMAZ.
     *
     * Bir müşterinin abonelik sayısı tek hanelidir; sayfalayıcı çizmek
     * için `meta` yollamak, istemciye olmayan bir denetim çizdirirdi
     * (`00-genel.md` §5). Kardeş uç sayfalı olduğu için tavanı (100) bir
     * kez isteyip `meta`yı SOYUYORUZ.
     */
    public function subscriptions(Request $request, int $customer): JsonResponse
    {
        $actor = $this->actor($request);
        $row = $this->find($customer);
        $id = (int) $row->customer_id;

        $inner = $this->subscriptionScreen->index($this->forward($request, [
            'customer_id' => $id,
            'page' => 1,
            'per_page' => 100,
        ]));

        /** @var array<string, mixed> $payload */
        $payload = $inner->getData(true);

        $body = [
            'data' => $payload['data'] ?? [],
            'server_time' => $this->serverTime(),
        ];

        $this->readAudit($request, $actor, $id);

        return $this->json($body);
    }

    // ── GET /{id}/addresses ───────────────────────────────────────────────

    /**
     * Adres defteri — SALT OKUNUR.
     *
     * Adres yazan bir uç yok: adres siparişe KOPYALANIYOR, bağlanmıyor
     * (`AddressController` sınıf yorumu) ve defteri panelden düzenlemek
     * geçmiş siparişlerin adresini değiştirmez — yönetici değiştirdiğini
     * sanırdı. Adresi müşteri kendi uygulamasından yönetir.
     *
     * YALNIZ DEFTER SATIRLARI (`bld_is_saved`). Aynı tabloda her siparişin
     * adres anlık görüntüsü de duruyor; süzgeç olmasaydı defter, yüz
     * siparişlik bir müşteride yüz bir satır gösterirdi.
     */
    public function addresses(Request $request, int $customer): JsonResponse
    {
        $actor = $this->actor($request);
        $row = $this->find($customer);
        $id = (int) $row->customer_id;

        $rows = Address::query()
            ->where('customer_id', $id)
            ->where('bld_is_saved', true)
            ->orderByDesc('bld_is_default')
            ->orderByDesc('address_id')
            ->get();

        $body = [
            'data' => $rows->map(static fn(Address $address): array => [
                'address_id' => (int) $address->address_id,
                'label' => self::nullText($address->bld_label),
                'line_1' => (string) $address->address_1,
                'line_2' => self::nullText($address->address_2),
                'city' => self::nullText($address->city),
                'district' => self::nullText($address->state),
                'neighbourhood' => StructuredAddress::read($address)['neighbourhood'],
                'postcode' => self::nullText($address->postcode),
                // Koordinat ÇİFT olarak anlamlı: yarısı dolu bir kayıtta
                // istemci "koordinat var" sanıp iğneyi ekvatora koyardı.
                'latitude' => self::coordinate($address->bld_latitude, $address->bld_longitude),
                'longitude' => self::coordinate($address->bld_longitude, $address->bld_latitude),
                'is_default' => (bool) $address->bld_is_default,
            ])->values()->all(),
            'server_time' => $this->serverTime(),
        ];

        $this->readAudit($request, $actor, $id);

        return $this->json($body);
    }

    // ── POST /{id}/disable · POST /{id}/enable ────────────────────────────

    public function disable(Request $request, int $customer): JsonResponse
    {
        return $this->setStatus($request, $customer, false);
    }

    public function enable(Request $request, int $customer): JsonResponse
    {
        return $this->setStatus($request, $customer, true);
    }

    /**
     * `customers.status` yazar — SİLMEZ.
     *
     * ZATEN KAPALI/AÇIK OLAN HESAP `409` ALMAZ. Yönetici hesabın kapalı
     * olmasını istedi ve hesap kapalı; istediği durum gerçekleşmiş
     * olduğu hâlde hata görmek, ekranı iki kez tıklattırırdı.
     *
     * AKTİF ABONELİK ENGEL DEĞİL, UYARIDIR. Abonelik üretimi hesaba
     * değil aboneliğe bağlı; hesap kapansa da gece işi sipariş üretmeye
     * devam eder ve yönetici bunu BİLMELİ. Engelleseydik, borcu olan bir
     * müşterinin hesabını kapatmak imkânsız hâle gelirdi.
     */
    private function setStatus(Request $request, int $customer, bool $status): JsonResponse
    {
        $row = $this->find($customer);
        $id = (int) $row->customer_id;
        $warnings = $status ? [] : $this->activeSubscriptionWarnings($id);

        return $this->write(
            $request,
            $status ? 'customer.enable' : 'customer.disable',
            ControlAudit::TARGET_CUSTOMER,
            $id,
            ['status_from' => (bool) $row->status, 'status_to' => $status],
            static fn(): array => self::statusBody([
                'action' => $status ? 'customer.enable' : 'customer.disable',
                'customer_id' => $id,
                'status' => $status,
            ], $warnings),
            function () use ($row, $id, $status, $warnings): array {
                $row->status = $status;
                $row->save();

                return self::statusBody(
                    ['data' => ['customer_id' => $id, 'status' => $status]],
                    $warnings,
                );
            },
        );
    }

    // ── KVKK okuma izi ────────────────────────────────────────────────────

    /**
     * `actor` sorgu parametresi — HER `GET` İÇİN ZORUNLU.
     *
     * Yazma uçlarında gövdede istenen alan burada sorgu dizesinde
     * taşınıyor ve bu yüzden İMZAYA GİRMİYOR (kanonik dize sorguyu
     * dışlıyor). Sınır bilinçli ve `00-genel.md` §9'da yazılı: kanonik
     * dizeyi değiştirmek yayınlanmış K-21 uçlarını kırardı, `actor` ise
     * yazma uçlarında da serbest metin — imza yalnız isteğin Kontrol
     * Merkezi'nden geldiğini kanıtlıyor.
     */
    private function actor(Request $request): string
    {
        $actor = trim($this->queryText($request, 'actor'));
        $length = mb_strlen($actor);

        if ($length < 2 || $length > 120) {
            throw ApiException::validationFailed(
                'Kişisel veri görüntülemek için `actor` sorgu parametresi zorunlu (2-120 karakter).',
                ['field' => 'actor'],
            );
        }

        return $actor;
    }

    /**
     * Okuma denetim satırını açar.
     *
     * `payload_json` YALNIZ SÜZGEÇLERİ TAŞIR; dönen kayıtlar yazılmaz.
     * `actor` süzgeç değil kimlik alanıdır, yüke girmez — orada tekrarı
     * `actor` sütununu ikinci kez yazmak olurdu.
     */
    private function readAudit(Request $request, string $actor, ?int $customerId): void
    {
        $filters = $request->query();
        unset($filters['actor']);

        // Sayfa numaraları SAYI olarak yazılıyor: denetim ekranı süzgeci
        // olduğu gibi gösteriyor ve `"page": "2"` ile `"page": 2`, aynı
        // erişimi iki farklı süzgeçmiş gibi okutur.
        foreach (['page', 'per_page'] as $numeric) {
            if (isset($filters[$numeric])) {
                $filters[$numeric] = (int) $filters[$numeric];
            }
        }

        ControlAudit::readAudit($actor, $request->getPathInfo(), $customerId, $filters);
    }

    // ── Arama yardımcıları ────────────────────────────────────────────────

    /**
     * Sorgu değerini metin olarak okur.
     *
     * `?status[]=active` gibi bir istekte `(string)` dönüşümü PHP uyarısı
     * üretip 500'e düşerdi; sözleşmedeki doğru cevap 422 ve bu uçlarda
     * kapı `actor`'dan geçtiği için ayrım önemli — kimlik alanının
     * biçimsizliği "sunucu hatası" gibi görünmemeli.
     */
    private function queryText(Request $request, string $field, string $default = ''): string
    {
        $value = $request->query($field, $default);

        if (!is_string($value)) {
            throw ApiException::validationFailed(
                '`'.$field.'` tek bir metin olmalı.',
                ['field' => $field],
            );
        }

        return $value;
    }

    private function validateSearch(Request $request): void
    {
        if (
            $request->filled('q')
            && mb_strlen(trim($this->queryText($request, 'q'))) < self::Q_MIN
        ) {
            // Tek harflik bir arama bütün müşteri tablosunu döndürürdü;
            // sayfalama onu yavaşlatır ama engellemez.
            throw ApiException::validationFailed(
                'Arama en az '.self::Q_MIN.' karakter olmalı.',
                ['field' => 'q'],
            );
        }

        $this->enum($request, 'status', ['active', 'disabled', 'all']);
        $this->enum($request, 'sort', ['name', 'created', 'last_order']);
        $this->enum($request, 'direction', ['asc', 'desc']);
    }

    /** @param list<string> $allowed */
    private function enum(Request $request, string $field, array $allowed): void
    {
        if ($request->filled($field) && !in_array($this->queryText($request, $field), $allowed, true)) {
            throw ApiException::validationFailed(
                'Geçersiz `'.$field.'` değeri.',
                ['field' => $field, 'allowed' => $allowed],
            );
        }
    }

    /**
     * @param  Builder<ApiCustomer>  $query
     */
    private function applySort(Builder $query, Request $request): void
    {
        $direction = $this->queryText($request, 'direction', 'asc');
        $sort = $this->queryText($request, 'sort', 'name');

        match ($sort) {
            'created' => $query->orderBy('created_at', $direction),
            'last_order' => $query->orderBy(
                DB::table('orders')
                    ->selectRaw('MAX(orders.created_at)')
                    ->whereColumn('orders.customer_id', 'customers.customer_id'),
                $direction,
            ),
            /*
             * VARSAYIM: `name` = ad + soyad. Sözleşme sıralamanın hangi
             * sütuna baktığını yazmıyor; liste satırında kurum adı ayrı
             * bir alan (`org_name`) olarak durduğu için "ad" en dar
             * okumasıyla alındı. Kurum adına göre sıralama istenirse
             * `sort` değerine yeni bir seçenek eklenir, bunun anlamı
             * değişmez.
             */
            default => $query->orderBy('first_name', $direction)->orderBy('last_name', $direction),
        };

        // KARARLI SIRA: eşit adlarda sayfalar arası kayma olmasın diye
        // her sıralamanın sonuna kimlik ekleniyor. Olmasaydı ikinci sayfa
        // birincinin bir satırını tekrar gösterebilirdi.
        $query->orderBy('customers.customer_id', $direction);
    }

    /**
     * Sayfadaki müşterilerin sipariş sayısı ve son sipariş anı.
     *
     * TEK SORGU, satır başına bir tane değil: yirmi beş satırlık bir
     * sayfa elli ek sorgu demek olurdu.
     *
     * @param  list<int>  $ids
     * @return array<int, array{count:int, last_at:string|null}>
     */
    private function orderStats(array $ids): array
    {
        if ($ids === []) {
            return [];
        }

        $map = [];

        foreach (
            DB::table('orders')
                ->whereIn('customer_id', $ids)
                ->groupBy('customer_id')
                ->selectRaw('customer_id, COUNT(*) AS order_count, MAX(created_at) AS last_at')
                ->get() as $row
        ) {
            $map[(int) $row->customer_id] = [
                'count' => (int) $row->order_count,
                'last_at' => self::ts($row->last_at),
            ];
        }

        return $map;
    }

    /**
     * @param  list<int>  $ids
     * @return array<int, int>
     */
    private function subscriptionCounts(array $ids): array
    {
        if ($ids === []) {
            return [];
        }

        $map = [];

        foreach (
            DB::table('veykemtu_subscriptions')
                ->whereIn('customer_id', $ids)
                ->groupBy('customer_id')
                ->selectRaw('customer_id, COUNT(*) AS subscription_count')
                ->get() as $row
        ) {
            $map[(int) $row->customer_id] = (int) $row->subscription_count;
        }

        return $map;
    }

    // ── Devretme yardımcıları ─────────────────────────────────────────────

    /**
     * Kardeş denetleyiciye gidecek isteğin kopyası.
     *
     * `actor` DÜŞÜRÜLÜYOR: o alan bu ailenin KVKK kuralı, kardeş uçların
     * sözleşmesinde yok. Orada bırakmak, bir gün oraya eklenecek bir
     * `actor` doğrulamasının bu uçtan tetiklenmesi demekti.
     *
     * @param  array<string, mixed>  $overrides
     */
    private function forward(Request $request, array $overrides): Request
    {
        $query = $request->query();
        unset($query['actor']);

        return $request->duplicate([...$query, ...$overrides]);
    }

    /**
     * Sipariş geçmişinin varsayılan penceresi.
     *
     * İstemci `from`/`to` gönderdiyse DOKUNULMAZ. Göndermediyse
     * müşterinin ilk ve son servis günü kullanılıyor; hiç siparişi yoksa
     * bugün — boş bir liste için de geçerli bir aralık gerekiyor.
     *
     * @return array<string, string>
     */
    private function orderWindow(Request $request, int $customerId): array
    {
        if ($request->filled('from') && $request->filled('to')) {
            return [];
        }

        $span = DB::table('orders')
            ->where('customer_id', $customerId)
            ->selectRaw('MIN(bld_service_date) AS ilk, MAX(bld_service_date) AS son')
            ->first();

        // İŞLETME GÜNÜ, UTC değil: kardeş uç da penceresini `BusinessTime`
        // ile kuruyor ve iki ayrı takvim, gece yarısından sonra bir günlük
        // fark üretirdi.
        $today = BusinessTime::now()->toDateString();
        $first = (string) ($span?->ilk ?? $today);
        $last = (string) ($span?->son ?? $today);

        $window = [];

        if (!$request->filled('from')) {
            $window['from'] = $first;
        }

        if (!$request->filled('to')) {
            $window['to'] = $last;
        }

        return $window;
    }

    // ── Güncelleme doğrulaması ────────────────────────────────────────────

    /**
     * Gövdeyi alan alan doğrular ve yazılacak değerleri döndürür.
     *
     * @return array<string, string|null> alan → yazılacak değer
     */
    private function validateUpdate(Request $request): array
    {
        foreach (array_keys($request->all()) as $field) {
            $name = (string) $field;

            if (in_array($name, self::ENVELOPE, true) || isset(self::COLUMNS[$name])) {
                continue;
            }

            /*
             * BİLİNMEYEN ALAN SESSİZCE YOK SAYILMAZ. `email` gönderip
             * "başarılı" cevabı alan bir yönetici, e-postayı değiştirdiğini
             * sanır ve yanlış adrese yazmaya devam eder. Ayrım
             * yapılmıyor — okunur ama yazılmaz bir şema alanı da,
             * hiç olmayan bir alan da aynı sebeple reddediliyor: bu uç
             * onları yazmıyor.
             */
            throw ApiException::validationFailed(
                '`'.$name.'` bu uçtan yazılamaz.',
                ['field' => $name, 'reason' => 'read_only'],
            );
        }

        $values = [];

        foreach (array_keys(self::COLUMNS) as $field) {
            if (!$request->has($field)) {
                continue;
            }

            $raw = $request->input($field);

            if ($raw !== null && !is_string($raw)) {
                throw ApiException::validationFailed(
                    '`'.$field.'` metin olmalı.',
                    ['field' => $field],
                );
            }

            $values[$field] = match (true) {
                in_array($field, self::NAME_FIELDS, true) => $this->name($raw, $field),
                in_array($field, self::PHONE_FIELDS, true) => $this->phone($raw, $field),
                $field === 'tax_no' => $this->taxNo($raw),
                default => $this->freeText($raw, $field),
            };
        }

        if ($values === []) {
            // Yazacak bir şey olmayan bir yazma, denetim izine "bir şey
            // yapıldı" satırı bırakıp hiçbir şey yapmazdı.
            throw ApiException::validationFailed(
                'Güncellenecek alan gönderilmedi.',
                ['reason' => 'no_fields'],
            );
        }

        return $values;
    }

    private function name(?string $value, string $field): string
    {
        $clean = trim((string) $value);

        if ($clean === '') {
            // Müşterinin adı fişte, listede, sözleşmede ve faturada
            // görünüyor; boş bırakılan bir ad her birinde boşluk açar.
            throw ApiException::validationFailed(
                'Ad ve soyad boş bırakılamaz.',
                ['field' => $field],
            );
        }

        return $this->capped($clean, $field);
    }

    /**
     * Telefon — rakam, boşluk, `+`, `(`, `)`, `-`; temizlenmiş hâli 10-15 hane.
     *
     * VERİTABANINA TEMİZLENMİŞ HÂLİ YAZILIYOR. Müşteri uygulaması da
     * numarayı çıplak on hane olarak yazıyor (`AuthController`); panel
     * biçimli yazsaydı aynı numara iki kayıtta iki farklı metin olur ve
     * ne SMS gönderimi ne de listedeki telefon araması ikisini birden
     * bulurdu.
     */
    private function phone(?string $value, string $field): ?string
    {
        $raw = trim((string) $value);

        // Boş dize → `null`: alanı temizlemenin yolu bu ve sözleşmede yazılı.
        if ($raw === '') {
            return null;
        }

        if (preg_match('/^[0-9 +()\-]+$/', $raw) !== 1) {
            throw ApiException::validationFailed(
                'Telefon yalnız rakam, boşluk, +, ( ) ve - içerebilir.',
                ['field' => $field],
            );
        }

        $digits = (string) preg_replace('/\D+/', '', $raw);

        if (strlen($digits) < 10 || strlen($digits) > 15) {
            throw ApiException::validationFailed(
                'Telefon 10-15 hane olmalı.',
                ['field' => $field],
            );
        }

        return $digits;
    }

    /**
     * Vergi numarası — 10 veya 11 hane, ya da `null`.
     *
     * ON/ON BİR HANE AYRIMI bilinçli: kurumun vergi numarası on hane,
     * şahıs işletmesinin TC kimlik numarası on bir. İkisini de aynı
     * alanda kabul etmek, panelde ikinci bir alan açmaktan dürüst.
     */
    private function taxNo(?string $value): ?string
    {
        $clean = trim((string) $value);

        if ($clean === '') {
            return null;
        }

        if (preg_match('/^\d{10}$|^\d{11}$/', $clean) !== 1) {
            throw ApiException::validationFailed(
                'Vergi numarası 10 ya da 11 hane rakam olmalı.',
                ['field' => 'tax_no'],
            );
        }

        return $clean;
    }

    /** Serbest metin kurum etiketi; boş dize alanı temizler. */
    private function freeText(?string $value, string $field): ?string
    {
        $clean = trim((string) $value);

        return $clean === '' ? null : $this->capped($clean, $field);
    }

    private function capped(string $value, string $field): string
    {
        if (mb_strlen($value) > self::MAX_LENGTHS[$field]) {
            // Sütuna sığmayan değer SESSİZCE KIRPILMIYOR: yarım yazılmış
            // bir unvan, yanlış yazılmış bir unvandır.
            throw ApiException::validationFailed(
                '`'.$field.'` en çok '.self::MAX_LENGTHS[$field].' karakter olabilir.',
                ['field' => $field],
            );
        }

        return $value;
    }

    /**
     * Gerçekten değişen alanlar — eski ve yeni değeriyle.
     *
     * @param  array<string, string|null>  $values
     * @return list<array{field:string, from:string|null, to:string|null}>
     */
    private function changes(ApiCustomer $row, array $values): array
    {
        $changes = [];

        foreach ($values as $field => $new) {
            $old = self::nullText($row->{self::COLUMNS[$field]});

            // Aynı değeri "değişti" diye yazmak, denetim izini gerçek
            // değişikliklerin arasında kaybolduğu bir listeye çevirirdi.
            if ($old === $new) {
                continue;
            }

            $changes[] = ['field' => $field, 'from' => $old, 'to' => $new];
        }

        return $changes;
    }

    /**
     * Denetime yazılacak hâl — telefonlar maskeli.
     *
     * İKİ TELEFON ALANI DA maskeleniyor (`telephone`, `org_phone`):
     * sözleşme örneği yalnız birincisini gösteriyor ama ikisi de aynı
     * türden kişisel veri ve yalnız birini maskelemek, korumayı alan
     * adına bağlamak olurdu. E-posta listede yok çünkü bu uçtan hiç
     * yazılmıyor — maskelenecek bir değişiklik doğmuyor.
     *
     * @param  list<array{field:string, from:string|null, to:string|null}>  $changes
     * @return list<array{field:string, from:string|null, to:string|null}>
     */
    private function maskChanges(array $changes): array
    {
        return array_map(static function (array $change): array {
            if (!in_array($change['field'], self::PHONE_FIELDS, true)) {
                return $change;
            }

            return [
                'field' => $change['field'],
                'from' => self::mask($change['from']),
                'to' => self::mask($change['to']),
            ];
        }, $changes);
    }

    /** `5321234567` → `532****567`; kısa değerlerde hepsi yıldız. */
    private static function mask(?string $value): ?string
    {
        if ($value === null) {
            return null;
        }

        $length = mb_strlen($value);

        if ($length <= 6) {
            return str_repeat('*', $length);
        }

        return mb_substr($value, 0, 3).'****'.mb_substr($value, -3);
    }

    // ── Ortak yardımcılar ─────────────────────────────────────────────────

    private function find(int $customerId): ApiCustomer
    {
        $row = ApiCustomer::query()->where('customer_id', $customerId)->first();

        if ($row === null) {
            throw ApiException::notFound('Müşteri bulunamadı.');
        }

        return $row;
    }

    /**
     * Şema tablosundaki alanlar — `stats` hariç.
     *
     * @return array<string, mixed>
     */
    private function detail(ApiCustomer $row): array
    {
        return [
            'customer_id' => (int) $row->customer_id,
            'first_name' => (string) $row->first_name,
            'last_name' => (string) $row->last_name,
            'email' => (string) $row->email,
            'telephone' => self::nullText($row->telephone),
            'status' => (bool) $row->status,
            'is_activated' => (bool) $row->is_activated,
            'account_type' => self::accountType($row),
            'org_name' => self::nullText($row->bld_org_name),
            'tax_office' => self::nullText($row->bld_tax_office),
            'tax_no' => self::nullText($row->bld_tax_no),
            'contact_person' => self::nullText($row->bld_contact_person),
            'org_phone' => self::nullText($row->bld_org_phone),
            'created_at' => self::ts($row->created_at),
            'last_login' => self::ts($row->last_login),
        ];
    }

    /**
     * Müşteri kartının sayıları.
     *
     * @return array<string, mixed>
     */
    private function stats(int $customerId): array
    {
        $cancelled = $this->cancelledStatusIds();
        $orders = DB::table('orders')->where('customer_id', $customerId);

        $subscriptionIds = DB::table('veykemtu_subscriptions')
            ->where('customer_id', $customerId)
            ->pluck('id')
            ->map(intval(...))
            ->all();

        return [
            'order_count' => (int) $orders->clone()->count(),
            'cancelled_order_count' => (int) $orders->clone()->whereIn('status_id', $cancelled)->count(),
            /*
             * İPTAL EDİLENLER TOPLAMA GİRMEZ: olmamış bir hizmetin
             * bedelini "harcadı" diye saymak, müşteriyi olduğundan değerli
             * gösterirdi (`invoices.md` içindeki aynı karar).
             */
            'total_spent_kurus' => Money::toKurus(
                $orders->clone()->whereNotIn('status_id', $cancelled)->sum('order_total'),
            ),
            'first_order_at' => self::ts($orders->clone()->min('created_at')),
            'last_order_at' => self::ts($orders->clone()->max('created_at')),
            'active_subscription_count' => Subscription::query()
                ->where('customer_id', $customerId)
                ->where('status', Subscription::STATUS_ACTIVE)
                ->count(),
            /*
             * Cari hesap kalktığı için borcun TEK KAYNAĞI abonelik dönem
             * ödemeleridir (`customers.md`). Başka bir yerden toplamak,
             * olmayan bir defteri okumak olurdu.
             */
            'unpaid_total_kurus' => $subscriptionIds === [] ? 0 : (int) SubscriptionPayment::query()
                ->whereIn('subscription_id', $subscriptionIds)
                ->where('status', SubscriptionPayment::STATUS_PENDING)
                ->sum('amount_kurus'),
            'address_count' => Address::query()
                ->where('customer_id', $customerId)
                ->where('bld_is_saved', true)
                ->count(),
        ];
    }

    /**
     * İptal durumunun kimlikleri — kod sabiti tek kaynak.
     *
     * Elle yazılmış bir kimlik listesi, `statuses` tablosu yeniden
     * kurulduğunda sessizce yanlış siparişleri sayardı.
     *
     * @return list<int>
     */
    private function cancelledStatusIds(): array
    {
        return DB::table('statuses')
            ->where('status_code', OrderStatusTransition::CANCELLED)
            ->pluck('status_id')
            ->map(intval(...))
            ->values()
            ->all();
    }

    /**
     * Kapatılan hesabın aktif abonelikleri.
     *
     * @return list<array{code:string, subscription_ids:list<int>}>
     */
    private function activeSubscriptionWarnings(int $customerId): array
    {
        $ids = Subscription::query()
            ->where('customer_id', $customerId)
            ->where('status', Subscription::STATUS_ACTIVE)
            ->orderBy('id')
            ->pluck('id')
            ->map(intval(...))
            ->values()
            ->all();

        return $ids === [] ? [] : [['code' => 'active_subscriptions', 'subscription_ids' => $ids]];
    }

    /**
     * @param  array<string, mixed>  $body
     * @param  list<array{code:string, subscription_ids:list<int>}>  $warnings
     * @return array<string, mixed>
     */
    private static function statusBody(array $body, array $warnings): array
    {
        // Boş `warnings` GÖNDERİLMİYOR: istemci "uyarı var mı" sorusunu
        // alanın varlığıyla cevaplıyor ve boş bir dizi, uyarı rozetini
        // her kapatmada bir an için yakardı.
        return $warnings === [] ? $body : [...$body, 'warnings' => $warnings];
    }

    private static function accountType(ApiCustomer $row): string
    {
        // Sütun `NOT NULL` ve varsayılanı `corporate`; yine de boş bir
        // dizeye düşen eski bir kayıt istemciye bilinmeyen bir değer
        // göndermesin diye varsayılan burada da duruyor.
        return (string) ($row->bld_account_type ?: 'corporate');
    }

    private static function nullText(mixed $value): ?string
    {
        if (!is_string($value)) {
            return $value === null ? null : (string) $value;
        }

        return $value === '' ? null : $value;
    }

    /** Çiftin diğer yarısı boşsa koordinat dönmez. */
    private static function coordinate(mixed $value, mixed $pair): ?float
    {
        return $value === null || $pair === null ? null : (float) $value;
    }

    /** `LIKE` süzgeci — joker karakterler kaçırılır. */
    private static function like(string $term): string
    {
        return '%'.str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], $term).'%';
    }
}
