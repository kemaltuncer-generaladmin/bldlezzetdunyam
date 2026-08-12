# 05 — Mutfak Uygulaması (KDS)

**Hedef platform: yalnızca Linux desktop (Ubuntu 24.04).** Android hedefi yoktur, eklenmeyecektir.

## 1. Donanım ortamı

| Bileşen | Detay |
|---|---|
| Bilgisayar | MSI kasa, Ubuntu 24.04 LTS Desktop |
| Ekran | Mutfağa monte monitör |
| Yazıcı | 80mm termal, USB, ESC/POS uyumlu |
| Giriş | Klavye/fare (kurulum için), dokunmatik değilse fare ile kullanım |
| Ağ | Kablolu veya WiFi, sürekli internet |

## 2. Teknoloji

- Flutter 3.x, `flutter build linux`
- State: Riverpod
- Model: freezed + json_serializable
- Yerel depolama: `sqlite3` (yazdırma kuyruğu) + `shared_preferences` (token, ayarlar)
- USB yazıcı: doğrudan cihaz dosyasına yazma (`/dev/usb/lp0`) — CUPS kullanılmaz
- Bağımlılıklar `packages/api_client` ve `packages/core` üzerinden

## 3. Ekran tasarımı

Tek ekran, üç bölge:

```
┌────────────────────────────────────────────────────────────┐
│ ÜRETİM LİSTESİ    Tavuk Sote 40 · Mercimek 25 · Pilav 18   │ ← üst şerit
├────────────────────────────────────────────────────────────┤
│  YENİ (3)      │ HAZIRLANIYOR (4) │ HAZIR (2)              │
│ ┌────────────┐ │ ┌──────────────┐ │ ┌──────────────┐       │
│ │S-5012  ADR │ │ │S-5008 GELAL  │ │ │S-5001  ADR   │       │
│ │2× Tavuk S. │ │ │1× Tost       │ │ │3× Pilav      │       │
│ │Az acılı    │ │ │Mehmet K.     │ │ │Ayşe Y.       │       │
│ │[ONAYLA]    │ │ │[HAZIR]       │ │ │[YOLA ÇIKTI]  │       │
│ └────────────┘ │ └──────────────┘ │ └──────────────┘       │
├────────────────────────────────────────────────────────────┤
│ ● Bağlı  ● Yazıcı hazır  Kuyruk: 0   14:32   [Ayarlar]     │ ← durum çubuğu
└────────────────────────────────────────────────────────────┘
```

**Kurallar:**
- Kartlar **büyük ve uzaktan okunur**: ürün adı en az 20sp, adet 28sp kalın.
- Teslimat rozeti renkli: `ADR` adrese gönderim (turuncu), `GELAL` gel-al (gri). Rozet `delivery_type` alanından türetilir.
- İstenen teslim saati (`requested_at`) varsa kartta gösterilir; geçmişse kırmızıya döner.
- Yeni sipariş: kart 3 saniye yanıp söner + sesli uyarı (kısa "ding", `assets/new_order.wav`).
- Sipariş notu varsa kartta **vurgulu** gösterilir (kırmızı arka plan), asla gizlenmez.
- `hazir` sütununda `delivery_type=delivery` siparişi "YOLA ÇIKTI", `pickup` siparişi "TESLİM EDİLDİ" butonu gösterir.
- Geri alma yok; yanlış basılırsa admin panelden düzeltilir (mutfakta yanlışlıkla geri alma riskini önlemek için).


### Pano yoğunluğu — boş sütun daralır (07.08.2026)

Üç sütun eşit üçte bir paylaşıyordu. Yoğun saatte gerçek tablo şöyle oluyor:
YENİ'de sekiz sipariş birikmiş, HAZIRLANIYOR boşalmış, HAZIR'da bir kart var.
Eşit paylaşımda **ekranın üçte ikisi boş dururken** kuyruğun biriktiği sütun
kayıyordu — aşçı bir metreden baktığında sırada ne olduğunu göremiyordu.

İki değişiklik birlikte çalışıyor:

1. **Boş sütun daralır.** `Expanded(flex: bos ? 1 : 3)`. Tek eşik var — sütun
   boş mu, dolu mu. Sipariş sayısıyla orantılı olsaydı her siparişte
   genişlikler oynar, göz her seferinde yeniden yer arardı.
2. **Genişleyen sütunda kartlar yan yana dizilir.** `OrderColumn` sütun
   genişliğini ölçüp satır başına kart sayısını buluyor
   (`_minCardWidth = 360`, en fazla iki).

Ölçülen sonuç: sekiz siparişli YENİ sütununda kaydırmadan görünen kart sayısı
**üçten altıya** çıktı. Pano dengeliyken (her sütunda kart varken) düzen
değişmiyor — hiçbir sütun iki kart sığdıracak kadar genişlemiyor.

> **`_minCardWidth` neden 360?** 1920 px'lik ekranda komşusu boşalmış bir
> sütun ~795 px'e çıkıyor. Eşik 400 olsaydı `795 / 400 = 1,98` aşağı
> yuvarlanır ve iki kart hiç yan yana gelmezdi. İlk denemede tam bu oldu.

> **Tek kalan kart sütunun tamamına yayılır.** Yarım genişlikte durup yanında
> boşluk bırakmıyor; HAZIR sütununda bekleyen tek sipariş daha görünür oluyor.

Başlık artık kırpılmıyor: daralan sütunda "HAZIRLANIYOR (0)" yazısı
`FittedBox(scaleDown)` ile küçülüyor. Kesik bir kelime ekranda arıza gibi
duruyordu.

Davranış `test/board_density_test.dart` ile korunuyor (6 test).

## 4. Veri katmanı

**Zorunlu soyutlama:**
```dart
abstract class OrderSource {
  Stream<List<KitchenOrder>> watch();
  Future<void> refresh();
}
class PollingOrderSource implements OrderSource { ... }   // Faz 1
class WebSocketOrderSource implements OrderSource { ... } // Faz 1.5
```

**Polling davranışı:**
- Her 5 saniyede `GET /api/kitchen/orders?since=<son server_time>`.
- Yanıttaki `server_time` bir sonraki isteğin `since` değeri olur.
- Ağ hatası: üstel geri çekilme (5s → 10s → 20s → max 60s), durum çubuğunda "Bağlantı yok" uyarısı, son bilinen liste ekranda kalır.
- Bağlantı geri gelince tam yenileme yapılır (kaçırılan durum değişimleri için).
- `heartbeat` her 60 saniyede bir gönderilir.

**Yerel önbellek:** Aktif siparişler SQLite'a yazılır; uygulama yeniden başlarsa ekran boş açılmaz.

## 5. Yazdırma alt sistemi

### 5.1 Yazıcı erişimi

Ubuntu'da USB termal yazıcı genelde `/dev/usb/lp0` olarak görünür.

```bash
# Cihazı bul
ls -l /dev/usb/
lsusb   # vendor:product id için
```

**udev kuralı** (`infra/kasa/99-thermal-printer.rules`) — kalıcı isim ve izin:
```
SUBSYSTEM=="usb", ATTRS{idVendor}=="XXXX", ATTRS{idProduct}=="YYYY", MODE="0666", SYMLINK+="thermal0"
```
Uygulama `/dev/thermal0` sembolik bağını kullanır; port değişse bile bozulmaz.

Yazıcı yolu ayarlardan değiştirilebilir (varsayılan `/dev/thermal0`).

### 5.2 ESC/POS komutları

Temel komut seti (`packages/core/lib/escpos/`):

| İşlev | Byte |
|---|---|
| Başlat/sıfırla | `1B 40` |
| Hizalama sol/orta/sağ | `1B 61 00/01/02` |
| Kalın aç/kapa | `1B 45 01` / `1B 45 00` |
| Çift boy | `1D 21 11` (normal: `1D 21 00`) |
| Satır besle | `0A` |
| Kağıt kes | `1D 56 42 00` |
| Türkçe karakter | Kod sayfası seçimi `1B 74 1D` (**ESC t 29**) — aşağıdaki nota bakın |

### Kod sayfası — gerçek donanımdan doğrulandı (04.08.2026)

Bu doküman başlangıçta `ESC t 13` (PC857) diyordu. **Sahadaki yazıcıda çalışmıyor.**

Donanım: `0483:5720` — `aaaait Printer`, seri `11101800002`, `/dev/usb/lp1`.

`ESC t 13` gönderildiğinde Türkçe baytlar **boşluk** olarak basıldı (o kod
sayfasında glif yok). `n = 0..47` taraması yapıldı; Türkçe karakterler
yalnızca **`n = 29`** ile doğru çıktı.

```
1B 74 1D      ESC t 29 — bu yazıcıda Türkçe kod sayfası
```

Bayt karşılıkları (PC857 düzeniyle aynı, yalnızca seçim numarası farklı):

| Harf | Bayt | Harf | Bayt |
|---|---|---|---|
| ç | `87` | Ç | `80` |
| ğ | `A7` | Ğ | `A6` |
| ı | `8D` | İ | `98` |
| ö | `94` | Ö | `99` |
| ş | `9F` | Ş | `9E` |
| ü | `81` | Ü | `9A` |

**Ders:** ESC/POS kod sayfası numaraları üreticiye göre değişir; standart
değildir. Yazıcı değişirse tarama tekrarlanmalıdır — `infra/kasa/`
altındaki `kodsayfasi-tara.sh` bunu tek komutla yapar.

**Türkçe karakter zorunluluğu:** ç ğ ı ö ş ü İ Ş Ğ Ü Ö Ç doğru basılmalı.
UTF-8 metin bu tabloya çevrilir; çeviri `packages/core/lib/src/escpos/pc857.dart`
içindedir ve golden test ile doğrulanır.

### 5.3 Fiş şablonları

**Mutfak fişi** (fiyat yok, iri punto):
```
   *** ADRESE GÖNDERİM ***
      SİPARİŞ S-5012
      04.08.2026 14:32
      Teslim: 05.08 09:30
      Tel: 5551234567     (çift boy)
--------------------------------
2×  TAVUK SOTE
    (Normal)
    >> Az acılı <<

1×  MERCİMEK ÇORBASI
--------------------------------
NOT: Fatura kurumsal
```

