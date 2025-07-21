#!/bin/bash
# Amass Automation Script - Comprehensive domain enumeration tool

###############################################################################
# Script Metadata
###############################################################################
# Title: Amass Automation Script
# Description: Automated domain enumeration using OWASP Amass with multiple scan types
# Author: Solo
# Version: 1.1.0
# License: MIT
# Last Modified: 2025-07-21
# Usage: ./amass-scan.sh <domain> [output-dir]
# Dependencies: amass, jq (for JSON processing)

###############################################################################
# Configuration
###############################################################################
VERSION="1.1.0"
DEFAULT_SCANS=("passive" "active" "full")  # Default scan types to perform
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_LEVEL="info"  # Available levels: error, warn, info, debug

###############################################################################
# Functions
###############################################################################

# Logging function with different levels
log() {
    local level=$1
    local message=$2
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    case $level in
        error) echo -e "[${timestamp}] [\e[31mERROR\e[0m] $message" >&2 ;;
        warn) echo -e "[${timestamp}] [\e[33mWARN\e[0m] $message" >&2 ;;
        info) echo -e "[${timestamp}] [\e[32mINFO\e[0m] $message" ;;
        debug) [ "$LOG_LEVEL" = "debug" ] && echo -e "[${timestamp}] [DEBUG] $message" ;;
    esac
}

# Display help information
show_help() {
    echo -e "\nAmass Automation Script v${VERSION}"
    echo "Usage: $0 [options] <domain> [output-dir]"
    echo ""
    echo "Options:"
    echo "  -h, --help       Show this help message"
    echo "  -v, --version    Display version information"
    echo "  -q, --quiet      Quiet mode (minimal output)"
    echo "  -d, --debug      Debug mode (verbose output)"
    echo "  -s, --scan-types Specify scan types (comma-separated: passive,active,full)"
    echo ""
    echo "Examples:"
    echo "  Basic scan: $0 example.com"
    echo "  Custom output: $0 example.com amass-results"
    echo "  Specific scans: $0 -s passive,active example.com"
    echo ""
    echo "Scan Types:"
    echo "  passive: Non-intrusive enumeration (no direct interaction)"
    echo "  active:  Includes DNS resolution and basic probing"
    echo "  full:    Comprehensive scan with brute forcing"
    exit 0
}

# Check for required dependencies
check_dependencies() {
    local missing=()
    
    if ! command -v amass &> /dev/null; then
        missing+=("amass")
    fi
    
    if ! command -v jq &> /dev/null; then
        log "warn" "jq not found - JSON processing will be limited"
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        log "error" "Missing dependencies: ${missing[*]}"
        log "info" "Install with: sudo apt install amass jq (Debian/Ubuntu)"
        exit 1
    fi
}

# Perform passive enumeration
run_passive_scan() {
    local domain=$1
    local output_dir=$2
    log "info" "Starting passive enumeration (no active probing)"
    amass enum -passive -d "$domain" -o "$output_dir/passive.txt" -log "$output_dir/amass.log"
}

# Perform active enumeration
run_active_scan() {
    local domain=$1
    local output_dir=$2
    log "info" "Starting active enumeration with DNS resolution"
    amass enum -active -d "$domain" -o "$output_dir/active.txt" -log "$output_dir/amass.log"
}

# Perform full enumeration with brute forcing
run_full_scan() {
    local domain=$1
    local output_dir=$2
    log "info" "Starting full enumeration with brute forcing"
    amass enum -brute -d "$domain" -o "$output_dir/full.txt" -json "$output_dir/full.json" -log "$output_dir/amass.log"
}

# Process results and generate summary
process_results() {
    local output_dir=$1
    
    log "info" "Processing results..."
    
    # Combine all results
    cat "$output_dir"/{passive,active,full}.txt 2>/dev/null | sort -u > "$output_dir/all_domains.txt"
    
    # Count results
    local passive_count=$(wc -l < "$output_dir/passive.txt" 2>/dev/null)
    local active_count=$(wc -l < "$output_dir/active.txt" 2>/dev/null)
    local full_count=$(wc -l < "$output_dir/full.txt" 2>/dev/null)
    local unique_count=$(wc -l < "$output_dir/all_domains.txt" 2>/dev/null)
    
    # Generate summary
    echo -e "\nScan Summary:" > "$output_dir/summary.txt"
    echo "-------------" >> "$output_dir/summary.txt"
    echo "Passive scan domains: ${passive_count:-0}" >> "$output_dir/summary.txt"
    echo "Active scan domains: ${active_count:-0}" >> "$output_dir/summary.txt"
    echo "Full scan domains: ${full_count:-0}" >> "$output_dir/summary.txt"
    echo "Unique domains found: $unique_count" >> "$output_dir/summary.txt"
    echo "Scan completed: $(date)" >> "$output_dir/summary.txt"
    
    cat "$output_dir/summary.txt"
}

###############################################################################
# Main Script
###############################################################################

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        -v|--version)
            echo "Amass Automation Script v$VERSION"
            exit 0
            ;;
        -q|--quiet)
            LOG_LEVEL="error"
            shift
            ;;
        -d|--debug)
            LOG_LEVEL="debug"
            shift
            ;;
        -s|--scan-types)
            IFS=',' read -r -a SCAN_TYPES <<< "$2"
            shift 2
            ;;
        -*)
            log "error" "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            if [ -z "$DOMAIN" ]; then
                DOMAIN="$1"
            elif [ -z "$OUTPUT_DIR" ]; then
                OUTPUT_DIR="$1"
            else
                log "error" "Too many arguments"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate arguments
if [ -z "$DOMAIN" ]; then
    log "error" "Domain argument is required"
    show_help
    exit 1
fi

# Set default output directory if not specified
OUTPUT_DIR="${OUTPUT_DIR:-amass-scan-$TIMESTAMP}"
SCAN_TYPES=("${SCAN_TYPES[@]:-${DEFAULT_SCANS[@]}}")

# Check for required tools
check_dependencies

# Create output directory
log "info" "Creating output directory: $OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR" || {
    log "error" "Failed to create output directory"
    exit 1
}

# Start scans
log "info" "Starting Amass enumeration for domain: $DOMAIN"
log "info" "Running scan types: ${SCAN_TYPES[*]}"

for scan_type in "${SCAN_TYPES[@]}"; do
    case $scan_type in
        passive)
            run_passive_scan "$DOMAIN" "$OUTPUT_DIR"
            ;;
        active)
            run_active_scan "$DOMAIN" "$OUTPUT_DIR"
            ;;
        full)
            run_full_scan "$DOMAIN" "$OUTPUT_DIR"
            ;;
        *)
            log "warn" "Unknown scan type: $scan_type"
            ;;
    esac
done

# Process and display results
process_results "$OUTPUT_DIR"

log "info" "Amass scan completed. Results saved in $OUTPUT_DIR/"
exit 0