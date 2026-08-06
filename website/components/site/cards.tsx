import Link from 'next/link';
import { ArrowRight } from 'lucide-react';
import type { LucideIcon } from 'lucide-react';
import type { ReactNode } from 'react';
import { cn } from '@/lib/utils';

/**
 * Kart ailesi.
 *
 * Hepsi aynı beyaz kutu değil: hizmet kartı ikon başlıklı ve tıklanabilir,
 * sektör kartı iki bölümlü (ihtiyaç/karşılık), süreç adımı numaralı ve
 * bağlantılı, ilke kartı çerçevesiz. Sayfada ritim bu farklardan doğuyor.
 */

/** Tıklanabilir hizmet kartı. Tüm yüzey link — dokunma hedefi kartın kendisi. */
export function ServiceCard({
  href,
  icon: Icon,
  title,
  summary,
}: {
  href: string;
  icon: LucideIcon;
  title: string;
  summary: string;
}) {
  return (
    <Link
      href={href}
      className={cn(
        'group relative flex flex-col rounded-2xl border bg-card p-6 text-card-foreground transition-all',
        'hover:border-primary/40 hover:shadow-md motion-safe:hover:-translate-y-0.5',
        'focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2',
      )}
    >
      <span
        aria-hidden="true"
        className="grid size-12 place-items-center rounded-xl bg-accent text-accent-foreground"
      >
        <Icon className="size-6" />
      </span>

      <h3 className="mt-5 font-display text-lg font-semibold tracking-tight">{title}</h3>
      <p className="mt-2 flex-1 text-sm/6 text-muted-foreground">{summary}</p>

      <span className="mt-5 inline-flex items-center gap-1.5 text-sm font-semibold text-primary">
        Detaylara bak
        <ArrowRight
          aria-hidden="true"
          className="size-4 transition-transform motion-safe:group-hover:translate-x-1"
        />
      </span>
    </Link>
  );
}

/** Sektör kartı — "ihtiyaç" ve "bizim karşılığımız" ayrı okunacak biçimde. */
export function SectorCard({
  icon: Icon,
  title,
  need,
  answer,
  href,
}: {
  icon: LucideIcon;
  title: string;
  need: string;
  answer: string;
  href: string;
}) {
  return (
    <article className="flex flex-col overflow-hidden rounded-2xl border bg-card text-card-foreground">
      <div className="flex items-center gap-3 border-b px-6 py-5">
        <span aria-hidden="true" className="text-primary">
          <Icon className="size-5" />
        </span>
        <h3 className="font-display text-lg font-semibold tracking-tight">{title}</h3>
      </div>

      <div className="flex-1 space-y-4 px-6 py-5">
        <div>
          <p className="text-xs font-semibold tracking-wider text-muted-foreground uppercase">
            İhtiyaç
          </p>
          <p className="mt-1.5 text-sm/6">{need}</p>
        </div>
        <div>
          <p className="text-xs font-semibold tracking-wider text-primary uppercase">
            Karşılığımız
          </p>
          <p className="mt-1.5 text-sm/6">{answer}</p>
        </div>
      </div>

      <div className="px-6 pb-5">
        <Link
          href={href}
          className="inline-flex items-center gap-1.5 text-sm font-semibold text-primary underline-offset-4 hover:underline"
        >
          İlgili hizmet
          <ArrowRight aria-hidden="true" className="size-4" />
        </Link>
      </div>
    </article>
  );
}

