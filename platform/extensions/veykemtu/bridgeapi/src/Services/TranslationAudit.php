<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

/**
 * Türkçe çeviri geçersiz kılmalarını İngilizce kaynaklarıyla karşılaştırır.
 *
 * NEDEN GEREKLİ: çeviri dosyaları SESSİZCE bozulur. Yanlış yazılmış bir
 * anahtar hata vermez, sadece hiç kullanılmaz; panelde İngilizce kalır ve
 * kimse sebebini anlamaz. Eksik bir `%s` ise çalışma anında `sprintf`'i
 * patlatır ve bunu ilk gören yönetici olur.
 *
 * Hem `TranslationOverrideTest` hem de `veykemtu:ceviri-denetle` komutu
 * buradan besleniyor: kural tek yerde dursun, test ile sahadaki denetim
 * ayrışmasın.
 */
final class TranslationAudit
{
    /**
     * Dizin adı → çeviri kaynağının bulunduğu paket.
     *
     * DİZİN ADINDA NOKTA DEĞİL TİRE VAR ve bu şart. Çeviri ad alanları
     * `igniter.cart` biçiminde ama TastyIgniter Laravel'in geçersiz kılma
     * çözümlemesini değiştirmiş: `Flame\Translation\FileLoader` noktayı
     * `/` ya da `-` yapıp altı aday yola bakıyor, `igniter.cart` dizinine
     * HİÇ BAKMIYOR.
     *
     * Sahada yaşandı: dosyalar `lang/vendor/igniter.cart/tr/` altına
     * yazıldı, denetim "sorun yok" dedi, panel İngilizce kaldı. Denetimin
     * yeşil yanması dosyanın YÜKLENDİĞİ anlamına gelmiyordu.
     *
     * Tire biçimi seçildi; `/` biçimi (`vendor/igniter/cart/`) çekirdeğin
     * `vendor/igniter/` ağacının içine gömülüp oraya aitmiş gibi görünür.
     *
     * Eşlemesi olmayan bir `tr` dizini SORUN sayılır — yazım hatasının
     * (örneğin noktalı biçime geri dönmenin) tek belirtisi budur.
     *
     * @var array<string, string>
     */
    public const array PACKAGES = [
        'igniter' => 'core',
        'igniter-cart' => 'ti-ext-cart',
        'igniter-local' => 'ti-ext-local',
        'igniter-user' => 'ti-ext-user',
        'igniter-payregister' => 'ti-ext-payregister',
        'igniter-coupons' => 'ti-ext-coupons',
        'igniter-reservation' => 'ti-ext-reservation',
        'igniter-automation' => 'ti-ext-automation',
        'igniter-api' => 'ti-ext-api',
        'igniter-pages' => 'ti-ext-pages',
        'igniter-frontend' => 'ti-ext-frontend',
        'igniter-socialite' => 'ti-ext-socialite',
        'igniter-broadcast' => 'ti-ext-broadcast',
    ];

    public function __construct(private readonly string $platformPath) {}

    /**
     * Her çeviri dosyası için bir rapor satırı döner.
     *
     * @return list<array{dosya: string, kaynak: int, ceviri: int, sorunlar: list<string>}>
     */
    public function run(): array
    {
        $rapor = [];

        foreach ($this->translationFiles() as $adAlani => $dosyalar) {
            foreach ($dosyalar as $tr) {
                $rapor[] = $this->auditFile($adAlani, $tr);
            }
        }

        return $rapor;
    }

    /**
     * `lang/vendor/<ad-alani>/tr/*.php` dosyaları.
     *
     * @return array<string, list<string>>
     */
    public function translationFiles(): array
    {
        $bulunan = [];

        foreach (glob($this->platformPath.'/lang/vendor/*/tr/*.php') ?: [] as $yol) {
            $bulunan[basename(dirname($yol, 2))][] = $yol;
        }

        return $bulunan;
    }

