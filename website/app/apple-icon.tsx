import { ImageResponse } from 'next/og';

/**
 * iOS ana ekran simgesi (180×180).
 *
 * `icon.svg` iOS'ta kullanılmıyor: Safari "ana ekrana ekle" dendiğinde bu
 * boyutta bir PNG arıyor, bulamazsa sayfanın ekran görüntüsünü kırpıp koyuyor
 * — genellikle okunmaz bir sonuç çıkıyor.
 *
 * Motif `icon.svg` ile aynı; orada neden harf değil de servis kapağı
 * kullanıldığının gerekçesi o dosyada.
 */
export const size = { width: 180, height: 180 };
export const contentType = 'image/png';

export default function AppleIcon() {
  return new ImageResponse(
    <div
      style={{
        width: '100%',
        height: '100%',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        // iOS köşeleri kendi yuvarlıyor; burada yuvarlarsak köşelerde
        // beyaz üçgenler kalıyor.
        background: 'linear-gradient(135deg,#f97316,#c2410c)',
      }}
    >
      <svg width="120" height="120" viewBox="0 0 64 64">
        <circle cx="32" cy="17" r="3.6" fill="#fff" />
        <path d="M13 41a19 19 0 0 1 38 0z" fill="#fff" />
        <rect x="8" y="42.5" width="48" height="6" rx="3" fill="#fff" />
      </svg>
    </div>,
    size,
  );
}
