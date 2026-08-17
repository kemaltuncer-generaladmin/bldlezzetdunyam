<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Flame\Database\Model;
use Illuminate\Support\Carbon;

/**
 * Kontrol Merkezi denetim satırı — K-21, `docs/03-api-sozlesmesi.md` §14.
 *
 * Her yazma isteği burada bir iz bırakır; kuru prova bile bırakır
 * (`result = dry_run`). Kuru provanın da yazılması bilinçli: "denedim ama
 * uygulamadım" bir eylemdir ve yanlış kasaya kilit uygulamaya çalışan
 * birinin ilk adımı çoğu zaman odur.
 *
 * SATIR SİLİNMEZ. Bu sınıfta silme yolu yok ve olmayacak.
 *
 * @property int $id
 * @property string $actor
 * @property string $action
 * @property string|null $target_type
 * @property int|null $target_id
 * @property string $reason
 * @property array<string, mixed>|null $payload_json
 * @property string $result
 * @property Carbon|null $created_at
 */
class ControlAudit extends Model
{
    /** Kuru prova: hiçbir yazma yapılmadı, yalnız niyet kaydedildi. */
    public const string RESULT_DRY_RUN = 'dry_run';

    /** Satır işlemden ÖNCE açılır; sonucu henüz belli değil. */
    public const string RESULT_PENDING = 'pending';

    public const string RESULT_APPLIED = 'applied';

    public const string RESULT_FAILED = 'failed';

    /** Hedef tipleri — `target_type` sütununun alabileceği değerler. */
    public const string TARGET_DEVICE = 'kitchen_device';

    public const string TARGET_ORDER = 'order';

    /*
     * ── Kontrol paneli alanlarının hedefleri (`docs/control/00-genel.md` §8.1)
     *
     * SABİT ADLARI VE DEĞERLERİ SÖZLEŞMEDEN BİREBİR GELİR. Faz planındaki
     * kısa adlar (`TARGET_PRODUCT`, `TARGET_CONTRACT`, `TARGET_CMS`,
     * `TARGET_QUOTE`, `TARGET_ERROR_EVENT`) burada karşılıklarıyla
     * duruyor: ürün → `TARGET_MENU`, sözleşme →
     * `TARGET_SUBSCRIPTION_CONTRACT`, içerik → üç ayrı tablo olduğu için
     * `TARGET_SITE_CONTENT` / `TARGET_SITE_SERVICE` / `TARGET_SITE_POST`,
     * talep → `TARGET_QUOTE_REQUEST`, hata olayı → `TARGET_MONITOR_EVENT`.
     * İkinci bir ad seti tanımlanmadı: aynı `target_type` değerini iki
     * sabitle yazmak, denetim ekranında filtrelenen değerin hangi sabitten
     * geldiğini araştırmayı gerektirirdi.
     *
     * `target_type` sütunu `string(32)`; en uzunu (`subscription_contract`,
     * 21 karakter) rahat sığıyor.
     */

    /** `veykemtu_daily_menus.id` — gün, kalem değil (`menu.md`). */
    public const string TARGET_DAILY_MENU = 'daily_menu';

    /** `menus.menu_id` — katalog ürünü (`products.md`). */
    public const string TARGET_MENU = 'menu';

    /** `categories.category_id`. */
    public const string TARGET_CATEGORY = 'category';

    /** `target_id` = `location_id` (`settings.md`). */
    public const string TARGET_SETTINGS = 'settings';

    /** `veykemtu_closed_days.id`. */
    public const string TARGET_CLOSED_DAY = 'closed_day';

    /** `veykemtu_subscriptions.id`. */
    public const string TARGET_SUBSCRIPTION = 'subscription';

    /** `veykemtu_quote_requests.id` — abonelik talebi. */
    public const string TARGET_QUOTE_REQUEST = 'quote_request';

    /** `veykemtu_subscription_contracts.id`. */
    public const string TARGET_SUBSCRIPTION_CONTRACT = 'subscription_contract';

    /** `veykemtu_subscription_payments.id`. */
    public const string TARGET_SUBSCRIPTION_PAYMENT = 'subscription_payment';

    /** `customers.customer_id` — KVKK gereği OKUMALARI da yazılır. */
    public const string TARGET_CUSTOMER = 'customer';

    /** `veykemtu_invoices.id`. */
    public const string TARGET_INVOICE = 'invoice';

    /** `target_id` YOK: birincil anahtar metin, `payload_json.key`'de. */
    public const string TARGET_SITE_CONTENT = 'site_content';

    /** `veykemtu_site_services.id`. */
    public const string TARGET_SITE_SERVICE = 'site_service';

    /** `veykemtu_site_posts.id`. */
    public const string TARGET_SITE_POST = 'site_post';

    /** `target_id` YOK: şablon anahtarı `payload_json.key`'de. */
    public const string TARGET_SMS_TEMPLATE = 'sms_template';

    /** `target_id` YOK: duyuru taslağı tekil bir ayardır. */
    public const string TARGET_ANNOUNCEMENT = 'announcement';

    /** `veykemtu_notifications.id` — uygulama içi duyuru. */
    public const string TARGET_NOTIFICATION = 'notification';

    /** `veykemtu_monitor_events.id` — toplanan hata olayı. */
    public const string TARGET_MONITOR_EVENT = 'monitor_event';

