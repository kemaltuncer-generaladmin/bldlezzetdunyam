#!/usr/bin/env bash
# Kasa için KDS derlemesi ve kurulumu — docs/05-mutfakapp.md §7.5, §6.
#
#   ./infra/kasa/derle.sh          # derle + kur + servisi yeniden başlat
#   ./infra/kasa/derle.sh --sadece-derle
#
# NEDEN AYRI BETİK: kasanın derlemesi çıplak `flutter build linux` DEĞİLDİR.
# Sunucu adresi, mutfak token'ı, yazıcı yolu ve kod sayfası derleme zamanında
# gömülür. Elle yazılınca biri unutuluyor ve kasa sessizce mock'a bağlanıyor
# ya da eşleme ekranında kalıyor.
set -euo pipefail

KOK="$(cd "$(dirname "$0")/../.." && pwd)"
AYAR="$KOK/infra/kasa/.kasa.env"
KURULUM="$HOME/.local/opt/mutfakapp"
SERVIS=mutfakapp

if [ ! -f "$AYAR" ]; then
  cat >&2 <<SON
HATA: $AYAR yok.

Bu dosya kasaya özeldir ve REPODA DURMAZ — içinde gerçek mutfak token'ı var.
Oluşturmak için önce sunucudan eşleme kodu alın:

  A=\$(docker ps -qf name=^app- | head -1)
  docker exec -u www-data -e HOME=/tmp "\$A" php artisan veykemtu:kds --new=MSI-Mutfak-Kasasi

Sonra kodu token'a çevirin ve dosyayı yazın:

  curl -s -H 'X-App-Id: mutfakapp' -H 'X-App-Version: 1.0.0' \\
       -H 'Content-Type: application/json' \\
       -X POST https://api.benimlezzetdunyam.com.tr/api/kitchen/pair \\
       -d '{"pairing_code":"XXXX-YYYY","device_name":"MSI Mutfak Kasası"}'

  cat > $AYAR <<'EOF'
  BLD_API_BASE_URL=https://api.benimlezzetdunyam.com.tr/api
  BLD_KITCHEN_TOKEN=<yukarıdaki token>
  BLD_PRINTER_DEVICE=/dev/thermal0
  BLD_PRINTER_CODEPAGE=29
  EOF
SON
  exit 1
fi

# Dosyayı KABUĞA YORUMLATMADAN okuyoruz. Sanctum token'ı `22|6ln4…`
# biçimindedir ve içindeki `|` kaynaklandığında boru sanılıp
# "command not found" ile patlar. Satırları elle ayırıp değeri olduğu
# gibi alıyoruz.
while IFS= read -r satir; do
  case "$satir" in
    ''|'#'*) continue ;;
  esac
  anahtar=${satir%%=*}
  deger=${satir#*=}
  [ "$anahtar" = "$satir" ] && continue
  printf -v "$anahtar" '%s' "$deger"
done < "$AYAR"

: "${BLD_API_BASE_URL:?.kasa.env içinde BLD_API_BASE_URL yok}"
: "${BLD_KITCHEN_TOKEN:?.kasa.env içinde BLD_KITCHEN_TOKEN yok}"
: "${BLD_PRINTER_DEVICE:=/dev/thermal0}"
: "${BLD_PRINTER_CODEPAGE:=29}"

echo "== KDS derlemesi =="
echo "  sunucu : $BLD_API_BASE_URL"
echo "  yazıcı : $BLD_PRINTER_DEVICE (kod sayfası $BLD_PRINTER_CODEPAGE)"
echo "  token  : ${BLD_KITCHEN_TOKEN:0:8}… (gömülü)"

cd "$KOK/mutfakapp"
flutter build linux --release \
  --dart-define="BLD_API_BASE_URL=$BLD_API_BASE_URL" \
  --dart-define="BLD_KITCHEN_TOKEN=$BLD_KITCHEN_TOKEN" \
  --dart-define="BLD_PRINTER_DEVICE=$BLD_PRINTER_DEVICE" \
  --dart-define="BLD_PRINTER_CODEPAGE=$BLD_PRINTER_CODEPAGE"

PAKET="$KOK/mutfakapp/build/linux/x64/release/bundle"

# Gömülen adres gerçekten girdiğimiz mi? Yanlış --dart-define anahtarı
# sessizce yok sayılır ve varsayılan (mock) kalır — sahada bu, sabah
# sipariş gelmemesi demek.
#
# `grep -q` KULLANMAYIN. `set -o pipefail` altında grep ilk eşleşmede
# çıkar, `strings` SIGPIPE alır ve pipefail bunu hata sayar — kontrol tam
# da eşleşmenin BULUNDUĞU durumda düşer. `-q` yerine çıktıyı yönlendirmek
# grep'in girdiyi sonuna kadar okumasını sağlar.
if ! strings "$PAKET/lib/libapp.so" | grep -F "$BLD_API_BASE_URL" >/dev/null; then
  echo "HATA: derlemede $BLD_API_BASE_URL yok — dart-define geçmemiş." >&2
  exit 1
fi
echo "  ✓ adres derlemede doğrulandı"

if [ "${1:-}" = "--sadece-derle" ]; then
  echo "Derleme hazır: $PAKET"
  exit 0
fi

echo "== Kurulum =="
mkdir -p "$HOME/.local/opt" "$HOME/.config/systemd/user"
rm -rf "$KURULUM"
cp -r "$PAKET" "$KURULUM"
cp "$KOK/infra/kasa/$SERVIS.service" "$HOME/.config/systemd/user/"

# ── Simge ve masaüstü girişi ──────────────────────────────────────────────
#
# İkon adı (`bld-mutfakapp`) hem `.desktop` girişinde hem de GTK penceresinde
# kullanılıyor; ikisi ayrışırsa görev çubuğunda genel bir dişli görünür.
#
# `hicolor` teması standart konum: masaüstü ortamının hangisi olduğunu
# bilmemize gerek kalmıyor.
for boyut in 16 24 32 48 64 128 256 512; do
  KAYNAK="$KOK/mutfakapp/assets/icons/bld_${boyut}.png"
  [ -f "$KAYNAK" ] || continue
  HEDEF="$HOME/.local/share/icons/hicolor/${boyut}x${boyut}/apps"
  mkdir -p "$HEDEF"
  cp "$KAYNAK" "$HEDEF/bld-mutfakapp.png"
done

mkdir -p "$HOME/.local/share/applications"
cp "$KOK/infra/kasa/bld-mutfakapp.desktop" "$HOME/.local/share/applications/"

# Önbellek yenilenmezse ikon menüde eski hâliyle kalır. Araç yoksa
# sessizce geçiyoruz: kurulumu bir önbellek yüzünden durdurmak yanlış.
command -v gtk-update-icon-cache >/dev/null \
  && gtk-update-icon-cache -qtf "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
command -v update-desktop-database >/dev/null \
  && update-desktop-database -q "$HOME/.local/share/applications" 2>/dev/null || true

echo "  ✓ simge ve masaüstü girişi kuruldu"

systemctl --user daemon-reload
systemctl --user enable "$SERVIS" >/dev/null
systemctl --user restart "$SERVIS"

sleep 5
if [ "$(systemctl --user is-active "$SERVIS")" != "active" ]; then
  echo "HATA: servis ayağa kalkmadı." >&2
  systemctl --user status "$SERVIS" --no-pager | head -20 >&2
  exit 1
fi

echo "  ✓ servis çalışıyor"
echo
echo "Kasa hazır. Ekranda parola sorulacak; girildikten sonra doğrudan"
echo "sipariş ekranı açılır — eşleme kodu istenmez, token gömülü."
