#!/bin/bash

# Guard to prevent multiple sourcing
if [[ -n "${TARGET_PROCESSING_SOURCED:-}" ]]; then
    return 0
fi
export TARGET_PROCESSING_SOURCED=1

# Import required modules
source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/validation.sh"

# Constants for target processing
readonly URL_REGEX='^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$'
readonly DOMAIN_REGEX='^([a-zA-Z0-9](([a-zA-Z0-9-]){0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'
readonly IP_REGEX='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
readonly PORT_REGEX=':[0-9]{1,5}$'
readonly WILDCARD_REGEX='^\*\.'

# Target processing configuration
# Using indexed arrays and functions instead of associative arrays for better compatibility
TOOL_NAMES=()
TOOL_CONFIGS=()

# Configuration schema fields:
# require_protocol:handle_wildcards:allow_ports:strip_www:validate_dns:max_depth

# Get tool configuration
get_tool_config() {
    local tool="$1"
    local default_config="false:true:false:true:false:5"
    
    # Check if tool exists in configuration
    local i
    for ((i=0; i<${#TOOL_NAMES[@]}; i++)); do
        if [[ "${TOOL_NAMES[$i]}" == "$tool" ]]; then
            echo "${TOOL_CONFIGS[$i]}"
            return 0
        fi
    done
    
    # Return default configuration if tool not found
    echo "$default_config"
}

# Set tool configuration
set_tool_config() {
    local tool="$1"
    local config="$2"
    
    # Check if tool already exists
    local i
    for ((i=0; i<${#TOOL_NAMES[@]}; i++)); do
        if [[ "${TOOL_NAMES[$i]}" == "$tool" ]]; then
            TOOL_CONFIGS[$i]="$config"
            return 0
        fi
    done
    
    # Add new tool configuration
    TOOL_NAMES+=("$tool")
    TOOL_CONFIGS+=("$config")
}

# Initialize tool configurations
init_tool_configs() {
    debug "Initializing tool configurations"
    
    # Set default configuration
    set_tool_config "default" "false:true:false:true:false:5"
    
    local config_file="$SCRIPT_DIR/config/target_processing.conf"
    
    # Check if config file exists
    if [[ -f "$config_file" ]]; then
        debug "Reading tool configurations from $config_file"
        
        local current_section=""
        local require_protocol=""
        local handle_wildcards=""
        local allow_ports=""
        local strip_www=""
        local validate_dns=""
        local max_depth=""
        
        # Read config file line by line
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Skip empty lines and comments
            [[ -z "$line" || "$line" =~ ^# ]] && continue
            
            # Check if line is a section header
            if [[ "$line" =~ ^\[(.*)\]$ ]]; then
                # Save previous section if complete
                if [[ -n "$current_section" && -n "$require_protocol" && -n "$handle_wildcards" && 
                      -n "$allow_ports" && -n "$strip_www" && -n "$validate_dns" && -n "$max_depth" ]]; then
                    set_tool_config "$current_section" "$require_protocol:$handle_wildcards:$allow_ports:$strip_www:$validate_dns:$max_depth"
                    
                    # Reset variables
                    require_protocol=""
                    handle_wildcards=""
                    allow_ports=""
                    strip_www=""
                    validate_dns=""
                    max_depth=""
                fi
                
                # Set new section
                current_section="${BASH_REMATCH[1]}"
                continue
            fi
            
            # Process key-value pairs
            if [[ "$line" =~ ^([^=]+)=(.*)$ ]] && [[ -n "$current_section" ]]; then
                local key="${BASH_REMATCH[1]}"
                local value="${BASH_REMATCH[2]}"
                
                # Store configuration values
                case "$key" in
                    require_protocol)
                        require_protocol="$value"
                        ;;
                    handle_wildcards)
                        handle_wildcards="$value"
                        ;;
                    allow_ports)
                        allow_ports="$value"
                        ;;
                    strip_www)
                        strip_www="$value"
                        ;;
                    validate_dns)
                        validate_dns="$value"
                        ;;
                    max_depth)
                        max_depth="$value"
                        ;;
                esac
            fi
        done < "$config_file"
        
        # Save last section if complete
        if [[ -n "$current_section" && -n "$require_protocol" && -n "$handle_wildcards" && 
              -n "$allow_ports" && -n "$strip_www" && -n "$validate_dns" && -n "$max_depth" ]]; then
            set_tool_config "$current_section" "$require_protocol:$handle_wildcards:$allow_ports:$strip_www:$validate_dns:$max_depth"
        fi
    else
        warn "Configuration file not found: $config_file"
        warn "Using default configurations"
        
        # Set default configurations for common tools
        set_tool_config "httpx" "true:true:true:true:false:5"
        set_tool_config "crtsh" "false:true:false:true:false:5"
        set_tool_config "wayback" "true:false:true:false:false:5"
        set_tool_config "hakrawler" "true:true:true:true:false:5"
        set_tool_config "nmap" "false:true:true:false:true:5"
        set_tool_config "httprobe" "true:true:true:true:false:5"
        set_tool_config "tls_bufferover" "false:true:false:true:false:5"
        set_tool_config "google_dorks" "false:true:false:true:false:5"
        set_tool_config "asn_enum" "false:true:false:true:false:5"
        set_tool_config "dir_enum" "true:true:true:true:false:5"
        set_tool_config "param_discovery" "true:true:true:true:false:5"
        set_tool_config "vuln_scan" "true:true:true:true:false:5"
    fi
    
    debug "Tool configurations initialized"
}

# Target processing functions
strip_protocol() {
    local input="$1"
    echo "$input" | sed -E 's#^https?://##'
}

add_protocol() {
    local input="$1"
    local protocol="${2:-https}"
    [[ "$input" =~ ^https?:// ]] && echo "$input" || echo "${protocol}://$input"
}

normalize_domain() {
    local input="$1"
    echo "$input" | tr '[:upper:]' '[:lower:]' | sed 's/\/$//'
}

process_wildcards() {
    local input="$1"
    local handle_wildcards="$2"
    
    if [[ "$handle_wildcards" == "true" && "$input" =~ $WILDCARD_REGEX ]]; then
        debug "Processing wildcard domain: $input"
        echo "${input#\*.}"
    else
        echo "$input"
    fi
}

extract_port() {
    local input="$1"
    if [[ "$input" =~ $PORT_REGEX ]]; then
        echo "${input##*:}"
    else
        echo ""
    fi
}

strip_port() {
    local input="$1"
    echo "$input" | sed -E 's/:[0-9]+$//'
}

validate_port() {
    local port="$1"
    [[ -n "$port" ]] && [[ "$port" -ge 1 ]] && [[ "$port" -le 65535 ]]
}

count_subdomains() {
    local domain="$1"
    echo "$domain" | tr '.' '\n' | wc -l
}

# Main target processing function
process_target() {
    local input="$1"
    local tool="${2:-default}"
    
    debug "Processing target for tool '$tool': $input"
    
    # Get tool configuration
    local config=$(get_tool_config "$tool")
    IFS=: read -r require_protocol handle_wildcards allow_ports strip_www validate_dns max_depth <<< "$config"
    
    # Initial normalization
    local processed="$(normalize_domain "$input")"
    debug "Normalized input: $processed"
    
    # Extract and validate port if present
    local port="$(extract_port "$processed")"
    if [[ -n "$port" ]]; then
        if [[ "$allow_ports" != "true" ]]; then
            warn "Tool '$tool' does not support ports, ignoring port $port"
            processed="$(strip_port "$processed")"
        elif ! validate_port "$port"; then
            error "Invalid port number: $port"
            return 1
        fi
        
        # Strip port for now, we'll add it back later if needed
        processed="$(strip_port "$processed")"
    fi
    
    # Process protocol
    local has_protocol=false
    if [[ "$processed" =~ ^https?:// ]]; then
        has_protocol=true
    fi
    
    processed="$(strip_protocol "$processed")"
    
    # Process wildcards if tool supports it
    if [[ "$handle_wildcards" == "true" ]]; then
        processed="$(process_wildcards "$processed" "true")"
    elif [[ "$processed" =~ $WILDCARD_REGEX ]]; then
        # If tool doesn't support wildcards but input is a wildcard, fail
        error "Tool '$tool' does not support wildcard domains: $processed"
        return 1
    fi
    
    # Strip www if configured
    if [[ "$strip_www" == "true" ]]; then
        processed="${processed#www.}"
    fi
    
    # Validate subdomain depth
    local depth="$(count_subdomains "$processed")"
    if [[ "$depth" -gt "$max_depth" ]]; then
        warn "Subdomain depth ($depth) exceeds maximum ($max_depth) for tool '$tool'"
        return 1
    fi
    
    # Final validation
    if ! validate_target "$processed"; then
        error "Invalid target format after processing: $processed"
        return 1
    fi
    
    # Add protocol back if required
    if [[ "$require_protocol" == "true" ]]; then
        if [[ "$has_protocol" == "true" ]]; then
            # Use the original protocol
            if [[ "$input" =~ ^https:// ]]; then
                processed="https://$processed"
            else
                processed="http://$processed"
            fi
        else
            # Default to https
            processed="https://$processed"
        fi
    fi
    
    # Add port back if allowed
    if [[ -n "$port" ]] && [[ "$allow_ports" == "true" ]]; then
        processed="$processed:$port"
    fi
    
    echo "$processed"
}

# Target validation function
validate_target() {
    local target="$1"
    local stripped="$(strip_protocol "$target")"
    stripped="$(strip_port "$stripped")"
    
    if [[ "$stripped" =~ $DOMAIN_REGEX ]] || [[ "$stripped" =~ $IP_REGEX ]]; then
        return 0
    else
        return 1
    fi
}

# Process a list of targets
process_target_list() {
    local input_file="$1"
    local output_file="$2"
    local tool="${3:-default}"
    
    debug "Processing target list for tool '$tool': $input_file -> $output_file"
    
    # Create output file
    > "$output_file"
    
    # Process each line
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        
        local processed="$(process_target "$line" "$tool")"
        if [[ $? -eq 0 ]]; then
            echo "$processed" >> "$output_file"
        else
            warn "Failed to process target: $line"
        fi
    done < "$input_file"
    
    # Count processed targets
    local count=$(wc -l < "$output_file")
    debug "Processed $count targets for tool '$tool'"
}

# Initialize configurations on source
init_tool_configs
