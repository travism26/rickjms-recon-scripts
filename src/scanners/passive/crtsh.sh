#!/bin/bash

# Import required modules
source "$(dirname "${BASH_SOURCE[0]}")/../../core/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../api/rate_limiting.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../core/utils.sh"

# Main crt.sh scanning function
run_crtsh() {
    local USERIN="$1"
    debug "run_crtsh($USERIN)"
    local CRTOUT="crtsh.host.out"
    local response
    local status
    local temp_output

    # Validate input is a domain-like string (not a file path)
    if [[ "$USERIN" == *"/"* ]]; then
        error "Invalid domain name: $USERIN (contains path separators)"
        return 1
    fi

    # Basic domain validation - should contain at least one dot
    if [[ "$USERIN" != *"."* ]]; then
        error "Invalid domain name: $USERIN (missing domain extension)"
        return 1
    fi

# curl -s "https://crt.sh/?q=%.$1&output=json" | jq -r '.[] | .name_value' | sed 's/\*\.//g' | sort -u
    if isDryRun; then
        echo "curl -s \"https://crt.sh/?q=%.$USERIN&output=json\" | jq -r '.[] | .name_value' | sed 's/\*\.//g' | sort -u >> $SCAN_FOLDER/$CRTOUT"
    else
        info "Executing search crt.sh/?q=%.$USERIN"
        rate_limit "crtsh"
        
        # Create temporary file for output with error handling
        temp_output=$(mktemp) || {
            error "Failed to create temporary file for crt.sh output" 1
            return 1
        }
        curl_command="curl -s -w \"%{http_code}\" --max-time 30 \"https://crt.sh/?q=%.$USERIN&output=json\""
        debug "curl_command: $curl_command"
        # Make the API call with timeout to prevent hanging
        response=$(eval "$curl_command")
        status=$?

        if [[ $status -ne 0 ]]; then
            handle_api_error "crt.sh" "$status" "$response"
            rm -f "$temp_output"
            return 1
        fi

        # Check if response has enough characters before extracting HTTP code
        if [[ ${#response} -lt 3 ]]; then
            warn "crt.sh API returned an empty or invalid response for $USERIN"
            rm -f "$temp_output"
            return 1
        else
            # Safely extract the HTTP code from the end of the response
            response_length=${#response}
            if [[ $response_length -ge 3 ]]; then
                http_code=${response: -3}
                # Verify that http_code is a valid number
                if [[ "$http_code" =~ ^[0-9]+$ ]]; then
                    if [[ $http_code -ne 200 ]]; then
                        warn "crt.sh API returned HTTP $http_code for $USERIN"
                        rm -f "$temp_output"
                        return 1
                    fi
                else
                    warn "crt.sh API returned invalid HTTP code for $USERIN: $http_code"
                    rm -f "$temp_output"
                    return 1
                fi
            else
                warn "crt.sh API response too short to extract HTTP code for $USERIN"
                rm -f "$temp_output"
                return 1
            fi
        fi

        # Process the JSON response
        # Extract the body content first to avoid processing HTTP code
        response_body="${response:0:-3}"
        
        # Check if the response body is valid JSON
        if echo "$response_body" | jq empty > /dev/null 2>&1; then
            echo "$response_body" | \
                jq -r '.[] | .name_value' 2>/dev/null | \
                sed 's/\*\.//g' | \
                sort -u > "$temp_output"
        else
            warn "crt.sh API returned invalid JSON for $USERIN"
            rm -f "$temp_output"
            return 1
        fi

        # Check if we got any results
        if [[ -s "$temp_output" ]]; then
            cat "$temp_output" >> "$SCAN_FOLDER/$CRTOUT"
            local found_count=$(wc -l < "$temp_output")
            info "Found $found_count certificates for $USERIN"
            
            # Log the first few results for verification
            if [[ $found_count -gt 0 && -n "${ENABLE_DEBUG:-}" ]]; then
                debug "Sample results (first 5):"
                head -n 5 "$temp_output" | while read -r domain; do
                    debug "  - $domain"
                done
            fi
        else
            warn "No certificates found for $USERIN"
        fi

        # Clean up
        rm -f "$temp_output"
    fi
}

# Process a file containing multiple domains
run_crtsh_with_file() {
    local FILEIN="$1"
    debug "run_crtsh_with_file($FILEIN)"
    
    # Validate input file
    if ! test -f "$FILEIN"; then
        error "Please enter a correct file, you entered an incorrect file:$FILEIN" 254
    fi

    local total_domains=$(wc -l < "$FILEIN")
    local processed=0
    local start_time=$(date +%s)

    # Process each domain
    while IFS= read -r line; do
        ((processed++))
        
        # Show progress
        if ((processed % 10 == 0)); then
            local current_time=$(date +%s)
            local elapsed=$((current_time - start_time))
            local percent=$((processed * 100 / total_domains))
            info "Progress: $processed/$total_domains ($percent%) - Elapsed time: ${elapsed}s"
        fi

        debug "run_crtsh_with_file->run_crtsh($line)"
        run_crtsh "$line"
        
        # Add a small delay between requests to be nice to the API
        sleep 1
    done < "$FILEIN"

    # Show final statistics
    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))
    info "Completed crt.sh scanning for $total_domains domains in ${total_time}s"
}
