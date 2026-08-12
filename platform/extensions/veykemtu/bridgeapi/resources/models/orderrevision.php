<?php

declare(strict_types=1);

/**
 * Sipariş revizyon geçmişi listesi —
 * `Veykemtu\BridgeApi\Http\Controllers\Admin\OrderRevisions`.
 *
 * Form YOK ve olmayacak: denetim kaydı düzenlenemez.
 */
$config['list']['filter'] = [
    'search' => [
        'prompt' => 'lang:veykemtu.bridgeapi::monitor.revisions_search',
        'mode' => 'all',
    ],
    'scopes' => [
        'created_at' => [
            'label' => 'lang:veykemtu.bridgeapi::monitor.filter_date',
            'type' => 'daterange',
            'conditions' => 'created_at >= CAST(:filtered_start AS DATETIME) '
                .'AND created_at <= CAST(:filtered_end AS DATETIME)',
        ],
    ],
];

$config['list']['columns'] = [
    'order_id' => [
        'label' => 'lang:veykemtu.bridgeapi::monitor.column_order',
        'type' => 'partial',
        'path' => 'column_revision_order',
        'searchable' => true,
        'sortable' => true,
    ],
    'created_at' => [
        'label' => 'lang:veykemtu.bridgeapi::monitor.column_when',
        'type' => 'datetime',
        'sortable' => true,
    ],
    'reason' => [
        'label' => 'lang:veykemtu.bridgeapi::monitor.column_reason',
        'type' => 'text',
        'searchable' => true,
    ],
    'delta' => [
        'label' => 'lang:veykemtu.bridgeapi::monitor.column_delta',
        'type' => 'partial',
        'path' => 'column_revision_delta',
    ],
    'money' => [
        'label' => 'lang:veykemtu.bridgeapi::monitor.column_money',
        'type' => 'partial',
        'path' => 'column_revision_money',
    ],
    'note' => [
        'label' => 'lang:veykemtu.bridgeapi::monitor.column_note',
        'type' => 'text',
        'searchable' => true,
    ],
    'id' => [
        'label' => 'lang:admin::lang.column_id',
        'invisible' => true,
    ],
];

return $config;
