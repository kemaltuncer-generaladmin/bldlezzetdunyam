# TastyIgniter (PHP 8.3 / Laravel) çalışma imajı.
#
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ NEDEN ALPINE DEĞİL — bu satırı silmeden önce oku.                         ║
# ║                                                                           ║
# ║ TastyIgniter çekirdeği ExtensionManager.php içinde GLOB_BRACE sabitini     ║
# ║ koşulsuz kullanıyor. GLOB_BRACE glibc'ye özgüdür; Alpine'ın musl libc'si   ║
# ║ sağlamaz ve PHP o sabiti tanımlamaz. Sonuç: `composer create-project`      ║
# ║ daha ilk `artisan package:discover` adımında                              ║
# ║   Undefined constant "Igniter\System\Classes\GLOB_BRACE"                   ║
# ║ ile patlar. Düzeltmek çekirdeğe dokunmayı gerektirirdi — ADR-02 yasak.     ║
# ║ Bu yüzden taban imaj Debian'dır. Alpine'a dönmek çalışmaz.                 ║
# ║ (04.08 — gerçek kurulumda doğrulandı, B-02)                               ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
#
# platform/ klasörü B-01 görevinde `composer create-project` ile doldurulur;
# bu imaj o kod için hazır bir çalışma ortamıdır. Kaynak, geliştirmede bind
# mount ile bağlanır (docker-compose.dev.yml), üretimde imaja kopyalanır.
FROM php:8.3-fpm-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
      git curl unzip ca-certificates \
      libicu-dev libzip-dev libonig-dev \
      libfreetype6-dev libjpeg62-turbo-dev libpng-dev \
      default-mysql-client \
 && docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install -j"$(nproc)" \
      pdo_mysql mysqli gd zip bcmath intl exif opcache \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# TastyIgniter medya yüklemeleri ve önbellek için makul sınırlar.
RUN { \
      echo 'memory_limit=512M'; \
      echo 'upload_max_filesize=32M'; \
      echo 'post_max_size=32M'; \
      echo 'max_execution_time=120'; \
    } > /usr/local/etc/php/conf.d/bld.ini

WORKDIR /var/www/platform

EXPOSE 9000
CMD ["php-fpm"]
