<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Tests\Feature;

use Tests\KitchenTestCase;
use Veykemtu\BridgeApi\Services\Geocoding\FakeGeocoder;
use Veykemtu\BridgeApi\Services\Geocoding\Geocoder;

/**
 * Akıllı adres — `docs/openapi.yaml` §/addresses/suggest, §/addresses/reverse.
 *
 * BU DOSYANIN KİLİTLEDİĞİ DÖRT KARAR:
 *
 *  1. **Sağlayıcı arızası sipariş akışını DURDURMAZ.** Geocoder çöktüğünde
 *     uç `200` + boş liste döner. `5xx` dönseydi dışarıdaki bir servisin
 *     bizim ödeme ekranımızı kapatabilmesi demek olurdu; oysa adres elle de
 *     yazılabiliyor. En kolay "iyileştirme" bu davranışı bozmaktır —
 *     `try/catch`'i kaldırıp istisnayı yukarı bırakmak yeter.
 *  2. **Hizmet alanı dışındaki aday LİSTEYE HİÇ GİRMEZ.** "Teslimat yok"
 *     diye işaretlenip gösterilmez: müşteriye seçebileceğini sandığı bir
 *     satır gösterip ödeme ekranında reddetmek, o satırı hiç göstermemekten
 *     daha kötüdür. Eleme hem kutuya hem ilçe adına bakar — kutu, Meram'ı da
 *     içine alan kaba bir dikdörtgen.
 *  3. **Ters geocoding isteğin KENDİ noktasını döndürür.** Sağlayıcının
 *     oturttuğu (snap) nokta yazılsaydı iğne kullanıcının parmağının
 *     altından kayardı.
 *  4. **Yapılandırılmış alanlar siparişe KOPYALANIR.** Sipariş adresi
 *     deftere bağlanmıyor; müşteri daire numarasını sonradan düzeltse bile
 *     teslim edilmiş siparişin kâğıdı değişmemeli.
 *
 * SAHTE SÜRÜCÜYLE, `Http::fake()` İLE DEĞİL: sahte HTTP yanıtı yazmak
 * Nominatim'in gövde biçimini bu dosyaya kopyalar ve sürücü değiştiği gün
 * (docs/11 §F2-01 Google Places'i planlıyor) testler sağlayıcıya göre
 * yeniden yazılmak zorunda kalır. Burada doğrulanan şey uygulama davranışı:
 * eleme, önbellek, hata yutma, kopyalama.
 */
class AddressSuggestTest extends KitchenTestCase
{
    /** Konya / Selçuklu — hizmet alanı kutusunun içinde gerçek bir nokta. */
    private const float LAT = 37.8901234;

    private const float LNG = 32.4876543;

    private FakeGeocoder $geocoder;

    protected function setUp(): void
    {
        parent::setUp();

        // Sürücü konteynere bağlanıyor; `AddressLookup` ve denetleyici
        // sürücüyü tanımıyor — geçiş noktası tek satır.
        $this->geocoder = new FakeGeocoder;
        $this->app->instance(Geocoder::class, $this->geocoder);
    }

    // ── Öneri ─────────────────────────────────────────────────────────────

    public function test_oneri_doner_ve_satiri_sunucu_kurar(): void
    {
        $this->geocoder->willReturn([FakeGeocoder::candidate()]);

        $response = $this->asCustomer()
            ->getJson('/api/addresses/suggest?q=Feritpaşa', self::HEADERS);

        $response->assertOk();
        $response->assertJsonCount(1, 'data');

        // `line1` ile `label` AYNI ŞEY DEĞİL: label ilçe ve ili de içerir,
        // line1 içermez (formda onlar ayrı kutular).
        $this->assertSame('Feritpaşa Mah. Kültür Sk. No:12', $response->json('data.0.line1'));
        $this->assertSame(
            'Feritpaşa Mah. Kültür Sk. No:12, Selçuklu / Konya',
            $response->json('data.0.label'),
        );
        $this->assertSame('Feritpaşa Mah.', $response->json('data.0.neighbourhood'));
        $this->assertSame('Selçuklu', $response->json('data.0.district'));
        $this->assertSame('Konya', $response->json('data.0.city'));
        $this->assertSame('fake', $response->json('data.0.source'));

        // Sözleşme: öneride koordinat ASLA null olamaz — istemci her satırda
        // iğneyi güvenle yerleştirebilmeli.
        $this->assertNotNull($response->json('data.0.latitude'));
        $this->assertNotNull($response->json('data.0.longitude'));
    }

