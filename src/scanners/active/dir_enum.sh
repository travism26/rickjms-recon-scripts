#!/bin/bash

# Import required modules
source "$(dirname "${BASH_SOURCE[0]}")/../../core/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../core/utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../api/rate_limiting.sh"

# Run directory enumeration using ffuf
run_dir_enum() {
    local USERIN="$1"
    debug "run_dir_enum($USERIN)"
    local DIROUT="dir_enum.out"
    local temp_output
    local url
    
    if isDryRun; then
        echo "Running directory enumeration for URLs in $USERIN"
    else
        info "Starting directory enumeration for URLs in $USERIN"
        
        # Create output directory if it doesn't exist
        mkdir -p "$POST_SCAN_ENUM/dir_enum"
        
        # Create temporary file for output
        temp_output=$(mktemp)
        
        # Get list of live URLs from httpx output
        if [[ ! -f "$ALIVE/httpx.out" ]]; then
            warn "No live URLs found. Run http_probe first."
            return 1
        fi
        
        # Process each URL
        cat "$ALIVE/httpx.out" | while IFS= read -r url; do
            # Skip empty lines
            if [[ -z "$url" ]]; then
                continue
            fi
            
            info "Running directory enumeration for: $url"
            
            # Create URL-specific output files
            local url_safe=$(echo "$url" | sed 's/[^a-zA-Z0-9]/_/g')
            local url_file="$POST_SCAN_ENUM/dir_enum/${url_safe}_dirs.json"
            local url_report="$POST_SCAN_ENUM/dir_enum/${url_safe}_report.md"
            
            # Determine wordlist based on technology
            local wordlist="/usr/share/wordlists/dirb/common.txt"  # Default wordlist
            
            # Check if SecLists is available and use more comprehensive lists
            if [[ -d "/usr/share/seclists" ]]; then
                wordlist="/usr/share/seclists/Discovery/Web-Content/common.txt"
                
                # Use technology-specific wordlists if available
                if echo "$url" | grep -q "\.php"; then
                    wordlist="/usr/share/seclists/Discovery/Web-Content/PHP.fuzz.txt"
                elif echo "$url" | grep -q "\.asp"; then
                    wordlist="/usr/share/seclists/Discovery/Web-Content/ASP.fuzz.txt"
                elif echo "$url" | grep -q "\.jsp"; then
                    wordlist="/usr/share/seclists/Discovery/Web-Content/JSP.fuzz.txt"
                fi
            fi
            
            info "Using wordlist: $wordlist"
            
            # Run ffuf with appropriate settings
            if ffuf -u "${url}/FUZZ" -w "$wordlist" -mc 200,204,301,302,307,401,403,405 -o "$url_file" -of json -t 50 -s > /dev/null 2>&1; then
                info "Directory enumeration completed for $url"
                
                # Generate a human-readable report
                {
                    echo "# Directory Enumeration Report for $url"
                    echo "Generated on: $(date)"
                    echo ""
                    echo "## Overview"
                    echo ""
                    echo "This report contains the results of directory enumeration for $url."
                    echo "Wordlist used: $wordlist"
                    echo ""
                    
                    # Parse JSON output and create a summary
                    if [[ -s "$url_file" ]]; then
                        echo "## Discovered Endpoints"
                        echo ""
                        echo "| Path | Status Code | Content Length | Content Type |"
                        echo "|------|------------|----------------|--------------|"
                        
                        # Extract and format results
                        jq -r '.results[] | "| \(.url | sub(".*FUZZ"; "")) | \(.status) | \(.length) | \(.content_type // "N/A") |"' "$url_file" | sort
                        
                        echo ""
                        echo "## Status Code Distribution"
                        echo ""
                        
                        # Count status codes
                        jq -r '.results[].status' "$url_file" | sort | uniq -c | sort -nr | while read -r count code; do
                            echo "- Status $code: $count endpoints"
                        done
                        
                        echo ""
                        echo "## Interesting Findings"
                        echo ""
                        
                        # Highlight potentially interesting endpoints
                        echo "### Admin/Management Interfaces"
                        jq -r '.results[] | select(.url | test("admin|manager|console|dashboard|cp|portal|login")) | "- [\(.status)] \(.url | sub(".*FUZZ"; ""))"' "$url_file" || echo "None found"
                        
                        echo ""
                        echo "### API Endpoints"
                        jq -r '.results[] | select(.url | test("api|graphql|v1|v2|rest|soap|swagger|openapi")) | "- [\(.status)] \(.url | sub(".*FUZZ"; ""))"' "$url_file" || echo "None found"
                        
                        echo ""
                        echo "### Potentially Sensitive Files"
                        jq -r '.results[] | select(.url | test("\\.log|\\.bak|\\.conf|\\.config|\\.sql|\\.xml|\\.json|\\.env|\\.git")) | "- [\(.status)] \(.url | sub(".*FUZZ"; ""))"' "$url_file" || echo "None found"
                    else
                        echo "No results found."
                    fi
                    
                    echo ""
                    echo "## Next Steps"
                    echo ""
                    echo "1. Manually inspect interesting endpoints"
                    echo "2. Test discovered endpoints for vulnerabilities"
                    echo "3. Use more comprehensive wordlists for deeper enumeration"
                    echo "4. Check for parameter vulnerabilities on discovered endpoints"
                    
                } > "$url_report"
                
                info "Directory enumeration report generated: $url_report"
                echo "$url" >> "$temp_output"
            else
                warn "Directory enumeration failed for $url"
            fi
            
            # Apply rate limiting
            rate_limit "ffuf"
        done
        
        # Combine all results
        if [[ -s "$temp_output" ]]; then
            cat "$temp_output" > "$POST_SCAN_ENUM/$DIROUT"
            local url_count=$(wc -l < "$temp_output")
            info "Completed directory enumeration for $url_count URLs"
        else
            warn "No successful directory enumeration results"
        fi
        
        # Clean up
        rm -f "$temp_output"
    fi
}

