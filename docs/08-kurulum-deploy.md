# 08 — Kurulum ve Dağıtım

## 1. Sunucu (Hetzner VPS)

**Öneri:** CPX21 veya üstü (3 vCPU, 4 GB RAM, 80 GB SSD), Ubuntu 24.04.

### 1.1 İlk hazırlık

```bash
# root olarak
adduser deploy && usermod -aG sudo deploy
# SSH anahtarını deploy kullanıcısına kopyala
# /etc/ssh/sshd_config: PasswordAuthentication no, PermitRootLogin no
systemctl restart ssh

# Docker
curl -fsSL https://get.docker.com | sh
usermod -aG docker deploy

# Güvenlik duvarı
ufw allow OpenSSH && ufw allow 80 && ufw allow 443 && ufw enable
```

### 1.2 Docker Compose

`infra/docker-compose.yml` servisleri:

| Servis | İmaj | Not |
|---|---|---|
| `caddy` | caddy:2 | TLS otomatik, 80/443 |
| `app` | özel PHP 8.3-fpm imajı | TastyIgniter |
| `web` | node:22 (Next.js standalone) | Website |
| `db` | mysql:8 | Yalnızca iç ağ, port dışa açılmaz |
| `reverb` | app imajı, farklı komut | Faz 1.5 |

**Caddyfile:**
```
api.<domain> {
    root * /var/www/platform/public
    php_fastcgi app:9000
    file_server
    encode gzip
}

<domain>, www.<domain> {
    reverse_proxy web:3000
    encode gzip
}
```

### 1.3 Dağıtım

```bash
cd /opt/catering && git pull
docker compose build app web
docker compose up -d
docker compose exec app php artisan migrate --force
docker compose exec app php artisan config:cache
```

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
| `platform.yml` | `platform/**` | composer install, lint, `php artisan test`, `vendor/` diff kontrolü, staging deploy |
| `website.yml` | `website/**`, `packages/**` | npm ci, lint, build, Playwright, staging deploy |
| `musteriapp.yml` | `musteriapp/**`, `packages/**` | flutter analyze, test, AAB build, Play kapalı test yükleme |
| `mutfakapp.yml` | `mutfakapp/**`, `packages/**` | flutter analyze, test, `flutter build linux`, `.deb` paketleme, sürüm kaydı |

**`vendor/` koruma adımı** (`platform.yml` içinde zorunlu):
```yaml
- name: Cekirdege dokunulmadi mi
  run: |
    if git diff --name-only origin/main...HEAD | grep -q '^platform/vendor/'; then
      echo "HATA: platform/vendor/ degistirilmis (ADR-02 ihlali)"; exit 1
    fi
```

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
- Uptime kontrolü: `https://api.<domain>/api/health` (basit 200 dönen uç) — harici bir uptime servisi
- Disk/bellek uyarısı: sunucuda `netdata` veya basit cron + e-posta
- Laravel log: `storage/logs`, logrotate ile 14 gün
- **Kasa canlılık:** `heartbeat` ucundaki `last_seen_at` 5 dakikadan eskiyse admin panelde uyarı — mutfak ekranı düşmüşse yönetici hemen görsün
