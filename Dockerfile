# =========================================================
# Stage 1: The Builder Stage (Compiles extensions & installs composer)
# =========================================================
FROM php:8.2-fpm-alpine AS builder

WORKDIR /var/www

# Install compilation tools and development packages
RUN apk add --no-cache \
    git \
    unzip \
    zip \
    libpng-dev \
    libzip-dev \
    freetype-dev \
    libjpeg-turbo-dev \
    zlib-dev \
    $PHPIZE_DEPS

# Configure and compile PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) pdo_mysql gd zip

# Get latest Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Copy application files
COPY . .

# Install dependencies (optimized for production)
RUN composer install --no-dev --optimize-autoloader --no-interaction


# =========================================================
# Stage 2: The Production Stage (Lean and optimized)
# =========================================================
FROM php:8.2-fpm-alpine

WORKDIR /var/www

# Install ONLY runtime dependencies and Nginx (No compilers or -dev extensions)
RUN apk add --no-cache \
    libpng \
    libzip \
    freetype \
    libjpeg-turbo

# 1. CRITICAL STEP: Copy the pre-compiled extensions from the builder stage
COPY --from=builder /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=builder /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

# 2. Copy the fully prepared application code and vendors from builder
COPY --from=builder /var/www /var/www

# Adjust folder permissions for Laravel
RUN chown -R www-data:www-data /var/www/storage /var/www/bootstrap/cache

EXPOSE 9000

CMD ["sh", "-c", "php-fpm -D && nginx -g 'daemon off;'"]
