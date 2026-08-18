import { subscribeCartChanged } from '@/lib/cart-events';

/**
 * SEPET ÖZETİNİN TEK İSTEMCİ KAYNAĞI.
 *
 * ## Neden modül düzeyinde bir depo, bileşen içinde `useState` değil?
 *
 * Özeti gösteren İKİ bileşen var ve menü sayfasında ikisi de aynı anda
 * basılıyor: masaüstündeki yapışkan kutu (`CartSummaryPanel`) ve mobildeki
 * alt çubuk (`CartSummaryBar`). Görünürlükleri CSS ile ayrılıyor
 * (`hidden lg:block` / `lg:hidden`), yani DAİMA İKİSİ DE MONTELİ — biri
 * ekranda görünmüyor olsa bile efekti çalışıyor.
 *
 * Her biri kendi `useEffect`'inde `/api/sepet-ozeti` çağırıyordu. Sonuç: her
 * sayfa yüklemesinde iki istek, her sepet değişiminde iki istek daha ve
 * sekmeye her dönüşte iki istek. Uç nokta `resolveCart()` çalıştırıyor, o da
 * vitrin + günün menüsü demek — yani ikiye katlanan şey iki HTTP isteği değil,
 * platformdaki iki sorgu yığını.
 *
 * Depo bunları tek bir isteğe indiriyor:
 *   * Uçuşta bir istek varsa ikinci çağıran ona KATILIYOR, yenisini açmıyor.
 *   * Cevap tek bir yere yazılıyor ve iki bileşen aynı anlık görüntüyü
 *     okuyor (`useSyncExternalStore`).
 *   * Sepet değişimi/odak dinleyicisi de tek: `subscribeCartChanged` artık
 *     bileşen başına değil, depo başına bir kez kuruluyor.
 *
 * ## Hata durumunda son bilinen özet KORUNUYOR
 *
 * Ağ hatasında `current` değiştirilmiyor. Dolu sepeti olan müşteriye geçici
 * bir kesinti yüzünden "sepetiniz boş" demek, hiçbir şey göstermemekten kötü.
 */

export type CartSummary = {
  count: number;
  subtotal: number;
  minOrderTotal: number;
  remainingToMinimum: number;
  hasUnavailable: boolean;
  orderingOpen: boolean;
  /** Sepetin bağlı olduğu servis günü (`YYYY-AA-GG`); boş sepette `null`. */
  serviceDate: string | null;
  dayOrderable: boolean;
};

function parseSummary(value: unknown): CartSummary | null {
  if (typeof value !== 'object' || value === null) return null;
  const raw = value as Record<string, unknown>;
  const num = (key: string): number => (typeof raw[key] === 'number' ? raw[key] : 0);

  return {
    count: num('count'),
    subtotal: num('subtotal'),
    minOrderTotal: num('min_order_total'),
    remainingToMinimum: num('remaining_to_minimum'),
    hasUnavailable: raw.has_unavailable === true,
    orderingOpen: raw.ordering_open === true,
    serviceDate: typeof raw.service_date === 'string' ? raw.service_date : null,
    dayOrderable: raw.day_orderable === true,
  };
}

let current: CartSummary | null = null;
let inflight: Promise<void> | null = null;
let subscriberCount = 0;
let unsubscribeCartEvents: (() => void) | null = null;

const listeners = new Set<() => void>();

function emit(): void {
  for (const listener of listeners) listener();
}

/**
 * Özeti tazeler. Uçuşta bir istek varsa ona katılır.
 *
 * `void` döner ve hiçbir zaman reddetmez: çağıranlar (efektler, olay
 * dinleyicileri) hata yolunu ayrıca işlemiyor ve yakalanmamış bir reddetme
 * konsolu kirletirdi.
 */
export function refreshCartSummary(): Promise<void> {
  if (inflight !== null) return inflight;

  inflight = (async () => {
    try {
      const response = await fetch('/api/sepet-ozeti', { cache: 'no-store' });
      if (!response.ok) return;

      const parsed = parseSummary(await response.json());
      if (parsed === null) return;

      current = parsed;
      emit();
    } catch {
      // Son bilinen özet korunur — gerekçe dosya başlığında.
    } finally {
      inflight = null;
    }
  })();

  return inflight;
}

export function getCartSummary(): CartSummary | null {
  return current;
}

/**
 * Sunucu anlık görüntüsü DAİMA `null`.
 *
 * Özet `httpOnly` çerezden türüyor ve bu bileşenler sunucuda okumuyor; ilk
 * boyama iki tarafta da özetsiz. Sabit bir değer döndürmek `useSyncExternalStore`
 * için ayrıca zorunlu: her çağrıda yeni bir nesne üretmek sonsuz döngü olurdu.
 */
export function getCartSummaryServerSnapshot(): CartSummary | null {
  return null;
}

/**
 * Depoyu dinler. İlk abone geldiğinde sepet olaylarına bağlanır ve ilk
 * okumayı yapar; son abone gidince bağlantı kapanır.
 */
export function subscribeCartSummary(listener: () => void): () => void {
  listeners.add(listener);
  subscriberCount += 1;

  if (subscriberCount === 1) {
    unsubscribeCartEvents = subscribeCartChanged(() => void refreshCartSummary());
    void refreshCartSummary();
  }

  return () => {
    listeners.delete(listener);
    subscriberCount -= 1;

    if (subscriberCount === 0) {
      unsubscribeCartEvents?.();
      unsubscribeCartEvents = null;
    }
  };
}
