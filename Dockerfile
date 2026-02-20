# =========================
# 1️⃣ Builder Stage
# =========================
FROM composer:2 AS builder

WORKDIR /app

COPY . .

RUN composer install \
    --no-dev \
    --no-interaction \
    --prefer-dist \
    --optimize-autoloader \
    --ignore-platform-reqs


# =========================
# 2️⃣ Runtime Stage
# =========================
FROM php:8.2-fpm-alpine

RUN apk add --no-cache \
    libpng \
    libzip \
    oniguruma \
    icu-libs \
    freetype \
    libjpeg-turbo \
    zip \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install \
        pdo_mysql \
        mbstring \
        bcmath \
        exif \
        pcntl \
        zip \
        gd \
        opcache

RUN addgroup -g 1000 laravel \
    && adduser -G laravel -u 1000 -D laravel

WORKDIR /var/www/html

COPY --from=builder /app /var/www/html

RUN rm -f .env \
    && chown -R laravel:laravel /var/www/html \
    && chmod -R 750 /var/www/html \
    && chmod -R 770 storage bootstrap/cache

USER laravel

EXPOSE 9000

CMD ["php-fpm"]