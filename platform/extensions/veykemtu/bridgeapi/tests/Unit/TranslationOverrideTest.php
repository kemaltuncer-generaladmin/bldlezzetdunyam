<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Unit;

use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;
use Veykemtu\BridgeApi\Services\TranslationAudit;

/**
 * Türkçe çeviri geçersiz kılmalarının sağlamlığı.
 *
 * Denetim mantığı `TranslationAudit` içinde ve `veykemtu:ceviri-denetle`
 * komutu da oradan besleniyor: test ile sahadaki denetim ayrışmasın.
 *
 * Veritabanı istemez — iki diziyi karşılaştırıyor.
 */
final class TranslationOverrideTest extends TestCase
{
    /** @return iterable<string, array{string, string}> */
    public static function ceviriDosyalari(): iterable
    {
        foreach ((new TranslationAudit(self::platformPath()))->translationFiles() as $adAlani => $dosyalar) {
            foreach ($dosyalar as $dosya) {
                yield $adAlani.'/'.basename($dosya) => [$adAlani, $dosya];
            }
        }
    }

    #[DataProvider('ceviriDosyalari')]
    public function test_ceviri_kaynagiyla_ortusuyor(string $adAlani, string $dosya): void
    {
        $sonuc = (new TranslationAudit(self::platformPath()))->auditFile($adAlani, $dosya);

        self::assertSame([], $sonuc['sorunlar'], sprintf(
            "[%s] çeviri denetimi başarısız:\n  - %s",
            $sonuc['dosya'],
            implode("\n  - ", $sonuc['sorunlar']),
        ));

        self::assertGreaterThan(0, $sonuc['ceviri'], 'Çeviri dosyası hiçbir kaynak anahtarla örtüşmüyor.');
    }

    /**
     * Çeviri dosyası olmayan bir ad alanı sessizce atlanmamalı.
     *
     * Bu test olmasaydı `translationFiles()` boş dönerse veri sağlayıcı
     * hiç test üretmez ve süit "yeşil" görünürdü — çeviriler tamamen
     * silinmiş olsa bile.
     */
    public function test_ceviri_dosyalari_bulunuyor(): void
    {
        self::assertNotEmpty(
            (new TranslationAudit(self::platformPath()))->translationFiles(),
            'lang/vendor/*/tr/ altında hiç çeviri dosyası yok.',
        );
    }

    private static function platformPath(): string
    {
        return dirname(__DIR__, 5);
    }
}
