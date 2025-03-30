#!/bin/bash

# Test script for target processing module

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"

# Import target processing module
source "$SCRIPT_DIR/src/core/target_processing.sh"

# Test file
TEST_CASES="$SCRIPT_DIR/tests/target_processing/test_cases.txt"
OUTPUT_DIR="$SCRIPT_DIR/tests/target_processing/output"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Tools to test
TOOLS=(
    "default"
    "httpx"
    "crtsh"
    "wayback"
    "hakrawler"
    "nmap"
    "httprobe"
    "tls_bufferover"
    "google_dorks"
)

# Test individual target processing
test_process_target() {
    local target="$1"
    local tool="$2"
    
    echo -e "${YELLOW}Testing target:${NC} $target ${YELLOW}with tool:${NC} $tool"
    
    # Process target
    local processed=$(process_target "$target" "$tool")
    local status=$?
    
    # Check result
    if [[ $status -eq 0 ]]; then
        echo -e "${GREEN}Success:${NC} $processed"
        
        # Verify tool-specific requirements
        local config="${TOOL_CONFIGS[$tool]}"
        IFS=: read -r require_protocol handle_wildcards allow_ports strip_www validate_dns max_depth <<< "$config"
        
        local validation_passed=true
        
        # Check protocol requirement
        if [[ "$require_protocol" == "true" && ! "$processed" =~ ^https?:// ]]; then
            echo -e "${RED}Validation failed:${NC} Protocol required but not present"
            validation_passed=false
        fi
        
        # Check wildcard handling
        if [[ "$handle_wildcards" == "false" && "$target" =~ ^\*\. && "$processed" != "$target" ]]; then
            echo -e "${RED}Validation failed:${NC} Wildcard should not be processed"
            validation_passed=false
        fi
        
        # Check port handling
        if [[ "$allow_ports" == "false" && "$processed" =~ :[0-9]+ ]]; then
            echo -e "${RED}Validation failed:${NC} Ports not allowed but present"
            validation_passed=false
        fi
        
        # Check www stripping
        if [[ "$strip_www" == "true" && "$processed" =~ ^https?://www\. ]]; then
            echo -e "${RED}Validation failed:${NC} www should be stripped"
            validation_passed=false
        fi
        
        if [[ "$validation_passed" == "true" ]]; then
            echo -e "${GREEN}Validation passed${NC}"
        fi
    else
        echo -e "${RED}Failed:${NC} Invalid target format"
    fi
    
    echo ""
}

# Test processing a list of targets
test_process_target_list() {
    local tool="$1"
    local output_file="$OUTPUT_DIR/${tool}_processed.txt"
    
    echo -e "${YELLOW}Testing target list processing for tool:${NC} $tool"
    
    # Process target list
    process_target_list "$TEST_CASES" "$output_file" "$tool"
    
    # Count processed targets
    local count=$(grep -v "^#" "$output_file" | wc -l)
    echo -e "${GREEN}Processed $count targets${NC}"
    echo -e "${YELLOW}Output saved to:${NC} $output_file"
    echo ""
}

# Main test function
run_tests() {
    echo "=== Testing Target Processing Module ==="
    echo ""
    
    # Test individual targets with each tool
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        
        for tool in "${TOOLS[@]}"; do
            test_process_target "$line" "$tool"
        done
    done < "$TEST_CASES"
    
    echo "=== Testing Target List Processing ==="
    echo ""
    
    # Test processing the entire list with each tool
    for tool in "${TOOLS[@]}"; do
        test_process_target_list "$tool"
    done
    
    echo "=== All Tests Completed ==="
}

# Run tests
run_tests
