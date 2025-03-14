#!/bin/bash

# Import required modules
source "$(dirname "${BASH_SOURCE[0]}")/../core/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../core/utils.sh"

# Generate final report
generate_report() {
    local OUTPUT_DIR="$1"
    local REPORT_FILE="$OUTPUT_DIR/recon_report_$(date +%Y%m%d_%H%M%S).md"
    local start_time=$(date +%s)
    
    info "Generating comprehensive reconnaissance report"
    
    {
        echo "# Reconnaissance Report"
        echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo
        echo "## Summary"
        echo
        
        # Passive Reconnaissance Results
        echo "### Passive Reconnaissance"
        echo
        
        # Certificate Transparency Results
        if [[ -f "$SCAN_FOLDER/crtsh.host.out" ]]; then
            echo "#### Certificate Transparency (crt.sh)"
            echo "- Total certificates found: $(wc -l < "$SCAN_FOLDER/crtsh.host.out")"
            echo
            echo "\`\`\`"
            head -n 10 "$SCAN_FOLDER/crtsh.host.out"
            echo "..."
            echo "\`\`\`"
            echo
        fi
        
        # TLS Bufferover Results
        if [[ -f "$SCAN_FOLDER/tls_bufferover.out" ]]; then
            echo "#### TLS Bufferover"
            echo "- Total records found: $(wc -l < "$SCAN_FOLDER/tls_bufferover.out")"
            echo
            echo "\`\`\`"
            head -n 10 "$SCAN_FOLDER/tls_bufferover.out"
            echo "..."
            echo "\`\`\`"
            echo
        fi
        
        # Wayback Machine Results
        if [[ -f "$WAYBACKURL/wayback.out" ]]; then
            echo "#### Wayback Machine"
            echo "- Total URLs archived: $(wc -l < "$WAYBACKURL/wayback.out")"
            if [[ -f "$WAYBACKURL/wayback_analysis.txt" ]]; then
                echo
                echo "Analysis:"
                echo "\`\`\`"
                cat "$WAYBACKURL/wayback_analysis.txt"
                echo "\`\`\`"
            fi
            echo
        fi
        
        # Google Dorking Results
        if [[ -f "$SCAN_FOLDER/google_dorks.out" ]]; then
            echo "#### Google Dorking"
            echo "- Total domains analyzed: $(wc -l < "$SCAN_FOLDER/google_dorks.out")"
            echo
            echo "For detailed Google dork queries, see the Google Dork Analysis Report."
            echo
        fi
        
        # ASN Enumeration Results
        if [[ -f "$SCAN_FOLDER/asn_enum.out" ]]; then
            echo "#### ASN Enumeration"
            echo "- Total domains analyzed: $(wc -l < "$SCAN_FOLDER/asn_enum.out")"
            
            # Count unique CIDRs
            local cidr_count=0
            if [[ -f "$SCAN_FOLDER/asn_intel/unique_cidrs.txt" ]]; then
                cidr_count=$(wc -l < "$SCAN_FOLDER/asn_intel/unique_cidrs.txt")
                echo "- Unique CIDRs discovered: $cidr_count"
            fi
            
            echo
            echo "For detailed ASN information, see the ASN Enumeration Report."
            echo
        fi
        
        # Active Reconnaissance Results
        echo "### Active Reconnaissance"
        echo
        
        # Nmap Results
        if [[ -f "$POST_SCAN_ENUM/nmap_analysis.txt" ]]; then
            echo "#### Port Scanning (Nmap)"
            echo
            echo "\`\`\`"
            cat "$POST_SCAN_ENUM/nmap_analysis.txt"
            echo "\`\`\`"
            echo
        fi
        
        # HTTP Probe Results
        if [[ -f "$ALIVE/httpx_analysis.txt" ]]; then
            echo "#### HTTP Service Detection"
            echo
            echo "HTTPx Analysis:"
            echo "\`\`\`"
            cat "$ALIVE/httpx_analysis.txt"
            echo "\`\`\`"
            echo
        fi
        
        if [[ -f "$ALIVE/httprobe_analysis.txt" ]]; then
            echo "HTTProbe Analysis:"
            echo "\`\`\`"
            cat "$ALIVE/httprobe_analysis.txt"
            echo "\`\`\`"
            echo
        fi
        
        # Crawler Results
        if [[ -f "$CRAWLING/hakrawler_analysis.txt" ]]; then
            echo "#### Web Crawling Results"
            echo
            echo "Hakrawler Analysis:"
            echo "\`\`\`"
            cat "$CRAWLING/hakrawler_analysis.txt"
            echo "\`\`\`"
            echo
        fi
        
        # JavaScript Analysis
        if [[ -f "$JS_SCANNING/subdomainizer_analysis.txt" ]]; then
            echo "#### JavaScript Analysis"
            echo
            echo "SubDomainizer Findings:"
            echo "\`\`\`"
            cat "$JS_SCANNING/subdomainizer_analysis.txt"
            echo "\`\`\`"
            echo
        fi
        
        # Directory Enumeration Results
        if [[ -f "$POST_SCAN_ENUM/dir_enum.out" ]]; then
            echo "#### Directory Enumeration"
            echo "- Total URLs analyzed: $(wc -l < "$POST_SCAN_ENUM/dir_enum.out")"
            echo
            echo "For detailed directory enumeration results, see the Directory Enumeration Report."
            echo
        fi
        
        # Parameter Discovery Results
        if [[ -f "$POST_SCAN_ENUM/param_discovery.out" ]]; then
            echo "#### Parameter Discovery"
            echo "- Total URLs analyzed: $(wc -l < "$POST_SCAN_ENUM/param_discovery.out")"
            echo
            echo "For detailed parameter discovery results, see the Parameter Discovery Report."
            echo
        fi
        
        # Vulnerability Scanning Results
        if [[ -f "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" ]]; then
            echo "#### Vulnerability Scanning"
            
            # Count vulnerabilities by severity
            local total_critical=$(grep -c '"severity":"critical"' "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" || echo 0)
            local total_high=$(grep -c '"severity":"high"' "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" || echo 0)
            local total_medium=$(grep -c '"severity":"medium"' "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" || echo 0)
            local total_low=$(grep -c '"severity":"low"' "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" || echo 0)
            local total_info=$(grep -c '"severity":"info"' "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" || echo 0)
            local total_vulns=$((total_critical + total_high + total_medium + total_low + total_info))
            
            echo "- Total potential vulnerabilities: $total_vulns"
            echo "- Critical: $total_critical"
            echo "- High: $total_high"
            echo "- Medium: $total_medium"
            echo "- Low: $total_low"
            echo "- Informational: $total_info"
            echo
            echo "For detailed vulnerability findings, see the Vulnerability Scan Report."
            echo
        fi
        
        # Interesting Findings
        echo "### Notable Findings"
        echo
        
        # Potential Security Issues
        echo "#### Security Concerns"
        {
            # Check for exposed admin interfaces
            echo "##### Exposed Administrative Interfaces"
            find "$OUTPUT_DIR" -type f -exec grep -l -i "admin\|dashboard\|console" {} \;
            
            # Check for potential API endpoints
            echo
            echo "##### API Endpoints"
            find "$OUTPUT_DIR" -type f -exec grep -l -i "api\|graphql\|rest" {} \;
            
            # Check for development/staging environments
            echo
            echo "##### Development/Staging Environments"
            find "$OUTPUT_DIR" -type f -exec grep -l -i "dev\|test\|stage\|uat" {} \;
            
            # Check for potential secrets
            echo
            echo "##### Potential Secrets/Sensitive Information"
            find "$OUTPUT_DIR" -type f -exec grep -l -i "key\|secret\|password\|token\|credential" {} \;
        } | sort -u | while read -r file; do
            if [[ -f "$file" ]]; then
                echo "- Found in: ${file#$OUTPUT_DIR/}"
            fi
        done
        
        # Critical Vulnerabilities
        if [[ -f "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" ]]; then
            echo
            echo "#### Critical and High Vulnerabilities"
            echo
            
            # Extract critical vulnerabilities
            local critical_vulns=$(grep -A 20 '"severity":"critical"' "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" | grep -E '"name"|"matched-at"|"template-id"' | paste -d '|' - - - | sed 's/"name"://g; s/"matched-at"://g; s/"template-id"://g; s/"//g; s/,//g; s/|/ | /g; s/^/| /; s/$/ |/' | head -n 5)
            
            if [[ -n "$critical_vulns" ]]; then
                echo "##### Critical Vulnerabilities"
                echo "| Vulnerability | URL | Template ID |"
                echo "|---------------|-----|------------|"
                echo "$critical_vulns"
                echo
            fi
            
            # Extract high vulnerabilities
            local high_vulns=$(grep -A 20 '"severity":"high"' "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" | grep -E '"name"|"matched-at"|"template-id"' | paste -d '|' - - - | sed 's/"name"://g; s/"matched-at"://g; s/"template-id"://g; s/"//g; s/,//g; s/|/ | /g; s/^/| /; s/$/ |/' | head -n 5)
            
            if [[ -n "$high_vulns" ]]; then
                echo "##### High Vulnerabilities"
                echo "| Vulnerability | URL | Template ID |"
                echo "|---------------|-----|------------|"
                echo "$high_vulns"
                echo
            fi
            
            echo "For complete vulnerability details, see the Vulnerability Scan Report."
        fi
        
        # Interesting Parameters
        if [[ -d "$POST_SCAN_ENUM/param_discovery" ]]; then
            echo
            echo "#### Interesting Parameters"
            echo
            
            # Security-related parameters
            echo "##### Security-Related Parameters"
            find "$POST_SCAN_ENUM/param_discovery" -name "*_params.json" -exec jq -r '.get_parameters[], .post_parameters[] | select(. | test("token|key|auth|pass|secret|jwt|session|access|csrf|xsrf|permission|admin|role|priv"))' {} \; 2>/dev/null | sort -u | head -n 10 | while read -r param; do
                echo "- $param"
            done
            
            echo
            echo "##### File Operation Parameters"
            find "$POST_SCAN_ENUM/param_discovery" -name "*_params.json" -exec jq -r '.get_parameters[], .post_parameters[] | select(. | test("file|path|folder|directory|upload|download|doc|attachment|name|filename"))' {} \; 2>/dev/null | sort -u | head -n 10 | while read -r param; do
                echo "- $param"
            done
            
            echo
            echo "##### Redirect Parameters"
            find "$POST_SCAN_ENUM/param_discovery" -name "*_params.json" -exec jq -r '.get_parameters[], .post_parameters[] | select(. | test("url|link|redirect|return|next|target|goto|dest|destination|continue|proceed"))' {} \; 2>/dev/null | sort -u | head -n 10 | while read -r param; do
                echo "- $param"
            done
            
            echo
            echo "For complete parameter details, see the Parameter Discovery Report."
        fi
        
        # Interesting Directories
        if [[ -d "$POST_SCAN_ENUM/dir_enum" ]]; then
            echo
            echo "#### Interesting Directories"
            echo
            
            # Admin interfaces
            echo "##### Admin/Management Interfaces"
            find "$POST_SCAN_ENUM/dir_enum" -name "*_dirs.json" -exec jq -r '.results[] | select(.url | test("admin|manager|console|dashboard|cp|portal|login")) | "- [\(.status)] \(.url)"' {} \; 2>/dev/null | sort -u | head -n 10
            
            echo
            echo "##### API Endpoints"
            find "$POST_SCAN_ENUM/dir_enum" -name "*_dirs.json" -exec jq -r '.results[] | select(.url | test("api|graphql|v1|v2|rest|soap|swagger|openapi")) | "- [\(.status)] \(.url)"' {} \; 2>/dev/null | sort -u | head -n 10
            
            echo
            echo "##### Potentially Sensitive Files"
            find "$POST_SCAN_ENUM/dir_enum" -name "*_dirs.json" -exec jq -r '.results[] | select(.url | test("\\.log|\\.bak|\\.conf|\\.config|\\.sql|\\.xml|\\.json|\\.env|\\.git")) | "- [\(.status)] \(.url)"' {} \; 2>/dev/null | sort -u | head -n 10
            
            echo
            echo "For complete directory enumeration details, see the Directory Enumeration Report."
        fi
        
        # Statistics
        echo
        echo "### Scan Statistics"
        echo "- Scan completed: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "- Total scan duration: $(($(date +%s) - start_time)) seconds"
        echo "- Output directory: $OUTPUT_DIR"
        
    } > "$REPORT_FILE"
    
    info "Report generated: $REPORT_FILE"
    
    # Generate HTML version if pandoc is available
    if command -v pandoc &>/dev/null; then
        local HTML_REPORT="${REPORT_FILE%.md}.html"
        if pandoc -f markdown -t html "$REPORT_FILE" -o "$HTML_REPORT" --self-contained --metadata title="Reconnaissance Report"; then
            info "HTML report generated: $HTML_REPORT"
        else
            warn "Failed to generate HTML report"
        fi
    fi
}

# Validate reporting dependencies
validate_reporting_tools() {
    local missing_tools=()
    
    # Check for pandoc (optional)
    if ! command -v pandoc &>/dev/null; then
        warn "pandoc not found - HTML report generation will be skipped"
    fi
    
    return 0
}
