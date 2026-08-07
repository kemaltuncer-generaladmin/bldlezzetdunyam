<?php

declare(strict_types=1);

return [
    // ── Yetki ve menü ──────────────────────────────────────────────────
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
