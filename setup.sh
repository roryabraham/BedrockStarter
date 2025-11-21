#!/bin/bash
# This script configures the VM with all the packages it needs, builds bedrock and the core plugin, and sets up the systemd services.
# It should be run from the VM.

set -e

echo "=========================================="
echo "Bedrock Starter Setup Script"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

# Get the project directory (where this script is located)
# Default to /bedrock-starter if running in Multipass VM, otherwise use script location
if [ -d "/bedrock-starter" ] && [ -f "/bedrock-starter/setup.sh" ]; then
    PROJECT_DIR="/bedrock-starter"
else
    PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
BEDROCK_DIR="$PROJECT_DIR/Bedrock"
CORE_DIR="$PROJECT_DIR/server/core"
API_DIR="$PROJECT_DIR/server/api"
INSTALL_DIR="/opt/bedrock"
DATA_DIR="/var/lib/bedrock"

echo -e "${GREEN}Project directory: $PROJECT_DIR${NC}"
echo -e "${GREEN}Install directory: $INSTALL_DIR${NC}"

# Update package lists
echo -e "\n${YELLOW}[1/10] Updating package lists...${NC}"
apt-get update

# Install apt-fast for faster package downloads
echo -e "\n${YELLOW}[2/10] Installing apt-fast...${NC}"
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
    echo -e "${GREEN}apt-fast already installed${NC}"
fi

# Install Bedrock dependencies
echo -e "\n${YELLOW}[3/10] Installing Bedrock dependencies...${NC}"
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
    python3-jinja2

# Set up Clang as default compiler
echo -e "\n${YELLOW}[4/10] Configuring Clang compiler...${NC}"
update-alternatives --install /usr/bin/cc cc /usr/bin/clang 100 || true
update-alternatives --install /usr/bin/c++ c++ /usr/bin/clang++ 100 || true

# Configure ccache
echo -e "\n${YELLOW}[5/10] Configuring ccache...${NC}"
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
echo -e "\n${YELLOW}[6/10] Installing PHP 8.4 and nginx...${NC}"
add-apt-repository ppa:ondrej/php -y
apt-get update
apt-fast install -y \
    php8.4-fpm \
    php8.4-cli \
    php8.4-curl \
    nginx \
    curl

# Install Composer
echo -e "\n${YELLOW}[7/10] Installing Composer...${NC}"
if ! command -v composer &> /dev/null; then
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
else
    echo -e "${GREEN}Composer already installed${NC}"
fi

# Clone/build Bedrock
echo -e "\n${YELLOW}[8/10] Building Bedrock...${NC}"
if [ ! -d "$BEDROCK_DIR" ]; then
    echo -e "${RED}Bedrock directory not found at $BEDROCK_DIR${NC}"
    echo -e "${YELLOW}Please ensure Bedrock is cloned as a git submodule:${NC}"
    echo -e "  git submodule update --init --recursive"
    exit 1
fi

cd "$BEDROCK_DIR"
export CC=clang
export CXX=clang++
export PATH="/usr/lib/ccache:$PATH"
make clean || true
# Build only the bedrock binary, skip tests
make bedrock --jobs "$(nproc)"

# Create installation directory structure
echo -e "\n${YELLOW}[9/10] Setting up installation directories...${NC}"
mkdir -p "$INSTALL_DIR"
cp -r "$BEDROCK_DIR" "$INSTALL_DIR/"
cp -r "$PROJECT_DIR/server" "$INSTALL_DIR/"

# Build Core plugin
echo -e "\n${YELLOW}[10/10] Building Core plugin...${NC}"
cd "$INSTALL_DIR/server/core"
export BEDROCK_DIR="$INSTALL_DIR/Bedrock"
export LD_LIBRARY_PATH="$INSTALL_DIR/server/core/lib:$LD_LIBRARY_PATH"
rm -rf CMakeCache.txt CMakeFiles/ build.ninja .ninja_* lib/ build/ || true
cmake -G Ninja .
ninja -j "$(nproc)"

# Create bedrock user
echo -e "\n${YELLOW}Creating bedrock user...${NC}"
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
echo -e "\n${YELLOW}Installing systemd service...${NC}"
cp "$PROJECT_DIR/server/config/bedrock.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable bedrock.service

# Configure nginx
echo -e "\n${YELLOW}Configuring nginx...${NC}"
cp "$API_DIR/nginx.conf" /etc/nginx/sites-available/bedrock-api
ln -sf /etc/nginx/sites-available/bedrock-api /etc/nginx/sites-enabled/bedrock-api
rm -f /etc/nginx/sites-enabled/default
systemctl enable nginx.service

# Install PHP dependencies
echo -e "\n${YELLOW}Installing PHP dependencies...${NC}"
cd "$INSTALL_DIR/server/api"
composer install --no-dev --optimize-autoloader

# Set permissions for PHP files
chown -R www-data:www-data "$INSTALL_DIR/server/api"

echo -e "\n${GREEN}=========================================="
echo "Setup complete!"
echo "==========================================${NC}"
echo ""
echo "To start services:"
echo "  sudo systemctl start bedrock"
echo "  sudo systemctl start php8.4-fpm"
echo "  sudo systemctl start nginx"
echo ""
echo "To check status:"
echo "  sudo systemctl status bedrock"
echo "  sudo systemctl status php8.4-fpm"
echo "  sudo systemctl status nginx"
echo ""
echo "To view logs:"
echo "  sudo journalctl -u bedrock -f"
echo "  sudo tail -f /var/log/nginx/api_error.log"
echo ""

