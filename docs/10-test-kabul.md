# 10 — Test ve Kabul Ölçütleri

Bu doküman "bitti" tanımıdır. Bir görev, buradaki ilgili ölçütleri karşılamadan tamamlanmış sayılmaz.

## 1. Uçtan uca kabul senaryoları

Her senaryo elle koşulur ve sonuç tabloya işlenir. Hepsi geçmeden canlıya alınmaz.

### S1 — Adrese gönderim siparişi (ana akış)

| # | Adım | Beklenen |
|---|---|---|
| 1 | Web'den kayıt ol, giriş yap | Hesap oluşur, token alınır |
| 2 | Menüden 2 ürün sepete ekle | Sepet tutarı doğru (kuruş hesabı) |
| 3 | Teslimat adresi + saat gir | Teslimat ücreti toplama eklendi |
| 4 | Ödeme yöntemi seç | Yalnızca `payment_methods`'taki yöntemler görünüyor (Faz 1: kapıda ödeme, cari hesap). Sipariş `yeni`, `payment.status = pending` |
| 5 | KDS ekranını izle | **3 saniye içinde** sipariş kartı görünür + sesli uyarı |
| 6 | Yazıcıyı kontrol et | Mutfak fişi otomatik basılmış, Türkçe karakterler doğru, fiyat **yok** |
| 7 | KDS'te "Onayla" | Durum `onaylandi`, müşteriye push gitti |
| 8 | KDS'te "Başla" → "Hazır" | Müşteri fişi basıldı (fiyatlı, adresli) |
| 9 | KDS'te "Yola çıktı" → "Teslim edildi" | Müşteri takip ekranı her adımı yansıttı |
| 10 | Mobil uygulamadan aynı hesapla gir | **Aynı sipariş görünüyor** (web/mobil tek kaynak) |

> Sanal POS (Kuveyt Türk) devreye girdiğinde bu senaryoya 3a adımı eklenir: "online ödeme seç → sanal POS'a yönlendirilir → ödemeyi tamamla → `payment.status = paid`".

### S2 — Gel-al siparişi

| # | Adım | Beklenen |
|---|---|---|
| 1 | Web veya mobilden `delivery_type=pickup` seçerek sipariş ver | Teslimat adresi adımı atlanır |
| 2 | Tutarı kontrol et | Teslimat ücreti **eklenmemiş**; toplam = ara toplam |
| 3 | KDS'i izle | Kart gri `GELAL` rozetli |
| 4 | "Hazır" yap | Müşteri fişi basıldı, üzerinde adres bloğu **yok**, `GEL-AL` yazıyor |
| 5 | KDS'te "Yola çıktı" dene | Buton **görünmüyor**; API'ye elle istek atılırsa `422 INVALID_TRANSITION` |
| 6 | "Teslim edildi" yap | Durum ilerledi, müşteriye push gitti |

### S3 — Sipariş alım şalteri ve kesim saati

