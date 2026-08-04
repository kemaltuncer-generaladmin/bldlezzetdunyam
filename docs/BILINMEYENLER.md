# BİLİNMEYENLER

> Ajanlar tahminle ilerlemez. Emin olunmayan her şey buraya yazılır ve TODO bırakılarak devam edilir.
> Format: `- [KOL-X][GG.AA] Soru | Etkilenen: <dosya> | Geçici çözüm: <ne yapıldı>`
> Gün 7'de bu dosya boşaltılır: her satır ya çözülür ya Faz 2 backlog'una taşınır.

## Açık

### Kol A — Platform

_(Kol A'nın açık maddesi kalmadı — B-02'nin iki mimari sorusu da karara bağlandı, aşağıya bakın.)_

## Çözülenler — B-02 doğrulaması (04.08, gerçek kurulumdan okundu)

Kurulan sürümler: **TastyIgniter core 4.3.4**, Laravel 12.64.0, PHP 8.3.33, `laravel/sanctum` 4.3.3, `ti-ext-api` 4.2.3, MySQL 8.4.11.

| Soru | Gerçek cevap |
|---|---|
| Sipariş **durum güncelleme** servisinin imzası | `Igniter\Cart\Models\Order::updateOrderStatus($id, array $options = []): StatusHistory\|false` — `Order.php:311`. Ayrı bir "sipariş oluşturma servisi" yoktur; sipariş `Order` modeli üzerinden kaydedilir. |
| Durum değişimine nasıl bağlanılır | `Igniter\Admin\EventSubscribers\StatusUpdatedSubscriber` var — çekirdeğe dokunmadan olay dinleyicisiyle bağlanılabilir (`veykemtu/push` bunu kullanacak). |
| Hangi API uçları hazır geliyor | `ti-ext-api` ile 82 rota: addresses, categories, coupons, currencies, customers, locations, location_settings, menus, menu_options, menu_item_options, orders, reservations, reviews, status, tables, users + `POST /api/token`, `GET /api/token/user`. |
| Teslimat tipi alanı | `orders.order_type`; sabitler `Igniter\Cart\Models\Order::DELIVERY = 'delivery'` ve `::COLLECTION = 'collection'`. **Bizim `pickup` değerimiz TastyIgniter'da `collection`'dır** — `bridgeapi` çevirmek zorunda. |
| Tek vitrin desteği | `.env`'de `IGNITER_LOCATION_MODE=single\|multiple` var. `single` seçildi. |
| Kurulum komutu | `php artisan igniter:install` **`--no-interaction` destekliyor** ama bu modda **admin kullanıcısı ve vitrin oluşturmuyor** — ikisi de ayrıca yapılmalı (`B-01` kalanı). |
| Alpine uyumluluğu | **Çalışmıyor.** Çekirdek `ExtensionManager.php:99` `GLOB_BRACE` kullanıyor; glibc'ye özgü, musl sağlamıyor. Taban imaj Debian'a çevrildi (`infra/platform/Dockerfile`). |

### ŞEMA UYUŞMAZLIĞI — `status_code` diye bir kolon yok

`statuses` tablosunun gerçek kolonları: `status_id`, `status_name`, `status_comment`, `notify_customer`, `status_for`, `status_color`, zaman damgaları. **Kod alanı yoktur.** `orders.status_id` bir tamsayı FK'dir.

Sonuç: `docs/02-veri-modeli.md` §4'teki üretim listesi sorgusu (`o.status_code IN (...)`) bu şemada **çalışmaz** ve düzeltildi.

Varsayılan durumlar da bizimkiler değil: `Received, Pending, Preparation, Delivery, Completed, Canceled`.

### B-02'nin iki mimari sorusu — karara bağlandı (04.08, işletme onayı)

| Soru | Karar | Uygulama |
|---|---|---|
| `ti-ext-api` 82 rotayla `/api` önekini işgal ediyor | **Devre dışı bırakıldı**, sözleşme `bridgeapi`'de sıfırdan uygulanacak | Paket çekirdeğin **zorunlu bağımlılığı** olduğu için composer'dan kaldırılamadı. Kapatma `platform/bootstrap/cache/disabled-addons.json` içindedir ve `.gitignore` istisnasıyla **commitlenir** — yoksa klonlayan ajanda geri açılırdı. Doğrulandı: `/api` rotası 0, `/admin` rotası 47 (panel sağlam). `laravel/sanctum` 4.3.3 duruyor. |
| 7 durum kodu nerede saklanacak | **`statuses` tablosuna `status_code` kolonu eklendi** | `bridgeapi` migration'ı (eklemeli, çekirdek dosyaya dokunmaz — ADR-02 ihlali değil). `veykemtu:setup` komutu 7 satırı yazar, `default_order_status`'u `yeni`ye ayarlar, vitrini ve müşteri grubunu açar. İdempotenttir. Admin panelde "Hazırlanıyor" görünür, API `hazirlaniyor` döner. |

