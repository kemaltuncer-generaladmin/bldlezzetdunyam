# 09 — Görev Planı (1 Hafta, Paralel Ajanlar)

## 1. Çalışma modeli

7 gün, paralel ajan hatları. **Kritik yol: API sözleşmesi → backend uçları → istemciler.** Sözleşme (`docs/03-api-sozlesmesi.md`) zaten yazılı olduğu için istemci ajanları backend'i beklemeden **mock sunucuya karşı** çalışmaya başlar; bu, 1 haftalık takvimi mümkün kılan tek şeydir.

**Hat sahipleri:**

| Hat | Kapsam | Ajan |
|---|---|---|
| **B** | Backend/platform (PHP) | B-ajanı |
| **K** | Mutfak uygulaması (Flutter Linux) | K-ajanı |
| **W** | Website (Next.js) | W-ajanı |
| **M** | Müşteri app (Flutter Android + iOS) | M-ajanı |
| **I** | Altyapı/CI/kasa | I-ajanı |

## 2. Gün 0 — Ortak temel (tüm ajanlar durur, bu bitmeden başlanmaz)

| ID | İş | Çıktı |
|---|---|---|
| `X-01` | Repo iskeleti: klasörler, `pubspec.yaml` workspace, `.gitignore`, `.env.example` dosyaları | Boş ama derlenen ağaç |
| `X-02` | `packages/core`: durum makinesi (geçiş matrisi), para/tarih biçimleme | Testli paket |
| `X-03` | `packages/api_client`: sözleşmedeki tüm DTO'lar (freezed), HTTP istemci, hata modeli, `OrderSource` arayüzü | Testli paket |
| `X-04` | **Mock API sunucusu**: `infra/mock/` — sözleşmedeki tüm uçları döndürür. **Durum tutar**: sipariş oluşturma, durum geçişleri, artımlı polling (`after`/`since`/`max_id`), idempotent fiş ack. İstemci ajanları buna bağlanır. | Çalışan mock |
| `X-05` | `docs/openapi.yaml` — sözleşmenin normatif, makine okunur biçimi | Geçerli OpenAPI 3.1 |

**X-04 kritik.** Bu olmadan istemci hatları backend'i bekler ve takvim kayar.

## 3. Gün 1-2

### Hat B — Backend
| ID | İş | Bağımlılık |
|---|---|---|
| `B-01` | TastyIgniter kurulumu, tek vitrin, tek müşteri grubu, durum seeder'ı | X-01 |
| `B-02` | **DOĞRULAMA:** kurulu TastyIgniter'ın gerçek kodunu oku — sipariş oluşturma servisinin imzası, hazır gelen uçlar, extension'dan route/migration/panel ekleme yolu. Bulguları `BILINMEYENLER.md`'ye yaz. Eğitim verisinden hatırlanan bilgiye güvenilmez. | B-01 |
| `B-03` | `veykemtu/bridgeapi` iskelet: Sanctum kapsamları, hata biçimi, sağlık ucu | B-02 |
| `B-04` | Katalog uçları: `/locations`, `/locations/{id}/menu` | B-03 |

### Hat K — Mutfak
| ID | İş | Bağımlılık |
|---|---|---|
| `K-01` | Flutter Linux projesi, Riverpod iskeleti, tam ekran pencere | X-01 |
| `K-02` | Sipariş ekranı UI: üç sütun, kartlar, üretim şeridi, durum çubuğu (mock veriyle) | K-01, X-03 |
| `K-03` | ESC/POS motoru: komut seti, PC857 çevirisi, üç fiş şablonu + golden testler | X-02 |

### Hat W — Website
| ID | İş | Bağımlılık |
|---|---|---|
| `W-01` | Next.js projesi, Tailwind, tasarım tokenları, layout | X-01 |
| `W-02` | Ana sayfa + menü sayfası (mock API), SSR + metadata + JSON-LD | W-01, X-04 |
| `W-03` | Ürün detay + sepet (cookie tabanlı) | W-02 |

### Hat M — Müşteri app
| ID | İş | Bağımlılık |
|---|---|---|
| `M-01` | Flutter projesi, Riverpod, tema, yönlendirme | X-01 |
| `M-02` | Giriş/kayıt ekranları + token saklama (mock API) | M-01, X-03 |
| `M-03` | Menü + ürün detay + sepet | M-02 |

### Hat I — Altyapı
| ID | İş | Bağımlılık |
|---|---|---|
| `I-01` | `docker-compose.yml`, Caddyfile, PHP imajı | X-01 |
| `I-02` | CI hatları (4 workflow) + `vendor/` koruma adımı | I-01 |
| `I-03` | Hetzner sunucu hazırlığı, staging ayağa kaldırma | I-01 |

## 4. Gün 3-4

### Hat B
| ID | İş |
|---|---|
| `B-05` | Kimlik uçları: register/login/logout/me |
| `B-06` | Sipariş oluşturma: `POST /api/orders`, doğrulamalar, `ordering_enabled`/`order_cutoff`/`payment_methods` kontrolleri |
| `B-07` | Sipariş görüntüleme/iptal: `GET /api/orders`, `GET /api/orders/{id}`, `POST .../cancel` |
| `B-08` | KDS uçları: pair, orders (artımlı), status, receipt, production-list, heartbeat, ack |
| `B-09` | `OrderStatusTransition` + tam geçiş matrisi testi |
| `B-10` | `veykemtu/appversion` + `openapi.json` üretimi |

### Hat K
| ID | İş |
|---|---|
| `K-04` | Yazdırma kuyruğu: SQLite, idempotentlik, tekrar deneme, ack |
| `K-05` | `PollingOrderSource`: artımlı çekme, geri çekilme, kurtarma |
| `K-06` | Durum butonları + geçiş istekleri + yazdırma tetikleri |
| `K-07` | Eşleme ekranı + token saklama + `DEVICE_REVOKED` davranışı |

