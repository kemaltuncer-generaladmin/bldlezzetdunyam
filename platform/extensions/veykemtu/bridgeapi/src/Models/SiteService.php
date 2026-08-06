<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Flame\Database\Model;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Carbon;
use Veykemtu\BridgeApi\Services\HtmlSanitizer;

/**
 * Kurumsal sitedeki hizmet kaydı.
 *
 * @property int $id
 * @property string $slug
 * @property string $title
 * @property string $summary
 * @property string $intro
 * @property string $icon
 * @property string|null $body_html
 * @property array<mixed> $audience
 * @property array<mixed> $how_it_works
 * @property array<mixed> $benefits
 * @property string $menu_planning
 * @property array<mixed> $quote_needs
 * @property int $sort_order
 * @property bool $is_published
 * @property Carbon|null $updated_at
 */
class SiteService extends Model
{
    protected $table = 'veykemtu_site_services';

    /**
     * AÇIKÇA AÇILIYOR. `Igniter\Flame\Database\Model` zaman damgalarını
     * varsayılan olarak KAPALI tutuyor (`$timestamps = false`), oysa tablonun
     * `created_at`/`updated_at` sütunları var. Kapalı kalsaydı iki şey sessizce
     * bozulurdu: panel listesindeki "Güncellenme" sütunu hep boş görünürdü ve
     * `SiteContentRepository::bundle()` içindeki `updated_at` damgası hiç
     * dolmazdı — site o damgaya bakarak yeniden çizim yapıyor.
     */
    public $timestamps = true;

    protected $guarded = [];

    /** @var array<string, string> */
    protected $casts = [
        'audience' => 'array',
        'how_it_works' => 'array',
        'benefits' => 'array',
        'quote_needs' => 'array',
        'is_published' => 'boolean',
        'sort_order' => 'integer',
    ];

    /**
     * Gövde HTML'i KAYIT ANINDA temizlenir.
     *
     * Mutator'da yapılmasının sebebi: kaydın nereden geldiği (admin formu,
     * içe aktarma komutu, test) fark etmeksizin aynı kuraldan geçmesi.
     * Denetleyicide yapılsaydı komutla eklenen kayıt temizlenmeden kalırdı.
     */
    public function setBodyHtmlAttribute(?string $value): void
    {
        $this->attributes['body_html'] = HtmlSanitizer::clean($value);
    }

    /** @param  Builder<self>  $query */
    public function scopePublished(Builder $query): void
    {
        $query->where('is_published', true)->orderBy('sort_order')->orderBy('id');
    }
}
