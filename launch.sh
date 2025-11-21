#!/bin/bash
# This script is used to launch a VM with Multipass and run the setup script.
# It should be run from the host machine.

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

# Check if git submodules are initialized
if [ ! -d "${PROJECT_DIR}/Bedrock" ]; then
    echo -e "${YELLOW}Bedrock submodule not found. Initializing...${NC}"
    cd "${PROJECT_DIR}"
    git submodule update --init --recursive || {
        echo -e "${RED}Failed to initialize Bedrock submodule${NC}"
        echo -e "${YELLOW}Please run: git submodule update --init --recursive${NC}"
        exit 1
    }
fi

# Generate .clangd from .clangd.example if it doesn't exist
if [ ! -f "${PROJECT_DIR}/.clangd" ] && [ -f "${PROJECT_DIR}/.clangd.example" ]; then
    echo -e "${YELLOW}Generating .clangd from template...${NC}"
    sed "s|{{PROJECT_ROOT}}|${PROJECT_DIR}|g" "${PROJECT_DIR}/.clangd.example" > "${PROJECT_DIR}/.clangd"
    echo -e "${GREEN}✓ Created .clangd with project-specific paths${NC}"
fi

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

# Detect architecture and set image
ARCH=$(uname -m)
IMAGE="24.04"  # Ubuntu 24.04 LTS - Multipass auto-detects architecture (ARM on ARM Macs, x86 on x86 systems)
if [[ "$ARCH" == "arm64" ]] || [[ "$ARCH" == "aarch64" ]]; then
    echo -e "${GREEN}Detected ARM architecture - Multipass will use ARM Ubuntu (native performance)${NC}"
else
    echo -e "${GREEN}Detected x86_64 architecture - Multipass will use x86_64 Ubuntu${NC}"
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
multipass launch \
    --name "${VM_NAME}" \
    --memory 4G \
    --cpus 4 \
    --disk 20G \
    --cloud-init "${PROJECT_DIR}/multipass.yaml" \
    --timeout 600 \
    "${IMAGE}"

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to launch VM${NC}"
    exit 1
fi

# Wait for cloud-init to complete
echo -e "\n${YELLOW}Waiting for cloud-init to complete...${NC}"
multipass exec "${VM_NAME}" -- cloud-init status --wait || true
sleep 5

# Set as primary if no primary exists (allows 'multipass shell' without name)
PRIMARY_NAME=$(multipass get local.primary-name 2>/dev/null || echo "")
if [ -z "$PRIMARY_NAME" ] || [ "$PRIMARY_NAME" = "None" ]; then
    echo -e "\n${YELLOW}Setting ${VM_NAME} as primary instance...${NC}"
    multipass set local.primary-name="${VM_NAME}" || true
    echo -e "${GREEN}✓ You can now use 'multipass shell' without specifying the VM name${NC}"
fi

# Try to mount project directories for development
PROJECT_MOUNT="/bedrock-starter"
echo -e "\n${YELLOW}Mounting project directories for real-time sync...${NC}"
if multipass mount "${PROJECT_DIR}" "${VM_NAME}:${PROJECT_MOUNT}" 2>/dev/null; then
    echo -e "${GREEN}✓ Mount successful - files will sync in real-time${NC}"
else
    echo -e "${YELLOW}⚠ Mount failed - copying files instead (one-time copy)${NC}"
    echo -e "${YELLOW}  For real-time sync, install multipass-sshfs manually:${NC}"
    echo -e "${YELLOW}  multipass exec ${VM_NAME} -- sudo snap install multipass-sshfs${NC}"
    echo -e "${YELLOW}  Then: multipass mount ${PROJECT_DIR} ${VM_NAME}:${PROJECT_MOUNT}${NC}"
    
    # Copy project files if mount failed
    echo -e "\n${YELLOW}Copying project files into VM...${NC}"
    multipass exec "${VM_NAME}" -- sudo mkdir -p "${PROJECT_MOUNT}"
    multipass exec "${VM_NAME}" -- sudo chown ubuntu:ubuntu "${PROJECT_MOUNT}"
    multipass transfer "${PROJECT_DIR}/setup.sh" "${VM_NAME}:${PROJECT_MOUNT}/setup.sh"

    # Use tar to transfer directories recursively (multipass transfer doesn't support -r)
    # Suppress macOS extended attribute warnings (they're harmless)
    echo -e "${YELLOW}Transferring server directory...${NC}"
    COPYFILE_DISABLE=1 tar --exclude='.DS_Store' -czf - -C "${PROJECT_DIR}" server 2>/dev/null | \
        multipass exec "${VM_NAME}" -- tar xzf - -C "${PROJECT_MOUNT}/" 2>/dev/null
    
    # Copy Bedrock if it exists (submodule)
    if [ -d "${PROJECT_DIR}/Bedrock" ]; then
        echo -e "${YELLOW}Transferring Bedrock submodule (this may take a moment)...${NC}"
        COPYFILE_DISABLE=1 tar --exclude='.DS_Store' -czf - -C "${PROJECT_DIR}" Bedrock 2>/dev/null | \
            multipass exec "${VM_NAME}" -- tar xzf - -C "${PROJECT_MOUNT}/" 2>/dev/null
    fi
fi

# Run the full setup script
echo -e "\n${YELLOW}Running setup script (this will take 5-10 minutes)...${NC}"
multipass exec "${VM_NAME}" -- sudo bash "${PROJECT_MOUNT}/setup.sh"

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
echo "  # Project is mounted at /bedrock-starter in the VM"
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