    public function test_kutu_disindaki_aday_elenir(): void
    {
        $this->geocoder->willReturn([
            FakeGeocoder::candidate(),
            // Ankara / Çankaya: geçerli bir koordinat ama teslimat yok.
            FakeGeocoder::candidate(
                neighbourhood: 'Kızılay Mah.',
                district: 'Çankaya',
                city: 'Ankara',
                latitude: 39.9208,
                longitude: 32.8541,
            ),
        ]);

        $response = $this->asCustomer()
            ->getJson('/api/addresses/suggest?q=Kızılay', self::HEADERS);

        $response->assertOk();
        $response->assertJsonCount(1, 'data');
        $this->assertSame('Selçuklu', $response->json('data.0.district'));
    }

    public function test_kutunun_icindeki_baska_ilce_de_elenir(): void
    {
        // Kutu (37.80–38.10 / 32.35–32.75) Meram'ı da içine alıyor. Yalnız
        // koordinata bakan bir eleme burayı geçirir, müşteri seçer ve ödeme
        // ekranında `ServiceArea::districtRule()` reddeder.
        $this->geocoder->willReturn([
            FakeGeocoder::candidate(
                neighbourhood: 'Alavardı Mah.',
                district: 'Meram',
                latitude: 37.8500000,
                longitude: 32.4600000,
            ),
        ]);

        $this->asCustomer()
            ->getJson('/api/addresses/suggest?q=Alavardı', self::HEADERS)
            ->assertOk()
            ->assertJsonCount(0, 'data');
    }

    public function test_ilce_adi_listedeki_yazimina_indirgenir(): void
    {
        // Sağlayıcı kendi kaynağındaki yazımı döndürüyor. Ham metin yanıta
        // yazılsaydı istemcinin ilçe seçicisi hiçbir seçeneğe denk gelmez ve
        // alan boş görünürdü.
        $this->geocoder->willReturn([FakeGeocoder::candidate(district: 'SELÇUKLU')]);

        $this->asCustomer()
            ->getJson('/api/addresses/suggest?q=Feritpaşa', self::HEADERS)
            ->assertOk()
            ->assertJsonPath('data.0.district', 'Selçuklu');
    }

    public function test_saglayici_cokerse_200_ve_bos_liste_doner(): void
    {
        // AKIŞ DURMAZ. Bu testin varlık sebebi: istisnayı yukarı bırakmak
        // "daha dürüst" görünür ve `5xx` dönerdi — o gün ödeme ekranı
        // dışarıdaki bir servisin arızasıyla kapanırdı.
        $this->geocoder->breakDown();

        $this->asCustomer()
            ->getJson('/api/addresses/suggest?q=Feritpaşa', self::HEADERS)
            ->assertOk()
            ->assertExactJson(['data' => []]);
    }

    public function test_kimliksiz_istek_401_doner(): void
    {
        // Anonim bir geocoder proxy'si sağlayıcı kotamızı yabancılara
        // harcatırdı.
        $this->getJson('/api/addresses/suggest?q=Feritpaşa', self::HEADERS)
            ->assertUnauthorized()
            ->assertJsonPath('error.code', 'UNAUTHENTICATED');

        $this->getJson('/api/addresses/reverse?lat='.self::LAT.'&lng='.self::LNG, self::HEADERS)
            ->assertUnauthorized();
    }

