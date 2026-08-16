#!/usr/bin/env bash
# Yayınlanacak `.deb` paketini üretir — docs/05-mutfakapp.md §9, görev B-10.
#
#   ./infra/kasa/paketle.sh 1.1.0                # paketle
#   ./infra/kasa/paketle.sh 1.1.0 --yayinla      # paketle + GitHub Releases'e yükle
#   ./infra/kasa/paketle.sh 1.1.0 --token-göm    # cihaz token'ını da göm (bkz. aşağıda)
#
# NEDEN `derle.sh` DEĞİL: `derle.sh` TEK BİR KASA için derler ve çıktıyı o
# makineye kurar. Bu betik ise SAHADAKİ TÜM KASALARA dağıtılacak bir paket
# üretir; ikisinin gömdüğü değerler aynı olamaz.
#
# ── TOKEN VARSAYILAN OLARAK GÖMÜLMEZ ──────────────────────────────────────
#
# `derle.sh` `BLD_KITCHEN_TOKEN`'ı ikiliye gömer ve `main.dart` onu her
# açılışta cihazın deposuna YAZAR (üzerine yazar). Bu, tek bir kasayı
# hazırlarken doğru; dağıtılan bir pakette ise iki ayrı sorun:
#
#   1. Paket GitHub Releases'te duruyor. Canlı API'de mutfak yetkisi olan
#      bir kimlik bilgisini indirilebilir bir dosyanın içine koymak, onu
#      yayınlamaktır.
#   2. Paketi kuran HER kasa aynı cihaz kimliğine bürünür. İkinci kasa
#      eklendiği gün ikisi birbirinin siparişini, sağlığını ve komutunu
#      paylaşır — ve bu, sahada teşhisi en zor arızalardandır.
#
# Gerek de yok: kasa token'ını ilk kurulumda `derle.sh` ile deposuna yazdı.
# `provisionedToken` boş gelirse `main.dart` var olanı korur (main.dart:27).
#
# `--token-göm` bilinçli bir istisna içindir (tek kasalı kurulumda paketi
# doğrudan sahaya indirmek gibi) ve ne yaptığını ekrana basar.
set -euo pipefail

KOK="$(cd "$(dirname "$0")/../.." && pwd)"
AYAR="$KOK/infra/kasa/.kasa.env"
CIKTI="$KOK/build/paket"

SURUM="${1:-}"
YAYINLA=0
TOKEN_GOM=0
for arg in "${@:2}"; do
  case "$arg" in
    --yayinla) YAYINLA=1 ;;
    --token-göm|--token-gom) TOKEN_GOM=1 ;;
    *) echo "Bilinmeyen seçenek: $arg" >&2; exit 1 ;;
  esac
done

if ! [[ "$SURUM" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Kullanım: $0 <sürüm> [--yayinla] [--token-göm]   (örn. 1.1.0)" >&2
  exit 1
fi

# ── Sürüm üç yerde de aynı olmalı ────────────────────────────────────────
#
# `AppConfig.appVersion` kasanın KENDİNİ tanıttığı sürümdür ve elle
# güncellenen bir sabittir. Paket 1.1.0 diye yayınlanıp ikili hâlâ "1.0.0"
# derse kasa güncellemeyi kurar, sonra kendini eski sürüm sanar ve rozet
# sonsuza kadar ekranda kalır. Burada durdurmak, sahada fark etmekten ucuz.
PUBSPEC_SURUM="$(sed -n 's/^version: *\([0-9.]*\).*/\1/p' "$KOK/mutfakapp/pubspec.yaml" | head -1)"
KOD_SURUM="$(sed -n "s/.*appVersion = '\([0-9.]*\)'.*/\1/p" \
  "$KOK/mutfakapp/lib/src/config/app_config.dart" | head -1)"

if [ "$PUBSPEC_SURUM" != "$SURUM" ] || [ "$KOD_SURUM" != "$SURUM" ]; then
  cat >&2 <<SON
HATA: sürümler tutmuyor.
  istenen               : $SURUM
  pubspec.yaml          : ${PUBSPEC_SURUM:-yok}
  AppConfig.appVersion  : ${KOD_SURUM:-yok}

Üçünü de $SURUM yapın, sonra tekrar çalıştırın.
SON
  exit 1
fi

# ── Derleme değerleri ────────────────────────────────────────────────────
#
# Sunucu adresi ve yazıcı varsayılanları `.kasa.env`'den okunuyor ama
# TOKEN OKUNMUYOR (yukarıdaki gerekçe). Yazıcı değerleri yalnızca
# varsayılan: kayıtlı ayarlar derlemeyi ezer (docs/05 §8), yani yazıcısı
# farklı bir kasa bu paketten etkilenmez.
BLD_KITCHEN_TOKEN=''
if [ -f "$AYAR" ]; then
  while IFS='=' read -r anahtar deger; do
    case "$anahtar" in
      BLD_API_BASE_URL|BLD_PRINTER_DEVICE|BLD_PRINTER_CODEPAGE)
        printf -v "$anahtar" '%s' "$deger" ;;
      BLD_KITCHEN_TOKEN)
        [ "$TOKEN_GOM" = 1 ] && printf -v "$anahtar" '%s' "$deger" ;;
    esac
  done < <(grep -v '^[[:space:]]*#' "$AYAR" | grep '=')
