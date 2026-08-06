import { createHash, timingSafeEqual } from 'node:crypto';
import { revalidateTag } from 'next/cache';
import { NextResponse, type NextRequest } from 'next/server';

import { SITE_CONTENT_TAG } from '@/lib/api/site-content';

/**
 * İçerik tazeleme ucu.
 *
 * Admin panelinde "kaydet"e basıldığında buraya bir `POST` gelir ve site
 * içeriğinin ISR önbelleği anında düşer. Onsuz da içerik en geç 5 dakikada
 * tazelenir (`SITE_CONTENT_REVALIDATE_SECONDS`); bu uç o pencereyi sıfırlar.
 *
 * ## Neden sır zorunlu ve neden tanımsızsa uç KAPALI?
 *
 * `revalidateTag` ucuz bir çağrı değil: her tetikleme, sonraki ziyaretçinin
 * sayfayı sunucuda yeniden ürettirmesi demek. Sırsız bırakılırsa saniyede
 * yüzlerce istekle önbellek sürekli boşaltılıp site yavaşlatılabilir.
 *
 * Bu yüzden "sır tanımsızsa herkese açık" davranışı YOK: değişken yoksa uç
 * 503 döner ve neden kapalı olduğunu söyler. Sessizce açık kalan bir uç,
 * kapalı bir uçtan çok daha tehlikelidir.
 */
export const dynamic = 'force-dynamic';

/** İstek gövdesinden okunan sır alanının adı. */
type RevalidateBody = { secret?: unknown };

/**
 * Sabit süreli karşılaştırma.
 *
 * `===` doğru karakter sayısına göre farklı sürede döner ve sır uzunluğu ile
 * ön ekleri sızdırabilir. İki değeri de SHA-256'dan geçirmek hem uzunlukları
 * eşitliyor (`timingSafeEqual` eşit uzunluk şart koşar) hem karşılaştırmayı
 * içerikten bağımsız kılıyor.
 */
function secretMatches(provided: string, expected: string): boolean {
  const a = createHash('sha256').update(provided).digest();
  const b = createHash('sha256').update(expected).digest();
  return timingSafeEqual(a, b);
}

/** `Authorization: Bearer <sır>` başlığı veya JSON gövdedeki `secret` alanı. */
async function readSecret(request: NextRequest): Promise<string | null> {
  const header = request.headers.get('authorization');
  if (header) {
    const bearer = header.replace(/^Bearer\s+/i, '').trim();
    if (bearer.length > 0) return bearer;
  }

  try {
    const body: unknown = await request.json();
    if (typeof body === 'object' && body !== null) {
      const { secret } = body as RevalidateBody;
      if (typeof secret === 'string' && secret.trim().length > 0) return secret.trim();
    }
  } catch {
    // Gövde yoksa veya JSON değilse sorun değil; başlık zaten denendi.
  }

  return null;
}

export async function POST(request: NextRequest) {
  const expected = process.env.CONTENT_REVALIDATE_SECRET?.trim();

  if (!expected) {
    return NextResponse.json(
      {
        error: {
          code: 'REVALIDATE_DISABLED',
          message:
            'İçerik tazeleme ucu kapalı: CONTENT_REVALIDATE_SECRET tanımlı değil. ' +
            'Sır tanımlanana kadar içerik yalnızca ISR penceresi dolduğunda tazelenir.',
        },
      },
      { status: 503, headers: { 'Cache-Control': 'no-store' } },
    );
  }

  const provided = await readSecret(request);

  if (!provided || !secretMatches(provided, expected)) {
    return NextResponse.json(
      { error: { code: 'UNAUTHORIZED', message: 'Geçersiz tazeleme sırrı.' } },
      { status: 401, headers: { 'Cache-Control': 'no-store' } },
    );
  }

  revalidateTag(SITE_CONTENT_TAG);

  return NextResponse.json(
    { revalidated: true, tag: SITE_CONTENT_TAG, at: new Date().toISOString() },
    { headers: { 'Cache-Control': 'no-store' } },
  );
}
