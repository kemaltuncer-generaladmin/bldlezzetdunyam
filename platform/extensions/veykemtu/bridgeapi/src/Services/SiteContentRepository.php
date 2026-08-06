<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use Illuminate\Support\Facades\Cache;
use Veykemtu\BridgeApi\Models\SiteContent;
use Veykemtu\BridgeApi\Models\SitePost;
use Veykemtu\BridgeApi\Models\SiteService;

/**
 * Kurumsal site içeriğinin tek okuma noktası.
 *
 * ## Neden tek uç, parça parça değil?
 *
 * Sitenin her sayfası aynı çekirdek veriye (marka, iletişim, gezinme)
 * ihtiyaç duyuyor. Ayrı uçlar yapsaydık ana sayfa yedi istek atardı ve
 * bunlardan biri gecikince sayfa yarım kalırdı. Tek paket hem küçük
 * (birkaç on kB) hem de site tarafında tek `fetch` ile önbelleklenebilir.
 *
 * ## Eksik anahtar hata değildir
 *
 * Panelde henüz doldurulmamış bir bölüm `null`/boş döner; site o bölümü
 * çizmez. Eksik anahtarda 500 dönmek, yeni kurulan bir sistemde sitenin
 * hiç açılmaması demekti.
 */
final class SiteContentRepository
{
    /**
     * Önbellek anahtarı.
     *
     * İçerik nadiren değişir ama her sayfa isteğinde okunur. Panelde kaydet'e
     * basıldığında `forget()` çağrılıyor (bkz. `SiteContentObserver`), yani
     * yönetici değişikliği anında görür — süre dolmasını beklemez.
     */
    public const string CACHE_KEY = 'veykemtu.site_content';

    private const int CACHE_MINUTES = 60;

    /** @return array<string, mixed> */
    public function bundle(): array
    {
        /** @var array<string, mixed> $bundle */
        $bundle = Cache::remember(
            self::CACHE_KEY,
            now()->addMinutes(self::CACHE_MINUTES),
            fn (): array => $this->build(),
        );

        return $bundle;
    }

    public function forget(): void
    {
        Cache::forget(self::CACHE_KEY);
    }

    /** @return array<string, mixed> */
    private function build(): array
    {
        $content = SiteContent::query()->get()->keyBy('key');

        /** @var array<string, mixed> $values */
        $values = [];
        foreach (SiteContent::KEYS as $key) {
            $row = $content->get($key);
            $values[$key] = $row instanceof SiteContent ? $row->value : null;
        }

        return [
            'brand' => $values[SiteContent::KEY_BRAND],
            'contact' => $values[SiteContent::KEY_CONTACT],
            'company' => $values[SiteContent::KEY_COMPANY],
            'faq' => $values[SiteContent::KEY_FAQ] ?? [],
            'sectors' => $values[SiteContent::KEY_SECTORS] ?? [],
            'menus' => $values[SiteContent::KEY_MENUS],
            'quality' => $values[SiteContent::KEY_QUALITY],
            'services' => $this->services(),
            'posts' => $this->posts(),
            'updated_at' => $this->lastUpdatedAt(),
        ];
    }

    /** @return list<array<string, mixed>> */
    private function services(): array
    {
        return SiteService::query()
            ->published()
            ->get()
            ->map(fn (SiteService $service): array => [
                'slug' => $service->slug,
                'title' => $service->title,
                'summary' => $service->summary,
                'intro' => $service->intro,
                'icon' => $service->icon,
                'body_html' => $service->body_html !== '' ? $service->body_html : null,
                'audience' => $service->audience,
                'how_it_works' => $service->how_it_works,
                'benefits' => $service->benefits,
                'menu_planning' => $service->menu_planning,
                'quote_needs' => $service->quote_needs,
            ])
            ->values()
            ->all();
    }

    /** @return list<array<string, mixed>> */
    private function posts(): array
    {
        return SitePost::query()
            ->published()
            ->get()
            ->map(fn (SitePost $post): array => [
                'slug' => $post->slug,
                'title' => $post->title,
                'description' => $post->description,
                'category' => $post->category,
                'published_at' => $post->published_at->toDateString(),
                'reading_minutes' => $post->readingMinutes(),
                'body_html' => $post->body_html,
            ])
            ->values()
            ->all();
    }

    /**
     * Paketin en son ne zaman değiştiği.
     *
     * Site bunu `ETag`/`Last-Modified` yerine kullanıyor: içerik değişmediyse
     * yeniden çizim yapmaya gerek yok. Üç tablonun en büyüğü alınıyor çünkü
     * yalnızca birine dokunmak da paketi değiştirir.
     */
    private function lastUpdatedAt(): ?string
    {
        $stamps = [
            SiteContent::query()->max('updated_at'),
            SiteService::query()->max('updated_at'),
            SitePost::query()->max('updated_at'),
        ];

        $stamps = array_filter($stamps, static fn ($value): bool => $value !== null);
        if ($stamps === []) {
            return null;
        }

        return (string) max($stamps);
    }
}
