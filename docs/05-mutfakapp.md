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
--------------------------------
2×  TAVUK SOTE
    (Normal)
    >> Az acılı <<

1×  MERCİMEK ÇORBASI
--------------------------------
NOT: Fatura kurumsal
```

**Müşteri fişi** (fiyatlı):
```
   BENİM LEZZET DÜNYAM
      Sipariş: S-5012
      04.08.2026 14:32
--------------------------------
2× Tavuk Sote        370,00
1× Mercimek Çorbası   85,00
--------------------------------
Ara Toplam           455,00
Teslimat              40,00
TOPLAM               495,00
Ödeme: Online (Ödendi)
--------------------------------
Teslimat:
Örnek Mah. 12. Sk No:3
Çankaya / Ankara
--------------------------------
Bu belge bilgi fişidir,
mali değeri yoktur.
```
`delivery_type=pickup` siparişinde "Teslimat" bloğu ve "Teslimat" ücret satırı **basılmaz**; yerine `GEL-AL` yazar.

### 5.4 Kuyruk

**Zorunlu davranış:**
- Her yazdırma işi önce SQLite'a yazılır (`print_queue` tablosu: `id`, `order_id`, `type`, `payload`, `attempts`, `created_at`, `printed_at`).
- İş kimliği `(order_id, type)` çiftidir → **idempotent**, aynı fiş iki kez basılmaz.
- Basım başarısızsa: `attempts++`, geri çekilmeli tekrar (2s, 5s, 15s, 60s...), kuyrukta kalır.
- Yazıcı yoksa/kağıt bittiyse durum çubuğunda kalıcı uyarı + kuyruk sayacı.
- Uygulama yeniden başlarsa kuyruk diskten okunur ve devam eder.
- Başarılı basımdan sonra `POST /api/kitchen/print-jobs/{order_id}/ack` gönderilir (başarısız olursa sessizce yut).
- Ayarlarda **"Yeniden bas"** butonu: seçili siparişin fişini elle tekrar basar.

### 5.5 Tetikler

**Sipariş başına tam olarak iki fiş çıkar** (karar 05.08.2026):

| Olay | Fiş |
|---|---|
| Mutfak siparişi **onayladı** (`onaylandi`) | Mutfak fişi (otomatik) |
| Durum **`hazir`** yapıldı | Müşteri fişi (otomatik) |

> **`yeni` durumunda fiş BASILMAZ.** Sipariş henüz kabul edilmemiştir ve
> müşteri iptal edebilir (`docs/03` §4 — iptal `yeni` ve `onaylandi`
> durumlarında serbest). Önceki davranış siparişi listede görür görmez
> basıyordu; iptal edilen her sipariş çöpe giden bir fiş demekti.

Her iki eşik de "**o durum ya da ötesi**" diye okunur. Sipariş `hazir`
iken uygulama kapanıp `yolda` iken açılırsa fiş hiç basılmamış olabilir;
tetiği kaçırmaktansa fazladan çağırmak yeğdir — kuyruktaki
`UNIQUE(order_id, type)` ikinci fişi zaten engelliyor.

`teslim_edildi` de "hazır ötesi" sayılır: gel-al siparişi `hazir`dan
doğrudan oraya geçer ve arada bir yayın kaçarsa müşteri fişi hiç
basılmazdı.

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

Oturum boyunca hatırlanır, kalıcı saklanmaz: uygulama yeniden başlarsa
(elektrik kesintisi, çökme, güncelleme) parola tekrar istenir.

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

## 8. Ayarlar ekranı

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
