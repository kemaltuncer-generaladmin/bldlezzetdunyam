# Fontlar — nasıl üretildi

Buradaki `.ttf` dosyaları **alt kümelenmiş** (subset) sürümlerdir; yayınlanan
fontun kendisi değildir. Yeniden üretilebilir olsun diye komut aşağıda.

| Dosya | Kaynak | Boyut |
|---|---|---|
| `Inter-Variable.ttf` | Inter 4.x variable (`opsz`, `wght`) | 876.576 → **397.364** bayt |
| `SourceSerif4-Variable.ttf` | Google Fonts `ofl/sourceserif4/SourceSerif4[opsz,wght].ttf` | 1.209.508 → **439.372** bayt |

Sora **kaldırıldı**: başlık ailesi Source Serif 4 oldu (`BldFontFamily.display`)
ve Sora'da Türk lirası işareti (`₺`) bile yoktu.

Toplam paket: 987.976 → 836.736 bayt (**−15,3 %**), üstelik gerçek bir serif
kazanılarak.

## Ne atıldı

1. **Yunanca, Kiril ve tam Vietnamca.** Uygulama Türkçe-only. Inter'in glif
   sayısı 2.933 → 1.742, cmap girdisi 2.849 → 1.003'e indi.
2. **`wght` ekseninin 400–700 dışı.** Tasarım ölçeği yalnız 400 / 600 / 700
   kullanıyor (`BldTextScale`); 100–300 ve 800–900 hiçbir yerde çağrılmıyordu.
   Bu tek başına Inter'de ~112 KB, serifte ~145 KB.

`opsz` ekseni **DURUYOR**. Optik boyut, Source Serif 4'ün seçilme
gerekçesiydi: aynı dosya 11 punto etikette de 44 punto başlıkta da doğru
kalınlıkta çiziliyor. Web'de `font-optical-sizing: auto` bunu kendiliğinden
uyguluyor; Flutter uygulamıyor — mobilde işe yaraması için `TextStyle`'a
`fontVariations: [FontVariation('opsz', <punto>)]` eklenmesi gerekiyor.

## Komut

Standart araç `pyftsubset` (fonttools). Aynı sonucu verir:

```sh
UNICODES="U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,\
U+0304,U+0308,U+0329,U+2000-206F,U+20AC,U+2122,U+2191,U+2193,U+2212,U+2215,\
U+FEFF,U+FFFD,U+0100-02BA,U+02BD-02C5,U+02C7-02CC,U+02CE-02D7,U+02DD-02FF,\
U+1D00-1DBF,U+1E00-1E9F,U+1EF2-1EFF,U+2020,U+20A0-20AB,U+20AD-20C0,U+2113,\
U+2C60-2C7F,U+A720-A7FF,U+20BA"

pyftsubset Inter-Variable-FULL.ttf \
  --output-file=Inter-Variable.ttf \
  --unicodes="$UNICODES" \
  --instance='wght=400:700' \
  --layout-features='*' \
  --flavor=  # düz TTF; Flutter woff2 okumaz

pyftsubset SourceSerif4-FULL.ttf \
  --output-file=SourceSerif4-Variable.ttf \
  --unicodes="$UNICODES" \
  --instance='wght=400:700' \
  --layout-features='*'
```

Bu depoda `fonttools` kurulu değildi; aynı iş `subset-font` (harfbuzz'ın WASM
derlemesi, `hb-subset` ile aynı motor) ile yapıldı:

```sh
npm install subset-font
node -e "…"   # unicode aralıkları yukarıdakiyle birebir aynı,
              # variationAxes: { wght: { min: 400, max: 700 } }
```

## Lisans

İkisi de SIL Open Font License 1.1: `Inter-OFL.txt`, `SourceSerif4-OFL.txt`.
OFL alt kümelemeye izin verir; lisans metninin fontla birlikte dağıtılması
şarttır, bu yüzden bu dosyalar assets içinde duruyor.

## Doğrulama

Alt küme değiştirildiğinde şu üçü kontrol edilir:

- `şŞğĞıİçÇöÖüÜ₺€` karakterlerinin hepsi cmap'te olmalı.
- `fvar` tablosu (değişken eksenler) korunmuş olmalı — kaybolursa
  `FontWeight.w600` diye bir şey kalmaz, her metin tek kalınlıkta çıkar.
- Dosya `.ttf` olmalı; Flutter `woff2` okumaz.
