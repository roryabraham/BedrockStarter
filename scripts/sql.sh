#!/bin/bash
# Open the sqlite3 CLI inside the Multipass VM, connected to the Bedrock database.
# Intended to be run from the host machine.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

VM_NAME="bedrock-starter"
DB_PATH="/var/lib/bedrock/bedrock.db"

print_header "SQLite CLI (Bedrock DB in VM: ${VM_NAME})"

# Ensure Multipass is available on the host
require_command multipass "Please install Multipass:
  macOS:   brew install multipass
  Linux:   snap install multipass
  Windows: Download from https://multipass.run/install"

# Make sure the VM exists and is reachable
if ! multipass info "${VM_NAME}" &>/dev/null; then
    error "VM '${VM_NAME}' not found. Run ./scripts/launch.sh first."
    exit 1
fi

# Ensure the VM is running
info "Starting VM '${VM_NAME}' if needed..."
multipass start "${VM_NAME}" >/dev/null 2>&1 || true

info "Launching sqlite3 against ${DB_PATH} (user: bedrock)..."
echo

# Drop into the sqlite3 CLI inside the VM.
# Forward any additional arguments (e.g., -cmd '.tables') to sqlite3.
multipass exec "${VM_NAME}" -- sudo -u bedrock sqlite3 "${DB_PATH}" "$@"


