# Görsellerin kaynağı

Bu klasördeki fotoğrafların **hiçbiri BLD'ye ait değildir.** Hepsi
[Unsplash](https://unsplash.com/license) lisanslı stok fotoğraftır: ticari
kullanımda ücretsiz, atıf zorunlu değil.

## Neden stok fotoğraf var?

Sitenin önceki sürümünde hiç fotoğraf yoktu; gerekçe "BLD'nin kendi fotoğrafı
olmadan stok fotoğraf koymak 'bu bizim mutfağımız' izlenimi yaratır" idi.
Gerekçe doğru ama sonucu, yemek satan bir sitenin tek bir yemek göstermemesi
oldu.

Bu yüzden kural şu hâle geldi: **fotoğraf, iddia taşımayacak biçimde
kullanılır.** Hiçbir başlık, alt metin veya yazı "kendi mutfağımızda çekildi",
"ekibimiz" ya da "tesisimiz" demez. Fotoğraflar yemeğin ve hizmetin ne olduğunu
gösterir, kimin yaptığını değil.

**Menü ürünü fotoğrafları ayrı bir kural izler:** her dosya gerçekten o yemeğin
fotoğrafıdır, benzerinin değil. Müşteri sipariş verirken gördüğü şeyle gelen
şey ayrı olamaz. Elimizde o yemeğin doğru fotoğrafı yoksa ürün görselsiz kalır
ve yer tutucu gösterilir.

## Değiştirmek gerektiğinde

| Nerede                             | Nasıl değişir                                                                                                                              |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| Bu klasördeki kurumsal fotoğraflar | Dosyayı aynı adla değiştirin, kod dokunulmaz. Oranları koruyun (aşağıda).                                                                  |
| Menü ürünü fotoğrafları            | **Bu klasörde değil.** Admin panelinden ürünün kendi görseli olarak yüklenir; ilk dolgu `php artisan veykemtu:menuGorselleri` ile yapılır. |

Gerçek fotoğraflar geldiğinde bu klasör tamamen değişmelidir. Stok fotoğraf
geçici bir çözümdür; bir catering firmasının kendi yemeğini göstermesi her
zaman daha iyidir.

## Oranlar

Dosyalar ekranda `object-cover` ile yerleşir, yani yanlış oranda bir dosya
kırpılır — bozulmaz ama konu kenarda kalabilir.

| Ön ek                                                 | Oran | Genişlik |
| ----------------------------------------------------- | ---- | -------- |
| `hero-`, `mutfak-`, `servis-`, `kahvalti-`, `kalite-` | 3:2  | 1400 px  |
| `hizmet-`, `yazi-`                                    | 16:9 | 1600 px  |
| `sektor-`, `menu-`                                    | 4:3  | 1000 px  |
| `sofra-mezze`                                         | 1:1  | 1000 px  |
| `izgara-tabak`, `mutfak-sef`                          | 4:5  | 900 px   |

Hepsi WebP, kalite 76. Toplam ~2,4 MB.
