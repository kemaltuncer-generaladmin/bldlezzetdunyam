'use client';

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
// Leaflet'in kendi stili. Bu bileşenle birlikte kod bölünmesine giriyor:
// `globals.css`'e konsaydı haritayla ilgisi olmayan her sayfaya inerdi.
// Onsuz karolar üst üste yığılıyor ve harita bozuk görünüyor.
import 'leaflet/dist/leaflet.css';
// TİP-ONLY içe aktarım: derleme sırasında siliniyor, yani Leaflet'i
// sunucu paketine sokmuyor. Çalışma anındaki gerçek yükleme aşağıda
// `await import('leaflet')` ile ve yalnızca tarayıcıda yapılıyor.
import type { LeafletMouseEvent, Map as LeafletMap, Marker } from 'leaflet';
import { Crosshair, MapPin } from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
  SERVICE_AREA_BOUNDS,
  SERVICE_AREA_CENTER,
  SERVICE_AREA_MAX_ZOOM,
  SERVICE_AREA_MIN_ZOOM,
  containsPoint,
} from '@/lib/service-area';

export type MapPin = { latitude: number; longitude: number };

/**
 * Haritadan teslimat noktası seçimi — W-16.
 *
 * ## Neden gerekli
 *
 * Kurye fişindeki QR (K-14) yalnızca koordinat varken basılıyor. Mobil
 * uygulama haritadan iğne alıyordu, site hiç almıyordu — yani **siteden
 * gelen her siparişin kurye fişi QR'sızdı** ve kurye adresi okuyup elle
 * aramak zorunda kalıyordu.
 *
 * ## Neden Leaflet ve OpenStreetMap
 *
 * Mobil zaten OSM karoları kullanıyor; harita kaynağı kararı verilmiş
 * durumda ve API anahtarı ya da faturalandırma gerektirmiyor. Google
 * Maps'e geçmek üç istemciyi birden bağlayan yeni bir maliyet kalemi
 * açardı.
 *
 * ## Neden `dynamic import` ile yükleniyor
 *
 * Leaflet `window` ve `document`'a modül düzeyinde dokunuyor; sunucuda
 * içe aktarıldığı anda derleme patlıyor. Bu bileşen `ssr: false` ile
 * yükleniyor (bkz. `map-picker-lazy.tsx`) ve harita paketi yalnızca
 * ödeme/adres ekranını açan kullanıcıya iniyor — kurumsal sayfaları
 * ~150 kB büyütmüyor.
 */
