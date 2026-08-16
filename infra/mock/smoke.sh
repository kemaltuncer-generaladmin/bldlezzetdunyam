#!/usr/bin/env bash
# Mock API duman testi — sözleşmenin kritik davranışlarını doğrular.
#
# Kullanım:  ./infra/mock/smoke.sh [taban_adres]
# Varsayılan: http://localhost:4010
#
# Gerçek backend hazır olunca bu betik staging'e karşı da koşulur (E-01):
#   ./infra/mock/smoke.sh https://staging-api.<domain>
# __mock/* kancaları orada olmadığı için o adımlar atlanır.

set -uo pipefail
BASE="${1:-http://localhost:4010}"
H=(-H "X-App-Id: website" -H "X-App-Version: 1.0.0" -H "Content-Type: application/json")
PASS=0
FAIL=0

kontrol() { # kontrol <aciklama> <beklenen> <gercek>
  if [ "$2" = "$3" ]; then
    printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1))
  else
    printf '  \033[31m✗\033[0m %s — beklenen: %s, gelen: %s\n' "$1" "$2" "$3"
    FAIL=$((FAIL + 1))
  fi
}

durum() { curl -s -o /dev/null -w '%{http_code}' "${H[@]}" "$@"; }
govde() { curl -s "${H[@]}" "$@"; }
# Bir JSON yolunu okur. Alan yoksa "YOK" yazar — böylece "alan bulunmamalı"
# testleri, alanın null olduğu testlerden ayrılabilir (null "null" yazar).
alan()  { node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{let v;try{v=eval('JSON.parse(d)'+process.argv[1])}catch(e){v=undefined}console.log(v===undefined?'YOK':v)})" "$1"; }

# İşletme günü (Europe/Istanbul = kalıcı UTC+03).
gun() { date -u -d "+3 hours ${1:-+0 days}" +%F; }

echo "== Mock duman testi: $BASE =="

# ── Zorunlu başlıklar ────────────────────────────────────────────────────
echo "Zorunlu başlıklar"
kontrol "başlıksız istek 422" 422 \
  "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/api/locations")"
kontrol "başlıklı istek 200" 200 "$(durum "$BASE/api/locations")"

# ── Katalog ──────────────────────────────────────────────────────────────
echo "Katalog"
kontrol "tek vitrin döner" 1 "$(govde "$BASE/api/locations" | alan '.data.length')"
kontrol "3 kategori" 3 "$(govde "$BASE/api/locations/1/menu" | alan '.data.length')"
kontrol "12 ürün" 12 \
  "$(govde "$BASE/api/locations/1/menu" | alan '.data.reduce((s,c)=>s+c.items.length,0)')"
kontrol "olmayan vitrin 404" 404 "$(durum "$BASE/api/locations/99/menu")"

VITRIN=$(govde "$BASE/api/locations")
kontrol "cari ödeme yöntemi kalktı" "false" \
  "$(echo "$VITRIN" | alan '.data[0].payment_methods.includes("account")')"
kontrol "hafta içi servis günleri" "1,2,3,4,5" \
  "$(echo "$VITRIN" | alan '.data[0].service_weekdays.join(",")')"
kontrol "azami ileri görüş 7 gün" 7 "$(echo "$VITRIN" | alan '.data[0].max_lookahead_days')"
kontrol "günlük menü şalteri açık" "true" "$(echo "$VITRIN" | alan '.data[0].daily_menu_enabled')"

# ── Cari hesap kalktı ────────────────────────────────────────────────────
echo "Cari hesap kalktı"
kontrol "/account/summary yok" 404 "$(durum "$BASE/api/account/summary")"
kontrol "/account/statement yok" 404 "$(durum "$BASE/api/account/statement")"
kontrol "/account/payments yok" 404 "$(durum -X POST "$BASE/api/account/payments" -d '{}')"

# ── Günün menüsü ─────────────────────────────────────────────────────────
echo "Günün menüsü"
TAKVIM=$(govde "$BASE/api/locations/1/menu-calendar?from=$(gun)&to=$(gun '+7 days')")
kontrol "takvim gün döndürüyor" "true" "$(echo "$TAKVIM" | alan '.data.length>0')"
kontrol "hafta sonu işaretli" "true" \
  "$(echo "$TAKVIM" | alan '.data.some(d=>d.weekend===true&&d.has_menu===false)')"
