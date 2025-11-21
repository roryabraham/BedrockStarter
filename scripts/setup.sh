#!/bin/bash
# This script configures the VM with all the packages it needs, builds bedrock and the core plugin, and sets up the systemd services.
# It should be run from the VM.

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

print_header "Bedrock Starter Setup Script"

# Check if running as root
check_root

# Get the project directory
PROJECT_DIR=$(get_project_dir)
BEDROCK_DIR="$PROJECT_DIR/Bedrock"
API_DIR="$PROJECT_DIR/server/api"
INSTALL_DIR="/opt/bedrock"
DATA_DIR="/var/lib/bedrock"

success "Project directory: $PROJECT_DIR"
success "Install directory: $INSTALL_DIR"

# Update package lists
warn "[1/10] Updating package lists..."
apt-get update

# Install apt-fast for faster package downloads
warn "[2/10] Installing apt-fast..."
if ! command -v apt-fast &> /dev/null; then
    apt-get install -y software-properties-common
    add-apt-repository ppa:apt-fast/stable -y
    apt-get update
    echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
    echo 'apt-fast apt-fast/maxdownloads string 10' | debconf-set-selections
    echo 'apt-fast apt-fast/dlflag boolean true' | debconf-set-selections
    echo 'apt-fast apt-fast/aptmanager string apt-get' | debconf-set-selections
    apt-get install -y apt-fast
else
    success "apt-fast already installed"
fi

# Install Bedrock dependencies
warn "[3/10] Installing Bedrock dependencies..."
apt-fast install -y \
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
    sqlite3

# Set up Clang as default compiler
warn "[4/10] Configuring Clang compiler..."
update-alternatives --install /usr/bin/cc cc /usr/bin/clang 100 || true
update-alternatives --install /usr/bin/c++ c++ /usr/bin/clang++ 100 || true

# Configure ccache
warn "[5/10] Configuring ccache..."
ccache --set-config=max_size=2G || true
ccache --set-config=compression=true || true
ccache --set-config=cache_dir=/var/cache/ccache || true
mkdir -p /var/cache/ccache
chmod 777 /var/cache/ccache

# Set up ccache wrapper symlinks
mkdir -p /usr/lib/ccache
ln -sf /usr/bin/ccache /usr/lib/ccache/clang || true
ln -sf /usr/bin/ccache /usr/lib/ccache/clang++ || true
ln -sf /usr/bin/ccache /usr/lib/ccache/gcc || true
ln -sf /usr/bin/ccache /usr/lib/ccache/g++ || true

# Install PHP and nginx
warn "[6/10] Installing PHP 8.4 and nginx..."
add-apt-repository ppa:ondrej/php -y
apt-get update
apt-fast install -y \
    php8.4-fpm \
    php8.4-cli \
    php8.4-curl \
    nginx \
    curl

# Install Composer
warn "[7/10] Installing Composer..."
if ! command -v composer &> /dev/null; then
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
else
    success "Composer already installed"
fi

# Clone/build Bedrock
warn "[8/10] Building Bedrock..."
if [ ! -d "$BEDROCK_DIR" ]; then
    error "Bedrock directory not found at $BEDROCK_DIR"
    warn "Please ensure Bedrock is cloned as a git submodule:"
    echo "  git submodule update --init --recursive"
    exit 1
fi

cd "$BEDROCK_DIR"
export CC=clang
export CXX=clang++
export PATH="/usr/lib/ccache:$PATH"
make clean || true
# Build only the bedrock binary, skip tests
make bedrock --jobs "$(nproc)"

# Verify sqlite3 CLI tool (used for manual maintenance tasks like VACUUM)
warn "Verifying sqlite3 CLI tool..."
if command -v sqlite3 &> /dev/null; then
    SQLITE_VERSION=$(sqlite3 --version 2>/dev/null | awk '{print $1}' || echo "")
    success "✓ sqlite3 CLI available (version ${SQLITE_VERSION})"
else
    error "✗ sqlite3 not found even after installation. Please install sqlite3 manually and re-run setup."
    exit 1
fi

# Create installation directory structure
warn "[9/10] Setting up installation directories..."
mkdir -p "$INSTALL_DIR"
cp -r "$BEDROCK_DIR" "$INSTALL_DIR/"
cp -r "$PROJECT_DIR/server" "$INSTALL_DIR/"

# Build Core plugin
warn "[10/10] Building Core plugin..."
cd "$INSTALL_DIR/server/core"
export BEDROCK_DIR="$INSTALL_DIR/Bedrock"
export LD_LIBRARY_PATH="$INSTALL_DIR/server/core/lib:$LD_LIBRARY_PATH"
rm -rf CMakeCache.txt CMakeFiles/ build.ninja .ninja_* lib/ build/ || true
cmake -G Ninja .
ninja -j "$(nproc)"

# Create bedrock user
warn "Creating bedrock user..."
if ! id "bedrock" &>/dev/null; then
    useradd -r -s /bin/false -d /opt/bedrock bedrock
fi

# Set ownership
chown -R bedrock:bedrock "$INSTALL_DIR"
chown -R bedrock:bedrock /var/cache/ccache

# Create data directory
mkdir -p "$DATA_DIR"
chown bedrock:bedrock "$DATA_DIR"
chmod 755 "$DATA_DIR"

# Install systemd service
warn "Installing systemd service..."
cp "$PROJECT_DIR/server/config/bedrock.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable bedrock.service

# Configure nginx
warn "Configuring nginx..."
cp "$PROJECT_DIR/server/config/nginx.conf" /etc/nginx/sites-available/bedrock-api
ln -sf /etc/nginx/sites-available/bedrock-api /etc/nginx/sites-enabled/bedrock-api
rm -f /etc/nginx/sites-enabled/default
systemctl enable nginx.service

# Install PHP dependencies
warn "Installing PHP dependencies..."
cd "$INSTALL_DIR/server/api"
composer install --no-dev --optimize-autoloader

# Set permissions for PHP files
chown -R www-data:www-data "$INSTALL_DIR/server/api"

echo
success "=========================================="
success "Setup complete!"
success "=========================================="
echo
echo "To start services:"
echo "  sudo systemctl start bedrock"
echo "  sudo systemctl start php8.4-fpm"
echo "  sudo systemctl start nginx"
echo
echo "To check status:"
echo "  sudo systemctl status bedrock"
echo "  sudo systemctl status php8.4-fpm"
echo "  sudo systemctl status nginx"
echo
echo "To view logs:"
echo "  sudo journalctl -u bedrock -f"
echo "  sudo tail -f /var/log/nginx/api_error.log"
echo

