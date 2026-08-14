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
[x] ayrı ayrı kurye fişi mutfak fişi istemiyorum. fişler işte revize 1 2 diye ayrı ayrı fiş
    çıkarmasın fazla fiş çıkıyor kafa karıştırıcı bunu düzeltelim
    → K-20. Kurye fişi müşteri fişine katlandı (sipariş başına 3 değil 2 kâğıt); revizyonda
      ayrı "REVİZE #N" kâğıdı yerine tek güncel fiş + 20 sn birleştirme penceresi.
      İki kez düzenlenmiş adrese gönderim: 7 kâğıt → 2. Ayrıca fişe teslim QR'ı eklendi ve
      takip QR'ının giriş duvarına çarpan hatası düzeltildi.
[x] kds ekranını yukarıdan yönetebilmek, sipariş revizeleri olsun her şey olsun, mutfak
    personelinin yapabildiğinin çok daha fazlasını yapabilmek. kds uygulamasını artık
    kilitliycez. ikisi senkron çalışmalı
    → K-21. İmzalı kontrol API'si (16 uç), 7 alanlı kilit politikası, Kontrol Merkezi'nde
      geçit + KDS Yönetimi paneli. Uzaktan yönetim altyapısı K-09'dan beri vardı; eksik
      olan makine okunur yönetim ucuydu.
[x] revize edilse dahi zaten aşamalı çıkıyor, revize onaylanır onaylanmaz mutfak fişi çıkar,
    kuryeye de en en en son hazıra basınca çıkar — şu an arka arkaya fiş basılıyor
    → K-21. Eşikler doğruydu; iki eşik aynı turda aşılabildiği için kâğıtlar peş peşe
      çıkıyordu. Kural: turda sipariş başına tek fiş, mutfak önce, ertelenen bir sonraki
      turda ve sipariş panodan düşse bile çıkar.

# Web-Admin
[x] api subdomaininde farklı bir bld sitesi yatıyor bu site kaldırılacak. orijinal anadomain olacak
[x] kullanıcı ana domaine ilk girdiği anda sisteme giriş yapabilşecek ve hızlıca sipariş verebileek
[x] menülere tıklayınca kaybolmuyıor kalıyor üst header bar gömzden geçirilecek
[x] abonelik-abonelik takibi gibi işlemler işte cari hesapta istenen ya da total tutara göre ödeme simülasyonu olacak.
[x] admin panelde çoğu icon görünmüyordu
[x] admin panelden telefonla gelen siparişlerin eklenmesi, KDS'ye iletilmesi (müşteri seç, ürün seç, abonelik mi değil mi)

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

## K-14 — Kurye fişi, telefon, revizyon · BİTTİ
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

- **KDS düzenleme ekranı**: adet ±, kalem kaldırma, ürün ekleme
  (fiyatsız), teslimat saati, müşteri notu, sebep seçimi, onay penceresi.
- **Kurye fişi elle yeniden bastırılabiliyor**; menü siparişten türüyor,
  gel-al siparişte kurye seçeneği çıkmıyor.
- **İade / ek tahsilat tutarı** kaydetme mesajında görünüyor — yalnız
  fark, cari bakiye değil (ADR-08 duruyor).

## K-15 — Abonelik üretim planı · BİTTİ

Tam ekran plan (bugün / yarın / hafta), ürün toplamları, teslimat
çizelgesi, durum ilerletme, uyarı bloğu (başlıklı) ve üretim planı fişi
(golden testli).

## K-16 — BBD Store köprüsü · BİTTİ VE CANLI

İmzalı webhook (`POST /api/partner/bbd/orders`), `external_id` ile
tekilleştirme, kitchen ucundan kuyruk + ack, BBD'ye özel ses, ayrı
**paketleme fişi** (kitap e-ticareti: stok kodu, yazar, kargo firması,
takip numarası) ve durum çubuğunda `BBD: n` çipi.

**Canlıda doğrulandı (12.08.2026):** ortak sır iki tarafın `.env`'inde
eşleşiyor — imzalı istek middleware'i geçti, yalnız gövde doğrulaması
reddetti (`422`). Doğrulama fiş oluşturmayan bir gövdeyle yapıldı;
temizlenecek test kaydı yok.

BBD siparişleri panoya, üretim şeridine, vardiya istatistiğine, günlük
sayaca ve cari hesaba **karışmıyor** — senin kararın.

## Dokunmatik ikinci tur — SIFIR KLAVYE/FARE (12.08.2026)

Kural: **dokunmatik kip açıkken kasada klavye ve fare takılı olmayacak.**
Denetimde çıkan ve kapatılan açıklar:

- **Dokunmatik kasa HİÇ EŞLEŞEMİYORDU.** Türkçe ekran klavyesinde rakam
  yoktu: sunucu adresi, eşleme kodu ve yazıcı yolu yazılamıyordu. Üstelik
  eşleme ekranının hiç klavyesi yoktu. Rakam sırası + `- _ / : @`
  eklendi; eşleme alanlarının klavye düğmesi **ayardan bağımsız** hep
  duruyor (o ekran ayarlardan önce geliyor, ayara bağlamak aynı
  kilitlenmeyi sürdürürdü).
- **Satışı kapatmanın dokunmatik yolu yoktu:** satış kontrolü yalnız
  satış KAPALIYKEN çıkan kırmızı şeritten açılıyordu. Vardiya özeti (F3)
  de hiç dokunuşla açılmıyordu. Durum çubuğuna **İşlemler** menüsü
  eklendi; klavye kısayolları duruyor.
- **Klavyesiz metin alanları:** ayarlardaki iki alan, satış kontrolü ve
  düzenleme ekranındaki ürün aramaları. Ortak `KeyboardTextField` ile
  kapandı.
- **Teslimat saati ve müşteri notu düzenleme hiç çalışmıyordu:** gövdede
  alan hazırdı, onları değiştirecek arayüz yoktu. Saat seçici Material'in
  kadranı değil, büyük düğmeli kendi penceremiz.
- **Ses tanılamada "yok" ile "denenmedi" ayrıldı**; kurulum komutu
  ekranda ve kopyalanabilir.
- Kullanılmayan 12 l10n anahtarı kaldırıldı — kalan sıfır.

## Doğrulama (bu turda çalıştırıldı)

```
mutfakapp      flutter analyze → temiz | flutter test → 455 test geçti
packages/core  flutter analyze → temiz | flutter test → 139 test geçti
api_client     flutter analyze → temiz
design_system  flutter analyze → temiz
musteriapp     flutter analyze → temiz | flutter test →  97 test geçti
website        eslint → temiz | tsc --noEmit → temiz
docs/openapi.yaml → YAML geçerli, 44 yol
```

**Canlı sunucu (12.08.2026):** kod deploy edildi, göçler koştu
(`veykemtu_menu_soldout`, `veykemtu_order_revisions`,
`veykemtu_payment_refunds`, `veykemtu_bbd_receipts`,
`orders.bld_revision_no`, `veykemtu_kitchen_devices.volume_percent`
doğrulandı). `/api/health` 200; BBD ucu imza doğrulaması ile çalışıyor.