### Hat W
| ID | İş |
|---|---|
| `W-04` | Giriş/kayıt, korumalı rotalar |
| `W-05` | Ödeme sayfası + sipariş oluşturma + sanal POS yönlendirme |
| `W-06` | Sipariş takip ekranı (adım çubuğu, polling) + siparişlerim |

### Hat M
| ID | İş |
|---|---|
| `M-04` | Ödeme ekranı + WebView + sipariş oluşturma |
| `M-05` | Sipariş takip + siparişlerim |
| `M-06` | FCM entegrasyonu, izin, token gönderimi, deep link |

### Hat I
| ID | İş |
|---|---|
| `I-04` | Kasa kurulum betiği + udev kuralı + systemd unit |
| `I-05` | Yedekleme betiği + cron |
| `I-06` | Play kapalı test kanalı açılışı, imzalama anahtarı CI'ya |

## 5. Gün 5 — Entegrasyon (mock kapatılır)

**Tüm istemciler mock'tan gerçek staging backend'ine geçirilir.** Bu günün tek işi: sözleşme uyuşmazlıklarını bulmak ve kapatmak.

| ID | İş |
|---|---|
| `E-01` | Tüm istemciler staging API'sine bağlanır, her uç manuel doğrulanır. **`platform/openapi.json` ile `docs/openapi.yaml` farkı sıfırlanır.** |
| `E-02` | Adrese gönderim akışı uçtan uca: sipariş → KDS → mutfak fişi → hazır → müşteri fişi → yolda → teslim |
| `E-03` | Gel-al akışı uçtan uca: `pickup` sipariş → KDS `GELAL` rozeti → hazır → müşteri fişi (adressiz) → teslim edildi |
| `E-04` | Sipariş alım şalteri: `ordering_enabled=false` → web ve mobilde sipariş engellenir, menü görünür |
| `E-05` | `veykemtu/push` + `veykemtu/sms` entegrasyonu ve testi |
| `E-06` | Ödeme eklentisi iskeleti: `cash` + `account` uçtan uca çalışır; sanal POS (Kuveyt Türk) arayüzü hazır, `payment_methods` ile kapalı |

## 6. Gün 6 — Saha kurulumu ve sertleştirme

| ID | İş |
|---|---|
| `S-01` | MSI kasaya Ubuntu kurulumu, `setup.sh` çalıştırma, yazıcı doğrulama |
| `S-02` | Kasa kabul listesi (`docs/08` §2.4) — 7 madde tek tek işaretlenir |
| `S-03` | Prod ortamı ayağa kaldırma, DNS, TLS, ilk veri (menü girişi) |
| `S-04` | Güvenlik geçişi: oran sınırları, `vendor/` kontrolü, sır taraması, admin 2FA |
| `S-05` | Yük provası: 50 sipariş peş peşe → KDS gecikmesi ve kuyruk davranışı ölçülür |
| `S-06` | Yedek al + geri dönüş tatbikatı |

## 7. Gün 7 — Kabul ve devir

| ID | İş |
|---|---|
| `A-01` | `docs/10-test-kabul.md` içindeki tüm senaryolar sırayla koşulur, sonuç tablosu doldurulur |
| `A-02` | Bilinen eksikler listesi + Faz 1.5/2 backlog'u |
| `A-03` | Kullanım kılavuzu: mutfak personeli için 1 sayfa, yönetici için 2 sayfa |
| `A-04` | Runbook: sık sorunlar (yazıcı basmıyor, internet yok, sipariş düşmüyor) ve çözümleri |
| `A-05` | Canlıya alma kararı |

## 8. Bağımlılık grafiği (kritik yol)

```
X-01 ─► X-05 ─┬─► X-02 ─► X-03 ─► X-04 ─┬─► K/W/M hatları (mock ile paralel)
              │                          │
              └─► B-01 ─► B-02 ─► B-03 ─► B-06 ─► B-08 ─► E-01 ─► S-* ─► A-*
```

**En riskli düğümler:** `K-03` (ESC/POS + Türkçe karakter), `B-08` (KDS uçları), `E-01` (sözleşme uyuşmazlıkları), `S-01` (donanım). Bu dördüne öncelik ver; gecikirse başka işleri kes, bunları bitir.

**Donanım riski, Gün 1'de kapatılır:** Termal yazıcı `K-03`'ten **önce** fiziksel olarak doğrulanır — `lsusb` ile VID/PID alınır, ham bayt testi (`echo -e "Test\n\n\n\x1D\x56\x42\x00" > /dev/usb/lp0`) yapılır. Fiş çıkmazsa hat durur ve bildirilir; bu projenin en büyük tek donanım riskidir.

## 8.5 Mutfak turu — K-09 … K-16 (11.08.2026)

`yapılacaklar.md` içindeki MutfakApp maddelerinin görev karşılıkları.
K-01…K-08 Faz 1'de kapandı; bu blok mutfak uygulamasının ikinci turu.

| ID | İş | Durum |
|---|---|---|
| `K-09` | Ses altyapısı: `pw-play` argüman hatası, seviye, çıkış cihazı, olay bazlı sesler, TTS, tanılama | **Bitti** |
| `K-10` | Dokunmatik uyum: hedef boyutları, Türkçe ekran klavyesi, kaydırma jestleri, geri alma penceresi | **Bitti** |
| `K-11` | Satış kontrolü: süreli+sebepli sipariş durdurma (şifre korumalı) + ürün bazında "bugün tükendi" | **Bitti** |
| `K-12` | Sipariş düzenleme motoru: `LineResolver` ayrıştırması, `OrderEditor`, revizyon tablosu, cari düzeltme | **Bitti** |
| `K-13` | İade katmanı: sağlayıcı-bağımsız `RefundGateway` + `RefundManager` + iade kayıtları | **Bitti** |
| `K-14` | Kurye fişi (3. tip), panoda telefon, revize rozeti, revizyonlu fiş tetikleri, **KDS düzenleme ekranı** | **Bitti** |
| `K-15` | Abonelik üretim planı ekranı + üretim planı fişi | **Bitti** |
| `K-16` | BBD Store köprüsü: imzalı webhook → ayrı ses + termal fiş | **Bitti** |

