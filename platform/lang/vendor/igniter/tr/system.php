<?php

declare(strict_types=1);

/**
 * Sistem ayarları, eklentiler ve e-posta şablonları — `igniter::system.*`.
 *
 * TARİH BİÇİMLERİ DE BURADA ve bunlar çeviri değil, YERELLEŞTİRME:
 * çekirdek `d M Y` ve `hh:mm a` kullanıyor, yani "05 Aug 2026, 02:30 pm".
 * Türkçede tarih `05.08.2026`, saat 24 saatlik. Bu anahtarlar
 * düzeltilmezse panel Türkçe görünür ama tarihleri İngilizce okur.
 *
 * `system.checks.*` KASTEN ÇEVRİLMEDİ: php.ini yönergelerine ve kabuk
 * komutlarına (`php artisan queue:work`) atıf yapan teknik tanı metinleri.
 * İngilizce hâlleri aranabilir ve yanlış bir çeviri gerçek sorunu gizler.
 */
return [
    'version' => 'Sürüm',

    'no_database' => [
        'label' => 'Veritabanı hatası',
        'help' => 'Veritabanı bağlantısı gerekli. Tekrar denemeden önce veritabanının doğru yapılandırıldığını ve göçlerin koştuğunu kontrol edin.',
    ],

    'missing' => [
        'carte_key' => 'Carte anahtarı bulunamadı; girmek için aşağıdaki düğmeye tıklayın.',
    ],

    'date' => [
        'today' => 'Bugün',
        'tomorrow' => 'Yarın',
        'yesterday' => 'Dün',
        'full' => '%s %s',
    ],

    // PHP `date()` biçimleri. Türkçede gün.ay.yıl ve 24 saat.
    'php' => [
        'date_format' => 'd.m.Y',
        'date_format_short' => 'd.m',
        'date_format_long' => 'j F Y, l',
        'time_format' => 'H:i',
        'date_time_format' => 'd.m.Y H:i',
        'date_time_format_short' => 'd.m H:i',
        'date_time_format_long' => 'j F Y, l H:i',
    ],

    // Moment.js biçimleri. `hh:mm a` (öğleden önce/sonra) BIRAKILMADI;
    // Türkçede saat 24 saatliktir ve "02:30 pm" okunmaz.
    'moment' => [
        'date_format' => 'DD.MM.YYYY',
        'date_format_short' => 'DD.MM',
        'date_format_long' => 'D MMMM YYYY, dddd',
        'time_format' => 'HH:mm',
        'date_time_format' => 'DD.MM.YYYY HH:mm',
        'date_time_format_short' => 'DD.MM HH:mm',
        'date_time_format_long' => 'D MMMM YYYY, dddd HH:mm',
        'weekday_format' => 'ddd',
        'day_format' => 'ddd DD',
        'day_time_format' => 'ddd DD HH:mm',
        'day_time_format_short' => 'ddd HH:mm',
    ],

    'countries' => [
        'text_title' => 'Ülkeler',
        'text_form_name' => 'Ülke',
        'text_filter_search' => 'Ad ya da koda göre arayın.',
        'text_empty' => 'Tanımlı ülke yok.',

        'column_status' => 'Durum',

        'label_priority' => 'Öncelik',
        'label_format' => 'Adres biçimi',

        'alert_set_default' => 'Ülke varsayılan yapıldı',
    ],

    'currencies' => [
        'text_title' => 'Para birimleri',
        'text_form_name' => 'Para birimi',
        'text_filter_search' => 'Ad ya da koda göre arayın.',
        'text_empty' => 'Tanımlı para birimi yok.',
        'text_right' => 'Sağda',
        'text_left' => 'Solda',

        'column_code' => 'Kod',
        'column_country' => 'Ülke',
        'column_symbol' => 'Simge',
        'column_rate' => 'Kur',
        'column_status' => 'Durum',

        'label_title' => 'Ad',
        'label_code' => 'Kod',
        'label_country' => 'Ülke',
        'label_symbol' => 'Simge',
        'label_symbol_position' => 'Simge konumu',
        'label_rate' => 'Kur',
        'label_thousand_sign' => 'Binlik ayracı',
        'label_decimal_sign' => 'Ondalık ayracı',
        'label_decimal_position' => 'Ondalık basamak',

        'alert_set_default' => 'Para birimi varsayılan yapıldı',
    ],

    'extensions' => [
        'text_title' => 'Eklentiler',
        'text_delete_title' => 'Eklenti: Sil',
        'text_filter_search' => 'Ada göre arayın.',
        'text_empty' => 'Eklenti yok.',
        'text_installed' => 'Kurulu',
        'text_uninstalled' => 'Kurulu değil',
        'text_files' => 'dosyalar',
        'text_files_data' => 'dosyalar ve veriler',
        'text_settings' => 'Ayarlar',
        'text_author' => 'Geliştirici',

        'button_delete' => 'Sil',
        'button_yes_delete' => 'Evet, sil',
        'button_return_to_list' => 'Hayır, listeye dön',

        'column_icon' => 'Simge',
        'column_version' => 'Sürüm',

        'label_delete_data' => 'Verileri de sil',

        'alert_delete_warning' => '<b>%s</b> eklentisinin %s öğesini silmek üzeresiniz',
        'alert_delete_confirm' => 'İlgili %s silinsin mi? Bu işlem geri alınamaz.',
        'alert_is_installed' => '. Silmeden önce eklentiyi kaldırmalısınız.',
        'alert_is_required' => 'Bu eklenti sistem tarafından zorunlu tutulduğu için kaldırılamaz.',
    ],

    'languages' => [
        'text_title' => 'Diller',
        'text_form_name' => 'Dil',
        'text_tab_general' => 'Ayrıntılar',
        'text_tab_files' => 'Çeviriler',
        'text_tab_edit_file' => 'Çevirileri düzenle',
        'text_filter_search' => 'Ada göre arayın.',
        'text_filter_file' => 'Tüm gruplar',
        'text_filter_translations' => 'Çevirilerde anahtar ya da metne göre arayın',
        'text_empty' => 'Tanımlı dil yok.',
        'text_empty_translations' => 'Çeviri yok.',
        'text_files' => 'dosyalar',
        'text_locale_strings' => 'Toplam: %s, çevrilen: %s (%%%s), çevrilmeyen: %s',

        'column_code' => 'Kod',
        'column_status' => 'Durum',
        'column_variable' => 'Kaynak metin (İngilizce)',
        'column_language' => 'Çeviri (%s)',

        'label_code' => 'Yerel kodu',
        'label_image' => 'Simge',

        'help_locale_strings' => '<b>%s</b> ya da <b>:name</b> gibi yer tutucuları ÇEVİRMEYİN, olduğu gibi bırakın.',

        'alert_set_default' => 'Dil varsayılan yapıldı',
        'alert_language_not_found' => 'Dil bulunamadı',

        'translations' => [
            'label_file' => 'Dil dosyası',
            'label_search' => 'Ara',

            'help_no_files' => 'Bu dil için eşleşen çeviri bulunamadı.',
        ],
    ],

    'mail_templates' => [
        'text_title' => 'E-posta düzenleri',
        'text_form_name' => 'E-posta düzeni',
        'text_template_title' => 'E-posta şablonları',
        'text_new_template_title' => 'E-posta şablonu: Yeni',
        'text_edit_template_title' => 'E-posta şablonu: Düzenle',
        'text_preview_template_title' => 'E-posta şablonu: Önizleme',
        'text_partial_title' => 'E-posta parçaları',
        'text_partial_form_name' => 'E-posta parçası',
        'text_templates' => 'Şablonlar',
        'text_layouts' => 'Düzenler',
        'text_partials' => 'Parçalar',
        'text_empty' => 'Tanımlı e-posta şablonu yok.',
        'text_variables' => 'Değişkenler',
        'text_internal' => 'Sistem mesajı',

        'button_test_message' => 'Test mesajı gönder',

        'column_code' => 'Kod',
        'column_title' => 'Başlık',
        'column_layout' => 'Düzen',
        'column_status' => 'Durum',

        'label_language' => 'Dil',
        'label_code' => 'Kod',
        'label_subject' => 'Konu',
        'label_layout' => 'Düzen',
        'label_body' => 'HTML',
        'label_plain' => 'Düz metin',

        'help_variables' => 'Bu değişkenleri içerik alanına sürükleyin:',

        'alert_test_message_sent' => 'Test mesajı %s adresine gönderildi',
        'alert_template_not_found' => ' Şablon bulunamadı',
    ],

    'mail_variables' => [
        'text_group_global' => 'Genel değişkenler',
        'text_site_name' => 'İşletme adı',
        'text_site_logo' => 'İşletme logosu',

        'text_group_customer' => 'Müşteri değişkenleri',
        'text_first_name' => 'Müşteri adı',
        'text_last_name' => 'Müşteri soyadı',
        'text_email' => 'Müşteri e-posta adresi',
        'text_telephone' => 'Müşteri telefonu',

        'text_group_registration' => 'Kayıt değişkenleri',
        'text_group_reset' => 'Parola sıfırlama değişkenleri',
        'text_reset_code' => 'Parola sıfırlama kodu',
        'text_reset_link' => 'Parola sıfırlama bağlantısı',

        'text_group_order' => 'Sipariş değişkenleri',
        'text_order_number' => 'Sipariş numarası',
        'text_customer_name' => 'Müşteri ad soyad',
        'text_order_type' => 'Sipariş türü (teslimat / gel al)',
        'text_order_time' => 'Teslim ya da gel al saati',
        'text_order_date' => 'Teslim ya da gel al tarihi',
        'text_order_added' => 'Sipariş oluşturma tarihi',
        'text_order_payment' => 'Ödeme yöntemi',
        'text_order_address' => 'Teslimat adresi',
        'text_order_comment' => 'Sipariş notu',
        'text_location_name' => 'Şube adı',
        'text_location_email' => 'Şube e-postası',
        'text_location_address' => 'Şube adresi',
        'text_location_telephone' => 'Şube telefonu',
        'text_menu_name' => 'Ürün adı',
        'text_menu_quantity' => 'Ürün adedi',
        'text_menu_price' => 'Ürün fiyatı',
        'text_menu_subtotal' => 'Ürün ara toplamı',
        'text_menu_comment' => 'Ürün notu',
        'text_order_total_title' => 'Toplam başlığı',
        'text_order_total_value' => 'Toplam tutar',

        'text_status_name' => 'Durum adı',
        'text_status_comment' => 'Durum notu',

        'text_group_stock' => 'Stok değişkenleri',
        'text_stock_name' => 'Stok adı',
        'text_stock_quantity' => 'Stok adedi',
        'text_low_stock_threshold' => 'Düşük stok eşiği',
    ],

    'permissions' => [
        'name' => 'Gelişmiş',
        'countries' => 'Ülke oluştur, düzenle ve sil',
        'currencies' => 'Para birimi oluştur, düzenle ve sil',
        'system_logs' => 'Sistem ve istek günlüklerini görüntüle',
        'extensions' => 'Eklenti kur, kaldır ve sil',
        'mail_templates' => 'E-posta şablonu oluştur, düzenle ve sil',
        'notifications' => 'Bildirimlere eriş ve yönet',
        'languages' => 'Dil oluştur, düzenle ve sil',
        'settings' => 'Sistem ayarlarını yönet',
        'system_info' => 'Sistem bilgilerini görüntüle ve bakım işlemlerini çalıştır',
    ],

    'system' => [
        'text_title' => 'Sistem bilgileri',
        'button_clear_cache' => 'Önbelleği temizle',
        'button_migrate' => 'Veritabanı göçü',
        'confirm_migrate' => 'Veritabanı göçlerini çalıştırmak istediğinize emin misiniz?',
        'alert_cache_cleared' => 'Önbellek temizlendi.',
        'alert_migrate_success' => 'Veritabanı göçleri tamamlandı.',
        'button_view_extensions_themes' => 'Listeyi gör',
        'status_ok' => 'Tamam',
        'status_warning' => 'Uyarı',
        'status_failed' => 'Başarısız',
    ],

    'request_logs' => [
        'text_title' => 'İstek günlükleri',
        'text_form_name' => 'İstek günlüğü',
        'text_filter_search' => 'Ada göre arayın.',
        'text_empty' => 'İstek günlüğü yok.',

        'column_status_code' => 'Durum kodu',
        'column_url' => 'İstenen adres',
        'column_count' => 'Sayaç',

        'label_url' => 'İstenen adres',
        'label_referer' => 'Yönlendiren',
    ],

    'settings' => [
        'text_title' => 'Ayarlar',
        'text_edit_title' => 'Ayarlar: %s',
        'text_tab_general' => 'Genel',
        'text_tab_site' => 'Yerelleştirme',
        'text_tab_restaurant' => 'İşletme',
        'text_tab_mail' => 'E-posta',
        'text_tab_server' => 'Gelişmiş',
        'text_tab_language' => 'Diller',
        'text_tab_currency' => 'Para birimleri',
        'text_tab_country' => 'Ülkeler',

        'text_tab_desc_general' => 'İşletme adı, e-postası, logosu ve konum ayarları',
        'text_tab_desc_site' => 'Varsayılan ülke, dil, para birimi ve saat dilimi',
        'text_tab_desc_mail' => 'E-posta gönderim ayarları',
        'text_tab_desc_status' => 'Sipariş durumlarını yönetin.',
        'text_tab_desc_server' => 'Bakım kipi gibi gelişmiş sistem ayarları.',
        'text_tab_desc_language' => 'Sitede kullanılabilecek dilleri yönetin.',
        'text_tab_desc_currency' => 'Sitede kullanılabilecek para birimlerini yönetin.',
        'text_tab_desc_country' => 'Sitede kullanılabilecek ülkeleri yönetin.',

        'text_tab_title_maps' => 'Konum',
        'text_tab_title_date_time' => 'Tarih / saat',
        'text_tab_title_currency' => 'Para birimi',
        'text_tab_title_language' => 'Dil',
        'text_tab_title_maintenance' => 'Bakım',
        'text_tab_title_system_log' => 'Günlük ayarları',
        'text_tab_title_activity_log' => 'Hareket günlüğü ayarları',
        'text_single' => 'Tek',
        'text_multiple' => 'Çoklu',
        'text_1_hour' => '1 saat',
        'text_3_hours' => '3 saat',
        'text_6_hours' => '6 saat',
        'text_12_hours' => '12 saat',
        'text_24_hours' => '24 saat',
        'text_3_days' => '3 gün',
        'text_5_days' => '5 gün',
        'text_1_week' => '1 hafta',
        'text_auto' => 'Kendiliğinden',
        'text_manual' => 'Elle',
        'text_kilometers' => 'Kilometre',
        'text_plain' => 'Düz metin',
        'text_smtp' => 'SMTP',
        'text_log_file' => 'Günlük dosyası',
        'text_mail_no_encryption' => 'Şifreleme yok',
        'text_test_email_message' => 'Bu bir test e-postasıdır. Bunu aldıysanız e-posta gönderimi çalışıyor demektir.',
        'text_to_customer' => 'Müşteriye',
        'text_to_location' => 'Şubeye',
        'text_send_test_email' => 'Test e-postası gönderildi',

        'label_site_name' => 'İşletme adı',
        'label_site_email' => 'İşletme e-postası',
        'label_site_logo' => 'İşletme logosu',
        'label_timezone' => 'Varsayılan saat dilimi',
        'label_currency_refresh_interval' => 'Kur yenileme aralığı',
        'label_detect_language' => 'Tarayıcı dilini algıla',
        'label_customer_group' => 'Müşteri grubu',
        'label_country' => 'Ülke',
        'label_maps_api_key' => 'Google Haritalar API anahtarı',
        'label_distance_unit' => 'Mesafe birimi',
        'label_default_geocoder' => 'Varsayılan konum çözücü',
        'label_mail_logo' => 'Logo',
        'label_sender_name' => 'Gönderen adı',
        'label_sender_email' => 'Gönderen e-postası',
        'label_protocol' => 'E-posta protokolü',
        'label_smtp_host' => 'SMTP sunucusu',
        'label_smtp_port' => 'SMTP bağlantı noktası',
        'label_smtp_user' => 'SMTP kullanıcı adı',
        'label_smtp_pass' => 'SMTP parolası',
        'label_smtp_encryption' => 'Şifreleme protokolü',
        'label_test_email' => 'Test e-postası',
        'label_permalink' => 'Kalıcı bağlantı',
        'label_enable_request_log' => 'Hatalı istekleri günlüğe yaz',
        'label_maintenance_mode' => 'Bakım kipi',
        'label_maintenance_message' => 'Bakım mesajı',
        'label_activity_log_timeout' => 'Şu süreden eski hareket kayıtlarını temizle',

        'alert_email_sending' => 'E-posta gönderiliyor…',
        'alert_email_sent' => 'E-posta %s adresine gönderildi',
        'alert_settings_errors' => 'Eksik zorunlu ayarları düzeltmek için tıklayın.',

        'help_timezone' => 'Varsayılan saat dilimi. İşletmenizle aynı saat diliminde bir şehir seçin.',
        'help_detect_language' => 'Tarayıcı dili algılansın mı? Açıksa site tarayıcının diline çevrilir.',
        'help_default_location' => 'Ana şubeniz olarak kullanılacak şubeyi seçin ya da yenisini ekleyin.',
        'help_media_max_size' => 'Yüklenecek dosyalar için en büyük boyut (kilobayt).',
        'help_media_extensions' => 'İzin verilen dosya uzantıları. Birden fazlası virgülle ayrılır.',
        'help_media_upload' => 'Dosya yüklemeyi aç ya da kapat',
        'help_media_new_folder' => 'Klasör oluşturmayı aç ya da kapat',
        'help_media_copy' => 'Dosya/klasör kopyalamayı aç ya da kapat',
        'help_media_move' => 'Dosya/klasör taşımayı aç ya da kapat',
        'help_media_rename' => 'Dosya/klasör yeniden adlandırmayı aç ya da kapat',
        'help_media_delete' => 'Dosya/klasör silmeyi aç ya da kapat',
        'help_mail_logo' => 'E-postalarda görünecek logoyu yükleyin',
        'help_enable_request_log' => '404 gibi hatalı tarayıcı istekleri günlüğe yazılsın mı.',
        'help_maintenance' => 'Açıkken müşteriler siteyi göremez. Giriş yapmış yöneticiler dışındaki herkese bakım mesajı gösterilir.',
        'help_activity_log_timeout' => 'Belirtilen gün sayısından eski tüm hareket kayıtlarını sil',
    ],

    'system_logs' => [
        'text_title' => 'Günlükler',

        'button_empty' => '<i class="fa fa-eraser"></i>&nbsp;&nbsp;Günlükleri boşalt',
        'button_request_logs' => '<i class="fa fa-globe"></i>&nbsp;&nbsp;İstek günlükleri',
    ],

    'themes' => [
        'text_title' => 'Temalar',
        'text_form_name' => 'Tema',
        'text_empty' => 'Tema yok.',
        'text_is_default' => 'Etkin',
        'text_set_default' => 'Etkinleştir',
        'text_author' => 'geliştirici',
        'text_version' => 'Sürüm',
        'text_files' => 'dosyalar',
        'text_files_data' => 'dosyalar ve veriler',

        'label_code' => 'Kod',
        'label_is_active' => 'Etkin',
        'label_title' => 'Başlık',
        'label_delete_data' => 'Verileri de sil',

        'button_delete' => 'Sil',
        'button_yes_delete' => 'Evet, sil',
        'button_return_to_list' => 'Hayır, listeye dön',
    ],

    'updates' => [
        'text_title' => 'Güncellemeler',
        'text_tab_title_extensions' => 'Eklentiler',
        'text_tab_title_themes' => 'Temalar',
        'text_tab_title_languages' => 'Diller',
        'text_ignore' => 'Yok say',
        'text_last_checked' => 'Son kontrol',
        'text_checking_updates' => 'Güncellemeler denetleniyor…',

        'text_no_updates' => 'Güncelleme yok.',

        'alert_no_carte_key' => 'Carte anahtarı girilmemiş.',

        'notify_new_update_found_title' => 'Güncelleme var.',
        'notify_new_update_found' => 'Bir güncelleme mevcut.',
        'notify_no_update_found_title' => 'Güncelleme yok.',
        'notify_no_update_found' => 'Uygulamanız güncel.',
    ],
];
