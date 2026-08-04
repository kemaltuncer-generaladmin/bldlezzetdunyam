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
| Türkçe karakter | Kod sayfası **PC857** (`1B 74 0D`) — metin bu tabloya çevrilir |

**Türkçe karakter zorunluluğu:** ç ğ ı ö ş ü İ Ş Ğ Ü Ö Ç doğru basılmalı. UTF-8 metin PC857'ye çevrilir; çeviri tablosu `packages/core/lib/escpos/pc857.dart`. Bu bir golden test ile doğrulanır.

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

| Olay | Fiş |
|---|---|
| Yeni sipariş listeye geldi | Mutfak fişi (otomatik) |
| Durum `hazir` yapıldı | Müşteri fişi (otomatik) |

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

**Uygulama davranışı:** açılışta tam ekran (`window_manager` ile fullscreen + always on top), `Esc` ile çıkılmaz, kapatma yalnızca ayarlar → gizli menü (uzun basma + PIN).

## 7. İlk kurulum akışı (eşleme)

1. Uygulama ilk açılışta "Sunucu adresi" + "Eşleme kodu" ekranı gösterir.
2. Yönetici admin panelden cihaz ekler, 12 karakterlik kod alır.
3. Kod girilir → `POST /api/kitchen/pair` → token alınır, `shared_preferences`'a yazılır.
4. Sonraki açılışlarda doğrudan sipariş ekranı gelir.
5. Token iptal edilirse (`403 DEVICE_REVOKED`) uygulama eşleme ekranına döner.

## 8. Ayarlar ekranı (gizli, PIN korumalı)

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
