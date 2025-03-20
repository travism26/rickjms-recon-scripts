#!/bin/bash

# Import logging functions
source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

# Flag check functions
isDryRun() {
    [ "$DRYRUN" = "true" ]
}

filePassed() {
    [ "$FILE_PASSED" = "true" ]
}

targetPassed() {
    [ "$TARGET_PASSED" = "true" ]
}

isLightScan() {
    [ "$LIGHT_SCAN" = "true" ]
}

inscopePassed() {
    [ "$INSCOPE_PASSED" = "true" ]
}

skipWaybackUrl() {
    [ "$SKIPWAYBACK" = "true" ]
}

skipAmass() {
    [ "$SKIPAMASS" = "true" ]
}

isResumeMode() {
    [ "$RESUME_MODE" = "true" ]
}

# Signal handler for interrupts
handle_interrupt() {
    info "Received interrupt signal. Saving state..."
    
    # Save current state if we're in the middle of a scan
    if [[ -n "$CURRENT_SCAN" && -n "$OUTPUT_DIR" ]]; then
        save_state "$OUTPUT_DIR" "$CURRENT_SCAN" "$PROCESSED_TARGETS"
        info "State saved. To resume, run with: -r -o $OUTPUT_DIR"
    fi
    
    # Call the regular cleanup function
    cleanup
    
    exit 1
}

# Cleanup function
cleanup() {
    local exit_code=$?
    # Remove temporary files
    rm -f "$tmp_target_list" 2>/dev/null
    
    # Don't remove TARGET_LIST if we're in resume mode
    if [[ "$RESUME_MODE" != "true" ]]; then
        rm -f "$TARGET_LIST" 2>/dev/null
    fi
    
    exit $exit_code
}

# Python virtual environment activation
activate_python_venv() {
    if [[ -f $BASEDIR/bin/activate ]]; then
        source $BASEDIR/bin/activate
    fi
}

# Display usage information
Usage() {
    echo "Usage:"
    echo -e "\t-h \t\t\t\tDisplay help menu"
    echo -e "\t-f FILENAME \t\tRun recon with file of target domains"
    echo -e "\t-n \t\t\tExecute a dry run listing all the commands executed and tools used"
    echo -e "\t-o PATH/TO/OUTPUT \tChange the output directoy default is current directory"
    echo -e "\t-t USER_TARGET \t\tRun recon against single domain"
    echo -e "\t-s \t\t\tSilent Mode do not post output"
    echo -e "\t-d \t\t\tEnable Debugging mode"
    echo -e "\t-l \t\t\tLIGHT SCAN Mode Only run the quick scans (assetfinder, crt.sh, tls.bufferover.run)"
    echo -e "\t-w \t\t\tSkip the waybackurl lookup."
    echo -e "\t-a \t\t\tSkip the amass tool (faster for large domain lists)."
    echo -e "\t-r \t\t\tResume from last saved state (requires -o to specify output directory)."
}

# Process command line arguments
userInput() {
    if [[ $@ =~ --help ]]; then
        Usage
        exit 0
    fi

    while getopts "hf:no:dt:slwar" flag; do
        case $flag in
            h)
                Usage
                exit 0
                ;;
            f)
                USER_FILE="$OPTARG"
                validate_input_file "$USER_FILE"
                FILE_PASSED="true"
                ;;
            n)
                DRYRUN="true"
                ;;
            o)
                OUTPUT_DIR="$OPTARG"
                validate_output_dir "$OUTPUT_DIR"
                ;;
            t)
                USER_TARGET="$OPTARG"
                validate_domain "$USER_TARGET"
                info "USER TARGET: $USER_TARGET"
                TARGET_PASSED="true"
                ;;
            d)
                ENABLE_DEBUG="true"
                ;;
            s)
                SILENT_MODE="true"
                ;;
            l)
                LIGHT_SCAN="true"
                ;;
            S)
                INSCOPE_PASSED="true"
                ;;
            w)
                SKIPWAYBACK="true"
                ;;
            a)
                SKIPAMASS="true"
                ;;
            r)
                RESUME_MODE="true"
                info "Resume mode enabled"
                ;;
            *)
                Usage
                exit 2
                ;;
        esac
    done

    # Validate that at least one target is specified
    if [[ "$FILE_PASSED" != "true" && -z "$USER_TARGET" ]]; then
        error "Must specify either a target domain (-t) or input file (-f)" 2
    fi
}

