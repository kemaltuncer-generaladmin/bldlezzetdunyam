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
use Veykemtu\BridgeApi\Admin\RepeaterList;
use Veykemtu\BridgeApi\Models\SiteService;

/**
 * Kurumsal sitedeki hizmetler ekranı.
 *
 * Bu ekran olmadan hizmet metinleri yalnızca `website/content/services.ts`
 * dosyasında, yani kodda yaşıyordu: bir cümleyi düzeltmek için geliştirici,
 * derleme ve yayın gerekiyordu. Buradan girilen kayıt `SiteContentRepository`
 * paketine düşer ve site onu okur.
 *
 * SİLME VAR (kasa ekranından farklı olarak). Bir hizmete bağlı sipariş,
 * kuyruk veya geçmiş yok; yanlış eklenen kaydı taşımanın anlamı olmaz.
 * Yine de günlük yol silme değil, YAYINDAN KALDIRMADIR (`is_published`):
 * silinen kaydın adresi 404 verir, yayından kaldırılan kayıt geri
 * getirilebilir.
 */
class SiteServices extends AdminController
{
    /** Rota ve yönlendirmelerde kullanılan taban yol. */
    private const string BASE_URI = AdminRegistrar::SERVICES_URI;

    /**
     * Tek metinli tekrarlayıcı alanları.
     *
     * Veritabanında düz metin listesi, formda satır dizisi olarak duruyorlar;
     * çevirinin gerekçesi `Admin\RepeaterList` sınıf yorumundadır. Liste tek
     * yerde: yükleme ve kaydetme yönleri ayrı ayrı sayılsaydı biri diğerinden
     * sapabilir ve o alan sessizce kaydedilmez olurdu.
     *
     * `how_it_works` BU LİSTEDE DEĞİL: satırları iki alanlı (`title`, `body`)
     * ve tekrarlayıcının doğal biçimiyle zaten örtüşüyor.
     *
     * @var list<string>
     */
    private const array TEXT_LISTS = ['audience', 'benefits', 'quote_needs'];

    public array $implement = [
        ListController::class,
        FormController::class,
    ];

    public array $listConfig = [
        'list' => [
            'model' => SiteService::class,
            'title' => 'lang:veykemtu.bridgeapi::default.services.text_title',
            'emptyMessage' => 'lang:veykemtu.bridgeapi::default.services.text_empty',
            // Sitedeki sıra bu sütundan doğuyor; liste de aynı sırayı
            // göstermezse yönetici kartların neden o düzende çıktığını
            // panelde göremez.
            'defaultSort' => ['sort_order', 'ASC'],
            'configFile' => 'siteservice',
        ],
    ];

    public array $formConfig = [
        'name' => 'lang:veykemtu.bridgeapi::default.services.text_form_name',
        'model' => SiteService::class,
        'create' => [
            'title' => 'lang:veykemtu.bridgeapi::default.services.text_create_title',
            'redirect' => self::BASE_URI.'/edit/{id}',
            'redirectClose' => self::BASE_URI,
        ],
        'edit' => [
            'title' => 'lang:veykemtu.bridgeapi::default.services.text_edit_title',
            'redirect' => self::BASE_URI.'/edit/{id}',
            'redirectClose' => self::BASE_URI,
        ],
        'delete' => [
            'redirect' => self::BASE_URI,
        ],
        'configFile' => 'siteservice',
    ];

    protected null|string|array $requiredPermissions = AdminRegistrar::PERMISSION_CONTENT;

    public function __construct()
    {
        parent::__construct();

        AdminMenu::setContext('bld_site_services', AdminRegistrar::CONTENT_MENU);
    }

