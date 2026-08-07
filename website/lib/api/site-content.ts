import 'server-only';

import { cache } from 'react';
import { z } from 'zod';
import { apiFetch } from './client';
import { resolveIcon } from '@/lib/lucide-icon';
import {
  DIFFERENTIATORS,
  FAQ,
  GROUP_RELATION,
  MISSION,
  PROCESS_STEPS,
  VALUES,
  VISION,
} from '@/content/company';
import { MENU_SOLUTIONS, SEASONAL_APPROACH } from '@/content/menus';
import { POSTS } from '@/content/posts';
import { ALLERGEN_APPROACH, CERTIFICATIONS, QUALITY_CHAIN } from '@/content/quality';
import { SECTORS } from '@/content/sectors';
import { SERVICES } from '@/content/services';
import { BRAND, CONTACT, LOGO, SOCIAL } from '@/content/site';
import type { Differentiator, FaqItem, ProcessStep, Value } from '@/content/company';
import type { MenuCourse, MenuSolution } from '@/content/menus';
import type { Post } from '@/content/posts';
import type { QualityPrinciple } from '@/content/quality';
import type { Sector } from '@/content/sectors';
import type { Service } from '@/content/services';
import type { ContactChannel, Nullable, PostalAddress, WorkingHours } from '@/content/site';

/**
 * Kurumsal site içeriğinin tek okuma noktası.
 *
 * İçeriğin **tek kaynağı admin panelidir**; site onu `GET /site-content`
 * üzerinden okur. `content/*.ts` dosyaları artık veri kaynağı değil, **yedek**:
 * API'ye ulaşılamadığında veya sözleşme dışı bir yanıt geldiğinde sayfaların
 * doldurulacağı başlangıç değerleri.
 *
 * ## Neden yedek var, neden hata sayfası yok?
 *
 * Kurumsal site bir uygulama ekranı değil, vitrindir. Ziyaretçinin ilk gördüğü
 * şeyin sipariş altyapısının sağlığına bağlı olması yanlış — API bakımdayken
 * "hizmetlerimiz" sayfasının bomboş açılması, panelde henüz kimse içerik
 * girmediği için ana sayfanın kararması ya da tek bir bozuk alanın tüm sayfayı
 * düşürmesi kabul edilemez. Bu yüzden burada üç kademe var:
 *
 * 1. **Ağ/HTTP hatası** → tamamen yedeğe düşülür (`FALLBACK_CONTENT`).
 * 2. **Sözleşme dışı bölüm** → yalnızca o bölüm yedeğe düşer (`.catch(null)`).
 * 3. **Boş/eksik alan** → alan alan yedekle birleştirilir (`text`, `mapList`).
 *
 * Sonuç: panelde hiçbir şey doldurulmamış olsa bile site bugünkü hâliyle
 * ayakta kalır; bir bölüm doldurulduğu anda yalnızca o bölüm API'den gelir.
 *
 * ## Önbellek
 *
 * ISR: 5 dakika + `site-content` etiketi. Panel "kaydet"e bastığında
 * `app/api/icerik-tazele/route.ts` bu etiketi tazeler; yani 5 dakika üst sınır,
 * normal koşulda güncelleme anında yayına girer.
 */

/** `revalidateTag` bu etiketi kullanır — tazeleme ucuyla tek kaynaktan paylaşılır. */
export const SITE_CONTENT_TAG = 'site-content';

/** Panel tetiklemesi gelmezse içeriğin kendiliğinden tazeleneceği üst sınır. */
export const SITE_CONTENT_REVALIDATE_SECONDS = 300;

/* ══════════════════════════════════════════════════════════════════════════
   1. Site tarafındaki biçim (camelCase)

   Tipler bilerek `content/*.ts` içindekilerle aynı: sayfalar API'ye geçerken
   alan adı değiştirmek zorunda kalmasın. Yanıttaki snake_case yalnızca bu
   dosyanın içinde yaşıyor.
   ══════════════════════════════════════════════════════════════════════════ */

export interface SiteBrand {
  readonly name: string;
  readonly shortName: string;
  readonly parentGroup: string;
  readonly tagline: string;
  readonly description: string;
  /** Panelden yüklenen logo. Yoksa `BrandMark` harf işaretine düşer. */
  readonly logoSrc: Nullable<string>;
  readonly primaryColor: Nullable<string>;
}