kontrol "tükenmiş gün işaretli" "true" \
  "$(echo "$TAKVIM" | alan '.data.some(d=>d.sold_out===true&&d.is_orderable===false)')"
kontrol "her günde cutoff_at alanı var" "true" \
  "$(echo "$TAKVIM" | alan '.data.every(d=>"cutoff_at" in d)')"
kontrol "aralık ters ise 422" VALIDATION_FAILED \
  "$(govde "$BASE/api/locations/1/menu-calendar?from=$(gun '+3 days')&to=$(gun)" | alan '.error.code')"
kontrol "92 günden geniş aralık 422" VALIDATION_FAILED \
  "$(govde "$BASE/api/locations/1/menu-calendar?from=$(gun)&to=$(gun '+120 days')" | alan '.error.code')"

GUN=$(echo "$TAKVIM" | alan '.data.find(d=>d.is_orderable&&d.package_price!==null).date')
MENU=$(govde "$BASE/api/locations/1/daily-menu?date=$GUN")
kontrol "sipariş verilebilir gün bulundu" "true" "$([ "$GUN" != YOK ] && echo true || echo false)"
kontrol "menüde paket var" 100 "$(echo "$MENU" | alan '.data.package.menu_id')"
kontrol "kalem fiyatı gün istisnasını uyguluyor" "true" \
  "$(echo "$MENU" | alan '.data.items.every(i=>Number.isInteger(i.price))')"
KALEM_TOPLAM=$(echo "$MENU" | alan '.data.items_total')
PAKET_FIYAT=$(echo "$MENU" | alan '.data.package.price')
kontrol "paket avantajı pozitif" "true" \
  "$([ "$KALEM_TOPLAM" -gt "$PAKET_FIYAT" ] && echo true || echo false)"
kontrol "cutoff_at mutlak an" "true" \
  "$(echo "$MENU" | alan '.data.cutoff_at' \
     | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' && echo true || echo false)"
kontrol "image_urls en fazla 4" "true" "$(echo "$MENU" | alan '.data.image_urls.length<=4')"
kontrol "yalnız pakette verilen kalem listede yok" "false" \
  "$(echo "$MENU" | alan '.data.items.some(i=>i.id===132)')"

GECMIS=$(govde "$BASE/api/locations/1/daily-menu?date=$(gun '-1 days')")
kontrol "geçmiş gün 200 ve past" past "$(echo "$GECMIS" | alan '.data.unavailable_reason')"
kontrol "geçmiş günde menü boş" 0 "$(echo "$GECMIS" | alan '.data.items.length')"
kontrol "ileri görüş dışı gün too_far" too_far \
  "$(govde "$BASE/api/locations/1/daily-menu?date=$(gun '+9 days')" | alan '.data.unavailable_reason')"
kontrol "bozuk tarih 422" VALIDATION_FAILED \
  "$(govde "$BASE/api/locations/1/daily-menu?date=2026-02-31" | alan '.error.code')"

HAFTASONU=$(echo "$TAKVIM" | alan '.data.find(d=>d.weekend).date')
kontrol "hafta sonu no_service_day" no_service_day \
  "$(govde "$BASE/api/locations/1/daily-menu?date=$HAFTASONU" | alan '.data.unavailable_reason')"

TUKENDI=$(echo "$TAKVIM" | alan '.data.find(d=>d.sold_out).date')
kontrol "tükenmiş gün sold_out" sold_out \
  "$(govde "$BASE/api/locations/1/daily-menu?date=$TUKENDI" | alan '.data.unavailable_reason')"
kontrol "tükenmiş günde kalan porsiyon 0" 0 \
  "$(govde "$BASE/api/locations/1/daily-menu?date=$TUKENDI" | alan '.data.remaining_portions')"

TAVANLI=$(echo "$TAKVIM" | alan '.data.filter(d=>d.has_menu&&!d.sold_out).map(d=>d.date).join(" ")')
KALAN=YOK
for d in $TAVANLI; do
  R=$(govde "$BASE/api/locations/1/daily-menu?date=$d" | alan '.data.remaining_portions')
  if [ "$R" != "null" ] && [ "$R" != YOK ]; then KALAN=$R; break; fi
