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
değildir.** (`AGENTS.md` §2 ile aynı ruh; aynı aileden
`veykemtu_error_events` de silmiyor, **çözüldü işaretliyor** — §10.9.)

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

**Referans neden siparişe değil REVİZYONA bağlanır:** kaldırılan cari defter
(§7.2) `UNIQUE(source, reference_type, reference_id, entry_type)` kısıtını
sipariş kimliğine bağlasaydı, aynı siparişin ikinci düzenlemesi
`insertOrIgnore` tarafından sessizce yutulur ve müşteri fazla borçlu kalırdı;
bu yüzden `reference_type = 'order_revision'` seçilmişti. Defter gitti ama
**ders duruyor** ve bugün SMS kaydında aynı yerde işliyor: `veykemtu_sms_log`
üzerindeki `UNIQUE(template_key, reference_type, reference_id)` de olaya
bağlıdır, siparişe değil — aksi hâlde ikinci düzenlemenin bilgilendirmesi hiç
gitmezdi (§10.7).

**BBD tablosu neden `orders`'tan ayrı:** BBD Store bir **kitap
e-ticaret sitesi** ve ayrı bir sunucuda yaşıyor. Ürünleri BLD menüsünde
yok, fiyatları BLD fiyat listesinde değil, müşterisi BLD müşterisi değil
ve iş akışı bile farklı — biri pişiriliyor, diğeri raftan alınıp
kutulanıyor. Köprünün tek varlık sebebi **termal yazıcıyı paylaşmak**.
`orders`'a yazılsaydı ciro raporu, üretim listesi ve günlük stok sayacı bir
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
- **Hata olayları** (`veykemtu_error_events`, §10.9) tek saklama kuralı olan
  tablodur: `veykemtu:hata-temizle` çözülmüş satırları 30, çözülmemişleri 90
  günden sonra siler. Diğerlerinde bilinçli olarak silme yoktur; bir olay
  kaydının "silinmiş" hâli, olayın hiç olmadığını iddia etmektir.
- **Toplu SMS için onay AYRI BİR KONUDUR** ve henüz çözülmedi. Sipariş durum
  bilgilendirmesi izin gerektirmez, ticari elektronik ileti (menü duyurusu,
  toplu duyuru) İYS kaydı ve önceden onay ister. `customers.bld_sms_opt_out`
  yalnız **reddi** tutar; onayı tutan bir alan yok ve o gelene kadar ticari
  şablonlar kapalı (§10.7).

## 7. B2B ve abonelik (Faz 2 — UYGULANDI, cari kısmı 17.08.2026'da kaldırıldı)

Tümü `bridgeapi` eklentisinde, ADR-09 additive kuralıyla: çekirdek `customers`/`orders` tablolarına yalnız `bld_` önekli kolon; geri kalan her şey `veykemtu_` önekli yeni tablo. `platform/vendor/` değişmez.

### 7.1 `customers` — kurumsal kolonlar (additive)

Müşteri grubu tek kalır ("Catering Müşterisi"); kurum/birey ayrımı kolonlarla taşınır. `up()` içinde **grandfather backfill**: mevcut tüm satırlar `corporate` yazılır — aktif alıcılar kırılmaz.

| Kolon | Tip | Not |
|---|---|---|
| `bld_account_type` | varchar(16), default `corporate`, index | `corporate` \| `individual`. **Artık bir kapı değil**, yalnız kayıt formunun hangi alanları topladığını ve belgelerde hangi unvanın basılacağını söyler. |
| `bld_org_name` | varchar null | Ticari unvan |
| `bld_tax_office` | varchar null | Vergi dairesi |
| `bld_tax_no` | varchar null | Vergi / TC no |
| `bld_contact_person` | varchar null | Yetkili kişi |
| `bld_org_phone` | varchar null | Kurum telefonu |

Sözleşmede `Customer.account_type` + `can_order` olarak yansır. **`can_order`
artık her zaman `true` döner** — sipariş kapısı kaldırıldı (§7.2). Alan
sözleşmede duruyor çünkü sahadaki eski istemciler onu okuyor; kaldırılsaydı
`undefined` görüp sipariş düğmesini hiç çizmezlerdi. Yeni istemci bu alana
BAKMAZ: siparişin verilebilirliği vitrinin (`is_open`, `ordering_enabled`) ve
günün (`DailyMenu.is_orderable`) durumundan okunur (`docs/03` §12.1).

### 7.2 Cari hesap — KALDIRILDI (17.08.2026)

**Burada `veykemtu_account_ledger` (cari defter), `veykemtu_account_periods`
(ay sonu özeti), `veykemtu_account_payments` (borç ödeme niyeti) ve
`customers.bld_credit_limit_kurus` (borç limiti) anlatılıyordu. Dördü de
şemadan düşürüldü; bu bölüm o şemayı arayan kişinin neden bulamadığını
anlaması için duruyor.**

**Neden:** iş modeli günlük menü satışına geçti. Cari hesap "ay sonu
faturalanan kurumsal müşteri" varsayımına dayanıyordu; bugün her sipariş
kendi başına ödeniyor (`online` \| `cash`) ve abonelik 30 günlük **peşin**
dönem ödemesiyle yürüyor (§10.5). Borç/alacak yürüten bir defterin
karşılığı kalmadı — dolduran hiçbir yazma yolu kalmayınca defter, kimsenin
bakmadığı ama hâlâ doğru sanılan bir tabloya dönüşürdü.

