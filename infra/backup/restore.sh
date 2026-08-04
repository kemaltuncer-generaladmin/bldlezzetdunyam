#!/usr/bin/env bash
# Yedekten geri dönüş — docs/08-kurulum-deploy.md §1.4
#
#   ./restore.sh <dosya.sql.gz.enc>                      # CANLI veritabanına
#   ./restore.sh <dosya.sql.gz.enc> --hedef=bld_tatbikat # tatbikat (güvenli)
#
# TATBİKAT ÖNCE: ayda bir, --hedef ile boş bir veritabanına açın ve
# içeriğini doğrulayın. Denenmemiş yedek yedek değildir; bir yedeğin
# bozuk olduğunu öğrenmenin en kötü zamanı ona ihtiyaç duyduğunuz andır.
set -euo pipefail

KOK="$(cd "$(dirname "$0")/../.." && pwd)"
# Compose dosyası dışarıdan verilebilir: geri dönüş tatbikatı dev
# ortamında da koşulabilmeli, yoksa betik yalnızca prod'da denenir
# ve orada denemek zaten istemediğimiz şey.
COMPOSE="docker compose -f ${BLD_COMPOSE:-$KOK/infra/docker-compose.yml}"

DOSYA="${1:-}"
HEDEF=""
ONAYLA=0

shift || true
for arg in "$@"; do
  case "$arg" in
    --hedef=*) HEDEF="${arg#*=}" ;;
    --onayla)  ONAYLA=1 ;;
    *) echo "Bilinmeyen seçenek: $arg" >&2; exit 1 ;;
  esac
done

if [ -z "$DOSYA" ] || [ ! -f "$DOSYA" ]; then
  echo "Kullanım: ./restore.sh <dosya.sql.gz.enc> [--hedef=veritabani] [--onayla]" >&2
  echo >&2
  echo "Mevcut yedekler:" >&2
  ls -lh "$KOK/infra/backup/dumps/" 2>/dev/null | tail -20 >&2
  exit 1
fi

# .env yüklenir ama UID/GID atlanır: bunlar docker compose için konuldu
# ve bash'te salt-okunur oldukları için `set -a` ile kaynaklamak hata basar.
if [ -f "$KOK/infra/.env" ]; then
  set -a
  # shellcheck source=/dev/null
  . <(grep -vE '^(UID|GID)=' "$KOK/infra/.env")
  set +a
fi

: "${DB_USERNAME:?infra/.env içinde DB_USERNAME yok}"
: "${DB_PASSWORD:?infra/.env içinde DB_PASSWORD yok}"
: "${BACKUP_PASSPHRASE:?infra/.env içinde BACKUP_PASSPHRASE yok}"

# Geri yükleme bir yönetim işidir: yeni veritabanı oluşturmak ve şema
# yazmak uygulama kullanıcısının yetkisinde değildir (olmamalı da —
# uygulama kullanıcısı DROP/CREATE DATABASE yapabilseydi bir SQL
# enjeksiyonu tüm veritabanını silebilirdi).
if [ -n "${DB_ROOT_PASSWORD:-}" ]; then
  YONETICI_KULLANICI=root
  YONETICI_PAROLA="$DB_ROOT_PASSWORD"
else
  echo "UYARI: DB_ROOT_PASSWORD yok; uygulama kullanıcısıyla denenecek." >&2
  echo "       Yeni veritabanına geri yükleme büyük olasılıkla yetki hatası verir." >&2
  YONETICI_KULLANICI="$DB_USERNAME"
  YONETICI_PAROLA="$DB_PASSWORD"
fi

TATBIKAT=1
if [ -z "$HEDEF" ]; then
  HEDEF="${DB_DATABASE:?}"
  TATBIKAT=0
fi

echo "== Geri yükleme =="
echo "  kaynak: $DOSYA"
echo "  hedef : $HEDEF"

if [ "$TATBIKAT" = 0 ]; then
  cat <<UYARI

  ╔════════════════════════════════════════════════════════════════════╗
  ║  DİKKAT: CANLI VERİTABANININ ÜZERİNE YAZILACAK                     ║
  ║                                                                    ║
  ║  Bu işlem geri alınamaz. Devam etmeden önce mevcut hâlin yedeğini  ║
  ║  alın:                                                             ║
  ║      ./infra/backup/backup.sh --etiket=geri-yukleme-oncesi         ║
  ║                                                                    ║
  ║  Tatbikat yapmak istiyorsanız --hedef=bld_tatbikat kullanın.       ║
  ╚════════════════════════════════════════════════════════════════════╝