    /**
     * @return array{dosya: string, kaynak: int, ceviri: int, sorunlar: list<string>}
     */
    public function auditFile(string $adAlani, string $trDosyasi): array
    {
        $kisaAd = $adAlani.'/'.basename($trDosyasi);

        if (!array_key_exists($adAlani, self::PACKAGES)) {
            return $this->fail($kisaAd, sprintf('Ad alanı [%s] eşlenmemiş; PACKAGES listesine ekleyin.', $adAlani));
        }

        $enDosyasi = sprintf(
            '%s/vendor/tastyigniter/%s/resources/lang/en/%s',
            $this->platformPath,
            self::PACKAGES[$adAlani],
            basename($trDosyasi),
        );

        if (!is_file($enDosyasi)) {
            return $this->fail($kisaAd, 'İngilizce kaynağı yok — dosya adı ya da ad alanı yanlış.');
        }

        $kaynak = $this->flatten((array) require $enDosyasi);
        $ceviri = $this->flatten((array) require $trDosyasi);

        $sorunlar = [];

        // ÖLÜ ANAHTAR: kaynakta karşılığı olmayan çeviri hiçbir zaman
        // gösterilmez. Yazım hatasının tek belirtisi budur.
        foreach (array_keys(array_diff_key($ceviri, $kaynak)) as $olu) {
            $sorunlar[] = sprintf('ölü anahtar: %s', $olu);
        }

        foreach ($ceviri as $anahtar => $metin) {
            if (!isset($kaynak[$anahtar]) || !is_string($metin) || !is_string($kaynak[$anahtar])) {
                continue;
            }

            $sorunlar = [...$sorunlar, ...$this->placeholderProblems((string) $anahtar, $kaynak[$anahtar], $metin)];
        }

        return [
            'dosya' => $kisaAd,
            'kaynak' => count($kaynak),
            'ceviri' => count(array_intersect_key($ceviri, $kaynak)),
            'sorunlar' => $sorunlar,
        ];
    }

    /**
     * Dosya gerçekten YÜKLENİYOR mu?
     *
     * Statik karşılaştırma dosyanın doğru yazıldığını gösterir, çevirmenin
     * onu bulduğunu göstermez. Sahada tam bu boşluğa düşüldü: dizin adı
     * yanlıştı, denetim "sorun yok" dedi, panel İngilizce kaldı.
     *
     * Bir anahtarı `tr` yereliyle çevirtip beklenen değerle karşılaştırıyor.
     * Laravel uygulaması gerektirir; bu yüzden konsol komutundan çağrılıyor,
     * saf birim testinden değil.
     *
     * @return list<string> boşsa yükleniyor
     */
    public function loadProblems(string $dizin, string $trDosyasi): array
    {
        $adAlani = str_replace('-', '.', $dizin);
        $grup = basename($trDosyasi, '.php');
        $ceviri = $this->flatten((array) require $trDosyasi);

        foreach ($ceviri as $anahtar => $beklenen) {
            if (!is_string($beklenen) || $beklenen === '') {
                continue;
            }

            $gelen = trans($adAlani.'::'.$grup.'.'.$anahtar, [], 'tr');

            return $gelen === $beklenen ? [] : [sprintf(
                'dosya YÜKLENMİYOR — "%s" anahtarı "%s" yerine "%s" dönüyor. '
                .'Dizin adı çevirmenin baktığı biçimde mi? (nokta değil tire)',
                $anahtar,
                $beklenen,
                is_string($gelen) ? $gelen : gettype($gelen),
            )];
        }

        return [];
    }

    /** @return list<string> */
    private function placeholderProblems(string $anahtar, string $kaynak, string $ceviri): array
    {
        $sorunlar = [];

        foreach (['%s', '%d'] as $tutucu) {
            if (substr_count($kaynak, $tutucu) !== substr_count($ceviri, $tutucu)) {
                $sorunlar[] = sprintf('%s: "%s" sayısı değişmiş', $anahtar, $tutucu);
            }
        }

        if ($this->namedPlaceholders($kaynak) !== $this->namedPlaceholders($ceviri)) {
            $sorunlar[] = sprintf('%s: adlandırılmış yer tutucular değişmiş', $anahtar);
        }

        return $sorunlar;
    }

    /**
     * `:name` gibi adlandırılmış yer tutucular.
     *
     * Sıralanıyor: Türkçe söz dizimi yüzünden yer değiştirmeleri normal,
     * kaybolmaları değil.
     *
     * @return list<string>
     */
    private function namedPlaceholders(string $metin): array
    {
        preg_match_all('/:[a-z_]+/', $metin, $eslesme);
        $tutucular = $eslesme[0];
        sort($tutucular);

        return $tutucular;
    }

    /**
     * İç içe diziyi `a.b.c` biçiminde tek düzeye indirir.
     *
     * @param  array<mixed>  $dizi
     * @return array<string, mixed>
     */
    private function flatten(array $dizi, string $onek = ''): array
    {
        $sonuc = [];

        foreach ($dizi as $anahtar => $deger) {
            $tam = $onek === '' ? (string) $anahtar : $onek.'.'.$anahtar;

            if (is_array($deger)) {
                $sonuc += $this->flatten($deger, $tam);

                continue;
            }

            $sonuc[$tam] = $deger;
        }

        return $sonuc;
    }

    /**
     * @return array{dosya: string, kaynak: int, ceviri: int, sorunlar: list<string>}
     */
    private function fail(string $kisaAd, string $sebep): array
    {
        return ['dosya' => $kisaAd, 'kaynak' => 0, 'ceviri' => 0, 'sorunlar' => [$sebep]];
    }
}