### B-02 sırasında düzeltilen varsayımlarım

| Varsaydığım | Gerçek |
|---|---|
| `locations.location_slug` | **`permalink_slug`** |
| `setting()->set()` + `->save()` | `set()` kendisi kaydeder; ek `save()` boş satır insert edip `1062` verir |
| Eklenti meta verisi `extension.json`'da | **`composer.json` → `extra.tastyigniter-extension`** (`docs/04` §3 düzeltildi) |
| Alpine tabanlı PHP imajı yeterli | **Yetersiz** — `GLOB_BRACE` musl'da yok, Debian'a geçildi |

- [KOL-A][04.08] `igniter:install` sonrası TastyIgniter'ın kendi "Default" vitrini (#1) ve "Default group" (#1) kaydı duruyor. | Etkilenen: admin paneli görünümü | Geçici çözüm: `veykemtu:setup` bunları **silmiyor**, uyarı veriyor — silme geri alınamaz ve bağlı veri olup olmadığını komut bilemez. Yönetici admin panelden temizlemeli. API zaten yalnızca `catering` vitrinini döndürecek.
- [KOL-A][04.08] `ordering_enabled` TastyIgniter'da hangi katmana yazılacak? Vitrin (`locations`) ayarı mı, ayrı `settings` kaydı mı? | Etkilenen: `docs/03-api-sozlesmesi.md` §3, `bridgeapi` | Geçici çözüm: sözleşmede vitrin alanı olarak tanımlandı. Kurulu sürümün `locations` şeması okununca saklama yeri kesinleşir; **API sözleşmesi değişmez.**
- [KOL-A][04.08] `order_cutoff`, TastyIgniter'ın kendi çalışma saati (`working_hours`) mekanizmasıyla çakışıyor mu? `is_open` bundan mı türetilecek? | Etkilenen: `bridgeapi`, `docs/03` §3 | Geçici çözüm: `is_open` = çalışma saatinden türetilir, `ordering_enabled` = elle şalter, `order_cutoff` = ayrı alan. Üçü bağımsız tanımlandı; kod okununca sadeleşebilir.
- [KOL-A][04.08] `MenuOption.type` alanının gerçek değer kümesi nedir? Sözleşmede yalnızca `radio` örneği vardı. | Etkilenen: `docs/openapi.yaml` `MenuOption`, `website/`, `musteriapp/` | Geçici çözüm: kapalı enum **yazılmadı**, serbest string bırakıldı; bilinen değerler açıklamada. TastyIgniter'ın gerçek kümesi `B-02`'de okunup enum'a çevrilecek (ekleme değil daraltma olacağı için sözleşme değişikliği sayılır, önce burada karara bağlanmalı).
- [KOL-A][04.08] Kuveyt Türk sanal POS'un teknik dokümanı ve test hesabı elimizde yok. Entegrasyon biçimi ne (3D Secure host-to-host / hosted page)? | Etkilenen: `platform/extensions/veykemtu/payment/` | Geçici çözüm: Faz 1'de `online` hiçbir vitrinin `payment_methods` listesinde yok. Eklenti arayüzü yazılır, sağlayıcı sınıfı boş kalır.

### Kol D — Altyapı

- [KOL-D][04.08] **DNS henüz sunucuya bakmıyor.** `benimlezzetdunyam.com.tr`, `www` ve `api` adlarının hiçbiri çözülmüyor. | Etkilenen: TLS, `I-03` | Geçici çözüm: yok — Caddy sertifika alamaz. Gereken A kayıtları: `@`, `www`, `api` → `62.238.102.197`. Kayıtlar yayılmadan üretim yığını başlatılırsa Caddy sonsuz yeniden dener.
- [KOL-D][04.08] Sunucu **Ubuntu 26.04 LTS**, dokümanlar 24.04 varsayıyor (`docs/08` §1). | Etkilenen: `docs/08-kurulum-deploy.md`, `infra/docker-compose.yml` | Geçici çözüm: yığın tamamen Docker içinde çalıştığı için fark büyük ihtimalle zararsız. `I-03`'te doğrulanacak: `get.docker.com` betiği 26.04'ü tanıyor mu, `ufw`/`unattended-upgrades` paket adları aynı mı. **Kasa (MSI) ayrı bir makinedir ve orada 24.04 kararı geçerlidir** (`docs/08` §2.1) — sunucu sürümü kasayı bağlamaz.
## Çözüldü — donanım doğrulaması (04.08, gerçek yazıcıda)

