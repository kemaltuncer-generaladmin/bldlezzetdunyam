<?php

declare(strict_types=1);

// Cari hesap ekranları (Cari hesaplar + Cari hareketler) metinleri.
return [
    // ── Yetki ve menü ──────────────────────────────────────────────────
    'permission' => 'Cari hesap (bakiye ve hareketler)',
    'side_menu_group' => 'Kurumsal',
    'side_menu_accounts' => 'Cari hesaplar',
    'side_menu_entries' => 'Cari hareketler',

    // ── Cari hesaplar listesi ──────────────────────────────────────────
    'accounts_title' => 'Cari hesaplar',
    'accounts_empty' => 'Kurumsal müşteri bulunmuyor.',
    'accounts_search' => 'Unvan, yetkili, e-posta veya telefon ara',
    'column_org' => 'Ticari unvan',
    'column_contact' => 'Yetkili kişi',
    'column_email' => 'E-posta',
    'column_telephone' => 'Telefon',
    'column_balance' => 'Güncel bakiye',
    'column_limit' => 'Borç limiti',
    'filter_debtors' => 'Yalnızca borcu olanlar',

    // ── Müşteri cari kartı (B-14) ──────────────────────────────────────
    //
    // "Limit" metinleri kasten uzun: alanın üç durumu var (boş / 0 / sayı) ve
    // ikisi birbirinin tam zıddı. Kısa bir etiket, yöneticinin cari hesabı
    // kapatmak isterken sınırsız açmasına yol açardı.
    'form_name' => 'Cari hesap',
    'form_edit_title' => 'Cari hesap: {name}',
    'alert_customer_missing' => 'Müşteri bulunamadı.',

    'summary_balance' => 'Güncel bakiye',
    'summary_balance_debt' => 'Müşterinin bize borcu var',
    'summary_balance_credit' => 'Müşteri fazla ödemiş (alacaklı)',
    'summary_balance_zero' => 'Hesap kapalı, borç yok',
    'summary_limit' => 'Borç limiti',
    'summary_remaining' => 'Kalan limit',
    'summary_remaining_blocked' => 'Limit doldu — cari hesapla yeni sipariş verilemez.',

    'section_limit' => 'Cari hesap limiti',
    'section_limit_comment' => 'Bu müşterinin cari hesaba (veresiye) ne kadar borçlanabileceğini belirler. Limit dolduğunda müşteri cari hesapla sipariş veremez; kapıda ödeme ve kart seçenekleri etkilenmez.',
    'label_limit' => 'Borç limiti (TL)',
    'help_limit' => 'BOŞ BIRAKIRSANIZ LİMİT YOKTUR — borç sınırsız birikir. "0" yazarsanız cari hesap KAPANIR ve müşteri "cari hesaba yaz" seçeneğini hiç görmez. Yeni açılan kurumsal hesaplar 0 ile başlar; veresiye vermek bilinçli bir karardır.',
    'limit_none' => 'Sınırsız',
    'limit_closed' => 'Cari kapalı',

    'section_payment' => 'Tahsilat girişi',
    'section_payment_comment' => 'Müşteriden alınan ödemeyi deftere alacak olarak işler ve bakiyeyi düşürür. Sipariş borcu eklemek için bu form kullanılmaz.',
    'label_payment_amount' => 'Tahsil edilen tutar (TL)',
    'label_payment_receipt' => 'Makbuz no',
    'label_payment_date' => 'Tahsilat tarihi',
    'button_payment' => 'Tahsilatı işle',
    'confirm_payment' => 'Bu tahsilat deftere işlenecek. Defter kaydı silinemez, yalnızca ters kayıtla düzeltilir. Devam edilsin mi?',
    'help_payment_receipt' => 'Makbuz no yalnızca rakamlardan oluşur ve sistemde bir kez kullanılabilir — aynı makbuzun iki kez işlenmesini engeller. Kâğıt makbuzdaki seri numarasını yazın.',
    'payment_description' => 'Tahsilat',
    'alert_payment_amount' => 'Tahsilat tutarı sıfırdan büyük olmalı.',
    'alert_payment_receipt' => 'Makbuz no zorunludur ve yalnızca rakam içermelidir.',
    'alert_payment_duplicate' => '%s numaralı makbuz zaten işlenmiş. Aynı makbuz ikinci kez kaydedilemez.',
    'alert_payment_saved' => 'Tahsilat deftere işlendi.',

    'section_statement' => 'Hesap ekstresi',
    'section_statement_comment' => 'Son 90 günün hareketleri. Daha eski dönemler ay-sonu özetlerinde tutulur.',
    'statement_opening' => 'Devir',
    'statement_closing' => 'Kapanış bakiyesi',
    'statement_empty' => 'Bu dönemde hareket yok.',
    'column_debit' => 'Borç',
    'column_credit' => 'Alacak',
    'column_running' => 'Bakiye',

    // ── Cari hareketler listesi ────────────────────────────────────────
    'entries_title' => 'Cari hareketler',
    'entries_empty' => 'Henüz cari hareket yok.',
    'entries_search' => 'Açıklama veya e-posta ara',
    'filter_type' => 'Hareket tipi',
    'filter_date' => 'Tarih aralığı',
    'column_date' => 'Tarih',
    'column_customer' => 'Müşteri',
    'column_type' => 'Tip',
    'column_amount' => 'Tutar',
    'column_source' => 'Kaynak',
    'column_description' => 'Açıklama',

    // ── Hareket tipleri ────────────────────────────────────────────────
    'type_debit' => 'Borç',
    'type_credit' => 'Alacak',
];
