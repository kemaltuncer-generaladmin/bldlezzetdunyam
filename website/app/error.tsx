'use client';

import { useEffect } from 'react';
import { TriangleAlert } from 'lucide-react';
import { StatePanel } from '@/components/state-panel';
import { Button } from '@/components/ui/button';

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
 */
export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error(error);
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
