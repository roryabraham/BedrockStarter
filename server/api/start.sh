#!/bin/bash
set -e

echo "Starting PHP API services..."

# Start PHP-FPM in background
echo "Starting PHP-FPM..."
php-fpm8.4 --daemonize

# Start nginx in foreground (keeps container alive)
echo "Starting nginx..."
echo "API available at: http://localhost/"

# Check if PHP-FPM started successfully
sleep 2
if pgrep -x "php-fpm8.4" > /dev/null; then
    echo "✓ PHP-FPM is running"
else
    echo "✗ PHP-FPM failed to start"
    exit 1
fi

# Start nginx in foreground
exec nginx -g "daemon off;"
