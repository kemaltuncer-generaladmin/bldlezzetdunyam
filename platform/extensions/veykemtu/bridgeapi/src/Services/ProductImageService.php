<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use finfo;
use Igniter\Cart\Models\Menu;
use Igniter\Flame\Exception\ApplicationException;
use Igniter\Flame\Support\MediaUploadValidator;
use Veykemtu\BridgeApi\Exceptions\ApiException;

/**
 * Ürün görselinin çözülmesi, denetlenmesi ve medya kitaplığına bağlanması
 * — `docs/control/products.md` § "Görsel".
 *
 * NEDEN AYRI SINIF: denetleyicinin işi gerekçe istemek ve denetime yazmak.
 * Görselin gerçekten güvenli olup olmadığı ayrı bir sorudur ve cevabı
 * (base64 → bayt → mime → çekirdek medya doğrulayıcısı) tek parça hâlinde
 * okunabilmeli. Kuru prova da bu sınıfın [decode] adımını koşar, yalnız
 * [attach] çağrılmaz — "kuru prova geçti" diyen ekranın gerçek gönderimde
 * patlamaması bu ayrıma bağlı.
 *
 * ŞEMA UYDURULMUYOR: görsel TastyIgniter'ın kendi medya kitaplığında,
 * `menus` ile aynı `thumb` etiketinde duruyor — admin panelden yüklenen
 * fotoğrafın durduğu yerin ta kendisi (`Console\MenuImageCommand` aynı
 * yolu kullanıyor). Ayrı bir tablo açmak, panelden yüklenen görselle
 * merkezden yüklenen görseli iki ayrı gerçeğe bölerdi.
 */
final class ProductImageService
{
    /**
     * Çözülmüş içeriğin üst sınırı — 5 MB.
     *
     * SINIR ÇÖZÜLMÜŞ BAYT ÜZERİNDEN. Base64 ~%33 şişirdiği için 5 MB'lık
     * bir görsel ~6,7 MB gövde eder; sunucunun `post_max_size` ve ters
     * vekilin `client_max_body_size` değerleri en az 8 MB olmalıdır.
     * Aksi hâlde istek denetleyiciye hiç ulaşmaz ve hata `413` olarak,
     * sözleşmenin hata biçimi dışında döner.
     */
    public const int MAX_BYTES = 5_242_880;

    /** Medya etiketi — `menus` görselinin çekirdekteki tek etiketi. */
    public const string MEDIA_TAG = 'thumb';

    /**
     * İçerikten okunan mime → kabul edilen uzantılar (ilki varsayılan).
     *
     * BURASI BEYAZ LİSTE, KARA LİSTE DEĞİL. Kara liste yazmak, yarın
     * çıkacak bir biçimi sessizce kabul etmek demekti.
     */
    private const array MIME_EXTENSIONS = [
        'image/jpeg' => ['jpg', 'jpeg'],
        'image/png' => ['png'],
        'image/webp' => ['webp'],
    ];

    /**
     * Base64 gövdeyi çözer ve sözleşmedeki SIRAYLA denetler.
     *
     * Sıra sözleşmede yazılı ve her adım kendi hatasını verir; adımlar yer
     * değiştirseydi bozuk bir base64 "çok büyük" diye reddedilir ve
     * yönetici dosyayı küçültmeye çalışırdı.
     *
     *   1. geçerli base64 mü        → `invalid_base64`
     *   2. çözülmüş boyut ≤ 5 MB    → `too_large`
     *   3. mime İÇERİKTEN okunur    → `invalid_mime`
     *   4. çekirdek medya doğrulayıcısı (gömülü betik, Apache yönergesi)
     *
     * 3. ADIM UZANTIYA DEĞİL İÇERİĞE BAKAR. Uzantıya güvenmek, `.jpg`
     * adlı bir PHP dosyasını yüklemenin en bilinen yoludur.
     *
     * 4. ADIM NEDEN BURADA, ÇEKİRDEĞE BIRAKILMIYOR: çekirdek
     * (`MediaAdder::processMediaItem`) doğrulamayı medya SATIRINI
     * kaydettikten SONRA yapıyor; orada patlarsa veritabanında diskte
     * karşılığı olmayan bir medya satırı kalırdı. Aynı doğrulayıcıyı önce
     * burada koşturmak o satırın hiç doğmamasını sağlıyor ve çekirdekteki
     * ikinci çağrı zararsız tekrardır.
     *
     * @return array{content:string, mime:string, bytes:int, filename:string}
     */
    public function decode(string $contentBase64, string $clientFilename, int $menuId): array
    {
        // `strict: true` — base64 alfabesi dışında bir karakter varsa
        // `false` döner. Gevşek kipte geçersiz karakterler sessizce
        // atılır ve bozuk bir gövdeden bozuk bir dosya üretilirdi.
        $content = base64_decode(trim($contentBase64), true);

        if ($content === false || $content === '') {
            throw ApiException::validationFailed(
                'Görsel içeriği geçerli base64 değil.',
                ['field' => 'content_base64', 'reason' => 'invalid_base64'],
            );
        }

        $bytes = strlen($content);

        if ($bytes > self::MAX_BYTES) {
            throw ApiException::validationFailed(
                'Görsel en fazla 5 MB olabilir.',
                ['reason' => 'too_large', 'bytes' => $bytes, 'max_bytes' => self::MAX_BYTES],
            );
        }

        $mime = (string) (new finfo(FILEINFO_MIME_TYPE))->buffer($content);

        if (!array_key_exists($mime, self::MIME_EXTENSIONS)) {
            throw ApiException::validationFailed(
                'Yalnız JPEG, PNG ve WebP görseller yüklenebilir.',
                ['reason' => 'invalid_mime', 'mime' => $mime],
            );
        }

        $filename = $this->safeFilename($mime, $clientFilename, $menuId);

        try {
            resolve(MediaUploadValidator::class)->validateAndSanitize($filename, $content);
        } catch (ApplicationException) {
            /*
             * SÖZLEŞMEDE OLMAYAN AMA GEREKEN GEREKÇE. Çekirdek, mime'ı
             * doğru olsa bile içinde `<?php` ya da Apache yönergesi geçen
             * bir görseli reddediyor. Bu hâli 500'e bırakmak, güvenlik
             * denetiminin sunucu arızası gibi görünmesi demekti;
             * `unavailable`/`invalid_mime` demek ise yanlış teşhis
             * yazdırırdı. Alan raporlanmıştır.
             */
            throw ApiException::validationFailed(
                'Görsel içeriği güvenli bulunmadı.',
                ['reason' => 'unsafe_content', 'mime' => $mime],
            );
        }

        return ['content' => $content, 'mime' => $mime, 'bytes' => $bytes, 'filename' => $filename];
    }

