#!/usr/bin/env bash

# Set the base directory for the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Import configuration and core modules
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/src/core/logging.sh"
source "$SCRIPT_DIR/src/core/validation.sh"
source "$SCRIPT_DIR/src/core/utils.sh"
source "$SCRIPT_DIR/src/core/state_manager.sh"

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
    
    # Initialize processed targets counter if not set
    PROCESSED_TARGETS=${PROCESSED_TARGETS:-0}
    
    # Passive Reconnaissance
    info "Starting passive reconnaissance"
    
    if ! isLightScan; then
        # Certificate Transparency
        if ! check_completed "crtsh"; then
            export CURRENT_SCAN="crtsh"
            save_progress "$OUTPUT_DIR" "$CURRENT_SCAN" "$PROCESSED_TARGETS"
            run_crtsh_with_file "$TARGET_LIST"
            mark_completed "$OUTPUT_DIR" "crtsh"
        else
            info "Skipping crtsh scan (already completed)"
        fi
        
        # TLS Bufferover
        if ! check_completed "tls_bufferover"; then
            export CURRENT_SCAN="tls_bufferover"
            save_progress "$OUTPUT_DIR" "$CURRENT_SCAN" "$PROCESSED_TARGETS"
            run_tls_bufferover "$TARGET_LIST"
            mark_completed "$OUTPUT_DIR" "tls_bufferover"
        else
            info "Skipping tls_bufferover scan (already completed)"
        fi
        
        # Wayback Machine
        if ! skipWaybackUrl; then
            if ! check_completed "waybackurls"; then
                export CURRENT_SCAN="waybackurls"
                save_progress "$OUTPUT_DIR" "$CURRENT_SCAN" "$PROCESSED_TARGETS"
                run_waybackurls "$TARGET_LIST"
                mark_completed "$OUTPUT_DIR" "waybackurls"
            else
                info "Skipping waybackurls scan (already completed)"
            fi
        fi
        
        # Google Dorking
        if ! check_completed "google_dorks"; then
            export CURRENT_SCAN="google_dorks"
            save_progress "$OUTPUT_DIR" "$CURRENT_SCAN" "$PROCESSED_TARGETS"
            run_google_dorks "$TARGET_LIST"
            mark_completed "$OUTPUT_DIR" "google_dorks"
        else
            info "Skipping google_dorks scan (already completed)"
        fi
        
        # ASN Enumeration
        if ! check_completed "asn_enum"; then
            export CURRENT_SCAN="asn_enum"
            save_progress "$OUTPUT_DIR" "$CURRENT_SCAN" "$PROCESSED_TARGETS"
            run_asn_enum "$TARGET_LIST"
            mark_completed "$OUTPUT_DIR" "asn_enum"
        else
            info "Skipping asn_enum scan (already completed)"
        fi
    else
        info "Light scan mode enabled - skipping intensive passive recon"
    fi
    
    # Active Reconnaissance
    info "Starting active reconnaissance"
    
    # HTTP Service Detection
    if ! check_completed "httpx"; then
        export CURRENT_SCAN="httpx"
        save_progress "$OUTPUT_DIR" "$CURRENT_SCAN" "$PROCESSED_TARGETS"
        run_httpx "$TARGET_LIST"
        mark_completed "$OUTPUT_DIR" "httpx"
    else
        info "Skipping httpx scan (already completed)"
    fi
    
    if ! check_completed "httprobe"; then
        export CURRENT_SCAN="httprobe"
        save_progress "$OUTPUT_DIR" "$CURRENT_SCAN" "$PROCESSED_TARGETS"
        run_httprobe "$TARGET_LIST"
        mark_completed "$OUTPUT_DIR" "httprobe"
    else
        info "Skipping httprobe scan (already completed)"
    fi
    
    # Port Scanning
    if ! check_completed "nmap"; then
        export CURRENT_SCAN="nmap"
        save_progress "$OUTPUT_DIR" "$CURRENT_SCAN" "$PROCESSED_TARGETS"
        run_nmap "$TARGET_LIST"
        mark_completed "$OUTPUT_DIR" "nmap"
    else
        info "Skipping nmap scan (already completed)"
    fi
    
    # Web Crawling and JavaScript Analysis
    if ! isLightScan; then
        if ! check_completed "hakrawler"; then
            export CURRENT_SCAN="hakrawler"
            save_progress "$OUTPUT_DIR" "$CURRENT_SCAN" "$PROCESSED_TARGETS"
            run_hakrawler "$TARGET_LIST"
            mark_completed "$OUTPUT_DIR" "hakrawler"
        else
            info "Skipping hakrawler scan (already completed)"
        fi
        # Disabled subdomainizer as it's not working
        # run_subdomainizer "$TARGET_LIST"
        
        # Directory Enumeration
        if ! check_completed "dir_enum"; then
            export CURRENT_SCAN="dir_enum"
            save_progress "$OUTPUT_DIR" "$CURRENT_SCAN" "$PROCESSED_TARGETS"
            run_dir_enum "$TARGET_LIST"
            mark_completed "$OUTPUT_DIR" "dir_enum"
        else
            info "Skipping dir_enum scan (already completed)"
        fi
        
        # Parameter Discovery
        if ! check_completed "param_discovery"; then
            export CURRENT_SCAN="param_discovery"
            save_progress "$OUTPUT_DIR" "$CURRENT_SCAN" "$PROCESSED_TARGETS"
            run_param_discovery "$TARGET_LIST"
            mark_completed "$OUTPUT_DIR" "param_discovery"
        else
            info "Skipping param_discovery scan (already completed)"
        fi
        
        # Vulnerability Scanning
        if ! check_completed "vuln_scan"; then
            export CURRENT_SCAN="vuln_scan"
            save_progress "$OUTPUT_DIR" "$CURRENT_SCAN" "$PROCESSED_TARGETS"
            run_vuln_scan "$TARGET_LIST"
            mark_completed "$OUTPUT_DIR" "vuln_scan"
        else
            info "Skipping vuln_scan scan (already completed)"
        fi
    fi
    
    # Generate Reports
    info "Generating reports"
    if ! check_completed "report_generation"; then
        export CURRENT_SCAN="report_generation"
        save_progress "$OUTPUT_DIR" "$CURRENT_SCAN" "$PROCESSED_TARGETS"
        generate_report "$OUTPUT_DIR"
        
        # Generate additional reports
        if ! isLightScan; then
            generate_google_dork_report "$OUTPUT_DIR"
            generate_asn_report "$OUTPUT_DIR"
            generate_dir_enum_report "$OUTPUT_DIR"
            generate_param_discovery_report "$OUTPUT_DIR"
            generate_vuln_report "$OUTPUT_DIR"
        fi
        
        mark_completed "$OUTPUT_DIR" "report_generation"
    else
        info "Skipping report generation (already completed)"
    fi
    
    # Clear current scan
    export CURRENT_SCAN=""
    save_progress "$OUTPUT_DIR" "$CURRENT_SCAN" "$PROCESSED_TARGETS"
    
    # Clean up state files on successful completion
    if isResumeMode; then
        info "Cleaning up state files after successful completion"
        cleanup_state "$OUTPUT_DIR"
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
