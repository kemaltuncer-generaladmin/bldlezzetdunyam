<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use Closure;

/**
 * Hizmet alanı — nereye teslimat yapıyoruz?
 *
 * Faz 1'de yalnızca **Konya / Selçuklu** ve **Konya / Karatay**.
 *
 * NEDEN SUNUCUDA DA VAR: istemcilerdeki kilit bir kolaylıktır, kural değildir.
 * API'ye doğrudan istek atan bir şey (eski sürüm uygulama, betik, meraklı
 * kullanıcı) o kilidi görmez. Kural burada denetlenmezse hizmet vermediğimiz
 * bir ilçeye sipariş girilir, mutfağa düşer ve kurye yola çıkarken iptal
 * edilir.
 *
 * Değerler üç yerde aynıdır ve BİRLİKTE değişir:
 *   - `packages/core/lib/src/service_area.dart` (Dart istemciler)
 *   - `website/lib/service-area.ts` (web sitesi)
 *   - bu dosya (sunucu — son söz burada)
 *
 * Bölge sayısı arttığında liste veritabanına/sözleşmeye taşınmalı
 * (`docs/11-yol-haritasi.md` §bölgeler); iki ilçe için üç sabit, sözleşmeye
 * alan eklemekten ucuz.
 */
abstract class ServiceArea
{
    /** Tek il. */
    public const CITY = 'Konya';

    /** Teslimat yapılan ilçeler. */
    public const DISTRICTS = ['Selçuklu', 'Karatay'];

    /** Kutunun kenarları — `docs/00-genel-bakis.md` §hizmet alanı. */
    public const SOUTH = 37.80;
    public const NORTH = 38.10;
    public const WEST = 32.35;
    public const EAST = 32.75;

    /**
     * `city` alanı için doğrulama kuralı.
     *
     * Kurallar burada duruyor ki sipariş ucu ile adres defteri ucu aynı
     * metni ve aynı denetimi paylaşsın; ikisi ayrıştığı gün müşteri
     * defterine kaydedemediği bir adresle sipariş verebilir hâle gelirdi.
     */
    public static function cityRule(): Closure
    {
        return static function (string $attribute, mixed $value, Closure $fail): void {
            // Boş/eksik değeri `required*` kuralları yakalar; burada boş
            // geçmek gel-al siparişinde adres alanının hiç gelmemesi demek.
            if ($value === null || $value === '') {
                return;
            }

            if (!self::coversCity(is_string($value) ? $value : null)) {
                $fail('Şu an yalnızca '.self::CITY.' iline teslimat yapıyoruz.');
            }
        };
    }

    /** `district` alanı için doğrulama kuralı. */
    public static function districtRule(): Closure
    {
        return static function (string $attribute, mixed $value, Closure $fail): void {
            if ($value === null || $value === '') {
                return;
            }

            if (!self::coversDistrict(is_string($value) ? $value : null)) {
                $fail('Şu an yalnızca '.implode(' ve ', self::DISTRICTS).' ilçelerine teslimat yapıyoruz.');
            }
        };
    }

    public static function coversCity(?string $value): bool
    {
        return $value !== null && self::lower($value) === self::lower(self::CITY);
    }

    public static function coversDistrict(?string $value): bool
    {
        if ($value === null) {
            return false;
        }

        $needle = self::lower($value);

        foreach (self::DISTRICTS as $district) {
            if (self::lower($district) === $needle) {
                return true;
            }
        }

        return false;
    }

    /**
     * Nokta kutunun içinde mi? Kenarlar dahildir.
     *
     * Koordinat yoksa (`null`) sipariş yine geçerlidir: iğne isteğe bağlıdır
     * ve haritayı kullanmayan müşteri de sipariş verebilmeli.
     */
    public static function containsPoint(?float $latitude, ?float $longitude): bool
    {
        if ($latitude === null || $longitude === null) {
            return false;
        }

        return $latitude >= self::SOUTH
            && $latitude <= self::NORTH
            && $longitude >= self::WEST
            && $longitude <= self::EAST;
    }

    /**
     * Türkçe'ye duyarlı küçük harf.
     *
     * `mb_strtolower` dilden bağımsızdır ve `I` harfini `i`'ye düşürür;
     * Türkçe'de doğrusu `ı`'dır. Bugünkü iki ilçe adında fark yaratmıyor ama
     * karşılaştırmayı baştan doğru yazmak, ileride eklenecek bir ilçede
     * sessiz bir eşleşmemeden ucuz.
     */
    private static function lower(string $value): string
    {
        $normalized = str_replace(['I', 'İ'], ['ı', 'i'], trim($value));

        return mb_strtolower($normalized, 'UTF-8');
    }
}
