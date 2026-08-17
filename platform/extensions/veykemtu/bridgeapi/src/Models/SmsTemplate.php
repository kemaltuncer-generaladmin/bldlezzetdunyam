<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Flame\Database\Model;

/**
 * Panelden düzenlenebilen SMS metni — B1 (`docs/control/sms.md`).
 *
 * ANAHTAR KÜMESİ SABİTTİR ve göçte tohumlanır. Kod `send('order_confirmed',
 * …)` diye çağırır; listede olmayan bir anahtar bir yazım hatasıdır,
 * yönetilecek bir kayıt değil. Panel yeni anahtar AÇAMAZ — açabilseydi,
 * hiçbir tetikleyicinin çağırmadığı ölü şablonlar birikirdi ve yönetici
 * "yazdım ama gitmiyor" derdi.
 *
 * `enabled` VARSAYILAN KAPALI doğar (göç yorumundaki kutu). Kapalı bir
 * şablon için gönderim DENENMEZ ve kayda satır YAZILMAZ — `SmsDispatcher`
 * sessizce döner.
 */
class SmsTemplate extends Model
{
    /** Günün menüsü duyurusu — İYS/KVKK imzası gelene kadar KAPALI. */
    public const string KEY_DAILY_MENU_ANNOUNCE = 'dailymenu.announce';

    protected $table = 'veykemtu_sms_templates';

    public $timestamps = true;

    protected $guarded = [];

    protected $casts = [
        'enabled' => 'boolean',
    ];

    /** Anahtara göre şablon — yoksa `null`. */
    public static function findByKey(string $key): ?self
    {
        return self::query()->where('key', $key)->first();
    }

    /**
     * Değişkenleri yerine koyar.
     *
     * TANINMAYAN DEĞİŞKEN OLDUĞU GİBİ BIRAKILIR (`{eta}`), boşa
     * ÇEVRİLMEZ. `docs/control/sms.md` bu kararı önizleme ucu için
     * gerekçelendiriyor ve aynı gerekçe gönderimde de geçerli: sessizce
     * boşaltılan bir değişken müşteriye "Sayın , siparişiniz…" diye giden,
     * kimsenin fark etmediği bir SMS üretir. Ham `{eta}` çirkindir ama
     * GÖRÜLÜR ve kayda da o hâliyle geçer.
     *
     * Değer `null` ise değişken hiç verilmemiş sayılır — aynı sebeple.
     *
     * @param  array<string, string|int|float|null>  $vars
     */
    public function render(array $vars): string
    {
        $pairs = [];

        foreach ($vars as $name => $value) {
            if ($value === null) {
                continue;
            }

            $pairs['{'.$name.'}'] = (string) $value;
        }

        return strtr((string) $this->body, $pairs);
    }
}
