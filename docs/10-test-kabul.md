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

## 2. Bileşen bazlı kabul ölçütleri

### Backend (`platform/`)
- [ ] `php artisan test` tamamı yeşil
- [ ] Sözleşmedeki her uç uygulanmış ve manuel doğrulanmış
- [ ] `OrderStatusTransition` tüm geçiş matrisini kapsayan test
- [ ] `openapi.json` üretiliyor ve sözleşmeyle uyumlu
- [ ] Tüm hatalar tek biçimde dönüyor
- [ ] `platform/vendor/` dokunulmamış
- [ ] Sır yok, `.env.example` güncel

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
- [ ] Sepet hesaplama unit testleri geçiyor
- [ ] Zorunlu güncelleme mantığı çalışıyor
- [ ] Play kapalı test kanalında yüklü ve açılıyor
- [ ] Push bildirimi geliyor ve deep link çalışıyor

### Altyapı (`infra/`)
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
- Abonelik ve toplu fiyatlama Faz 2'dir; bu fazda ürün fiyatı tekildir.