export interface SiteContact {
  readonly phone: Nullable<ContactChannel>;
  readonly whatsapp: Nullable<ContactChannel>;
  readonly email: Nullable<ContactChannel>;
  readonly address: Nullable<PostalAddress>;
  readonly workingHours: readonly WorkingHours[];
  readonly social: readonly { readonly label: string; readonly href: string }[];
}

export interface SiteCompany {
  readonly mission: string;
  readonly vision: string;
  readonly groupRelation: string;
  readonly values: readonly Value[];
  readonly processSteps: readonly ProcessStep[];
  readonly differentiators: readonly Differentiator[];
}

export interface SiteCertification {
  readonly name: string;
  readonly issuer: string;
  readonly validUntil: Nullable<string>;
}

export interface SiteQuality {
  readonly chain: readonly QualityPrinciple[];
  readonly allergen: readonly string[];
  readonly certifications: readonly SiteCertification[];
}

export interface SiteMenus {
  readonly solutions: readonly MenuSolution[];
  readonly seasonal: readonly { readonly season: string; readonly note: string }[];
}

/**
 * Hizmet ve yazı gövdeleri.
 *
 * `bodyHtml` yalnızca panelden gelir; yedek içerikte `null`'dır. Yazılarda
 * yedek gövde hâlâ tipli bloklardan (`Post.body`) oluşuyor — sayfa hangisi
 * doluysa onu basar, böylece API kapalıyken de yazılar okunabilir kalır.
 */
export type SiteService = Service & { readonly bodyHtml: Nullable<string> };
export type SitePost = Post & { readonly bodyHtml: Nullable<string> };

export interface SiteContent {
  readonly brand: SiteBrand;
  readonly contact: SiteContact;
  readonly company: SiteCompany;
  readonly faq: readonly FaqItem[];
  readonly sectors: readonly Sector[];
  readonly menus: SiteMenus;
  readonly quality: SiteQuality;
  readonly services: readonly SiteService[];
  /** Yayın tarihine göre yeniden eskiye sıralı. */
  readonly posts: readonly SitePost[];
  readonly updatedAt: Nullable<string>;
  /** İçeriğin API'den mi yedekten mi geldiği — tanılama için, arayüz kullanmaz. */
  readonly origin: 'api' | 'fallback';
}

/* ══════════════════════════════════════════════════════════════════════════
   2. Sözleşme şeması (snake_case)

   Her üst düzey bölüm `.catch(null)` ile sarılı: bozuk bir `posts` dizisi
   `services`'i de düşürmesin, yalnızca kendi bölümü yedeğe düşsün.
   Bölüm içindeki alanlar `nullish` — panelde yarım doldurulmuş bir bölüm
   doğrulamayı düşürmek yerine alan bazında yedekle tamamlanır.
   ══════════════════════════════════════════════════════════════════════════ */

const channelSchema = z.object({ display: z.string(), href: z.string() });

const brandSchema = z.object({
  name: z.string().nullish(),
  short_name: z.string().nullish(),
  parent_group: z.string().nullish(),
  tagline: z.string().nullish(),
  description: z.string().nullish(),
  logo_url: z.string().nullish(),
  primary_color: z.string().nullish(),
});

const contactSchema = z.object({
  phone: channelSchema.nullish(),
  whatsapp: channelSchema.nullish(),
  email: channelSchema.nullish(),
  address: z
    .object({
      street_address: z.string(),
      district: z.string(),
      city: z.string(),
      postal_code: z.string().nullish(),
      map_embed_url: z.string().nullish(),
    })
    .nullish(),
  working_hours: z.array(z.object({ label: z.string(), value: z.string() })).nullish(),
  social: z.array(z.object({ label: z.string(), href: z.string() })).nullish(),
});

const titleBodySchema = z.object({ title: z.string(), body: z.string() });
const iconCardSchema = z.object({
  title: z.string(),
  icon: z.string().nullish(),
  body: z.string(),
});

