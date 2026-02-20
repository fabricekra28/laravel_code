# =========================
# 1️⃣ Builder Stage
# =========================
FROM composer:2 AS builder

WORKDIR /app

COPY composer.json composer.lock ./
RUN composer install \
    --no-dev \
    --no-interaction \
    --prefer-dist \
    --optimize-autoloader

COPY . .

RUN composer dump-autoload --optimize


# =========================
# 2️⃣ Runtime Stage
# =========================
FROM php:8.2-fpm-alpine

# Installer dépendances runtime uniquement
RUN apk add --no-cache \
    libpng \
    libzip \
    oniguruma \
    icu-libs \
    freetype \
    libjpeg-turbo \
    && docker-php-ext-install pdo_mysql mbstring bcmath exif pcntl zip gd

# Créer user non-root
RUN addgroup -g 1000 laravel \
    && adduser -G laravel -u 1000 -D laravel

WORKDIR /var/www/html

# Copier uniquement le nécessaire depuis builder
COPY --from=builder /app /var/www/html

# Supprimer .env si présent
RUN rm -f .env

# Permissions strictes
RUN chown -R laravel:laravel /var/www/html \
    && chmod -R 750 /var/www/html \
    && chmod -R 770 storage bootstrap/cache

USER laravel

EXPOSE 9000

CMD ["php-fpm"]