fi

: "${BLD_API_BASE_URL:?BLD_API_BASE_URL yok — .kasa.env veya ortam değişkeni gerekli}"
: "${BLD_PRINTER_DEVICE:=/dev/thermal0}"
: "${BLD_PRINTER_CODEPAGE:=29}"

echo "== KDS paketi $SURUM =="
echo "  sunucu : $BLD_API_BASE_URL"
echo "  yazıcı : $BLD_PRINTER_DEVICE (kod sayfası $BLD_PRINTER_CODEPAGE, yalnız varsayılan)"
if [ -n "$BLD_KITCHEN_TOKEN" ]; then
  echo "  token  : ${BLD_KITCHEN_TOKEN:0:8}… GÖMÜLÜYOR"
  echo "           ⚠ bu paketi kuran her kasa aynı cihaz kimliğini alır."
else
  echo "  token  : gömülmüyor (kasa kendi deposundakini kullanır)"
fi

# ── Derle ────────────────────────────────────────────────────────────────
cd "$KOK/mutfakapp"
DEFINES=(
  --dart-define="BLD_API_BASE_URL=$BLD_API_BASE_URL"
  --dart-define="BLD_PRINTER_DEVICE=$BLD_PRINTER_DEVICE"
  --dart-define="BLD_PRINTER_CODEPAGE=$BLD_PRINTER_CODEPAGE"
)
[ -n "$BLD_KITCHEN_TOKEN" ] && \
  DEFINES+=(--dart-define="BLD_KITCHEN_TOKEN=$BLD_KITCHEN_TOKEN")

flutter build linux --release "${DEFINES[@]}"

BUNDLE="$KOK/mutfakapp/build/linux/x64/release/bundle"

# Gömülen adres gerçekten girdiğimiz mi? (derle.sh ile aynı kontrol ve aynı
# `grep -q` tuzağı: pipefail altında SIGPIPE hata sayılır.)
if ! strings "$BUNDLE/lib/libapp.so" | grep -F "$BLD_API_BASE_URL" >/dev/null; then
  echo "HATA: derlemede $BLD_API_BASE_URL yok — dart-define geçmemiş." >&2
  exit 1
fi
echo "  ✓ adres derlemede doğrulandı"

# ── .deb ağacını kur ─────────────────────────────────────────────────────
#
# İçerik `/opt/mutfakapp` altına konuyor. Kasa paketi KURMUYOR, `dpkg-deb -x`
# ile açıyor ve `AppUpdater._findBundle` çalıştırılabiliri ağaçta arayıp
# buluyor — yani yol bir sözleşme değil, yalnızca alışılmış bir yer.
AGAC="$CIKTI/mutfakapp_${SURUM}_amd64"
DEB_KAYNAK="$KOK/infra/kasa/deb"
rm -rf "$AGAC"
mkdir -p "$AGAC/DEBIAN" "$AGAC/opt/mutfakapp" \
         "$AGAC/usr/lib/mutfakapp" "$AGAC/usr/share/mutfakapp" \
         "$AGAC/usr/lib/udev/rules.d" "$AGAC/etc/systemd/user" \
         "$AGAC/usr/share/applications"
cp -a "$BUNDLE/." "$AGAC/opt/mutfakapp/"

# Kurulumun kullanıcı tarafı: oturumda koşan hazırlık betiği ve onu
# çağıran birim. Gerekçesi `deb/kasa-ayarla` başlığında.
install -m 0755 "$DEB_KAYNAK/kasa-ayarla" "$AGAC/usr/lib/mutfakapp/kasa-ayarla"
install -m 0644 "$DEB_KAYNAK/mutfakapp-kurulum.service" "$AGAC/etc/systemd/user/"
install -m 0644 "$KOK/infra/kasa/mutfakapp.service" "$AGAC/usr/share/mutfakapp/"

