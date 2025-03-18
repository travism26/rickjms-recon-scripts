#!/bin/bash

# Import required modules
source "$(dirname "${BASH_SOURCE[0]}")/../../core/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../api/rate_limiting.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../core/utils.sh"

# Run ASN enumeration using amass intel
run_asn_enum() {
    local USERIN="$1"
    debug "run_asn_enum($USERIN)"
    local ASNOUT="asn_enum.out"
    local temp_output
    local domain
    local org_name

    if isDryRun; then
        echo "Running ASN enumeration for domains in $USERIN"
    else
        info "Starting ASN enumeration for domains in $USERIN"
        
        # Create output directory if it doesn't exist
        mkdir -p "$SCAN_FOLDER/asn_intel"
        
        # Create temporary file for output
        temp_output=$(mktemp)
        
        # Process each domain
        while IFS= read -r domain; do
            info "Running ASN enumeration for: $domain"
            
            # Create domain-specific output files
            local domain_file="$SCAN_FOLDER/asn_intel/${domain}_asn.txt"
            local domain_cidr_file="$SCAN_FOLDER/asn_intel/${domain}_cidrs.txt"
            
            # Extract organization name from domain (simple heuristic)
            org_name=$(echo "$domain" | awk -F. '{print $(NF-1)}')
            
            echo "# ASN Enumeration Results for $domain" > "$domain_file"
            echo "# Generated on $(date)" >> "$domain_file"
            echo "" >> "$domain_file"
            
            # Find ASNs for the organization
            info "Finding ASNs for organization: $org_name"
            echo "## ASNs for organization: $org_name" >> "$domain_file"
            
            if skipAmass; then
                warn "Skipping amass for ASN enumeration (flag -a used)"
                echo "Amass scan skipped (flag -a used)" >> "$domain_file"
            elif amass intel -org "$org_name" 2>/dev/null | tee -a "$domain_file" | grep -q "ASN"; then
                info "Found ASNs for $org_name"
            else
                warn "No ASNs found for $org_name"
                echo "No ASNs found for $org_name" >> "$domain_file"
            fi
            
            echo "" >> "$domain_file"
            
            # Find domains from WHOIS records
            info "Finding domains from WHOIS records for: $domain"
            echo "## Domains from WHOIS records" >> "$domain_file"
            
            if skipAmass; then
                warn "Skipping amass for WHOIS lookup (flag -a used)"
                echo "Amass WHOIS lookup skipped (flag -a used)" >> "$domain_file"
            elif amass intel -d "$domain" -whois 2>/dev/null | tee -a "$domain_file" | grep -q "found"; then
                info "Found domains from WHOIS for $domain"
            else
                warn "No domains found from WHOIS for $domain"
                echo "No domains found from WHOIS for $domain" >> "$domain_file"
            fi
            
            echo "" >> "$domain_file"
            
            # Extract ASNs from the results
            grep "ASN:" "$domain_file" | awk '{print $2}' | sort -u > "$temp_output"
            
            # If ASNs were found, enumerate domains from those ASNs
            if [[ -s "$temp_output" ]]; then
                echo "## CIDRs for discovered ASNs" >> "$domain_file"
                
                while IFS= read -r asn; do
                    info "Enumerating CIDRs for ASN: $asn"
                    
                    if skipAmass; then
                        warn "Skipping amass for CIDR enumeration (flag -a used)"
                        echo "Amass CIDR enumeration skipped (flag -a used)" >> "$domain_cidr_file"
                    elif amass intel -asn "$asn" 2>/dev/null | tee -a "$domain_cidr_file" | grep -q "CIDR"; then
                        info "Found CIDRs for ASN $asn"
                    else
                        warn "No CIDRs found for ASN $asn"
                        echo "No CIDRs found for ASN $asn" >> "$domain_cidr_file"
                    fi
                done < "$temp_output"
                
                # Extract CIDRs
                grep "CIDR:" "$domain_cidr_file" | awk '{print $2}' | sort -u >> "$SCAN_FOLDER/asn_intel/all_cidrs.txt"
            fi
            
            echo "$domain" >> "$SCAN_FOLDER/$ASNOUT"
        done < "$USERIN"
        
        # Deduplicate all CIDRs
        if [[ -f "$SCAN_FOLDER/asn_intel/all_cidrs.txt" ]]; then
            sort -u "$SCAN_FOLDER/asn_intel/all_cidrs.txt" > "$SCAN_FOLDER/asn_intel/unique_cidrs.txt"
            local cidr_count=$(wc -l < "$SCAN_FOLDER/asn_intel/unique_cidrs.txt")
            info "Discovered $cidr_count unique CIDRs from ASN enumeration"
        fi
        
        # Clean up
        rm -f "$temp_output"
    fi
}

