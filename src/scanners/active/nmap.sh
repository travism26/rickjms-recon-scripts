#!/usr/bin/env bash

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")")" && pwd)"

# Import required modules
source "$SCRIPT_DIR/src/core/logging.sh"
source "$SCRIPT_DIR/src/core/utils.sh"
source "$SCRIPT_DIR/config/settings.sh"

# Main Nmap scanning function
run_nmap() {
    local USERIN="$1"
    local NMAPOUT="nmap.out"
    local start_time
    local total_hosts
    local scan_type="default"
    local nmap_args=()
    local progress_pid
    
    debug "run_nmap($USERIN)"
    
    if isDryRun; then
        echo "nmap -iL $USERIN -T4 -oA $POST_SCAN_ENUM/$NMAPOUT"
    else
        info "Starting Nmap scan on targets from: $USERIN"
        
        # Count total hosts
        total_hosts=$(wc -l < "$USERIN")
        start_time=$(date +%s)
        
        # Build scan arguments based on host count
        if [[ $total_hosts -gt $NMAP_FAST_SCAN_THRESHOLD ]]; then
            warn "Large number of hosts detected ($total_hosts). Using faster scan settings."
            scan_type="fast"
            nmap_args=(
                "-iL" "$USERIN"
                "-T4"
                "-Pn"
                "--min-rate=1000"
                "--max-retries=2"
                "-p" "$PORTS_TO_SCAN"
                "--open"
                "--script=http-title"
                "-oA" "$POST_SCAN_ENUM/$NMAPOUT"
            )
        else
            scan_type="detailed"
            nmap_args=(
                "-iL" "$USERIN"
                "-T4"
                "-A"
                "-p" "$PORTS_TO_SCAN"
                "--version-intensity=5"
                "-oA" "$POST_SCAN_ENUM/$NMAPOUT"
            )
        fi
        
        info "Using $scan_type scan profile for $total_hosts hosts"
        
        # Set up progress monitoring
        local progress_file=$(mktemp)
        (
            while true; do
                if [[ -f "$POST_SCAN_ENUM/${NMAPOUT}.gnmap" ]]; then
                    local scanned=$(grep -c "Host:" "$POST_SCAN_ENUM/${NMAPOUT}.gnmap" || echo 0)
                    local current_time=$(date +%s)
                    local elapsed=$((current_time - start_time))
                    local percent=$((scanned * 100 / total_hosts))
                    local rate=$(( scanned / (elapsed + 1) ))
                    info "Progress: $scanned/$total_hosts ($percent%) at $rate hosts/sec - Elapsed: ${elapsed}s"
                fi
                sleep 30
            done
        ) &
        progress_pid=$!
        
        # Run the scan
        if ! nmap "${nmap_args[@]}" 2>/dev/null; then
            kill $progress_pid 2>/dev/null
            error "Nmap scan failed" 1
            return 1
        fi
        
        # Clean up progress monitoring
        kill $progress_pid 2>/dev/null
        
        # Generate scan statistics
        local end_time=$(date +%s)
        local total_time=$((end_time - start_time))
        local open_ports=0
        local hosts_up=0
        
        if [[ -f "$POST_SCAN_ENUM/${NMAPOUT}.gnmap" ]]; then
            hosts_up=$(grep -c "Status: Up" "$POST_SCAN_ENUM/${NMAPOUT}.gnmap")
            open_ports=$(grep -c "Ports:" "$POST_SCAN_ENUM/${NMAPOUT}.gnmap")
            
            # Generate detailed report
            {
                echo "=== Nmap Scan Summary ==="
                echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
                echo "Scan Type: $scan_type"
                echo "Duration: ${total_time}s"
                echo "Total Hosts: $total_hosts"
                echo "Hosts Up: $hosts_up"
                echo "Open Ports: $open_ports"
                echo
                echo "=== Open Ports Summary ==="
                grep "Ports:" "$POST_SCAN_ENUM/${NMAPOUT}.gnmap" | \
                    sed 's/Ports: /\n/g' | grep -v "Host:" | \
                    tr ',' '\n' | grep "open" | \
                    sort | uniq -c | sort -rn
                echo
                echo "=== Service Version Summary ==="
                grep "Ports:" "$POST_SCAN_ENUM/${NMAPOUT}.gnmap" | \
                    sed 's/Ports: /\n/g' | grep -v "Host:" | \
                    tr ',' '\n' | grep "open" | \
                    awk -F'/' '{print $5}' | sort | uniq -c | sort -rn
                echo
                echo "=== Interesting Services ==="
                grep -i "admin\|jenkins\|jboss\|tomcat\|weblogic\|wordpress\|phpmyadmin" \
                    "$POST_SCAN_ENUM/${NMAPOUT}.nmap" || echo "None found"
            } > "$POST_SCAN_ENUM/${NMAPOUT}_analysis.txt"
        fi
        
        info "Nmap scan completed in ${total_time}s"
        info "Results: $hosts_up hosts up, $open_ports ports open"
        info "Output saved to: $POST_SCAN_ENUM/$NMAPOUT.{nmap,gnmap,xml}"
        info "Analysis saved to: $POST_SCAN_ENUM/${NMAPOUT}_analysis.txt"
        
        # Naffy's recommended command for reference
        info "Consider running Naffy's recommended scan:"
        echo "nmap -T4 -iL $USERIN -Pn --script=http-title -p80,4443,4080,443 --open"
    fi
}

# Check if a port is likely to be filtered by a firewall
check_port_filtered() {
    local host="$1"
    local port="$2"
    
    # Try a quick TCP connect scan
    if ! nmap -p"$port" -Pn -n --max-retries=1 --host-timeout=5s "$host" | grep -q "open"; then
        return 0  # Port is likely filtered
    fi
    return 1  # Port appears to be accessible
}

# Validate that nmap is installed with required capabilities
validate_nmap_installation() {
    # Check if nmap is installed
    if ! command -v nmap &>/dev/null; then
        error "nmap is not installed" 1
        return 1
    fi

    # Check if we have permission to run TCP SYN scans
    if ! nmap --privileged --version &>/dev/null; then
        warn "nmap is not running with sufficient privileges for SYN scans"
        warn "Consider running with sudo or setting capabilities"
        warn "sudo setcap cap_net_raw+ep $(which nmap)"
    fi
    
    # Check if NSE scripts are available
    if ! [[ -d "$(nmap --datadir)/scripts" ]]; then
        warn "NSE scripts directory not found"
        warn "Some scan features may be limited"
    fi
    
    return 0
}
