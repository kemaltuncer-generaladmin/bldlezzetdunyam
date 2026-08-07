<?php

declare(strict_types=1);

/**
 * "Teklif Talepleri" ekranının Türkçe metinleri.
 *
 * `default.php`'den AYRI, `sitecontent.php` ile aynı gerekçe: bu ekran
 * kendi başına değişiyor ve metinleri ortak dosyaya koymak her görevde
 * gereksiz birleştirme çakışması üretiyordu.
 *
 * Yetki ve yan menü etiketleri de burada: `AdminRegistrar` bu iki anahtarı
 * buradan okuyor. Ekranın kendisiyle birlikte taşınmaları, ekran bir gün
 * kaldırılırsa geride yetim çeviri anahtarı bırakmamalarını sağlıyor.
 */

return [
    'side_menu' => 'Teklif Talepleri',
    'permission' => 'Teklif taleplerini görüntüle ve yönet (kişisel veri içerir)',

    'text_title' => 'Teklif talepleri',
    'text_form_name' => 'Teklif talebi',
    'text_edit_title' => 'Teklif talebi',
    'text_empty' => 'Henüz teklif talebi gelmedi. Talepler sitedeki "Teklif Al" formundan otomatik düşer; buraya elle kayıt eklenmez.',
    'text_filter_search' => 'Ad, firma, telefon, e-posta veya hizmete göre ara',
    'text_filter_status' => 'Duruma göre',
    'text_filter_date' => 'Geliş tarihine göre',
    'confirm_delete' => 'Bu talep KALICI olarak silinecek; kişinin adı, telefonu ve e-postası dâhil hiçbir kaydı kalmayacak. Talebi kapatmak istiyorsanız silmek yerine durumunu "Kapandı" yapın. Silinsin mi?',

    'column_created_at' => 'Geldi',
    'column_status' => 'Durum',
    'column_full_name' => 'Ad soyad',
    'column_organization' => 'Firma / kurum',
    'column_telephone' => 'Telefon',
    'column_email' => 'E-posta',
    'column_service_type' => 'Hizmet',
    'column_headcount' => 'Kişi',

    'status_yeni' => 'Yeni',
    'status_okundu' => 'Okundu',
    'status_cevaplandi' => 'Cevaplandı',
    'status_kapandi' => 'Kapandı',

    'section_follow_up' => 'Takip',
    'section_follow_up_comment' => 'Bu bölüm sizindir; ziyaretçi buradaki hiçbir şeyi görmez. Talebin altındaki bilgiler ziyaretçinin gönderdiği hâlidir ve değiştirilemez.',

    'label_status' => 'Durum',
    'help_status' => 'Talebe döndükçe ilerletin: Okundu (gördüm), Cevaplandı (teklif gönderildi), Kapandı (iş alındı veya kaybedildi). Yeni kalan talepler listenin başında toplanır; durum filtresiyle yalnızca onları görebilirsiniz.',

    'label_admin_note' => 'İç not',
    'help_admin_note' => 'Görüşmeden aklınızda kalanlar: verilen fiyat, aranacak tarih, kimin ilgilendiği. Ziyaretçiye GÖNDERİLMEZ, sitede görünmez; yalnızca panele girenler okur.',

    'section_submission' => 'Gönderilen talep',
    'section_submission_comment' => 'Aşağıdaki bilgileri ziyaretçi formda kendisi yazdı. Doldurmadığı alanlar hiç gösterilmez. Bu bölüm salt okunurdur: bir kişinin bize ilettiği beyanı sonradan düzeltmek, kaydın değerini ortadan kaldırır.',

    'label_organization' => 'Firma / kurum',
    'label_service_type' => 'Hizmet türü',
    'label_headcount' => 'Kişi sayısı',
    'label_frequency' => 'Sıklık',
    'label_start_date' => 'Tarih',
    'label_location' => 'Konum',
    'label_menu_preference' => 'Menü tercihi',
    'label_kitchen_note' => 'Mutfak altyapısı',
    'label_message' => 'Açıklama',
    'label_submitted_at' => 'Gönderim zamanı',
    'label_kvkk' => 'KVKK onayı',
];
