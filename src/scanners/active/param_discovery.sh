#!/bin/bash

# Import required modules
source "$(dirname "${BASH_SOURCE[0]}")/../../core/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../core/utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../api/rate_limiting.sh"

# Run parameter discovery using Arjun
run_param_discovery() {
    local USERIN="$1"
    debug "run_param_discovery($USERIN)"
    local PARAMOUT="param_discovery.out"
    local temp_output
    local url
    
    if isDryRun; then
        echo "Running parameter discovery for URLs in $USERIN"
    else
        info "Starting parameter discovery for URLs in $USERIN"
        
        # Create output directory if it doesn't exist
        mkdir -p "$POST_SCAN_ENUM/param_discovery"
        
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
            
            info "Running parameter discovery for: $url"
            
            # Create URL-specific output files
            local url_safe=$(echo "$url" | sed 's/[^a-zA-Z0-9]/_/g')
            local url_file="$POST_SCAN_ENUM/param_discovery/${url_safe}_params.json"
            local url_report="$POST_SCAN_ENUM/param_discovery/${url_safe}_report.md"
            
            # Run Arjun for GET parameters
            info "Discovering GET parameters for $url"
            if arjun -u "$url" -t 50 -oJ "$url_file.get" -m GET > /dev/null 2>&1; then
                info "GET parameter discovery completed for $url"
            else
                warn "GET parameter discovery failed for $url"
            fi
            
            # Run Arjun for POST parameters
            info "Discovering POST parameters for $url"
            if arjun -u "$url" -t 50 -oJ "$url_file.post" -m POST > /dev/null 2>&1; then
                info "POST parameter discovery completed for $url"
            else
                warn "POST parameter discovery failed for $url"
            fi
            
            # Combine results
            {
                echo "{"
                echo "  \"url\": \"$url\","
                echo "  \"get_parameters\": "
                if [[ -s "$url_file.get" ]]; then
                    jq '.parameters' "$url_file.get" || echo "[]"
                else
                    echo "[]"
                fi
                echo "  ,"
                echo "  \"post_parameters\": "
                if [[ -s "$url_file.post" ]]; then
                    jq '.parameters' "$url_file.post" || echo "[]"
                else
                    echo "[]"
                fi
                echo "}"
            } | jq '.' > "$url_file"
            
            # Clean up temporary files
            rm -f "$url_file.get" "$url_file.post"
            
            # Generate a human-readable report
            {
                echo "# Parameter Discovery Report for $url"
                echo "Generated on: $(date)"
                echo ""
                echo "## Overview"
                echo ""
                echo "This report contains the results of parameter discovery for $url."
                echo ""
                
                # Parse JSON output and create a summary
                if [[ -s "$url_file" ]]; then
                    echo "## GET Parameters"
                    echo ""
                    
                    local get_count=$(jq '.get_parameters | length' "$url_file")
                    if [[ $get_count -gt 0 ]]; then
                        echo "| Parameter | Notes |"
                        echo "|-----------|-------|"
                        jq -r '.get_parameters[] | "| \(.) | |"' "$url_file"
                    else
                        echo "No GET parameters discovered."
                    fi
                    
                    echo ""
                    echo "## POST Parameters"
                    echo ""
                    
                    local post_count=$(jq '.post_parameters | length' "$url_file")
                    if [[ $post_count -gt 0 ]]; then
                        echo "| Parameter | Notes |"
                        echo "|-----------|-------|"
                        jq -r '.post_parameters[] | "| \(.) | |"' "$url_file"
                    else
                        echo "No POST parameters discovered."
                    fi
                    
                    echo ""
                    echo "## Potentially Interesting Parameters"
                    echo ""
                    
                    # Highlight potentially interesting parameters
                    echo "### Security-Related Parameters"
                    jq -r '.get_parameters[], .post_parameters[] | select(. | test("token|key|auth|pass|secret|jwt|session|access|csrf|xsrf|permission|admin|role|priv")) | "- \(.)"' "$url_file" || echo "None found"
                    
                    echo ""
                    echo "### File Operations Parameters"
                    jq -r '.get_parameters[], .post_parameters[] | select(. | test("file|path|folder|directory|upload|download|doc|attachment|name|filename")) | "- \(.)"' "$url_file" || echo "None found"
                    
                    echo ""
                    echo "### Redirect Parameters"
                    jq -r '.get_parameters[], .post_parameters[] | select(. | test("url|link|redirect|return|next|target|goto|dest|destination|continue|proceed")) | "- \(.)"' "$url_file" || echo "None found"
                else
                    echo "No parameters discovered."
                fi
                
                echo ""
                echo "## Vulnerability Testing Ideas"
                echo ""
                echo "1. Test security-related parameters for authentication bypasses"
                echo "2. Test file operation parameters for path traversal and LFI/RFI"
                echo "3. Test redirect parameters for open redirects"
                echo "4. Test all parameters for XSS, CSRF, and injection vulnerabilities"
                echo "5. Test for parameter pollution by duplicating parameters"
                
            } > "$url_report"
            
            info "Parameter discovery report generated: $url_report"
            echo "$url" >> "$temp_output"
            
            # Apply rate limiting
            rate_limit "arjun"
        done
        
        # Combine all results
        if [[ -s "$temp_output" ]]; then
            cat "$temp_output" > "$POST_SCAN_ENUM/$PARAMOUT"
            local url_count=$(wc -l < "$temp_output")
            info "Completed parameter discovery for $url_count URLs"
        else
            warn "No successful parameter discovery results"
        fi
        
        # Clean up
        rm -f "$temp_output"
    fi
}

