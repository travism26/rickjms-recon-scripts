# Enhanced Recon System Implementation Guide

This guide provides a practical approach to implementing the enhanced reconnaissance system specified in `ENHANCED_RECON_SPEC.md`. It focuses on high-value components first and provides a step-by-step roadmap for development.

## Getting Started

### Prerequisites

Ensure you have the following tools installed:

```bash
# Check for required tools
./verify-tools.sh

# Install any missing dependencies
./install-rickjms-tools.sh
```

## Implementation Roadmap

### Phase 1: Core Infrastructure (Week 1)

1. **Setup Directory Structure**

```bash
# Create new directories
mkdir -p src/scanners/cloud
mkdir -p src/scanners/git
mkdir -p src/scanners/auth
mkdir -p src/scanners/logic
mkdir -p src/scanners/fuzzing
mkdir -p src/scanners/race
mkdir -p src/core/parallel
mkdir -p src/core/filter
mkdir -p src/core/validator
mkdir -p src/core/patterns
```

2. **Enhance Error Handling**

Extend the existing error handling in `src/core/utils.sh` with the global error handler:

```bash
# Add to src/core/utils.sh
handle_error() {
  local error_type=$1
  local error_message=$2
  local severity=${3:-"warning"}

  case $severity in
    "critical")
      log_error "[${error_type}] ${error_message}"
      cleanup
      exit 1
      ;;
    "warning")
      log_warning "[${error_type}] ${error_message}"
      return 1
      ;;
    "info")
      log_info "[${error_type}] ${error_message}"
      ;;
  esac
}
```

3. **Setup Configuration System**

Create a YAML-based configuration system:

```bash
# Install yq for YAML processing
brew install yq

# Create config template
cat > config/enhanced-recon.yaml << EOL
asset_discovery:
  cloud:
    enabled: true
    providers:
      - aws
      - azure
      - gcp
    rate_limit: 100
  api:
    enabled: true
    timeout: 30
    max_depth: 5
  git:
    enabled: true
    platforms:
      - github
      - gitlab
    token: ""

vulnerability_assessment:
  auth:
    enabled: true
    timeout: 60
    max_attempts: 3
  logic:
    enabled: true
    depth: 5
  fuzzing:
    enabled: true
    threads: 10
    patterns:
      - sql
      - xss
      - rce
  race:
    enabled: true
    threads: 5
    timeout: 30

optimization:
  parallel:
    max_threads: 20
    queue_size: 1000
  filter:
    enabled: true
    rules: rules.yaml
  validator:
    enabled: true
    confidence: 0.8
  patterns:
    enabled: true
    learn: true

logging:
  level: info
  file: recon.log
  rotate: true
  max_size: 100M
EOL

# Create config loader
cat > src/core/config.sh << EOL
#!/bin/bash

# Load configuration from YAML file
load_config() {
  local config_file=\${1:-"config/enhanced-recon.yaml"}

  if ! command -v yq &> /dev/null; then
    echo "Error: yq is required for configuration parsing"
    echo "Install with: brew install yq"
    return 1
  fi

  if [ ! -f "\$config_file" ]; then
    echo "Error: Configuration file not found: \$config_file"
    return 1
  fi

  # Export configuration as environment variables
  eval \$(yq eval 'to_entries | .[] | select(.value | type == "object") |
    .key + "_" + (.value | to_entries | .[] | select(.value | type != "object") |
    .key + "=\"" + (.value | tostring) + "\"")' \$config_file)

  # Handle nested objects
  eval \$(yq eval 'to_entries | .[] | select(.value | type == "object") |
    .key as \$parent | .value | to_entries | .[] | select(.value | type == "object") |
    \$parent + "_" + .key + "_" + (.value | to_entries | .[] | select(.value | type != "object") |
    .key + "=\"" + (.value | tostring) + "\"")' \$config_file)

  return 0
}
EOL

chmod +x src/core/config.sh
```

### Phase 2: High-Value Asset Discovery (Week 2)

1. **Implement Cloud Asset Discovery**

Create the S3 bucket scanner:

