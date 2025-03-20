#!/bin/bash

# Test script for the continue feature
# This script will:
# 1. Start a scan with a test domain
# 2. Wait for a few seconds
# 3. Interrupt the scan with SIGINT
# 4. Resume the scan
# 5. Verify that the scan completes successfully

# Set up test environment
TEST_DIR=$(mktemp -d)
TEST_DOMAIN="example.com"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Continue Feature Test ==="
echo "Test directory: $TEST_DIR"
echo "Test domain: $TEST_DOMAIN"

# Clean up function
cleanup() {
    echo "Cleaning up test environment..."
    rm -rf "$TEST_DIR"
    echo "Done."
}

# Set up trap for cleanup
trap cleanup EXIT

# Step 1: Start a scan
echo "Step 1: Starting scan..."
"$SCRIPT_DIR/rickjms-recon.sh" -t "$TEST_DOMAIN" -o "$TEST_DIR" &
SCAN_PID=$!

# Step 2: Wait for a few seconds
echo "Step 2: Waiting for scan to progress..."
sleep 10

# Step 3: Interrupt the scan
echo "Step 3: Interrupting scan with SIGINT..."
kill -INT $SCAN_PID
sleep 2

# Check if state file exists
if [[ ! -f "$TEST_DIR/.recon_state.json" ]]; then
    echo "ERROR: State file not created after interruption"
    exit 1
fi

echo "State file created successfully"
echo "State file contents:"
cat "$TEST_DIR/.recon_state.json"

# Step 4: Resume the scan
echo "Step 4: Resuming scan..."
"$SCRIPT_DIR/rickjms-recon.sh" -r -o "$TEST_DIR"

# Step 5: Verify that the scan completed successfully
echo "Step 5: Verifying scan completion..."
if [[ ! -f "$TEST_DIR/.recon_state.json" ]]; then
    echo "SUCCESS: State file cleaned up after successful completion"
else
    echo "WARNING: State file still exists after completion"
    echo "State file contents:"
    cat "$TEST_DIR/.recon_state.json"
fi

# Check if report was generated
if [[ -f "$TEST_DIR/report.md" ]]; then
    echo "SUCCESS: Report generated successfully"
else
    echo "ERROR: Report not generated"
    exit 1
fi

echo "=== Test completed successfully ==="
