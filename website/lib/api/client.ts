import type { ApiErrorBody, ErrorCode } from './types';

/** `X-App-Id` sözleşmede kapalı enum; site her zaman `website` gönderir. */
export const APP_ID = 'website';
/** `X-App-Version` SemVer olmalı (`^\d+\.\d+\.\d+$`). package.json ile aynı tutulur. */
export const APP_VERSION = '1.0.0';

export const API_BASE_URL = (
  process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:4010/api'
).replace(/\/+$/, '');

export const SITE_URL = (process.env.NEXT_PUBLIC_SITE_URL ?? 'http://localhost:3000').replace(
  /\/+$/,
  '',
);

/** Menü/vitrin ISR penceresi — `docs/06` §7 varsayılanı 60 sn. */
export const REVALIDATE_SECONDS = Number.parseInt(process.env.REVALIDATE_SECONDS ?? '60', 10) || 60;

/** Ağ ve sözleşme dışı durumlar için tek hata tipi. */
export type ApiFailureCode = ErrorCode | 'NETWORK' | 'MALFORMED';

export class ApiError extends Error {
  readonly status: number;
  readonly code: ApiFailureCode;
  readonly details: Record<string, unknown> | null;

  constructor(
    status: number,
    code: ApiFailureCode,
    message: string,
    details: Record<string, unknown> | null = null,
  ) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.code = code;
    this.details = details;
  }

  /**
   * Alan bazlı doğrulama hatalarını `{alan: mesaj}` biçimine indirger.
   *
   * Sözleşme `Error.details` içeriğini serbest bırakır (`additionalProperties`),
   * bu yüzden iki biçim de geliyor: mesaj metni **ve** izinli değer listesi
   * (örn. `{payment_method: ["cash","account"]}`). Tek kelimelik değerler
   * kullanıcıya gösterilecek mesaj değildir; atlanır — üst düzey `message`
   * zaten Türkçe ve gösterilebilir.
   */
  fieldErrors(): Record<string, string> {
    const out: Record<string, string> = {};
    if (!this.details) return out;

    const looksLikeMessage = (value: string): boolean => value.trim().includes(' ');

    for (const [field, value] of Object.entries(this.details)) {
      if (typeof value === 'string') {
        if (looksLikeMessage(value)) out[field] = value;
      } else if (Array.isArray(value)) {
        const first = value.find(
          (entry): entry is string => typeof entry === 'string' && looksLikeMessage(entry),
        );
        if (first !== undefined) out[field] = first;
      }
    }
    return out;
  }
}

type CacheDirective =
  { kind: 'revalidate'; seconds: number; tags?: string[] } | { kind: 'no-store' };

export type RequestOptions = {
  /**
   * `PATCH` ve `DELETE` W-15 ile eklendi: adres defteri güncelleme ve
   * silme uçları bunları kullanıyor (`docs/openapi.yaml` `/addresses/{id}`).
   * Sözleşmede başka metot yok; listeyi geniş tutmak, olmayan bir uca
   * istek atmayı derleme anında yakalanamaz hâle getirirdi.
   */
  method?: 'GET' | 'POST' | 'PATCH' | 'DELETE';
  /** JSON gövdesi; `undefined` ise gövde gönderilmez. */
  body?: unknown;
  /** Müşteri token'ı (`Authorization: Bearer`). */
  token?: string | null;
  query?: Record<string, string | number | boolean | undefined>;
  cache?: CacheDirective;
  signal?: AbortSignal;
};

function buildUrl(path: string, query: RequestOptions['query']): string {
  const url = new URL(`${API_BASE_URL}${path.startsWith('/') ? path : `/${path}`}`);
  if (query) {
    for (const [key, value] of Object.entries(query)) {
      if (value !== undefined) url.searchParams.set(key, String(value));
    }
  }
  return url.toString();
}

function isErrorBody(value: unknown): value is ApiErrorBody {
  if (typeof value !== 'object' || value === null || !('error' in value)) return false;
  const { error } = value as { error: unknown };
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    'message' in error &&
    typeof (error as { message: unknown }).message === 'string'
  );
}

