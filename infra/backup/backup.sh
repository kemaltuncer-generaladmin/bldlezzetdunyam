#!/usr/bin/env bash
# Gecelik yedekleme — docs/08-kurulum-deploy.md §1.4
#
#   ./backup.sh                        # normal gecelik yedek
#   ./backup.sh --etiket=surum-oncesi  # elle, adlandırılmış yedek
#
# Alınanlar: MySQL dökümü + medya klasörü. Şifrelenir, saklama penceresi
# uygulanır ve sunucu dışına kopyalanır.
#
# ŞİFRELEME NEDEN: yedek müşteri adı, telefon ve adres içerir (KVKK).
# Sunucu dışına şifresiz bir kopya çıkarmak, veriyi güvendiğimiz sınırın
# dışına şifresiz taşımak demektir.
set -euo pipefail

KOK="$(cd "$(dirname "$0")/../.." && pwd)"
DUMP_DIZINI="$KOK/infra/backup/dumps"
# Compose dosyası dışarıdan verilebilir: geri dönüş tatbikatı dev
# ortamında da koşulabilmeli, yoksa betik yalnızca prod'da denenir
# ve orada denemek zaten istemediğimiz şey.
COMPOSE="docker compose -f ${BLD_COMPOSE:-$KOK/infra/docker-compose.yml}"
ETIKET="gecelik"

for arg in "$@"; do
  case "$arg" in
    --etiket=*) ETIKET="${arg#*=}" ;;
    *) echo "Bilinmeyen seçenek: $arg" >&2; exit 1 ;;
  esac
done

# .env yüklenir ama UID/GID atlanır: bunlar docker compose için konuldu
# ve bash'te salt-okunur oldukları için `set -a` ile kaynaklamak hata basar.
if [ -f "$KOK/infra/.env" ]; then
  set -a
  # shellcheck source=/dev/null
  . <(grep -vE '^(UID|GID)=' "$KOK/infra/.env")
  set +a
fi

: "${DB_DATABASE:?infra/.env içinde DB_DATABASE yok}"
: "${DB_USERNAME:?infra/.env içinde DB_USERNAME yok}"
: "${DB_PASSWORD:?infra/.env içinde DB_PASSWORD yok}"
: "${BACKUP_PASSPHRASE:?infra/.env içinde BACKUP_PASSPHRASE yok — yedek şifrelenemez}"

DAMGA="$(date +%Y%m%d-%H%M%S)"
AD="bld-${ETIKET}-${DAMGA}"
mkdir -p "$DUMP_DIZINI"

echo "== Yedek: $AD =="

# ── 1. Veritabanı ─────────────────────────────────────────────────────────
# --single-transaction: InnoDB'de tabloları kilitlemeden tutarlı anlık
# görüntü alır. Onsuz, gecelik yedek servis sırasında sipariş yazmayı
# bloklayabilir.
echo "  veritabanı dökümü..."

# --no-tablespaces: uygulama kullanıcısında PROCESS yetkisi yoktur ve
# mysqldump tablespace bilgisini almaya çalışıp hata basar. Bu hata
# ÖLDÜRÜCÜ DEĞİLDİR — döküm yine üretilir — ama betiği durdurmadığı için
# "yedek alındı" denip eksik dosya bırakılabilirdi. Yetkiyi genişletmek
# yerine ihtiyaç duyulmayan bölümü hiç istemiyoruz.
#
# Dökümü ÖNCE düz dosyaya alıyoruz: doğrudan boruya akıtınca mysqldump'ın
# çıkış kodu gzip/openssl arkasında kaybolur ve bozuk bir arşiv sessizce
# yazılır. Yedekleme betiğinin sessizce başarısız olması, yedek olmamasından
# beterdir — çünkü yedek olduğu sanılır.
HAM="$(mktemp -t bld-dump-XXXXXX.sql)"
trap 'rm -f "$HAM"' EXIT

if ! $COMPOSE exec -T db mysqldump \
      --single-transaction --quick --no-tablespaces \
      --routines --triggers --events \
      -u"$DB_USERNAME" -p"$DB_PASSWORD" "$DB_DATABASE" > "$HAM" 2>"$HAM.err"; then
  echo "HATA: mysqldump başarısız:" >&2
  cat "$HAM.err" >&2
  rm -f "$HAM.err"
  exit 1
