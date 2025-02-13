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

    if isDryRun; then
        echo "curl -s https://crt.sh/?Identity=%.$USERIN | grep \"\>\*.$USERIN\" | \
sed 's/<[/]*[TB][DR]>/\n/g' | grep -vE \"<|^[\*]*[\.]*$USERIN\" | sort -u | awk 'NF' >> $SCAN_FOLDER/$CRTOUT"
    else
        info "Executing search crt.sh/?...$USERIN"
        rate_limit "crtsh"
        
        # Create temporary file for output
        temp_output=$(mktemp)
        
        # Make the API call
        response=$(curl -s -w "%{http_code}" "https://crt.sh/?Identity=%.$USERIN")
        status=$?

        if [[ $status -ne 0 ]]; then
            handle_api_error "crt.sh" "$status" "$response"
            rm -f "$temp_output"
            return 1
        fi

        http_code=${response: -3}
        if [[ $http_code -ne 200 ]]; then
            warn "crt.sh API returned HTTP $http_code for $USERIN"
            rm -f "$temp_output"
            return 1
        fi

        # Process the response
        echo "${response:0:-3}" | \
            grep ">*.$USERIN" | \
            sed 's/<[/]*[TB][DR]>/\n/g' | \
            grep -vE "<|^[\*]*[\.]*$USERIN" | \
            sort -u | \
            awk 'NF' > "$temp_output"

        # Check if we got any results
        if [[ -s "$temp_output" ]]; then
            cat "$temp_output" >> "$SCAN_FOLDER/$CRTOUT"
            local found_count=$(wc -l < "$temp_output")
            info "Found $found_count certificates for $USERIN"
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
