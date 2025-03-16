#!/usr/bin/env bash

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")")" && pwd)"

# Import required modules
source "$SCRIPT_DIR/src/core/logging.sh"
source "$SCRIPT_DIR/src/core/utils.sh"
source "$SCRIPT_DIR/config/settings.sh"

# Signal handler function
handle_signals() {
    local signal=$1
    local progress_pid=$2
    local progress_file=$3
    
    debug "Received signal $signal in main process"
    echo "[DEBUG] Main process received signal: $signal" >> "$progress_file"
    
    # Check if progress monitor is running
    if [[ -n "$progress_pid" ]] && ps -p $progress_pid > /dev/null 2>&1; then
        debug "Terminating progress monitor (PID: $progress_pid) due to signal $signal"
        echo "[DEBUG] Terminating progress monitor due to signal $signal" >> "$progress_file"
        kill -TERM $progress_pid 2>/dev/null
        
        # Give it a moment to terminate gracefully
        sleep 1
        
        # Force kill if still running
        if ps -p $progress_pid > /dev/null 2>&1; then
            debug "Progress monitor did not terminate with TERM, sending KILL signal"
            echo "[DEBUG] Sending KILL signal to progress monitor" >> "$progress_file"
            kill -KILL $progress_pid 2>/dev/null
        fi
    fi
    
    # Copy debug logs to output directory before exiting
    if [[ -f "$progress_file" ]]; then
        mkdir -p "$POST_SCAN_ENUM" 2>/dev/null
        cp "$progress_file" "$POST_SCAN_ENUM/nmap_debug.log" 2>/dev/null
        info "Debug logs saved to: $POST_SCAN_ENUM/nmap_debug.log"
    fi
    
    # Exit with appropriate code
    exit 1
}

