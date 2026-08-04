'use client';

import { useEffect } from 'react';

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
    <div className="mx-auto max-w-content px-4 py-20 text-center">
      <h1 className="text-2xl font-bold text-neutral-900">Bir şeyler ters gitti</h1>
      <p className="mx-auto mt-3 max-w-md text-sm text-neutral-600">
        İşleminizi tamamlayamadık. Lütfen tekrar deneyin; sorun sürerse birkaç dakika sonra yeniden
        bakın.
      </p>
      <button
        type="button"
        onClick={reset}
        className="mt-6 rounded-lg bg-brand-700 px-6 py-3 text-sm font-semibold text-neutral-0 hover:bg-brand-800"
      >
        Tekrar deneyin
      </button>
    </div>
  );
}
