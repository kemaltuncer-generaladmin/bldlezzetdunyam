<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

use DOMDocument;
use DOMElement;
use DOMNode;
use LibXMLError;

/**
 * Zengin metin editöründen gelen HTML'i izin listesine göre temizler.
 *
 * ## Neden gerekli?
 *
 * Panelde içerik yazan kişi kötü niyetli olmasa bile üç şey oluyor:
 *
 * 1. **Word/Google Docs yapıştırması** yüzlerce satır `style="..."`,
 *    `<span class="Apple-...">` ve `<o:p>` taşır. Sitede tasarım sistemi
 *    dışına çıkan yazı tipleri ve renkler belirir; sayfa "bozuk" görünür.
 * 2. **`<script>` / `onerror=`** — yönetici hesabı ele geçirilirse veya
 *    içerik bir yerden kopyalanırsa siteye kod enjekte edilebilir.
 * 3. **Yarım etiket** kalırsa sayfanın kalanı bozulur.
 *
 * Bu yüzden HTML'i olduğu gibi saklamıyoruz: KAYIT ANINDA temizliyoruz.
 * Okuma anında değil — okuma her istekte olur, kayıt nadiren; ayrıca
 * veritabanında zaten temiz veri durması, siteyi tek savunma hattı olmaktan
 * çıkarır.
 *
 * ## İzin listesi, yasak listesi değil
 *
 * Yasaklanacakları saymak kaybedilen bir yarıştır (`<svg onload>`,
 * `javascript:` şemaları, veri URI'leri…). Sadece bilinen-iyi etiket ve
 * öznitelikler geçer; geri kalan ETİKET SİLİNİR AMA İÇİNDEKİ METİN KORUNUR
 * — yöneticinin yazdığı cümle kaybolmaz, yalnızca biçimi düşer.
 */
final class HtmlSanitizer
{
    /**
     * Geçmesine izin verilen etiketler.
     *
     * Tasarım sistemiyle çakışanlar bilinçli olarak YOK:
     * `<font>`, `<style>`, `<div>` (düzen kırar), `<table>` (mobilde taşar —
     * tablo gerekiyorsa yapılandırılmış alan kullanılmalı), `<img>` (görsel
     * yönetimi ayrı bir iş; gövdeye gömülen dış URL kırık görsel bırakır).
     *
     * @var array<string, list<string>> etiket => izinli öznitelikler
     */
    private const array ALLOWED = [
        'p' => [],
        'br' => [],
        'strong' => [],
        'b' => [],
        'em' => [],
        'i' => [],
        'u' => [],
        'h2' => [],
        'h3' => [],
        'h4' => [],
        'ul' => [],
        'ol' => [],
        'li' => [],
        'blockquote' => [],
        'a' => ['href', 'title'],
        'hr' => [],
    ];

    /** `href` içinde kabul edilen şemalar. */
    private const array ALLOWED_SCHEMES = ['http', 'https', 'mailto', 'tel'];

    private function __construct() {}

    public static function clean(?string $html): string
    {
        $html = trim((string) $html);
        if ($html === '') {
            return '';
        }

        $document = new DOMDocument('1.0', 'UTF-8');

        /*
         * Ayrıştırıcı uyarıları bastırılıyor: editörden gelen HTML parçası
         * gövdesiz/başlıksız olduğu için libxml her seferinde uyarı üretir
         * ve bunlar sunucu günlüğünü doldurur. Gerçek hatalar zaten
         * `loadHTML` dönüşünde yakalanıyor.
         */
        $previous = libxml_use_internal_errors(true);

        // `mb_encode_numericentity` yerine meta etiketi: DOMDocument girdiyi
        // varsayılan olarak ISO-8859-1 sayar ve Türkçe karakterler bozulur.
        $loaded = $document->loadHTML(
            '<?xml encoding="UTF-8"><div id="kok">'.$html.'</div>',
            LIBXML_HTML_NOIMPLIED | LIBXML_HTML_NODEFDTD,
        );

        /** @var list<LibXMLError> $errors */
        $errors = libxml_get_errors();
        libxml_clear_errors();
        libxml_use_internal_errors($previous);

        if (! $loaded) {
            // Ayrıştırılamayan girdi tamamen düşürülür: yarım HTML kaydetmek
            // sayfanın kalanını bozar. Hata sayısı günlüğe yazılır.
            return '';
        }
        unset($errors);

        $root = $document->getElementById('kok');
        if (! $root instanceof DOMElement) {
            return '';
        }

        self::cleanNode($root);

        $output = '';
        foreach ($root->childNodes as $child) {
            $output .= $document->saveHTML($child);
        }

        return trim($output);
    }

