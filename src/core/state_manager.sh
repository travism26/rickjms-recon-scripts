#!/bin/bash

# Import logging functions
source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

# State file paths
STATE_FILE=".recon_state.json"
STATE_FILE_BACKUP=".recon_state.json.bak"

# Initialize a new state file
init_state() {
    local output_dir="$1"
    local target_list="$2"
    local scan_mode="$3"
    
    debug "Initializing state file in $output_dir"
    
    # Generate a unique scan ID
    local scan_id=$(uuidgen || date +%s)
    local start_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Create scan mode object
    local scan_mode_json="{
        \"light_scan\": $(isLightScan && echo "true" || echo "false"),
        \"dry_run\": $(isDryRun && echo "true" || echo "false"),
        \"skip_wayback\": $(skipWaybackUrl && echo "true" || echo "false"),
        \"skip_amass\": $(skipAmass && echo "true" || echo "false")
    }"
    
    # Count total targets
    local total_targets=$(wc -l < "$target_list")
    
    # Create state file
    local state_content="{
        \"scan_id\": \"$scan_id\",
        \"start_time\": \"$start_time\",
        \"last_updated\": \"$start_time\",
        \"target_list\": \"$target_list\",
        \"output_dir\": \"$output_dir\",
        \"scan_mode\": $scan_mode_json,
        \"completed_scans\": [],
        \"current_scan\": \"\",
        \"scan_stats\": {
            \"total_targets\": $total_targets,
            \"processed_targets\": 0
        }
    }"
    
    # Write state file
    echo "$state_content" > "$output_dir/$STATE_FILE"
    
    # Create backup
    cp "$output_dir/$STATE_FILE" "$output_dir/$STATE_FILE_BACKUP"
    
    # Set permissions
    chmod 600 "$output_dir/$STATE_FILE" "$output_dir/$STATE_FILE_BACKUP"
    
    info "Initialized state file: $output_dir/$STATE_FILE"
    return 0
}

# Save current state
save_state() {
    local output_dir="$1"
    local current_scan="$2"
    local processed_targets="$3"
    
    debug "Saving state to $output_dir/$STATE_FILE"
    
    # Check if state file exists
    if [[ ! -f "$output_dir/$STATE_FILE" ]]; then
        error "State file not found: $output_dir/$STATE_FILE"
        return 1
    }
    
    # Create temporary file for atomic write
    local temp_file=$(mktemp)
    
    # Update last_updated timestamp
    local last_updated=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Update state file with jq
    jq ".last_updated = \"$last_updated\" | 
        .current_scan = \"$current_scan\" | 
        .scan_stats.processed_targets = $processed_targets" \
        "$output_dir/$STATE_FILE" > "$temp_file"
    
    # Atomic move
    mv "$temp_file" "$output_dir/$STATE_FILE"
    
    # Update backup
    cp "$output_dir/$STATE_FILE" "$output_dir/$STATE_FILE_BACKUP"
    
    info "State saved: current_scan=$current_scan, processed_targets=$processed_targets"
    return 0
}

# Mark a scan as completed
mark_completed() {
    local output_dir="$1"
    local scan_name="$2"
    
    debug "Marking scan as completed: $scan_name"
    
    # Check if state file exists
    if [[ ! -f "$output_dir/$STATE_FILE" ]]; then
        error "State file not found: $output_dir/$STATE_FILE"
        return 1
    }
    
    # Create temporary file for atomic write
    local temp_file=$(mktemp)
    
    # Update last_updated timestamp
    local last_updated=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Update state file with jq
    jq ".last_updated = \"$last_updated\" | 
        .completed_scans += [\"$scan_name\"] | 
        .current_scan = \"\"" \
        "$output_dir/$STATE_FILE" > "$temp_file"
    
    # Atomic move
    mv "$temp_file" "$output_dir/$STATE_FILE"
    
    # Update backup
    cp "$output_dir/$STATE_FILE" "$output_dir/$STATE_FILE_BACKUP"
    
    info "Scan marked as completed: $scan_name"
    return 0
}

