<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Admin;

/**
 * Marka renginin erişilebilirlik denetimi.
 *
 * ## Neden sunucuda doğruluyoruz?
 *
 * Ana marka rengi panelden seçilebilir hâle geldi. Bu güzel bir özgürlük ama
 * tehlikeli: yönetici açık sarı bir turuncu seçtiğinde butonların üstündeki
 * beyaz yazı okunamaz olur ve site erişilebilirlik gerekliliğini (docs/06 §5,
 * "kontrast AA") sessizce kaybeder. Kimse fark etmez, çünkü rengi seçen kişi
 * kontrast oranı hesaplamaz.
 *
 * Bu yüzden renk KAYDEDİLMEDEN ÖNCE ölçülüyor. Geçmeyen renk reddediliyor ve
 * yöneticiye sebebi söyleniyor — "kaydedildi ama site bozuldu" durumundan
 * çok daha iyi.
 *
 * ## Hangi oran?
 *
 * Butonun dolgusu bu renk, üstündeki etiket beyaz. WCAG 2.1 normal boyut
 * metin için 4,5:1 ister. Sitenin mevcut birincil rengi (#C2410C) 5,18:1
 * veriyor; eşiği oradan değil standarttan alıyoruz.
 */
final class BrandGuard
{
    /** WCAG 2.1 AA — normal boyut metin. */
    public const float MIN_CONTRAST = 4.5;

    private function __construct() {}

    /**
     * Renk beyaz metinle AA'yı geçiyor mu?
     *
     * @param  string  $hex  `#RRGGBB` biçiminde
     */
    public static function passesOnWhiteText(string $hex): bool
    {
        return self::contrast($hex, '#FFFFFF') >= self::MIN_CONTRAST;
    }

    /** İki renk arasındaki WCAG kontrast oranı (1–21). */
    public static function contrast(string $first, string $second): float
    {
        $a = self::relativeLuminance($first);
        $b = self::relativeLuminance($second);

        if ($a === null || $b === null) {
            // Ayrıştırılamayan renk "geçti" sayılmamalı: 0 döndürmek eşiğin
            // altında kalmasını ve reddedilmesini sağlar.
            return 0.0;
        }

        $lighter = max($a, $b);
        $darker = min($a, $b);

        return ($lighter + 0.05) / ($darker + 0.05);
    }

    /** Geçersiz girdide `null`. */
    private static function relativeLuminance(string $hex): ?float
    {
        $hex = ltrim(trim($hex), '#');

        // Kısa biçim (#F80) da kabul ediliyor: renk seçici bazen böyle üretir.
        if (strlen($hex) === 3) {
            $hex = $hex[0].$hex[0].$hex[1].$hex[1].$hex[2].$hex[2];
        }

        if (! preg_match('/^[0-9a-fA-F]{6}$/', $hex)) {
            return null;
        }

        $channels = [];
        foreach ([0, 2, 4] as $offset) {
            $value = hexdec(substr($hex, $offset, 2)) / 255;
            $channels[] = $value <= 0.03928
                ? $value / 12.92
                : (($value + 0.055) / 1.055) ** 2.4;
        }

        return 0.2126 * $channels[0] + 0.7152 * $channels[1] + 0.0722 * $channels[2];
    }
}