**Müşteri fişi** (fiyatlı — K-20'den beri **kuryenin de fişi**):
```
###### GÜNCEL FİŞ ######      (yalnız revizyonda, çift boy)
###### REVİZE #2 ######
### ÖNCEKİ FİŞİ ATIN ###
--------------------------------
   BENİM LEZZET DÜNYAM
      Sipariş: S-5012
      04.08.2026 14:32
      Teslim: 05.08 09:30
--------------------------------
TESLİMAT
AYŞE YILMAZ
Tel: 0555 123 45 67           (çift boy)
Örnek Mah. 12. Sk No:3
Selçuklu / Konya

        [HARİTA QR]
       Haritada aç
NOT: Zili çalmayın
--------------------------------
2× Tavuk Sote        370,00
1× Mercimek Çorbası   85,00
--------------------------------
Ara Toplam           455,00
Teslimat              40,00
TOPLAM               495,00
Ödeme: Kapıda (Bekliyor)
--------------------------------
DEĞİŞİKLİKLER                 (yalnız revizyonda)
* Mercimek Çorbası: 20 -> 10
--------------------------------
     TAHSİL: 495,00           (çift boy, ödenmemişse)
--------------------------------
      [KARTLA ÖDE QR]         (ödenmemişse)
      [TAKİP QR]
 KURYE: TESLİMDEN ÖNCE OKUT
      [TESLİM QR]             (yalnız adrese gönderim)
--------------------------------
Bu belge bilgi fişidir,
mali değeri yoktur.
```

**BLOK SIRASI KEYFÎ DEĞİL — kâğıdı kimin ne zaman okuduğuna göre.** Kurye
kâğıdı eline aldığında sorduğu ilk soru "nereye gidiyorum"; kalem
fiyatlarına hiç bakmıyor. Bu yüzden teslimat bloğu fiyat tablosunun
**üstünde**. Aşağıda kalsaydı her teslimatta fişin tamamı okunmak zorunda
olurdu.

`DEĞİŞİKLİKLER` bloğu toplam ile tahsilat **arasında**: okunuşu bir neden
zinciri kuruyor — "toplam bu → çünkü şunlar değişti → şu kadar tahsil et".
Kapıda tutar tartışması çıktığında okunacak sıra tam olarak budur.

**SİPARİŞ NOTU TESLİMAT BLOĞUNDA, fişin dibinde değil.** "Zili çalmayın" bir
kapı talimatı ve kurye onu yola çıkmadan okumalı. Not bugüne kadar kuryeye
yalnız kurye fişiyle ulaşıyordu; o fişi otomatik basmaktan vazgeçip notu
taşımasaydık, kuryenin elinden bir kapı talimatını silmiş olurduk.

`delivery_type=pickup` siparişinde **teslimat bloğunun tamamı** (ad, telefon,
adres, harita QR, sipariş notu), "Teslimat" ücret satırı, `TAHSİL` satırı ve
teslim QR'ı **basılmaz**; yerine `GEL-AL` yazar. Sunucu gel-al'da bu alanları
zaten `null` gönderiyor, ama kapı şablonun kendisinde de var — bir alan dolu
gelse bile gel-al fişinde tek satır belirmez.

Mutfak fişindeki `Tel:` satırı `customer_phone` doluysa **çift boy** basılır —
numara mutfağın ışığında, kâğıdı eline almadan okunabilmeli. Çift boyda satır
24 karakterdir; şablon numarayı bu genişliğe göre sarar. Fiş, mutfak
kapsamının müşteri telefonunu gördüğü **tek** yerdir; KDS kartlarında telefon
yoktur (`docs/03-api-sozlesmesi.md` §GET /api/kitchen/orders/{id}/receipt).

Müşteri fişindeki harita QR'ı yalnızca adreste iğne varsa basılır ve içinde
`https://www.google.com/maps?q=<enlem>,<boylam>` bağlantısı taşır. Serbest metin
adres QR'la birlikte **yine de** basılır: fiş buruşabilir, kuryenin telefonu
bitebilir.

#### Fişteki dört QR — K-18/K-19/K-20

Fişte artık en çok dört QR olabiliyor. Hepsi **koşullu**: veri yoksa blok hiç
basılmaz, boş kare çıkmaz.

| QR | Nerede | Ne zaman basılır | İçerik |
|---|---|---|---|
| Harita | Teslimat bloğunun altında | `address_latitude` **ve** `address_longitude` dolu | `https://www.google.com/maps?q=<enlem>,<boylam>` |
| Ödeme | Fişin sonunda, takip QR'ının **üstünde** | `pay_url` dolu | Ödeme sayfası + `?return=<takip adresi>` |
| Takip | Ödeme QR'ının altında | `track_url` dolu | `<FRONTEND_URL>/takip/<id>?e=…&s=…` |
| **Teslim** | En altta, `KURYE: TESLİMDEN ÖNCE OKUT` başlığıyla | `deliver_url` dolu (yalnız adrese gönderim) | `<APP_URL>/teslimat/<id>?e=…&s=…` |

**TAKİP ADRESİ K-20'DE DEĞİŞTİ VE BU BİR HATA DÜZELTMESİYDİ.** Eskiden
`<FRONTEND_URL>/siparis/<id>` idi; o rota `website/middleware.ts` matcher'ında
ve `requireSession` ile korunuyor. Yani **fişteki kareyi okutan müşteri
sipariş durumunu değil giriş ekranını görüyordu.** Kâğıda basılan bir QR giriş
isteyemez. Yeni adres imzalı ve girişsiz; girişli `/siparis/{id}` sayfası
olduğu gibi duruyor.

**Teslim QR'ı başlıklı basılıyor** çünkü kâğıt teslimden sonra müşteride
kalıyor: kurye onu kapıda, kâğıdı vermeden ÖNCE okutmalı. Başlıksız dördüncü
bir kare, hangisinin kimin olduğunu belirsiz bırakırdı.

**Ödeme QR'ı simülasyon kapalıyken de basılmıyor (K-20).** `veykemtu/payment`
üretimde `POS_ALLOW_SIMULATION` tanımsızken rotayı **hiç kaydetmiyor**; bu
kontrol eklenene kadar fişe ölü bir adrese giden kare basılıyordu ve okutan
müşteri Caddy'nin 308'i sayesinde ana sayfaya düşüyordu.

#### Teslim onayı — imzalı, tek kullanımlık (K-20)

Kurye QR'ı okutuyor → tek düğmeli bir onay sayfası açılıyor (sipariş numarası,
ad, adres, tahsil edilecek tutar, `TESLİM ETTİM`) → basınca sipariş
`teslim_edildi` oluyor.

* **Kurye girişi yok.** Kuryenin sistemde hesabı yok ve olması bu işin on katı
  bir iş. Yetki URL'deki HMAC imzasında; imza sipariş kimliğine, amaca ve son
  geçerlilik anına bağlı.
* **Tek kullanımlık, ayrı bir bayrak olmadan.** `teslim_edildi` durum
  makinesinde terminal, yani ikinci okutma geçerli bir geçiş bulamıyor. Ayrı
  bir "kullanıldı" sütunu aynı gerçeği ikinci kez kodlar ve ikisinin
  ayrışabildiği bir durum yaratırdı.
* **İkinci okutma hata ekranı DEĞİL:** "bu sipariş zaten teslim edildi" diyor.
  Çift dokunan kurye kırmızı ekran görmemeli, iş zaten olmuş.
* **`hazir` durumunda iki adım atılıyor.** Fiş `hazir`da basılıyor ama durum
  makinesi adrese gönderimde `hazir -> teslim_edildi` geçişini reddediyor
  (`docs/02` §3) ve mutfakta kimse "yolda" düğmesine basmamış olabilir. Matris
  **gevşetilmedi** — gevşetmek o adımı atlama iznini bütün istemcilere
  verirdi; onun yerine tek işlem içinde `yolda` sonra `teslim_edildi`
  yazılıyor. İki dürüst geçmiş satırı gerçeğe de daha yakın: kurye gerçekten
  yola çıktı ve gerçekten vardı, ikisini aynı anda öğrendik.
* **Kabul edilen risk:** fişi fotoğraflayan biri siparişi teslim edilmiş
  işaretleyebilir. Zarar sınırlı (yemek zaten gitti), bağlantı tek
  kullanımlık ve süresi kısa (2 gün). Alternatif, kuryeyi kapıda giriş yapmaya
  zorlamaktı.
* **`infra/Caddyfile.internal` izin listesi şart:** `/teslimat/*` orada
  olmazsa istek ana siteye 308'lenir ve hata "QR ana sayfayı açıyor" diye
  görünüp yanlış depoda aranır.

**Ödeme QR'ı ödenmiş siparişte basılmaz.** `ReceiptBuilder::payUrl()`,
`$order->processed` doğruysa `null` döner. Ödenmiş bir fişte ödeme karesi
görmek, müşteriyi ikinci kez ödemeye çalıştırır.

**Sıra rastgele değil:** ödeme QR'ı takip QR'ının üstünde. Kapıda ödemeli
müşteri fişi eline aldığında yapması gereken ilk iş ödemek; takip ise
sonrasında lazım oluyor.

`FRONTEND_URL` tanımlı değilse `track_url` da `pay_url` da `null` döner ve
fiş eski hâliyle, QR'sız basılır. Site adresi olmadan üretilecek bağlantı
API köküne çıkardı — orası artık ana domaine 308 veriyor (I-07), yani QR
müşteriyi ana sayfaya atardı. Env tanımı: `docs/08-kurulum-deploy.md`.

### 5.4 Kuyruk