### Bağımlılıklar

```
K-09 ──┐
K-10 ──┼── bağımsız, paralel gidebilir
K-11 ──┘
K-12 → K-13 → K-14
K-15, K-16 bağımsız
```

### Mutfak turu KAPANDI (12.08.2026)

`yapılacaklar.md` içindeki yedi MutfakApp maddesinin tamamı karşılandı.
Kapsam dışında bırakılan tek şey **cari hesabın KDS'te gösterilmesi**;
bu bilinçli bir karar (ADR-08 korunuyor) ve düzenleme onayında yalnız
iade/fark tutarı görünüyor.

**Sunucuda koşturulacak göçler (5 adet):**

```bash
cd platform
php artisan igniter:up
vendor/bin/phpunit --testsuite Veykemtu
```

**Yeni `.env` girdileri:** `BBD_WEBHOOK_SECRET` (boşsa BBD ucu kapalı),
`BLD_REFUND_DRIVER`.

## 8.6 Web + Admin turu — I-07 … I-08, B-11 … B-18, W-07 … W-14 (12.08.2026)

`yapılacaklar.md` içindeki dört **Web-Admin** maddesi ve turda eklenen iki
istek (panelden telefon siparişi, admin ikonları) karşılandı.

### Altyapı

| Kimlik | İş | Not |
|---|---|---|
| I-07 | api.* kökündeki vitrin kaldırıldı | Ayrı bir deploy değildi: `IGNITER_URI` boş olduğu için TastyIgniter'ın Orange teması `/` altına biniyordu. `disableThemeRoutes(true)` + Caddy 308 |
| I-08 | Admin ikonları düzeltildi | `Dockerfile.web` derlemede `vendor:publish` koşmuyordu; Caddy imajında `/vendor/igniter/fonts/` hiç yoktu. CSS PHP birleştiricisinden geldiği için stiller çalışıyor, yalnız webfont 404 alıyordu |

### Admin paneli