**Nerede kaldırıldı:**

| Göç | Ne yaptı |
|---|---|
| `2026_08_20_000001_export_account_data_before_drop` | Düşürmeden önce veriyi dosyaya döktü (ikinci emniyet kemeri) |
| `2026_08_20_000002_drop_account_tables` | Üç tabloyu ve `bld_credit_limit_kurus` kolonunu düşürdü; `payments` tablosundaki `account` satırını pasifleştirdi |

**ŞEMA GERİ ALINABİLİR, VERİ GERİ ALINAMAZ.** `down()` üç tabloyu **boş**
olarak, orijinal indeksleriyle geri kurar; içlerindeki tek satırı bile geri
getirmez. Verinin tek yolu arşiv komutudur ve asıl adım operatörün onu ELLE
koşup dizini sunucudan indirmesidir — konteyner dosya sistemi geçicidir:

```bash
php artisan veykemtu:cari-arsivle    # docs/RUNBOOK.md §9
```

**`payments` SATIRI SİLİNMEDİ.** `orders.payment` alanı `payments.code` ile
eşleşiyor; satır silinseydi eski cari siparişlerin `Order::$payment_method`
ilişkisi `null` döner ve ödeme günlüğü "property on null" ile patlardı.
Satır `status = 0`, `class_name = ''` ile duruyor: panelde seçilebilir bir
yöntem olarak **görünmüyor**, tarihsel siparişler ise hâlâ çözülüyor.
Aynı sebeple sözleşmedeki `PaymentMethod` enum'ında `account` değeri de
duruyor ama **kabul edilmiyor** (`docs/03` §12.2).

**Yerine ne geldi:** abonelik dönem ödemesi (§10.5) ve mali değeri olmayan
fatura belgesi (§10.6). İkisi de cari defterin yaptığı işi yapmıyor; cari
hesap bir daha açılırsa yeni bir karardır, geri alma değil.

### 7.3 Abonelik ailesi (`veykemtu_subscription*`)

**İlke:** abonelik sipariş değil, **sipariş üreten kuraldır**. Gece işi kurala bakıp ertesi günün siparişlerini doğurur; doğan sipariş kendi hayatını yaşar.

- **`veykemtu_subscriptions`** — kural başlığı: `customer_id`, `location_id`, `status` (`pending`\|`active`\|`paused`\|`cancelled`, default `pending`), `start_date`, `end_date` null=süresiz, `delivery_type`, `delivery_time_from/to`, `service_days` (JSON, ISO 1..7), `default_quantity`, `menu_mode` (`fixed_list`\|`daily_menu`), `agreed_unit_price_kurus` null (talepte fiyatsız; admin belirler), `payment_mode` (kolon `account`\|`prepaid_monthly` doğdu; cari kalkınca **tek geçerli değer `prepaid_monthly`** oldu — kolon silinmedi, çünkü yeni bir ödeme modu geldiğinde tek doğru yer burasıdır ve `Control` ucu başka değeri `422` ile reddediyor).

`status` kolonu dört değerle doğdu (`pending`\|`active`\|`paused`\|`cancelled`)
ama sözleşme bugün iki değer daha yayınlıyor: `awaiting_contract` ve
`awaiting_payment` (`docs/03` §15.1). İkisi de model sabiti değil,
`Services\ContractService` içinde tanımlı — sözleşme imzalanmadan ve ilk dönem
ödenmeden abonelik sipariş üretmemeli, ama bu "duraklatılmış" da değildir.

