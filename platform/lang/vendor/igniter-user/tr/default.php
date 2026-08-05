<?php

declare(strict_types=1);

/**
 * Müşteri, personel ve oturum metinleri — `igniter.user::default.*`.
 *
 * Giriş ekranı da burada: yöneticinin panelde gördüğü İLK ekran bu ve
 * çevrilmemiş kalması "yarım Türkçe" izlenimi verir.
 *
 * "Staff member" karşılığı "Kullanıcı": TastyIgniter bunu personel diye
 * adlandırıyor ama bizde bu kayıtlar mutfak personeli değil, PANELE GİREN
 * kişiler. Mutfak personelinin sistemde hesabı yok, KDS'i kullanıyorlar.
 */
return [
    'text_title' => 'Hesabım',

    'text_heading' => 'Hesap',
    'text_account' => 'Hesabım',
    'text_edit_details' => 'Bilgilerimi düzenle',
    'text_address' => 'Adres defteri',
    'text_orders' => 'Son siparişler',
    'text_change_password' => 'Parola değiştir',
    'text_edit' => 'DÜZENLE',
    'text_set_default' => 'VARSAYILAN YAP',
    'text_default_address' => 'Varsayılan adresim',
    'text_no_default_address' => 'Varsayılan adresiniz yok',
    'text_no_orders' => 'Gösterilecek sipariş yok.',
    'text_charts_customers' => 'Müşteriler',
    'text_total_customer' => 'Toplam müşteri',

    'text_mail_admin_password_reset' => 'Yöneticiye parola sıfırlama e-postası',
    'text_mail_admin_password_reset_request' => 'Yöneticiye parola sıfırlama isteği e-postası',
    'text_mail_password_reset' => 'Müşteriye parola sıfırlama e-postası',
    'text_mail_password_reset_request' => 'Müşteriye parola sıfırlama isteği e-postası',
    'text_mail_registration' => 'Müşteriye kayıt e-postası',
    'text_mail_registration_alert' => 'Yöneticiye kayıt bildirimi e-postası',
    'text_mail_activation' => 'Müşteriye hesap etkinleştirme e-postası',
    'text_mail_invite_customer' => 'Müşteriye sipariş daveti e-postası',

    'text_permission_group' => 'Kullanıcı',
    'text_permission_customer_groups' => 'Müşteri gruplarını yönet',
    'text_permission_customers' => 'Müşteri oluştur ve yönet',
    'text_permission_user_groups' => 'Kullanıcı gruplarını yönet',
    'text_permission_staffs' => 'Kullanıcı oluştur ve yönet',
    'text_permission_delete_staffs' => 'Kullanıcı silme yetkisi',
    'text_permission_delete_customers' => 'Müşteri silme yetkisi',

    'text_side_menu_user' => 'Kullanıcılar',
    'text_side_menu_customer' => 'Müşteriler',
    'text_side_menu_customer_group' => 'Gruplar',
    'text_side_menu_user_group' => 'Gruplar',
    'text_side_menu_user_role' => 'Roller',

    'text_logout' => 'Çıkış',
    'text_leave' => 'Ayrıl',
    'text_super_admin' => 'Tam yetkili hesap',

    'label_heading' => 'Başlık:',
    'label_template' => 'E-posta şablonu',
    'label_send_to' => 'Gönderilecek',
    'label_send_to_staff_group' => 'Gönderilecek kullanıcı grubu',
    'label_send_to_custom' => 'Gönderilecek e-posta adresi',
    'label_allow_registration' => 'Müşteri kaydına izin ver',
    'label_registration_email' => 'Kayıt e-postası gönder',

    'column_date' => 'Tarih / saat',
    'column_subject' => 'Konu',

    'alert_logout_success' => 'Çıkış yapıldı.',

    'text_send_to_location' => 'Şube e-posta adresi (varsa)',
    'text_send_to_staff_email' => 'Kullanıcı e-posta adresi (varsa)',
    'text_send_to_customer_email' => 'Müşteri e-posta adresi (varsa)',
    'text_send_to_custom' => 'Belirli bir e-posta adresi',
    'text_send_to_staff_group' => 'Kullanıcı grubu',
    'text_send_to_customer_group' => 'Müşteri grubu',
    'text_send_to_all_staff' => 'Tüm kullanıcılar',
    'text_send_to_all_customer' => 'Tüm müşteriler',
    'text_tab_user' => 'Müşteri kaydı',

    'help_allow_registration' => 'Kapalıysa müşteri hesapları yalnızca yöneticiler tarafından oluşturulabilir.',
    'help_registration_email' => 'Hesap oluşturulduktan sonra müşteriye ve/veya yöneticiye onay e-postası gönder',

    'login' => [
        'text_title' => 'Giriş',
        'text_password_reset_title' => 'Parolayı sıfırla',
        'text_forgot_password' => 'Parolanızı mı unuttunuz?',
        'text_reset_password_title' => 'Parolanızı sıfırlayın',
        'text_back_to_login' => 'Girişe dön',

        'button_login' => 'Giriş yap',
        'button_reset_password' => 'Parolayı sıfırla',

        'label_reset_code' => 'Sıfırlama kodu',
        'label_email' => 'E-posta adresi',
        'label_password' => 'Parola',
        'label_password_confirm' => 'Parolayı doğrula',
        'label_remember' => 'Beni hatırla',
        'label_activation' => 'Etkinleştirme kodu',

        'alert_login_failed' => 'Giriş başarısız. Tekrar deneyin ya da sistem yöneticisiyle görüşün.',
        'alert_success_reset' => 'Parolanız değiştirildi.',
        'alert_failed_reset' => 'Sıfırlama kodu geçersiz ya da süresi dolmuş.',
        'alert_success_logout' => 'Çıkış yaptınız.',
        'alert_email_sent' => 'Parola sıfırlama bağlantısını e-postanıza gönderdik.',
        'alert_email_not_sent' => 'E-posta gönderilemedi.',

        'alert_logout_success' => 'Çıkış yapıldı.',
        'alert_expired_login' => 'Oturum süresi doldu, tekrar giriş yapın',
        'alert_invalid_login' => 'E-posta ya da parola hatalı.',
        'alert_account_created' => 'Hesap oluşturuldu, aşağıdan giriş yapabilirsiniz.',
        'alert_account_activation' => 'E-posta adresinize etkinleştirme bağlantısı gönderildi.',
        'alert_registration_disabled' => 'Kayıt şu anda kapalı.',

        'error_email_exist' => 'Bu e-posta adresiyle bir hesap var, giriş yapın',

        'notify_registered_account_title' => 'Yeni müşteri kaydı',
        'notify_registered_account' => '<b>%s</b> hesap oluşturdu.',
    ],

    'account' => [
        'text_heading' => 'Adres defteri',
        'text_edit_heading' => 'Adres defterini düzenle',
        'text_no_address' => 'Kayıtlı adresiniz yok',
        'text_edit' => 'DÜZENLE',
        'text_delete' => 'SİL',

        'button_back' => 'Geri',
        'button_add' => 'Yeni adres ekle',
        'button_update' => 'Adresi güncelle',

        'label_address_1' => 'Adres 1',
        'label_address_2' => 'Adres 2',
        'label_city' => 'İlçe',
        'label_state' => 'İl',
        'label_postcode' => 'Posta kodu',
        'label_country' => 'Ülke',

        'alert_updated_success' => 'Adres kaydedildi.',
        'alert_deleted_success' => 'Adres silindi.',
    ],

    'reset' => [
        'text_heading' => 'Parola sıfırlama',
        'text_summary' => 'Hesabınıza giriş yaptığınız e-posta adresini girin; size yeni bir parola göndereceğiz.',

        'label_email' => 'E-posta adresi',
        'label_password' => 'Parola',
        'label_password_confirm' => 'Parolayı doğrula',
        'label_code' => 'Sıfırlama kodu',

        'button_login' => 'Giriş yap',
        'button_reset' => 'Parolayı sıfırla',

        'alert_reset_success' => 'Parola sıfırlandı.',
        'alert_reset_request_success' => 'Parola sıfırlama isteği alındı; nasıl devam edeceğinizi e-postanızda bulacaksınız.',
        'alert_reset_error' => 'Parola sıfırlanamadı; e-posta bulunamadı ya da bilgiler hatalı.',
        'alert_reset_failed' => 'Parola sıfırlanamadı; kod geçersiz ya da süresi dolmuş.',
        'alert_activation_failed' => 'Hesap etkinleştirilemedi, tekrar deneyin.',
        'alert_no_email_match' => 'Eşleşen e-posta adresi yok',
    ],

    'settings' => [
        'text_heading' => 'Bilgilerim',
        'text_details' => 'Bilgilerinizi düzenleyin',
        'text_password_heading' => 'Parola değiştir',

        'button_back' => 'Geri',
        'button_delete' => 'Hesabı sil',
        'button_save' => 'Bilgileri kaydet',

        'label_first_name' => 'Ad',
        'label_last_name' => 'Soyad',
        'label_email' => 'E-posta adresi',
        'label_password' => 'Yeni parola',
        'label_password_confirm' => 'Yeni parolayı doğrula',
        'label_old_password' => 'Eski parola',
        'label_telephone' => 'Telefon',

        'error_password' => 'Girdiğiniz %s eşleşmiyor.',

        'alert_updated_success' => 'Bilgiler güncellendi.',
        'alert_deleted_success' => 'Hesap silindi.',
        'alert_delete_confirm' => 'Hesabınızı silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
    ],

    'user_groups' => [
        'text_title' => 'Kullanıcı grupları',
        'text_form_name' => 'Kullanıcı grubu',
        'text_empty' => 'Tanımlı kullanıcı grubu yok.',
        'text_round_robin' => 'Sırayla',
        'text_load_balanced' => 'Yük dengeli',

        'label_auto_assign' => 'Siparişleri kendiliğinden ata',
        'label_assignment_mode' => 'Atama kipi',
        'label_assignment_availability' => 'Atama uygunluğu',
        'label_load_balanced_limit' => 'Yük dengeleme sınırı',

        'column_users' => 'Kullanıcı sayısı',

        'alert_no_available_assignee' => 'Uygun atanacak kişi yok.',

        'help_auto_assign' => 'Bu gruptaki kullanıcılara atanan sipariş sayısını dağıtın ve sınırlayın.',
        'help_round_robin' => 'Siparişleri çevrimiçi kullanıcılara sırayla atar.',
        'help_load_balanced' => 'Bir kullanıcının aynı anda yürütebileceği sipariş sayısını sınırlar.',
        'help_load_balanced_limit' => 'Kullanıcı başına en fazla sipariş sayısı.',
        'help_assignment_availability' => 'Kullanıcı, kendiliğinden sipariş atamasına açık olup olmadığını kendi belirleyebilsin',
    ],

    'user_roles' => [
        'text_title' => 'Kullanıcı rolleri',
        'text_form_name' => 'Kullanıcı rolü',
        'text_tab_permission' => 'Yetkiler',
        'text_empty' => 'Tanımlı kullanıcı rolü yok.',

        'label_permissions' => 'Yetkiler',
    ],

    'staff' => [
        'text_title' => 'Kullanıcılar',
        'text_form_name' => 'Kullanıcı',
        'text_filter_search' => 'Şube, ad ya da e-postaya göre arayın.',
        'text_filter_role' => 'Tüm roller',
        'text_filter_group' => 'Tüm gruplar',
        'text_empty' => 'Tanımlı kullanıcı yok.',
        'text_roles_scope_groups' => 'Kapsam, roller ve gruplar',
        'text_sale_permission_global_access' => 'Tam erişim',
        'text_sale_permission_groups' => 'Gruplar',
        'text_sale_permission_restricted' => 'Kısıtlı erişim',

        'column_group' => 'Kullanıcı grupları',
        'column_role' => 'Kullanıcı rolleri',
        'column_location' => 'Şubeler',
        'column_last_login' => 'Son giriş',

        'label_full_name' => 'Ad soyad',
        'label_telephone' => 'Telefon',
        'label_super_staff' => 'Tam yetkili',
        'label_username' => 'Kullanıcı adı',
        'label_send_invite' => 'Davet e-postası gönder',
        'label_password' => 'Parola',
        'label_confirm_password' => 'Parolayı doğrula',
        'label_role' => 'Rol',
        'label_group' => 'Gruplar',
        'label_language' => 'Dil',
        'label_location' => 'Şubeler',

        'help_send_invite' => 'Hesabına parola belirlemesi için bağlantı içeren bir davet gönderir.',
        'help_super_staff' => 'Bu kullanıcıya sistemin tamamına sınırsız erişim verir. Tam yetkili kullanıcı başka kullanıcıları da ekleyip yönetebilir.',
        'help_role' => 'Roller kullanıcı yetkilerini belirler.',
        'help_groups' => 'Kullanıcının hangi gruplara ait olacağını seçin. Gruplama, sipariş atamasını kolaylaştırır.',

        'alert_login_restricted' => 'Bir <b>kullanıcı hesabına erişme</b> yetkiniz yok. Sistem yöneticisiyle görüşün.',
    ],

    'staff_status' => [
        'text_set_status' => 'Durum belirle',
        'text_online' => 'Çevrimiçi',
        'text_back_soon' => 'Birazdan dönerim',
        'text_away' => 'Uzakta',
        'text_lunch_break' => 'Öğle molasındayım…',
        'text_custom_status' => 'Kendi durum notunuzu yazın',
        'text_clear_tomorrow' => 'Yarın kaldır',
        'text_clear_hours' => '4 saat sonra kaldır',
        'text_clear_minutes' => '30 dakika sonra kaldır',
        'text_dont_clear' => 'Kaldırma',
    ],

    'customer_groups' => [
        'text_title' => 'Müşteri grupları',
        'text_form_name' => 'Müşteri grubu',
        'text_empty' => 'Tanımlı müşteri grubu yok.',

        'column_customers' => 'Müşteri sayısı',

        'label_approval' => 'Onay gerektirir',

        'alert_set_default' => 'Müşteri grubu varsayılan yapıldı',

        'help_approval' => 'Yeni müşterilerin giriş yapabilmesi için onay gereksin mi? Müşteriye hesabını doğrulaması için bağlantı içeren bir e-posta gönderilir.',
    ],

    'customers' => [
        'text_title' => 'Müşteriler',
        'text_form_name' => 'Müşteri',
        'text_tab_general' => 'Müşteri',
        'text_tab_address' => 'Adresler',
        'text_filter_search' => 'Ad ya da e-postaya göre arayın.',
        'text_empty' => 'Kayıtlı müşteri yok.',
        'text_title_edit_address' => 'Adres',

        'column_full_name' => 'Ad soyad',
        'column_telephone' => 'Telefon',
        'column_date_added' => 'Kayıt tarihi',

        'button_activate' => 'Etkinleştir',

        'label_first_name' => 'Ad',
        'label_last_name' => 'Soyad',
        'label_password' => 'Parola',
        'label_confirm_password' => 'Parolayı doğrula',
        'label_telephone' => 'Telefon',
        'label_send_invite' => 'Davet e-postası gönder',
        'label_customer_group' => 'Müşteri grubu',
        'label_address_1' => 'Adres 1',
        'label_address_2' => 'Adres 2',
        'label_city' => 'İlçe',
        'label_state' => 'İl',
        'label_postcode' => 'Posta kodu',
        'label_country' => 'Ülke',

        'help_send_invite' => 'Hesabına parola belirlemesi için bağlantı içeren bir davet gönderir.',
        'help_password' => 'Parolayı değiştirmeyecekseniz boş bırakın',

        'alert_login_restricted' => 'Bir <b>müşteri hesabına erişme</b> yetkiniz yok. Sistem yöneticisiyle görüşün.',
        'alert_activation_success' => 'Müşteri etkinleştirildi.',
        'alert_customer_not_active' => "'%s' kullanıcısı etkinleştirilmeden giriş yapamaz.",
    ],

    'notifications' => [
        'text_title' => 'Bildirimler',
        'text_filter_search' => 'Bildirimlerde ara…',
        'text_empty' => 'Bildirim yok.',

        'button_mark_as_read' => 'Tümünü okundu işaretle',
    ],
];