    public function test_kisa_sorgu_422_doner_ve_saglayiciya_gitmez(): void
    {
        // "k", "ka" hiçbir şey ayırt etmiyor; sağlayıcıya sormak kotayı
        // yakar ve önbelleği aynı çöple doldurur. İstemcideki 300 ms
        // debounce bir kolaylık, kota koruması değil.
        $this->asCustomer()
            ->getJson('/api/addresses/suggest?q=ka', self::HEADERS)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_FAILED');

        $this->assertSame(0, $this->geocoder->suggestCalls);
    }

    public function test_ayni_sorgu_saglayiciya_bir_kez_gider(): void
    {
        $this->geocoder->willReturn([FakeGeocoder::candidate()]);

        $this->asCustomer()->getJson('/api/addresses/suggest?q=Feritpaşa', self::HEADERS)->assertOk();
        $this->asCustomer()->getJson('/api/addresses/suggest?q=feritpaşa', self::HEADERS)->assertOk();

        // Büyük/küçük harf farkı ayrı bir anahtar üretmemeli: aynı ofisin üç
        // çalışanı aynı adresi farklı yazımlarla arıyor.
        $this->assertSame(1, $this->geocoder->suggestCalls);
    }

    public function test_arizali_yanit_onbellege_yazilmaz(): void
    {
        // Arıza 24 saat saklansaydı sağlayıcı ayağa kalktıktan sonra da
        // öneri verilmezdi.
        $this->geocoder->breakDown()->willReturn([FakeGeocoder::candidate()]);
        $this->asCustomer()->getJson('/api/addresses/suggest?q=Feritpaşa', self::HEADERS)->assertOk();

        $this->geocoder->breakDown(false);

        $this->asCustomer()
            ->getJson('/api/addresses/suggest?q=Feritpaşa', self::HEADERS)
            ->assertOk()
            ->assertJsonCount(1, 'data');
    }

    // ── Ters geocoding ────────────────────────────────────────────────────

    public function test_ters_geocoding_kutu_disinda_422_doner(): void
    {
        // Burada `422` doğru yanıt: kullanıcı haritayı GÖRDÜ ve teslimat
        // yapmadığımız bir yeri kasten seçti. Sessiz bir boş yanıt "arıza
        // var" gibi okunurdu.
        $this->asCustomer()
            ->getJson('/api/addresses/reverse?lat=39.9208&lng=32.8541', self::HEADERS)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_FAILED')
            ->assertJsonPath('error.details.reason', 'out_of_service_area');

        $this->assertSame(0, $this->geocoder->reverseCalls);
    }

    public function test_ters_geocoding_yarim_koordinati_reddeder(): void
    {
        // Kayıtlı adreste yarım çift sessizce `null`'a düşüyor; burada
        // çifti tamamlamanın yolu yok — sorulacak bir nokta yoksa soru da
        // yoktur.
        $this->asCustomer()
            ->getJson('/api/addresses/reverse?lat='.self::LAT, self::HEADERS)
            ->assertStatus(422);
    }

    public function test_ters_geocoding_istegin_kendi_noktasini_dondurur(): void
    {
        // Sağlayıcı sokak merkezine oturtuyor; o nokta iğneye yazılsaydı
        // iğne kullanıcının parmağının altından kayardı. Kapıyı müşteri
        // biliyor, geocoder değil.
        $this->geocoder->willReverseTo(FakeGeocoder::candidate(
            latitude: 37.8851832,
            longitude: 32.4898714,
        ));

        $response = $this->asCustomer()
            ->getJson('/api/addresses/reverse?lat='.self::LAT.'&lng='.self::LNG, self::HEADERS);

        $response->assertOk();
        $this->assertSame(self::LAT, $response->json('data.latitude'));
        $this->assertSame(self::LNG, $response->json('data.longitude'));
        $this->assertSame('Kültür Sk.', $response->json('data.street'));
    }