done
kontrol "stok tavanlı gün kalan porsiyon gösteriyor" "true" \
  "$([ "$KALAN" != YOK ] && [ "$KALAN" -gt 0 ] && echo true || echo false)"

# ── Duyuru ve hata toplama ───────────────────────────────────────────────
echo "Duyuru ve hata toplama"
kontrol "yürürlükteki duyurular döner" "true" \
  "$(govde "$BASE/api/announcements" | alan '.data.length>0')"
kontrol "süresi dolmuş duyuru elenir" "false" \
  "$(govde "$BASE/api/announcements" | alan '.data.some(a=>a.id===3)')"
kontrol "istemci hatası 204" 204 \
  "$(durum -X POST "$BASE/api/client-errors" -d '{"message":"Duman testi","occurred_at":"2026-08-16T09:00:00Z"}')"

# ── Kimlik ───────────────────────────────────────────────────────────────
echo "Kimlik"
LOGIN=$(govde -X POST "$BASE/api/auth/login" \
  -d '{"email":"ayse@ornek.com","password":"parola123"}')
TOKEN=$(echo "$LOGIN" | alan '.token')
kontrol "giriş token döner" "0" "$([ -n "$TOKEN" ] && [ "$TOKEN" != YOK ] && echo 0 || echo 1)"
kontrol "yanlış şifre 422" 422 "$(durum -X POST "$BASE/api/auth/login" \
  -d '{"email":"ayse@ornek.com","password":"yanlis"}')"
kontrol "kvkk onaysız kayıt 422" 422 "$(durum -X POST "$BASE/api/auth/register" \
  -d '{"first_name":"A","last_name":"B","email":"yeni@ornek.com","telephone":"5551110000","password":"parola123","kvkk_accepted":false}')"

CH=("${H[@]}" -H "Authorization: Bearer $TOKEN")
kontrol "me çalışır" 200 "$(curl -s -o /dev/null -w '%{http_code}' "${CH[@]}" "$BASE/api/auth/me")"
kontrol "me'de group alanı yok" YOK \
  "$(curl -s "${CH[@]}" "$BASE/api/auth/me" | alan '.group')"
# Sipariş kapısı kalktı: hesap tipi ne olursa olsun sipariş verilebilir.
kontrol "herkes sipariş verebilir" "true" \
  "$(curl -s "${CH[@]}" "$BASE/api/auth/me" | alan '.can_order')"

# ── Sipariş oluşturma ────────────────────────────────────────────────────
echo "Sipariş oluşturma"
BEKLENEN=$((PAKET_FIYAT * 2 + 4000))
YENI=$(curl -s "${CH[@]}" -X POST "$BASE/api/orders" -d "{
  \"location_id\":1,
  \"service_date\":\"$GUN\",
  \"items\":[{\"menu_id\":100,\"quantity\":2}],
  \"delivery_type\":\"delivery\",
  \"address\":{\"line1\":\"Test Sk 1\",\"district\":\"Çankaya\",\"city\":\"Ankara\"},
  \"payment_method\":\"cash\"}")
SIPARIS_ID=$(echo "$YENI" | alan '.id')
kontrol "paket tutarı sunucuda hesaplandı" "$BEKLENEN" "$(echo "$YENI" | alan '.total')"
kontrol "servis günü yanıtta" "$GUN" "$(echo "$YENI" | alan '.service_date')"
kontrol "yanıtta channel alanı yok" YOK "$(echo "$YENI" | alan '.channel')"
kontrol "yanıtta pickup_code yok" YOK "$(echo "$YENI" | alan '.pickup_code')"
kontrol "durum yeni" yeni "$(echo "$YENI" | alan '.status')"

kontrol "cari ödeme reddedilir" VALIDATION_FAILED \
  "$(curl -s "${CH[@]}" -X POST "$BASE/api/orders" \
    -d "{\"location_id\":1,\"service_date\":\"$GUN\",\"items\":[{\"menu_id\":100,\"quantity\":2}],\"delivery_type\":\"pickup\",\"payment_method\":\"account\"}" \
    | alan '.error.code')"