> **AÇIK: `awaiting_contract` bu kolona BUGÜN YAZILAMIYOR.** Değer **17
> karakter**, kolon ise `varchar(16)`. `awaiting_payment` tam 16 hane olduğu
> için yedek yol çalışıyor ve akış ölmüyor; ama sözleşme bekleyen bir abonelik
> o durumu kolona yazamıyor. Kolonu genişletmek **abonelik kulvarının işi** —
> sözleşme kulvarı başka bir kulvarın tablosunu değiştirmiyor
> (`ContractService::STATUS_AWAITING_CONTRACT` docblock'u). Genişletme göçü
> yazılana kadar sözleşme ile şema burada ayrışık.
>
> Arızanın biçimi önemli: MySQL varsayılan (gevşek) kipte fazlalığı **sessizce
> kırpar** ve kolona `awaiting_contrac` yazılırdı — hiçbir istemcinin
> tanımadığı, hiçbir yerde eşleşmeyen bir durum. Bu yüzden kod o değeri
> yazmayı hiç denemiyor.
- **`veykemtu_subscription_lines`** — satır listesi (diyet/alerjen varyantı): `subscription_id`, `menu_id` null, `quantity`, `agreed_unit_price_kurus` null, `label`.
- **`veykemtu_subscription_delivery_points`** — adres defterinden **çoklu** teslim noktası: `subscription_id`, `address_id`, `quantity` null (o noktaya porsiyon), `note`.
- **`veykemtu_subscription_pauses`** — duraklatma (≠ iptal): `subscription_id`, `start_date`, `end_date`, `reason`.
- **`veykemtu_subscription_exceptions`** — tek-gün istisna: `subscription_id`, `service_date`, `skip`, `quantity_override`; `UNIQUE(subscription_id, service_date)`.
- **`veykemtu_closed_days`** — resmî tatil/kapalı gün: `closed_on` UNIQUE, `description`.
- **`veykemtu_subscription_runs`** — üretim kaydı, **idempotency şemada**: `subscription_id`, `delivery_point_id` (default 0), `service_date`, `order_id` null; `UNIQUE(subscription_id, delivery_point_id, service_date)` → gece işi iki kez koşsa da tek sipariş.

### 7.4 `orders` — abonelik bağı (additive)

`bld_subscription_id` (bigint null, index). Üretilen siparişin hangi aboneliğe ait olduğu; normal siparişlerde null. KDS bu kolonu okumaz, `OrderPresenter` `is_subscription = (bld_subscription_id !== null)` türetir (yeni kolon gerekmez).


### 7.5 Telefonla giriş kodları — v2.0 (12.08.2026)

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

---

## 10. Günlük menü modelinin getirdiği tablolar (Faz 3–5, 20–24.08.2026)

§8 satışı güne bağladı; bu bölüm o kararın arkasından gelen şemayı anlatıyor.
Sıra göç sırasıdır ve bilinçlidir: önce satışın kendisi (stok, kesim, serbest
bırakma), sonra aboneliğin parası (sözleşme, dönem ödemesi), sonra
müşteriyle konuşma (fatura belgesi, SMS, duyuru), en sonda kendi hatalarımız.

### 10.1 `veykemtu_daily_menu_stock` — günlük porsiyon tavanı

İş kararı: *"gün toplamı VE ürün bazlı tavan; hangisi önce dolarsa kapatır.
Satır yoksa sınırsız."* Tablo o cümlenin tamamı.

| Kolon | Tip | Not |
|---|---|---|
| `id` | bigint PK | |
| `location_id` | bigint, index | Faz 1 tek vitrin; kolon bugünden tekil anahtarda (§8.1 ile aynı gerekçe) |
| `service_date` | date | |
| `menu_id` | bigint | **`0` = gün toplamı satırı**, aksi hâlde çekirdek `menus.menu_id` |
| `capacity` | unsigned int | Tavan |
| `reserved` | unsigned int, default 0 | Abonelik rezervasyonu — henüz satılmadı |
| `sold` | unsigned int, default 0 | Gerçekten satıldı |
| `updated_by` | varchar(120) null | Serbest metin; Kontrol Merkezi kullanıcısı, panel ya da konsol |
| `created_at` / `updated_at` | timestamp | |

`UNIQUE(location_id, service_date, menu_id)` (`veykemtu_stok_essiz`) ·
`INDEX(service_date)` (`veykemtu_stok_gun`)

**KALAN = `capacity − reserved − sold`.** Bir gün ya da bir kalem, kendi
satırı VEYA gün toplamı satırı sıfırlandığında kapanır; "hangisi önce
dolarsa" kuralı ikisini birden denetlemekten kendiliğinden çıkar, ayrıca
kodlanmış bir öncelik yoktur.

**SATIR YOKSA SINIRSIZ.** Tavan konmamış bir gün için hiçbir satır yazılmaz
ve `DailyStock::remaining()` `null` döner. **`null` ile `0` asla
karıştırılmamalı:** `null`'ı sıfır sayan taraf, tavanı hiç konmamış bir günü
tükenmiş gösterir. Bu kural üç dilde birden test ediliyor —
`docs/contract/sales-rules.cases.json` değişmezleri.

**`menu_id = 0` GÜN TOPLAMI NÖBETÇİSİDİR, `NULL` DEĞİL.** MySQL benzersiz
indekste NULL'ları birbirinden ayrı sayar: `(1, '2026-08-20', NULL)` iki kez
yazılabilir ve kısıt hiçbirini engellemez. Yani NULL nöbetçi aynı güne iki
gün-toplamı satırına izin verir ve **tavan sessizce ikiye katlanır** — kimse
bir hata görmez, yalnız o gün iki katı porsiyon satılır. `menus.menu_id` bir
`AUTO_INCREMENT` ve asla 0 olmadığı için 0 nöbetçisi çakışmaz.

**`reserved` ile `sold` neden ayrı kolon:** abonelikler stoku ÖNCE rezerve
ediyor ve o porsiyonlar henüz satılmamıştır. Tek kolona toplansaydı "kaç
tanesi gerçekten satıldı" sorusunun cevabı kaybolur, abonelik iptalinde neyi
geri vereceğimizi bilemezdik.

Yarının satırlarını gece `veykemtu:stok-tazele` (21:30) hazırlıyor ve bu
**abonelik üretiminden (22:00) önce olmak zorunda**: rezervasyonun yazılacağı
gün satırı hazır değilse abonelik siparişleri stoksuz bir güne düşer ve o
günün serbest satış kapasitesi olduğundan büyük görünür.

> **§5'teki `veykemtu_stock_ledger` ile karıştırmayın.** O tablo hâlâ
> yazılmadı ve **malzeme** stoğunu (un, tavuk, kilogram) anlatıyor. Buradaki
> tavan **porsiyon** sayısıdır ve reçeteden hiçbir şey bilmez.

### 10.2 `veykemtu_daily_menus.cutoff_time` (additive)

`time`, nullable, `status` kolonundan sonra. GÜNE ÖZEL sabah kesim saati.

Vitrinin genel kesim saati (`location_options.bld_order_cutoff`) bunun
varsayılanı; bu kolon o günü tek tek ezmek içindir. Birleştirme kuralı tektir
ve `Services\OrderingWindow::cutoffFor()` içinde tek yerde yaşıyor:
**`gün.cutoff_time ?? ayar.order_cutoff`**.

**`null` = "bu güne özel saat girilmedi".** Kolona genel saatin kopyası
yazılsaydı iki doğruluk kaynağı doğardı: yönetici genel saati
değiştirdiğinde girilmiş günlerin hiçbiri takip etmezdi.

**`time`, `datetime` değil:** kesim bir SAATTİR, bir an değil. Mutlak an
(sözleşmedeki `cutoff_at`) servis gününün takviminden türetilir; depolamak,
menü kopyalandığında sessizce yanlış bir ana bağlanmak olurdu.

### 10.3 `orders` — serbest bırakma ve stok kredisi (additive)

| Kolon | Tip | Ne |
|---|---|---|
| `bld_released_at` | timestamp null, **indeksli** | Siparişin mutfağa AÇILDIĞI an |
| `bld_stock_released_at` | timestamp null | Stok kredisinin geri verildiği an |

**`bld_released_at` — `NULL` = SERBEST.** Abonelik siparişleri gece 22:00'de
üretiliyor ama KDS'e vardiya başında düşmeli; gecikme olmasaydı sabah 05:00'te
işbaşı yapan mutfak, ekranı kırk abonelik kartıyla dolu bulur ve o an gelen
GERÇEK bir siparişi göremezdi. Göçten önceki her satır ve her vitrin siparişi
`null` kalıyor — varsayılanı "beklet" yapmak, tek kolon eklemesiyle bütün
panoyu karartmak olurdu. Boolean değil AN: kapı "şimdi"ye göre kendiliğinden
açılıyor, hiçbir arka plan işi bayrak çevirmiyor; bir cron'a bağlansaydı
cron'un koşmadığı her sabah mutfak boş ekrana bakardı. İndeksli, çünkü mutfak
panosu her yoklamada (birkaç saniyede bir) bu kolona bakıyor.

**`bld_stock_released_at` — stok kredisi BİR KEZ verilir.** İptal, siparişin
düştüğü porsiyonları stoka geri veriyor (`DailyStock::releaseOrder()`). Bu
kolon olmadan ikinci bir iptal çağrısı — çift tıklama, KDS'in yeniden
denemesi, panelden ve mutfaktan aynı anda basılan iptal — aynı porsiyonları
İKİNCİ KEZ geri verir ve o gün tavanın üstünde satış açılır. Arıza sessizdir:
kimse hata görmez, yalnız mutfak akşam iki porsiyon fazla sipariş bulur.
Geriye doldurulmuyor: göçten önceki iptaller stok hiç düşmemiş siparişlerdi.

### 10.4 `veykemtu_subscription_contracts` — imzalı sözleşme

Sözleşme bir PDF değil, **tek kullanımlık bir bağlantıdır**: müşteri açar,
metni okur, telefonuna gelen kodu girer ve onaylar. Tablo o onayın hukuki izi.

`id`, `subscription_id` (index), `version` (varchar 32), `body_html`
(**mediumText**), `agreed_unit_price_kurus`, `term_days` (default 30),
`terms_json`, `status` (index), `token_hash` (**char(64) UNIQUE**), `sent_at`,
`sent_to_phone`, `otp_verified_at`, `approved_at`, `approved_ip`,
`approved_user_agent`, `approved_full_name`, `expires_at`, `cancelled_at`,
`cancel_reason`, `created_by`, timestamps.

`status` sözlüğü sözleşmedeki `ContractStatus`'tür:
`draft` \| `sent` \| `approved` \| `expired` \| `cancelled`. Kontrol
Merkezi'nin beklediği ayrı sözlüğe çeviri **tek yerde**,
`SubscriptionContract::controlStatus()` içinde.

**`body_html` DONMUŞ SAKLANIR — yalnız sürüm etiketi yetmez.** Metnin kendisi
yerine sadece `version` saklansaydı, şablon sonradan değiştiğinde müşterinin
"imzaladığı" metin de sessizce değişirdi: kayıtta `v1` yazar, ekranda bugünkü
metin çizilirdi ve hiçbir denetim bu farkı göremezdi. "Neyi onayladı"
sorusunun cevabı, sorulduğu güne değil onaylandığı ana aittir. `mediumText`
çünkü 64 KB'lik `text` uzun bir kurumsal sözleşmeye dar gelebilir ve taşan
metin MySQL'de **sessizce kırpılır** — hukuki bir belgede kabul edilemez.

Aynı gerekçe `terms_json` için de geçerli: fiyat, servis günleri ve porsiyon
sayısı abonelikte sonradan değişirse sözleşme değişmez.

**HAM TOKEN SAKLANMAZ.** Bağlantının kendisi bir anahtardır: onu bilen
sözleşmeyi okur ve (SMS koduyla) onaylar. Açık saklansaydı bir yedek sızıntısı
o an geçerli her sözleşme bağlantısını kullanılabilir hâle getirirdi. Ham
tokeni sunucunun yeniden üretebilmesi imza sırrına bağlı
(`Support\SignedLink`) — veritabanı tek başına yetmez.

**`sent_to_phone` kolonda, istekte değil.** Kodun gideceği numara istemciden
alınsaydı bağlantıyı ele geçiren kodu kendi telefonuna ısmarlardı.

`expires_at` imzanın İÇİNDE de var; kolonu elle ileri almak bağlantıyı
uzatmaz, imza tutmaz.

### 10.5 `veykemtu_subscription_payments` — 30 günlük peşin dönem

Bu tablo sıfırdan tasarlanmadı: kaldırılan `veykemtu_account_payments`
yapısının bilinçli devamıdır — yapısı sağlamdı, yalnız amacı kalktı.
Devralınan gerekçeler kod parçalarıyla
`docs/control/_devralinan-odeme-yapisi.md` dosyasında.

`id`, `subscription_id` (index), `period_start`, `period_end`,
`portions_planned`, `unit_price_kurus`, `amount_kurus`, `status` (index),
`hash` (UNIQUE), `gateway`, `provider_ref`, `created_at`, `settled_at`.

`status`: `pending` \| `succeeded` \| `failed` \| `refunded`.
`UNIQUE(subscription_id, period_start)` (`veykemtu_sub_pay_donem_essiz`).

1. **Niyet ayrı bir satırdır.** Sağlayıcıya gidip dönmek gerekiyor ve dönüş
   güvenilmez: kullanıcı sekmeyi kapatır, sağlayıcı geri-aramayı iki kez
   gönderir, ağ kopar. Niyeti önce `pending` yazıp dönüşte `succeeded`'a
   çevirmek "ödeme başladı ama bitmedi" durumunu **temsil edilebilir** kılıyor.
   Aboneliği doğrudan `active` yapmak, yarıda kalan her denemeyi bedava bir
   aboneliğe çevirirdi.
2. **Dışa kimlik `hash`.** Sıralı `id` ödeme adresinde görünmez; adres tahmin
   edilerek başkasının ödeme sayfası açılamamalı.
3. **İdempotans şemada.** Dönem başına TEK niyet. Kodun `if`'i bir yarışta
   delinse bile ikinci satır yazılamaz; yinelenen geri-arama ikinci bir
   `succeeded` üretemez.

**Neden `period_start`+`period_end`, "ay" değil:** dönem 30 GÜNDÜR, takvim ayı
değil. Abonelik ayın 17'sinde başlarsa dönemi de 17'sinde biter; takvim ayına
yuvarlamak ilk dönemi kısaltır ve eksik gün için tam para almış oluruz.
Sözleşmedeki `period` alanı (`YYYY-AA`) bu tarihten **türetilir** — sunum
biçimi, saklama birimi değil.

**Neden `portions_planned` ve `unit_price_kurus` de saklanıyor:** tutar
`porsiyon × birim fiyat` çarpımıdır ve iki çarpan da sonradan değişebilir.
Yalnız `amount_kurus` saklansaydı "neden 4.500 TL ödedim" sorusunun cevabı
hiçbir yerde olmazdı.

### 10.6 `veykemtu_invoices` + `veykemtu_invoice_counters` — belge

> **BU BELGENİN MALİ DEĞERİ YOKTUR.** e-Fatura değil, e-Arşiv değil, GİB'e
> gitmiyor, KDV hesaplamıyor. Müşterinin "bir belge verin" talebini
> karşılayan, yazdırılabilir bir A4 dökümüdür (`docs/10` §4).

Yine de numarası **boşluksuzdur**: gerçek entegrasyon bir gün buraya
takılacaksa, o gün geriye dönük numaralandırma yapmak imkânsız olur.

**`veykemtu_invoice_counters`** — `series` (varchar 8), `year` (smallint),
`next_sequence` (default 1), timestamps. Birincil anahtar `(series, year)`.

**`MAX(sequence)+1` ASLA.** Eşzamanlı iki kesimde aynı sayıyı döndürür: ikisi
de aynı en büyük değeri okur, ikisi de bir ekler; sonra tekil indeks
ikincisini reddeder ve kullanıcı yazdır düğmesinde 500 görür — hata
ayıklamasının en zor anı, en yoğun andır. Sayaç tablosu bunun yerine TEK BİR
SATIR kilitletir (`SELECT … FOR UPDATE`); ikinci kesim bekler ve artmış değeri
okur. `next_sequence` "bir sonraki"dir, "son kesilen" değil: satır 1 ile doğar
ve ilk kesim 1'i alır. Sıra **yıl başında sıfırlanır**, her seri kendi
sayacını taşır.

**`veykemtu_invoices`** — `invoice_no` (UNIQUE, `BLD-2026-000001`), parçaları
ayrı kolonlarda (`series`, `year`, `sequence`), `type`
(`order`\|`subscription`\|`void`), `status` (`issued`\|`void`, index),
`replaces_invoice_id`, `order_id`, `subscription_id`,
`subscription_payment_id`, `customer_id`, `issued_at` (index),
`period_start`/`period_end` (dönem belgesinde dolu), `currency` (`TRY`),
`subtotal_kurus`/`delivery_kurus`/`total_kurus`, `snapshot_json`, `pdf_path`,
`void_at`, `void_reason`, `created_by_actor`, timestamps.

`UNIQUE(series, year, sequence)` (`veykemtu_fatura_sira_essiz`) ·
`INDEX(customer_id, issued_at)` (`veykemtu_fatura_musteri_tarih`)

- **`type` ile `status` karıştırılmamalı:** `type` belgenin NE OLDUĞUNU,
  `status` hâlâ geçerli olup olmadığını söyler.
- **Fatura DÜZENLENMEZ.** Düzeltme, eskisini iptal edip yenisini kesmektir;
  yeni belge hangisinin yerine geçtiğini `replaces_invoice_id` ile taşır.
  Kolonu sonradan eklemek, o güne kadarki bütün düzeltmeleri elle geriye
  doldurmak demekti.
- **`snapshot_json` belgenin donmuş içeriğidir.** Belge canlı tablodan
  çizilseydi, müşteri adı ya da ürün fiyatı değiştiğinde aynı belge iki farklı
  kâğıt üretirdi. HTML render'ı YALNIZ buradan okuyor. Tutar kırılımı yine de
  ayrı kolonlarda: rapor ve toplam sorguları JSON ayrıştırmasın.
- **`pdf_path` bugün boş.** v1'de PDF üretilmiyor (dompdf/mpdf gibi yeni bir
  bağımlılık `AGENTS.md` §4/§6.3 gereği ayrı bir karar); belge
  `GET /api/control/invoices/{id}/html` ile basılıyor. Kolon, o karar
  verildiğinde şema değişikliği gerekmesin diye şimdiden duruyor.
