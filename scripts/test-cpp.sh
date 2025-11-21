#!/bin/bash
# Run the Bedrock Core plugin tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

PROJECT_DIR="$(get_project_dir)"
CORE_DIR="${PROJECT_DIR}/server/core"

print_header "Bedrock Core Tests"
info "Project directory: ${PROJECT_DIR}"

cd "${CORE_DIR}"

if [ ! -f "${PROJECT_DIR}/Bedrock/libbedrock.a" ]; then
    warn "Bedrock library not found. Building Bedrock (this may take a while)..."
    pushd "${PROJECT_DIR}/Bedrock" > /dev/null
    make bedrock --jobs "$(nproc)"
    popd > /dev/null
fi

info "Configuring CMake..."
rm -rf CMakeCache.txt CMakeFiles/ build.ninja .ninja_* coretest coretest.dSYM
cmake -G Ninja .

info "Building test target..."
ninja -j "$(nproc)" coretest

info "Running tests..."
cd "${CORE_DIR}/test"
./coretest "$@"

success "Core plugin tests finished successfully."

