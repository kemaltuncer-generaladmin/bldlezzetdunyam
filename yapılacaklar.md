# MutfakApp

[x] Sipariş düzenleme: burada sipariş düzenleme talebi oluturulacak mutfaktaki personel zaten müşteri telefon numarası görebiliyor müşteri ile ileitşime geçip işte atıyorum 20 mercimek değil de 10 mercimeğe çekebilecek siparişi. ücret iadesi akışları pos cari hesapbuna gmöre yapılacak ve yeni bir mutfak kurye fişi hazırlanacak. web-mobil-admin poanel ilketişiminde de bu güncellemeler gidecek
    → K-12/K-13/K-14. Motor + KDS düzenleme ekranı + iade + kurye fişi + panoda telefon + web/mobil/admin yansıması.
[x] sipariş gelince hoparlörden ses çalmıor ayrıca hoparlör kontrol eklenecek
    → K-09. Kök neden bulundu: `pw-play -q <dosya>` hatalıydı, ses hiç çalmıyordu.
[x] sistem dokunmatik monitörle uygun hale getirilecek
    → K-10. Ekran klavyesi, büyük hedefler, kaydırma jestleri, geri alma penceresi.
[x] api katmanına posla haberleşme gelecek böylelikle ileride bbdstore da onaylanan oluşturulan siparişler otomaitk olarak fiş basımı aynı yazıcıdan olacak. bbd katman adında bir buton mini ekran ekler oradan görürüz olanı
    → K-16. İmzalı webhook + ayrı ses + termal fiş + durum çubuğunda "BBD: n" çipi.
      BBD siparişleri panoya, ciroya ve cari hesaba KARIŞMAZ (senin kararın). BBD tarafına not en altta.
[x] müşteri cari hesabı stok durumu satışa açık kapalı ürünler sipariş almayı durdurma gibi özellikler gelecek
    → K-11. Stok/"bugün tükendi", satışa açık-kapalı ve sipariş durdurma bitti.
      Cari hesap KDS'e ALINMADI — senin kararın (ADR-08 korunuyor); yalnız düzenleme onayında iade/fark tutarı görünüyor.
[x] mutfak app sipariş almayı açıp kapatabilecek
    → K-11. Süre + sebep + açılış şifresi ile.
[x] abonelik için atığımız ekran detaylandırılacak. ekran aşlırı boş işlevsellik arttırılacak
    → K-15. Tam ekran üretim planı (bugün/yarın/hafta), ürün toplamları, teslimat çizelgesi,
      durum ilerletme, "üretim koşmadı" uyarısı ve üretim planı fişi.

# Web-Admin
[] api subdomaininde farklı bir bld sitesi yatıyor bu site kaldırılacak. orijinal anadomain olacak
[] kullanıcı ana domaine ilk girdiği anda sisteme giriş yapabilşecek ve hızlıca sipariş verebileek
[] menülere tıklayınca kaybolmuyıor kalıyor üst header bar gömzden geçirilecek
[] abonelik-abonelik takibi gibi işlemler işte cari hesapta istenen ya da total tutara göre ödeme simülasyonu olacak.

# MusteriApp
[] abonelik-abonelik takibi gibi işlemler işte cari hesapta istenen ya da total tutara göre ödeme simülasyonu olacak.
[] mobil uygulama anmasyon ve işlevselliği arttırılacak
[] mobil ui sıfırdan yemeksepeti gibi tasarlanacak. bu tasarımda kullanıcının prati bi şekilde kurumsal catering hissiyatı arttırılacak. 
[] Admin panelden yönetilen bir ana sayfa görsel ve uygulama içi CTA mantığı oturtulacak. böylelikle panelden üğrün reklamı tanıtım duyuru vs yapoıalbilecek
[] admin panelden abonelik ne zaman başlayacak işte beklenen teslimat saati gibi ayrıntılar toplaacak. 
[] profil sekmesine belgelerim eklenecek böylelikle genel bir işte onaylanan sözleşmeler vs olacak. admin panelden müşteri bazlı her müşteri sözleşmelerini kontrol edecek
[] kullanıcı dış linkten ödeme yapomayacak her türlü işlemi uygulamada yapacak
[] uygulama içerisinde tek tıkla mutağı arayabilecek siparişi oluştuktan sonra gereken desteği oradan alacak. böylelikle müşteri temsilcisi kısmı da mutfağa düşecek

# Siber
[] maksimum düzeyde RLS kural çalışmaı yapıalcak. her türlü rls kaynaklı veri sızıntısı önlenecek engellenecek
[] dış kullanıcılar için esnek ama sıkı bir fail2ban sistemi kurulacak
[] kapsamlı bir watchdog kurulacak.
[] tüm tokenler ve imza süreleri elden geçirilecek. imzası doğrulanmayan token olmayacak doğrulanmamış imzalı tokenler sisteme sızamayacak
[] sistemde fishing tarzı durumlara karşı bir saldırı koruma kalkanı kurulacak

