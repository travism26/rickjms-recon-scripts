#!/usr/bin/env bash

# Set the base directory for the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Import configuration and core modules
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/src/core/logging.sh"
source "$SCRIPT_DIR/src/core/validation.sh"
source "$SCRIPT_DIR/src/core/utils.sh"

# Import scanner modules
source "$SCRIPT_DIR/src/scanners/passive/crtsh.sh"
source "$SCRIPT_DIR/src/scanners/passive/tls_bufferover.sh"
source "$SCRIPT_DIR/src/scanners/passive/wayback.sh"
source "$SCRIPT_DIR/src/scanners/passive/google_dorks.sh"
source "$SCRIPT_DIR/src/scanners/passive/asn_enum.sh"
source "$SCRIPT_DIR/src/scanners/active/nmap.sh"
source "$SCRIPT_DIR/src/scanners/active/http_probe.sh"
source "$SCRIPT_DIR/src/scanners/active/crawler.sh"
source "$SCRIPT_DIR/src/scanners/active/dir_enum.sh"
source "$SCRIPT_DIR/src/scanners/active/param_discovery.sh"
source "$SCRIPT_DIR/src/scanners/active/vuln_scan.sh"

# Import reporting module
source "$SCRIPT_DIR/src/reporting/report_generator.sh"

# Consolidate targets from file or single target
consolidateTargets() {
    debug "consolidateTargets()"
    
    # Create temporary file for target list
    TARGET_LIST=$(mktemp)
    
    if filePassed; then
        debug "File passed, copying contents to target list"
        
        # Process each line in the input file
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Check if line is a wildcard pattern
            if [[ "$line" == *"*."* ]]; then
                debug "Wildcard pattern detected: $line"
                # Extract the base domain from wildcard pattern
                base_domain=$(echo "$line" | sed 's/^\*\.//')
                echo "$base_domain" >> "$TARGET_LIST"
                info "Converted wildcard pattern to base domain: $base_domain"
            else
                # Regular domain or IP, add as-is
                echo "$line" >> "$TARGET_LIST"
            fi
        done < "$USER_FILE"
    else
        debug "Single target passed, adding to target list"
        # Check if target is a wildcard pattern
        if [[ "$USER_TARGET" == *"*."* ]]; then
            debug "Wildcard pattern detected in target: $USER_TARGET"
            # Extract the base domain from wildcard pattern
            base_domain=$(echo "$USER_TARGET" | sed 's/^\*\.//')
            echo "$base_domain" >> "$TARGET_LIST"
            info "Converted wildcard pattern to base domain: $base_domain"
        else
            echo "$USER_TARGET" > "$TARGET_LIST"
        fi
    fi
    
    # Count total targets
    local total_targets=$(wc -l < "$TARGET_LIST")
    info "Total targets to scan: $total_targets"
}

# Main scanning function
run_scans() {
    local start_time=$(date +%s)
    info "Starting reconnaissance scans"
    
    # Passive Reconnaissance
    info "Starting passive reconnaissance"
    
    if ! isLightScan; then
        # Certificate Transparency
        run_crtsh "$TARGET_LIST"
        
        # TLS Bufferover
        run_tls_bufferover "$TARGET_LIST"
        
        # Wayback Machine
        if ! skipWaybackUrl; then
            run_waybackurls "$TARGET_LIST"
        fi
        
        # Google Dorking
        run_google_dorks "$TARGET_LIST"
        
        # ASN Enumeration
        run_asn_enum "$TARGET_LIST"
    else
        info "Light scan mode enabled - skipping intensive passive recon"
    fi
    
    # Active Reconnaissance
    info "Starting active reconnaissance"
    
    # HTTP Service Detection
    run_httpx "$TARGET_LIST"
    run_httprobe "$TARGET_LIST"
    
    # Port Scanning
    run_nmap "$TARGET_LIST"
    
    # Web Crawling and JavaScript Analysis
    if ! isLightScan; then
        run_hakrawler "$TARGET_LIST"
        # Disabled subdomainizer as it's not working
        # run_subdomainizer "$TARGET_LIST"
        
        # Directory Enumeration
        run_dir_enum "$TARGET_LIST"
        
        # Parameter Discovery
        run_param_discovery "$TARGET_LIST"
        
        # Vulnerability Scanning
        run_vuln_scan "$TARGET_LIST"
    fi
    
    # Generate Reports
    info "Generating reports"
    generate_report "$OUTPUT_DIR"
    
    # Generate additional reports
    if ! isLightScan; then
        generate_google_dork_report "$OUTPUT_DIR"
        generate_asn_report "$OUTPUT_DIR"
        generate_dir_enum_report "$OUTPUT_DIR"
        generate_param_discovery_report "$OUTPUT_DIR"
        generate_vuln_report "$OUTPUT_DIR"
    fi
    
    # Show execution time
    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))
    info "Reconnaissance completed in ${total_time}s"
}

# Main function
main() {
    # Set up trap for cleanup
    trap cleanup EXIT
    
    # Process command line arguments
    userInput "$@"
    
    # Initialize scan environment
    init
    
    # Validate required tools
    check_requirements
    
    # Run scans
    run_scans
    
    info "Reconnaissance completed successfully"
}

# Execute main function with all arguments
main "$@"
