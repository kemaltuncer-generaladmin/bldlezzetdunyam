<?php

declare(strict_types=1);

use Veykemtu\BridgeApi\Services\KitchenDeviceSettings;

/**
 * Mutfak kasaları listesi ve düzenleme formu —
 * `Veykemtu\BridgeApi\Http\Controllers\Admin\KitchenDevices`.
 *
 * TASARIM KARARI — BOŞ ALAN "KAPALI" DEĞİL, "DOKUNULMADI" DEMEK. Dokuz
 * ayarın hepsi boş bırakılabilir ve boş bırakılan alanda kasa kendi
 * derleme varsayılanını kullanır (`Services\KitchenDeviceSettings`).
 * Bu yüzden iki anahtar (`sound_enabled`, `alarm_silenceable`) `switch`
 * DEĞİL, üç seçenekli `select`'tir: bir anahtar yalnızca açık/kapalı
 * söyleyebilir ve yönetici "dokunmadım"ı "kapattım" sanırdı.
 *
 * KASANIN BİLDİRDİKLERİ (yazıcı durumu, kuyruk, sürüm) FORM ALANI DEĞİLDİR.
 * Onlar salt okunurdur ve `resources/views/kitchendevices/edit.blade.php`
 * içinde formun dışında çizilir; form alanı olsalardı kaydedilebilir
 * görünürlerdi.
 *
 * `placeholder` DEĞERLERİ `lang()` İLE ÇÖZÜLÜR, `lang:` ÖNEKİYLE DEĞİL.
 * Çekirdeğin `text`/`number` alan şablonları placeholder'ı olduğu gibi
 * basıyor (`FormField::evalConfig` bu anahtara çeviri uygulamıyor); önek
 * bırakılsaydı kutuların içinde ham çeviri anahtarı görünürdü. Etiket ve
 * açıklamalarda önek çalışıyor ve öyle kalıyor.
 */
$config['list']['filter'] = [
    'search' => [
        'prompt' => 'lang:veykemtu.bridgeapi::default.kds.text_filter_search',
        'mode' => 'all',
    ],
];

$config['list']['toolbar'] = [
    'buttons' => [
        'create' => [
            'label' => 'lang:veykemtu.bridgeapi::default.kds.button_new',
            'class' => 'btn btn-primary',
            'href' => 'veykemtu/bridgeapi/kitchen_devices/create',
        ],
    ],
];

$config['list']['columns'] = [
    'edit' => [
        'type' => 'button',
        'iconCssClass' => 'fa fa-pencil',
        'attributes' => [
            'class' => 'btn btn-edit',
            'href' => 'veykemtu/bridgeapi/kitchen_devices/edit/{id}',
        ],
    ],
    'name' => [
        'label' => 'lang:veykemtu.bridgeapi::default.kds.column_name',
        'type' => 'text',
        'searchable' => true,
    ],
    // Aşağıdaki dört sütun `partial` tipindedir: her biri birden çok
    // sütunun birleşiminden bir DURUM üretiyor ve rengi o duruma bağlı.
    // `formatter` kapanışıyla HTML üretmek, cihazın bildirdiği sürüm
    // metnini kaçışsız ekrana basma riskini taşırdı.
    'connection' => [
        'label' => 'lang:veykemtu.bridgeapi::default.kds.column_connection',
        'type' => 'partial',
        'path' => 'column_connection',
        'sortable' => false,
    ],
    'printer' => [
        'label' => 'lang:veykemtu.bridgeapi::default.kds.column_printer',
        'type' => 'partial',
        'path' => 'column_printer',
        'sortable' => false,
    ],
    'queue' => [
        'label' => 'lang:veykemtu.bridgeapi::default.kds.column_queue',
        'type' => 'partial',
        'path' => 'column_queue',
        'sortable' => false,
    ],
    'health' => [
        'label' => 'lang:veykemtu.bridgeapi::default.kds.column_health',
        'type' => 'partial',
        'path' => 'column_health',
        'sortable' => false,
    ],
    'id' => [
        'label' => 'lang:admin::lang.column_id',
        'invisible' => true,
    ],
];

$config['form']['toolbar'] = [
    'buttons' => [
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
    ],
];