- **`DELETE` yok.**

### 10.7 SMS — `veykemtu_sms_templates`, `veykemtu_sms_log`, `customers.bld_sms_opt_out`

İki tablo, iki ayrı soru: "hangi metin gidecek" ve "ne gitti". Sağlayıcının
kendi paneli ikincisinin yerini tutmaz: orada bizim sipariş numaramız,
abonelik kimliğimiz ve hangi şablondan çıktığı yoktur.

**`veykemtu_sms_templates`** — `key` (UNIQUE), `title`, `body` (500),
`enabled`, `locale` (default `tr`), `updated_by`, timestamps.

> **ŞABLONLAR KAPALI DOĞAR (`enabled` default `0`)** — göçteki en önemli
> seçim. Açık doğan bir şablon, tek bir dağıtımı binlerce SMS'e çevirir: göç
> koştuğu anda durum tetikleyicileri canlanır ve o gün açık olan her siparişin
> her geçişi müşteriye mesaj olarak gider. Geri alınamaz, özür dilenemez ve
> faturası gelir. Kapalı doğan bir şablonun bedeli ise yalnızca "yönetici
> anahtarı açmayı unuttu" — fark edilir ve düzeltilir.

Tohumlama `insertOrIgnore`: göç yeniden koşarsa yöneticinin ELLE açtığı bir
şablon tekrar kapanmaz, düzenlenmiş metin ezilmez. Kolon adı `title`
(`name` değil): `Control\SmsController` bu ada zaten yazıyor ve ayrışsalardı
`PATCH /templates/{key}` "Unknown column" ile — yalnız o uç çağrıldığında —
patlardı.