    /** Düğümü ve alt ağacını yerinde temizler. */
    private static function cleanNode(DOMNode $node): void
    {
        // Sondan başa geziliyor: temizlik sırasında düğüm silindiğinde
        // `childNodes` canlı listesi kayar ve baştan giden döngü öğe atlar.
        for ($i = $node->childNodes->length - 1; $i >= 0; $i--) {
            $child = $node->childNodes->item($i);
            if (! $child instanceof DOMNode) {
                continue;
            }

            if ($child->nodeType === XML_TEXT_NODE) {
                continue;
            }

            if (! $child instanceof DOMElement) {
                // Yorum, CDATA, işlem talimatı — hiçbiri içerikte olmamalı.
                $node->removeChild($child);

                continue;
            }

            $tag = strtolower($child->nodeName);

            if (! array_key_exists($tag, self::ALLOWED)) {
                self::cleanNode($child);
                self::unwrap($child);

                continue;
            }

            self::stripAttributes($child, self::ALLOWED[$tag]);
            self::cleanNode($child);
        }
    }

    /**
     * Etiketi kaldırır, çocuklarını yerine koyar.
     *
     * Silmek yerine açmanın sebebi: `<div>Merhaba</div>` içindeki "Merhaba"
     * yöneticinin yazdığı metindir. Etiketle birlikte silinseydi, kaydet'e
     * bastığında yazısının bir kısmının kaybolduğunu görürdü.
     */
    private static function unwrap(DOMElement $element): void
    {
        $parent = $element->parentNode;
        if ($parent === null) {
            return;
        }

        while ($element->firstChild !== null) {
            $parent->insertBefore($element->firstChild, $element);
        }

        $parent->removeChild($element);
    }

    /** @param  list<string>  $allowed */
    private static function stripAttributes(DOMElement $element, array $allowed): void
    {
        for ($i = $element->attributes->length - 1; $i >= 0; $i--) {
            $attribute = $element->attributes->item($i);
            if ($attribute === null) {
                continue;
            }

            $name = strtolower($attribute->nodeName);

            if (! in_array($name, $allowed, true)) {
                $element->removeAttribute($attribute->nodeName);

                continue;
            }

            if ($name === 'href' && ! self::isSafeUrl($attribute->nodeValue)) {
                $element->removeAttribute($attribute->nodeName);
            }
        }

        // Dış bağlantılar yeni sekmede ve `noopener` ile açılır: aksi hâlde
        // hedef sayfa `window.opener` üzerinden bizim sayfamızı yönlendirebilir.
        if (strtolower($element->nodeName) === 'a' && $element->hasAttribute('href')) {
            $href = (string) $element->getAttribute('href');
            if (str_starts_with($href, 'http')) {
                $element->setAttribute('rel', 'noopener noreferrer');
                $element->setAttribute('target', '_blank');
            }
        }
    }

    private static function isSafeUrl(?string $url): bool
    {
        $url = trim((string) $url);
        if ($url === '') {
            return false;
        }

        // Site içi göreli bağlantı (`/hizmetler`, `#bolum`).
        if (str_starts_with($url, '/') || str_starts_with($url, '#')) {
            return true;
        }

        $scheme = strtolower((string) parse_url($url, PHP_URL_SCHEME));

        return in_array($scheme, self::ALLOWED_SCHEMES, true);
    }
}
