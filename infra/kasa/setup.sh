#!/usr/bin/env bash
# Mutfak kasası kurulumu — docs/08-kurulum-deploy.md §2.2, ADR-06
#
# Hedef: elektrik kesintisinden sonra KİMSENİN müdahale etmesi gerekmemeli.
# Makine açılır, otomatik giriş yapar, KDS tam ekran gelir, yazıcı hazırdır.
#
#   ./setup.sh              # her şeyi yap
#   ./setup.sh --kontrol    # hiçbir şeyi değiştirme, yalnızca durumu raporla
#
# İdempotenttir: tekrar tekrar koşulabilir.
set -uo pipefail

KOK="$(cd "$(dirname "$0")/../.." && pwd)"
KURULUM_DIZINI=/opt/mutfakapp
SERVIS_ADI=mutfakapp
KONTROL_MODU=0
[ "${1:-}" = "--kontrol" ] && KONTROL_MODU=1

TAMAM=0; UYARI=0; HATA=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; TAMAM=$((TAMAM+1)); }
uyar() { printf '  \033[33m!\033[0m %s\n' "$1"; UYARI=$((UYARI+1)); }
hata() { printf '  \033[31m✗\033[0m %s\n' "$1"; HATA=$((HATA+1)); }
baslik(){ printf '\n\033[1m%s\033[0m\n' "$1"; }

yap() {
  # yap <aciklama> <komut...>
  local aciklama="$1"; shift
  if [ "$KONTROL_MODU" = 1 ]; then
    uyar "ATLANDI (kontrol modu): $aciklama"
    return 0
  fi
  if "$@" >/dev/null 2>&1; then ok "$aciklama"; else hata "$aciklama"; fi
}

if [ "$KONTROL_MODU" = 1 ]; then
  echo "== KASA DURUM KONTROLÜ (hiçbir şey değiştirilmiyor) =="
else
  echo "== KASA KURULUMU =="
  if [ "$(id -u)" = 0 ]; then
    echo "HATA: bu betik normal kullanıcı olarak çalıştırılmalı; sudo'yu kendi çağırır." >&2
    exit 1
  fi
  sudo -v || { echo "HATA: sudo gerekli." >&2; exit 1; }
fi

# ── 1. Ekran ve güç ───────────────────────────────────────────────────────
# Mutfak ekranı asla kararmamalı: aşçı ekrana bakıp sipariş görecek,
# fare oynatmak için elini yıkamak zorunda kalmamalı.
baslik "1. Ekran ve güç"
if command -v gsettings >/dev/null 2>&1; then
  yap "ekran uykusu kapatıldı" gsettings set org.gnome.desktop.session idle-delay 0
  yap "ekran kilidi kapatıldı" gsettings set org.gnome.desktop.screensaver lock-enabled false
  yap "boşta kilit kapatıldı" gsettings set org.gnome.desktop.screensaver idle-activation-enabled false
  yap "AC'de askıya alma kapatıldı" \
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type nothing
  yap "kapak kapanınca askıya alma kapatıldı" \
    gsettings set org.gnome.settings-daemon.plugins.power lid-close-ac-action nothing
else
  uyar "gsettings yok — GNOME kurulu değil, ekran ayarları elle yapılmalı"
fi

# ── 2. Otomatik giriş ─────────────────────────────────────────────────────
# Elektrik gelince parola bekleyen bir ekran, mutfağın körleşmesi demek.
baslik "2. Otomatik giriş"
GDM_CONF=/etc/gdm3/custom.conf
if [ ! -f "$GDM_CONF" ]; then
  uyar "$GDM_CONF yok — GDM kullanılmıyor olabilir, otomatik giriş elle ayarlanmalı"
elif [ "$KONTROL_MODU" = 1 ]; then
  # Kontrol modu hiç sudo istemez; dosya okunamıyorsa da rapor verir.
  if grep -qE '^\s*AutomaticLoginEnable\s*=\s*[Tt]rue' "$GDM_CONF" 2>/dev/null; then
    ok "otomatik giriş açık"
  else
    uyar "otomatik giriş kapalı görünüyor (veya dosya okunamadı — sudo gerekir)"
  fi
else
  if sudo grep -qE '^\s*AutomaticLoginEnable\s*=\s*[Tt]rue' "$GDM_CONF" 2>/dev/null; then
    ok "otomatik giriş zaten açık"
  else
    yap "otomatik giriş açıldı ($USER)" sudo sed -i \
      -e "s/^#*\s*AutomaticLoginEnable\s*=.*/AutomaticLoginEnable=true/" \
      -e "s/^#*\s*AutomaticLogin\s*=.*/AutomaticLogin=$USER/" \
      "$GDM_CONF"
    sudo grep -qE '^AutomaticLoginEnable' "$GDM_CONF" || uyar \
      "custom.conf'a satır eklenemedi — [daemon] bölümüne elle ekleyin"
  fi
fi

