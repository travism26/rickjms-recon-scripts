#!/bin/bash

# Import required modules
source "$(dirname "${BASH_SOURCE[0]}")/../../core/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../api/rate_limiting.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../core/utils.sh"

# Main TLS Bufferover scanning function
run_tls_bufferover() {
    local USERIN="$1"
    debug "run_tls_bufferover($USERIN)"
    local TLSOUT="tls_bufferover.out"
    local response
    local status
    local temp_output

    if isDryRun; then
        echo "curl tls.bufferover.run/dns?q=\"$USERIN\" 2>/dev/null | jq .Results >> $SCAN_FOLDER/$TLSOUT"
    else
        info "Executing search tls.bufferover.run $USERIN"
        rate_limit "tls_bufferover"
        
        # Create temporary file for output
        temp_output=$(mktemp)
        
        # Make the API call
        response=$(curl -s -w "%{http_code}" "tls.bufferover.run/dns?q=$USERIN" 2>/dev/null)
        status=$?

        if [[ $status -ne 0 ]]; then
            handle_api_error "tls_bufferover" "$status" "$response"
            rm -f "$temp_output"
            return 1
        fi

        http_code=${response: -3}
        if [[ $http_code -ne 200 ]]; then
            warn "TLS Bufferover API returned HTTP $http_code for $USERIN"
            rm -f "$temp_output"
            return 1
        fi

        # Process the response
        echo "${response:0:-3}" | jq -r '.Results[]?' > "$temp_output"

        # Check if we got any results
        if [[ -s "$temp_output" ]]; then
            # Filter out empty lines and duplicates
            cat "$temp_output" | grep -v '^$' | sort -u >> "$SCAN_FOLDER/$TLSOUT"
            local found_count=$(wc -l < "$temp_output")
            info "Found $found_count TLS records for $USERIN"
        else
            warn "No TLS records found for $USERIN"
        fi

        # Clean up
        rm -f "$temp_output"
    fi
}

# Process a file containing multiple domains
run_tls_bufferover_with_file() {
    local FILEIN="$1"
    debug "run_tls_bufferover_with_file($FILEIN)"
    
    # Validate input file
    if ! test -f "$FILEIN"; then
        error "Please enter a correct file, you entered an incorrect file:$FILEIN" 254
    fi

    local total_domains=$(wc -l < "$FILEIN")
    local processed=0
    local start_time=$(date +%s)
    local errors=0

    # Process each domain
    while IFS= read -r line; do
        ((processed++))
        
        # Show progress
        if ((processed % 5 == 0)); then
            local current_time=$(date +%s)
            local elapsed=$((current_time - start_time))
            local percent=$((processed * 100 / total_domains))
            info "Progress: $processed/$total_domains ($percent%) - Elapsed time: ${elapsed}s"
        fi

        debug "run_tls_bufferover_with_file->run_tls_bufferover($line)"
        if ! run_tls_bufferover "$line"; then
            ((errors++))
            warn "Failed to process $line"
        fi
        
        # Add a small delay between requests to be nice to the API
        sleep 2
    done < "$FILEIN"

    # Show final statistics
    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))
    info "Completed TLS Bufferover scanning for $total_domains domains in ${total_time}s"
    if ((errors > 0)); then
        warn "$errors domains failed to process"
    fi
}

# Validate TLS Bufferover API access
check_tls_bufferover_access() {
    debug "Checking TLS Bufferover API access"
    
    local response
    local status
    
    response=$(curl -s -w "%{http_code}" "tls.bufferover.run/dns?q=example.com" 2>/dev/null)
    status=$?

    if [[ $status -ne 0 ]]; then
        warn "TLS Bufferover API is not accessible"
        return 1
    fi

    http_code=${response: -3}
    if [[ $http_code -ne 200 ]]; then
        warn "TLS Bufferover API returned unexpected status code: $http_code"
        return 1
    fi

    info "TLS Bufferover API is accessible"
    return 0
}
