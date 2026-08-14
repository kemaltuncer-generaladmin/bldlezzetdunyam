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
