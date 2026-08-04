# Mutfak kasası kurulumu (MSI / Ubuntu 24.04)

**`setup.sh` `I-04` görevinde yazılır.** Şu an burada iki dosya var:

| Dosya | Durum |
|---|---|
| `99-thermal-printer.rules` | **Yer tutucu** — VID/PID Gün 1'de doldurulacak |
| `mutfakapp.service` | Hazır |
| `setup.sh` | `I-04`'te yazılacak |

Spesifikasyon: [`docs/08-kurulum-deploy.md`](../../docs/08-kurulum-deploy.md) §2

## Sıra önemli

1. **Önce yazıcıyı doğrula** (Gün 1, `K` hattı) — VID/PID olmadan udev kuralı
   anlamsız. Bkz. `99-thermal-printer.rules` içindeki yönerge.
2. Sonra `setup.sh` yazılır ve kasada koşulur.
3. En son `docs/08` §2.4'teki 7 maddelik kabul listesi tek tek işaretlenir.

## Kabul listesi (7/7 olmadan kasa teslim edilmez)

- [ ] Elektrik kesilip gelince makine kendiliğinden açılıyor (BIOS: AC power on)
- [ ] Otomatik giriş yapılıyor, parola sorulmuyor
- [ ] Uygulama kendiliğinden açılıyor ve tam ekran
- [ ] Ekran hiç kararmıyor/kilitlenmiyor
- [ ] Test fişi basılıyor, Türkçe karakterler doğru
- [ ] İnternet kesilip gelince uygulama kendini toparlıyor
- [ ] Uygulama zorla kapatılınca 5 saniyede yeniden başlıyor
