import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { ErrorState } from '@/components/error-state';
import { ApiError } from '@/lib/api/client';
import { fetchContract, type ContractStatus, type SubscriptionContract } from '@/lib/api/contracts';
import { formatDate, formatDateTime, formatPrice } from '@/lib/format';
import { cn } from '@/lib/utils';
import { ContractApprovalForm } from './contract-approval-form';

/**
 * Abonelik sözleşmesi onay sayfası — M2.
 *
 * ## Neden web KANONİK iniş yeri?
 *
 * Onay bağlantısı SMS ile gidiyor ve **uygulama kurmamış** birine de
 * çalışmak zorunda. Mobil uygulamada da aynı ekran var (uygulama kullanıcısı
 * kendi sözleşmesini onaylamak için tarayıcıya atılmamalı), ama SMS'teki
 * bağlantının açtığı yer burasıdır.
 *
 * ## Giriş İSTEMEZ ve `middleware.ts` matcher'ında YOKTUR
 *
 * Onaylayan kişi çoğu zaman sitede oturum açmış kişi değil, satın almayı
 * onaylayan yetkilidir. Yetki, adresteki imzalı belirteçte; ikinci etken SMS
 * kodudur. Matcher'a `/sozlesme` eklenirse SMS'i alan kişi sözleşme yerine
 * giriş ekranı görür — `/takip/{id}` sayfasında birebir aynı hata yaşandı.
 *
 * ## `noindex`
 *
 * Sayfa herkese açık ama arama motorunda YERİ YOK: adres tek bir aboneye
 * ait imzalı bir belirteç taşıyor ve dizine girmesi, sözleşmeyi aramayla
 * bulunur hâle getirirdi.
 */

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'Abonelik sözleşmesi',
  description: 'Abonelik sözleşmenizi okuyup SMS koduyla onaylayın.',
  robots: { index: false, follow: false },
};

/** `docs/openapi.yaml`: `minLength: 20, maxLength: 200`. */
const TOKEN_MIN = 20;
const TOKEN_MAX = 200;

