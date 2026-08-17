'use client';

import { useEffect } from 'react';
import { TriangleAlert } from 'lucide-react';
import { StatePanel } from '@/components/state-panel';
import { Button } from '@/components/ui/button';
import { reportClientError } from '@/lib/report-error';

/**
 * Rota hata sınırı.
 *
 * ## Neden `StatePanel`?
 *
 * Boş/hata/çevrimdışı üçlüsü sitede TEK DÜZEN, ÜÇ TON olarak tanımlı: 72 px
 * daire + 28 px ikon + serif h3 + gövde + tek eylem. Bu sayfa kendi
 * başlığını ve kendi butonunu elle çiziyordu; sabit `text-neutral-900` ve
 * `bg-brand-700` yazıyordu, yani karanlık temada da açık tema renklerinde
 * kalıyordu ve sitedeki diğer hata ekranlarından farklı görünüyordu.
 *
 * ## Eylem neden OUTLINE?
 *
 * Bileşen dili hata panelinin eylemini outline olarak veriyor: "Tekrar
 * deneyin" bir onarım denemesi, sayfanın birincil eylemi değil. Görünüm
 * başına tek primary kuralı burada da geçerli.
 *
 * ## Metin neden `next-intl` üzerinden gelmiyor?
 *
 * `NextIntlClientProvider` kök yerleşimde bilinçli olarak yok
 * (`app/layout.tsx`) ve bu bir İSTEMCİ bileşeni — `getTranslations` burada
 * çağrılamaz. Sağlayıcıyı yalnızca hata ekranı için geri koymak, ICU
 * çalışma zamanını sitedeki her sayfaya indirmek demekti.
 *
 * ## Neden `console.error` değil?
 *
 * Konsola yazmak hatayı KULLANICININ tarayıcısında bırakır; biz onu asla
 * görmeyiz. Rapor artık `POST /client-errors` ile durum monitörüne düşüyor
 * (`lib/report-error.ts`). `digest` bağlama giriyor: sunucuda doğan bir
 * hatanın istemciye ulaşan mesajı bilerek anlamsızlaştırılır ve sunucu
 * günlüğüyle eşleştirmenin tek yolu o karmadır.
 *
 * Raportör kendi içinde susturulmuş (`void` döner, hiç fırlatmaz), yani
 * buradaki `useEffect` ikinci bir hata sınırı tetiklemez.
 */
export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    reportClientError({
      error,
      kind: 'render',
      context: error.digest ? { digest: error.digest } : null,
    });
  }, [error]);

  return (
    <div className="mx-auto max-w-content px-4 py-20 sm:px-6">
      <StatePanel
        tone="error"
        role="alert"
        icon={<TriangleAlert strokeWidth={1.75} aria-hidden="true" />}
        title="Bir şeyler ters gitti"
        message="İşleminizi tamamlayamadık. Tekrar deneyin; sorun sürerse birkaç dakika sonra yeniden bakın."
        action={
          <Button type="button" variant="outline" size="lg" onClick={reset}>
            Tekrar deneyin
          </Button>
        }
      />
    </div>
  );
}