# ── 3. Otomatik güncelleme yeniden başlatması ─────────────────────────────
# Gece 03:00'te kendini yeniden başlatan bir kasa, sabah servisinde
# kapalı ekran demektir.
baslik "3. Otomatik güncelleme"
UU=/etc/apt/apt.conf.d/50unattended-upgrades
if [ -f "$UU" ]; then
  yap "otomatik yeniden başlatma kapatıldı" sudo sed -i \
    's|^//*\s*Unattended-Upgrade::Automatic-Reboot\s*".*";|Unattended-Upgrade::Automatic-Reboot "false";|' "$UU"
else
  uyar "$UU yok — unattended-upgrades kurulu değil, sorun yok"
fi

# ── 4. Yazıcı ─────────────────────────────────────────────────────────────
baslik "4. Termal yazıcı"
KURAL="$KOK/infra/kasa/99-thermal-printer.rules"
if grep -q 'XXXX' "$KURAL" 2>/dev/null; then
  hata "udev kuralında yer tutucu var (XXXX/YYYY) — VID/PID doldurulmalı"
  echo "      lsusb ile bulun, sonra kuralı düzenleyin."
else
  yap "udev kuralı kopyalandı" sudo cp "$KURAL" /etc/udev/rules.d/
  yap "udev kuralları yeniden yüklendi" sudo udevadm control --reload-rules
  yap "udev tetiklendi" sudo udevadm trigger
fi

if [ -e /dev/thermal0 ]; then
  ok "/dev/thermal0 var → $(readlink -f /dev/thermal0)"
  [ -w /dev/thermal0 ] && ok "/dev/thermal0 yazılabilir" \
    || hata "/dev/thermal0 yazılamıyor — udev kuralındaki MODE=0666 uygulanmamış"
else
  hata "/dev/thermal0 yok — yazıcı bağlı mı? 'lsusb' ve 'ls /dev/usb/' kontrol edin"
fi

# Cihaz düğümü varsa modül zaten yüklüdür; `lsmod` her ortamda okunamıyor
# ve orada yanlış uyarı üretmek gerçek sorunları gölgeler.
if [ ! -e /dev/thermal0 ] && [ ! -e /dev/usb/lp0 ] && [ ! -e /dev/usb/lp1 ]; then
  if lsmod 2>/dev/null | grep -q usblp; then
    uyar "usblp yüklü ama cihaz düğümü yok — yazıcı bağlı değil olabilir"
  else
    hata "usblp modülü yüklü değil — 'sudo modprobe usblp'"
  fi
fi

# ── 5. Uygulama ───────────────────────────────────────────────────────────
baslik "5. Uygulama"
PAKET="$KOK/mutfakapp/build/linux/x64/release/bundle"
if [ -d "$PAKET" ]; then
  yap "kurulum dizini oluşturuldu" sudo mkdir -p "$KURULUM_DIZINI"
  yap "uygulama kopyalandı" sudo cp -r "$PAKET/." "$KURULUM_DIZINI/"
  yap "çalıştırma izni verildi" sudo chmod +x "$KURULUM_DIZINI/mutfakapp"
else
  uyar "derleme çıktısı yok — önce: cd mutfakapp && flutter build linux --release"
fi

# ── 6. systemd kullanıcı servisi ──────────────────────────────────────────
# Çökerse 5 saniyede geri gelir (docs/10 S4 adım 7).
baslik "6. systemd servisi"
if [ -x "$KURULUM_DIZINI/mutfakapp" ]; then
  yap "servis dizini oluşturuldu" mkdir -p "$HOME/.config/systemd/user"
  yap "servis dosyası kopyalandı" \
    cp "$KOK/infra/kasa/$SERVIS_ADI.service" "$HOME/.config/systemd/user/"
  yap "systemd yeniden yüklendi" systemctl --user daemon-reload
  yap "servis etkinleştirildi" systemctl --user enable "$SERVIS_ADI"
  # linger: kullanıcı oturumu kapansa bile servis ayakta kalır.
  yap "linger açıldı" sudo loginctl enable-linger "$USER"
else
  uyar "uygulama kurulmadığı için servis atlandı"
fi

# ── 7. Kabul kontrol listesi ──────────────────────────────────────────────
baslik "7. Elle doğrulanacaklar (docs/08 §2.4)"
cat <<'LISTE'
  Bu betik yazılımı hazırlar; aşağıdakiler FİZİKSEL olarak denenmeli:

  [ ] BIOS: "AC power on" = Power On  (elektrik gelince kendiliğinden açılsın)
  [ ] Elektriği kes, geri ver → makine açılıyor, parola sormuyor
  [ ] Uygulama kendiliğinden açılıyor ve tam ekran
  [ ] Ekran 15 dakika beklendiğinde kararmıyor
  [ ] Test fişi basılıyor, Türkçe karakterler doğru
  [ ] İnterneti kes, geri ver → uygulama kendini toparlıyor
  [ ] pkill -9 mutfakapp → 5 saniyede geri geliyor

  Yazıcı testi:
    printf 'BLD test\n\n\n\x1D\x56\x42\x00' > /dev/thermal0
LISTE

printf '\nSonuç: \033[32m%d tamam\033[0m, \033[33m%d uyarı\033[0m, \033[31m%d hata\033[0m\n' \
  "$TAMAM" "$UYARI" "$HATA"
[ "$HATA" -eq 0 ]
