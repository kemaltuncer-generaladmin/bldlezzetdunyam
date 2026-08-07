<?php

declare(strict_types=1);

use Veykemtu\BridgeApi\Models\AccountLedgerEntry;

/**
 * Cari hareketler listesi — `Veykemtu\BridgeApi\Http\Controllers\Admin\AccountEntries`.
 *
 * Salt liste (append-only defter). Müşteri adı `customer` ilişkisinden gelir;
 * tutar ve tip renk kodlu partial'larla gösterilir.
 */
$config['list']['filter'] = [
    'search' => [
        'prompt' => 'lang:veykemtu.bridgeapi::accountledger.entries_search',
        'mode' => 'all',
    ],
    'scopes' => [
        'entry_type' => [
            'label' => 'lang:veykemtu.bridgeapi::accountledger.filter_type',
            'type' => 'select',
            'conditions' => 'entry_type = :filtered',
            'options' => AccountLedgerEntry::entryTypeOptions(),
        ],
        'date' => [
            'label' => 'lang:veykemtu.bridgeapi::accountledger.filter_date',
            'type' => 'daterange',
            'conditions' => 'effective_date >= CAST(:filtered_start AS DATE) AND effective_date <= CAST(:filtered_end AS DATE)',
        ],
    ],
];

$config['list']['columns'] = [
    'effective_date' => [
        'label' => 'lang:veykemtu.bridgeapi::accountledger.column_date',
        'type' => 'date',
        'sortable' => true,
    ],
    'customer_email' => [
        'label' => 'lang:veykemtu.bridgeapi::accountledger.column_customer',
        'relation' => 'customer',
        'select' => 'email',
        'searchable' => true,
        'sortable' => false,
    ],
    'entry_type' => [
        'label' => 'lang:veykemtu.bridgeapi::accountledger.column_type',
        'type' => 'partial',
        'path' => 'column_type',
        'sortable' => true,
    ],
    'amount_kurus' => [
        'label' => 'lang:veykemtu.bridgeapi::accountledger.column_amount',
        'type' => 'partial',
        'path' => 'column_amount',
        'sortable' => true,
    ],
    'source' => [
        'label' => 'lang:veykemtu.bridgeapi::accountledger.column_source',
        'type' => 'text',
        'sortable' => true,
    ],
    'description' => [
        'label' => 'lang:veykemtu.bridgeapi::accountledger.column_description',
        'type' => 'text',
        'searchable' => true,
        'sortable' => false,
    ],
    'id' => [
        'label' => 'lang:admin::lang.column_id',
        'invisible' => true,
    ],
];

return $config;
