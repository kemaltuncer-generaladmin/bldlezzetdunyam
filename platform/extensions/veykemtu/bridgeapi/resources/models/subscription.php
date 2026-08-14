<?php

declare(strict_types=1);

use Veykemtu\BridgeApi\Models\Subscription;

/**
 * Abonelikler listesi, oluşturma ve fiyatlandırma formu —
 * `Veykemtu\BridgeApi\Http\Controllers\Admin\Subscriptions`.
 *
 * İKİ BAĞLAM, İKİ FARKLI ALAN KÜMESİ:
 *
 *  * `create` — abonelik masa başında konuşulup panelden açılıyor (B-16).
 *    Takvim, ürün satırları ve fiyat burada giriliyor.
 *  * `edit` — abonelik ÜRETİM YAPARKEN düzenleniyor. Yalnız fiyat, durum,
 *    adet ve ödeme modu açık; takvim ve satırlar salt-okunur (`_details`).
 *    Çalışan bir kuralın gün listesini değiştirmek, o güne ait üretilmiş
 *    siparişlerle kuralın ayrışması demek olurdu.
 *
 * `context` anahtarı alanların hangi bağlamda görüneceğini belirler;
 * yazılmayan alan HER İKİSİNDE de görünür.
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

$config['list']['toolbar'] = [
    'buttons' => [
        'create' => [
            'label' => 'lang:veykemtu.bridgeapi::subscription.button_create',
            'class' => 'btn btn-primary',
            'href' => 'veykemtu/bridgeapi/subscriptions/create',
        ],
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
            'data-request-confirm' => 'lang:veykemtu.bridgeapi::subscription.confirm_delete',
            'data-progress-indicator' => 'admin::lang.text_deleting',
            'context' => ['edit'],
        ],
    ],
];

$config['form']['fields'] = [
    /*
     * ── Yalnızca OLUŞTURMA bağlamı ───────────────────────────────────
     *
     * Bu alanlar aboneliğin kim için, hangi günlerde ve neyi ürettiğini
     * belirler. Bir kez yazılır; sonra değişmez (gerekçe dosya başlığında).
     */
    'setup_section' => [
        'type' => 'section',
        'label' => 'lang:veykemtu.bridgeapi::subscription.section_setup',
        'comment' => 'lang:veykemtu.bridgeapi::subscription.section_setup_comment',
        'context' => ['create'],
    ],
    'customer_id' => [
        'label' => 'lang:veykemtu.bridgeapi::subscription.column_customer',
        'type' => 'select',
        'span' => 'left',
        'options' => [Subscription::class, 'customerOptions'],
        'comment' => 'lang:veykemtu.bridgeapi::subscription.help_customer',
        'context' => ['create'],
    ],
    'delivery_type' => [
        'label' => 'lang:veykemtu.bridgeapi::subscription.label_delivery_type',
        'type' => 'select',
        'span' => 'right',
        'options' => [
            'delivery' => 'lang:veykemtu.bridgeapi::subscription.delivery',
            'pickup' => 'lang:veykemtu.bridgeapi::subscription.pickup',
        ],
        'context' => ['create'],
    ],
    'start_date' => [
        'label' => 'lang:veykemtu.bridgeapi::subscription.column_start',
        'type' => 'datepicker',
        'mode' => 'date',
        'span' => 'left',
        'context' => ['create'],
    ],
    'end_date' => [
        'label' => 'lang:veykemtu.bridgeapi::subscription.column_end',
        'type' => 'datepicker',
        'mode' => 'date',
        'span' => 'right',
        'comment' => 'lang:veykemtu.bridgeapi::subscription.help_end_date',
        'context' => ['create'],
    ],
    'service_days' => [
        'label' => 'lang:veykemtu.bridgeapi::subscription.detail_days',
        'type' => 'checkboxlist',
        'options' => [Subscription::class, 'dayOptions'],
        'comment' => 'lang:veykemtu.bridgeapi::subscription.help_service_days',
        'context' => ['create'],
    ],
    'delivery_time_from' => [
        'label' => 'lang:veykemtu.bridgeapi::subscription.label_time_from',
        'type' => 'text',
        'span' => 'left',
        'comment' => 'lang:veykemtu.bridgeapi::subscription.help_time_from',
        'context' => ['create'],
    ],
    'delivery_time_to' => [
        'label' => 'lang:veykemtu.bridgeapi::subscription.label_time_to',
        'type' => 'text',
        'span' => 'right',
        'context' => ['create'],
    ],
    /*
     * MENÜ KAYNAĞI — bu alan olmadan `daily_menu` aboneliği panelden
     * AÇILAMIYORDU. `Subscriptions::formExtendModel` içindeki `??=` yalnızca
     * varsayılanı yazıyor; formda alan bulunmayınca kayıt her zaman
     * `fixed_list` doğuyor ve mod hiç seçilemiyordu.
     *
     * Yalnız OLUŞTURMADA: menü kaynağı sözleşmenin kendisi. Çalışan bir
     * aboneliğin modunu değiştirmek, üretilmiş siparişlerle kuralın
     * ayrışması demek (takvim alanlarıyla aynı gerekçe).
     */
    'menu_mode' => [
        'label' => 'lang:veykemtu.bridgeapi::subscription.label_menu_mode',
        'type' => 'radiotoggle',
        'options' => [Subscription::class, 'menuModeOptions'],
        'comment' => 'lang:veykemtu.bridgeapi::subscription.help_menu_mode',
        'context' => ['create'],
    ],
    'lines_section' => [
        'type' => 'section',
        'label' => 'lang:veykemtu.bridgeapi::subscription.section_lines',
        'comment' => 'lang:veykemtu.bridgeapi::subscription.section_lines_comment',
        'context' => ['create'],
        // Günün menüsü modunda porsiyonun içeriği her gün
        // `veykemtu_daily_menus`'ten geliyor; burada ürün sormak,
        // hiçbir zaman okunmayacak ikinci bir içerik kaynağı yaratırdı.
        'trigger' => [
            'action' => 'show',
            'field' => 'menu_mode',
            'condition' => 'value['.Subscription::MENU_FIXED_LIST.']',
        ],
    ],
    /*
     * `line_items` GERÇEK BİR SÜTUN DEĞİL. Satırlar
     * `veykemtu_subscription_lines` tablosunda yaşıyor; bu alan yalnızca
     * formun taşıyıcısı. `Subscriptions::formValidate` onu kayıt verisinden
     * çıkarıyor ve `formAfterCreate` ilişkili tabloya yazıyor — aksi hâlde
     * kayıt "böyle bir sütun yok" ile düşerdi.
     */
    'line_items' => [
        'label' => 'lang:veykemtu.bridgeapi::subscription.detail_lines',
        'type' => 'repeater',
        'prompt' => 'lang:veykemtu.bridgeapi::subscription.prompt_line',
        'emptyMessage' => 'lang:veykemtu.bridgeapi::subscription.empty_lines',
        'context' => ['create'],
        'trigger' => [
            'action' => 'show',
            'field' => 'menu_mode',
            'condition' => 'value['.Subscription::MENU_FIXED_LIST.']',
        ],
        'form' => [
            'fields' => [
                'menu_id' => [
                    'label' => 'lang:veykemtu.bridgeapi::subscription.label_line_menu',
                    'type' => 'select',
                    'options' => [Subscription::class, 'menuOptions'],
                ],
                'quantity' => [
                    'label' => 'lang:veykemtu.bridgeapi::subscription.label_line_quantity',
                    'type' => 'number',
                    'default' => 1,
                ],
                'label' => [
                    'label' => 'lang:veykemtu.bridgeapi::subscription.label_line_label',
                    'type' => 'text',
                ],
            ],
        ],
    ],

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
        'context' => ['edit'],
    ],
    '_details' => [
        'type' => 'partial',
        'path' => 'subscription_details',
        'context' => ['edit'],
    ],
    'calendar_section' => [
        'type' => 'section',
        'label' => 'lang:veykemtu.bridgeapi::subscription.section_calendar',
        'comment' => 'lang:veykemtu.bridgeapi::subscription.section_calendar_comment',
        'context' => ['edit'],
    ],
    '_calendar' => [
        'type' => 'partial',
        'path' => 'subscription_calendar',
        'context' => ['edit'],
    ],
];

