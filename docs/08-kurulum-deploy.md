# 08 — Kurulum ve Dağıtım

## 1. Sunucu (Hetzner VPS)

**Mevcut:** `62.238.102.197` — 2 vCPU, 3.8 GB RAM, 75 GB SSD, Ubuntu 26.04 LTS.

### 1.1 İlk hazırlık

Sunucu: **`62.238.102.197`** (`bldmain`, Ubuntu 26.04 LTS, 2 vCPU / 3.8 GB
/ 75 GB). Docker ve **Coolify** kurulu geliyor; Coolify kendi Traefik'ini
80/443'te çalıştırır.

Kalan sertleştirme adımları:

```bash
# SSH: parola girişini kapat (anahtar zaten kurulu)
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' \
  /etc/ssh/sshd_config.d/50-cloud-init.conf
systemctl restart ssh

# Güvenlik duvarı — 8000 Coolify arayüzü
ufw allow OpenSSH && ufw allow 80 && ufw allow 443 && ufw allow 8000
ufw --force enable
```

> **Uyarı:** Coolify arayüzü (`:8000`) alan adı ve TLS gelene kadar düz
> HTTP üzerinden erişilebilir. Yönetim arayüzünü internete açık bırakmak
> geçici bir durumdur; DNS geldiğinde Coolify'ın kendi alan adı ayarı
> yapılıp 8000 güvenlik duvarından kapatılmalıdır.

### 1.2 Dağıtım: Coolify

**Karar (05.08.2026):** sunucuda **Coolify** kurulu ve Traefik 80/443'ü
yönetiyor. Kendi Caddy'mizle ikinci bir ters vekil çalıştırmak aynı portlar
için yarışmak demekti; Coolify üzerinden dağıtıyoruz.

Bu kararın getirdikleri: TLS, git'ten otomatik dağıtım, log görüntüleme,
ortam değişkeni yönetimi ve dağıtım geri alma hazır geliyor. Götürdüğü:
dağıtım topolojisi artık Coolify'ın kuralarına tabi.

| Dosya | Ne |
|---|---|
| `docker-compose.coolify.yml` | Coolify'ın okuduğu yığın (repo kökünde) |
| `infra/platform/Dockerfile.prod` | php-fpm; `composer install` derleme anında |
| `infra/platform/Dockerfile.web` | Caddy + uygulama imajından kopyalanan statik dosyalar |
| `infra/Caddyfile.internal` | Yalnızca iç FastCGI önyüzü, dışarı port açmaz |
| `website/Dockerfile` | Next.js üretim imajı (üç aşamalı, standalone) |

**Caddy neden hâlâ var:** Traefik FastCGI konuşamaz. php-fpm'in önünde bir
HTTP sunucusu şart; Caddy o rolde, dışarı açık değil.

**Sırlar repoda durmaz.** Compose, Coolify'ın `SERVICE_PASSWORD_*` sihirli
değişkenlerini kullanır — parolaları Coolify üretir ve saklar. `APP_KEY`
Coolify ortam değişkenlerinde elle tanımlanır.

**Traefik etiketi elle yazılmaz.** `SERVICE_FQDN_WEB_80` değişkenini gören
Coolify yönlendirmeyi ve sertifikayı kendisi kurar.

> **Sihirli değişken tuzağı — sahada yaşandı.** Değeri olmayan liste
> girdisi (`- SERVICE_FQDN_SITE_3000`) Coolify tarafından ortam haritasına
> çevrilirken anahtar olarak **liste indeksi** kullanılabiliyor. Sonuç
> `0: SERVICE_FQDN_SITE_3000` olur ve derleme
> `non-string key in services.<servis>.environment: 0` ile düşer.
>
> Alan adı Coolify'ın kalıcı `docker_compose_domains` kaydında zaten
> varsa sihirli değişkene hiç gerek yoktur — Traefik etiketleri oradan
> üretilir. `site` servisi bu yüzden değişkeni taşımıyor.

#### Alan adları

