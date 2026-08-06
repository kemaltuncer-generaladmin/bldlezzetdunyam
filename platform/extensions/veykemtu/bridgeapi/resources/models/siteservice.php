<?php

declare(strict_types=1);

use Veykemtu\BridgeApi\Admin\AdminRegistrar;
use Veykemtu\BridgeApi\Admin\RepeaterList;

/**
 * Hizmetler listesi ve düzenleme formu —
 * `Veykemtu\BridgeApi\Http\Controllers\Admin\SiteServices`.
 *
 * FORMUN SIRASI SAYFANIN SIRASIDIR. Alanlar veritabanı sütun sırasına göre
 * değil, hizmet detay sayfasının yukarıdan aşağı akışına göre dizildi:
 * kimlik → kart → giriş → kimler için → nasıl işler → ne kazandırır → menü →
 * teklif. Yönetici yazarken sayfayı zihninde çizebilsin diye.
 *
 * TEKRARLAYICI ALANLARIN İKİ BİÇİMİ VAR. `audience`, `benefits` ve
 * `quote_needs` veritabanında düz metin listesi, formda `text` alanlı satır
 * dizisidir; çeviriyi denetleyici yapıyor (`Admin\RepeaterList`).
 *
 * ADRES (`slug`) BENZERSİZLİK KURALI BURADA YOK: kural düzenlenen kaydın
 * kimliğini hariç tutmak zorunda ve bu dosya kaydı görmüyor. Kuralı
 * `SiteServices::withSlugRule` ekliyor.
 */

/**
 * Seçilebilir ikonlar — site `lucide-react` kullanıyor
 * (`website/content/services.ts`).
 *
 * SERBEST METİN DEĞİL, AÇILIR LİSTE: yönetici ikon adını elle yazsaydı bir
 * harf hatası sitede boş kutu bırakırdı. Etiketler ikon adını değil ne
 * gösterdiğini anlatır; panelde çalışan kişinin Lucide kataloğunu bilmesi
 * beklenemez.
 *
 * @var array<string, string> $icons
 */
$icons = [
    'Building2' => 'lang:veykemtu.bridgeapi::default.services.icon_building',
    'Truck' => 'lang:veykemtu.bridgeapi::default.services.icon_truck',
    'ChefHat' => 'lang:veykemtu.bridgeapi::default.services.icon_chef_hat',
    'GraduationCap' => 'lang:veykemtu.bridgeapi::default.services.icon_graduation_cap',
    'Stethoscope' => 'lang:veykemtu.bridgeapi::default.services.icon_stethoscope',
    'HardHat' => 'lang:veykemtu.bridgeapi::default.services.icon_hard_hat',
    'CalendarHeart' => 'lang:veykemtu.bridgeapi::default.services.icon_calendar_heart',
    'Coffee' => 'lang:veykemtu.bridgeapi::default.services.icon_coffee',
    'UtensilsCrossed' => 'lang:veykemtu.bridgeapi::default.services.icon_utensils_crossed',
    'Soup' => 'lang:veykemtu.bridgeapi::default.services.icon_soup',
    'Users' => 'lang:veykemtu.bridgeapi::default.services.icon_users',
    'Package' => 'lang:veykemtu.bridgeapi::default.services.icon_package',
];

$config['list']['filter'] = [
    'search' => [
        'prompt' => 'lang:veykemtu.bridgeapi::default.services.text_filter_search',
        'mode' => 'all',
    ],
];

$config['list']['toolbar'] = [
    'buttons' => [
        'create' => [
            'label' => 'lang:veykemtu.bridgeapi::default.services.button_new',
            'class' => 'btn btn-primary',
            'href' => AdminRegistrar::SERVICES_URI.'/create',
        ],
    ],
];

