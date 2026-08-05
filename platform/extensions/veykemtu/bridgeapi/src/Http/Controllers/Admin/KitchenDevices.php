<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers\Admin;

use Igniter\Admin\Classes\AdminController;
use Igniter\Admin\Facades\AdminMenu;
use Igniter\Admin\Http\Actions\FormController;
use Igniter\Admin\Http\Actions\ListController;
use Igniter\Admin\Widgets\Form;
use Igniter\Flame\Database\Model;
use Igniter\Flame\Exception\FlashException;
use Illuminate\Http\RedirectResponse;
use Veykemtu\BridgeApi\Admin\AdminRegistrar;
use Veykemtu\BridgeApi\Admin\KitchenDevicePanel;
use Veykemtu\BridgeApi\Models\KitchenCommand;
use Veykemtu\BridgeApi\Models\KitchenDevice;
use Veykemtu\BridgeApi\Models\PrintJob;
use Veykemtu\BridgeApi\Services\KitchenDeviceSettings;

/**
 * Mutfak kasaları yönetim ekranı — `docs/05-mutfakapp.md` §7-8.
 *
 * Bugüne kadar cihaz eklemek, eşleme kodu üretmek ve cihaz iptal etmek
 * yalnızca `php artisan veykemtu:kds` ile yapılabiliyordu; kasa ayarları
 * ise hiç yönetilemiyordu. Bu ekran ikisini de panele taşır.
 *
 * ALT KLASÖRDE (`Http/Controllers/Admin/`): çekirdeğin denetleyici taraması
 * özyinelemelidir (`Igniter\Admin\Classes\RouteRegistrar::getAdminPages` →
 * `File::allFiles`), bu yüzden alt klasör sorunsuz bulunur ve rota yine
 * `admin/veykemtu/bridgeapi/kitchen_devices` olur. Klasör ayrımı bilinçli:
 * bu dosyanın komşuları API denetleyicileridir ve ikisi tamamen farklı
 * sözleşmelere uyar.
 *
 * SİLME YOK, İPTAL VAR. Bir kasayı silmek fiş kuyruğunu ve komut geçmişini
 * de silerdi; iptal edilen kasa ise bir daha eşleşemez ve geçmişi durur
 * (`KitchenDevice::revoke()` gerekçesi).
 */
class KitchenDevices extends AdminController
{
    /** Rota ve yönlendirmelerde kullanılan taban yol. */
    private const string BASE_URI = 'veykemtu/bridgeapi/kitchen_devices';

    public array $implement = [
        ListController::class,
        FormController::class,
    ];

    public array $listConfig = [
        'list' => [
            'model' => KitchenDevice::class,
            'title' => 'lang:veykemtu.bridgeapi::default.kds.text_title',
            'emptyMessage' => 'lang:veykemtu.bridgeapi::default.kds.text_empty',
            'defaultSort' => ['id', 'ASC'],
            'configFile' => 'kitchendevice',
        ],
    ];

    public array $formConfig = [
        'name' => 'lang:veykemtu.bridgeapi::default.kds.text_form_name',
        'model' => KitchenDevice::class,
        'create' => [
            'title' => 'lang:veykemtu.bridgeapi::default.kds.text_create_title',
            'redirect' => self::BASE_URI.'/edit/{id}',
            'redirectClose' => self::BASE_URI,
        ],
        'edit' => [
            'title' => 'lang:veykemtu.bridgeapi::default.kds.text_edit_title',
            'redirect' => self::BASE_URI.'/edit/{id}',
            'redirectClose' => self::BASE_URI,
        ],
        'configFile' => 'kitchendevice',
    ];

    protected null|string|array $requiredPermissions = AdminRegistrar::PERMISSION_DEVICES;

    /**
     * `formValidate` ile `formAfterSave` arasında taşınan ayar değerleri.
     *
     * NEDEN MODELE DOĞRUDAN YAZILMIYOR: dokuz ayarın tek yazarı
     * `KitchenDeviceSettings`'tir (sınırlar, "geciken ≥ uyarı" kuralı ve
     * `settings_updated_at` damgası orada). Form parçacığının değerleri
     * modele kendi doldurmasına izin verilseydi ikinci bir yazar doğardı;
     * üstelik boş bırakılan bir sayı alanı ('' → INT sütun) kaydı MySQL
     * katı kipinde patlatırdı.
     *
     * @var array<string, mixed>
     */
    protected array $pendingSettings = [];

