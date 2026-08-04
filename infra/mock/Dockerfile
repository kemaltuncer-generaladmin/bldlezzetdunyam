FROM node:22-alpine

WORKDIR /app

# Bağımlılıklar önce: kaynak değişince npm katmanı yeniden kurulmasın.
COPY package.json ./
RUN npm install --omit=dev --no-audit --no-fund

COPY src ./src

ENV NODE_ENV=production
ENV PORT=4010
EXPOSE 4010

# Konteyner içinden sağlık kontrolü; compose "up mock-api" sonrası hazır olmayı bekler.
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- --header="X-App-Id: website" --header="X-App-Version: 1.0.0" \
      http://127.0.0.1:4010/api/health || exit 1

CMD ["node", "src/server.js"]
