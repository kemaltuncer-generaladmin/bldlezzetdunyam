# RUNBOOK — Arıza Müdahale

Bu belge servis sırasında, telaşlıyken okunmak için yazıldı. Her bölüm
**önce en olası sebeple** başlar ve her adım tek bir komuttur.

**Altın kural:** sipariş verisi kaybolmaz. Mutfak ekranı düşse bile
siparişler sunucuda durur; admin panelinden görülebilir ve elle basılabilir.
Panik etmeden önce bunu hatırla.

| Hızlı erişim | |
|---|---|
| API / Admin panel | `https://api.benimlezzetdunyam.com.tr` |
| Coolify | `http://62.238.102.197:8000` |
| Sunucu | `ssh root@62.238.102.197` |
| Kasa | mutfaktaki MSI, kullanıcı `mutfak` |
| Yazıcı | `/dev/thermal0` → USB `0483:5720` |

**Sunucuda komut çalıştırma.** Konteyner adları her dağıtımda değişir;
adı sabit yazma, ara:

```bash
A=$(docker ps --format '{{.Names}}' | grep '^app-' | head -1)
docker exec -u www-data -e HOME=/tmp "$A" php artisan <komut>
```

`-u www-data` ATLANMAZ — sebebi §4.5.

---

## 1. Yazıcı basmıyor

Fiş **kaybolmaz** — KDS kuyruğu diskte tutar ve yazıcı gelince basar.
Durum çubuğundaki kuyruk sayacı kaç fişin beklediğini gösterir.

### 1.1 Önce bunlara bak (sırayla, 30 saniye)

1. **Kağıt var mı?** Kapağı aç, rulo bitmiş olabilir. Termal kağıdın
   **parlak yüzü** yazıcıya bakmalı; ters takılırsa boş kağıt çıkar.
2. **Kapak tam kapalı mı?** Yarım kapalı kapakta yazıcı sessizce beklemede kalır.
3. **Kırmızı ışık yanıyor mu?** Yanıyorsa kağıt yok ya da kapak açık.
4. **USB kablosu** — hem yazıcıdan hem kasadan çek tak.

### 1.2 Cihaz görünüyor mu

```bash
ls -l /dev/thermal0
```

- **Çıktı var** → cihaz tamam, §1.3'e geç.
- **"No such file"** → çekirdek yazıcıyı görmüyor:

```bash
lsusb | grep -i 0483:5720     # yazıcı USB'de görünüyor mu
ls -l /dev/usb/                # lp0 / lp1 var mı
sudo modprobe usblp            # sürücü yüklü değilse
sudo udevadm trigger           # sembolik bağı yeniden kur
```

`lsusb` çıktısında yazıcı **hiç yoksa** sorun kablo veya yazıcının kendisidir;
başka bir USB portu dene.

### 1.3 Doğrudan yazdırma testi

Uygulamayı devre dışı bırakıp doğrudan yazıcıya yaz:

```bash
printf 'TEST\n\n\n\x1D\x56\x42\x00' > /dev/thermal0
```

- **Fiş çıktı** → yazıcı sağlam, sorun uygulamada. §1.4'e geç.
- **"Permission denied"** → udev kuralı düşmüş:

  ```bash
  cd ~/Desktop/BLD
  sudo cp infra/kasa/99-thermal-printer.rules /etc/udev/rules.d/
  sudo udevadm control --reload-rules && sudo udevadm trigger
  ```

- **Komut takıldı, dönmüyor** → yazıcı meşgul veya hata durumunda.
  Yazıcıyı kapat, 10 saniye bekle, aç.

### 1.4 Uygulama basmıyor ama yazıcı sağlam

```bash
systemctl --user restart mutfakapp
systemctl --user status mutfakapp --no-pager | tail -20
```

Kuyruk diskte durur; yeniden başlatma fiş kaybettirmez. Uygulama açılınca
bekleyen fişleri sırayla basar.

### 1.5 Türkçe karakterler bozuk çıkıyor

Yazıcı **değiştirildiyse** kod sayfası numarası farklı olabilir; bu numara
üreticiye göre değişir, standart değildir.

