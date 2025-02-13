#!/bin/bash

# Import configuration and core modules
source "$(dirname "${BASH_SOURCE[0]}")/config/settings.sh"
source "$(dirname "${BASH_SOURCE[0]}")/src/core/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/src/core/validation.sh"
source "$(dirname "${BASH_SOURCE[0]}")/src/core/utils.sh"

# Import scanner modules
source "$(dirname "${BASH_SOURCE[0]}")/src/scanners/passive/crtsh.sh"
source "$(dirname "${BASH_SOURCE[0]}")/src/scanners/passive/tls_bufferover.sh"
source "$(dirname "${BASH_SOURCE[0]}")/src/scanners/passive/wayback.sh"
source "$(dirname "${BASH_SOURCE[0]}")/src/scanners/active/nmap.sh"
source "$(dirname "${BASH_SOURCE[0]}")/src/scanners/active/http_probe.sh"
source "$(dirname "${BASH_SOURCE[0]}")/src/scanners/active/crawler.sh"

# Import reporting module
source "$(dirname "${BASH_SOURCE[0]}")/src/reporting/report_generator.sh"

# Consolidate targets from file or single target
consolidateTargets() {
    debug "consolidateTargets()"
    
    # Create temporary file for target list
    TARGET_LIST=$(mktemp)
    
    if filePassed; then
        debug "File passed, copying contents to target list"
        cat "$USER_FILE" > "$TARGET_LIST"
    else
        debug "Single target passed, adding to target list"
        echo "$USER_TARGET" > "$TARGET_LIST"
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
        run_subdomainizer "$TARGET_LIST"
    fi
    
    # Generate Report
    generate_report "$OUTPUT_DIR"
    
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
