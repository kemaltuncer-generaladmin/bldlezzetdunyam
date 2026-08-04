# TastyIgniter (PHP 8.3 / Laravel) çalışma imajı.
#
# platform/ klasörü B-01 görevinde `composer create-project` ile doldurulur;
# bu imaj o kod için hazır bir çalışma ortamıdır. Kaynak, geliştirmede bind
# mount ile bağlanır (docker-compose.dev.yml), üretimde imaja kopyalanır.
FROM php:8.3-fpm-alpine

RUN apk add --no-cache \
      git curl unzip icu-dev libzip-dev oniguruma-dev \
      freetype-dev libjpeg-turbo-dev libpng-dev \
      mysql-client \
 && docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install -j"$(nproc)" \
      pdo_mysql mysqli gd zip bcmath intl exif opcache \
 && rm -rf /var/cache/apk/*

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
