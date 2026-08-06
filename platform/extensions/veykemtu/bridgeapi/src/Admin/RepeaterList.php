<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Admin;

/**
 * Tek metinli `repeater` alanı ile düz metin listesi arasında çeviri.
 *
 * ## Neden gerekli?
 *
 * `Igniter\Admin\FormWidgets\Repeater` her satırı bir DİZİ olarak okur ve
 * yazar: tek alanlı bir tekrarlayıcı bile `[['text' => 'Ofisler'], …]`
 * üretir. Oysa `audience`, `benefits` ve `quote_needs` alanlarının doğal
 * biçimi düz bir metin listesidir (`['Ofisler', …]`) — `SiteContentRepository`
 * paketi bu biçimde yayınlıyor ve site (`website/content/services.ts`,
 * `readonly string[]`) bu biçimi bekliyor.
 *
 * ## Neden çeviri FORM SINIRINDA, veritabanında değil?
 *
 * İki seçenek vardı: (a) satır biçimini olduğu gibi saklayıp okuma anında
 * düzleştirmek, (b) düz saklayıp form sınırında satıra çevirmek. (b) seçildi,
 * çünkü (a) bir arayüz bileşeninin veri biçimini belirlemesi demekti: yarın
 * tekrarlayıcıdan vazgeçilse veritabanında sebebi anlaşılmayan `{"text": …}`
 * sarmalayıcıları kalırdı. Bir içe aktarma komutu veya elle yazılan bir
 * satırın da bu sarmalayıcıyı bilmesi gerekmezdi.
 */
final class RepeaterList
{
    /** Tekrarlayıcı satırındaki tek alanın adı. */
    public const string FIELD = 'text';

    private function __construct() {}

    /**
     * Veritabanı biçimi → form biçimi.
     *
     * @param  mixed  $values  düz metin listesi (veya zaten satır biçiminde veri)
     * @return list<array{text: string}>
     */
    public static function toRows(mixed $values): array
    {
        if (! is_array($values)) {
            return [];
        }

        $rows = [];
        foreach ($values as $value) {
            // Zaten satır biçiminde gelen veri olduğu gibi kabul ediliyor:
            // form doğrulama hatasıyla yeniden çizildiğinde model üzerindeki
            // değer bir kez daha bu metottan geçebiliyor ve ikinci sarmalama
            // satırları boş gösterirdi.
            $text = is_array($value) ? ($value[self::FIELD] ?? '') : $value;

            if (is_scalar($text) && trim((string) $text) !== '') {
                $rows[] = [self::FIELD => trim((string) $text)];
            }
        }

        return $rows;
    }

    /**
     * Form biçimi → veritabanı biçimi.
     *
     * Boş satırlar düşürülür: tekrarlayıcıda "ekle"ye basıp doldurmadan
     * kaydetmek sık olur ve boş bir madde sitede boş bir madde işareti çizerdi.
     *
     * @param  mixed  $rows  tekrarlayıcının gönderdiği satırlar
     * @return list<string>
     */
    public static function toValues(mixed $rows): array
    {
        if (! is_array($rows)) {
            return [];
        }

        $values = [];
        foreach ($rows as $row) {
            $text = is_array($row) ? ($row[self::FIELD] ?? '') : $row;

            if (is_scalar($text) && trim((string) $text) !== '') {
                $values[] = trim((string) $text);
            }
        }

        return $values;
    }
}