**Bu PC'ye KDS kuruldu:** `infra/kasa/derle.sh` ile derlenip
`~/.local/opt/mutfakapp` altına kuruldu, `mutfakapp.service` ayakta
(çökme yok). Ses gerçekten çalışıyor — `pw-play --volume=0.800 <dosya>`
çıkış kodu 0; eski hata `pw-play`'e `-q` geçirilmesiydi.

**PHP feature testleri:** ilk kez sunucuda koştuğunda iki gerçek hata
çıktı ve düzeltildi:

1. Paylaşılan `KitchenTestCase` hiçbir autoload haritasında değildi —
   PHPUnit eklenti test dizinlerini `suffix="Test.php"` ile tarıyor, o
   desene uymayan taban sınıf toplanmıyor ve yüklenmiyordu. **226 testin
   tamamı hiç koşmamıştı.** Sınıf `platform/tests/` altına (autoload-dev
   `Tests\`) taşındı.
2. `bld` kullanıcısının `bld_test` veritabanında yetkisi yoktu.

3. **`DB_PREFIX` boş verilmemişti** (benim kurulum hatam).
   `config/database.php` varsayılanı `ti_`; üretimde bu değeri boşa çeken
   yer `entrypoint.sh`'in ürettiği `.env` ve konteyner `--entrypoint sh`
   ile açılınca o betik koşmuyor. Her sorgu var olmayan `ti_*` tablosunu
   aradı; "116 hata / altyapı bozuk" izlenimi buradan çıktı. Doğru kurulum
   `docs/08-kurulum-deploy.md` §3'e yazıldı.

**SONUÇ: 226/226 geçiyor, 902 doğrulama, sıfır hata.** Paket ~50 dakika
sürüyor: `KitchenTestCase::setUp` her testte `veykemtu:setup` +
`veykemtu:demo-menu` koşuyor (test başına ~13 sn). Hızlandırmak ayrı iş.

### Paketi koşturmak neyi yakaladı

Testler daha önce hiç koşamadığı için **üretim kodunda üç hata sessizce
çıkmıştı**:

1. **`OrderFactory::storeAddress()` silinmiş, çağrısı kalmıştı** (K-12
   `LineResolver` ayrıştırması). `POST /api/orders` adrese gönderimde
   ölümcül hatayla 500 dönüyordu — **üretimde sipariş verilemiyordu** ve
   bu hâl `57f7d5f` ile dağıtılmıştı. Acil düzeltme `b61e143`.
2. **`revision_no` müşteri detay ucunda yoktu.** Alan `summary()` ve
   `kitchen()`'a eklenmiş, takip ekranının çektiği `detail()`'e
   eklenmemişti: web'de "Revize edildi" rozeti ve mobildeki "siparişiniz
   güncellendi" bildirimi hiç çalışmıyordu. `docs/openapi.yaml`'daki
   `OrderDetail` şeması da eksikti.
3. **`receipt_type_kurye` dil anahtarı yoktu**; admin paneli ham anahtarı
   basıyordu. Blade anahtarı fiş tipinden türettiği için derleme uyarmaz.

Test altyapısında da üç hata:

4. **`igniter:up` açık işlemin içinde koşuyordu.** MySQL'de DDL örtük
   commit yapar: savepoint yok olur, `DB::transaction()` kullanan her uç
   `SAVEPOINT trans2 does not exist` ile 500 döner ve testler arası geri
   alma çalışmaz (demo menü her testte üstüne yükleniyordu). Tek başına
   25 testi düşürüyordu.
5. `registerPayload()` paylaşılan tabana taşınmamıştı — 13 test.
6. `KitchenTestCase` autoload haritası dışındaydı — 226 testin tamamı.

**Ders:** bu tur deploy edilip testler sonra koşuldu. Sıra tersine
çevrilmeliydi; 1 numaralı hata o zaman üretime hiç çıkmazdı.

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

**BBD Store bir KİTAP e-ticaret sitesidir.** Çıkan kâğıt bir mutfak fişi
değil, **paketleme fişi**: raftan kitabı bulup kargoya vermek için.

```json
{
  "external_id": "BBD-2026-000123",
  "order_number": "BBD-123",
  "created_at": "2026-08-11T14:32:00Z",
  "customer_label": "Ayşe Y.",
  "phone": "0555 123 45 67",
  "delivery_type": "delivery",
  "address": "Örnek Mah. 12. Sk No:3, Selçuklu / Konya",
  "note": "Hediye paketi yapılsın",
  "items": [
    {
      "name": "Türkiye'nin Yakın Tarihi — Cilt II",
      "quantity": 2,
      "sku": "9789750718533",
      "attributes": ["Orhan Pamuk", "Ciltli", "3. Baskı"],
      "note": null
    }
  ],
  "amount_kurus": 18500,
  "cargo_company": "Yurtiçi Kargo",
  "tracking_number": "1234567890123",
  "payment_label": "Ödendi (kredi kartı)"
}
```

- `external_id` **zorunlu ve tekil**. Tekilleştirme buna bakar.
- `items[].name` **kitap adı**, fişe olduğu gibi basılır; BLD menüsüyle
  eşleştirme yapılmaz. Uzun adlar fişte satıra sarılır.
- `items[].sku` **stok kodu / ISBN** — raftan bulmanın en hızlı yolu,
  fişte `Kod:` satırında basılır.
- `items[].attributes` yazar / cilt / baskı gibi ek nitelikler
  (en çok 5 tane, her biri en çok 80 karakter).
- `cargo_company` + `tracking_number`: paketleyen kişi doğru poşeti
  seçsin diye. Takip numarası fişte **çift boy** basılır.
  Kitapta `delivery` **kargo** demek, kurye değil.
- `delivery_type: "pickup"` ise fişe adres basılmaz (mağazadan teslim).
- `payment_label` serbest metin: "Ödendi (kredi kartı)", "Kapıda ödeme".
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

**Sır girildi ve doğrulandı (12.08.2026).** `BBD_WEBHOOK_SECRET` iki
tarafın `.env`'inde eşleşiyor: imzalı bir istek middleware'i geçiyor,
yalnız gövde doğrulaması reddediyor (`422`). Köprü canlı.

**BBD ajanına iletilecek iki not:**

1. Daha önce aldıkları `404`, yol yanlışlığından değil **kodun henüz
   deploy edilmemiş olmasından** kaynaklanıyordu. Uç adresi doğru:
   `https://api.benimlezzetdunyam.com.tr/api/partner/bbd/orders`
2. İmza **ham gövde** (raw body) üzerinden alınır. JSON yeniden
   serileştirilirse (boşluk/sıra değişir) imza tutmaz.

**Bizim tarafta açık kalanlar** (BBD'nin bildirdiği):
takip numarası sipariş anında gönderilmiyor, `delivery_type` her zaman
`delivery` geliyor, müşteri sipariş notu yok. Üçü de fişte boş alan
olarak geçiliyor — fiş yine basılıyor.

---

# Web + Admin v2.0 turu KAPANDI (12.08.2026)

Web-Admin başlığındaki dört madde ve tur içinde eklenen iki istek
karşılandı. Ayrıntılı görev tablosu: `docs/09-gorev-plani.md` §8.6.

## Ne yapıldı

**api.* kökündeki ikinci site.** Ayrı bir deploy değilmiş: TastyIgniter'ın
kendi Orange vitrin teması, `IGNITER_URI` boş olduğu için `/` altına
biniyordu. İki kemerle kapatıldı — eklentide `disableThemeRoutes(true)`
(rota hiç kurulmuyor) ve Caddy'de ana domaine 308. Konteyner çalıştırılıp
ölçüldü: `/` ve bilinmeyen yollar yönleniyor, `/api/*`, `/admin`,
`/_assets/*`, `/odeme-simulasyon/*` geçiyor.

**Admin ikonları.** Sebep `infra/platform/Dockerfile.web` idi: derleme
sırasında `vendor:publish` koşmuyor, Caddy imajında `/vendor/igniter/`
klasörü hiç bulunmuyordu. Admin CSS'i PHP tarafındaki `_assets`
birleştiricisinden geldiği için stiller çalışıyor, yalnızca Font
Awesome'ın webfont'u 404 alıyordu — "stiller yerinde, ikonlar boş kutu"
tablosunun sebebi buydu. Yayınlama adımı eklendi, arkasına `test -f`
konuldu: sessizce bozulursa derleme patlar.

**Üst menü kapanmıyordu.** Masaüstünde `<details>` kullanılmış; Next.js
istemci tarafında gezinince DOM korunuyor ve panel açık kalıyordu. Radix
`NavigationMenu`'ye geçildi. Mobilde kapanma yalnızca `pathname`
değişimine bağlıydı ve üç durumda deliniyordu: aynı sayfanın bağlantısı,
`tel:`/`wa.me` düğmeleri, yavaş RSC geçişi. Her bağlantı `SheetClose` ile
sarıldı. Üçü de Playwright'ta sabitlendi.

**Hızlı giriş ve sipariş.** `/giris` sekmeli oldu; telefon varsayılan.
Kod 6 haneli, 5 dk ömürlü, tek kullanımlık, veritabanında bcrypt'li.
Ana sayfaya hızlı sipariş kutusu geldi: girişliye "geçen siparişi
tekrarla", girişsize giriş + kurumsal kayıt. Kutu verisini istemciden
çekiyor, böylece ana sayfa ISR'da kaldı.

**Abonelik ve cari self-servisi.** `docs/06`'daki "yalnız mobil" kararı
değişti. `/hesabim` dört bölümlü bir merkez oldu; `/hesabim/cari` bakiye,
90 günlük ekstre ve ödeme (tamamı ya da istenen tutar) sunuyor,
`/hesabim/abonelikler` duraklat/devam/iptal ve gün atlama yapıyor.

**Telefon siparişi ekranı.** Panelden müşteri seçip (ya da aynı ekranda
kurumsal müşteri açıp) sipariş giriliyor; sipariş `onaylandi` doğduğu için
mutfağa anında düşüyor ve fiş basılıyor. Fiyatlama yeniden yazılmadı,
`OrderFactory` çağrılıyor — panelin kendi hesabını yapması web ile
zamanla ayrışan iki fiyat demekti.

## Turda yakalanan beş hata

Beşi de yazarken değil, **doğrularken** çıktı:

1. **Admin işleyici imzası.** Çekirdek eylem işleyicilerini
   `[$action, ...$params]` ile çağırıyor; tek parametreli yazılan
   `onRecordPayment` `$recordId` olarak `"edit"` alıyordu. Tahsilat ekranı
   canlıda ilk denemede 406 verirdi.
2. **Abonelik ek porsiyonu.** `quantity_override` o günün TOPLAMI. Ek
   porsiyonu oraya doğrudan yazmak 100 kişilik aboneliği 10'a düşürürdü ve
   belirtisi ancak ertesi sabah mutfakta görülürdü. Ayrıca sipariş +
   istisna birlikte yazılınca aynı yemek iki kez pişerdi.
3. **OTP bekleme süresi hiç çalışmıyordu.** `created_at` UTC yazılıp
   Istanbul olarak okunuyordu; üç saatlik kayma 60 saniyelik sınırı
   sessizce devre dışı bırakıyordu. Sınırsız SMS gönderilebilirdi.
4. **Tahsilat makbuzu.** Makbuz numarası CRC32'lenip `reference_id`
   yapılıyordu; çakışmada `insertOrIgnore` ikinci tahsilatı sessizce
   yutar, yönetici "kaydedildi" görüp ekstrede bulamazdı.
5. **Gün atlamada geri bildirim yoktu.** E2E testi yakaladı; kullanıcı
   kartın değişmediğini görüp işlemin geçtiğini anlayamıyordu.

## Doğrulama

| Ne | Sonuç |
|---|---|
| `vendor/bin/phpunit --testsuite Veykemtu` | **276/276** (226 mevcut + 50 yeni) |
| Playwright (chromium + mobil) | **62/62** |
| `tsc`, `eslint`, `prettier`, `next build` | temiz |
| Redocly `docs/openapi.yaml` | geçerli |

**Test komutu tuzağı:** `php artisan test` bu projede bazen yalnızca
`Unit` paketini koşuyor (bir seferinde 227, sonrakinde 1 test).
Güvenilir komut `vendor/bin/phpunit --testsuite Veykemtu`.

## Dağıtımdan önce

1. Üç göç: `php artisan igniter:up` (cari limit, cari ödeme niyeti,
   giriş kodları).
2. `NETGSM_USERNAME`, `NETGSM_PASSWORD`, `NETGSM_HEADER` Coolify'a
   girilecek. **Üçü birden dolu değilse SMS gönderilmez** — kod yalnızca
   sunucu günlüğüne yazılır, e-posta + parola girişi çalışmaya devam eder.
3. `SITE_PUBLIC_URL` (web konteyneri) ana domaine işaret etmeli.
4. Her iki imaj da yeniden derlenmeli: `Dockerfile.web` değişti.

## Tur sonu tamamlama (aynı gün)

İlk teslimde eksik kalan ve gözden geçirmede çıkan maddeler:

- **Ana sayfadan sipariş verilebiliyor.** "Bugün mutfakta" bölümü yalnızca
  vitrindi; kartlar ürün sayfasına bağlanıyordu. Artık seçeneği olmayan
  ürünler doğrudan sepete ekleniyor, seçeneği olanlar detaya gidiyor.
- **Sepet rozeti sepet doluyken her sayfada görünüyor.** Önceden yalnızca
  sipariş rotalarında çiziliyordu; ana sayfadan ürün ekleyen ziyaretçi
  sepetinin varlığını `/menu`ye gidene kadar göremiyordu. Boş sepette
  kurumsal sayfalar eskisi gibi rozetsiz.
- **`/kayit` → `/kurumsal-kayit` (307).** Eski bireysel form unvan ve vergi
  bilgisi sormuyordu, yani faturalandırılamayan "kurumsal" hesaplar
  üretiyordu — iki kayıt yolu arasındaki bu tutarsızlık formu doldurduktan
  sonra fark edilirdi.
- **`robots.txt` ile `sitemap.xml` çelişkisi giderildi.** `/kurumsal-kayit`
  haritada ilan ediliyor ama robots onu engelliyordu. Bir dönüşüm sayfası
  ve boş bir form olduğu için yasak listesinden çıkarıldı; e2e testi ikisinin
  tutarlılığını bekçiliyor.
- **Ölü blog yolu temizlendi.** `content/posts.ts` (352 satır) ve
  `site-content.ts` içindeki `postSchema` / `mergePosts` / `findPost` /
  yedek girdisi kaldırıldı: hiçbir sayfa yazı basmıyordu ama içerik hâlâ
  çekilip doğrulanıyordu. Uç `posts` döndürmeye devam ediyor (sözleşme
  eklemeli); site onu artık görmüyor.
- **Kullanılmayan `register-form.tsx` ve `registerAction` kaldırıldı.**
  `registerSchema` duruyor — kurumsal şemanın tabanı.
- **CI'daki "Playwright yoksa atla" dalı silindi.** `playwright.config.ts`
  artık var; o dal, testler hiç koşmadan yeşil dönmenin yoluydu ve aylarca
  öyle kaldı. Hata durumunda iz dosyaları artifact olarak yükleniyor.
- **Panel giydirmesi doğrulandı.** Marka CSS'i bir olay dinleyicisiyle
  ekleniyor ve dosya `public/` altına yayınlanmıyor — çekirdeğin
  birleştiricisi onu doğrudan eklenti klasöründen okuyor. Zincirin bir
  halkası koparsa panel sessizce stoksuz açılırdı: hata yok, yalnızca
  giydirme yok. `AdminBrandingTest` hem CSS'in HTML'e düştüğünü hem yol
  simgesinin çözüldüğünü hem de gizlenen menülerin gerçekten kaybolduğunu
  ölçüyor.
- **Dokümanlar tamamlandı:** `docs/03` (OTP + cari ödeme uçları), `docs/08`
  (api.* yönlendirme, `Dockerfile.web` düzeltmesi, yeni env, göçler, test
  komutu tuzağı), `docs/10` (S10 kabul senaryoları), `docs/11` (§10
  simülasyon kararı).

### Bu turda ayrıca iki yanlış test yakalandı

İkisi de **geçiyordu ama yanlış sebeple**:

1. `getByRole('status')` ile ekleme onayı bekleniyordu; `/menu` sayfasında
   sipariş şalteri banner'ı zaten o role'ü taşıyor, yani test sayfanın en
   başından beri orada duran bir kutuyu bekliyordu.
2. Sepet bağlantısının görünürlüğü sinyal sanılmıştı; oysa sipariş
   rotalarında sepet boşken de duruyor.

İkisi de "Sepette N ürün var" sayacına bağlandı — sepetin gerçekten
dolduğunun tek işareti o.

## Bilinçli olarak yapılmayanlar

- **`bld-*` kısayol sınıfları silinmedi.** Hepsi zaten v2 jetonlarının
  üzerine kurulu, yani shadcn'den ayrı bir görsel dil değiller. Altmış
  kullanımı bileşene çevirmek kullanıcıya hiçbir şey kazandırmaz, on sekiz
  dosyada gerileme riski açardı. Gerekçe `app/globals.css` içinde yazılı.
- **Yeni abonelik web'den açılmıyor.** `POST /subscriptions` bir talep
  açıyor ama içeriği (ürünler, günler, adres, porsiyon) telefonla
  konuşulan bir anlaşma; formda toplamak yarım bir sözleşme üretirdi.
- **Simülasyon POS canlıda açık kalıyor** (kullanıcı kararı). Kartla
  ödenen sipariş fiilen bedava; panelde her ekranın tepesinde uyarı
  şeridi var.

---

# Fiş güncelliği, QR'lar ve sitenin mobilden geri kalması (12.08.2026)

Üç şikâyet: *"fişlerde saçmalık var, eski fişler asla çıkmamalı"*,
*"konum QR'ı yok"*, *"web sitesi mobil uygulamanın gerisinde"*.

## K-17 — Eski fiş artık basılmıyor

Sipariş düzenlenince (K-12) yeni sürüm kuyruğa giriyordu ama **eski sürüm de
kuyrukta bekliyordu.** Yazıcı meşgulse, kâğıt bittiyse ya da kasa yeniden
başladıysa mutfak önce eskiyi, sonra yeniyi alıyordu. İki kâğıt arasındaki
farkı kimse okumuyor — üstteki neyse o pişiyor. Yani iptal edilmiş bir satır
yine de hazırlanıyordu.

Kural: bir iş kuyruğa girer girmez, aynı siparişin aynı türdeki **daha eski ve
henüz basılmamış** işleri düşürülüyor.

Üç sınır bilerek kondu ve testle çakıldı (37 test):

- **Basılmış iş silinmiyor** — o satır hem denetim kaydı hem de sunucuya `ack`
  gidip gitmediğinin tek izi.
- **Yalnız daha eski sürümler** — parametre korunacak sürüm; eşitlik dâhil
  edilseydi işin kendisi silinirdi.
- **Tür bazında** — müşteri fişi düzenlemede yeniden tetiklenmiyor; mutfak
  fişi yenilendi diye bekleyen müşteri fişini düşürmek onu tamamen
  kaybettirirdi.

**Sıra önemli: önce ekle, sonra düşür.** Tersi olsaydı iki işlem arasında
çöken kasa o sipariş için kuyrukta sıfır iş bırakırdı — mutfak hiç fiş
görmezdi. Bu sırayla en kötü ihtimalde fazladan bir eski fiş basılır.

## K-18/K-19 — Fişteki QR'lar üçe çıktı

Harita QR'ı K-14'ten beri vardı. Eklenenler: **takip QR'ı** (`/siparis/<id>`)
ve **ödeme QR'ı**. Üçü de koşullu — veri yoksa blok hiç basılmıyor, boş kare
çıkmıyor.

- **Ödeme QR'ı ödenmiş siparişte basılmıyor.** Ödenmiş fişte ödeme karesi
  görmek müşteriyi ikinci kez ödemeye çalıştırır.
- **Ödeme QR'ı takip QR'ının üstünde.** Kapıda ödemeli müşterinin fişi eline
  alınca yapacağı ilk iş ödemek.
- Bağlantıyı **sunucu üretiyor**, KDS değil: kasada eski bir alan adı kalırsa
  QR sessizce ölü bir bağlantı taşır ve kimse fark etmez.

## Bu turun asıl bulgusu: `FRONTEND_URL` hiçbir yerde tanımlı değildi

İki ödeme denetleyicisi de `config('app.frontend_url')` okuyordu; değişken ne
`platform/.env.example`'da ne `docker-compose.coolify.yml`'de vardı — yani
**canlıda hiç set edilmemişti.** Ödeme dönüş adresi API köküne düşüyordu ve
I-07'den sonra orası ana domaine 308 verdiği için müşteri ödemeyi bitirip ana
sayfada buluyor, siparişinin ödenip ödenmediğini göremiyordu. Fiş QR'ları da
aynı değeri kullandığı için hata bu turda ortaya çıktı.

## W-15/W-16 — Site mobilin gerisindeydi

`/addresses` uçları sözleşmede baştan beri vardı ve mobil kullanıyordu; **site
hiç çağırmıyordu.** İki sonucu vardı:

1. Siteden sipariş veren müşteri adresini her seferinde elden yazıyordu.
2. Site hiç koordinat toplamadığı için **siteden gelen her siparişin kurye
   fişi QR'sızdı.** Kurye adresi okuyup elle aramak zorunda kalıyordu — arayüz
   eksiği gibi görünen boşluk mutfağa ve kuryeye kadar uzanıyordu.

Eklenenler: `/hesabim/adresler` tam defteri (ekle/düzenle/sil/varsayılan) ve
ödeme adımında kayıtlı adres seçimi; Leaflet + OpenStreetMap ile haritadan
iğne. Harita **hizmet alanına kilitli** — dışarı kaydırılabilen harita "oraya
da gidiyoruz" izlenimi verir, müşteri iğneyi Ankara'ya koyar ve siparişi
reddedilince sebebini anlamaz. İğne **isteğe bağlı**: zorunlu kılmak, konum
iznini reddeden müşterinin sipariş veremeyeceği anlamına gelirdi.

## Doğrulama

| Paket | Sonuç |
|---|---|
| PHP (`vendor/bin/phpunit --testsuite Veykemtu`) | **279/279** |
| `packages/core` | **145/145** (QR golden'ları dâhil) |
| `packages/api_client` | **49/49** |
| `mutfakapp` | **462/462** |
| Site: tsc + eslint + `next build` | temiz |
| Playwright | **68 geçti**, 4 atlandı |
| `docs/openapi.yaml` (Redocly) | geçerli |

## Turda yakalanan hatalar

- **Yanlış geçen bir e2e testi daha.** Kayıtlı adresin ödeme adımında seçili
  geldiğini ölçen test, sepete tek ürün koyuyordu; tutar 250 ₺ asgarisinin
  altında kaldığı için `/odeme` formu hiç çizmeyip "minimum sipariş tutarı"
  uyarısını gösteriyordu. Test formu arıyor, bulamıyordu — hata mesajı
  "seçici yok" diyordu ama sorun sepetteydi.
- **Kuyrukta silme sırası** (yukarıda): önce sil–sonra ekle taslağı, çöken
  kasada fişi tamamen kaybettirirdi.

## Bilinçli olarak yapılmayanlar

- **Pint ile toplu biçimlendirme yapılmadı.** Repoda `composer lint` script'i
  hiç tanımlı değil ve `vendor/bin/pint --test` eklentideki neredeyse her
  dosyayı işaretliyor — bu turda dokunulmayanlar dâhil. Kırk dosyayı yeniden
  biçimlendirmek bu turun kapsamı değildi; ayrı bir iş olarak durmalı.

---

# Log — Fiş sadeleştirme turu (14.08.2026)

**Şikâyet:** "ayrı ayrı kurye fişi mutfak fişi istemiyorum, revize 1 2 diye
ayrı ayrı fiş çıkarmasın, fazla fiş çıkıyor kafa karıştırıcı."

Sayım şikâyeti doğruluyordu. Görev kimliği `K-20`; gerekçelerin tamamı
`docs/05-mutfakapp.md` §5.3/§5.5 ve `docs/09-gorev-plani.md` §8.8'de.

## Kâğıt sayımı

| Senaryo | Önce | Sonra |
|---|---|---|
| Gel-al | 2 | 2 |
| Adrese gönderim | 3 | **2** |
| Adrese gönderim, 2 revizyon | 7 | **2** (aynı pencerede) |

## Ne yapıldı

- **Kurye fişi müşteri fişine katlandı.** Kuryenin üç sorusunun cevabı (kime,
  nereye, ne kadar tahsil edilecek) müşteri fişine taşındı ve teslimat bloğu
  fiyat tablosunun **üstüne** alındı — kurye önce nereye gideceğine bakıyor,
  kalem fiyatlarına hiç bakmıyor. Kâğıt kapıda kuryenin elinde, sonra
  müşteride kalıyor.
- **Sipariş notu da taşındı.** "Zili çalmayın" kuryeye bugüne kadar yalnız
  kurye fişiyle ulaşıyordu; taşınmasaydı o fişi kaldırmak kuryenin elinden
  bir kapı talimatını silmek olurdu.
- **Revizyonda tek güncel fiş.** Ayrı "REVİZE #1/#2" kâğıtları yok; basılmış
  fişler bir kez, güncel hâliyle, tepesinde çift boy `GÜNCEL FİŞ / REVİZE #N
  / ÖNCEKİ FİŞİ ATIN` bandıyla çıkıyor. Bant mutfak fişine de geldi.
- **20 sn birleştirme penceresi.** Personel telefonda konuşurken art arda
  kaydediyor; ara sürümler artık hiç kâğıda çıkmıyor. Üst sınır 60 sn.
  **İlk basım asla beklemiyor** — mutfak yemeğe başlamak için kâğıdı hemen
  görmeli.
- **Teslim QR'ı.** Kurye okutuyor → tek düğmeli onay → sipariş
  `teslim_edildi`. Kurye girişi yok; yetki HMAC imzasında, bağlantı tek
  kullanımlık.

## Turda yakalanan hatalar (altı tane, hepsi mevcut)

1. **Takip QR'ı yazıldığı günden beri çalışmıyordu.** K-18 bağlantıyı
   `/siparis/<id>` olarak üretiyordu; o rota giriş istiyor, yani fişteki
   kareyi okutan müşteri sipariş durumunu değil **giriş ekranını**
   görüyordu. Girişsiz, imzalı bir takip sayfası eklendi.
2. **Ödeme QR'ı üretimde ölü adrese gidiyordu** — sanal POS simülasyonu
   kapalıyken rota hiç kaydedilmiyor ama fişe kare basılıyordu.
3. **`PrintJob` revizyon körüydü.** Revizyon ack'i yutuluyor, yeniden
   basılan kâğıt yerini aldığı eski kâğıdın saatiyle damgalanıyordu — tam
   da "GÜNCEL FİŞ" bandının çözdüğü sorunu zaman damgası üretiyordu.
4. **"Yeniden bas" iki kâğıt çıkarıyordu** — revizyon süzgeci yoktu.
5. **Sanal POS dönüş adresi kırılacaktı** — düz string birleştirme, imzalı
   takip adresi sorgu taşıdığı anda `durum` parametresini okunamaz kılardı.
   Bu hatayı değişikliğin kendisi üretecekti, aynı turda düzeltildi.
6. **`/cari-odeme-simulasyon/*` Caddy izin listesinde yoktu** — cari borç
   ödeme sayfası üretimde ana siteye yönleniyordu. K-20 ile ilgisiz, aynı
   satıra dokunulurken görüldü.

## Doğrulama

| Paket | Sonuç |
|---|---|
| PHP (`vendor/bin/phpunit`) | **316/316** |
| `packages/core` | **163/163** |
| `packages/api_client` | **49/49** |
| `mutfakapp` | **472/472** |
| `flutter analyze` (tüm çalışma alanı) | temiz |
| Site: tsc + eslint + `next build` | temiz |
| Playwright | **72 geçti**, 4 atlandı |

Kurye, mutfak, üretim planı ve BBD golden'ları **bayt bayt aynı** kaldı;
sözleşme değişikliklerinin tamamı additive, `required` listeleri değişmedi.

## SENDEN BEKLEYEN — QR donanımı hâlâ doğrulanmadı

`docs/10` §"QR AÇIK MADDE" kapanmadı: fişteki konum QR'ı sahada kâğıda
çıkmıyor ve sebebi bilinmiyor. **Yeni teslim QR'ı aynı komuta dayanıyor.**

Sahaya çıkmadan kasada koşulmalı:

```bash
cd mutfakapp && dart run tool/yazici_teshis.dart
```

Yalnız C bölümü çıkıyorsa yazıcı yerleşik QR'ı desteklemiyor demektir ve
QR'ların raster çizilmesi gerekiyor — ayrı ve daha büyük bir iş.
Birleştirme ve revizyon düzeltmesi bu karardan **bağımsız** çalışıyor.

## Dağıtımda yapılacaklar

```bash
cd platform
php artisan igniter:up          # veykemtu_print_jobs.revision göçü
```

- **Yeni `.env` girdisi:** `BLD_LINK_SECRET`. Boşsa `APP_KEY`'e düşer ve
  özellik çalışır; yine de üretimde ayrı tanımlanmalı — `APP_KEY`
  döndürüldüğünde oturumlar ve şifrelenmiş sütunlar da geçersiz olur.
  Sır değişince **basılı fişlerdeki QR'lar ölür**.
- **`infra/Caddyfile.internal` dağıtılmalı:** `/teslimat/*` izin listesine
  eklendi. Güncellenmiş dosya gitmezse teslim QR'ı ana siteye 308'lenir ve
  hata "QR ana sayfayı açıyor" diye görünüp yanlış depoda aranır.

## Bilinçli olarak yapılmayanlar

- **Pint ile toplu biçimlendirme yine yapılmadı.** Önceki turdaki gerekçe
  aynen geçerli: `vendor/bin/pint --test` bu turda dokunulmayan onlarca
  dosyayı da işaretliyor.
- **`kurye` fiş tipi silinmedi.** Sözleşme additive-only ve kuyrukta duran
  eski satırlar tipe göre ayrıştırılıyor; enum değeri kalksaydı eski bir
  kurye satırı mutfak fişi olarak yeniden basılırdı. Otomatik tetiği ve KDS
  menüsündeki seçeneği kalktı, uç elle yeniden basım için duruyor.

---

# Log — KDS'in Kontrol Merkezi'nden yönetimi (K-21, 14.08.2026)

**İstek:** *"kds ekranını buradan yukarıdan yönetebilmek, sipariş revizeleri
olsun her şey olsun, mutfak personelinin yapabildiğinin çok daha fazlasını
yapabilmek. KDS uygulamasını artık kilitleyeceğiz. İkisi senkron çalışmalı."*

Artı iki fiş şikâyeti: *"1 kurye 1 de mutfak fişi çıkacak, kurye siparişi
müşteriye teslim edilecek, kuryede kalmayacak"* ve *"revize onaylanır
onaylanmaz mutfak fişi çıkar, kuryeye de en en en son hazıra basınca çıkar —
şu an arka arkaya fiş basılıyor."*

## Bulunan durum: altyapının çoğu zaten vardı

Uzaktan yönetim K-09'dan beri çalışıyordu — 16 yönetilen ayar, 5 komut, cihaz
kaydı/iptali, sağlık telemetrisi. **Eksik olan tek şey makine okunur bir
yönetim ucuydu:** `/api/kitchen/*` bir KASANIN token'ına bağlı, yönetim tarafı
ise yalnızca HTML admin ekranı. Kontrol Merkezi oraya kasa gibi eşleşseydi,
panelde açık duran bir ekran mutfakta olmayan bir kasayı "çevrimiçi"
gösterirdi ve yöneticinin gördüğü tablo kendi kendini doğrulardı.

## K-21 — Kontrol Merkezi kapısı

**Yeni imza şeması `X-Control-Signature`**, sır `BLD_CONTROL_SECRET`.
`bbd.signature` YENİDEN KULLANILMADI: yönü ters (BBD bize yazıyor, Kontrol
Merkezi yönetiyor) ve aynı sırrı iki yetki seviyesi için kullanmak, BBD'nin
sırrını ele geçiren birine mutfağı yönetme hakkı da verirdi.

**Tekrar saldırısına kapalı.** `bbd.signature` yalnız gövdeyi imzalıyor;
orada etki `external_id` tekilliğiyle sınırlı kalıyor. Burada kalmazdı —
"cihazı iptal et" isteğini tekrar oynatmak mutfağı sipariş göremez hâle
getirir. İmza dört şeyi birden kapsıyor:

    METOT \n YOL \n ZAMAN \n NONCE \n sha256(gövde)

Metot ve yol imzada olmasaydı, gövdesiz iki farklı uç aynı imzayı paylaşırdı —
ki iptal ucunun gövdesi boş. Zaman penceresi ±300 sn, nonce 600 sn hatırlanır
(`Cache::add` atomik; `has`+`put` ikilisi arada yarış bırakırdı).

**16 uç** `/api/control/kds/*`: cihaz listesi/ekleme/adlandırma/eşleme
kodu/iptal, ayar itme, komut gönderme ve geçmişi, fiş denetim kaydı,
siparişler, revizyon, durum ilerletme, ürün kataloğu.

**İş mantığı yeniden yazılmadı:** `OrderEditor`, `OrderStatusTransition`,
`KitchenDeviceSettings`, `KitchenDevice`, `KitchenCommand`, `OrderPresenter`
aynen kullanılıyor. Uçlar yalnız kabuk. Böylece kasadan ve merkezden yapılan
aynı iş aynı kodu koşuyor ve ikisi ayrışamıyor.

**Her yazma `reason` (min 10) + `actor` ister** ve `veykemtu_control_audit`'e
satır yazar; kuru provada da yazar (`result="dry_run"`). Satır silinmez.
`created_by_staff` = "Kontrol Merkezi · <aktör>" — kasadan mı merkezden mi
yapıldığı denetim izinde ayrışıyor.

## Kilit politikası — 7 yeni yönetilen ayar

`allow_settings`, `allow_server_change`, `allow_window_controls`,
`allow_order_edit`, `allow_manual_reprint`, `allow_sales_control`,
`lock_message`. Ayrıntı ve gerekçeler `docs/05-mutfakapp.md` §8.5.

**Varsayılan `null` = serbest.** Alanların eklenmesi sahadaki hiçbir kasayı
kilitlemez; tersi olsaydı sunucu güncellemesi mutfağı bir gecede kilitlerdi.

**Kilit diske yazılıyor.** Kasa ağsız açıldığında ilk sağlık turu 60 sn sonra
gelir; kilit yalnız bellekte dursaydı kasa o pencerede serbest açılırdı ve
kilidi aşmanın yolu "kapat–aç" olurdu. Aynı turda, bugüne kadar diske hiç
yazılmayan dört ayar da kalıcı hâle geldi (`printer_code_page`,
`health_seconds`, `connection_alarm_seconds`, `alarm_silenceable`) — kod
sayfası yeniden başlatmada varsayılana döndüğü için arada basılan fişlerde
Türkçe harfler boşluğa dönüyordu.

**Kilit sipariş akışına dokunmaz:** durum ilerletme, geri alma, alarm
susturma, arama ve yenileme her koşulda açık. Kilitli düğme gizlenmez,
pasifleşir — gizlemek personele "bozuldu" dedirtir ve mutfaktan telefon
açtırır.

## Fiş şikâyeti: tasarım doğruydu, aşamalar çöküyordu

K-20 zaten sipariş başına iki kâğıda indirmişti ve eşikler doğruydu (mutfak
`onaylandi`, müşteri/kurye `hazir`). Şikâyetin sebebi **iki eşiğin aynı turda
aşılabilmesiydi**; o anda iki kâğıt 1200 ms arayla peş peşe çıkıyordu. Üç yol:

1. Sipariş iki yoklama arasında `yeni`→`hazir` atlarsa KDS onu ilk kez `hazir`
   görür ve her iki eşiği aynı turda geçer. **Bu davranış test edilmiş ve
   "doğru" sayılıyordu** — testler güncellendi, silinmedi.
2. Revizyon bekletmesi salınırken basılmış tiplerin hepsi aynı turda dökülüyordu.
3. Bekletmedeki revize mutfak fişi ile hiç basılmamış ilk müşteri fişi aynı
   tura denk gelebiliyordu.

**Kural: turda sipariş başına tek fiş, mutfak önce.** Ertelenen tip bir
sonraki turda çıkar. Ayrıntı `docs/05-mutfakapp.md` §5.5.

> **ERTELEMEK KAYBETMEK DEĞİLDİR.** İki incelik testle çakıldı: erteleme
> `_acceptedOrders`/`_readyOrders` kümesini İŞARETLEMEZ (işaretlemek fişi
> bastırmaz, tamamen kaybettirirdi), ve ertelenen iş sipariş listesinden
> BAĞIMSIZ salınır — sipariş `teslim_edildi` olup panodan düşse bile kurye
> fişi çıkar. Kurye kâğıtsız yola çıkarsa müşterinin elinde tek belge kalmaz.

## Turda yakalanan üç hata (hepsi mevcut, hiçbiri bu turun ürünü değil)

1. **Seçenek KİMLİĞİ kayboluyordu.** `OrderPresenter::editable()` seçeneklerin
   yalnız adını döndürüyor, `LineResolver` ise `option_value_ids` istiyor.
   Sonuç: seçenekli bir sipariş KDS'ten düzenlenince satır **seçeneksiz
   yeniden fiyatlanıyor** — müşteri eksik ücretlendiriliyor ve fişten seçenek
   satırı düşüyor. Kimlikler `order_menu_options`'ta duruyordu; `editable()`
   artık tek sorguda okuyup `option_value_ids` olarak veriyor (additive).
2. **Seçenek ADI boş kaydediliyordu.** `LineResolver::resolveOptions()`
   `option_value->value` okuyordu; `menu_option_values` sütununun adı `name`.
   Eloquent tanımsız özniteliğe `null` dönüyor, `?? ''` boş dizgeye çeviriyor.
   Fiyat farkı doğru işlendiği için toplam tutuyordu ve hata görünmüyordu.
3. **`audio_sink` boş dizesi tele hiç ulaşmıyordu.** Sözleşme "boş dize =
   varsayılan çıkışa dön" diyor ve testi de vardı — ama test nesneyi doğrudan
   kuruyordu; sunucudan gelen yolda `_asStringOrNull` boş dizeyi `null`'a
   çeviriyor, `null` da "dokunmadı" demek. Yani yönetici seçtiği hoparlörü
   panelden geri alamıyordu. Düzeltme geri alınıp testin gerçekten düştüğü
   görülerek doğrulandı.

## Doğrulama

| Paket | Sonuç |
|---|---|
| PHP (`phpunit --testsuite Veykemtu`) | **441 test / 1842 doğrulama**, 1 hata* |
| `ControlKdsTest` + `OrderRevisionTest` | **66 test / 311 doğrulama**, temiz |
| `mutfakapp` | **519 test**, `flutter analyze` temiz |
| `packages/api_client` | **100 test** |
| `packages/core` | golden fiş baytları **değişmedi** |

\* `AddressSuggestTest::test_oneri_doner_ve_satiri_sunucu_kurar` — adres
birleştirmede fazladan virgül. Test dosyası ve `StructuredAddress.php`
untracked, yani yapısal adres iş kolunun devam eden işi; K-21 diff'i adres
yolunun hiçbir yerine değmiyor.

## Dağıtımda yapılacaklar

```bash
cd platform
php artisan igniter:up      # 2026_08_17_000001 + 000002
```

- **Yeni `.env` girdisi: `BLD_CONTROL_SECRET`** (`openssl rand -hex 32`).
  `BBD_WEBHOOK_SECRET` ile AYNI OLMAMALI. Boşsa `/api/control/kds/*` 401
  döner ve Kontrol Merkezi hiçbir şey yönetemez.
- Aynı değer Kontrol Merkezi'nin kasasına `server.bld.control_secret` adıyla
  girilir.
- `docker-compose.coolify.yml` güncellendi; Coolify'da değişken tanımlanmalı.

## Bilinçli olarak yapılmayanlar

- **`CatalogController.php:394` düzeltilmedi.** Hata 2 numaranın birebir
  kopyası (`option_value->value`) ve müşteri menüsündeki seçenek adlarını
  boşaltıyor. Dosya şu an başka bir iş kolunda değişiklik altında; tek
  satırlık düzeltme için çakışma riskine girilmedi. **Açık madde.**
- **Geriye dönük veri düzeltmesi yapılmadı.** 1 ve 2 numaralı düzeltmeler
  yalnız bundan sonra yazılan satırları etkiler; veritabanında boş adla duran
  mevcut `order_menus.option_values` / `order_menu_options.order_option_name`
  kayıtları öyle kalır. Düzeltmek ayrı bir göç ister.
- **Yeni komut eklenmedi.** `update` (uzaktan `.deb` kurulumu) ve makine
  yeniden başlatma hâlâ yok; `restart` yalnız uygulamayı öldürüyor.
- **WebSocket'e geçilmedi.** Kontrol Merkezi de yoklamayla çalışıyor;
  ADR-05'in Faz 1.5 kararı değişmedi.
- **Açılış parolası hâlâ derleme sabiti** — uzaktan döndürülemiyor.
- **Pint ile toplu biçimlendirme yine yapılmadı** (önceki turların gerekçesi
  aynen geçerli).

---

# Log — Ayarlar ekranının tamamı merkeze taşındı (K-22, 14.08.2026)

**İstek:** *"kds uygulamasının ayarlar ekranındaki her şeyi, tüm butonlarının
yaptığı işlemlere kadar yönetecek ayrıntılı bir şey istiyorum. kuru provaya
gerek yok. daha da işlevsel ayrıntılı hale getir."*

K-21 yirmi üç alan ve beş komut taşıyordu. Bu tur kalan boşlukları kapattı.

## Olay bazlı sesler — `disabled_sound_events`

Kasadaki beş sesli uyarı tek tek kapatılabiliyordu ama sunucu bunu ne görüyor
ne değiştirebiliyordu. Üç durumlu: `null` = dokunulmadı, `""` = hiçbiri kapalı
olmasın, dolu = tam olarak bunlar kapalı. `connectionLost` **iki katmanda da
sessizce eleniyor** — yöneticinin yazım hatası mutfağı sessiz bırakmamalı.

## Üç yeni komut

`update`, `unpair`, `clear_queue`. Ayrıca `KitchenCommand::DESTRUCTIVE`
listesi eklendi; hangi komutun ayrı izin istediğini sunucu ve Kontrol Merkezi
tek yerden okuyor.

**`update` `pkexec` KULLANMIYOR.** Kasada etkileşimli parola sorar ve komut
sonsuza dek asılı kalırdı. Uygulama `~/.local/opt/mutfakapp` altında bir
systemd **kullanıcı** servisi olduğu için root gerekmiyor: `.deb` imzası
doğrulanıyor, `dpkg-deb -x` ile açılıyor, iki rename ile takas ediliyor,
`systemctl --user restart`. **Her hata dalında eski kurulum yerinde kalıyor.**

## Zenginleştirilmiş telemetri

`last_error`, `alarm_muted`, `alarm_mute_reason`, `queue_oldest_at`,
`sound_ok`. Hepsi opsiyonel — eski kasalar göndermiyor, sunucu `null` yazıyor.
"Kuyrukta 3 iş var" ile "en eskisi 40 dakikadır bekliyor" arasındaki fark
sahaya gitme kararını değiştiriyor.

İki bilinçli karar: telemetri **kalıcı değil** (`app_version`in aksine — o bir
kimlik, bu bir ölçüm), ve ses kapalıyken `sound_ok` `null` (altsistem sağlıklı
değil, **denenmemiş**).

## Turda yakalanan hata: boş dize sunucuya hiç ulaşmıyordu

Laravel'in `ConvertEmptyStringsToNull` ara katmanı gövdedeki her `""` değerini
`null`'a çeviriyordu. Sözleşmede `null` "yönetici dokunmadı" demek — yani
**boş dizeyle yapılan hiçbir sıfırlama kontrol API'sinden geçemiyordu:**
seçili hoparlörü varsayılana döndürmek, kilit mesajını silmek, kapatılmış bir
sesi geri açmak. Üçü de sessizce hiçbir şey yapıyordu; K-21'den beri açıktı.
`Control\DeviceController::restoreEmptyStrings()` yalnız boş dizeleri ham
gövdeden geri koyuyor, doğrulama temizlenmiş girdi üzerinde koşmaya devam ediyor.

## Sunucu adresi bilerek yönetilmiyor

Kasadaki "Sunucuyu değiştir" düğmesinin uzaktan karşılığı **yazılmadı**.
Yanlış bir adres yazıldığı anda kasa yeni adrese gider, oradan hiçbir şey
alamaz ve **düzeltmeyi de alamaz** — çünkü düzeltme eski adresten gelecekti.
Tek bir yazım hatasının mutfağı durdurduğu tek ayar budur. Gerekçe
`docs/05-mutfakapp.md` §8.6'da; ters yön (`allow_server_change`) K-21'de var.

## Kuru prova kalktı

Kontrol Merkezi'nde varsayılan kapandı ve panelden şalter kaldırıldı. Sunucu
ve geçitteki `dry_run` parametresi ile testleri **duruyor** — sözleşme
additive. Gerekçe zorunluluğu (`reason`, min 10) aynen sürüyor: kuru prova bir
güvenlik ağıydı, gerekçe denetim kaydıdır.

## Kasa temizliği

Sahada tek gerçek kasa var (MSI Mutfak Kasası). Kalan 20 kayıt deneme
artığıydı ve **dördünün token'ı 9 gündür kullanılmamasına rağmen hâlâ
geçerliydi.** Kullanıcı kararıyla silindi; öncesinde tam yedek alındı
(`/root/kds-yedek-tam-*.json`). İki fiş denetim satırının `device_id`'si
`NULL`'a çekildi — kayıt korundu, sarkan başvuru kalktı.

## Doğrulama

| Paket | Sonuç |
|---|---|
| PHP (`phpunit --testsuite Veykemtu`) | **457 test / 1921 doğrulama**, 1 hata* |
| `mutfakapp` | **554 test**, `flutter analyze` temiz |
| `packages/core` | **182 test** — golden fiş baytları değişmedi |
| Kontrol Merkezi modülleri | **150 test**, depo geneli 2507, ruff temiz |

\* `AddressSuggestTest` — yapısal adres iş kolunun devam eden işi, K-22 ile ilgisiz.

## Dağıtımda yapılacaklar

```bash
cd platform && php artisan igniter:up   # 2026_08_18_000001
```
Kasa yeni komutları ve ayarları ancak **yeniden derlenip kurulunca** tanır
(`infra/kasa/derle.sh`).

## Bilinçli olarak yapılmayanlar

- **`packages/core` için `dart test` değil `flutter test`** — çalışma alanı
  `flutter_test` çektiği için `dart pub` sürüm çözemiyor. Belgelerde `dart test`
  yazan yerler bu turda düzeltilmedi.
- **Kontrol Merkezi'nde `clear_queue` yıkıcı sayıldı**, BLD'de böyle bir ayrım
  yok. Gerekçe: `clear_queue` ⊃ `clear_failed`; dışarıda bırakmak dar yetkiliye
  daha fazlasını yaptırırdı.
- **`server_url` cihaz künyesinde taşınmıyor.** Panel varsa gösteriyor, yoksa
  "kasa bildirmiyor" yazıyor. Alan eklemek ayrı bir iş.
