#!/bin/sh

set -e

echo "🚀 Starting k8sapp container..."

# Wait a moment for potential filesystem to be ready
sleep 2

echo "📊 Setting up database..."

# Create database if it doesn't exist
php bin/console doctrine:database:create --if-not-exists --env=prod --no-interaction

echo "🔄 Running database migrations..."
# Run migrations
php bin/console doctrine:migrations:migrate --env=prod --no-interaction

echo "🌱 Loading database fixtures..."
# Load fixtures (only if database is empty)
php bin/console doctrine:fixtures:load --env=prod --no-interaction --append

echo "♻️ Clearing and warming cache..."
# Clear and warm cache for production
php bin/console cache:clear --env=prod
php bin/console cache:warmup --env=prod

echo "✅ Initialization complete! Starting services..."

# Start supervisord
exec /usr/bin/supervisord -c /etc/supervisord.conf