function toDetails(value: unknown): Record<string, unknown> | null {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

/**
 * Taze okumanın en fazla bekleyeceği süre.
 *
 * YALNIZCA `no-store` İSTEKLERE UYGULANIYOR. Bir `AbortSignal` vermek Next.js'in
 * Data Cache'ini devre dışı bırakabiliyor; ISR ile okunan yüzeylerde (ana sayfa,
 * kurumsal içerik) bunu göze alamayız — orada zaten önbellek var ve tıkanan bir
 * istek bir sonraki ziyaretçiyi bekletmiyor.
 *
 * Süre dolduğunda istek ağ hatası sayılıyor ve GET ise yeniden deneniyor.
 * Sınırsız beklemek, platform tıkandığında sitenin de onunla birlikte
 * kilitlenmesi demekti: Next.js işçisi yanıt bekleyerek duruyor ve arkadaki
 * bütün istekler kuyruğa giriyordu.
 */
const FRESH_TIMEOUT_MS = Number.parseInt(process.env.API_TIMEOUT_MS ?? '', 10) || 8000;

/**
 * GET yeniden deneme aralıkları (ms). Dizi uzunluğu = ek deneme sayısı.
 *
 * KISA VE AZ. Amaç dayanıklılık değil, TEK SEFERLİK bir hıçkırığı yutmak:
 * platform yeniden başlarken ya da bağlantı havuzu bir an dolduğunda gelen
 * 502/503, müşteriye "Günün menüsü yüklenemedi" diye görünüyordu. Uzun
 * beklemeler bunu düzeltmez, sadece hatayı geciktirir.
 */
const RETRY_DELAYS_MS = [120, 320] as const;

/**
 * Hangi durum kodları yeniden denenir.
 *
 * `429` BİLEREK YOK: hız sınırına takılan isteği tekrarlamak sınırı daha da
 * doldurur. `4xx` de yok — istek yanlışsa ikincisi de yanlış olur.
 */
const RETRYABLE_STATUS = new Set([500, 502, 503, 504]);

/** YALNIZCA GET yeniden denenir; sipariş oluşturmayı tekrarlamak çift sipariş demek. */
function isRetryable(method: NonNullable<RequestOptions['method']>): boolean {
  return method === 'GET';
}

/** `attempt`inci denemeden sonraki bekleme. Dizi biterse son değeri kullanır. */
function retryDelay(attempt: number): Promise<void> {
  const ms = RETRY_DELAYS_MS[attempt] ?? RETRY_DELAYS_MS[RETRY_DELAYS_MS.length - 1] ?? 0;
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Sözleşmeye uygun tek HTTP girişi. Zorunlu başlıkları (`X-App-Id`,
 * `X-App-Version`, `Accept-Language`) her istekte ekler — eksikse sunucu `422`
 * döner (`docs/03` §1.1).
 *
 * Dönüş tipi çağıran tarafından `lib/api/types.ts`'teki üretilmiş tiplerle
 * verilir; burada gövde şekli doğrulanmaz, sözleşme normatiftir.
 */
export async function apiFetch<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const { method = 'GET', body, token, query, cache, signal } = options;

  const headers: Record<string, string> = {
    'X-App-Id': APP_ID,
    'X-App-Version': APP_VERSION,
    'Accept-Language': 'tr',
    Accept: 'application/json',
  };
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  if (token) headers.Authorization = `Bearer ${token}`;

  // Kimlik gerektiren yanıtlar asla önbelleklenmez.
  const directive: CacheDirective = cache ?? (token ? { kind: 'no-store' } : { kind: 'no-store' });

  const init: RequestInit = {
    method,
    headers,
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    ...(directive.kind === 'no-store'
      ? { cache: 'no-store' as const }
      : {
          next: {
            revalidate: directive.seconds,
            ...(directive.tags ? { tags: directive.tags } : {}),
          },
        }),
  };

  const url = buildUrl(path, query);
  const attempts = isRetryable(method) ? RETRY_DELAYS_MS.length + 1 : 1;

  let response: Response | null = null;

  for (let attempt = 0; attempt < attempts; attempt++) {
    /*
     * Zaman aşımı yalnız taze okumalarda; gerekçesi `FRESH_TIMEOUT_MS`'te.
     * Çağıranın kendi sinyali varsa ikisi birleştiriliyor — biri iptal
     * ederse istek düşüyor.
     */
    const deadline = directive.kind === 'no-store' ? AbortSignal.timeout(FRESH_TIMEOUT_MS) : null;
    const attemptSignal =
      deadline === null
        ? signal
        : signal === undefined
          ? deadline
          : AbortSignal.any([signal, deadline]);

    try {
      response = await fetch(url, { ...init, signal: attemptSignal });
    } catch (cause) {
      /*
       * ÇAĞIRANIN İPTALİ YENİDEN DENENMEZ ve olduğu gibi yukarı çıkar:
       * "vazgeçildi" bir arıza değil. Kendi zaman aşımımız ise ağ hatası
       * sayılıyor ve bir kez daha deneniyor.
       */
      if (signal?.aborted === true) throw cause;

      response = null;

      if (attempt === attempts - 1) {
        throw new ApiError(0, 'NETWORK', 'Sunucuya ulaşılamadı, tekrar deneyin.');
      }

      await retryDelay(attempt);
      continue;
    }

    if (!RETRYABLE_STATUS.has(response.status) || attempt === attempts - 1) break;

    // Gövdeyi okumadan bırakmak bağlantıyı açık tutar; atılan denemenin
    // gövdesi kapatılıyor.
    await response.body?.cancel().catch(() => {});
    await retryDelay(attempt);
  }

  // Döngü her yolda ya `response` atar ya fırlatır; tip daraltma için.
  if (response === null) {
    throw new ApiError(0, 'NETWORK', 'Sunucuya ulaşılamadı, tekrar deneyin.');
  }

  if (response.status === 204) return undefined as T;

  const raw = await response.text();
  let parsed: unknown = null;
  if (raw.length > 0) {
    try {
      parsed = JSON.parse(raw);
    } catch {
      parsed = null;
    }
  }

  if (!response.ok) {
    if (isErrorBody(parsed)) {
      throw new ApiError(
        response.status,
        parsed.error.code,
        parsed.error.message,
        toDetails(parsed.error.details),
      );
    }
    throw new ApiError(response.status, 'MALFORMED', 'Beklenmeyen bir sunucu yanıtı alındı.');
  }

  if (parsed === null) {
    throw new ApiError(response.status, 'MALFORMED', 'Sunucu yanıtı okunamadı.');
  }

  return parsed as T;
}

/** Kullanıcıya gösterilecek Türkçe metin — bilinmeyen hatayı da karşılar. */
export function userMessage(
  error: unknown,
  fallback = 'Bir şeyler ters gitti, tekrar deneyin.',
): string {
  if (error instanceof ApiError) {
    return error.code === 'NETWORK'
      ? 'Sunucuya ulaşılamadı, bağlantınızı kontrol edip tekrar deneyin.'
      : error.message;
  }
  return fallback;
}
