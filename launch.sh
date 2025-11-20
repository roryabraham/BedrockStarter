#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

VM_NAME="bedrock-starter"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}=========================================="
echo "Bedrock Starter - Multipass Launcher"
echo "==========================================${NC}"

# Check if Multipass is installed
if ! command -v multipass &> /dev/null; then
    echo -e "${RED}Multipass is not installed!${NC}"
    echo ""
    echo "Please install Multipass:"
    echo "  macOS:   brew install multipass"
    echo "  Linux:   snap install multipass"
    echo "  Windows: Download from https://multipass.run/install"
    exit 1
fi

# Detect architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]] || [[ "$ARCH" == "aarch64" ]]; then
    IMAGE="ubuntu/arm64"
    echo -e "${GREEN}Detected ARM architecture - using ARM Ubuntu (native performance)${NC}"
else
    IMAGE="ubuntu/amd64"
    echo -e "${GREEN}Detected x86_64 architecture - using x86_64 Ubuntu${NC}"
fi

# Check if VM already exists
if multipass list | grep -q "^${VM_NAME}"; then
    echo -e "${YELLOW}VM '${VM_NAME}' already exists${NC}"
    read -p "Delete and recreate? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Deleting existing VM...${NC}"
        multipass delete "${VM_NAME}" --purge || true
    else
        echo -e "${GREEN}Using existing VM. To start it: multipass start ${VM_NAME}${NC}"
        echo -e "${GREEN}To shell into it: multipass shell ${VM_NAME}${NC}"
        exit 0
    fi
fi

# Launch VM with cloud-init (just installs dependencies)
echo -e "\n${YELLOW}Launching Ubuntu VM (this may take a few minutes)...${NC}"
multipass launch "${IMAGE}" \
    --name "${VM_NAME}" \
    --memory 4G \
    --cpus 4 \
    --disk 20G \
    --cloud-init "${PROJECT_DIR}/multipass.yaml" \
    --timeout 600

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to launch VM${NC}"
    exit 1
fi

# Wait for cloud-init to complete
echo -e "\n${YELLOW}Waiting for cloud-init to complete...${NC}"
multipass exec "${VM_NAME}" -- cloud-init status --wait || true
sleep 5

# Mount project directories for development
echo -e "\n${YELLOW}Mounting project directories for real-time sync...${NC}"
multipass mount "${PROJECT_DIR}" "${VM_NAME}:/vagrant" || {
    echo -e "${YELLOW}Mount failed (may already be mounted). Continuing...${NC}"
}

# Run the full setup script now that directory is mounted
echo -e "\n${YELLOW}Running setup script (this will take 5-10 minutes)...${NC}"
multipass exec "${VM_NAME}" -- sudo bash /vagrant/setup.sh

# Set up port forwarding
echo -e "\n${YELLOW}Setting up port forwarding...${NC}"
echo -e "${GREEN}Bedrock will be available at: localhost:8888${NC}"
echo -e "${GREEN}API will be available at: localhost:8080${NC}"

# Note: Multipass port forwarding needs to be set up manually or via alias
# We'll provide instructions in the output

# Get VM IP
VM_IP=$(multipass info "${VM_NAME}" | grep "IPv4" | awk '{print $2}')
echo -e "\n${GREEN}VM IP address: ${VM_IP}${NC}"

# Wait for setup to complete
echo -e "\n${YELLOW}Waiting for setup to complete (this may take 5-10 minutes)...${NC}"
echo -e "${YELLOW}You can monitor progress with: multipass exec ${VM_NAME} -- tail -f /var/log/cloud-init-output.log${NC}"

# Check if services are running
echo -e "\n${YELLOW}Checking service status...${NC}"
sleep 10

multipass exec "${VM_NAME}" -- systemctl is-active bedrock > /dev/null 2>&1 && \
    echo -e "${GREEN}✓ Bedrock service is running${NC}" || \
    echo -e "${YELLOW}⚠ Bedrock service may still be starting...${NC}"

multipass exec "${VM_NAME}" -- systemctl is-active php8.4-fpm > /dev/null 2>&1 && \
    echo -e "${GREEN}✓ PHP-FPM service is running${NC}" || \
    echo -e "${YELLOW}⚠ PHP-FPM service may still be starting...${NC}"

multipass exec "${VM_NAME}" -- systemctl is-active nginx > /dev/null 2>&1 && \
    echo -e "${GREEN}✓ Nginx service is running${NC}" || \
    echo -e "${YELLOW}⚠ Nginx service may still be starting...${NC}"

echo -e "\n${GREEN}=========================================="
echo "Setup Complete!"
echo "==========================================${NC}"
echo ""
echo -e "${BLUE}Quick Start:${NC}"
echo "  # SSH into the VM (like 'vagrant ssh')"
echo "  multipass shell ${VM_NAME}"
echo ""
echo "  # Or run commands directly"
echo "  multipass exec ${VM_NAME} -- systemctl status bedrock"
echo ""
echo -e "${BLUE}Access Services:${NC}"
echo "  # Bedrock (from host)"
echo "  nc ${VM_IP} 8888"
echo ""
echo "  # API (from host)"
echo "  curl http://${VM_IP}/api/status"
echo ""
echo -e "${BLUE}Port Forwarding (optional):${NC}"
echo "  # To access from localhost instead of VM IP:"
echo "  multipass port-forward ${VM_NAME} 8888:8888  # Bedrock"
echo "  multipass port-forward ${VM_NAME} 80:8080   # API (host:guest)"
echo ""
echo -e "${BLUE}Development:${NC}"
echo "  # Project is mounted at /vagrant in the VM"
echo "  # Edit files locally - changes sync in real-time!"
echo "  # After editing C++ code, rebuild:"
echo "  multipass exec ${VM_NAME} -- bash -c 'cd /opt/bedrock/server/core && ninja'"
echo ""
echo -e "${BLUE}Service Management:${NC}"
echo "  multipass exec ${VM_NAME} -- sudo systemctl restart bedrock"
echo "  multipass exec ${VM_NAME} -- sudo systemctl restart nginx"
echo ""
echo -e "${BLUE}View Logs:${NC}"
echo "  multipass exec ${VM_NAME} -- sudo journalctl -u bedrock -f"
echo ""