**Zorunlu davranış:**
- Her yazdırma işi önce SQLite'a yazılır (`print_queue` tablosu: `id`, `order_id`, `type`, `revision`, `payload`, `attempts`, `created_at`, `printed_at`).
- İş kimliği `(order_id, type, revision)` üçlüsüdür → **idempotent**, aynı fişin aynı sürümü iki kez basılmaz. `revision` sütunu K-12 ile geldi: düzenlenen sipariş yeni bir sürüm doğurur ve o sürüm basılmalıdır (bkz. aşağıdaki K-17 kuralı).
- Basım başarısızsa: `attempts++`, geri çekilmeli tekrar (2s, 5s, 15s, 60s...), kuyrukta kalır.
- Yazıcı yoksa/kağıt bittiyse durum çubuğunda kalıcı uyarı + kuyruk sayacı.
- Uygulama yeniden başlarsa kuyruk diskten okunur ve devam eder.
- Başarılı basımdan sonra `POST /api/kitchen/print-jobs/{order_id}/ack` gönderilir (başarısız olursa sessizce yut).
- Ayarlarda **"Yeniden bas"** butonu: seçili siparişin fişini elle tekrar basar.

#### ESKİ FİŞ ASLA BASILMAZ — K-17 (12.08.2026)

Sipariş düzenlenince (K-12) `revision_no` artıyor ve mutfak fişi yeniden
kuyruğa giriyor. Kuyrukta o siparişin **eski sürümü hâlâ basılmayı bekliyor**
olabiliyordu: yazıcı meşgulse, kâğıt bittiyse ya da kasa yeniden başladıysa
mutfak önce eski fişi, sonra yenisini alıyordu. İki fiş arasındaki farkı
kimse okumuyor — üstteki kâğıt neyse o hazırlanıyor. Sahada bunun anlamı
iptal edilmiş bir satırın yine de pişmesi.

Kural: **bir iş kuyruğa girdiği anda, aynı siparişin aynı türdeki daha eski
ve HENÜZ BASILMAMIŞ işleri düşürülür** (`PrintQueue.dropSuperseded`).

Üç sınırı bilerek koyduk:

* **Basılmış iş silinmez** (`printed_at IS NULL` şartı). O satır hem denetim
  kaydı hem de sunucuya `ack` gönderilip gönderilmediğinin tek izi.
* **Yalnızca daha eski sürümler** (`revision < keepRevision`). Parametre
  korunacak sürümdür, silinecek olan değil — eşitlik dâhil edilseydi işin
  kendisi de silinirdi.
* **Tür bazında** (`type` şartı). Müşteri fişi düzenlemede yeniden
  tetiklenmiyor; mutfak fişi yenilendi diye bekleyen müşteri fişini
  düşürmek, o fişi tamamen kaybettirirdi.

**Sıra önemli: önce ekle, sonra düşür.** Tersi olsaydı, silme ile ekleme
arasında çöken bir kasa o sipariş için kuyrukta **sıfır** iş bırakırdı —
mutfak hiç fiş görmezdi. Bu sırayla en kötü ihtimalde fazladan bir eski fiş
basılır; sessizce kaybolan fişten iyidir.

### 5.5 Tetikler

**Sipariş başına tam olarak iki fiş çıkar** (karar 05.08.2026, K-20 ile
teslimat tipinden bağımsız hâle geldi):

| Olay | Fiş |
|---|---|
| Mutfak siparişi **onayladı** (`onaylandi`) | Mutfak fişi (otomatik) |
| Durum **`hazir`** yapıldı | Müşteri fişi (otomatik) — kurye bilgileri içinde |

> **KURYE FİŞİ OTOMATİK BASILMAZ (K-20, 14.08.2026).** K-14'te üçüncü tip
> olarak eklenmişti ve `hazir`da adrese gönderim siparişlerinde basılıyordu;
> yani adrese gönderim başına **üç** kâğıt, iki kez düzenlenmiş siparişte
> **yedi** kâğıt çıkıyordu. Tezgâhta aynı siparişin birkaç kâğıdı birikiyor
> ve hangisinin güncel olduğu kâğıda bakarak anlaşılmıyordu.
>
> Kuryenin üç sorusunun cevabı (kime, nereye, ne kadar tahsil edilecek)
> müşteri fişine taşındı. Kâğıt kapıda kuryenin elinde, sonra müşteride
> kalıyor. `kurye` tipi sözleşmede ve kuyrukta duruyor — yalnız **elle
> yeniden bastırma** yolu olarak.

> **`yeni` durumunda fiş BASILMAZ.** Sipariş henüz kabul edilmemiştir ve
> müşteri iptal edebilir (`docs/03` §4 — iptal `yeni` ve `onaylandi`
> durumlarında serbest). Önceki davranış siparişi listede görür görmez
> basıyordu; iptal edilen her sipariş çöpe giden bir fiş demekti.

Her iki eşik de "**o durum ya da ötesi**" diye okunur. Sipariş `hazir`
iken uygulama kapanıp `yolda` iken açılırsa fiş hiç basılmamış olabilir;
tetiği kaçırmaktansa fazladan çağırmak yeğdir — kuyruktaki
`UNIQUE(order_id, type, revision)` ikinci fişi zaten engelliyor.

`teslim_edildi` de "hazır ötesi" sayılır: gel-al siparişi `hazir`dan
doğrudan oraya geçer ve arada bir yayın kaçarsa müşteri fişi hiç
basılmazdı.

#### Revizyon tetiği ve birleştirme penceresi — K-20 (14.08.2026)

Yukarıdaki iki satır **düzenlenmemiş** sipariş içindir. Sipariş
düzenlenince (K-12) `revision_no` artıyor ve daha önce basılmış fişlerin
güncellenmesi gerekiyor.

| Olay | Fiş |
|---|---|
| Revizyon arttı, o tip **daha önce basıldı** | Aynı fiş, **güncel** hâliyle, bir kez |
| Revizyon arttı, o tip **henüz basılmadı** | Hiçbir şey — kendi eşiğinde zaten güncel çıkacak |

**Düzenlemelerin çoğu `hazir` öncesi geliyor** ve o anda müşteri fişi henüz
basılmamış oluyor; bu yüzden pratikte fazladan kâğıt üretmiyorlar.

**BEKLETME PENCERESİ.** Revizyon işi hemen kuyruğa girmiyor; **20 saniye**
sessizlik bekleniyor. Personel müşteriyle telefonda konuşurken birkaç kez
kaydediyor ve her kayıt ayrı bir kâğıt demekti. Pencere dolmadan yeni bir
revizyon gelirse sayaç sıfırlanıyor ve **yalnız sonuncusu** basılıyor; ara
sürümler hiç kâğıda çıkmıyor.

Üst sınır **60 saniye**: düzenlemeye devam eden bir personel yüzünden
mutfak asıl siparişi pişirmeye devam etmesin diye, sessizlik hiç gelmese
bile bu süre dolunca güncel fiş çıkıyor.

> **İlk basım ASLA beklemez.** Mutfak yemeğe başlamak için kâğıdı hemen
> görmeli; bekletme yalnız *yeniden* basımlara uygulanıyor.

**Pencere `PrintTriggers` içinde ve zamanlayıcısız.** `PollingOrderSource`
zaten ~5 saniyede bir yayın yapıyor; bekleyen iş bir sonraki yoklamada
salınıyor. İki sonucu var: testler sahte saatle belirlenimci koşuyor, ve
bekletme sırasında çöken bir kasa yeniden açıldığında **hemen** basıyor
(hafıza boş → eşikler ateşlenir). Hata yönü "daha erken kâğıt", asla "hiç
kâğıt yok".

`PrintService`'te tutulsaydı iş pencere boyunca yalnız RAM'de dururdu ve
§5.4'ün ilk maddesi ("her yazdırma işi önce SQLite'a yazılır") çiğnenirdi.

#### Sesli uyarılar (05.08.2026)

İki ayrı alarm var ve **sesleri farklıdır** — aynı sesi kullansaydık
personel hangisinin çaldığını ayırt edemez, bağlantı uyarısını yeni
sipariş sanıp ekrana koşar ve orada bir şey bulamazdı.

| Uyarı | Ses | Davranış |
|---|---|---|
| **Yeni sipariş** | `yeni_siparis.wav` (yükselen çan) | Sipariş **onaylanana kadar** kesintisiz döngü |
| **Bağlantı yok** | `baglanti_yok.wav` (alçalan iki ton) | **45 saniyede bir** tek uyarı, **SUSTURULAMAZ** |

> **Neden biri kesintisiz, diğeri aralıklı.** Yeni sipariş alarmını
> personel bir tuşla çözebilir: onaylar, susar. Bağlantı kopmasını
> çözemez. Ağ gelene kadar kesintisiz ses çalmak, yapabilecekleri bir şey
> olmadığı hâlde onları cezalandırmaktır ve sonu hoparlörün fişini
> çekmektir — yani her iki alarmın da kaybedilmesi.

Bağlantı uyarısı **kopma anında hemen** çalar, aralık kadar beklemez:
kopmayı 45 saniye sonra duyurmak, kopmanın kendisi kadar zararlı.

> **BAĞLANTI UYARISI SUSTURULAMAZ** (karar 05.08.2026). Yeni sipariş
> alarmının "sustur" düğmesi var çünkü personel siparişi görüp
> onaylayabilir — sorunu çözer. Bağlantı kopmasında susturmak, tek uyarıyı
> kapatıp mutfağı kör bırakmaktır ve kopukluk saatlerce sürebilir. Sesi
> durduran tek şey bağlantının geri gelmesidir.
>
> Ayarlar ekranındaki **genel ses şalteri de bu uyarıyı kapatmaz**. Yeni
> sipariş sesi kapatılabilir; personel ekrana bakıyorsa siparişi zaten
> görür. Bağlantı kopması öyle değil: ekran son bilinen listeyi gösterir
> ve **doğru görünür**, yeni sipariş hiç gelmez.

`connecting` durumu **kopuk sayılmaz**: ilk açılışta ve her yeniden
denemede kısa süre bundan geçiliyor, uyarı çalsaydı her açılış bir
alarmla başlardı. `revoked` de sayılmaz — o bir ağ sorunu değil, yönetici
kararı ve uygulama zaten eşleme ekranına dönüyor.

