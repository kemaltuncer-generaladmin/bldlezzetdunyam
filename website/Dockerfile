# Next.js 15 üretim imajı — docs/06-website.md
#
# Üç aşama: bağımlılıklar / derleme / çalıştırma. Ayırmanın sebebi son
# imajda ne derleme araçları ne de dev bağımlılıkları kalsın.

FROM node:22-alpine AS deps
WORKDIR /app
COPY website/package.json website/package-lock.json ./
RUN npm ci

FROM node:22-alpine AS build
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY website/ ./
# Sözleşme tipleri repo kökündeki openapi.yaml'dan üretiliyor; derleme
# bağlamı kök olduğu için dosya erişilebilir.
COPY docs/openapi.yaml /docs/openapi.yaml

# NEXT_PUBLIC_* değişkenleri derleme anında gömülür — çalışma anında
# değiştirilemezler. Bu yüzden build arg olarak alınıyorlar.
ARG NEXT_PUBLIC_API_URL
ARG NEXT_PUBLIC_SITE_URL
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_SITE_URL=$NEXT_PUBLIC_SITE_URL
ENV NEXT_TELEMETRY_DISABLED=1

# public/ opsiyoneldir: robots.txt ve ikon `app/` altından üretiliyor.
# Klasörü garanti altına alıyoruz ki son aşamadaki COPY her durumda çalışsın.
RUN mkdir -p public && npm run build

FROM node:22-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

# Root olarak çalıştırmıyoruz: Next.js sunucusunun dosya sistemine
# yazması gerekmiyor.
RUN addgroup -g 1001 -S nodejs && adduser -S nextjs -u 1001

COPY --from=build --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=build --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=build --chown=nextjs:nodejs /app/public ./public

USER nextjs
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/ >/dev/null 2>&1 || exit 1

CMD ["node", "server.js"]
