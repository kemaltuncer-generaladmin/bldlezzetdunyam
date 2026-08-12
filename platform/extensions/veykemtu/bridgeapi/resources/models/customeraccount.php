<?php

declare(strict_types=1);

/**
 * Cari hesaplar listesi ve müşteri kartı —
 * `Veykemtu\BridgeApi\Http\Controllers\Admin\CustomerAccounts`.
 *
 * Bakiye kaydedilmez, `column_balance` partial'ı her satırda
 * `AccountLedger::balance` ile hesaplar (borç kırmızı, alacak yeşil).
 *
 * Formda düzenlenebilen TEK alan borç limitidir. Müşterinin adı, e-postası,
 * unvanı burada değiştirilemez — o kayıt çekirdeğin Müşteriler ekranına ait.
 * İki ekranda birden düzenlenebilir bir alan, hangisinin kazandığı belirsiz
 * bir yarış yaratırdı.
 */
$config['list']['filter'] = [
    'search' => [
        'prompt' => 'lang:veykemtu.bridgeapi::accountledger.accounts_search',
        'mode' => 'all',
    ],
    'scopes' => [
        /*
         * "Borcu olanlar" filtresi bir tarama değil, günlük iş: tahsilat
         * yapacak kişi otuz müşteri arasından borçluları gözle ayıklamak
         * zorunda kalmasın.
         *
         * `conditions` ham SQL çünkü bakiye bir kolon değil, defterin
         * toplamı — Eloquent scope'u ile ifade edilemiyor.
         */
        'borclu' => [
            'label' => 'lang:veykemtu.bridgeapi::accountledger.filter_debtors',
            'type' => 'switch',
            'conditions' => 'customer_id IN ('
                .'SELECT customer_id FROM veykemtu_account_ledger '
                ."GROUP BY customer_id HAVING SUM(CASE WHEN entry_type = 'debit' "
                .'THEN amount_kurus ELSE -amount_kurus END) > 0)',
        ],
    ],
];

$config['list']['columns'] = [
    'edit' => [
        'type' => 'button',
        'iconCssClass' => 'fa fa-pencil',
        'attributes' => [
            'class' => 'btn btn-edit',
            'href' => 'veykemtu/bridgeapi/customer_accounts/edit/{customer_id}',
        ],
    ],
    'bld_org_name' => [
        'label' => 'lang:veykemtu.bridgeapi::accountledger.column_org',
        'type' => 'text',
        'searchable' => true,
        'sortable' => true,
    ],
    'bld_contact_person' => [
        'label' => 'lang:veykemtu.bridgeapi::accountledger.column_contact',
        'type' => 'text',
        'searchable' => true,
        'sortable' => false,
    ],
    'email' => [
        'label' => 'lang:veykemtu.bridgeapi::accountledger.column_email',
        'type' => 'text',
        'searchable' => true,
        'sortable' => false,
    ],
    'telephone' => [
        'label' => 'lang:veykemtu.bridgeapi::accountledger.column_telephone',
        'type' => 'text',
        'searchable' => true,
        'sortable' => false,
    ],
    'balance' => [
        'label' => 'lang:veykemtu.bridgeapi::accountledger.column_balance',
        'type' => 'partial',
        'path' => 'column_balance',
    ],
    'credit_limit' => [
        'label' => 'lang:veykemtu.bridgeapi::accountledger.column_limit',
        'type' => 'partial',
        'path' => 'column_limit',
    ],
    'customer_id' => [
        'label' => 'lang:admin::lang.column_id',
        'invisible' => true,
    ],
];

$config['form']['toolbar'] = [
    'buttons' => [
        'back' => [
            'label' => 'lang:admin::lang.button_icon_back',
            'class' => 'btn btn-outline-secondary',
            'href' => 'veykemtu/bridgeapi/customer_accounts',
        ],
        'save' => [
            'label' => 'lang:admin::lang.button_save',
            'class' => 'btn btn-primary',
            'data-request' => 'onSave',
            'data-progress-indicator' => 'admin::lang.text_saving',
            'context' => ['edit'],
        ],
    ],
];

$config['form']['fields'] = [
    /*
     * ÖZET EN ÜSTTE: yönetici bu ekrana "ne kadar borcu var" sorusuyla
     * geliyor. Limit alanı ya da ekstre önce gelseydi, cevabı bulmak için
     * kaydırması gerekirdi.
     */
    '_summary' => [
        'type' => 'partial',
        'path' => 'account_summary',
    ],
    'limit_section' => [
        'type' => 'section',
        'label' => 'lang:veykemtu.bridgeapi::accountledger.section_limit',
        'comment' => 'lang:veykemtu.bridgeapi::accountledger.section_limit_comment',
    ],
    'credit_limit_lira' => [
        'label' => 'lang:veykemtu.bridgeapi::accountledger.label_limit',
        // `text`, `number` DEĞİL: gerekçe `Admin\LiraField` sınıf yorumunda —
        // çekirdek `number` alanını postback'te `(int)` ile daraltıyor ve
        // kuruşlar kayboluyor.
        'type' => 'text',
        'span' => 'left',
        'comment' => 'lang:veykemtu.bridgeapi::accountledger.help_limit',
    ],
    'payment_section' => [
        'type' => 'section',
        'label' => 'lang:veykemtu.bridgeapi::accountledger.section_payment',
        'comment' => 'lang:veykemtu.bridgeapi::accountledger.section_payment_comment',
    ],
    '_payment' => [
        'type' => 'partial',
        'path' => 'account_payment',
    ],
    'statement_section' => [
        'type' => 'section',
        'label' => 'lang:veykemtu.bridgeapi::accountledger.section_statement',
        'comment' => 'lang:veykemtu.bridgeapi::accountledger.section_statement_comment',
    ],
    '_statement' => [
        'type' => 'partial',
        'path' => 'account_statement',
    ],
];

$config['form']['rules'] = [
    [
        'credit_limit_lira',
        'lang:veykemtu.bridgeapi::accountledger.label_limit',
        // `nullable` + boş metin: boş = limitsiz, "0" = cari kapalı.
        // Ayrım `ApiCustomer::setCreditLimitLiraAttribute` içinde korunuyor.
        'nullable|string|max:32',
    ],
];

return $config;
