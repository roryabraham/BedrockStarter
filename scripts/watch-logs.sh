#!/bin/bash
# Watch colorized logs from the Bedrock service in realtime
# Optionally filter logs with grep

set -e

# shellcheck source=scripts/common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Default service to watch
SERVICE="bedrock"
FILTER=""
LINES=50

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --service|-s)
            SERVICE="$2"
            shift 2
            ;;
        --filter|-f)
            FILTER="$2"
            shift 2
            ;;
        --lines|-n)
            LINES="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "Watch colorized logs from services in realtime"
            echo
            echo "Options:"
            echo "  -s, --service NAME    Service to watch (default: bedrock)"
            echo "                        Options: bedrock, nginx, php"
            echo "  -f, --filter PATTERN  Filter logs with grep pattern"
            echo "  -n, --lines NUM       Number of initial lines to show (default: 50)"
            echo "  -h, --help            Show this help message"
            echo
            echo "Examples:"
            echo "  $0                              # Watch bedrock logs"
            echo "  $0 -s nginx                     # Watch nginx logs"
            echo "  $0 -f HelloWorld                # Filter for HelloWorld logs"
            echo "  $0 -s bedrock -f \"error|warn\" # Watch bedrock, show errors/warnings"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

print_header "Watching ${SERVICE} logs"
if [ -n "$FILTER" ]; then
    info "Filter: ${FILTER}"
fi
echo

# Check if we're on the host (need multipass) or in the VM
if [ -d "/bedrock-starter" ] && [ -f "/bedrock-starter/scripts/setup.sh" ]; then
    # We're in the VM
    IN_VM=true
else
    # We're on the host
    IN_VM=false
    
    # Check if VM is running
    if ! multipass list | grep -q "bedrock-starter.*Running"; then
        error "VM is not running"
        echo "Start it with: ./scripts/launch.sh"
        exit 1
    fi
fi

# Function to tail logs based on service
tail_logs() {
    case "$SERVICE" in
        bedrock)
            if [ "$IN_VM" = true ]; then
                CMD="journalctl -u bedrock -n ${LINES} -f --no-pager"
            else
                CMD="multipass exec bedrock-starter -- sudo journalctl -u bedrock -n ${LINES} -f --no-pager"
            fi
            ;;
        nginx)
            if [ "$IN_VM" = true ]; then
                CMD="tail -n ${LINES} -f /var/log/nginx/api_error.log"
            else
                CMD="multipass exec bedrock-starter -- sudo tail -n ${LINES} -f /var/log/nginx/api_error.log"
            fi
            ;;
        php|php8.4-fpm)
            if [ "$IN_VM" = true ]; then
                CMD="journalctl -u php8.4-fpm -n ${LINES} -f --no-pager"
            else
                CMD="multipass exec bedrock-starter -- sudo journalctl -u php8.4-fpm -n ${LINES} -f --no-pager"
            fi
            ;;
        *)
            error "Unknown service: $SERVICE"
            echo "Available services: bedrock, nginx, php"
            exit 1
            ;;
    esac

    # Apply filter if specified
    if [ -n "$FILTER" ]; then
        eval "$CMD" | grep --color=always -E "$FILTER"
    else
        # Add color to output using ccze if available, otherwise use grep for basic coloring
        if command -v ccze &> /dev/null; then
            eval "$CMD" | ccze -A
        else
            # Basic colorization with grep
            eval "$CMD" | grep --color=always -E 'error|warn|info|dbug|eror|\[.*\]|$'
        fi
    fi
}

# Run with proper signal handling
trap 'echo; info "Stopped watching logs"; exit 0' INT TERM

tail_logs

