#!/bin/bash

# Set the base directory for the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Import required modules
source "$SCRIPT_DIR/src/core/logging.sh"
source "$SCRIPT_DIR/src/core/utils.sh"
source "$SCRIPT_DIR/src/scanners/api/rate_limiting.sh"
source "$SCRIPT_DIR/src/scanners/passive/crtsh.sh"

# Enable debug logging
export ENABLE_DEBUG=1

# Set up scan folder
export SCAN_FOLDER="./test-output/crtsh"
mkdir -p "$SCAN_FOLDER"

# Test with a domain from test.domain file
DOMAIN=$(cat test.domain)
echo "Testing crtsh.sh with domain: $DOMAIN"

# Run the crtsh function
run_crtsh "$DOMAIN"

echo "Test completed. Check $SCAN_FOLDER/crtsh.host.out for results."
