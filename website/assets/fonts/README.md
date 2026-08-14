# Paylaşım kartı fontları

`app/opengraph-image.tsx` bu dosyaları kullanır. `app/apple-icon.tsx` metin
içermiyor, font okumuyor.

## Neden depoda duruyorlar?

`next/og` (satori) font verilmediğinde çalışma anında Google Fonts'tan font
**indirmeye çalışıyor**. Bu iki soruna yol açıyordu:

1. **Ağ erişimi olmayan/kısıtlı sunucuda kart bozuluyor.** Derleme sırasında
   `Failed to load dynamic font for ğş` hatası alındı ve Türkçe karakterler
   kutu olarak çizilecekti. Paylaşım kartı Türkçe metinden oluşuyor; "ğ" ve
   "ş" kaybolunca kart kullanılamaz hâle gelir.
2. **Her istekte dış bağımlılık.** Kartı üretmek Google'ın sunucusunun ayakta
   olmasına bağlı kalıyordu.

Font dosyayla geldiğinde satori ağa hiç çıkmıyor.

## Neden Liberation Sans?

Türkçe (`ı İ ğ Ğ ş Ş ç ö ü`) tam kapsanıyor ve boyutu makul: 410 kB regular,
414 kB bold. Sistemdeki alternatif DejaVu Sans 760 kB'dı.

**WOFF2 KULLANILAMAZ** — satori yalnızca TTF/OTF/WOFF okuyor. Sitenin kendi
fontları (Inter, Source Serif 4) `next/font` üzerinden WOFF2 olarak geliyor,
bu yüzden onlar burada kullanılamıyor.

## Lisans

SIL Open Font License 1.1 — `LICENSE.txt`. Gömülmesi ve dağıtılması serbest.