```bash
cat > src/scanners/cloud/s3_scanner.sh << EOL
#!/bin/bash

source src/core/utils.sh
source src/core/logging.sh
source src/core/config.sh

scan_s3_buckets() {
  local target=\$1
  local wordlist=\$2
  local output_file=\$3

  log_info "Starting S3 bucket scan for \$target"

  while read -r word; do
    local bucket_name="\${target}-\${word}"
    log_debug "Checking bucket: \$bucket_name"

    # Check if bucket exists
    if aws s3 ls "s3://\$bucket_name" 2>/dev/null; then
      log_success "Found bucket: \$bucket_name"
      echo "\$bucket_name" >> "\$output_file"

      # Check if bucket is public
      if aws s3api get-bucket-acl --bucket "\$bucket_name" | grep -q "AllUsers"; then
        log_warning "Bucket is public: \$bucket_name"
        echo "\$bucket_name,public" >> "\$output_file.public"
      fi
    fi
  done < "\$wordlist"

  log_info "S3 bucket scan completed for \$target"
}

# Main function
main() {
  local target=\$1
  local wordlist=\${2:-"wordlists/s3-buckets.txt"}
  local output_dir=\${3:-"output"}

  # Validate inputs
  validate_input "\$target" "Target is required"
  validate_file "\$wordlist" "Wordlist file not found"

  # Create output directory
  mkdir -p "\$output_dir"
  local output_file="\$output_dir/s3_buckets.txt"

  # Run scan
  scan_s3_buckets "\$target" "\$wordlist" "\$output_file"
}

# Execute if run directly
if [[ "\${BASH_SOURCE[0]}" == "\${0}" ]]; then
  main "\$@"
fi
EOL

chmod +x src/scanners/cloud/s3_scanner.sh
```

2. **Implement Git Intelligence**

Create the GitHub dork engine:

```bash
cat > src/scanners/git/github_dork.sh << EOL
#!/bin/bash

source src/core/utils.sh
source src/core/logging.sh
source src/core/config.sh

# GitHub dork patterns
declare -A GITHUB_DORKS=(
  ["api_key"]="filename:config api_key"
  ["password"]="filename:config password"
  ["secret"]="filename:config secret"
  ["token"]="filename:config token"
  ["aws_key"]="filename:.env AWS_ACCESS_KEY"
  ["private_key"]="extension:pem private"
  ["db_connection"]="filename:.env DB_"
  ["config_file"]="filename:config.json"
)

github_dork_search() {
  local target=\$1
  local output_file=\$2
  local token=\$3

  log_info "Starting GitHub dork search for \$target"

  for dork_name in "\${!GITHUB_DORKS[@]}"; do
    local dork_query="\${GITHUB_DORKS[\$dork_name]} \$target"
    log_debug "Running dork: \$dork_name with query: \$dork_query"

    # Use GitHub search API
    if [ -n "\$token" ]; then
      curl -s -H "Authorization: token \$token" \\
        "https://api.github.com/search/code?q=\$(echo \$dork_query | tr ' ' '+')" \\
        | jq -r '.items[] | "[\$dork_name] " + .html_url' >> "\$output_file"
    else
      # Rate-limited version without token
      curl -s "https://api.github.com/search/code?q=\$(echo \$dork_query | tr ' ' '+')" \\
        | jq -r '.items[] | "[\$dork_name] " + .html_url' >> "\$output_file"
      sleep 10  # Avoid rate limiting
    fi
  done

  log_info "GitHub dork search completed for \$target"
}

# Main function
main() {
  local target=\$1
  local output_dir=\${2:-"output"}
  local token=\${3:-""}

  # Load config if token not provided
  if [ -z "\$token" ]; then
    load_config
    token="\$git_token"
  fi

  # Validate inputs
  validate_input "\$target" "Target is required"

  # Create output directory
  mkdir -p "\$output_dir"
  local output_file="\$output_dir/github_dorks.txt"

  # Run search
  github_dork_search "\$target" "\$output_file" "\$token"
}

# Execute if run directly
if [[ "\${BASH_SOURCE[0]}" == "\${0}" ]]; then
  main "\$@"
fi
EOL

chmod +x src/scanners/git/github_dork.sh
```

3. **Enhance Domain Intelligence**

Extend the existing subdomain enumeration with permutation:

