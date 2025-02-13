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