```bash
cd ~/Desktop/BLD
./infra/kasa/kodsayfasi-tara.sh
```

Çıkan fişte Türkçe harflerin doğru göründüğü `n=XX` satırını bul, sonra
KDS → Ayarlar → Kod sayfası alanına o sayıyı yaz. (Mevcut yazıcıda **29**.)

### 1.6 Son çare: fişsiz devam

Yazıcı tümden bozulduysa operasyon durmaz:

- KDS ekranı çalışmaya devam eder, siparişler görünür.
- Admin panelinden sipariş detayı okunup elle not alınabilir.
- Yazıcı gelince kuyruktaki fişler **otomatik** basılır; elle bir şey yapma.

---

## 2. Sipariş mutfağa düşmüyor

### 2.1 Sipariş gerçekten oluştu mu

Önce siparişin var olduğunu doğrula — yoksa sorun mutfakta değil, sipariş
alma tarafında.

Admin panel → Siparişler. Sipariş **listede varsa** sorun KDS ile sunucu
arasındadır (§2.2). **Yoksa** sorun web/mobil taraftadır (§3).

### 2.2 KDS bağlantısı

KDS durum çubuğunun soluna bak:

| Gösterge | Anlamı | Ne yap |
|---|---|---|
| ● Bağlı (yeşil) | Veri akıyor | Sorun başka yerde |
| ● Bağlanıyor (sarı) | Yeniden deniyor | 1 dakika bekle |
| ● Bağlantı yok (kırmızı) | Sunucuya ulaşamıyor | §2.3 |
| ● Cihaz iptal (kırmızı) | Token iptal edilmiş | §2.4 |

Ekrandaki liste bağlantı koptuğunda **silinmez** — son bilinen hâliyle kalır.
Bağlantı gelince kaçırılanlar otomatik yüklenir.

### 2.3 Kasa internete çıkamıyor

```bash
ping -c3 8.8.8.8                                   # internet var mı
curl -s -o /dev/null -w '%{http_code}\n' \
  -H 'X-App-Id: mutfakapp' -H 'X-App-Version: 1.0.0' \
  https://api.benimlezzetdunyam.com.tr/api/health   # sunucu ayakta mı
```

- `ping` başarısız → mutfağın interneti yok. Modem/switch kontrol et.
- `ping` tamam ama `curl` 000 → sunucu sorunu, §4'e geç.
- `curl` 200 → uygulama sorunu: `systemctl --user restart mutfakapp`

### 2.4 "Cihaz iptal edilmiş"

Kasanın token'ı admin panelden iptal edilmiş. Yeniden eşle:

```bash
# Sunucuda yeni eşleme kodu üret (10 dakika geçerli)
ssh root@62.238.102.197 \
  'A=$(docker ps --format "{{.Names}}" | grep "^app-" | head -1);
   docker exec -u www-data -e HOME=/tmp "$A" php artisan veykemtu:kds --new="Mutfak Kasası"'
```

Kodu KDS'in eşleme ekranına gir.

---

## 3. Müşteri sipariş veremiyor

### 3.1 Önce şalteri kontrol et

En sık sebep bu ve teknik bir arıza değil: **sipariş alımı kapatılmış olabilir.**

Admin panel → Ayarlar → Vitrin. `Sipariş alımı` açık mı? Kesim saati geçmiş mi?

Sipariş alımı kapalıyken menü görünmeye devam eder ama sepete ekleme
engellenir — müşteri "site çalışmıyor" der, oysa şalter kapalıdır.

### 3.2 Hangi hatayı alıyor

| Müşterinin gördüğü | Sebep |
|---|---|
| "Şu anda sipariş alınmıyor" | Şalter kapalı veya çalışma saati dışı → §3.1 |
| "Bugünün sipariş kabul saati doldu" | Kesim saati geçmiş → admin panelden saati değiştir |
| "Asgari sipariş tutarının altındasınız" | Beklenen davranış; asgari tutar admin panelde |
| "Bu ödeme yöntemi kullanılamıyor" | Vitrinin açık yöntemleri değişmiş → §3.3 |
| "Bağlantı kurulamadı" | Sunucu erişilemiyor → §4 |