`docs/09-gorev-plani.md` §8 "projenin en büyük tek donanım riski" ilan
ettiği madde **kapandı**. MSI kasada, bağlı yazıcıyla fiziksel olarak
doğrulandı:

| Soru | Cevap |
|---|---|
| Yazıcı kimliği | `0483:5720` — `aaaait Printer`, seri `11101800002` |
| Cihaz dosyası | `/dev/usb/lp1` (**`lp0` değil** — takılma sırasına bağlı, bu yüzden `/dev/thermal0` sembolik bağı şart) |
| Çekirdek modülü | `usblp`, yüklü |
| udev kuralı | Yazıldı ve kuruldu; `/dev/thermal0` → `usb/lp1`, mod `0666`, yazılabilir |
| Fiş basıyor mu | **Evet** |
| Türkçe kod sayfası | **`ESC t 29`** (`1B 74 1D`) |

### Dokümanın yanlış olduğu nokta

`docs/05-mutfakapp.md` §5.2 kod sayfası için `ESC t 13` (PC857) diyordu.
**Bu yazıcıda çalışmıyor** — Türkçe baytlar boşluk basılıyor, o kod
sayfasında glif yok. `n = 0..47` taraması yapıldı, yalnızca `n = 29`
doğru sonuç verdi. Doküman düzeltildi.

Bayt karşılıkları PC857 düzeniyle aynı; farklı olan yalnızca **seçim
numarası**. Gerçek yazıcıda doğrulanan 12 harf: ç ğ ı ö ş ü Ç Ğ İ Ö Ş Ü.

**Ders:** ESC/POS kod sayfası numaraları standart değildir, üreticiye göre
değişir. Yazıcı değişirse tarama tekrarlanmalı —
`infra/kasa/kodsayfasi-tara.sh` tek komutla yapar.
- [KOL-D][04.08] Geliştirme makinesinde araç zinciri kurulu değildi (git/docker/node/dart/php yok, apt indeksi boş). | Etkilenen: tüm hatlar | Geçici çözüm: Node 22 ve Dart SDK `~/.local/sdk` altına sudo'suz kuruldu; git + docker + Flutter Linux masaüstü bağımlılıkları için sudo gerekti, kullanıcı elle koştu.

## Karara bağlanmayı bekleyen iş soruları

Bunlar teknik değil, **işletmenin cevaplaması gereken** sorular. Cevapsız kalırsa varsayılan uygulanır.

| # | Soru | Varsayılan (cevap gelmezse) |
|---|---|---|
| 7 | Abonelik modeli nasıl işleyecek? (haftalık/aylık paket, kaç öğün, iptal kuralı, faturalama dönemi) | **Faz 2.** Faz 1'de yok. Dokümanlarda tanımı bulunmadığı için tasarlanmadı. |
| 8 | Toplu fiyatlama nasıl hesaplanacak? (adet kırılımlı kademe mi, müşteriye özel fiyat listesi mi, sözleşme fiyatı mı) | **Faz 2.** Faz 1'de ürün fiyatı tekildir. |
| 9 | Cari hesap (`account`) ödemesi kimlere açık? Her müşteri seçebilir mi, yönetici tek tek mi yetkilendirir? | Her giriş yapmış müşteri seçebilir; tahsilat sistem dışında takip edilir. |
| 10 | Teslimat ücreti nasıl belirlenir? Sabit mi, bölge bazlı mı, tutar üstü ücretsiz mi? | TastyIgniter'ın kendi teslimat ücreti mekanizması, sabit ücret. |
| 11 | Logo ve nihai renk paleti | Yer tutucu turuncu palet (`#F97316`) ile devam, Gün 6'da değiştirilir. |

## Çözüldü

