#!/usr/bin/env bash

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")")" && pwd)"

# Import required modules
source "$SCRIPT_DIR/src/core/logging.sh"
source "$SCRIPT_DIR/src/core/utils.sh"
source "$SCRIPT_DIR/config/settings.sh"

# Run hakrawler for web crawling
run_hakrawler() {
    local USERIN="$1"
    local HAKOUT="hakrawler.out"
    local start_time
    local temp_output
    
    debug "run_hakrawler($USERIN)"
    
    if isDryRun; then
        echo "cat $USERIN | hakrawler -d 3 -h -u -s >> $CRAWLING/$HAKOUT"
    else
        info "Starting hakrawler on targets from: $USERIN"
        start_time=$(date +%s)
        
        # Create temporary file for output
        temp_output=$(mktemp)
        
        # Run hakrawler with enhanced features
        if cat "$USERIN" | hakrawler -d 3 -h -u -s > "$temp_output" 2>/dev/null; then
            if [[ -s "$temp_output" ]]; then
                # Process and deduplicate URLs
                sort -u "$temp_output" > "$CRAWLING/$HAKOUT"
                
                # Generate analysis
                {
                    echo "=== Hakrawler Analysis ==="
                    echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
                    echo
                    echo "=== URL Path Distribution ==="
                    cut -d'/' -f4- "$temp_output" | sort | uniq -c | sort -rn | head -n 20
                    echo
                    echo "=== Interesting Endpoints ==="
                    grep -i "admin\|api\|dev\|test\|stage\|beta\|internal\|auth\|login" "$temp_output" || echo "None found"
                    echo
                    echo "=== File Extensions ==="
                    grep -o '\.[^/?]*' "$temp_output" | sort | uniq -c | sort -rn
                } > "$CRAWLING/${HAKOUT%.out}_analysis.txt"
                
                local total_urls=$(wc -l < "$CRAWLING/$HAKOUT")
                local js_files=$(grep -c '\.js$' "$CRAWLING/$HAKOUT" || echo 0)
                local api_endpoints=$(grep -ci 'api' "$CRAWLING/$HAKOUT" || echo 0)
                
                info "Crawling completed successfully"
                info "Total URLs: $total_urls"
                info "JavaScript files: $js_files"
                info "Potential API endpoints: $api_endpoints"
            else
                warn "No URLs discovered during crawling"
            fi
        else
            error "hakrawler crawling failed" 1
            rm -f "$temp_output"
            return 1
        fi
        
        # Clean up
        rm -f "$temp_output"
        
        # Show execution time
        local end_time=$(date +%s)
        local total_time=$((end_time - start_time))
        debug "Crawling completed in ${total_time}s"
    fi
}

# Run SubDomainizer for JavaScript analysis
run_subdomainizer() {
    local USERIN="$1"
    local SUBDOMOUT="subdomainizer.out"
    local start_time
    local temp_output
    
    debug "run_subdomainizer($USERIN)"
    
    if isDryRun; then
        echo "python3 SubDomainizer.py -l $USERIN -o $JS_SCANNING/$SUBDOMOUT"
    else
        info "Starting SubDomainizer analysis on targets from: $USERIN"
        start_time=$(date +%s)
        
        # Create temporary file for output
        temp_output=$(mktemp)
        
        # Activate Python virtual environment if exists
        activate_python_venv
        
        # Run SubDomainizer
        if python3 -m SubDomainizer -l "$USERIN" -o "$temp_output" 2>/dev/null; then
            if [[ -s "$temp_output" ]]; then
                # Process results
                cat "$temp_output" > "$JS_SCANNING/$SUBDOMOUT"
                
                # Generate analysis
                {
                    echo "=== SubDomainizer Analysis ==="
                    echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
                    echo
                    echo "=== Discovered Endpoints ==="
                    grep -v '^#' "$temp_output" | sort -u
                    echo
                    echo "=== Potential Secrets ==="
                    grep -i "key\|token\|secret\|password\|credential" "$temp_output" || echo "None found"
                    echo
                    echo "=== Cloud Services ==="
                    grep -i "aws\|azure\|gcp\|cloudfront\|s3\|blob" "$temp_output" || echo "None found"
                } > "$JS_SCANNING/${SUBDOMOUT%.out}_analysis.txt"
                
                local total_findings=$(grep -v '^#' "$temp_output" | wc -l)
                local secrets=$(grep -ci "key\|token\|secret\|password\|credential" "$temp_output" || echo 0)
                local cloud_refs=$(grep -ci "aws\|azure\|gcp\|cloudfront\|s3\|blob" "$temp_output" || echo 0)
                
                info "JavaScript analysis completed successfully"
                info "Total findings: $total_findings"
                info "Potential secrets: $secrets"
                info "Cloud service references: $cloud_refs"
            else
                warn "No findings from JavaScript analysis"
            fi
        else
            error "SubDomainizer analysis failed" 1
            rm -f "$temp_output"
            return 1
        fi
        
        # Clean up
        rm -f "$temp_output"
        
        # Show execution time
        local end_time=$(date +%s)
        local total_time=$((end_time - start_time))
        debug "JavaScript analysis completed in ${total_time}s"
    fi
}

# Validate crawler tools installation
validate_crawler_tools() {
    local missing_tools=()
    
    # Check hakrawler
    if ! command -v hakrawler &>/dev/null; then
        missing_tools+=("hakrawler")
    fi
    
    # Check SubDomainizer
    if ! python3 -c "import SubDomainizer" 2>/dev/null; then
        missing_tools+=("SubDomainizer (Python package)")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        error "Missing required crawler tools: ${missing_tools[*]}" 1
        return 1
    fi
    
    return 0
}
