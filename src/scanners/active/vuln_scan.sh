#!/bin/bash

# Import required modules
source "$(dirname "${BASH_SOURCE[0]}")/../../core/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../core/utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../api/rate_limiting.sh"

# Run vulnerability scanning using nuclei
run_vuln_scan() {
    local USERIN="$1"
    debug "run_vuln_scan($USERIN)"
    local VULNOUT="vuln_scan.out"
    local temp_output
    local url
    
    if isDryRun; then
        echo "Running vulnerability scanning for URLs in $USERIN"
    else
        info "Starting vulnerability scanning for URLs in $USERIN"
        
        # Create output directory if it doesn't exist
        mkdir -p "$POST_SCAN_ENUM/vuln_scan"
        
        # Create temporary file for output
        temp_output=$(mktemp)
        
        # Get list of live URLs from httpx output
        if [[ ! -f "$ALIVE/httpx.out" ]]; then
            warn "No live URLs found. Run http_probe first."
            return 1
        fi
        
        # Create a list of URLs to scan
        cat "$ALIVE/httpx.out" > "$temp_output"
        local url_count=$(wc -l < "$temp_output")
        
        info "Scanning $url_count URLs for vulnerabilities"
        
        # Define vulnerability categories to scan
        local vuln_categories=(
            "cves"
            "vulnerabilities"
            "misconfigurations"
            "exposures"
            "technologies"
        )
        
        # Run nuclei for each category
        for category in "${vuln_categories[@]}"; do
            info "Scanning for $category"
            
            local category_file="$POST_SCAN_ENUM/vuln_scan/${category}.json"
            
            if nuclei -l "$temp_output" -t "$category/" -o "$category_file" -j -silent -c 50 > /dev/null 2>&1; then
                if [[ -s "$category_file" ]]; then
                    local findings=$(wc -l < "$category_file")
                    info "Found $findings potential $category"
                else
                    info "No $category found"
                fi
            else
                warn "Nuclei scan for $category failed"
            fi
            
            # Apply rate limiting
            rate_limit "nuclei"
        done
        
        # Run additional targeted scans for specific vulnerability types
        info "Running targeted vulnerability scans"
        
        # XSS scan
        info "Scanning for XSS vulnerabilities"
        if nuclei -l "$temp_output" -t "vulnerabilities/xss/" -o "$POST_SCAN_ENUM/vuln_scan/xss.json" -j -silent -c 50 > /dev/null 2>&1; then
            if [[ -s "$POST_SCAN_ENUM/vuln_scan/xss.json" ]]; then
                local xss_count=$(wc -l < "$POST_SCAN_ENUM/vuln_scan/xss.json")
                info "Found $xss_count potential XSS vulnerabilities"
            else
                info "No XSS vulnerabilities found"
            fi
        fi
        
        # SQL Injection scan
        info "Scanning for SQL Injection vulnerabilities"
        if nuclei -l "$temp_output" -t "vulnerabilities/sql-injection/" -o "$POST_SCAN_ENUM/vuln_scan/sqli.json" -j -silent -c 50 > /dev/null 2>&1; then
            if [[ -s "$POST_SCAN_ENUM/vuln_scan/sqli.json" ]]; then
                local sqli_count=$(wc -l < "$POST_SCAN_ENUM/vuln_scan/sqli.json")
                info "Found $sqli_count potential SQL Injection vulnerabilities"
            else
                info "No SQL Injection vulnerabilities found"
            fi
        fi
        
        # SSRF scan
        info "Scanning for SSRF vulnerabilities"
        if nuclei -l "$temp_output" -t "vulnerabilities/ssrf/" -o "$POST_SCAN_ENUM/vuln_scan/ssrf.json" -j -silent -c 50 > /dev/null 2>&1; then
            if [[ -s "$POST_SCAN_ENUM/vuln_scan/ssrf.json" ]]; then
                local ssrf_count=$(wc -l < "$POST_SCAN_ENUM/vuln_scan/ssrf.json")
                info "Found $ssrf_count potential SSRF vulnerabilities"
            else
                info "No SSRF vulnerabilities found"
            fi
        fi
        
        # Open Redirect scan
        info "Scanning for Open Redirect vulnerabilities"
        if nuclei -l "$temp_output" -t "vulnerabilities/open-redirect/" -o "$POST_SCAN_ENUM/vuln_scan/open-redirect.json" -j -silent -c 50 > /dev/null 2>&1; then
            if [[ -s "$POST_SCAN_ENUM/vuln_scan/open-redirect.json" ]]; then
                local redirect_count=$(wc -l < "$POST_SCAN_ENUM/vuln_scan/open-redirect.json")
                info "Found $redirect_count potential Open Redirect vulnerabilities"
            else
                info "No Open Redirect vulnerabilities found"
            fi
        fi
        
        # Combine all results into a single file
        find "$POST_SCAN_ENUM/vuln_scan/" -name "*.json" -exec cat {} \; > "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json"
        
        # Clean up
        rm -f "$temp_output"
        
        info "Vulnerability scanning completed"
    fi
}

