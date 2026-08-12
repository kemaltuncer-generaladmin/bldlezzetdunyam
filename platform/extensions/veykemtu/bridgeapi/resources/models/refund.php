<?php

declare(strict_types=1);

use Veykemtu\BridgeApi\Models\PaymentRefund;

/**
 * İade listesi — `Veykemtu\BridgeApi\Http\Controllers\Admin\Refunds`.
 *
 * Form YOK: iade panelden açılmaz (`RefundManager` açar) ve düzenlenmez.
 * Tek yazma işlemi, satırdaki "işaretle" düğmesinin tetiklediği
 * `onMarkSettled`.
 */
$config['list']['filter'] = [
    'search' => [
        'prompt' => 'lang:veykemtu.bridgeapi::refund.text_search',
        'mode' => 'all',
    ],
    'scopes' => [
        /*
         * VARSAYILAN "elle iade bekleyenler" DEĞİL, çünkü çekirdeğin scope
         * mekanizmasında varsayılan bir seçim, filtrenin kapatılabildiğinin
         * fark edilmemesine yol açıyor. Bunun yerine liste en eskiden
         * sıralanıyor (controller) ve durum sütunu rozetle vurgulanıyor.
         */
        'status' => [
            'label' => 'lang:veykemtu.bridgeapi::refund.column_status',
            'type' => 'select',
            'conditions' => 'status = :filtered',
            'options' => PaymentRefund::statusOptions(),
        ],
        'created_at' => [
            'label' => 'lang:veykemtu.bridgeapi::refund.filter_date',
            'type' => 'daterange',
            'conditions' => 'created_at >= CAST(:filtered_start AS DATETIME) '
                .'AND created_at <= CAST(:filtered_end AS DATETIME)',
        ],
    ],
];

$config['list']['columns'] = [
    'order_id' => [
        'label' => 'lang:veykemtu.bridgeapi::refund.column_order',
        'type' => 'partial',
        'path' => 'column_order',
        'sortable' => true,
        'searchable' => true,
    ],
    'created_at' => [
        'label' => 'lang:veykemtu.bridgeapi::refund.column_created',
        'type' => 'datetime',
        'sortable' => true,
    ],
    'amount' => [
        'label' => 'lang:veykemtu.bridgeapi::refund.column_amount',
        'type' => 'partial',
        'path' => 'column_amount',
    ],
    'gateway' => [
        'label' => 'lang:veykemtu.bridgeapi::refund.column_gateway',
        'type' => 'text',
        'sortable' => true,
    ],
    'status' => [
        'label' => 'lang:veykemtu.bridgeapi::refund.column_status',
        'type' => 'partial',
        'path' => 'column_status',
        'sortable' => true,
    ],
    'reason' => [
        'label' => 'lang:veykemtu.bridgeapi::refund.column_reason',
        'type' => 'text',
        'searchable' => true,
    ],
    'settle' => [
        'label' => 'lang:veykemtu.bridgeapi::refund.column_action',
        'type' => 'partial',
        'path' => 'column_settle',
    ],
    'id' => [
        'label' => 'lang:admin::lang.column_id',
        'invisible' => true,
    ],
];

return $config;