# Yasal Metinler
[] Kapsamlı bir cari hesap sözleşmesi hazırlanacak
[] KVKK, Gizlilik Politikaı ve Uygulama kullanım koşulları yasal belgeleri hazırlanacak.
[] Ödeme planı metinleri oluşturulacak

---

# Log — MutfakApp turu (11–12.08.2026)

**MutfakApp maddelerinin tamamı kapandı.** Görev kimlikleri
`docs/09-gorev-plani.md` §8.5'te, her maddenin gerekçesi
`docs/05-mutfakapp.md` §11–§16'da.

Kapsam dışında bırakılan tek şey **cari hesabın KDS'te gösterilmesi** —
senin kararın; ADR-08 korunuyor ve düzenleme onayında yalnız iade/fark
tutarı görünüyor.

## K-09 — Ses ve hoparlör · BİTTİ

**Kök neden bulundu ve makinede yeniden üretildi.** `pw-play -q <dosya>`
çağrısı hatalıydı: `aplay`'de `-q` "sessiz kip", `pw-play`'de `--quality`
ve bir değer bekliyor — dosya yolunu yutuyor, geriye çalınacak dosya
kalmıyor. Ubuntu 24.04 PipeWire ile geliyor ve `pw-play` tercih listesinde
ilk sırada, yani **kasada alarm hiç çalmadı**:

```
$ pw-play -q /tmp/bld_yeni_siparis.wav
error: filename or - argument missing
exit=1
```

Hatanın görünmemesinin sebebi de düzeltildi: eski kod yalnız istisna
yakalıyordu; süreç başlayıp hata koduyla çıkınca `isMuted` `false` kalıyor,
arayüz "ses açık" gösteriyor, döngü de sıkı biçimde süreç açmaya devam
ediyordu.

- Argümanlar `AudioPlayerCommand` içine alındı ve **regresyon testiyle**
  sabitlendi (`pw-play` `-q` almaz).
- Çıkış kodu denetleniyor; sessizliğin **sebebi** arayüze taşınıyor
  (`muteReason` → uyarı şeridi + "Ses tanılama" bloğu).
- Ardışık hatada geri çekilme (sıkı döngü yok).
- Ses dosyaları `/tmp` yerine uygulama destek klasörüne çıkarılıyor
  (systemd `PrivateTmp` / dolu `/tmp` sessiz başarısızlık üretiyordu).
- Ses seviyesi (0–100), çıkış cihazı seçimi, **sistem hoparlör seviyesi**
  (`wpctl`/`amixer`), olay bazlı 6 ses, tekrar aralığı/sınırı, Türkçe sesli
  anons (`spd-say`).
- Sesler `mutfakapp/tool/ses_uret.py` ile **üretiliyor** — telifsiz,
  yeniden üretilebilir, ayırt edilebilirlikleri gerekçeli.
- Sözleşmede olup **hiçbir yere bağlanmamış** 4 alan bağlandı:
  `printer_code_page`, `health_seconds`, `connection_alarm_seconds`,
  `alarm_silenceable`.

## K-10 — Dokunmatik uyum · BİTTİ

- `touchMode` ayarı; **kapalıyken bugünkü düzen bit bit aynı** (regresyon
  riski sıfır).
- Türkçe ekran klavyesi (`lib/src/input/onscreen_keyboard.dart`) — kilit
  ekranı, arama, sebep metni, şifre. Kasada sistem klavyesi yok; harici
  klavye yoksa uygulama **hiç açılamıyordu**.
- Tema düzeyinde büyük dokunma hedefleri, açılır menü yerine alt sayfa,
  kartta kaydırma jestleri.
- **Geri alma penceresi:** "geri alma yoktur" kuralı kaldırılmadı, 120
  saniyelik tek adımlık pencereye daraltıldı. `yeni`ye dönüş ve terminal
  durumlardan geri alma yok (basılı fiş / cari ters kayıt).

## K-11 — Satış kontrolü · BİTTİ

- **Kural değişikliği belgelendi:** `docs/03` §3'teki "mutfak tek tuşla
  cirosu kapatamamalı" kuralı, sahada tersine işlediği için değiştirildi.
  Şalter mutfaktan çevriliyor ama süre + sebep + **açılış şifresi** ile.
- Süreli durdurma (30 dk / 1 sa / gün sonu / süresiz); süre **tembel**
  değerlendiriliyor, cron yok.
- Sebep müşteriye gösteriliyor (web bandı + mobil menü uyarısı).
- Ürün bazında "bugün tükendi" — `menus.menu_status` kullanılmadı
  (yöneticinin kalıcı kararı ile mutfağın günlük kararı ayrı tutuldu).
