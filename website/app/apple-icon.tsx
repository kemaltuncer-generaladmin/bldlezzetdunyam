import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { ImageResponse } from 'next/og';

/**
 * iOS ana ekran simgesi (180×180).
 *
 * `icon.svg` iOS'ta kullanılmıyor: Safari "ana ekrana ekle" dendiğinde bu
 * boyutta bir PNG arıyor, bulamazsa sayfanın ekran görüntüsünü kırpıp koyuyor
 * — genellikle okunmaz bir sonuç çıkıyor.
 *
 * ## Üç kural
 *
 * 1. **Opak.** Alfa kanalı olan bir apple-touch-icon iOS'ta siyah zemine
 *    bileşiklenir; şeffaf bıraktığımız her piksel siyah çıkar.
 * 2. **Yuvarlama yok.** iOS köşeleri kendi maskeliyor. Burada da
 *    yuvarlarsaydık maskenin dışında kalan köşelerde beyaz üçgenler kalırdı.
 * 3. **Amblem kanvasın ~%72'si.** Maskable Android ikonundaki %60 burada
 *    fazla küçük duruyor (iOS kırpması çok daha yumuşak).
 *
 * Amblem plakasız PNG'den geliyor: plakalı `icon-512.png` kullanılsaydı
 * kendi çizdiğimiz kare zeminin içinde ikinci bir yuvarlak köşe görünürdü.
 */
export const size = { width: 180, height: 180 };
export const contentType = 'image/png';

export default async function AppleIcon() {
  const emblem = await readFile(join(process.cwd(), 'public', 'emblem.png'));

  return new ImageResponse(
    <div
      style={{
        width: '100%',
        height: '100%',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        // Logonun kendi gradyanı: brand800 → brand500.
        background: 'linear-gradient(135deg,#941C01,#DD5D02)',
      }}
    >
      {/* satori yalnızca <img> çiziyor; `next/image` bir ImageResponse ağacında çalışmaz. */}
      <img
        alt=""
        src={`data:image/png;base64,${emblem.toString('base64')}`}
        width={89}
        height={130}
      />
    </div>,
    size,
  );
}