# Generate a consolidated report of all directory enumeration findings
generate_dir_enum_report() {
    local output_dir="$1"
    debug "generate_dir_enum_report($output_dir)"
    
    if isDryRun; then
        echo "Generating directory enumeration report in $output_dir"
    else
        local report_file="$output_dir/directory_enumeration_report.md"
        
        {
            echo "# Directory Enumeration Summary Report"
            echo "Generated on: $(date)"
            echo ""
            echo "## Overview"
            echo ""
            echo "This report summarizes the results of directory enumeration across all targets."
            echo ""
            
            # Count total endpoints discovered
            local total_endpoints=0
            local total_urls=0
            
            if [[ -d "$POST_SCAN_ENUM/dir_enum" ]]; then
                total_urls=$(ls "$POST_SCAN_ENUM/dir_enum/"*_dirs.json 2>/dev/null | wc -l)
                
                for json_file in "$POST_SCAN_ENUM/dir_enum/"*_dirs.json; do
                    if [[ -f "$json_file" ]]; then
                        local endpoints=$(jq '.results | length' "$json_file" 2>/dev/null || echo 0)
                        total_endpoints=$((total_endpoints + endpoints))
                    fi
                done
            fi
            
            echo "- URLs scanned: $total_urls"
            echo "- Total endpoints discovered: $total_endpoints"
            echo ""
            
            # List top interesting findings across all targets
            echo "## Top Interesting Findings"
            echo ""
            
            if [[ -d "$POST_SCAN_ENUM/dir_enum" ]]; then
                echo "### Admin/Management Interfaces"
                echo ""
                for json_file in "$POST_SCAN_ENUM/dir_enum/"*_dirs.json; do
                    if [[ -f "$json_file" ]]; then
                        local url_safe=$(basename "$json_file" | sed 's/_dirs\.json$//')
                        jq -r '.results[] | select(.url | test("admin|manager|console|dashboard|cp|portal|login")) | "- [\(.status)] \(.url)"' "$json_file" 2>/dev/null | head -n 5 | sed "s|^|- $url_safe: |" || true
                    fi
                done
                
                echo ""
                echo "### API Endpoints"
                echo ""
                for json_file in "$POST_SCAN_ENUM/dir_enum/"*_dirs.json; do
                    if [[ -f "$json_file" ]]; then
                        local url_safe=$(basename "$json_file" | sed 's/_dirs\.json$//')
                        jq -r '.results[] | select(.url | test("api|graphql|v1|v2|rest|soap|swagger|openapi")) | "- [\(.status)] \(.url)"' "$json_file" 2>/dev/null | head -n 5 | sed "s|^|- $url_safe: |" || true
                    fi
                done
                
                echo ""
                echo "### Potentially Sensitive Files"
                echo ""
                for json_file in "$POST_SCAN_ENUM/dir_enum/"*_dirs.json; do
                    if [[ -f "$json_file" ]]; then
                        local url_safe=$(basename "$json_file" | sed 's/_dirs\.json$//')
                        jq -r '.results[] | select(.url | test("\\.log|\\.bak|\\.conf|\\.config|\\.sql|\\.xml|\\.json|\\.env|\\.git")) | "- [\(.status)] \(.url)"' "$json_file" 2>/dev/null | head -n 5 | sed "s|^|- $url_safe: |" || true
                    fi
                done
            else
                echo "No directory enumeration results available."
            fi
            
            echo ""
            echo "## Individual Target Reports"
            echo ""
            
            if [[ -d "$POST_SCAN_ENUM/dir_enum" ]]; then
                for report_file in "$POST_SCAN_ENUM/dir_enum/"*_report.md; do
                    if [[ -f "$report_file" ]]; then
                        local url_safe=$(basename "$report_file" | sed 's/_report\.md$//')
                        echo "- [${url_safe}]($(basename "$report_file"))"
                    fi
                done
            else
                echo "No individual reports available."
            fi
            
            echo ""
            echo "## Recommendations"
            echo ""
            echo "1. Manually inspect interesting endpoints identified in this report"
            echo "2. Test discovered endpoints for vulnerabilities"
            echo "3. Focus on admin interfaces and API endpoints for deeper testing"
            echo "4. Check for parameter vulnerabilities on discovered endpoints"
            echo "5. Review potentially sensitive files for information disclosure"
            
        } > "$report_file"
        
        info "Directory enumeration summary report generated: $report_file"
    fi
}
