#!/bin/bash
# Install C++ build dependencies for Bedrock development
# Used by both VM setup and CI workflows

set -e

# shellcheck source=scripts/common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/common.sh" ]]; then
    source "${SCRIPT_DIR}/common.sh"
    print_header "Installing C++ Build Dependencies"
else
    # Fallback for CI environments
    echo "Installing C++ Build Dependencies..."
fi

# Base C++ build packages (common to all environments)
PACKAGES=(
    cmake
    ninja-build
    clang
    mold
    libpcre2-dev
    libfmt-dev
    pkg-config
)

# VM-specific packages
VM_PACKAGES=(
    zlib1g-dev
    git
    libc++-dev
    libc++abi-dev
    ccache
    python3
    python3-jsonschema
    python3-jinja2
    sqlite3
)

# Optional packages based on arguments
INCLUDE_VM_DEPS=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --clang-tidy)
            PACKAGES+=(clang-tidy)
            shift
            ;;
        --vm)
            INCLUDE_VM_DEPS=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--clang-tidy] [--vm]"
            exit 1
            ;;
    esac
done

# Add VM packages if requested
if [[ "${INCLUDE_VM_DEPS}" == true ]]; then
    PACKAGES+=("${VM_PACKAGES[@]}")
fi

# Install packages
if command -v apt-fast &> /dev/null; then
    # Use apt-fast if available (VM setup)
    apt-fast install -y "${PACKAGES[@]}"
else
    # Fall back to apt-get (CI)
    apt-get update
    apt-get install -y "${PACKAGES[@]}"
fi

if [[ -f "${SCRIPT_DIR}/common.sh" ]]; then
    success "C++ build dependencies installed"
else
    echo "✓ C++ build dependencies installed"
fi

