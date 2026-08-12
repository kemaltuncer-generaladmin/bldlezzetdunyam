<?php

declare(strict_types=1);

// Telefon siparişi giriş ekranı (B-13) metinleri.
//
// Uyarı metinleri kasten sonuç odaklı: bu ekran sipariş YARATIYOR ve mutfağa
// anında gönderiyor. "Hata oluştu" gibi bir cümle, yöneticinin siparişin
// mutfağa düşüp düşmediğini bilmemesi demek olurdu.
return [
    'permission' => 'Telefon siparişi girme (sipariş ve müşteri oluşturur)',
    'side_menu' => 'Telefon siparişi',
    'text_title' => 'Telefonla alınan sipariş',

    // ── Müşteri ────────────────────────────────────────────────────────
    'section_customer' => 'Müşteri',
    'label_customer' => 'Kayıtlı müşteri',
    'option_new_customer' => '— Yeni müşteri oluştur —',
    'help_new_customer' => 'Müşteri sistemde yoksa aşağıdaki üç alanı doldurun; sipariş kaydedilirken kurumsal hesap da açılır. Cari hesap KAPALI açılır — veresiye vermek için Kurumsal → Cari hesaplar ekranından limit tanımlayın.',
    'label_org_name' => 'Ticari unvan',
    'label_contact' => 'Yetkili kişi',
    'label_phone' => 'Telefon',

    // ── Ürünler ────────────────────────────────────────────────────────
    'section_items' => 'Ürünler',
    'column_item' => 'Ürün',
    'column_quantity' => 'Adet',
    'column_line_note' => 'Satır notu (mutfak fişinde görünür)',
    'button_add_line' => 'Satır ekle',
    'help_items' => 'Adedi 0 olan ve ürün seçilmemiş satırlar yok sayılır — kullanmadığınız satırları silmenize gerek yok. Fiyatlar menüden okunur; elle fiyat girilmez.',

    // ── Teslimat ───────────────────────────────────────────────────────
    'section_delivery' => 'Teslimat ve ödeme',
    'label_delivery_type' => 'Teslim şekli',
    'delivery' => 'Adrese gönderim',
    'pickup' => 'Gel-al',
    'label_date' => 'Teslim tarihi',
    'label_time' => 'Teslim saati',
    'help_time' => 'Saat boş bırakılırsa sipariş "en kısa sürede" olarak düşer. İleri tarih seçebilirsiniz; sipariş o günün listesinde görünür.',
    'label_payment' => 'Ödeme yöntemi',
    'payment_cash' => 'Kapıda ödeme',
    'payment_account' => 'Cari hesaba yaz',
    'payment_online' => 'Kart (simülasyon)',
    'label_address' => 'Adres',
    'label_district' => 'İlçe',
    'label_city' => 'İl',
    'label_address_note' => 'Adres tarifi (kapı, kat, işaret)',
    'label_note' => 'Sipariş notu',

    // ── Abonelik ───────────────────────────────────────────────────────
    'section_subscription' => 'Abonelik bağı',
    'label_subscription' => 'Abonelik',
    'option_no_subscription' => '— Aboneliğe bağlı değil —',
    'portion' => 'porsiyon',
    'help_subscription' => 'Sipariş bir aboneliğe bağlanırsa mutfaktaki abonelik üretim planında görünür ve ay sonu ekstresinde o sözleşmeye yazılır. Yalnızca seçili müşterinin abonelikleri listelenir.',

    // ── Ek porsiyon ────────────────────────────────────────────────────
    'section_extra' => 'Aboneliğe ek porsiyon (gelecek gün)',
    'help_extra' => 'Bu bölüm SİPARİŞ AÇMAZ. İleri bir servis gününün porsiyon sayısını artırır; siparişi o gece otomatik üretim işi oluşturur. "Perşembe 10 kişi fazla olacak" gibi durumlar için. Bugün teslim edilecek ek porsiyonları yukarıdaki sipariş formundan girin — ikisini birden yaparsanız aynı yemek iki kez pişer.',
    'label_extra_date' => 'Servis günü',
    'label_extra_quantity' => 'Ek porsiyon',
    'button_extra' => 'Porsiyonu ekle',

    // ── Eylemler ───────────────────────────────────────────────────────
    'confirm_create' => 'Sipariş oluşturulacak ve MUTFAĞA ANINDA gönderilecek; fiş basılacak. Devam edilsin mi?',
    'button_create' => 'Siparişi oluştur ve mutfağa gönder',

    // ── Uyarılar ───────────────────────────────────────────────────────
    'alert_no_location' => 'Etkin bir vitrin bulunamadı. Ayarlar → Konumlar altından vitrini etkinleştirin.',
    'alert_no_items' => 'En az bir ürün seçip adet girin.',
    'alert_customer_missing' => 'Seçilen müşteri bulunamadı.',
    'alert_new_customer_fields' => 'Yeni müşteri için ticari unvan ve telefon zorunludur.',
    'alert_subscription_missing' => 'Seçilen abonelik bulunamadı.',
    'alert_subscription_mismatch' => 'Seçilen abonelik başka bir müşteriye ait. Aboneliği ancak sahibinin siparişine bağlayabilirsiniz.',
    'alert_created' => 'Sipariş #%s oluşturuldu ve mutfağa gönderildi.',
    'alert_confirm_failed' => 'Sipariş #%s oluşturuldu ama MUTFAĞA GÖNDERİLEMEDİ (%s). Sipariş listesinden elle onaylayın.',
    'alert_extra_quantity' => 'Ek porsiyon sayısı sıfırdan büyük olmalı.',
    'alert_extra_date' => 'Servis günü seçin.',
    'alert_extra_past' => 'Geçmiş bir gün için ek porsiyon işlenemez — o günün üretimi çoktan yapıldı.',
    'alert_extra_saved' => '%s günü için toplam porsiyon %s olarak güncellendi.',
    'exception_note' => 'Panelden eklenen ek porsiyon',
];
