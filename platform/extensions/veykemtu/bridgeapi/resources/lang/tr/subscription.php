<?php

declare(strict_types=1);

return [
    // ── Yetki ve menü ──────────────────────────────────────────────────
    // ── Oluşturma ve takvim (B-16) ─────────────────────────────────────
    'button_create' => 'Yeni abonelik',
    'text_create_title' => 'Yeni abonelik',
    'section_setup' => 'Sözleşme',
    'section_setup_comment' => 'Bu bölüm aboneliğin kim için, hangi günlerde ve hangi saatte üretileceğini belirler. KAYDEDİLDİKTEN SONRA DEĞİŞTİRİLEMEZ — çalışan bir kuralın takvimini değiştirmek, o güne ait üretilmiş siparişlerle kuralın ayrışması demek. Gün atlamak için istisna, ara vermek için duraklatma kullanılır.',
    'help_customer' => 'Yalnızca kurumsal müşteriler listelenir; abonelik bir sözleşmedir ve sipariş kapısı kurumsal hesaplarda açıktır.',
    'label_delivery_type' => 'Teslim şekli',
    'delivery' => 'Adrese gönderim',
    'pickup' => 'Gel-al',
    'help_end_date' => 'Boş bırakılırsa abonelik süresizdir ve iptal edilene kadar üretmeye devam eder.',
    'help_service_days' => 'Sipariş üretilecek günler. Gece çalışan üretim işi yalnızca bu günlerde sipariş açar.',
    'label_time_from' => 'Teslim saati (başlangıç)',
    'help_time_from' => 'SS:DD biçiminde, örneğin 12:00. Boş bırakılırsa 12:00 kabul edilir.',
    'label_time_to' => 'Teslim saati (bitiş)',
    'section_lines' => 'Porsiyon içeriği',
    'section_lines_comment' => 'Bir porsiyonun neyden oluştuğunu yazın. Adetler PORSİYON BAŞINADIR: 1 çorba + 1 ana yemek yazıp günlük 100 porsiyon derseniz mutfağa 100 çorba ve 100 ana yemek düşer. Fiyat satırlardan değil, aşağıdaki anlaşmalı porsiyon fiyatından hesaplanır.',
    'prompt_line' => 'Ürün ekle',
    'empty_lines' => 'Henüz ürün eklenmedi.',
    'label_line_menu' => 'Ürün',
    'label_line_quantity' => 'Porsiyon başına adet',
    'label_line_label' => 'Etiket (fişte görünür)',

    'section_calendar' => 'Takvim ve üretim',
    'section_calendar_comment' => 'Önümüzdeki 30 gün, gece üretim işinin kullandığı kuralların aynısıyla hesaplanır — burada gördüğünüz gün ve porsiyon sayısı, gerçekten üretilecek olandır.',
    'calendar_upcoming' => 'Önümüzdeki servis günleri',
    'calendar_none' => 'Önümüzdeki 30 günde servis günü yok. Abonelik pasif, süresi dolmuş ya da duraklatılmış olabilir.',
    'calendar_day' => 'Gün',
    'calendar_portions' => 'Porsiyon',
    'calendar_state' => 'Durum',
    'calendar_closed' => 'Kapalı gün — üretilmez',
    'calendar_override' => 'Adet istisnası',
    'calendar_normal' => 'Normal',
    'calendar_generated' => 'Son üretilen siparişler',
    'calendar_no_runs' => 'Bu abonelik için henüz sipariş üretilmedi.',
    'calendar_no_order' => 'Üretilmedi',

    'permission' => 'Abonelikler',
    'side_menu' => 'Abonelikler',
    'closed_side_menu' => 'Kapalı günler',

    // ── Abonelik listesi/formu ─────────────────────────────────────────
    'text_title' => 'Abonelikler',
    'text_empty' => 'Henüz abonelik yok.',
    'text_filter_search' => 'Müşteri e-postası ara',
    'text_form_name' => 'Abonelik',
    'text_edit_title' => 'Abonelik: fiyatlandır ve yönet',
    'confirm_delete' => 'Bu aboneliği silmek istediğinize emin misiniz?',

    'column_customer' => 'Müşteri',
    'column_status' => 'Durum',
    'column_start' => 'Başlangıç',
    'column_end' => 'Bitiş',
    'column_quantity' => 'Günlük adet',
    'column_price' => 'Anlaşmalı fiyat',
    'column_payment' => 'Ödeme',

    'status_pending' => 'Talep (fiyat bekliyor)',
    'status_active' => 'Aktif',
    'status_paused' => 'Duraklatıldı',
    'status_cancelled' => 'İptal',

    'section_pricing' => 'Fiyat ve durum',
    'section_pricing_comment' => 'Anlaşmalı porsiyon fiyatını girin ve aboneliği aktifleştirin.',
    'help_status' => 'Talebi onaylamak için fiyatı girip "Aktif" yapın.',
    'payment_account' => 'Cari hesap (ay sonu)',
    'payment_prepaid' => 'Peşin (aylık)',
    'label_agreed_price' => 'Porsiyon başı anlaşmalı fiyat (₺)',
    'help_agreed_price' => 'Örn. 150 veya 150,00. Boş bırakılırsa fiyatsız kalır.',
    'label_quantity' => 'Günlük porsiyon adedi',
    'section_details' => 'Müşteri talebi (salt okunur)',
    'section_details_comment' => 'Takvim ve ürünler müşteri tarafından belirlendi.',
    'no_price' => '—',

    // ── Gün adları (ISO) ───────────────────────────────────────────────
    'day_1' => 'Pzt',
    'day_2' => 'Sal',
    'day_3' => 'Çar',
    'day_4' => 'Per',
    'day_5' => 'Cum',
    'day_6' => 'Cmt',
    'day_7' => 'Paz',

    // ── Form künyesi ───────────────────────────────────────────────────
    'detail_period' => 'Dönem',
    'detail_open_ended' => 'süresiz',
    'detail_days' => 'Günler',
    'detail_delivery' => 'Teslimat',
    'detail_lines' => 'Ürünler',
    'detail_no_lines' => 'Ürün satırı yok.',

    // ── Kapalı günler ──────────────────────────────────────────────────
    'closed_title' => 'Kapalı günler',
    'closed_empty' => 'Kapalı gün tanımlı değil.',
    'closed_form_name' => 'Kapalı gün',
    'closed_create_title' => 'Kapalı gün ekle',
    'closed_edit_title' => 'Kapalı günü düzenle',
    'closed_date' => 'Tarih',
    'closed_date_help' => 'Üretim bu gün atlanır (resmî tatil vb.).',
    'closed_description' => 'Açıklama',

    // ── Gösterge paneli ────────────────────────────────────────────────
    'dashboard_label' => 'Kurumsal özet',
    'dashboard_active' => 'Aktif abonelik',
    'dashboard_portions' => 'Yarın porsiyon',
    'dashboard_closed' => 'Kapalı gün',
    'dashboard_balance' => 'Açık cari',
];