# Load existing state
load_state() {
    local output_dir="$1"
    
    debug "Loading state from $output_dir/$STATE_FILE"
    
    # Check if state file exists
    if [[ ! -f "$output_dir/$STATE_FILE" ]]; then
        # Check if backup exists
        if [[ -f "$output_dir/$STATE_FILE_BACKUP" ]]; then
            warn "State file not found, but backup exists. Restoring from backup."
            cp "$output_dir/$STATE_FILE_BACKUP" "$output_dir/$STATE_FILE"
        else
            error "State file not found: $output_dir/$STATE_FILE"
            return 1
        fi
    }
    
    # Validate state file
    if ! validate_state "$output_dir"; then
        error "State file validation failed"
        return 1
    }
    
    # Load state into environment variables
    export SCAN_ID=$(jq -r '.scan_id' "$output_dir/$STATE_FILE")
    export TARGET_LIST=$(jq -r '.target_list' "$output_dir/$STATE_FILE")
    export COMPLETED_SCANS=$(jq -r '.completed_scans | join(",")' "$output_dir/$STATE_FILE")
    export CURRENT_SCAN=$(jq -r '.current_scan' "$output_dir/$STATE_FILE")
    export TOTAL_TARGETS=$(jq -r '.scan_stats.total_targets' "$output_dir/$STATE_FILE")
    export PROCESSED_TARGETS=$(jq -r '.scan_stats.processed_targets' "$output_dir/$STATE_FILE")
    
    # Load scan mode
    export LIGHT_SCAN=$(jq -r '.scan_mode.light_scan' "$output_dir/$STATE_FILE")
    export DRYRUN=$(jq -r '.scan_mode.dry_run' "$output_dir/$STATE_FILE")
    export SKIPWAYBACK=$(jq -r '.scan_mode.skip_wayback' "$output_dir/$STATE_FILE")
    export SKIPAMASS=$(jq -r '.scan_mode.skip_amass' "$output_dir/$STATE_FILE")
    
    info "State loaded: scan_id=$SCAN_ID, completed_scans=$COMPLETED_SCANS"
    return 0
}

# Validate state file integrity
validate_state() {
    local output_dir="$1"
    
    debug "Validating state file: $output_dir/$STATE_FILE"
    
    # Check if file is valid JSON
    if ! jq empty "$output_dir/$STATE_FILE" 2>/dev/null; then
        error "State file is not valid JSON"
        return 1
    }
    
    # Check required fields
    local required_fields=("scan_id" "start_time" "last_updated" "target_list" "output_dir" "scan_mode" "completed_scans" "scan_stats")
    for field in "${required_fields[@]}"; do
        if [[ $(jq "has(\"$field\")" "$output_dir/$STATE_FILE") != "true" ]]; then
            error "State file missing required field: $field"
            return 1
        fi
    done
    
    # Check if target_list file exists
    local target_list=$(jq -r '.target_list' "$output_dir/$STATE_FILE")
    if [[ ! -f "$target_list" ]]; then
        warn "Target list file not found: $target_list"
        return 1
    }
    
    # Check if output directory matches
    local state_output_dir=$(jq -r '.output_dir' "$output_dir/$STATE_FILE")
    if [[ "$state_output_dir" != "$output_dir" ]]; then
        warn "Output directory mismatch: $state_output_dir != $output_dir"
        # This is not a fatal error, but we should update the state file
        local temp_file=$(mktemp)
        jq ".output_dir = \"$output_dir\"" "$output_dir/$STATE_FILE" > "$temp_file"
        mv "$temp_file" "$output_dir/$STATE_FILE"
        info "Updated output directory in state file"
    }
    
    info "State file validation successful"
    return 0
}

# Check if a scan was completed
check_completed() {
    local scan_name="$1"
    
    debug "Checking if scan was completed: $scan_name"
    
    # Check if COMPLETED_SCANS is set
    if [[ -z "$COMPLETED_SCANS" ]]; then
        debug "COMPLETED_SCANS not set, scan not completed: $scan_name"
        return 1
    }
    
    # Check if scan is in completed scans
    if [[ "$COMPLETED_SCANS" == *"$scan_name"* ]]; then
        info "Scan already completed: $scan_name"
        return 0
    else
        debug "Scan not completed: $scan_name"
        return 1
    fi
}

# Update scan progress
update_state() {
    local output_dir="$1"
    local current_scan="$2"
    local processed_targets="$3"
    
    debug "Updating state: current_scan=$current_scan, processed_targets=$processed_targets"
    
    # Save state
    save_state "$output_dir" "$current_scan" "$processed_targets"
    
    return $?
}

# Clean up state files
cleanup_state() {
    local output_dir="$1"
    
    debug "Cleaning up state files in $output_dir"
    
    # Remove state files
    rm -f "$output_dir/$STATE_FILE" "$output_dir/$STATE_FILE_BACKUP"
    
    info "State files cleaned up"
    return 0
}

# Save progress for a specific scan
save_progress() {
    local output_dir="$1"
    local scan_name="$2"
    local processed_targets="$3"
    
    debug "Saving progress for $scan_name: $processed_targets/$TOTAL_TARGETS targets"
    
    # Update state
    update_state "$output_dir" "$scan_name" "$processed_targets"
    
    return $?
}