const companySchema = z.object({
  mission: z.string().nullish(),
  vision: z.string().nullish(),
  group_relation: z.string().nullish(),
  values: z.array(titleBodySchema).nullish(),
  process_steps: z.array(iconCardSchema).nullish(),
  differentiators: z.array(iconCardSchema).nullish(),
});

const faqSchema = z.object({ question: z.string(), answer: z.string() });

const sectorSchema = z.object({
  slug: z.string(),
  title: z.string(),
  icon: z.string().nullish(),
  need: z.string(),
  answer: z.string(),
  service_slug: z.string(),
});

const menusSchema = z.object({
  solutions: z
    .array(
      z.object({
        slug: z.string(),
        title: z.string(),
        summary: z.string(),
        audience: z.string(),
        principle: z.string(),
        courses: z
          .array(
            z.object({
              label: z.string(),
              // Panelde tek satırlık metin olarak giriliyor; dizi de kabul edilir.
              examples: z.union([z.string(), z.array(z.string())]).nullish(),
            }),
          )
          .nullish(),
      }),
    )
    .nullish(),
  seasonal: z.array(z.object({ season: z.string(), note: z.string() })).nullish(),
});

const qualitySchema = z.object({
  chain: z.array(iconCardSchema).nullish(),
  // Panel `{text: "..."}` gönderiyor; düz metin de kabul edilir.
  allergen: z.array(z.union([z.string(), z.object({ text: z.string() })])).nullish(),
  certifications: z
    .array(
      z.object({
        name: z.string(),
        issuer: z.string(),
        valid_until: z.string().nullish(),
      }),
    )
    .nullish(),
});

const serviceSchema = z.object({
  slug: z.string(),
  title: z.string(),
  summary: z.string(),
  intro: z.string(),
  icon: z.string().nullish(),
  body_html: z.string().nullish(),
  audience: z.array(z.string()).nullish(),
  how_it_works: z.array(titleBodySchema).nullish(),
  benefits: z.array(z.string()).nullish(),
  menu_planning: z.string().nullish(),
  quote_needs: z.array(z.string()).nullish(),
});

const postSchema = z.object({
  slug: z.string(),
  title: z.string(),
  description: z.string(),
  category: z.string(),
  published_at: z.string(),
  // Panel sayıyı metin olarak yollayabiliyor; sayfa `number` bekliyor.
  reading_minutes: z.coerce.number().nullish(),
  body_html: z.string().nullish(),
});

const siteContentSchema = z.object({
  brand: brandSchema.nullish().catch(null),
  contact: contactSchema.nullish().catch(null),
  company: companySchema.nullish().catch(null),
  faq: z.array(faqSchema).nullish().catch(null),
  sectors: z.array(sectorSchema).nullish().catch(null),
  menus: menusSchema.nullish().catch(null),
  quality: qualitySchema.nullish().catch(null),
  services: z.array(serviceSchema).nullish().catch(null),
  posts: z.array(postSchema).nullish().catch(null),
  updated_at: z.string().nullish().catch(null),
});

type SiteContentResponse = z.infer<typeof siteContentSchema>;

/* ══════════════════════════════════════════════════════════════════════════
   3. Yedek içerik
   ══════════════════════════════════════════════════════════════════════════ */

function byNewestFirst(posts: readonly SitePost[]): readonly SitePost[] {
  return [...posts].sort((a, b) => b.publishedAt.localeCompare(a.publishedAt));
}

/**
 * `content/*.ts` dosyalarından derlenen yedek.
 *
 * Modül yüklenirken bir kez kuruluyor: her istekte yeniden üretmek gereksiz iş
 * ve nesne kimliği değiştiği için React'ın yeniden render kararlarını bozar.
 */
