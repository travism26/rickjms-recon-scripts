#!/usr/bin/env bash

# Import logging functions
source "$(dirname "${BASH_SOURCE[0]}")/../../core/logging.sh"

# Rate limiting configuration - using indexed arrays instead of associative arrays
# Format: API_NAME:LIMIT
API_RATE_LIMITS=(
    "tls_bufferover:60"  # requests per minute
    "crtsh:60"          # requests per minute
    "wayback:100"       # requests per minute
)

# Format: API_NAME:TIMESTAMP
LAST_API_CALL=(
    "tls_bufferover:0"
    "crtsh:0"
    "wayback:0"
)

# Get rate limit for an API
get_rate_limit() {
    local api_name="$1"
    local limit=0
    
    for entry in "${API_RATE_LIMITS[@]}"; do
        local name="${entry%%:*}"
        local value="${entry#*:}"
        
        if [[ "$name" == "$api_name" ]]; then
            limit="$value"
            break
        fi
    done
    
    echo "$limit"
}

# Get last call timestamp for an API
get_last_call() {
    local api_name="$1"
    local timestamp=0
    
    for entry in "${LAST_API_CALL[@]}"; do
        local name="${entry%%:*}"
        local value="${entry#*:}"
        
        if [[ "$name" == "$api_name" ]]; then
            timestamp="$value"
            break
        fi
    done
    
    echo "$timestamp"
}

# Update last call timestamp for an API
update_last_call() {
    local api_name="$1"
    local new_time="$2"
    local i=0
    
    for entry in "${LAST_API_CALL[@]}"; do
        local name="${entry%%:*}"
        
        if [[ "$name" == "$api_name" ]]; then
            LAST_API_CALL[$i]="${name}:${new_time}"
            return
        fi
        
        ((i++))
    done
    
    # If not found, add it
    LAST_API_CALL+=("${api_name}:${new_time}")
}

# Rate limiting function
rate_limit() {
    local api_name="$1"
    local rate_limit=$(get_rate_limit "$api_name")
    local last_call=$(get_last_call "$api_name")
    local current_time=$(date +%s)
    local time_diff=$((current_time - last_call))
    local min_interval=$((60 / rate_limit))

    if [[ $time_diff -lt $min_interval ]]; then
        local sleep_time=$((min_interval - time_diff))
        debug "Rate limiting $api_name, sleeping for ${sleep_time}s"
        sleep "$sleep_time"
    fi

    update_last_call "$api_name" "$(date +%s)"
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
    
    # Check if it already exists
    for entry in "${API_RATE_LIMITS[@]}"; do
        local name="${entry%%:*}"
        
        if [[ "$name" == "$api_name" ]]; then
            # Update existing entry
            local i=0
            for e in "${API_RATE_LIMITS[@]}"; do
                if [[ "${e%%:*}" == "$api_name" ]]; then
                    API_RATE_LIMITS[$i]="${api_name}:${rate_limit}"
                    break
                fi
                ((i++))
            done
            
            # Also update last call if needed
            update_last_call "$api_name" "0"
            debug "Updated rate limit for $api_name: $rate_limit requests per minute"
            return
        fi
    done
    
    # Add new entry
    API_RATE_LIMITS+=("${api_name}:${rate_limit}")
    LAST_API_CALL+=("${api_name}:0")
    
    debug "Added rate limit for $api_name: $rate_limit requests per minute"
}

# Remove an API rate limit
remove_api_rate_limit() {
    local api_name="$1"
    local new_limits=()
    local new_calls=()
    
    # Remove from API_RATE_LIMITS
    for entry in "${API_RATE_LIMITS[@]}"; do
        local name="${entry%%:*}"
        
        if [[ "$name" != "$api_name" ]]; then
            new_limits+=("$entry")
        fi
    done
    API_RATE_LIMITS=("${new_limits[@]}")
    
    # Remove from LAST_API_CALL
    for entry in "${LAST_API_CALL[@]}"; do
        local name="${entry%%:*}"
        
        if [[ "$name" != "$api_name" ]]; then
            new_calls+=("$entry")
        fi
    done
    LAST_API_CALL=("${new_calls[@]}")
    
    debug "Removed rate limit for $api_name"
}

# Get current rate limit for an API
get_api_rate_limit() {
    local api_name="$1"
    get_rate_limit "$api_name"
}

# Check if an API has rate limiting enabled
has_rate_limit() {
    local api_name="$1"
    local limit=$(get_rate_limit "$api_name")
    [[ "$limit" != "0" ]]
}
