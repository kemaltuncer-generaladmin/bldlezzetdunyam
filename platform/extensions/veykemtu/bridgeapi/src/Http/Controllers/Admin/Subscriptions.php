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
use Veykemtu\BridgeApi\Models\Subscription;

/**
 * Abonelikler ekranı — mevcut TastyIgniter admin panelinin bir sayfası.
 *
 * İŞ AKIŞI: Müşteri app'ten TALEP açar (`status = pending`, fiyatsız). Admin
 * bu ekranda fiyatı (anlaşmalı porsiyon fiyatı) belirler ve `active` yapar;
 * gece üretim işi o günden sonra sipariş üretmeye başlar.
 *
 * OLUŞTURMA YOK: abonelik müşteri talebinden doğar (ürün satırlarını müşteri
 * seçer). Admin fiyatlandırır/durum yönetir; satırlar formda salt-okunur
 * gösterilir. Bu yüzden `formConfig`'te `create` bağlamı tanımlı değil.
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

    public function __construct()
    {
        parent::__construct();

        AdminMenu::setContext('bld_subscriptions', AdminRegistrar::CORPORATE_MENU);
    }

    /**
     * `resources/models/subscription.php` kurallarını uygular VE doğrulama
     * geçince TÜM form verisini döndürür (yalnız kuralı olan alanlarla
     * daraltmaz) — böylece admin fiyat + durum + takvim alanlarının hepsi
     * kaydedilir.
     *
     * @return array<string, mixed>|false
     */
    public function formValidate(Model $model, Form $form): array|false
    {
        /** @var array<int, array<int, string>> $rules */
        $rules = array_get($form->config, 'rules', []);
        $data = $form->getSaveData();

        return $this->validatePasses($data, $rules) === false ? false : $data;
    }
}
