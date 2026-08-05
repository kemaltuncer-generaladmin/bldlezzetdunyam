<?php

declare(strict_types=1);

/**
 * Arayüz metinleri — `docs/04-platform.md` §7: kodda sabit Türkçe metin yasak.
 *
 * Metinlerin tonu bilinçli olarak açıklayıcıdır: bu sayfadaki iki anahtar
 * (yoğunluk / sipariş alımı) birbirine karıştırıldığında sonucu ciro kaybıdır,
 * bu yüzden fark her ikisinin de altında yazılıdır.
 */
return [
    'settings' => [
        'label' => 'BLD Ayarları',
        'description' => 'Sipariş alım şalteri, kesim saati, asgari sepet, teslimat ücreti, ödeme yöntemleri ve mutfak yoğunluğu.',
    ],

    'side_menu' => [
        'settings' => 'BLD Ayarları',
    ],

    'permission_settings' => 'BLD sipariş ayarlarını görüntüleme ve değiştirme',

    'alert_no_location' => 'Etkin bir vitrin bulunamadı. Ayarlar → Konumlar altından vitrini etkinleştirin.',

    'section_ordering' => 'Sipariş alımı',
    'section_ordering_comment' => 'Bu bölümdeki ayarlar siparişin alınıp alınmayacağını belirler. Sipariş almayı durduran tek anahtar aşağıdaki "Sipariş alımı"dır; mutfak yoğunluğu siparişi engellemez.',

    'section_busy' => 'Mutfak yoğunluğu',
    'section_busy_comment' => 'Yoğunluk sipariş almayı DURDURMAZ. Yalnızca müşteriye "hazırlanması uzun sürebilir" uyarısı gösterir. Mutfak ekranındaki tuş da bu anahtarı değiştirir.',

    'label_ordering_enabled' => 'Sipariş alımı',
    'help_ordering_enabled' => 'Kapatıldığında hiçbir kanaldan (web, mobil) sipariş alınmaz. Çalışma saatlerinden bağımsızdır ve kendiliğinden geri açılmaz.',

    'label_order_cutoff' => 'Günlük son sipariş saati',
    'help_order_cutoff' => 'SS:DD biçiminde, örneğin 16:00. Boş bırakılırsa kesim saati uygulanmaz. Yalnızca aynı güne verilen siparişleri etkiler; ertesi gün için sipariş her zaman alınabilir.',

    'label_min_order_total' => 'Asgari sepet tutarı (TL)',
    'help_min_order_total' => 'Bu tutarın altındaki sepetler reddedilir. 0 yazarsanız alt sınır yoktur. Kuruş için nokta veya virgül kullanın: 250.00',

    'label_delivery_fee' => 'Teslimat ücreti (TL)',
    'help_delivery_fee' => 'Adrese gönderimde sepete eklenir. Gel-al siparişlerde uygulanmaz.',

    'label_payment_methods' => 'Açık ödeme yöntemleri',
    'help_payment_methods' => 'En az bir yöntem seçili olmalıdır. Çalışan bir ödeme geçidi yoksa "Online ödeme"yi işaretlemeyin: müşteri tıklar ve hiçbir şey olmaz.',
    'text_payment_online' => 'Online ödeme',
    'text_payment_cash' => 'Kapıda nakit',
    'text_payment_account' => 'Cari hesaba yazdır',

    'label_busy' => 'Mutfak yoğun',
    'help_busy' => 'Açıkken müşteriye gecikme uyarısı gösterilir, sipariş alınmaya devam eder.',

    'label_busy_message' => 'Yoğunluk uyarı metni',
    'help_busy_message' => 'Müşteri uygulamalarında ve sitede gösterilir. Boş bırakırsanız varsayılan metin kullanılır.',

    'permission_devices' => 'Mutfak kasalarını yönetme (ayar, komut, eşleme)',

    /**
     * Mutfak kasaları ekranı.
     *
     * Metinlerin uzunluğu bilinçlidir. Bu ekranda yöneticinin yapabileceği
     * iki pahalı hata var: (1) boş bir alanı "kapalı" sanmak, (2) komutun
     * anında gideceğini sanıp düğmeye iki kez basmak. Her ikisinin de
     * panzehiri, kısa bir etiket değil, ne olduğunu söyleyen bir cümledir.
     */
    'kds' => [
        'label' => 'Mutfak kasaları',
        'text_title' => 'Mutfak kasaları',
        'text_form_name' => 'Mutfak kasası',
        'text_create_title' => 'Yeni mutfak kasası',
        // ":name" YAZILMAZ: çekirdek bu yer tutucuyu kaydın adıyla değil,
        // form adıyla ("Mutfak kasası") doldurur ve başlık kendini tekrar
        // ederdi. Kasanın adı sayfa içinde, formun ilk alanında duruyor.
        'text_edit_title' => 'Mutfak kasasını düzenle',
        'text_empty' => 'Kayıtlı mutfak kasası yok. "Yeni kasa" ile ekleyin; kaydettiğinizde çıkan eşleme kodunu mutfak ekranına girin.',
        'text_filter_search' => 'Kasa adına göre ara',
        'button_new' => 'Yeni kasa',

        'column_name' => 'Kasa',
        'column_connection' => 'Bağlantı',
        'column_printer' => 'Yazıcı',
        'column_queue' => 'Fiş kuyruğu',
        'column_health' => 'Son sağlık bildirimi',

        // ── Durum rozetleri ────────────────────────────────────────────
        'state_online' => 'Çevrimiçi',
        'state_offline' => 'Çevrimdışı',
        'state_never' => 'Hiç bağlanmadı',
        'state_revoked' => 'İptal edildi',

        'printer_ok' => 'Hazır',
        'printer_fault' => 'ARIZALI',
        'printer_unknown' => 'Bilinmiyor',
        'printer_unknown_hint' => 'Kasa henüz yazıcı durumu bildirmedi. Bu bir arıza değildir.',

        'sync_untouched' => 'Panelden ayar yapılmadı',
        'sync_unverified' => 'Kasa hiç bildirim göndermedi',
        'sync_applied' => 'Kasaya ulaştı',
        'sync_pending' => 'Kasa henüz almadı',

        'command_queued' => 'Gönderildi, sırada',
        'command_delivered' => 'Kasaya ulaştı, sonuç bekleniyor',
        'command_retrying' => 'Sonuç gelmedi, yeniden gönderilecek',
        'command_succeeded' => 'Çalıştı',
        'command_failed' => 'Çalıştırılamadı',

        'command_test_receipt' => 'Test fişi bas',
        'command_reprint' => 'Fişi yeniden bas',
        'command_clear_failed' => 'Başarısız kuyruğu temizle',
        'command_silence_alarm' => 'Alarmı sustur',
        'command_restart' => 'Uygulamayı yeniden başlat',
        'confirm_restart' => 'Mutfak ekranı kapanıp yeniden açılacak. Hazırlanmakta olan siparişler sunucuda durur, ekran birkaç saniye içinde geri gelir. Devam edilsin mi?',

        // ── Form ───────────────────────────────────────────────────────
        'label_name' => 'Kasa adı',
        'help_name' => 'Mutfakta bu makineyi ayırt eden ad, örneğin "Ana mutfak kasası". Yalnızca panelde görünür.',

        'section_new' => 'Eşleme',
        'section_new_comment' => 'Kaydettiğinizde tek kullanımlık bir eşleme kodu üretilir ve bu sayfada gösterilir. Kodu mutfak ekranındaki eşleme alanına girin.',

        'section_settings' => 'Kasa ayarları',
        'section_settings_comment' => 'BOŞ BIRAKILAN ALAN "KAPALI" DEMEK DEĞİLDİR. Boş bıraktığınız her alanda kasa kendi varsayılanını kullanmaya devam eder; yalnızca doldurduğunuz alanlar sunucudan dayatılır. Bir ayarı kasanın kendi varsayılanına geri döndürmek için alanı boşaltıp kaydedin.',

        'label_poll_seconds' => 'Sipariş yoklama aralığı (saniye)',
        'help_poll_seconds' => 'Kasa yeni siparişleri kaç saniyede bir sorar. 2 ile 60 arası.',

        'label_health_seconds' => 'Sağlık bildirimi aralığı (saniye)',
        'help_health_seconds' => 'Kasa kendi durumunu kaç saniyede bir bildirir. AYNI ZAMANDA KOMUTLARIN VARIŞ SÜRESİDİR: aşağıdaki komutlar bu bildirimin yanıtıyla taşınır. 10 ile 300 arası.',

        'section_alarm' => 'Ses ve alarm',
        'section_alarm_comment' => 'Bağlantı kesildi uyarısı her hâlükârda susturulamaz; buradaki susturma izni yalnızca yeni sipariş alarmı içindir.',

        'label_sound_enabled' => 'Sesli uyarılar',
        'help_sound_enabled' => 'Kapatıldığında mutfak yeni siparişi yalnızca ekrandan görür.',

        'label_alarm_silenceable' => 'Yeni sipariş alarmı susturulabilsin mi',
        'help_alarm_silenceable' => 'Susturulamaz seçilirse alarmı durdurmanın tek yolu siparişi onaylamaktır.',
        'text_silenceable' => 'Susturulabilir',
        'text_not_silenceable' => 'Susturulamaz (yalnızca sipariş onaylanınca susar)',

        'label_connection_alarm_seconds' => 'Bağlantı uyarısı tekrar aralığı (saniye)',
        'help_connection_alarm_seconds' => 'Sunucuya ulaşılamadığında uyarının kaç saniyede bir tekrarlanacağı. 10 ile 600 arası.',

        'section_thresholds' => 'Gecikme eşikleri',
        'section_thresholds_comment' => 'Sipariş kartı önce sarıya, sonra kırmızıya döner. Geciken eşiği uyarı eşiğinden küçük olamaz; küçük yazarsanız uyarı eşiğine yükseltilir.',

        'label_warning_after_minutes' => 'Uyarı eşiği (dakika)',
        'help_warning_after_minutes' => 'Bu süreyi aşan sipariş kartı sarıya döner. 1 ile 480 arası.',

        'label_late_after_minutes' => 'Geciken eşiği (dakika)',
        'help_late_after_minutes' => 'Bu süreyi aşan sipariş kartı kırmızıya döner. Uyarı eşiğinden küçük olamaz.',

        'section_printer' => 'Yazıcı',
        'section_printer_comment' => 'Bu iki değer o makinenin donanım gerçeğidir; iki kasada aynı olmak zorunda değildir.',

        'label_printer_device_path' => 'Yazıcı aygıt yolu',
        'help_printer_device_path' => 'Ubuntu üzerindeki aygıt dosyası, örneğin /dev/usb/lp0. Yanlış yol fiş basımını tamamen durdurur; değiştirdikten sonra test fişi basın.',

        'label_printer_code_page' => 'ESC/POS kod sayfası',
        'help_printer_code_page' => 'Türkçe harfler için sahada doğrulanan değer 29\'dur. Yanlış değer bütün Türkçe harfleri boşluk bastırır. 0 ile 255 arası.',

        'text_device_default' => 'Kasa varsayılanı',
        'text_untouched' => 'Dokunma — kasa kendi varsayılanını kullansın',
        'text_on' => 'Açık',
        'text_off' => 'Kapalı',

        // ── Sağlık paneli ──────────────────────────────────────────────
        'panel_health' => 'Kasanın bildirdiği durum',
        'panel_health_comment' => 'Bu bölümdeki değerleri kasa bildirir; panelden değiştirilemez. Sunucu yazıcının gerçekten çalıştığını doğrulayamaz, yalnızca kasanın beyanını zaman damgasıyla saklar.',
        'text_last_seen' => 'Son görülme',
        'text_last_health' => 'Son sağlık bildirimi',
        'text_app_version' => 'Uygulama sürümü',
        'text_queue_pending' => 'Bekleyen fiş',
        'text_queue_failed' => 'Başarısız fiş',
        'text_settings_sync' => 'Ayarların durumu',
        'text_settings_changed_at' => 'Ayarlar en son değişti',
        'text_never' => 'Hiç',
        'text_unknown' => 'Bilinmiyor',

        // ── Eşleme paneli ──────────────────────────────────────────────
        'panel_pairing' => 'Eşleme',
        'panel_pairing_comment' => 'Kod tek kullanımlıktır. Kasa eşleştiği anda kod düşer ve bir daha görünmez.',
        'text_pairing_code' => 'Eşleme kodu',
        'text_pairing_minutes_left' => ':minutes dakika sonra geçersiz olacak.',
        'text_pairing_none' => 'Bekleyen eşleme kodu yok.',
        'text_pairing_paired' => 'Kasa eşlenmiş durumda. Yeni kod üretmek yalnızca kasayı baştan eşlemeniz gerektiğinde gerekir.',
        'button_pairing_code' => 'Eşleme kodu üret',
        'button_revoke' => 'Cihazı iptal et',
        'confirm_revoke' => 'Bu kasa iptal edilecek: bir daha eşleşemez ve mutfak ekranı eşleme ekranına döner. Emin misiniz?',
        'text_revoked_banner' => 'Bu kasa :when iptal edildi. Ayarları ve komutları artık kullanılamaz; yerine yeni bir kasa ekleyin.',

        // ── Komut paneli ───────────────────────────────────────────────
        'panel_commands' => 'Komut gönder',
        'panel_commands_comment' => 'Komutlar ANINDA GİTMEZ. Kasanın bir sonraki sağlık bildiriminin yanıtına binerler; bu kasada bu en fazla :seconds saniye sürer. Düğmeye ikinci kez basmadan önce aşağıdaki listede sonucu bekleyin.',
        'label_command' => 'Komut',
        'label_order_id' => 'Sipariş numarası',
        'label_receipt_type' => 'Fiş tipi',
        'help_reprint' => '"Fişi yeniden bas" için sipariş numarası ve fiş tipi zorunludur.',
        'receipt_type_mutfak' => 'Mutfak fişi',
        'receipt_type_musteri' => 'Müşteri fişi',
        'panel_command_log' => 'Gönderilen komutlar',
        'text_no_commands' => 'Bu kasaya henüz komut gönderilmedi.',
        'column_command_sent' => 'Gönderildi',
        'column_command_state' => 'Durum',
        'column_command_result' => 'Kasanın yanıtı',
        'text_command_no_result' => '—',

        // ── Bildirimler ────────────────────────────────────────────────
        'alert_created' => 'Kasa eklendi ve eşleme kodu üretildi. Kodu aşağıdan okuyup mutfak ekranına girin.',
        'alert_code_created' => 'Yeni eşleme kodu üretildi, %d dakika geçerli.',
        'alert_revoked' => 'Kasa iptal edildi. Mutfak ekranı bir sonraki istekte eşleme ekranına dönecek.',
        'alert_revoked_device' => 'Bu kasa iptal edilmiş. İptal edilmiş bir kasaya komut gönderilemez ve kod üretilemez; yerine yeni bir kasa ekleyin.',
        'alert_command_queued' => '"%s" komutu kuyruğa alındı. Kasa en geç %d saniye içinde, bir sonraki sağlık bildiriminde alacak.',
        'alert_late_raised' => 'Geciken eşiği uyarı eşiğinden küçük olamaz; %d dakikaya yükseltildi.',
    ],

    'side_menu_devices' => 'Mutfak kasaları',

    'dashboard' => [
        'label' => 'BLD işletme durumu',
        'text_title' => 'BLD işletme durumu',
        'text_ordering_on' => 'Sipariş alımı açık',
        'text_ordering_off' => 'Sipariş alımı KAPALI',
        'text_busy_on' => 'Mutfak yoğun (sipariş alınmaya devam ediyor)',
        'text_busy_off' => 'Mutfak normal',
        'text_cutoff' => 'Son sipariş saati',
        'text_no_cutoff' => 'Kesim saati yok',
        'text_orders_today' => 'Bugünkü sipariş',
        'text_revenue_today' => 'Bugünkü ciro',
        'text_pending' => 'İşlem bekleyen sipariş',
        'text_unprinted' => 'Fişi basılmamış sipariş',
        'text_devices_online' => 'Çevrimiçi mutfak kasası',
        'text_devices_total' => 'kayıtlı',
        'text_no_location' => 'Etkin vitrin yok — ayarlar okunamıyor.',
        'text_open_settings' => 'BLD Ayarları',
    ],
];