kontrol "yalnız pakette verilen kalem tek satılmaz" ITEM_UNAVAILABLE \
  "$(curl -s "${CH[@]}" -X POST "$BASE/api/orders" \
    -d "{\"location_id\":1,\"service_date\":\"$GUN\",\"items\":[{\"menu_id\":132,\"quantity\":20}],\"delivery_type\":\"pickup\",\"payment_method\":\"cash\"}" \
    | alan '.error.code')"
kontrol "menüde olmayan ürün ITEM_UNAVAILABLE" ITEM_UNAVAILABLE \
  "$(curl -s "${CH[@]}" -X POST "$BASE/api/orders" \
    -d "{\"location_id\":1,\"service_date\":\"$GUN\",\"items\":[{\"menu_id\":105,\"quantity\":2}],\"delivery_type\":\"pickup\",\"payment_method\":\"cash\"}" \
    | alan '.error.code')"
kontrol "tükenmiş güne sipariş verilemez" ITEM_UNAVAILABLE \
  "$(curl -s "${CH[@]}" -X POST "$BASE/api/orders" \
    -d "{\"location_id\":1,\"service_date\":\"$TUKENDI\",\"items\":[{\"menu_id\":100,\"quantity\":1}],\"delivery_type\":\"pickup\",\"payment_method\":\"cash\"}" \
    | alan '.error.code')"
kontrol "hafta sonuna sipariş verilemez" LOCATION_CLOSED \
  "$(curl -s "${CH[@]}" -X POST "$BASE/api/orders" \
    -d "{\"location_id\":1,\"service_date\":\"$HAFTASONU\",\"items\":[{\"menu_id\":100,\"quantity\":1}],\"delivery_type\":\"pickup\",\"payment_method\":\"cash\"}" \
    | alan '.error.code')"
kontrol "ileri görüş dışına sipariş verilemez" VALIDATION_FAILED \
  "$(curl -s "${CH[@]}" -X POST "$BASE/api/orders" \
    -d "{\"location_id\":1,\"service_date\":\"$(gun '+9 days')\",\"items\":[{\"menu_id\":100,\"quantity\":1}],\"delivery_type\":\"pickup\",\"payment_method\":\"cash\"}" \
    | alan '.error.code')"
kontrol "adressiz delivery 422" VALIDATION_FAILED \
  "$(curl -s "${CH[@]}" -X POST "$BASE/api/orders" \
    -d "{\"location_id\":1,\"service_date\":\"$GUN\",\"items\":[{\"menu_id\":100,\"quantity\":2}],\"delivery_type\":\"delivery\",\"payment_method\":\"cash\"}" \
    | alan '.error.code')"
kontrol "asgari tutar altı 422" VALIDATION_FAILED \
  "$(curl -s "${CH[@]}" -X POST "$BASE/api/orders" \
    -d "{\"location_id\":1,\"service_date\":\"$GUN\",\"items\":[{\"menu_id\":118,\"quantity\":1}],\"delivery_type\":\"pickup\",\"payment_method\":\"cash\"}" \
    | alan '.error.code')"

# ── Abonelik ödemesi ve sözleşme ─────────────────────────────────────────
echo "Abonelik ödemesi ve sözleşme"
MTOKEN=$(govde -X POST "$BASE/api/auth/login" \
  -d '{"email":"mehmet@ornek.com","password":"parola123"}' | alan '.token')
MH=("${H[@]}" -H "Authorization: Bearer $MTOKEN")
ODEME=$(curl -s "${MH[@]}" -X POST "$BASE/api/subscriptions/1/payments" \
  -d '{"payment_method":"online","period":"2026-09"}')
ODEME_ID=$(echo "$ODEME" | alan '.payment_id')
kontrol "online ödeme 3D Secure'a düşer" otp "$(echo "$ODEME" | alan '.next_action')"
kontrol "ödeme beklemede" pending "$(echo "$ODEME" | alan '.status')"
kontrol "kapıda ödeme anında kapanır" none \
  "$(curl -s "${MH[@]}" -X POST "$BASE/api/subscriptions/1/payments" \
    -d '{"payment_method":"cash","period":"2026-10"}' | alan '.next_action')"
