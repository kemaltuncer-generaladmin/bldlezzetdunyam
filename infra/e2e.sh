#!/usr/bin/env bash
# Sözleşme uçtan uca testi — HEM mock HEM gerçek backend'e karşı koşar.
#
#   ./infra/e2e.sh http://localhost:4010     # mock
#   ./infra/e2e.sh http://localhost:8080     # gerçek backend
#   ./infra/e2e.sh https://api.benimlezzetdunyam.com.tr   # staging/prod
#
# NEDEN TEK BETİK: `E-01` entegrasyon gününün tek işi, istemciler mock'tan
# gerçeğe geçerken sözleşme uyuşmazlıklarını bulmak. İki ayrı test kümesi
# tutulursa, "mock'ta geçiyor gerçekte geçmiyor" farkının kaynağı testin
# kendisi mi sunucu mu, ayırt edilemez.
#
# Hiçbir kimlik sabit değildir: vitrin, ürün ve sipariş kimlikleri çalışma
# anında keşfedilir.
set -uo pipefail

BASE="${1:-http://localhost:8080}"
API="$BASE/api"
H=(-H "X-App-Id: website" -H "X-App-Version: 1.0.0" -H "Content-Type: application/json")
KHDR=(-H "X-App-Id: mutfakapp" -H "X-App-Version: 1.0.0" -H "Content-Type: application/json")
PASS=0; FAIL=0; SKIP=0

ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
no()   { printf '  \033[31m✗\033[0m %s — beklenen: %s, gelen: %s\n' "$1" "$2" "$3"; FAIL=$((FAIL+1)); }
skip() { printf '  \033[33m–\033[0m %s (%s)\n' "$1" "$2"; SKIP=$((SKIP+1)); }
is()   { [ "$2" = "$3" ] && ok "$1" || no "$1" "$2" "$3"; }

j() { node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{let v;try{v=eval('JSON.parse(d)'+process.argv[1])}catch(e){v=undefined}console.log(v===undefined?'YOK':v)})" "$1"; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }

echo "== Sözleşme uçtan uca testi: $BASE =="

# Hız sınırına takılıysak DUR. 429 alındığında her uç aynı gövdeyi döner
# ve paketin tamamı kırmızıya boyanır — 30 uydurma başarısızlık, tek
# gerçek sebep. Bu yüzden peşin bakıyoruz: art arda koşulan testler
# `bld-order` penceresini (saatte 20) tüketebilir.
if [ "$(code "${H[@]}" -X POST "$API/orders" -d '{}')" = "429" ]; then
  printf '\033[31mDURDU:\033[0m hız sınırı etkin (429). Pencere dolana kadar\n'
  printf '       sonuçlar anlamsız olur. Bir sonraki saati bekleyin ya da\n'
  printf '       sunucuda sayaçları sıfırlayın: artisan cache:clear\n'
  exit 2
fi

# ── Sağlık ve zorunlu başlıklar ──────────────────────────────────────────
echo "Sağlık ve başlıklar"
is "başlıksız istek 422" 422 "$(code "$API/health")"
is "sağlık ucu 200" 200 "$(code "${H[@]}" "$API/health")"
is "geçersiz X-App-Id 422" 422 \
  "$(code -H 'X-App-Id: korsan' -H 'X-App-Version: 1.0.0' "$API/health")"
is "olmayan uç 404" 404 "$(code "${H[@]}" "$API/bilinmeyen")"

# ── Katalog ──────────────────────────────────────────────────────────────
echo "Katalog"
LOC=$(curl -s "${H[@]}" "$API/locations")
is "tek vitrin döner" 1 "$(echo "$LOC" | j '.data.length')"
LID=$(echo "$LOC" | j '.data[0].id')
is "online ödeme sunuluyor (simülasyon geçidi)" "true" \
  "$(echo "$LOC" | j '.data[0].payment_methods.includes("online")')"
is "ordering_enabled alanı var" "true" \
  "$(echo "$LOC" | j '.data[0].ordering_enabled!==undefined')"
# Müşteri toplamı onaydan ÖNCE görebilmeli — alan yoksa web sitesi
# yalnızca ara toplam gösterebiliyordu (mesafeli satış sorunu).
is "delivery_fee vitrinde ilan ediliyor" "true" \
  "$(echo "$LOC" | j '.data[0].delivery_fee!==undefined')"

