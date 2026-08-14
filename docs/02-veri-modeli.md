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
| `name` | varchar(64) | "Mutfak Kasası 1" |
| `pairing_code` | varchar(16) null UNIQUE | Tek kullanımlık eşleme kodu; kullanılınca null |
| `pairing_expires_at` | timestamp null | Kodun son geçerlilik anı (üretimden **10 dk** sonra) |
| `last_seen_at` | timestamp null | Son istek zamanı (indeksli) |
| `revoked_at` | timestamp null | İptal edilmişse dolu → `403 DEVICE_REVOKED` |
| `created_at`, `updated_at` | timestamp | |

**DÜZELTME (14.08.2026): `token_hash` diye bir kolon YOK** ve hiç olmadı.
Bu satır belgede duruyordu ama karşılığı `2026_08_04_000002` göçünde de,
`KitchenDevice` modelinde de bulunmuyor. Cihaz token'ları **Sanctum'un
`personal_access_tokens` tablosunda** yaşıyor (`kitchen` kapsamıyla);
`KitchenDevice::issueToken()` orayı yazıyor ve eski token'ları silerek bir
cihazın aynı anda tek token taşımasını sağlıyor.

Ayrımın pratik sonucu var: **kasa iptal edilirken token satırı kasten
silinmiyor.** Silinseydi `findToken()` `null` döner, istek
`401 UNAUTHENTICATED` ile biter ve KDS'in beklediği `403 DEVICE_REVOKED`
dalına hiç ulaşılmazdı — mutfak "eşleme iptal edildi" yerine genel bir
oturum hatası görürdü. Erişim yine kapalı: her mutfak ucu `bld.auth`
içinde `isRevoked()` denetiminden geçiyor.

**DÜZELTME (14.08.2026): eşleme kodu `varchar(12)` değil `varchar(16)`.**
Üretilen kodun biçimi `XXXX-XXXX`, yani **9 karakter**
(`^[A-Z0-9]{4}-[A-Z0-9]{4}$`); sütun 16'ya kadar yer bırakıyor. Alfabede
karıştırılması kolay karakterler (`0`/`O`, `1`/`I`) **yok** — kod mutfakta
elle, çoğu zaman kötü ışıkta giriliyor. (`docs/05-mutfakapp.md` §7 adım 2 hâlâ "12
karakter" diyor; o dosya bu görevin kapsamı dışında ve düzeltilmesi
gerekiyor.)

Tabloya sonradan eklenen **yönetilen ayar** kolonları (`poll_seconds`,
`sound_enabled`, ses/alarm/TTS ailesi, `touch_mode`, `settings_updated_at`)
ve **sağlık** kolonları (`health_reported_at`, `printer_ok`,
`print_queue_pending`, `print_queue_failed`, `app_version`) burada tek tek
sayılmıyor; normatif listesi `docs/openapi.yaml` → `KitchenSettings` ve
`docs/05-mutfakapp.md` §8. Hepsinin ortak kuralı: **`null` = "yönetici
dokunmadı"**, o alanda kasa kendi derleme varsayılanını kullanır.

#### Kilit politikası kolonları (K-21 — `2026_08_17_000001`)

| Kolon | Tip | Kapattığı şey |
|---|---|---|
| `allow_settings` | boolean **null** | Kasadaki ayarlar ekranının tamamı |
| `allow_server_change` | boolean **null** | Sunucu adresi değişimi + eşlemeyi sıfırlama |
| `allow_window_controls` | boolean **null** | Tam ekrandan çıkma / küçültme |
| `allow_order_edit` | boolean **null** | Kasadan sipariş düzenleme (K-12) |
| `allow_manual_reprint` | boolean **null** | Elle yeniden fiş bastırma |
| `allow_sales_control` | boolean **null** | Satış şalteri + "bugün tükendi" (K-11) |
| `lock_message` | varchar(160) null | Kilitli düğmeye basınca gösterilecek metin |

