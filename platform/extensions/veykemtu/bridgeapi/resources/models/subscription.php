<?php

declare(strict_types=1);

use Veykemtu\BridgeApi\Models\Subscription;

/**
 * Abonelikler listesi ve fiyatlandırma formu —
 * `Veykemtu\BridgeApi\Http\Controllers\Admin\Subscriptions`.
 *
 * Admin fiyatı (anlaşmalı porsiyon fiyatı), durumu, adedi ve ödeme modunu
 * düzenler; müşterinin belirlediği takvim ve ürün satırları SALT-OKUNUR
 * (`_details` partial). "Yeni" düğmesi yok — abonelik müşteri talebinden doğar.
 */
$config['list']['filter'] = [
    'search' => [
        'prompt' => 'lang:veykemtu.bridgeapi::subscription.text_filter_search',
        'mode' => 'all',
    ],
    'scopes' => [
        'status' => [
            'label' => 'lang:veykemtu.bridgeapi::subscription.column_status',
            'type' => 'select',
            'conditions' => 'status = :filtered',
            'options' => Subscription::statusOptions(),
        ],
    ],
];

$config['list']['columns'] = [
    'edit' => [
        'type' => 'button',
        'iconCssClass' => 'fa fa-pencil',
        'attributes' => [
            'class' => 'btn btn-edit',
            'href' => 'veykemtu/bridgeapi/subscriptions/edit/{id}',
        ],
    ],
    'customer_email' => [
        'label' => 'lang:veykemtu.bridgeapi::subscription.column_customer',
        'relation' => 'customer',
        'select' => 'email',
        'searchable' => true,
        'sortable' => false,
    ],
    'status' => [
        'label' => 'lang:veykemtu.bridgeapi::subscription.column_status',
        'type' => 'partial',
        'path' => 'column_status',
        'sortable' => true,
    ],
    'start_date' => [
        'label' => 'lang:veykemtu.bridgeapi::subscription.column_start',
        'type' => 'date',
        'sortable' => true,
    ],
    'end_date' => [
        'label' => 'lang:veykemtu.bridgeapi::subscription.column_end',
        'type' => 'date',
        'sortable' => true,
    ],
    'default_quantity' => [
        'label' => 'lang:veykemtu.bridgeapi::subscription.column_quantity',
        'type' => 'text',
        'sortable' => true,
    ],
    'agreed_price' => [
        'label' => 'lang:veykemtu.bridgeapi::subscription.column_price',
        'type' => 'partial',
        'path' => 'column_agreed',
    ],
    'payment_mode' => [
        'label' => 'lang:veykemtu.bridgeapi::subscription.column_payment',
        'type' => 'text',
        'sortable' => true,
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
            'href' => 'veykemtu/bridgeapi/subscriptions',
        ],
        'save' => [
            'label' => 'lang:admin::lang.button_save',
            'class' => 'btn btn-primary',
            'data-request' => 'onSave',
            'data-progress-indicator' => 'admin::lang.text_saving',
            'context' => ['edit'],
        ],
        'saveClose' => [
            'label' => 'lang:admin::lang.button_save_close',
            'class' => 'btn btn-default',
            'data-request' => 'onSave',
            'data-request-data' => 'close:1',
            'data-progress-indicator' => 'admin::lang.text_saving',
            'context' => ['edit'],
        ],
        'delete' => [
            'label' => 'lang:admin::lang.button_icon_delete',
            'class' => 'btn btn-danger',
            'data-request' => 'onDelete',
            'data-request-data' => "_method:'DELETE'",
            'data-request-confirm' => 'lang:veykemtu.bridgeapi::subscription.confirm_delete',
            'data-progress-indicator' => 'admin::lang.text_deleting',
            'context' => ['edit'],
        ],
    ],
];

$config['form']['fields'] = [
    'pricing_section' => [
        'type' => 'section',
        'label' => 'lang:veykemtu.bridgeapi::subscription.section_pricing',
        'comment' => 'lang:veykemtu.bridgeapi::subscription.section_pricing_comment',
    ],
    'status' => [
        'label' => 'lang:veykemtu.bridgeapi::subscription.column_status',
        'type' => 'select',
        'span' => 'left',
        'options' => Subscription::statusOptions(),
        'comment' => 'lang:veykemtu.bridgeapi::subscription.help_status',
    ],
    'payment_mode' => [
        'label' => 'lang:veykemtu.bridgeapi::subscription.column_payment',
        'type' => 'select',
        'span' => 'right',
        'options' => [
            'account' => 'lang:veykemtu.bridgeapi::subscription.payment_account',
            'prepaid_monthly' => 'lang:veykemtu.bridgeapi::subscription.payment_prepaid',
        ],
    ],
    'agreed_price_lira' => [
        'label' => 'lang:veykemtu.bridgeapi::subscription.label_agreed_price',
        'type' => 'text',
        'span' => 'left',
        'comment' => 'lang:veykemtu.bridgeapi::subscription.help_agreed_price',
    ],
    'default_quantity' => [
        'label' => 'lang:veykemtu.bridgeapi::subscription.label_quantity',
        'type' => 'number',
        'span' => 'right',
    ],
    'details_section' => [
        'type' => 'section',
        'label' => 'lang:veykemtu.bridgeapi::subscription.section_details',
        'comment' => 'lang:veykemtu.bridgeapi::subscription.section_details_comment',
    ],
    '_details' => [
        'type' => 'partial',
        'path' => 'subscription_details',
    ],
];

$config['form']['rules'] = [
    [
        'status',
        'lang:veykemtu.bridgeapi::subscription.column_status',
        'required|string|in:'.implode(',', Subscription::STATUSES),
    ],
    [
        'payment_mode',
        'lang:veykemtu.bridgeapi::subscription.column_payment',
        'required|string|in:account,prepaid_monthly',
    ],
    [
        'agreed_price_lira',
        'lang:veykemtu.bridgeapi::subscription.label_agreed_price',
        'nullable|string|max:32',
    ],
    [
        'default_quantity',
        'lang:veykemtu.bridgeapi::subscription.label_quantity',
        'required|integer|min:1|max:9999',
    ],
];

return $config;