    public function __construct()
    {
        parent::__construct();

        AdminMenu::setContext('bld_kitchen_devices', 'restaurant');
    }

    /**
     * Düzenleme ekranı: form + sağlık, eşleme ve komut panelleri.
     *
     * Paneller form ALANI DEĞİL, bu yüzden `resources/views/kitchendevices/edit.blade.php`
     * içinde formun dışında çiziliyorlar. Form alanı yapılsalardı kaydedilebilir
     * görünürlerdi; oysa hepsi ya kasanın bildirdiğidir (salt okunur) ya da tek
     * seferlik eylemdir.
     */
    public function edit(string $context, ?string $recordId = null): void
    {
        $this->asExtension('FormController')->edit($context, $recordId);

        $device = $this->getFormModel();

        if ($device instanceof KitchenDevice) {
            $this->preparePanelVars($device);
        }
    }

    // ── Kaydetme yolu ─────────────────────────────────────────────────────

    /**
     * Doğrulanmış veriyi ikiye ayırır: modele yazılacaklar ve ayar servisine
     * gidecekler.
     *
     * Çekirdek bu metodun dönüşünü `$saveData` yerine kullanır
     * (`FormController::validateSaveData`), yani ayar sütunlarını burada
     * çıkarmak onların modele hiç dokunmaması demektir.
     *
     * @return array<string, mixed>|false
     */
    public function formValidate(Model $model, Form $form): array|false
    {
        /** @var array<int, array<int, string>> $rules */
        $rules = array_get($form->config, 'rules', []);

        $validated = $this->validatePasses($form->getSaveData(), $rules);

        if ($validated === false) {
            return false;
        }

        $settingFields = array_flip($this->settingFields($model));

        $this->pendingSettings = array_intersect_key($validated, $settingFields);

        return array_diff_key($validated, $settingFields);
    }

    public function formAfterCreate(Model $model): void
    {
        if (!$model instanceof KitchenDevice) {
            return;
        }

        // Kod kaydın hemen ardından üretiliyor: yönetici "cihazı ekledim ama
        // eşleyemiyorum" diye ikinci bir adım aramak zorunda kalmasın.
        $model->refreshPairingCode();

        flash()->success(lang('veykemtu.bridgeapi::default.kds.alert_created'));
    }

    public function formAfterSave(Model $model): void
    {
        if ($this->pendingSettings === [] || !$model instanceof KitchenDevice) {
            return;
        }

        $submittedLate = $this->pendingSettings['late_after_minutes'] ?? null;

        resolve(KitchenDeviceSettings::class)->update($model, $this->pendingSettings);

        // Servis "geciken eşiği uyarıdan küçük olamaz" kuralını sessizce
        // uyguluyor. Sessiz kalırsak yönetici yazdığı sayının kaydedildiğini
        // sanır ve ekranda başka bir sayı görünce forma güvenmeyi bırakır.
        if ($submittedLate !== null && (int) $submittedLate !== $model->late_after_minutes) {
            flash()->warning(sprintf(
                lang('veykemtu.bridgeapi::default.kds.alert_late_raised'),
                (int) $model->late_after_minutes,
            ));
        }
    }

    // ── Eşleme ────────────────────────────────────────────────────────────

    public function onRefreshPairingCode(string $context, ?string $recordId = null): RedirectResponse
    {
        $device = $this->findDevice($recordId);

        throw_if($device->isRevoked(), new FlashException(
            lang('veykemtu.bridgeapi::default.kds.alert_revoked_device'),
        ));

        $device->refreshPairingCode();

        flash()->success(sprintf(
            lang('veykemtu.bridgeapi::default.kds.alert_code_created'),
            KitchenDevice::PAIRING_TTL_MINUTES,
        ));

        return $this->refresh();
    }

    public function onRevokeDevice(string $context, ?string $recordId = null): RedirectResponse
    {
        $this->findDevice($recordId)->revoke();

        flash()->success(lang('veykemtu.bridgeapi::default.kds.alert_revoked'));

        return $this->refresh();
    }

    // ── Komutlar ──────────────────────────────────────────────────────────

