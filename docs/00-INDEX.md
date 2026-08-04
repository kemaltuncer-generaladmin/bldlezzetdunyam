# Doküman İndeksi

Ajanlar bu sırayla okur. `AGENTS.md` (repo kökü) her zaman ilk sıradadır.

| # | Dosya | Ne anlatır | Kim okur |
|---|---|---|---|
| — | `../AGENTS.md` | Ajan çalışma kuralları, altın kurallar, iş kolları | **Herkes, ilk** |
| 00 | `00-genel-bakis.md` | Problem, roller, kapsam sınırı, uçtan uca akış, sözlük | Herkes |
| 01 | `01-mimari.md` | Sistem şeması, bileşen sınırları, ADR'ler, repo yapısı | Herkes |
| 02 | `02-veri-modeli.md` | Tablolar, sipariş durum makinesi, üretim listesi | Kol A, B |
| 03 | `03-api-sozlesmesi.md` | **Tek doğruluk kaynağı** — tüm uçlar, kimlik, WebSocket | Herkes |
| 04 | `04-platform.md` | TastyIgniter kurulumu, extension yapısı, yazılacak modüller | Kol A |
| 05 | `05-mutfakapp.md` | KDS: Ubuntu, ESC/POS, kuyruk, kiosk, dayanıklılık | Kol B |
| 06 | `06-website.md` | Next.js müşteri sitesi | Kol C |
| 07 | `07-musteriapp.md` | Flutter Android müşteri uygulaması | Kol C |
| 08 | `08-kurulum-deploy.md` | Hetzner, Docker, MSI kasa kurulumu, CI/CD | Kol D |
| 09 | `09-gorev-plani.md` | 7 günlük paralel plan, kritik yol, kapsam kesme sırası | Herkes |
| 10 | `10-test-kabul.md` | Kabul senaryoları — "bitti" tanımı | Herkes |
| — | `BILINMEYENLER.md` | Açık sorular, karar bekleyen iş soruları | **Herkes, her gün** |

## Çelişki kuralı

Kod ile doküman çelişirse **doküman kazanır**, kod düzeltilir.
Dokümanlar birbiriyle çelişirse **`03-api-sozlesmesi.md` kazanır**.
Sözleşme değişecekse önce doküman güncellenir, sonra kod yazılır.
