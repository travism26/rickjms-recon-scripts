#!/bin/bash

# Define colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to check if a tool is installed
check_tool() {
    local tool=$1
    if command -v "$tool" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $tool is installed and accessible"
        return 0
    else
        echo -e "${RED}✗${NC} $tool is NOT installed or not accessible"
        return 1
    fi
}

# List of tools to check
tools=(
    "assetfinder"
    "httprobe"
    "waybackurls"
    "subjack"
    "fff"
    "anew"
    "gau"
    "puredns"
    "hakrawler"
    "inscope"
)

echo "Verifying Go tools installation..."
echo "=================================="

# Check each tool
for tool in "${tools[@]}"; do
    check_tool "$tool"
done

echo "=================================="
echo "If all tools show as installed, your Go environment is set up correctly."
echo "If any tools are missing, you may need to reinstall them using:"
echo "go install github.com/toolauthor/toolname@latest"