    /**
     * Kasaya tek seferlik bir komut kuyruklar.
     *
     * ANINDA DEĞİL. Komut, kasanın bir sonraki sağlık bildiriminin yanıtına
     * biniyor (`KitchenController::health`); onay mesajı bunu açıkça söyler,
     * yoksa yönetici "olmadı" deyip aynı düğmeye tekrar basar ve iki fiş
     * çıkar.
     */
    public function onSendCommand(string $context, ?string $recordId = null): RedirectResponse
    {
        $device = $this->findDevice($recordId);

        throw_if($device->isRevoked(), new FlashException(
            lang('veykemtu.bridgeapi::default.kds.alert_revoked_device'),
        ));

        $data = $this->validate(post(), [
            [
                'command',
                'lang:veykemtu.bridgeapi::default.kds.label_command',
                'required|string|in:'.implode(',', KitchenCommand::ALL),
            ],
            [
                'order_id',
                'lang:veykemtu.bridgeapi::default.kds.label_order_id',
                'nullable|required_if:command,'.KitchenCommand::REPRINT.'|integer|min:1',
            ],
            [
                'receipt_type',
                'lang:veykemtu.bridgeapi::default.kds.label_receipt_type',
                'nullable|required_if:command,'.KitchenCommand::REPRINT.'|string|in:'.implode(',', PrintJob::TYPES),
            ],
        ]);

        KitchenCommand::create([
            'device_id' => $device->id,
            'command' => $data['command'],
            'payload' => $this->commandPayload($data),
            // DAMGA ELLE VURULUYOR. `Igniter\Flame\Database\Model` zaman
            // damgalarını varsayılan olarak KAPALI tutuyor (`$timestamps =
            // false`), oysa `veykemtu_kitchen_commands` tablosunda sütunlar
            // var. Elle yazılmazsa komut geçmişindeki "Gönderildi" sütunu
            // boş kalır ve "bunu ne zaman göndermiştim" sorusu cevapsız
            // kalırdı — bir komutu ikinci kez göndermeden önce sorulan tek
            // soru da odur.
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        flash()->success(sprintf(
            lang('veykemtu.bridgeapi::default.kds.alert_command_queued'),
            KitchenDevicePanel::commandLabel((string) $data['command']),
            KitchenDevicePanel::commandArrivalSeconds($device),
        ));

        return $this->refresh();
    }

    // ── Yardımcılar ───────────────────────────────────────────────────────

    /**
     * Yalnızca "fişi yeniden bas" bir yük taşır; diğer dördü argümansızdır.
     *
     * @param  array<string, mixed>  $data
     * @return array<string, mixed>|null
     */
    protected function commandPayload(array $data): ?array
    {
        if ($data['command'] !== KitchenCommand::REPRINT) {
            return null;
        }

        return [
            'order_id' => (int) $data['order_id'],
            'type' => (string) $data['receipt_type'],
        ];
    }

    /**
     * Ayar alanlarının listesi servisin kendisinden okunur.
     *
     * Elle yazılmış ikinci bir liste, servise onuncu bir ayar eklendiği gün
     * sessizce eksik kalır ve o ayar formdan kaydedilemez.
     *
     * @return list<string>
     */
    protected function settingFields(Model $model): array
    {
        if (!$model instanceof KitchenDevice) {
            return [];
        }

        $fields = resolve(KitchenDeviceSettings::class)->forDevice($model);

        // `updated_at` servisin okuma biçiminde var ama yazılabilir bir ayar
        // değil; damgayı servis kendisi vuruyor.
        unset($fields['updated_at']);

        return array_keys($fields);
    }

    protected function findDevice(?string $recordId): KitchenDevice
    {
        $device = KitchenDevice::find((int) $recordId);

        throw_unless($device instanceof KitchenDevice, new FlashException(
            sprintf(lang('igniter::admin.form.not_found'), (string) $recordId),
        ));

        return $device;
    }

    protected function preparePanelVars(KitchenDevice $device): void
    {
        $this->vars['device'] = $device;
        $this->vars['connection'] = KitchenDevicePanel::connection($device);
        $this->vars['printer'] = KitchenDevicePanel::printer($device);
        $this->vars['settingsSync'] = KitchenDevicePanel::settingsSync($device);
        $this->vars['lastSeen'] = KitchenDevicePanel::since($device->last_seen_at);
        $this->vars['lastHealth'] = KitchenDevicePanel::since($device->health_reported_at);
        $this->vars['pairingMinutesLeft'] = KitchenDevicePanel::pairingCodeMinutesLeft($device);
        $this->vars['arrivalSeconds'] = KitchenDevicePanel::commandArrivalSeconds($device);
        $this->vars['receiptTypes'] = PrintJob::TYPES;
        $this->vars['commands'] = KitchenCommand::query()
            ->where('device_id', $device->id)
            ->orderByDesc('id')
            ->limit(10)
            ->get();
    }
}
