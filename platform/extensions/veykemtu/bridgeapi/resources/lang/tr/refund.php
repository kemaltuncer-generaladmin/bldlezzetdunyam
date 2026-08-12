<?php

declare(strict_types=1);

// İade takibi ekranı (B-15) metinleri.
return [
    'side_menu' => 'İadeler',
    'text_title' => 'Ödeme iadeleri',
    'text_empty' => 'Bekleyen ya da geçmiş iade yok.',
    'text_search' => 'Sipariş numarası veya sebep ara',

    'column_order' => 'Sipariş',
    'column_created' => 'Açıldı',
    'column_amount' => 'Tutar',
    'column_gateway' => 'Kanal',
    'column_status' => 'Durum',
    'column_reason' => 'Sebep',
    'column_action' => 'İşlem',
    'filter_date' => 'Tarih aralığı',
    'revision' => 'Revizyon',

    'status_manual' => 'Elle iade bekliyor',
    'status_pending' => 'Sağlayıcıda',
    'status_failed' => 'Başarısız',
    'status_succeeded' => 'Tamamlandı',

    'button_settle' => 'İade edildi',
    'confirm_settle' => '%s ₺ tutarındaki iade, S-%s numaralı sipariş için ELDEN/HAVALEYLE gönderildi olarak işaretlenecek. Parayı gerçekten gönderdiğinizden emin misiniz?',
    'alert_settled' => 'S-%s siparişinin iadesi tamamlandı olarak işaretlendi.',
    'alert_missing' => 'İade kaydı bulunamadı.',
    'alert_already_settled' => 'Bu iade zaten kapanmış. İkinci kez işaretlenemez.',
];
