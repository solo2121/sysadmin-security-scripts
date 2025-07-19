#!/bin/bash

# Amass Automation Script
# Usage: ./amass-scan.sh <domain> [output-dir]

if [ $# -lt 1 ]; then
    echo "Usage: $0 <domain> [output-dir]"
    echo "Example: $0 example.com amass-results"
    exit 1
fi

DOMAIN="$1"
OUTPUT_DIR="${2:-amass-scan-$(date +%Y%m%d-%H%M%S)}"

echo "[*] Creating output directory: $OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

echo "[*] Starting Amass enumeration for domain: $DOMAIN"

# Passive enumeration (no active probing)
amass enum -passive -d "$DOMAIN" -o "$OUTPUT_DIR/passive.txt"

# Active enumeration with brute forcing and DNS resolution
amass enum -active -brute -d "$DOMAIN" -o "$OUTPUT_DIR/active.txt"

# Full enumeration with all techniques and output in JSON and text
amass enum -d "$DOMAIN" -o "$OUTPUT_DIR/full.txt" -json "$OUTPUT_DIR/full.json"

echo "[+] Amass scan completed. Results saved in $OUTPUT_DIR/"