    /**
     * KVKK okuma eylemi — `readAudit()` varsayılanı.
     *
     * Sabit olarak duruyor çünkü değeri iki yerde birden geçiyor: satırı
     * yazan yardımcı ve denetim ekranının süzgeci (`GET /control/audit`
     * `action` parametresi). Elle yazılan bir dize, ikisinden birinde
     * harf farkıyla ayrıştığında ekran KVKK erişimlerini hiç göstermezdi
     * ve eksiklik ancak bir denetimde fark edilirdi.
     */
    public const string ACTION_CUSTOMER_READ = 'customer.read';

    protected $table = 'veykemtu_control_audit';

    protected $guarded = [];

    /**
     * DAMGALAR KAPALI ve bu kasıtlı: tabloda `updated_at` sütunu yok.
     *
     * `created_at` elle yazılıyor (`record()`). Damgalar açık bırakılsaydı
     * Eloquent her `save()`'de var olmayan bir sütunu yazmaya çalışır ve
     * `result` güncellemesi SQL hatasıyla düşerdi.
     */
    public $timestamps = false;

    protected $casts = [
        'payload_json' => 'array',
        'created_at' => 'datetime',
    ];

    /**
     * Denetim satırını açar.
     *
     * @param  array<string, mixed>  $payload  eylemi anlamlandıran alanlar
     */
    public static function record(
        string $actor,
        string $action,
        ?string $targetType,
        ?int $targetId,
        string $reason,
        array $payload,
        string $result,
    ): self {
        $row = new self;

        $row->actor = mb_substr($actor, 0, 120);
        $row->action = $action;
        $row->target_type = $targetType;
        $row->target_id = $targetId;
        $row->reason = mb_substr($reason, 0, 500);
        $row->payload_json = $payload;
        $row->result = $result;
        $row->created_at = Carbon::now();
        $row->save();

        return $row;
    }

    /**
     * KVKK okuma izi — `control/customers/*` (`00-genel.md` §9).
     *
     * SÖZLEŞMEDEKİ TEK "OKUMA DENETİM SATIRI" BİÇİMİ ve başka hiçbir alanda
     * tekrarlanmaz. Diğer alanlarda yalnız yazmalar iz bırakır; müşteri
     * uçları farklıdır çünkü sistemdeki en geniş kişisel veri yüzeyi
     * oradadır (ad, telefon, e-posta, kurum, adres ve sipariş geçmişi tek
     * ekranda). Sızıntı çoğu zaman bir yazma değil bir OKUMADIR; yazma izi
     * tek başına "kim, ne zaman, kimin kaydını açtı" sorusuna cevap
     * vermiyor.
     *
     * `ControlController::write()` KABUĞUNDAN GEÇMEZ ve geçemez: o kabuk
     * kuru prova, gerekçe zorunluluğu ve `pending` → `applied` geçişi
     * üzerine kurulu. Okumanın kuru provası yoktur (okumayı "denemek" ile
     * yapmak aynı şeydir) ve satır ilk hâlinde `applied` doğar.
     *
     * GEREKÇE İSTEMCİDEN İSTENMEZ, SUNUCU ÜRETİR. Her müşteri kaydı
     * açılışında yöneticiden serbest metin istemek, ekranı kullanılamaz
     * kılar ve doldurulan alan üç günde "-" olurdu. Üretilen metin
     * `reason` sütununun en az 10 karakter beklentisini kendiliğinden
     * karşılıyor.
     *
     * `payload_json` YALNIZ SÜZGEÇLERİ TAŞIR. Dönen kayıtların kendisi
     * yazılsaydı denetim izi ikinci bir müşteri veritabanına dönerdi —
     * yani kişisel veriyi korumak için tutulan defter, korumaya çalıştığı
     * veriyi çoğaltırdı.
     *
     * @param  string    $path      isteğin yolu; gerekçeye ve yüke girer
     * @param  array<string, mixed>  $filters  liste süzgeçleri (`q`, `page`, …)
     * @param  int|null  $targetId  tekil kayıtta müşteri kimliği, listede `null`
     */
    public static function readAudit(
        string $actor,
        string $path,
        ?int $targetId = null,
        array $filters = [],
        string $action = self::ACTION_CUSTOMER_READ,
        string $targetType = self::TARGET_CUSTOMER,
    ): self {
        return self::record(
            actor: $actor,
            action: $action,
            targetType: $targetType,
            targetId: $targetId,
            reason: 'Kişisel veri görüntüleme: '.$path,
            payload: ['path' => $path, 'filters' => $filters],
            result: self::RESULT_APPLIED,
        );
    }

    public function markApplied(): void
    {
        $this->result = self::RESULT_APPLIED;
        $this->save();
    }

    /**
     * Başarısız denemeyi işaretler ve sebebini yükün içine yazar.
     *
     * KURU PROVANIN SONUCU DEĞİŞMEZ: sözleşme (§4) kuru prova satırının
     * `result = "dry_run"` olmasını şart koşuyor ve bir ön denetimin
     * ("bu sipariş teslim edilmiş, düzenlenemez") bunu `failed`'a
     * çevirmesi, Kontrol Merkezi'nin denetim ekranında kuru provaları
     * gerçek yazma denemeleriyle karıştırırdı. Sebep yine kaydediliyor,
     * yalnız `payload_json.error` içinde.
     */
    public function markFailed(string $message): void
    {
        $payload = $this->payload_json ?? [];
        $payload['error'] = mb_substr($message, 0, 500);
        $this->payload_json = $payload;

        if ($this->result !== self::RESULT_DRY_RUN) {
            $this->result = self::RESULT_FAILED;
        }

        $this->save();
    }
}