$config['list']['columns'] = [
    'edit' => [
        'type' => 'button',
        'iconCssClass' => 'fa fa-pencil',
        'attributes' => [
            'class' => 'btn btn-edit',
            'href' => AdminRegistrar::SERVICES_URI.'/edit/{id}',
        ],
    ],
    'title' => [
        'label' => 'lang:veykemtu.bridgeapi::default.services.column_title',
        'type' => 'text',
        'searchable' => true,
        'sortable' => true,
    ],
    'slug' => [
        'label' => 'lang:veykemtu.bridgeapi::default.services.column_slug',
        'type' => 'text',
        'searchable' => true,
        'sortable' => true,
    ],
    'sort_order' => [
        'label' => 'lang:veykemtu.bridgeapi::default.services.column_sort_order',
        'type' => 'number',
        'sortable' => true,
    ],
    // `switch` sütunu listeden doğrudan açılıp kapanabilir görünmesin diye
    // DEĞİL, salt okunur bir rozet olarak duruyor: yayın kararı bir tık
    // uzaklıkta olmamalı, forma girip özeti görerek verilmeli.
    'is_published' => [
        'label' => 'lang:veykemtu.bridgeapi::default.services.column_published',
        'type' => 'switch',
        'sortable' => true,
    ],
    'updated_at' => [
        'label' => 'lang:veykemtu.bridgeapi::default.services.column_updated',
        'type' => 'timetense',
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
            'href' => AdminRegistrar::SERVICES_URI,
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
            'data-request-confirm' => 'lang:veykemtu.bridgeapi::default.services.confirm_delete',
            'data-progress-indicator' => 'admin::lang.text_deleting',
            'context' => ['edit'],
        ],
    ],
];

