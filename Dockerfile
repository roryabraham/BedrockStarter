FROM ubuntu:24.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libpcre++-dev \
    zlib1g-dev \
    git \
    netcat \
    cmake \
    ninja-build \
    php8.3-fpm \
    php8.3-cli \
    php8.3-json \
    php8.3-mbstring \
    nginx \
    systemd \
    systemd-sysv \
    curl \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Create application directory structure
WORKDIR /app

# Clone Bedrock as a sibling to server
RUN git clone https://github.com/Expensify/Bedrock.git

# Build Bedrock
WORKDIR /app/Bedrock
RUN make && touch bedrock.db

# Create server directory structure
WORKDIR /app
RUN mkdir -p server/api server/core server/core/commands

# Copy project files
COPY server/ server/

# Build the Core plugin
WORKDIR /app/server/core
RUN cmake -G Ninja . && ninja

# Setup systemd
RUN systemctl enable nginx
RUN systemctl enable php8.3-fpm

# Expose ports
EXPOSE 80 8888

# Copy startup script
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

# Start services
CMD ["/app/start.sh"]