**HEPSİ NULLABLE VE VARSAYILANI `null` — bu göçün en önemli kararı.**
`null` "yönetici dokunmadı" demektir ve kasanın **bugünkü** davranışı
geçerli kalır, yani **serbest**. Sütunlara `false` varsayılanı konsaydı göç
koştuğu saniyede sahadaki bütün kasalar kilitlenir, mutfak ayar ekranına
giremez ve kimse sebebini anlamazdı; üstelik kilidi açacak arayüz (Kontrol
Merkezi) henüz devrede bile olmayabilirdi. `true` varsayılanı da yanlış
olurdu: o zaman "yönetici açıkça izin verdi" ile "kimse dokunmadı" ayırt
edilemez, ileride varsayılanı sıkılaştırmak imkânsız hâle gelirdi.

**Kilit ancak yönetici açıkça `false` yazınca doğar.** Yazma yolu tek:
`PATCH /api/control/kds/devices/{id}/settings` (§14, `docs/03`). Kasa
değerleri bir sonraki **sağlık bildiriminin** yanıtında alıyor; kasa
tarafında düğme **gizlenmez, pasifleşir** (`docs/05` §8) — gizlenen düğme
personeli "bozuldu" sanısına iter ve destek çağrısı üretir.

`lock_message` neden ayrı bir alan: kilitli bir düğmeye basınca kasa bir şey
söylemek zorunda. Metin kasaya gömülseydi ("Bu işlem yönetici tarafından
kapatılmıştır") mutfak **kime başvuracağını** bilemezdi; yöneticinin
"Kapatıldı — Ahmet Bey'i arayın, 0532..." yazabilmesi gerekiyor. 160
karakter, çünkü kasa bunu tek satırlık bir uyarı şeridinde gösteriyor.

### 2.2 `veykemtu_print_jobs` (bridgeapi eklentisi — opsiyonel sunucu kopyası)

KDS kendi kuyruğunu diskte tutar; bu tablo yalnızca **denetim** içindir (hangi fiş ne zaman basıldı).

| Kolon | Tip |
|---|---|
| `id` | bigint PK |
| `order_id` | bigint FK |
| `type` | enum: `mutfak` \| `musteri` \| `kurye` |
| `revision` | int, varsayılan `0` — K-20 |
| `printed_at` | timestamp null |
| `device_id` | bigint FK null |

Tekillik `(order_id, type, revision)` **üçlüsüdür**. K-20'ye kadar
`(order_id, type)` çiftiydi ve `record()` ilk-yazan-kazanır çalışıyordu;
düzenlenen siparişin yeniden basılan fişinin `ack`'i **sessizce yutuluyordu**.
Sonucu `printed_at` alanında görünüyordu: yeniden basılan kâğıt, yerini
aldığı eski kâğıdın saatiyle damgalanıyordu ve elinde iki kâğıt olan kurye
hangisinin yeni olduğunu tek zaman damgasından anlayamıyordu. Denetim sorusu
değişmedi, daraldı: "bu revizyon ilk ne zaman basıldı".

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

### 2.5 `veykemtu_control_audit` (bridgeapi — K-21, `2026_08_17_000002`)

Kontrol Merkezi'nden yapılan **her yazma** işleminin izi. "Kim, ne zaman,
hangi kasayı iptal etti ve neden" sorusunun cevabı bu tablodur.

| Kolon | Tip | Açıklama |
|---|---|---|
| `id` | bigint PK | Yanıttaki `audit_id` |
| `actor` | varchar(120) | İşlemi yapan kişi — Kontrol Merkezi'nin bildirdiği **serbest metin** |
| `action` | varchar(64), indeksli | `device.create`, `device.rename`, `device.pairing_code`, `device.revoke`, `device.settings`, `device.command`, `order.revise`, `order.status` |
| `target_type` | varchar(32) null | `kitchen_device` \| `order` \| `null` (henüz kimliği olmayan cihaz yaratma) |
| `target_id` | bigint null | Hedefin kimliği |
| `reason` | varchar(500) | **En az 10 karakter** — sunucu zorluyor |
| `payload_json` | json null | İsteğin **özeti**; hata varsa `error` anahtarı da burada |
| `result` | varchar(32), indeksli | `pending` \| `applied` \| `failed` \| `dry_run` |
| `created_at` | timestamp null | Eylemin anı |

İkinci indeks `(target_type, target_id)` — "bu kasaya ne yapıldı"
sorgusunun dayanağı.

**SATIR SİLİNMEZ.** Silme yolu bilinçli olarak açılmıyor ve `ControlAudit`
modelinde de yok: **denetim izini silebilen bir denetim izi denetim izi
değildir.** (`AGENTS.md` §2 ile aynı ruh; `veykemtu_account_ledger`'ın
append-only kuralıyla da aynı aile.)

**Güncelleme yalnız sonuca dokunur.** `result` `pending` doğar, işlem
bitince `applied` ya da `failed` olur; `actor`, `action`, `reason` ve hedef
bir daha değişmez.

**Satır işlemden ÖNCE açılır.** Sonra açılsaydı, yarıda kalan bir yazma
(veritabanı hatası, zaman aşımı) hiçbir iz bırakmazdı — oysa "denendi ve
olmadı" tam da soruşturulması gereken hâldir.

**Kuru prova da satır yazar** (`result = "dry_run"`). "Denedim ama
uygulamadım" bir eylemdir ve yanlış kasaya kilit uygulamaya çalışan birinin
ilk adımı çoğu zaman odur. Kuru provada bir **ön denetim** düşse bile satır
`dry_run` kalır, `failed` olmaz: aksi hâlde denetim ekranında kuru provalar
gerçek yazma denemeleriyle karışırdı. Sebep yine kaydediliyor, yalnız
`payload_json.error` içinde.

**Neden sunucuda, Kontrol Merkezi'nde değil:** gerekçeyi ve aktörü karşı
tarafın kaydetmesine güvenmek, kaydı isteyen tarafın kendi kendini
denetlemesi olurdu. Kontrol Merkezi arayüzünde gerekçe alanını gizlemek ya
da otomatik doldurmak tek satırlık bir değişiklik; sunucu `reason`'ı
**zorunlu** kılıyor ve buraya **kendisi** yazıyor.

**`actor` neden yabancı anahtar değil:** Kontrol Merkezi ayrı bir depo, ayrı
bir kullanıcı tablosu; o kişinin BLD'de hesabı yok ve olmayacak. Yabancı
anahtar iki sistemi birbirine bağlardı. Kimliğin doğruluğunu imza garanti
ediyor (isteğin oradan geldiğini kanıtlıyor), sütunun kendisi değil.

**`payload_json` isteğin özetidir, tam gövdesi değil:** yalnız o eylemi
anlamlandıran alanlar yazılıyor (hangi ayar, hangi komut, kaç kalem). Ham
gövdeyi saklamak müşteri notu gibi kişisel veriyi ikinci bir yerde
çoğaltırdı (§6, KVKK).

**Zaman damgası tek: `updated_at` YOK.** Bir denetim satırının "güncellenme
saati" diye bir kavramı olmamalı; `created_at` eylemin anıdır ve `result` o
anın sonucudur. Model bu yüzden `$timestamps = false` ile çalışıyor —
açık bırakılsaydı Eloquent her `save()`'de var olmayan bir sütunu yazmaya
çalışır ve `result` güncellemesi SQL hatasıyla düşerdi.

Uçların tamamı ve gerekçe/kuru prova kuralları: `docs/03-api-sozlesmesi.md`
§14.

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

**Yazdırma tetikleri** (güncel — `docs/05-mutfakapp.md` §5.5 ve §14):

| Durum | Basılan fiş | Koşul |
|---|---|---|
| `onaylandi` ya da ötesi | Mutfak fişi | — |
| `hazir` ya da ötesi | Müşteri fişi (kurye bilgileri içinde) | — |
| revizyon numarası arttı | Daha önce **basılmış** fişler, güncel hâliyle, bir kez | 20 sn sessizlik penceresi |

**Sipariş başına tam iki kâğıt çıkar** ve bu teslimat tipinden bağımsızdır.

> **DÜZELTME (11.08.2026).** Bu tablo "→ `yeni` (oluşma anı) → mutfak
> fişi" diyordu ve **05.08.2026'dan beri yanlıştı**: `yeni` durumunda
> hiçbir fiş basılmıyor. Gerekçe `docs/05` §5.5'te — sipariş henüz kabul
> edilmemiştir ve müşteri iptal edebilir (`docs/03` §4); `yeni`de basmak,
> iptal edilen her sipariş için çöpe giden bir fiş demekti. Kod baştan
> beri doğruydu, doküman geride kalmıştı.
>
> Kurye fişi ve revizyon tetiği K-14 ile eklendi.
>
> **DÜZELTME (14.08.2026, K-20).** Kurye fişi satırı kaldırıldı: artık
> otomatik basılmıyor. K-14'teki hâliyle adrese gönderim başına **üç**,
> iki kez düzenlenmiş siparişte **yedi** kâğıt çıkıyordu ve tezgâhta
> hangisinin güncel olduğu okunamıyordu. Kuryenin ihtiyaç duyduğu her şey
> müşteri fişine taşındı; `kurye` tipi yalnız elle yeniden bastırma için
> duruyor. Revizyon tetiği de değişti: yalnız **daha önce basılmış** fişler
> yeniden çıkıyor ve art arda düzenlemeler tek kâğıtta birleşiyor.

### Mutfak turu tabloları (K-11 … K-13, 11.08.2026)

| Tablo | Ne için | Kritik kısıt |
|---|---|---|
| `veykemtu_menu_soldout` | Mutfağın günlük "bugün tükendi" işareti | `UNIQUE(menu_id, sold_out_on)` — aynı ürün aynı gün iki kez işaretlenemez; `sold_out_on` **tarih** olduğu için gün dönümünde kendiliğinden geçersizleşir (temizleyecek cron yok) |
| `veykemtu_order_revisions` | Sipariş düzenlemesinin belgesi | `UNIQUE(order_id, revision_no)`; `before_json`/`after_json` **tam anlık görüntü** tutar, fark değil |
| `veykemtu_payment_refunds` | İade kayıtları | `UNIQUE(revision_id)` — bir revizyon en fazla bir iade doğurur; `NULL` revizyon (elle iade) tekilliğe takılmaz |
| `veykemtu_bbd_receipts` | BBD Store (kitap e-ticareti) siparişleri | `UNIQUE(external_id)`; `printed_at IS NULL` **kuyruk** görevi görüyor. `orders` tablosuna HİÇ dokunmaz — gerekçe aşağıda |
| `orders.bld_revision_no` | Kaçıncı revizyon (additive kolon) | 0 = düzenlenmedi; fiş tekilliğinin üçüncü parçası |

**`menus.menu_status` neden kullanılmadı:** o alan yöneticinin KALICI
kararı, mutfağınki GÜNLÜK. Aynı alanı paylaşsalardı akşam tükenen ürünü
sabah yöneticinin elle geri açması gerekirdi.

**Cari defter referansı revizyona bağlı:** `veykemtu_account_ledger`
üzerindeki `UNIQUE(source, reference_type, reference_id, entry_type)`
kısıtı sipariş kimliğine bağlansaydı, aynı siparişin ikinci düzenlemesi
`insertOrIgnore` tarafından sessizce yutulur ve müşteri fazla borçlu
kalırdı. Bu yüzden `reference_type = 'order_revision'`.

**BBD tablosu neden `orders`'tan ayrı:** BBD Store bir **kitap
e-ticaret sitesi** ve ayrı bir sunucuda yaşıyor. Ürünleri BLD menüsünde
yok, fiyatları BLD fiyat listesinde değil, müşterisi BLD müşterisi değil
ve iş akışı bile farklı — biri pişiriliyor, diğeri raftan alınıp
kutulanıyor. Köprünün tek varlık sebebi **termal yazıcıyı paylaşmak**.
`orders`'a yazılsaydı ciro raporu, üretim listesi ve cari hesap bir
gecede yanlış olurdu.

**`order_totals` tekilliği yok:** `(order_id, code)` üzerinde kısıt
bulunmuyor ve eski `storeTotals()` yalnız `insert` yapıyordu. İkinci kez
çağrılsa sipariş iki "Ara Toplam" satırı taşırdı.
`LineResolver::rewriteTotals()` önce siliyor.

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


### 7.6 Cari borç limiti ve ödeme niyeti — v2.0 (12.08.2026)

**`customers.bld_credit_limit_kurus`** (nullable, `unsignedInteger`) —
üç durumu var ve ikisi birbirinin tam zıddı:

| Değer | Anlam |
|---|---|
| `NULL` | Sınırsız. Göç öncesinden gelen müşteriler ve bilinçli seçim |
| `0` | Cari hesap KAPALI. `account` ödeme yöntemi hiç görünmez |
| `n > 0` | Borç `n` kuruşu aşamaz |

Yeni açılan kurumsal hesaplar `0` alır: sipariş anında açılıyor ama
veresiye ayrı bir güven kararı. Mevcut satırlar `NULL` kaldı — göç kimseyi
kırmadı. Kontrol `Services\CreditLimit` içinde tek yerde; sipariş
oluşurken borç deftere düşmeden ÖNCE bakılıyor.

**`veykemtu_account_payments`** — cari borç ödeme niyeti. Mevcut simülasyon
POS'u siparişe bağlı (`Order::where('hash', ...)`); "borcumun 2.500 TL'sini
ödeyeyim" dendiğinde ortada sipariş yok.

Niyet önce `pending` yazılıyor, defter ancak ödeme kesinleşince alacak
satırı alıyor. İdempotency iki katmanda: `status` alanı ve defterdeki
`(payment, account_payment, id, credit)` tekil indeksi.

**`veykemtu_otp_codes`** — telefonla giriş kodları. Kod `code_hash` olarak
bcrypt'le saklanıyor; kısa ömür yetmez, bir yedek sızıntısı o an geçerli
her kodu aktif anahtara çevirirdi. Satırlar silinmez, `consumed_at` ile
tüketilir — silinseydi "bu kod kullanıldı mı" sorusu yanıtsız kalırdı.
`attempts` sayacı KODA bağlı: oran sınırı IP başına ve saldırgan IP
değiştirebilir.

---

## 8. Günün menüsü (B-19 — 14.08.2026)

Sistemin satış modeli değişti: artık **sabit bir katalog değil, gün gün
girilen menü** satılıyor. `docs/11-yol-haritasi.md` §7.5'te "kaynağı yok"
diye ertelenen `menu_mode = daily_menu` bu bölümle kaynağına kavuşuyor.

### 8.1 `veykemtu_daily_menus` — bir gün, bir menü

`id`, `location_id` (index), `menu_date` (date), `title` (120), `description`
(500), `package_price_kurus` (null = o gün paket satılmıyor, yalnız kalemler),
`components_sellable` (bool, false = yalnız paket), `status`
(`draft`\|`published`), `published_at`, `published_by`, `image_path`,
`internal_note` (**panelde kalır, müşteriye gitmez**), `created_by`,
timestamps.

`UNIQUE(location_id, menu_date)` · `INDEX(menu_date, status)`

**`location_id` neden bugünden tekil anahtarda:** Faz 1 tek vitrin, ama
kolonu sonradan tekil anahtara eklemek, o gün tabloda çift satır varsa
**başarısız olan** bir göç demektir. Bugün bedava, yarın imkânsız.

**`status` neden boolean değil:** `menus.menu_status` bu dersi bir kez
verdi (§"Mutfak turu tabloları"). Boolean üçüncü bir duruma büyüyemez.
Yönetici bir ay öncesinden plan giriyor; taslak ayrımı olmasaydı yarım
girilmiş perşembe, kaydedildiği anda müşteriye görünürdü.

### 8.2 `veykemtu_daily_menu_items` — o günün kalemleri

`id`, `daily_menu_id` (index), `menu_id` (index, çekirdek `menus`), `quantity`
(bir pakette kaç porsiyon), `sort_order` (çorba → ana yemek → pilav → tatlı),
`price_override_kurus` (null = ürünün kendi fiyatı; **yalnız tek tek satışta
geçerli, paket fiyatını etkilemez**), `is_required`, `sellable_alone` (ekmek,
ayran gibi kalemler yalnız pakette olabilir), `label` ("Günün Çorbası:
Mercimek").

`UNIQUE(daily_menu_id, menu_id)`

### 8.3 `orders.bld_service_date` (additive)

`date`, null, index. Siparişin **hangi gün için** olduğu.

Değişmez kural: **`bld_service_date === DATE(order_date)`**, her yazma
yolunda. `order_date` bugünkü anlamını koruyor (`OrderFactory` zaten istenen
teslim gününe yazıyor), böylece `order_date` üzerinden filtreleyen her sorgu
— `KitchenController::orders`, `ProductionListService::today()`,
`SubscriptionKitchenPlan` — **hiç değişmeden doğru kalıyor**.

Ayrı kolon yine de gerekli: `order_date` bir tarih+saat çifti ve mutfak
teslim saatini düzenlediğinde `OrderEditor` onu yeniden yazıyor. Servis
günü ise bir **iş anahtarı** — siparişin hangi günün menüsüne bağlandığını
seçiyor, indeksli olmalı ve saat düzenlemesinden etkilenmemeli. Göç mevcut
satırları `DATE(order_date)` ile dolduruyor.

### 8.4 `order_menus` — paket bağı (additive)

`bld_daily_menu_id` (null, index), `bld_line_role` (`package`\|`component`\|
null), `bld_parent_line_id` (null, index).

Sipariş **bir paket satırı + sıfır fiyatlı bileşen satırları** olarak
yazılıyor. Bu kalıp yeni değil: abonelik siparişleri baştan beri böyle
yazılıyor (`OrderFactory::resolveSubscriptionLines` bileşenleri
`unit_price: 0` ile yazıyor, para `order_totals`'ta). Paket satırının
eklenmesi aslında aboneliğin bugün **bozduğu** bir değişmezi de onarıyor:
`sum(order_menus.subtotal)` artık `order_totals.subtotal` ile tutuyor.

Gerekçe ve reddedilen alternatifler: `docs/03-api-sozlesmesi.md` §4.

### 8.5 Mevcut tarihli tablolarla ilişki

**`veykemtu_closed_days` her zaman kazanır.** Kapalı güne menü girilmiş
olsa bile sipariş alınmaz. Sebep: abonelik üretimi ve
`Subscription::upcomingServiceDays()` zaten bu tabloya bakıyor; "açık mıyız"
sorusunun ikinci bir kaynağı bir gün ilkiyle çelişir ve çeliştiği gün bayram
sabahıdır. **Kapalı günde menü satırı silinmez** — tatil iptal olabilir,
menü ise daha pahalı bir emek.

**`veykemtu_menu_soldout` yalnız bugünü bilir** ve öyle kalıyor: mutfak
gelecek salı köftenin biteceğini bilemez. Servis günü bugün değilse tükenme
işaretleri hiç okunmaz. Bugünse, tükenen **zorunlu** bir kalem paketi de
düşürür — ana yemeği olmayan menüyü satmak, bir telefon özrünü kırka
çevirir.

### 8.6 "Günün Menüsü" ürün kaydı

Paket satırının `order_menus.menu_id`'si için çekirdekte **kategorisiz,
kalıcı bir `menus` kaydı** açılıyor; kimliği `location_options` içinde
`bld_daily_package_menu_id` olarak duruyor.

Kategorisiz olması bilinçli: `CatalogController::menu()` yanıtı
`$item->categories` üzerinden kuruyor, yani kategorisi olmayan ürün hiçbir
vitrine sızamaz. `menu_status = true` olması da bilinçli: mutfak bu kaydı
`menu-availability` ile "bugün tükendi" işaretleyip **yalnız paketi**
kapatabilsin diye.

`menus.menu_price = 0.00`. Bu yüzden `LineResolver`, bu kimliği çözülmüş
bir gün olmadan gördüğünde **istisna fırlatır, asla ürün fiyatına
düşmez** — günün menüsünü sıfır liraya satmak, buradaki en pahalı sessiz
arıza olurdu ve kendi testi var.

---

## 9. Akıllı adres — yapılandırılmış adres kolonları

Sözleşme tarafı: `docs/03-api-sozlesmesi.md` §13.

### 9.1 `addresses` — bugünkü hâli

Tablo TastyIgniter'ın; hem **adres defteri** hem **sipariş adres kopyası**
bu tabloda duruyor ve ikisini `bld_is_saved` ayırıyor.

| Kolon | Kimin | Taşıdığı |
|---|---|---|
| `address_1` | çekirdek | API'deki `line1` |
| `address_2` | çekirdek | API'deki `note` (kuryeye not) |
| `state` | çekirdek | API'deki `district` (ilçe) |
| `city` | çekirdek | API'deki `city` |
| `bld_label` | bizim | "Ev", "Ofis" |
| `bld_is_saved` | bizim | defter satırı mı, sipariş kopyası mı |
| `bld_is_default` | bizim | ödeme ekranında seçili gelen |
| `bld_latitude` / `bld_longitude` | bizim | `DECIMAL(10,7)`, harita iğnesi |

`state` sütununun ilçeyi taşıması çekirdek şemanın dayattığı bir eşleme ve
`OrderPresenter::address` ile `AddressController::fill` **aynı** eşlemeyi
kullanıyor. İkisi ayrıştığı gün adresin yarısı kaybolur.

### 9.2 Eklenen kolonlar (additive)

| Kolon | Tip | Not |
|---|---|---|
| `bld_neighbourhood` | `varchar(96)` null | Mahalle |
| `bld_street` | `varchar(128)` null | Cadde / sokak |
| `bld_building_no` | `varchar(24)` null | Bina / dış kapı no |
| `bld_floor` | `varchar(16)` null | Kat |
| `bld_door_no` | `varchar(16)` null | Daire / iç kapı no |

Beşi de **nullable**, öneksiz karşılıkları yok, indekssiz. Göç geri
alınabilir (`down()` beş kolonu düşürür).

**`bld_` öneki, tablo bizim olmadığı için.** 2026_08_05_000001'in gerekçesi
burada da geçerli: çekirdek ileride kendi `street` kolonunu eklerse öneksiz
bir kolon göçü sebebi hiç anlaşılmayan bir çakışmayla patlatır.

**Ayrı tablo AÇILMIYOR.** Bu beş alan adresin **parçaları**, ilişkili bir
kavram değil; ayrı tabloya konsaydı her adres okuması bir `JOIN` kazanır,
karşılığında hiçbir şey kazanmazdı. Sipariş kopyası da aynı satırda kalıyor:
teslimat adresi değişmez bir kayıt ve parçalarının ayrı bir tabloda ayrı bir
ömür sürmesi o değişmezliği kırardı.

**Üçü neden `varchar`, `int` değil.** `bld_building_no` sahada `12/A`, `3-5`,
`12 B blok` gibi değerler alıyor; `int` bunların hepsini ya reddeder ya da
sessizce `12`'ye kırpar — ikincisi kuryeyi yanlış bloğa gönderir. Aynı
şekilde `bld_floor` için `Zemin`, `Bodrum`, `Asma` geçerli cevaplar ve
`0`/`-1` onların yerini tutmaz.

**`address_1` (`line1`) DURUYOR ve boş bırakılmıyor.** Yeni kolonlar onu
bölmüyor, üstüne biniyor. Sebep sözleşme tarafında yazılı (`docs/03` §13.7):
fiş basan her yol bugün `address_1`'i okuyor. Sunucu, istemci yalnız
yapılandırılmış alanları gönderdiğinde `address_1`'i onlardan **türetip**
yazar — kolon her satırda dolu kalır.

**Eski satırlar geriye dönük AYRIŞTIRILMIYOR.** Göç, mevcut `address_1`
metinlerini mahalle/sokak/no diye bölmeye çalışmıyor; beş kolon eski
satırlarda `NULL` kalıyor. Serbest metin adresi ayrıştırmak tahminle
çalışır ve tahminin tuttuğu satırlarda hiçbir şey kazandırmaz, tutmadığı
satırlarda ise **doğru olan `address_1`'in yanına yanlış bir mahalle yazar**.
Yanlış veri, eksik veriden pahalıdır.

**Kat ve daire hiçbir geocoder'dan gelmez.** `bld_neighbourhood`,
`bld_street` ve `bld_building_no` öneriden dolabilir; `bld_floor` ve
`bld_door_no` **her zaman** müşterinin elinden çıkar — hiçbir harita verisi
kimin hangi dairede oturduğunu bilmiyor.

### 9.3 Geocoder önbelleği için tablo YOK

Öneri ve ters geocoding yanıtları (`docs/03` §13.5) uygulamanın **cache
store'unda** duruyor, veritabanında değil. Gerekçe: veri tamamen atılabilir
(kaybı yalnız bir sağlayıcı isteği maliyeti demek), TTL'i kendi kendine
işliyor ve tabloda dursaydı beraberinde bir temizlik işi getirirdi —
süresi geçmiş satırları silen ve unutulduğu gün tabloyu şişiren türden.

Kalıcı olması gereken tek şey müşterinin **seçtiği** adres; o da zaten
`addresses` satırına yazılıyor.