# Initialize scan environment
init() {
    # Check if we're in resume mode
    if isResumeMode; then
        # Validate that output directory is specified
        if [[ -z "$OUTPUT_DIR" ]]; then
            error "Resume mode requires output directory (-o)" 2
        fi
        
        # Check if state file exists
        if [[ ! -f "$OUTPUT_DIR/$STATE_FILE" && ! -f "$OUTPUT_DIR/$STATE_FILE_BACKUP" ]]; then
            error "No state file found in $OUTPUT_DIR" 2
        fi
        
        # Load state
        info "Loading state from $OUTPUT_DIR"
        if ! load_state "$OUTPUT_DIR"; then
            error "Failed to load state from $OUTPUT_DIR" 2
        fi
        
        # Validate that directories exist
        if [[ ! -d "$OUTPUT_DIR/scans" || ! -d "$OUTPUT_DIR/post-scanning" ]]; then
            error "Output directory structure is incomplete" 2
        fi
        
        # Set up directory variables
        SCAN_FOLDER="$OUTPUT_DIR/scans"
        POST_SCAN_ENUM="$OUTPUT_DIR/post-scanning"
        POSSIBLE_OOS_TARGETS="$OUTPUT_DIR/maybe-out-scope"
        
        # Set up subdirectory variables
        ALIVE="$POST_SCAN_ENUM/subdomains"
        DNSCAN="$POST_SCAN_ENUM/dnmasscan"
        HAKTRAILS="$POST_SCAN_ENUM/haktrails"
        CRAWLING="$POST_SCAN_ENUM/website-crawling"
        WAYBACKURL="$POST_SCAN_ENUM/waybackurls"
        JS_SCANNING="$POST_SCAN_ENUM/js-endpoint-discovery"
        
        info "Resumed scan with ID: $SCAN_ID"
        info "Completed scans: $COMPLETED_SCANS"
        info "Current scan: $CURRENT_SCAN"
        info "Progress: $PROCESSED_TARGETS/$TOTAL_TARGETS targets"
    else
        # Generate folders
        generate_folders
        # Parse user input and get all targets into one file.
        consolidateTargets
        # Initialize state
        init_state "$OUTPUT_DIR" "$TARGET_LIST"
    fi
    
    # Set up trap for interrupt signal
    trap handle_interrupt INT
}

# Generate folder structure for scan outputs
generate_folders() {
    # Top level directories
    SCAN_FOLDER="$OUTPUT_DIR/scans"
    POST_SCAN_ENUM="$OUTPUT_DIR/post-scanning"
    POSSIBLE_OOS_TARGETS="$OUTPUT_DIR/maybe-out-scope"
    TOPFOLDERS="$SCAN_FOLDER $POST_SCAN_ENUM $POSSIBLE_OOS_TARGETS"

    # Sub directories
    ALIVE="$POST_SCAN_ENUM/subdomains"
    DNSCAN="$POST_SCAN_ENUM/dnmasscan"
    HAKTRAILS="$POST_SCAN_ENUM/haktrails"
    CRAWLING="$POST_SCAN_ENUM/website-crawling"
    WAYBACKURL="$POST_SCAN_ENUM/waybackurls"
    JS_SCANNING="$POST_SCAN_ENUM/js-endpoint-discovery"
    SUBFOLDERS="$ALIVE $DNSCAN $HAKTRAILS $CRAWLING $WAYBACKURL"

    info "Creating directory structure for recon files"
    info "TOPFOLDERS = $TOPFOLDERS"

    # Create top-level directories
    for top_path in $TOPFOLDERS; do
        debug "Attempting to create folder:$top_path"
        if test -d "$top_path"; then
            error "Path:$top_path already exists..." 255
        fi
        if isDryRun; then
            echo "mkdir -p $top_path"
        else
            mkdir -p "$top_path"
            debug "Created directory:$top_path"
        fi
    done

    # Create sub-directories
    for sub_folder in $SUBFOLDERS; do
        debug "Attempting to create folder:$sub_folder"
        if test -d "$sub_folder"; then
            error "Path:$sub_folder already exists"
        fi
        if isDryRun; then
            echo "mkdir -p $sub_folder"
        else
            mkdir -p "$sub_folder"
            debug "Created directory:$sub_folder"
        fi
    done
}
