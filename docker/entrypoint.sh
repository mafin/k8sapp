#!/bin/sh

set -e

echo "🚀 Starting k8sapp container..."

# Wait a moment for potential filesystem to be ready
sleep 2

echo "📊 Setting up database..."

# For SQLite, database is created automatically when running migrations
# No need to explicitly create database

echo "🔄 Running database migrations..."
# Run migrations (this will create SQLite database if it doesn't exist)
php bin/console doctrine:migrations:migrate --env=prod --no-interaction

echo "ℹ️ Skipping fixtures loading in production environment..."
# Note: Fixtures are not loaded in production for security reasons
# If you need sample data, load it manually after deployment

echo "♻️ Clearing and warming cache..."
# Clear and warm cache for production
php bin/console cache:clear --env=prod
php bin/console cache:warmup --env=prod

echo "✅ Initialization complete! Starting services..."

# Start supervisord
exec /usr/bin/supervisord -c /etc/supervisord.conf