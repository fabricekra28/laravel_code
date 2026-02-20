# =========================
# 1️⃣ Builder Stage
# =========================
FROM composer:2 AS builder

WORKDIR /app

# Installer dépendances système nécessaires aux extensions PHP
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libzip-dev \
    libonig-dev \
    libicu-dev \
    libjpeg-dev \
    libfreetype6-dev \
    zip \
    unzip \
    git \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install \
        pdo_mysql \
        mbstring \
        bcmath \
        zip \
        exif \
        pcntl \
        gd

# Copier uniquement les fichiers Composer d'abord (cache Docker optimisé)
COPY composer.json composer.lock ./

# Installer dépendances Laravel (production only)
RUN composer install \
    --no-dev \
    --no-interaction \
    --prefer-dist \
    --optimize-autoloader

# Copier le reste du projet
COPY . .

# Optimisation autoload
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
    zip \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install \
        pdo_mysql \
        mbstring \
        bcmath \
        exif \
        pcntl \
        zip \
        gd

# Activer OPcache (production ready)
RUN docker-php-ext-install opcache

# Configuration OPcache optimisée
RUN echo "opcache.enable=1" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.memory_consumption=128" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.max_accelerated_files=10000" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.validate_timestamps=0" >> /usr/local/etc/php/conf.d/opcache.ini

# Créer utilisateur non-root (sécurité)
RUN addgroup -g 1000 laravel \
    && adduser -G laravel -u 1000 -D laravel

WORKDIR /var/www/html

# Copier uniquement le nécessaire depuis builder
COPY --from=builder /app /var/www/html

# Supprimer .env si présent (sécurité)
RUN rm -f .env

# Permissions sécurisées
RUN chown -R laravel:laravel /var/www/html \
    && chmod -R 750 /var/www/html \
    && chmod -R 770 storage bootstrap/cache

USER laravel

EXPOSE 9000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD php-fpm -t || exit 1

CMD ["php-fpm"]