```bash
cat > src/scanners/passive/subdomain_permutation.sh << EOL
#!/bin/bash

source src/core/utils.sh
source src/core/logging.sh

# Generate permutations based on common patterns
generate_permutations() {
  local domain=\$1
  local output_file=\$2
  local wordlist=\$3

  log_info "Generating subdomain permutations for \$domain"

  # Extract domain parts
  local domain_parts=(\${domain//./ })
  local root_domain="\${domain_parts[-2]}.\${domain_parts[-1]}"

  # Common prefixes
  local prefixes=("dev" "stage" "test" "qa" "uat" "prod" "api" "admin" "portal" "app" "mobile" "m" "v1" "v2" "beta" "alpha")

  # Generate permutations
  for prefix in "\${prefixes[@]}"; do
    echo "\$prefix.\$root_domain" >> "\$output_file"
    echo "\$prefix-\${domain_parts[-2]}.\${domain_parts[-1]}" >> "\$output_file"
  done

  # Generate from wordlist if provided
  if [ -n "\$wordlist" ] && [ -f "\$wordlist" ]; then
    while read -r word; do
      echo "\$word.\$root_domain" >> "\$output_file"
    done < "\$wordlist"
  fi

  log_info "Generated \$(wc -l < "\$output_file") permutations"
}

# Main function
main() {
  local domain=\$1
  local output_dir=\${2:-"output"}
  local wordlist=\${3:-""}

  # Validate inputs
  validate_input "\$domain" "Domain is required"

  # Create output directory
  mkdir -p "\$output_dir"
  local output_file="\$output_dir/permutations.txt"

  # Generate permutations
  generate_permutations "\$domain" "\$output_file" "\$wordlist"

  # Resolve permutations
  if command -v massdns &> /dev/null; then
    log_info "Resolving permutations with massdns"
    massdns -r resolvers.txt -t A "\$output_file" -o S > "\$output_dir/resolved_permutations.txt"
  else
    log_warning "massdns not found, skipping resolution"
  fi
}

# Execute if run directly
if [[ "\${BASH_SOURCE[0]}" == "\${0}" ]]; then
  main "\$@"
fi
EOL

chmod +x src/scanners/passive/subdomain_permutation.sh
```

### Phase 3: High-Value Vulnerability Assessment (Week 3)

1. **Implement JWT Analyzer**

```bash
cat > src/scanners/auth/jwt_analyzer.sh << EOL
#!/bin/bash

source src/core/utils.sh
source src/core/logging.sh

analyze_jwt() {
  local token=\$1
  local output_file=\$2

  log_info "Analyzing JWT token"

  # Decode header
  local header=\$(echo "\$token" | cut -d. -f1 | base64 -d 2>/dev/null)
  log_debug "Header: \$header"

  # Decode payload
  local payload=\$(echo "\$token" | cut -d. -f2 | base64 -d 2>/dev/null)
  log_debug "Payload: \$payload"

  # Check for vulnerabilities

  # 1. Check algorithm
  if echo "\$header" | grep -q '"alg":"none"'; then
    log_warning "Vulnerable: Algorithm 'none' detected"
    echo "algorithm_none,high" >> "\$output_file"
  fi

  # 2. Check for weak signature
  if echo "\$header" | grep -q '"alg":"HS256"'; then
    log_info "HS256 algorithm detected, checking for weak signature"
    # Implement signature strength check
  fi

  # 3. Check expiration
  if ! echo "\$payload" | grep -q '"exp":'; then
    log_warning "Vulnerable: No expiration claim"
    echo "missing_expiration,medium" >> "\$output_file"
  fi

  log_info "JWT analysis completed"
}

# Main function
main() {
  local token=\$1
  local output_dir=\${2:-"output"}

  # Validate inputs
  validate_input "\$token" "JWT token is required"

  # Create output directory
  mkdir -p "\$output_dir"
  local output_file="\$output_dir/jwt_vulnerabilities.txt"

  # Run analysis
  analyze_jwt "\$token" "\$output_file"
}

# Execute if run directly
if [[ "\${BASH_SOURCE[0]}" == "\${0}" ]]; then
  main "\$@"
fi
EOL

chmod +x src/scanners/auth/jwt_analyzer.sh
```

2. **Implement Parameter Fuzzer**