const FALLBACK_CONTENT: SiteContent = {
  brand: {
    name: BRAND.name,
    shortName: BRAND.shortName,
    parentGroup: BRAND.parentGroup,
    tagline: BRAND.tagline,
    description: BRAND.description,
    logoSrc: LOGO.src,
    primaryColor: null,
  },
  contact: {
    phone: CONTACT.phone,
    whatsapp: CONTACT.whatsapp,
    email: CONTACT.email,
    address: CONTACT.address,
    workingHours: CONTACT.workingHours,
    social: SOCIAL,
  },
  company: {
    mission: MISSION,
    vision: VISION,
    groupRelation: GROUP_RELATION,
    values: VALUES,
    processSteps: PROCESS_STEPS,
    differentiators: DIFFERENTIATORS,
  },
  faq: FAQ,
  sectors: SECTORS,
  menus: { solutions: MENU_SOLUTIONS, seasonal: SEASONAL_APPROACH },
  quality: {
    chain: QUALITY_CHAIN,
    allergen: ALLERGEN_APPROACH,
    certifications: CERTIFICATIONS,
  },
  services: SERVICES.map((service) => ({ ...service, bodyHtml: null })),
  posts: byNewestFirst(POSTS.map((post) => ({ ...post, bodyHtml: null }))),
  updatedAt: null,
  origin: 'fallback',
};

/* ══════════════════════════════════════════════════════════════════════════
   4. Birleştirme

   Kural: API'den gelen **dolu** değer kazanır. Boş metin, `null` ve boş dizi
   "henüz doldurulmadı" demektir ve yedeğe düşer — panelde bir bölüm boş
   bırakıldı diye sayfanın o kısmının kaybolmasını istemiyoruz.
   ══════════════════════════════════════════════════════════════════════════ */

function text(value: string | null | undefined, fallback: string): string {
  const trimmed = value?.trim();
  return trimmed !== undefined && trimmed.length > 0 ? trimmed : fallback;
}

function optionalText(
  value: string | null | undefined,
  fallback: Nullable<string>,
): Nullable<string> {
  const trimmed = value?.trim();
  return trimmed !== undefined && trimmed.length > 0 ? trimmed : fallback;
}

function mapList<TIn, TOut>(
  input: readonly TIn[] | null | undefined,
  map: (item: TIn) => TOut,
  fallback: readonly TOut[],
): readonly TOut[] {
  if (!input || input.length === 0) return fallback;
  return input.map(map);
}