- **Abonelik muaf**: sözleşme, günlük stok kararıyla iptal edilemez.
- `_BusyToggle` hatası düzeltildi: yoğunluk şalteri açılışta sunucudan
  okunmuyordu; iki kasalı kurulumda ikincisi hiç haberdar olmuyordu.

## K-12/K-13 — Sipariş düzenleme motoru ve iade · BİTTİ

- `LineResolver` ayrıştırıldı: fiyat/opsiyon/uygunluk mantığı tek yerde
  (`OrderFactory` de artık onu kullanıyor).
- `OrderEditor` — tek işlemde satır yeniden yazma, **toplam yeniden
  hesaplama**, revizyon belgesi, cari düzeltme, iade.
- **En riskli detay çözüldü:** `orders.updated_at` dokunulmasaydı
  düzenleme KDS ekranına **hiç düşmezdi**; testi yazıldı.
- **İkinci düzenlemenin sessizce yutulması önlendi:** cari defter referansı
  siparişe değil **revizyona** bağlandı.
- **`order_totals` iki katına çıkması önlendi:** tabloda `(order_id, code)`
  tekilliği yok, eski kod yalnız `insert` yapıyordu.
- Sağlayıcı-bağımsız `RefundGateway` + `RefundManager`; sürücü **ödeme
  yönteminden** türüyor. Başarısız iade de kayıt açıyor.
- İptal edilen ödenmiş siparişte de iade kaydı açılıyor.

## K-14 — Kurye fişi, telefon, revizyon · KISMÎ

**Bitti:**
- Üçüncü fiş tipi `kurye` (`packages/core` şablonu + 2 golden test + 4
  kural testi). Tahsilat satırı çift boy; ödenmiş siparişte basılmıyor.
- **Panoda telefon** — `docs/03` §5'teki gizlilik kuralı daraltıldı
  (fiyat ve adres hâlâ gizli).
- Kartta `REVİZE #N` rozeti.
- Fiş tekilliği `(order_id, type)` → `(order_id, type, revision)`;
  SQLite göçü veri kaybetmeden yapılıyor. Revize fiş eskiden **sessizce
  yutuluyordu**.
- Müşteri tarafı: `GET /orders/{id}` artık `revision_no` + `revisions[]`
  döndürüyor.

**Yapılmadı:** KDS'teki düzenleme ekranı (adet ±, ürün ekleme, sebep
seçimi, fark onayı). Motor ve uçlar hazır, tetiği yok.

## K-15 / K-16 · YAPILMADI

Abonelik üretim planı ekranı ve BBD Store köprüsü bu turda başlanmadı.
BBD tarafına bırakılan not aşağıda; kendi tarafımızdaki iş henüz sıfır
(yalnız `bbd_siparis.wav` ses dosyası hazır).

## Doğrulama (bu turda çalıştırıldı)

```
mutfakapp      flutter analyze → temiz | flutter test → 430 test geçti
packages/core  flutter analyze → temiz | flutter test → 134 test geçti
api_client     flutter analyze → temiz
design_system  flutter analyze → temiz
musteriapp     flutter analyze → temiz | flutter test →  97 test geçti
website        eslint → temiz | tsc --noEmit → temiz
docs/openapi.yaml → YAML geçerli, 44 yol
```

**PHP tarafı KOŞTURULAMADI:** bu makinede PHP çalışma zamanı ve MySQL yok.
Yazılan bütün PHP dosyaları Docker (`php:8.3-cli`) ile `php -l` sözdizimi
denetiminden geçirildi; **feature testleri çalıştırılmadı.** Sunucuda ilk iş:

```bash
cd platform
php artisan igniter:up          # yeni göçler: 5 adet
vendor/bin/phpunit --testsuite Veykemtu
```

---

# BBD Store ajanına not (K-16 — BLD tarafı)

> Bu blok **Benim Başarı Dünyam** projesindeki ajan içindir.
>
> **BLD TARAFI HAZIR (12.08.2026).** Uç yazıldı, imza doğrulaması,
> tekilleştirme, kasa kuyruğu, ayrı ses ve fiş şablonu çalışıyor.
> Eksik tek şey: `BBD_WEBHOOK_SECRET` değerinin iki tarafa da
> girilmesi. Sırrı üretip iletince entegrasyon açılır.

## Amaç — ve amaç OLMAYAN şey

BBD Store'da bir sipariş oluştuğunda mutfaktaki KDS'in **tek yapacağı**:

1. BBD'ye özel bir **ses** çalmak,
2. aynı termal yazıcıdan bir **fiş** basmak.

