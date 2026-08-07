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
use Veykemtu\BridgeApi\Models\QuoteRequest;

/**
 * Teklif talepleri ekranı — sitedeki "Teklif Al" formunun düştüğü yer.
 *
 * OLUŞTURMA YOK. Talep yalnızca `POST /api/quote-requests` ile doğar; panelden
 * el ile talep eklemek, "ziyaretçi ne gönderdi" sorusunun cevabını
 * bulanıklaştırırdı. Bu yüzden liste araç çubuğunda "Yeni" düğmesi yok ve
 * `formConfig`'te `create` bağlamı tanımlı değil.
 *
 * ZİYARETÇİNİN GÖNDERDİĞİ ALANLAR DÜZENLENEMEZ. Hepsi formda `disabled`;
 * çekirdek `disabled` alanları kaydedilecek veriden tamamen çıkarıyor
 * (`Widgets\Form::getSaveData`), yani salt okunurluk arayüz süsü değil,
 * gerçekten uygulanıyor. Gerekçe: bu satırlar bir kişinin bize ilettiği
 * beyandır; yönetici yazım hatasını "düzeltirse" kaydın delil değeri gider.
 * Panelden değişen tek iki şey firmanın kendi takip alanları: `status` ve
 * `admin_note`.
 *
 * SİLME VAR. KVKK'da kişinin verisinin silinmesini isteme hakkı var ve bu
 * ekran o talebi karşılayabilecek tek yer; silmeyi kapatmak, hakkın yerine
 * getirilmesini veritabanına elle girmeye bağlardı.
 */
class QuoteRequests extends AdminController
{
    /** Rota ve yönlendirmelerde kullanılan taban yol. */
    private const string BASE_URI = AdminRegistrar::QUOTES_URI;

    public array $implement = [
        ListController::class,
        FormController::class,
    ];

    public array $listConfig = [
        'list' => [
            'model' => QuoteRequest::class,
            'title' => 'lang:veykemtu.bridgeapi::quoterequest.text_title',
            'emptyMessage' => 'lang:veykemtu.bridgeapi::quoterequest.text_empty',
            // En yeni talep en üstte: bu listeye bakma sebebi "bugün ne geldi".
            // `QuoteRequest::scopeNewestFirst` ile aynı sıra.
            'defaultSort' => ['created_at', 'DESC'],
            'configFile' => 'quoterequest',
        ],
    ];

    public array $formConfig = [
        'name' => 'lang:veykemtu.bridgeapi::quoterequest.text_form_name',
        'model' => QuoteRequest::class,
        'edit' => [
            'title' => 'lang:veykemtu.bridgeapi::quoterequest.text_edit_title',
            'redirect' => self::BASE_URI.'/edit/{id}',
            'redirectClose' => self::BASE_URI,
        ],
        'delete' => [
            'redirect' => self::BASE_URI,
        ],
        'configFile' => 'quoterequest',
    ];

    protected null|string|array $requiredPermissions = AdminRegistrar::PERMISSION_QUOTES;

    public function __construct()
    {
        parent::__construct();

        AdminMenu::setContext('bld_quote_requests', AdminRegistrar::CONTENT_MENU);
    }

    /**
     * `resources/models/quoterequest.php` içindeki kuralları uygular.
     *
     * BU METOT OLMADAN KURALLAR HİÇ ÇALIŞMAZ. Çekirdeğin varsayılan
     * `formValidate`'i boş bir gövdedir (`Traits\FormExtendable`) ve
     * `$config['form']['rules']` kendiliğinden okunmaz; kural dizisi
     * yazılıp burası unutulsaydı doğrulama sessizce yok sayılır ve durum
     * alanına elle gönderilen uydurma bir değer kaydedilirdi.
     *
     * Dönen `validated` dizisi kaydedilecek veriyi de DARALTIYOR: yalnızca
     * kuralı olan iki alan (`status`, `admin_note`) geçiyor. Ziyaretçinin
     * beyanı zaten formda yok, ama forma elle eklenen bir alan da bu
     * süzgeçten geçemiyor.
     *
     * @return array<string, mixed>|false
     */
    public function formValidate(Model $model, Form $form): array|false
    {
        /** @var array<int, array<int, string>> $rules */
        $rules = array_get($form->config, 'rules', []);

        return $this->validatePasses($form->getSaveData(), $rules);
    }
}
