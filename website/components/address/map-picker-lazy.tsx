'use client';

import dynamic from 'next/dynamic';
import type { MapPin } from '@/components/address/map-picker';

/**
 * Harita seçicinin tembel yükleyicisi — W-16.
 *
 * `ssr: false` ZORUNLU: Leaflet modül düzeyinde `window` ve `document`'a
 * dokunuyor, sunucuda içe aktarıldığı anda derleme patlıyor.
 *
 * Ayrıca bir performans kararı: harita paketi ~150 kB ve yalnızca adres
 * giren kullanıcıya iniyor. Statik olarak içe aktarılsaydı `/kurumsal` ve
 * `/iletisim` gibi haritayla hiç ilgisi olmayan sayfalar da onu indirirdi.
 *
 * Yükleme sırasında sabit yükseklikli bir kutu gösteriliyor: harita gelince
 * sayfanın zıplamaması için.
 */
export const MapPickerLazy = dynamic(
  () => import('@/components/address/map-picker').then((mod) => mod.MapPicker),
  {
    ssr: false,
    loading: () => (
      <div className="mt-3 h-64 w-full animate-pulse rounded-lg border bg-muted sm:h-80" />
    ),
  },
);

export type { MapPin };