UYARI
  if [ "$ONAYLA" != 1 ]; then
    read -r -p "  'EVET' yazın: " CEVAP
    [ "$CEVAP" = "EVET" ] || { echo "  İptal edildi."; exit 1; }
  fi
fi

# ── 1. Şifre çözme ve bütünlük ────────────────────────────────────────────
# Önce ayrı bir dosyaya açıyoruz: bozuk bir yedeği doğrudan veritabanına
# akıtmak, yarısı yüklenmiş bir şema bırakır.
GECICI="$(mktemp -t bld-restore-XXXXXX.sql)"
trap 'rm -f "$GECICI"' EXIT

echo "  şifre çözülüyor..."
if ! openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 \
      -pass "pass:$BACKUP_PASSPHRASE" -in "$DOSYA" | gunzip > "$GECICI"; then
  echo "HATA: şifre çözülemedi veya arşiv bozuk. Parola doğru mu?" >&2
  exit 1
fi

SATIR=$(wc -l < "$GECICI")
if [ "$SATIR" -lt 10 ]; then
  echo "HATA: döküm şüpheli derecede kısa ($SATIR satır). Yükleme yapılmadı." >&2
  exit 1
fi
echo "  döküm: $SATIR satır, $(du -h "$GECICI" | cut -f1)"

if ! grep -qi 'CREATE TABLE' "$GECICI"; then
  echo "HATA: dökümde CREATE TABLE yok — bu geçerli bir yedek değil." >&2
  exit 1
fi

# ── 2. Yükleme ────────────────────────────────────────────────────────────
echo "  hedef veritabanı hazırlanıyor..."
$COMPOSE exec -T db mysql -u"$YONETICI_KULLANICI" -p"$YONETICI_PAROLA" \
  -e "CREATE DATABASE IF NOT EXISTS \`$HEDEF\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

echo "  yükleniyor..."
$COMPOSE exec -T db mysql -u"$YONETICI_KULLANICI" -p"$YONETICI_PAROLA" "$HEDEF" < "$GECICI"

# ── 3. Doğrulama ──────────────────────────────────────────────────────────
# "Komut hata vermedi" ile "veri geldi" aynı şey değil.
echo
echo "  doğrulama:"
$COMPOSE exec -T db mysql -u"$YONETICI_KULLANICI" -p"$YONETICI_PAROLA" "$HEDEF" -N -e "
  SELECT CONCAT('    tablo sayısı : ', COUNT(*))
    FROM information_schema.tables WHERE table_schema='$HEDEF';
  SELECT CONCAT('    sipariş      : ', COUNT(*)) FROM orders;
  SELECT CONCAT('    müşteri      : ', COUNT(*)) FROM customers;
  SELECT CONCAT('    menü ürünü   : ', COUNT(*)) FROM menus;
  SELECT CONCAT('    durum kodu   : ', COUNT(*)) FROM statuses WHERE status_code IS NOT NULL;
" 2>/dev/null || echo "    UYARI: doğrulama sorguları çalışmadı — şema eksik olabilir"

echo
if [ "$TATBIKAT" = 1 ]; then
  cat <<SON
Tatbikat tamam. Yukarıdaki sayılar makul görünüyorsa yedek sağlamdır.

Durum kodu sayısı 7 OLMALI — değilse veykemtu:setup koşmamış bir yedektir.

Tatbikat veritabanını temizlemek için:
  $COMPOSE exec -T db mysql -u$YONETICI_KULLANICI -p'***' -e "DROP DATABASE \\\`$HEDEF\\\`;"
SON
else
  cat <<SON
Geri yükleme tamam. Şimdi:
  1. $COMPOSE exec app php artisan config:clear
  2. $COMPOSE restart app
  3. curl -H 'X-App-Id: website' -H 'X-App-Version: 1.0.0' \\
       https://api.benimlezzetdunyam.com.tr/api/health
  4. Admin panele girip son siparişlerin göründüğünü doğrulayın
SON
fi