| Servis | Adres | Durum |
|---|---|---|
| `web` (API + admin) | `https://api.benimlezzetdunyam.com.tr` | canlı, LE sertifikası |
| `site` (müşteri sitesi) | `https://benimlezzetdunyam.com.tr` | canlı, LE sertifikası |
| — | `www.benimlezzetdunyam.com.tr` | **DNS kaydı yok** |

`www` kaydı eklendiğinde yapılacak tek şey Coolify'da `site` servisinin
alan adı alanına virgülle eklemektir; kod ve compose değişmez.

#### api.* kökü ana domaine yönleniyor (I-07, 12.08.2026)

`api.benimlezzetdunyam.com.tr` kökünde ikinci bir "BLD sitesi" duruyordu.
Ayrı bir deploy değildi: `IGNITER_URI` hiç tanımlanmadığı için TastyIgniter,
kurulu `ti-theme-orange` temasının bütün sayfalarını `/` altına bağlıyordu
(`Igniter\Main\Classes\RouteRegistrar::forThemePages`).

**İki kemerle kapatıldı** ve ikisi de gerekli:

1. `BridgeApi\Extension::disableStorefrontTheme()` — `register()` içinde
   `Igniter::disableThemeRoutes(true)`. Rota hiç kurulmuyor.
   **`boot()` DEĞİL:** rotalar `Igniter\Main\ServiceProvider::boot()`
   içinde tanımlanıyor; eklentiler `ExtensionServiceProvider::register()`
   sırasında kaydedildiği için bizim `register()`'ımız ondan önce koşuyor.
   `boot()`'a yazılsaydı bayrak rotalar kurulduktan sonra çevrilir ve hiçbir
   etkisi olmazdı.
2. `infra/Caddyfile.internal` — `/api/*`, `/admin*`, `/storage/*`,
   `/vendor/*`, `/_assets/*`, `/odeme-simulasyon/*`, `/robots.txt`,
   `/favicon.svg` dışındaki her yol `SITE_PUBLIC_URL`'e 308 ile gidiyor.
   Rota kurulmasa bile o adrese yazan müşteri 404 değil gerçek siteyi görür.

Hedef `SITE_PUBLIC_URL` ortam değişkeninden okunuyor (varsayılan üretim
adresi); `docker-compose.coolify.yml` içinde `web` servisine veriliyor.

**Doğrulama:**

```bash
curl -sI https://api.benimlezzetdunyam.com.tr/            # 308 → ana domain
curl -s  https://api.benimlezzetdunyam.com.tr/api/health  # 200
curl -sI https://api.benimlezzetdunyam.com.tr/admin       # panel açılır
```

#### Admin panel ikonları — `Dockerfile.web` varlık yayınlama (I-08)

Panelde ikonların çoğu boş kutu görünüyordu. Sebep `infra/platform/Dockerfile.web`
idi: derleme aşaması yalnızca `composer install` koşuyor, `vendor:publish`
koşmuyordu. `platform/public/vendor` gitignore'lu olduğu için Caddy imajının
`public/` klasöründe `vendor/igniter` dizini **hiç yoktu**.

Belirti kafa karıştırıcıydı: admin CSS'i çalışıyordu, çünkü o PHP tarafındaki
`_assets` birleştirici rotasından geliyor. Ama Font Awesome'ın `@font-face`
kuralı `url(../fonts/FontAwesome/fa-solid-900.woff2)` diyor ve tarayıcı bunu
`/vendor/igniter/fonts/...` altında arıyordu — 404. Stiller yerinde, ikonların
hepsi boş.

Derleme aşamasına yayınlama adımı eklendi. Geçici bir `.env` (bellek içi
SQLite) kullanılıyor çünkü `vendor:publish` uygulamayı ayağa kaldırıyor ve
derleme anında MySQL yok; dosya hemen siliniyor. Arkasındaki `test -f`
kasıtlı: yayınlama sessizce başarısız olursa **derleme patlar**, aksi hâlde
hata yalnızca canlıda kırık ikonlar olarak görünürdü.

