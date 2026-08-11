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
