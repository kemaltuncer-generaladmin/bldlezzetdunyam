<?php

declare(strict_types=1);

/**
 * "Site İçeriği" form tanımı — `Veykemtu\BridgeApi\Admin\SiteContentSettings`.
 *
 * TASARIM KARARI — bölümler yöneticinin aradığı sıraya göre: en sık
 * değişecek olan (iletişim) en üstte değil ama marka hemen ardından geliyor;
 * en nadir değişecekler (kalite zinciri) en altta. Alfabetik veya teknik
 * sıralama, aylık bir güncelleme için sayfayı baştan sona taratırdı.
 *
 * ETİKETLER AYRI DİL DOSYASINDA (`sitecontent.php`), `default.php`'de değil:
 * bu sayfa ile hizmet/yazı ekranları farklı zamanlarda ve farklı kişilerce
 * değişiyor; aynı dosyaya yığmak birleştirme çakışması üretir.
 */

use Veykemtu\BridgeApi\Admin\BrandGuard;

/** Sitenin tanıdığı lucide ikon adları. Bilinmeyen ad varsayılana düşer. */
$iconOptions = [
    'Building2' => 'Bina',
    'Truck' => 'Kamyon',
    'ChefHat' => 'Aşçı şapkası',
    'GraduationCap' => 'Mezuniyet',
    'Stethoscope' => 'Stetoskop',
    'HardHat' => 'Baret',
    'CalendarHeart' => 'Takvim',
    'Coffee' => 'Kahve',
    'UtensilsCrossed' => 'Çatal bıçak',
    'Soup' => 'Çorba',
    'Factory' => 'Fabrika',
    'HeartPulse' => 'Kalp',
    'Landmark' => 'Kamu binası',
    'TrafficCone' => 'İnşaat',
    'PartyPopper' => 'Kutlama',
    'Building' => 'Ofis',
    'Sprout' => 'Filiz',
    'Refrigerator' => 'Soğutucu',
    'ShieldCheck' => 'Kalkan',
    'ClipboardCheck' => 'Kontrol listesi',
    'ThermometerSnowflake' => 'Sıcaklık',
    'PackageCheck' => 'Paket',
    'MessageSquare' => 'Mesaj',
    'ClipboardList' => 'Liste',
    'CalendarCheck' => 'Takvim onay',
    'Sparkles' => 'Parıltı',
    'UsersRound' => 'Kişiler',
    'HandshakeIcon' => 'El sıkışma',
];

