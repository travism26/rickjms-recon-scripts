#!/usr/bin/env bash

# Set the base directory for the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Import configuration and core modules
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/src/core/logging.sh"
source "$SCRIPT_DIR/src/core/utils.sh"
source "$SCRIPT_DIR/src/scanners/active/crawler.sh"

# Create test output directory
mkdir -p "$SCRIPT_DIR/test-output/crawling"
export CRAWLING="$SCRIPT_DIR/test-output/crawling"

# Enable debug logging
export ENABLE_DEBUG="true"

# Run hakrawler test
echo "Testing hakrawler with updated configuration..."
run_hakrawler "$SCRIPT_DIR/test.domain"

# Check results
if [ -f "$CRAWLING/hakrawler.out" ]; then
    echo "Test successful! Results saved to $CRAWLING/hakrawler.out"
    echo "Found $(wc -l < "$CRAWLING/hakrawler.out") URLs"
else
    echo "Test failed! No output file was created."
fi