    public function test_ters_geocoding_saglayici_bilmiyorsa_null_doner(): void
    {
        // Arazi, yeni açılmış yol. İstemci iğneyi KORUR ve alanları elle
        // doldurtur — sağlayıcı arızasıyla ayırt etmesine gerek yok.
        $this->geocoder->willReverseTo(null);

        $this->asCustomer()
            ->getJson('/api/addresses/reverse?lat='.self::LAT.'&lng='.self::LNG, self::HEADERS)
            ->assertOk()
            ->assertExactJson(['data' => null]);
    }

    public function test_ters_geocoding_saglayici_cokerse_null_doner(): void
    {
        $this->geocoder->breakDown();

        $this->asCustomer()
            ->getJson('/api/addresses/reverse?lat='.self::LAT.'&lng='.self::LNG, self::HEADERS)
            ->assertOk()
            ->assertExactJson(['data' => null]);
    }

    // ── Yapılandırılmış alanlar ───────────────────────────────────────────

    public function test_yapilandirilmis_alanlar_kaydedilir_ve_geri_doner(): void
    {
        $response = $this->asCustomer()->postJson('/api/addresses', $this->structured([
            'line1' => 'Feritpaşa Mah. Kültür Sk. No:12/A Kat:3 Daire:7',
        ]), self::HEADERS);

        $response->assertCreated();
        $this->assertSame('Feritpaşa Mah.', $response->json('neighbourhood'));
        $this->assertSame('Kültür Sk.', $response->json('street'));
        $this->assertSame('12/A', $response->json('building_no'));
        $this->assertSame('3', $response->json('floor'));
        $this->assertSame('7', $response->json('door_no'));

        // Müşterinin yazdığı `line1` AYNEN korunur; türetilip üzerine
        // yazılsaydı "mavi kepenkli dükkân" gibi kuryenin gerçekten
        // kullandığı tarifler sessizce silinirdi.
        $this->assertSame(
            'Feritpaşa Mah. Kültür Sk. No:12/A Kat:3 Daire:7',
            $response->json('line1'),
        );
    }

    public function test_line1_gonderilmezse_alanlardan_turetilir(): void
    {
        $response = $this->asCustomer()
            ->postJson('/api/addresses', $this->structured(), self::HEADERS);

        $response->assertCreated();

        // Kat ve daire de cümleye giriyor: kurye adresi arar değil OKUR ve
        // fişte yalnız `line1` basılıyor.
        $this->assertSame(
            'Feritpaşa Mah. Kültür Sk. No:12/A Kat:3 Daire:7',
            $response->json('line1'),
        );
    }

    public function test_ne_line1_ne_alan_varsa_reddedilir(): void
    {
        // `line1` sözleşmede zorunlu kalıyor. Tek gevşeme yapılandırılmış
        // alanlardan türetme; ikisi de yoksa adres yoktur.
        $this->asCustomer()->postJson('/api/addresses', [
            'district' => 'Selçuklu',
            'city' => 'Konya',
            'floor' => '3',
        ], self::HEADERS)
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_FAILED');
    }

    public function test_null_gonderilirse_alan_silinir_gonderilmezse_korunur(): void
    {
        $id = (int) $this->asCustomer()
            ->postJson('/api/addresses', $this->structured(), self::HEADERS)
            ->json('id');

        // Alanı hiç göndermemek: korunur.
        $kept = $this->asCustomer()->patchJson("/api/addresses/{$id}", [
            'line1' => 'Feritpaşa Mah. Kültür Sk. No:12/A Kat:3 Daire:7',
            'district' => 'Selçuklu',
            'city' => 'Konya',
            'label' => 'Ofis',
        ], self::HEADERS);

        $kept->assertOk();
        $this->assertSame('7', $kept->json('door_no'), 'Etiket düzenlemek daire numarasını düşürdü.');

        // `null` göndermek: silinir. Koordinattaki kuralın aynısı.
        $cleared = $this->asCustomer()->patchJson("/api/addresses/{$id}", [
            'line1' => 'Feritpaşa Mah. Kültür Sk. No:12/A',
            'district' => 'Selçuklu',
            'city' => 'Konya',
            'door_no' => null,
        ], self::HEADERS);

        $cleared->assertOk();
        $this->assertNull($cleared->json('door_no'));
        $this->assertSame('3', $cleared->json('floor'), 'Daire silinince kat da gitti — alanlar bağımsız olmalı.');
    }

