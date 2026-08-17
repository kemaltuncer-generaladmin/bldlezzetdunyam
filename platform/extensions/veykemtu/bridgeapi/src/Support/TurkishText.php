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
    /**
     * SMS gövdesini GSM-7'ye indiren harf eşlemesi.
     *
     * Türkçeye özgü harflerin yanında Word/mobil klavyelerin sessizce
     * ürettiği tipografik işaretler de var: tek bir kıvrık kesme işareti
     * ("müşterimizin" değil "müşterimiz’in") mesajın tamamını UCS-2'ye
     * düşürmeye yeter ve kimse sebebini metne bakarak bulamaz.
     *
     * @var array<string, string>
     */
    private const array GSM7_MAP = [
        'ç' => 'c', 'Ç' => 'C',
        'ğ' => 'g', 'Ğ' => 'G',
        'ı' => 'i', 'İ' => 'I',
        'ö' => 'o', 'Ö' => 'O',
        'ş' => 's', 'Ş' => 'S',
        'ü' => 'u', 'Ü' => 'U',
        'â' => 'a', 'Â' => 'A',
        'î' => 'i', 'Î' => 'I',
        'û' => 'u', 'Û' => 'U',
        '’' => "'", '‘' => "'",
        '“' => '"', '”' => '"',
        '–' => '-', '—' => '-',
        '…' => '...',
        ' ' => ' ',
    ];

    public static function lower(string $value): string
    {
        // Nokta ÖNCE kaldırılıyor: `mb_strtolower` `İ`'yi "i + birleşen
        // nokta" (U+0307) hâline getirir ve sonuç görsel olarak aynı ama
        // bayt bayt farklı bir dizedir; karşılaştırma sessizce başarısız olur.
        $normalized = str_replace(['I', 'İ'], ['ı', 'i'], trim($value));

        return mb_strtolower($normalized, 'UTF-8');
    }

    /**
     * SMS gövdesini tek baytlık alfabeye indirir — B1.
     *
     * ═════════════════════════════════════════════════════════════════════
     * NEDEN: BU DOĞRUDAN PARADIR.
     *
     * GSM-7 alfabesinin dışına çıkan TEK bir karakter, mesajın TAMAMINI
     * UCS-2'ye düşürür ve segment başına karakter 160'tan 70'e iner (çoklu
     * segmentte 153 → 67). Yani "Sayın Ayşe" yazan 150 karakterlik bir
     * şablon tek segment yerine üç segment gider: maliyet üçe katlanır ve
     * bunu gösteren tek yer ay sonundaki faturadır.
     * ═════════════════════════════════════════════════════════════════════
     *
     * ŞABLON VERİTABANINDA DÜZGÜN TÜRKÇE DURUR, İNDİRGEME GÖNDERİM ANINDA
     * OLUR. Yönetici panelde "Sayın {customer_name}, siparişiniz alındı."
     * yazar ve öyle görür; müşterinin telefonuna "Sayin …" düşer. Metni
     * kaynağında bozsaydık, panel her düzenlemede kendi yazdığından farklı
     * bir metin gösterir ve yönetici düzeltmeye çalıştıkça bozardı.
     *
     * `Ç`, `Ö`, `ö`, `Ü`, `ü` ASLINDA GSM-7 TABLOSUNDA VARDIR ve teknik
     * olarak korunabilirlerdi. Yine de eşlenmişlerdir: korunsalardı bir
     * mesajın maliyeti "hangi Türkçe harf geçiyor" sorusuna bağlanırdı —
     * "Gülşen" iki segment, "Gülöz" bir segment. Tek bir kural
     * ("Türkçeye özgü harfler ASCII'ye iner") hem öngörülebilir hem de
     * sağlayıcının karakter kümesi yorumundan bağımsızdır.
     */
    public static function toGsm7(string $value): string
    {
        return strtr($value, self::GSM7_MAP);
    }
}
