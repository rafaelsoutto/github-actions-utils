#!/usr/bin/env bash
# logging.sh - Logging utilities for CI/CD pipelines
# Version: 1.0.0
# This file is automatically sourced and provides logging functions

# Prevent multiple sourcing
if [[ -n "${LOGGING_SH_LOADED:-}" ]]; then
    return 0
fi
readonly LOGGING_SH_LOADED=1

# Color codes for output
readonly LOG_COLOR_RED='\033[0;31m'
readonly LOG_COLOR_GREEN='\033[0;32m'
readonly LOG_COLOR_YELLOW='\033[1;33m'
readonly LOG_COLOR_BLUE='\033[0;34m'
readonly LOG_COLOR_NC='\033[0m' # No Color

# Log levels
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3

# Default log level (can be overridden by LOG_LEVEL env var)
: "${LOG_LEVEL:=${LOG_LEVEL_INFO}}"

# Check if we should log based on level
should_log() {
    local level=$1
    [[ ${level} -ge ${LOG_LEVEL} ]]
}

# Get timestamp for logs
log_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Debug logging
log_debug() {
    if should_log ${LOG_LEVEL_DEBUG}; then
        echo -e "${LOG_COLOR_BLUE}[DEBUG $(log_timestamp)]${LOG_COLOR_NC} $*" >&2
    fi
}

# Info logging
log_info() {
    if should_log ${LOG_LEVEL_INFO}; then
        echo -e "${LOG_COLOR_GREEN}[INFO $(log_timestamp)]${LOG_COLOR_NC} $*" >&2
    fi
}

# Warning logging
log_warn() {
    if should_log ${LOG_LEVEL_WARN}; then
        echo -e "${LOG_COLOR_YELLOW}[WARN $(log_timestamp)]${LOG_COLOR_NC} $*" >&2
    fi
}

# Error logging
log_error() {
    if should_log ${LOG_LEVEL_ERROR}; then
        echo -e "${LOG_COLOR_RED}[ERROR $(log_timestamp)]${LOG_COLOR_NC} $*" >&2
    fi
}

# Log and exit with error
log_fatal() {
    log_error "$@"
    exit 1
}

# Log command execution (useful for debugging)
log_exec() {
    log_debug "Executing: $*"
    "$@"
}

# Export functions so they're available in subshells
export -f log_debug
export -f log_info
export -f log_warn
export -f log_error
export -f log_fatal
export -f log_exec
export -f should_log
export -f log_timestamp
