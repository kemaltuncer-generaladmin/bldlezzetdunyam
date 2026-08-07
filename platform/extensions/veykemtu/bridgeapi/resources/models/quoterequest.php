<?php

declare(strict_types=1);

use Veykemtu\BridgeApi\Admin\AdminRegistrar;
use Veykemtu\BridgeApi\Models\QuoteRequest;

/**
 * Teklif talepleri listesi ve detay formu —
 * `Veykemtu\BridgeApi\Http\Controllers\Admin\QuoteRequests`.
 *
 * "YENİ" DÜĞMESİ YOK. Talep yalnızca sitedeki formdan doğar; gerekçe
 * denetleyicinin sınıf yorumundadır.
 *
 * ZİYARETÇİNİN GÖNDERDİĞİ ALANLAR FORM ALANI DEĞİL, TEK BİR `partial`.
 * On üç alanı `disabled` metin kutusu olarak dizmek, kaydedilebilir görünen
 * ama kaydedilmeyen bir ekran üretirdi; ayrıca tarih alanları kutunun içinde
 * ham `2026-09-01 00:00:00` biçiminde çıkardı. Panel bunları okunur bir
 * künye olarak çiziyor (`_partials/quoterequests/quote_submission`) ve
 * formda yalnızca firmanın kendi doldurduğu iki alan kalıyor.
 *
 * ALAN ADI `_submission` — ALT ÇİZGİ BİLİNÇLİ. Çekirdek, adı `_` ile
 * başlayan alanları kaydedilecek veriden tamamen çıkarıyor
 * (`Widgets\Form::getSaveData`). Alt çizgisiz bırakılsaydı, forma elle
 * `QuoteRequest[submission]` gönderen biri var olmayan bir sütuna yazmaya
 * çalışır ve kayıt SQL hatasıyla düşerdi.
 */
$config['list']['filter'] = [
    'search' => [
        'prompt' => 'lang:veykemtu.bridgeapi::quoterequest.text_filter_search',
        'mode' => 'all',
    ],
    'scopes' => [
        /*
         * Durum filtresi, listenin tek gerçek iş aracı: firma sabah panele
         * girip "bugün hangi taleplere dönmedim" sorusunu bununla cevaplıyor.
         * Filtre olmasaydı liste birkaç ay sonra kapanmış taleplerle dolar ve
         * yeni talep aşağıda kalırdı.
         */
        'status' => [
            'label' => 'lang:veykemtu.bridgeapi::quoterequest.text_filter_status',
            'type' => 'select',
            'conditions' => 'status = :filtered',
            'options' => QuoteRequest::statusOptions(),
        ],
        'date' => [
            'label' => 'lang:veykemtu.bridgeapi::quoterequest.text_filter_date',
            'type' => 'daterange',
            'conditions' => 'created_at >= CAST(:filtered_start AS DATE) AND created_at <= CAST(:filtered_end AS DATE)',
        ],
    ],
];

$config['list']['columns'] = [
    'edit' => [
        'type' => 'button',
        'iconCssClass' => 'fa fa-pencil',
        'attributes' => [
            'class' => 'btn btn-edit',
            'href' => AdminRegistrar::QUOTES_URI.'/edit/{id}',
        ],
    ],
    // GÖRELİ ZAMAN ("2 saat önce"). Bu listede sorulan soru "ne zaman geldi"
    // değil, "ne kadar bekledi"dir; bir talebin üç gündür açık durduğunu
    // mutlak tarihten çıkarmak yöneticiye zihinden çıkarma yaptırırdı.
    'created_at' => [
        'label' => 'lang:veykemtu.bridgeapi::quoterequest.column_created_at',
        'type' => 'timesince',
        'sortable' => true,
    ],
    'status' => [
        'label' => 'lang:veykemtu.bridgeapi::quoterequest.column_status',
        'type' => 'partial',
        'path' => 'column_status',
        'sortable' => true,
    ],
    'full_name' => [
        'label' => 'lang:veykemtu.bridgeapi::quoterequest.column_full_name',
        'type' => 'text',
        'searchable' => true,
        'sortable' => true,
    ],
    'organization' => [
        'label' => 'lang:veykemtu.bridgeapi::quoterequest.column_organization',
        'type' => 'text',
        'searchable' => true,
        'sortable' => true,
    ],
    /*
     * TELEFON VE E-POSTA LİSTEDE GÖRÜNÜR — bilinçli.
     *
     * Bu ekranın tek işi firmanın talebe DÖNMESİNİ sağlamak; numarayı görmek
     * için her kaydı tek tek açmak zorunda kalmak, on talepte on tıklama
     * demektir. Veriyi görebilen çevre zaten `PERMISSION_QUOTES` ile dar
     * tutuluyor; asıl koruma orada, sütunu gizlemekte değil.
     */
    'telephone' => [
        'label' => 'lang:veykemtu.bridgeapi::quoterequest.column_telephone',
        'type' => 'text',
        'searchable' => true,
        'sortable' => false,
    ],
    'email' => [
        'label' => 'lang:veykemtu.bridgeapi::quoterequest.column_email',
        'type' => 'text',
        'searchable' => true,
        'sortable' => false,
    ],
    'service_type' => [
        'label' => 'lang:veykemtu.bridgeapi::quoterequest.column_service_type',
        'type' => 'text',
        'searchable' => true,
        'sortable' => true,
    ],
    'headcount' => [
        'label' => 'lang:veykemtu.bridgeapi::quoterequest.column_headcount',
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
            'href' => AdminRegistrar::QUOTES_URI,
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
            'data-request-confirm' => 'lang:veykemtu.bridgeapi::quoterequest.confirm_delete',
            'data-progress-indicator' => 'admin::lang.text_deleting',
            'context' => ['edit'],
        ],
    ],
];

$config['form']['fields'] = [
    'follow_up_section' => [
        'type' => 'section',
        'label' => 'lang:veykemtu.bridgeapi::quoterequest.section_follow_up',
        'comment' => 'lang:veykemtu.bridgeapi::quoterequest.section_follow_up_comment',
    ],
    'status' => [
        'label' => 'lang:veykemtu.bridgeapi::quoterequest.label_status',
        'type' => 'select',
        'span' => 'left',
        'options' => QuoteRequest::statusOptions(),
        'comment' => 'lang:veykemtu.bridgeapi::quoterequest.help_status',
    ],
    'admin_note' => [
        'label' => 'lang:veykemtu.bridgeapi::quoterequest.label_admin_note',
        'type' => 'textarea',
        'span' => 'right',
        'comment' => 'lang:veykemtu.bridgeapi::quoterequest.help_admin_note',
        'attributes' => ['rows' => 4, 'maxlength' => 2000],
    ],

    'submission_section' => [
        'type' => 'section',
        'label' => 'lang:veykemtu.bridgeapi::quoterequest.section_submission',
        'comment' => 'lang:veykemtu.bridgeapi::quoterequest.section_submission_comment',
    ],
    '_submission' => [
        'type' => 'partial',
        'path' => 'quote_submission',
    ],
];

$config['form']['rules'] = [
    [
        'status',
        'lang:veykemtu.bridgeapi::quoterequest.label_status',
        'required|string|in:'.implode(',', QuoteRequest::STATUSES),
    ],
    [
        'admin_note',
        'lang:veykemtu.bridgeapi::quoterequest.label_admin_note',
        'nullable|string|max:2000',
    ],
];

return $config;