```bash
cat > src/scanners/fuzzing/param_fuzzer.sh << EOL
#!/bin/bash

source src/core/utils.sh
source src/core/logging.sh

# Payload templates for different vulnerability types
declare -A PAYLOADS=(
  ["xss"]='<script>alert(1)</script>|<img src=x onerror=alert(1)>|javascript:alert(1)'
  ["sqli"]="'|' OR 1=1 --|1' OR '1'='1|1 UNION SELECT 1,2,3"
  ["rce"]='|ls|&cat /etc/passwd&|$(cat /etc/passwd)|`cat /etc/passwd`'
  ["lfi"]='../../../etc/passwd|../../../../etc/passwd|/etc/passwd'
  ["open_redirect"]='https://evil.com|//evil.com|javascript:alert(1)'
)

fuzz_parameters() {
  local url=\$1
  local output_file=\$2
  local vuln_types=\$3

  log_info "Starting parameter fuzzing for \$url"

  # Extract parameters from URL
  local params=()
  if [[ "\$url" == *"?"* ]]; then
    local query_string=\${url#*\?}
    IFS='&' read -ra param_pairs <<< "\$query_string"
    for pair in "\${param_pairs[@]}"; do
      params+=("\${pair%%=*}")
    done
  fi

  # If no parameters found, try common ones
  if [ \${#params[@]} -eq 0 ]; then
    params=("id" "page" "file" "url" "search" "q" "query" "redirect" "return" "returnUrl" "next")
    log_info "No parameters found in URL, using common parameters"
  fi

  log_debug "Parameters to fuzz: \${params[*]}"

  # Fuzz each parameter with payloads
  for param in "\${params[@]}"; do
    log_info "Fuzzing parameter: \$param"

    for vuln_type in \$(echo \$vuln_types | tr ',' ' '); do
      if [[ -z "\${PAYLOADS[\$vuln_type]}" ]]; then
        log_warning "Unknown vulnerability type: \$vuln_type"
        continue
      fi

      IFS='|' read -ra type_payloads <<< "\${PAYLOADS[\$vuln_type]}"

      for payload in "\${type_payloads[@]}"; do
        # Create test URL
        local test_url=\$url
        if [[ "\$url" == *"?"* ]]; then
          # URL already has parameters
          if [[ "\$url" == *"\$param="* ]]; then
            # Parameter exists, replace its value
            test_url=\$(echo "\$url" | sed "s/\$param=[^&]*/\$param=\$payload/g")
          else
            # Parameter doesn't exist, add it
            test_url="\$url&\$param=\$payload"
          fi
        else
          # URL has no parameters
          test_url="\$url?\$param=\$payload"
        fi

        log_debug "Testing: \$test_url"

        # Send request and check response
        local response=\$(curl -s -L -A "Mozilla/5.0" "\$test_url")

        # Check for indicators of vulnerability
        case \$vuln_type in
          "xss")
            if [[ "\$response" == *"\$payload"* ]]; then
              log_warning "Potential XSS found: \$test_url"
              echo "xss,\$param,\$payload,\$test_url" >> "\$output_file"
            fi
            ;;
          "sqli")
            if [[ "\$response" == *"SQL syntax"* || "\$response" == *"mysql_fetch"* || "\$response" == *"ORA-"* ]]; then
              log_warning "Potential SQL Injection found: \$test_url"
              echo "sqli,\$param,\$payload,\$test_url" >> "\$output_file"
            fi
            ;;
          "rce")
            if [[ "\$response" == *"root:"* || "\$response" == *"/bin/bash"* ]]; then
              log_warning "Potential RCE found: \$test_url"
              echo "rce,\$param,\$payload,\$test_url" >> "\$output_file"
            fi
            ;;
          "lfi")
            if [[ "\$response" == *"root:"* || "\$response" == *"/bin/bash"* ]]; then
              log_warning "Potential LFI found: \$test_url"
              echo "lfi,\$param,\$payload,\$test_url" >> "\$output_file"
            fi
            ;;
          "open_redirect")
            local redirect_url=\$(curl -s -L -I "\$test_url" | grep -i "location:" | tail -1 | awk '{print \$2}' | tr -d '\r')
            if [[ "\$redirect_url" == *"evil.com"* ]]; then
              log_warning "Potential Open Redirect found: \$test_url -> \$redirect_url"
              echo "open_redirect,\$param,\$payload,\$test_url,\$redirect_url" >> "\$output_file"
            fi
            ;;
        esac
      done
    done
  done

  log_info "Parameter fuzzing completed for \$url"
}

# Main function
main() {
  local url=\$1
  local output_dir=\${2:-"output"}
  local vuln_types=\${3:-"xss,sqli,rce,lfi,open_redirect"}

  # Validate inputs
  validate_input "\$url" "URL is required"

  # Create output directory
  mkdir -p "\$output_dir"
  local output_file="\$output_dir/fuzzing_results.txt"

  # Run fuzzing
  fuzz_parameters "\$url" "\$output_file" "\$vuln_types"
}

# Execute if run directly
if [[ "\${BASH_SOURCE[0]}" == "\${0}" ]]; then
  main "\$@"
fi
EOL

chmod +x src/scanners/fuzzing/param_fuzzer.sh
```

### Phase 4: Process Optimization (Week 4)

1. **Implement Parallel Execution Engine**

