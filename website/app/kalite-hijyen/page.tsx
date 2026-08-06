import { Check, FileCheck } from 'lucide-react';
import { JsonLd } from '@/components/json-ld';
import { CtaBand } from '@/components/site/cta-band';
import { PageHero } from '@/components/site/page-hero';
import { Section, SectionHeading } from '@/components/site/section';
import { ALLERGEN_APPROACH, CERTIFICATIONS, QUALITY_CHAIN } from '@/content/quality';
import { breadcrumbJsonLd, pageMetadata } from '@/lib/seo';
import type { Crumb } from '@/components/site/page-hero';

/**
 * Kalite ve hijyen sayfası.
 *
 * Sertifika bölümü `CERTIFICATIONS` doluysa basılır; boşken sahte bir belge
 * iddiası doğmasın diye bölüm hiç render edilmez ve yerine uygulanan yöntemi
 * anlatan bir açıklama kalır. Gerekçe: `content/quality.ts` dosya başı yorumu.
 */

const CRUMBS: readonly Crumb[] = [{ href: '/kalite-hijyen', label: 'Kalite ve Hijyen' }];

export const metadata = pageMetadata({
  title: 'Kalite ve Hijyen',
  description:
    'Hammadde girişinden teslimata kadar sekiz halkalı hijyen zinciri, alerjen yönetimi ve izlenebilirlik yaklaşımımız.',
  path: '/kalite-hijyen',
});

export default function KaliteHijyenPage() {
  const hasCertifications = CERTIFICATIONS.length > 0;

  return (
    <>
      <JsonLd data={breadcrumbJsonLd(CRUMBS)} />

      <PageHero
        crumbs={CRUMBS}
        eyebrow="Kalite ve Hijyen"
        title="Hijyen, işin kendisidir"
        description="Toplu üretimde güvenliği tek bir kontrol değil, birbirine bağlı bir zincir sağlar. Aşağıda o zincirin halkaları var."
      />

      <Section aria-labelledby="giris-baslik">
        <SectionHeading
          id="giris-baslik"
          eyebrow="Yaklaşımımız"
          title="Zincirin en zayıf halkası kadar güçlü"
          description="Her halka bir öncekine bağlı: malzeme uygun değilse depolama, depolama bozuksa üretim anlamını yitirir. Bu yüzden hepsi tek akış olarak yürütülür."
        />
      </Section>

      <Section tone="muted" aria-labelledby="zincir-baslik">
        <SectionHeading
          id="zincir-baslik"
          eyebrow="Hijyen zinciri"
          title="Hammaddeden teslimata sekiz halka"
        />

        <ol className="mt-10 grid bld-reveal gap-5 md:grid-cols-2">
          {QUALITY_CHAIN.map((link, index) => {
            const Icon = link.icon;
            return (
              <li
                key={link.title}
                className="flex gap-5 rounded-2xl border bg-card p-6 text-card-foreground"
              >
                <span
                  aria-hidden="true"
                  className="grid size-11 shrink-0 place-items-center rounded-xl bg-accent text-sm font-bold text-accent-foreground"
                >
                  {String(index + 1).padStart(2, '0')}
                </span>

                <div>
                  <div className="flex items-center gap-2">
                    <Icon aria-hidden="true" className="size-4 text-primary" />
                    <h3 className="font-display text-lg font-semibold tracking-tight">
                      {link.title}
                    </h3>
                  </div>
                  <p className="mt-2 text-sm/6 text-muted-foreground">{link.body}</p>
                </div>
              </li>
            );
          })}
        </ol>
      </Section>

      {/* Alerjen bölümü koyu bantta: sorumluluğun kurumla paylaşıldığı tek
          başlık, sayfada gözden kaçmaması gerekiyor. */}
      <Section tone="olive" aria-labelledby="alerjen-baslik">
        <div className="max-w-3xl">
          <h2
            id="alerjen-baslik"
            className="font-display text-3xl font-semibold tracking-tight sm:text-4xl"
          >
            Alerjen yaklaşımı
          </h2>
          <p className="mt-4 text-base/7 opacity-80">
            Alerjen yönetimi tek taraflı yürümez; doğru bilgi kurumdan gelir, uygulama bizde olur.
          </p>

          <ul className="mt-8 bld-reveal space-y-4">
            {ALLERGEN_APPROACH.map((item) => (
              <li key={item} className="flex gap-3">
                <Check aria-hidden="true" className="mt-1 size-4 shrink-0" />
                <span className="text-base/7 opacity-90">{item}</span>
              </li>
            ))}
          </ul>
        </div>
      </Section>

      <Section tone="warm" aria-labelledby="belge-baslik">
        <div className="max-w-3xl bld-reveal">
          <span
            aria-hidden="true"
            className="grid size-11 place-items-center rounded-xl bg-accent text-accent-foreground"
          >
            <FileCheck className="size-5" />
          </span>

          <h2
            id="belge-baslik"
            className="mt-5 font-display text-3xl font-semibold tracking-tight sm:text-4xl"
          >
            {hasCertifications ? 'Belgelerimiz' : 'Belge yerine yöntem'}
          </h2>

          {hasCertifications ? (
            <ul className="mt-8 grid gap-5 sm:grid-cols-2">
              {CERTIFICATIONS.map((certification) => (
                <li
                  key={certification.name}
                  className="rounded-2xl border bg-card p-6 text-card-foreground"
                >
                  <h3 className="font-display text-lg font-semibold tracking-tight">
                    {certification.name}
                  </h3>
                  <p className="mt-2 text-sm/6 text-muted-foreground">{certification.issuer}</p>
                  {certification.validUntil && (
                    <p className="mt-1 text-sm/6 text-muted-foreground">
                      Geçerlilik: {certification.validUntil}
                    </p>
                  )}
                </li>
              ))}
            </ul>
          ) : (
            <div className="bld-prose mt-5">
              <p>
                Bu sayfada belge görseli veya sertifika adı bulunmuyor. Sahip olunmayan bir belgeyi
                varmış gibi göstermek gıda sektöründe yaptırımı olan bir beyandır; bu yüzden
                anlattığımız tek şey uygulanan yöntem.
              </p>
              <p>
                Kurumunuzun tedarikçi denetimi kapsamında resmî belge talebi varsa, hangi belgelerin
                paylaşılabileceğini teklif görüşmesinde açıkça iletiyoruz.
              </p>
            </div>
          )}
        </div>
      </Section>

      <CtaBand />
    </>
  );
}
