# 01 — Mimari

## 1. Sistem şeması

```
                          İNTERNET
                              │
                  ┌───────────┴────────────┐
                  │  Hetzner VPS (Ubuntu)  │
                  │  ┌──────────────────┐  │
                  │  │  Caddy (TLS)     │  │
                  │  └───┬──────────┬───┘  │
                  │      │          │      │
                  │  ┌───┴────┐ ┌───┴────┐ │
                  │  │Platform│ │Website │ │
                  │  │PHP/TI  │ │Next.js │ │
                  │  │+ Admin │ │  SSR   │ │
                  │  └───┬────┘ └────────┘ │
                  │  ┌───┴────┐ ┌────────┐ │
                  │  │ MySQL  │ │ Reverb │ │
                  │  └────────┘ │  (WS)  │ │
                  │             └────────┘ │
                  └───────┬────────────────┘
                          │
          ┌───────────────┴───────────────┐
          │                               │
   ┌──────┴───────┐              ┌────────┴─────────┐
   │ musteriapp   │              │    mutfakapp     │
   │ Flutter/     │              │ Flutter Linux    │
   │ Android      │              │ MSI kasa·Ubuntu  │
   │              │              │        │         │
   │ REST + FCM   │              │  WS/polling      │
   └──────────────┘              │        │         │
                                 │  USB ESC/POS     │
                                 │        ▼         │
                                 │  Termal yazıcı   │
                                 └──────────────────┘
```

## 2. Bileşen sınırları

**Kim kiminle konuşur:**

| Kaynak | Hedef | Protokol | Amaç |
|---|---|---|---|
| `website/` | `platform/` | HTTPS REST | Menü, sipariş oluştur, sipariş takip |
| `musteriapp/` | `platform/` | HTTPS REST | Aynı |
| `platform/` | `musteriapp/` | FCM Push | Durum bildirimi |
| `mutfakapp/` | `platform/` | HTTPS REST (polling) / WebSocket | Sipariş çek, durum güncelle |
| `platform/` | `mutfakapp/` | WebSocket (Reverb) | Yeni sipariş yayını |
| `mutfakapp/` | Yazıcı | USB / ESC-POS | Fiş basımı |
| Admin panel | `platform/` | Aynı süreç | — |

**Kim kiminle KONUŞMAZ:** İstemciler birbirleriyle doğrudan konuşmaz. `website/` MySQL'e doğrudan bağlanmaz. `mutfakapp/` internet üzerinden dış servise çıkmaz (yalnızca kendi backend'i).

---

## 3. Mimari Kararlar (ADR)

### ADR-01 — Çekirdek platform: TastyIgniter

**Karar.** Sipariş çekirdeği, menü yönetimi ve admin paneli TastyIgniter'dan (MIT, Laravel tabanlı) gelir. Özelleştirme yalnızca `extensions/` ve `themes/` katmanında yapılır.

**Gerekçe.** Menü/sipariş/müşteri/ödeme/panel yeniden yazılmayacak kadar standart problemler. Ekip Bagisto ile aynı modeli (hazır platform + markalama) daha önce uygulamış.

**Elenenler.** Sıfırdan NestJS monolit (admin panelini de yazmak gerekirdi, 1 haftalık takvime sığmaz); Next.js tabanlı hazır repolar (ekosistemde olgun/bakımlı bir eşdeğer yok, çıkanlar eğitim projesi); Odoo (yabancı ekosistem, zayıf müşteri sipariş deneyimi).

**Sonuç.** Backend dili PHP olur. Gerçek zamanlılık ayrıca çözülür (ADR-05). Çekirdeğe dokunmama kuralı (ADR-02) bu kararın ön koşuludur.

### ADR-02 — Çekirdeğe dokunmama kuralı

**Karar.** `platform/vendor/` altındaki hiçbir dosya değiştirilmez. Davranış değişikliği yalnızca `platform/extensions/veykemtu/*` altında, Laravel'in event/hook mekanizmalarıyla yapılır.

**Gerekçe.** Platform sürüm yükseltmesinin `composer update` + migration'dan ibaret kalmasının tek güvencesi budur. Çekirdeğe sızan tek "geçici" düzeltme, bir yıl sonra yükseltmeyi imkânsızlaştırır.

**Uygulama.** CI'da `platform/vendor/` diff kontrolü; değişiklik varsa build kırmızı.

### ADR-03 — Müşteri web sitesi ayrı Next.js uygulaması

**Karar.** Müşteri vitrini TastyIgniter temasıyla değil, ayrı bir Next.js 15 uygulamasıyla yapılır; platform API'sinden beslenir.

**Gerekçe.** SEO, ilk yükleme performansı ve marka esnekliği. Ayrıca admin panelini platformdan bedavaya alırken vitrini istediğimiz stack'te tutmuş oluruz.

**Sonuç.** `platform/` yalnızca API + admin sunar; müşteriye görünen HTML'i Next.js üretir. Ortak sözleşme `docs/03-api-sozlesmesi.md`.

### ADR-04 — Mutfak ekranı: Flutter Linux desktop (Android iptal)

**Karar.** KDS yalnızca **Ubuntu 24.04 üzerinde Flutter Linux desktop** uygulaması olarak çalışır. Android tablet planı iptal edilmiştir. `mutfakapp/` içinde Android hedefi bulunmaz.

**Gerekçe.** Mutfakta MSI kasa + monitör var; tek güçlü cihazda tek uygulama, iki cihaz yönetmekten basit. Linux'ta USB yazıcı erişimi Android'den kolay: cihaz `/dev/usb/lp0` olarak görünür, ham byte yazmak yeterli, izin diyaloğu yok.

