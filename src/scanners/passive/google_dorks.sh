#!/bin/bash

# Import required modules
source "$(dirname "${BASH_SOURCE[0]}")/../../core/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../api/rate_limiting.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../core/utils.sh"

# Google dork patterns
GOOGLE_DORKS=(
    "site:{{TARGET}}"
    "site:{{TARGET}} ext:php"
    "site:{{TARGET}} inurl:admin"
    "site:{{TARGET}} intitle:admin"
    "site:{{TARGET}} ext:pdf inurl:confidential"
    "site:{{TARGET}} inurl:'/content/dam' ext:txt"
    "site:{{TARGET}} inurl:redirectUrl=http"
    "site:{{TARGET}} inurl:returnUrl"
    "site:{{TARGET}} inurl:redir"
    "site:{{TARGET}} inurl:url="
    "site:{{TARGET}} inurl:return="
    "site:{{TARGET}} inurl:next="
    "site:{{TARGET}} inurl:api"
    "site:{{TARGET}} ext:xml"
    "site:{{TARGET}} ext:json"
    "site:{{TARGET}} ext:sql"
    "site:{{TARGET}} ext:bak"
    "site:{{TARGET}} ext:log"
    "site:{{TARGET}} ext:conf"
    "site:{{TARGET}} ext:config"
)

# Main Google dorking function
run_google_dorks() {
    local USERIN="$1"
    debug "run_google_dorks($USERIN)"
    local DORKOUT="google_dorks.out"
    local temp_output
    local domain

    if isDryRun; then
        echo "Running Google dork searches for domains in $USERIN"
    else
        info "Starting Google dork searches for domains in $USERIN"
        
        # Create output directory if it doesn't exist
        mkdir -p "$SCAN_FOLDER/google_dorks"
        
        # Create temporary file for output
        temp_output=$(mktemp)
        
        # Process each domain
        while IFS= read -r domain; do
            info "Running Google dorks for: $domain"
            
            # Create domain-specific output file
            local domain_file="$SCAN_FOLDER/google_dorks/${domain}_dorks.txt"
            echo "# Google Dork Results for $domain" > "$domain_file"
            echo "# Generated on $(date)" >> "$domain_file"
            echo "" >> "$domain_file"
            
            # Process each dork pattern
            for dork in "${GOOGLE_DORKS[@]}"; do
                # Replace placeholder with actual domain
                local search_query="${dork//\{\{TARGET\}\}/$domain}"
                
                # Encode for URL
                local encoded_query=$(echo "$search_query" | sed 's/ /%20/g')
                
                echo "## Dork: $search_query" >> "$domain_file"
                echo "## Search URL: https://www.google.com/search?q=$encoded_query" >> "$domain_file"
                echo "" >> "$domain_file"
                
                # Note: We don't actually scrape Google results here as that would violate ToS
                # Instead, we provide the search URLs for manual investigation
                # No rate limiting needed since we're not making actual requests to Google
            done
            
            info "Completed Google dork generation for $domain"
            echo "$domain" >> "$temp_output"
        done < "$USERIN"
        
        # Combine all results
        cat "$temp_output" > "$SCAN_FOLDER/$DORKOUT"
        
        # Generate summary
        local total_domains=$(wc -l < "$temp_output")
        info "Generated Google dork queries for $total_domains domains"
        info "Results saved to $SCAN_FOLDER/google_dorks/"
        
        # Clean up
        rm -f "$temp_output"
    fi
}

# Generate a report of all Google dork findings
generate_google_dork_report() {
    local output_dir="$1"
    debug "generate_google_dork_report($output_dir)"
    
    if isDryRun; then
        echo "Generating Google dork report in $output_dir"
    else
        local report_file="$output_dir/google_dorks_report.md"
        
        {
            echo "# Google Dork Analysis Report"
            echo "Generated on: $(date)"
            echo ""
            echo "## Overview"
            echo ""
            echo "This report contains Google search queries that can be used to discover potentially"
            echo "sensitive information about the target domains. These queries should be manually"
            echo "executed in a browser to analyze the results."
            echo ""
            echo "## Search Queries by Domain"
            echo ""
            
            # List all domain files
            for domain_file in "$SCAN_FOLDER/google_dorks/"*_dorks.txt; do
                if [[ -f "$domain_file" ]]; then
                    domain=$(basename "$domain_file" | sed 's/_dorks.txt//')
                    echo "### Domain: $domain"
                    echo ""
                    
                    # Extract and list all search URLs
                    grep "^## Search URL:" "$domain_file" | sed 's/^## Search URL: /- /' | sort -u
                    
                    echo ""
                    echo "For detailed queries, see: $(basename "$domain_file")"
                    echo ""
                fi
            done
            
            echo "## Recommended Manual Analysis Steps"
            echo ""
            echo "1. Open each search URL in a browser"
            echo "2. Review the results for sensitive information"
            echo "3. Look for potential security issues such as:"
            echo "   - Exposed configuration files"
            echo "   - Sensitive documents"
            echo "   - Admin interfaces"
            echo "   - API endpoints"
            echo "   - Error messages revealing technical details"
            echo "4. Document any findings for further investigation"
            
        } > "$report_file"
        
        info "Google dork report generated: $report_file"
    fi
}