kontrol "yanlış OTP reddedilir" VALIDATION_FAILED \
  "$(curl -s "${MH[@]}" -X POST "$BASE/api/subscriptions/1/payments/confirm" \
    -d "{\"payment_id\":$ODEME_ID,\"code\":\"000000\"}" | alan '.error.code')"

if curl -s -o /dev/null -w '%{http_code}' "$BASE/__mock/payment-otp/$ODEME_ID" | grep -q 200; then
  KOD=$(curl -s "$BASE/__mock/payment-otp/$ODEME_ID" | alan '.code')
  kontrol "doğru OTP ile ödeme kapanır" paid \
    "$(curl -s "${MH[@]}" -X POST "$BASE/api/subscriptions/1/payments/confirm" \
      -d "{\"payment_id\":$ODEME_ID,\"code\":\"$KOD\"}" | alan '.status')"
fi

kontrol "sözleşme girişsiz okunur" pending \
  "$(govde "$BASE/api/contracts/SOZLESME-MOCK" | alan '.status')"
kontrol "sözleşmede telefon maskeli" "true" \
  "$(govde "$BASE/api/contracts/SOZLESME-MOCK" | alan '.signer_phone_masked.includes("*")')"
kontrol "olmayan sözleşme 404" 404 "$(durum "$BASE/api/contracts/YOK")"
kontrol "onay kodu istenir 202" 202 \
  "$(durum -X POST "$BASE/api/contracts/SOZLESME-MOCK/otp" -d '{}')"
kontrol "kodsuz imza reddedilir" VALIDATION_FAILED \
  "$(govde -X POST "$BASE/api/contracts/SOZLESME-MOCK" -d '{"code":"000000"}' | alan '.error.code')"

if curl -s -o /dev/null -w '%{http_code}' "$BASE/__mock/otp/5559876543" | grep -q 200; then
  SKOD=$(curl -s "$BASE/__mock/otp/5559876543" | alan '.code')
  kontrol "doğru kodla imzalanır" signed \
    "$(govde -X POST "$BASE/api/contracts/SOZLESME-MOCK" -d "{\"code\":\"$SKOD\"}" | alan '.status')"
  kontrol "imza aboneliği yürürlüğe alır" active \
    "$(curl -s "${MH[@]}" "$BASE/api/subscriptions/1" | alan '.status')"
fi

# ── Kapsam ayrımı (docs/10 S5) ───────────────────────────────────────────
echo "Kapsam ayrımı"
kontrol "müşteri token'ı /kitchen/* → 403" 403 \
  "$(curl -s -o /dev/null -w '%{http_code}' "${CH[@]}" "$BASE/api/kitchen/orders")"
kontrol "token'sız /orders → 401" 401 "$(durum "$BASE/api/orders")"

PAIR=$(govde -X POST "$BASE/api/kitchen/pair" \
  -d '{"pairing_code":"BLD1-MOCK","device_name":"Duman Testi"}')
KTOKEN=$(echo "$PAIR" | alan '.token')
KH=("${H[@]}" -H "Authorization: Bearer $KTOKEN")
kontrol "yanlış eşleme kodu 404" 404 "$(durum -X POST "$BASE/api/kitchen/pair" \
  -d '{"pairing_code":"YANLIS","device_name":"X"}')"
kontrol "mutfak token'ı /orders → 403" 403 \
  "$(curl -s -o /dev/null -w '%{http_code}' "${KH[@]}" "$BASE/api/orders")"
kontrol "başkasının siparişi 404 (403 değil)" 404 \
  "$(curl -s -o /dev/null -w '%{http_code}' "${CH[@]}" "$BASE/api/orders/5009")"

# ── Mutfak listesi ───────────────────────────────────────────────────────
echo "Mutfak listesi"
KL=$(curl -s "${KH[@]}" "$BASE/api/kitchen/orders")
kontrol "tamamlananlar hariç" "false" \
  "$(echo "$KL" | alan '.data.some(o=>o.status==="teslim_edildi")')"
