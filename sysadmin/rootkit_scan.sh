#!/bin/bash

# Modern Rootkit Scanner Script
# ShellCheck-compliant version with proper error handling and bash best practices

set -euo pipefail  # Exit on error, undefined vars, pipe failures
IFS=$'\n\t'       # Secure IFS

# Constants
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME SCRIPT_DIR
readonly LOG_FILE="/var/log/rootkit_scan.log"
echo "Script: $SCRIPT_NAME (dir: $SCRIPT_DIR)" >&2
touch "$LOG_FILE" || { echo "ERROR: Can't write to $LOG_FILE" >&2; exit 1; }

# Colors for better user experience
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Dummy usage to prevent SC2034 warning
: "${RED}${GREEN}${YELLOW}${BLUE}${PURPLE}${CYAN}${NC}"

# Make them readonly
readonly RED GREEN YELLOW BLUE PURPLE CYAN NC

log_message() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log_message "INFO" "$1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    log_message "SUCCESS" "$1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log_message "WARNING" "$1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    log_message "ERROR" "$1"
}

print_header() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}================================${NC}"
    log_message "INFO" "HEADER: $1"
}

# Error handling function
error_exit() {
    print_error "$1"
    exit "${2:-1}"
}

# Cleanup function
cleanup() {
    local exit_code=$?
    print_status "Cleaning up..."
    rm -f "${TMP_FILE:-}" 2>/dev/null || true
    return $exit_code
}

# Set trap for cleanup on script exit
trap cleanup EXIT

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root (use sudo)" 1
    fi
}

# Check if required tools are installed
check_dependencies() {
    local missing_tools=()
    local tool

    if ! command -v rkhunter &> /dev/null; then
        missing_tools+=("rkhunter")
    fi

    if ! command -v chkrootkit &> /dev/null; then
        missing_tools+=("chkrootkit")
    fi

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_status "Please install missing tools:"
        for tool in "${missing_tools[@]}"; do
            case "$tool" in
                "rkhunter")
                    echo "  Ubuntu/Debian: sudo apt install rkhunter"
                    echo "  RHEL/CentOS: sudo yum install rkhunter"
                    ;;
                "chkrootkit")
                    echo "  Ubuntu/Debian: sudo apt install chkrootkit"
                    echo "  RHEL/CentOS: sudo yum install chkrootkit"
                    ;;
            esac
        done
        exit 1
    fi
}

# Run rkhunter scan
run_rkhunter() {
    print_header "Running RKHunter Scan"

    print_status "Updating rkhunter database..."
    if rkhunter --update --quiet; then
        print_success "RKHunter database updated successfully"
    else
        print_warning "Failed to update rkhunter database, continuing with scan..."
    fi

    print_status "Running rkhunter rootkit scan..."
    local rkhunter_log
    rkhunter_log="/tmp/rkhunter_scan_$(date +%Y%m%d_%H%M%S).log"

    if rkhunter --check --skip-keypress --report-warnings-only --logfile "$rkhunter_log"; then
        print_success "RKHunter scan completed successfully"
    else
        print_warning "RKHunter scan completed with warnings. Check log: $rkhunter_log"
    fi

    # Update file properties database
    print_status "Updating rkhunter file properties database..."
    if rkhunter --propupd --quiet; then
        print_success "RKHunter properties updated"
    else
        print_warning "Failed to update rkhunter properties"
    fi
}

# Run chkrootkit scan
run_chkrootkit() {
    print_header "Running Chkrootkit Scan"

    print_status "Running chkrootkit rootkit scan..."
    local chkrootkit_log
    chkrootkit_log="/tmp/chkrootkit_scan_$(date +%Y%m%d_%H%M%S).log"

    if chkrootkit | tee "$chkrootkit_log"; then
        print_success "Chkrootkit scan completed successfully"
        print_status "Full log saved to: $chkrootkit_log"
    else
        print_error "Chkrootkit scan failed"
        return 1
    fi
}

# Display usage information
show_usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Modern rootkit scanner script using rkhunter and chkrootkit.

OPTIONS:
    -h, --help          Show this help message
    -r, --rkhunter-only Run only rkhunter scan
    -c, --chkrootkit-only Run only chkrootkit scan
    -q, --quiet         Run in quiet mode (minimal output)
    -v, --verbose       Run in verbose mode

EXAMPLES:
    $SCRIPT_NAME                    # Run both scanners
    $SCRIPT_NAME -r                 # Run only rkhunter
    $SCRIPT_NAME --chkrootkit-only  # Run only chkrootkit
    $SCRIPT_NAME -v                 # Run with verbose output

NOTES:
    - This script must be run as root (use sudo)
    - Logs are saved to $LOG_FILE
    - Individual scan logs are saved to /tmp/
EOF
}

# Main function
main() {
    local run_rkhunter=true
    local run_chkrootkit=true
    local quiet_mode=false
    local verbose_mode=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -r|--rkhunter-only)
                run_chkrootkit=false
                shift
                ;;
            -c|--chkrootkit-only)
                run_rkhunter=false
                shift
                ;;
            -q|--quiet)
                quiet_mode=true
                shift
                ;;
            -v|--verbose)
                verbose_mode=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Set verbosity
    if [[ "$quiet_mode" == true ]]; then
        exec > /dev/null 2>&1
    elif [[ "$verbose_mode" == true ]]; then
        set -x
    fi

    print_header "Rootkit Security Scan - $(date)"
    print_status "Script: $SCRIPT_NAME"
    print_status "Log file: $LOG_FILE"

    # Perform checks
    check_root
    check_dependencies

    # Create log file if it doesn't exist
    if [[ ! -f "$LOG_FILE" ]]; then
        touch "$LOG_FILE" || error_exit "Cannot create log file: $LOG_FILE"
    fi

    # Run scans based on options
    local scan_count=0
    local failed_scans=0

    if [[ "$run_rkhunter" == true ]]; then
        if run_rkhunter; then
            ((scan_count++))
        else
            ((failed_scans++))
        fi
    fi

    if [[ "$run_chkrootkit" == true ]]; then
        if run_chkrootkit; then
            ((scan_count++))
        else
            ((failed_scans++))
        fi
    fi

    # Final summary
    print_header "Scan Summary"
    print_status "Completed scans: $scan_count"
    if [[ $failed_scans -gt 0 ]]; then
        print_warning "Failed scans: $failed_scans"
    fi

    print_success "Rootkit scan session completed at $(date)"
    print_status "Check individual scan logs in /tmp/ for detailed results"
    print_status "Full session log available at: $LOG_FILE"

    exit $failed_scans
}

# Run main function with all arguments
main "$@"
