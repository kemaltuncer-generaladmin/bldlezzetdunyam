import Image from 'next/image';
import Link from 'next/link';
import { ArrowRight } from 'lucide-react';
import type { LucideIcon } from 'lucide-react';
import type { ReactNode } from 'react';
import { cn } from '@/lib/utils';

/**
 * Kart ailesi.
 *
 * Hepsi aynı beyaz kutu değil: hizmet kartı fotoğraf başlıklı ve tıklanabilir,
 * sektör kartı fotoğraf + iki paragraf, süreç adımı numaralı, ilke kartı
 * çerçevesiz. Sayfada ritim bu farklardan doğuyor.
 *
 * ## Fotoğraf zorunlu değil
 *
 * `image` verilmezse kart ikonlu, fotoğrafsız düzene döner. Bunun sebebi
 * panelin yeni bir hizmet/sektör ekleyebilmesi: o kaydın fotoğrafı olmayacak
 * (bkz. `lib/site-images.ts`) ve kırık görsel yerine sade bir kart çıkmalı.
 */

/** Fotoğraflı kart başlığı. `priority` yalnızca ilk ekranda görünenler için. */
function CardPhoto({
  src,
  ratio,
  priority = false,
  overlay = false,
}: {
  src: string;
  ratio: 'video' | '4/3';
  priority?: boolean;
  overlay?: boolean;
}) {
  return (
    <div
      className={cn(
        'relative overflow-hidden bg-muted',
        ratio === 'video' ? 'aspect-video' : 'aspect-4/3',
      )}
    >
      <Image
        // Fotoğraf dekoratif: başlık ve özet aynı bilgiyi zaten metin olarak
        // veriyor, alt metni doldurmak ekran okuyucuda tekrara yol açardı.
        alt=""
        src={src}
        fill
        priority={priority}
        sizes="(max-width: 640px) 100vw, (max-width: 1024px) 50vw, 380px"
        className="object-cover transition-transform duration-500 motion-safe:group-hover:scale-105"
      />
      {overlay && (
        // Krem başlık fotoğrafın üstünde duruyor; `/85` başlangıç değeri
        // aydınlık karelerde bile AA eşiğini geçmesi için ölçülerek seçildi.
        <div
          aria-hidden="true"
          className="absolute inset-0 bg-linear-to-t from-charcoal/85 via-charcoal/35 to-transparent"
        />
      )}
    </div>
  );
}

/** Tıklanabilir hizmet kartı. Tüm yüzey link — dokunma hedefi kartın kendisi. */
export function ServiceCard({
  href,
  icon: Icon,
  title,
  summary,
  image,
  priority = false,
}: {
  href: string;
  icon: LucideIcon;
  title: string;
  summary: string;
  image?: string | null;
  priority?: boolean;
}) {
  return (
    <Link
      href={href}
      className={cn(
        'group relative flex h-full flex-col overflow-hidden rounded-2xl border bg-card text-card-foreground transition-all',
        'hover:border-primary/40 hover:shadow-lg motion-safe:hover:-translate-y-0.5',
        'focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2',
      )}
    >
      {image ? (
        <CardPhoto src={image} ratio="video" priority={priority} />
      ) : (
        <span
          aria-hidden="true"
          className="grid aspect-video place-items-center bg-accent text-accent-foreground"
        >
          <Icon className="size-10" />
        </span>
      )}

      <div className="flex flex-1 flex-col p-6">
        <h3 className="font-display text-lg font-semibold tracking-tight">{title}</h3>
        <p className="mt-2 flex-1 text-sm/6 text-muted-foreground">{summary}</p>

        <span className="mt-5 inline-flex items-center gap-1.5 text-sm font-semibold text-primary">
          Detaylara bak
          <ArrowRight
            aria-hidden="true"
            className="size-4 transition-transform motion-safe:group-hover:translate-x-1"
          />
        </span>
      </div>
    </Link>
  );
}

/**
 * Sektör kartı.
 *
 * Önceki sürümde "İHTİYAÇ" ve "KARŞILIĞIMIZ" diye iki büyük harf etiket vardı;
 * yedi kart yan yana gelince sayfa forma benziyordu. Etiketler kalktı, iki
 * paragraf tipografiyle ayrılıyor: ihtiyaç koyu, karşılık normal.
 */
export function SectorCard({
  icon: Icon,
  title,
  need,
  answer,
  href,
  image,
}: {
  icon: LucideIcon;
  title: string;
  need: string;
  answer: string;
  href: string;
  image?: string | null;
}) {
  return (
    <article className="group relative flex h-full flex-col overflow-hidden rounded-2xl border bg-card text-card-foreground transition-shadow hover:shadow-lg">
      {image ? (
        <div className="relative">
          <CardPhoto src={image} ratio="4/3" overlay />
          <h3 className="absolute inset-x-5 bottom-4 font-display text-xl font-semibold tracking-tight text-cream">
            {title}
          </h3>
        </div>
      ) : (
        <div className="flex items-center gap-3 border-b px-6 py-5">
          <Icon aria-hidden="true" className="size-5 text-primary" />
          <h3 className="font-display text-lg font-semibold tracking-tight">{title}</h3>
        </div>
      )}

      <div className="flex flex-1 flex-col gap-3 px-6 py-5">
        <p className="text-sm/6 font-medium">{need}</p>
        <p className="flex-1 text-sm/6 text-muted-foreground">{answer}</p>

        <Link
          href={href}
          className="mt-1 inline-flex items-center gap-1.5 text-sm font-semibold text-primary underline-offset-4 after:absolute after:inset-0 hover:underline"
        >
          <span className="relative">İlgili hizmet</span>
          <ArrowRight aria-hidden="true" className="relative size-4" />
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
  image,
  children,
}: {
  title: string;
  summary: string;
  audience: string;
  image?: string | null;
  children: ReactNode;
}) {
  return (
    <article className="group flex h-full flex-col overflow-hidden rounded-2xl border bg-card text-card-foreground">
      {image && <CardPhoto src={image} ratio="4/3" />}

      <div className="flex flex-1 flex-col p-6">
        <h3 className="font-display text-xl font-semibold tracking-tight">{title}</h3>
        <p className="mt-2 text-sm/6 text-muted-foreground">{summary}</p>
        <p className="mt-3 text-xs font-semibold text-primary">{audience}</p>
        <div className="mt-5 flex-1 border-t pt-5">{children}</div>
      </div>
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
  image,
}: {
  href: string;
  category: string;
  title: string;
  description: string;
  publishedAt: string;
  readingMinutes: number;
  image?: string | null;
}) {
  return (
    // `relative`: başlıktaki yayılan bağlantının (`after:inset-0`) sınırı bu kart.
    <article className="group relative flex h-full flex-col overflow-hidden rounded-2xl border bg-card text-card-foreground transition-all hover:shadow-lg motion-safe:hover:-translate-y-0.5">
      {image && <CardPhoto src={image} ratio="video" />}

      <div className="flex flex-1 flex-col p-6">
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
      </div>
    </article>
  );
}
