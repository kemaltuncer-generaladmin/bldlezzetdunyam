<?php

declare(strict_types=1);

// Aylık menü takvimi ekranı (B-19) metinleri.
//
// Bu ekran şirketin O GÜN NE SATACAĞINA ve HANGİ FİYATA satacağına karar
// veriyor. Metinler bu yüzden "kaydedildi" demekle yetinmiyor: kopyalamanın
// kaç günü atladığını, hangi günün neden kilitli olduğunu ve taslağın neden
// taslak kaldığını açıkça söylüyor. Sessizce istenenden azını yapan bir
// ekran, reddeden bir ekrandan kötüdür.
return [
    'permission' => 'Aylık menü takvimi (ne satılacağına ve fiyatına karar verir)',
    'side_menu' => 'Günün menüsü',
    'text_title' => 'Aylık menü takvimi',
    'text_intro' => 'Satış artık günün menüsü üzerinden yapılıyor: bir güne menü girilmemişse o gün hiçbir şey satılmaz. Gün kutusuna tıklayarak menüyü kurun, sonra yayına alın.',

    // ── Kapılar ────────────────────────────────────────────────────────
    'alert_no_location' => 'Etkin bir vitrin bulunamadı. Menü takvimi bir vitrine bağlıdır; önce Restoran → Konumlar altından vitrini etkinleştirin.',
    'alert_regime_off' => 'Günün menüsü rejimi bu vitrinde KAPALI. Buraya girdiğiniz menüler müşteriye görünmez. Restoran → BLD Ayarları ekranından açabilirsiniz.',
    'alert_no_package_product' => '"Günün Menüsü" paket ürünü bu vitrinde tanımlı değil; paket fiyatı girseniz bile menü bütün olarak satılamaz. Sunucuda `php artisan veykemtu:setup` çalıştırılmalı.',

    // ── Ay gezinme ─────────────────────────────────────────────────────
    'nav_prev' => 'Önceki ay',
    'nav_next' => 'Sonraki ay',
    'nav_today' => 'Bu ay',

    'weekday_1' => 'Pazartesi',
    'weekday_2' => 'Salı',
    'weekday_3' => 'Çarşamba',
    'weekday_4' => 'Perşembe',
    'weekday_5' => 'Cuma',
    'weekday_6' => 'Cumartesi',
    'weekday_7' => 'Pazar',

    'month_1' => 'Ocak',
    'month_2' => 'Şubat',
    'month_3' => 'Mart',
    'month_4' => 'Nisan',
    'month_5' => 'Mayıs',
    'month_6' => 'Haziran',
    'month_7' => 'Temmuz',
    'month_8' => 'Ağustos',
    'month_9' => 'Eylül',
    'month_10' => 'Ekim',
    'month_11' => 'Kasım',
    'month_12' => 'Aralık',

    // ── Izgara hücresi ─────────────────────────────────────────────────
    'badge_draft' => 'Taslak',
    'badge_published' => 'Yayında',
    'badge_closed' => 'Kapalı gün',
    'badge_locked' => 'Siparişli — kilitli',
    'cell_empty' => 'Menü yok',
    'cell_items' => '%d kalem',
    'cell_package' => 'Paket %s',
    'cell_no_package' => 'Paket satılmıyor',
    'cell_orders' => '%d sipariş',
    'cell_select' => 'Bu günü kopyalama hedefi olarak seç',
    'cell_open' => 'Menüyü düzenle',

    // ── Gün düzenleyici ────────────────────────────────────────────────
    'editor_title' => 'Gün menüsü',
    'editor_close' => 'Kapat',
    'editor_locked_notice' => 'BU GÜNÜN SİPARİŞİ VAR (%d adet). Paket fiyatı, kalemler ve yayın durumu donduruldu; yalnızca başlık, açıklama ve iç not düzenlenebilir. Sipariş varken fiyat değiştirilseydi, yalnızca notu düzelten bir revizyon siparişi sessizce yeniden fiyatlandırır ve cari deftere uydurma bir iade ya da ek ücret yazardı.',
    'editor_closed_notice' => 'Bu gün kapalı olarak işaretli (%s). Menü girebilirsiniz ama o gün sipariş alınmaz — kapalı gün her zaman kazanır.',
    'editor_new_notice' => 'Bu güne henüz menü girilmemiş. Kaydettiğinizde TASLAK olarak açılır; müşteriye görünmesi için ayrıca yayına almanız gerekir.',

    'label_title' => 'Menü başlığı',
    'help_title' => 'Müşteriye görünür. Boş bırakılırsa sipariş satırında "Günün Menüsü (gg.aa.yyyy)" yazar.',
    'label_description' => 'Açıklama',
    'help_description' => 'Müşteriye görünür. Menünün bir cümlelik tanıtımı.',
    'label_internal_note' => 'İç not',
    'help_internal_note' => 'YALNIZ PANELDE görünür, müşteriye gitmez. Tedarik, porsiyon ya da mutfak notu.',
    'label_package_price' => 'Paket fiyatı (₺)',
    'help_package_price' => 'Menünün bütün olarak fiyatı; kalemlerin toplamından ucuz olabilir. BOŞ BIRAKILIRSA o gün paket satılmaz, yalnız kalemler tek tek alınır. Sıfır kabul edilmez — "bedava" ile "paket yok" aynı şey değil.',
    'label_components_sellable' => 'Kalemler tek tek de satılabilsin',
    'help_components_sellable' => 'Kapatılırsa o gün yalnızca paket satılır; müşteri tek bir yemeği ayrı alamaz.',

    'section_items' => 'Menü kalemleri',
    'help_items' => 'Sıra müşteriye ve mutfağa aynen yansır: çorba → ana yemek → pilav → tatlı. Ürün seçilmemiş satırlar yok sayılır.',
    'column_item' => 'Ürün',
    'column_quantity' => 'Adet',
    'column_price_override' => 'Gün fiyatı (₺)',
    'column_label' => 'Gün etiketi',
    'column_required' => 'Zorunlu',
    'column_sellable_alone' => 'Tek satılır',
    'column_actions' => 'Sıra',
    'option_pick_product' => '— Ürün seçin —',
    'help_price_override' => 'Boşsa ürünün kendi fiyatı kullanılır.',
    'help_label' => 'Boşsa ürünün adı kullanılır.',
    'help_required' => 'Zorunlu bir kalem tükendiğinde paket de satıştan düşer.',
    'help_sellable_alone' => 'Ekmek, ayran gibi kalemler yalnız pakette olabilir.',
    'button_add_item' => 'Kalem ekle',
    'button_remove_item' => 'Kalemi çıkar',
    'button_move_up' => 'Yukarı taşı',
    'button_move_down' => 'Aşağı taşı',
    'empty_items' => 'Bu güne henüz kalem eklenmedi.',

    'button_save' => 'Kaydet',
    'button_publish' => 'Yayına al',
    'button_unpublish' => 'Taslağa çek',
    'confirm_unpublish' => 'Gün taslağa çekilecek ve müşteriye görünmeyecek. Devam edilsin mi?',

    // ── Kopyalama ──────────────────────────────────────────────────────
    'section_copy' => 'Kopyalama',
    'help_copy' => 'KOPYA HER ZAMAN TASLAK OLARAK DÜŞER — bir ayı kazara yayına almak, taslak ayrımının var olma sebebi olan sızıntının ta kendisidir. Kapalı günler ve siparişi olan günler her zaman atlanır ve atlananlar tek tek raporlanır.',
    'label_copy_week_start' => 'Kopyalanacak haftanın herhangi bir günü',
    'help_copy_week' => 'Seçilen günün ait olduğu Pazartesi–Pazar haftası, bir sonraki haftaya kopyalanır.',
    'button_copy_week' => 'Bu haftayı gelecek haftaya kopyala',
    'label_source_day' => 'Kaynak gün',
    'button_copy_selected' => 'Bu günü seçili günlere uygula',
    'help_copy_selected' => 'Hedef günleri takvimdeki kutucuklardan işaretleyin.',
    'label_copy_overwrite' => 'Hedefte menü varsa üzerine yaz',
    'help_copy_overwrite' => 'İşaretlenmezse menüsü olan hedef günler atlanır. İşaretlense bile kapalı günler ve siparişi olan günler atlanır.',

    'section_bulk' => 'Ayı toplu işle',
    'help_bulk' => 'Yalnızca ekranda görünen ayın menüleri etkilenir. Siparişi olan günlerin durumu değişmez.',
    'button_bulk_publish' => 'Ayı toplu yayına al',
    'button_bulk_draft' => 'Ayı toplu taslağa çek',
    'confirm_bulk_publish' => 'Bu ayın bütün menüleri yayına alınacak ve müşteriye görünecek. Devam edilsin mi?',
    'confirm_bulk_draft' => 'Bu ayın bütün menüleri taslağa çekilecek ve satıştan kalkacak. Devam edilsin mi?',

    // ── Sonuç bildirimleri ─────────────────────────────────────────────
    'alert_package_no_product' => 'Paket fiyatı kaydedildi ama menü sitede PAKET OLARAK GÖRÜNMEYECEK: vitrinin "Günün Menüsü" ürünü tanımlı değil. Sunucuda \'php artisan veykemtu:setup\' komutunu çalıştırın; komut tekrar çalıştırılabilir ve mevcut veriyi bozmaz.',
    'alert_package_no_components' => 'Paket fiyatı kaydedildi ama menü sitede PAKET OLARAK GÖRÜNMEYECEK: güne zorunlu kalem girilmemiş, paketin içi boş olurdu. En az bir kalemin "zorunlu" kutusunu işaretleyin.',
    'alert_saved' => '%s günü kaydedildi.',
    'alert_saved_locked' => '%s günü kaydedildi (yalnız başlık, açıklama ve iç not — gün siparişli olduğu için kilitli).',
    'alert_published' => '%s günü yayına alındı.',
    'alert_unpublished' => '%s günü taslağa çekildi.',
    'alert_bulk_done' => '%d gün %s.',
    'alert_bulk_none' => 'Durumu değişen gün olmadı.',
    'text_status_published' => 'yayına alındı',
    'text_status_draft' => 'taslağa çekildi',

    'alert_copy_done' => '%d gün kopyalandı (taslak olarak).',
    'alert_copy_skipped' => '%d gün kopyalandı (taslak olarak), %d gün atlandı: %s',
    'alert_copy_none' => 'Kopyalanacak gün bulunamadı: kaynak günlerin hiçbirinde menü yok.',
    'skip_closed' => '%s kapalı gün',
    'skip_orders' => '%s siparişi var',
    'skip_exists' => '%s menüsü var',
    'skip_unsellable' => '%s satılabilir bir şey yok',

    // ── Hata bildirimleri ──────────────────────────────────────────────
    'alert_date_invalid' => 'Gün YYYY-AA-GG biçiminde ve geçerli bir tarih olmalı.',
    'alert_day_missing' => 'Bu güne ait bir menü yok. Önce menüyü kaydedin.',
    'alert_locked' => '%s gününün siparişi var: paket fiyatı, kalemler ve yayın durumu değiştirilemez. Başlık, açıklama ve iç not düzenlenebilir.',
    'alert_locked_status' => '%s gününün siparişi var; yayın durumu değiştirilemez. Siparişler o günün menüsüne ve fiyatına bağlı.',
    'alert_package_zero' => 'Paket fiyatı sıfır olamaz. O gün paket satılmayacaksa alanı boş bırakın.',
    'alert_publish_empty' => '%s gününde hiç kalem yok; boş bir menü yayına alınamaz.',
    'alert_publish_unsellable' => '%s gününde ne paket fiyatı var ne de kalemler tek tek satılıyor — yayına alınsa hiçbir şey satılamazdı.',
    'alert_duplicate_item' => 'Aynı ürün iki kez eklenmiş: %s. Adet sütununu kullanın.',
    'alert_package_item' => '"Günün Menüsü" paket ürünü bir menü kalemi olamaz; paketin kendisi zaten bu gündür.',
    'alert_no_targets' => 'Hedef gün seçilmedi. Takvimdeki kutucuklardan en az bir gün işaretleyin.',
    'alert_source_missing' => 'Kaynak günde (%s) menü yok; kopyalanacak bir şey bulunamadı.',
];