| # | Soru | Karar | Tarih | Etki |
|---|---|---|---|---|
| 1 | Öğrenci ödemesi: online / tezgahta / bakiye-cüzdan? | **Öğrenci kanalı tamamen iptal** — hiçbir sürümde olmayacak. | 04.08 | `docs/00` §3-4-6-7, `docs/02` §1-2-3-6, `docs/03` (`channel`/`pickup_code`/`group` alanları ve `teslim` fiş tipi silindi), `docs/05` §3/§5.3/§5.5/§10, `docs/06`, `docs/07`, `docs/09`, `docs/10` S2 |
| 2 | Catering tahsilatı: online POS / cari hesap + fatura? | **Online POS alınacak (Kuveyt Türk)**, sağlayıcı sözleşmesi bitene kadar kapalı. Faz 1'de `cash` (kapıda) + `account` (cari) çalışır. | 04.08 | `docs/03` §3'e `payment_methods` alanı eklendi, `docs/04` §5, `docs/06` §3, `docs/10` S1 |
| 3 | Kurum içi sipariş girişi: günlük toplu mu, haftalık şablon mu? | **Kurum içi kanal tamamen iptal.** Yönetici gerekirse admin panelden normal sipariş açar. | 04.08 | `veykemtu/channels` eklentisi ve `veykemtu_order_meta` tablosu iptal edildi (`docs/02` §2, `docs/04` §4) |
| 4 | Öğrenci bildirimi veliye SMS gidecek mi? | Konusuz — öğrenci kanalı iptal. | 04.08 | — |
| 5 | Sipariş kesim saati var mı? | **Var ve yönetilebilir.** Admin panelden sipariş alımı açılıp kapatılabilir (`ordering_enabled`) + günlük kesim saati (`order_cutoff`). | 04.08 | `docs/03` §3, `docs/04` §4.1, `docs/06` §3, `docs/10` S3 |
| 6 | Firma/marka adı, logo, renk paleti | **Ad: "Benim Lezzet Dünyam" (BLD).** Palet turuncu. Logo sonra yapılacak → soru #11'e taşındı. | 04.08 | `README.md`, `docs/04` §2, `docs/05` §5.3, `packages/design_system` |
| — | Alan adı ne olacak? | **`benimlezzetdunyam.com.tr`** — site `www.` ile, API `api.` alt alan adında. Sunucu: `62.238.102.197` (`bldmain`, Ubuntu 26.04 LTS). | 04.08 | `infra/.env.example`, `docs/openapi.yaml` servers, `platform/.env.example`, `website/.env.example` |

## Master prompt ↔ doküman çelişkileri (Oturum 0'da karara bağlandı)

| Konu | Master prompt | Doküman | Karar |
|---|---|---|---|
| KDS veri arayüzü adı | `SiparisKaynagi`, "`docs/05` §5'teki imza" | `OrderSource`, **§4**'te | `OrderSource` — `AGENTS.md` §4 "Türkçe değişken adı kullanma" kuralı gereği. §5 yazdırma bölümüdür, arayüz §4'tedir. |
| Mock sunucu klasörü | `infra/mock-api/` | `infra/mock/` | `infra/mock/` — doküman kazanır (`00-INDEX.md` çelişki kuralı). Compose **servis** adı `mock-api` kaldı, verilen komut aynen çalışır. |
| Kasa betikleri | `infra/ubuntu/kur.sh`, `99-termal-yazici.rules` | `infra/kasa/setup.sh`, `99-thermal-printer.rules` | Doküman kazanır |
| Dev compose | `infra/docker-compose.dev.yml` | `infra/docker-compose.yml` | Çelişki değil, ikisi de var: `.dev.yml` = dev (mysql + platform + mock), `.yml` = prod (`docs/08` §1.2) |
| api_client kaynağı | `openapi.yaml`'dan üretilsin | `platform/openapi.json`'dan (`docs/03` §9) | `docs/openapi.yaml` normatif tohumdur; `platform`'un ürettiği `openapi.json` buna uymak zorunda, CI fark kontrolü yapar (`E-01`) |
| Boş gövde | "`UnimplementedError` olabilir" | `AGENTS.md` §2.5 "placeholder bırakma" | Çelişki değil: Oturum 0 çıktısı **iskelettir**, "bitti" değildir. `X-03` gövdeleri boş bırakılmadı, gerçekten uygulandı — kalan `UnimplementedError` yok. |
| Katalog ucunun adı | Bitirme ölçütünde `GET /api/catalog` | Sözleşmede böyle bir uç yok: `GET /api/locations` + `GET /api/locations/{id}/menu` (`docs/03` §3) | Doküman kazanır. Ölçüt "mock örnek katalog verisi dönüyor" olarak yorumlandı ve iki uçla da doğrulandı. |
