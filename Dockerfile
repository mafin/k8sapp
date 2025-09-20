# Stage 1: Composer dependencies (production)
FROM composer:2 AS composer_deps

WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --optimize-autoloader

# Stage 1b: Composer dependencies (development)
FROM composer:2 AS composer_dev_deps

WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-scripts --optimize-autoloader

# Stage 2: Application build
FROM php:8.4-fpm-alpine AS app_build

ENV APP_ENV=prod

WORKDIR /var/www/html

# Install system dependencies
RUN apk add --no-cache \
    nginx \
    supervisor \
    sqlite \
    sqlite-dev \
    icu-dev

# Install required PHP extensions
RUN docker-php-ext-install pdo pdo_sqlite intl

# Add debug configuration for production troubleshooting
RUN echo "log_errors = On" >> /usr/local/etc/php/conf.d/debug.ini && \
    echo "error_log = /var/log/php_errors.log" >> /usr/local/etc/php/conf.d/debug.ini

# Copy application source code
COPY . .

# Copy vendor dependencies from composer_deps stage
COPY --from=composer_deps /app/vendor/ ./vendor/

# Create directories and set permissions
RUN mkdir -p /var/www/html/var/cache /var/www/html/var/log && \
    chown -R www-data:www-data /var/www/html/var && \
    chmod -R 775 /var/www/html/var

# Install assets and clear cache
RUN php bin/console assets:install --env=prod --symlink --relative public && \
    php bin/console cache:clear --env=prod --no-warmup

# Copy configurations
COPY docker/nginx/nginx.conf /etc/nginx/nginx.conf
COPY docker/supervisor/supervisord.conf /etc/supervisord.conf
COPY docker/entrypoint.sh /entrypoint.sh

# Make entrypoint executable
RUN chmod +x /entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]

# Stage 3: Development build (with dev dependencies and Composer)
FROM app_build AS app_dev

# Copy Composer binary
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Copy dev dependencies
COPY --from=composer_dev_deps /app/vendor/ ./vendor/

# Set development environment
ENV APP_ENV=dev

# Clear cache for dev environment
RUN php bin/console cache:clear --env=dev --no-warmup

# Keep the same CMD for consistency
