#!/bin/bash
set -e

echo "Starting Bedrock Starter services..."

# Setup nginx configuration
cp /app/server/api/nginx.conf /etc/nginx/sites-available/api
ln -sf /etc/nginx/sites-available/api /etc/nginx/sites-enabled/api
rm -f /etc/nginx/sites-enabled/default

# Setup systemd service for bedrock
cp /app/bedrock.service /etc/systemd/system/
systemctl daemon-reload

# Install PHP dependencies
cd /app/server/api
composer install --no-dev --optimize-autoloader

# Start systemd (required for services)
/lib/systemd/systemd --system &
sleep 2

# Start PHP-FPM
systemctl start php8.3-fpm
systemctl enable php8.3-fpm

# Start nginx
systemctl start nginx
systemctl enable nginx

# Start Bedrock with Core plugin
systemctl start bedrock
systemctl enable bedrock

echo "All services started successfully!"
echo "API available at: http://localhost/"
echo "Bedrock available at: localhost:8888"

# Keep container running
tail -f /var/log/nginx/api_access.log /var/log/nginx/api_error.log