$config['form']['fields'] = [
    'title' => [
        'label' => 'lang:veykemtu.bridgeapi::default.services.label_title',
        'type' => 'text',
        'span' => 'left',
        'comment' => 'lang:veykemtu.bridgeapi::default.services.help_title',
        'attributes' => ['maxlength' => 160],
    ],
    'slug' => [
        'label' => 'lang:veykemtu.bridgeapi::default.services.label_slug',
        'type' => 'text',
        'span' => 'right',
        'comment' => 'lang:veykemtu.bridgeapi::default.services.help_slug',
        'attributes' => ['maxlength' => 96],
        // Yeni kayıtta başlıktan türetilir; yazılmış bir adrese dokunmaz.
        // Elle yazmak zorunda kalmak, Türkçe karakterli başlıklarda bozuk
        // adreslerin ana kaynağıdır.
        'preset' => [
            'field' => 'title',
            'type' => 'slug',
        ],
    ],
    'icon' => [
        'label' => 'lang:veykemtu.bridgeapi::default.services.label_icon',
        'type' => 'select',
        'span' => 'left',
        'default' => 'UtensilsCrossed',
        'comment' => 'lang:veykemtu.bridgeapi::default.services.help_icon',
        'options' => $icons,
    ],
    'sort_order' => [
        'label' => 'lang:veykemtu.bridgeapi::default.services.label_sort_order',
        'type' => 'number',
        'span' => 'right',
        'default' => 0,
        'comment' => 'lang:veykemtu.bridgeapi::default.services.help_sort_order',
        'attributes' => ['min' => 0, 'max' => 999, 'step' => 1],
    ],
    'is_published' => [
        'label' => 'lang:veykemtu.bridgeapi::default.services.label_published',
        'type' => 'switch',
        'span' => 'left',
        'default' => true,
        'comment' => 'lang:veykemtu.bridgeapi::default.services.help_published',
    ],

    'card_section' => [
        'type' => 'section',
        'label' => 'lang:veykemtu.bridgeapi::default.services.section_card',
        'comment' => 'lang:veykemtu.bridgeapi::default.services.section_card_comment',
    ],
    'summary' => [
        'label' => 'lang:veykemtu.bridgeapi::default.services.label_summary',
        'type' => 'textarea',
        'comment' => 'lang:veykemtu.bridgeapi::default.services.help_summary',
        'attributes' => ['rows' => 2, 'maxlength' => 400],
    ],
    'intro' => [
        'label' => 'lang:veykemtu.bridgeapi::default.services.label_intro',
        'type' => 'textarea',
        'comment' => 'lang:veykemtu.bridgeapi::default.services.help_intro',
        'attributes' => ['rows' => 4],
    ],

    'detail_section' => [
        'type' => 'section',
        'label' => 'lang:veykemtu.bridgeapi::default.services.section_detail',
        'comment' => 'lang:veykemtu.bridgeapi::default.services.section_detail_comment',
    ],
    'audience' => [
        'label' => 'lang:veykemtu.bridgeapi::default.services.label_audience',
        'type' => 'repeater',
        'commentAbove' => 'lang:veykemtu.bridgeapi::default.services.help_audience',
        'prompt' => 'lang:veykemtu.bridgeapi::default.services.prompt_audience',
        'emptyMessage' => 'lang:veykemtu.bridgeapi::default.services.empty_list',
        'form' => [
            'fields' => [
                RepeaterList::FIELD => [
                    'label' => 'lang:veykemtu.bridgeapi::default.services.label_audience_item',
                    'type' => 'text',
                    'attributes' => ['maxlength' => 200],
                ],
            ],
        ],
    ],
    'how_it_works' => [
        'label' => 'lang:veykemtu.bridgeapi::default.services.label_how_it_works',
        'type' => 'repeater',
        'commentAbove' => 'lang:veykemtu.bridgeapi::default.services.help_how_it_works',
        'prompt' => 'lang:veykemtu.bridgeapi::default.services.prompt_how_it_works',
        'emptyMessage' => 'lang:veykemtu.bridgeapi::default.services.empty_list',
        'form' => [
            'fields' => [
                'title' => [
                    'label' => 'lang:veykemtu.bridgeapi::default.services.label_step_title',
                    'type' => 'text',
                    'attributes' => ['maxlength' => 120],
                ],
                'body' => [
                    'label' => 'lang:veykemtu.bridgeapi::default.services.label_step_body',
                    'type' => 'textarea',
                    'attributes' => ['rows' => 3, 'maxlength' => 600],
                ],
            ],
        ],
    ],
    'benefits' => [
        'label' => 'lang:veykemtu.bridgeapi::default.services.label_benefits',
        'type' => 'repeater',
        'commentAbove' => 'lang:veykemtu.bridgeapi::default.services.help_benefits',
        'prompt' => 'lang:veykemtu.bridgeapi::default.services.prompt_benefits',
        'emptyMessage' => 'lang:veykemtu.bridgeapi::default.services.empty_list',
        'form' => [
            'fields' => [
                RepeaterList::FIELD => [
                    'label' => 'lang:veykemtu.bridgeapi::default.services.label_benefit_item',
                    'type' => 'text',
                    'attributes' => ['maxlength' => 200],
                ],
            ],
        ],
    ],
    'menu_planning' => [
        'label' => 'lang:veykemtu.bridgeapi::default.services.label_menu_planning',
        'type' => 'textarea',
        'comment' => 'lang:veykemtu.bridgeapi::default.services.help_menu_planning',
        'attributes' => ['rows' => 4],
    ],
    'quote_needs' => [
        'label' => 'lang:veykemtu.bridgeapi::default.services.label_quote_needs',
        'type' => 'repeater',
        'commentAbove' => 'lang:veykemtu.bridgeapi::default.services.help_quote_needs',
        'prompt' => 'lang:veykemtu.bridgeapi::default.services.prompt_quote_needs',
        'emptyMessage' => 'lang:veykemtu.bridgeapi::default.services.empty_list',
        'form' => [
            'fields' => [
                RepeaterList::FIELD => [
                    'label' => 'lang:veykemtu.bridgeapi::default.services.label_quote_item',
                    'type' => 'text',
                    'attributes' => ['maxlength' => 200],
                ],
            ],
        ],
    ],

    'body_section' => [
        'type' => 'section',
        'label' => 'lang:veykemtu.bridgeapi::default.services.section_body',
        'comment' => 'lang:veykemtu.bridgeapi::default.services.section_body_comment',
    ],
    'body_html' => [
        'label' => 'lang:veykemtu.bridgeapi::default.services.label_body_html',
        'type' => 'richeditor',
        'comment' => 'lang:veykemtu.bridgeapi::default.services.help_body_html',
    ],
];

