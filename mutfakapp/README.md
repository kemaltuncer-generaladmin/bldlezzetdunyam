# mutfakapp — Mutfak Ekranı (KDS)

**Bu klasör `K-01` görevinde doldurulur.** Şu an bilinçli olarak boştur.

Spesifikasyon: [`docs/05-mutfakapp.md`](../docs/05-mutfakapp.md)

## Değişmez kısıtlar

- **Hedef platform yalnızca Linux desktop.** `flutter create --platforms=linux`
  ile oluşturulur. `mutfakapp/android/` **oluşturulmaz**, Android'e özgü hiçbir
  paket eklenmez (ADR-04). `.gitignore` bunu ayrıca engeller.
- Tüm ağ çağrıları `packages/api_client` üzerinden. Doğrudan `dio`/`http`
  çağrısı bulunmaz.
- Veri katmanı `OrderSource` arayüzünü uygular (`packages/api_client`);
  Faz 1 `PollingOrderSource`, Faz 1.5 `WebSocketOrderSource`.

## Gün 1'in ilk işi — donanım doğrulaması, ertelenemez

Kod yazmadan önce yazıcı fiziksel olarak doğrulanır:

```bash
lsusb                     # VID:PID'yi not al
ls -l /dev/usb/
echo -e "Test\n\n\n\x1D\x56\x42\x00" > /dev/usb/lp0
```

Fiş çıkmıyorsa **dur ve bildir** — bu projenin en büyük tek donanım riskidir
(`docs/09-gorev-plani.md` §8). Çıkıyorsa VID/PID
`infra/kasa/99-thermal-printer.rules` dosyasına yazılır.

## Backend'i bekleme

```bash
docker compose -f infra/docker-compose.dev.yml up mock-api
```

Eşleme kodu: `BLD1-MOCK` — ayrıntı: [`infra/mock/README.md`](../infra/mock/README.md)