**Bunun dışında hiçbir şey yok.** BBD siparişleri BLD'nin `orders`
tablosuna girmez, KDS panosunda görünmez, üretim listesine, vardiya
istatistiğine, günlük sipariş sayacına ve cari hesaba **karışmaz**. İki
sistem ayrı kalır; tek bağ ses ve kâğıttır.

## Uç

```
POST https://api.benimlezzetdunyam.com.tr/api/partner/bbd/orders
Content-Type: application/json
X-BBD-Signature: sha256=<hex>
Idempotency-Key: <external_id>
```

## İmzalama

Ortak sır BLD tarafından iletilecek (`BBD_WEBHOOK_SECRET`; repoya girmez,
`.env` ile taşınır).

```
imza = HMAC_SHA256(anahtar = BBD_WEBHOOK_SECRET, veri = ham istek gövdesi)
X-BBD-Signature: sha256=<imzanın hex hâli>
```

Ham gövde üzerinde hesaplanır — JSON yeniden serileştirilmez (boşluk ve
anahtar sırası imzayı değiştirir). Örnek (PHP):

```php
$body = json_encode($payload, JSON_UNESCAPED_UNICODE);
$signature = 'sha256='.hash_hmac('sha256', $body, $secret);
```

## Gövde

```json
{
  "external_id": "BBD-2026-000123",
  "order_number": "BBD-123",
  "created_at": "2026-08-11T14:32:00Z",
  "customer_label": "Ayşe Y.",
  "phone": "0555 123 45 67",
  "delivery_type": "delivery",
  "address": "Örnek Mah. 12. Sk No:3, Selçuklu / Konya",
  "note": "Zili çalmayın",
  "items": [
    { "name": "Mercimek Çorbası", "quantity": 2, "options": ["Büyük"], "note": null }
  ],
  "amount_kurus": 18500
}
```

- `external_id` **zorunlu ve tekil**. Tekilleştirme buna bakar.
- `items[].name` fişe **olduğu gibi** basılır; BLD menüsüyle eşleştirme
  yapılmaz (BBD ürünleri BLD menüsünde yok).
- `amount_kurus` kuruş cinsinden tamsayı. Yoksa fişe tutar basılmaz.
- Türkçe karakterler UTF-8; fişte PC857'ye çevrilir.

## Yanıtlar

| Kod | Anlamı | Ne yapmalısınız |
|---|---|---|
| `200` | Alındı (yeni ya da **tekrar**) | Başarılı sayın, tekrar göndermeyin |
| `401` | İmza geçersiz | Sırrı ve imzalama biçimini kontrol edin |
| `422` | Şema hatası | Gövdeyi düzeltin; tekrar denemek işe yaramaz |
| `429` | Oran sınırı (300/saat) | Geri çekilerek tekrar deneyin |
| `5xx` | BLD tarafında sorun | Geri çekilerek tekrar deneyin |

## Yeniden deneme

- Üstel geri çekilme: 5 sn, 15 sn, 1 dk, 5 dk, 15 dk, sonra 30 dakikada bir.
- **24 saat** boyunca deneyin, sonra ölü-mektup kuyruğuna alın.
- Aynı `external_id` ile tekrar göndermek **güvenlidir**: ikinci fiş
  basılmaz.

## Test

```bash
SECRET='...'
BODY='{"external_id":"BBD-TEST-1","order_number":"BBD-1","created_at":"2026-08-11T14:32:00Z","customer_label":"Test","delivery_type":"pickup","items":[{"name":"Test Ürün","quantity":1}]}'
SIG="sha256=$(printf '%s' "$BODY" | openssl dgst -sha256 -hmac "$SECRET" -r | cut -d' ' -f1)"

curl -sS -X POST https://api.benimlezzetdunyam.com.tr/api/partner/bbd/orders \
  -H "Content-Type: application/json" \
  -H "X-BBD-Signature: $SIG" \
  -H "Idempotency-Key: BBD-TEST-1" \
  -d "$BODY"
```

Aynı komutu ikinci kez çalıştırın: yanıt yine `200` olmalı ve mutfakta
**ikinci fiş çıkmamalı**.

## BLD tarafı — HAZIR

- `veykemtu_bbd_receipts` tablosu (`external_id` UNIQUE) ✅
- `POST /api/partner/bbd/orders` + `bbd.signature` middleware +
  `throttle:bld-partner` (300/saat) ✅
- `GET /api/kitchen/bbd-orders` + ack ucu (kuyruk sunucuda) ✅
- `packages/core`'da `buildBbdReceipt` + 2 golden + 5 kural testi ✅
- KDS'te ayrı ses, fiş basımı ve durum çubuğunda "BBD: n" çipi ✅
- 14 feature testi (imza, tekilleştirme, "panoya karışmıyor") ✅

**Tek kalan:** `BBD_WEBHOOK_SECRET` sırrının üretilip iki tarafa da
girilmesi. Boşken uç 401 döner — bilinçli.