/** Numaralı süreç adımı. Sıralı liste öğesi olarak kullanılır. */
export function ProcessStepCard({
  index,
  icon: Icon,
  title,
  body,
}: {
  index: number;
  icon: LucideIcon;
  title: string;
  body: string;
}) {
  return (
    // `group/step`: birleştirici çizginin "son adım mıyım" sorusunu sorabilmesi
    // için isimlendirilmiş grup. Çizgi kendi kapsayıcısının zaten son çocuğu
    // olduğundan `last:hidden` her adımda gizlerdi — sorulması gereken,
    // çizginin değil ADIMIN sonuncu olup olmadığı.
    <li className="group/step relative flex gap-5">
      <div className="flex flex-col items-center">
        <span
          aria-hidden="true"
          className="grid size-11 shrink-0 place-items-center rounded-full bg-primary text-sm font-bold text-primary-foreground"
        >
          {index}
        </span>
        <span aria-hidden="true" className="mt-2 w-px flex-1 bg-border group-last/step:hidden" />
      </div>

      <div className="pb-10">
        <div className="flex items-center gap-2">
          <Icon aria-hidden="true" className="size-4 text-primary" />
          <h3 className="font-display text-lg font-semibold tracking-tight">{title}</h3>
        </div>
        <p className="mt-2 max-w-xl text-sm/6 text-muted-foreground">{body}</p>
      </div>
    </li>
  );
}

/** Çerçevesiz ilke/özellik bloğu — kart yığınını kırmak için. */
export function FeatureItem({
  icon: Icon,
  title,
  body,
  tone = 'light',
}: {
  icon: LucideIcon;
  title: string;
  body: string;
  tone?: 'light' | 'dark';
}) {
  return (
    <div>
      <span
        aria-hidden="true"
        className={cn(
          'grid size-11 place-items-center rounded-xl',
          tone === 'light' ? 'bg-accent text-accent-foreground' : 'bg-white/10 text-white',
        )}
      >
        <Icon className="size-5" />
      </span>
      <h3 className="mt-4 font-display text-base font-semibold tracking-tight">{title}</h3>
      <p
        className={cn('mt-2 text-sm/6', tone === 'light' ? 'text-muted-foreground' : 'opacity-75')}
      >
        {body}
      </p>
    </div>
  );
}

/** Menü çözümü kartı — kap kap listeleme için. */
export function MenuSolutionCard({
  title,
  summary,
  audience,
  children,
}: {
  title: string;
  summary: string;
  audience: string;
  children: ReactNode;
}) {
  return (
    <article className="flex flex-col rounded-2xl border bg-card p-6 text-card-foreground">
      <h3 className="font-display text-xl font-semibold tracking-tight">{title}</h3>
      <p className="mt-2 text-sm/6 text-muted-foreground">{summary}</p>
      <p className="mt-3 text-xs font-semibold text-primary">{audience}</p>
      <div className="mt-5 flex-1 border-t pt-5">{children}</div>
    </article>
  );
}

/** Blog/bilgi merkezi kartı. */
export function PostCard({
  href,
  category,
  title,
  description,
  publishedAt,
  readingMinutes,
}: {
  href: string;
  category: string;
  title: string;
  description: string;
  publishedAt: string;
  readingMinutes: number;
}) {
  return (
    // `relative`: başlıktaki yayılan bağlantının (`after:inset-0`) sınırı bu kart.
    <article className="group relative flex flex-col rounded-2xl border bg-card p-6 text-card-foreground transition-all hover:shadow-md motion-safe:hover:-translate-y-0.5">
      <p className="text-xs font-semibold tracking-wider text-primary uppercase">{category}</p>

      <h3 className="mt-3 font-display text-lg font-semibold tracking-tight">
        {/* Kartın tamamı tıklanabilir olsun diye yayılan bağlantı; odak halkası
            başlıkta kalır, böylece klavye kullanıcısı nerede olduğunu görür. */}
        <Link href={href} className="after:absolute after:inset-0">
          <span className="relative">{title}</span>
        </Link>
      </h3>

      <p className="mt-2 flex-1 text-sm/6 text-muted-foreground">{description}</p>

      <p className="mt-5 text-xs text-muted-foreground">
        <time dateTime={publishedAt}>
          {new Date(publishedAt).toLocaleDateString('tr-TR', {
            day: 'numeric',
            month: 'long',
            year: 'numeric',
          })}
        </time>
        <span aria-hidden="true"> · </span>
        {readingMinutes} dakika okuma
      </p>
    </article>
  );
}
