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

# Cleanup function
cleanup() {
    local exit_code=$?
    # Remove temporary files
    rm -f "$tmp_target_list" 2>/dev/null
    rm -f "$TARGET_LIST" 2>/dev/null
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
}

# Process command line arguments
userInput() {
    if [[ $@ =~ --help ]]; then
        Usage
        exit 0
    fi

    while getopts "hf:no:dt:slw" flag; do
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
    # Generate folders
    generate_folders
    # Parse user input and get all targets into one file.
    consolidateTargets
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
