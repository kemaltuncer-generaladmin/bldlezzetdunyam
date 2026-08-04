# RUNBOOK — Arıza Müdahale

Bu belge servis sırasında, telaşlıyken okunmak için yazıldı. Her bölüm
**önce en olası sebeple** başlar ve her adım tek bir komuttur.

**Altın kural:** sipariş verisi kaybolmaz. Mutfak ekranı düşse bile
siparişler sunucuda durur; admin panelinden görülebilir ve elle basılabilir.
Panik etmeden önce bunu hatırla.

| Hızlı erişim | |
|---|---|
| Admin panel | `https://api.benimlezzetdunyam.com.tr/admin` |
| Sunucu | `ssh deploy@62.238.102.197` |
| Kasa | mutfaktaki MSI, kullanıcı `mutfak` |
| Yazıcı | `/dev/thermal0` → USB `0483:5720` |

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
ssh deploy@62.238.102.197 \
  'cd /opt/bld && docker compose exec -T app php artisan veykemtu:kds --new="Mutfak Kasası"'
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
curl -s -o /dev/null -w '%{http_code}\n' https://api.benimlezzetdunyam.com.tr/api/health
ssh deploy@62.238.102.197 'uptime && df -h / && free -m'
```

- **SSH bağlanmıyor** → sunucu kapalı veya ağ sorunu. Hetzner panelinden
  makineyi kontrol et; gerekirse panelden yeniden başlat.
- **Disk %90+ dolu** → §4.3
- **SSH tamam, HTTP yok** → §4.2

### 4.2 Servisler

```bash
ssh deploy@62.238.102.197
cd /opt/bld
docker compose ps                    # hangisi ayakta değil
docker compose logs --tail=100 app   # PHP hataları
docker compose logs --tail=50 caddy  # TLS / yönlendirme
docker compose logs --tail=50 db     # veritabanı
```

Tek servis düşmüşse:

```bash
docker compose up -d <servis>
```

Hepsi karışmışsa (**veri kaybolmaz**, veritabanı ayrı bir birimdedir):

```bash
docker compose down && docker compose up -d
```

### 4.3 Disk doldu

```bash
docker system df                     # ne yer yiyor
docker system prune -af --volumes=false   # DİKKAT: --volumes YOK, veri silinmez
sudo journalctl --vacuum-time=7d
du -sh /opt/bld/platform/storage/logs/*
```

`--volumes` bayrağını **asla ekleme**: veritabanı ve medya orada.

### 4.4 TLS sertifikası alınamıyor

Caddy sürekli yeniden deniyorsa neredeyse her zaman DNS sebebidir:

```bash
dig +short benimlezzetdunyam.com.tr
dig +short api.benimlezzetdunyam.com.tr
```

İkisi de `62.238.102.197` dönmeli. Dönmüyorsa DNS kaydı eksik veya henüz
yayılmamış — Caddy'yi kurcalama, DNS'i düzelt ve bekle.

---

## 5. Veri geri yükleme

**Tatbikatı yapılmamış yedek, yedek değildir.** Ayda bir bunu boş bir
ortamda dene.

```bash
ssh deploy@62.238.102.197
cd /opt/bld
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

```bash
ssh deploy@62.238.102.197
cd /opt/bld
git log --oneline -5                 # hangi sürümdeyiz
git checkout <önceki-commit>
docker compose build app web && docker compose up -d
docker compose exec app php artisan migrate --force
```

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