```bash
cat > src/core/parallel/executor.sh << EOL
#!/bin/bash

source src/core/utils.sh
source src/core/logging.sh
source src/core/config.sh

# Default values
DEFAULT_MAX_THREADS=10
DEFAULT_QUEUE_SIZE=100

# Initialize parallel execution
init_parallel() {
  local max_threads=\${1:-\$DEFAULT_MAX_THREADS}

  # Load config if available
  if load_config &>/dev/null; then
    max_threads=\${optimization_parallel_max_threads:-\$max_threads}
  fi

  # Create temporary directory for job control
  PARALLEL_TMP_DIR=\$(mktemp -d)
  PARALLEL_JOBS_DIR="\$PARALLEL_TMP_DIR/jobs"
  PARALLEL_RESULTS_DIR="\$PARALLEL_TMP_DIR/results"
  PARALLEL_RUNNING_DIR="\$PARALLEL_TMP_DIR/running"

  mkdir -p "\$PARALLEL_JOBS_DIR" "\$PARALLEL_RESULTS_DIR" "\$PARALLEL_RUNNING_DIR"

  # Set max threads
  echo \$max_threads > "\$PARALLEL_TMP_DIR/max_threads"

  log_info "Initialized parallel execution with max \$max_threads threads"

  # Start worker process
  parallel_worker &
  PARALLEL_WORKER_PID=\$!

  # Register cleanup on exit
  trap cleanup_parallel EXIT
}

# Add a job to the queue
add_job() {
  local job_id=\$(date +%s%N)
  local command="\$@"

  echo "\$command" > "\$PARALLEL_JOBS_DIR/\$job_id"

  log_debug "Added job \$job_id to queue: \$command"

  return 0
}

# Wait for all jobs to complete
wait_all_jobs() {
  log_info "Waiting for all jobs to complete..."

  while true; do
    local jobs_count=\$(ls -1 "\$PARALLEL_JOBS_DIR" 2>/dev/null | wc -l)
    local running_count=\$(ls -1 "\$PARALLEL_RUNNING_DIR" 2>/dev/null | wc -l)

    if [ "\$jobs_count" -eq 0 ] && [ "\$running_count" -eq 0 ]; then
      break
    fi

    log_debug "Jobs in queue: \$jobs_count, running: \$running_count"
    sleep 1
  done

  log_info "All jobs completed"
}

# Worker process that executes jobs
parallel_worker() {
  log_debug "Started parallel worker process"

  while true; do
    # Check if we should exit
    if [ -f "\$PARALLEL_TMP_DIR/stop" ]; then
      log_debug "Worker received stop signal"
      break
    fi

    # Get max threads
    local max_threads=\$(cat "\$PARALLEL_TMP_DIR/max_threads")

    # Count running jobs
    local running_count=\$(ls -1 "\$PARALLEL_RUNNING_DIR" 2>/dev/null | wc -l)

    # Process jobs if below max threads
    if [ "\$running_count" -lt "\$max_threads" ]; then
      # Get next job
      local next_job=\$(ls -1 "\$PARALLEL_JOBS_DIR" 2>/dev/null | head -1)

      if [ -n "\$next_job" ]; then
        # Move job to running
        mv "\$PARALLEL_JOBS_DIR/\$next_job" "\$PARALLEL_RUNNING_DIR/\$next_job"

        # Execute job
        local command=\$(cat "\$PARALLEL_RUNNING_DIR/\$next_job")
        log_debug "Executing job \$next_job: \$command"

        # Run in background
        (
          eval "\$command" > "\$PARALLEL_RESULTS_DIR/\$next_job.out" 2> "\$PARALLEL_RESULTS_DIR/\$next_job.err"
          echo \$? > "\$PARALLEL_RESULTS_DIR/\$next_job.exit"
          rm "\$PARALLEL_RUNNING_DIR/\$next_job"
        ) &
      fi
    fi

    # Sleep briefly
    sleep 0.1
  done
}

# Cleanup parallel execution
cleanup_parallel() {
  log_debug "Cleaning up parallel execution"

  # Signal worker to stop
  touch "\$PARALLEL_TMP_DIR/stop"

  # Wait for worker to exit
  if [ -n "\$PARALLEL_WORKER_PID" ]; then
    wait "\$PARALLEL_WORKER_PID" 2>/dev/null
  fi

  # Remove temporary directory
  if [ -d "\$PARALLEL_TMP_DIR" ]; then
    rm -rf "\$PARALLEL_TMP_DIR"
  fi
}

# Get results of all jobs
get_results() {
  local output_dir=\$1

  mkdir -p "\$output_dir"

  # Copy all results
  if [ -d "\$PARALLEL_RESULTS_DIR" ]; then
    cp "\$PARALLEL_RESULTS_DIR"/*.out "\$output_dir/" 2>/dev/null
    cp "\$PARALLEL_RESULTS_DIR"/*.err "\$output_dir/" 2>/dev/null
    cp "\$PARALLEL_RESULTS_DIR"/*.exit "\$output_dir/" 2>/dev/null
  fi
}

# Main function
main() {
  local command=\$1
  shift

  case "\$command" in
    "init")
      init_parallel "\$@"
      ;;
    "add")
      add_job "\$@"
      ;;
    "wait")
      wait_all_jobs
      ;;
    "results")
      get_results "\$@"
      ;;
    "cleanup")
      cleanup_parallel
      ;;
    *)
      echo "Usage: \$0 {init|add|wait|results|cleanup}"
      return 1
      ;;
  esac
}

# Execute if run directly
if [[ "\${BASH_SOURCE[0]}" == "\${0}" ]]; then
  main "\$@"
fi
EOL

chmod +x src/core/parallel/executor.sh
```

