<?php

declare(strict_types=1);

use Veykemtu\BridgeApi\Admin\SettingsRepository;
use Veykemtu\BridgeApi\Services\LocationGate;

/**
 * "BLD Ayarları" form tanımı — `Veykemtu\BridgeApi\Admin\BldSettings`.
 *
 * TASARIM KARARI — iki bölüm, ayrı başlıklarla: yöneticinin bu sayfada
 * yapabileceği en pahalı hata, "bugün çok yoğunuz" derken sipariş alımını
 * kapatmaktır. Bu yüzden yoğunluk anahtarı sipariş şalterinin YANINDA değil,
 * kendi bölümünde ve altında ne yapıp ne yapmadığını söyleyen bir açıklamayla
 * durur (`docs/11-yol-haritasi.md` §8).
 *
 * PARA ALANLARI `text` TİPİNDEDİR, `number` DEĞİL: form parçacığı `number`
 * tipini postback'te `(int)` ile daraltıyor ve "45.50" değeri 45'e düşüyor.
 * Ayrıntı ve dönüşüm: `Veykemtu\BridgeApi\Admin\LiraField`.
 */
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
            'ordering_section' => [
                'type' => 'section',
                'label' => 'lang:veykemtu.bridgeapi::default.section_ordering',
                'comment' => 'lang:veykemtu.bridgeapi::default.section_ordering_comment',
            ],
            SettingsRepository::FIELD_ORDERING => [
                'label' => 'lang:veykemtu.bridgeapi::default.label_ordering_enabled',
                'type' => 'switch',
                'default' => 1,
                'comment' => 'lang:veykemtu.bridgeapi::default.help_ordering_enabled',
            ],
            SettingsRepository::FIELD_CUTOFF => [
                'label' => 'lang:veykemtu.bridgeapi::default.label_order_cutoff',
                'type' => 'text',
                'span' => 'left',
                'placeholder' => '16:00',
                'comment' => 'lang:veykemtu.bridgeapi::default.help_order_cutoff',
                'attributes' => ['inputmode' => 'numeric', 'maxlength' => 5],
            ],
            SettingsRepository::FIELD_MIN_TOTAL => [
                'label' => 'lang:veykemtu.bridgeapi::default.label_min_order_total',
                'type' => 'text',
                'span' => 'right',
                'placeholder' => '0.00',
                'comment' => 'lang:veykemtu.bridgeapi::default.help_min_order_total',
                'attributes' => ['inputmode' => 'decimal'],
            ],
            SettingsRepository::FIELD_DELIVERY_FEE => [
                'label' => 'lang:veykemtu.bridgeapi::default.label_delivery_fee',
                'type' => 'text',
                'span' => 'left',
                'placeholder' => '0.00',
                'comment' => 'lang:veykemtu.bridgeapi::default.help_delivery_fee',
                'attributes' => ['inputmode' => 'decimal'],
            ],
            SettingsRepository::FIELD_PAYMENTS => [
                'label' => 'lang:veykemtu.bridgeapi::default.label_payment_methods',
                'type' => 'checkbox',
                'comment' => 'lang:veykemtu.bridgeapi::default.help_payment_methods',
                'options' => [
                    'online' => 'lang:veykemtu.bridgeapi::default.text_payment_online',
                    'cash' => 'lang:veykemtu.bridgeapi::default.text_payment_cash',
                    'account' => 'lang:veykemtu.bridgeapi::default.text_payment_account',
                ],
            ],
            'busy_section' => [
                'type' => 'section',
                'label' => 'lang:veykemtu.bridgeapi::default.section_busy',
                'comment' => 'lang:veykemtu.bridgeapi::default.section_busy_comment',
            ],
            SettingsRepository::FIELD_BUSY => [
                'label' => 'lang:veykemtu.bridgeapi::default.label_busy',
                'type' => 'switch',
                'default' => 0,
                'comment' => 'lang:veykemtu.bridgeapi::default.help_busy',
            ],
            // Sayfa çizildiği andaki yoğunluk değeri. Kaydetmede mutfağın
            // aradaki değişikliğini ezmemek için kullanılır — gerekçe:
            // SettingsRepository::saveBusy().
            SettingsRepository::FIELD_BUSY_SNAPSHOT => [
                'type' => 'hidden',
            ],
            SettingsRepository::FIELD_BUSY_MESSAGE => [
                'label' => 'lang:veykemtu.bridgeapi::default.label_busy_message',
                'type' => 'textarea',
                'attributes' => ['rows' => 3, 'maxlength' => 500],
                'comment' => 'lang:veykemtu.bridgeapi::default.help_busy_message',
            ],
        ],
        'rules' => [
            [
                SettingsRepository::FIELD_ORDERING,
                'lang:veykemtu.bridgeapi::default.label_ordering_enabled',
                'required|boolean',
            ],
            [
                SettingsRepository::FIELD_CUTOFF,
                'lang:veykemtu.bridgeapi::default.label_order_cutoff',
                'nullable|date_format:H:i',
            ],
            // Binlik ayıracına izin verilmiyor: "1.250" yazan bir yönetici
            // 1250 TL mi 1,25 TL mi kastettiğini tahmin ettirmemeli.
            [
                SettingsRepository::FIELD_MIN_TOTAL,
                'lang:veykemtu.bridgeapi::default.label_min_order_total',
                'required|regex:/^\d{1,6}([.,]\d{1,2})?$/',
            ],
            [
                SettingsRepository::FIELD_DELIVERY_FEE,
                'lang:veykemtu.bridgeapi::default.label_delivery_fee',
                'required|regex:/^\d{1,6}([.,]\d{1,2})?$/',
            ],
            [
                SettingsRepository::FIELD_PAYMENTS,
                'lang:veykemtu.bridgeapi::default.label_payment_methods',
                'required|array|min:1',
            ],
            [
                SettingsRepository::FIELD_PAYMENTS.'.*',
                'lang:veykemtu.bridgeapi::default.label_payment_methods',
                'in:'.implode(',', LocationGate::ALL_PAYMENT_METHODS),
            ],
            [
                SettingsRepository::FIELD_BUSY,
                'lang:veykemtu.bridgeapi::default.label_busy',
                'required|boolean',
            ],
            [
                SettingsRepository::FIELD_BUSY_SNAPSHOT,
                'lang:veykemtu.bridgeapi::default.label_busy',
                'nullable|boolean',
            ],
            [
                SettingsRepository::FIELD_BUSY_MESSAGE,
                'lang:veykemtu.bridgeapi::default.label_busy_message',
                'nullable|string|max:500',
            ],
        ],
    ],
];
