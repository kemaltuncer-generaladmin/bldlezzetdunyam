import { reportClientError } from '@/lib/report-error';

/**
 * Sunucu tarafı hata kancası — App Router'ın resmî `onRequestError`'ı.
 *
 * ## ASIL HATALAR BURADA
 *
 * `app/error.tsx` ve `app/global-error.tsx` yalnızca TARAYICIDA doğan render
 * hatalarını görüyor. Bu sitenin işi ise büyük ölçüde sunucuda dönüyor:
 * Server Component'ler menüyü ve içeriği çekiyor, Route Handler'lar sepet
 * özetini üretiyor, Server Action'lar sipariş oluşturuyor. Oralarda atılan bir
 * istisna istemciye yalnızca anonimleştirilmiş bir `digest` olarak ulaşıyor —
 * yani hata sınırından gelen rapor "bir şey oldu" diyor, ne olduğunu
 * söylemiyor. `onRequestError` istisnanın kendisini, yığın iziyle birlikte
 * veriyor.
 *
 * ## Yalnızca Node.js çalışma zamanı
 *
 * `register()` YAZILMADI: OpenTelemetry ya da başka bir kurulum işi yok ve boş
 * bir `register` fonksiyonu ihraç etmek, ileride birinin oraya iş koyup her
 * iki çalışma zamanında (Node + Edge) çalıştığını sanmasına davetiye olurdu.
 * `onRequestError` tek başına yeterli.
 *
 * ## `void` döner ve beklenmez
 *
 * Raportör kendi içinde susturulmuş; buradan bir istisna çıkmıyor. Yine de
 * `async` imza korunuyor: Next.js kancayı `await` ediyor ve senkron bir
 * fonksiyon döndürmek ileride sözleşme değişirse sessizce kırılırdı.
 */
export async function onRequestError(
  error: unknown,
  request: { path: string; method: string; headers: { [key: string]: string | undefined } },
  context: {
    routerKind: 'Pages Router' | 'App Router';
    routePath: string;
    routeType: 'render' | 'route' | 'action' | 'middleware';
    renderSource?: string;
    revalidateReason?: string;
  },
): Promise<void> {
  /*
   * `routeType` sözleşmedeki `kind` ile birebir eşlenmiyor ve eşlenmemeli:
   * `kind` istemcinin kendi sınıflandırması ve kapalı enum değil. Render
   * hatası `render`, geri kalanı `unhandled` — bir Route Handler ya da
   * Server Action'da patlayan şey "arayüz çizilemedi" değildir.
   */
  const kind = context.routeType === 'render' ? 'render' : 'unhandled';

  reportClientError({
    error,
    kind,
    /*
     * `request.path` sorgu dizesi taşıyabiliyor; raportör onu kesiyor. Yine de
     * `context.routePath` (`/siparis/[id]` gibi kalıp) bağlama ayrıca
     * yazılıyor: monitörde aynı rotanın bin ayrı kimliği tek satırda
     * toplanabilsin diye.
     */
    route: request.path,
    context: {
      method: request.method,
      route_pattern: context.routePath,
      route_type: context.routeType,
      ...(context.renderSource ? { render_source: context.renderSource } : {}),
      ...(context.revalidateReason ? { revalidate_reason: context.revalidateReason } : {}),
    },
  });
}