export function MapPicker({
  value,
  onChange,
  className,
}: {
  value: MapPin | null;
  onChange: (pin: MapPin | null) => void;
  className?: string;
}) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<LeafletMap | null>(null);
  const markerRef = useRef<Marker | null>(null);
  const [ready, setReady] = useState(false);
  const [locating, setLocating] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

  // `onChange` her çizimde yeni referans olabiliyor; efektin bağımlılığına
  // koymak haritayı sürekli kurup yıkardı.
  const onChangeRef = useRef(onChange);
  onChangeRef.current = onChange;

  const bounds = useMemo(
    () =>
      [
        [SERVICE_AREA_BOUNDS.south, SERVICE_AREA_BOUNDS.west],
        [SERVICE_AREA_BOUNDS.north, SERVICE_AREA_BOUNDS.east],
      ] as [[number, number], [number, number]],
    [],
  );

  useEffect(() => {
    let disposed = false;
    const container = containerRef.current;
    if (!container) return;

    void (async () => {
      const L = await import('leaflet');
      if (disposed || mapRef.current) return;

      const map = L.map(container, {
        center: [SERVICE_AREA_CENTER.latitude, SERVICE_AREA_CENTER.longitude],
        zoom: 14,
        minZoom: SERVICE_AREA_MIN_ZOOM,
        maxZoom: SERVICE_AREA_MAX_ZOOM,
        // HARİTA KUTUYA HAPSEDİLİYOR: hizmet alanı dışına kaydırılan bir
        // harita, oraya da gidiyormuşuz izlenimi veriyor. Müşteri iğneyi
        // Ankara'ya koyup siparişi reddedilince sebebini anlamıyor.
        maxBounds: bounds,
        maxBoundsViscosity: 1,
        attributionControl: true,
      });

      L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: SERVICE_AREA_MAX_ZOOM,
        attribution: '&copy; OpenStreetMap katkıcıları',
      }).addTo(map);

      map.on('click', (event: LeafletMouseEvent) => {
        const { lat, lng } = event.latlng;
        if (!containsPoint(lat, lng)) {
          setMessage('Bu nokta teslimat alanımızın dışında.');
          return;
        }
        setMessage(null);
        onChangeRef.current({ latitude: lat, longitude: lng });
      });

      mapRef.current = map;
      setReady(true);
    })();

    return () => {
      disposed = true;
      mapRef.current?.remove();
      mapRef.current = null;
      markerRef.current = null;
    };
  }, [bounds]);

  // İğneyi dışarıdan gelen değere göre çiziyoruz; haritanın kendi durumu
  // tek doğru kaynak değil (form sıfırlanabilir, kayıtlı adres seçilebilir).
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !ready) return;

    void (async () => {
      const L = await import('leaflet');

      if (value === null) {
        markerRef.current?.remove();
        markerRef.current = null;
        return;
      }

      const position: [number, number] = [value.latitude, value.longitude];

      if (markerRef.current) {
        markerRef.current.setLatLng(position);
      } else {
        markerRef.current = L.marker(position, {
          draggable: true,
          // Varsayılan ikon karoları CDN'den geliyor ve CSP altında
          // düşebiliyor; SVG'yi kendimiz gömüyoruz.
          icon: L.divIcon({
            className: '',
            html:
              '<span style="display:block;width:24px;height:24px;border-radius:9999px;' +
              'background:#ea580c;border:3px solid #fff;box-shadow:0 2px 6px rgba(0,0,0,.4)"></span>',
            iconSize: [24, 24],
            iconAnchor: [12, 12],
          }),
        }).addTo(map);

        markerRef.current.on('dragend', () => {
          const { lat, lng } = markerRef.current!.getLatLng();
          if (!containsPoint(lat, lng)) {
            setMessage('Bu nokta teslimat alanımızın dışında.');
            markerRef.current!.setLatLng([value.latitude, value.longitude]);
            return;
          }
          setMessage(null);
          onChangeRef.current({ latitude: lat, longitude: lng });
        });
      }

      map.panTo(position);
    })();
  }, [value, ready]);

  /**
   * Tarayıcı konumu. İzin verilmezse sessizce vazgeçilmiyor — kullanıcı
   * neden bir şey olmadığını bilmeli.
   */
  const useMyLocation = useCallback(() => {
    if (!('geolocation' in navigator)) {
      setMessage('Tarayıcınız konum paylaşımını desteklemiyor.');
      return;
    }

    setLocating(true);
    navigator.geolocation.getCurrentPosition(
      (position) => {
        setLocating(false);
        const { latitude, longitude } = position.coords;
        if (!containsPoint(latitude, longitude)) {
          setMessage('Bulunduğunuz yer teslimat alanımızın dışında.');
          return;
        }
        setMessage(null);
        onChangeRef.current({ latitude, longitude });
      },
      () => {
        setLocating(false);
        setMessage('Konum alınamadı. Haritadan elle seçebilirsiniz.');
      },
      { enableHighAccuracy: true, timeout: 10_000 },
    );
  }, []);

  return (
    <div className={className}>
      <div className="flex flex-wrap items-center justify-between gap-2">
        <p className="text-sm text-muted-foreground">
          Haritaya dokunarak ya da iğneyi sürükleyerek kapınızı işaretleyin.
        </p>
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={useMyLocation}
          disabled={locating}
        >
          <Crosshair aria-hidden="true" />
          {locating ? 'Konum alınıyor…' : 'Konumumu kullan'}
        </Button>
      </div>

      <div
        ref={containerRef}
        // Yükseklik ŞART: Leaflet sıfır yükseklikli bir kapta sessizce
        // hiçbir şey çizmiyor ve hata da vermiyor.
        className="mt-3 h-64 w-full overflow-hidden rounded-lg border bg-muted sm:h-80"
        role="application"
        aria-label="Teslimat noktası haritası"
      />

      {message && (
        <p role="status" className="mt-2 rounded-md bg-warning/10 px-3 py-2 text-sm">
          {message}
        </p>
      )}

      {value && (
        <p className="mt-2 flex items-center gap-1.5 text-sm text-muted-foreground">
          <MapPin aria-hidden="true" className="size-4 text-primary" />
          Nokta seçildi — kurye fişine harita QR&apos;ı basılacak.
          <button
            type="button"
            onClick={() => onChangeRef.current(null)}
            className="ml-1 underline underline-offset-4 hover:text-foreground"
          >
            Kaldır
          </button>
        </p>
      )}
    </div>
  );
}
