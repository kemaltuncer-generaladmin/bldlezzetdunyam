<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Services;

/**
 * Adresin parçalanmış hâli — B-21, `docs/openapi.yaml` §Address /
 * §SavedAddress.
 *
 * Beş alan: mahalle, sokak, bina no, kat, daire. Hepsi isteğe bağlı ve
 * hepsi metin (gerekçe: `2026_08_16_000001` göçünün başlığında).
 *
 * ## NEDEN TEK SINIF
 *
 * Aynı beş alanı DÖRT yer tanımak zorunda: adres defteri denetleyicisi,
 * sipariş oluşturma doğrulaması, sipariş adresi kopyası (`OrderFactory`) ve
 * sipariş yanıtı (`OrderPresenter`). Eşleme dört yere ayrı ayrı yazılsaydı
 * — `address_1`/`state`/`address_2` üçlüsünde bir kez yaşandığı gibi —
 * ikisinin ayrıştığı gün adresin yarısı kaybolurdu. Sütun adları, uzunluk
 * sınırları ve tek satırlık adresin nasıl kurulduğu BURADA, tek yerde.
 *
 * ## `line1` bir GÖSTERİM DEĞİL, kaydın kendisi
 *
 * Mutfak fişi, kurye fişi ve eski istemci sürümleri yalnız `line1`'i
 * okuyor. Bu yüzden kat ve daire de cümleye giriyor: kurye adresi arar
 * değil OKUR ve daire numarası yalnız kendi alanında kalırsa fişte hiç
 * görünmez.
 */
abstract class StructuredAddress
{
    /**
     * Sözleşme alanı → veritabanı sütunu.
     *
     * Sütunlar `bld_` önekli: `addresses` tablosu TastyIgniter'ın, sahibi
     * belli olsun.
     *
     * @var array<string, string>
     */
    public const array COLUMNS = [
        'neighbourhood' => 'bld_neighbourhood',
        'street' => 'bld_street',
        'building_no' => 'bld_building_no',
        'floor' => 'bld_floor',
        'door_no' => 'bld_door_no',
    ];

    /**
     * Sözleşmedeki `maxLength` değerleri. Göçteki sütun genişlikleriyle
     * birebir aynı — sütun daha darsa doğrulamayı geçen bir değer
     * veritabanında sessizce kırpılırdı.
     *
     * @var array<string, int>
     */
    public const array MAX_LENGTHS = [
        'neighbourhood' => 96,
        'street' => 128,
        'building_no' => 24,
        'floor' => 16,
        'door_no' => 16,
    ];

    /** `line1` sözleşmede 255 karakter. Kırpma burada, veritabanında değil. */
    public const int LINE_MAX_LENGTH = 255;

    /**
     * `line1` boş geldiğinde ondan türetilebilen alanlar.
     *
     * Kat ve daire LİSTEDE YOK: "Kat:3 Daire:7" tek başına bir adres değil,
     * kurye onunla kapıyı bulamaz. Mahalle, sokak ya da bina numarasından en
     * az biri gerekiyor.
     *
     * Defter ucu ve sipariş ucu AYNI listeyi kullanmak zorunda: ayrıştıkları
     * gün defterde kaydedilebilen bir adres siparişte reddedilirdi.
     *
     * @var list<string>
     */
    public const array LINE_SOURCES = ['neighbourhood', 'street', 'building_no'];

    /**
     * Beş alanın doğrulama kuralları.
     *
     * `$prefix` iç içe gövdeler için (`address.neighbourhood`): sipariş ucu
     * adresi bir alt nesne olarak alıyor, defter ucu kök seviyede.
     *
     * `sometimes` + `nullable` ÇİFTİ ANLAMLI: sözleşme "alanı `null`
     * göndermek onu SİLER, hiç göndermemek mevcut değeri KORUR" diyor.
     * `sometimes` olmadan her PATCH beş alanı da göndermek zorunda kalırdı.
     *
     * @return array<string, list<mixed>>
     */
    public static function rules(string $prefix = ''): array
    {
        $rules = [];

        foreach (self::MAX_LENGTHS as $field => $max) {
            $rules[$prefix.$field] = ['sometimes', 'nullable', 'string', 'max:'.$max];
        }

        return $rules;
    }