**Doğrulama:**

```bash
curl -sI https://api.benimlezzetdunyam.com.tr/vendor/igniter/fonts/FontAwesome/fa-solid-900.woff2
# 200 beklenir
```

> **Her iki imaj da yeniden derlenmeli.** `Dockerfile.web` değişti; yalnız
> `app` konteynerini yenilemek ikonları düzeltmez.

#### Dağıtım akışı

1. Coolify → BLD projesi → yeni **Docker Compose** kaynağı
2. Kaynak: GitHub App ile bağlanmış `bldlezzetdunyam` deposu
3. Compose yolu: `docker-compose.coolify.yml`
4. Ortam değişkenleri: `APP_KEY` (bir kez `php artisan key:generate --show`
   ile üretilip yapıştırılır), gerekirse `MYSQL_DATABASE`, `MYSQL_USER`
5. Deploy. GitHub webhook'u sonraki itmelerde otomatik tetikler.

#### İlk dağıtımdan sonra — zorunlu

**Artisan HER ZAMAN `-u www-data` ile koşulur.** Sebebi aşağıda.

```bash
A=$(docker ps --format '{{.Names}}' | grep '^app-' | head -1)
docker exec -u www-data -e HOME=/tmp "$A" php artisan igniter:install --no-interaction
docker exec -u www-data -e HOME=/tmp "$A" php artisan veykemtu:setup
docker exec -u www-data -e HOME=/tmp "$A" php artisan veykemtu:admin <e-posta> --super
```

`veykemtu:setup` olmadan sipariş durumları, vitrin ve ödeme yöntemleri
tanımsız kalır; API çalışır ama sipariş oluşturulamaz.

> **`-u www-data` neden zorunlu — sahada yaşandı.**
>
> Artisan'ı root olarak koşmak `storage/framework/cache` altında **root'a
> ait** dosyalar bırakır. php-fpm `www-data` koşar ve o dosyalara yazamaz.
> Sonuç: oran sınırlayıcı gibi önbelleğe yazan her uç **500** döner, ama
> yalnızca BAZI uçlar — sorunun kaynağı görünmez olur. Bizde
> `POST /api/kitchen/pair` 500 verirken `GET /api/kitchen/orders` sorunsuz
> çalışıyordu ve hata mesajı da loglanamıyordu.
>
> Konteyner yeniden başlarsa giriş betiği sahipliği düzeltir; ama komutu
> doğru koşmak bunu hiç yaşamamayı sağlar.

#### Erişim adresi

**`https://api.benimlezzetdunyam.com.tr`** — Let's Encrypt sertifikası
Traefik tarafından alındı ve otomatik yenilenir.

Alan adı **Cloudflare arkasında** (proxy açık). Bu, kurulumda bir tuzak
çıkardı ve kaydı burada:

Cloudflare'in SSL/TLS modu **Full** olduğunda kenar sunucudan origin'e
**HTTPS** ile gidilir. Origin yalnızca HTTP sunuyorsa Cloudflare
`503 no available server` döner — ve bu hata origin loglarında hiç
görünmez, çünkü istek origin'e hiç ulaşmaz. Çözüm origin'e de gerçek
sertifika almaktır: Coolify'daki alan adı `https://` şemasıyla yazılır,
Traefik Let's Encrypt'ten sertifikayı alır.

Let's Encrypt HTTP-01 doğrulaması Cloudflare proxy'si açıkken de çalışır:
`/.well-known/acme-challenge/` isteği kenar sunucudan origin'in 80
portuna iletilir.

Geçiş dönemi için Coolify'ın sslip.io joker adresi de tanımlı bırakıldı
(`http://<uuid>.62.238.102.197.sslip.io`); DNS'e bağımlı olmadan test
imkânı verir.

