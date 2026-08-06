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
use Veykemtu\BridgeApi\Models\SitePost;

/**
 * Bilgi merkezi yazıları ekranı.
 *
 * Hizmet ekranıyla aynı gerekçe: yazılar kodda değil, panelde yaşamalı.
 * Ayrı bir denetleyici olmasının sebebi alanların ortak olmaması — yazının
 * sırası ve ikonu yok, hizmetin yayın tarihi ve okuma süresi yok. Tek
 * denetleyiciye sıkıştırmak her iki formu da bağlam anahtarlarıyla dolu bir
 * yapılandırmaya çevirirdi.
 */
class SitePosts extends AdminController
{
    /** Rota ve yönlendirmelerde kullanılan taban yol. */
    private const string BASE_URI = AdminRegistrar::POSTS_URI;

    public array $implement = [
        ListController::class,
        FormController::class,
    ];

    public array $listConfig = [
        'list' => [
            'model' => SitePost::class,
            'title' => 'lang:veykemtu.bridgeapi::default.posts.text_title',
            'emptyMessage' => 'lang:veykemtu.bridgeapi::default.posts.text_empty',
            // Sitedeki sırayla aynı: en yeni yazı üstte
            // (`SitePost::scopePublished`).
            'defaultSort' => ['published_at', 'DESC'],
            'configFile' => 'sitepost',
        ],
    ];

    public array $formConfig = [
        'name' => 'lang:veykemtu.bridgeapi::default.posts.text_form_name',
        'model' => SitePost::class,
        'create' => [
            'title' => 'lang:veykemtu.bridgeapi::default.posts.text_create_title',
            'redirect' => self::BASE_URI.'/edit/{id}',
            'redirectClose' => self::BASE_URI,
        ],
        'edit' => [
            'title' => 'lang:veykemtu.bridgeapi::default.posts.text_edit_title',
            'redirect' => self::BASE_URI.'/edit/{id}',
            'redirectClose' => self::BASE_URI,
        ],
        'delete' => [
            'redirect' => self::BASE_URI,
        ],
        'configFile' => 'sitepost',
    ];

    protected null|string|array $requiredPermissions = AdminRegistrar::PERMISSION_CONTENT;

    public function __construct()
    {
        parent::__construct();

        AdminMenu::setContext('bld_site_posts', AdminRegistrar::CONTENT_MENU);
    }

    /**
     * @return array<string, mixed>|false
     */
    public function formValidate(Model $model, Form $form): array|false
    {
        /** @var array<int, array<int, string>> $rules */
        $rules = array_get($form->config, 'rules', []);

        $validated = $this->validatePasses($form->getSaveData(), $this->withSlugRule($rules, $model));

        if ($validated === false) {
            return false;
        }

        // BOŞ ALAN SIFIR DEĞİL, NULL OLARAK KAYDEDİLİYOR. `SitePost::readingMinutes()`
        // "elle girildi mi" sorusunu `null` kontrolüyle cevaplıyor; boş alan
        // `0` olarak yazılsaydı sütun dolu görünür ve formu bir daha açan
        // yönetici oraya kendisinin bir değer girdiğini sanırdı.
        $minutes = $validated['reading_minutes'] ?? null;
        $validated['reading_minutes'] = ($minutes === null || $minutes === '') ? null : (int) $minutes;

        return $validated;
    }

    /**
     * Gerekçe `SiteServices::withSlugRule` üzerinde — aynı sorun, başka tablo.
     *
     * @param  array<int, array<int, string>>  $rules
     * @return array<int, array<int, string>>
     */
    private function withSlugRule(array $rules, Model $model): array
    {
        $ignore = $model->exists ? ','.$model->getKey().',id' : '';

        foreach ($rules as $index => $rule) {
            if (($rule[0] ?? null) === 'slug') {
                $rules[$index][2] = ($rule[2] ?? '').'|unique:veykemtu_site_posts,slug'.$ignore;
            }
        }

        return $rules;
    }
}
