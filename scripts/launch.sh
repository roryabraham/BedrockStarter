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
if [[ ! -d "${PROJECT_DIR}/Bedrock" ]]; then
    warn "Bedrock submodule not found. Initializing..."
    cd "${PROJECT_DIR}"
    git submodule update --init --recursive || {
        error "Failed to initialize Bedrock submodule"
        warn "Please run: git submodule update --init --recursive"
        exit 1
    }
fi

# Generate .clangd from .clangd.example if it doesn't exist
if [[ ! -f "${PROJECT_DIR}/.clangd" ]] && [[ -f "${PROJECT_DIR}/.clangd.example" ]]; then
    info "Generating .clangd from template..."

    # Detect fmt library path based on OS
    FMT_INCLUDE=""
    if command -v brew &> /dev/null; then
        # macOS with Homebrew
        FMT_PREFIX=$(brew --prefix fmt 2>/dev/null || echo "")
        if [[ -n "$FMT_PREFIX" && -d "${FMT_PREFIX}/include/fmt" ]]; then
            FMT_INCLUDE="${FMT_PREFIX}/include"
        fi
    elif [[ -d "/usr/include/fmt" ]]; then
        # Linux (Ubuntu/Debian) - fmt installed via apt
        FMT_INCLUDE="/usr/include/fmt"
    elif [[ -d "/usr/local/include/fmt" ]]; then
        # Linux - fmt installed from source to /usr/local
        FMT_INCLUDE="/usr/local/include/fmt"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        # Windows - vcpkg typical location
        if [[ -d "C:/vcpkg/installed/x64-windows/include/fmt" ]]; then
            FMT_INCLUDE="C:/vcpkg/installed/x64-windows/include/fmt"
        fi
    fi

    # If still not found, leave empty and rely on compile_commands.json
    if [[ -z "$FMT_INCLUDE" ]]; then
        warn "fmt library not found in standard locations IDE may not find fmt headers"
        FMT_INCLUDE=""
    fi

    sed -e "s|{{PROJECT_ROOT}}|${PROJECT_DIR}|g" \
        -e "s|{{FMT_INCLUDE}}|${FMT_INCLUDE}|g" \
        "${PROJECT_DIR}/.clangd.example" > "${PROJECT_DIR}/.clangd"

    if [[ -n "$FMT_INCLUDE" ]]; then
        success "✓ Created .clangd with project-specific paths (fmt: ${FMT_INCLUDE})"
    else
        success "✓ Created .clangd (fmt paths will be resolved from compile_commands.json)"
    fi
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

# Configure networking (Bridged mode on macOS to avoid port 53/WARP conflicts)
NETWORK_ARGS=()
if [[ "$(uname)" == "Darwin" ]]; then
    DEFAULT_IFACE=$(route get default | grep interface | awk '{print $2}')
    if [[ -n "$DEFAULT_IFACE" ]]; then
        info "Detected default network interface: $DEFAULT_IFACE"
        info "Using bridged networking to avoid DNS port 53 conflicts (WARP compatible)..."
        NETWORK_ARGS=("--network" "$DEFAULT_IFACE")
    fi
fi

# Check if VM already exists
if multipass list | grep -q "^${VM_NAME}"; then
    warn "VM '${VM_NAME}' already exists"
    read -p "Delete and recreate? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "Deleting existing VM..."
        multipass delete "${VM_NAME}" --purge || true
    else
        success "Using existing VM. To start it: multipass start ${VM_NAME}"
        success "To shell into it: multipass shell ${VM_NAME}"
        exit 0
    fi
fi

# Launch VM with cloud-init (just installs dependencies)
info "Launching Ubuntu VM (this may take a few minutes)..."
if ! multipass launch \
    --name "${VM_NAME}" \
    --memory 4G \
    --cpus 4 \
    --disk 20G \
    --cloud-init "${PROJECT_DIR}/multipass.yaml" \
    --timeout 600 \
    "${NETWORK_ARGS[@]}" \
    "${IMAGE}"; then
    error "Failed to launch VM"
    exit 1
fi

# Wait for cloud-init to complete
info "Waiting for cloud-init to complete..."
multipass exec "${VM_NAME}" -- cloud-init status --wait || true
sleep 5

# Set as primary if no primary exists (allows 'multipass shell' without name)
PRIMARY_NAME=$(multipass get client.primary-name || echo "")
if [[ -z "$PRIMARY_NAME" ]] || [[ "$PRIMARY_NAME" == "None" ]] || [[ "$PRIMARY_NAME" == "primary" ]]; then
    info "Setting ${VM_NAME} as primary instance..."
    if multipass set client.primary-name="${VM_NAME}"; then
        success "✓ You can now use 'multipass shell' without specifying the VM name"
    else
        error "Failed to set primary instance. Run 'multipass set client.primary-name=${VM_NAME}' manually to investigate."
        exit 1
    fi
fi

# Prepare project directory mount for development
PROJECT_MOUNT="/bedrock-starter"
info "Installing multipass-sshfs inside the VM (required for mounts)..."
if multipass exec "${VM_NAME}" -- sudo snap install multipass-sshfs; then
    success "✓ multipass-sshfs installed"
else
    warn "snap install failed, attempting snap refresh..."
    if multipass exec "${VM_NAME}" -- sudo snap refresh multipass-sshfs; then
        success "✓ multipass-sshfs refreshed"
    else
        error "Failed to install or refresh multipass-sshfs. Ensure the VM has internet access, then rerun this script."
        exit 1
    fi
fi

info "Mounting project directories for real-time sync..."
if multipass mount "${PROJECT_DIR}" "${VM_NAME}:${PROJECT_MOUNT}"; then
    success "✓ Mount successful - files will sync in real-time"
else
    error "Unable to mount ${PROJECT_DIR} to ${VM_NAME}:${PROJECT_MOUNT}. Confirm multipassd has Full Disk Access and rerun."
    exit 1
fi

# Run the full setup script
info "Running setup script (this will take 5-10 minutes)..."
info "Monitor progress in another terminal with: multipass exec ${VM_NAME} -- tail -f /var/log/cloud-init-output.log"
multipass exec "${VM_NAME}" -- sudo bash "${PROJECT_MOUNT}/scripts/setup.sh"

# Set up port forwarding
info "Setting up port forwarding..."
success "Bedrock will be available at: localhost:8888"
success "API will be available at: localhost:8080"

# Note: Multipass port forwarding needs to be set up manually or via alias
# We'll provide instructions in the output

# Get VM IP
VM_IPS=$(multipass info "${VM_NAME}" | grep "IPv4" | awk -F: '{print $2}' | xargs)
success "VM IP address(es): ${VM_IPS}"

# Check if services are running
info "Checking service status..."
sleep 10

if multipass exec "${VM_NAME}" -- systemctl is-active bedrock; then
    success "✓ Bedrock service is running"
else
    warn "⚠ Bedrock service may still be starting..."
fi

if multipass exec "${VM_NAME}" -- systemctl is-active php8.4-fpm; then
    success "✓ PHP-FPM service is running"
else
    warn "⚠ PHP-FPM service may still be starting..."
fi

if multipass exec "${VM_NAME}" -- systemctl is-active nginx; then
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
echo "  nc <VM_IP> 8888"
echo
echo "  # API (from host)"
echo "  curl http://<VM_IP>/api/status"
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