Tohumlanan anahtarlar: `order_created`, `order_confirmed`, `order_on_the_way`,
`order_delivered`, `order_cancelled`, `order_revised`,
`subscription_contract`, `subscription_payment_due`, `invoice_issued`,
`announcement`, `dailymenu.announce`.

**`otp_login` bu listede YOKTUR ve olmayacaktır:** giriş kodu metni
`OtpService` içindedir. Panelden düzenlenebilir olsaydı, kodun kendisini
metinden çıkarmak ya da metne bağlantı gömmek tek satırlık bir değişiklik
olurdu.

**`veykemtu_sms_log`** — `template_key` (null, index), `phone` (null,
normalleştirilmiş 10 hane), `customer_id` (null, index), `order_id`,
`subscription_id`, `body` (gönderilen metnin kendisi), `segments`, `status`
(`sent`\|`failed`\|`skipped`\|`dry_run`), `provider_ref`, `error`, `context`
(`auto`\|`test`\|`announcement`), `reference_type`, `reference_id`,
`created_at` (index), `sent_at` (index).

`UNIQUE(template_key, reference_type, reference_id)` (`veykemtu_sms_log_essiz`)

**Bu kısıt bir işlev değil, bir KAPIDIR.** SMS gönderimi zaman aşımına
uğrayabilen bir iştir; zaman aşımına uğrayan istek yeniden denenir, kuyruk işi
tekrar koşar, kullanıcı düğmeye iki kez basar. Üçü de aynı sonuca çıkar: aynı
sipariş geçişi için müşteriye beş mesaj. İdempotansı uygulamada kurmak
("önce bak, sonra yaz") iki eşzamanlı işçi arasında hiçbir şey garanti etmez —
kontrol ile yazma arasındaki pencere tam olarak o beş mesajın çıktığı yerdir.