**`expose` bildirimi zorunludur.** Coolify, Traefik hizmetini portu
bilmeden kuramaz; `web` servisinde `expose: ["80"]` olmadan konteyner
etiketsiz kalır ve dışarıdan 404 döner. `ports` değil `expose` — dışarı
açılmıyor, yalnızca proxy'nin ulaşacağı port ilan ediliyor.

#### Müşteri sitesi (Next.js)

Aynı compose yığınında `site` servisi olarak koşar. İki nokta önemli:

**`output: 'standalone'`** (`website/next.config.ts`): `next build` yalnızca
gerçekten kullanılan bağımlılıkları toplar. Onsuz imaja tüm bağımlılık
ağacını kopyalamak gerekirdi — ~800 MB yerine **342 MB**.

**`NEXT_PUBLIC_*` derleme anında gömülür.** Bunlar ortam değişkeni değil,
**build arg**'dır. Coolify'da değiştirildiğinde yeniden **derleme** gerekir;
yalnızca yeniden başlatmak eski adresi kullanmaya devam eder.

> **`FRONTEND_URL` tuzağı — sahada yaşandı.** Bu değişken `www.` alt
> alanına bakacak şekilde kalmıştı ve o kayıt DNS'te yoktu. Ödeme
> simülasyonu siparişi doğru şekilde `paid` yapıyor, sonra müşteriyi
> **çözülemeyen bir adrese** yolluyordu. Hiçbir uç hata döndürmüyordu;
> yalnızca müşteri kayboluyordu. `infra/e2e.sh` artık dönüş adresinin
> gerçekten 200 döndüğünü sınıyor.

### 1.3 Dağıtım geri alma

Coolify her dağıtımı sürümler; arayüzden önceki dağıtıma dönülebilir.
Elle geri alma gerekiyorsa `docs/RUNBOOK.md` §7.


### 1.4 Yedekleme

`infra/backup/backup.sh` — gecelik cron (03:00):
- `mysqldump` → şifreli arşiv (AES-256, `BACKUP_PASSPHRASE`)
- medya klasörü
- sunucu dışı bir hedefe kopyalanır (`BACKUP_REMOTE`)
- 7 günlük + 4 haftalık + 3 aylık saklama

**Ayda bir geri dönüş tatbikatı zorunlu:** yedek boş bir ortama açılır, sistem ayağa kalkıyor mu doğrulanır.

#### Sunucudaki kurulum (yapıldı — 05.08.2026)

Coolify sunucusunda **repo çalışma kopyası yoktur**; betikler tek başına
`/opt/bld/infra/backup/` altına kopyalandı, ayarlar `/opt/bld/infra/.env`
(mod 600) içinde. Cron `/etc/cron.d/bld-yedekleme`.

```
BLD_DB_CONTAINER=^db-wl1c5om85          # AD DEĞİL, ÖRÜNTÜ
BLD_APP_CONTAINER=^app-wl1c5om85
BLD_MEDIA_PATH=/var/www/platform/storage/app
```

> **Konteyner adı neden örüntü:** Coolify konteyner adlarına her
> dağıtımda değişen bir sonek ekler (`db-<uuid>-233152209364`). Sabit ad
> yazmak, ilk dağıtımdan sonra **sessizce çalışmayan** bir yedekleme
> demekti — cron her gece koşar, her gece "konteyner yok" der ve kimse
> bakmaz. Betik örüntüyü her koşuda yeniden çözer.

Doğrulandı: gerçek yedek alındı (85 tablo), **geri dönüş tatbikatı
yapıldı** (85 tablo / 31 sipariş / 7 durum kodu), ve betik **çıplak cron
ortamında** (`env -i`) da koşuyor.

> **AÇIK EKSİK: `BACKUP_REMOTE` tanımlı değil.** Yedekler şu an yalnızca
> aynı sunucuda duruyor; disk arızasında yedek de gider. Betik bunu her
> koşuda uyarı olarak basıyor. Kapatmak için nesne depolama ya da ikinci
> bir sunucu adresi gerekiyor.
>
> **`BACKUP_PASSPHRASE` kaybolursa hiçbir yedek açılamaz.** Parola
> `/opt/bld/infra/.env` içinde ve başka hiçbir yerde yok — parola
> yöneticisine alınmalı.