kontrol "mutfak siparişinde fiyat yok" "true" \
  "$(echo "$KL" | alan '.data.every(o=>o.total===undefined&&o.items.every(i=>i.unit_price===undefined))')"
kontrol "mutfak siparişinde adres yok" "true" \
  "$(echo "$KL" | alan '.data.every(o=>o.address===undefined)')"
kontrol "mutfak kartında servis günü var" "true" \
  "$(echo "$KL" | alan '.data.every(o=>typeof o.service_date==="string")')"
kontrol "customer_label baş harfli" "Ayşe Y." \
  "$(echo "$KL" | alan '.data.find(o=>o.id===5012).customer_label')"
kontrol "server_time var" "true" "$(echo "$KL" | alan '.server_time!==undefined')"

SINCE=$(echo "$KL" | alan '.server_time')
kontrol "since ile boş liste (değişiklik yok)" 0 \
  "$(curl -s "${KH[@]}" "$BASE/api/kitchen/orders?since=$SINCE" | alan '.data.length')"
kontrol "after ile yalnızca yeniler" "true" \
  "$(curl -s "${KH[@]}" "$BASE/api/kitchen/orders?after=5011" | alan '.data.every(o=>o.id>5011)')"

# ── Durum geçişleri (docs/10 S6) ─────────────────────────────────────────
echo "Durum geçişleri"
kontrol "yeni → hazir reddedilir" INVALID_TRANSITION \
  "$(curl -s "${KH[@]}" -X POST "$BASE/api/kitchen/orders/$SIPARIS_ID/status" \
    -d '{"status":"hazir"}' | alan '.error.code')"
kontrol "yeni → onaylandi kabul" onaylandi \
  "$(curl -s "${KH[@]}" -X POST "$BASE/api/kitchen/orders/$SIPARIS_ID/status" \
    -d '{"status":"onaylandi"}' | alan '.status')"
kontrol "teslim_edildi'den çıkış yok" INVALID_TRANSITION \
  "$(curl -s "${KH[@]}" -X POST "$BASE/api/kitchen/orders/5008/status" \
    -d '{"status":"yolda"}' | alan '.error.code')"
# 5009 hazir + pickup
kontrol "pickup'ta hazir → yolda reddedilir" INVALID_TRANSITION \
  "$(curl -s "${KH[@]}" -X POST "$BASE/api/kitchen/orders/5009/status" \
    -d '{"status":"yolda"}' | alan '.error.code')"
kontrol "pickup'ta hazir → teslim_edildi kabul" teslim_edildi \
  "$(curl -s "${KH[@]}" -X POST "$BASE/api/kitchen/orders/5009/status" \
    -d '{"status":"teslim_edildi"}' | alan '.status')"

# ── Fişler ───────────────────────────────────────────────────────────────
echo "Fişler"
kontrol "mutfak fişinde fiyat yok" "true" \
  "$(curl -s "${KH[@]}" "$BASE/api/kitchen/orders/5010/receipt?type=mutfak" \
    | alan '.total===undefined')"
kontrol "müşteri fişinde adres var (delivery)" "Çankaya" \
  "$(curl -s "${KH[@]}" "$BASE/api/kitchen/orders/5010/receipt?type=musteri" \
    | alan '.address.district')"
kontrol "müşteri fişinde adres yok (pickup)" "null" \
  "$(curl -s "${KH[@]}" "$BASE/api/kitchen/orders/5011/receipt?type=musteri" \
    | alan '.address')"
kontrol "teslim fiş tipi kalktı" VALIDATION_FAILED \
  "$(curl -s "${KH[@]}" "$BASE/api/kitchen/orders/5010/receipt?type=teslim" \
    | alan '.error.code')"

# ── Fiş ack idempotentliği (docs/10 S4) ──────────────────────────────────
echo "Fiş ack idempotentliği"
kontrol "ilk ack 204" 204 "$(curl -s -o /dev/null -w '%{http_code}' "${KH[@]}" \
  -X POST "$BASE/api/kitchen/print-jobs/5010/ack" \
  -d '{"type":"mutfak","printed_at":"2026-08-04T11:30:07Z","revision":2}')"
