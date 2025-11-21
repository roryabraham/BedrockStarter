#!/bin/bash
# This script is used to launch a VM with Multipass and run the setup script.
# It should be run from the host machine.

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

VM_NAME="bedrock-starter"
PROJECT_DIR=$(get_project_dir)

print_header "Bedrock Starter - Multipass Launcher"

# Check if git submodules are initialized
if [ ! -d "${PROJECT_DIR}/Bedrock" ]; then
    warn "Bedrock submodule not found. Initializing..."
    cd "${PROJECT_DIR}"
    git submodule update --init --recursive || {
        error "Failed to initialize Bedrock submodule"
        warn "Please run: git submodule update --init --recursive"
        exit 1
    }
fi

# Generate .clangd from .clangd.example if it doesn't exist
if [ ! -f "${PROJECT_DIR}/.clangd" ] && [ -f "${PROJECT_DIR}/.clangd.example" ]; then
    warn "Generating .clangd from template..."
    sed "s|{{PROJECT_ROOT}}|${PROJECT_DIR}|g" "${PROJECT_DIR}/.clangd.example" > "${PROJECT_DIR}/.clangd"
    success "✓ Created .clangd with project-specific paths"
fi

# Check if Multipass is installed
require_command multipass "Please install Multipass:
  macOS:   brew install multipass
  Linux:   snap install multipass
  Windows: Download from https://multipass.run/install"

# Detect architecture and set image
ARCH=$(uname -m)
IMAGE="24.04"  # Ubuntu 24.04 LTS - Multipass auto-detects architecture (ARM on ARM Macs, x86 on x86 systems)
if [[ "$ARCH" == "arm64" ]] || [[ "$ARCH" == "aarch64" ]]; then
    success "Detected ARM architecture - Multipass will use ARM Ubuntu (native performance)"
else
    success "Detected x86_64 architecture - Multipass will use x86_64 Ubuntu"
fi

# Check if VM already exists
if multipass list | grep -q "^${VM_NAME}"; then
    warn "VM '${VM_NAME}' already exists"
    read -p "Delete and recreate? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        warn "Deleting existing VM..."
        multipass delete "${VM_NAME}" --purge || true
    else
        success "Using existing VM. To start it: multipass start ${VM_NAME}"
        success "To shell into it: multipass shell ${VM_NAME}"
        exit 0
    fi
fi

# Launch VM with cloud-init (just installs dependencies)
warn "Launching Ubuntu VM (this may take a few minutes)..."
if ! multipass launch \
    --name "${VM_NAME}" \
    --memory 4G \
    --cpus 4 \
    --disk 20G \
    --cloud-init "${PROJECT_DIR}/multipass.yaml" \
    --timeout 600 \
    "${IMAGE}"; then
    error "Failed to launch VM"
    exit 1
fi

# Wait for cloud-init to complete
warn "Waiting for cloud-init to complete..."
multipass exec "${VM_NAME}" -- cloud-init status --wait || true
sleep 5

# Set as primary if no primary exists (allows 'multipass shell' without name)
PRIMARY_NAME=$(multipass get local.primary-name 2>/dev/null || echo "")
if [ -z "$PRIMARY_NAME" ] || [ "$PRIMARY_NAME" = "None" ]; then
    warn "Setting ${VM_NAME} as primary instance..."
    multipass set local.primary-name="${VM_NAME}" || true
    success "✓ You can now use 'multipass shell' without specifying the VM name"
fi

# Try to mount project directories for development
PROJECT_MOUNT="/bedrock-starter"
warn "Mounting project directories for real-time sync..."
if multipass mount "${PROJECT_DIR}" "${VM_NAME}:${PROJECT_MOUNT}" 2>/dev/null; then
    success "✓ Mount successful - files will sync in real-time"
