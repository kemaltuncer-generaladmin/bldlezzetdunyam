<?php

declare(strict_types=1);

use Veykemtu\BridgeApi\Admin\AdminRegistrar;

/**
 * Bilgi merkezi yazıları listesi ve düzenleme formu —
 * `Veykemtu\BridgeApi\Http\Controllers\Admin\SitePosts`.
 *
 * YAZI SIRALANMAZ, TARİHLENİR. Hizmetlerin aksine burada `sort_order` yok;
 * sıra `published_at`'ten doğuyor (`SitePost::scopePublished`). Yazıya elle
 * sıra vermek, on yazıdan sonra kimsenin bakmadığı bir numara alanı demekti.
 *
 * ADRES (`slug`) BENZERSİZLİK KURALI BURADA YOK: gerekçe
 * `SitePosts::withSlugRule` üzerinde.
 */
$config['list']['filter'] = [
    'search' => [
        'prompt' => 'lang:veykemtu.bridgeapi::default.posts.text_filter_search',
        'mode' => 'all',
    ],
];

$config['list']['toolbar'] = [
    'buttons' => [
        'create' => [
            'label' => 'lang:veykemtu.bridgeapi::default.posts.button_new',
            'class' => 'btn btn-primary',
            'href' => AdminRegistrar::POSTS_URI.'/create',
        ],
    ],
];

$config['list']['columns'] = [
    'edit' => [
        'type' => 'button',
        'iconCssClass' => 'fa fa-pencil',
        'attributes' => [
            'class' => 'btn btn-edit',
            'href' => AdminRegistrar::POSTS_URI.'/edit/{id}',
        ],
    ],
    'title' => [
        'label' => 'lang:veykemtu.bridgeapi::default.posts.column_title',
        'type' => 'text',
        'searchable' => true,
        'sortable' => true,
    ],
    'category' => [
        'label' => 'lang:veykemtu.bridgeapi::default.posts.column_category',
        'type' => 'text',
        'searchable' => true,
        'sortable' => true,
    ],
    // MUTLAK TARİH, "3 gün önce" DEĞİL. Yayın tarihi yazarın kararıdır ve
    // ileri tarihli olabilir; göreli biçim ileri tarihi anlaşılmaz gösterirdi.
    'published_at' => [
        'label' => 'lang:veykemtu.bridgeapi::default.posts.column_published_at',
        'type' => 'date',
        'sortable' => true,
    ],
    'is_published' => [
        'label' => 'lang:veykemtu.bridgeapi::default.posts.column_published',
        'type' => 'switch',
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
            'href' => AdminRegistrar::POSTS_URI,
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
            'data-request-confirm' => 'lang:veykemtu.bridgeapi::default.posts.confirm_delete',
            'data-progress-indicator' => 'admin::lang.text_deleting',
            'context' => ['edit'],
        ],
    ],
];

$config['form']['fields'] = [
    'title' => [
        'label' => 'lang:veykemtu.bridgeapi::default.posts.label_title',
        'type' => 'text',
        'span' => 'left',
        'comment' => 'lang:veykemtu.bridgeapi::default.posts.help_title',
        'attributes' => ['maxlength' => 200],
    ],
    'slug' => [
        'label' => 'lang:veykemtu.bridgeapi::default.posts.label_slug',
        'type' => 'text',
        'span' => 'right',
        'comment' => 'lang:veykemtu.bridgeapi::default.posts.help_slug',
        'attributes' => ['maxlength' => 96],
        'preset' => [
            'field' => 'title',
            'type' => 'slug',
        ],
    ],
    'category' => [
        'label' => 'lang:veykemtu.bridgeapi::default.posts.label_category',
        'type' => 'text',
        'span' => 'left',
        'comment' => 'lang:veykemtu.bridgeapi::default.posts.help_category',
        'attributes' => ['maxlength' => 64],
    ],
    'published_at' => [
        'label' => 'lang:veykemtu.bridgeapi::default.posts.label_published_at',
        'type' => 'datepicker',
        'mode' => 'date',
        'span' => 'right',
        'comment' => 'lang:veykemtu.bridgeapi::default.posts.help_published_at',
    ],
    'reading_minutes' => [
        'label' => 'lang:veykemtu.bridgeapi::default.posts.label_reading_minutes',
        'type' => 'number',
        'span' => 'left',
        // Yer tutucu `lang()` ile çözülüyor, `lang:` önekiyle değil: çekirdeğin
        // `number` alan şablonu bu anahtara çeviri uygulamıyor ve önek
        // bırakılsaydı kutunun içinde ham çeviri anahtarı görünürdü.
        'placeholder' => lang('veykemtu.bridgeapi::default.posts.text_auto_minutes'),
        'comment' => 'lang:veykemtu.bridgeapi::default.posts.help_reading_minutes',
        'attributes' => ['min' => 1, 'max' => 600, 'step' => 1],
    ],
    'is_published' => [
        'label' => 'lang:veykemtu.bridgeapi::default.posts.label_published',
        'type' => 'switch',
        'span' => 'right',
        'default' => true,
        'comment' => 'lang:veykemtu.bridgeapi::default.posts.help_published',
    ],

    'summary_section' => [
        'type' => 'section',
        'label' => 'lang:veykemtu.bridgeapi::default.posts.section_summary',
        'comment' => 'lang:veykemtu.bridgeapi::default.posts.section_summary_comment',
    ],
    'description' => [
        'label' => 'lang:veykemtu.bridgeapi::default.posts.label_description',
        'type' => 'textarea',
        'comment' => 'lang:veykemtu.bridgeapi::default.posts.help_description',
        'attributes' => ['rows' => 3, 'maxlength' => 400],
    ],

    'body_section' => [
        'type' => 'section',
        'label' => 'lang:veykemtu.bridgeapi::default.posts.section_body',
        'comment' => 'lang:veykemtu.bridgeapi::default.posts.section_body_comment',
    ],
    'body_html' => [
        'label' => 'lang:veykemtu.bridgeapi::default.posts.label_body_html',
        'type' => 'richeditor',
        'comment' => 'lang:veykemtu.bridgeapi::default.posts.help_body_html',
    ],
];

$config['form']['rules'] = [
    [
        'title',
        'lang:veykemtu.bridgeapi::default.posts.label_title',
        'required|string|max:200',
    ],
    [
        'slug',
        'lang:veykemtu.bridgeapi::default.posts.label_slug',
        'required|string|max:96|regex:/^[a-z0-9]+(?:-[a-z0-9]+)*$/',
    ],
    [
        'category',
        'lang:veykemtu.bridgeapi::default.posts.label_category',
        'required|string|max:64',
    ],
    [
        'description',
        'lang:veykemtu.bridgeapi::default.posts.label_description',
        'required|string|max:400',
    ],
    [
        'body_html',
        'lang:veykemtu.bridgeapi::default.posts.label_body_html',
        'required|string|max:60000',
    ],
    [
        'published_at',
        'lang:veykemtu.bridgeapi::default.posts.label_published_at',
        'required|date',
    ],
    [
        'reading_minutes',
        'lang:veykemtu.bridgeapi::default.posts.label_reading_minutes',
        'nullable|integer|min:1|max:600',
    ],
    [
        'is_published',
        'lang:veykemtu.bridgeapi::default.posts.label_published',
        'required|boolean',
    ],
];

return $config;
