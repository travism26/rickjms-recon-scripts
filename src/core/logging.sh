#!/bin/bash

# Guard to prevent multiple sourcing
if [[ -n "${LOGGING_SOURCED:-}" ]]; then
    return 0
fi
export LOGGING_SOURCED=1

# Logging colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Main logging function
log() {
    local level="$1"
    local msg="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")
            [[ -z "${SILENT_MODE:-}" ]] && echo -e "${GREEN}[${timestamp}] [INFO]${NC}  $msg"
            ;;
        "WARN")
            [[ -z "${SILENT_MODE:-}" ]] && echo -e "${YELLOW}[${timestamp}] [WARN]${NC}  $msg"
            ;;
        "ERROR")
            echo -e "${RED}[${timestamp}] [ERROR]${NC} $msg" >&2
            ;;
        "DEBUG")
            [[ -n "${ENABLE_DEBUG:-}" ]] && echo -e "${BLUE}[${timestamp}] [DEBUG]${NC} $msg"
            ;;
    esac
}

# Wrapper functions for logging
info() { log "INFO" "$1"; }
warn() { log "WARN" "$1"; }
debug() { log "DEBUG" "$1"; }
error() { log "ERROR" "$1"; exit "${2:-1}"; }