> Ses **bir kez çalınır** (`AlarmPlayer.playOnce`), döngü sabit bir
> gecikmeyle kesilmez. "2 saniye sonra durdur" yazmak parçanın uzunluğunu
> koda gömmek olurdu ve testlerde asılı zamanlayıcı bırakıyordu.

#### Sağlık göstergesi (05.08.2026)

Ekranda yazıcı, sunucu bağlantısı, fiş kuyruğu, bugünkü sipariş sayısı ve
canlı saat bir arada duruyor. Kasa aynı bilgiyi dakikada bir sunucuya da
gönderiyor (`POST /api/kitchen/health`), böylece admin panelden hangi
kasanın ne durumda olduğu görülebiliyor.

İki hata sahada bulundu ve ikisinin de gerileme testi var:

> **`FileStat` KARAKTER AYGITINI GÖRMÜYOR.** Yazıcı yoklaması
> `FileStat.stat().type == notFound` bakıyordu. Dart'ın
> `FileSystemEntityType` listesinde karakter aygıtı **yok**;
> `/dev/thermal0` için çalışan bir yazıcıda bile `notFound` dönüyor.
> Sonuç: fişler basılırken ekranda "Yazıcı yok" yazıyordu.
> `File.exists()` doğru cevabı veriyor — türü değil varlığı soruyor.

> **İLK BİLDİRİM AKIŞ ÖNBELLEĞİNİ OKUYORDU.** Sağlık toplayıcısı
> `printerStatusProvider` akışının önbelleğe alınmış değerini okuyordu;
> ilk bildirim açılışta, akış daha hiçbir şey yaymadan gidiyor ve
> `null == ready` yanlış çıkıyordu. Her açılışta bir dakika boyunca
> "yazıcı arızalı" bildiriliyordu. Toplayıcı artık asenkron ve yazıcıyı
> doğrudan yokluyor.

Ayrıca sunucu tarafında: **Laravel'in `boolean` doğrulama kuralı `"true"`
dizgesini reddediyor** (yalnızca `1/0/"1"/"0"` kabul eder). Sorgu
dizesinde boolean ancak metin olabilir; KDS'in artımlı yoklaması
(`?since=…&include_completed=true`) her çağrıda 422 alıyordu, ekran tam
listeye düşüp geri geliyor ve bağlantı göstergesi sürekli yanıp
sönüyordu. `since` ve `include_completed` ayrı ayrı sınanıyordu, **ikisi
birlikte hiç sınanmamıştı**.

#### Fişler arası soluklanma payı (05.08.2026)

İki fiş arasında **1,2 saniye** beklenir — yalnızca sırada başka iş varsa.

> **SAHADA YAŞANDI.** Kuyrukta 28 iş birikmişti ve işçi bunları arka
> arkaya, yazıcı baytları kabul ettiği hızda gönderdi. Kesici hâlâ
> hareket ederken bir sonraki fişin baytları akmaya başlıyor; ucuz termal
> yazıcılarda bu takılma ve bozuk çıktı demek. Operatörün tarifi:
> *"açtım tak tak tak yazdırdı."*

Süre ölçüyle değil gözlemle seçildi: fişin kesilip düşmesi bir saniyenin
biraz altında sürüyor. Daha kısası kesiciyi yakalar, daha uzunu yoğun
saatte mutfağı bekletir.

Tek fiş basılırken bekleme **eklenmez** — sıradaki iş yokken beklemek
yalnızca mutfağı geciktirirdi. İkisinin de testi var.

#### Açılış test fişi (05.08.2026)

Uygulama **her açılışta** bir test fişi basar. Amaç yazıcının çalıştığını
kâğıt üzerinde göstermek: kâğıdın bittiğini, kapağın açık kaldığını ya da
USB'nin çıktığını ilk siparişte öğrenmek geçtir — o sipariş basılmadan
mutfağa düşer ve kimse fark etmez.

Fiş kilit ekranından **önce** basılır; personel parolayı girerken fiş
çıkmış olur ve ayrıca bir işlem yapması gerekmez.

> **ÇÖKME DÖNGÜSÜ KORUMASI.** `mutfakapp.service` `Restart=always` ve
> `RestartSec=5` ile koşuyor. Uygulama açılışta çökerse servis onu her
> beş saniyede yeniden başlatır; korumasız her denemede bir fiş basar ve
> rulo dakikalar içinde biter. Bu yüzden son açılış fişinin zamanı
> saklanıyor ve **3 dakika** içindeki tekrarlar atlanıyor. Süre kasten
> kısa: gerçek bir yeniden başlatma (güncelleme, elektrik, personelin
> kapatıp açması) fişi görmeli.

Damga fiş **basılmadan önce** yazılır. Sonraya bırakılsaydı, yazma
sırasında çöken bir uygulama damgayı hiç yazamaz ve yeniden başlayıp
tekrar basardı — korumanın engellemesi gereken döngünün ta kendisi.

İşlev hiçbir hatayı yukarı atmaz (`Object` yakalanır, `Exception` değil):
mutfak, yazıcı arızalı ya da bir depo erişilemez diye sipariş göremez
hâle gelemez.

## 6. Kiosk davranışı

**Ubuntu ayarları** (`infra/kasa/setup.sh` bunları yapar):
- Otomatik login: `/etc/gdm3/custom.conf` → `AutomaticLoginEnable=true`
- Ekran uykusu ve kilit kapalı: `gsettings set org.gnome.desktop.session idle-delay 0`, `org.gnome.desktop.screensaver lock-enabled false`
- Güç: kapanma/askıya alma devre dışı
- Otomatik güncelleme yeniden başlatması kapalı

**systemd user servisi** (`infra/kasa/mutfakapp.service`):
```ini
[Unit]
Description=Mutfak KDS
After=graphical-session.target

[Service]
ExecStart=/opt/mutfakapp/mutfakapp
Restart=always
RestartSec=5
Environment=DISPLAY=:0

[Install]
WantedBy=default.target
```

**Uygulama davranışı:** açılışta tam ekran (`window_manager` ile fullscreen
+ always on top), `Esc` ile çıkılmaz, pencere kapatma düğmesi devre dışı
(`setPreventClose`).

