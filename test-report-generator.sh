#!/bin/bash

# Set up test environment variables
export TARGET_DOMAIN="example.com"
export SCAN_FOLDER="./scans"
export POST_SCAN_ENUM="./post-scanning"
export ALIVE="./post-scanning/subdomains"
export CRAWLING="./post-scanning/website-crawling"
export WAYBACKURL="./post-scanning/waybackurls"
export JS_SCANNING="./post-scanning/js-scanning"

# Create test directories
mkdir -p "$SCAN_FOLDER" "$POST_SCAN_ENUM" "$ALIVE" "$CRAWLING" "$WAYBACKURL" "$JS_SCANNING"

# Create sample crt.sh output
echo "admin.example.com
api.example.com
dev.example.com
staging.example.com
test.example.com" > "$SCAN_FOLDER/crtsh.host.out"

# Create sample httpx analysis with WAF detection
echo "=== HTTP Probe Analysis ===
Date: $(date)

=== Response Code Distribution ===
   1 [301,200]

=== Technology Stack Summary ===
   1 Cloudflare
   1 HTTP/3
   1 HSTS
   1 301
   1 200 Example https://www.example.com/ Cloudflare

=== Interesting Endpoints ===
None found" > "$ALIVE/httpx_analysis.txt"

# Create sample hakrawler analysis with crawling blocked
echo "=== Hakrawler Analysis ===
Date: $(date)

=== Crawling Blocked ===
The target appears to be blocking automated crawling.
This is common for large enterprise sites with WAF protection.

=== Recommendations ===
1. Try manual browsing with browser dev tools
2. Use Burp Suite with browser integration
3. Try waybackurls for historical endpoint discovery
4. Consider using a proxy or rotating user agents" > "$CRAWLING/hakrawler_analysis.txt"

# Source the report generator
source ./src/core/logging.sh
source ./src/core/utils.sh
source ./src/reporting/report_generator.sh

# Create output directory
OUTPUT_DIR="./test-output"
mkdir -p "$OUTPUT_DIR"

# Generate the report
generate_report "$OUTPUT_DIR"

echo "Test report generated in $OUTPUT_DIR"
echo "Check for the new 'Recommended Follow-up Scans' section"