---

## 2. Mutfak kasası (MSI / Ubuntu)

### 2.1 İşletim sistemi

**Ubuntu 24.04 LTS Desktop** (Server değil — ekran ve GUI gerekiyor).

Kurulumda:
- Kullanıcı: `mutfak`, otomatik giriş açık
- Disk şifreleme kapalı (elektrik gelince otomatik açılması gerekiyor, parola sorulmamalı)
- Üçüncü parti sürücüler: evet

### 2.2 Kurulum betiği

`infra/kasa/setup.sh` şunları yapar:

```bash
#!/usr/bin/env bash
set -euo pipefail

# 1. Güç ve ekran ayarları
gsettings set org.gnome.desktop.session idle-delay 0
gsettings set org.gnome.desktop.screensaver lock-enabled false
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'

# 2. Otomatik güncelleme yeniden başlatmasını kapat
sudo sed -i 's/^Unattended-Upgrade::Automatic-Reboot.*/Unattended-Upgrade::Automatic-Reboot "false";/' \
  /etc/apt/apt.conf.d/50unattended-upgrades

# 3. Yazıcı udev kuralı
sudo cp 99-thermal-printer.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules && sudo udevadm trigger

# 4. Uygulama kurulumu
sudo mkdir -p /opt/mutfakapp
sudo cp -r build/linux/x64/release/bundle/* /opt/mutfakapp/
sudo chmod +x /opt/mutfakapp/mutfakapp

# 5. systemd user servisi
mkdir -p ~/.config/systemd/user
cp mutfakapp.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now mutfakapp
sudo loginctl enable-linger mutfak   # oturum kapansa da çalışsın
```

### 2.3 Yazıcı doğrulama

```bash
lsusb                          # vendor:product id'yi bul
ls -l /dev/usb/                # lp0 var mı
echo -e "TEST\n\n\n" > /dev/thermal0   # udev kuralından sonra
```
Çıktı gelmezse: `dmesg | tail` ile çekirdek mesajlarına bak, `usblp` modülü yüklü mü kontrol et (`lsmod | grep usblp`).

### 2.3.5 Otomatik açılış zinciri (05.08.2026)

Elektrik gelince kasa kendiliğinden açılıp KDS'i göstermeli; kimse
klavyeye dokunmamalı. Zincir dört halka:

| Halka | Durum | Nerede |
|---|---|---|
| BIOS "AC power on" | **fiziksel, elle yapılır** | BIOS ayarı |
| GDM otomatik giriş | `AutomaticLogin=kemaltuncer` | `/etc/gdm3/custom.conf` |
| systemd kullanıcı servisi | `WantedBy=graphical-session.target` | `~/.config/systemd/user/` |
| Ekran uykusu ve kilit kapalı | `idle-delay=0`, `lock-enabled=false` | gsettings |

> **`default.target` DEĞİL, `graphical-session.target`.** İlki kullanıcı
> oturumu açılır açılmaz ulaşılıyor ve bu, masaüstünün hazır olmasından
> önce olabilir. `After=` yalnızca iki birim aynı işlemde başlatılıyorsa
> sıra dayatır; grafik oturum o işlemin parçası değilse etkisiz kalır ve
> uygulama ekran sunucusu yokken açılıp çökerek yeniden başlatma turuna
> girer. `graphical-session.target` tam olarak "masaüstü hazır" demek ve
> GNOME ortam değişkenlerini (`WAYLAND_DISPLAY`, `XDG_RUNTIME_DIR`)
> systemd'ye o aşamada aktarıyor.

> **Bu halka yalnızca YENİDEN BAŞLATMAYLA doğrulanabilir.**
> `graphical-session.target` elle başlatmayı reddediyor
> (`RefuseManualStart`), yani oturumu yeniden açmadan sınanamıyor.
> Kasa yeniden başlatıldığında KDS kendiliğinden gelmiyorsa ilk bakılacak
> yer `systemctl --user status mutfakapp` ve
> `journalctl --user -u mutfakapp -b`.

