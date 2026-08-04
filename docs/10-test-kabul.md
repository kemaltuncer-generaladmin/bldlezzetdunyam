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

### Mutfak (`mutfakapp/`)
- [ ] `flutter analyze` sıfır uyarı
- [ ] ESC/POS golden testleri geçiyor (2 fiş tipi × 2 teslimat tipi)
- [ ] PC857 Türkçe karakter testi geçiyor
- [ ] Kuyruk idempotentlik testi geçiyor
- [ ] Android'e dair kod/bağımlılık **yok**
- [ ] Kasa kabul listesi (`docs/08` §2.4) 7/7
- [ ] `OrderSource` soyutlaması var (WebSocket'e geçiş hazır)

### Website (`website/`)
- [ ] `npm run lint` ve `tsc --noEmit` temiz, `any` yok
- [ ] Playwright senaryoları geçiyor
- [ ] Lighthouse: Performance ≥ 90, Accessibility ≥ 95
- [ ] `sitemap.xml`, `robots.txt`, ürün JSON-LD var
- [ ] Mobil görünüm 360px genişlikte bozulmuyor

### Müşteri app (`musteriapp/`)
- [ ] `flutter analyze` sıfır uyarı
- [ ] Sepet hesaplama unit testleri geçiyor
- [ ] Zorunlu güncelleme mantığı çalışıyor
- [ ] Play kapalı test kanalında yüklü ve açılıyor
- [ ] Push bildirimi geliyor ve deep link çalışıyor

### Altyapı (`infra/`)
- [ ] Docker Compose tek komutla ayağa kalkıyor
- [ ] 4 CI hattı da yeşil
- [ ] Yedek alınıyor ve **geri dönüş tatbikatı yapıldı**
- [ ] TLS sertifikası otomatik yenileniyor
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

**Canlıya alma kararı:** S1, S3, S4, S5 ve S6 zorunlu. S2 (gel-al) ve S7 (yük) eksik kalırsa gerekçesi ve kapatma tarihi yazılarak canlıya çıkılabilir.

## 4. Bilinen sınırlar (kabul edilen)

- Termal fiş **bilgi fişidir**, mali belge değildir. e-Arşiv fatura ayrı süreçtir.
- Tek kasa/tek yazıcı: donanım arızasında operasyon durur; yedek plan admin panelden sipariş görüntülemektir.
- Faz 1'de gerçek zamanlılık polling ile 5 saniyeye kadar gecikebilir.
- Stok takibi ve reçete maliyeti bu fazda yoktur.
- Online ödeme (sanal POS) Faz 1'de **kapalıdır**; tahsilat kapıda ödeme veya cari hesap ile yapılır.
- Öğrenci ve kurum içi sipariş kanalları **hiç yoktur** (bkz. `docs/00-genel-bakis.md` §4).
- Abonelik ve toplu fiyatlama Faz 2'dir; bu fazda ürün fiyatı tekildir.
