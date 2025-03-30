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
        if [[ -f "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" ]] && [[ -s "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" ]]; then
            echo "#### Vulnerability Scanning"
            
            # Count vulnerabilities by severity using jq if available
            local total_critical=0
            local total_high=0
            local total_medium=0
            local total_low=0
            local total_info=0
            
            if command -v jq &>/dev/null; then
                # Use jq for proper JSON parsing
                total_critical=$(jq -r '[.[] | select(.severity=="critical")] | length' "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" 2>/dev/null || echo 0)
                total_high=$(jq -r '[.[] | select(.severity=="high")] | length' "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" 2>/dev/null || echo 0)
                total_medium=$(jq -r '[.[] | select(.severity=="medium")] | length' "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" 2>/dev/null || echo 0)
                total_low=$(jq -r '[.[] | select(.severity=="low")] | length' "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" 2>/dev/null || echo 0)
                total_info=$(jq -r '[.[] | select(.severity=="info")] | length' "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" 2>/dev/null || echo 0)
            else
                # Fallback to grep with safer error handling
                total_critical=$(grep -c '"severity":"critical"' "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" 2>/dev/null || echo 0)
                total_high=$(grep -c '"severity":"high"' "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" 2>/dev/null || echo 0)
                total_medium=$(grep -c '"severity":"medium"' "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" 2>/dev/null || echo 0)
                total_low=$(grep -c '"severity":"low"' "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" 2>/dev/null || echo 0)
                total_info=$(grep -c '"severity":"info"' "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" 2>/dev/null || echo 0)
            fi
            
            # Ensure all variables are integers
            total_critical=${total_critical:-0}
            total_high=${total_high:-0}
            total_medium=${total_medium:-0}
            total_low=${total_low:-0}
            total_info=${total_info:-0}
            
            # Calculate total with proper arithmetic
            local total_vulns=0
            total_vulns=$((total_critical + total_high + total_medium + total_low + total_info))
            
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
        if [[ -f "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" ]] && [[ -s "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" ]]; then
            echo
            echo "#### Critical and High Vulnerabilities"
            echo
            
            # Extract critical vulnerabilities with safer approach
            local critical_vulns=""
            if command -v jq &>/dev/null; then
                critical_vulns=$(jq -r '.[] | select(.severity=="critical") | "| " + .name + " | " + .["matched-at"] + " | " + .["template-id"] + " |"' "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" 2>/dev/null | head -n 5)
            else
                critical_vulns=$(grep -A 20 '"severity":"critical"' "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" 2>/dev/null | grep -E '"name"|"matched-at"|"template-id"' | paste -d '|' - - - 2>/dev/null | sed 's/"name"://g; s/"matched-at"://g; s/"template-id"://g; s/"//g; s/,//g; s/|/ | /g; s|^|| |; s|$| |' 2>/dev/null | head -n 5)
            fi
            
            if [[ -n "$critical_vulns" ]]; then
                echo "##### Critical Vulnerabilities"
                echo "| Vulnerability | URL | Template ID |"
                echo "|---------------|-----|------------|"
                echo "$critical_vulns"
                echo
            fi
            
            # Extract high vulnerabilities with safer approach
            local high_vulns=""
            if command -v jq &>/dev/null; then
                high_vulns=$(jq -r '.[] | select(.severity=="high") | "| " + .name + " | " + .["matched-at"] + " | " + .["template-id"] + " |"' "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" 2>/dev/null | head -n 5)
            else
                high_vulns=$(grep -A 20 '"severity":"high"' "$POST_SCAN_ENUM/vuln_scan/all_vulnerabilities.json" 2>/dev/null | grep -E '"name"|"matched-at"|"template-id"' | paste -d '|' - - - 2>/dev/null | sed 's/"name"://g; s/"matched-at"://g; s/"template-id"://g; s/"//g; s/,//g; s/|/ | /g; s|^|| |; s|$| |' 2>/dev/null | head -n 5)
            fi
            
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
        
        # Recommended Follow-up Scans
        echo
        echo "### Recommended Follow-up Scans"
        echo
        echo "Based on the initial reconnaissance findings, the following targeted scans are recommended for deeper investigation:"
        echo
        
        # WAF Bypass Scanning
        echo "#### WAF Bypass Scanning"
        echo
        if grep -q "WAF\|Cloudflare\|blocking\|rate limit" "$ALIVE/httpx_analysis.txt" 2>/dev/null || grep -q "WAF\|Cloudflare\|blocking\|rate limit" "$CRAWLING/hakrawler_analysis.txt" 2>/dev/null; then
            echo "**WAF detected - Use these rate-limited approaches:**"
            echo
            echo "\`\`\`bash"
            echo "# Amass with custom settings for WAF bypass"
            echo "amass enum -d $TARGET_DOMAIN -active -max-dns-queries 50 -dns-qps 5 -timeout 10"
            echo
            echo "# Nuclei with rate limiting and custom user agents"
            echo "nuclei -l alive_subdomains.txt -H \"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36\" -rl 10 -timeout 10"
            echo "\`\`\`"
        else
            echo "**No WAF detected - Standard scanning approaches should work:**"
            echo
            echo "\`\`\`bash"
            echo "# Amass with active enumeration"
            echo "amass enum -d $TARGET_DOMAIN -active"
            echo "\`\`\`"
        fi
        echo
        
        # Pattern-Based Subdomain Discovery
        echo "#### Pattern-Based Subdomain Discovery"
        echo
        echo "Based on discovered naming patterns, create a custom wordlist for targeted brute forcing:"
        echo
        echo "\`\`\`bash"
        echo "# Extract naming patterns from discovered subdomains"
        echo "cat subdomains.txt | cut -d. -f1 > naming_patterns.txt"
        echo
        echo "# Use for targeted brute forcing"
        echo "amass enum -d $TARGET_DOMAIN -brute -w custom_wordlist.txt"
        echo "ffuf -w custom_wordlist.txt -u https://FUZZ.$TARGET_DOMAIN"
        echo "\`\`\`"
        echo
        echo "**Suggested wordlist patterns based on discovered subdomains:**"
        echo
        
        # Extract subdomain patterns if crt.sh results exist
        if [[ -f "$SCAN_FOLDER/crtsh.host.out" ]]; then
            echo "- Product/service names: $(cat "$SCAN_FOLDER/crtsh.host.out" | cut -d. -f1 | grep -v -E '^[0-9]+$' | sort -u | head -n 5 | tr '\n' ', ' | sed 's/,$//')"
            echo "- Environment prefixes: dev, staging, test, uat, qa, sandbox"
            echo "- Common services: api, admin, portal, login, dashboard, console"
        else
            echo "- Environment prefixes: dev, staging, test, uat, qa, sandbox"
            echo "- Common services: api, admin, portal, login, dashboard, console"
            echo "- Product variations: mobile, app, web, internal, partner"
        fi
        echo
        
        # Targeted Service Scanning
        echo "#### Targeted Service Scanning"
        echo
        echo "Focus on specific services and potential vulnerabilities:"
        echo
        echo "\`\`\`bash"
        echo "# For discovered admin interfaces"
        echo "nuclei -l admin_interfaces.txt -t admin-panels/ -t exposed-panels/ -severity critical,high"
        echo
        echo "# For API endpoints"
        echo "nuclei -l api_endpoints.txt -t api/ -severity critical,high"
        echo
        echo "# For specific technologies detected"
        # Extract detected technologies from httpx analysis
        if [[ -f "$ALIVE/httpx_analysis.txt" ]]; then
            # Look for common web technologies in the httpx output
            for tech in $(grep -o -E "WordPress|Drupal|Joomla|Laravel|Django|Rails|Node\.js|Express|React|Angular|Vue|PHP|ASP\.NET|Java|Tomcat|Nginx|Apache|IIS|Cloudflare|WAF" "$ALIVE/httpx_analysis.txt" 2>/dev/null | sort -u); do
                # Convert to lowercase for nuclei template path
                tech_lower=$(echo "$tech" | tr '[:upper:]' '[:lower:]' | sed 's/\.//g')
                echo "nuclei -l alive_subdomains.txt -t technologies/$tech_lower/ -t exposures/configs/"
            done
        else
            echo "# Run technology detection first:"
            echo "nuclei -l alive_subdomains.txt -t technologies/ -severity info"
        fi
        echo "\`\`\`"
        echo
        
        # Manual Investigation Tools
        echo "#### Manual Investigation Tools"
        echo
        if grep -q "blocking\|WAF\|protection" "$CRAWLING/hakrawler_analysis.txt" 2>/dev/null; then
            echo "**Automated crawling appears to be blocked. Try these manual approaches:**"
            echo
            echo "\`\`\`bash"
            echo "# Stealthy directory enumeration"
            echo "gobuster dir -u https://TARGET -w wordlist.txt -a \"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36\" --delay 5s"
            echo
            echo "# Manual tools:"
            echo "# - Burp Suite with browser integration"
            echo "# - Browser DevTools for network analysis"
            echo "# - OWASP ZAP for passive scanning"
            echo "\`\`\`"
        else
            echo "\`\`\`bash"
            echo "# Standard content discovery"
            echo "ffuf -w wordlist.txt -u https://TARGET/FUZZ"
            echo "dirsearch -u https://TARGET -w wordlist.txt"
            echo "\`\`\`"
        fi
        echo
        
        # Historical Data Analysis
        echo "#### Historical Data Analysis"
        echo
        echo "When live crawling is limited, historical data can reveal valuable endpoints:"
        echo
        echo "\`\`\`bash"
        echo "# Gather URLs from various sources"
        echo "gau --subs $TARGET_DOMAIN | grep -E \"dev|staging|test|admin|internal\""
        echo "waybackurls $TARGET_DOMAIN | grep -E \"api|graphql|v1|v2\""
        echo
        echo "# Find potentially sensitive files"
        echo "gau --subs $TARGET_DOMAIN | grep -E \"\\.json|\\.xml|\\.yaml|\\.txt|\\.sql|\\.bak|\\.config\""
        echo "\`\`\`"
        echo
        
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
