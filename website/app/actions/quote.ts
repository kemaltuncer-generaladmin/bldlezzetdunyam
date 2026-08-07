'use server';

import { APP_ID, APP_VERSION } from '@/lib/api/client';
import { quoteSchema } from '@/lib/validation/quote';
import type { QuoteState } from '@/lib/action-state';

/**
 * Teklif talebi gönderimi.
 *
 * ## Alıcı uç neden env değişkeni?
 *
 * Gönderim, dışarıdan tanımlanan bir HTTP hedefine yapılıyor:
 * `QUOTE_WEBHOOK_URL`. Varsayılan hedef artık kendi ucumuz —
 * `POST /api/quote-requests` (sözleşme §7) — ve talepler admin panelde
 * "İçerikler → Teklif Talepleri" ekranında görünüyor. Değişken yine de dışarı
 * açık: firma isterse bir form servisine veya e-posta kancasına çevirebilir,
 * form kodu değişmeden.
 *
 * ## Tanımlı değilse ne oluyor?
 *
 * **Başarı mesajı GÖSTERİLMİYOR.** Kullanıcıya talebin iletilemediği açıkça
 * söyleniyor. Sessizce "teşekkürler" deyip veriyi çöpe atmak, kullanıcının
 * cevap beklemesine ve işin kaybolmasına yol açar.
 *
 * Talep her hâlükârda sunucu günlüğüne yazılıyor; böylece yapılandırma
 * eksikken gelen talep en azından log üzerinden kurtarılabilir.
 */

const WEBHOOK_URL = process.env.QUOTE_WEBHOOK_URL;

/** Formun açılışından gönderime kadar geçmesi beklenen en kısa süre. */
const MIN_FILL_MS = 3000;

export async function submitQuote(_previous: QuoteState, formData: FormData): Promise<QuoteState> {
  const raw = Object.fromEntries(formData) as Record<string, unknown>;

  // Onay kutusu FormData'da yalnızca işaretliyse ve "on" olarak gelir.
  raw.kvkk_accepted = formData.get('kvkk_accepted') === 'on';

  const parsed = quoteSchema.safeParse(raw);

  if (!parsed.success) {
    const fieldErrors: Record<string, string> = {};
    for (const issue of parsed.error.issues) {
      const field = issue.path[0];
      if (typeof field === 'string' && !fieldErrors[field]) fieldErrors[field] = issue.message;
    }
    return {
      status: 'error',
      message: 'Formda eksik veya hatalı alanlar var. Lütfen kontrol edin.',
      fieldErrors,
      at: Date.now(),
    };
  }

  const { website, ...payload } = parsed.data;

  /*
   * Spam elemesi iki katmanlı ve ikisi de sessiz:
   *   1. Bal küpü alanı dolu → bot.
   *   2. Form üç saniyeden kısa sürede gönderilmiş → otomatik doldurma.
   * Bota "yakalandın" demiyoruz; başarı görünümü döndürüp geçiyoruz, yoksa
   * bot yöntemini değiştirip tekrar dener.
   */
  const openedAt = Number(formData.get('opened_at'));
  const tooFast = Number.isFinite(openedAt) && Date.now() - openedAt < MIN_FILL_MS;

  if (website || tooFast) {
    return { status: 'ok', message: null, fieldErrors: {}, at: Date.now() };
  }

  if (!WEBHOOK_URL) {
    // Talebi kaybetmemek için günlüğe yaz — yapılandırma tamamlanınca kaldırılabilir.
    console.error('[teklif] QUOTE_WEBHOOK_URL tanımlı değil, talep iletilemedi:', payload);
    return {
      status: 'unconfigured',
      message:
        'Teklif formu henüz bir alıcıya bağlanmadı, bu yüzden talebinizi iletemedik. Site yöneticisinin QUOTE_WEBHOOK_URL ayarını tamamlaması gerekiyor.',
      fieldErrors: {},
      at: Date.now(),
    };
  }

  try {
    const response = await fetch(WEBHOOK_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        /*
         * Platformun `bld.headers` ara katmanı bu iki başlığı ZORUNLU tutuyor
         * (sözleşme §1.1); eksik gönderilirse uç talebi almadan 422 döner ve
         * müşterinin işi kaybolur. Kendi API'mize gönderdiğimiz için buradalar.
         *
         * Hedef bizim ucumuz değil de bir form servisiyse fazladan iki başlık
         * zararsız — servisler tanımadıkları başlıkları yok sayıyor.
         */
        'X-App-Id': APP_ID,
        'X-App-Version': APP_VERSION,
      },
      body: JSON.stringify({ ...payload, submitted_at: new Date().toISOString() }),
      // Teklif talebi önbelleğe alınacak bir istek değil.
      cache: 'no-store',
    });

    if (!response.ok) {
      console.error('[teklif] Alıcı uç hata döndü:', response.status, payload);
      return {
        status: 'error',
        message:
          'Talebiniz gönderilemedi. Lütfen birazdan tekrar deneyin veya doğrudan bizimle iletişime geçin.',
        fieldErrors: {},
        at: Date.now(),
      };
    }
  } catch (error) {
    console.error('[teklif] Alıcı uca ulaşılamadı:', error, payload);
    return {
      status: 'error',
      message:
        'Talebiniz gönderilemedi. Bağlantınızı kontrol edip tekrar deneyin veya doğrudan bizimle iletişime geçin.',
      fieldErrors: {},
      at: Date.now(),
    };
  }

  return { status: 'ok', message: null, fieldErrors: {}, at: Date.now() };
}
