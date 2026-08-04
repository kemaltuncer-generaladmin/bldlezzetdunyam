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

# ── Sipariş oluşturma ────────────────────────────────────────────────────
echo "Sipariş oluşturma"
YENI=$(curl -s "${CH[@]}" -X POST "$BASE/api/orders" -d '{
  "location_id":1,
  "items":[{"menu_id":101,"quantity":2,"option_value_ids":[32],"note":"Az acılı"}],
  "delivery_type":"delivery",
  "address":{"line1":"Test Sk 1","district":"Çankaya","city":"Ankara"},
  "payment_method":"cash"}')
SIPARIS_ID=$(echo "$YENI" | alan '.id')
# 2 × (18500 + 4000) + 4000 teslimat = 49000
kontrol "tutar sunucuda hesaplandı (49000)" 49000 "$(echo "$YENI" | alan '.total')"
kontrol "yanıtta channel alanı yok" YOK "$(echo "$YENI" | alan '.channel')"
kontrol "yanıtta pickup_code yok" YOK "$(echo "$YENI" | alan '.pickup_code')"
kontrol "durum yeni" yeni "$(echo "$YENI" | alan '.status')"

kontrol "tükenmiş ürün ITEM_UNAVAILABLE" ITEM_UNAVAILABLE \
  "$(curl -s "${CH[@]}" -X POST "$BASE/api/orders" \
    -d '{"location_id":1,"items":[{"menu_id":105,"quantity":1}],"delivery_type":"pickup","payment_method":"cash"}' \
    | alan '.error.code')"
kontrol "online ödeme kapalı → VALIDATION_FAILED" VALIDATION_FAILED \
  "$(curl -s "${CH[@]}" -X POST "$BASE/api/orders" \
    -d '{"location_id":1,"items":[{"menu_id":101,"quantity":2}],"delivery_type":"pickup","payment_method":"online"}' \
    | alan '.error.code')"
kontrol "adressiz delivery 422" VALIDATION_FAILED \
  "$(curl -s "${CH[@]}" -X POST "$BASE/api/orders" \
    -d '{"location_id":1,"items":[{"menu_id":101,"quantity":2}],"delivery_type":"delivery","payment_method":"cash"}' \
    | alan '.error.code')"
kontrol "asgari tutar altı 422" VALIDATION_FAILED \
  "$(curl -s "${CH[@]}" -X POST "$BASE/api/orders" \
    -d '{"location_id":1,"items":[{"menu_id":132,"quantity":1}],"delivery_type":"pickup","payment_method":"cash"}' \
    | alan '.error.code')"

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
  -d '{"type":"mutfak","printed_at":"2026-08-04T11:30:07Z"}')"
kontrol "ikinci ack yine 204" 204 "$(curl -s -o /dev/null -w '%{http_code}' "${KH[@]}" \
  -X POST "$BASE/api/kitchen/print-jobs/5010/ack" \
  -d '{"type":"mutfak","printed_at":"2026-08-04T11:31:00Z"}')"
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

# ── Sipariş alım şalteri (docs/10 S3) — yalnızca mock ────────────────────
if curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/__mock/reset" | grep -q 200; then
  echo "Sipariş alım şalteri (mock kancası)"
  curl -s -X POST "$BASE/__mock/location" -H 'Content-Type: application/json' \
    -d '{"ordering_enabled":false}' >/dev/null
  TOKEN=$(govde -X POST "$BASE/api/auth/login" \
    -d '{"email":"ayse@ornek.com","password":"parola123"}' | alan '.token')
  CH=("${H[@]}" -H "Authorization: Bearer $TOKEN")
  kontrol "şalter kapalıyken LOCATION_CLOSED" LOCATION_CLOSED \
    "$(curl -s "${CH[@]}" -X POST "$BASE/api/orders" \
      -d '{"location_id":1,"items":[{"menu_id":101,"quantity":2}],"delivery_type":"pickup","payment_method":"cash"}' \
      | alan '.error.code')"
  kontrol "menü hâlâ görünür (SEO)" 200 "$(durum "$BASE/api/locations/1/menu")"
  curl -s -X POST "$BASE/__mock/reset" >/dev/null
fi

echo
printf 'Sonuç: \033[32m%d geçti\033[0m, \033[31m%d kaldı\033[0m\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
