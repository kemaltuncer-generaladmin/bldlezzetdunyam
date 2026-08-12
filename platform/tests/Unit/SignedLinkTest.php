<?php

declare(strict_types=1);

namespace Tests\Unit;

use Tests\TestCase;
use Veykemtu\BridgeApi\Support\SignedLink;

/**
 * Fişe basılan bağlantıların imzası — K-20.
 *
 * NEDEN `Tests\TestCase`, saf PHPUnit değil: `SignedLink` sırrı `env()` ve
 * `config()` üzerinden okuyor, yani ayağa kalkmış bir uygulama gerekiyor.
 * Veritabanına dokunmuyor, `RefreshDatabase` de yok.
 */
class SignedLinkTest extends TestCase
{
    private const string SECRET = 'test-baglanti-sirri-0123456789abcdef';

    protected function setUp(): void
    {
        parent::setUp();

        putenv('BLD_LINK_SECRET='.self::SECRET);
        $_ENV['BLD_LINK_SECRET'] = self::SECRET;
    }

    protected function tearDown(): void
    {
        putenv('BLD_LINK_SECRET');
        unset($_ENV['BLD_LINK_SECRET']);

        parent::tearDown();
    }

    public function test_uretilen_imza_dogrulanir(): void
    {
        $expires = time() + 3600;
        $signature = SignedLink::sign(SignedLink::PURPOSE_TRACK, 5012, $expires);

        $this->assertTrue(
            SignedLink::verify(SignedLink::PURPOSE_TRACK, 5012, $expires, $signature),
        );
    }

    /**
     * BAŞKA SİPARİŞE TAŞINAMAZ.
     *
     * Sipariş kimliği imzanın içinde; olmasaydı elinde tek bir geçerli
     * bağlantı olan kişi numarayı arttırarak bütün siparişleri gezerdi.
     */
    public function test_baska_siparisin_imzasi_kabul_edilmez(): void
    {
        $expires = time() + 3600;
        $signature = SignedLink::sign(SignedLink::PURPOSE_TRACK, 5012, $expires);

        $this->assertFalse(
            SignedLink::verify(SignedLink::PURPOSE_TRACK, 5013, $expires, $signature),
        );
    }

    /**
     * SÜRE UZATILAMAZ.
     *
     * Son geçerlilik anı imzanın içinde; dışarıda kalsaydı bağlantıyı okutan
     * kişi `?e=` değerini büyütüp ömrünü sonsuza çıkarabilirdi.
     */
    public function test_son_gecerlilik_degistirilirse_imza_tutmaz(): void
    {
        $expires = time() + 3600;
        $signature = SignedLink::sign(SignedLink::PURPOSE_TRACK, 5012, $expires);

        $this->assertFalse(
            SignedLink::verify(SignedLink::PURPOSE_TRACK, 5012, $expires + 86400, $signature),
        );
    }

    /**
     * AMAÇ AYRIMI: takip imzası teslim imzası yerine geçemez.
     *
     * Geçseydi, siparişini takip eden müşteri aynı imzayla siparişini
     * "teslim edildi" işaretleyebilirdi.
     */
    public function test_takip_imzasi_teslim_icin_kullanilamaz(): void
    {
        $expires = time() + 3600;
        $signature = SignedLink::sign(SignedLink::PURPOSE_TRACK, 5012, $expires);

        $this->assertFalse(
            SignedLink::verify(SignedLink::PURPOSE_DELIVER, 5012, $expires, $signature),
        );
    }

    public function test_bos_imza_reddedilir(): void
    {
        $this->assertFalse(
            SignedLink::verify(SignedLink::PURPOSE_TRACK, 5012, time() + 3600, ''),
        );
    }

    public function test_suresi_gecmis_baglanti_taninir(): void
    {
        $this->assertTrue(SignedLink::isExpired(time() - 1));
        $this->assertFalse(SignedLink::isExpired(time() + 60));
    }

    /**
     * SÜRE SİPARİŞE BAĞLI, SAATE DEĞİL.
     *
     * İleri tarihli catering siparişinde çıpa teslim anı olmalı: pazartesi
     * verilen cumartesi siparişinin teslim bağlantısı, yemek mutfaktan
     * çıkmadan ölmüş olurdu.
     */
    public function test_sure_ileri_tarihli_teslimden_sayilir(): void
    {
        $created = 1_786_000_000;
        $requested = $created + (5 * 86400);

        $this->assertSame(
            $requested + (2 * 86400),
            SignedLink::expiresAt($created, $requested, 2),
        );
    }

    /** ASAP siparişte istenen zaman yok; çıpa sipariş anı. */
    public function test_istenen_zaman_yoksa_siparis_ani_cipa_olur(): void
    {
        $created = 1_786_000_000;

        $this->assertSame(
            $created + (14 * 86400),
            SignedLink::expiresAt($created, null, 14),
        );
    }

    /**
     * Sır tanımsızsa `app.key`'e düşülür ve özellik ÇALIŞMAYA DEVAM EDER.
     *
     * BBD ucu boş sırla kapanıyor çünkü orası dışarıdan gelen bir kapı;
     * burada kapanmak yalnızca fişten iki QR'ı sessizce silerdi.
     */
    public function test_ozel_sir_yoksa_uygulama_anahtarina_dusulur(): void
    {
        putenv('BLD_LINK_SECRET');
        unset($_ENV['BLD_LINK_SECRET']);
        config(['app.key' => 'base64:'.base64_encode(str_repeat('k', 32))]);

        $this->assertTrue(SignedLink::isConfigured());
    }

    /** İki sır da boşsa imzalama kapalı — çağıranlar QR basmıyor. */
    public function test_hicbir_sir_yoksa_imzalama_kapalidir(): void
    {
        putenv('BLD_LINK_SECRET');
        unset($_ENV['BLD_LINK_SECRET']);
        config(['app.key' => '']);

        $this->assertFalse(SignedLink::isConfigured());
        $this->assertFalse(
            SignedLink::verify(SignedLink::PURPOSE_TRACK, 5012, time() + 60, 'herhangi'),
        );
    }
}
