<?php

declare(strict_types=1);

/**
 * Cari hesaplar listesi — `Veykemtu\BridgeApi\Http\Controllers\Admin\CustomerAccounts`.
 *
 * Salt liste: form yok. Bakiye kaydedilmez, `column_balance` partial'ı her
 * satırda `AccountLedger::balance` ile hesaplar (borç kırmızı, alacak yeşil).
 */
$config['list']['filter'] = [
    'search' => [
        'prompt' => 'lang:veykemtu.bridgeapi::accountledger.accounts_search',
        'mode' => 'all',
    ],
];

$config['list']['columns'] = [
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
    'customer_id' => [
        'label' => 'lang:admin::lang.column_id',
        'invisible' => true,
    ],
];

return $config;
