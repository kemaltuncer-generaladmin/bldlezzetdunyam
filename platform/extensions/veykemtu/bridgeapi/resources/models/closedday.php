<?php

declare(strict_types=1);

/**
 * Kapalı günler listesi ve formu —
 * `Veykemtu\BridgeApi\Http\Controllers\Admin\ClosedDays`.
 */
$config['list']['columns'] = [
    'edit' => [
        'type' => 'button',
        'iconCssClass' => 'fa fa-pencil',
        'attributes' => [
            'class' => 'btn btn-edit',
            'href' => 'veykemtu/bridgeapi/closed_days/edit/{id}',
        ],
    ],
    'closed_on' => [
        'label' => 'lang:veykemtu.bridgeapi::subscription.closed_date',
        'type' => 'date',
        'sortable' => true,
    ],
    'description' => [
        'label' => 'lang:veykemtu.bridgeapi::subscription.closed_description',
        'type' => 'text',
        'searchable' => true,
        'sortable' => false,
    ],
    'id' => [
        'label' => 'lang:admin::lang.column_id',
        'invisible' => true,
    ],
];

$config['form']['toolbar'] = [
    'buttons' => [
        'back' => [
            'label' => 'lang:admin::lang.button_icon_back',
            'class' => 'btn btn-outline-secondary',
            'href' => 'veykemtu/bridgeapi/closed_days',
        ],
        'save' => [
            'label' => 'lang:admin::lang.button_save',
            'class' => 'btn btn-primary',
            'data-request' => 'onSave',
            'data-progress-indicator' => 'admin::lang.text_saving',
            'context' => ['create', 'edit'],
        ],
        'saveClose' => [
            'label' => 'lang:admin::lang.button_save_close',
            'class' => 'btn btn-default',
            'data-request' => 'onSave',
            'data-request-data' => 'close:1',
            'data-progress-indicator' => 'admin::lang.text_saving',
            'context' => ['create', 'edit'],
        ],
        'delete' => [
            'label' => 'lang:admin::lang.button_icon_delete',
            'class' => 'btn btn-danger',
            'data-request' => 'onDelete',
            'data-request-data' => "_method:'DELETE'",
            'data-progress-indicator' => 'admin::lang.text_deleting',
            'context' => ['edit'],
        ],
    ],
];

$config['form']['fields'] = [
    'closed_on' => [
        'label' => 'lang:veykemtu.bridgeapi::subscription.closed_date',
        'type' => 'text',
        'span' => 'left',
        'comment' => 'lang:veykemtu.bridgeapi::subscription.closed_date_help',
        'attributes' => ['placeholder' => 'YYYY-AA-GG'],
    ],
    'description' => [
        'label' => 'lang:veykemtu.bridgeapi::subscription.closed_description',
        'type' => 'text',
        'span' => 'right',
        'attributes' => ['maxlength' => 160],
    ],
];

$config['form']['rules'] = [
    [
        'closed_on',
        'lang:veykemtu.bridgeapi::subscription.closed_date',
        'required|date',
    ],
    [
        'description',
        'lang:veykemtu.bridgeapi::subscription.closed_description',
        'nullable|string|max:160',
    ],
];

return $config;
