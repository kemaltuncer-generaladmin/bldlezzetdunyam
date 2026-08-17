'use client';

import { useEffect } from 'react';
import { reportClientError } from '@/lib/report-error';

/**
 * Kök yerleşim hata sınırı.
 *
 * ## Bu dosya olmadan ne oluyordu?
 *
 * `app/error.tsx` yalnızca **yerleşimin içindeki** hataları yakalar. Kök
 * yerleşimin kendisinde (`app/layout.tsx`) bir hata doğduğunda — tema
 * sağlayıcısı, `getTranslations`, altbilginin içerik çağrısı — o sınır hiç
 * devreye girmiyor; Next.js kendi asgari hata sayfasını basıyor ve olay
 * HİÇBİR YERE yazılmıyor. Yani sitenin en pahalı arızası, bugüne kadar
 * görünmeyen tek arızaydı.
 *
 * ## Neden kendi `<html>` ve `<body>` etiketleri var?
 *
 * `global-error` KÖK YERLEŞİMİN YERİNE geçer; onun içinde render edilmez.
 * Yerleşim çalışmadığı için `<html>`/`<body>` iskeletini bu dosya kurmak
 * zorunda. Bu aynı zamanda burada tasarım jetonlarına, tema sağlayıcısına ve
 * shadcn bileşenlerine GÜVENİLEMEYECEĞİ anlamına geliyor: hata tam da o
 * katmandan gelmiş olabilir. Stil bu yüzden satır içi ve bağımlılıksız —
 * `globals.css` yüklenmemiş olsa bile okunur bir sayfa çıkıyor.
 *
 * ## Renkler neden elle yazılı?
 *
 * `--background` / `--foreground` jetonları `globals.css` içinde tanımlı ve o
 * dosya bu senaryoda yüklenmemiş olabilir. Değerler `app/layout.tsx`
 * `themeColor` girdisiyle aynı ikili (`#FAF6F0` / `#1B120C`); karanlık tema
 * `prefers-color-scheme` ile çözülüyor, çünkü `next-themes` de çalışmıyor
 * olabilir.
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
      context: {
        // Bu iki kelime raporun tek ayırt edici bilgisi: aynı istisna rota
        // sınırından da gelebilir ve ikisi çok farklı ciddiyette.
        boundary: 'global',
        ...(error.digest ? { digest: error.digest } : {}),
      },
    });
  }, [error]);

  return (
    <html lang="tr">
      <body
        style={{
          margin: 0,
          minHeight: '100dvh',
          display: 'grid',
          placeItems: 'center',
          padding: '2rem 1rem',
          fontFamily: 'system-ui, -apple-system, Segoe UI, Roboto, sans-serif',
          background: '#FAF6F0',
          color: '#1B120C',
        }}
      >
        {/* Karanlık tema: jeton yok, medya sorgusu satır içi stil ile
            yazılamıyor; tek elemanlık bir stil bloğu en ucuz çözüm. */}
        <style>{`
          @media (prefers-color-scheme: dark) {
            body { background: #1B120C !important; color: #FAF6F0 !important; }
            .bld-global-error-action { border-color: #FAF6F0 !important; color: #FAF6F0 !important; }
          }
        `}</style>

        <main role="alert" style={{ maxWidth: '32rem', textAlign: 'center' }}>
          <h1 style={{ fontSize: '1.5rem', fontWeight: 600, margin: 0, lineHeight: 1.3 }}>
            Sayfa açılamadı
          </h1>
          <p style={{ marginTop: '0.75rem', lineHeight: 1.6, opacity: 0.8 }}>
            Beklenmeyen bir sorun çıktı ve sayfayı çizemedik. Tekrar deneyin; sorun sürerse birkaç
            dakika sonra yeniden bakın.
          </p>

          <button
            type="button"
            onClick={reset}
            className="bld-global-error-action"
            style={{
              marginTop: '1.75rem',
              minHeight: '2.75rem',
              padding: '0 1.25rem',
              borderRadius: '0.5rem',
              border: '1px solid #1B120C',
              background: 'transparent',
              color: 'inherit',
              font: 'inherit',
              fontWeight: 500,
              cursor: 'pointer',
            }}
          >
            Tekrar deneyin
          </button>
        </main>
      </body>
    </html>
  );
}
