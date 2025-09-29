FROM ubuntu:24.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install Bedrock dependencies
RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \
    && apt-get update \
    && apt-get install -y software-properties-common \
    && add-apt-repository ppa:apt-fast/stable -y \
    && apt-get update \
    && apt-get install -y apt-fast \
    && echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
    && echo 'apt-fast apt-fast/maxdownloads string 10' | debconf-set-selections \
    && echo 'apt-fast apt-fast/dlflag boolean true' | debconf-set-selections \
    && echo 'apt-fast apt-fast/aptmanager string apt-get' | debconf-set-selections \
    && apt-fast install -y \
    libpcre2-dev \
    zlib1g-dev \
    git \
    cmake \
    ninja-build \
    pkg-config \
    clang \
    libc++-dev \
    libc++abi-dev \
    mold \
    ccache \
    python3 \
    python3-jsonschema \
    python3-jinja2 \
    && rm -rf /var/lib/apt/lists/*

# Set up Clang as default compiler
RUN update-alternatives --install /usr/bin/cc cc /usr/bin/clang 100 \
    && update-alternatives --install /usr/bin/c++ c++ /usr/bin/clang++ 100

# Configure ccache
RUN ccache --set-config=max_size=2G \
    && ccache --set-config=compression=true \
    && ccache --set-config=cache_dir=/var/cache/ccache \
    && mkdir -p /var/cache/ccache \
    && chmod 777 /var/cache/ccache

# Set up ccache wrapper symlinks
RUN mkdir -p /usr/lib/ccache \
    && ln -sf /usr/bin/ccache /usr/lib/ccache/clang \
    && ln -sf /usr/bin/ccache /usr/lib/ccache/clang++ \
    && ln -sf /usr/bin/ccache /usr/lib/ccache/gcc \
    && ln -sf /usr/bin/ccache /usr/lib/ccache/g++

# Add ccache to PATH and set environment variables
ENV PATH="/usr/lib/ccache:$PATH"
ENV CCACHE_DIR=/var/cache/ccache
ENV CCACHE_COMPRESS=1
ENV CCACHE_MAXSIZE=2G

# Create application directory
WORKDIR /app

# Clone and build Bedrock
RUN git clone https://github.com/Expensify/Bedrock.git
WORKDIR /app/Bedrock
ENV CC=clang
ENV CXX=clang++
RUN --mount=type=cache,target=/var/cache/ccache \
    make --jobs $(nproc) && touch bedrock.db

# Copy Core plugin source
WORKDIR /app
COPY . core/

# Build the Core plugin
WORKDIR /app/core
RUN --mount=type=cache,target=/var/cache/ccache \
    cmake -G Ninja . && ninja -j $(nproc)

# Set library path for plugin loading
ENV LD_LIBRARY_PATH=/app/core/lib:$LD_LIBRARY_PATH

# Expose Bedrock port
EXPOSE 8888

# Start Bedrock with Core plugin
WORKDIR /app/Bedrock
CMD ["./bedrock", "-plugins", "Core", "-pluginDir", "/app/core/lib"]
