#!/usr/bin/env bash

# Set the base directory for the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Import configuration and core modules
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/src/core/logging.sh"
source "$SCRIPT_DIR/src/core/validation.sh"
source "$SCRIPT_DIR/src/core/utils.sh"
source "$SCRIPT_DIR/src/core/state_manager.sh"
source "$SCRIPT_DIR/src/core/target_processing.sh"

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
    
    # Create temporary file for raw target list
    local RAW_TARGET_LIST=$(mktemp)
    
    # Create directory for tool-specific target lists
    mkdir -p "$OUTPUT_DIR/targets"
    
    # Populate raw target list
    if filePassed; then
        debug "File passed, copying contents to raw target list"
        cat "$USER_FILE" > "$RAW_TARGET_LIST"
    else
        debug "Single target passed, adding to raw target list"
        echo "$USER_TARGET" > "$RAW_TARGET_LIST"
    fi
    
    # Create master target list
    TARGET_LIST="$OUTPUT_DIR/targets/master_target_list.txt"
    
    # Process raw targets using default configuration
    process_target_list "$RAW_TARGET_LIST" "$TARGET_LIST" "default"
    
    # Create tool-specific target lists
    create_tool_target_lists
    
    # Count total targets
    local total_targets=$(wc -l < "$TARGET_LIST")
    info "Total targets to scan: $total_targets"
    
    # Clean up
    rm -f "$RAW_TARGET_LIST"
}

# Create tool-specific target lists
create_tool_target_lists() {
    debug "Creating tool-specific target lists"
    
    # Define tools that need specific target formatting
    local TOOLS=(
        "crtsh"
        "tls_bufferover"
        "wayback"
        "google_dorks"
        "asn_enum"
        "httpx"
        "httprobe"
        "nmap"
        "hakrawler"
        "dir_enum"
        "param_discovery"
        "vuln_scan"
    )
    
    # Process target list for each tool
    for tool in "${TOOLS[@]}"; do
        local tool_target_list="$OUTPUT_DIR/targets/${tool}_targets.txt"
        process_target_list "$TARGET_LIST" "$tool_target_list" "$tool"
        debug "Created target list for $tool: $tool_target_list"
    done
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
            run_crtsh_with_file "$OUTPUT_DIR/targets/crtsh_targets.txt"
            mark_completed "$OUTPUT_DIR" "crtsh"
        else
            info "Skipping crtsh scan (already completed)"
        fi
        
        # TLS Bufferover
        if ! check_completed "tls_bufferover"; then
            export CURRENT_SCAN="tls_bufferover"
            save_progress "$OUTPUT_DIR" "$CURRENT_SCAN" "$PROCESSED_TARGETS"
            run_tls_bufferover "$OUTPUT_DIR/targets/tls_bufferover_targets.txt"
            mark_completed "$OUTPUT_DIR" "tls_bufferover"
        else
            info "Skipping tls_bufferover scan (already completed)"
        fi
        
        # Wayback Machine
        if ! skipWaybackUrl; then
            if ! check_completed "waybackurls"; then
                export CURRENT_SCAN="waybackurls"
                save_progress "$OUTPUT_DIR" "$CURRENT_SCAN" "$PROCESSED_TARGETS"
                run_waybackurls "$OUTPUT_DIR/targets/wayback_targets.txt"
                mark_completed "$OUTPUT_DIR" "waybackurls"
            else
                info "Skipping waybackurls scan (already completed)"
            fi
        fi
        
        # Google Dorking
        if ! check_completed "google_dorks"; then
            export CURRENT_SCAN="google_dorks"
            save_progress "$OUTPUT_DIR" "$CURRENT_SCAN" "$PROCESSED_TARGETS"
            run_google_dorks "$OUTPUT_DIR/targets/google_dorks_targets.txt"
            mark_completed "$OUTPUT_DIR" "google_dorks"
        else
            info "Skipping google_dorks scan (already completed)"
        fi
        
        # ASN Enumeration
        if ! check_completed "asn_enum"; then
            export CURRENT_SCAN="asn_enum"
            save_progress "$OUTPUT_DIR" "$CURRENT_SCAN" "$PROCESSED_TARGETS"
            run_asn_enum "$OUTPUT_DIR/targets/asn_enum_targets.txt"
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
        run_httpx "$OUTPUT_DIR/targets/httpx_targets.txt"
        mark_completed "$OUTPUT_DIR" "httpx"
    else
        info "Skipping httpx scan (already completed)"
    fi
    
    if ! check_completed "httprobe"; then
        export CURRENT_SCAN="httprobe"
        save_progress "$OUTPUT_DIR" "$CURRENT_SCAN" "$PROCESSED_TARGETS"
        run_httprobe "$OUTPUT_DIR/targets/httprobe_targets.txt"
        mark_completed "$OUTPUT_DIR" "httprobe"
    else
        info "Skipping httprobe scan (already completed)"
    fi
    
    # Port Scanning
    if ! check_completed "nmap"; then
        export CURRENT_SCAN="nmap"
        save_progress "$OUTPUT_DIR" "$CURRENT_SCAN" "$PROCESSED_TARGETS"
        run_nmap "$OUTPUT_DIR/targets/nmap_targets.txt"
        mark_completed "$OUTPUT_DIR" "nmap"
    else
        info "Skipping nmap scan (already completed)"
    fi
    
    # Web Crawling and JavaScript Analysis
    if ! isLightScan; then
        if ! check_completed "hakrawler"; then
            export CURRENT_SCAN="hakrawler"
            save_progress "$OUTPUT_DIR" "$CURRENT_SCAN" "$PROCESSED_TARGETS"
            run_hakrawler "$OUTPUT_DIR/targets/hakrawler_targets.txt"
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
            run_dir_enum "$OUTPUT_DIR/targets/dir_enum_targets.txt"
            mark_completed "$OUTPUT_DIR" "dir_enum"
        else
            info "Skipping dir_enum scan (already completed)"
        fi
        
        # Parameter Discovery
        if ! check_completed "param_discovery"; then
            export CURRENT_SCAN="param_discovery"
            save_progress "$OUTPUT_DIR" "$CURRENT_SCAN" "$PROCESSED_TARGETS"
            run_param_discovery "$OUTPUT_DIR/targets/param_discovery_targets.txt"
            mark_completed "$OUTPUT_DIR" "param_discovery"
        else
            info "Skipping param_discovery scan (already completed)"
        fi
        
        # Vulnerability Scanning
        if ! check_completed "vuln_scan"; then
            export CURRENT_SCAN="vuln_scan"
            save_progress "$OUTPUT_DIR" "$CURRENT_SCAN" "$PROCESSED_TARGETS"
            run_vuln_scan "$OUTPUT_DIR/targets/vuln_scan_targets.txt"
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