$config['form']['fields'] = [
    'name' => [
        'label' => 'lang:veykemtu.bridgeapi::default.kds.label_name',
        'type' => 'text',
        'comment' => 'lang:veykemtu.bridgeapi::default.kds.help_name',
        'attributes' => ['maxlength' => 64],
    ],
    'pairing_section@create' => [
        'type' => 'section',
        'label' => 'lang:veykemtu.bridgeapi::default.kds.section_new',
        'comment' => 'lang:veykemtu.bridgeapi::default.kds.section_new_comment',
    ],

    'untouched_section@edit' => [
        'type' => 'section',
        'label' => 'lang:veykemtu.bridgeapi::default.kds.section_settings',
        'comment' => 'lang:veykemtu.bridgeapi::default.kds.section_settings_comment',
    ],
    'poll_seconds@edit' => [
        'label' => 'lang:veykemtu.bridgeapi::default.kds.label_poll_seconds',
        'type' => 'number',
        'span' => 'left',
        'placeholder' => lang('veykemtu.bridgeapi::default.kds.text_device_default'),
        'comment' => 'lang:veykemtu.bridgeapi::default.kds.help_poll_seconds',
        'attributes' => [
            'min' => KitchenDeviceSettings::MIN_POLL_SECONDS,
            'max' => KitchenDeviceSettings::MAX_POLL_SECONDS,
            'step' => 1,
        ],
    ],
    'health_seconds@edit' => [
        'label' => 'lang:veykemtu.bridgeapi::default.kds.label_health_seconds',
        'type' => 'number',
        'span' => 'right',
        'placeholder' => lang('veykemtu.bridgeapi::default.kds.text_device_default'),
        'comment' => 'lang:veykemtu.bridgeapi::default.kds.help_health_seconds',
        'attributes' => ['min' => 10, 'max' => 300, 'step' => 1],
    ],

    'alarm_section@edit' => [
        'type' => 'section',
        'label' => 'lang:veykemtu.bridgeapi::default.kds.section_alarm',
        'comment' => 'lang:veykemtu.bridgeapi::default.kds.section_alarm_comment',
    ],
    'sound_enabled@edit' => [
        'label' => 'lang:veykemtu.bridgeapi::default.kds.label_sound_enabled',
        'type' => 'select',
        'span' => 'left',
        'placeholder' => lang('veykemtu.bridgeapi::default.kds.text_untouched'),
        'comment' => 'lang:veykemtu.bridgeapi::default.kds.help_sound_enabled',
        'options' => [
            1 => 'lang:veykemtu.bridgeapi::default.kds.text_on',
            0 => 'lang:veykemtu.bridgeapi::default.kds.text_off',
        ],
    ],
    'alarm_silenceable@edit' => [
        'label' => 'lang:veykemtu.bridgeapi::default.kds.label_alarm_silenceable',
        'type' => 'select',
        'span' => 'right',
        'placeholder' => lang('veykemtu.bridgeapi::default.kds.text_untouched'),
        'comment' => 'lang:veykemtu.bridgeapi::default.kds.help_alarm_silenceable',
        'options' => [
            1 => 'lang:veykemtu.bridgeapi::default.kds.text_silenceable',
            0 => 'lang:veykemtu.bridgeapi::default.kds.text_not_silenceable',
        ],
    ],
    'connection_alarm_seconds@edit' => [
        'label' => 'lang:veykemtu.bridgeapi::default.kds.label_connection_alarm_seconds',
        'type' => 'number',
        'span' => 'left',
        'placeholder' => lang('veykemtu.bridgeapi::default.kds.text_device_default'),
        'comment' => 'lang:veykemtu.bridgeapi::default.kds.help_connection_alarm_seconds',
        'attributes' => ['min' => 10, 'max' => 600, 'step' => 1],
    ],
    'volume_percent@edit' => [
        'label' => 'lang:veykemtu.bridgeapi::default.kds.label_volume_percent',
        'type' => 'number',
        'span' => 'right',
        'placeholder' => lang('veykemtu.bridgeapi::default.kds.text_device_default'),
        'comment' => 'lang:veykemtu.bridgeapi::default.kds.help_volume_percent',
        'attributes' => ['min' => 0, 'max' => 100, 'step' => 5],
    ],
    'audio_sink@edit' => [
        'label' => 'lang:veykemtu.bridgeapi::default.kds.label_audio_sink',
        'type' => 'text',
        'span' => 'left',
        'placeholder' => lang('veykemtu.bridgeapi::default.kds.text_default_output'),
        'comment' => 'lang:veykemtu.bridgeapi::default.kds.help_audio_sink',
        'attributes' => ['maxlength' => 128],
    ],
    'alarm_repeat_seconds@edit' => [
        'label' => 'lang:veykemtu.bridgeapi::default.kds.label_alarm_repeat_seconds',
        'type' => 'number',
        'span' => 'right',
        'placeholder' => lang('veykemtu.bridgeapi::default.kds.text_device_default'),
        'comment' => 'lang:veykemtu.bridgeapi::default.kds.help_alarm_repeat_seconds',
        'attributes' => ['min' => 0, 'max' => KitchenDeviceSettings::MAX_ALARM_REPEAT_SECONDS, 'step' => 5],
    ],
    'alarm_max_repeats@edit' => [
        'label' => 'lang:veykemtu.bridgeapi::default.kds.label_alarm_max_repeats',
        'type' => 'number',
        'span' => 'left',
        'placeholder' => lang('veykemtu.bridgeapi::default.kds.text_device_default'),
        'comment' => 'lang:veykemtu.bridgeapi::default.kds.help_alarm_max_repeats',
        'attributes' => ['min' => 0, 'max' => 60, 'step' => 1],
    ],
    'tts_enabled@edit' => [
        'label' => 'lang:veykemtu.bridgeapi::default.kds.label_tts_enabled',
        'type' => 'select',
        'span' => 'right',
        'placeholder' => lang('veykemtu.bridgeapi::default.kds.text_untouched'),
        'comment' => 'lang:veykemtu.bridgeapi::default.kds.help_tts_enabled',
        'options' => [
            1 => 'lang:veykemtu.bridgeapi::default.kds.text_on',
            0 => 'lang:veykemtu.bridgeapi::default.kds.text_off',
        ],
    ],
    'tts_rate_percent@edit' => [
        'label' => 'lang:veykemtu.bridgeapi::default.kds.label_tts_rate_percent',
        'type' => 'number',
        'span' => 'left',
        'placeholder' => lang('veykemtu.bridgeapi::default.kds.text_device_default'),
        'comment' => 'lang:veykemtu.bridgeapi::default.kds.help_tts_rate_percent',
        'attributes' => [
            'min' => KitchenDeviceSettings::MIN_TTS_RATE_PERCENT,
            'max' => KitchenDeviceSettings::MAX_TTS_RATE_PERCENT,
            'step' => 10,
        ],
    ],
    'touch_mode@edit' => [
        'label' => 'lang:veykemtu.bridgeapi::default.kds.label_touch_mode',
        'type' => 'select',
        'span' => 'right',
        'placeholder' => lang('veykemtu.bridgeapi::default.kds.text_untouched'),
        'comment' => 'lang:veykemtu.bridgeapi::default.kds.help_touch_mode',
        'options' => [
            1 => 'lang:veykemtu.bridgeapi::default.kds.text_on',
            0 => 'lang:veykemtu.bridgeapi::default.kds.text_off',
        ],
    ],

    'threshold_section@edit' => [
        'type' => 'section',
        'label' => 'lang:veykemtu.bridgeapi::default.kds.section_thresholds',
        'comment' => 'lang:veykemtu.bridgeapi::default.kds.section_thresholds_comment',
    ],
    'warning_after_minutes@edit' => [
        'label' => 'lang:veykemtu.bridgeapi::default.kds.label_warning_after_minutes',
        'type' => 'number',
        'span' => 'left',
        'placeholder' => lang('veykemtu.bridgeapi::default.kds.text_device_default'),
        'comment' => 'lang:veykemtu.bridgeapi::default.kds.help_warning_after_minutes',
        'attributes' => [
            'min' => KitchenDeviceSettings::MIN_THRESHOLD_MINUTES,
            'max' => KitchenDeviceSettings::MAX_THRESHOLD_MINUTES,
            'step' => 1,
        ],
    ],
    'late_after_minutes@edit' => [
        'label' => 'lang:veykemtu.bridgeapi::default.kds.label_late_after_minutes',
        'type' => 'number',
        'span' => 'right',
        'placeholder' => lang('veykemtu.bridgeapi::default.kds.text_device_default'),
        'comment' => 'lang:veykemtu.bridgeapi::default.kds.help_late_after_minutes',
        'attributes' => [
            'min' => KitchenDeviceSettings::MIN_THRESHOLD_MINUTES,
            'max' => KitchenDeviceSettings::MAX_THRESHOLD_MINUTES,
            'step' => 1,
        ],
    ],

    'printer_section@edit' => [
        'type' => 'section',
        'label' => 'lang:veykemtu.bridgeapi::default.kds.section_printer',
        'comment' => 'lang:veykemtu.bridgeapi::default.kds.section_printer_comment',
    ],
    'printer_device_path@edit' => [
        'label' => 'lang:veykemtu.bridgeapi::default.kds.label_printer_device_path',
        'type' => 'text',
        'span' => 'left',
        'placeholder' => '/dev/usb/lp0',
        'comment' => 'lang:veykemtu.bridgeapi::default.kds.help_printer_device_path',
        'attributes' => ['maxlength' => 128],
    ],
    'printer_code_page@edit' => [
        'label' => 'lang:veykemtu.bridgeapi::default.kds.label_printer_code_page',
        'type' => 'number',
        'span' => 'right',
        'placeholder' => lang('veykemtu.bridgeapi::default.kds.text_device_default'),
        'comment' => 'lang:veykemtu.bridgeapi::default.kds.help_printer_code_page',
        'attributes' => ['min' => 0, 'max' => 255, 'step' => 1],
    ],
];

