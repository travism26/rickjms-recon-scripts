#!/bin/bash

# Import logging functions
source "$(dirname "${BASH_SOURCE[0]}")/../../core/logging.sh"

# Rate limiting configuration
declare -A API_RATE_LIMITS=(
    ["tls_bufferover"]=60  # requests per minute
    ["crtsh"]=60          # requests per minute
    ["wayback"]=100       # requests per minute
)

declare -A LAST_API_CALL=(
    ["tls_bufferover"]=0
    ["crtsh"]=0
    ["wayback"]=0
)

# Rate limiting function
rate_limit() {
    local api_name="$1"
    local rate_limit="${API_RATE_LIMITS[$api_name]}"
    local last_call="${LAST_API_CALL[$api_name]}"
    local current_time=$(date +%s)
    local time_diff=$((current_time - last_call))
    local min_interval=$((60 / rate_limit))

    if [[ $time_diff -lt $min_interval ]]; then
        local sleep_time=$((min_interval - time_diff))
        debug "Rate limiting $api_name, sleeping for ${sleep_time}s"
        sleep "$sleep_time"
    fi

    LAST_API_CALL[$api_name]=$(date +%s)
}

# Error handling for API calls
handle_api_error() {
    local api_name="$1"
    local status="$2"
    local response="$3"
    local max_retries=3
    local retry_count=0

    while [[ $status -ne 0 && $retry_count -lt $max_retries ]]; do
        warn "API call to $api_name failed (status: $status). Retrying in 5s... (attempt $((retry_count + 1))/$max_retries)"
        sleep 5
        ((retry_count++))
        return 1
    done

    if [[ $retry_count -eq $max_retries ]]; then
        error "API call to $api_name failed after $max_retries attempts" 1
    fi
}

# Add a new API rate limit
add_api_rate_limit() {
    local api_name="$1"
    local rate_limit="$2"
    
    API_RATE_LIMITS["$api_name"]=$rate_limit
    LAST_API_CALL["$api_name"]=0
    
    debug "Added rate limit for $api_name: $rate_limit requests per minute"
}

# Remove an API rate limit
remove_api_rate_limit() {
    local api_name="$1"
    
    unset API_RATE_LIMITS["$api_name"]
    unset LAST_API_CALL["$api_name"]
    
    debug "Removed rate limit for $api_name"
}

# Get current rate limit for an API
get_api_rate_limit() {
    local api_name="$1"
    echo "${API_RATE_LIMITS[$api_name]:-0}"
}

# Check if an API has rate limiting enabled
has_rate_limit() {
    local api_name="$1"
    [[ -n "${API_RATE_LIMITS[$api_name]:-}" ]]
}
