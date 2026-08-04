<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Support;

/**
 * Kuruş ↔ TL dönüşümü.
 *
 * Sözleşme parayı **kuruş cinsinden tam sayı** olarak taşır
 * (`docs/03-api-sozlesmesi.md` §1.3): `4550` = 45,50 TL. TastyIgniter ise
 * veritabanında ondalık saklar. Bu sınıf iki dünya arasındaki tek geçittir.
 *
 * NEDEN TEK YER: dönüşümü çağrı yerlerine dağıtmak, birinde `round`
 * unutulduğunda 1 kuruşluk sapmalar üretir ve sipariş toplamı kalemlerin
 * toplamını tutmaz. Bunu üretimde yakalamak çok pahalıdır.
 */
final class Money
{
    private function __construct() {}

    /** Veritabanındaki ondalık TL değerini kuruşa çevirir. */
    public static function toKurus(mixed $decimal): int
    {
        return (int) round(((float) $decimal) * 100);
    }

    /** Kuruşu veritabanına yazılacak ondalık TL değerine çevirir. */
    public static function toDecimal(int $kurus): float
    {
        return $kurus / 100;
    }
}
