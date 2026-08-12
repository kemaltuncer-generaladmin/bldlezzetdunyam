<?php

declare(strict_types=1);

namespace Veykemtu\BridgeApi\Http\Controllers\Admin;

use Igniter\Admin\Classes\AdminController;
use Igniter\Admin\Facades\AdminMenu;
use Igniter\Admin\Http\Actions\FormController;
use Igniter\Admin\Http\Actions\ListController;
use Igniter\Admin\Widgets\Form;
use Igniter\Flame\Database\Model;
use Veykemtu\BridgeApi\Admin\AdminRegistrar;
use Veykemtu\BridgeApi\Admin\SettingsRepository;
use Veykemtu\BridgeApi\Models\Subscription;
use Veykemtu\BridgeApi\Models\SubscriptionLine;

/**
 * Abonelikler ekranı — mevcut TastyIgniter admin panelinin bir sayfası.
 *
 * İKİ DOĞUŞ YOLU VAR:
 *
 *  1. Müşteri uygulamadan TALEP açar (`status = pending`, fiyatsız). Admin
 *     fiyatı belirler ve `active` yapar.
 *  2. Admin panelden DOĞRUDAN oluşturur (B-16). Kurumsal satış çoğu zaman
 *     masa başında konuşulup bitiyor; müşteriden "önce uygulamadan talep
 *     açın" istemek, anlaşmanın hiç sisteme girmemesine yol açıyordu.
 *
 * Bu yüzden `create` bağlamı var ve düzenleme bağlamından daha geniş:
 * oluştururken takvim ve ürün satırları da giriliyor, düzenlerken bunlar
 * salt-okunur kalıyor. Sebep, düzenlemenin ÜRETİM SÜRERKEN yapılması:
 * çalışan bir aboneliğin gün listesini form üzerinden değiştirmek, o güne
 * ait üretilmiş siparişlerle kuralın ayrışması demek. Takvim değişikliği
 * duraklatma ve istisna kayıtlarıyla yapılır.
 */
class Subscriptions extends AdminController
{
    private const string BASE_URI = AdminRegistrar::SUBSCRIPTIONS_URI;

    public array $implement = [
        ListController::class,
        FormController::class,
    ];

    public array $listConfig = [
        'list' => [
            'model' => Subscription::class,
            'title' => 'lang:veykemtu.bridgeapi::subscription.text_title',
            'emptyMessage' => 'lang:veykemtu.bridgeapi::subscription.text_empty',
            'defaultSort' => ['id', 'DESC'],
            'configFile' => 'subscription',
        ],
    ];

    public array $formConfig = [
        'name' => 'lang:veykemtu.bridgeapi::subscription.text_form_name',
        'model' => Subscription::class,
        'create' => [
            'title' => 'lang:veykemtu.bridgeapi::subscription.text_create_title',
            'redirect' => self::BASE_URI.'/edit/{id}',
            'redirectClose' => self::BASE_URI,
        ],
        'edit' => [
            'title' => 'lang:veykemtu.bridgeapi::subscription.text_edit_title',
            'redirect' => self::BASE_URI.'/edit/{id}',
            'redirectClose' => self::BASE_URI,
        ],
        'delete' => [
            'redirect' => self::BASE_URI,
        ],
        'configFile' => 'subscription',
    ];

    protected null|string|array $requiredPermissions = AdminRegistrar::PERMISSION_SUBSCRIPTIONS;

    /**
     * `formValidate` ile `formAfterSave` arasında taşınan ürün satırları.
     *
     * NEDEN MODELE DOĞRUDAN YAZILMIYOR: satırlar `veykemtu_subscription_lines`
     * tablosunda, aboneliğin kendi sütunlarında değil. Repeater alanının
     * değeri modele bir öznitelik olarak ulaşsaydı, kayıt sırasında
     * "böyle bir sütun yok" hatasıyla düşerdi. Aynı desen
     * `KitchenDevices::$pendingSettings`.
     *
     * @var list<array<string, mixed>>|null
     */
    protected ?array $pendingLines = null;

    public function __construct()
    {
        parent::__construct();

        AdminMenu::setContext('bld_subscriptions', AdminRegistrar::CORPORATE_MENU);
    }

    /**
     * Yeni abonelik: vitrin ve varsayılanlar önceden dolduruluyor.
     *
     * `location_id` formda sorulmuyor. Faz 1'de tek vitrin var
     * (`IGNITER_LOCATION_MODE=single`) ve yöneticiye tek seçenekli bir
     * açılır liste göstermek, cevabı belli bir soru sormaktır.
     */
    public function formExtendModel(Model $model): void
    {
        if (!$model instanceof Subscription || $model->exists) {
            return;
        }

        $model->location_id ??= resolve(SettingsRepository::class)->location()?->location_id;
        $model->status ??= Subscription::STATUS_ACTIVE;
        $model->menu_mode ??= Subscription::MENU_FIXED_LIST;
        $model->payment_mode ??= Subscription::PAYMENT_ACCOUNT;
        $model->delivery_type ??= 'delivery';
        $model->default_quantity ??= 1;
    }

    /**
     * `resources/models/subscription.php` kurallarını uygular VE doğrulama
     * geçince TÜM form verisini döndürür (yalnız kuralı olan alanlarla
     * daraltmaz) — böylece admin fiyat + durum + takvim alanlarının hepsi
     * kaydedilir.
     *
     * Ürün satırları buradan ÇIKARILIYOR: ilişkili tabloya aitler ve
     * kaydetme sırası önemli (önce abonelik doğmalı ki satırın
     * `subscription_id`'si olsun).
     *
     * @return array<string, mixed>|false
     */
    public function formValidate(Model $model, Form $form): array|false
    {
        /** @var array<int, array<int, string>> $rules */
        $rules = array_get($form->config, 'rules', []);
        $data = $form->getSaveData();

        if ($this->validatePasses($data, $rules) === false) {
            return false;
        }

        if (array_key_exists('line_items', $data)) {
            $this->pendingLines = array_values((array) $data['line_items']);
            unset($data['line_items']);
        }

        return $data;
    }

    /**
     * Ürün satırlarını yazar — YALNIZCA OLUŞTURMADA.
     *
     * Düzenlemede satırlara dokunulmuyor: `formAfterSave` her kaydetmede
     * koşuyor ve satırları silip yeniden yazmak, o satırlara bakan
     * üretilmiş siparişlerin geçmişini bozardı. Çalışan bir aboneliğin
     * içeriğini değiştirmek yeni bir abonelik açmayı gerektirir; bu,
     * sözleşme değişikliğinin doğru karşılığı.
     */
    public function formAfterCreate(Model $model): void
    {
        if (!$model instanceof Subscription || $this->pendingLines === null) {
            return;
        }

        foreach ($this->pendingLines as $row) {
            $menuId = (int) ($row['menu_id'] ?? 0);
            $quantity = (int) ($row['quantity'] ?? 0);

            // Boş repeater satırları sessizce atlanır; yönetici eklediği
            // ama doldurmadığı bir satırı silmek zorunda kalmasın.
            if ($menuId <= 0 || $quantity <= 0) {
                continue;
            }

            $line = new SubscriptionLine;
            $line->subscription_id = (int) $model->id;
            $line->menu_id = $menuId;
            $line->quantity = $quantity;
            $line->label = trim((string) ($row['label'] ?? '')) ?: null;
            $line->save();
        }

        $this->pendingLines = null;
    }
}