`loginctl enable-linger` **gerekmiyor**: otomatik giriş açık olduğu için
kullanıcı oturumu açılışta başlıyor ve servis onunla geliyor. Linger,
oturum hiç açılmasa bile servisi ayakta tutmak içindir.

### 2.4 Kabul kontrol listesi (kasa)

- [ ] Elektrik kesilip gelince makine kendiliğinden açılıyor (BIOS: AC power on = Power On)
- [ ] Otomatik giriş yapılıyor, parola sorulmuyor
- [ ] Uygulama kendiliğinden açılıyor ve tam ekran
- [ ] Ekran hiç kararmıyor/kilitlenmiyor
- [ ] Test fişi basılıyor, Türkçe karakterler doğru
- [ ] İnternet kesilip gelince uygulama kendini toparlıyor
- [ ] Uygulama zorla kapatılınca 5 saniyede yeniden başlıyor

---

### 1.x v2.0 ortam değişkenleri (12.08.2026)

| Değişken | Servis | Boş bırakılırsa |
|---|---|---|
| `NETGSM_USERNAME` | `app` | **SMS gönderilmez.** Giriş kodu yalnızca `storage/logs` içine `warning` olarak yazılır; e-posta + parola girişi çalışmaya devam eder |
| `NETGSM_PASSWORD` | `app` | aynı |
| `NETGSM_HEADER` | `app` | aynı — Netgsm panelinde **onaylı** gönderici adı olmalı, onaysız başlıkta sağlayıcı `40` döner ve tek mesaj bile ulaşmaz |
| `SITE_PUBLIC_URL` | `web` | Varsayılan `https://benimlezzetdunyam.com.tr`; api.* kökünün yönleneceği adres |

Üçü birden dolu olmadıkça uygulama **ayağa kalkmayı reddetmez** — tek eksik
değişken yüzünden bütün siteyi indirmek doğru olmazdı. SMS ikinci bir giriş
yolu; eksikliğin izi günlükteki uyarı satırıdır.

### 1.y v2.0 göçleri

```bash
cd platform
php artisan igniter:up
vendor/bin/phpunit --testsuite Veykemtu   # 273 test yeşil olmalı
```

| Göç | Ne ekler |
|---|---|
| `2026_08_13_000001` | `customers.bld_credit_limit_kurus` — cari borç limiti (NULL sınırsız, 0 kapalı) |
| `2026_08_13_000002` | `veykemtu_account_payments` — cari ödeme niyeti |
| `2026_08_13_000003` | `veykemtu_otp_codes` — telefonla giriş kodları |

> **`php artisan test` KULLANMAYIN.** Bu projede bazen yalnızca `Unit`
> paketini koşuyor (bir seferinde 227 test, hemen sonrasında 1 test) ve
> yeşil dönüyor. Güvenilir komut `vendor/bin/phpunit --testsuite Veykemtu`.

## 3. CI/CD

`.github/workflows/` — path filtreli hatlar:

| Dosya | Tetik | İş |
|---|---|---|
| `platform.yml` | `platform/**`, `docs/openapi.yaml` | composer install, `php artisan test`, `vendor/` izlenmiyor kontrolü, openapi geçerliliği + uç karşılaştırması |
| `website.yml` | `website/**`, `docs/openapi.yaml` | npm ci, `any` yasağı, tsc, lint, build, mock e2e |
| `dart.yml` | `packages/**` | üretilen dosyalar güncel mi, analyze, test, format |
| `musteriapp.yml` | `musteriapp/**`, `packages/**` | flutter analyze, test, AAB build, Play kapalı test yükleme |
| `mutfakapp.yml` | `mutfakapp/**`, `packages/**` | flutter analyze, test, `flutter build linux`, `.deb` paketleme, sürüm kaydı |