2. **Create Integration Script**

```bash
cat > enhanced-recon.sh << EOL
#!/bin/bash

# Enhanced Reconnaissance Script
# Based on the specification in ENHANCED_RECON_SPEC.md

source src/core/utils.sh
source src/core/logging.sh
source src/core/config.sh
source src/core/parallel/executor.sh

# Display banner
display_banner() {
  echo "
  ███████╗███╗   ██╗██╗  ██╗ █████╗ ███╗   ██╗ ██████╗███████╗██████╗
  ██╔════╝████╗  ██║██║  ██║██╔══██╗████╗  ██║██╔════╝██╔════╝██╔══██╗
  █████╗  ██╔██╗ ██║███████║███████║██╔██╗ ██║██║     █████╗  ██║  ██║
  ██╔══╝  ██║╚██╗██║██╔══██║██╔══██║██║╚██╗██║██║     ██╔══╝  ██║  ██║
  ███████╗██║ ╚████║██║  ██║██║  ██║██║ ╚████║╚██████╗███████╗██████╔╝
  ╚══════╝╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝╚══════╝╚═════╝

  ██████╗ ███████╗ ██████╗ ██████╗ ███╗   ██╗
  ██╔══██╗██╔════╝██╔════╝██╔═══██╗████╗  ██║
  ██████╔╝█████╗  ██║     ██║   ██║██╔██╗ ██║
  ██╔══██╗██╔══╝  ██║     ██║   ██║██║╚██╗██║
  ██║  ██║███████╗╚██████╗╚██████╔╝██║ ╚████║
  ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝
  "
  echo "Enhanced Reconnaissance System v1.0"
  echo "-----------------------------------"
}

# Display help
display_help() {
  echo "Usage: \$0 [options]"
  echo ""
  echo "Options:"
  echo "  -h                    Display help menu"
  echo "  -t TARGET             Run recon against single domain"
  echo "  -f FILENAME           Run recon with file of target domains"
  echo "  -o PATH/TO/OUTPUT     Change the output directory (default: current directory)"
  echo "  -c CONFIG_FILE        Specify custom config file"
  echo "  -m MODULE             Run specific module (cloud, git, auth, fuzzing)"
  echo "  -l                    Light scan mode (quick scans only)"
  echo "  -d                    Enable Debugging mode"
  echo "  -s                    Silent Mode (suppress output)"
  echo "  -r                    Resume from last saved state"
  echo ""
}

# Main function
main() {
  local target=""
  local target_file=""
  local output_dir="output"
  local config_file="config/enhanced-recon.yaml"
  local module=""
  local light_mode=false
  local debug_mode=false
  local silent_mode=false
  local resume_mode=false

  # Parse command line arguments
  while getopts "ht:f:o:c:m:ldsr" opt; do
    case $opt in
      h)
        display_help
        exit 0
        ;;
      t)
        target="$OPTARG"
        ;;
      f)
        target_file="$OPTARG"
        ;;
      o)
        output_dir="$OPTARG"
        ;;
      c)
        config_file="$OPTARG"
        ;;
      m)
        module="$OPTARG"
        ;;
      l)
        light_mode=true
        ;;
      d)
        debug_mode=true
        ;;
      s)
        silent_mode=true
        ;;
      r)
        resume_mode=true
        ;;
      \?)
        echo "Invalid option: -$OPTARG" >&2
        display_help
        exit 1
        ;;
    esac
  done

  # Display banner
  display_banner

  # Set logging level
  if $debug_mode; then
    set_log_level "debug"
  elif $silent_mode; then
    set_log_level "error"
  else
    set_log_level "info"
  fi

  # Load configuration
  log_info "Loading configuration from $config_file"
  if ! load_config "$config_file"; then
    log_error "Failed to load configuration"
    exit 1
  fi

  # Validate inputs
  if [ -z "$target" ] && [ -z "$target_file" ]; then
    log_error "No target specified. Use -t for a single domain or -f for a file of domains."
    display_help
    exit 1
  fi

  # Create output directory
  mkdir -p "$output_dir"

  # Initialize parallel execution
  init_parallel

  # Process targets
  if [ -n "$target" ]; then
    log_info "Starting reconnaissance on target: $target"
    process_target "$target" "$output_dir" "$module" "$light_mode" "$resume_mode"
  elif [ -n "$target_file" ]; then
    log_info "Starting reconnaissance on targets from file: $target_file"
    if [ ! -f "$target_file" ]; then
      log_error "Target file not found: $target_file"
      exit 1
    fi

    while read -r domain; do
      # Skip empty lines and comments
      if [ -z "$domain" ] || [[ "$domain" == \#* ]]; then
        continue
      fi

      log_info "Processing target: $domain"
      process_target "$domain" "$output_dir/$domain" "$module" "$light_mode" "$resume_mode"
    done < "$target_file"
  fi

  # Wait for all jobs to complete
  wait_all_jobs

  # Generate report
  log_info "Generating report"
  generate_report "$output_dir"

  log_success "Reconnaissance completed successfully"
}

# Process a single target
process_target() {
  local target=$1
  local output_dir=$2
  local module=$3
  local light_mode=$4
  local resume_mode=$5

  # Create target output directory
  mkdir -p "$output_dir"

  # Check if we should resume
  if $resume_mode; then
    if [ -f "$output_dir/state.json" ]; then
      log_info "Resuming from saved state"
    else
      log_warning "No saved state found, starting fresh"
      resume_mode=false
    fi
  fi

  # Run modules based on configuration and command line options
  if [ -z "$module" ] || [ "$module" = "cloud" ]; then
    if [ "$asset_discovery_cloud_enabled" = "true" ]; then
      log_info "Running cloud asset discovery"

      # Skip if already completed in resume mode
      if ! $resume_mode || ! grep -q "cloud_completed" "$output_dir/state.json" 2>/dev/null; then
        # Add job to queue
        add_job "src/scanners/cloud/s3_scanner.sh \"$target\" \"wordlists/s3-buckets.txt\" \"$output_dir/cloud\""

        # Mark as completed for resume mode
        if [ -f "$output_dir/state.json" ]; then
          sed -i 's/"cloud_completed": false/"cloud_completed": true/' "$output_dir/state.json"
        else
          echo '{"cloud_completed": true}' > "$output_dir/state.json"
        fi
      else
        log_info "Skipping cloud asset discovery (already completed)"
      fi
    fi
  fi

  if [ -z "$module" ] || [ "$module" = "git" ]; then
    if [ "$asset_discovery_git_enabled" = "true" ]; then
      log_info "Running git intelligence"

      # Skip if already completed in resume mode
      if ! $resume_mode || ! grep -q "git_completed" "$output_dir/state.json" 2>/dev/null; then
        # Add job to queue
        add_job "src/scanners/git/github_dork.sh \"$target\" \"$output_dir/git\""

        # Mark as completed for resume mode
        if [ -f "$output_dir/state.json" ]; then
          sed -i 's/"git_completed": false/"git_completed": true/' "$output_dir/state.json"
        else
          echo '{"git_completed": true}' > "$output_dir/state.json"
        fi
      else
        log_info "Skipping git intelligence (already completed)"
      fi
    fi
  fi

  # Add more modules here...
}

# Generate final report
generate_report() {
  local output_dir=$1

  log_info "Generating report in $output_dir"

  # Create report directory
  mkdir -p "$output_dir/report"

  # Create markdown report
  cat > "$output_dir/report/report.md" << EOF
# Enhanced Reconnaissance Report

## Overview

- Target(s): $(find "$output_dir" -maxdepth 1 -type d | grep -v "report" | grep -v "^$output_dir$" | xargs basename | tr '\n' ', ')
- Scan Date: $(date)
- Scan Duration: $(if [ -f "$output_dir/start_time" ]; then echo $(($(date +%s) - $(cat "$output_dir/start_time"))); else echo "Unknown"; fi) seconds

## Summary of Findings

### Cloud Assets

$(if [ -d "$output_dir/cloud" ]; then
  echo "- S3 Buckets: $(find "$output_dir" -name "s3_buckets.txt" | xargs cat | wc -l)"
  echo "- Public S3 Buckets: $(find "$output_dir" -name "s3_buckets.txt.public" | xargs cat 2>/dev/null | wc -l || echo "0")"
else
  echo "- No cloud asset scan performed"
fi)

### Git Intelligence

$(if [ -d "$output_dir/git" ]; then
  echo "- GitHub Findings: $(find "$output_dir" -name "github_dorks.txt" | xargs cat | wc -l)"
else
  echo "- No git intelligence scan performed"
fi)

### Vulnerabilities

$(if [ -d "$output_dir/auth" ]; then
  echo "- JWT Vulnerabilities: $(find "$output_dir" -name "jwt_vulnerabilities.txt" | xargs cat | wc -l)"
else
  echo "- No authentication testing performed"
fi)

$(if [ -d "$output_dir/fuzzing" ]; then
  echo "- Fuzzing Findings: $(find "$output_dir" -name "fuzzing_results.txt" | xargs cat | wc -l)"
  if [ -f "$output_dir/fuzzing/fuzzing_results.txt" ]; then
    echo "  - XSS: $(grep "xss," "$output_dir/fuzzing/fuzzing_results.txt" | wc -l)"
    echo "  - SQL Injection: $(grep "sqli," "$output_dir/fuzzing/fuzzing_results.txt" | wc -l)"
    echo "  - RCE: $(grep "rce," "$output_dir/fuzzing/fuzzing_results.txt" | wc -l)"
    echo "  - LFI: $(grep "lfi," "$output_dir/fuzzing/fuzzing_results.txt" | wc -l)"
    echo "  - Open Redirect: $(grep "open_redirect," "$output_dir/fuzzing/fuzzing_results.txt" | wc -l)"
  fi
else
  echo "- No fuzzing performed"
fi)

## Detailed Findings

EOF

  # Add detailed findings
  if [ -d "$output_dir/cloud" ]; then
    echo "### Cloud Assets" >> "$output_dir/report/report.md"
    echo "" >> "$output_dir/report/report.md"
    echo "#### S3 Buckets" >> "$output_dir/report/report.md"
    echo "" >> "$output_dir/report/report.md"
    echo "| Bucket | Public |" >> "$output_dir/report/report.md"
    echo "|--------|--------|" >> "$output_dir/report/report.md"

    for bucket_file in $(find "$output_dir" -name "s3_buckets.txt"); do
      while read -r bucket; do
        if grep -q "$bucket,public" "$(dirname "$bucket_file")/s3_buckets.txt.public" 2>/dev/null; then
          echo "| $bucket | Yes |" >> "$output_dir/report/report.md"
        else
          echo "| $bucket | No |" >> "$output_dir/report/report.md"
        fi
      done < "$bucket_file"
    done

    echo "" >> "$output_dir/report/report.md"
  fi

  # Convert to HTML if pandoc is available
  if command -v pandoc &> /dev/null; then
    log_info "Converting report to HTML"
    pandoc -s "$output_dir/report/report.md" -o "$output_dir/report/report.html"
  else
    log_warning "pandoc not found, skipping HTML report generation"
  fi

  log_success "Report generated successfully"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Record start time
  echo $(date +%s) > "$(dirname "$0")/output/start_time"

  main "$@"
fi
EOL

chmod +x enhanced-recon.sh
```

