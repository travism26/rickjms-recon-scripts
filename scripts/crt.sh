#!/bin/bash

# This script will be used to pull domains from crt.sh

# Get all domains from crt.sh
curl -s "https://crt.sh/?q=%.$1&output=json" | jq -r '.[] | .name_value' | sed 's/\*\.//g' | sort -u

# How can we get all the unique subdomains from crt.sh?
# cat OUTPUTFILE.txt | rev | cut -d "." -f 1,2 | rev | sort -u > subdomains.txt