**Sonuç.** Kiosk davranışı systemd + autostart ile sağlanır (ADR-06). Uygulama güncellemesi mağaza gerektirmez; `.deb`/AppImage veya doğrudan `git pull + build` ile yapılır.

### ADR-05 — Gerçek zamanlılık: polling önce, WebSocket sonra

**Karar.** KDS Faz 1'de 5 saniyelik **artımlı polling** (`GET /api/kitchen/orders?after=<id>`) kullanır. Faz 1.5'te Laravel **Reverb** WebSocket devreye girer; polling kodda yedek mekanizma olarak kalır.

**Gerekçe.** Polling ilk günde çalışır ve 1 haftalık takvimi riske atmaz. Tek mutfaklı yükte 5 sn'lik sorgu sunucuya yük değildir.

**Uygulama zorunluluğu.** KDS'in veri katmanı `OrderSource` arayüzü ile yazılır; `PollingOrderSource` ve `WebSocketOrderSource` aynı arayüzü uygular. Faz 1.5 geçişi tek satırlık bağımlılık değişimidir.

### ADR-06 — Kasa kiosk davranışı

**Karar.** Ubuntu kasada: otomatik login, `systemd --user` servisi ile uygulama açılışta başlar, uygulama tam ekran ve daima önde, ekran uykusu ve kilit kapalı, çökerse `Restart=always` ile yeniden başlar.

**Gerekçe.** Elektrik kesintisinden sonra kimsenin müdahale etmesi gerekmemeli.

### ADR-07 — Yazdırma: uygulama içinden USB ESC/POS + kalıcı kuyruk

**Karar.** CUPS ve sistem yazdırma yığını kullanılmaz. Uygulama ESC/POS baytlarını doğrudan yazıcı cihaz dosyasına yazar. Her yazdırma işi diske kalıcı kuyruğa alınır; başarısızsa geri çekilmeli tekrar dener.

**Gerekçe.** Sürücü/spooler karmaşası olmadan tam otomatik basım. Kuyruk, "yazıcı kapalıydı, fiş kayboldu" senaryosunu ortadan kaldırır.

**Zamanlama.** Mutfak fişi `yeni` durumunda; müşteri fişi `hazir` durumunda basılır.

### ADR-08 — Kimlik: cihaz token'ı ve kapsam ayrımı

**Karar.** Müşteri hesapları platformun hesap sistemindedir (JWT/Sanctum). KDS'in kullanıcı hesabı yoktur; admin panelinden üretilen tek kullanımlık eşleme koduyla **cihaz kaydı** yapar ve `kitchen` kapsamlı, iptal edilebilir bir token alır.

**Gerekçe.** Kasa çalınır/el değiştirirse tek tıkla iptal. Mutfak token'ı fiyat, müşteri verisi veya rapor uçlarına erişemez.

### ADR-09 — API geriye uyumluluk

**Karar.** API yalnızca eklemeli evrilir. Alan silinmez, tipi/adı değişmez. Kırıcı değişiklik gerekirse `/api/v2/` açılır. Her istemci `X-App-Id` ve `X-App-Version` başlığı gönderir.

**Gerekçe.** İstemciler bağımsız güncellenir; sahada her an farklı sürümler bulunur.

### ADR-10 — Tek repo (monorepo)

**Karar.** Tüm bileşenler tek git reposunda. Dart tarafı pub workspace ile bağlanır. CI path filtresiyle sadece değişen bileşeni derler.

**Gerekçe.** API sözleşmesi değiştiğinde platform + istemciler tek commit'te güncellenir; uyumsuzluk derleme anında yakalanır.

---

## 4. Repo yapısı

```
catering/
├── AGENTS.md                    # ajan kuralları — önce bu okunur
├── README.md
├── CLAUDE.md → AGENTS.md        # sembolik bağ; ajan aracı otomatik okur
├── docs/                        # bu doküman seti
│   └── openapi.yaml             # NORMATİF sözleşme (OpenAPI 3.1)
├── platform/                    # TastyIgniter (backend + admin)
│   ├── composer.json
│   ├── extensions/veykemtu/
│   │   ├── bridgeapi/           # KDS ve istemci API uçları
│   │   ├── push/                # FCM
│   │   ├── sms/                 # Netgsm
│   │   ├── appversion/          # sürüm/self-update ucu
│   │   └── payment/             # sanal POS (Kuveyt Türk)
│   └── themes/veykemtu-admin/   # admin markalama (minimal)
├── website/                     # Next.js 15
│   ├── app/
│   ├── components/
│   ├── lib/api/                 # üretilen API istemcisi
│   └── .env.example
├── musteriapp/                  # Flutter → Android
├── mutfakapp/                   # Flutter → Linux desktop
├── packages/
│   ├── api_client/              # Dart API istemcisi (openapi.yaml'dan)
│   ├── core/                    # durum makinesi, para/tarih, ESC/POS
│   └── design_system/           # ortak tema (BLD turuncu palet)
├── infra/
│   ├── docker-compose.yml       # prod
│   ├── docker-compose.dev.yml   # dev: mysql + platform + mock-api
│   ├── Caddyfile
│   ├── mock/                    # sözleşme mock sunucusu (X-04)
│   ├── kasa/                    # Ubuntu kasa kurulum betikleri + systemd unit
│   └── backup/
├── .github/workflows/           # path filtreli CI
└── pubspec.yaml                 # pub workspace kökü
```

## 5. Ortamlar

| Ortam | Nerede | Amaç |
|---|---|---|
| dev | Geliştirici makinesi, Docker Compose | Günlük geliştirme |
| staging | Hetzner küçük instance | Sürüm yükseltme provası, uçtan uca test |
| prod | Hetzner VPS | Canlı |

Kasa (MSI/Ubuntu) prod'a bağlanır; geliştirme sırasında `.env` ile staging'e yönlendirilebilir.
