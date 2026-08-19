<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Admin;

use Igniter\Flame\Database\Model;
use Igniter\Flame\Exception\FlashException;
use Veykemtu\BridgeApi\Models\SiteContent;
use Veykemtu\BridgeApi\Services\SiteContentRepository;

/**
 * "Site İçeriği" sayfasının form nesnesi.
 *
 * Kurumsal sitedeki sınırlı listeler burada yönetilir: marka, iletişim,
 * kurumsal metinler, SSS, sektörler, menü çözümleri ve kalite yaklaşımı.
 * Hizmetler ve yazılar kendi ekranlarında — onlar çoğalan kayıtlar.
 *
 * `BldSettings` ile aynı sözleşmeyi karşılar (`getSettingsRecord()`,
 * `getFieldConfig()`, `set()`), böylece çekirdeğin form ekranını kullanır ve
 * kendi denetleyicimizi yazmayız.
 *
 * ## Telefon iki alan değil, tek alan
 *
 * Site `{display, href}` çifti bekliyor ama panelde iki ayrı kutu göstermek
 * ("0212 000 00 00" ve "tel:+902120000000") yöneticiyi bir biçim kuralını
 * elle uygulamaya zorlardı ve ilk yazım hatasında bağlantı çalışmazdı.
 * Yönetici numarayı okunur biçimde yazar; `href` burada türetilir.
 */
class SiteContentSettings extends Model
{
    /** `registerSettings()` içindeki anahtar; URL'in son parçası. */
    public const string SETTINGS_CODE = 'site_content';

    /**
     * Eloquent'in tablosuz kalmaması için gerçek bir tabloya işaret eder.
     * Model bu tablo üzerinden KAYDEDİLMEZ; okuma ve yazma `SiteContent`
     * satırlarına elle yapılır.
     */
    protected $table = 'veykemtu_site_content';

    protected $primaryKey = 'key';

    public $incrementing = false;

    protected $keyType = 'string';

    public $timestamps = false;

    protected $guarded = [];

    public function __construct(array $attributes = [])
    {
        parent::__construct($attributes);

        $this->loadFromContent();
    }

    /** Veritabanındaki değerleri düz form alanlarına açar. */
    public function loadFromContent(): void
    {
        $rows = SiteContent::query()->get()->keyBy('key');

        $brand = $this->arrayValue($rows->get(SiteContent::KEY_BRAND));
        $contact = $this->arrayValue($rows->get(SiteContent::KEY_CONTACT));
        $company = $this->arrayValue($rows->get(SiteContent::KEY_COMPANY));
        $legal = $this->arrayValue($rows->get(SiteContent::KEY_LEGAL));
        $menus = $this->arrayValue($rows->get(SiteContent::KEY_MENUS));
        $quality = $this->arrayValue($rows->get(SiteContent::KEY_QUALITY));

        $address = is_array($contact['address'] ?? null) ? $contact['address'] : [];

        $this->setRawAttributes([
            // Marka
            'brand_name' => $brand['name'] ?? '',
            'brand_short_name' => $brand['short_name'] ?? '',
            'brand_parent_group' => $brand['parent_group'] ?? '',
            'brand_tagline' => $brand['tagline'] ?? '',
            'brand_description' => $brand['description'] ?? '',
            'brand_logo' => $brand['logo_url'] ?? null,
            'brand_primary_color' => $brand['primary_color'] ?? '',

            // İletişim — kullanıcıya görünen biçim; `href` kaydederken türetilir.
            'contact_phone' => $this->displayOf($contact['phone'] ?? null),
            'contact_whatsapp' => $this->displayOf($contact['whatsapp'] ?? null),
            'contact_email' => $this->displayOf($contact['email'] ?? null),
            'address_street' => $address['street_address'] ?? '',
            'address_district' => $address['district'] ?? '',
            'address_city' => $address['city'] ?? '',
            'address_postal_code' => $address['postal_code'] ?? '',
            'address_map_embed_url' => $address['map_embed_url'] ?? '',
            'working_hours' => $contact['working_hours'] ?? [],
            'social' => $contact['social'] ?? [],

            // Kurumsal
            'company_mission' => $company['mission'] ?? '',
            'company_vision' => $company['vision'] ?? '',
            'company_group_relation' => $company['group_relation'] ?? '',
            'company_values' => $company['values'] ?? [],
            'company_process_steps' => $company['process_steps'] ?? [],
            'company_differentiators' => $company['differentiators'] ?? [],

            // Yasal kimlik
            'legal_trade_name' => $legal['trade_name'] ?? '',
            'legal_form' => $legal['legal_form'] ?? '',
            'legal_registered_address' => $legal['registered_address'] ?? '',
            'legal_tax_office' => $legal['tax_office'] ?? '',
            'legal_tax_number' => $legal['tax_number'] ?? '',
            'legal_mersis_no' => $legal['mersis_no'] ?? '',
            'legal_kep_address' => $legal['kep_address'] ?? '',
            'legal_payment_provider' => $legal['payment_provider'] ?? '',

            // Listeler
            'faq' => $this->arrayValue($rows->get(SiteContent::KEY_FAQ)),
            'sectors' => $this->arrayValue($rows->get(SiteContent::KEY_SECTORS)),
            'menu_solutions' => $menus['solutions'] ?? [],
            'menu_seasonal' => $menus['seasonal'] ?? [],
            'quality_chain' => $quality['chain'] ?? [],
            'quality_allergen' => $quality['allergen'] ?? [],
            'quality_certifications' => $quality['certifications'] ?? [],
        ]);
    }

