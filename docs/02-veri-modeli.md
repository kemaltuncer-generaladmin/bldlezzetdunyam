# 02 — Veri Modeli

TastyIgniter'ın kendi şeması (menü, kategori, müşteri, sipariş, vitrin) **olduğu gibi** kullanılır. Bu doküman, üzerine eklediğimiz kavramları ve tüm sistemin uyacağı kuralları tanımlar.

## 1. Platformdan gelen ve kullanılan tablolar

| Tablo | Kullanım |
|---|---|
| `menus` | Ürünler. Fiyat, açıklama, görsel. |
| `categories` | Menü kategorileri. |
| `locations` | **Vitrin.** Tek kayıt: `catering`. Platformun çoklu vitrin yeteneği kullanılmaz. |
| `customers` | Müşteri hesapları. |
| `customer_groups` | Tek grup: `Catering Müşterisi`. |
| `orders` | Sipariş başlığı. |
| `order_menus` | Sipariş kalemleri. |
| `statuses` | Sipariş durumları — bizim durum makinemize göre yapılandırılır (§3). Kolonları: `status_id`, `status_name`, `status_comment`, `notify_customer`, `status_for`, `status_color`. **Kod alanı yoktur**, `bridgeapi` migration'ı ekler. |
| `status_history` | Durum geçiş geçmişi. Kim, ne zaman. |

## 2. Eklediğimiz tablolar

> **İptal edilen tablo:** `veykemtu_order_meta` ve onu barındıran `veykemtu/channels` eklentisi, kanal kavramıyla birlikte **iptal edilmiştir** (bkz. `docs/00-genel-bakis.md` §4). Siparişe eklenen kanal/teslim-kodu/kurum-içi-not alanı yoktur; TastyIgniter'ın kendi `orders` şeması olduğu gibi yeterlidir.

### 2.1 `veykemtu_kitchen_devices` (bridgeapi eklentisi)

| Kolon | Tip | Açıklama |
|---|---|---|
| `id` | bigint PK | |
| `name` | varchar | "Mutfak Kasası 1" |
| `pairing_code` | varchar(12) null | Tek kullanımlık eşleme kodu; kullanılınca null |
| `token_hash` | varchar null | Cihaz token'ının hash'i |
| `last_seen_at` | timestamp null | Son istek zamanı |
| `revoked_at` | timestamp null | İptal edilmişse dolu |
| `created_at`, `updated_at` | timestamp | |

### 2.2 `veykemtu_print_jobs` (bridgeapi eklentisi — opsiyonel sunucu kopyası)

KDS kendi kuyruğunu diskte tutar; bu tablo yalnızca **denetim** içindir (hangi fiş ne zaman basıldı).

| Kolon | Tip |
|---|---|
| `id` | bigint PK |
| `order_id` | bigint FK |
| `type` | enum: `mutfak` \| `musteri` |
| `printed_at` | timestamp null |
| `device_id` | bigint FK null |

### 2.3 `veykemtu_app_releases` (appversion eklentisi)

| Kolon | Tip | Açıklama |
|---|---|---|
| `app_id` | enum | `musteriapp` \| `mutfakapp` |
| `version` | varchar | Semver: `1.2.0` |
| `min_supported` | varchar | Bu sürümün altındakiler zorunlu güncellenir |
| `download_url` | varchar null | mutfakapp için paket adresi |
| `notes` | text null | |
| `released_at` | timestamp | |

### 2.4 `veykemtu_device_tokens` (push eklentisi)

| Kolon | Tip |
|---|---|
| `customer_id` | bigint FK |
| `fcm_token` | varchar |
| `platform` | enum: `android` |
| `updated_at` | timestamp |

## 3. Sipariş durum makinesi

**Tek makine.** `delivery_type` yalnızca `hazir` sonrası hangi dalın kullanılacağını belirler: `delivery` → `yolda` → `teslim_edildi`, `pickup` → doğrudan `teslim_edildi`.

```
   ┌──────┐  onayla   ┌───────────┐  başla   ┌──────────────┐
   │ yeni ├──────────►│ onaylandi ├─────────►│ hazirlaniyor │
   └───┬──┘           └─────┬─────┘          └──────┬───────┘
       │                    │                       │ bitti
       │                    │                       ▼
       │                    │                 ┌──────────┐
       │                    │                 │  hazir   │
       │                    │                 └────┬─────┘
       │                    │              ┌───────┴────────┐
       │                    │       çıkış  │                │ teslim
       │                    │              ▼                ▼
       │                    │         ┌────────┐    ┌───────────────┐
       │                    │         │ yolda  ├───►│ teslim_edildi │
       │                    │         └────────┘    └───────────────┘
       │                    │
       └────────┬───────────┘
                ▼
           ┌────────┐
           │ iptal  │   ← teslim_edildi hariç her durumdan
           └────────┘
```

