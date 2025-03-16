#!/bin/bash

# Import required modules
source "$(dirname "${BASH_SOURCE[0]}")/../../core/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../api/rate_limiting.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../core/utils.sh"

# Function to retry curl commands with exponential backoff
retry_curl() {
    local cmd="$1"
    local max_retries="${2:-3}"  # Default to 3 retries
    local retry_delay="${3:-5}"  # Default to 5 seconds delay
    local attempt=1
    local response=""
    local status=0
    
    while [ $attempt -le $max_retries ]; do
        debug "crt.sh API attempt $attempt of $max_retries"
        response=$(eval "$cmd")
        status=$?
        
        # Check if curl command was successful
        if [ $status -eq 0 ]; then
            # Check if response has enough content
            if [ ${#response} -gt 3 ]; then
                debug "Response length: ${#response}"
                # Extract HTTP code from the end of the response
                http_code=${response: -3}
                
                # Verify that http_code is a valid number
                if [[ "$http_code" =~ ^[0-9]+$ ]] && [ "$http_code" -eq 200 ]; then
                    # Success - return the response
                    echo "$response"
                    return 0
                else
                    debug "Invalid HTTP code: $http_code"
                fi
            else
                debug "Response too short (${#response} chars): $response"
            fi
        else
            debug "Curl command failed with status: $status"
        fi
        
        # If we get here, the request failed
        if [ $attempt -lt $max_retries ]; then
            warn "crt.sh API attempt $attempt failed. Retrying in $retry_delay seconds..."
            sleep $retry_delay
            # Increase delay for next attempt (exponential backoff)
            retry_delay=$((retry_delay * 2))
        else
            # Last attempt failed
            error "crt.sh API failed after $max_retries attempts"
        fi
        
        ((attempt++))
    done
    
    # If we get here, all retries failed
    echo "$response"  # Return the last response
    return 1
}

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
        
        # Make the API call with retries
        response=$(retry_curl "$curl_command")
        status=$?

        if [[ $status -ne 0 ]]; then
            handle_api_error "crt.sh" "$status" "$response"
            rm -f "$temp_output"
            return 1
        fi
        
        # Check if response has enough characters before extracting HTTP code
        if [[ ${#response} -lt 3 ]]; then
            warn "crt.sh API returned an empty or invalid response for $USERIN (length: ${#response})"
            rm -f "$temp_output"
            return 1
        fi
        
        # Safely extract the HTTP code from the end of the response
        # First check if the response is long enough
        debug "Response length before extracting HTTP code: ${#response}"
        
        # Get the last 3 characters safely
        if [[ ${#response} -ge 3 ]]; then
            http_code=${response: -3}
            debug "Extracted HTTP code: $http_code"
        else
            warn "Response too short to extract HTTP code: $response"
            rm -f "$temp_output"
            return 1
        fi
        
        # Verify that http_code is a valid number and equals 200
        if ! [[ "$http_code" =~ ^[0-9]+$ ]] || [[ "$http_code" -ne 200 ]]; then
            warn "crt.sh API returned invalid or non-200 HTTP code for $USERIN: $http_code"
            rm -f "$temp_output"
            return 1
        fi

        # Process the JSON response
        # Extract the body content first to avoid processing HTTP code
        # Use parameter expansion to remove the last 3 characters
        response_length=${#response}
        if [[ $response_length -gt 3 ]]; then
            # Use a different approach to extract the body that works in all bash versions
            response_body=$(echo "$response" | head -c $(($response_length - 3)))
            debug "Response body length: ${#response_body}"
        else
            warn "Response too short to extract body: $response"
            rm -f "$temp_output"
            return 1
        fi
        
        # Check if the response body is valid JSON
        if echo "$response_body" | jq empty > /dev/null 2>&1; then
            echo "$response_body" | \
                jq -r '.[] | .name_value' 2>/dev/null | \
                sed 's/\*\.//g' | \
                sort -u > "$temp_output"
        else
            # Try to handle HTML responses (common when crt.sh is overloaded)
            warn "crt.sh API returned invalid JSON for $USERIN, attempting to retry with different approach"
            
            # Save the first 100 chars of response for debugging
            debug "First 100 chars of response: $(echo "$response_body" | head -c 100)"
            
            # Try a different approach - direct curl without JSON output
            info "Retrying with direct HTML parsing approach"
            
            # Try with a longer timeout and different user agent
            curl -s --max-time 60 -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" "https://crt.sh/?q=%.$USERIN" | \
                grep -oE ">[a-zA-Z0-9._-]+\.${USERIN}<" | \
                sed 's/>//g' | \
                sed 's/<//g' | \
                sort -u > "$temp_output"
                
            # If that fails too, try a third approach
            if [[ ! -s "$temp_output" ]]; then
                warn "Alternative approach also failed for $USERIN, trying last resort method"
                
                # Last resort: try a simpler approach with a different pattern
                # This is less accurate but more likely to work when the site is having issues
                curl -s --max-time 60 -A "Mozilla/5.0" "https://crt.sh/?q=$USERIN" | \
                    grep -o '[a-zA-Z0-9\._-]*\.\'"$USERIN" | \
                    sort -u > "$temp_output"
                
                if [[ ! -s "$temp_output" ]]; then
                    warn "All approaches failed for $USERIN"
                    rm -f "$temp_output"
                    return 1
                fi
                
                info "Last resort approach succeeded for $USERIN"
            else
                info "Alternative approach succeeded for $USERIN"
            fi
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
