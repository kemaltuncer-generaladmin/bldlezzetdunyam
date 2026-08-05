<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Admin;

/**
 * Admin formundaki TL alanı ile kuruş tam sayısı arasındaki TEK geçit.
 *
 * Sistemde para her yerde `int` kuruştur (`docs/11-yol-haritasi.md` §0) ama
 * yönetici TL yazar. Bu iki dünyanın arasında bir dönüşüm noktası vardır ve
 * burasıdır — çağrı yerlerine dağıtılmaz.
 *
 * `Support\Money` ile karıştırılmamalı: o, **veritabanındaki ondalık TL**
 * ile kuruş arasındaki geçittir. Bu sınıf ise **serbest metin form girdisi**
 * ile kuruş arasındaki geçittir; ayrı bir iştir çünkü form girdisi
 * "45", "45.5", "45,50" gibi üç ayrı biçimde gelebilir.
 *
 * NEDEN FLOAT YOK: `(float) "45,50"` PHP'de 45.0'dır — virgülle yazan bir
 * yöneticinin asgari sepeti sessizce 50 kuruş eksilir. Ayrıca `round()` ile
 * yapılan çarpım, bir kuruşluk sapmaların klasik kaynağıdır. Bu yüzden
 * dönüşüm baştan sona tam sayı aritmetiğiyle yapılır.
 *
 * NEDEN FORMDA `type => number` KULLANILMIYOR: TastyIgniter'ın form parçacığı
 * (`Igniter\Admin\Widgets\Form::getSaveData`) `number` tipindeki alanı
 * postback'te `(int)` ile daraltır — "45.50" değeri kayıt öncesinde 45'e
 * düşer ve kuruşlar tamamen kaybolur. Alanlar bu yüzden `text` tipindedir.
 */
final class LiraField
{
    private function __construct() {}

    /**
     * Form girdisini kuruşa çevirir.
     *
     * Kabul edilen biçimler: `45`, `45.5`, `45,50`, ` 45,50 `.
     * Boş girdi 0 kuruştur. İkiden fazla ondalık basamak yarım-yukarı
     * yuvarlanır (`0,455` → 46 kuruş).
     */
    public static function toKurus(mixed $input): int
    {
        $text = trim(str_replace(["\u{00A0}", ' '], '', (string) $input));

        if ($text === '') {
            return 0;
        }

        $negative = str_starts_with($text, '-');

        // Son görülen ayıraç ondalık ayıracıdır; öncekiler binlik ayıracıdır
        // ve atılır. Bu kural hem "1.250,75" hem "1,250.75" için doğrudur.
        $lastSeparator = max(strrpos($text, ','), strrpos($text, '.'));

        if ($lastSeparator === false) {
            $whole = self::digitsOf($text);
            $fraction = '';
        } else {
            $whole = self::digitsOf(substr($text, 0, $lastSeparator));
            $fraction = self::digitsOf(substr($text, $lastSeparator + 1));
        }

        // Üçüncü basamak yalnızca yuvarlama için okunur.
        $fraction = substr($fraction.'000', 0, 3);

        $kurus = (int) ($whole === '' ? '0' : $whole) * 100
            + intdiv((int) $fraction + 5, 10);

        return $negative ? -$kurus : $kurus;
    }

    /**
     * Kuruşu form kutusuna yazılacak metne çevirir: `4550` → `"45.50"`.
     *
     * Ondalık ayıracı **nokta**dır. Sebep: aynı metin doğrulama kuralından
     * ve `toKurus()`'tan geri geçecek; iki yönde de aynı biçimi kullanmak
     * "kaydet → aç → kaydet" turunda değerin kaymadığını garanti eder.
     */
    public static function toInput(int $kurus): string
    {
        $sign = $kurus < 0 ? '-' : '';
        $absolute = abs($kurus);

        return $sign
            .intdiv($absolute, 100)
            .'.'
            .str_pad((string) ($absolute % 100), 2, '0', STR_PAD_LEFT);
    }

    private static function digitsOf(string $text): string
    {
        return preg_replace('/\D/', '', $text) ?? '';
    }
}