**NULL referanslar bilinçli olarak AYRI SAYILIR** (10.1'de reddedilen MySQL
davranışı, burada tam olarak istenen şey): referansı olmayan bir gönderim
(deneme SMS'i, toplu duyuru) tekilleştirilecek bir olaya bağlı değildir;
500 alıcıya giden duyurunun 500 satır yazması gerekir.

**İki zaman damgası, aynı an.** `created_at` satırın doğuşu, `sent_at` panelin
sıraladığı ve `from`/`to` ile süzdüğü alan. Ayrışmıyorlar çünkü satır gönderim
denemesiyle birlikte doğuyor; tek kolona indirmek iki kulvardan birinin
sözleşmesini kırardı. **`sent_at` başarısız satırlarda da dolu:** boş
bırakılsaydı `GET /log?status=failed&from=…` hiçbir şey döndürmezdi — yani tam
da hataları aramaya gelen kişi hiçbir şey bulamazdı. `updated_at` yok: satır
bir olay kaydıdır, düzenlenmez.

**`customers.bld_sms_opt_out`** (bool, default `false`, indeksli
`veykemtu_musteri_sms_ret`) — teknik bir ayar değil, **hukuki bir
zorunluluk**. Sipariş durum SMS'i müşterinin kendi siparişinin
bilgilendirmesidir ve izin gerektirmez; günün menüsü duyurusu
(`dailymenu.announce`) ile toplu duyuru (`announcement`) ise **ticari
elektronik iletidir**: İYS kaydı ve alıcının önceden onayı ister, her iletide
çıkış hakkı sunmayı zorunlu kılar (6563 sayılı kanun + KVKK). Bu sunucunun
çözebileceği bir sorun değil; onay ve İYS entegrasyonu iş tarafının imzasını
bekliyor ve **`dailymenu.announce` şablonu o imza gelene kadar kapalı kalır**.

**Varsayılan `false` = "reddetmedi", "onayladı" DEĞİL.** İkisi aynı şey
değildir ve karıştırılması tam olarak yukarıdaki ihlali üretir. Onay kaydı
ayrı bir alandır ve henüz yoktur.

### 10.8 `veykemtu_announcements` + `veykemtu_announcement_reads`

**PUSH (FCM) YOK.** Müşteriye ulaşmanın iki yolu kaldı: SMS ve bu tablo.
Duyuru yalnız istemci açıkken çekilir; "teslim edildi" diye bir kavram yoktur,
"ekranda çizildi" vardır.

**`veykemtu_announcements`** — `title` (null), `body` (1000), `image_path`,
`placement` (default `home`), `severity` (default `info`), `style` (default
`banner`), `action_label`/`action_type`/`action_value`, `audience` (default
`all`), `starts_at`, `ends_at`, `priority`, `status` (default `draft`),
`dismissible` (default `true`), `created_by`, timestamps.
İndeksler: `(status, placement)`, `starts_at`, `ends_at`.

- **`placement` / `style` / `severity` üç ayrı soru:** hangi ekranda durduğu,
  nasıl çizildiği (bant mı kart mı), tonu. Tek kolona sıkıştırılsalardı "ana
  sayfada kart olarak duran kritik duyuru" ifade edilemezdi. `placement`
  kapalı enum DEĞİL (`string`): yeni bir ekran açıldığında sözleşmeyi
  beklemek, duyurunun haftalarca yayınlanamaması demek olurdu.
- **Eylem üç parçadır.** `action_label` boşsa düğme çizilmez; `action_type`
  hedefin cinsini söyler. Tek bir "url" kolonuna indirilseydi istemci
  `/siparislerim` yolunu tarayıcıda açıp müşteriyi uygulamadan çıkarırdı.
- **Kitle sunucuda süzülür** (`audience`). "Aboneliğinizi yenileyin"
  duyurusunu abone olmayana göstermek kadar kötü tek şey, süzgeci üç istemcide
  üç kez yazıp birinde unutmaktır.
- **Görselin YOLU saklanıyor, URL değil.** Alan adı ya da şema değiştiğinde
  (http → https, taşınma) tablodaki bütün satırlar bir anda kırık bağlantıya
  dönerdi.
- **`draft` doğar:** kaydedilir kaydedilmez yayına giren bir duyuru, yarım
  yazılmış metni bütün müşterilere gösterirdi.

**`veykemtu_announcement_reads`** — `announcement_id`, `customer_id`,
`seen_at`, `dismissed_at`. `UNIQUE(announcement_id, customer_id)`
(`veykemtu_duyuru_okuma_essiz`) · `INDEX(customer_id)`.

Okuma tablosu bu özelliğin **yarısıdır**, süs değil. Duyuru "açılışta göster"
mantığıyla çiziliyor; kapatma işareti sunucuda tutulmasaydı müşteri aynı bandı
her açılışta, her cihazda yeniden görürdü. İstemci yerelinde tutulsaydı da
web'de kapatılan duyuru mobilde yeniden açılırdı — üç istemcinin üç ayrı
hafızası olurdu. Aynı satır Kontrol Merkezi'nin "kaç kişi gördü / kaç kişi
kapattı" istatistiğini de besliyor.

**`seen_at` duyuruyu listeden DÜŞÜRMEZ, `dismissed_at` düşürür.** Tek bayrağa
indirilseydi ekranda çizilen her duyuru ilk karede kaybolur, müşteri okumaya
fırsat bulamazdı. `seen_at` İLK görülme anıdır ve bir daha değişmez.

### 10.9 `veykemtu_error_events` — durum monitörünün tek havuzu

Dört bileşenin (sunucu, KDS kasası, mobil, site) hataları burada buluşuyor.
"Bir şey çalışmıyor" şikâyeti geldiğinde bakılacak ilk ekran bu tabloyu okur
(`docs/control/monitor.md`).

`id`, `source` (index), `level` (index), `fingerprint` (**char(40) UNIQUE**),
`type`, `message` (500), `stack` (text), `context` (json), `occurred_at`
(index), `first_seen_at`, `last_seen_at` (index), `occurrences` (default 1),
`resolved_at` (index), `resolved_by`.

**`fingerprint` üzerindeki UNIQUE, tasarımın tamamıdır.** Tek bir çökme
döngüsü aynı hatayı dakikada yüzlerce kez üretir: yazıcıya ulaşamayan bir kasa
her yoklamada, sonsuz döngüye giren bir ekran her karede. Her tekrar ayrı satır
olsaydı bir öğleden sonra bu tabloya bir milyon satır yazılır, monitör ekranı
açılamaz hâle gelir ve GERÇEK hata — yanında duran, bir kez olmuş, kimsenin
göremediği satır — kaybolurdu. Tekrar yalnızca `occurrences` sayacını
artırıyor; "47 kez oldu" cümlesi 47 satırdan daha çok şey anlatır. SHA-1
seçildi çünkü aranan kriptografik güç değil, aynı hatanın iki tekrarının aynı
dizeyi üretmesi.

**`first_seen_at` hiç değişmez** ("bu ne zamandır oluyor"), **`last_seen_at`
her tekrarda ilerler** ("hâlâ oluyor mu"). Tek kolona indirilseydi üç haftadır
süren bir arıza ile beş dakika önce başlayan bir arıza panelde aynı görünürdü.
`occurred_at` ise hatanın İSTEMCİDE oluştuğu andır; sunucunun alış anıyla
arasındaki fark, çevrimdışıyken biriktirilip sonra gönderilen raporları ayırt
eden tek işarettir.

`source` sunucuda türetilir (`X-App-Id`), gövdeden okunmaz. **`DELETE` yok:**
bir hata kaydını silmek o hatanın hiç olmadığını iddia etmektir; çözülen olay
işaretlenir ve varsayılan süzgeçten düşer. `resolved_by` serbest metin —
Kontrol Merkezi ayrı bir depo, ayrı bir kullanıcı tablosu.

**Saklama şart:** `veykemtu:hata-temizle` (03:30) çözülmüş satırları 30,
çözülmemişleri 90 günden sonra siler. Saklama kuralı olmadan bu tablo, hiç
kimsenin silmeyi düşünmediği için diski dolduran tablo olurdu.

### 10.10 `veykemtu_kitchen_commands` — teslimat sayacı (additive)

| Kolon | Tip | Ne |
|---|---|---|
| `attempts` | tinyint unsigned, default 0 | Kaç kez teslim edildi |
| `expires_at` | timestamp null | Bu andan sonra komut anlamını yitirir |
| `dedupe_key` | varchar(64) null | Yineleme koruması |

`UNIQUE(device_id, dedupe_key)` (`kitchen_commands_dedupe_uq`) ·
`INDEX(device_id, executed_at, expires_at)` (`kitchen_commands_pending_idx`)

**Sahadaki belirti:** mutfak ekranı her on dakikada bir test fişi basıyordu.
`KitchenCommand::pendingFor()` sonucu gelmemiş her komutu on dakikada bir
yeniden teslim ediyor, `takeCommands()` de `delivered_at`'i yeniden damgalayıp
saati sıfırlıyordu — kusursuz ve kalıcı bir on dakikalık döngü.

**İki sayaç da gerekli, biri diğerini kapsamıyor:**

- `attempts` **ulaşılabilen** ama komutu sürekli düşüren kasayı sınırlar. Kasa
  sağlık bildiriyor, komutu alıyor, çalıştıramıyor ve sonucu bildiremiyor;
  `expires_at` tek başına burada otuz dakika boyunca üç yerine altı kez fiş
  bastırırdı.
- `expires_at` **ulaşılamayan** kasayı sınırlar. Hafta sonu kapalı kalan bir
  kasa pazartesi açıldığında `attempts` hâlâ sıfırdır ve cuma akşamından kalma
  bir test fişi basılırdı.

`dedupe_key` üçüncü kapı: aynı düğmeye iki kez basmak iki bağımsız döngü
açıyordu. Anahtar YALNIZ idempotent komutlarda dolu; **`reprint` bilerek
dışarıda** — aynı fişi ikinci kez basmak o düğmenin tek varlık sebebi.
Kapsam cihaz başına: iki kasaya aynı anda test fişi göndermek meşru bir istek.

Göç, o an döngüde olan satırları da kapatıyor (teslim edilmiş ama
onaylanmamışlar `executed_at` alıyor); yalnız **en az bir kez teslim
edilmişler** — hiç teslim edilmemiş bir komutu kapatmak, yöneticinin dakikalar
önce bastığı düğmeyi sessizce yutmak olurdu.