# Generate a report of all ASN findings
generate_asn_report() {
    local output_dir="$1"
    debug "generate_asn_report($output_dir)"
    
    if isDryRun; then
        echo "Generating ASN enumeration report in $output_dir"
    else
        local report_file="$output_dir/asn_report.md"
        
        {
            echo "# ASN Enumeration Report"
            echo "Generated on: $(date)"
            echo ""
            echo "## Overview"
            echo ""
            echo "This report contains information about Autonomous System Numbers (ASNs) and"
            echo "associated network ranges (CIDRs) discovered for the target domains."
            echo ""
            
            # Summary of findings
            echo "## Summary"
            echo ""
            
            local domain_count=0
            local asn_count=0
            local cidr_count=0
            
            if [[ -d "$SCAN_FOLDER/asn_intel" ]]; then
                domain_count=$(ls "$SCAN_FOLDER/asn_intel/"*_asn.txt 2>/dev/null | wc -l)
                asn_count=$(grep -h "ASN:" "$SCAN_FOLDER/asn_intel/"*_asn.txt 2>/dev/null | awk '{print $2}' | sort -u | wc -l)
                
                if [[ -f "$SCAN_FOLDER/asn_intel/unique_cidrs.txt" ]]; then
                    cidr_count=$(wc -l < "$SCAN_FOLDER/asn_intel/unique_cidrs.txt")
                fi
            fi
            
            echo "- Domains analyzed: $domain_count"
            echo "- Unique ASNs discovered: $asn_count"
            echo "- Unique CIDRs discovered: $cidr_count"
            echo ""
            
            # List all ASNs
            echo "## Discovered ASNs"
            echo ""
            
            if [[ -d "$SCAN_FOLDER/asn_intel" ]]; then
                grep -h "ASN:" "$SCAN_FOLDER/asn_intel/"*_asn.txt 2>/dev/null | sort -u | while read -r line; do
                    echo "- $line"
                done
            else
                echo "No ASNs discovered."
            fi
            
            echo ""
            
            # List top CIDRs
            echo "## Top CIDRs (by network size)"
            echo ""
            
            if [[ -f "$SCAN_FOLDER/asn_intel/unique_cidrs.txt" ]]; then
                # Sort CIDRs by network size (smaller prefix = larger network)
                sort -t/ -k2 -n "$SCAN_FOLDER/asn_intel/unique_cidrs.txt" | head -n 20 | while read -r cidr; do
                    echo "- $cidr"
                done
                
                if [[ $cidr_count -gt 20 ]]; then
                    echo "- ... and $(($cidr_count - 20)) more"
                fi
            else
                echo "No CIDRs discovered."
            fi
            
            echo ""
            echo "## Recommended Next Steps"
            echo ""
            echo "1. Use the discovered CIDRs for targeted port scanning"
            echo "2. Identify critical infrastructure within these networks"
            echo "3. Look for additional domains hosted on the same infrastructure"
            echo "4. Map the organization's network topology based on ASN information"
            
            # Add amass commands if they were skipped
            if skipAmass; then
                echo ""
                echo "## Manual Amass Commands"
                echo ""
                echo "Amass was skipped during this scan. If you want more comprehensive results, you can run these commands manually:"
                echo ""
                echo "```bash"
                echo "# For each domain in your target list:"
                
                if [[ -d "$SCAN_FOLDER/asn_intel" ]]; then
                    for domain_file in "$SCAN_FOLDER/asn_intel/"*_asn.txt; do
                        if [[ -f "$domain_file" ]]; then
                            domain=$(basename "$domain_file" _asn.txt)
                            org_name=$(echo "$domain" | awk -F. '{print $(NF-1)}')
                            
                            echo "# For domain: $domain"
                            echo "amass intel -org \"$org_name\"  # Find ASNs for organization"
                            echo "amass intel -d \"$domain\" -whois  # Find domains from WHOIS"
                            
                            # If we have ASNs in the file (from other sources), add commands for them
                            if grep -q "ASN:" "$domain_file"; then
                                echo "# For ASNs discovered through other means:"
                                grep "ASN:" "$domain_file" | awk '{print $2}' | sort -u | while read -r asn; do
                                    echo "amass intel -asn \"$asn\"  # Find CIDRs for ASN $asn"
                                done
                            fi
                            
                            echo ""
                        fi
                    done
                else
                    # If no domain files exist, provide generic examples
                    echo "amass intel -org \"organization_name\"  # Find ASNs for organization"
                    echo "amass intel -d \"example.com\" -whois  # Find domains from WHOIS"
                    echo "amass intel -asn \"AS12345\"  # Find CIDRs for a specific ASN"
                fi
                
                echo "```"
            fi
            
        } > "$report_file"
        
        info "ASN enumeration report generated: $report_file"
    fi
}
