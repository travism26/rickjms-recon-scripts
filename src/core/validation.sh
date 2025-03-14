#!/bin/bash

# Import logging functions
source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

# Validate input file exists and is readable
validate_input_file() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        error "Input file does not exist: $file" 2
    fi
    if [[ ! -r "$file" ]]; then
        error "Input file is not readable: $file" 2
    fi
}

# Validate output directory
validate_output_dir() {
    local dir="$1"
    # Create directory if it doesn't exist
    if [[ ! -d "$dir" ]]; then
        if ! mkdir -p "$dir" 2>/dev/null; then
            error "Failed to create output directory: $dir" 2
        fi
    fi
    # Check if directory is writable
    if [[ ! -w "$dir" ]]; then
        error "Output directory is not writable: $dir" 2
    fi
}

# Validate domain format
validate_domain() {
    local domain="$1"
    local domain_regex="^([a-zA-Z0-9](([a-zA-Z0-9-]){0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$"
    if [[ ! "$domain" =~ $domain_regex ]]; then
        error "Invalid domain format: $domain" 2
    fi
}

# Check for required tools
check_requirements() {
    local missing_tools=()
    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! command -v "$tool" &> /dev/null && [[ "$tool" != "SubDomainizer" ]]; then
            missing_tools+=("$tool")
        fi
    done
    
    # Special check for SubDomainizer as it's a Python script
    if ! python3 -c "import SubDomainizer" 2>/dev/null; then
        missing_tools+=("SubDomainizer (Python package)")
    fi

    if [ ${#missing_tools[@]} -ne 0 ]; then
        echo "Error: Required tools are missing:"
        printf '%s\n' "${missing_tools[@]}"
        echo "Please install missing tools before running this script."
        exit 1
    fi
}
