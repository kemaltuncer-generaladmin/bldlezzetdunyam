<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Support;

/**
 * Türkçeye duyarlı metin işlemleri.
 *
 * NEDEN VAR: `mb_strtolower` DİLDEN BAĞIMSIZDIR ve `I` harfini `i`'ye
 * düşürür; Türkçede doğrusu `ı`'dır. `İ` de simetrik olarak `i` olmalıdır.
 * Bu iki harf mahalle ve ilçe adlarının yarısında geçiyor:
 *
 *   - "İSTASYON" ile "istasyon" ayrı iki önbellek satırı açar ve ikisi de
 *     sağlayıcıya gider (`docs/03` §13.5).
 *   - "KARATAY" ile "Karatay" ayrı iki ilçe sayılır ve biri hizmet alanı
 *     denetiminden geçemez.
 *
 * Ders `ServiceArea` içinde bir kez öğrenildi; ikinci tüketici (adres
 * önbelleği) çıkınca kural buraya taşındı — iki kopya, ikisinin ayrıştığı
 * gün sessiz bir eşleşmeme demek.
 */
abstract class TurkishText
{
    public static function lower(string $value): string
    {
        // Nokta ÖNCE kaldırılıyor: `mb_strtolower` `İ`'yi "i + birleşen
        // nokta" (U+0307) hâline getirir ve sonuç görsel olarak aynı ama
        // bayt bayt farklı bir dizedir; karşılaştırma sessizce başarısız olur.
        $normalized = str_replace(['I', 'İ'], ['ı', 'i'], trim($value));

        return mb_strtolower($normalized, 'UTF-8');
    }
}
