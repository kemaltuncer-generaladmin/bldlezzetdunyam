'use client';

import { useEffect, useRef, useState, type ReactNode } from 'react';

/**
 * Başlık kabuğu: aşağı kaydırınca gizlenir, yukarı kaydırınca geri gelir (W-07).
 *
 * NEDEN: başlık `sticky` ve 72 px yüksekliğinde. Menüde gezinen kullanıcıda
 * ekranın üst yedide biri kalıcı olarak başlığa gidiyordu — mobilde bu, bir
 * ürün kartı demek. Başlığı tamamen `static` yapmak da doğru değil: sepete
 * ve girişe her an ulaşılabilmesi gerekiyor.
 *
 * Yukarı kaydırma "bir şey arıyorum" niyetidir ve başlığı hemen geri getirir;
 * aşağı kaydırma "okumaya devam" niyetidir ve yer açar.
 *
 * SUNUCU BİLEŞENİNİ SARAR, İÇİNE ALMAZ: `children` sunucuda çiziliyor ve
 * buraya hazır ağaç olarak iniyor. Başlığın oturumsuz kalması (dolayısıyla
 * pazarlama sayfalarının ISR'da kalması) bu ayrımla korunuyor.
 *
 * ERİŞİLEBİLİRLİK:
 *   * `prefers-reduced-motion` açıksa başlık hiç gizlenmez — kaybolup geri
 *     gelen bir çubuk, hareket duyarlılığı olan kullanıcı için rahatsız
 *     edici ve yön kaybettirici.
 *   * Odak başlığın içindeyken de gizlenmez: klavyeyle sekme atan kullanıcı
 *     odaklandığı düğmenin ekrandan kaymasını yaşamamalı.
 *   * Sayfanın en üstünde her zaman görünür.
 */
export function HeaderShell({ children }: { children: ReactNode }) {
  const [hidden, setHidden] = useState(false);
  const ref = useRef<HTMLElement>(null);

  useEffect(() => {
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

    // Son BOYANMIŞ karedeki konum. `window.scrollY`yi doğrudan okuyup
    // karşılaştırmak, iOS'un esneme (rubber-band) kaydırmasında negatif ve
    // sıçramalı değerler ürettiği için başlığı titretiyordu.
    let lastY = window.scrollY;
    let frame = 0;

    const onScroll = () => {
      if (frame) return;

      frame = window.requestAnimationFrame(() => {
        frame = 0;
        const y = window.scrollY;
        const delta = y - lastY;

        // 6 px'lik ölü bölge: dokunmatik yüzeylerde parmak kaldırırken oluşan
        // 1-2 px'lik salınım, onsuz başlığı açıp kapatıyordu.
        if (Math.abs(delta) < 6) return;

        // Başlık yüksekliğinin altındayken hep açık: sayfanın tepesinde
        // gizli bir başlık, "kayboldu" olarak okunuyor.
        const nearTop = y < 96;
        const holdsFocus = ref.current?.contains(document.activeElement) ?? false;

        setHidden(!nearTop && !holdsFocus && delta > 0);
        lastY = y;
      });
    };

    window.addEventListener('scroll', onScroll, { passive: true });
    return () => {
      window.removeEventListener('scroll', onScroll);
      if (frame) window.cancelAnimationFrame(frame);
    };
  }, []);

  return (
    <header
      ref={ref}
      data-hidden={hidden ? '' : undefined}
      className="sticky top-0 z-40 border-b bg-background/90 backdrop-blur transition-transform duration-300 ease-out data-hidden:-translate-y-full supports-[backdrop-filter]:bg-background/70 motion-reduce:transition-none motion-reduce:data-hidden:translate-y-0"
    >
      {children}
    </header>
  );
}