# Generate a consolidated report of all parameter discovery findings
generate_param_discovery_report() {
    local output_dir="$1"
    debug "generate_param_discovery_report($output_dir)"
    
    if isDryRun; then
        echo "Generating parameter discovery report in $output_dir"
    else
        local report_file="$output_dir/parameter_discovery_report.md"
        
        {
            echo "# Parameter Discovery Summary Report"
            echo "Generated on: $(date)"
            echo ""
            echo "## Overview"
            echo ""
            echo "This report summarizes the results of parameter discovery across all targets."
            echo ""
            
            # Count total parameters discovered
            local total_get_params=0
            local total_post_params=0
            local total_urls=0
            
            if [[ -d "$POST_SCAN_ENUM/param_discovery" ]]; then
                total_urls=$(ls "$POST_SCAN_ENUM/param_discovery/"*_params.json 2>/dev/null | wc -l)
                
                for json_file in "$POST_SCAN_ENUM/param_discovery/"*_params.json; do
                    if [[ -f "$json_file" ]]; then
                        local get_params=$(jq '.get_parameters | length' "$json_file" 2>/dev/null || echo 0)
                        local post_params=$(jq '.post_parameters | length' "$json_file" 2>/dev/null || echo 0)
                        total_get_params=$((total_get_params + get_params))
                        total_post_params=$((total_post_params + post_params))
                    fi
                done
            fi
            
            echo "- URLs scanned: $total_urls"
            echo "- Total GET parameters discovered: $total_get_params"
            echo "- Total POST parameters discovered: $total_post_params"
            echo "- Total parameters: $((total_get_params + total_post_params))"
            echo ""
            
            # List top interesting parameters across all targets
            echo "## Top Interesting Parameters"
            echo ""
            
            if [[ -d "$POST_SCAN_ENUM/param_discovery" ]]; then
                echo "### Security-Related Parameters"
                echo ""
                for json_file in "$POST_SCAN_ENUM/param_discovery/"*_params.json; do
                    if [[ -f "$json_file" ]]; then
                        local url=$(jq -r '.url' "$json_file" 2>/dev/null)
                        jq -r '.get_parameters[], .post_parameters[] | select(. | test("token|key|auth|pass|secret|jwt|session|access|csrf|xsrf|permission|admin|role|priv"))' "$json_file" 2>/dev/null | sort -u | head -n 5 | sed "s|^|- $url: |" || true
                    fi
                done
                
                echo ""
                echo "### File Operations Parameters"
                echo ""
                for json_file in "$POST_SCAN_ENUM/param_discovery/"*_params.json; do
                    if [[ -f "$json_file" ]]; then
                        local url=$(jq -r '.url' "$json_file" 2>/dev/null)
                        jq -r '.get_parameters[], .post_parameters[] | select(. | test("file|path|folder|directory|upload|download|doc|attachment|name|filename"))' "$json_file" 2>/dev/null | sort -u | head -n 5 | sed "s|^|- $url: |" || true
                    fi
                done
                
                echo ""
                echo "### Redirect Parameters"
                echo ""
                for json_file in "$POST_SCAN_ENUM/param_discovery/"*_params.json; do
                    if [[ -f "$json_file" ]]; then
                        local url=$(jq -r '.url' "$json_file" 2>/dev/null)
                        jq -r '.get_parameters[], .post_parameters[] | select(. | test("url|link|redirect|return|next|target|goto|dest|destination|continue|proceed"))' "$json_file" 2>/dev/null | sort -u | head -n 5 | sed "s|^|- $url: |" || true
                    fi
                done
            else
                echo "No parameter discovery results available."
            fi
            
            echo ""
            echo "## Individual Target Reports"
            echo ""
            
            if [[ -d "$POST_SCAN_ENUM/param_discovery" ]]; then
                for report_file in "$POST_SCAN_ENUM/param_discovery/"*_report.md; do
                    if [[ -f "$report_file" ]]; then
                        local url_safe=$(basename "$report_file" | sed 's/_report\.md$//')
                        echo "- [${url_safe}]($(basename "$report_file"))"
                    fi
                done
            else
                echo "No individual reports available."
            fi
            
            echo ""
            echo "## Vulnerability Testing Recommendations"
            echo ""
            echo "1. Test security-related parameters for:"
            echo "   - Authentication bypasses"
            echo "   - Privilege escalation"
            echo "   - Information disclosure"
            echo ""
            echo "2. Test file operation parameters for:"
            echo "   - Path traversal"
            echo "   - Local/Remote file inclusion"
            echo "   - Arbitrary file uploads"
            echo ""
            echo "3. Test redirect parameters for:"
            echo "   - Open redirects"
            echo "   - SSRF vulnerabilities"
            echo ""
            echo "4. General testing for all parameters:"
            echo "   - XSS (Cross-Site Scripting)"
            echo "   - CSRF (Cross-Site Request Forgery)"
            echo "   - SQL Injection"
            echo "   - Command Injection"
            echo "   - Parameter pollution"
            
        } > "$report_file"
        
        info "Parameter discovery summary report generated: $report_file"
    fi
}
