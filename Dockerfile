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

# Installer dépendances système + build deps
RUN apk add --no-cache \
        libpng \
        libzip \
        oniguruma \
        icu-libs \
        freetype \
        libjpeg-turbo \
        zlib \
    && apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        libpng-dev \
        libzip-dev \
        oniguruma-dev \
        freetype-dev \
        libjpeg-turbo-dev \
        zlib-dev \
        icu-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install \
        pdo_mysql \
        mbstring \
        bcmath \
        exif \
        pcntl \
        zip \
        gd \
        opcache \
    && apk del .build-deps

# Créer user non-root
RUN addgroup -g 1000 laravel \
    && adduser -G laravel -u 1000 -D laravel

WORKDIR /var/www/html

# Copier application depuis builder
COPY --from=builder /app /var/www/html

# Supprimer .env si présent
RUN rm -f .env

# Permissions
RUN chown -R laravel:laravel /var/www/html \
    && chmod -R 750 /var/www/html \
    && chmod -R 770 storage bootstrap/cache

USER laravel

EXPOSE 9000

CMD ["php-fpm"]