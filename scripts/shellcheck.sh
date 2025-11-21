#!/bin/bash
# Run shellcheck on all shell scripts in the project
# Excludes Bedrock submodule scripts

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Check if shellcheck is installed
require_command shellcheck "Install shellcheck:
  macOS:   brew install shellcheck
  Linux:   apt-get install shellcheck
  Other:   https://github.com/koalaman/shellcheck#installing"

# Get project root
PROJECT_DIR=$(get_project_dir)

info "Running shellcheck on project scripts..."
echo

# Find all shell scripts in scripts/ directory (excluding Bedrock submodule)
SCRIPTS=()
while IFS= read -r -d '' script; do
    SCRIPTS+=("$script")
done < <(find "${PROJECT_DIR}/scripts" -name "*.sh" -type f -print0 2>/dev/null)

if [ ${#SCRIPTS[@]} -eq 0 ]; then
    warn "No shell scripts found in scripts/ directory"
    exit 0
fi

# Run shellcheck on each script (only fail on warnings and errors, not info)
ERRORS=0
for script in "${SCRIPTS[@]}"; do
    echo "Checking: ${script#"${PROJECT_DIR}"/}"
    if ! shellcheck -S warning "$script"; then
        ERRORS=$((ERRORS + 1))
    fi
done

echo
if [ $ERRORS -eq 0 ]; then
    success "✓ All scripts passed shellcheck"
    exit 0
else
    error "✗ shellcheck found issues in $ERRORS script(s)"
    exit 1
fi