## Usage Guide

### Basic Usage

Once you've implemented the components described in this guide, you can use the enhanced recon system as follows:

```bash
# Scan a single domain
./enhanced-recon.sh -t example.com

# Scan multiple domains from a file
./enhanced-recon.sh -f domains.txt

# Run a specific module
./enhanced-recon.sh -t example.com -m cloud

# Use a custom output directory
./enhanced-recon.sh -t example.com -o /path/to/output

# Enable debug mode
./enhanced-recon.sh -t example.com -d

# Resume an interrupted scan
./enhanced-recon.sh -t example.com -o /path/to/output -r
```

### Advanced Usage

#### Cloud Asset Discovery

```bash
# Run S3 bucket scanner directly
src/scanners/cloud/s3_scanner.sh example.com wordlists/s3-buckets.txt output/cloud
```

#### Git Intelligence

```bash
# Run GitHub dork scanner directly
src/scanners/git/github_dork.sh example.com output/git
```

#### Authentication Testing

```bash
# Analyze a JWT token
src/scanners/auth/jwt_analyzer.sh "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U" output/auth
```

#### Parameter Fuzzing

```bash
# Fuzz parameters on a URL
src/scanners/fuzzing/param_fuzzer.sh "https://example.com/search?q=test" output/fuzzing "xss,sqli"
```

### Parallel Execution

```bash
# Initialize parallel execution
source src/core/parallel/executor.sh
init_parallel 10

# Add jobs to queue
add_job "src/scanners/cloud/s3_scanner.sh example.com wordlists/s3-buckets.txt output/cloud"
add_job "src/scanners/git/github_dork.sh example.com output/git"

# Wait for all jobs to complete
wait_all_jobs

# Get results
get_results output/results
```

## Next Steps

After implementing the core components outlined in this guide, consider the following enhancements:

1. **Add More Scanners**

   - Implement Azure Blob and GCP Storage scanners
   - Add GraphQL introspection scanner
   - Implement business logic testing modules

2. **Improve Reporting**

   - Add visualization of results
   - Implement severity scoring
   - Create executive summary reports

3. **Enhance Automation**

   - Implement smart scope filtering
   - Add pattern-based target prioritization
   - Develop automated validation of findings

4. **Integration with Other Tools**
   - Add integration with vulnerability tracking systems
   - Implement notification mechanisms (Slack, Email, etc.)
   - Create API for programmatic access

By following this implementation guide, you'll have a solid foundation for an enhanced reconnaissance system that can significantly improve your bug bounty effectiveness.
