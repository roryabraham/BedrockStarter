#!/bin/bash
# Run clang-tidy on Core plugin C++ code

set -e

# shellcheck source=scripts/common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

PROJECT_DIR=$(get_project_dir)
readonly PROJECT_DIR

CORE_DIR="${PROJECT_DIR}/server/core"
readonly CORE_DIR

print_header "Clang-Tidy"

# Check if clang-tidy is installed
if ! command -v clang-tidy &> /dev/null; then
    error "clang-tidy is not installed"
    echo
    echo "Install it with:"
    echo "  brew install llvm          # macOS"
    echo "  sudo apt install clang-tidy # Ubuntu/Debian"
    exit 1
fi

CLANG_TIDY_VERSION=$(clang-tidy --version | head -n1)
info "Using: ${CLANG_TIDY_VERSION}"

# Ensure we have compile_commands.json
cd "${CORE_DIR}"
if [ ! -f "compile_commands.json" ]; then
    info "compile_commands.json not found, generating..."
    rm -rf CMakeCache.txt CMakeFiles/ build.ninja .ninja_* || true
    cmake -G Ninja -DCMAKE_EXPORT_COMPILE_COMMANDS=ON .
fi

# Run clang-tidy on Core plugin source files
info "Running clang-tidy on Core plugin..."
echo

# Find all .cpp files in the core directory (excluding test directory)
CPP_FILES=$(find "${CORE_DIR}" -name "*.cpp" -not -path "*/test/*" -not -path "*/CMakeFiles/*")

if [ -z "${CPP_FILES}" ]; then
    warn "No C++ files found to analyze"
    exit 0
fi

# Run clang-tidy
FAILED=0
for file in ${CPP_FILES}; do
    RELATIVE_FILE="${file#"${PROJECT_DIR}"/}"
    info "Checking ${RELATIVE_FILE}..."
    if ! clang-tidy --quiet -p "${CORE_DIR}" "${file}"; then
        FAILED=1
    fi
done

echo
if [ ${FAILED} -eq 0 ]; then
    success "Clang-tidy checks passed!"
else
    error "Clang-tidy found issues"
    exit 1
fi