    /**
     * Çözülmüş görseli ürüne bağlar ve yeni adresini döndürür.
     *
     * ESKİ GÖRSEL ÖNCE TEMİZLENİR: `thumb` tek görsellik bir etiket, ikinci
     * dosya eklendiğinde hangisinin döneceği sıralamaya kalırdı
     * (`MenuImageCommand` ile aynı gerekçe).
     *
     * @param  array{content:string, mime:string, bytes:int, filename:string}  $decoded
     */
    public function attach(Menu $menu, array $decoded): ?string
    {
        $menu->clearMediaTag(self::MEDIA_TAG);
        $menu->newMediaInstance()->addFromRaw(
            $decoded['content'],
            $decoded['filename'],
            self::MEDIA_TAG,
        );

        // Bağıntı önbelleği tazeleniyor: `media()->save()` yüklenmiş
        // koleksiyona satırı EKLEMİYOR ve tazelenmezse yeni yüklenen
        // görselin adresi yerine eskisinin (ya da `null`'ın) dönerdi.
        $menu->unsetRelation('media');

        return $this->url($menu);
    }

    /**
     * Ürünün görselini kaldırır.
     *
     * Görseli olmayan üründen görsel silmek HATA DEĞİLDİR: işlem sonuç
     * odaklıdır ve istenen son hâl (`image_url: null`) zaten geçerlidir.
     */
    public function detach(Menu $menu): void
    {
        $menu->clearMediaTag(self::MEDIA_TAG);
        $menu->unsetRelation('media');
    }

    /**
     * Ürün görselinin mutlak adresi, yoksa `null`.
     *
     * ÖLÇÜ MÜŞTERİ KATALOĞUYLA AYNI (800×600, `CatalogController::imageUrl`).
     * Panelde ayrı bir ölçü üretmek, aynı fotoğrafın diskte ikinci bir
     * küçük resmini biriktirirdi ve yöneticinin gördüğü kırpma müşterinin
     * gördüğünden farklı olurdu — "site neden böyle gösteriyor" sorusu.
     */
    public function url(Menu $menu): ?string
    {
        $thumb = $menu->getThumb(['width' => 800, 'height' => 600], self::MEDIA_TAG);

        if ($thumb === null || $thumb === '') {
            return null;
        }

        // Medya diski `APP_URL` tabanlı mutlak adres üretir. Yine de
        // göreli gelirse mutlaklaştırıyoruz: Kontrol Merkezi bir tarayıcı
        // sayfası değil, göreli adresi çözecek bir bağlamı yok.
        return str_starts_with($thumb, 'http://') || str_starts_with($thumb, 'https://')
            ? $thumb
            : url($thumb);
    }

    /**
     * Diske yazılacak ad — SUNUCUDA üretilir.
     *
     * İstemciden gelen yolu diske yazmak yol geçişi (`../`) demekti;
     * `filename` alanından yalnız UZANTI okunuyor, o da doğrulanmış
     * mime ile uyuşuyorsa. Uyuşmuyorsa mime'ın kanonik uzantısı
     * kullanılır: PNG baytlarını `.jpg` adıyla yazmak, çekirdeğin sihirli
     * bayt denetimini düşürür ve dosya ikinci adımda reddedilirdi.
     */
    private function safeFilename(string $mime, string $clientFilename, int $menuId): string
    {
        $allowed = self::MIME_EXTENSIONS[$mime];

        $claimed = strtolower(pathinfo(basename(trim($clientFilename)), PATHINFO_EXTENSION));

        $extension = in_array($claimed, $allowed, true) ? $claimed : $allowed[0];

        return sprintf('%d-%s.%s', $menuId, bin2hex(random_bytes(4)), $extension);
    }
}
