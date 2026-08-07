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
use Veykemtu\BridgeApi\Models\ClosedDay;

/**
 * Kapalı günler — resmî tatil / üretim yapılmayan günler.
 *
 * Abonelik gece üretim işi bu günleri atlar (bayram sabahı 400 porsiyon
 * pişmesin). Global; aboneliğe özel değil.
 */
class ClosedDays extends AdminController
{
    private const string BASE_URI = AdminRegistrar::CLOSED_DAYS_URI;

    public array $implement = [
        ListController::class,
        FormController::class,
    ];

    public array $listConfig = [
        'list' => [
            'model' => ClosedDay::class,
            'title' => 'lang:veykemtu.bridgeapi::subscription.closed_title',
            'emptyMessage' => 'lang:veykemtu.bridgeapi::subscription.closed_empty',
            'defaultSort' => ['closed_on', 'DESC'],
            'configFile' => 'closedday',
        ],
    ];

    public array $formConfig = [
        'name' => 'lang:veykemtu.bridgeapi::subscription.closed_form_name',
        'model' => ClosedDay::class,
        'create' => [
            'title' => 'lang:veykemtu.bridgeapi::subscription.closed_create_title',
            'redirect' => self::BASE_URI.'/edit/{id}',
            'redirectClose' => self::BASE_URI,
        ],
        'edit' => [
            'title' => 'lang:veykemtu.bridgeapi::subscription.closed_edit_title',
            'redirect' => self::BASE_URI.'/edit/{id}',
            'redirectClose' => self::BASE_URI,
        ],
        'delete' => [
            'redirect' => self::BASE_URI,
        ],
        'configFile' => 'closedday',
    ];

    protected null|string|array $requiredPermissions = AdminRegistrar::PERMISSION_SUBSCRIPTIONS;

    public function __construct()
    {
        parent::__construct();

        AdminMenu::setContext('bld_closed_days', AdminRegistrar::CORPORATE_MENU);
    }

    /** @return array<string, mixed>|false */
    public function formValidate(Model $model, Form $form): array|false
    {
        /** @var array<int, array<int, string>> $rules */
        $rules = array_get($form->config, 'rules', []);

        return $this->validatePasses($form->getSaveData(), $rules);
    }
}