| # | Adım | Beklenen |
|---|---|---|
| 1 | Admin panelden sipariş alımını kapat (`ordering_enabled=false`) | `GET /api/locations` yanıtında `false` |
| 2 | Web'de menü sayfasını aç | Menü **görünmeye devam ediyor** (SEO), sepete ekleme kapalı, açıklayıcı bant var |
| 3 | Sipariş göndermeyi zorla (API'ye doğrudan istek) | `422 LOCATION_CLOSED` |
| 4 | Alımı aç, `order_cutoff` saatini geçmiş bir saate ayarla | Aynı hata: `422 LOCATION_CLOSED` |
| 5 | Kesim saatini ileri al, sipariş ver | Sipariş oluşuyor |
| 6 | Üretim listesini kontrol et | Aktif siparişlerin toplamı doğru gösteriliyor |

### S4 — Dayanıklılık

| # | Adım | Beklenen |
|---|---|---|
| 1 | Yazıcıyı kapat, sipariş ver | Durum çubuğunda uyarı, kuyruk sayacı 1 |
| 2 | Yazıcıyı aç | Fiş kaldığı yerden basıldı, **tek kez** |
| 3 | Kağıdı bitir, sipariş ver, kağıt tak | Aynı davranış |
| 4 | Kasanın internetini kes | "Bağlantı yok" uyarısı, mevcut liste ekranda kalıyor |
| 5 | Bu sırada web'den sipariş ver | Sipariş kaydediliyor (backend etkilenmiyor) |
| 6 | İnterneti geri ver | Kaçırılan sipariş **30 saniye içinde** ekrana geliyor, fişi basılıyor |
| 7 | Uygulamayı zorla kapat (`kill -9`) | 5 saniyede kendiliğinden açılıyor, kuyruk korunmuş |
| 8 | Elektriği kes, geri ver | Makine açılıyor, otomatik giriş, uygulama tam ekran geliyor |

### S5 — Güvenlik

| # | Adım | Beklenen |
|---|---|---|
| 1 | KDS token'ıyla `GET /api/orders` çağır | `403 FORBIDDEN` |
| 2 | KDS token'ıyla rapor/fiyat ucuna eriş | `403 FORBIDDEN` |
| 3 | Müşteri token'ıyla `/api/kitchen/*` çağır | `403 FORBIDDEN` |
| 4 | A müşterisinin token'ıyla B'nin siparişini iste | `404 NOT_FOUND` (varlık sızdırılmaz) |
| 5 | Admin panelden cihazı iptal et | KDS bir sonraki istekte `403 DEVICE_REVOKED`, eşleme ekranına döner |
| 6 | Repoda sır taraması (`gitleaks` vb.) | Sıfır bulgu |
| 7 | `platform/vendor/` diff kontrolü | Sıfır değişiklik |
| 8 | `GET /api/kitchen/orders` yanıtını incele | `customer_phone` **VAR** (K-14), `address` ve fiyat alanları **YOK** |
| 9 | İmzasız `POST /api/partner/bbd/orders` | `401` (K-16) |
| 10 | Gövdesi değiştirilmiş imzalı BBD isteği | `401` — imza ham gövde üzerinde |
| 11 | `BBD_WEBHOOK_SECRET` boşken BBD isteği | `401` — sırsız uç kapalıdır |

> **KURAL DEĞİŞİKLİĞİ (K-14, 11.08.2026).** 8. satır eskiden "telefon
> döndürmemeli" diyordu. Sipariş düzenleme geldiğinde personel müşteriyi
> **arayıp** anlaşmak zorunda kaldı; numarayı görmek için fiş basmak saçma.
> Fiyat ve adres gizliliği aynen duruyor — kural kaldırılmadı, daraltıldı.
> Gerekçe `docs/05-mutfakapp.md` §14.

### S9 — Mutfak turu (K-09 … K-16, 12.08.2026)

| # | Adım | Beklenen |
|---|---|---|
| 1 | Ayarlar → Ses → "Sesi dene" | Hoparlörden ses çıkar; çıkmıyorsa "Ses tanılama" satırı **sebebi yazar** |
| 2 | Ses seviyesini %20'ye çek, tekrar dene | Ses gözle görülür biçimde kısılır |
| 3 | Kasadan hoparlörü sessize al, ayarlardan "Hoparlör seviyesi"ni aç | Ses geri gelir (sessiz kip de kalkar) |
| 4 | Dokunmatik kipi aç, klavye/fareyi çıkar | Kilit açma, arama, satış durdurma, sipariş düzenleme **tamamen dokunmatikle** yapılabilir |
| 5 | Bir siparişi ilerlet, 10 sn içinde "GERİ AL" | Sipariş bir adım geri döner |
| 6 | Aynı işlemi 3 dakika sonra dene | `422` — pencere doldu |
| 7 | Satış kontrolü → durdur (30 dk, sebep) | Şifre sorulur; şifresiz kapanmaz |
| 8 | Kapalıyken web ve mobilden sipariş dene | Engellenir, **sebep ve saat** gösterilir |
| 9 | Süre dolduktan sonra sipariş dene | Kendiliğinden açılmış olmalı (cron yok) |
| 10 | Bir ürünü "bugün tükendi" işaretle | Menüde soluk; siparişe eklenemez; **abonelik üretimi etkilenmez** |
| 11 | Siparişi düzenle (20 → 10), sebep seç, kaydet | 5 sn içinde web takip ekranında adet ve toplam değişir; mobilde bildirim düşer |
| 12 | Aynı siparişi ikinci kez düzenle | Cari deftere **ikinci** hareket yazılır (birincisi yutulmaz) |
| 13 | Düzenleme sonrası yazıcı | Basılmış fişler **"GÜNCEL FİŞ / REVİZE #N / ÖNCEKİ FİŞİ ATIN"** bandıyla, 20 sn sessizlikten sonra **bir kez** yeniden basılır (K-20). Ayrı kurye fişi çıkmaz |
| 14 | Admin panel | Revizyon ve iade kaydı görünür; başarısız iade **açık** durur |
| 15 | Abonelik ekranı (F8) | Ürün toplamları, teslimat saatleri ve uyarılar görünür |
| 16 | `veykemtu:abonelik-uret` KOŞMADAN yarın sekmesi | **Kırmızı "üretim koşmamış" uyarısı** çıkar |
| 17 | "Üretim planı fişi bas", iki kez | İki ayrı kâğıt çıkar (kuyruk tekilliğine takılmaz); uyarılar kâğıtta da var |
| 18 | İmzalı `curl` ile BBD siparişi gönder | BBD sesi çalar, **paketleme fişi** basar |
| 19 | Aynı `external_id` ile ikinci kez gönder | `accepted: false`, **ikinci fiş çıkmaz** |
| 20 | BBD fişi gönderirken yazıcıyı kapat | Fiş kuyrukta kalır; yazıcı açılınca basılır (ack yalnız basım başarılıysa) |
| 21 | BBD siparişi sonrası panoyu ve `orders_today` sayacını incele | **Hiçbir değişiklik yok** |
| 22 | Bir vardiya boyunca kasa loglarını izle | `429` **hiç görülmemeli** (istek bütçesi, `docs/05` §11) |

### S6 — Geçersiz durum geçişleri

| # | Adım | Beklenen |
|---|---|---|
| 1 | `yeni` → `hazir` dene | `422 INVALID_TRANSITION` |
| 2 | `teslim_edildi` → herhangi bir durum | `422 INVALID_TRANSITION` |
| 3 | `hazirlaniyor` durumundaki siparişi müşteri iptal etmeye çalış | `422 INVALID_TRANSITION` |
| 4 | `pickup` siparişte `hazir` → `yolda` dene | `422 INVALID_TRANSITION` |
| 5 | İstemciden `total` alanı göndererek sipariş oluştur | Alan yok sayıldı, tutar sunucuda hesaplandı |

### S7 — Yük

| # | Adım | Beklenen |
|---|---|---|
| 1 | 50 sipariş peş peşe oluştur (script) | Hepsi kaydedildi, kayıp yok |
| 2 | KDS'i izle | Tümü listede, gecikme < 10 sn |
| 3 | Yazdırma kuyruğu | 50 fiş sırayla basıldı, tekrar/kayıp yok |
| 4 | Üretim listesi | Toplamlar doğru |

### S8 — Abonelik (kurumsal öğle yemeği)

| # | Adım | Beklenen |
|---|---|---|
| 1 | Uygulamadan abonelik talebi (hafta içi, günlük 20) | `pending` oluşur, fiyat boş |
| 2 | Admin panelde anlaşmalı fiyat girilir, `active` yapılır | Kural aktif |
| 3 | `veykemtu:abonelik-uret --date=<yarın>` | Servis günündeyse sipariş(ler) doğar, `bld_subscription_id` dolu, fiyat **anlaşmalı fiyattan kopya** |
| 4 | Aynı komut **ikinci kez** koşulur | Yeni sipariş **yok** (idempotency: `subscription_runs` UNIQUE) |
| 5 | KDS'e bak | Sipariş normal düşer, `is_subscription = true` rozeti |
| 6 | Uygulamadan duraklat → ertesi gün üret | Sipariş üretilmez; devam ettir → tekrar üretir |

### S9 — Cari hesap (borç/tahsilat/ekstre)

| # | Adım | Beklenen |
|---|---|---|
| 1 | `payment=account` sipariş oluştur | Deftere `debit` yazılır, bakiye artar |
| 2 | Siparişi iptal et | Ters `credit` yazılır (satır silinmez), bakiye eski değerine döner |
| 3 | Admin "Tahsilat gir" ile `credit` | Bakiye düşer |
| 4 | Aynı sipariş borcunu ikinci kez yazmayı dene | Engellenir (`UNIQUE(source, reference_type, reference_id, entry_type)`) |
| 5 | Uygulamadan ekstre çek | Hareketler + yürüyen bakiye doğru; tutarlar sunucudan |
| 6 | `veykemtu:cari-donem-ozeti --dry-run` | Açılış/borç/alacak/kapanış doğru; **fatura üretilmez** |

### S10 — Web + Admin v2.0 (12.08.2026)

Otomatik karşılıkları: PHP tarafında `AdminAccountTest`, `AdminPhoneOrderTest`,
`AdminRefundTest`, `OtpLoginTest`; site tarafında `website/e2e/*.spec.ts`.

**S10.1 — api.* kökü**

| # | Adım | Beklenen |
|---|---|---|
| 1 | `curl -I https://api.benimlezzetdunyam.com.tr/` | 308, hedef ana domain |
| 2 | `/api/health`, `/admin`, `/_assets/*` | Yönlenmez, normal yanıt |
| 3 | `/vendor/igniter/fonts/FontAwesome/fa-solid-900.woff2` | 200 — ikonların şartı |
| 4 | Panelde herhangi bir ekran | İkonlar görünür, ham çeviri anahtarı yok |

**S10.2 — Telefonla giriş**

| # | Adım | Beklenen |
|---|---|---|
| 1 | Kayıtlı numarayla kod iste | 202; SMS gelir |
| 2 | Kayıtsız numarayla kod iste | **Aynı** 202 ve aynı gövde; SMS gitmez |
| 3 | Yanlış kodu beş kez gir | Kod ölür; doğru kod da kabul edilmez |
| 4 | Aynı kodu ikinci kez kullan | Reddedilir |
| 5 | 60 sn dolmadan yeni kod iste | `422`, kalan süre `retry_after`'da |
| 6 | `0555 …`, `+90 555 …`, `555 …` | Üçü de aynı hesabı açar |

**S10.3 — Cari hesap self-servisi**

| # | Adım | Beklenen |
|---|---|---|
| 1 | Borçlu müşteri `/hesabim/cari` | Bakiye + 90 günlük ekstre; pozitif = borç |
| 2 | "Borcun tamamı" ile öde | Sağlayıcıya gider, döner, bakiye sıfırlanır |
| 3 | Kısmi öde (400 / 1000) | Bakiye 600 kalır |
| 4 | Borçtan büyük tutar gir | `422`, ödeme başlamaz |
| 5 | Borcu olmayan müşteri | Ödeme formu hiç çizilmez |

**S10.4 — Abonelik self-servisi**

| # | Adım | Beklenen |
|---|---|---|
| 1 | Aktif aboneliği duraklat, devam ettir | Rozet `Duraklatıldı` ↔ `Aktif` |
| 2 | İleri bir günü atla | "Değişiklik kaydedildi"; o gün üretilmez |
| 3 | `pending` abonelik | "Fiyat bekleniyor" + talep bilgilendirmesi |
| 4 | İptal et | Onay sorulur; geri alınamaz |

**S10.5 — Panelden telefon siparişi**

| # | Adım | Beklenen |
|---|---|---|
| 1 | Kayıtlı müşteri + ürün + kaydet | Sipariş `onaylandi` doğar, **mutfak listesinde görünür** |
| 2 | Kayıtsız müşteri, unvan + telefon | Kurumsal hesap açılır, cari limiti `0` |
| 3 | Unvansız yeni müşteri | Reddedilir; ne sipariş ne müşteri oluşur |
| 4 | Cari limiti aşan sipariş | Reddedilir; sipariş hiç doğmaz |
| 5 | Başka müşterinin aboneliğine bağla | Reddedilir |
| 6 | İleri güne ek porsiyon (100 + 10) | İstisna **110** olur, 10 değil |
| 7 | Bugüne ya da geçmişe ek porsiyon | Reddedilir — o günün üretimi koştu |

**S10.6 — Header ve bilgi mimarisi**

| # | Adım | Beklenen |
|---|---|---|
| 1 | Mobilde menü aç, bağlantıya dokun | Panel kapanır |
| 2 | Bulunduğun sayfanın bağlantısına dokun | Panel yine kapanır |
| 3 | Menüdeki `tel:` düğmesine dokun | Panel kapanır |
| 4 | `/hizmetler`, `/bilgi-merkezi`, `/kayit` … | Yönlenir, 404 yok |
| 5 | `sitemap.xml` | Kaldırılan sayfaları ilan etmez |

**S10.7 — Ana sayfadan sipariş**

| # | Adım | Beklenen |
|---|---|---|
| 1 | Girişsiz ana sayfa | "Giriş yapın" + kurumsal kayıt |
| 2 | Girişli, son siparişi olan | "Aynı siparişi tekrarla" çalışır |
| 3 | Ana sayfadaki menüden sepete ekle | Sepet çubuğu ve header rozeti görünür |
| 4 | Seçeneği olan ürün | Sepete eklenmez, detay sayfasına gider |

### S11 — Fiş güncelliği ve QR'lar (K-17 … K-19, W-15/W-16, 12.08.2026)

Otomatik karşılıkları: `mutfakapp/test/print_queue_test.dart` (37),
`packages/core/test/escpos_golden_test.dart` (QR golden'ları ve dört kural
testi), `ContractTest` içindeki üç fiş bağlantısı testi,
`website/e2e/hesap.spec.ts` "Adres defteri (W-15)".

**S11.1 — Eski fiş asla çıkmaz**

| # | Adım | Beklenen |
|---|---|---|
| 1 | Yazıcıyı kapat, sipariş onayla | Mutfak fişi kuyrukta bekler |
| 2 | Aynı siparişi KDS'ten düzenle | Kuyrukta o siparişin **tek** mutfak işi kalır, sürümü yeni olan |
| 3 | Yazıcıyı aç | **Yalnız güncel fiş** basılır, eskisi hiç çıkmaz |
| 4 | 1–2'yi yaptıktan sonra basmadan kasayı yeniden başlat | Kuyruk diskten gelir, yine yalnız güncel fiş basılır |
| 5 | Fiş basıldıktan **sonra** düzenle | Basılmış satır kuyrukta durur (denetim izi), yeni sürüm ayrıca basılır |
| 6 | Mutfak fişi yenilenirken bekleyen müşteri fişi | **Düşürülmez** — tür bazında siliniyor |

**S11.2 — Fişteki QR'lar**

| # | Adım | Beklenen |
|---|---|---|
| 1 | Kapıda ödemeli sipariş, `hazir` yap | Müşteri fişinde **iki** QR: üstte ödeme, altta takip |
| 2 | Ödeme QR'ını okut | Ödeme sayfası açılır; bitince takip sayfasına döner |
| 3 | Takip QR'ını okut | `/takip/<id>?e=…&s=…` açılır — **giriş istemez** (K-20) |
| 4 | Online ödenmiş sipariş | Ödeme QR'ı **basılmaz**, takip QR'ı basılır |
| 5 | `FRONTEND_URL` boşken | İki QR da basılmaz, fiş eski hâliyle çıkar |
| 6 | Haritada iğnesi olan adres | Harita QR'ı ayrıca basılır (K-14) |

**S11.3 — Adres defteri ve harita**

| # | Adım | Beklenen |
|---|---|---|
| 1 | `/hesabim/adresler` → yeni adres | Listede görünür |
| 2 | "Varsayılan" işaretli adres, `/odeme` | Form önceden dolu gelir |
| 3 | Haritada iğne koy, sipariş ver | Kurye fişinde harita QR'ı basılır |
| 4 | İğneyi hizmet alanı dışına sürükle | Kabul edilmez, iğne eski yerine döner, uyarı çıkar |
| 5 | İğne koymadan sipariş ver | Sipariş geçer; fiş QR'sız basılır (iğne zorunlu değil) |
| 6 | Adresi sil | Onay sorar; geçmiş siparişlerin adresi değişmez |

### S12 — Fiş birleşmesi ve teslim QR'ı (K-20, 14.08.2026)

Otomatik karşılıkları: `mutfakapp/test/print_triggers_test.dart` (23),
`mutfakapp/test/print_queue_test.dart` ("Yeniden bas revizyona duyarlıdır"),
`packages/core/test/escpos_golden_test.dart` ("Birleşik fiş kuralları" grubu
+ dört yeni golden), `PublicTrackingTest` (8), `DeliveryConfirmTest` (11),
`SignedLinkTest` (10), `website/e2e/siparis.spec.ts` (girişsiz takip).

> **ÖNCE DONANIM.** `docs/10` §"QR AÇIK MADDE" hâlâ kapanmadı: fişteki konum
> QR'ı sahada kâğıda çıkmıyor ve sebebi bilinmiyor. Teslim QR'ı da aynı
> `GS ( k` komutuna dayanıyor. Aşağıdaki 4–6 numaralı adımlardan önce
> `cd mutfakapp && dart run tool/yazici_teshis.dart` koşulmalı; yalnız C
> bölümü çıkıyorsa yazıcı yerleşik QR'ı yutuyor demektir ve QR'lar raster
> çizilmek zorunda (ayrı görev).

**S12.1 — Kâğıt sayımı**

| # | Adım | Beklenen |
|---|---|---|
| 1 | Adrese gönderim siparişi, `onaylandi` | **Bir** mutfak fişi |
| 2 | `hazir` yap | **Bir** müşteri fişi: ad, telefon, adres, harita QR, `TAHSİL`, takip + teslim QR'ı. Ayrı kurye fişi **çıkmaz** |
| 3 | Gel-al siparişi, `hazir` | Fişte adres, ad, telefon, `TAHSİL` ve teslim QR'ı **yok**; `GEL-AL` yazar |
| 4 | Karttan "Yeniden bas" | Menüde **iki** seçenek (mutfak, müşteri); **tek** kâğıt çıkar |

**S12.2 — Revizyon tek kâğıda iner**

| # | Adım | Beklenen |
|---|---|---|
| 1 | `hazir` siparişi düzenle | 20 sn boyunca **hiç kâğıt çıkmaz** |
| 2 | 20 sn dolmadan ikinci kez düzenle | Sayaç sıfırlanır; ara sürüm basılmaz |
| 3 | Sessizlikten sonra | Mutfak + müşteri fişi **birer kez**, son sürümle, üstünde `GÜNCEL FİŞ / REVİZE #2 / ÖNCEKİ FİŞİ ATIN` |
| 4 | `hazir` ÖNCESİ düzenle | Müşteri fişi fazladan çıkmaz; `hazir`da bir kez, güncel veriyle çıkar |
| 5 | Bekletme sırasında kasayı yeniden başlat | Fiş **hemen** çıkar (hata yönü "erken", "hiç" değil) |
| 6 | Bekletme sırasında siparişi iptal et | Bekleyen fiş **hiç basılmaz** |

**S12.3 — Girişsiz takip**

| # | Adım | Beklenen |
|---|---|---|
| 1 | Takip QR'ını **çıkış yapmış** telefonla okut | Sipariş durumu görünür; `/giris` ekranı **çıkmaz** |
| 2 | Sayfada adres/telefon/kalem ara | **Yok** — yalnız durum, tutar, ödeme durumu |
| 3 | `?s=` değerini bozup aç | "Bağlantı geçersiz" |
| 4 | Başka siparişin imzasıyla aç | `403` |
| 5 | `BLD_LINK_SECRET` ve `APP_KEY` boşken | QR hiç basılmaz, fiş eski hâliyle çıkar |

**S12.4 — Teslim onayı**

| # | Adım | Beklenen |
|---|---|---|
| 1 | `yolda` siparişin teslim QR'ını okut | Sipariş no, ad, adres, tahsil edilecek tutar + tek düğme |
| 2 | "TESLİM ETTİM" | Sipariş `teslim_edildi`; `status_history`'de "Kurye QR ile teslim onayı" |
| 3 | Aynı QR'ı ikinci kez okut | "Bu sipariş zaten teslim edildi" — **hata ekranı değil**, yeni kayıt açılmaz |
| 4 | `hazir` (yolda yapılmamış) siparişte okut | Teslim edilir; geçmişte **`yolda` satırı da** oluşur |
| 5 | `onaylandi` siparişte okut | "Sipariş henüz hazır değil"; durum değişmez |
| 6 | İptal edilmiş siparişte okut | "Bu sipariş iptal edilmiş"; durum değişmez |
| 7 | Süresi dolmuş bağlantı | "Bağlantının süresi doldu — kasadan yeni fiş bastırın" |
| 8 | `infra/Caddyfile.internal` güncellenmeden üretime çık | QR ana siteye 308'lenir — **dağıtım öncesi kontrol edilecek madde** |

## 2. Bileşen bazlı kabul ölçütleri

### Backend (`platform/`)
- [ ] `php artisan test` tamamı yeşil
- [ ] Hizmet alanı dışındaki il/ilçe hem `POST /api/orders` hem
      `POST/PATCH /api/addresses` ucunda `422` alıyor (`ServiceArea`)
- [ ] Hizmet alanı kutusunun dışındaki harita iğnesi `422` alıyor
- [ ] Mutfak fişi `customer_phone` döndürüyor, KDS kartları döndürmüyor
- [ ] Sözleşmedeki her uç uygulanmış ve manuel doğrulanmış
- [ ] `OrderStatusTransition` tüm geçiş matrisini kapsayan test
- [ ] `openapi.json` üretiliyor ve sözleşmeyle uyumlu
- [ ] Tüm hatalar tek biçimde dönüyor
- [ ] `platform/vendor/` dokunulmamış
- [ ] Sır yok, `.env.example` güncel

### Donanım — QR AÇIK MADDE (07.08.2026)

Müşteri fişindeki konum QR'ı sahada kâğıda çıkmıyor. Veri yolu (sunucu → KDS →
ESC/POS) kodda eksiksiz ve golden test QR baytlarının fişte bulunduğunu
doğruluyor; geriye iki olasılık kalıyor:

