<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Admin;

use Igniter\Flame\Database\Model;
use Igniter\Flame\Exception\FlashException;

/**
 * "BLD Ayarları" sayfasının form nesnesi.
 *
 * TastyIgniter'ın `Igniter\System\Http\Controllers\Extensions::edit` ucu,
 * `registerSettings()` içinde bildirilen `model` sınıfını `new` ile kurar ve
 * ondan üç şey bekler: `getSettingsRecord()`, `getFieldConfig()`, `set()`.
 * Bu sınıf o sözleşmeyi karşılar — böylece kendi admin denetleyicimizi
 * yazmadan çekirdeğin form ekranını kullanırız.
 *
 * ÇEKİRDEĞİN `SettingsModel` DAVRANIŞI BİLİNÇLİ OLARAK KULLANILMIYOR:
 * o davranış değerleri `extension_settings` tablosuna yazar. Bizim
 * değerlerimiz `location_options`'ta yaşıyor ve API, KDS ve müşteri
 * uygulamaları onları oradan okuyor (`LocationGate`). İki tablo birden
 * tutmak, panelden değiştirilen ayarın API'ye hiç yansımaması demekti.
 *
 * Bu yüzden model **Eloquent üzerinden kaydedilmez**: okuma da yazma da
 * `SettingsRepository` → `LocationGate` yolundan geçer. `$table` yalnızca
 * Eloquent'in tablosuz kalmaması için gerçek bir tabloya işaret eder.
 */
class BldSettings extends Model
{
    /** `registerSettings()` içindeki anahtar; URL'in son parçası. */
    public const string SETTINGS_CODE = 'settings';

    protected $table = 'location_options';

    public $timestamps = false;

    protected $guarded = [];

    public function __construct(array $attributes = [])
    {
        parent::__construct($attributes);

        $this->loadFromGate();
    }

    /**
     * Gate'teki güncel değerleri form alanlarına yükler.
     *
     * Adı `reload()` DEĞİL: çekirdeğin `Model::reload()`'u `refresh()` çağırıp
     * veritabanından satır çeker ve dönüş tipi farklıdır; üzerine yazmak
     * ölümcül hata verir.
     */
    public function loadFromGate(): void
    {
        $repository = $this->repository();
        $location = $repository->location();

        $this->setRawAttributes(
            $location === null ? [] : $repository->toFormData($location),
        );
    }

    /**
     * Çekirdek burada bir veritabanı satırı arar; bizde satır yok.
     *
     * `null` dönmek `Extensions::formFindModelObject`'in bu nesnenin
     * kendisini kullanmasını sağlar — değerler zaten `reload()` ile
     * yüklendi.
     */
    public function getSettingsRecord(): ?Model
    {
        return null;
    }

    /** @return array<string, mixed> */
    public function getFieldConfig(): array
    {
        /** @var array{form: array<string, mixed>} $config */
        $config = require dirname(__DIR__, 2).'/resources/models/bldsettings.php';

        return $config['form'];
    }

    /**
     * Formun kaydet düğmesi buraya düşer.
     *
     * @param  array<string, mixed>|string  $key
     */
    public function set(array|string $key, mixed $value = null): bool
    {
        $data = is_array($key) ? $key : [$key => $value];

        $repository = $this->repository();
        $location = $repository->location();

        throw_if($location === null, new FlashException(
            lang('veykemtu.bridgeapi::default.alert_no_location'),
        ));

        $repository->save($location, $data);

        // Kaydedilen değerler gate'te normalize ediliyor (kuruşa yuvarlama,
        // bilinmeyen ödeme yönteminin elenmesi). Formu geri yüklemek,
        // yöneticiye kaydın gerçek sonucunu gösterir.
        $this->loadFromGate();

        return true;
    }

    private function repository(): SettingsRepository
    {
        return resolve(SettingsRepository::class);
    }
}
