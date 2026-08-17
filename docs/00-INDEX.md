# Doküman İndeksi

Ajanlar bu sırayla okur. `AGENTS.md` (repo kökü) her zaman ilk sıradadır.

| # | Dosya | Ne anlatır | Kim okur |
|---|---|---|---|
| — | `../AGENTS.md` | Ajan çalışma kuralları, altın kurallar, iş kolları | **Herkes, ilk** |
| 00 | `00-genel-bakis.md` | Problem, roller, kapsam sınırı, uçtan uca akış, sözlük | Herkes |
| 01 | `01-mimari.md` | Sistem şeması, bileşen sınırları, ADR'ler, repo yapısı | Herkes |
| 02 | `02-veri-modeli.md` | Tablolar, sipariş durum makinesi, üretim listesi, günlük menü şeması | Kol A, B |
| 03 | `03-api-sozlesmesi.md` | **Tek doğruluk kaynağı** — tüm uçlar, kimlik, WebSocket | Herkes |
| — | `openapi.yaml` | **Normatif sözleşme** (OpenAPI 3.1) — istemci modelleri bundan üretilir | Herkes |
| 04 | `04-platform.md` | TastyIgniter kurulumu, extension yapısı, yazılacak modüller | Kol A |
| 05 | `05-mutfakapp.md` | KDS: Ubuntu, ESC/POS, kuyruk, kiosk, dayanıklılık | Kol B |
| 06 | `06-website.md` | Next.js müşteri sitesi | Kol C |
| 07 | `07-musteriapp.md` | Flutter müşteri uygulaması (Android + iOS) | Kol C |
| 08 | `08-kurulum-deploy.md` | Hetzner, Docker, MSI kasa kurulumu, CI/CD | Kol D |
| 09 | `09-gorev-plani.md` | 7 günlük paralel plan, kritik yol, kapsam kesme sırası | Herkes |
| 10 | `10-test-kabul.md` | Kabul senaryoları — "bitti" tanımı | Herkes |
| 11 | `11-yol-haritasi.md` | Sonraki faz: Maps, bölgeler, kampanya, kupon | Herkes |
| — | `BILINMEYENLER.md` | Açık sorular, karar bekleyen iş soruları | **Herkes, her gün** |
| — | `KDS-GUNCELLE.md` | Mutfak kasasına sürüm yayınlama prosedürü | Kol D |
| — | `RUNBOOK.md` | Tek seferlik dağıtım adımları (cari arşivi vb.) | Kol D |
| — | `control/` | Kontrol Merkezi ↔ sunucu API sözleşmesi, alan başına bir dosya | Kol D, KM |
| — | `contract/sales-rules.cases.json` | Stok aritmetiğinin altın veri kümesi — üç dil onu okur | Herkes |
| — | `../yapılacaklar.md` | Sahibinin istek listesi + **tur günlükleri**: ne yapıldı, ne bilerek bırakıldı | Herkes |

## Çelişki kuralı

Kod ile doküman çelişirse **doküman kazanır**, kod düzeltilir.
Dokümanlar birbiriyle çelişirse **`03-api-sozlesmesi.md` kazanır**.
Sözleşme değişecekse önce doküman güncellenir, sonra kod yazılır.

**Kuralın sınırı — 17.08.2026'da öğrenildi.** Bu kural bir KURAL çeliştiğinde
işler: "kesim saati kaça kadar", "hangi alan yazılabilir", "sıra nedir".
Çelişen şey bir OLGU ise (doküman "şu tablo var" diyor ama tablo düşürülmüş,
doküman "şu test zorunlu" diyor ama test silinmiş) **kod kazanır ve doküman
düzeltilir** — aksi hâlde uzlaştırma, kaldırılmış bir şeyi geri kurmaya
çalışmak olurdu.

Ayrım şudur: kural bir NİYETTİR ve niyetin sahibi dokümandır; olgu bir
DURUMDUR ve durumun sahibi koddur.

**Kaldırılan şey silinmez, "kaldırıldı" diye işaretlenir.** Bir bölümü sessizce
çıkarmak, o şemayı arayan kişiyi neden bulamadığını hiç öğrenemez hâlde
bırakır (`02-veri-modeli.md` §7.2, `10-test-kabul.md` S9b, `07-musteriapp.md`
§7 aynı kalıbı izler).