1. Siparişin adresinde harita iğnesi yok — basılacak veri hiç yok.
2. Yazıcı yerleşik QR komutunu (`GS ( k`) yok sayıyor. Bu komut ESC/POS'un
   isteğe bağlı bir eklentisidir; desteklemeyen yazıcı hata vermez, sessizce
   hiçbir şey basmaz.

Ayırt etmek için teşhis fişi: `cd mutfakapp && dart run tool/yazici_teshis.dart`
Fişte üç bölüm var — A: yerleşik QR (Model 2), B: yerleşik QR (Model 1),
C: raster nokta görseli (`GS v 0`).

- [ ] A veya B kâğıda çıkıyor → yerleşik QR çalışıyor, sorun sipariş verisinde
- [ ] İkisi de boş, C çıkıyor → QR görsel olarak çizilip basılmalı
      (`qr` paketi + `EscPosBuilder.bitImage`, ayrı görev)
- [ ] Üçü de boş → yazıcı/kablo sorunu, önce onu doğrula

### Donanım — GERÇEK YAZICIDA DOĞRULANDI (04.08.2026)

- [x] Yazıcı tanındı: `0483:5720` `aaaait Printer`, `/dev/usb/lp1`
- [x] udev kuralı kurulu, `/dev/thermal0` sembolik bağı yazılabilir
- [x] Fiş basıyor
- [x] Türkçe kod sayfası bulundu: **`ESC t 29`** (doküman `13` diyordu, yanlıştı)
- [x] 12 Türkçe harf doğru basıyor: ç ğ ı ö ş ü Ç Ğ İ Ö Ş Ü
- [x] Dört golden fiş (2 tip × 2 teslimat) **kâğıda basıldı ve gözle doğrulandı** —
      düzen, hizalama, punto ve kesme doğru

