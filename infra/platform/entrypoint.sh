#!/bin/sh
# Konteyner girişi — .env dosyasını ortam değişkenlerinden üretir.
#
# NEDEN GEREKLİ: Coolify (ve genel olarak konteyner dağıtımı) yapılandırmayı
# ortam değişkeni olarak verir, dosya olarak değil. Laravel bununla sorunsuz
# çalışır ama TastyIgniter'ın `igniter:install` komutu `.env` dosyasını
# DOĞRUDAN okur ve yoksa
#   File does not exist at path /var/www/platform/.env
# ile durur. Kurulum yapılamayınca veritabanı boş kalır ve API 500 döner.
#
# Dosya yalnızca YOKSA yazılır. Laravel'in Dotenv'i var olan ortam
# değişkenlerini EZMEZ; yani konteyner ortamı yine tek doğruluk kaynağıdır,
# bu dosya sadece kurulum komutunun beklentisini karşılar.
set -e

ENV_DOSYASI=/var/www/platform/.env

if [ ! -f "$ENV_DOSYASI" ]; then
  echo "[giris] .env yok, ortam değişkenlerinden üretiliyor"
  {
    echo "APP_NAME=\"${APP_NAME:-Benim Lezzet Dunyam}\""
    echo "APP_ENV=${APP_ENV:-production}"
    echo "APP_KEY=${APP_KEY}"
    echo "APP_DEBUG=${APP_DEBUG:-false}"
    echo "APP_URL=${APP_URL}"
    echo "APP_TIMEZONE=${APP_TIMEZONE:-Europe/Istanbul}"
    echo "APP_LOCALE=${APP_LOCALE:-tr}"
    echo "IGNITER_CARTE_KEY="
    echo "IGNITER_LOCATION_MODE=${IGNITER_LOCATION_MODE:-single}"
    echo "DB_CONNECTION=${DB_CONNECTION:-mysql}"
    echo "DB_HOST=${DB_HOST:-db}"
    echo "DB_PORT=${DB_PORT:-3306}"
    echo "DB_DATABASE=${DB_DATABASE}"
    echo "DB_USERNAME=${DB_USERNAME}"
    echo "DB_PASSWORD=${DB_PASSWORD}"
    echo "DB_PREFIX="
    echo "BROADCAST_DRIVER=${BROADCAST_DRIVER:-log}"
    echo "CACHE_DRIVER=${CACHE_DRIVER:-file}"
    echo "QUEUE_CONNECTION=${QUEUE_CONNECTION:-sync}"
    echo "SESSION_DRIVER=${SESSION_DRIVER:-file}"
    echo "SESSION_LIFETIME=120"
    echo "MAIL_MAILER=${MAIL_MAILER:-log}"
    echo "MAIL_FROM_ADDRESS=${MAIL_FROM_ADDRESS:-noreply@benimlezzetdunyam.com.tr}"
    echo "MAIL_FROM_NAME=\"${APP_NAME:-Benim Lezzet Dunyam}\""
  } > "$ENV_DOSYASI"
  chown www-data:www-data "$ENV_DOSYASI"
  chmod 600 "$ENV_DOSYASI"
fi

# Kalıcı birimler root olarak bağlanır; php-fpm www-data koşar.
# Bu satır olmadan uygulama loga ve yüklenen medyaya yazamaz ve HER
# SAYFA 500 döner — üstelik hata da loglanamadığı için sebebi görünmez.
mkdir -p /var/www/platform/storage/app /var/www/platform/storage/logs \
         /var/www/platform/storage/framework/cache \
         /var/www/platform/storage/framework/sessions \
         /var/www/platform/storage/framework/views \
         /var/www/platform/bootstrap/cache
chown -R www-data:www-data /var/www/platform/storage /var/www/platform/bootstrap/cache

# ── Göçler ────────────────────────────────────────────────────────────────
#
# NEDEN BURADA: dağıtım göç koşmuyordu. Sütun ekleyen bir sürüm
# yayınlandığında kod yeni sütunu okuyor, veritabanında yok ve uç 500
# dönüyordu — ta ki biri elle `igniter:up` koşana kadar. Bunu insan
# hafızasına bırakmak, er geç unutulacak bir adım demek.
#
# `igniter:up` ÇEKİRDEK VE EKLENTİ göçlerini birlikte koşar; düz
# `artisan migrate` yalnızca Laravel'in tablolarını kurar ve TastyIgniter
# şeması eksik kalır.
#
# Veritabanı henüz kurulmamışsa (ilk dağıtım) komut hata verir; bu
# ÖLDÜRÜCÜ DEĞİLDİR — kurulum `igniter:install` ile elle yapılır ve
# konteynerin ayağa kalkmasını engellememeli.
#
# `-u www-data`: root olarak koşmak storage altında root'a ait dosya
# bırakır ve php-fpm bazı uçlarda sessizce 500 döner (docs/RUNBOOK §4.5).
if [ "${BLD_SKIP_MIGRATIONS:-}" != "1" ]; then
  echo "[giris] göçler koşuluyor"
  su -s /bin/sh -c "php /var/www/platform/artisan igniter:up --no-interaction" www-data \
    || echo "[giris] UYARI: göçler koşmadı (veritabanı henüz kurulmamış olabilir)"
fi

exec "$@"
