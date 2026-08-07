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
    # KVKK: `MAIL_MAILER=log` her e-postanın GÖVDESİNİ log dosyasına yazar
    # ve gövdede müşteri adı, adresi ve e-postası var. Varsayılan
    # `LOG_LEVEL` `debug` olduğu için bunlar diske düşüyordu — sahada
    # 2,3 MB'lık logda gerçek müşteri e-postaları bulundu.
    #
    # `warning`: hatalar loglanır, posta dökümleri loglanmaz.
    echo "LOG_LEVEL=${LOG_LEVEL:-warning}"
    # `single` kanal tek dosyaya yazar ve HİÇ döndürmez; disk sessizce
    # dolar. `daily` 14 günlük pencere tutar.
    echo "LOG_CHANNEL=${LOG_CHANNEL:-daily}"
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

# ── Paket varlıkları ──────────────────────────────────────────────────────
#
# NEDEN BURADA: admin paneline HİÇ GİRİLEMİYORDU. Belirti "parola doğru
# ama giriş ekranı gitmiyor" idi; sebep parola değil, varlıklardı.
#
# Zincir: `platform/.gitignore` `public/vendor`'ı dışlıyor (doğru — derleme
# çıktısı repoda durmaz), imaj repodan derleniyor, dizin yok. Varlıkları
# yayımlayan tek betik `composer.json` içindeki `post-update-cmd` ve o
# kanca YALNIZCA `composer update`'te çalışır; imaj `composer install` ile
# derlendiği için hiç tetiklenmedi.
#
# Sonuç: `public/vendor` boş kalınca TastyIgniter'ın birleştiricisi paketin
# `public/js/app.js` derlemesini bulamayıp `resources/js/app.js` KAYNAĞINI
# servis etti. Kaynak `require('jquery')` ile başlıyor; `require` tarayıcıda
# yok, dosya ilk satırda patlıyor, jQuery ve AJAX katmanı hiç kurulmuyor.
# Giriş formu `data-request="onLogin"` ile çalıştığı için JS'siz kalınca
# düz POST'a düşüyor ve sunucu giriş sayfasını tekrar basıyor — sonsuz
# "giriş ekranı gitmiyor" döngüsü.
#
# ROOT OLARAK koşuyor: `public/` root'a ait ve bunlar çalışma anında
# yalnızca OKUNAN derleme çıktıları. `-u www-data` kuralı `storage/` için
# geçerli; artisan'ın root'ken storage'a bıraktığı izleri hemen aşağıda
# geri alıyoruz.
echo "[giris] paket varlıkları yayımlanıyor"
php /var/www/platform/artisan vendor:publish --tag=laravel-assets --force --no-interaction \
  || echo "[giris] UYARI: varlıklar yayımlanmadı — admin paneli JS'siz kalır"

# Medya diski `storage/app/public`; panelden yüklenen ürün görselleri bu
# bağlantı olmadan 404 döner. `storage/app` kalıcı bir birim, dolayısıyla
# dosyalar duruyordu — görünmeyen tek şey bağlantıydı.
if [ ! -e /var/www/platform/public/storage ]; then
  php /var/www/platform/artisan storage:link --no-interaction \
    || echo "[giris] UYARI: storage bağlantısı kurulamadı — yüklenen görseller 404 döner"
fi

# Artisan yukarıda root koştu; storage'da root'a ait dosya bırakmış
# olabilir ve o dosyalar php-fpm'i sessizce 500'e düşürür.
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
  # `--force` ŞART: Laravel üretim ortamında göç öncesi onay ister ve
  # `--no-interaction` bunu geçmez, komut sessizce hiçbir şey yapmadan
  # döner. Sahada yaşandı: giriş betiği "göçler koşuluyor" yazdı,
  # "APPLICATION IN PRODUCTION" uyarısı bastı ve sütunlar eklenmedi.
  su -s /bin/sh -c "php /var/www/platform/artisan igniter:up --force --no-interaction" www-data \
    || echo "[giris] UYARI: göçler koşmadı (veritabanı henüz kurulmamış olabilir)"

  # Kurumsal site içeriğini panele yükler.
  #
  # NEDEN BURADA: içerik tabloları göçle oluşuyor ama BOŞ geliyor. Yönetici
  # panele girdiğinde bomboş bir ekran görür ve sitenin içeriğini elle
  # yazmak zorunda kalırdı — oysa metinler zaten depoda hazır.
  #
  # Komut IDEMPOTENT: var olan kaydı atlar, yalnızca eksikleri ekler. Yani
  # her dağıtımda koşması güvenli ve panelde yapılan düzenlemeleri EZMEZ.
  # Üzerine yazmak isteyen elle `--force` ile koşar.
  su -s /bin/sh -c "php /var/www/platform/artisan veykemtu:siteIceriginiAktar --no-interaction" www-data \
    || echo "[giris] UYARI: site içeriği aktarılamadı"

  # Menü görsellerini ürünlere bağlar.
  #
  # NEDEN BURADA: görsel dosyaları depoda ve imajda hazır, ama ürüne BAĞLI
  # değil — bağlantı veritabanında durur ve göçle gelmez. Canlıda bu atlandığı
  # için menü on iki görselsiz satır olarak açıldı; yereldeyse komut elle
  # koşulduğundan fotoğraflı görünüyordu. İki ortam arasındaki bu fark
  # dağıtımın tekrarlanabilir olmadığının işaretiydi.
  #
  # `siteIceriginiAktar` ile aynı sözleşme: idempotent, görseli olan ürüne
  # dokunmaz. Yöneticinin panelden yüklediği gerçek fotoğraf bir sonraki
  # dağıtımda stok görselle EZİLMEZ.
  su -s /bin/sh -c "php /var/www/platform/artisan veykemtu:menuGorselleri --no-interaction" www-data \
    || echo "[giris] UYARI: menü görselleri bağlanamadı"
fi

exec "$@"