    /**
     * Kaydı forma vermeden önce düz listeleri tekrarlayıcı satırına çevirir.
     *
     * `formExtendFieldsBefore` seçildi çünkü alanlar kurulmadan hemen önce
     * çalışıyor ve modele erişimi var. Kaydetme yolunda da tetikleniyor ama
     * zararsız: kaydedilecek veri POST'tan okunuyor (`Form::getSaveData`),
     * modelin o andaki değerinden değil.
     */
    public function formExtendFieldsBefore(Form $form): void
    {
        if (! $form->model instanceof SiteService) {
            return;
        }

        foreach (self::TEXT_LISTS as $field) {
            $form->model->{$field} = RepeaterList::toRows($form->model->{$field});
        }
    }

    /**
     * @return array<string, mixed>|false
     */
    public function formValidate(Model $model, Form $form): array|false
    {
        /** @var array<string, mixed> $saveData */
        $saveData = $form->getSaveData();

        /** @var array<int, array<int, string>> $rules */
        $rules = array_get($form->config, 'rules', []);

        $validated = $this->validatePasses($saveData, $this->withSlugRule($rules, $model));

        if ($validated === false) {
            return false;
        }

        // Tekrarlayıcı satırları burada düzleştiriliyor — doğrulamadan SONRA,
        // çünkü kurallar (`audience.*.text`) satır biçimine yazılmış.
        // Değerler doğrulanmış diziden değil ham `$saveData`'dan alınıyor:
        // yönetici son maddeyi de silip kaydettiğinde alan POST'ta boş dizi
        // olarak geliyor ve `validated()` boş diziyi atlarsa eski maddeler
        // kayıtta kalırdı — yani "sildim ama geri geldi".
        foreach (self::TEXT_LISTS as $field) {
            $validated[$field] = RepeaterList::toValues($saveData[$field] ?? []);
        }

        $validated['how_it_works'] = $this->cleanSteps($saveData['how_it_works'] ?? []);

        // Sütun `unsignedSmallInteger NOT NULL`: boş bırakılan alan MySQL katı
        // kipinde kaydı patlatırdı. Boş sıra "en sonda" değil "sırasız"
        // demektir ve sıfır tam olarak bunu ifade eder.
        $validated['sort_order'] = (int) ($validated['sort_order'] ?? 0);

        return $validated;
    }

    /**
     * Benzersizlik kuralını düzenlenen kaydı hariç tutarak ekler.
     *
     * KURAL YAPILANDIRMA DOSYASINDA DEĞİL: `resources/models/siteservice.php`
     * kaydın kimliğini bilmiyor (düz bir dizi döndürüyor, bağlam almıyor).
     * Oradan `unique:veykemtu_site_services,slug` yazılsaydı, bir hizmeti
     * açıp adresine dokunmadan kaydetmek "bu adres kullanılıyor" hatası
     * verirdi — kendi kendisiyle çakışırdı.
     *
     * @param  array<int, array<int, string>>  $rules
     * @return array<int, array<int, string>>
     */
    private function withSlugRule(array $rules, Model $model): array
    {
        $ignore = $model->exists ? ','.$model->getKey().',id' : '';

        foreach ($rules as $index => $rule) {
            if (($rule[0] ?? null) === 'slug') {
                $rules[$index][2] = ($rule[2] ?? '').'|unique:veykemtu_site_services,slug'.$ignore;
            }
        }

        return $rules;
    }

    /**
     * "Nasıl işler" adımlarından boş satırları düşürür.
     *
     * Başlığı ve gövdesi boş bir adım sitede numaralı ama içeriksiz bir kutu
     * çizerdi; tekrarlayıcıda "ekle"ye basıp doldurmadan kaydetmek sık olur.
     *
     * @return list<array{title: string, body: string}>
     */
    private function cleanSteps(mixed $rows): array
    {
        if (! is_array($rows)) {
            return [];
        }

        $steps = [];
        foreach ($rows as $row) {
            $title = trim((string) (is_array($row) ? ($row['title'] ?? '') : ''));
            $body = trim((string) (is_array($row) ? ($row['body'] ?? '') : ''));

            if ($title !== '' || $body !== '') {
                $steps[] = ['title' => $title, 'body' => $body];
            }
        }

        return $steps;
    }
}
