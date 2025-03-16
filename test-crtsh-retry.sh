#!/bin/bash

# Set the base directory for the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Import required modules
source "$SCRIPT_DIR/src/core/logging.sh"
source "$SCRIPT_DIR/src/core/utils.sh"
source "$SCRIPT_DIR/src/scanners/api/rate_limiting.sh"

# Enable debug logging
export ENABLE_DEBUG=1

# Define the retry_curl function directly for testing
retry_curl() {
    local cmd="$1"
    local max_retries="${2:-3}"  # Default to 3 retries
    local retry_delay="${3:-2}"  # Default to 2 seconds delay for faster testing
    local attempt=1
    local response=""
    local status=0
    
    echo "Testing retry functionality with command: $cmd"
    echo "Max retries: $max_retries, Initial delay: $retry_delay seconds"
    
    while [ $attempt -le $max_retries ]; do
        echo "Attempt $attempt of $max_retries..."
        response=$(eval "$cmd")
        status=$?
        
        echo "Command status: $status, Response length: ${#response}"
        
        # Check if curl command was successful and response has enough content
        if [ $status -eq 0 ] && [ ${#response} -gt 3 ]; then
            # Extract HTTP code from the end of the response
            http_code=${response: -3}
            
            echo "HTTP code: $http_code"
            
            # Verify that http_code is a valid number
            if [[ "$http_code" =~ ^[0-9]+$ ]] && [ "$http_code" -eq 200 ]; then
                # Success - return the response
                echo "Success! Got valid response."
                return 0
            fi
        fi
        
        # If we get here, the request failed
        if [ $attempt -lt $max_retries ]; then
            echo "Attempt $attempt failed. Retrying in $retry_delay seconds..."
            sleep $retry_delay
            # Increase delay for next attempt (exponential backoff)
            retry_delay=$((retry_delay * 2))
        else
            # Last attempt failed
            echo "All $max_retries attempts failed."
        fi
        
        ((attempt++))
    done
    
    # If we get here, all retries failed
    return 1
}

# Test with a deliberately failing command
echo "Test 1: Command that will always fail (non-existent URL)"
retry_curl "curl -s -w \"%{http_code}\" --max-time 2 \"https://nonexistent-domain-that-will-fail.xyz\""

echo ""
echo "Test 2: Command with timeout that should fail"
retry_curl "curl -s -w \"%{http_code}\" --max-time 1 \"https://crt.sh/?q=%.shopify.com&output=json\""

echo ""
echo "Test 3: Command that should eventually succeed"
retry_curl "curl -s -w \"%{http_code}\" --max-time 30 \"https://crt.sh/?q=%.example.com&output=json\""

echo "All tests completed."
