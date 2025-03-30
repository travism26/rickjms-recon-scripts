#!/bin/bash

# Demo script for target processing module

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"

# Import target processing module
source "$SCRIPT_DIR/src/core/target_processing.sh"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Test cases
TEST_CASES=(
    "example.com"
    "https://example.com"
    "www.example.com"
    "*.example.com"
    "example.com:8080"
    "https://www.sub.example.com:8443"
)

# Tools to demonstrate
TOOLS=(
    "default"
    "httpx"
    "crtsh"
    "wayback"
    "hakrawler"
    "nmap"
)

# Function to get tool configuration is now provided by target_processing.sh

# Function to process a target
process_demo_target() {
    local target="$1"
    local tool="$2"
    
    # Process target
    processed=$(process_target "$target" "$tool")
    status=$?
    
    # Get tool configuration
    config=$(get_tool_config "$tool")
    IFS=: read -r require_protocol handle_wildcards allow_ports strip_www validate_dns max_depth <<< "$config"
    
    # Display result
    echo -ne "${BLUE}$tool${NC} "
    printf "%-15s" "(config: "
    [[ "$require_protocol" == "true" ]] && echo -n "protocol " || echo -n "no-protocol "
    [[ "$handle_wildcards" == "true" ]] && echo -n "wildcards " || echo -n "no-wildcards "
    [[ "$allow_ports" == "true" ]] && echo -n "ports" || echo -n "no-ports"
    echo -n "): "
    
    if [[ $status -eq 0 ]]; then
        echo -e "${GREEN}$processed${NC}"
    else
        echo -e "${RED}Invalid format${NC}"
    fi
}

# Print header
echo -e "${BLUE}=== Target Processing Demo ===${NC}"
echo -e "${BLUE}This demo shows how different targets are processed for various tools${NC}"
echo

# Process each test case with each tool
for target in "${TEST_CASES[@]}"; do
    echo -e "${YELLOW}Original Target:${NC} $target"
    echo
    
    for tool in "${TOOLS[@]}"; do
        process_demo_target "$target" "$tool"
    done
    
    echo "-----------------------------------"
    echo
done

echo -e "${BLUE}=== Demo Complete ===${NC}"