else
    warn "⚠ Mount failed - copying files instead (one-time copy)"
    warn "  For real-time sync, install multipass-sshfs manually:"
    warn "  multipass exec ${VM_NAME} -- sudo snap install multipass-sshfs"
    warn "  Then: multipass mount ${PROJECT_DIR} ${VM_NAME}:${PROJECT_MOUNT}"

    # Copy project files if mount failed
    warn "Copying project files into VM..."
    multipass exec "${VM_NAME}" -- sudo mkdir -p "${PROJECT_MOUNT}/scripts"
    multipass exec "${VM_NAME}" -- sudo chown ubuntu:ubuntu "${PROJECT_MOUNT}"
    multipass exec "${VM_NAME}" -- sudo chown ubuntu:ubuntu "${PROJECT_MOUNT}/scripts"
    multipass transfer "${PROJECT_DIR}/scripts/setup.sh" "${VM_NAME}:${PROJECT_MOUNT}/scripts/setup.sh"
    multipass transfer "${PROJECT_DIR}/scripts/common.sh" "${VM_NAME}:${PROJECT_MOUNT}/scripts/common.sh"

    # Use tar to transfer directories recursively (multipass transfer doesn't support -r)
    # Suppress macOS extended attribute warnings (they're harmless)
    warn "Transferring server directory..."
    COPYFILE_DISABLE=1 tar --exclude='.DS_Store' -czf - -C "${PROJECT_DIR}" server 2>/dev/null | \
        multipass exec "${VM_NAME}" -- tar xzf - -C "${PROJECT_MOUNT}/" 2>/dev/null

    # Copy Bedrock if it exists (submodule)
    if [ -d "${PROJECT_DIR}/Bedrock" ]; then
        warn "Transferring Bedrock submodule (this may take a moment)..."
        COPYFILE_DISABLE=1 tar --exclude='.DS_Store' -czf - -C "${PROJECT_DIR}" Bedrock 2>/dev/null | \
            multipass exec "${VM_NAME}" -- tar xzf - -C "${PROJECT_MOUNT}/" 2>/dev/null
    fi
fi

# Run the full setup script
warn "Running setup script (this will take 5-10 minutes)..."
multipass exec "${VM_NAME}" -- sudo bash "${PROJECT_MOUNT}/scripts/setup.sh"

# Set up port forwarding
warn "Setting up port forwarding..."
success "Bedrock will be available at: localhost:8888"
success "API will be available at: localhost:8080"

# Note: Multipass port forwarding needs to be set up manually or via alias
# We'll provide instructions in the output

# Get VM IP
VM_IP=$(multipass info "${VM_NAME}" | grep "IPv4" | awk '{print $2}')
success "VM IP address: ${VM_IP}"

# Wait for setup to complete
warn "Waiting for setup to complete (this may take 5-10 minutes)..."
warn "You can monitor progress with: multipass exec ${VM_NAME} -- tail -f /var/log/cloud-init-output.log"

# Check if services are running
warn "Checking service status..."
sleep 10

if multipass exec "${VM_NAME}" -- systemctl is-active bedrock > /dev/null 2>&1; then
    success "✓ Bedrock service is running"
else
    warn "⚠ Bedrock service may still be starting..."
fi

if multipass exec "${VM_NAME}" -- systemctl is-active php8.4-fpm > /dev/null 2>&1; then
    success "✓ PHP-FPM service is running"
else
    warn "⚠ PHP-FPM service may still be starting..."
fi

if multipass exec "${VM_NAME}" -- systemctl is-active nginx > /dev/null 2>&1; then
    success "✓ Nginx service is running"
else
    warn "⚠ Nginx service may still be starting..."
fi

echo
success "=========================================="
success "Setup Complete!"
success "=========================================="
echo
info "Quick Start:"
echo "  # SSH into the VM (like 'vagrant ssh')"
echo "  multipass shell ${VM_NAME}"
echo
echo "  # Or run commands directly"
echo "  multipass exec ${VM_NAME} -- systemctl status bedrock"
echo
info "Access Services:"
echo "  # Bedrock (from host)"
echo "  nc ${VM_IP} 8888"
echo
echo "  # API (from host)"
echo "  curl http://${VM_IP}/api/status"
echo
info "Port Forwarding (optional):"
echo "  # To access from localhost instead of VM IP:"
echo "  multipass port-forward ${VM_NAME} 8888:8888  # Bedrock"
echo "  multipass port-forward ${VM_NAME} 80:8080   # API (host:guest)"
echo
info "Development:"
echo "  # Project is mounted at /bedrock-starter in the VM"
echo "  # Edit files locally - changes sync in real-time!"
echo "  # After editing C++ code, rebuild:"
echo "  multipass exec ${VM_NAME} -- bash -c 'cd /opt/bedrock/server/core && ninja'"
echo
info "Service Management:"
echo "  multipass exec ${VM_NAME} -- sudo systemctl restart bedrock"
echo "  multipass exec ${VM_NAME} -- sudo systemctl restart nginx"
echo
info "View Logs:"
echo "  multipass exec ${VM_NAME} -- sudo journalctl -u bedrock -f"
echo

