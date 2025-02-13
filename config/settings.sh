#!/bin/bash

# Script information
VERSION="1.0.1"
SCRIPT_NAME="rickjms-recon.sh"
SCRIPT_DESCRIPTION="Advanced Reconnaissance Script"
SCRIPT_AUTHOR="rickjms"

# Required tools array
REQUIRED_TOOLS=(
    "assetfinder"
    "amass"
    "subfinder"
    "httpx"
    "httprobe"
    "hakrawler"
    "SubDomainizer"
    "dnmasscan"
    "waybackurls"
    "subjack"
    "nmap"
    "fff"
    "linkfinder"
)

# Global paths and directories
SCRIPT=$(echo $0 | awk -F "/" '{print $NF}')
CUR_DATE=$(date +"%Y%m%d")
UUIDSHORT=$(uuidgen | cut -d\- -f1)
CURRENT_DIR=$(pwd)
BASEDIR=$(dirname $0)

# Default settings
OUTPUT_DIR="$CURRENT_DIR"  # Default current directory
PORTS_TO_SCAN="443,80,4443,8443,8080,8081"

# User input variables
USER_TARGET=""
USER_FILE=""

# Flag variables
DRYRUN="false"
FILE_PASSED="false"
TARGET_PASSED="false"
SILENT_MODE=""
ENABLE_DEBUG=""
LIGHT_SCAN=""
INSCOPE_PASSED=""
SKIPWAYBACK=""

# Temporary files
tmp_target_list=$(mktemp /tmp/rickjms-recon.XXXXXX)
TARGET_LIST=""  # Will be set during initialization
FINAL_TARGETS=""  # Will be set during initialization

# Scan output directories
# These will be set relative to OUTPUT_DIR during initialization
SCAN_FOLDER=""
POST_SCAN_ENUM=""
POSSIBLE_OOS_TARGETS=""
ALIVE=""
DNSCAN=""
HAKTRAILS=""
CRAWLING=""
WAYBACKURL=""
JS_SCANNING=""

# Tool-specific settings
NMAP_FAST_SCAN_THRESHOLD=1000  # Number of hosts above which to use fast scan mode
HTTPROBE_CONCURRENT=60         # Number of concurrent connections for httprobe
SUBFINDER_THREADS=100          # Number of threads for subfinder
SUBJACK_THREADS=100           # Number of threads for subjack
FFF_DEPTH=100                 # Depth for fff crawler

# Error handling
MAX_RETRIES=3                 # Maximum number of retries for failed operations
RETRY_DELAY=5                 # Delay in seconds between retries

# Export all variables
export VERSION SCRIPT_NAME SCRIPT_DESCRIPTION SCRIPT_AUTHOR
export REQUIRED_TOOLS
export SCRIPT CUR_DATE UUIDSHORT CURRENT_DIR BASEDIR
export OUTPUT_DIR PORTS_TO_SCAN
export USER_TARGET USER_FILE
export DRYRUN FILE_PASSED TARGET_PASSED SILENT_MODE ENABLE_DEBUG LIGHT_SCAN INSCOPE_PASSED SKIPWAYBACK
export tmp_target_list TARGET_LIST FINAL_TARGETS
export SCAN_FOLDER POST_SCAN_ENUM POSSIBLE_OOS_TARGETS ALIVE DNSCAN HAKTRAILS CRAWLING WAYBACKURL JS_SCANNING
export NMAP_FAST_SCAN_THRESHOLD HTTPROBE_CONCURRENT SUBFINDER_THREADS SUBJACK_THREADS FFF_DEPTH
export MAX_RETRIES RETRY_DELAY
