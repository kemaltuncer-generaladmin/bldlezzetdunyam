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
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Request;
use Veykemtu\BridgeApi\Admin\AdminRegistrar;
use Veykemtu\BridgeApi\Admin\LiraField;
use Veykemtu\BridgeApi\Models\AccountLedgerEntry;
use Veykemtu\BridgeApi\Models\ApiCustomer;
use Veykemtu\BridgeApi\Services\AccountLedger;
use Veykemtu\BridgeApi\Support\BusinessTime;

/**
 * Cari hesaplar — kurumsal müşterinin bakiyesi, limiti, ekstresi ve tahsilatı.
 *
 * TAHSİLAT AYRI BİR EKRAN DEĞİL, BU EKRANIN İÇİNDE (B-14). Ayrı bir "tahsilat
 * girişi" sayfası, yöneticiye önce müşteriyi bir açılır listeden bulmayı
 * zorunlu kılardı — oysa tahsilat kararı zaten müşterinin ekstresine
 * bakarken veriliyor. Bakiyeyi gördüğü yerde "2.500 TL tahsil edildi"
 * yazabilmesi, hem daha az tıklama hem de yanlış müşteriye yazma riskinin
 * ortadan kalkması demek.
 *
 * OLUŞTURMA/SİLME YOK: müşteri kaydı çekirdeğin Müşteriler ekranındadır ve
 * defter append-only'dir (`docs/02` §7.2) — yanlış girilen hareket silinmez,
 * ters kayıtla düzeltilir.
 */
class CustomerAccounts extends AdminController
{
    private const string BASE_URI = AdminRegistrar::ACCOUNTS_URI;

    public array $implement = [
        ListController::class,
        FormController::class,
    ];

    public array $listConfig = [
        'list' => [
            'model' => ApiCustomer::class,
            'title' => 'lang:veykemtu.bridgeapi::accountledger.accounts_title',
            'emptyMessage' => 'lang:veykemtu.bridgeapi::accountledger.accounts_empty',
            'defaultSort' => ['customer_id', 'DESC'],
            'configFile' => 'customeraccount',
        ],
    ];

    public array $formConfig = [
        'name' => 'lang:veykemtu.bridgeapi::accountledger.form_name',
        'model' => ApiCustomer::class,
        'edit' => [
            'title' => 'lang:veykemtu.bridgeapi::accountledger.form_edit_title',
            'redirect' => self::BASE_URI.'/edit/{customer_id}',
            'redirectClose' => self::BASE_URI,
        ],
        'configFile' => 'customeraccount',
    ];

    protected null|string|array $requiredPermissions = AdminRegistrar::PERMISSION_ACCOUNT;

    public function __construct()
    {
        parent::__construct();

        AdminMenu::setContext('bld_customer_accounts', AdminRegistrar::CORPORATE_MENU);
    }

    /**
     * Yalnızca kurumsal müşteriler listelenir — cari yalnız onlarda anlamlı.
     */
    public function listExtendQuery($query): void
    {
        $query->where('bld_account_type', 'corporate');
    }

