FROM ubuntu:24.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    libpcre++-dev \
    zlib1g-dev \
    git \
    cmake \
    ninja-build \
    clang-18 \
    libc++-18-dev \
    libc++abi-18-dev \
    mold \
    php8.4-fpm \
    php8.4-cli \
    nginx \
    systemd \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set up Clang as default compiler
RUN update-alternatives --install /usr/bin/clang clang /usr/bin/clang-18 100 \
    && update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-18 100 \
    && update-alternatives --install /usr/bin/cc cc /usr/bin/clang 100 \
    && update-alternatives --install /usr/bin/c++ c++ /usr/bin/clang++ 100

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
RUN systemctl enable php8.4-fpm

# Expose ports
EXPOSE 80 8888

# Copy startup script
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

# Start services
CMD ["/app/start.sh"]