    public function getSettingsRecord(): ?Model
    {
        return null;
    }

    /** @return array<string, mixed> */
    public function getFieldConfig(): array
    {
        /** @var array{form: array<string, mixed>} $config */
        $config = require dirname(__DIR__, 2).'/resources/models/sitecontentsettings.php';

        return $config['form'];
    }

    /**
     * Kaydet düğmesi buraya düşer.
     *
     * @param  array<string, mixed>|string  $key
     */
    public function set(array|string $key, mixed $value = null): bool
    {
        $data = is_array($key) ? $key : [$key => $value];

        $color = trim((string) ($data['brand_primary_color'] ?? ''));
        if ($color !== '' && ! BrandGuard::passesOnWhiteText($color)) {
            /*
             * Renk reddediliyor, kırpılmıyor veya "en yakın uygun tona"
             * çevrilmiyor: yönetici seçtiği rengin değiştirildiğini fark
             * etmez ve markanın rengini yanlış bilir. Reddetmek onu haberdar
             * ediyor.
             */
            throw new FlashException(sprintf(
                lang('veykemtu.bridgeapi::sitecontent.error_contrast'),
                number_format(BrandGuard::contrast($color, '#FFFFFF'), 2),
                number_format(BrandGuard::MIN_CONTRAST, 1),
            ));
        }

        $this->writeBrand($data);
        $this->writeContact($data);
        $this->writeCompany($data);
        $this->writeLegal($data);

        $this->put(SiteContent::KEY_FAQ, $this->rows($data['faq'] ?? []));
        $this->put(SiteContent::KEY_SECTORS, $this->rows($data['sectors'] ?? []));
        $this->put(SiteContent::KEY_MENUS, [
            'solutions' => $this->rows($data['menu_solutions'] ?? []),
            'seasonal' => $this->rows($data['menu_seasonal'] ?? []),
        ]);
        $this->put(SiteContent::KEY_QUALITY, [
            'chain' => $this->rows($data['quality_chain'] ?? []),
            'allergen' => $this->rows($data['quality_allergen'] ?? []),
            'certifications' => $this->rows($data['quality_certifications'] ?? []),
        ]);

        app(SiteContentRepository::class)->forget();

        $this->loadFromContent();

        return true;
    }

    /** @param  array<string, mixed>  $data */
    private function writeBrand(array $data): void
    {
        $this->put(SiteContent::KEY_BRAND, [
            'name' => trim((string) ($data['brand_name'] ?? '')),
            'short_name' => trim((string) ($data['brand_short_name'] ?? '')),
            'parent_group' => trim((string) ($data['brand_parent_group'] ?? '')),
            'tagline' => trim((string) ($data['brand_tagline'] ?? '')),
            'description' => trim((string) ($data['brand_description'] ?? '')),
            'logo_url' => $this->nullIfBlank($data['brand_logo'] ?? null),
            'primary_color' => $this->nullIfBlank($data['brand_primary_color'] ?? null),
        ]);
    }

    /** @param  array<string, mixed>  $data */
    private function writeContact(array $data): void
    {
        $street = trim((string) ($data['address_street'] ?? ''));
        $city = trim((string) ($data['address_city'] ?? ''));

        $this->put(SiteContent::KEY_CONTACT, [
            'phone' => $this->channel($data['contact_phone'] ?? null, 'tel'),
            'whatsapp' => $this->channel($data['contact_whatsapp'] ?? null, 'whatsapp'),
            'email' => $this->channel($data['contact_email'] ?? null, 'mailto'),
            /*
             * Adres ancak sokak VE şehir doluysa yazılır. Yarım adres, sitede
             * eksik bir blok ve arama motorunda hatalı bir konum bilgisi
             * demek; yoksa hiç göstermemek daha doğru.
             */
            'address' => ($street !== '' && $city !== '') ? [
                'street_address' => $street,
                'district' => trim((string) ($data['address_district'] ?? '')),
                'city' => $city,
                'postal_code' => $this->nullIfBlank($data['address_postal_code'] ?? null),
                'map_embed_url' => $this->nullIfBlank($data['address_map_embed_url'] ?? null),
            ] : null,
            'working_hours' => $this->rows($data['working_hours'] ?? []),
            'social' => $this->rows($data['social'] ?? []),
        ]);
    }