/** Panelde virgülle ayrılmış tek metin olarak girilen örnekler. */
function toExamples(value: string | readonly string[] | null | undefined): readonly string[] {
  if (Array.isArray(value)) return value.map((item) => item.trim()).filter(Boolean);
  if (typeof value !== 'string') return [];
  return value
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

function mergeBrand(input: SiteContentResponse['brand']): SiteBrand {
  const fallback = FALLBACK_CONTENT.brand;
  if (!input) return fallback;

  return {
    name: text(input.name, fallback.name),
    shortName: text(input.short_name, fallback.shortName),
    parentGroup: text(input.parent_group, fallback.parentGroup),
    tagline: text(input.tagline, fallback.tagline),
    description: text(input.description, fallback.description),
    logoSrc: optionalText(input.logo_url, fallback.logoSrc),
    primaryColor: optionalText(input.primary_color, fallback.primaryColor),
  };
}

function mergeContact(input: SiteContentResponse['contact']): SiteContact {
  const fallback = FALLBACK_CONTENT.contact;
  if (!input) return fallback;

  /*
   * İletişim kanalları için kural TERS: burada yedek "bilinmiyor" (`null`)
   * demek ve `content/site.ts` bunu bilinçli bir durum olarak tanımlıyor.
   * Panelden gelen `null`, "bu kanal yok" anlamına gelir ve olduğu gibi
   * korunur — yedekte zaten `null` olduğu için sonuç değişmiyor, ama ileride
   * yedeğe gerçek bir numara girilse bile panelin silme kararı geçersiz
   * kılınmaz.
   */
  return {
    phone: input.phone ?? null,
    whatsapp: input.whatsapp ?? null,
    email: input.email ?? null,
    address: input.address
      ? {
          streetAddress: input.address.street_address,
          district: input.address.district,
          city: input.address.city,
          postalCode: optionalText(input.address.postal_code, null),
          mapEmbedUrl: optionalText(input.address.map_embed_url, null),
        }
      : null,
    workingHours: input.working_hours ?? fallback.workingHours,
    social: input.social ?? fallback.social,
  };
}

function mergeCompany(input: SiteContentResponse['company']): SiteCompany {
  const fallback = FALLBACK_CONTENT.company;
  if (!input) return fallback;

  return {
    mission: text(input.mission, fallback.mission),
    vision: text(input.vision, fallback.vision),
    groupRelation: text(input.group_relation, fallback.groupRelation),
    values: mapList(
      input.values,
      (item) => ({ title: item.title, body: item.body }),
      fallback.values,
    ),
    processSteps: mapList(
      input.process_steps,
      (item) => ({ title: item.title, body: item.body, icon: resolveIcon(item.icon) }),
      fallback.processSteps,
    ),
    differentiators: mapList(
      input.differentiators,
      (item) => ({ title: item.title, body: item.body, icon: resolveIcon(item.icon) }),
      fallback.differentiators,
    ),
  };
}

function mergeMenus(input: SiteContentResponse['menus']): SiteMenus {
  const fallback = FALLBACK_CONTENT.menus;
  if (!input) return fallback;

  return {
    solutions: mapList(
      input.solutions,
      (solution): MenuSolution => ({
        slug: solution.slug,
        title: solution.title,
        summary: solution.summary,
        audience: solution.audience,
        principle: solution.principle,
        courses: (solution.courses ?? []).map((course): MenuCourse => ({
          label: course.label,
          examples: toExamples(course.examples),
        })),
      }),
      fallback.solutions,
    ),
    seasonal: mapList(
      input.seasonal,
      (entry) => ({ season: entry.season, note: entry.note }),
      fallback.seasonal,
    ),
  };
}

function mergeQuality(input: SiteContentResponse['quality']): SiteQuality {
  const fallback = FALLBACK_CONTENT.quality;
  if (!input) return fallback;

  return {
    chain: mapList(
      input.chain,
      (item) => ({ title: item.title, body: item.body, icon: resolveIcon(item.icon) }),
      fallback.chain,
    ),
    allergen: mapList(
      input.allergen,
      (entry) => (typeof entry === 'string' ? entry : entry.text),
      fallback.allergen,
    ),
    /*
     * Sertifikalarda BOŞ DİZİ geçerli bir cevaptır ve yedeğe düşmez: sahip
     * olunmayan bir belgeyi göstermek gıda sektöründe yaptırımı olan bir
     * beyandır (`content/quality.ts`). Panel listeyi boşaltabilmeli.
     */
    certifications: input.certifications
      ? input.certifications.map((item) => ({
          name: item.name,
          issuer: item.issuer,
          validUntil: optionalText(item.valid_until, null),
        }))
      : fallback.certifications,
  };
}

function mergeServices(input: SiteContentResponse['services']): readonly SiteService[] {
  return mapList(
    input,
    (service): SiteService => ({
      slug: service.slug,
      title: service.title,
      summary: service.summary,
      intro: service.intro,
      icon: resolveIcon(service.icon),
      audience: service.audience ?? [],
      howItWorks: service.how_it_works ?? [],
      benefits: service.benefits ?? [],
      menuPlanning: service.menu_planning ?? '',
      quoteNeeds: service.quote_needs ?? [],
      bodyHtml: optionalText(service.body_html, null),
    }),
    FALLBACK_CONTENT.services,
  );
}

/**
 * Okuma süresi tahmini.
 *
 * Panel bu alanı boş bırakabiliyor. Sabit bir sayı yazmak uydurma olurdu;
 * bunun yerine gövdedeki sözcük sayısından hesaplıyoruz (Türkçe için ~200
 * sözcük/dakika). En az 1 dakika — "0 dakika okuma" anlamsız görünür.
 */
function estimateReadingMinutes(bodyHtml: Nullable<string>): number {
  if (!bodyHtml) return 1;
  const words = bodyHtml
    .replace(/<[^>]*>/g, ' ')
    .trim()
    .split(/\s+/).length;
  return Math.max(1, Math.round(words / 200));
}

function mergePosts(input: SiteContentResponse['posts']): readonly SitePost[] {
  return byNewestFirst(
    mapList(
      input,
      (post): SitePost => {
        const bodyHtml = optionalText(post.body_html, null);
        return {
          slug: post.slug,
          title: post.title,
          description: post.description,
          category: post.category,
          publishedAt: post.published_at,
          readingMinutes: post.reading_minutes ?? estimateReadingMinutes(bodyHtml),
          // Panelden gelen yazının tipli blok gövdesi yok; metin `bodyHtml`'de.
          body: [],
          bodyHtml,
        };
      },
      FALLBACK_CONTENT.posts,
    ),
  );
}

function merge(input: SiteContentResponse): SiteContent {
  return {
    brand: mergeBrand(input.brand),
    contact: mergeContact(input.contact),
    company: mergeCompany(input.company),
    faq: mapList(
      input.faq,
      (item) => ({ question: item.question, answer: item.answer }),
      FALLBACK_CONTENT.faq,
    ),
    sectors: mapList(
      input.sectors,
      (sector): Sector => ({
        slug: sector.slug,
        title: sector.title,
        icon: resolveIcon(sector.icon),
        need: sector.need,
        answer: sector.answer,
        serviceSlug: sector.service_slug,
      }),
      FALLBACK_CONTENT.sectors,
    ),
    menus: mergeMenus(input.menus),
    quality: mergeQuality(input.quality),
    services: mergeServices(input.services),
    posts: mergePosts(input.posts),
    updatedAt: optionalText(input.updated_at, null),
    origin: 'api',
  };
}

/* ══════════════════════════════════════════════════════════════════════════
   5. Okuma
   ══════════════════════════════════════════════════════════════════════════ */

/**
 * Kurumsal içeriği getirir. **Asla hata fırlatmaz.**
 *
 * `cache()`: tek bir render sırasında başlık, altbilgi, sayfa gövdesi ve çağrı
 * bandı aynı içeriği istiyor. Başarılı istekleri Next zaten tekilleştiriyor,
 * ama başarısız olanları etmiyor — API kapalıyken her bileşen için ayrı bir
 * bağlantı denemesi yapılmasın diye sonucu istek ömrü boyunca tutuyoruz.
 */
export const fetchSiteContent = cache(async (): Promise<SiteContent> => {
  let raw: unknown;

  try {
    raw = await apiFetch<unknown>('/site-content', {
      cache: {
        kind: 'revalidate',
        seconds: SITE_CONTENT_REVALIDATE_SECONDS,
        tags: [SITE_CONTENT_TAG],
      },
    });
  } catch (cause) {
    console.warn('[site-content] API okunamadı, yedek içerik kullanılıyor.', cause);
    return FALLBACK_CONTENT;
  }

  const parsed = siteContentSchema.safeParse(raw);
  if (!parsed.success) {
    // Buraya düşmek için yanıtın nesne bile olmaması gerekir; bölüm bazlı
    // bozulmalar `.catch(null)` ile yukarıda yakalanıyor.
    console.warn('[site-content] Yanıt sözleşmeye uymadı, yedek içerik kullanılıyor.');
    return FALLBACK_CONTENT;
  }

  return merge(parsed.data);
});

/* ══════════════════════════════════════════════════════════════════════════
   6. Türetilmiş yardımcılar

   Eskiden `content/*.ts` içindeydiler; artık **birleştirilmiş** içerik
   üzerinden çalışıyorlar, yoksa panel doldurulduğunda hâlâ yedeğe bakarlardı.
   ══════════════════════════════════════════════════════════════════════════ */

/**
 * Firma sahibinin doldurması gereken iletişim alanları.
 *
 * İletişim sayfası bu listeyi okuyup, henüz girilmemiş kanallar yüzünden
 * sayfanın boş kalmasını engelleyen bir yönlendirme gösterir. Liste
 * boşaldığında o yönlendirme kendiliğinden kaybolur.
 */
export function pendingContactFields(contact: SiteContact): readonly string[] {
  return [
    contact.phone ? null : 'telefon',
    contact.whatsapp ? null : 'WhatsApp',
    contact.email ? null : 'e-posta',
    contact.address ? null : 'adres',
    contact.workingHours.length > 0 ? null : 'çalışma saatleri',
  ].filter((field): field is string => field !== null);
}

export function hasAnyContactChannel(contact: SiteContact): boolean {
  return contact.phone !== null || contact.whatsapp !== null || contact.email !== null;
}

export function findService(
  services: readonly SiteService[],
  slug: string,
): SiteService | undefined {
  return services.find((service) => service.slug === slug);
}

export function findPost(posts: readonly SitePost[], slug: string): SitePost | undefined {
  return posts.find((post) => post.slug === slug);
}
