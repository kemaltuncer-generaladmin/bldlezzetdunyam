<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Flame\Database\Model;
use Illuminate\Support\Carbon;

/**
 * Yayınlanmış bir uygulama sürümü — `docs/05-mutfakapp.md` §9.
 *
 * `AppVersionController` bunu okur, `AppReleaseCommand` yazar. Kasa bu
 * satırdaki adresten `.deb`'i indirip `sha256` ile doğrular.
 *
 * @property int $id
 * @property string $app_id
 * @property string $version
 * @property string $min_supported
 * @property string|null $download_url
 * @property string|null $sha256
 * @property int|null $size_bytes
 * @property string|null $notes
 * @property Carbon $released_at
 */
class AppRelease extends Model
{
    /** Kasa uygulaması — `.deb` ile güncellenir. */
    public const string MUTFAKAPP = 'mutfakapp';

    /** Müşteri uygulaması — mağazadan güncellenir, `download_url` boştur. */
    public const string MUSTERIAPP = 'musteriapp';

    /** @var list<string> */
    public const array APPS = [self::MUTFAKAPP, self::MUSTERIAPP];

    protected $table = 'veykemtu_app_releases';

    protected $guarded = [];

    /**
     * DAMGALAR AÇIK OLMALI — `KitchenCommand` ile aynı tuzak.
     *
     * `Igniter\Flame\Database\Model` `public $timestamps = false;` tanımlıyor
     * ve alt sınıf devralıyor; göç `timestamps()` ile sütunları açsa bile
     * hiçbir zaman yazılmıyorlar.
     */
    public $timestamps = true;

    protected $casts = [
        'released_at' => 'datetime',
        'size_bytes' => 'integer',
    ];

    /**
     * Bir uygulamanın yayındaki en yeni sürümü.
     *
     * SIRALAMA `released_at`'E GÖRE, `id`'ye değil: bir sürüm kaydı
     * düzeltilmek için silinip yeniden girilebilir ve o zaman daha büyük
     * bir `id` alır. Yayın tarihi ise gerçeği anlatır; `1.0.9`'u düzelten
     * yeni satır, `1.1.0`'ı geçmiş sayılmamalı.
     */
    public static function latestFor(string $appId): ?self
    {
        return static::query()
            ->where('app_id', $appId)
            ->orderByDesc('released_at')
            ->orderByDesc('id')
            ->first();
    }
}