MENU=$(curl -s "${H[@]}" "$API/locations/$LID/menu")
is "3 kategori" 3 "$(echo "$MENU" | j '.data.length')"
is "12 ürün" 12 "$(echo "$MENU" | j '.data.reduce((s,c)=>s+c.items.length,0)')"
is "tükenmiş ürün listede kalır" "false" \
  "$(echo "$MENU" | j '.data.flatMap(c=>c.items).find(i=>i.name==="Izgara Köfte").is_available')"
is "fiyat kuruş tamsayı" 18500 \
  "$(echo "$MENU" | j '.data.flatMap(c=>c.items).find(i=>i.name==="Tavuk Sote").price')"
is "olmayan vitrin 404" 404 "$(code "${H[@]}" "$API/locations/99999/menu")"

TAVUK=$(echo "$MENU" | j '.data.flatMap(c=>c.items).find(i=>i.name==="Tavuk Sote").id')
KOFTE=$(echo "$MENU" | j '.data.flatMap(c=>c.items).find(i=>i.name==="Izgara Köfte").id')
AYRAN=$(echo "$MENU" | j '.data.flatMap(c=>c.items).find(i=>i.name==="Ayran").id')

# ── Kimlik ───────────────────────────────────────────────────────────────
echo "Kimlik"
EPOSTA="e2e$(date +%s)@ornek.com"
REG=$(curl -s "${H[@]}" -X POST "$API/auth/register" \
  -d "{\"first_name\":\"Ayşe\",\"last_name\":\"Yılmaz\",\"email\":\"$EPOSTA\",\"telephone\":\"5551234567\",\"password\":\"parola123\",\"kvkk_accepted\":true}")
TOKEN=$(echo "$REG" | j '.token')
is "kayıt token döner" "0" "$([ "$TOKEN" != YOK ] && echo 0 || echo 1)"
is "KVKK onaysız kayıt 422" VALIDATION_FAILED \
  "$(curl -s "${H[@]}" -X POST "$API/auth/register" \
     -d "{\"first_name\":\"A\",\"last_name\":\"B\",\"email\":\"x$(date +%s)@y.com\",\"telephone\":\"5551110000\",\"password\":\"parola123\",\"kvkk_accepted\":false}" | j '.error.code')"
is "yanlış şifre 422" VALIDATION_FAILED \
  "$(curl -s "${H[@]}" -X POST "$API/auth/login" -d "{\"email\":\"$EPOSTA\",\"password\":\"yanlis\"}" | j '.error.code')"

CH=("${H[@]}" -H "Authorization: Bearer $TOKEN")
is "me çalışır" 200 "$(code "${CH[@]}" "$API/auth/me")"
is "me'de group alanı yok" YOK "$(curl -s "${CH[@]}" "$API/auth/me" | j '.group')"

# ── Kapsam ayrımı (docs/10 S5) ───────────────────────────────────────────
echo "Kapsam ayrımı"
is "token'sız /orders 401" 401 "$(code "${H[@]}" "$API/orders")"
is "müşteri token'ı /kitchen/* 403" 403 "$(code "${CH[@]}" "$API/kitchen/orders")"
is "geçersiz eşleme kodu 404" 404 \
  "$(code "${KHDR[@]}" -X POST "$API/kitchen/pair" -d '{"pairing_code":"AAAA-BBBB","device_name":"Sahte"}')"