    /**
     * `resources/models/customeraccount.php` kurallarını uygular VE doğrulama
     * geçince tüm form verisini döndürür (`Subscriptions` ile aynı gerekçe:
     * yalnız kuralı olan alanlarla daraltmak, kuralsız alanları kaydetmezdi).
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

    /**
     * Tahsilat kaydeder: deftere ALACAK hareketi yazar.
     *
     * MAKBUZ NUMARASI ZORUNLU VE SAYISAL. Sebep defterin idempotency
     * indeksinde: `(source, reference_type, reference_id, entry_type)` —
     * `customer_id` İÇERMİYOR. Yani bu numara sistem genelinde tekildir ve
     * bu tam olarak istediğimiz şeydir: bir makbuz tek bir tahsilattır,
     * yanlışlıkla ikinci bir müşteriye de işlenemez. İşletmede tek makbuz
     * serisi var; numara zaten küresel.
     *
     * `reference_id` NULL BIRAKILMIYOR: migration yorumunun dediği gibi
     * MySQL NULL'ları tekil saymıyor, yani null referanslı manuel hareket
     * hiçbir tekilleştirmeye takılmaz. Kaydet'e iki kez basan yönetici aynı
     * tahsilatı iki kez yazar ve bakiye olduğundan düşük görünür.
     *
     * ÇAKIŞMA SESSİZ KALMASIN DİYE ÖNCE SORULUYOR: `record()` içeride
     * `insertOrIgnore` kullanıyor, yani var olan bir makbuz numarası hiçbir
     * hata vermeden yutulur ve yönetici "kaydedildi" görüp ekstrede satırı
     * bulamazdı. `hasEntry` ile önce bakıp açık bir hata veriyoruz.
     *
     * Tutar POZİTİF olmak zorunda: negatif bir "tahsilat", borç yazmanın
     * dolambaçlı yolu olurdu ve ekstrede yanlış satır tipiyle görünürdü.
     * Borç eklemek isteyen `veykemtu:cari-hareket` komutunu kullanır — o
     * kararın panelden kolayca verilememesi bilinçlidir.
     *
     * İMZA `($context, $recordId)` OLMAK ZORUNDA. Çekirdek eylem
     * işleyicilerini `[$this->action, ...$this->params]` ile çağırıyor
     * (`AdminController::processHandlers`), yani ilk argüman HER ZAMAN
     * bağlam adıdır (`edit`). Tek parametreli yazıldığında `$recordId`
     * değeri `"edit"` oluyor, müşteri bulunamıyor ve ekran sebebi
     * anlaşılmayan bir 406 dönüyordu.
     */
    public function onRecordPayment(string $context, ?string $recordId = null): RedirectResponse
    {
        $customer = $this->locateCustomer($recordId);

        $post = Request::post();
        $amount = LiraField::toKurus($post['payment_amount'] ?? '');

        throw_if($amount <= 0, new FlashException(
            lang('veykemtu.bridgeapi::accountledger.alert_payment_amount'),
        ));

        $receiptNo = trim((string) ($post['payment_receipt'] ?? ''));

        throw_unless(
            $receiptNo !== '' && ctype_digit($receiptNo) && (int) $receiptNo > 0,
            new FlashException(lang('veykemtu.bridgeapi::accountledger.alert_payment_receipt')),
        );

        $ledger = resolve(AccountLedger::class);

        throw_if(
            $ledger->hasEntry(
                AccountLedgerEntry::SOURCE_PAYMENT,
                'receipt',
                (int) $receiptNo,
                AccountLedgerEntry::TYPE_CREDIT,
            ),
            new FlashException(sprintf(
                lang('veykemtu.bridgeapi::accountledger.alert_payment_duplicate'),
                $receiptNo,
            )),
        );

        $date = trim((string) ($post['payment_date'] ?? ''));
        $effective = $date === ''
            ? BusinessTime::now()
            : Carbon::parse($date, BusinessTime::ZONE);

        $ledger->record(
            customerId: (int) $customer->customer_id,
            type: AccountLedgerEntry::TYPE_CREDIT,
            amountKurus: $amount,
            source: AccountLedgerEntry::SOURCE_PAYMENT,
            referenceType: 'receipt',
            referenceId: (int) $receiptNo,
            description: lang('veykemtu.bridgeapi::accountledger.payment_description')
                .' — '.lang('veykemtu.bridgeapi::accountledger.label_payment_receipt').' '.$receiptNo,
            effectiveDate: $effective,
            createdBy: (int) ($this->currentUser?->getKey() ?? 0) ?: null,
        );

        flash()->success(lang('veykemtu.bridgeapi::accountledger.alert_payment_saved'));

        return $this->redirect(self::BASE_URI.'/edit/'.$customer->customer_id);
    }

    private function locateCustomer(?string $recordId): ApiCustomer
    {
        $customer = ApiCustomer::query()->find((int) $recordId);

        throw_unless($customer instanceof ApiCustomer, new FlashException(
            lang('veykemtu.bridgeapi::accountledger.alert_customer_missing'),
        ));

        return $customer;
    }
}
