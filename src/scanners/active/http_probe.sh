#!/usr/bin/env bash

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")")" && pwd)"

# Import required modules
source "$SCRIPT_DIR/src/core/logging.sh"
source "$SCRIPT_DIR/src/core/utils.sh"
source "$SCRIPT_DIR/config/settings.sh"

# Run httpx probe
run_httpx() {
    local USERIN="$1"
    local HTTPXOUT="httpx.out"
    local start_time
    local temp_output
    
    debug "run_httpx($USERIN)"
    
    if isDryRun; then
        echo "cat $USERIN | httpx -silent -title -tech-detect -status-code -follow-redirects -o $ALIVE/$HTTPXOUT"
    else
        info "Starting httpx probe on targets from: $USERIN"
        start_time=$(date +%s)
        
        # Create temporary file for output
        temp_output=$(mktemp)
        
        # Run httpx with enhanced features
        if cat "$USERIN" | httpx -silent -title -tech-detect -status-code -follow-redirects \
            -threads 50 -rate-limit 150 -timeout 10 \
            -no-color 2>/dev/null > "$temp_output"; then
            
            # Process and analyze results
            if [[ -s "$temp_output" ]]; then
                # Save raw output
                cat "$temp_output" > "$ALIVE/$HTTPXOUT"
                
                # Generate analysis
                {
                    echo "=== HTTP Probe Analysis ==="
                    echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
                    echo
                    echo "=== Response Code Distribution ==="
                    awk '{print $2}' "$temp_output" | sort | uniq -c | sort -rn
                    echo
                    echo "=== Technology Stack Summary ==="
                    grep -o '\[.*\]' "$temp_output" | tr ',' '\n' | sed 's/[][]//g' | sort | uniq -c | sort -rn
                    echo
                    echo "=== Interesting Endpoints ==="
                    grep -i "admin\|login\|portal\|api\|dev\|test\|stage" "$temp_output" || echo "None found"
                } > "$ALIVE/${HTTPXOUT%.out}_analysis.txt"
                
                local total_urls=$(wc -l < "$temp_output")
                local http_200=$(grep -c " 200 " "$temp_output" || echo 0)
                local redirects=$(grep -cE " 30[1-8] " "$temp_output" || echo 0)
                
                info "HTTP probe completed successfully"
                info "Total URLs: $total_urls"
                info "200 OK: $http_200"
                info "Redirects: $redirects"
            else
                warn "No live URLs found"
            fi
        else
            error "httpx probe failed" 1
            rm -f "$temp_output"
            return 1
        fi
        
        # Clean up
        rm -f "$temp_output"
        
        # Show execution time
        local end_time=$(date +%s)
        local total_time=$((end_time - start_time))
        debug "HTTP probe completed in ${total_time}s"
    fi
}

# Run httprobe
run_httprobe() {
    local USERIN="$1"
    local HTTPROBEOUT="httprobe.out"
    local start_time
    local temp_output
    
    debug "run_httprobe($USERIN)"
    
    if isDryRun; then
        echo "cat $USERIN | httprobe -c $HTTPROBE_CONCURRENT >> $ALIVE/$HTTPROBEOUT"
    else
        info "Starting httprobe on targets from: $USERIN"
        start_time=$(date +%s)
        
        # Create temporary file for output
        temp_output=$(mktemp)
        
        # Run httprobe with concurrent connections
        if cat "$USERIN" | httprobe -c "$HTTPROBE_CONCURRENT" > "$temp_output" 2>/dev/null; then
            if [[ -s "$temp_output" ]]; then
                # Process results
                sort -u "$temp_output" > "$ALIVE/$HTTPROBEOUT"
                
                local total_urls=$(wc -l < "$ALIVE/$HTTPROBEOUT")
                local https_count=$(grep -c "^https://" "$ALIVE/$HTTPROBEOUT" || echo 0)
                local http_count=$(grep -c "^http://" "$ALIVE/$HTTPROBEOUT" || echo 0)
                
                # Generate analysis
                {
                    echo "=== HTTProbe Analysis ==="
                    echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
                    echo "Total URLs: $total_urls"
                    echo "HTTPS URLs: $https_count"
                    echo "HTTP URLs: $http_count"
                    echo
                    echo "=== Protocol Distribution ==="
                    echo "HTTPS: $https_count ($(( https_count * 100 / total_urls ))%)"
                    echo "HTTP: $http_count ($(( http_count * 100 / total_urls ))%)"
                } > "$ALIVE/${HTTPROBEOUT%.out}_analysis.txt"
                
                info "HTTProbe completed successfully"
                info "Found $total_urls live URLs ($https_count HTTPS, $http_count HTTP)"
            else
                warn "No live URLs found"
            fi
        else
            error "httprobe failed" 1
            rm -f "$temp_output"
            return 1
        fi
        
        # Clean up
        rm -f "$temp_output"
        
        # Show execution time
        local end_time=$(date +%s)
        local total_time=$((end_time - start_time))
        debug "HTTProbe completed in ${total_time}s"
    fi
}

# Validate HTTP tools installation
validate_http_tools() {
    local missing_tools=()
    
    # Check httpx
    if ! command -v httpx &>/dev/null; then
        missing_tools+=("httpx")
    fi
    
    # Check httprobe
    if ! command -v httprobe &>/dev/null; then
        missing_tools+=("httprobe")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        error "Missing required HTTP tools: ${missing_tools[*]}" 1
        return 1
    fi
    
    return 0
}
