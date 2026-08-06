import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { ImageResponse } from 'next/og';
import { fetchSiteContent } from '@/lib/api/site-content';

/**
 * Bağlantı paylaşım kartı (WhatsApp, LinkedIn, X, Slack…).
 *
 * Bu dosya yokken sitenin bağlantısını paylaşan kişi boş beyaz bir kutu
 * görüyordu. Kurumsal bir catering firması için ilk temasın çoğu böyle
 * oluyor: birileri linki bir gruba atıyor.
 *
 * ## Neden statik PNG değil, üretilen görsel?
 *
 * Marka adı ve sloganı artık panelden yönetiliyor. Statik bir dosya
 * koysaydık, firma adını panelden değiştirdiğinde paylaşım kartı eski adı
 * göstermeye devam ederdi ve kimse bunu fark etmezdi.
 *
 * ## Neden fotoğraf yok?
 *
 * Projede BLD'ye ait catering fotoğrafı yok. Stok fotoğraf koymak "bu bizim
 * mutfağımız" izlenimi yaratırdı. Kart, sitenin kendi tipografisi ve renk
 * dilinden kuruluyor; gerçek fotoğraflar geldiğinde arka plan olarak
 * eklenebilir.
 */
export const size = { width: 1200, height: 630 };
export const contentType = 'image/png';
export const alt = 'Benim Lezzet Dünyam — kurumsal catering ve toplu yemek hizmeti';

/**
 * Fontlar depodan okunuyor, ağdan değil.
 *
 * Font verilmediğinde satori Google Fonts'a çıkıyor ve bu ortamda
 * `Failed to load dynamic font for ğş` hatasıyla zaman aşımına uğradı —
 * yani Türkçe karakterler kutu olarak çizilecekti. Gerekçenin tamamı ve
 * lisans: `assets/fonts/README.md`.
 */
async function fonts() {
  const dir = join(process.cwd(), 'assets', 'fonts');

  const [regular, bold] = await Promise.all([
    readFile(join(dir, 'LiberationSans-Regular.ttf')),
    readFile(join(dir, 'LiberationSans-Bold.ttf')),
  ]);

  return [
    { name: 'Liberation Sans', data: regular, weight: 400 as const, style: 'normal' as const },
    { name: 'Liberation Sans', data: bold, weight: 700 as const, style: 'normal' as const },
  ];
}

export default async function OpengraphImage() {
  const [content, fontData] = await Promise.all([fetchSiteContent(), fonts()]);
  const { brand } = content;

  return new ImageResponse(
    <div
      style={{
        width: '100%',
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'space-between',
        padding: 72,
        // Kömür zemin: sitenin koyu bantlarıyla aynı. Paylaşım akışlarında
        // beyaz kartların arasında ayrışıyor.
        background: '#241f1b',
        fontFamily: 'Liberation Sans',
      }}
    >
      {/* Sıcaklık lekesi — sitedeki CTA bandının aynısı. */}
      <div
        style={{
          position: 'absolute',
          top: -160,
          right: -120,
          width: 520,
          height: 520,
          borderRadius: '50%',
          background: 'rgba(234,88,12,0.35)',
          filter: 'blur(90px)',
          display: 'flex',
        }}
      />

      <div style={{ display: 'flex', alignItems: 'center', gap: 20 }}>
        <div
          style={{
            width: 72,
            height: 72,
            borderRadius: 18,
            background: 'linear-gradient(135deg,#f97316,#c2410c)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: '#fff',
            fontSize: 24,
            fontWeight: 700,
            letterSpacing: -0.5,
          }}
        >
          BLD
        </div>
        <div style={{ display: 'flex', color: '#faf6ee', fontSize: 30, fontWeight: 600 }}>
          {brand.name}
        </div>
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 24 }}>
        <div
          style={{
            display: 'flex',
            color: '#faf6ee',
            fontSize: 66,
            fontWeight: 700,
            lineHeight: 1.15,
            letterSpacing: -1.5,
            maxWidth: 900,
          }}
        >
          {brand.tagline}
        </div>
        <div
          style={{
            display: 'flex',
            color: 'rgba(250,246,238,0.68)',
            fontSize: 28,
            maxWidth: 860,
          }}
        >
          {brand.description}
        </div>
      </div>

      <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
        <div style={{ display: 'flex', width: 44, height: 4, background: '#f97316' }} />
        <div style={{ display: 'flex', color: 'rgba(250,246,238,0.55)', fontSize: 24 }}>
          Kurumsal toplu yemek · Taşıma yemek · Organizasyon catering
        </div>
      </div>
    </div>,
    { ...size, fonts: fontData },
  );
}
