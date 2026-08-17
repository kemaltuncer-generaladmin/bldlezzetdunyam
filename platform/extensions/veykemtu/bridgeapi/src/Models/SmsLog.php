<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Flame\Database\Model;

/**
 * Bir SMS gönderim denemesinin kaydı — B1 (`docs/control/sms.md`).
 *
 * SALT OKUNUR SAYILIR ve **SİLİNMEZ**: kayıt, sağlayıcının kendi panelinden
 * bağımsız olarak bizim tarafımızdaki gerçektir. "Müşteriye haber verildi
 * mi" sorusunun cevabı burasıdır ve o soru genellikle bir şikâyet
 * üzerine, yani mesajın gittiği iddia edilen günden çok sonra sorulur.
 *
 * SATIRI YAZAN TEK YER `Services\Sms\SmsDispatcher`'dır. Model üzerinden
 * `create()` çağırmak, idempotans kapısını (`insertOrIgnore` +
 * `UNIQUE(template_key, reference_type, reference_id)`) atlamak demektir;
 * o kapı aşılırsa müşteri aynı mesajı beş kez alır.
 */
class SmsLog extends Model
{
    /** Sağlayıcı kabul etti. */
    public const string STATUS_SENT = 'sent';

    /** Sağlayıcı reddetti, ulaşılamadı ya da gönderim yarıda kaldı. */
    public const string STATUS_FAILED = 'failed';

    /** Gönderilmedi ve gönderilmeyecek — numara SMS'e uygun değil. */
    public const string STATUS_SKIPPED = 'skipped';

    /** Kuru koşum: neyin gideceği hesaplandı, hiçbir şey gönderilmedi. */
    public const string STATUS_DRY_RUN = 'dry_run';

    protected $table = 'veykemtu_sms_log';

    /**
     * `updated_at` KOLONU YOK — satır bir olay kaydı, düzenlenen bir kayıt
     * değil. Eloquent'in zaman damgalarını açık bırakmak, her yazmada var
     * olmayan bir kolona değer basmaya çalışırdı.
     */
    public $timestamps = false;

    protected $guarded = [];

    protected $casts = [
        'reference_id' => 'integer',
        'created_at' => 'datetime',
    ];

    /**
     * Kayıt ekranında gösterilecek maskeli numara (`532****567`).
     *
     * NEDEN MASKE: tam numara zaten müşteri kartında duruyor ve orası
     * denetleniyor. Gönderim kaydı, panele erişebilen herkesin serbestçe
     * tarayabildiği bir İLETİŞİM DEFTERİNE dönüşmemeli
     * (`docs/control/sms.md`).
     *
     * Beklenmedik uzunluktaki bir numara TAMAMEN maskelenir: kısa bir
     * numarada ilk 3 + son 3 çakışıp numaranın tamamını gösterirdi.
     */
    public static function maskPhone(string $phone): string
    {
        if (mb_strlen($phone) < 8) {
            return str_repeat('*', mb_strlen($phone));
        }

        return mb_substr($phone, 0, 3)
            .str_repeat('*', mb_strlen($phone) - 6)
            .mb_substr($phone, -3);
    }
}
