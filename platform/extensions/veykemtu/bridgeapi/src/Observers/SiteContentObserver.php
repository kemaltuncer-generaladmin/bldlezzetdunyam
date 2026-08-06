<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Observers;

use Igniter\Flame\Database\Model;
use Veykemtu\BridgeApi\Services\SiteContentRepository;
use Veykemtu\BridgeApi\Services\SiteRevalidator;

/**
 * İçerik değiştiğinde site önbelleğini düşürür.
 *
 * ## Neden ayrı bir gözlemci, modelin `booted()`'ı değil?
 *
 * Aynı kural üç modelde geçerli (`SiteContent`, `SiteService`, `SitePost`) ve
 * hepsinin sebebi tek: paket (`SiteContentRepository::bundle()`) üçünü birden
 * okuyor, biri değişince paketin tamamı bayatlıyor. `booted()` içine yazılsaydı
 * aynı iki satır üç dosyada tekrarlanır ve dördüncü bir içerik modeli
 * eklendiğinde kopyalanması unutulurdu — unutulduğunda da hata vermez, sadece
 * yönetici değişikliğini bir saat boyunca sitede göremez. Sessiz bozulma en
 * kötüsüdür.
 *
 * Ayrıca modeller şu an önbellekten hiç haberdar değil (`use` listelerinde
 * `Cache` yok); bu bağı gözlemcide tutmak o bilgisizliği koruyor.
 *
 * ## Neden `saved` ve `deleted`, `updated` değil?
 *
 * `saved` hem yeni kaydı hem güncellemeyi kapsar. Yalnızca `updated`
 * dinlenseydi panelden EKLENEN ilk hizmet sitede görünmezdi.
 */
final class SiteContentObserver
{
    public function __construct(
        private readonly SiteContentRepository $repository,
        private readonly SiteRevalidator $revalidator,
    ) {}

    public function saved(Model $model): void
    {
        $this->flush();
    }

    public function deleted(Model $model): void
    {
        $this->flush();
    }

    /**
     * İki önbellek var ve ikisi de düşmeli.
     *
     * Sunucu önbelleği (`forget`) düşmezse site tazeleme isteğinden sonra
     * gelip yine BAYAT veriyi okur — sıralama önemli: önce sunucu, sonra site.
     *
     * Site tarafı "en iyi çaba"dır ve hata fırlatmaz; gerekçesi
     * `SiteRevalidator` başlığında.
     */
    private function flush(): void
    {
        $this->repository->forget();
        $this->revalidator->revalidate();
    }
}
