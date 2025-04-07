# Target Processing Module

The Target Processing Module provides standardized handling of target inputs across all tools in the rickjms-recon-scripts framework. It ensures that each tool receives targets in the format it expects, regardless of how the targets were initially provided.

## Features

- Consistent target format validation
- Tool-specific target formatting
- Wildcard domain handling
- Protocol handling (http/https)
- Port specification handling
- Subdomain depth validation
- Batch processing of target lists

## Configuration

Tool-specific configurations are defined in `config/target_processing.conf`. Each tool can have the following settings:

```ini
[tool_name]
require_protocol=true|false   # Whether the tool requires http(s):// prefix
handle_wildcards=true|false   # Whether to process wildcard domains (*.example.com)
allow_ports=true|false        # Whether to allow port specifications (example.com:8080)
strip_www=true|false          # Whether to remove www. prefix
validate_dns=true|false       # Whether to perform DNS validation
max_depth=5                   # Maximum subdomain depth allowed
```

## Usage

### In Scanner Modules

```bash
# Import the module
source "$(dirname "${BASH_SOURCE[0]}")/../../core/target_processing.sh"

# Process a single target for a specific tool
processed_target=$(process_target "$input_target" "tool_name")
if [[ $? -eq 0 ]]; then
    # Use processed target
    echo "Processed target: $processed_target"
else
    # Handle invalid target
    echo "Invalid target format"
fi

# Process a list of targets
process_target_list "$input_file" "$output_file" "tool_name"
```

### In Main Script

The main script uses the target processing module to create tool-specific target lists:

```bash
# Create master target list
TARGET_LIST="$OUTPUT_DIR/targets/master_target_list.txt"
process_target_list "$RAW_TARGET_LIST" "$TARGET_LIST" "default"

# Create tool-specific target lists
for tool in "${TOOLS[@]}"; do
    local tool_target_list="$OUTPUT_DIR/targets/${tool}_targets.txt"
    process_target_list "$TARGET_LIST" "$tool_target_list" "$tool"
done
```

## Target Format Examples

| Original Target     | Tool    | Processed Target         |
| ------------------- | ------- | ------------------------ |
| example.com         | default | example.com              |
| example.com         | httpx   | https://example.com      |
| https://example.com | crtsh   | example.com              |
| \*.example.com      | crtsh   | example.com              |
| example.com:8080    | httpx   | https://example.com:8080 |
| example.com:8080    | crtsh   | example.com              |
| www.example.com     | default | example.com              |

## Testing

You can test the target processing module using the provided test scripts:

```bash
# Run the test suite
./tests/target_processing/test_target_processing.sh

# Run the demo script
./tests/target_processing/demo.sh
```

## Implementation Details

The module provides the following key functions:

- `process_target`: Process a single target for a specific tool
- `process_target_list`: Process a list of targets for a specific tool
- `validate_target`: Validate a target format
- `strip_protocol`: Remove http(s):// prefix
- `add_protocol`: Add http(s):// prefix
- `process_wildcards`: Handle wildcard domains
- `extract_port`: Extract port from target
- `strip_port`: Remove port from target
- `validate_port`: Validate port number
- `normalize_domain`: Normalize domain format

## Benefits

- Eliminates inconsistent target handling across tools
- Reduces errors from incompatible target formats
- Simplifies scanner module implementation
- Provides centralized configuration for all tools
- Makes it easier to add new tools with different requirements
