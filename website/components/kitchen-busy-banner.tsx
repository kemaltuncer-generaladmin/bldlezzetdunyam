'use client';

import { useEffect, useState } from 'react';

/**
 * Mutfak yoğunken gösterilen bant.
 *
 * [OrderingClosedBanner] ile KARIŞTIRILMAMALI: bu bant sipariş almayı
 * engellemez, yalnızca gecikme uyarısıdır. Sipariş düğmeleri açık kalır.
 *
 * NEDEN İSTEMCİ BİLEŞENİ: sayfalar 60 saniyelik ISR ile önbellekleniyor.
 * Sunucuda üretilseydi mutfak tuşa bastıktan bir dakika sonra görünürdü
 * ve "yoğunuz" uyarısının bir dakika gecikmesi onu işe yaramaz kılar.
 * Menü önbelleğini bozmak yerine yalnızca bu küçük durumu taze çekiyoruz.
 *
 * Metin sunucudan gelir; sabit yazsaydık yönetici metni değiştirdiğinde
 * siteyi yeniden yayınlamak gerekirdi.
 */
export function KitchenBusyBanner() {
  const [notice, setNotice] = useState<string | null>(null);

  useEffect(() => {
    let iptal = false;

    async function oku() {
      try {
        const res = await fetch('/api/vitrin-durumu', { cache: 'no-store' });
        if (!res.ok) return;
        const data: { busy?: boolean; busy_message?: string | null } = await res.json();
        if (iptal) return;
        setNotice(data.busy ? (data.busy_message?.trim() ?? null) : null);
      } catch {
        // Ağ hatasında bandı DEĞİŞTİRMİYORUZ. Geçici bir kesinti yüzünden
        // uyarıyı kaldırmak, mutfak yoğunken müşteriyi habersiz bırakır.
      }
    }

    void oku();
    // 30 sn: mutfak tuşa bastığında müşteri yarım dakika içinde görür.
    // Daha sık yoklamak, açık her sekmeden sunucuya trafik demek.
    const zamanlayici = setInterval(() => void oku(), 30_000);

    return () => {
      iptal = true;
      clearInterval(zamanlayici);
    };
  }, []);

  if (!notice) return null;

  return (
    <div
      role="status"
      className="rounded-card border border-brand-600/40 bg-brand-50 px-4 py-3 text-sm text-neutral-900"
    >
      <p className="font-semibold">Mutfağımız yoğun</p>
      <p className="mt-1 text-neutral-800">{notice}</p>
    </div>
  );
}