/**
 * Kurallar `KitchenDeviceSettings`'in sınırlarını AYNEN tekrar eder.
 *
 * Servis sınır dışındaki değeri zaten kırpıyor; buradaki kuralların işi
 * kırpmayı önlemek değil, GÖRÜNÜR kılmaktır. "70 yazdım, 60 kaydedildi"
 * sessizce olursa yönetici formun çalışmadığını düşünür.
 *
 * `health_seconds` ve `connection_alarm_seconds` sınırları servis içinde
 * sabit olarak yazılı (adlandırılmış sabitleri yok), bu yüzden burada da
 * sayı olarak duruyorlar.
 */
$config['form']['rules'] = [
    [
        'name',
        'lang:veykemtu.bridgeapi::default.kds.label_name',
        'required|string|max:64',
    ],
    [
        'poll_seconds',
        'lang:veykemtu.bridgeapi::default.kds.label_poll_seconds',
        'nullable|integer|min:'.KitchenDeviceSettings::MIN_POLL_SECONDS.'|max:'.KitchenDeviceSettings::MAX_POLL_SECONDS,
    ],
    [
        'health_seconds',
        'lang:veykemtu.bridgeapi::default.kds.label_health_seconds',
        'nullable|integer|min:10|max:300',
    ],
    [
        'sound_enabled',
        'lang:veykemtu.bridgeapi::default.kds.label_sound_enabled',
        'nullable|boolean',
    ],
    [
        'alarm_silenceable',
        'lang:veykemtu.bridgeapi::default.kds.label_alarm_silenceable',
        'nullable|boolean',
    ],
    [
        'connection_alarm_seconds',
        'lang:veykemtu.bridgeapi::default.kds.label_connection_alarm_seconds',
        'nullable|integer|min:10|max:600',
    ],
    [
        'volume_percent',
        'lang:veykemtu.bridgeapi::default.kds.label_volume_percent',
        'nullable|integer|min:0|max:100',
    ],
    [
        'audio_sink',
        'lang:veykemtu.bridgeapi::default.kds.label_audio_sink',
        'nullable|string|max:128',
    ],
    [
        'alarm_repeat_seconds',
        'lang:veykemtu.bridgeapi::default.kds.label_alarm_repeat_seconds',
        'nullable|integer|min:0|max:'.KitchenDeviceSettings::MAX_ALARM_REPEAT_SECONDS,
    ],
    [
        'alarm_max_repeats',
        'lang:veykemtu.bridgeapi::default.kds.label_alarm_max_repeats',
        'nullable|integer|min:0|max:60',
    ],
    [
        'tts_enabled',
        'lang:veykemtu.bridgeapi::default.kds.label_tts_enabled',
        'nullable|boolean',
    ],
    [
        'tts_rate_percent',
        'lang:veykemtu.bridgeapi::default.kds.label_tts_rate_percent',
        'nullable|integer|min:'.KitchenDeviceSettings::MIN_TTS_RATE_PERCENT.'|max:'.KitchenDeviceSettings::MAX_TTS_RATE_PERCENT,
    ],
    [
        'touch_mode',
        'lang:veykemtu.bridgeapi::default.kds.label_touch_mode',
        'nullable|boolean',
    ],
    [
        'warning_after_minutes',
        'lang:veykemtu.bridgeapi::default.kds.label_warning_after_minutes',
        'nullable|integer|min:'.KitchenDeviceSettings::MIN_THRESHOLD_MINUTES.'|max:'.KitchenDeviceSettings::MAX_THRESHOLD_MINUTES,
    ],
    [
        'late_after_minutes',
        'lang:veykemtu.bridgeapi::default.kds.label_late_after_minutes',
        'nullable|integer|min:'.KitchenDeviceSettings::MIN_THRESHOLD_MINUTES.'|max:'.KitchenDeviceSettings::MAX_THRESHOLD_MINUTES,
    ],
    [
        'printer_device_path',
        'lang:veykemtu.bridgeapi::default.kds.label_printer_device_path',
        'nullable|string|max:128',
    ],
    [
        'printer_code_page',
        'lang:veykemtu.bridgeapi::default.kds.label_printer_code_page',
        'nullable|integer|min:0|max:255',
    ],
];

return $config;