    public function test_yapilandirilmis_alanlar_siparis_adresine_kopyalanir(): void
    {
        $order = $this->asCustomer()->postJson('/api/orders', [
            'location_id' => $this->locationId(),
            // Adet 5: tek porsiyon asgari sipariş tutarının altında kalıyor
            // ve sipariş, adresle ilgisi olmayan bir kuralla reddediliyor.
            'items' => [['menu_id' => $this->anyMenuId(), 'quantity' => 5]],
            'delivery_type' => 'delivery',
            'payment_method' => 'cash',
            // `line1` BİLEREK YOK: sipariş ucu da parçalardan türetmeli,
            // yoksa yeni formu kullanan istemci sipariş veremez.
            'address' => $this->structured(),
        ], self::HEADERS);

        $order->assertCreated();

        // Adres sipariş OLUŞTURMA yanıtında yok — o yanıt bilinçli olarak
        // dar. Kopyanın göründüğü yer sipariş detayı; fiş de oradan besleniyor.
        $detail = $this->asCustomer()
            ->getJson('/api/orders/'.$order->json('id'), self::HEADERS);

        $detail->assertOk();
        $this->assertSame('Feritpaşa Mah.', $detail->json('address.neighbourhood'));
        $this->assertSame('Kültür Sk.', $detail->json('address.street'));
        $this->assertSame('12/A', $detail->json('address.building_no'));
        $this->assertSame('3', $detail->json('address.floor'));
        $this->assertSame('7', $detail->json('address.door_no'));
        $this->assertSame(
            'Feritpaşa Mah. Kültür Sk. No:12/A Kat:3 Daire:7',
            $detail->json('address.line1'),
        );
    }

    public function test_eski_adreste_alanlar_null_kalir(): void
    {
        // Geçmiş adresleri geriye dönük ayrıştırmak, ayrıştırmanın yanlış
        // olduğu her satırda kuryeyi yanlış kapıya götürürdü.
        $response = $this->asCustomer()->postJson('/api/addresses', [
            'line1' => 'Atatürk Caddesi No:12',
            'district' => 'Selçuklu',
            'city' => 'Konya',
        ], self::HEADERS);

        $response->assertCreated();
        $this->assertNull($response->json('neighbourhood'));
        $this->assertNull($response->json('street'));
        $this->assertNull($response->json('building_no'));
        $this->assertSame('Atatürk Caddesi No:12', $response->json('line1'));
    }

    // ── Yardımcılar ───────────────────────────────────────────────────────

    /**
     * Beş alanı da dolu bir adres gövdesi. `line1` YOK — türetmeyi sınayan
     * testler onu eklemiyor, aynen korumayı sınayanlar ekliyor.
     *
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function structured(array $overrides = []): array
    {
        return array_merge([
            'neighbourhood' => 'Feritpaşa Mah.',
            'street' => 'Kültür Sk.',
            'building_no' => '12/A',
            'floor' => '3',
            'door_no' => '7',
            'district' => 'Selçuklu',
            'city' => 'Konya',
        ], $overrides);
    }

    private function anyMenuId(): int
    {
        $categories = $this->getJson(
            '/api/locations/'.$this->locationId().'/menu',
            self::HEADERS,
        )->json('data');

        return (int) $categories[0]['items'][0]['id'];
    }
}
