<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Models;

use Igniter\Flame\Database\Model;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Carbon;
use Veykemtu\BridgeApi\Services\HtmlSanitizer;

/**
 * Bilgi merkezi yazısı.
 *
 * @property int $id
 * @property string $slug
 * @property string $title
 * @property string $description
 * @property string $category
 * @property string $body_html
 * @property Carbon $published_at
 * @property int|null $reading_minutes
 * @property bool $is_published
 * @property Carbon|null $updated_at
 */
class SitePost extends Model
{
    /** Dakikada okunan ortalama kelime — okuma süresi tahmini için. */
    private const int WORDS_PER_MINUTE = 200;

    protected $table = 'veykemtu_site_posts';

    /** Gerekçe `SiteService::$timestamps` üzerinde — aynı çekirdek varsayılanı. */
    public $timestamps = true;

    protected $guarded = [];

    /** @var array<string, string> */
    protected $casts = [
        'published_at' => 'date',
        'is_published' => 'boolean',
        'reading_minutes' => 'integer',
    ];

    public function setBodyHtmlAttribute(?string $value): void
    {
        $this->attributes['body_html'] = HtmlSanitizer::clean($value);
    }

    /**
     * Okuma süresi — elle girilmediyse gövdeden hesaplanır.
     *
     * Yöneticiden her yazı için dakika girmesini beklemek, unutulduğunda
     * sitede "0 dakika okuma" yazması demekti. Elle girilen değer yine de
     * kazanır: bazen yazının ağırlığı kelime sayısıyla ölçülmez.
     */
    public function readingMinutes(): int
    {
        if ($this->reading_minutes !== null && $this->reading_minutes > 0) {
            return $this->reading_minutes;
        }

        $words = str_word_count(strip_tags((string) $this->body_html));

        return max(1, (int) ceil($words / self::WORDS_PER_MINUTE));
    }

    /** @param  Builder<self>  $query */
    public function scopePublished(Builder $query): void
    {
        $query->where('is_published', true)->orderByDesc('published_at')->orderByDesc('id');
    }
}