| Kimlik | İş |
|---|---|
| B-11 | Menü sadeleştirme: `themes`, `mail_templates`, `api`, `updates`, `system_logs`, blog gizlendi |
| B-12 | BLD marka CSS'i + her ekranda **SİMÜLASYON MODU** şeridi |
| B-13 | **Telefon siparişi ekranı** — müşteri seç/oluştur, satırlar, abonelik bağı; sipariş `onaylandi` doğar |
| B-14 | Cari: borç limiti, tahsilat girişi, 90 günlük ekstre, `POST /api/account/payments` |
| B-15 | İade takibi (tablo K-13'ten beri vardı, arayüzü yoktu) |
| B-16 | Abonelik oluşturma + 30 günlük takvim önizlemesi |
| B-17 | Sipariş revizyonları ve tükenen ürün geçmişi (salt okunur) |
| B-18 | Kurumsal kayıt alanları + **telefonla giriş (OTP)**, Netgsm |

### Website

| Kimlik | İş |
|---|---|
| W-07 | Header: `<details>` → Radix `NavigationMenu`, mobilde `SheetClose`, aşağı kaydırınca gizlenen bar |
| W-08 | Bilgi mimarisi 10+ → 4 sayfa, 308 yönlendirmeler |
| W-09 | `cn` yardımcısı tek sürüme indi (`twMerge`'lü olan); `bld-*` kısayolları gerekçeli olarak bırakıldı |
| W-10 | Ana sayfada hızlı sipariş kutusu + "geçen siparişi tekrarla" |
| W-11 | Telefonla giriş arayüzü + `/kurumsal-kayit` |
| W-12 | Cari self-servisi + ödeme (tamamı / istenen tutar) |
| W-13 | Abonelik self-servisi + `/hesabim` merkezi |
| W-14 | **Playwright kuruldu** — config ve `e2e/` yoktu, CI adımı sessizce atlanıyordu |

### Turda yakalanan hatalar

1. **Admin eylem işleyicilerinin imzası.** Çekirdek `[$action, ...$params]`
   ile çağırıyor, yani ilk argüman hep bağlam adı. Tek parametreli yazılan
   `onRecordPayment` `$recordId` olarak `"edit"` alıyordu → 406.
2. **Abonelik ek porsiyonu.** `quantity_override` o günün TOPLAMI; ek
   porsiyonu oraya doğrudan yazmak 100 kişilik aboneliği 10'a düşürürdü.
   Ayrıca sipariş + istisna birlikte yazılınca aynı yemek iki kez pişerdi —
   ek porsiyon ayrı bir eyleme alındı, sipariş açmıyor.
3. **OTP bekleme süresi hiç çalışmıyordu.** `created_at` UTC yazılıp
   Istanbul olarak okunuyordu; üç saatlik kayma 60 saniyelik sınırı sessizce
   devre dışı bırakıyordu.
4. **Tahsilat makbuzu.** İlk tasarımda makbuz numarası CRC32'lenip
   `reference_id` yapılıyordu; çakışmada `insertOrIgnore` ikinci tahsilatı
   sessizce yutardı. Numara artık sayısal ve doğrudan kullanılıyor, kayıttan
   önce `hasEntry` ile bakılıyor.
5. **Abonelik gün atlamada geri bildirim yoktu.** E2E testi yakaladı;
   kart artık "Değişiklik kaydedildi" diyor.

### Sunucuda koşturulacak göçler (3 adet)

```bash
cd platform
php artisan igniter:up
vendor/bin/phpunit --testsuite Veykemtu   # 273 test
```

`2026_08_13_000001` (cari limit), `2026_08_13_000002` (cari ödeme niyeti),
`2026_08_13_000003` (giriş kodları).

### Yeni `.env` girdileri

`NETGSM_USERNAME`, `NETGSM_PASSWORD`, `NETGSM_HEADER` — **üçü birden dolu
değilse SMS gönderilmez**, kod yalnızca sunucu günlüğüne yazılır ve
e-posta + parola girişi çalışmaya devam eder.

`SITE_PUBLIC_URL` (web konteyneri) — api.* köküne düşen isteklerin
yönlendirileceği adres.

### Test komutu tuzağı

`php artisan test` bu projede bazen yalnızca `Unit` paketini koşuyor (bir
seferinde 227, sonrakinde 1 test). Güvenilir komut:

```bash
vendor/bin/phpunit --testsuite Veykemtu
```

## 8.8 Fiş sadeleştirme turu — K-20 (14.08.2026)

Tek şikâyet: **"fazla fiş çıkıyor, kafa karıştırıcı."** Sahadaki sayım
şikâyeti doğruluyordu — adrese gönderim başına üç kâğıt, iki kez düzenlenmiş
siparişte yedi kâğıt. Tezgâhta aynı siparişin birkaç kâğıdı birikiyor ve
hangisinin güncel olduğu kâğıda bakarak anlaşılmıyordu.

| Kimlik | İş | Durum |
|---|---|---|
| K-20 | **Kurye fişi müşteri fişine katlandı** (otomatik tetiği kalktı, elle yeniden basım kaldı); **revizyonda tek güncel kâğıt** + 20 sn birleştirme penceresi; mutfak fişine `GÜNCEL FİŞ / REVİZE #N` bandı; girişsiz **imzalı takip** sayfası; **teslim ettim QR'ı**; `PrintJob` ve `requeue` revizyon körlüğü düzeltmeleri | **Bitti** |

**Kâğıt sayımı — öncesi / sonrası**

| Senaryo | Önce | Sonra |
|---|---|---|
| Gel-al, düzenlenmemiş | 2 | 2 |
| Adrese gönderim, düzenlenmemiş | 3 | **2** |
| Adrese gönderim, 2 revizyon | 7 | **2** (aynı pencerede) / 4 (ayrı pencerelerde) |

### Turda yakalanan hatalar

1. **Takip QR'ı giriş duvarına çarpıyordu.** K-18 bağlantıyı
   `<FRONTEND_URL>/siparis/<id>` olarak üretiyordu; o rota `middleware.ts`
   matcher'ında ve `requireSession` ile korunuyor. Yani fişteki kareyi okutan
   müşteri sipariş durumunu değil `/giris` ekranını görüyordu. Özellik
   yazıldığı günden beri çalışmıyordu ve kimse fark etmemişti.
2. **Ödeme QR'ı üretimde ölü bir adrese gidiyordu.** `veykemtu/payment`
   simülasyon rotalarını `POS_ALLOW_SIMULATION` tanımsız üretimde **hiç
   kaydetmiyor**, ama `ReceiptBuilder::payUrl()` bu kontrolü yapmıyordu.
   Okutan müşteri Caddy'nin 308'i sayesinde ana sayfaya düşüyordu.
3. **`PrintJob` revizyon körü.** Tekillik `(order_id, type)` olduğu için
   revizyon `ack`'i sessizce yutuluyor ve yeniden basılan kâğıt, yerini
   aldığı eski kâğıdın saatiyle damgalanıyordu — "GÜNCEL FİŞ" bandının
   çözdüğü sorunun aynısını zaman damgası üretiyordu.
4. **"Yeniden bas" iki kâğıt çıkarıyordu.** `PrintQueue.requeue` revizyon
   süzgeci ve satır sınırı olmadan çalışıyordu: tek dokunuş o tipin **her**
   revizyon satırını basılmamışa çeviriyordu — tam da K-17'nin
   `dropSuperseded` ile engellediği hata, elle tetiklenen yoldan geri
   geliyordu.
5. **Ödeme dönüşü kırılacaktı.** Sanal POS denetleyicileri dönüş adresine
   `.'?durum=odendi'` diye **düz birleştirme** yapıyordu. Bugün çalışıyordu
   çünkü `/siparis/{id}` sorgusuz; imzalı takip adresi `?e=…&s=…` taşıdığı
   anda ikinci bir `?` girip `durum`u okunamaz kılacaktı. Değişiklik bu
   hatayı **üretecekti**, aynı turda düzeltildi.
6. **`/cari-odeme-simulasyon/*` Caddy izin listesinde yoktu** — cari borç
   ödeme sayfası üretimde ana siteye yönleniyordu. K-20 ile ilgisiz, aynı
   satıra dokunulurken görüldü ve düzeltildi.

### Açık kalan — DONANIM

`docs/10` §"QR AÇIK MADDE" hâlâ kapanmadı: fişteki konum QR'ı sahada kâğıda
çıkmıyor ve sebebi bilinmiyor (siparişte iğne yok mu, yoksa yazıcı `GS ( k`
komutunu sessizce yutuyor mu). Yeni teslim QR'ı aynı komuta dayanıyor.

**Sahaya çıkmadan `cd mutfakapp && dart run tool/yazici_teshis.dart`
koşulmalı.** Yalnız C bölümü çıkıyorsa yazıcı yerleşik QR'ı desteklemiyor
demektir ve QR'lar `qr` paketi + `EscPosBuilder.bitImage` ile raster
çizilmek zorunda — ayrı ve daha büyük bir iş. Birleştirme ve revizyon
düzeltmesi o karardan bağımsız çalışıyor.

### Sunucuda koşturulacak

```bash
cd platform
php artisan igniter:up          # veykemtu_print_jobs.revision göçü
vendor/bin/phpunit --testsuite Veykemtu
```

**Yeni `.env` girdisi:** `BLD_LINK_SECRET` (boşsa `APP_KEY`'e düşer; üretimde
ayrı tanımlanmalı — `APP_KEY` döndürüldüğünde oturumlar da geçersiz olur).

**Dağıtım öncesi:** `infra/Caddyfile.internal` izin listesine `/teslimat/*`
eklendi; güncellenmiş dosya dağıtılmazsa teslim QR'ı ana siteye 308'lenir.

## 8.7 Fiş ve harita turu — K-17 … K-19, W-15 … W-16 (12.08.2026)

Üç şikâyet: "eski fişler asla çıkmamalı", "konum QR'ı yok", "web sitesi
mobil uygulamanın gerisinde".

| Kimlik | İş |
|---|---|
| K-17 | **Eskimiş fiş kuyruktan düşüyor.** Sipariş düzenlenince yeni sürüm kuyruğa girerken aynı siparişin aynı türdeki basılmamış eski işleri siliniyor (`PrintQueue.dropSuperseded`) |
| K-18 | Müşteri fişine **sipariş takip QR'ı** (`track_url`) |
| K-19 | Müşteri fişine **ödeme QR'ı** (`pay_url`) — ödenmiş siparişte basılmaz |
| W-15 | **Adres defteri**: `/hesabim/adresler` + ödeme adımında kayıtlı adres seçimi |
| W-16 | **Haritadan konum seçimi** (Leaflet + OSM), hizmet alanına kilitli |

### Turda yakalanan hatalar

1. **`FRONTEND_URL` hiçbir yerde tanımlı değildi.** İki ödeme denetleyicisi
   de `config('app.frontend_url')` okuyordu ama değişken ne
   `.env.example`'da ne `docker-compose.coolify.yml`'de vardı. Canlıda ödeme
   dönüşü API köküne düşüyordu ve I-07'den sonra orası ana sayfaya 308
   veriyor — müşteri ödedikten sonra siparişini göremiyordu. K-18/K-19 aynı
   değeri kullandığı için hata bu turda ortaya çıktı.
2. **Site hiç koordinat toplamıyordu.** Kurye fişindeki harita QR'ı K-14'ten
   beri hazırdı ama yalnız iğne varken basılıyor; mobil iğne alıyor, site
   almıyordu. Yani "siteden gelen her sipariş QR'sız" — arayüz eksiği gibi
   görünen bir boşluk kuryeye kadar uzanıyordu. W-16 bunu kapattı.
3. **Kuyrukta silme sırası.** İlk taslak önce siliyor sonra ekliyordu; iki
   işlem arasında çöken kasa o sipariş için kuyrukta **sıfır** iş bırakırdı.
   Sıra ters çevrildi: en kötü ihtimalde fazladan bir fiş basılır.

## 8.9 Günün menüsü turu — B-19 (13.08.2026)

İşletme sahibinin kararı: **satış artık katalogdan değil, GÜNÜN MENÜSÜ
üzerinden.** Yönetici takvimden gün gün menü giriyor; o gün yalnız o menü
satılıyor — paket olarak ya da içindeki ürünler tek tek. Katalog listeleme
ve ürün detayı web ile mobilden kalkıyor, ürün KAYITLARI duruyor: onlar artık
günün menüsünün kalemleri.

### Katman 1 — Admin paneli: aylık menü takvimi

Turun kilit taşı. **Menü girilmeden ne web ne mobil sınanabilir**, bu yüzden
ilk çıktı bu ekran.

| Dosya | İş |
|---|---|
| `src/Http/Controllers/Admin/DailyMenus.php` | Ay ızgarası + beş AJAX işleyicisi |
| `resources/views/dailymenus/index.blade.php` | Ekran, kopyalama ve toplu işlem kartları, gün tablosu (JSON) |
| `resources/views/_partials/dailymenus/month_grid.blade.php` | Yedi sütunlu ay ızgarası, gün kutusu, rozetler |
| `resources/views/_partials/dailymenus/day_editor.blade.php` | Tek `<dialog>`, otuz bir gün; kalem satırı `<template>`'i |
| `resources/css/dailymenu.css` | Yalnız bu ekranda yüklenen düzen (admin.css'e dokunulmadı) |
| `resources/lang/{tr,en}/dailymenu.php` | 120 anahtar, iki dilde birebir |
| `src/Admin/AdminRegistrar.php` | `Veykemtu.DailyMenu` yetkisi + "Restoran" grubunda priority 88 |

**Çekirdeğin `ListController`/`FormController`'ı KULLANILMADI.** Burada
kaydedilen şey tek bir model değil: bir gün kaydı, N kalem satırı, kopyalama
semantiği ve toplu durum değişimi birlikte yaşıyor. Ayrıca ekranın birincil
görünümü bir liste değil, bir AY IZGARASI — yönetici "18 Ağustos'ta ne var"
sorusunu satır satır bir listede değil, takvimde cevaplıyor. Kalıp
`PhoneOrders` ile aynı ve gerekçesi orada da yazılı.

**Yetki SEKİZİNCİ ayrı kutu.** Bu ekran şirketin ne satacağına ve hangi
fiyata satacağına karar veriyor. Sipariş görüntüleme yetkisiyle aynı kutuya
konsaydı, siparişlere bakabilen herkes gelecek ayı yeniden fiyatlandırabilirdi.

### ÜÇ KURAL

1. **Kopya her zaman TASLAK olarak düşer** (`DailyMenus::copyDay()`),
   kaynak yayında olsa bile. Bir ayı kazara yayına almak, `status` alanının
   var olma sebebi olan sızıntının ta kendisi: yarım girilmiş bir perşembe
   kopyalandığı anda müşteriye görünür ve pişmeyecek bir yemek satılır.

2. **Kapalı günler her zaman atlanır**, `overwrite` verilse bile.
   `DailyMenuService::verdict()` kapalı günü her şeyin önünde tutuyor;
   kopyanın oraya menü yazması, ızgarada "yayında" görünen ama satılamayan
   bir gün üretirdi — yani yöneticinin emeğini boşa harcardı.

3. **Siparişi olan gün kilitli.** `package_price_kurus`, `status` ve kalem
   satırları donar; başlık, açıklama ve iç not düzenlenebilir kalır
   (kozmetik, üstelik sipariş satırındaki ad `orderLineName()` ile zaten
   kopyalanmış). **Gerekçe:** `OrderEditor` paketi gün satırından YENİDEN
   fiyatlıyor. Sipariş varken fiyat değiştirilseydi, yalnızca notu düzelten
   bir revizyon siparişi sessizce yeniden fiyatlandırır ve cari deftere
   uydurma bir iade/ek ücret yazardı — üstelik defter revizyon başına
   idempotent olduğu için **kendiliğinden düzelmez**.
   İptal edilmiş sipariş günü kilitlemez: iptal cari borcu ters kayıtla
   nötrledi ve durum makinesi iptal edilmiş siparişin revizyonuna izin
   vermiyor. Sayılsaydı tek bir iptal o günü sonsuza kadar kilitlerdi.

Kopyalama ve toplu işlem **atladığı her günü sebebiyle raporlar**
("5 gün kopyalandı, 2 gün atlandı: 18.08 kapalı gün, 20.08 siparişi var").
İstenenden azını sessizce yapan bir kopya, reddeden bir kopyadan kötüdür:
yönetici atlanan günün menüsüz kaldığını ancak o sabah öğrenir.

### Turda yakalanan hatalar

1. **Menü kalemleri yanlış sırada okunuyordu — ve bu sıra KALICI OLARAK
   BOZULUYORDU.** `veykemtu_daily_menu_items` üzerinde
   `(daily_menu_id, menu_id)` tekil indeksi var; MySQL sırasız bir okumada
   kalemleri o indeksten, yani **ürün kimliği sırasında** getiriyor. Ekleme
   sırası gibi görünen şey aslında ürün kimliği sırasıydı ve sonradan
   kataloğa eklenmiş bir çorba listenin altına düşüyordu. Panelde bu yalnız
   kozmetik değil: gün düzenleyici kalemleri o sırayla çiziyor ve kaydet'e
   basıldığı anda `sort_order` **o yanlış sırayla** yeniden yazılıyor —
   yöneticinin girdiği sıra geri dönülemez biçimde kayboluyordu. Sıra artık
   `DailyMenu::$relation` içinde (`'order' => ['sort_order asc', 'id asc']`);
   okuma yerlerine dağıtılmış bir sıralama, unutulan ilk okumada sessizce
   bozuluyor. Çekirdeğin tanıdığı anahtar `'order'`; daha önce denenen
   `'sort'` **sessizce yok sayılıyor**
   (`Flame\Database\Relations\DefinedConstraints`).
2. **Flash mesajının oturum anahtarı tahmin edilmişti.** Testler Laravel
   dünyasının alışıldık `flash_notification` anahtarını okuyordu; TastyIgniter
   ise anahtarı çalışma bağlamına göre seçiyor
   (`System\ServiceProvider::resolveFlashSessionKey` → panelde
   `flash_data_admin`). Kopyalama raporu yazılmıştı, yalnız başka bir
   kutudaydı ve testler "rapor hiç üretilmiyor" diye kırmızıydı.
3. **Ay sonunda kırılacak bir test.** Toplu işlem testi ayı `now()`'dan,
   siparişli günü `now()+1`'den türetiyordu; ayın son gününde sipariş
   sonraki aya düşer ve toplu işlem onu hiç görmezdi. Ay artık siparişli
   günden türetiliyor.

### Çekirdek tuzağı — işleyici imzası

`AdminController::processHandlers()` işleyiciyi `[$this->action, ...$params]`
ile çağırıyor: **ilk argüman her zaman bağlam adıdır.** Tek parametreli
yazılan `onXxx(?string $date)` `"index"` alır ve ekran sebebi anlaşılmayan
bir 406 döner (B-14'te sahada oldu). Bu ekranın beş işleyicisi de
`(string $context, ?string $recordId = null)` ile başlıyor ve
`AdminDailyMenuTest::test_her_isleyici_baglam_argumaniyla_baslar` bunu
yansımayla kilitliyor.

İkinci tuzak: para alanları `type="text"`, `number` **değil** — çekirdek
number postback'ini `(int)`'e daraltıp kuruşu yiyor (`LiraField` docblock'u).

### Doğrulama

```bash
cd platform
vendor/bin/phpunit --testsuite Veykemtu   # 353/353
```

Yeni göç **yok**: takvim ekranı B-19'un backend turunda açılan
`veykemtu_daily_menus` / `veykemtu_daily_menu_items` tablolarını kullanıyor.
Menü kaydedilince ve yayına alınınca `SiteRevalidator` sitenin ISR
önbelleğini tazeliyor — yönetici yarınki menüyü akşam giriyor ve bir sonraki
ISR turuna kadar eski menü kalırsa müşteri var olmayan bir yemeği sipariş
etmeye çalışır.

## 8.10 Abonelik `menu_mode = daily_menu` — nihayet çalışıyor (14.08.2026)

`docs/11` §7.5'te "Ertelenen" diye duran mod açıldı. Erteleme gerekçesi
("günün menüsü kaynağı yok") B-19 ile ortadan kalkmıştı;
`veykemtu_daily_menus` o kaynağın kendisi.

### Asıl kilit formdaydı, kodda değil

`OrderFactory` daily_menu'yü açıkça reddediyordu ve `SubscriptionController`
modu `fixed_list`'e zorluyordu — ama ikisi düzeltilse bile mod
**seçilemiyordu**: `resources/models/subscription.php` içinde `menu_mode`
form alanı hiç yoktu. `Subscriptions::formExtendModel` içindeki
`$model->menu_mode ??= MENU_FIXED_LIST` yalnızca varsayılanı yazar; formda
alan bulunmayınca her kayıt `fixed_list` doğar. Alan artık `radiotoggle`
olarak **yalnız oluşturma bağlamında** var (menü kaynağı sözleşmenin kendisi;
çalışan bir aboneliğinkini değiştirmek takvimini değiştirmekle aynı şey) ve
ürün satırı repeater'ı `trigger` ile `fixed_list`'e bağlı.

`trigger` yalnızca **gizler**; alan DOM'da kalır ve doluysa gönderilir. Bu
yüzden `formAfterCreate` daily_menu'de satırları yazmadan dönüyor ve API ucu
daily_menu + `lines` birleşimini 422 ile reddediyor — iki içerik kaynağı,
panelde gerçekle çelişen bir liste demekti.

### Şekil, tek seferlik siparişle aynı olmak zorunda

Abonelik siparişi de fiyatlı bir `role = "package"` üst satırı + sıfır
fiyatlı `role = "component"` satırları olarak yazılıyor. Sebep kozmetik
değil: `ProductionListService`, `SubscriptionKitchenPlan::totals` ve
`OrderPresenter::kitchenItems` üçü de `bld_line_role != 'package'`
süzgecini kullanıyor. Bileşenler üst satırsız yazılsaydı süzgeç abonelikte
hiçbir şey elemez, mutfak şeridi iki kaynaktan iki farklı şekil görürdü.

Fiyat **her iki modda da** `agreed_unit_price_kurus` ve daily_menu'de de
zorunlu: sözleşme "o gün ne pişerse pişsin porsiyonu şu kadar" der. Günün
`package_price_kurus` değeri hiç okunmuyor — o gün vitrinde paket
satılmasa bile abonelik üretimi koşar.

### Menü yoksa: gürültü değil, tek satır

`veykemtu:abonelik-uret` hedef gün için daily_menu aboneliği varken
yayınlanmış menü yoksa **vitrin başına tek** hata satırı basar (abonelik
başına bir yığın izi değil), o abonelikleri üretime hiç sokmaz ve `FAILURE`
döner. `veykemtu_subscription_runs` satırı yazılmadığı için menü
yayınlandıktan sonra komut yeniden koşturulunca sipariş doğar; UNIQUE kısıtı
tek sipariş garantisini korur.

Aynı durum iki yerde daha görünüyor:

* `SubscriptionKitchenPlan::warnings` → `kind = 'not_generated'`. **Yeni bir
  tür uydurulmadı**: `mutfakapp/lib/src/data/subscription_plan.dart` içinde
  `isCritical => kind == 'not_generated'` sabit kodlu; yeni tür mavi/bilgi
  olarak çizilirdi ve "yarınki 400 porsiyonun menüsü yok" alarmdır.
* Gösterge panelindeki BLD kutusu → önümüzdeki yedi günün menüsü olmayan
  günleri **adlarıyla**. Gece üretimi 22:00'de yarın için koşuyor; uyarıyı
  kimsenin izlemediği ikinci bir cron'a bağlamak yerine yöneticinin zaten
  her sabah baktığı yere koymak, görülme ihtimalini tek başına belirliyor.
  Kapalı günler elenir — bayramda menü olmaması eksiklik değil, kararın
  kendisi.

### Doğrulama

```bash
cd platform
vendor/bin/phpunit --testsuite Veykemtu   # 368/368
```

Yeni göç **yok**. Sözleşme additive: `SubscriptionCreate.menu_mode`
(gönderilmezse `fixed_list`, eski davranış birebir korunur).

## 8.11 Akıllı adres — B-21 backend (14.08.2026)

Adres bugüne kadar tek bir serbest metindi (`address_1`). Kurye onu okuyordu
ama sistem hiçbir parçasını bilmiyordu. B-21 iki şey ekliyor: adresin
**parçalanmış hâli** ve o parçaları dolduran bir **geocoder**.

| Kimlik | İş | Durum |
|---|---|---|
| B-21 | `addresses` tablosuna beş yapılandırılmış sütun; `Geocoding` sürücü katmanı (OSM/Nominatim + sahte); `GET /addresses/suggest` ve `/addresses/reverse`; defter + sipariş uçlarında kabul/kopyalama/yanıt | **Bitti** |

### Sürücü arayüzü, sağlayıcıdan önce

`Services/Geocoding/Geocoder` üç metot: `suggest`, `reverse`, `name`.
Bugünkü gerçeklemesi `NominatimGeocoder` — anahtar istemiyor, faturası yok.
`docs/11` §F2-01 Google Places'i planlıyor; o gün değişecek tek yer
`Extension::registerGeocoder()` içindeki tek satır olmalı. Bu yüzden
**sürücü hizmet alanını bilmez**: kutuya göre eleme, kanonik ilçe yazımı,
önbellek ve arıza yutma `AddressLookup` içinde. Sürücüye konsaydı her yeni
sağlayıcı aynı kuralı baştan uygulamak zorunda kalırdı.

### Türkiye'ye özgü tuzak — `city` şehir değil

Nominatim'in Konya yanıtı (ölçüldü, tahmin edilmedi):

```json
{"suburb":"Feritpaşa Mahallesi","city":"Konya","town":"Selçuklu","province":"Konya"}
```

Yani **mahalle `suburb`'te, ilçe `town`'da** ve `city` büyükşehrin kendisi.
"city = şehir, suburb = ilçe" diye okuyan sezgisel eşleme her öneriyi
"Feritpaşa Mahallesi" ilçesine düşürür, hizmet alanı elemesinden geçemez ve
öneri kutusu **hep boş** görünür — hata da vermez.

### Arıza sipariş akışını durdurmaz

Sağlayıcı çökerse `/suggest` `200` + boş liste, `/reverse` `200` + `null`
döner; ayrım yalnızca sunucu günlüğüne yazılır. `5xx` dönseydi dışarıdaki
bir servisin bizim ödeme ekranımızı kapatabilmesi demek olurdu — oysa öneri
bir **kolaylık**, adres elle de yazılabiliyor. Tek istisna ters
geocoding'de kutu dışı nokta: orada `422` +
`details.reason = "out_of_service_area"`, çünkü kullanıcı haritayı gördü ve
teslimat yapmadığımız bir yeri **kasten** seçti.

Eleme hem kutuya hem ilçe adına bakıyor: kutu (37.80–38.10 / 32.35–32.75)
Meram'ı da içine alan kaba bir dikdörtgen. Kutu dışı aday listeye hiç
girmez — "teslimat yok" diye işaretlenip gösterilmez.

### `line1` zorunlu kalır ama artık türetilebiliyor

`line1`'i isteğe bağlı yapmak sözleşmeyi kırardı: fiş, kurye ekranı ve
sahadaki istemci sürümleri yalnız onu okuyor. Tek gevşeme
`required_without_all:neighbourhood,street,building_no` — yeni form
parçaları gönderdiğinde cümleyi **sunucu** kuruyor
(`StructuredAddress::compose`, "Feritpaşa Mah. Kültür Sk. No:12/A Kat:3
Daire:7"). Kat ve daire de cümleye giriyor: kurye adresi arar değil OKUR.
Gönderilen `line1` **aynen korunuyor** — her zaman türetilseydi "mavi
kepenkli dükkân" gibi kuryenin gerçekten kullandığı tarifler silinirdi.

Beş alan `latitude`/`longitude` ile aynı güncelleme kuralını izliyor:
`null` göndermek siler, hiç göndermemek korur. Koordinat çiftinin aksine
**birbirinden bağımsız** — kat bilinip daire bilinmemesi olağan.

### Yeni `.env` girdileri

```
GEOCODER_CONTACT=     # OSM kullanım şartı: User-Agent'ta iletişim adresi. Boşsa APP_URL.
GEOCODER_URL=         # Boşsa https://nominatim.openstreetmap.org
```

Genel Nominatim sunucusu **saniyede 1 istek** şart koşuyor ve engel SESSİZ
oluyor (öneri kutusu boş açılır, hata görünmez). Trafik büyüdüğünde doğru
hamle oran sınırını yükseltmek değil, `GEOCODER_URL` ile kendi örneğimize
geçmek. Yük ayrıca 24 saatlik sunucu önbelleğiyle ve `bld-adres` sınırıyla
(30/dk, **hesap** başına — IP başına olsaydı tek NAT arkasındaki ofis
çalışanları birbirini kilitlerdi) tutuluyor.

### Sunucuda koşturulacak göç (1 adet)

```
2026_08_16_000001_add_structured_address_columns
```

`addresses` tablosuna `bld_neighbourhood`, `bld_street`, `bld_building_no`,
`bld_floor`, `bld_door_no`. Hepsi nullable ve hepsi metin (`12/A`, `Zemin`
sahada yaygın). **Eski satırlar ayrıştırılmıyor**: geriye dönük bir regex
satırların çoğunda çalışır, azında çalışmaz — ve çalışmadığı her satırda
kuryeyi yanlış kapıya götürür.

### Doğrulama

```bash
cd platform
vendor/bin/phpunit --testsuite Veykemtu   # 388/388
```

`tests/Feature/AddressSuggestTest.php` (20 test) sahte sürücüyle koşuyor,
`Http::fake()` ile değil: sahte HTTP gövdesi Nominatim'in biçimini teste
kopyalar ve sürücü değiştiği gün testler sağlayıcıya göre yeniden yazılmak
zorunda kalırdı. Doğrulanan şey uygulama davranışı — eleme, önbellek, hata
yutma, kopyalama.

## 9. Kapsam kesme sırası (takvim sıkışırsa)

Sırayla feda edilir:
1. SMS eklentisi (`veykemtu/sms`) — push yeterli
2. Müşteri app'in Play üretim yayını — kapalı test yeterli, web canlıda
3. Sipariş geçmişi ekranları (web + mobil)
4. Gel-al (`pickup`) akışı — Faz 1'de yalnızca adrese gönderim ile çıkılabilir

**Asla feda edilmeyecekler:** sipariş oluşturma, KDS'e düşme, mutfak fişi basımı, durum geçişleri. Bunlar olmadan sistem canlıya alınamaz.

## 10. Günlük ritim

Her gün sonunda her ajan şunu rapor eder:
- Tamamlanan görev kimlikleri
- Açılan PR'lar
- Engelleyiciler (kimden ne bekliyor)
- Yapılan varsayımlar (`// VARSAYIM:` yorumlarının listesi)

Engelleyiciler ertesi gün ilk iş çözülür; varsayımlar dokümana işlenir veya reddedilir.