### 3.3 Ödeme yöntemi görünmüyor

Faz 1'de **online ödeme kapalıdır**; kapıda ödeme ve cari hesap çalışır.
Bu bir arıza değil, sunucudaki bir şalterdir. Sanal POS sözleşmesi
tamamlandığında yalnızca sunucu ayarı değişir — uygulama güncellemesi
gerekmez.

---

## 4. Sunucu cevap vermiyor

### 4.1 Ayakta mı

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  -H 'X-App-Id: website' -H 'X-App-Version: 1.0.0' \
  https://api.benimlezzetdunyam.com.tr/api/health
ssh root@62.238.102.197 'uptime && df -h / && free -m'
```

- **SSH bağlanmıyor** → sunucu kapalı veya ağ sorunu. Hetzner panelinden
  makineyi kontrol et; gerekirse panelden yeniden başlat.
- **Disk %90+ dolu** → §4.3
- **SSH tamam, HTTP yok** → §4.2

### 4.2 Servisler

Yığın Coolify tarafından yönetiliyor; `docker compose` ile elle
karışmak Coolify'ın durum kaydıyla çelişir.

```bash
ssh root@62.238.102.197
docker ps -a --format '{{.Names}}\t{{.Status}}' | grep -viE '^coolify'
docker logs --tail=100 "$(docker ps -a --format '{{.Names}}' | grep '^app-' | head -1)"
docker logs --tail=50  "$(docker ps -a --format '{{.Names}}' | grep '^web-' | head -1)"
docker logs --tail=50  "$(docker ps -a --format '{{.Names}}' | grep '^db-'  | head -1)"
```

Yeniden başlatma ve geri alma **Coolify arayüzünden** yapılır
(`http://62.238.102.197:8000` → BLD → Redeploy / önceki dağıtım).

### 4.3 Disk doldu

```bash
docker system df                     # ne yer yiyor
docker system prune -af --volumes=false   # DİKKAT: --volumes YOK, veri silinmez
sudo journalctl --vacuum-time=7d
docker exec "$(docker ps --format '{{.Names}}' | grep '^app-' | head -1)" du -sh storage/logs
```

`--volumes` bayrağını **asla ekleme**: veritabanı ve medya orada.

### 4.4 Dışarıdan 404 "page not found" geliyor

Bu **Traefik'in** 404'ü, bizim JSON hatamız değil — istek uygulamaya hiç
ulaşmıyor demektir. İki olağan şüpheli:

```bash
W=$(docker ps --format '{{.Names}}' | grep '^web-' | head -1)
docker inspect "$W" --format '{{json .Config.Labels}}' | grep -c traefik
```

- **0 etiket** → Coolify proxy yapılandırmasını uygulamamış. `web`
  servisinde `expose: ["80"]` var mı ve `SERVICE_FQDN_WEB_80` **çıplak
  anahtar** olarak mı yazılmış (değer atanmamış) kontrol et. İkisi de
  gerekli; biri eksikse etiket üretilmiyor.
- **Etiket var ama yine 404** → Coolify arayüzünden alan adını kontrol et
  ve yeniden dağıt.

### 4.4b TLS sertifikası alınamıyor

Alan adı alındıktan sonra geçerli. Neredeyse her zaman DNS sebebidir:

```bash
dig +short benimlezzetdunyam.com.tr
dig +short api.benimlezzetdunyam.com.tr
```

İkisi de `62.238.102.197` dönmeli. Dönmüyorsa DNS kaydı eksik veya henüz
yayılmamış — proxy'yi kurcalama, DNS'i düzelt ve bekle.

---

## 4.5 Bazı uçlar 500 dönüyor, bazıları çalışıyor

Neredeyse her zaman **dosya sahipliği**dir. Artisan bir komut root olarak
koşulmuşsa `storage` altında root'a ait dosyalar kalır; php-fpm
(`www-data`) onlara yazamaz ve yalnızca oraya yazmaya çalışan uçlar
patlar. Hata da loglanamadığı için sebebi görünmez.