/**
 * `slug` KURALI EKSİK GÖRÜNÜYOR AMA DEĞİL: benzersizlik kısmını denetleyici
 * ekliyor (`SiteServices::withSlugRule`), çünkü düzenlenen kaydı hariç
 * tutabilmek için kaydın kimliğini bilmek gerekiyor.
 *
 * Adres deseni küçük harf, rakam ve tire ile sınırlı: büyük harf ve Türkçe
 * karakter içeren bir adres tarayıcıda kaçışlanır ve paylaşılan bağlantı
 * okunmaz hâle gelir.
 */
$config['form']['rules'] = [
    [
        'title',
        'lang:veykemtu.bridgeapi::default.services.label_title',
        'required|string|max:160',
    ],
    [
        'slug',
        'lang:veykemtu.bridgeapi::default.services.label_slug',
        'required|string|max:96|regex:/^[a-z0-9]+(?:-[a-z0-9]+)*$/',
    ],
    [
        'icon',
        'lang:veykemtu.bridgeapi::default.services.label_icon',
        'required|string|in:'.implode(',', array_keys($icons)),
    ],
    [
        'sort_order',
        'lang:veykemtu.bridgeapi::default.services.label_sort_order',
        'nullable|integer|min:0|max:999',
    ],
    [
        'is_published',
        'lang:veykemtu.bridgeapi::default.services.label_published',
        'required|boolean',
    ],
    [
        'summary',
        'lang:veykemtu.bridgeapi::default.services.label_summary',
        'required|string|max:400',
    ],
    [
        'intro',
        'lang:veykemtu.bridgeapi::default.services.label_intro',
        'required|string|max:2000',
    ],
    [
        'audience',
        'lang:veykemtu.bridgeapi::default.services.label_audience',
        'array',
    ],
    [
        'audience.*.'.RepeaterList::FIELD,
        'lang:veykemtu.bridgeapi::default.services.label_audience_item',
        'nullable|string|max:200',
    ],
    [
        'how_it_works',
        'lang:veykemtu.bridgeapi::default.services.label_how_it_works',
        'array',
    ],
    [
        'how_it_works.*.title',
        'lang:veykemtu.bridgeapi::default.services.label_step_title',
        'nullable|string|max:120',
    ],
    [
        'how_it_works.*.body',
        'lang:veykemtu.bridgeapi::default.services.label_step_body',
        'nullable|string|max:600',
    ],
    [
        'benefits',
        'lang:veykemtu.bridgeapi::default.services.label_benefits',
        'array',
    ],
    [
        'benefits.*.'.RepeaterList::FIELD,
        'lang:veykemtu.bridgeapi::default.services.label_benefit_item',
        'nullable|string|max:200',
    ],
    [
        'menu_planning',
        'lang:veykemtu.bridgeapi::default.services.label_menu_planning',
        'required|string|max:2000',
    ],
    [
        'quote_needs',
        'lang:veykemtu.bridgeapi::default.services.label_quote_needs',
        'array',
    ],
    [
        'quote_needs.*.'.RepeaterList::FIELD,
        'lang:veykemtu.bridgeapi::default.services.label_quote_item',
        'nullable|string|max:200',
    ],
    [
        'body_html',
        'lang:veykemtu.bridgeapi::default.services.label_body_html',
        'nullable|string|max:20000',
    ],
];

return $config;