# Generate a report of all vulnerability findings
generate_vuln_report() {
    local output_dir="$1"
    debug "generate_vuln_report($output_dir)"
    
    if isDryRun; then
        echo "Generating vulnerability report in $output_dir"
    else
        local report_file="$output_dir/vulnerability_report.md"
        
        {
            echo "# Vulnerability Scan Report"
            echo "Generated on: $(date)"
            echo ""
            echo "## Overview"
            echo ""
            echo "This report contains the results of automated vulnerability scanning across all targets."
            echo "Note that these are potential vulnerabilities that require manual verification."
            echo ""
            
            # Count total vulnerabilities by severity
            local total_critical=0
            local total_high=0
            local total_medium=0
            local total_low=0
            local total_info=0
            
            if [[ -f "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" ]]; then
                total_critical=$(grep -c '"severity":"critical"' "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" || echo 0)
                total_high=$(grep -c '"severity":"high"' "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" || echo 0)
                total_medium=$(grep -c '"severity":"medium"' "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" || echo 0)
                total_low=$(grep -c '"severity":"low"' "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" || echo 0)
                total_info=$(grep -c '"severity":"info"' "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" || echo 0)
            fi
            
            local total_vulns=$((total_critical + total_high + total_medium + total_low + total_info))
            
            echo "## Summary"
            echo ""
            echo "- Total vulnerabilities found: $total_vulns"
            echo "- Critical: $total_critical"
            echo "- High: $total_high"
            echo "- Medium: $total_medium"
            echo "- Low: $total_low"
            echo "- Informational: $total_info"
            echo ""
            
            # List critical vulnerabilities
            echo "## Critical Vulnerabilities"
            echo ""
            
            if [[ $total_critical -gt 0 ]]; then
                echo "| Vulnerability | URL | Template ID |"
                echo "|---------------|-----|------------|"
                
                grep -A 20 '"severity":"critical"' "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" | grep -E '"name"|"matched-at"|"template-id"' | paste -d '|' - - - | sed 's/"name"://g; s/"matched-at"://g; s/"template-id"://g; s/"//g; s/,//g; s/|/ | /g; s/^/| /; s/$/ |/' | head -n 10
                
                if [[ $total_critical -gt 10 ]]; then
                    echo "... and $((total_critical - 10)) more critical vulnerabilities"
                fi
            else
                echo "No critical vulnerabilities found."
            fi
            
            echo ""
            
            # List high vulnerabilities
            echo "## High Vulnerabilities"
            echo ""
            
            if [[ $total_high -gt 0 ]]; then
                echo "| Vulnerability | URL | Template ID |"
                echo "|---------------|-----|------------|"
                
                grep -A 20 '"severity":"high"' "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" | grep -E '"name"|"matched-at"|"template-id"' | paste -d '|' - - - | sed 's/"name"://g; s/"matched-at"://g; s/"template-id"://g; s/"//g; s/,//g; s/|/ | /g; s/^/| /; s/$/ |/' | head -n 10
                
                if [[ $total_high -gt 10 ]]; then
                    echo "... and $((total_high - 10)) more high vulnerabilities"
                fi
            else
                echo "No high vulnerabilities found."
            fi
            
            echo ""
            
            # List medium vulnerabilities
            echo "## Medium Vulnerabilities"
            echo ""
            
            if [[ $total_medium -gt 0 ]]; then
                echo "| Vulnerability | URL | Template ID |"
                echo "|---------------|-----|------------|"
                
                grep -A 20 '"severity":"medium"' "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" | grep -E '"name"|"matched-at"|"template-id"' | paste -d '|' - - - | sed 's/"name"://g; s/"matched-at"://g; s/"template-id"://g; s/"//g; s/,//g; s/|/ | /g; s/^/| /; s/$/ |/' | head -n 10
                
                if [[ $total_medium -gt 10 ]]; then
                    echo "... and $((total_medium - 10)) more medium vulnerabilities"
                fi
            else
                echo "No medium vulnerabilities found."
            fi
            
            echo ""
            
            # List vulnerability types
            echo "## Vulnerability Types"
            echo ""
            
            if [[ -f "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" ]]; then
                echo "| Type | Count |"
                echo "|------|-------|"
                
                grep '"name":' "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" | sed 's/"name"://g; s/"//g; s/,//g' | sort | uniq -c | sort -nr | head -n 20 | awk '{print "| " $2 " | " $1 " |"}'
            else
                echo "No vulnerability data available."
            fi
            
            echo ""
            echo "## Next Steps"
            echo ""
            echo "1. Manually verify each vulnerability to confirm it is exploitable"
            echo "2. Prioritize remediation based on severity and exploitability"
            echo "3. Develop a remediation plan for confirmed vulnerabilities"
            echo "4. Conduct more targeted testing for high-risk areas"
            echo "5. Implement security controls to mitigate identified risks"
            
        } > "$report_file"
        
        info "Vulnerability report generated: $report_file"
    fi
}