# Eşleme kodu: mock'ta sabit, gerçekte artisan komutu üretir.
CODE="BLD1-MOCK"
if [ "$(code "${KHDR[@]}" -X POST "$API/kitchen/pair" -d "{\"pairing_code\":\"$CODE\",\"device_name\":\"E2E\"}")" != "200" ]; then
  # Eşleme kodu artisan ile üretilir. Nerede koşulacağı ortama göre
  # değişir: yerelde docker compose, sunucuda ssh + docker exec.
  # BLD_ARTISAN ile dışarıdan verilebilir.
  ARTISAN="${BLD_ARTISAN:-docker compose -f $(dirname "$0")/docker-compose.dev.yml exec -T -e HOME=/tmp app php artisan}"
  # Cihaz adında BOŞLUK OLMAMALI. Uzak koşumda ($ARTISAN bir ssh
  # komutudur) argümanları bir de karşı taraftaki kabuk ayrıştırır ve
  # "E2E 123" iki argümana bölünür — komut "No arguments expected" ile
  # düşer, eşleme sessizce atlanır ve mutfak testlerinin tamamı kaybolur.
  CODE=$($ARTISAN veykemtu:kds --new=E2E-$(date +%s) 2>/dev/null \
    | sed 's/\x1b\[[0-9;]*m//g' | grep -oE '[A-Z0-9]{4}-[A-Z0-9]{4}' | head -1)
fi
KT=$(curl -s "${KHDR[@]}" -X POST "$API/kitchen/pair" -d "{\"pairing_code\":\"$CODE\",\"device_name\":\"E2E\"}" | j '.token')
if [ "$KT" = YOK ]; then
  skip "mutfak uçları" "eşleme kodu alınamadı"
  KT=""
else
  ok "cihaz eşleme başarılı"
fi
KH=("${KHDR[@]}" -H "Authorization: Bearer $KT")
[ -n "$KT" ] && is "mutfak token'ı /orders 403" 403 "$(code "${KH[@]}" "$API/orders")"

# ── Sipariş oluşturma ────────────────────────────────────────────────────
echo "Sipariş oluşturma"
ADDR='{"line1":"Örnek Mah. 12. Sk No:3","district":"Çankaya","city":"Ankara"}'
NEW=$(curl -s "${CH[@]}" -X POST "$API/orders" \
  -d "{\"location_id\":$LID,\"items\":[{\"menu_id\":$TAVUK,\"quantity\":2,\"note\":\"Az acılı\"}],\"delivery_type\":\"delivery\",\"address\":$ADDR,\"payment_method\":\"cash\",\"customer_note\":\"Fatura kurumsal\",\"total\":1}")
OID=$(echo "$NEW" | j '.id')
is "durum yeni" yeni "$(echo "$NEW" | j '.status')"
is "yanıtta channel yok" YOK "$(echo "$NEW" | j '.channel')"
is "yanıtta pickup_code yok" YOK "$(echo "$NEW" | j '.pickup_code')"
# Toplam, teslimat ücretine bağlıdır (ortama göre değişir); sabitlemek
# yerine sunucunun kendi hesabıyla tutarlı olmasını doğruluyoruz.
NEWDET=$(curl -s "${CH[@]}" "$API/orders/$(echo "$NEW" | j '.id')")
is "ara toplam sunucuda hesaplandı" 37000 "$(echo "$NEWDET" | j '.subtotal')"
is "toplam = ara toplam + teslimat" "true" \
  "$(echo "$NEWDET" | j '["total"]===JSON.parse(d).subtotal+JSON.parse(d).delivery_fee')"
is "istemcinin gönderdiği tutar yok sayıldı" "true" \
  "$(echo "$NEW" | j '.total>1')"
is "tükenmiş ürün ITEM_UNAVAILABLE" ITEM_UNAVAILABLE \
  "$(curl -s "${CH[@]}" -X POST "$API/orders" -d "{\"location_id\":$LID,\"items\":[{\"menu_id\":$KOFTE,\"quantity\":2}],\"delivery_type\":\"pickup\",\"payment_method\":\"cash\"}" | j '.error.code')"
is "tanımsız ödeme yöntemi reddedilir" VALIDATION_FAILED \
  "$(curl -s "${CH[@]}" -X POST "$API/orders" -d "{\"location_id\":$LID,\"items\":[{\"menu_id\":$TAVUK,\"quantity\":2}],\"delivery_type\":\"pickup\",\"payment_method\":\"kripto\"}" | j '.error.code')"

# Online ödeme: sipariş yönlendirme adresi döndürmeli, ödenmeden `pending`
# kalmalı. Sağlayıcı simülasyon da olsa gerçek de olsa sözleşme aynı.
ONL=$(curl -s "${CH[@]}" -X POST "$API/orders" \
  -d "{\"location_id\":$LID,\"items\":[{\"menu_id\":$TAVUK,\"quantity\":2}],\"delivery_type\":\"pickup\",\"payment_method\":\"online\"}")
is "online sipariş pending doğar" pending "$(echo "$ONL" | j '.payment.status')"
is "online siparişte yönlendirme adresi var" "true" \
  "$(echo "$ONL" | j '.payment.redirect_url!==undefined&&JSON.parse(d).payment.redirect_url!==null')"
# Yönlendirme adresinin VAR OLMASI yetmez, ÇALIŞMASI gerekir. Üretimde
# FRONTEND_URL bir kez `www.` alt alanına bakacak şekilde kaldı; o kayıt
# DNS'te yoktu ve müşteri ödemeyi bitirdikten sonra ölü bir adrese
# düşüyordu. Sipariş "paid" olduğu için hiçbir uç hata vermiyordu —
# yalnızca müşteri kayboluyordu. Bu yüzden hem ödeme sayfasını hem de
# dönüş adresinin gerçekten cevap verdiğini sınıyoruz.
RU=$(echo "$ONL" | j '.payment.redirect_url')
if [ "$RU" != "YOK" ]; then
  is "ödeme sayfası açılıyor" 200 "$(code "$RU")"
  DONUS=$(curl -s "$RU" | grep -oE 'return=[^"&]+' | head -1 | sed 's/^return=//')
  DONUS=$(printf '%b' "${DONUS//%/\\x}")
  if [ -n "$DONUS" ]; then
    is "ödeme dönüş adresi cevap veriyor" 200 "$(code -L "$DONUS")"
  else
    skip "ödeme dönüş adresi" "formda return parametresi yok"
  fi
fi

is "adressiz delivery reddedilir" VALIDATION_FAILED \
  "$(curl -s "${CH[@]}" -X POST "$API/orders" -d "{\"location_id\":$LID,\"items\":[{\"menu_id\":$TAVUK,\"quantity\":2}],\"delivery_type\":\"delivery\",\"payment_method\":\"cash\"}" | j '.error.code')"
is "asgari tutar altı reddedilir" VALIDATION_FAILED \
  "$(curl -s "${CH[@]}" -X POST "$API/orders" -d "{\"location_id\":$LID,\"items\":[{\"menu_id\":$AYRAN,\"quantity\":1}],\"delivery_type\":\"pickup\",\"payment_method\":\"cash\"}" | j '.error.code')"

echo "Sipariş görüntüleme"
DET=$(curl -s "${CH[@]}" "$API/orders/$OID")
is "detayda adres var" "Çankaya" "$(echo "$DET" | j '.address.district')"
is "durum geçmişi başlıyor" yeni "$(echo "$DET" | j '.status_history[0].status')"
is "kalem birim fiyatı" 18500 "$(echo "$DET" | j '.items[0].unit_price')"

# ── Mutfak ───────────────────────────────────────────────────────────────
if [ -n "$KT" ]; then
  echo "Mutfak"
  KL=$(curl -s "${KH[@]}" "$API/kitchen/orders")
  is "mutfak listesinde fiyat yok" "true" \
    "$(echo "$KL" | j '.data.every(o=>o.total===undefined&&o.items.every(i=>i.unit_price===undefined))')"
  is "mutfak listesinde adres yok" "true" "$(echo "$KL" | j '.data.every(o=>o.address===undefined)')"
  is "customer_label baş harfli" "Ayşe Y." "$(echo "$KL" | j ".data.find(o=>o.id===$OID).customer_label")"
  SINCE=$(echo "$KL" | j '.server_time')
  is "since ile boş liste" 0 "$(curl -s "${KH[@]}" "$API/kitchen/orders?since=$SINCE" | j '.data.length')"

  echo "Durum geçişleri"
  is "yeni → hazir reddedilir" INVALID_TRANSITION \
    "$(curl -s "${KH[@]}" -X POST "$API/kitchen/orders/$OID/status" -d '{"status":"hazir"}' | j '.error.code')"
  is "yeni → onaylandi" onaylandi \
    "$(curl -s "${KH[@]}" -X POST "$API/kitchen/orders/$OID/status" -d '{"status":"onaylandi"}' | j '.status')"
  curl -s "${KH[@]}" -X POST "$API/kitchen/orders/$OID/status" -d '{"status":"hazirlaniyor"}' >/dev/null
  curl -s "${KH[@]}" -X POST "$API/kitchen/orders/$OID/status" -d '{"status":"hazir"}' >/dev/null
  is "adrese gönderim kurye adımını atlayamaz" INVALID_TRANSITION \
    "$(curl -s "${KH[@]}" -X POST "$API/kitchen/orders/$OID/status" -d '{"status":"teslim_edildi"}' | j '.error.code')"
  is "hazir → yolda" yolda \
    "$(curl -s "${KH[@]}" -X POST "$API/kitchen/orders/$OID/status" -d '{"status":"yolda"}' | j '.status')"

  echo "Fişler ve ack"
  is "mutfak fişinde fiyat yok" YOK \
    "$(curl -s "${KH[@]}" "$API/kitchen/orders/$OID/receipt?type=mutfak" | j '.total')"
  is "müşteri fişinde ara toplam var" 37000 \
    "$(curl -s "${KH[@]}" "$API/kitchen/orders/$OID/receipt?type=musteri" | j '.subtotal')"
  is "teslim fiş tipi kaldırıldı" VALIDATION_FAILED \
    "$(curl -s "${KH[@]}" "$API/kitchen/orders/$OID/receipt?type=teslim" | j '.error.code')"
  is "ilk ack 204" 204 "$(code "${KH[@]}" -X POST "$API/kitchen/print-jobs/$OID/ack" -d '{"type":"mutfak","printed_at":"2026-08-04T11:30:07Z"}')"
  is "ikinci ack yine 204" 204 "$(code "${KH[@]}" -X POST "$API/kitchen/print-jobs/$OID/ack" -d '{"type":"mutfak","printed_at":"2026-08-04T12:00:00Z"}')"
  is "printed_at ilk değerde kaldı" "2026-08-04T11:30:07Z" \
    "$(curl -s "${KH[@]}" "$API/kitchen/orders/$OID/receipt?type=mutfak" | j '.printed_at')"

  echo "Üretim listesi ve heartbeat"
  is "heartbeat min sürüm" "1.0.0" "$(curl -s "${KH[@]}" "$API/kitchen/heartbeat" | j '.min_supported_version')"
  is "üretim listesi çoktan aza sıralı" "true" \
    "$(curl -s "${KH[@]}" "$API/kitchen/production-list" | j '.data.every((x,i,a)=>i===0||a[i-1].total>=x.total)')"
fi

# ── Gel-al dalı ──────────────────────────────────────────────────────────
echo "Gel-al dalı"
PICK=$(curl -s "${CH[@]}" -X POST "$API/orders" \
  -d "{\"location_id\":$LID,\"items\":[{\"menu_id\":$TAVUK,\"quantity\":2}],\"delivery_type\":\"pickup\",\"payment_method\":\"cash\"}")
PID=$(echo "$PICK" | j '.id')
PDET=$(curl -s "${CH[@]}" "$API/orders/$PID")
is "gel-al'da teslimat ücreti yok" 0 "$(echo "$PDET" | j '.delivery_fee')"
is "gel-al'da adres null" "null" "$(echo "$PDET" | j '.address')"
if [ -n "$KT" ]; then
  for s in onaylandi hazirlaniyor hazir; do
    curl -s "${KH[@]}" -X POST "$API/kitchen/orders/$PID/status" -d "{\"status\":\"$s\"}" >/dev/null
  done
  is "gel-al yola çıkarılamaz" INVALID_TRANSITION \
    "$(curl -s "${KH[@]}" -X POST "$API/kitchen/orders/$PID/status" -d '{"status":"yolda"}' | j '.error.code')"
  is "gel-al doğrudan teslim edilir" teslim_edildi \
    "$(curl -s "${KH[@]}" -X POST "$API/kitchen/orders/$PID/status" -d '{"status":"teslim_edildi"}' | j '.status')"
  is "terminal durumdan çıkılamaz" INVALID_TRANSITION \
    "$(curl -s "${KH[@]}" -X POST "$API/kitchen/orders/$PID/status" -d '{"status":"iptal"}' | j '.error.code')"
fi

# ── Müşteri iptali ───────────────────────────────────────────────────────
echo "Müşteri iptali"
C1=$(curl -s "${CH[@]}" -X POST "$API/orders" \
  -d "{\"location_id\":$LID,\"items\":[{\"menu_id\":$TAVUK,\"quantity\":2}],\"delivery_type\":\"pickup\",\"payment_method\":\"cash\"}" | j '.id')
is "yeni sipariş iptal edilebilir" iptal \
  "$(curl -s "${CH[@]}" -X POST "$API/orders/$C1/cancel" | j '.status')"
is "hazırlanan sipariş iptal edilemez" INVALID_TRANSITION \
  "$(curl -s "${CH[@]}" -X POST "$API/orders/$OID/cancel" | j '.error.code')"

# ── Sürüm ────────────────────────────────────────────────────────────────
echo "Sürüm"
is "app-version çalışır" mutfakapp "$(curl -s "${H[@]}" "$API/app-version?app_id=mutfakapp" | j '.app_id')"
is "bilinmeyen uygulama reddedilir" 422 "$(code "${H[@]}" "$API/app-version?app_id=korsan")"

echo
printf 'Sonuç: \033[32m%d geçti\033[0m, \033[31m%d kaldı\033[0m, \033[33m%d atlandı\033[0m\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