kontrol "ikinci ack yine 204" 204 "$(curl -s -o /dev/null -w '%{http_code}' "${KH[@]}" \
  -X POST "$BASE/api/kitchen/print-jobs/5010/ack" \
  -d '{"type":"mutfak","printed_at":"2026-08-04T11:31:00Z","revision":2}')"
kontrol "printed_at ilk değerde kaldı" "2026-08-04T11:30:07Z" \
  "$(curl -s "${KH[@]}" "$BASE/api/kitchen/orders/5010/receipt?type=mutfak" | alan '.printed_at')"

# ── Üretim listesi ve heartbeat ──────────────────────────────────────────
echo "Üretim listesi"
kontrol "aktif siparişlerin toplamı" "true" \
  "$(curl -s "${KH[@]}" "$BASE/api/kitchen/production-list" | alan '.data.length>0')"
kontrol "çoktan aza sıralı" "true" \
  "$(curl -s "${KH[@]}" "$BASE/api/kitchen/production-list" \
    | alan '.data.every((x,i,a)=>i===0||a[i-1].total>=x.total)')"
kontrol "heartbeat min sürüm döner" "1.0.0" \
  "$(curl -s "${KH[@]}" "$BASE/api/kitchen/heartbeat" | alan '.min_supported_version')"

# ── Yalnızca mock: şalter ve kesim saati ─────────────────────────────────
if curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/__mock/reset" | grep -q 200; then
  echo "Sipariş alım şalteri (mock kancası)"
  curl -s -X POST "$BASE/__mock/location" -H 'Content-Type: application/json' \
    -d '{"ordering_enabled":false}' >/dev/null
  TOKEN=$(govde -X POST "$BASE/api/auth/login" \
    -d '{"email":"ayse@ornek.com","password":"parola123"}' | alan '.token')
  CH=("${H[@]}" -H "Authorization: Bearer $TOKEN")
  kontrol "şalter kapalıyken LOCATION_CLOSED" LOCATION_CLOSED \
    "$(curl -s "${CH[@]}" -X POST "$BASE/api/orders" \
      -d "{\"location_id\":1,\"service_date\":\"$GUN\",\"items\":[{\"menu_id\":100,\"quantity\":2}],\"delivery_type\":\"pickup\",\"payment_method\":\"cash\"}" \
      | alan '.error.code')"
  kontrol "menü hâlâ görünür (SEO)" 200 "$(durum "$BASE/api/locations/1/menu")"
  curl -s -X POST "$BASE/__mock/reset" >/dev/null

  echo "Kesim saati (mock kancası)"
  # Kesim saatini günün başına çekip bugüne menü açıyoruz: "kesim geçti"
  # dalı ancak böyle, haftanın gününden bağımsız denenebiliyor.
  TOKEN=$(govde -X POST "$BASE/api/auth/login" \
    -d '{"email":"ayse@ornek.com","password":"parola123"}' | alan '.token')
  CH=("${H[@]}" -H "Authorization: Bearer $TOKEN")
  curl -s -X POST "$BASE/__mock/location" -H 'Content-Type: application/json' \
    -d '{"order_cutoff":"00:00","service_weekdays":[1,2,3,4,5,6,7]}' >/dev/null
  curl -s -X POST "$BASE/__mock/daily-menu/$(gun)" -H 'Content-Type: application/json' \
    -d '{"published":true}' >/dev/null
  kontrol "kesim saati geçmiş gün cutoff_passed" cutoff_passed \
    "$(govde "$BASE/api/locations/1/daily-menu?date=$(gun)" | alan '.data.unavailable_reason')"
  kontrol "kesim geçmiş güne sipariş LOCATION_CLOSED" LOCATION_CLOSED \
    "$(curl -s "${CH[@]}" -X POST "$BASE/api/orders" \
      -d "{\"location_id\":1,\"service_date\":\"$(gun)\",\"items\":[{\"menu_id\":100,\"quantity\":2}],\"delivery_type\":\"pickup\",\"payment_method\":\"cash\"}" \
      | alan '.error.code')"
  curl -s -X POST "$BASE/__mock/reset" >/dev/null
fi

echo
printf 'Sonuç: \033[32m%d geçti\033[0m, \033[31m%d kaldı\033[0m\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