**Dağıtım CI'da değil, Coolify'ın GitHub webhook'unda.** CI yalnızca
doğrular; `main`'e itilen kod Coolify tarafından dağıtılır.

### PHP testlerini sunucuda elle koşmak (12.08.2026)

Uygulama imajıyla tek seferlik bir konteyner açıp `phpunit` koşmak
mümkün, ama **iki tuzağı var** ve ikisi de sessizce yanlış sonuç
üretiyor:

**1. `DB_PREFIX` boş verilmezse her sorgu yanlış tabloyu arar.**
`config/database.php` varsayılanı `ti_`. Üretimde bu değeri boşa çeken
yer `infra/platform/entrypoint.sh`'in ürettiği `.env`. Konteyneri
`--entrypoint sh` ile açınca o betik **koşmuyor**, `.env` üretilmiyor ve
prefix `ti_`'ye düşüyor. Sonuç: `Table 'bld_test.ti_menu_categories'
doesn't exist` gibi yüzlerce hata ve "test altyapısı bozuk" izlenimi.
Sahada yaşandı — yarım gün buna gitti.

**2. Test veritabanı adı `_test` ile bitmeli ve kullanıcının yetkisi
olmalı.** `tests/bootstrap.php` `DB_DATABASE`'in sonuna `_test` ekliyor,
yani `DB_DATABASE=bld` verilir ve testler `bld_test`'e gider. O
veritabanında `bld` kullanıcısının yetkisi yoksa paket ilk testte düşer:

```sql
GRANT ALL PRIVILEGES ON bld_test.* TO 'bld'@'%'; FLUSH PRIVILEGES;
```

Doğru env dosyası:

```
APP_KEY / DB_USERNAME / DB_PASSWORD   → app konteynerinden kopyalanır
APP_ENV=testing   DB_HOST=db   DB_DATABASE=bld   DB_PREFIX=
CACHE_DRIVER=array   SESSION_DRIVER=array   QUEUE_CONNECTION=sync
```

**Paket ~50 dakika sürüyor.** `KitchenTestCase::setUp` her testte
`veykemtu:setup` + `veykemtu:demo-menu` koşuyor (test başına ~13 sn).
Konteyneri `docker run -d` ile **ayrık** başlatın: ssh koparsa ya da
istemci zaman aşımına düşerse paket yarıda kalıyor.

**ADR kapıları** — bunlar test değil, mimari kuralın CI karşılığıdır:

| Kural | Kapı |
|---|---|
| ADR-02: çekirdeğe dokunma | `platform/vendor/` altında **izlenen** dosya varsa kırmızı |
| ADR-04: Android planı iptal | `mutfakapp/android` veya `ios` varsa kırmızı |
| AGENTS.md §2.4 | `musteriapp/lib` içinde `package:dio`/`package:http` varsa kırmızı |
| AGENTS.md §4 | `website` içinde `any` kullanımı varsa kırmızı |

**Sırlar:** GitHub Actions secrets — `SSH_KEY`, `ANDROID_KEYSTORE`, `PLAY_SERVICE_ACCOUNT`, `FCM_SERVICE_ACCOUNT`. Repoda sır dosyası bulunmaz; yalnızca `.env.example`.

## 4. Sürüm etiketleme

```
platform-v1.0.0    → prod deploy
website-v1.0.0     → prod deploy
musteriapp-v1.0.0  → Play üretim kanalı
mutfakapp-v1.0.0   → .deb üretimi + app_releases kaydı
```

## 5. İzleme

Minimal ve yeterli:
- Uptime kontrolü: `https://api.benimlezzetdunyam.com.tr/api/health` (basit 200 dönen uç) — harici bir uptime servisi
- Disk/bellek uyarısı: sunucuda `netdata` veya basit cron + e-posta
- Laravel log: `storage/logs`, logrotate ile 14 gün
- **Kasa canlılık:** `heartbeat` ucundaki `last_seen_at` 5 dakikadan eskiyse admin panelde uyarı — mutfak ekranı düşmüşse yönetici hemen görsün
