'use client';

import { useActionState, useEffect, useState, useTransition } from 'react';
import Link from 'next/link';
import { ArrowRight, RotateCcw, UtensilsCrossed } from 'lucide-react';
import { repeatOrderAction } from '@/app/actions/order';
import { IDLE_CART_STATE } from '@/lib/action-state';
import { Button } from '@/components/ui/button';
import { formatPrice } from '@/lib/format';
import { CART_CHANGED_EVENT } from '@/lib/cart-events';

type QuickOrderData = {
  logged_in: boolean;
  can_order: boolean;
  first_name: string | null;
  last_order: {
    id: number;
    order_number: string;
    total: number;
    created_at: string;
    item_count: number;
  } | null;
};

/**
 * Ana sayfadaki hızlı sipariş kutusu — W-10.
 *
 * BAĞLAMA GÖRE ÜÇ HÂLİ VAR:
 *  * girişli + son sipariş varsa → "geçen siparişi tekrarla";
 *  * girişli ama sipariş yoksa   → doğrudan menüye;
 *  * girişsiz                    → giriş + kurumsal kayıt.
 *
 * VERİ İSTEMCİDEN ÇEKİLİYOR, SUNUCU BİLEŞENİNDEN DEĞİL. Ana sayfa ISR ile
 * önbellekli ve öyle kalmalı (SEO); oturumu sunucuda okumak sayfayı her
 * ziyaretçi için yeniden çizdirirdi. `HeaderActions` da aynı sebeple
 * istemci tarafında çalışıyor.
 *
 * İLK BOYAMADA HİÇBİR ŞEY ÇİZİLMİYOR (`data === null`). Bir iskelet
 * gösterilseydi, girişsiz ziyaretçilerin çoğunda o iskelet "giriş yapın"
 * kutusuna dönüşür ve sayfa zıplardı.
 */
export function QuickOrder() {
  const [data, setData] = useState<QuickOrderData | null>(null);
  const [state, formAction] = useActionState(repeatOrderAction, IDLE_CART_STATE);
  const [pending, startTransition] = useTransition();

  useEffect(() => {
    let cancelled = false;

    fetch('/api/hizli-siparis', { cache: 'no-store' })
      .then((response) => (response.ok ? response.json() : null))
      .then((payload: QuickOrderData | null) => {
        if (!cancelled && payload) setData(payload);
      })
      .catch(() => {
        // Sessiz: kutu çizilmez, sayfanın kalanı çalışmaya devam eder.
      });

    return () => {
      cancelled = true;
    };
  }, []);

  /*
   * Sepete ekleme başarılıysa header rozetini uyandır. Olay yayınlanmazsa
   * kullanıcı "eklendi" mesajını görür ama üstteki sepet sayısı eski kalır
   * ve hangisine inanacağını bilemez.
   */
  useEffect(() => {
    if (state.status === 'ok') window.dispatchEvent(new Event(CART_CHANGED_EVENT));
  }, [state.status, state.at]);

  if (data === null) return null;

  return (
    <div className="rounded-xl border bg-card p-5 shadow-sm sm:p-6">
      {state.message && (
        <p
          role="status"
          className={`mb-4 rounded-md px-3 py-2 text-sm ${
            state.status === 'error' ? 'bg-danger/10 text-danger' : 'bg-success/10'
          }`}
        >
          {state.message}
        </p>
      )}

      {!data.logged_in && (
        <>
          <h2 className="text-lg font-semibold">Sipariş vermek için giriş yapın</h2>
          <p className="mt-1 text-sm text-muted-foreground">
            Telefonunuza gelen kodla saniyeler içinde girebilirsiniz — şifre gerekmez.
          </p>
          <div className="mt-4 flex flex-wrap gap-2">
            <Button asChild size="lg">
              <Link href="/giris?next=%2Fmenu">Giriş yap</Link>
            </Button>
            <Button asChild variant="outline" size="lg">
              <Link href="/kurumsal-kayit">Kurumsal kayıt</Link>
            </Button>
          </div>
        </>
      )}

      {data.logged_in && !data.can_order && (
        <>
          <h2 className="text-lg font-semibold">Hesabınız sipariş vermeye kapalı</h2>
          <p className="mt-1 text-sm text-muted-foreground">
            Sipariş kapısı kurumsal hesaplarda açık. Firma bilgilerinizi tamamlamak için bizimle
            iletişime geçin.
          </p>
          <Button asChild size="lg" className="mt-4">
            <Link href="/iletisim">İletişime geç</Link>
          </Button>
        </>
      )}

      {data.logged_in && data.can_order && (
        <>
          <h2 className="text-lg font-semibold">
            {data.first_name ? `Hoş geldiniz, ${data.first_name}` : 'Hoş geldiniz'}
          </h2>

          {data.last_order ? (
            <>
              <p className="mt-1 text-sm text-muted-foreground">
                Son siparişiniz {formatDate(data.last_order.created_at)} ·{' '}
                {data.last_order.item_count} ürün ·{' '}
                <span className="tabular-nums">{formatPrice(data.last_order.total)}</span>
              </p>

              <div className="mt-4 flex flex-wrap gap-2">
                <Button
                  type="button"
                  size="lg"
                  disabled={pending}
                  onClick={() => {
                    const formData = new FormData();
                    formData.set('order_id', String(data.last_order?.id));
                    startTransition(() => formAction(formData));
                  }}
                >
                  <RotateCcw aria-hidden="true" />
                  {pending ? 'Sepete ekleniyor…' : 'Aynı siparişi tekrarla'}
                </Button>

                <Button asChild variant="outline" size="lg">
                  <Link href="/menu">
                    <UtensilsCrossed aria-hidden="true" />
                    Menüye göz at
                  </Link>
                </Button>

                {state.status === 'ok' && (
                  <Button asChild variant="ghost" size="lg">
                    <Link href="/sepet">
                      Sepete git
                      <ArrowRight aria-hidden="true" />
                    </Link>
                  </Button>
                )}
              </div>
            </>
          ) : (
            <>
              <p className="mt-1 text-sm text-muted-foreground">
                Henüz siparişiniz yok. Bugünün menüsünden başlayın.
              </p>
              <Button asChild size="lg" className="mt-4">
                <Link href="/menu">
                  <UtensilsCrossed aria-hidden="true" />
                  Bugünün menüsü
                </Link>
              </Button>
            </>
          )}
        </>
      )}
    </div>
  );
}

function formatDate(iso: string): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return '';

  return new Intl.DateTimeFormat('tr-TR', {
    day: '2-digit',
    month: 'long',
    timeZone: 'Europe/Istanbul',
  }).format(date);
}
