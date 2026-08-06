<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Flame\Database\Model;
use Illuminate\Support\Carbon;

/**
 * Sınırlı içerik listeleri ve tekil değerler — anahtar → JSON.
 *
 * İletişim bilgisi, SSS, sektörler, menü çözümleri, kalite zinciri ve
 * kurumsal metinler burada durur. Her biri için ayrı tablo açmak, dört
 * maddelik bir listeyi yönetmek üzere panele ayrı bir bölüm koymak olurdu.
 *
 * @property string $key
 * @property array<mixed> $value
 * @property Carbon|null $updated_at
 */
class SiteContent extends Model
{
    // ── Anahtarlar. Site bu sabitlere göre okur; yönetici değiştiremez. ────
    public const string KEY_BRAND = 'brand';

    public const string KEY_CONTACT = 'contact';

    public const string KEY_COMPANY = 'company';

    public const string KEY_FAQ = 'faq';

    public const string KEY_SECTORS = 'sectors';

    public const string KEY_MENUS = 'menus';

    public const string KEY_QUALITY = 'quality';

    /** @var list<string> */
    public const array KEYS = [
        self::KEY_BRAND,
        self::KEY_CONTACT,
        self::KEY_COMPANY,
        self::KEY_FAQ,
        self::KEY_SECTORS,
        self::KEY_MENUS,
        self::KEY_QUALITY,
    ];

    protected $table = 'veykemtu_site_content';

    /** Gerekçe `SiteService::$timestamps` üzerinde — aynı çekirdek varsayılanı. */
    public $timestamps = true;

    protected $primaryKey = 'key';

    public $incrementing = false;

    protected $keyType = 'string';

    protected $guarded = [];

    /** @var array<string, string> */
    protected $casts = ['value' => 'array'];
}
