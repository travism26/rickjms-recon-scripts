# Continue Feature Specification

## Overview

The continue feature allows users to resume reconnaissance scans that were interrupted (e.g., via Ctrl+C), preserving progress and avoiding redundant work. This document outlines the technical specifications for implementing this feature.

## Requirements

### Functional Requirements

1. Save scan progress when interrupted via Ctrl+C
2. Resume scans from last saved state
3. Skip previously completed scan modules
4. Maintain output directory structure integrity
5. Support all existing scan modes (light scan, dry run, etc.)

### Non-Functional Requirements

1. Minimal performance overhead during normal operation
2. Atomic state file operations to prevent corruption
3. Backward compatibility with existing scan outputs
4. Clear error messaging for state-related issues

## Technical Design

### State Management

#### State File Structure

```json
{
  "scan_id": "uuid-v4",
  "start_time": "ISO-8601-timestamp",
  "last_updated": "ISO-8601-timestamp",
  "target_list": "/path/to/target/list",
  "output_dir": "/path/to/output",
  "scan_mode": {
    "light_scan": false,
    "dry_run": false,
    "skip_wayback": false,
    "skip_amass": false
  },
  "completed_scans": ["crtsh", "tls_bufferover"],
  "current_scan": "waybackurls",
  "scan_stats": {
    "total_targets": 10,
    "processed_targets": 5
  }
}
```

#### State File Location

- Primary: `$OUTPUT_DIR/.recon_state.json`
- Backup: `$OUTPUT_DIR/.recon_state.json.bak`

### Architecture Changes

#### New Command Line Flag

```bash
-r, --resume    Resume from last saved state
```

#### Core Components

1. State Manager (`src/core/state_manager.sh`)

```bash
# Key functions
init_state()          # Initialize new state file
save_state()          # Save current state
load_state()          # Load existing state
update_state()        # Update scan progress
validate_state()      # Verify state integrity
cleanup_state()       # Remove state files on completion
```

2. Signal Handler (`src/core/utils.sh` additions)

```bash
handle_interrupt() {
    save_state
    cleanup
    exit 1
}
```

3. Scanner Modifications

```bash
# Each scanner function needs:
check_completed()     # Check if scan was completed
mark_completed()      # Mark scan as completed
save_progress()       # Save intermediate progress
```

### Implementation Details

#### State File Operations

1. Use `jq` for JSON manipulation
2. Implement atomic writes using temporary files
3. Maintain backup copy of state file
4. Use file locking for concurrent access protection

#### Resume Process Flow

1. Validate state file existence and integrity
2. Compare stored configuration with current flags
3. Verify output directory structure
4. Skip completed scan modules
5. Resume from last recorded position

#### Error Handling

1. State File Errors

   - Missing state file
   - Corrupted state file
   - Version mismatch
   - Configuration mismatch

2. Recovery Strategies
   - Automatic backup restoration
   - Partial progress recovery
   - Clean restart option

#### Logging Enhancements

1. State operation logging
2. Resume operation logging
3. Progress indicators
4. Error condition logging

## Testing Strategy

### Unit Tests

1. State File Operations

   - Create/read/update/delete operations
   - JSON structure validation
   - Atomic write verification
   - Backup mechanism

2. Signal Handling
   - Ctrl+C interrupt handling
   - State preservation verification
   - Cleanup procedure validation

### Integration Tests

1. Resume Scenarios

   - Resume after passive recon
   - Resume during active recon
   - Resume with different scan modes

2. Error Handling

   - Corrupted state file recovery
   - Missing directory handling
   - Permission issues

3. Edge Cases
   - Zero targets
   - Very large target lists
   - Network interruptions

### Performance Tests

1. State Operation Overhead
   - Measure impact on scan time
   - File I/O performance
   - Memory usage

### Test Cases Matrix

| Test Category   | Test Case                   | Expected Result                    |
| --------------- | --------------------------- | ---------------------------------- |
| Basic Resume    | Interrupt during crtsh scan | Resume from next uncompleted scan  |
| State Integrity | Corrupt state file          | Fallback to backup or clean start  |
| Configuration   | Changed scan mode           | Warning and confirmation prompt    |
| Performance     | 1000+ targets               | < 1% overhead for state operations |

## Implementation Plan

### Phase 1: Core Infrastructure

1. Implement state manager
2. Add signal handling
3. Create state file structure
4. Add basic resume flag

### Phase 2: Scanner Integration

1. Modify scanner modules
2. Add progress tracking
3. Implement state checks
4. Add completion marking

### Phase 3: Error Handling

1. Implement validation
2. Add recovery mechanisms
3. Enhance logging
4. Add user notifications

### Phase 4: Testing

1. Write test suite
2. Perform integration testing
3. Run performance tests
4. Document edge cases

## Dependencies

- jq (JSON processor)
- mktemp (Atomic file operations)
- flock (File locking)

## Security Considerations

1. State file permissions (600)
2. Sensitive data handling
3. Backup file security
4. Clean state file removal

## Documentation Requirements

1. Update main README.md
2. Add continue feature usage guide
3. Document recovery procedures
4. Update error message guide

## Migration Guide

1. Backup existing scan outputs
2. Install required dependencies
3. Update script version
4. No database migrations required

## Rollback Plan

1. Revert core script changes
2. Remove state files
3. Restore original signal handlers
4. Update version number

## Success Criteria

1. Successfully resume interrupted scans
2. No data loss on interruption
3. Minimal performance impact
4. Clear user feedback
5. All tests passing

## Future Enhancements

1. Web interface for progress monitoring
2. Multiple save states
3. Branching scan paths
4. Cloud state synchronization
