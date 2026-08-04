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

**Caddy neden hâlâ var:** Traefik FastCGI konuşamaz. php-fpm'in önünde bir
HTTP sunucusu şart; Caddy o rolde, dışarı açık değil.

**Sırlar repoda durmaz.** Compose, Coolify'ın `SERVICE_PASSWORD_*` sihirli
değişkenlerini kullanır — parolaları Coolify üretir ve saklar. `APP_KEY`
Coolify ortam değişkenlerinde elle tanımlanır.

**Traefik etiketi elle yazılmaz.** `SERVICE_FQDN_WEB_80` değişkenini gören
Coolify yönlendirmeyi ve sertifikayı kendisi kurar.

#### Alan adı gelene kadar

DNS yok; erişim sunucu IP'si (`62.238.102.197`) üzerinden ve **düz HTTP**.
Let's Encrypt alan adı olmadan sertifika veremez. `@`, `www` ve `api`
kayıtları sunucuya yönlendirildiğinde Coolify'daki alan adı alanına
yazmak yeterli — kod ve compose değişmez.

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

#### Erişim adresi (alan adı gelene kadar)

Coolify sslip.io joker DNS'iyle otomatik bir adres verir:
`http://<uuid>.62.238.102.197.sslip.io`. Gerçek DNS gerektirmez, doğrudan
sunucu IP'sine çözülür — staging bu adresle test edilebilir.

**`expose` bildirimi zorunludur.** Coolify, Traefik hizmetini portu
bilmeden kuramaz; `web` servisinde `expose: ["80"]` olmadan konteyner
etiketsiz kalır ve dışarıdan 404 döner. `ports` değil `expose` — dışarı
açılmıyor, yalnızca proxy'nin ulaşacağı port ilan ediliyor.

### 1.3 Dağıtım geri alma

Coolify her dağıtımı sürümler; arayüzden önceki dağıtıma dönülebilir.
Elle geri alma gerekiyorsa `docs/RUNBOOK.md` §7.


### 1.4 Yedekleme

`infra/backup/backup.sh` — gecelik cron (03:00):
- `mysqldump` → şifreli arşiv
- `platform/storage/app` medya klasörü
- Hetzner dışı bir hedefe kopyalanır (nesne depolama / ayrı sunucu)
- 7 günlük + 4 haftalık + 3 aylık saklama

**Ayda bir geri dönüş tatbikatı zorunlu:** yedek boş bir ortama açılır, sistem ayağa kalkıyor mu doğrulanır.

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

### 2.4 Kabul kontrol listesi (kasa)

- [ ] Elektrik kesilip gelince makine kendiliğinden açılıyor (BIOS: AC power on = Power On)
- [ ] Otomatik giriş yapılıyor, parola sorulmuyor
- [ ] Uygulama kendiliğinden açılıyor ve tam ekran
- [ ] Ekran hiç kararmıyor/kilitlenmiyor
- [ ] Test fişi basılıyor, Türkçe karakterler doğru
- [ ] İnternet kesilip gelince uygulama kendini toparlıyor
- [ ] Uygulama zorla kapatılınca 5 saniyede yeniden başlıyor

---

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
