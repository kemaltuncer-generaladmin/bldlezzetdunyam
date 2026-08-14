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
 * Fontlar ve amblem depodan okunuyor, ağdan değil.
 *
 * Font verilmediğinde satori Google Fonts'a çıkıyor ve bu ortamda
 * `Failed to load dynamic font for ğş` hatasıyla zaman aşımına uğradı —
 * yani Türkçe karakterler kutu olarak çizilecekti. Gerekçenin tamamı ve
 * lisans: `assets/fonts/README.md`.
 *
 * Amblem PLAKASIZ sürümden geliyor (`public/emblem.png`). Plakalı
 * `icon-512.png` kullanılsaydı koyu kartın ortasında turuncu bir kare
 * belirir, kartın kendi zemini iki katmana bölünürdü.
 */
async function assets() {
  const fontDir = join(process.cwd(), 'assets', 'fonts');

  const [regular, bold, emblem] = await Promise.all([
    readFile(join(fontDir, 'LiberationSans-Regular.ttf')),
    readFile(join(fontDir, 'LiberationSans-Bold.ttf')),
    readFile(join(process.cwd(), 'public', 'emblem.png')),
  ]);

  return {
    fonts: [
      { name: 'Liberation Sans', data: regular, weight: 400 as const, style: 'normal' as const },
      { name: 'Liberation Sans', data: bold, weight: 700 as const, style: 'normal' as const },
    ],
    emblem: `data:image/png;base64,${emblem.toString('base64')}`,
  };
}

export default async function OpengraphImage() {
  const [content, { fonts, emblem }] = await Promise.all([fetchSiteContent(), assets()]);
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
        // Koyu temanın zemini (neutral950). Paylaşım akışlarında beyaz
        // kartların arasında ayrışıyor.
        background: '#1B120C',
        fontFamily: 'Liberation Sans',
      }}
    >
      {/*
        Radyal parıltı — brand700. `radial-gradient` yerine bulanıklaştırılmış
        daire: satori'nin gradyan çözümleyicisi bu boyutta bantlanma
        üretiyordu, blur filtresi düzgün bir düşüş veriyor.
      */}
      <div
        style={{
          position: 'absolute',
          top: -180,
          right: -140,
          width: 620,
          height: 620,
          borderRadius: '50%',
          background: 'rgba(168,50,10,0.55)',
          filter: 'blur(110px)',
          display: 'flex',
        }}
      />

      <div style={{ display: 'flex', alignItems: 'center', gap: 24 }}>
        {/* satori yalnızca <img> çiziyor; `next/image` bir ImageResponse ağacında çalışmaz. */}
        <img alt="" src={emblem} width={62} height={90} />
        <div style={{ display: 'flex', color: '#F2EBE3', fontSize: 30, fontWeight: 700 }}>
          {brand.name}
        </div>
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 24 }}>
        <div
          style={{
            display: 'flex',
            color: '#F2EBE3',
            fontSize: 66,
            fontWeight: 700,
            lineHeight: 1.15,
            letterSpacing: -1.5,
            maxWidth: 900,
          }}
        >
          {brand.tagline}
        </div>
        <div style={{ display: 'flex', color: '#D2C3B4', fontSize: 28, maxWidth: 860 }}>
          {brand.description}
        </div>
      </div>

      <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
        {/* brand400: koyu zeminde marka rengi olarak okunabilen adım. */}
        <div style={{ display: 'flex', width: 44, height: 4, background: '#E8863F' }} />
        <div style={{ display: 'flex', color: '#A28A78', fontSize: 24 }}>
          Kurumsal toplu yemek · Taşıma yemek · Organizasyon catering
        </div>
      </div>
    </div>,
    { ...size, fonts },
  );
}
