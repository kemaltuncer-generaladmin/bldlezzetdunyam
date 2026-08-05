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
