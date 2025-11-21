#!/bin/bash
# Common shell utilities for Bedrock Starter scripts
# Source this file in other scripts: source "$(dirname "${BASH_SOURCE[0]}")/../scripts/common.sh"

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Print colored output functions
info() {
    echo -e "${BLUE}$*${NC}"
}

success() {
    echo -e "${GREEN}$*${NC}"
}

warn() {
    echo -e "${YELLOW}$*${NC}"
}

error() {
    echo -e "${RED}$*${NC}"
}

# Get project directory
# Usage: PROJECT_DIR=$(get_project_dir)
# Returns: Absolute path to project root
get_project_dir() {
    # If running in Multipass VM, check for mounted directory first
    if [ -d "/bedrock-starter" ] && [ -f "/bedrock-starter/scripts/setup.sh" ]; then
        echo "/bedrock-starter"
        return
    fi

    # common.sh is in scripts/, so go up one directory to get project root
    local script_dir
    script_dir="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"
    echo "${script_dir}"
}

# Check if running as root
# Usage: check_root
# Exits with error if not root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Please run as root (use sudo)"
        exit 1
    fi
}

# Check if command exists
# Usage: require_command <command> [install_instructions]
# Exits with error if command not found
require_command() {
    local cmd="$1"
    local instructions="${2:-Please install $cmd}"

    if ! command -v "$cmd" &> /dev/null; then
        error "$cmd is not installed!"
        echo
        echo "$instructions"
        exit 1
    fi
}

# Print a section header
# Usage: print_header "Title"
print_header() {
    local title="$1"
    echo "=========================================="
    echo "$title"
    echo "=========================================="
}