```bash
A=$(docker ps --format '{{.Names}}' | grep '^app-' | head -1)
docker exec "$A" find storage bootstrap/cache ! -user www-data | head
docker exec "$A" chown -R www-data:www-data storage bootstrap/cache
```

Tekrarlamaması için artisan **her zaman** `-u www-data` ile koşulmalı.

## 4.6 Admin paneline girilemiyor: parola doğru, giriş ekranı gitmiyor

**Belirti.** `/admin/login`'de doğru e-posta ve parolayla giriş denenir,
sayfa yenilenir ve yine giriş ekranı gelir. Hata mesajı YOKTUR. Panel
görsel olarak da bozuk görünebilir.

**Sebep parola değildir.** Önce bunu ayırın:

```bash
A=$(docker ps -qf name=^app- | head -1)
S=https://api.benimlezzetdunyam.com.tr
T=$(curl -s -c /tmp/c -L $S/admin/login | grep -oE 'csrf-token" content="[^"]+"' | sed 's/.*content="//;s/"//')
curl -s -b /tmp/c -X POST $S/admin/login \
  -H "X-Requested-With: XMLHttpRequest" -H "X-IGNITER-REQUEST-HANDLER: onLogin" -H "X-CSRF-TOKEN: $T" \
  --data-urlencode "email=<eposta>" --data-urlencode "password=<parola>"
```

`X_IGNITER_REDIRECT` dönüyorsa **kimlik bilgileri doğrudur** ve arıza
tarayıcı tarafındadır: JavaScript çalışmıyor demektir.

**Asıl sebep: paket varlıkları yayımlanmamış.** Doğrulama:

```bash
docker exec "$A" ls /var/www/platform/public/vendor    # yoksa arıza budur
curl -s $S/admin/login | grep -oE 'src="[^"]+\.js"' | head -1   # bu adresi çekin
# içerik `require('jquery')` ile başlıyorsa DERLENMEMİŞ KAYNAK servis ediliyor
```

Zincir: `platform/.gitignore` `public/vendor`'ı dışlar (doğru — derleme
çıktısı repoda durmaz). Varlıkları yayımlayan tek betik `composer.json`
içindeki `post-update-cmd`'dir ve o kanca **yalnızca `composer update`**
ile çalışır; imaj `composer install` ile derlendiği için hiç tetiklenmez.
`public/vendor` boş kalınca TastyIgniter'ın birleştiricisi paketin
derlenmiş `public/js/app.js` dosyasını bulamaz ve `resources/js/app.js`
**kaynağını** servis eder. Kaynak `require('jquery')` ile başlar;
`require` tarayıcıda tanımlı değildir, dosya ilk satırda patlar, jQuery
ve TastyIgniter'ın AJAX katmanı hiç kurulmaz. Giriş formu
`data-request="onLogin"` ile çalıştığından JS'siz kalınca düz POST'a
düşer ve sunucu giriş sayfasını yeniden basar.

**Çözüm.** Kalıcı düzeltme `infra/platform/entrypoint.sh` içindedir ve her
açılışta koşar. Elle koşmak gerekirse:

```bash
docker exec -e HOME=/tmp "$A" php /var/www/platform/artisan vendor:publish --tag=laravel-assets --force
docker exec -e HOME=/tmp "$A" php /var/www/platform/artisan storage:link
docker exec "$A" chown -R www-data:www-data /var/www/platform/storage
```

Bu ikisi **root olarak** koşar: `public/` root'a aittir ve bunlar çalışma
anında yalnızca okunan derleme çıktılarıdır. Son satır şart — artisan
root'ken storage'a root'a ait dosya bırakır ve §4.5'teki sessiz 500'lere
yol açar.

`storage:link` aynı arızanın ikinci yüzüdür: medya diski
`storage/app/public`'tir ve bu bağlantı olmadan panelden yüklenen her
ürün görseli 404 döner.

## 4.7 Menü görselleri 500 veriyor: "Unable to write file at location: media/..."