# Main Nmap scanning function
run_nmap() {
    local USERIN="$1"
    local NMAPOUT="nmap.out"
    local start_time
    local total_hosts
    local scan_type="default"
    local nmap_args=()
    local progress_pid=""
    local progress_file=""
    
    debug "run_nmap($USERIN)"
    
    if isDryRun; then
        echo "nmap -iL $USERIN -T4 -oA $POST_SCAN_ENUM/$NMAPOUT"
    else
        info "Starting Nmap scan on targets from: $USERIN"
        
        # Count total hosts
        total_hosts=$(grep -v "^$" "$USERIN" | wc -l)
        if [[ -z "$total_hosts" ]] || [[ "$total_hosts" -le 0 ]]; then
            warn "No valid hosts found in input file for Nmap scan"
            info "This may happen if the scope contains only wildcard domains"
            info "Try using a scope file with specific hostnames or IP addresses"
            return 0
        fi
        start_time=$(date +%s)
        
        # Build scan arguments based on host count
        if [[ $total_hosts -gt $NMAP_FAST_SCAN_THRESHOLD ]]; then
            warn "Large number of hosts detected ($total_hosts). Using faster scan settings."
            scan_type="fast"
            nmap_args=(
                "-iL" "$USERIN"
                "-T3"
                "-Pn"
                "--min-rate=500"
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
                "-T3"
                "-A"
                "-p" "$PORTS_TO_SCAN"
                "--version-intensity=4"
                "--max-rate=300"
                "-oA" "$POST_SCAN_ENUM/$NMAPOUT"
            )
        fi
        
        info "Using $scan_type scan profile for $total_hosts hosts"
        
        # Create temp file for progress monitoring
        progress_file=$(mktemp)
        debug "Creating progress monitoring process with temp file: $progress_file"
        
        # Set up signal handlers for the main process
        trap 'handle_signals TERM "$progress_pid" "$progress_file"' TERM
        trap 'handle_signals INT "$progress_pid" "$progress_file"' INT
        trap 'handle_signals HUP "$progress_pid" "$progress_file"' HUP
        (
            # Add trap for debugging process termination
            trap 'echo "[DEBUG] Progress monitor received signal - PID: $$" >> "$progress_file"' TERM INT
            
            debug_pid=$$
            echo "[DEBUG] Progress monitor started with PID: $debug_pid" >> "$progress_file"
            
            # Ensure the output directory exists
            mkdir -p "$POST_SCAN_ENUM" 2>/dev/null
            echo "[DEBUG] Ensuring output directory exists: $POST_SCAN_ENUM" >> "$progress_file"
            
            while true; do
                # Check if the process should exit (parent process might have terminated)
                if ! ps -p $PPID > /dev/null 2>&1; then
                    echo "[DEBUG] Parent process no longer exists, exiting progress monitor" >> "$progress_file"
                    exit 0
                fi
                
                if [[ -d "$POST_SCAN_ENUM" ]] && [[ -f "$POST_SCAN_ENUM/${NMAPOUT}.gnmap" ]]; then
                    scanned=$(grep -c "Host:" "$POST_SCAN_ENUM/${NMAPOUT}.gnmap" 2>/dev/null || echo 0)
                    scanned=$(echo "$scanned" | tr -d '\n')
                    current_time=$(date +%s)
                    elapsed=$((current_time - start_time))
                    percent=0
                    rate=0
                    if [[ $total_hosts -gt 0 ]] && [[ $scanned -ge 0 ]]; then
                        percent=$((scanned * 100 / total_hosts))
                        rate=$(( scanned / (elapsed + 1) ))
                    fi
                    info "Progress: $scanned/$total_hosts ($percent%) at $rate hosts/sec - Elapsed: ${elapsed}s"
                    echo "[DEBUG] Progress update: $scanned/$total_hosts ($percent%) at $rate hosts/sec - Elapsed: ${elapsed}s" >> "$progress_file"
                else
                    if [[ ! -d "$POST_SCAN_ENUM" ]]; then
                        echo "[DEBUG] Output directory does not exist: $POST_SCAN_ENUM" >> "$progress_file"
                        mkdir -p "$POST_SCAN_ENUM" 2>/dev/null
                    else
                        echo "[DEBUG] Waiting for gnmap file: $POST_SCAN_ENUM/${NMAPOUT}.gnmap" >> "$progress_file"
                    fi
                fi
                sleep 30
            done
        ) &
        progress_pid=$!
        debug "Progress monitoring process started with PID: $progress_pid"
        
        # Run the scan
        debug "Starting nmap scan with args: ${nmap_args[*]}"
        if ! nmap "${nmap_args[@]}" 2>"$progress_file.nmap_errors"; then
            debug "Nmap scan failed, checking error log: $progress_file.nmap_errors"
            cat "$progress_file.nmap_errors" >> "$progress_file"
            debug "Terminating progress monitor (PID: $progress_pid)"
            kill -TERM $progress_pid 2>/dev/null
            wait $progress_pid 2>/dev/null
            debug "Progress monitor termination result: $?"
            error "Nmap scan failed. See debug log for details." 1
            # Copy debug logs to output directory
            cp "$progress_file" "$POST_SCAN_ENUM/nmap_debug.log" 2>/dev/null
            info "Debug logs saved to: $POST_SCAN_ENUM/nmap_debug.log"
            return 1
        fi
        
        # Clean up progress monitoring with more robust error handling
        debug "Nmap scan completed successfully, terminating progress monitor (PID: $progress_pid)"
        
        # Check if process is still running
        if ps -p $progress_pid > /dev/null 2>&1; then
            debug "Progress monitor is still running, sending TERM signal"
            kill -TERM $progress_pid 2>/dev/null
            term_result=$?
            debug "TERM signal result: $term_result"
            
            # Give it a moment to terminate gracefully
            sleep 1
            
            # Check if it's still running after TERM
            if ps -p $progress_pid > /dev/null 2>&1; then
                debug "Progress monitor did not terminate with TERM, sending KILL signal"
                kill -KILL $progress_pid 2>/dev/null
                kill_result=$?
                debug "KILL signal result: $kill_result"
            else
                debug "Progress monitor terminated successfully with TERM signal"
            fi
        else
            debug "Progress monitor (PID: $progress_pid) is no longer running"
        fi
        
        # Wait for any child processes to complete
        wait $progress_pid 2>/dev/null
        wait_result=$?
        debug "Wait result for progress monitor: $wait_result"
        
        # Add process state information to debug log
        echo "[DEBUG] Process termination summary:" >> "$progress_file"
        echo "[DEBUG] Progress PID: $progress_pid" >> "$progress_file"
        echo "[DEBUG] Process state before termination:" >> "$progress_file"
        ps -p $progress_pid -o pid,ppid,stat,cmd 2>/dev/null >> "$progress_file" || echo "[DEBUG] Process not found in ps output" >> "$progress_file"
        
        # Copy debug logs to output directory
        mkdir -p "$POST_SCAN_ENUM" 2>/dev/null
        cp "$progress_file" "$POST_SCAN_ENUM/nmap_debug.log" 2>/dev/null
        info "Debug logs saved to: $POST_SCAN_ENUM/nmap_debug.log"
        
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
    
    # Reset signal handlers
    trap - TERM INT HUP
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