fi
rm -f "$HAM.err"

# İçerik denetimi: "komut hata vermedi" ile "veri var" aynı şey değil.
if ! grep -qi 'CREATE TABLE' "$HAM"; then
  echo "HATA: dökümde CREATE TABLE yok — boş veya bozuk döküm." >&2
  exit 1
fi

TABLO=$(grep -ci '^CREATE TABLE' "$HAM" || true)
if [ "$TABLO" -lt 20 ]; then
  # TastyIgniter tek başına 50'den fazla tablo kurar; 20'nin altı
  # neredeyse kesinlikle yarım bir dökümdür.
  echo "HATA: dökümde yalnızca $TABLO tablo var — eksik görünüyor." >&2
  exit 1
fi

gzip -9 -c "$HAM" \
  | openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -salt \
      -pass "pass:$BACKUP_PASSPHRASE" \
      -out "$DUMP_DIZINI/$AD.sql.gz.enc"

echo "  veritabanı: $(du -h "$DUMP_DIZINI/$AD.sql.gz.enc" | cut -f1), $TABLO tablo"

# ── 2. Medya ──────────────────────────────────────────────────────────────
MEDYA="$KOK/platform/storage/app"
if [ -d "$MEDYA" ]; then
  echo "  medya arşivi..."
  tar -czf - -C "$MEDYA" . \
    | openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -salt \
        -pass "pass:$BACKUP_PASSPHRASE" \
        -out "$DUMP_DIZINI/$AD-medya.tar.gz.enc"
  echo "  medya: $(du -h "$DUMP_DIZINI/$AD-medya.tar.gz.enc" | cut -f1)"
else
  echo "  medya klasörü yok, atlandı"
fi

# ── 3. Sunucu dışına kopya ────────────────────────────────────────────────
# Aynı diskte duran yedek, disk arızasında yedek değildir.
if [ -n "${BACKUP_REMOTE:-}" ]; then
  echo "  uzak kopya: $BACKUP_REMOTE"
  if rsync -az --timeout=120 "$DUMP_DIZINI/$AD"* "$BACKUP_REMOTE/"; then
    echo "  uzak kopya tamam"
  else
    # Uzak kopya başarısız olsa bile yerel yedek durur; ama bu SESSİZ
    # kalmamalı — yedeğin yarısı yoktur.
    echo "UYARI: uzak kopya BAŞARISIZ. Yerel yedek var ama sunucu dışında kopya yok." >&2
  fi
else
  echo "UYARI: BACKUP_REMOTE tanımlı değil — yedek yalnızca bu sunucuda." >&2
fi

# ── 4. Saklama penceresi ──────────────────────────────────────────────────
# 7 günlük + 4 haftalık + 3 aylık (docs/08 §1.4).
echo "  eski yedekler temizleniyor..."
cd "$DUMP_DIZINI"

# Son 7 günün hepsi kalır.
# 7–30 gün arası: her haftanın yalnızca pazartesi yedeği.
find . -name 'bld-gecelik-*' -mtime +7 -mtime -31 | while read -r f; do
  GUN=$(basename "$f" | grep -oE '[0-9]{8}' | head -1)
  [ -z "$GUN" ] && continue
  if [ "$(date -d "$GUN" +%u 2>/dev/null)" != "1" ]; then rm -f "$f"; fi
done

# 30–90 gün arası: her ayın yalnızca 1'i.
find . -name 'bld-gecelik-*' -mtime +30 -mtime -91 | while read -r f; do
  GUN=$(basename "$f" | grep -oE '[0-9]{8}' | head -1)
  [ -z "$GUN" ] && continue
  if [ "$(date -d "$GUN" +%d 2>/dev/null)" != "01" ]; then rm -f "$f"; fi
done

# 90 günden eskisi gider.
find . -name 'bld-gecelik-*' -mtime +90 -delete

echo "  kalan yedek: $(find . -name 'bld-*' | wc -l) dosya, $(du -sh . | cut -f1)"

echo
echo "Yedek tamam: $AD"
echo "GERİ DÖNÜŞ TATBİKATI AYDA BİR ZORUNLUDUR — denenmemiş yedek yedek değildir."
echo "  ./infra/backup/restore.sh $DUMP_DIZINI/$AD.sql.gz.enc --hedef=bld_tatbikat"