    /**
     * İstekten modele yazar.
     *
     * `array_key_exists`, `??` DEĞİL — koordinatlardaki kuralın aynısı:
     * `null` göndermek alanı siler, alanı hiç göndermemek korur. `??` ile
     * yazılsaydı "daire numarasını kaldırdım" isteği sessizce yok sayılırdı.
     *
     * Koordinat çiftinden farklı olarak bu beş alan BİRBİRİNDEN BAĞIMSIZ:
     * kat bilinip daire numarası bilinmemesi olağan bir durum, yarım bir
     * çift değil.
     *
     * @param array<string, mixed> $data
     */
    public static function write(object $model, array $data): void
    {
        foreach (self::COLUMNS as $field => $column) {
            if (!array_key_exists($field, $data)) {
                continue;
            }

            $model->{$column} = self::clean($data[$field]);
        }
    }

    /**
     * İstekteki değerleri doğrudan modele yazar — kaynak alan adları
     * farkında olmadan (sipariş adresi KOPYALANIR, bağlanmaz).
     *
     * @param array<string, mixed> $data
     */
    public static function copy(object $model, array $data): void
    {
        foreach (self::COLUMNS as $field => $column) {
            $model->{$column} = self::clean($data[$field] ?? null);
        }
    }

    /**
     * Modelden/satırdan sözleşme alanlarını okur.
     *
     * `object` alıyor, `Address` değil: `OrderPresenter` adresi
     * `DB::table()` ile çekiyor ve elinde bir `stdClass` var. Modele
     * bağlansaydı orada ikinci bir okuma yolu yazılmak zorunda kalırdı.
     *
     * @return array<string, string|null>
     */
    public static function read(object $row): array
    {
        $out = [];

        foreach (self::COLUMNS as $field => $column) {
            $value = $row->{$column} ?? null;
            $out[$field] = is_string($value) && $value !== '' ? $value : null;
        }

        return $out;
    }

    /** Satırdaki parçalardan tek satırlık adresi kurar. */
    public static function lineFor(object $row): string
    {
        $fields = self::read($row);

        return self::compose(
            $fields['neighbourhood'],
            $fields['street'],
            $fields['building_no'],
            $fields['floor'],
            $fields['door_no'],
        );
    }

    /**
     * Parçaları "Feritpaşa Mah. Kültür Sk. No:12 Kat:3 Daire:7" hâline getirir.
     *
     * Hiçbir parça yoksa boş dize döner ve kararı çağıran verir: defter
     * ucunda bu bir doğrulama hatası, sipariş ucunda müşterinin yazdığı
     * `line1`'e düşme sebebi.
     *
     * Ön ekler Türkçe ve çeviri katmanından GEÇMİYOR: bu metin doğrudan
     * termal fişe basılıyor ve fişin dili işletmenin dili.
     */
    public static function compose(
        ?string $neighbourhood,
        ?string $street,
        ?string $buildingNo,
        ?string $floor = null,
        ?string $doorNo = null,
    ): string {
        $parts = [
            (string) self::clean($neighbourhood),
            (string) self::clean($street),
            self::prefixed('No:', $buildingNo),
            self::prefixed('Kat:', $floor),
            self::prefixed('Daire:', $doorNo),
        ];

        $line = implode(' ', array_filter($parts, static fn(string $part): bool => $part !== ''));

        return mb_substr($line, 0, self::LINE_MAX_LENGTH);
    }

    private static function prefixed(string $prefix, ?string $value): string
    {
        $clean = self::clean($value);

        return $clean === null ? '' : $prefix.$clean;
    }

    /** Boşlukları toplar; geriye kalan boşsa `null`. */
    private static function clean(mixed $value): ?string
    {
        if (!is_string($value)) {
            return null;
        }

        // İçerideki fazla boşluklar da toplanıyor: geocoder yanıtlarında
        // "Kültür  Sokak" gibi çift boşluklar geliyor ve aynı adres iki
        // farklı kaynaktan iki farklı metin olarak kaydediliyor.
        $clean = trim(preg_replace('/\s+/u', ' ', $value) ?? '');

        return $clean === '' ? null : $clean;
    }
}