**Durum kodları (sabit, değiştirilmez):**
`yeni` · `onaylandi` · `hazirlaniyor` · `hazir` · `yolda` · `teslim_edildi` · `iptal`

**Geçiş kuralları:**

| Kaynak | İzinli hedefler |
|---|---|
| `yeni` | `onaylandi`, `iptal` |
| `onaylandi` | `hazirlaniyor`, `iptal` |
| `hazirlaniyor` | `hazir`, `iptal` |
| `hazir` | `yolda` (`delivery_type=delivery`), `teslim_edildi` (`delivery_type=pickup`), `iptal` |
| `yolda` | `teslim_edildi`, `iptal` |
| `teslim_edildi` | — (terminal) |
| `iptal` | — (terminal) |

**Zorunluluklar:**
- Geçiş kuralları **sunucuda** uygulanır. Geçersiz geçiş → `422` + hata kodu `INVALID_TRANSITION`.
- Her geçiş `status_history`'ye yazılır: kim (cihaz veya kullanıcı), ne zaman.
- İstemci sadece hedef durumu ister; sunucu izin verir veya reddeder.
- `yolda` yalnızca `delivery_type=delivery` siparişlerde kullanılır; `pickup` siparişte `hazir → yolda` isteği `422 INVALID_TRANSITION` döner.

**Yazdırma tetikleri:**

| Durum geçişi | Basılan fiş |
|---|---|
| → `yeni` (oluşma anı) | Mutfak fişi |
| → `hazir` | Müşteri fişi |

## 4. Üretim listesi (türetilmiş veri)

Tablo değildir, sorgudur. Aktif siparişlerin (`onaylandi` + `hazirlaniyor`) ürün bazında toplamı:

```sql
-- DİKKAT: orders tablosunda status_code diye bir kolon YOKTUR (B-02'de
-- kurulu sürümden doğrulandı). orders.status_id bir tamsayı FK'dir ve
-- statuses tablosunda da kod alanı bulunmaz — kod kolonunu bizim
-- migration'ımız ekler (bkz. BILINMEYENLER, "7 durum kodu nasıl saklanacak").
SELECT m.menu_name, SUM(om.quantity) AS toplam
FROM order_menus om
JOIN orders o  ON o.order_id  = om.order_id
JOIN menus m   ON m.menu_id   = om.menu_id
JOIN statuses s ON s.status_id = o.status_id
WHERE s.status_code IN ('onaylandi','hazirlaniyor')
  AND DATE(o.order_date) = CURDATE()
GROUP BY m.menu_id
ORDER BY toplam DESC;
```

KDS bunu üst şeritte gösterir — mutfak toplam üretime bakar.

## 5. Faz 2 hazırlığı (şimdi yazılmaz, şema burada dursun)

**`veykemtu_stock_ledger`** — stok hareket defteri. Miktar kolonu güncellenmez; her olay bir satırdır, güncel stok toplamdır.

| Kolon | Tip |
|---|---|
| `id` | bigint PK |
| `item_id` | bigint FK |
| `type` | enum: `alim` \| `tuketim` \| `duzeltme` |
| `quantity` | decimal(10,3) (işaretli) |
| `unit` | varchar |
| `source` | enum: `mal_kabul` \| `sayim` \| `uretim` |
| `document_no` | varchar null |
| `created_by` | bigint |
| `created_at` | timestamp |

## 6. Veri saklama ve KVKK

- Sipariş geçmişi 2 yıl saklanır, sonrası anonimleştirilir (müşteri bağı koparılır, istatistik kalır).
- KVKK aydınlatma metni `website/` ve `musteriapp/` kayıt ekranında gösterilir; onay `customers` tablosunda zaman damgasıyla saklanır.

## 7. B2B, cari hesap ve abonelik (Faz 2 — UYGULANDI)

Tümü `bridgeapi` eklentisinde, ADR-09 additive kuralıyla: çekirdek `customers`/`orders` tablolarına yalnız `bld_` önekli kolon; geri kalan her şey `veykemtu_` önekli yeni tablo. `platform/vendor/` değişmez.

### 7.1 `customers` — kurumsal kolonlar (additive)

Müşteri grubu tek kalır ("Catering Müşterisi"); kurum/birey ayrımı kolonlarla taşınır. `up()` içinde **grandfather backfill**: mevcut tüm satırlar `corporate` yazılır — aktif alıcılar kırılmaz.

