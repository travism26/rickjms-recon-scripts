#!/bin/bash

# Import required modules
source "$(dirname "${BASH_SOURCE[0]}")/../../core/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../api/rate_limiting.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../core/utils.sh"

# Main Wayback scanning function
run_waybackurls() {
    local USERIN="$1"
    local WAYBACKOUT="wayback.out"
    debug "run_waybackurls($USERIN)"
    local temp_output
    local status
    local start_time=$(date +%s)

    if isDryRun; then
        echo "cat $USERIN | waybackurls >> $WAYBACKURL/$WAYBACKOUT"
    else
        info "Executing waybackurls on targets"
        rate_limit "wayback"

        # Create a temporary file for output
        temp_output=$(mktemp)
        
        if cat "$USERIN" | waybackurls > "$temp_output" 2>/dev/null; then
            # Check if we got any results
            if [[ -s "$temp_output" ]]; then
                # Process and deduplicate URLs
                sort -u "$temp_output" > "${temp_output}.sorted"
                
                # Filter out common noise and unwanted extensions
                grep -iEv '\.(png|jpg|jpeg|gif|css|js|woff|svg|ttf|eot)$' "${temp_output}.sorted" | \
                grep -iv '/static/' | \
                grep -iv '/assets/' | \
                grep -iv '/images/' > "${temp_output}.filtered"
                
                # Get statistics
                local total_urls=$(wc -l < "${temp_output}.sorted")
                local filtered_urls=$(wc -l < "${temp_output}.filtered")
                local excluded=$((total_urls - filtered_urls))
                
                # Save filtered results
                cat "${temp_output}.filtered" >> "$WAYBACKURL/$WAYBACKOUT"
                
                # Calculate interesting endpoints
                local interesting=$(grep -iE '(admin|api|dev|test|staging|beta|internal)' "${temp_output}.filtered" | wc -l)
                
                info "Successfully retrieved $filtered_urls URLs from Wayback"
                info "Excluded $excluded static/media files"
                info "Found $interesting potentially interesting endpoints"
                
                # Generate endpoint summary
                {
                    echo "=== Wayback URL Analysis ==="
                    echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
                    echo "Target: $USERIN"
                    echo "Total URLs: $total_urls"
                    echo "Filtered URLs: $filtered_urls"
                    echo "Excluded Files: $excluded"
                    echo "Interesting Endpoints: $interesting"
                    echo
                    echo "=== Top Paths ==="
                    cat "${temp_output}.filtered" | cut -d'/' -f4 | sort | uniq -c | sort -rn | head -n 10
                    echo
                    echo "=== Interesting Endpoints ==="
                    grep -iE '(admin|api|dev|test|staging|beta|internal)' "${temp_output}.filtered" | sort -u
                } > "$WAYBACKURL/${WAYBACKOUT%.out}_analysis.txt"
                
            else
                warn "No URLs found in Wayback for targets in $USERIN"
            fi
        else
            status=$?
            handle_api_error "waybackurls" "$status" "Failed to retrieve URLs"
            rm -f "$temp_output" "${temp_output}.sorted" "${temp_output}.filtered"
            return 1
        fi
        
        # Clean up
        rm -f "$temp_output" "${temp_output}.sorted" "${temp_output}.filtered"
        
        # Show execution time
        local end_time=$(date +%s)
        local total_time=$((end_time - start_time))
        debug "Wayback scan completed in ${total_time}s"
    fi
}

# Process a file containing multiple domains
run_waybackurls_with_file() {
    local FILEIN="$1"
    debug "run_waybackurls_with_file($FILEIN)"
    
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
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        local percent=$((processed * 100 / total_domains))
        info "Progress: $processed/$total_domains ($percent%) - Elapsed time: ${elapsed}s"

        debug "run_waybackurls_with_file->run_waybackurls($line)"
        if ! run_waybackurls "$line"; then
            ((errors++))
            warn "Failed to process $line"
        fi
        
        # Add a small delay between requests
        sleep 1
    done < "$FILEIN"

    # Show final statistics
    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))
    info "Completed Wayback scanning for $total_domains domains in ${total_time}s"
    if ((errors > 0)); then
        warn "$errors domains failed to process"
    fi
}

# Check if a domain has any Wayback data
check_wayback_availability() {
    local domain="$1"
    local response
    
    response=$(curl -s "http://web.archive.org/cdx/search/cdx?url=${domain}&output=json&limit=1")
    
    if [[ -n "$response" && "$response" != "[]" ]]; then
        return 0
    else
        return 1
    fi
}