**Pencere denetimleri** (durum çubuğunun sağında, 05.08.2026'da eklendi):

| Düğme | Ne yapar |
|---|---|
| **Küçült** | Pencereyi görev çubuğuna indirir |
| **Pencere / Tam ekran** | Tam ekran ↔ 1280×800 pencere |

> `alwaysOnTop`, tam ekranla **birlikte** açılıp kapanır. Küçültmeden önce
> de kapatılır: kapatılmazsa pencere küçülür ve hemen geri gelir, düğme
> çalışmıyor gibi görünür. Pencere modunda üstte kalan bir KDS, altındaki
> ayar penceresini kullanılamaz hâle getirirdi.

Gerekçe: kasa tek amaçlı bir makine ama arada masaüstüne inmek gerekiyor —
yazıcı ayarı, ağ, güncelleme. Bunun tek yolu `systemd` servisini durdurmak
olmamalı.

## 7. İlk kurulum akışı (eşleme)

1. Uygulama ilk açılışta "Sunucu adresi" + "Eşleme kodu" ekranı gösterir.
2. Yönetici admin panelden cihaz ekler, 12 karakterlik kod alır.
3. Kod girilir → `POST /api/kitchen/pair` → token alınır, `shared_preferences`'a yazılır.
4. Sonraki açılışlarda doğrudan sipariş ekranı gelir.
5. Token iptal edilirse (`403 DEVICE_REVOKED`) uygulama eşleme ekranına döner.

Kod üretme (sunucuda):

```bash
A=$(docker ps -qf name=^app- | head -1)
docker exec -u www-data -e HOME=/tmp "$A" php artisan veykemtu:kds --new=MSI-Mutfak-Kasasi
```

Kod **10 dakika** geçerlidir; kasanın başında değilken üretmeyin.

> **KAYITLI ADRES DERLEMEYİ EZER.** `kitchen_base_url` bir kez
> `shared_preferences`'a yazıldıktan sonra `--dart-define` ile verilen
> adres **kullanılmaz**. Kasa daha önce mock ya da staging'e bağlandıysa,
> üretim adresiyle yeniden derlemek onu üretime taşımaz — sabah sipariş
> gelmez ve sebebi görünmez. Ayarlar ekranından (K-08) değiştirin ya da
> `~/.local/share/*/shared_preferences.json` dosyasını silin.
>
> 05.08.2026'da MSI kasada bu dosyanın **olmadığı** doğrulandı; ilk
> açılışta derlemedeki üretim adresi kullanılacak.

## 7.5 Açılış kilidi (05.08.2026)

Uygulama açıldığında **bir kez** parola sorar: *"Şifreyi giriniz"*. Doğru
parola girilince KDS açılır ve **bir daha sorulmaz** — ayarlar, fiş
yeniden basma, eşleme sıfırlama hiçbiri parola istemez.

> **Neden her işlemde değil:** elleri dolu bir mutfak personeline her
> işlemde parola girdirmek, parolanın duvara yazılmasıyla sonuçlanır.
> Kilidin amacı yoldan geçenin ekrana dokunup sipariş durumu
> değiştirmesini engellemek; asıl koruma kasanın kilitli mutfakta
> durmasıdır.

Parola **sunucuya sorulmaz**: internet yokken de açılmalı, mutfak sabah
bağlantı bekleyemez. Sunucu tarafındaki yetki zaten cihaz token'ıdır.

**Parola BİR KEZ girilir** (karar 05.08.2026). Girildikten sonra kalıcı
olarak hatırlanır; yeniden başlatmada tekrar sorulmaz. Saklanan şey parola
değil özetidir — parola değiştirildiğinde kayıt eşleşmez ve kasa yeniden
sorar.

> **Kilit ekranı ağacın ÜSTÜNDE durur, yerine geçmez.** Eskiden kilitliyken
> sipariş kaynağı, yazdırma tetikleri ve alarmlar hiç kurulmuyordu: kasa
> yeniden başladığında parola girilene kadar **sipariş gelmiyordu** ve
> bağlantı alarmı da çalmıyordu, çünkü yoklama hiç başlamamıştı. Servis
> çökmede kendini geri getiriyor (`Restart=always`) ve bunu vardiya
> ortasında kimse fark etmez.
>
> Artık her şey arkada çalışır: siparişler düşer, fiş basılır, alarm çalar.
> Kilit yalnızca ekrana dokunulmasını engeller.

> **Kaynakta düz metin parola YOKTUR** — depo herkese açık ve gizli-tarama
> botları bulurdu. `unlock_password.dart` içinde yalnızca tuzlanmış
> SHA-256 özeti durur. Bunun gerçek bir kriptografik koruma olmadığını
> biliyoruz; parolayı bilen biri özeti saniyede doğrular. Amaç parolanın
> aranabilir bir dizge olarak repoda durmaması.

Parola değiştirme:

```bash
python3 -c "import hashlib;print(hashlib.sha256(('bld-mutfak-kasasi-v1'+'YENİ').encode()).hexdigest())"
# çıktıyı mutfakapp/lib/src/lock/unlock_password.dart içindeki
# unlockPasswordDigest sabitine yazın, yeniden derleyin
```

## 7.9 Kurulum ve simge (05.08.2026)

`infra/kasa/derle.sh` derlemeyi yapar, `~/.local/opt/mutfakapp` altına
kurar, simgeyi ve masaüstü girişini yerleştirir, servisi başlatır.

Simge `mutfakapp/assets/icons/bld_*.png` (8 boyut, 16–512). Marka
turuncusu degradesi üzerinde beyaz servis kapağı — catering'in evrensel
işareti ve 16 pikselde bile okunur.

> **İkon adı iki yerde AYNI olmalı:** `.desktop` girişindeki `Icon=` ve
> GTK'daki `gtk_window_set_icon_name`. Ayrışırlarsa görev çubuğunda genel
> bir dişli görünür. İkisi de `bld-mutfakapp`.

`SingleMainWindow=true`: iki KDS penceresi aynı yazıcıya yazar ve fişler
karışır.

## 8. Ayarlar ekranı

### Ayarların tek kaynağı SUNUCUDUR (05.08.2026)

Dokuz ayarın tamamı admin panelden yönetilir ve sağlık bildiriminin
yanıtıyla kasaya iner: ses, yoklama aralığı, uyarı eşiği, geciken eşiği,
yazıcı yolu, kod sayfası, sağlık sıklığı, bağlantı uyarısı aralığı ve
alarmın susturulabilirliği.

> **`null` = "yönetici dokunmadı"**, "kapalı" değil. O alanda kasa kendi
> derleme varsayılanını korur. `null`'ı "varsayılana dön" diye yorumlamak,
> yönetici tek bir ayarı değiştirdiğinde diğer sekizini sıfırlardı.

Sınırlar **iki yerde** uygulanır — sunucuda ve kasada. Sunucuya güvenip
kasada atlamak, elle veritabanı düzenlemesinin ya da eski bir sunucu
sürümünün kasayı bozmasına izin vermek olurdu.

### Komutlar

Admin panel kasaya tek seferlik komut gönderir; sağlık yanıtıyla iner,
sonuç bir sonraki bildirimle döner.

| Komut | Ne yapar |
|---|---|
| `test_receipt` | Test fişi basar |
| `reprint` | Bir siparişin fişini yeniden basar |
| `clear_failed` | Basılamamış işleri kuyruktan düşürür |
| `silence_alarm` | Çalan yeni sipariş alarmını susturur |
| `restart` | Uygulamayı yeniden başlatır (systemd geri getirir) |

> **Ayar değil komut olmaları şart.** Ayar "şu andan itibaren böyle olsun"
> der ve kalıcıdır; komut "şunu bir kez yap" der ve tüketilir. "Test fişi
> bas" bir ayar olsaydı her yoklamada kâğıt harcardı.

Komutlar **sırayla** çalışır — "kuyruğu temizle" ile "fişi yeniden bas"
aynı anda koşarsa hangisinin kazandığı belirsiz olur. Biri patlarsa
diğerleri yine çalışır. Bilinmeyen komut sessizce yutulmaz, gerekçeyle
başarısız döner.

Sonucu gelmeyen komut **10 dakika sonra yeniden gönderilir**: kasa komutu
alıp çökmüş olabilir ve komutun hiç çalışmaması sessiz bir başarısızlıktır.

**PIN KALDIRILDI (05.08.2026).** Önceki plan ayarları ayrı bir PIN
arkasına almaktı; açılış kilidi geldiği için ikinci bir parola katmanı
yalnızca sürtünme üretiyordu. Ayarlar doğrudan açılır.

- Sunucu adresi
- Yazıcı cihaz yolu + **test fişi bas** butonu
- Ses açık/kapalı, ses seviyesi
- Polling aralığı (varsayılan 5 sn)
- Kuyruk görüntüleme + elle yeniden basma
- Cihaz eşlemesini sıfırla
- Sürüm bilgisi + güncelleme kontrolü

## 9. Güncelleme

`GET /api/app-version?app_id=mutfakapp` ile kontrol. Yeni sürüm varsa durum çubuğunda bildirim. Kurulum: `.deb` indirilir, kullanıcı onayıyla `pkexec dpkg -i` ile kurulur, servis yeniden başlar. Sürüm `min_supported` altındaysa uygulama engelleyici ekran gösterir.

## 10. Testler

- `OrderStatusTransition` istemci tarafı doğrulaması (unit)
- ESC/POS byte üretimi golden test — iki fiş tipi (`mutfak`, `musteri`) × iki teslimat tipi (`delivery`, `pickup`) için beklenen byte dizisi `test/golden/` altında sabit dosyalarda
- PC857 karakter çevirisi testi (tüm Türkçe karakterler)
- Kuyruk davranışı: yazıcı yokken iş birikir, sahte yazıcı gelince sırayla basılır, idempotentlik korunur
- Polling kaynağı: ağ hatası → geri çekilme → kurtarma senaryosu

---

## 11. Ses ve hoparlör — K-09 (11.08.2026)

### SAHA HATASI: `pw-play -q <dosya>` — alarm hiç çalmadı

Mutfaktan gelen "sipariş geliyor ama ses çıkmıyor" şikâyetinin sebebi tek
bir argümandı:

```
$ pw-play -q /tmp/bld_yeni_siparis.wav
error: filename or - argument missing
exit=1
```

`aplay` için `-q` "sessiz kip" demek. `pw-play` için `-q` = `--quality`
ve **bir değer bekliyor**; dosya yolunu kendi değeri sanıp yutuyor,
geriye oynatılacak dosya kalmıyor. Ubuntu 24.04 PipeWire ile geliyor,
`pw-play` tercih listesinde ilk sırada — yani kasada alarm **hiç
çalmadı**.

Hatanın günlerce yaşamasının sebebi, çalmamasının **görünmemesiydi**:
eski kod yalnız istisna yakalıyordu, süreç başlayıp hata koduyla
çıktığında istisna atılmıyor, `isMuted` `false` kalıyordu. Arayüz "ses
açık" gösterirken hoparlör susuyor, döngü de sıkı biçimde yeni süreç
açmaya devam ediyordu.

**Alınan önlemler:**

* argümanlar `AudioPlayerCommand` içinde ve **testli** — `pw-play`'in
  `-q` almadığı bir regresyon testiyle sabitlendi,
* **çıkış kodu denetleniyor**: süreç başlamış olması sesin çıktığı
  anlamına gelmiyor,
* sessizliğin **sebebi** taşınıyor (`AlarmPlayer.muteReason`) ve uyarı
  şeridi ile ayarlardaki "Ses tanılama" bloğunda yazıyor,
* ardışık hatada döngü **geri çekiliyor** (sıkı döngü yok),
* ses dosyaları `/tmp` yerine uygulama destek klasörüne çıkarılıyor —
  systemd `PrivateTmp` ya da dolu `/tmp` sessizce çalmamaya yol açıyordu.

### Hoparlör denetimi

Uygulama seviyesi (`--volume`) yalnız kendi akışını kısıyor. Hoparlörün
kendisi kısıksa ya da yanlış çıkışa (HDMI monitör hoparlörü) yönlenmişse
hiçbir şey duyulmuyor ve uygulama bunu bilemiyor. Ayarlar ekranı artık:

* uygulama ses seviyesi (0–100, ±5 düğmeleriyle — kaydırıcı yok,
  `docs/05` §8'deki gerekçe),
* **sistem** hoparlör seviyesi (`wpctl` / `amixer`, sessize alınmışsa
  aynı çağrıda açılıyor),
* çıkış cihazı seçimi (`pactl list short sinks`, yoksa `wpctl status`),
* "Ses tanılama": bulunan ikili, ses klasörü, anons aracı, son hata.

### Olay bazlı sesler

Tek bir "bip" hangi olayın olduğunu söylemiyor; personel yeni sipariş
sanıp ekrana koşuyor, bir şey bulamıyor ve zamanla sesi ciddiye almayı
bırakıyor. Altı olay, altı ses — her biri **farklı bir boyutta** ayrışıyor
(perde değil; ritim, tını ve yön de):

| Olay | Ses | Karakter |
|---|---|---|
| Yeni sipariş | `yeni_siparis.wav` | ısrarcı, tekrar eden |
| Bağlantı koptu | `baglanti_yok.wav` | alçalan iki ton, aralıklı, **susturulamaz** |
| Geciken sipariş | `gecikme.wav` | sert, yükselen üç bip |
| Yazıcı sorunu | `yazici_hatasi.wav` | alçak, titreşimli iki vuruş |
| Abonelik | `abonelik.wav` | yumuşak çan, majör üçlü |
| BBD Store (K-16) | `bbd_siparis.wav` | dört notalı motif |

Sesler `tool/ses_uret.py` ile **üretiliyor**, indirilmiyor: telifsiz,
yeniden üretilebilir ve ayırt edilebilirlikleri gerekçeli.

### Sesli anons (TTS)

`spd-say` (yoksa `espeak-ng`) alt süreci — yeni Dart bağımlılığı yok,
`ProcessAlarmPlayer` kalıbının aynısı. "12 numaralı yeni sipariş, 4 ürün".
Açılışta bekleyen siparişler **okunmuyor**: elektrik kesintisinden sonra
12 siparişi arka arkaya okumak anons değil gürültü.

### Sunucudan yönetim

`KitchenSettings` 9 alandan 16'ya çıktı. Aynı turda, **hâlihazırda
sözleşmede olup hiçbir yere bağlanmamış** dört alan da bağlandı:
`printer_code_page`, `health_seconds`, `connection_alarm_seconds`,
`alarm_silenceable`. Yönetici panelden değiştiriyor, kasada hiçbir şey
olmuyordu.

`audio_sink` alanında **boş dize = varsayılan çıkışa dön**; `null` bu
alanda da "yönetici dokunmadı" demek ve seçimi geri almanın başka yolu
yok.

---

## 12. Dokunmatik monitör — K-10 (11.08.2026)

`KdsSettings.touchMode` kapalıyken bugünkü klavye öncelikli düzen **bit
bit** aynı kalıyor; regresyon riski sıfır. Açıkken:

* dokunma hedefleri büyüyor (tema düzeyinde — her widget'a bayrak
  geçirmek yerine tek yerden, gözden kaçan küçük hedef kalmasın diye),
* açılır menüler **alt sayfaya** dönüyor: `PopupMenuButton` küçük satırlar
  çiziyor ve menü parmağın altında kalıyor,
* **Türkçe ekran klavyesi** (`lib/src/input/onscreen_keyboard.dart`):
  kilit ekranı, arama, sebep metni ve şifre alanları. Kasada masaüstü
  ortamı yok, sistem klavyesi açılmıyor; harici klavye yoksa uygulama
  **hiç açılamıyordu** — kurtarılamaz bir kilitlenme,
* kartta kaydırma jestleri: sağa = ilerlet, sola/uzun bas = işlem sayfası.

### SIFIR KLAVYE / FARE KURALI (12.08.2026)

Dokunmatik kip açıkken kasada **klavye ve fare takılı olmayacak.**
Bu, "büyük düğme" meselesinden fazlası: kipin açık olması, o kasada
klavyeyle yapılabilen her işin dokunuşla da yapılabildiğinin **garantisi**.
İki somut şart:

**1. Her metin alanı kendi klavyesini getirir.** Ortak
`lib/src/input/keyboard_text_field.dart` — dokunmatikte alan salt okunur
oluyor ve dokununca tam ekran klavye penceresi açılıyor; klasik kipte
sıradan bir `TextField` olarak kalıyor.

Açık kalan alanlar kapatıldı: ayarlar ekranındaki iki metin alanı
(hiç klavyesi yoktu), satış kontrolündeki ürün araması, düzenleme
ekranındaki ürün araması.

Pencerenin İÇİNDEKİ alan da salt okunur: yazının tek kaynağı alttaki
tuşlar olmalı, yoksa imleç konumu iki yerden değişip karışıyor.
`onChanged` elle çağrılıyor — denetleyiciye programla yazmak alanın geri
çağrısını tetiklemiyor ve arama alanları buna bağlı.

**2. Her klavye kısayolunun dokunmatik karşılığı var.** Durum çubuğuna
**İşlemler** menüsü eklendi (`kds/widgets/actions_sheet.dart`).

Kapatılan üç açık: vardiya özeti (F3) hiçbir yerden dokunuşla
açılmıyordu; **satış kontrolü (F7) yalnız satış KAPALIYKEN çıkan kırmızı
şeritten açılıyordu — yani dokunmatik kasada satışı kapatmanın hiçbir
yolu yoktu, kapatmak için önce kapalı olması gerekiyordu**; abonelik
planı (F8) yalnız abonelik siparişi varken görünen şeritten açılıyordu.

Kısayollar kaldırılmadı: klavyeli bir kasada F7 hâlâ çalışıyor. Alt sayfa
onların yerine değil yanına eklendi.

**Teslimat saati seçicisi Material'in `showTimePicker`'ı DEĞİL**
(`_TimePrompt`): kadran ve küçük metin alanları yağlı elle çalışmıyor ve
yazma kipi donanım klavyesi istiyor. Kendi penceremiz `-1 sa / -5 dk /
+5 dk / +1 sa` düğmeleriyle çalışıyor. Dakika beşer adım ilerliyor —
mutfak "16:47"ye teslim sözü vermiyor.

**3. Klavye düzeninde rakam ve adres işaretleri var.** Türkçe düzende
yalnız harfler vardı: `https://api…`, `A1B2-C3D4` ve `/dev/thermal0`
**hiç yazılamıyordu.** Yani dokunmatik bir kasa eşleşemiyordu — kilit
ekranındaki eski kilitlenmenin aynısı. Rakam sırası ve `- _ / : @`
eklendi.

**4. Eşleme ekranındaki alanların klavye düğmesi ayara bakmıyor.** O
ekran ayarlardan **önce** geliyor (cihaz eşleşmeden pano açılmıyor, pano
açılmadan ayarlara girilemiyor) ve `touchMode` varsayılanı kapalı.
Ayara bağlansaydı dokunmatik kasa hiç eşleşemezdi. Alan salt okunur
yapılmadı: klavyeli kasada doğrudan yazmak hâlâ en hızlı yol.

Kural `test/touch_only_test.dart` ile sabitlendi.

### Ses tanılamada "yok" ile "denenmedi" ayrıldı

Araç gerçekten eksikken de "Henüz denenmedi" yazıyordu ve bu, eksik
aracı "birazdan bulunur" gibi okutuyordu. Artık araştırma bittiyse
**"bulunamadı"** yazıyor ve altında kurulum komutu duruyor
(`sudo apt install speech-dispatcher`) — seçilip kopyalanabilir. "Ses
çalınamıyor" bilgisi tek başına kimseyi harekete geçirmiyordu.

### GERİ ALMA — "geri alma yoktur" kuralı daraltıldı

§3 "geri alma yoktur" diyordu ve dokunmatik monitör gelene kadar
doğruydu: klavyeyle yanlış kartı ilerletmek zordu. Dokunmatikte kartlar
parmağın altında ve yanlışlıkla kaydırma gerçek.

Kural kaldırılmadı, **dar bir pencereye** çevrildi
(`OrderStatusTransition::UNDO_WINDOW_SECONDS = 120`):

* yalnız **tek adım** geri (`hazir` → `hazirlaniyor`),
* yalnız son durum değişikliğinden sonraki 120 saniye içinde,
* `yeni`ye dönüş **yok**: mutfak fişi `onaylandi`da basıldı ve basılı
  kâğıt geri alınamaz,
* terminal durumlardan (`teslim_edildi`, `iptal`) **yok**: iptal cari
  hesaba ters kayıt yazıyor, geri alması muhasebe düzeltmesi olur.

Kararı **sunucu** veriyor; şerit ekranda unutulursa istek `422` ile
reddediliyor ve personel uyarıyı görüyor.

**Şerit küçültüldü (12.08.2026).** İlk hâli tam genişlikte bir çubuktu ve
"Sipariş ilerletildi. Hazırlanıyor durumuna geri alınsın mı?" yazıyordu;
panonun alt kenarını, yani en alttaki kartların ilerletme düğmelerini
kapatıyordu. Dokunmatikte asıl sorun ikinciydi: geri alma bir metin
bağlantısıydı, parmakla ıskalanıyordu. Şimdi altta ortalanmış 460 px'lik
yüzer bir kutu var; içinde kısa bilgi ("Hazırlanıyor durumuna"), **52 px
yüksekliğinde GERİ AL düğmesi** ve 64 px'lik bir kapatma hedefi. Kapatma
düğmesi eklendi çünkü şeridi kaydırarak kapatmak dokunmatikte alttaki
kartı da kaydırıyordu. Şerit **5 saniyede** kendiliğinden kapanıyor (önce
10 idi): yanlış dokunuş ilk saniyede fark ediliyor, sonrası yalnızca panoyu
kapatıyor. Ölçüt `test/kds_screen_test.dart` içinde.

---

## 13. Satış kontrolü — K-11 (11.08.2026)

### KURAL DEĞİŞTİ: mutfak sipariş almayı durdurabiliyor

`docs/03` §3 "mutfak personeli tek tuşla cirosu kapatabilmemeli" diyordu.
Sahada kural **tersine işledi**: yazıcı bozulduğunda, malzeme bittiğinde
ya da ekip yetişemediğinde mutfak sipariş almaya devam ediyor, gelenleri
tek tek telefonla iptal ediyordu. Müşteri için "siparişim alındı, sonra
arandı ve iptal edildi", kapalı bir dükkândan **çok daha kötü**.

Şalter mutfaktan da çevriliyor ama **tek tuşla değil** — dört adım:

1. süre seçimi (30 dk / 1 sa / gün sonu / süresiz),
2. sebep seçimi (müşteriye gösteriliyor),
3. kasanın **açılış şifresi** (ayrı bir şifre yok — ikinci şifre, iki
   şifrenin de duvara yazılmasıyla sonuçlanırdı, §7.5'teki PIN kararının
   aynısı),
4. onay.

**Açmak da şifre istiyor:** yanlışlıkla açılan bir dükkân, yanlışlıkla
kapanan kadar zararlı (mutfak hazır değilken sipariş akmaya başlar).

Süreli durdurma var çünkü "kapattım, açmayı unuttum" en olası hata.
Sürenin dolması **tembel** değerlendiriliyor — cron yok; zamanlayıcıya
bağlansaydı kuyruk durduğunda dükkân kapalı kalırdı.

Kapalıyken panonun en üstünde kalıcı kırmızı şerit, sebep ve kalan süre
sayacıyla duruyor: kapalı bir günde pano boşalıyor ve boş pano "sakin
gün" gibi görünüyor.

### Ürün bazında "bugün tükendi"

`menus.menu_status` **kullanılmıyor**: o alan yöneticinin KALICI kararı
("artık satmıyoruz"), mutfağınki GÜNLÜK ("bugünlük bitti"). Aynı alanı
paylaşsalardı akşam tükenen ürünü sabah yöneticinin elle geri açması
gerekirdi ve bir sabah unutulduğunda ürün sessizce menüden düşerdi.

`veykemtu_menu_soldout.sold_out_on` bir **tarih**; gün dönümünde
kendiliğinden geçersizleşiyor. Temizleyecek cron yok, dolayısıyla cron
durduğunda ürünlerin kapalı kalması gibi bir arıza da yok.

**Abonelik muaftır.** Abonelik bir sözleşmedir; günlük stok kararı onu
iptal edemez. Bir günü atlamak için `veykemtu_subscription_exceptions`
kaydı girilir — ayrı ve bilinçli bir karardır.

---

## 14. Sipariş düzenleme ve iade — K-12/K-13/K-14 (11.08.2026)

### Akış

Mutfak personeli müşteriyle **telefonda konuşur**, anlaşır, sonra
değişikliği sisteme yazar. Onay beklenmez; onay zaten alınmıştır. Bu
yüzden uç bir "talep" değil, bir **kayıt** ucudur.

### Panoda telefon — gizlilik kuralı daraltıldı

`docs/03` §5 üç ayrı yerde "mutfak listesinde telefon GÖRÜNMEZ" diyordu
ve sipariş düzenleme gelene kadar doğruydu: mutfağın telefona ihtiyacı
yoktu. Artık personel müşteriyi **arayıp** anlaşmak zorunda ve numarayı
görmek için fiş basmak (ya da basılmış fişi aramak) saçma.

**Fiyat ve adres hâlâ gizli** — ADR-08 duruyor. Değişen tek şey telefon;
kural kaldırılmadı, daraltıldı.

### En riskli tek detay: `orders.updated_at`

KDS artımlı yoklaması `since` ile **`orders.updated_at`** üzerinden
çalışıyor. Yalnız `order_menus` değişip `orders` dokunulmasaydı,
düzenleme mutfak ekranına **hiç düşmezdi** — personel eski adedi
hazırlamaya devam ederdi. `OrderEditor` bu yüzden `save()` sonrası
ayrıca `touch()` çağırıyor ve testi zorunlu.

### İkinci düzenlemenin sessizce yutulması (önlendi)

Cari defterdeki `UNIQUE(source, reference_type, reference_id,
entry_type)` kısıtı **sipariş kimliğine** bağlansaydı, aynı siparişin
ikinci düzenlemesi `insertOrIgnore` tarafından yutulur ve müşteri fazla
borçlu kalırdı. Referans bu yüzden **revizyona** bağlı
(`reference_type = 'order_revision'`).

### `order_totals` iki katına çıkıyordu (önlendi)

`order_totals` tablosunda `(order_id, code)` tekilliği **yok** ve eski
`storeTotals()` yalnız `insert` yapıyordu. İkinci kez çağrılsa sipariş
iki "Ara Toplam" satırı taşır, admin panelde toplam iki katı görünürdü.
`LineResolver::rewriteTotals()` önce siliyor.

### İade

Gerçek sanal POS henüz seçilmedi (`docs/11` §10 açık madde). Sağlayıcı
bağımsız katman kuruldu: `RefundGateway` arayüzü + `RefundManager`.
Sürücü **ödeme yönteminden** türüyor, yapılandırmadan değil — bir
siparişin parası nasıl alındıysa öyle iade edilir:

| Ödeme | Sürücü | Davranış |
|---|---|---|
| `account` | `AccountRefund` | Para hareketi yok; cari defterde ters kayıt |
| `online` | `SimulatedRefund` (bugün) | Üretimde `POS_ALLOW_SIMULATION` olmadan `failed` |
| `cash` / diğer | `ManualRefund` | Kayıt `manual` kalır; insan tamamlar |

**Başarısız iade de kayıt açar.** Kaydetmemek onu görünmez kılardı:
müşteri parasını bekler, kimse bir şey bilmez.

**Ek tahsilat otomatik alınmaz.** Müşterinin kartından habersiz ek çekim
kabul edilemez; fark kurye fişine yazılır.

### Kurye fişi — üçüncü fiş tipiydi, K-20'de müşteri fişine katlandı

**11.08.2026'daki gerekçe:** kurye üç bilgiye ihtiyaç duyuyor ve hiçbiri tek
bir mevcut fişte birlikte yok — **kime** (ad + telefon), **nereye** (adres +
harita QR), **ne kadar tahsil edilecek**. Mutfak fişinde adres yok; müşteri
fişi ise müşteride kalıyor. Bu yüzden üçüncü bir tip açıldı.

**14.08.2026'da (K-20) o karar geri alındı.** Gerekçe hâlâ doğruydu ama
çözümü yanlıştı: üçüncü kâğıt, adrese gönderim başına toplamı **üçe**,
iki kez düzenlenmiş siparişte **yediye** çıkardı. Tezgâhta aynı siparişin
birkaç kâğıdı birikiyor ve hangisinin güncel olduğu kâğıda bakarak
anlaşılmıyordu — personelin şikâyeti tam olarak buydu.

Doğru çözüm ayrı bir kâğıt değil, **aynı kâğıdın doğru sıralanması**:
teslimat bloğu müşteri fişinin fiyat tablosunun üstüne alındı. Kurye kapıda
okuyor, kâğıt sonra müşteride kalıyor — zaten yemekle birlikte hareket eden
tek kâğıt o.

**"Müşteri fişi kuryenin elinde olmaz" itirazı neden geçersiz:** o fiş
zaten kuryeyle gidiyordu; K-14'ten önce de müşteriye kurye teslim ediyordu.
Değişen tek şey, kuryenin ihtiyaç duyduğu bilginin ayrı bir kâğıt yerine
aynı kâğıtta olması.

Bugünkü hâli:

* Teslimat bloğu (ad, telefon, adres, harita QR, sipariş notu) **yalnız
  `delivery` siparişte** basılır — gel-al'da kurye yok.
* Tahsilat satırı **çift boy**, değişiklik listesinin altında; ödenmiş
  siparişte ve gel-al'da hiç basılmaz (sıfırlık bir satır, sonraki fişte
  gerçek tutarı gözden kaçırtıyor).
* Sipariş düzenlendiyse fişin **en üstünde** çift boy `GÜNCEL FİŞ / REVİZE
  #N / ÖNCEKİ FİŞİ ATIN` bandı; `DEĞİŞİKLİKLER` listesi toplam ile tahsilat
  arasında. **Bant mutfak fişinde de var** — K-20'ye kadar yalnız kurye
  fişindeydi ve `docs/10` S9-13 bunu zaten şart koşuyordu.
* `kurye` tipi **silinmedi**: sözleşme additive-only ve kuyruktaki eski
  satırlar `wireName` ile ayrıştırılıyor; enum değeri kalksaydı eski bir
  kurye satırı mutfak fişi olarak yeniden basılırdı. Uç çalışmaya devam
  ediyor, yalnız otomatik tetiği ve KDS menüsündeki seçeneği kalktı.
* **Menüde iki seçenek kaldı** (mutfak, müşteri). Kurye fişini menüde
  bırakmak, personele "hangisini basayım" sorusunu geri getirirdi —
  birleştirmenin çözdüğü sorunun ta kendisi.

### Fiş tekilliği revizyon bazlı

Kuyruk tekilliği `(order_id, type)` idi; sipariş düzenlendiğinde revize
fiş `INSERT OR IGNORE` tarafından **sessizce yutuluyordu**. Artık
`(order_id, type, revision)`. SQLite `ALTER TABLE` ile tekilliği
değiştiremediği için tablo yeniden kuruluyor ve veri kopyalanıyor —
kuyrukta bekleyen fiş kaybolmuyor.

**Müşteri fişi yeniden basılmaz:** o fiş müşterinin eline geçti, ikinci
kopya yalnız kafa karıştırır. Mutfağın ve kuryenin elindeki kâğıt ise
güncel olmak zorunda.

### KDS düzenleme ekranı (12.08.2026)

Karttaki kalem ikonu → tam ekran düzenleme.

**SIRALAMA ÖNEMLİ:** ekranın en üstünde telefon ve "kaydetmeden ÖNCE
müşteriyi arayın" uyarısı duruyor. Tersine çevirmek, müşteriye haber
verilmeden değişmiş bir sipariş demek.

* Kalem satırında büyük `−` / adet / `+`; **adet sıfıra inince kalem
  kalkıyor** (eksiye basa basa sıfıra inen personelin beklentisi bu).
* Ürün ekleme: aranabilir alt sayfa, **fiyatsız** (ADR-08). Aynı ürün
  ikinci kez eklenirse adet artıyor, ikinci satır açılmıyor — iki satır
  fişte de iki satır olur ve mutfak aynı yemeği iki kez hazırlar.
* **Sebep zorunlu**, sabit listeden (müşteri talebi / malzeme yetmedi /
  personel hatası / diğer + metin). Herkesin kendi cümlesini yazdığı bir
  alan, "neden düzenleniyor" sorusunu cevaplanamaz kılar.
* **Değişiklik yokken kaydedilemiyor:** boş revizyon fişleri yeniden
  bastırır ve mutfakta kâğıt paradır.
* Onay penceresi **ne değiştiğini** gösteriyor; **tutar farkını değil**.
  Fiyatı istemci bilmiyor (ADR-08) ve sunucudan "ne kadar olurdu" diye
  sormak, kaydetmeden önce ikinci bir uç ve ikinci bir hesap demekti.
  Para sonucu kaydettikten sonra bildiriliyor.
* **Fark tutarı kaydetme mesajında görünüyor** (12.08.2026): "Revizyon #1
  kaydedildi — Müşteriye iade edilecek: 180,00 ₺". Personel bu
  değişikliği müşteriyle telefonda konuşarak giriyor; kapatmadan önce
  rakamı teyit edebilmeli. Gösterilen yalnızca **fark**, cari bakiye
  değil — ADR-08 duruyor. Fark sıfırsa satır hiç eklenmiyor: "0,00 ₺"
  yazmak personeli boşuna kasaya yollar.

**TEK BİLDİRİM, İKİ DEĞİL.** İlk sürüm önce "kaydedildi" sonra "iade
başlatılamadı" gösteriyordu; ikisi kuyruğa giriyor, personel ilkini görüp
gidiyor ve ikincisi kimseye ulaşmıyordu. Para uyarısı artık başarı
mesajının **yerine** geçiyor ve daha uzun duruyor. Testte yakalandı.

---

## 15. Abonelik üretim planı — K-15 (12.08.2026)

Önceki hâli tek bir banner ve salt-okunur bir pencereydi: kaç sipariş
olduğunu söylüyor, **ne pişeceğini** söylemiyordu. Mutfak sabah "40
abonelik var" bilgisiyle hiçbir şey yapamıyor; ihtiyacı olan "120
mercimek, 85 tavuk".

Ekran üç soruya **bu sırayla** cevap veriyor:

1. **Ne EKSİK?** Uyarılar en üstte. Alta konsaydı, listeyi okuyup işine
   dönen personel oraya hiç bakmazdı.
2. **Ne pişecek?** Ürün bazında toplam, büyük punto.
3. **Nereye, kaçta?** Teslimat çizelgesi + **durum ilerletme**. Panoya
   dönüp aynı siparişi orada bulmak zorunda kalmak, ekranı yalnız
   "bakılan" bir yer yapardı.

### En sinsi durum: üretim koşmamış

Sipariş yok ama olması gerekiyor. Mutfak "bugün abonelik yok" sanıp
hazırlık yapmıyor, oysa akşam 22:00'deki `veykemtu:abonelik-uret`
çalışmamış. `SubscriptionKitchenPlan` o günü çalışması beklenen abonelik
sayısını `Subscription::runsOnDate()` ile hesaplıyor ve sipariş yoksa
`not_generated` uyarısı üretiyor. Bu uyarı **kırmızı**; diğerleri (kapalı
gün, duraklatma, istisna) sarı — ikisi aynı renkte olsaydı kırmızının
anlamı kalmazdı.

### Üretim planı fişi

Mutfak akşam kapatırken yarının listesini **kâğıda** basıp tezgâha
asıyor. Ekrana bakmak için elini yıkayıp kasaya gitmek gerekir; kâğıt
tezgâhın üstünde durur.

* Kuyruğa **girmiyor**: sipariş kimliği yok ve `UNIQUE(order_id, type,
  revision)` kısıtına takılırdı; ikinci kez basılamazdı. Açılış test
  fişiyle aynı yol — `printDiagnostic`.
* Uyarılar **fişe de basılıyor** ve listeden önce: ekranda görünüp
  kâğıtta görünmezse, tezgâhtaki kâğıda bakan kişi eksik bilgiyle
  çalışır.
* Boş günde "ÜRETİM YOK" yazıyor — boş bir kâğıt "yazıcı bozuk mu"
  sorusunu doğurur.

---

## 16. BBD Store köprüsü — K-16 (12.08.2026)

### BBD Store nedir, ne değildir

**BBD Store bir KİTAP e-ticaret sitesidir**, catering değil. Ayrı bir
sunucuda, ayrı bir proje olarak yaşıyor.

**KÖPRÜNÜN TEK VARLIK SEBEBİ TERMAL YAZICIYI PAYLAŞMAK.** İşletme tek
mekânda ve tek 80 mm termal yazıcı var. BBD'de bir sipariş onaylandığında
buradaki kasa BBD'ye özel bir **ses** çalıyor ve aynı yazıcıdan bir
**paketleme fişi** basıyor. Başka hiçbir şey yok — geri bildirim yok,
durum senkronizasyonu yok, ortak veri yok.

Bu siparişler BLD'nin `orders` tablosuna **girmez**, panoda görünmez,
üretim listesine / vardiya istatistiğine / `orders_today` sayacına / cari
hesaba **karışmaz**.

**NEDEN `orders`'A YAZILMIYOR:** BBD kitap satıyor. Ürünleri BLD
menüsünde yok, fiyatları BLD fiyat listesinde değil, müşterisi BLD
müşterisi değil ve **iş akışı bile farklı** — biri pişiriliyor, diğeri
raftan alınıp kutulanıyor. Zorla `orders`'a sokmak ciro raporunu, üretim
listesini ve cari hesabı bir gecede yanlış yapardı.

### Fiş: mutfak fişi değil, paketleme fişi

Kâğıdı alan kişi yemek hazırlamıyor; raftan kitap toplayıp kutuluyor.
Mutfak fişinden **üç tasarım farkı** var, üçü de iş akışından:

| | Mutfak fişi | BBD paketleme fişi |
|---|---|---|
| Ürün adı | **Çift boy** — bir metreden okunuyor | **Normal**, satıra sarılıyor |
| Kimlik | yok | **Stok kodu / ISBN** — raftan bulmanın en hızlı yolu |
| Teslimat | kurye, adres + harita QR | **kargo firması + takip numarası** |

Ürün adının çift boy basılmaması bir ayrıntı değil, ölçülmüş bir sorun:
80 mm kâğıtta çift boy **24 sütun** demek ve `"Türkiye'nin Yakın Tarihi —
Cilt II"` üç satıra bölünür, fiş uzar ve okunmaz hâle gelir. Burada
**adet** çift boy, ad normal. Golden testi bunu bayt düzeyinde sabitliyor
(başlıktan önceki son boyut komutunun "kapat" olduğunu doğruluyor).

Diğer kurallar:

* Takip numarası **çift genişlik**: paketin üstündeki etiketle elle
  karşılaştırılıyor ve tek yanlış hane yanlış pakete gider.
* `pickup` ise **adres bloğu hiç basılmıyor** — basılan adres, paketin
  yanlışlıkla kargoya verilmesine yol açar.
* Kargo bilgisi yoksa boş bir "Kargo:" başlığı basılmıyor: eksik başlık,
  paketleyene bir şeyin kayıp olduğunu düşündürür.
* Satır bazında **fiyat yok** — BBD'nin fiyatlandırması bizim değil.
  Toplam tutar yalnız BBD gönderdiyse basılıyor; uydurulmuş ya da sıfır
  bir tutar kapıda ödemede yanlış tahsilata yol açar.

### MEVCUT BLD FİŞLERİ DEĞİŞMEDİ

Mutfak, müşteri ve kurye fişlerinin golden dosyaları **bayt bayt aynı**
kaldı (`git diff` boş). BBD şablonu ayrı bir fonksiyon
(`buildBbdReceipt`) ve ayrı veri tipleri kullanıyor; ortak bir tipe
zorlamak, iki sistemin fişini birbirine bağlar ve birinde yapılan
değişiklik diğerini bozardı.

### Kimlik: HMAC imzası, token değil

Arada paylaşılan tek şey bir sır (`BBD_WEBHOOK_SECRET`). Sabit bir Bearer
token, her istekte ağdan geçen ve loglara düşen bir parola demekti; HMAC
imzası sırrı hiç göndermez ve gövdenin de değişmediğini kanıtlar.

* İmza **ham gövde** üzerinde: JSON yeniden serileştirilirse boşluk ve
  anahtar sırası imzayı değiştirir ve iki taraf asla tutturamaz.
* `hash_equals` kullanılıyor, `===` değil: eşitlik karşılaştırması ilk
  farklı baytta duruyor ve süre farkından imza tahmin edilebiliyor.
* **Sır tanımsızsa uç kapalı** (401): boş sırla imza doğrulamak,
  herkesin geçebildiği bir kapı olurdu.
* Reddetme sebebi ayrıntılandırılmıyor ("sır yok" ile "imza yanlış"
  ayrımı saldırgana yapılandırma bilgisi verir).

### Kuyruk sunucuda, kasada değil

Yerel SQLite kuyruğunun tekilliği `(order_id, type, revision)` üçlüsüne
dayanıyor ve BBD fişinin BLD sipariş kimliği yok. Dördüncü bir
`ReceiptType` değeri eklemek gerekirdi; o enum veritabanı kısıtında,
tetikleyicilerde, ayarlar ekranında ve sözleşmede geçiyor — küçük bir iş
için geniş bir yüzey.

Sunucu zaten `printed_at IS NULL` ile kuyruk tutuyor:

* kasa **yalnız basım başarılıysa** ack gönderiyor,
* başarısızsa fiş kuyrukta kalıyor ve bir sonraki turda geri geliyor,
* yazıcı kapalıyken kasa yeniden başlasa bile fiş kaybolmuyor.

Yerel kuyruğun verdiği garantinin aynısı, fazladan şema olmadan.

### Ses ve fiş

* **Ses bir kez çalıyor, fiş başına değil:** beş fiş birden geldiğinde
  beş kez üst üste ses çalmak, mutfağı sesi kapatmaya iter.
* **Ses önce, fiş sonra:** basım saniyeler sürebiliyor ve personelin
  kâğıdı almak için yazıcıya gitmesi o sesle başlıyor.
* Fiş başlığı çift boy **"BBD STORE"** ve altında "BLD panosunda
  görünmez" satırı: kâğıdı BLD fişiyle karıştıran personel, panoda
  olmayan bir siparişi arar ve bulamaz.
* **Satır bazında fiyat basılmıyor** — BBD'nin fiyatlandırması bizim
  değil. Toplam tutar, BBD gönderdiyse, tek satır olarak basılıyor;
  göndermediyse hiç basılmıyor (uydurulmuş bir tutar yanlış tahsilat
  demek).
* Durum çubuğunda "BBD: n" çipi; hiç fiş gelmediyse çizilmiyor.
