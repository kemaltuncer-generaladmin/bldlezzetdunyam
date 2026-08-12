<?php

declare(strict_types=1);

/**
 * Günlük "tükendi" geçmişi listesi —
 * `Veykemtu\BridgeApi\Http\Controllers\Admin\MenuSoldOuts`.
 *
 * Form YOK: bugünün satış kararı mutfağındır (K-11).
 */
$config['list']['filter'] = [
    'search' => [
        'prompt' => 'lang:veykemtu.bridgeapi::monitor.soldout_search',
        'mode' => 'all',
    ],
    'scopes' => [
        'sold_out_on' => [
            'label' => 'lang:veykemtu.bridgeapi::monitor.filter_date',
            'type' => 'daterange',
            'conditions' => 'sold_out_on >= CAST(:filtered_start AS DATE) '
                .'AND sold_out_on <= CAST(:filtered_end AS DATE)',
        ],
    ],
];

$config['list']['columns'] = [
    'sold_out_on' => [
        'label' => 'lang:veykemtu.bridgeapi::monitor.column_day',
        'type' => 'date',
        'sortable' => true,
    ],
    'menu_name' => [
        'label' => 'lang:veykemtu.bridgeapi::monitor.column_menu',
        'relation' => 'menu',
        'select' => 'menu_name',
        'searchable' => true,
        'sortable' => false,
    ],
    'reason' => [
        'label' => 'lang:veykemtu.bridgeapi::monitor.column_reason',
        'type' => 'text',
        'searchable' => true,
    ],
    'created_at' => [
        'label' => 'lang:veykemtu.bridgeapi::monitor.column_when',
        'type' => 'datetime',
        'sortable' => true,
    ],
    'id' => [
        'label' => 'lang:admin::lang.column_id',
        'invisible' => true,
    ],
];

return $config;