$config['form']['rules'] = [
    /*
     * Oluşturma alanları `sometimes` ile: düzenleme bağlamında formda hiç
     * bulunmuyorlar ve `required` yazılsaydı her kaydetme "müşteri zorunlu"
     * diye düşerdi.
     */
    [
        'customer_id',
        'lang:veykemtu.bridgeapi::subscription.column_customer',
        'sometimes|required|integer|exists:customers,customer_id',
    ],
    [
        'start_date',
        'lang:veykemtu.bridgeapi::subscription.column_start',
        'sometimes|required|date',
    ],
    [
        'end_date',
        'lang:veykemtu.bridgeapi::subscription.column_end',
        'sometimes|nullable|date|after_or_equal:start_date',
    ],
    [
        'service_days',
        'lang:veykemtu.bridgeapi::subscription.detail_days',
        'sometimes|required|array|min:1',
    ],
    [
        'service_days.*',
        'lang:veykemtu.bridgeapi::subscription.detail_days',
        'integer|between:1,7',
    ],
    [
        'delivery_type',
        'lang:veykemtu.bridgeapi::subscription.label_delivery_type',
        'sometimes|required|string|in:delivery,pickup',
    ],
    [
        'delivery_time_from',
        'lang:veykemtu.bridgeapi::subscription.label_time_from',
        'sometimes|nullable|date_format:H:i',
    ],
    [
        'delivery_time_to',
        'lang:veykemtu.bridgeapi::subscription.label_time_to',
        'sometimes|nullable|date_format:H:i',
    ],
    [
        'menu_mode',
        'lang:veykemtu.bridgeapi::subscription.label_menu_mode',
        'sometimes|required|string|in:'.Subscription::MENU_FIXED_LIST.','.Subscription::MENU_DAILY,
    ],
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
