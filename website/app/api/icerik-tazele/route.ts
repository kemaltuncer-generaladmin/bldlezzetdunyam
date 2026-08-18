import { createHash, timingSafeEqual } from 'node:crypto';
import { revalidateTag } from 'next/cache';
import { NextResponse, type NextRequest } from 'next/server';

import { CATALOG_TAG } from '@/lib/api/catalog';
import { DAILY_MENU_TAG } from '@/lib/api/daily-menu';
import { dropFreshCache } from '@/lib/api/fresh-cache';
import { SITE_CONTENT_TAG } from '@/lib/api/site-content';

/**
 * ÖNBELLEK TAZELEME UCU.
 *
 * Admin panelinde "kaydet"e basıldığında buraya bir `POST` gelir ve ilgili
 * önbellek anında düşer. Onsuz da içerik ISR penceresi dolunca tazelenir; bu
 * uç o pencereyi sıfırlar.
 *
 * ## Sözleşme
 *
 * ```
 * POST {SITE_REVALIDATE_URL}
 * Authorization: Bearer {SITE_REVALIDATE_SECRET}
 * {"tag": "daily-menu"}
 * ```
 *
 * `tag` İSTEĞE BAĞLI ve yokluğunda `site-content` varsayılıyor — panelin eski
 * çağrıları (gövdesiz `POST`) bozulmadan çalışmaya devam etsin diye
 * (`Veykemtu\BridgeApi\Services\SiteRevalidator`).
 *
 * ## Neden BEYAZ LİSTE
 *
 * Serbest etiket kabul etmek, isteği atabilen herkesin dilediği önbelleği
 * boşaltmasına açık kapı bırakır. `revalidateTag` ucuz bir çağrı değil: her
 * tetikleme, sonraki ziyaretçinin sayfayı sunucuda yeniden ürettirmesi
 * demek. Sır zaten kapıyı tutuyor ama sır sızarsa zararın büyüklüğünü
 * sınırlayan şey bu liste.
 *
 * ## Neden sır tanımsızsa uç KAPALI
 *
 * "Sır tanımsızsa herkese açık" davranışı YOK: değişken yoksa uç 503 döner ve
 * neden kapalı olduğunu söyler. Sessizce açık kalan bir uç, kapalı bir uçtan
 * çok daha tehlikelidir.
 *
 * ## ETİKET TEK BAŞINA YETMEZ — okuyun
 *
 * `daily-menu` etiketi yalnızca **ISR ile** okunan yüzeylere yapışıyor
 * (`lib/api/daily-menu.ts` → `cacheFor`): ana sayfadaki "bugün mutfakta"
 * bandı ve gün seçici şeridi. Sipariş kararı veren yollar (menü sayfası,
 * sepet, ödeme, sepete ekleme) menüyü `no-store` okuyor; onlar Next.js'in
 * Data Cache'inde HİÇ DURMUYOR, dolayısıyla `revalidateTag` onlara
 * dokunmaz.
 *
 * O yolların önünde duran tek pencere `lib/api/fresh-cache.ts`'teki iki
 * saniyelik mikro-önbellek. Bu yüzden her kabul edilen tetiklemede O DA
 * düşürülüyor. Aksi hâlde tetikleme, tam da kaçınılmak istenen şeye
 * dönerdi: hiçbir şey yapmayan bir çağrı.
 */
export const dynamic = 'force-dynamic';

/**
 * Tazelenebilecek etiketler.
 *
 * Üçü de bu depodaki `export`lardan geliyor, elle yazılmıyor: etiket adı
 * değiştiğinde beyaz liste sessizce eskiyemez.
 */
const ALLOWED_TAGS = [SITE_CONTENT_TAG, CATALOG_TAG, DAILY_MENU_TAG] as const;

type AllowedTag = (typeof ALLOWED_TAGS)[number];

function isAllowedTag(value: string): value is AllowedTag {
  return (ALLOWED_TAGS as readonly string[]).includes(value);
}

type RevalidateBody = { secret?: unknown; tag?: unknown };

/**
 * Gövde BİR KEZ okunuyor.
 *
 * `Request.json()` akışı tüketiyor; ikinci çağrı hata veriyor. Sır ve etiket
 * ayrı ayrı okunsaydı ikisinden biri her zaman boş çıkardı — sessiz ve
 * bulması zor bir hata.
 */
async function readBody(request: NextRequest): Promise<RevalidateBody> {
  try {
    const parsed: unknown = await request.json();
    return typeof parsed === 'object' && parsed !== null ? (parsed as RevalidateBody) : {};
  } catch {
    // Gövde yok ya da JSON değil; sır başlıktan da gelebilir.
    return {};
  }
}

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
function readSecret(request: NextRequest, body: RevalidateBody): string | null {
  const header = request.headers.get('authorization');
  if (header) {
    const bearer = header.replace(/^Bearer\s+/i, '').trim();
    if (bearer.length > 0) return bearer;
  }

  const { secret } = body;
  if (typeof secret === 'string' && secret.trim().length > 0) return secret.trim();

  return null;
}

function noStore(body: unknown, status = 200): NextResponse {
  return NextResponse.json(body, { status, headers: { 'Cache-Control': 'no-store' } });
}

export async function POST(request: NextRequest) {
  const expected = process.env.CONTENT_REVALIDATE_SECRET?.trim();

  if (!expected) {
    return noStore(
      {
        error: {
          code: 'REVALIDATE_DISABLED',
          message:
            'İçerik tazeleme ucu kapalı: CONTENT_REVALIDATE_SECRET tanımlı değil. ' +
            'Sır tanımlanana kadar içerik yalnızca ISR penceresi dolduğunda tazelenir.',
        },
      },
      503,
    );
  }

  const body = await readBody(request);
  const provided = readSecret(request, body);

  if (!provided || !secretMatches(provided, expected)) {
    return noStore(
      { error: { code: 'UNAUTHORIZED', message: 'Geçersiz tazeleme sırrı.' } },
      401,
    );
  }

  /*
   * Etiket yoksa `site-content`: panelin gövdesiz eski çağrısı bu davranışa
   * güveniyor ve onu kırmak, kurumsal içerik tazelemesini sessizce durdurmak
   * olurdu.
   */
  const requested = body.tag === undefined ? SITE_CONTENT_TAG : body.tag;

  if (typeof requested !== 'string' || !isAllowedTag(requested)) {
    return noStore(
      {
        error: {
          code: 'UNPROCESSABLE',
          message: 'Bilinmeyen tazeleme etiketi.',
          details: { tag: ALLOWED_TAGS },
        },
      },
      422,
    );
  }

  revalidateTag(requested);

  /*
   * Taze okumaların iki saniyelik penceresi de düşürülüyor; gerekçesi dosya
   * başlığındaki "ETİKET TEK BAŞINA YETMEZ" notunda. Yalnız bu süreçteki
   * pencereyi düşürür — birden fazla kopya çalışıyorsa diğerleri kendi
   * pencereleri dolunca tazelenir ve o pencere zaten iki saniye.
   */
  dropFreshCache();

  return noStore({ revalidated: true, tag: requested, at: new Date().toISOString() });
}