# udev kuralı PAKETTEN GELİYOR: `/usr/lib/udev/rules.d` paketlerin yeri,
# `/etc/udev/rules.d` ise yöneticinin. Pakete ait bir dosyayı /etc'ye
# koymak, paket kaldırılınca ortada kalmasına yol açardı.
install -m 0644 "$KOK/infra/kasa/99-thermal-printer.rules" "$AGAC/usr/lib/udev/rules.d/"

[ -f "$KOK/infra/kasa/bld-mutfakapp.desktop" ] && \
  install -m 0644 "$KOK/infra/kasa/bld-mutfakapp.desktop" "$AGAC/usr/share/applications/"

for betik in postinst prerm; do
  install -m 0755 "$DEB_KAYNAK/$betik" "$AGAC/DEBIAN/$betik"
done

BOYUT_KB="$(du -sk "$AGAC/opt" "$AGAC/usr" | awk '{t+=$1} END {print t}')"

# `Depends` BURADA BELGE NİTELİĞİNDE: kasa paketi `dpkg-deb -x` ile açtığı
# için bağımlılıklar zorlanmıyor. Yine de doğru yazılmalı — paketi elle
# `dpkg -i` ile kuran biri (ilk kurulum, kurtarma) eksik kütüphaneyi burada
# görür. sqlite3 bağımlılığının gerekçesi mutfakapp/pubspec.yaml'da.
cat > "$AGAC/DEBIAN/control" <<SON
Package: mutfakapp
Version: $SURUM
Section: utils
Priority: optional
Architecture: amd64
Depends: libgtk-3-0t64 | libgtk-3-0, libsqlite3-0, libglib2.0-0t64 | libglib2.0-0, systemd, udev, dpkg
Maintainer: VeyKemTu <bilgi@benimlezzetdunyam.com.tr>
Installed-Size: $BOYUT_KB
Description: Benim Lezzet Dunyam mutfak ekrani (KDS)
 Mutfak kasasinda calisan siparis ekrani ve fis yazdirma uygulamasi.
 .
 Kurulum makineyi bir kiosk'a donusturur: otomatik giris acilir, ekran
 kararmasi ve uyku kapatilir, uygulama acilista tam ekran baslar. Ilk
 acilista eslesme ekrani cikar ve cihaz kendi kimligini sunucudan alir.
SON

# `--root-owner-group`: paketi kim derlerse derlesin dosya sahibi `root:root`
# olur. Olmazsa paket, derleyen kullanıcının uid'sini taşır ve başka bir
# makinede açıldığında sahiplik anlamsız bir sayıya düşer.
dpkg-deb --build --root-owner-group "$AGAC" >/dev/null

DEB="$CIKTI/mutfakapp_${SURUM}_amd64.deb"
OZET="$(sha256sum "$DEB" | cut -d' ' -f1)"
BAYT="$(stat -c%s "$DEB")"

echo
echo "== Paket hazır =="
echo "  dosya  : $DEB"
echo "  boyut  : $((BAYT / 1048576)) MB ($BAYT bayt)"
echo "  sha256 : $OZET"

# ── GitHub Releases ──────────────────────────────────────────────────────
if [ "$YAYINLA" = 1 ]; then
  command -v gh >/dev/null || { echo "HATA: gh CLI kurulu değil." >&2; exit 1; }

  ETIKET="mutfakapp-v$SURUM"
  echo
  echo "== GitHub Releases =="
  if gh release view "$ETIKET" >/dev/null 2>&1; then
    gh release upload "$ETIKET" "$DEB" --clobber
  else
    gh release create "$ETIKET" "$DEB" \
      --title "mutfakapp $SURUM" \
      --notes "KDS $SURUM"
  fi

  ADRES="$(gh release view "$ETIKET" --json assets \
    --jq '.assets[] | select(.name | endswith(".deb")) | .url')"
  echo "  adres : $ADRES"
else
  ADRES='<gh release upload sonrası adres>'
fi

# ── Son adım elle ────────────────────────────────────────────────────────
#
# Sürümü KAYDA GEÇİRMEK bilinçli olarak ayrı: paketi üretmek geri
# alınabilir, `veykemtu:surum` ise sahadaki tüm kasaları etkileyen bir
# yayındır. İkisini tek komutta birleştirmek, yanlış paketi tek tuşla
# mutfağa göndermek olurdu.
cat <<SON

== Yayınlamak için (sunucuda) ==
  php artisan veykemtu:surum --publish --app=mutfakapp --version=$SURUM \\
      --url="$ADRES" \\
      --sha256=$OZET \\
      --notes="..."

Kasalar bunu en geç bir saat içinde görür; hemen kurdurmak için Kontrol
Merkezi'nden ilgili cihaza "update" komutu gönderin.
SON