const DAY_NAMES = ['', 'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];

export default async function ContractPage({ params }: { params: Promise<{ token: string }> }) {
  const { token: rawToken } = await params;
  const token = decodeURIComponent(rawToken);

  /*
   * Uzunluk sözleşmedeki sınırların dışındaysa sunucuya hiç gidilmiyor:
   * belirteç bu hâliyle geçerli olamaz ve 200 KB'lık bir yolu uca taşımanın
   * anlamı yok. Sunucunun yanıtı da `404` olurdu.
   */
  if (token.length < TOKEN_MIN || token.length > TOKEN_MAX) notFound();

  let contract: SubscriptionContract;
  try {
    contract = await fetchContract(token);
  } catch (error) {
    /*
     * `404` = belirteç tanınmadı. SÜRESİ DOLMUŞ BAĞLANTIDAN AYRIDIR: o
     * `200` + `status: expired` ile geliyor ve aşağıda kendi cümlesini
     * kuruyor. İkisi tek ekrana indirgenseydi, süresi dolan bağlantıyı elinde
     * tutan kişiye "böyle bir sözleşme yok" denirdi.
     */
    if (error instanceof ApiError && error.status === 404) {
      return (
        <div className="mx-auto max-w-3xl px-4 py-16">
          <ErrorState
            title="Sözleşme bulunamadı"
            message="Bu bağlantı tanınmadı. SMS ile gelen bağlantıyı olduğu gibi açtığınızdan emin olun; sorun sürerse bizimle iletişime geçin."
            retryHref="/iletisim"
            retryLabel="İletişime geçin"
          />
        </div>
      );
    }

    return (
      <div className="mx-auto max-w-3xl px-4 py-16">
        <ErrorState
          title="Sözleşme yüklenemedi"
          message="Sözleşme bilgisi alınamadı. Bağlantınızı kontrol edip tekrar deneyin."
          retryHref={`/sozlesme/${encodeURIComponent(token)}`}
        />
      </div>
    );
  }

  const notice = STATUS_NOTICE[contract.status];
  const approvable = contract.status === 'draft' || contract.status === 'sent';

  return (
    <div className="mx-auto max-w-3xl px-4 py-10 sm:py-14">
      <header>
        <p className="text-sm font-semibold text-primary-text">Abonelik sözleşmesi</p>
        <h1 className="mt-1 font-display text-h1 font-semibold text-heading">
          {contract.title ?? 'Abonelik sözleşmesi'}
        </h1>
        <p className="mt-2 text-body-sm text-muted-foreground">
          {contract.customer_label ? `${contract.customer_label} · ` : ''}Sürüm {contract.version}
        </p>
      </header>

      {notice && (
        <div
          role="status"
          className={cn('mt-6 rounded-xl border p-4 text-sm sm:p-5', notice.className)}
        >
          <p className="font-semibold">{notice.title}</p>
          <p className="mt-1">{notice.body}</p>
          {contract.status === 'approved' && contract.approved_at && (
            <p className="mt-1 tabular-nums">Onay zamanı: {formatDateTime(contract.approved_at)}</p>
          )}
        </div>
      )}

      {/*
       * FİYAT METNİN ÜSTÜNDE ve büyük. Onaylayan kişi neyi imzaladığını
       * sayfalarca metnin arasından çıkarmak zorunda kalmamalı; aylık tahmin
       * de porsiyon fiyatından zihninde çarparak değil, yazılı bir rakamla
       * görünüyor.
       */}
      <section
        aria-label="Sözleşme koşulları"
        className="mt-6 rounded-xl border bg-card p-5 shadow-sm sm:p-6"
      >
        <p className="text-sm text-muted-foreground">Porsiyon fiyatı</p>
        <p className="mt-1 font-display text-h2 font-semibold text-heading tabular-nums">
          {formatPrice(contract.unit_price)}
        </p>

        <dl className="mt-5 grid gap-4 text-sm sm:grid-cols-2">
          {contract.monthly_estimate != null && (
            <div>
              <dt className="text-muted-foreground">Aylık tahmini tutar</dt>
              <dd className="mt-0.5 font-medium tabular-nums">
                {formatPrice(contract.monthly_estimate)}
              </dd>
            </div>
          )}
          {contract.default_quantity != null && (
            <div>
              <dt className="text-muted-foreground">Günlük porsiyon</dt>
              <dd className="mt-0.5 font-medium tabular-nums">{contract.default_quantity}</dd>
            </div>
          )}
          <div>
            <dt className="text-muted-foreground">Servis günleri</dt>
            <dd className="mt-0.5 font-medium">
              {contract.service_days.map((day) => DAY_NAMES[day] ?? '—').join(', ') || '—'}
            </dd>
          </div>
          <div>
            <dt className="text-muted-foreground">Süre</dt>
            <dd className="mt-0.5 font-medium">
              {contract.start_date ? formatDate(contract.start_date) : '—'}
              {' – '}
              {contract.end_date ? formatDate(contract.end_date) : 'süresiz'}
            </dd>
          </div>
        </dl>
      </section>

      <ContractBody body={contract.body} format={contract.body_format} />

      {approvable && (
        <section aria-label="Sözleşme onayı" className="mt-8">
          <h2 className="font-display text-h3 font-semibold text-heading">Sözleşmeyi onaylayın</h2>
          {contract.expires_at && (
            <p className="mt-1 text-sm text-muted-foreground">
              Bu bağlantı {formatDateTime(contract.expires_at)} tarihine kadar geçerli.
            </p>
          )}
          <div className="mt-4">
            <ContractApprovalForm token={token} maskedPhone={contract.masked_phone ?? null} />
          </div>
        </section>
      )}
    </div>
  );
}

/**
 * Sözleşme metni.
 *
 * ## Neden HTML değil?
 *
 * Sunucu HTML GÖNDERMİYOR (`body_format: markdown | plain`): metin panelde
 * yazılıyor ve doğrudan HTML gömmek, bu sayfaya script sokabilecek bir kapı
 * açardı. Gelen metin React'in metin düğümü olarak basılıyor, yani kaçış
 * otomatik.
 *
 * ## Markdown neden çizilmiyor?
 *
 * Bir markdown işleyici YENİ BİR BAĞIMLILIK demek ve `AGENTS.md` §2.4 önce
 * sormayı istiyor. Metin düz metin olarak da eksiksiz okunuyor — kalın yazı
 * kaybı, sözleşmenin anlamını değiştirmiyor. `markdown` geldiğinde de aynı
 * yol izleniyor; bilinmeyen bir `body_format` değeri de buraya düşer.
 */
function ContractBody({
  body,
  format,
}: {
  body: string;
  format: SubscriptionContract['body_format'];
}) {
  // Boş satırla ayrılan bloklar paragraf; blok İÇİNDEKİ satır sonları
  // `whitespace-pre-wrap` ile korunuyor (madde listeleri böyle ayakta kalıyor).
  const blocks = body.split(/\n{2,}/).filter((block) => block.trim().length > 0);

  return (
    <section aria-label="Sözleşme metni" className="mt-8">
      <h2 className="font-display text-h3 font-semibold text-heading">Sözleşme metni</h2>
      <div
        className="mt-3 space-y-4 rounded-xl border bg-card p-5 text-body-sm leading-relaxed sm:p-6"
        data-body-format={format}
      >
        {blocks.length > 0 ? (
          blocks.map((block, index) => (
            <p key={index} className="whitespace-pre-wrap">
              {block}
            </p>
          ))
        ) : (
          <p className="text-muted-foreground">Sözleşme metni boş görünüyor.</p>
        )}
      </div>
    </section>
  );
}

/**
 * Onaya kapalı durumların açıklaması.
 *
 * `Record<ContractStatus, …>` BİLEREK: sözleşmeye yeni bir durum eklendiğinde
 * derleyici burayı gösterir. `expired` ile `cancelled` AYRI cümleler kuruyor
 * — birinde abonenin yapacağı iş yeni bağlantı istemek, öbüründe yapacak bir
 * şey yok. Tek metne indirgenselerdi ikisine de aynı çözüm önerilirdi.
 */
const STATUS_NOTICE: Record<
  ContractStatus,
  { title: string; body: string; className: string } | null
> = {
  draft: null,
  sent: null,
  approved: {
    title: 'Bu sözleşme onaylandı',
    body: 'Onayınız kayıtlara geçti. Yeniden onaylamanız gerekmiyor.',
    className: 'border-success/30 bg-success/10',
  },
  expired: {
    title: 'Bağlantının süresi doldu',
    body: 'Sözleşmeyi bu bağlantıdan onaylayamazsınız. Bizimle iletişime geçip yeni bir onay bağlantısı isteyin.',
    className: 'border-warning/30 bg-warning/10',
  },
  cancelled: {
    title: 'Bu sözleşme geçersiz',
    body: 'Sözleşme iptal edildi ya da yerine yeni bir sürüm hazırlandı. Geçerli sürüm için gönderilen son bağlantıyı kullanın.',
    className: 'border-muted bg-muted/50',
  },
};
