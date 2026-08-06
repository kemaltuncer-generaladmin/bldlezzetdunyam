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
        'description' => 'Sipariş alım şalteri, kesim saati, asgari sepet, teslimat ücreti, ödeme yöntemleri, mutfak yoğunluğu ve teslim süresi tahmini.',
    ],

    'side_menu' => [
        'settings' => 'BLD Ayarları',
        'content' => 'İçerikler',
        'services' => 'Hizmetler',
        'posts' => 'Bilgi Merkezi',
    ],

    'permission_settings' => 'BLD sipariş ayarlarını görüntüleme ve değiştirme',

    'alert_no_location' => 'Etkin bir vitrin bulunamadı. Ayarlar → Konumlar altından vitrini etkinleştirin.',

    'section_ordering' => 'Sipariş alımı',
    'section_ordering_comment' => 'Bu bölümdeki ayarlar siparişin alınıp alınmayacağını belirler. Sipariş almayı durduran tek anahtar aşağıdaki "Sipariş alımı"dır; mutfak yoğunluğu siparişi engellemez.',

    'section_busy' => 'Mutfak yoğunluğu',
    'section_busy_comment' => 'Yoğunluk sipariş almayı DURDURMAZ. Yalnızca müşteriye "hazırlanması uzun sürebilir" uyarısı gösterir. Mutfak ekranındaki tuş da bu anahtarı değiştirir.',

    'section_eta' => 'Teslim süresi tahmini',
    'section_eta_comment' => 'Müşteriye "yaklaşık 60-85 dakika" gibi bir ARALIK gösterilir; tek bir saat sözü verilmez. Buradaki değerler yalnızca BAŞLANGIÇ NOKTASIDIR: son 14 günde en az 8 tamamlanmış sipariş biriktiğinde sistem bu alanları kullanmayı bırakır ve gerçekleşen süreleri ölçerek tahmin üretir. Elle girilen süre iyimser olmaya meyillidir ve kimse onu güncellemeyi hatırlamaz; ölçüm mutfağın bugünkü hızını kendiliğinden takip eder.',

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

    'label_prep_minutes' => 'Hazırlık süresi (dakika)',
    'help_prep_minutes' => 'Siparişin mutfakta hazır hâle gelmesi için öngörülen süre. Hem adrese gönderimde hem gel-alda sayılır. 1-480 arası tam sayı.',

    'label_delivery_minutes' => 'Teslimat süresi (dakika)',
    'help_delivery_minutes' => 'Hazır siparişin adrese ulaşması için öngörülen yol süresi. Gel-al siparişlerde UYGULANMAZ — müşteri gelip aldığı için yol süresi yoktur. 1-480 arası tam sayı.',

    'label_busy_extra_minutes' => 'Yoğunluk ek süresi (dakika)',
    'help_busy_extra_minutes' => 'Yukarıdaki "Mutfak yoğun" anahtarı açıkken tahmine eklenir; aralığın hem alt hem üst ucu bu kadar uzar. Süreyi de uzatmazsak müşteri yoğun saatte gerçekçi olmayan bir teslim saati görür. 1-480 arası tam sayı.',

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

    'permission_content' => 'Kurumsal site içeriğini yönetme (hizmetler, bilgi merkezi yazıları)',

    /**
     * Hizmetler ekranı.
     *
     * Bu ekranda yöneticinin yapabileceği geri alınması en zor hata ADRESİ
     * (`slug`) DEĞİŞTİRMEKTİR: paylaşılmış her bağlantı, arama motorundaki
     * her kayıt kırılır. Alanın altındaki uyarı bu yüzden kısa bir etiket
     * değil, sonucu söyleyen bir cümledir.
     */
    'services' => [
        'text_title' => 'Hizmetler',
        'text_form_name' => 'Hizmet',
        'text_create_title' => 'Yeni hizmet',
        'text_edit_title' => 'Hizmeti düzenle',
        'text_empty' => 'Kayıtlı hizmet yok. "Yeni hizmet" ile ekleyin; yayınladığınız hizmetler sitedeki Hizmetler sayfasında listelenir.',
        'text_filter_search' => 'Başlık veya adrese göre ara',
        'button_new' => 'Yeni hizmet',
        'confirm_delete' => 'Bu hizmet silinecek ve sitedeki adresi çalışmaz hâle gelecek. Hizmeti geçici olarak kaldırmak istiyorsanız silmek yerine "Sitede yayında" anahtarını kapatın. Silinsin mi?',

        'column_title' => 'Hizmet',
        'column_slug' => 'Adres',
        'column_sort_order' => 'Sıra',
        'column_published' => 'Yayında',
        'column_updated' => 'Güncellenme',

        'label_title' => 'Hizmet adı',
        'help_title' => 'Sitede kartın ve detay sayfasının başlığı olarak görünür.',

        'label_slug' => 'Adres (slug)',
        'help_slug' => 'Sitedeki bağlantının son parçası: /hizmetler/BURASI. YENİ KAYITTA BAŞLIKTAN OTOMATİK ÜRETİLİR. Yayındaki bir hizmetin adresini değiştirmeyin: daha önce paylaşılan bağlantılar ve arama motoru kayıtları kırılır, ziyaretçi "sayfa bulunamadı" görür. Yalnızca küçük harf, rakam ve tire kullanın.',

        'label_icon' => 'Kart ikonu',
        'help_icon' => 'Hizmet kartının üzerinde görünen simge. Listede olmayan bir simge kullanılamaz; sitede kırık kutu görünmemesi için seçenekler sınırlıdır.',

        'label_sort_order' => 'Sıra',
        'help_sort_order' => 'Küçük sayı üstte görünür. Aynı sayıyı taşıyan hizmetler kendi aralarında eklenme sırasına göre dizilir. Boş bırakırsanız 0 kabul edilir.',

        'label_published' => 'Sitede yayında',
        'help_published' => 'Kapalıyken hizmet sitede hiç görünmez; kayıt burada durur, silinmez. Metni bitirmeden kaydetmek için bu anahtarı kapalı tutun.',

        'section_card' => 'Kart ve giriş metni',
        'section_card_comment' => 'Özet hizmetler sayfasındaki kartta, giriş ise detay sayfasının en üstünde görünür. İkisi aynı cümle olmamalı: kartta okuyan kişi "bu bana uygun mu" sorusuna, detayda "nasıl işliyor" sorusuna cevap arıyor.',

        'label_summary' => 'Kart özeti',
        'help_summary' => 'Kartta görünen tek cümle. En fazla 400 karakter, ama bir-iki satırda kalması kartların aynı boyda görünmesini sağlar.',

        'label_intro' => 'Giriş paragrafı',
        'help_intro' => 'Detay sayfasının açılış metni. Hizmetin ne olduğunu ve kime hitap ettiğini anlatan bir-iki paragraf.',

        'section_detail' => 'Detay sayfası bölümleri',
        'section_detail_comment' => 'Aşağıdaki her bölüm detay sayfasında ayrı bir başlık olarak çizilir. Boş bıraktığınız bölüm sayfada HİÇ GÖRÜNMEZ — boş başlık çizilmez, o yüzden yalnızca gerçekten dolduracağınız bölümleri doldurun.',

        'label_audience' => 'Kimler için uygun?',
        'help_audience' => 'Her satıra bir madde yazın. Ziyaretçi burada kendini tanıyabilmeli; "herkes için" gibi maddeler hiçbir şey söylemez.',
        'label_audience_item' => 'Madde',
        'prompt_audience' => 'Madde ekle',

        'label_how_it_works' => 'Hizmet nasıl işler?',
        'help_how_it_works' => 'Sıralı adımlar; sayfada yukarıdan aşağı numaralandırılır. Adımları müşterinin göreceği sırayla yazın: ilk temastan servis sonrasına kadar.',
        'label_step_title' => 'Adım başlığı',
        'label_step_body' => 'Adım açıklaması',
        'prompt_how_it_works' => 'Adım ekle',

        'label_benefits' => 'Müşteriye ne kazandırır?',
        'help_benefits' => 'Her satıra bir kazanım. Doğrulanamayan rakam yazmayın ("%30 tasarruf" gibi); yazılamayan söz sonradan tartışma çıkarır.',
        'label_benefit_item' => 'Kazanım',
        'prompt_benefits' => 'Kazanım ekle',

        'label_menu_planning' => 'Menü nasıl planlanır?',
        'help_menu_planning' => 'Bu hizmette menünün neye göre kurgulandığını anlatan paragraf. Boş bırakılamaz: teklif isteyen kurumun en sık sorduğu soru budur.',

        'label_quote_needs' => 'Teklif almak için ne gerekir?',
        'help_quote_needs' => 'Teklif hazırlamak için müşteriden istenen bilgiler. Her satıra bir madde. Eksik yazılırsa teklif süreci iki-üç yazışma uzar.',
        'label_quote_item' => 'Gereken bilgi',
        'prompt_quote_needs' => 'Bilgi ekle',

        'empty_list' => 'Bu bölüm boş — sitede hiç görünmeyecek.',

        'section_body' => 'Serbest anlatım (isteğe bağlı)',
        'section_body_comment' => 'Yukarıdaki bölümler sayfanın düzenini kuruyor. Bu alan onların dışında kalan bir anlatım gerektiğinde kullanılır ve BOŞ BIRAKILABİLİR. Yapıştırdığınız biçimlendirmenin bir kısmı kaydedilirken temizlenir: tasarım dışına çıkan yazı tipleri, renkler ve tablolar sayfayı bozduğu için kabul edilmez.',

        'label_body_html' => 'Ek metin',
        'help_body_html' => 'Başlık, paragraf, kalın/italik, madde listesi ve bağlantı kullanılabilir. Görsel gömülemez.',

        // ── İkon seçenekleri. Simgenin adı değil NE GÖSTERDİĞİ yazılı: ──
        // panelde çalışan kişinin Lucide kataloğunu bilmesi beklenemez.
        'icon_building' => 'Bina — kurumsal, ofis, fabrika',
        'icon_truck' => 'Kamyon — taşıma, teslimat',
        'icon_chef_hat' => 'Aşçı şapkası — mutfak, üretim',
        'icon_graduation_cap' => 'Mezuniyet külahı — okul, eğitim',
        'icon_stethoscope' => 'Steteskop — hastane, sağlık',
        'icon_hard_hat' => 'Baret — şantiye, saha',
        'icon_calendar_heart' => 'Kalpli takvim — düğün, özel gün',
        'icon_coffee' => 'Kahve — ikram, kahvaltı, kokteyl',
        'icon_utensils_crossed' => 'Çatal bıçak — genel yemek hizmeti',
        'icon_soup' => 'Çorba — sıcak yemek, öğün',
        'icon_users' => 'İnsanlar — topluluk, personel',
        'icon_package' => 'Paket — kumanya, paketli öğün',
    ],

    /**
     * Bilgi merkezi yazıları ekranı.
     *
     * Metinlerin ağırlığı iki alanda: okuma süresinin boş bırakılabilmesi
     * (yönetici boş alanı "hata" sanıp rastgele bir sayı yazmasın) ve yayın
     * tarihinin sıralamayı belirlemesi.
     */
    'posts' => [
        'text_title' => 'Bilgi Merkezi yazıları',
        'text_form_name' => 'Yazı',
        'text_create_title' => 'Yeni yazı',
        'text_edit_title' => 'Yazıyı düzenle',
        'text_empty' => 'Kayıtlı yazı yok. "Yeni yazı" ile ekleyin; yayınladığınız yazılar sitedeki Bilgi Merkezi sayfasında en yeniden eskiye doğru listelenir.',
        'text_filter_search' => 'Başlık, kategori veya adrese göre ara',
        'button_new' => 'Yeni yazı',
        'confirm_delete' => 'Bu yazı silinecek ve sitedeki adresi çalışmaz hâle gelecek. Yazıyı geçici olarak kaldırmak istiyorsanız silmek yerine "Sitede yayında" anahtarını kapatın. Silinsin mi?',

        'column_title' => 'Başlık',
        'column_category' => 'Kategori',
        'column_published_at' => 'Yayın tarihi',
        'column_published' => 'Yayında',

        'label_title' => 'Başlık',
        'help_title' => 'Yazının listede ve detay sayfasında görünen başlığı.',

        'label_slug' => 'Adres (slug)',
        'help_slug' => 'Sitedeki bağlantının son parçası: /bilgi-merkezi/BURASI. YENİ KAYITTA BAŞLIKTAN OTOMATİK ÜRETİLİR. Yayınlanmış bir yazının adresini değiştirmeyin: paylaşılan bağlantılar ve arama motoru kayıtları kırılır. Yalnızca küçük harf, rakam ve tire kullanın.',

        'label_category' => 'Kategori',
        'help_category' => 'Yazının üzerinde rozet olarak görünür, örneğin "Gıda güvenliği" veya "Menü planlama". Aynı kategoriyi birebir aynı yazın; "Gıda Güvenliği" ve "Gıda güvenliği" sitede iki ayrı rozet olur.',

        'label_published_at' => 'Yayın tarihi',
        'help_published_at' => 'Yazının sitedeki sırasını bu tarih belirler; en yeni tarih en üstte görünür. Yazının oluşturulma tarihiyle aynı olmak zorunda değildir.',

        'label_reading_minutes' => 'Okuma süresi (dakika)',
        'help_reading_minutes' => 'BOŞ BIRAKILABİLİR — boş bırakırsanız süre yazının uzunluğundan otomatik hesaplanır ve çoğu durumda doğru sonucu verir. Yalnızca hesaplanan süreyi yanlış buluyorsanız elle yazın.',
        'text_auto_minutes' => 'Otomatik hesaplanır',

        'label_published' => 'Sitede yayında',
        'help_published' => 'Kapalıyken yazı sitede hiç görünmez; kayıt burada durur, silinmez. Yarım kalan yazıyı kaydetmek için bu anahtarı kapalı tutun.',

        'section_summary' => 'Liste kartı',
        'section_summary_comment' => 'Aşağıdaki metin yazının kendisi değil, listede ve paylaşım önizlemelerinde görünen tanıtımıdır.',

        'label_description' => 'Kısa açıklama',
        'help_description' => 'Listede başlığın altında görünen bir-iki cümle. En fazla 400 karakter. Yazının ilk cümlesini kopyalamak yerine "bu yazıyı okursam ne öğrenirim" sorusuna cevap verin.',

        'section_body' => 'Yazı metni',
        'section_body_comment' => 'Yapıştırdığınız biçimlendirmenin bir kısmı kaydedilirken temizlenir: tasarım dışına çıkan yazı tipleri, renkler ve tablolar sayfayı bozduğu için kabul edilmez. Yazdığınız cümleler korunur, yalnızca biçimleri düşer.',

        'label_body_html' => 'Yazı',
        'help_body_html' => 'Başlık, paragraf, kalın/italik, madde listesi ve bağlantı kullanılabilir. Görsel gömülemez.',
    ],

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