Bu, `docs/09` §8'in "projenin en büyük tek donanım riski" dediği maddedir.
Kapandı.

### Mutfak (`mutfakapp/`)
- [ ] `flutter analyze` sıfır uyarı
- [ ] ESC/POS golden testleri geçiyor (2 fiş tipi × 2 teslimat tipi)
- [ ] PC857 Türkçe karakter testi geçiyor
- [ ] Kuyruk idempotentlik testi geçiyor
- [x] Açılış kilidi çalışıyor — parola testleri mutasyonla doğrulandı
      (kontrolü `return true` yapınca 4 test kırmızıya döndü)
- [x] Pencere küçültme ve tam ekran aç/kapa düğmeleri var
- [x] Yoğunluk tuşu — üretimde uçtan uca doğrulandı (mutfak → API →
      müşteri ~2 sn); yoğunkken siparişin YİNE alındığı ayrı testle korunuyor
- [x] Ürün görseli admin medyasından API'ye akıyor (`image_url`)
- [x] Yoğunluk admin panelde görünür/ayarlanabilir — BLD Ayarları sayfası
- [x] Yedi şalterin tamamı panelden yönetilebiliyor (artisan gerekmiyor)
- [x] TL↔kuruş dönüşümü kaymıyor — gidiş-dönüş ve virgüllü girdi doğrulandı
- [ ] Mutfak cihazları ve fiş kuyruğu admin ekranları — hâlâ yalnızca artisan
- [ ] Mobil uygulamada yoğunluk bandı — henüz yok
- [ ] Android'e dair kod/bağımlılık **yok**
- [ ] Kasa kabul listesi (`docs/08` §2.4) 7/7
- [ ] `OrderSource` soyutlaması var (WebSocket'e geçiş hazır)

### Website (`website/`)
- [x] `npm run lint` ve `tsc --noEmit` temiz, `any` yok
- [ ] Playwright senaryoları geçiyor — **yazılmadı**
- [ ] Lighthouse: Performance ≥ 90, Accessibility ≥ 95 — **ölçülmedi**
- [x] `sitemap.xml`, `robots.txt`, ürün JSON-LD var — canlıda 200, apex host
- [ ] Mobil görünüm 360px genişlikte bozulmuyor — **gerçek cihazda bakılmadı**
- [x] Üretim imajı derleniyor ve canlıda koşuyor (`site` servisi, 342 MB)

> `robots.txt` çıktısının başında **Cloudflare'in yönetilen bloğu** var
> (`GPTBot`, `ClaudeBot`, `CCBot`… engelli). Bunu biz yazmadık, Cloudflare
> ekliyor. Bizim kurallarımız altta duruyor ve geçerli.

### Müşteri app (`musteriapp/`)
- [ ] `flutter analyze` sıfır uyarı
- [ ] Kurumsal kayıt formu ticari unvan + yetkili kişiyi zorunlu tutuyor
- [ ] `can_order = false` hesap sepet/ödemeye giremiyor, "Sipariş kapalı"
      ekranına düşüyor; menü/keşif serbest
- [ ] Aboneliklerim: talep oluşturulabiliyor (`pending`), detayda
      duraklat/devam/iptal çalışıyor
- [ ] Cari hesabım: bakiye ve ekstre sunucudan geliyor, tutar istemcide
      hesaplanmıyor
- [ ] "Beni hatırla" kapalıyken uygulama yeniden açıldığında oturum kapalı;
      açıkken oturum sürüyor
- [ ] Adres formlarında il değiştirilemiyor, ilçe yalnızca Selçuklu/Karatay
- [ ] Harita hizmet alanı kutusunun dışına kaydırılamıyor
- [ ] Ödeme ekranında bırakılan iğne adres defterine işleniyor (sonraki
      siparişte harita iğneli açılıyor)
- [ ] Sepet hesaplama unit testleri geçiyor
- [ ] Zorunlu güncelleme mantığı çalışıyor
- [ ] Play kapalı test kanalında yüklü ve açılıyor
- [ ] **App Store TestFlight'ta yüklü ve açılıyor** — iOS hedefi
      05.08.2026'da eklendi; `ios/` iskeleti ve CI derleme işi hazır,
      gerçek derleme **Mac + Apple Developer Program** gerektirir
- [ ] Bundle kimliği iki platformda da `com.veykemtu.catering` (CI kontrol ediyor)
- [ ] Push bildirimi geliyor ve deep link çalışıyor
- [x] Marka fontları (Inter + Sora) `assets/fonts/` içinde bundle'lı, OFL
      lisansları yanında; çalışma anında indirme yok
- [ ] **Marka uygulama ikonu + açılış (splash) üretilecek** — tek elde kalan
      sürüm işi. `flutter_launcher_icons`/`flutter_native_splash` yapılandırması
      **marka logosu** (owner'dan) gelince eklenir; şu an varsayılan Flutter
      ikonu duruyor. Değişiklik native `android/`+`ios/` dosyalarına dokunduğu
      için bir derleme ortamında doğrulanmalı (körlemesine üretilmedi — ağ
      bozulmasın). Turuncu palet: `brand600 = #EA580C`.
- [ ] Docker Compose tek komutla ayağa kalkıyor
- [ ] 4 CI hattı da yeşil
- [x] Yedek alınıyor ve **geri dönüş tatbikatı yapıldı** — üretim sunucusunda, 85 tablo / 31 sipariş geri geldi
- [x] TLS sertifikası otomatik yenileniyor — Traefik + Let's Encrypt, iki alan adı
- [ ] **`BACKUP_REMOTE` tanımlı değil** — yedekler yalnızca aynı sunucuda
- [ ] `heartbeat` gecikmesi admin panelde uyarı üretiyor

## 3. Sonuç tablosu (Gün 7'de doldurulur)

| Senaryo | Durum | Not |
|---|---|---|
| S1 Adrese gönderim | ☐ Geçti ☐ Kaldı | |
| S2 Gel-al | ☐ Geçti ☐ Kaldı | |
| S3 Sipariş alım şalteri | ☐ Geçti ☐ Kaldı | |
| S4 Dayanıklılık | ☐ Geçti ☐ Kaldı | |
| S5 Güvenlik | ☐ Geçti ☐ Kaldı | |
| S9 Mutfak turu (K-09…K-16) | ☐ Geçti ☐ Kaldı | |
| S6 Durum geçişleri | ☐ Geçti ☐ Kaldı | |
| S7 Yük | ☐ Geçti ☐ Kaldı | |

### Canlıya almadan ÖNCE kapatılacaklar

- [ ] **`POS_ALLOW_SIMULATION` kaldırıldı.** Açık kalırsa simülasyon geçidi
      her kartı onaylar ve **her sipariş bedava olur.** Doğrulama:
      `GET /api/health` yanıtında `payment_simulation_active` alanı
      **görünmemeli**; görünüyorsa bayrak hâlâ açık.
- [ ] Vitrinin `payment_methods` listesinde `online` varsa, arkasında
      **gerçek** bir sanal POS olduğu doğrulandı
- [ ] `veykemtu:demo-menu` ile yüklenen deneme ürünleri silindi
- [ ] **`infra/e2e.sh` üretimde çöp bırakır.** Her koşu deneme müşterisi,
      deneme siparişi ve mutfak cihazı yaratır. Canlıya almadan önce
      temizlenir: `veykemtu:kds --revoke=<id>` ile cihazlar (05.08.2026'da
      9 tanesi temizlendi), sipariş ve müşteriler admin panelden.
- [ ] `APP_DEBUG=false`
- [ ] Coolify API token'ı ve tüm geçici parolalar yenilendi
- [ ] `www.benimlezzetdunyam.com.tr` DNS kaydı eklendi ve Coolify'da
      `site` servisinin alan adlarına yazıldı (şu an **yok**; apex çalışıyor)
- [ ] `FRONTEND_URL` çözülebilir adresi gösteriyor — doğrulama:
      `infra/e2e.sh` içindeki "ödeme dönüş adresi cevap veriyor" yeşil

**Canlıya alma kararı:** S1, S3, S4, S5 ve S6 zorunlu. S2 (gel-al) ve S7 (yük) eksik kalırsa gerekçesi ve kapatma tarihi yazılarak canlıya çıkılabilir.

## 4. Bilinen sınırlar (kabul edilen)

- Termal fiş **bilgi fişidir**, mali belge değildir. e-Arşiv fatura ayrı süreçtir.
- Tek kasa/tek yazıcı: donanım arızasında operasyon durur; yedek plan admin panelden sipariş görüntülemektir.
- Faz 1'de gerçek zamanlılık polling ile 5 saniyeye kadar gecikebilir.
- Stok takibi ve reçete maliyeti bu fazda yoktur.
- Online ödeme (sanal POS) Faz 1'de **kapalıdır**; tahsilat kapıda ödeme veya cari hesap ile yapılır.
- Öğrenci ve kurum içi sipariş kanalları **hiç yoktur** (bkz. `docs/00-genel-bakis.md` §4).
- **Cari hesap muhasebe yazılımı değildir:** sistem borç/alacak hareketi, yürüyen bakiye, ekstre ve ay sonu **özeti** üretir; **fatura / e-Arşiv KESMEZ** (e-Arşiv ayrı, sonraki faz süreci). Tahsilat deftere ayrı `credit` hareketidir; `AccountPayment` geçidi `pending` kalır.
- Abonelik `daily_menu` modu bu turda **ertelendi**: "günün menüsü" kaynağı olmadığından yalnız `fixed_list` tam desteklenir (bkz. `docs/11` §7.5).
- Abonelik ve toplu fiyatlama Faz 2'dir; bu fazda ürün fiyatı tekildir.