| Kolon | Tip | Not |
|---|---|---|
| `bld_account_type` | varchar(16), default `corporate`, index | `corporate` \| `individual`. Sipariş kapısının kaynağı. |
| `bld_org_name` | varchar null | Ticari unvan |
| `bld_tax_office` | varchar null | Vergi dairesi |
| `bld_tax_no` | varchar null | Vergi / TC no |
| `bld_contact_person` | varchar null | Yetkili kişi |
| `bld_org_phone` | varchar null | Kurum telefonu |

Sözleşmede `Customer.account_type` + `can_order` olarak yansır; `can_order = (bld_account_type === 'corporate')`. İstemci sipariş yolunu bu bayrağa göre açar.

### 7.2 `veykemtu_account_ledger` — cari hesap defteri (append-only)

Muhasebe yazılımı değiliz (bkz. `docs/10` §4): fatura/e-Arşiv **kesilmez**. Bu tablo borç/alacak hareketini tutar; bakiye satır silinerek değil, ters kayıtla düzeltilir.

| Kolon | Tip | Not |
|---|---|---|
| `id` | bigint PK | |
| `customer_id` | bigint | |
| `entry_type` | varchar(8) | `debit` (borç) \| `credit` (alacak) |
| `amount_kurus` | bigint | Her zaman pozitif; yön `entry_type`'ta |
| `source` | varchar(16) | `order` \| `subscription` \| `payment` \| `manual` \| `adjustment` |
| `reference_type` / `reference_id` | varchar/bigint null | Kaynak belge |
| `description` | varchar null | |
| `effective_date` | date | İşlem günü (Istanbul) |
| `created_by` | bigint null | Elle girişte admin |
| `created_at` | timestamp | |

- **İdempotency (şemada):** `UNIQUE(source, reference_type, reference_id, entry_type)` — bir siparişin borcu iki kez yazılamaz (`insertOrIgnore`).
- İndeksler: `(customer_id, effective_date)`, `(customer_id, id)`.
- **Bakiye** çalışma anında `SUM(credit − amount) − SUM(debit)` ile hesaplanır (stok defteri felsefesi: doğruluk önce, drift yok). Pozitif = müşterinin borcu.

### 7.3 `veykemtu_account_periods` — ay sonu özeti

Ay kapanış anlık görüntüsü (fatura değil): `customer_id`, `period` (YYYY-MM), `opening_kurus`, `debit_total_kurus`, `credit_total_kurus`, `closing_kurus`, `generated_at`. `UNIQUE(customer_id, period)` → aynı ay iki kez yazılamaz.

### 7.4 Abonelik ailesi (`veykemtu_subscription*`)

**İlke:** abonelik sipariş değil, **sipariş üreten kuraldır**. Gece işi kurala bakıp ertesi günün siparişlerini doğurur; doğan sipariş kendi hayatını yaşar.

- **`veykemtu_subscriptions`** — kural başlığı: `customer_id`, `location_id`, `status` (`pending`\|`active`\|`paused`\|`cancelled`, default `pending`), `start_date`, `end_date` null=süresiz, `delivery_type`, `delivery_time_from/to`, `service_days` (JSON, ISO 1..7), `default_quantity`, `menu_mode` (`fixed_list`\|`daily_menu`), `agreed_unit_price_kurus` null (talepte fiyatsız; admin belirler), `payment_mode` (`account`\|`prepaid_monthly`).
- **`veykemtu_subscription_lines`** — satır listesi (diyet/alerjen varyantı): `subscription_id`, `menu_id` null, `quantity`, `agreed_unit_price_kurus` null, `label`.
- **`veykemtu_subscription_delivery_points`** — adres defterinden **çoklu** teslim noktası: `subscription_id`, `address_id`, `quantity` null (o noktaya porsiyon), `note`.
- **`veykemtu_subscription_pauses`** — duraklatma (≠ iptal): `subscription_id`, `start_date`, `end_date`, `reason`.
- **`veykemtu_subscription_exceptions`** — tek-gün istisna: `subscription_id`, `service_date`, `skip`, `quantity_override`; `UNIQUE(subscription_id, service_date)`.
- **`veykemtu_closed_days`** — resmî tatil/kapalı gün: `closed_on` UNIQUE, `description`.
- **`veykemtu_subscription_runs`** — üretim kaydı, **idempotency şemada**: `subscription_id`, `delivery_point_id` (default 0), `service_date`, `order_id` null; `UNIQUE(subscription_id, delivery_point_id, service_date)` → gece işi iki kez koşsa da tek sipariş.

### 7.5 `orders` — abonelik bağı (additive)

`bld_subscription_id` (bigint null, index). Üretilen siparişin hangi aboneliğe ait olduğu; normal siparişlerde null. KDS bu kolonu okumaz, `OrderPresenter` `is_subscription = (bld_subscription_id !== null)` türetir (yeni kolon gerekmez).