**Belirti.** `GET /locations/{id}/menu` `SERVER_ERROR` dönüyor, ayrıntıda
`League\Flysystem\UnableToWriteFile` ve `media/attachments/public/.../thumb_*.jpg`
yazıyor. Panelde görsel görünüyor ama API patlıyor.

**Sebep.** Medya dosyaları `root` olarak oluşturulmuş. Küçük resmi (thumb) ise
php-fpm üretiyor ve o `www-data` olarak çalışıyor; root'un açtığı klasöre
yazamıyor. En sık nedeni `docker exec bld-app php artisan ...` komutunu
kullanıcı belirtmeden çalıştırmak — konteynerde varsayılan kullanıcı root.

**Çözüm.**

```bash
docker exec -u root bld-app \
  chown -R www-data:www-data /var/www/platform/storage/app/media
```

**Tekrarlamaması için.** Dosya yazan artisan komutlarını her zaman
`-u www-data` ile çalıştırın:

```bash
docker exec -u www-data bld-app php artisan veykemtu:menuGorselleri
docker exec -u www-data bld-app php artisan veykemtu:siteIceriginiAktar
```

## 5. Veri geri yükleme

**Tatbikatı yapılmamış yedek, yedek değildir.** Ayda bir bunu boş bir
ortamda dene.

```bash
ssh root@62.238.102.197
cd /opt/bld                          # yedek betikleri buraya klonlanır
ls -lh infra/backup/dumps/           # en son yedek hangisi

# GERİ YÜKLEMEDEN ÖNCE mevcut hâlin yedeğini al
./infra/backup/backup.sh --etiket=geri-yukleme-oncesi

./infra/backup/restore.sh infra/backup/dumps/<dosya>.sql.gz.enc
```

Geri yükleme **mevcut veritabanının üzerine yazar**. Emin değilsen önce
boş bir veritabanına aç ve içeriğini kontrol et.

---

## 6. Elektrik kesintisi sonrası

Kasa kendiliğinden toparlanmalı. Toparlanmazsa sırayla:

| Belirti | Kontrol |
|---|---|
| Makine hiç açılmadı | BIOS → "AC power on" = **Power On** olmalı |
| Açıldı, giriş ekranında bekliyor | `/etc/gdm3/custom.conf` → `AutomaticLoginEnable=true` |
| Giriş yaptı, uygulama yok | `systemctl --user status mutfakapp` |
| Uygulama açık ama pencere küçük | Uygulamayı yeniden başlat; tam ekran açılışta kurulur |

Hepsini tek komutla yeniden kur:

```bash
cd ~/Desktop/BLD && ./infra/kasa/setup.sh
```

Neyin eksik olduğunu **hiçbir şeyi değiştirmeden** görmek için:

```bash
./infra/kasa/setup.sh --kontrol
```

---

## 7. Dağıtım geri alma

Yeni sürüm sorun çıkardıysa:

Coolify her dağıtımı saklar: arayüz → BLD → **Deployments** → önceki
dağıtımda **Redeploy**. Elle git işlemi gerekmez.

**Migration geri alma:** `php artisan migrate:rollback` yalnızca son toplu
işlemi geri alır ve **veri kaybettirebilir**. Şema değişikliği içeren bir
sürümü geri alıyorsan önce yedek al.

---

## 8. Kime ne zaman haber verilir

| Durum | Aciliyet |
|---|---|
| Yazıcı basmıyor, kuyruk birikiyor | Servis içinde: hemen. Fişler kaybolmaz ama mutfak körleşir. |
| Sipariş mutfağa düşmüyor | **Hemen** — sipariş alınıyor ama hazırlanmıyor demektir |
| Müşteri sipariş veremiyor | **Hemen** — doğrudan ciro kaybı |
| Sunucu cevapsız | **Hemen** — her şey durur |
| Kasa canlılık uyarısı (admin panel) | Servis dışıysa aynı gün; servis içindeyse hemen |
| Disk %80 | Aynı hafta |
| TLS sertifikası 15 gün içinde bitiyor | Aynı hafta (Caddy normalde kendi yeniler) |