    /** @param  array<string, mixed>  $data */
    private function writeCompany(array $data): void
    {
        $this->put(SiteContent::KEY_COMPANY, [
            'mission' => trim((string) ($data['company_mission'] ?? '')),
            'vision' => trim((string) ($data['company_vision'] ?? '')),
            'group_relation' => trim((string) ($data['company_group_relation'] ?? '')),
            'values' => $this->rows($data['company_values'] ?? []),
            'process_steps' => $this->rows($data['company_process_steps'] ?? []),
            'differentiators' => $this->rows($data['company_differentiators'] ?? []),
        ]);
    }

    /**
     * İşletmenin yasal kimliği.
     *
     * Doldurulmamış alan boş dize değil `null` yazılır: site `null` alanı
     * "Girilmesi gerekiyor" uyarısıyla gösteriyor, boş dizeyi ise doldurulmuş
     * sayıp yanına hiçbir şey basmadan geçerdi — eksik bilgi görünmez olurdu.
     *
     * @param  array<string, mixed>  $data
     */
    private function writeLegal(array $data): void
    {
        $this->put(SiteContent::KEY_LEGAL, [
            'trade_name' => $this->nullIfBlank($data['legal_trade_name'] ?? null),
            'legal_form' => $this->nullIfBlank($data['legal_form'] ?? null),
            'registered_address' => $this->nullIfBlank($data['legal_registered_address'] ?? null),
            'tax_office' => $this->nullIfBlank($data['legal_tax_office'] ?? null),
            'tax_number' => $this->nullIfBlank($data['legal_tax_number'] ?? null),
            'mersis_no' => $this->nullIfBlank($data['legal_mersis_no'] ?? null),
            'kep_address' => $this->nullIfBlank($data['legal_kep_address'] ?? null),
            'payment_provider' => $this->nullIfBlank($data['legal_payment_provider'] ?? null),
        ]);
    }

    /**
     * Okunur numaradan tıklanabilir bağlantı üretir.
     *
     * Türkiye numarası varsayılıyor: rakamlar dışındaki her şey atılır,
     * baştaki `0` veya `90` temizlenip `+90` ekleniyor. Yönetici numarayı
     * "0212 000 00 00", "+90 212 000 00 00" veya "2120000000" yazsın —
     * üçü de aynı bağlantıyı üretir.
     *
     * @return array{display: string, href: string}|null
     */
    private function channel(mixed $raw, string $kind): ?array
    {
        $display = trim((string) $raw);
        if ($display === '') {
            return null;
        }

        if ($kind === 'mailto') {
            return ['display' => $display, 'href' => 'mailto:'.$display];
        }

        $digits = preg_replace('/\D+/', '', $display) ?? '';
        if (str_starts_with($digits, '90') && strlen($digits) === 12) {
            $digits = substr($digits, 2);
        } elseif (str_starts_with($digits, '0') && strlen($digits) === 11) {
            $digits = substr($digits, 1);
        }

        $international = '+90'.$digits;

        return [
            'display' => $display,
            'href' => $kind === 'whatsapp'
                ? 'https://wa.me/90'.$digits
                : 'tel:'.$international,
        ];
    }

    /** @param  array<string, mixed>  $value */
    private function put(string $key, array $value): void
    {
        SiteContent::query()->updateOrCreate(['key' => $key], ['value' => $value]);
    }

    /**
     * Repeater çıktısını temizler.
     *
     * Repeater silinen satırları boş dizi olarak bırakabiliyor; anahtarları da
     * sıra numarasıyla verir. `array_values` ile yeniden indeksleniyor, tamamen
     * boş satırlar atılıyor — yoksa sitede boş kart belirir.
     *
     * @return list<mixed>
     */
    private function rows(mixed $value): array
    {
        if (! is_array($value)) {
            return [];
        }

        $rows = array_filter($value, static function (mixed $row): bool {
            if (! is_array($row)) {
                return trim((string) $row) !== '';
            }

            foreach ($row as $field) {
                if (is_array($field) ? $field !== [] : trim((string) $field) !== '') {
                    return true;
                }
            }

            return false;
        });

        return array_values($rows);
    }

    /** @return array<string, mixed> */
    private function arrayValue(?SiteContent $row): array
    {
        return $row instanceof SiteContent && is_array($row->value) ? $row->value : [];
    }

    private function displayOf(mixed $channel): string
    {
        return is_array($channel) ? (string) ($channel['display'] ?? '') : '';
    }

    private function nullIfBlank(mixed $value): ?string
    {
        $value = trim((string) $value);

        return $value === '' ? null : $value;
    }
}
