FROM ubuntu:24.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install PHP and nginx dependencies
RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \
    && apt-get update \
    && apt-get install -y software-properties-common \
    && add-apt-repository ppa:apt-fast/stable -y \
    && add-apt-repository ppa:ondrej/php -y \
    && apt-get update \
    && apt-get install -y apt-fast \
    && echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
    && echo 'apt-fast apt-fast/maxdownloads string 10' | debconf-set-selections \
    && echo 'apt-fast apt-fast/dlflag boolean true' | debconf-set-selections \
    && echo 'apt-fast apt-fast/aptmanager string apt-get' | debconf-set-selections \
    && apt-fast install -y \
    php8.4-fpm \
    php8.4-cli \
    php8.4-curl \
    nginx \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Create application directory
WORKDIR /app

# Copy PHP application
COPY . .

# Install PHP dependencies
RUN composer install --no-dev --optimize-autoloader

# Copy nginx configuration
COPY nginx.conf /etc/nginx/sites-available/api
RUN ln -sf /etc/nginx/sites-available/api /etc/nginx/sites-enabled/api \
    && rm -f /etc/nginx/sites-enabled/default

# Copy startup script
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

# Expose HTTP port
EXPOSE 80

# Start PHP-FPM and nginx
CMD ["/app/start.sh"]