return [
    'form' => [
        'toolbar' => [
            'buttons' => [
                'save' => [
                    'label' => 'lang:admin::lang.button_save',
                    'class' => 'btn btn-primary',
                    'data-request' => 'onSave',
                ],
                'saveClose' => [
                    'label' => 'lang:admin::lang.button_save_close',
                    'class' => 'btn btn-default',
                    'data-request' => 'onSave',
                    'data-request-data' => 'close:1',
                ],
            ],
        ],
        'fields' => [
            // ── Marka ──────────────────────────────────────────────────────
            'brand_section' => [
                'type' => 'section',
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.section_brand',
                'comment' => 'lang:veykemtu.bridgeapi::sitecontent.section_brand_comment',
            ],
            'brand_name' => [
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_brand_name',
                'type' => 'text',
                'span' => 'left',
            ],
            'brand_short_name' => [
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_brand_short_name',
                'type' => 'text',
                'span' => 'right',
            ],
            'brand_tagline' => [
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_brand_tagline',
                'type' => 'text',
                'comment' => 'lang:veykemtu.bridgeapi::sitecontent.help_brand_tagline',
            ],
            'brand_description' => [
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_brand_description',
                'type' => 'textarea',
                'attributes' => ['rows' => 2],
                'comment' => 'lang:veykemtu.bridgeapi::sitecontent.help_brand_description',
            ],
            'brand_parent_group' => [
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_brand_parent_group',
                'type' => 'text',
                'span' => 'left',
            ],
            'brand_primary_color' => [
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_brand_color',
                'type' => 'colorpicker',
                'span' => 'right',
                // Kontrast eşiği burada da yazılı: yönetici reddedilme
                // mesajını görmeden önce kuralı bilsin.
                'comment' => 'lang:veykemtu.bridgeapi::sitecontent.help_brand_color',
            ],
            'brand_logo' => [
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_brand_logo',
                'type' => 'mediafinder',
                'mode' => 'inline',
                'comment' => 'lang:veykemtu.bridgeapi::sitecontent.help_brand_logo',
            ],

            // ── İletişim ───────────────────────────────────────────────────
            'contact_section' => [
                'type' => 'section',
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.section_contact',
                'comment' => 'lang:veykemtu.bridgeapi::sitecontent.section_contact_comment',
            ],
            'contact_phone' => [
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_phone',
                'type' => 'text',
                'span' => 'left',
                'placeholder' => '0212 000 00 00',
                'comment' => 'lang:veykemtu.bridgeapi::sitecontent.help_phone',
            ],
            'contact_whatsapp' => [
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_whatsapp',
                'type' => 'text',
                'span' => 'right',
                'placeholder' => '0555 000 00 00',
                'comment' => 'lang:veykemtu.bridgeapi::sitecontent.help_whatsapp',
            ],
            'contact_email' => [
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_email',
                'type' => 'text',
                'span' => 'left',
            ],
            'address_street' => [
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_street',
                'type' => 'text',
                'comment' => 'lang:veykemtu.bridgeapi::sitecontent.help_address',
            ],
            'address_district' => [
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_district',
                'type' => 'text',
                'span' => 'left',
            ],
            'address_city' => [
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_city',
                'type' => 'text',
                'span' => 'right',
            ],
            'address_postal_code' => [
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_postal_code',
                'type' => 'text',
                'span' => 'left',
            ],
            'address_map_embed_url' => [
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_map',
                'type' => 'text',
                'comment' => 'lang:veykemtu.bridgeapi::sitecontent.help_map',
            ],
            'working_hours' => [
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_working_hours',
                'type' => 'repeater',
                'form' => [
                    'fields' => [
                        'label' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_hours_day',
                            'type' => 'text',
                            'span' => 'left',
                            'placeholder' => 'Hafta içi',
                        ],
                        'value' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_hours_value',
                            'type' => 'text',
                            'span' => 'right',
                            'placeholder' => '08:00 – 18:00',
                        ],
                    ],
                ],
            ],
            'social' => [
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_social',
                'type' => 'repeater',
                'form' => [
                    'fields' => [
                        'label' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_social_name',
                            'type' => 'text',
                            'span' => 'left',
                        ],
                        'href' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_social_url',
                            'type' => 'text',
                            'span' => 'right',
                        ],
                    ],
                ],
            ],

            // ── Kurumsal ───────────────────────────────────────────────────
            'company_section' => [
                'type' => 'section',
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.section_company',
            ],
            'company_mission' => [
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_mission',
                'type' => 'textarea',
                'attributes' => ['rows' => 3],
            ],
            'company_vision' => [
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_vision',
                'type' => 'textarea',
                'attributes' => ['rows' => 3],
            ],
            'company_group_relation' => [
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_group_relation',
                'type' => 'textarea',
                'attributes' => ['rows' => 2],
                'comment' => 'lang:veykemtu.bridgeapi::sitecontent.help_group_relation',
            ],
            'company_values' => [
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_values',
                'type' => 'repeater',
                'form' => [
                    'fields' => [
                        'title' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_title',
                            'type' => 'text',
                        ],
                        'body' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_body',
                            'type' => 'textarea',
                            'attributes' => ['rows' => 2],
                        ],
                    ],
                ],
            ],
            'company_process_steps' => [
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_process',
                'type' => 'repeater',
                'comment' => 'lang:veykemtu.bridgeapi::sitecontent.help_process',
                'form' => [
                    'fields' => [
                        'title' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_title',
                            'type' => 'text',
                            'span' => 'left',
                        ],
                        'icon' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_icon',
                            'type' => 'select',
                            'span' => 'right',
                            'options' => $iconOptions,
                        ],
                        'body' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_body',
                            'type' => 'textarea',
                            'attributes' => ['rows' => 2],
                        ],
                    ],
                ],
            ],
            'company_differentiators' => [
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_differentiators',
                'type' => 'repeater',
                'form' => [
                    'fields' => [
                        'title' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_title',
                            'type' => 'text',
                            'span' => 'left',
                        ],
                        'icon' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_icon',
                            'type' => 'select',
                            'span' => 'right',
                            'options' => $iconOptions,
                        ],
                        'body' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_body',
                            'type' => 'textarea',
                            'attributes' => ['rows' => 2],
                        ],
                    ],
                ],
            ],

            // ── Sık sorulan sorular ────────────────────────────────────────
            'faq_section' => [
                'type' => 'section',
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.section_faq',
                'comment' => 'lang:veykemtu.bridgeapi::sitecontent.section_faq_comment',
            ],
            'faq' => [
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_faq',
                'type' => 'repeater',
                'form' => [
                    'fields' => [
                        'question' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_question',
                            'type' => 'text',
                        ],
                        'answer' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_answer',
                            'type' => 'textarea',
                            'attributes' => ['rows' => 3],
                        ],
                    ],
                ],
            ],

            // ── Sektörler ──────────────────────────────────────────────────
            'sectors_section' => [
                'type' => 'section',
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.section_sectors',
                'comment' => 'lang:veykemtu.bridgeapi::sitecontent.section_sectors_comment',
            ],
            'sectors' => [
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_sectors',
                'type' => 'repeater',
                'form' => [
                    'fields' => [
                        'title' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_title',
                            'type' => 'text',
                            'span' => 'left',
                        ],
                        'slug' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_slug',
                            'type' => 'text',
                            'span' => 'right',
                        ],
                        'icon' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_icon',
                            'type' => 'select',
                            'span' => 'left',
                            'options' => $iconOptions,
                        ],
                        'service_slug' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_service_slug',
                            'type' => 'text',
                            'span' => 'right',
                            'comment' => 'lang:veykemtu.bridgeapi::sitecontent.help_service_slug',
                        ],
                        'need' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_need',
                            'type' => 'textarea',
                            'attributes' => ['rows' => 2],
                        ],
                        'answer' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_our_answer',
                            'type' => 'textarea',
                            'attributes' => ['rows' => 2],
                        ],
                    ],
                ],
            ],

            // ── Menü çözümleri ─────────────────────────────────────────────
            'menus_section' => [
                'type' => 'section',
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.section_menus',
                'comment' => 'lang:veykemtu.bridgeapi::sitecontent.section_menus_comment',
            ],
            'menu_solutions' => [
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_menu_solutions',
                'type' => 'repeater',
                'form' => [
                    'fields' => [
                        'title' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_title',
                            'type' => 'text',
                            'span' => 'left',
                        ],
                        'slug' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_slug',
                            'type' => 'text',
                            'span' => 'right',
                        ],
                        'summary' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_summary',
                            'type' => 'textarea',
                            'attributes' => ['rows' => 2],
                        ],
                        'audience' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_audience',
                            'type' => 'text',
                        ],
                        'principle' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_principle',
                            'type' => 'textarea',
                            'attributes' => ['rows' => 2],
                        ],
                        'courses' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_courses',
                            'type' => 'repeater',
                            'form' => [
                                'fields' => [
                                    'label' => [
                                        'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_course_name',
                                        'type' => 'text',
                                        'span' => 'left',
                                    ],
                                    'examples' => [
                                        'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_examples',
                                        'type' => 'text',
                                        'span' => 'right',
                                        'comment' => 'lang:veykemtu.bridgeapi::sitecontent.help_examples',
                                    ],
                                ],
                            ],
                        ],
                    ],
                ],
            ],
            'menu_seasonal' => [
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_seasonal',
                'type' => 'repeater',
                'form' => [
                    'fields' => [
                        'season' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_season',
                            'type' => 'text',
                            'span' => 'left',
                        ],
                        'note' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_note',
                            'type' => 'text',
                            'span' => 'right',
                        ],
                    ],
                ],
            ],

            // ── Kalite ve hijyen ───────────────────────────────────────────
            'quality_section' => [
                'type' => 'section',
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.section_quality',
                'comment' => 'lang:veykemtu.bridgeapi::sitecontent.section_quality_comment',
            ],
            'quality_chain' => [
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_quality_chain',
                'type' => 'repeater',
                'form' => [
                    'fields' => [
                        'title' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_title',
                            'type' => 'text',
                            'span' => 'left',
                        ],
                        'icon' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_icon',
                            'type' => 'select',
                            'span' => 'right',
                            'options' => $iconOptions,
                        ],
                        'body' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_body',
                            'type' => 'textarea',
                            'attributes' => ['rows' => 2],
                        ],
                    ],
                ],
            ],
            'quality_allergen' => [
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_allergen',
                'type' => 'repeater',
                'form' => [
                    'fields' => [
                        'text' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_item',
                            'type' => 'text',
                        ],
                    ],
                ],
            ],
            'quality_certifications' => [
                'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_certifications',
                'type' => 'repeater',
                // EN ÖNEMLİ AÇIKLAMA: sahip olunmayan belge yazılmamalı.
                'comment' => 'lang:veykemtu.bridgeapi::sitecontent.help_certifications',
                'form' => [
                    'fields' => [
                        'name' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_cert_name',
                            'type' => 'text',
                            'span' => 'left',
                        ],
                        'issuer' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_cert_issuer',
                            'type' => 'text',
                            'span' => 'right',
                        ],
                        'valid_until' => [
                            'label' => 'lang:veykemtu.bridgeapi::sitecontent.label_cert_valid',
                            'type' => 'text',
                            'span' => 'left',
                        ],
                    ],
                ],
            ],
        ],

        'rules' => [
            ['brand_name', 'lang:veykemtu.bridgeapi::sitecontent.label_brand_name', 'required|string|max:120'],
            ['brand_short_name', 'lang:veykemtu.bridgeapi::sitecontent.label_brand_short_name', 'nullable|string|max:32'],
            ['contact_email', 'lang:veykemtu.bridgeapi::sitecontent.label_email', 'nullable|email|max:160'],
            ['address_map_embed_url', 'lang:veykemtu.bridgeapi::sitecontent.label_map', 'nullable|url|max:600'],
        ],
    ],

    /** Kontrast eşiği tek kaynaktan okunur; dil dosyasındaki metne gömülmez. */
    'min_contrast' => BrandGuard::MIN_CONTRAST,
];
