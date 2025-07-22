#!/bin/bash

# TimeShift Manager - Modern System Snapshot Management Tool
# Description: Interactive shell script for managing system snapshots with TimeShift
# Version: 3.0 (Modernized)
# Author: Solo
# Last Modified: 2024-12-19

# Strict error handling and security
set -euo pipefail  # Exit on error, undefined variables, and pipe failures
IFS=$'\n\t'        # Secure IFS

# Script metadata
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="3.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="/var/log/timeshift-manager.log"
readonly CONFIG_FILE="/etc/timeshift-manager.conf"

# Color constants (readonly for immutability)
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly WHITE='\033[1;37m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# Configuration defaults
declare -A CONFIG=(
    ["auto_description"]="true"
    ["confirm_actions"]="true"
    ["log_operations"]="true"
    ["max_snapshots"]="10"
    ["backup_location"]="/timeshift"
)

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    if [[ "${CONFIG[log_operations]}" == "true" ]]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

# Enhanced output functions with logging
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
    echo -e "${CYAN}${BOLD}$1${NC}"
    log_message "HEADER" "$1"
}

# Error handling function
error_exit() {
    local message="${1:-"Unknown error occurred"}"
    local exit_code="${2:-1}"
    print_error "$message"
    exit "$exit_code"
}

# Cleanup function
cleanup() {
    # Cleanup temporary files if any were created
    return 0
}

# Set trap for cleanup
trap cleanup EXIT

# Load configuration file
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # Source config file safely
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ $key =~ ^[[:space:]]*# ]] && continue
            [[ -z "$key" ]] && continue

            # Remove quotes if present
            value="${value//\"/}"
            value="${value//\'/}"

            # Set config value if key exists
            if [[ -n "${CONFIG[$key]:-}" ]]; then
                CONFIG["$key"]="$value"
            fi
        done < "$CONFIG_FILE"
        print_status "Configuration loaded from $CONFIG_FILE"
    fi
}

# Create default configuration file
create_default_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << EOF
# TimeShift Manager Configuration File
# Boolean values: true/false

# Automatically generate snapshot descriptions
auto_description=true

# Confirm destructive actions
confirm_actions=true

# Log all operations
log_operations=true

# Maximum number of snapshots to keep
max_snapshots=10

# Backup location
backup_location=/timeshift
EOF
        print_success "Default configuration created at $CONFIG_FILE"
    fi
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root. Use: sudo $SCRIPT_NAME" 1
    fi
}

# Enhanced dependency checking
check_dependencies() {
    local missing=()
    local optional_missing=()

    # Required dependencies
    local required_deps=("timeshift")
    for dep in "${required_deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done

    # Optional dependencies
    local optional_deps=("rsync" "btrfs")
    for dep in "${optional_deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            optional_missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        print_error "Missing required dependencies: ${missing[*]}"
        print_status "Install with:"
        echo -e "  ${CYAN}Ubuntu/Debian:${NC} sudo apt install ${missing[*]}"
        echo -e "  ${CYAN}RHEL/CentOS:${NC} sudo yum install ${missing[*]}"
        echo -e "  ${CYAN}Arch:${NC} sudo pacman -S ${missing[*]}"
        exit 1
    fi

    if [[ ${#optional_missing[@]} -gt 0 ]]; then
        print_warning "Optional dependencies not found: ${optional_missing[*]}"
        print_status "Some features may be limited"
    fi

    print_success "All required dependencies are installed"
}

# Get system information
get_system_info() {
    local info=""
    info+="System: $(uname -s) $(uname -r)\n"
    info+="Hostname: $(hostname)\n"
    info+="Uptime: $(uptime -p 2>/dev/null || uptime)\n"
    info+="Disk Usage: $(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')% used\n"
    echo -e "$info"
}

# Enhanced snapshot listing with better parsing
get_snapshots() {
    local -a snapshots=()
    local snapshot_data

    # Use timeshift --list --scripted for better parsing
    if snapshot_data=$(timeshift --list --scripted 2>/dev/null); then
        while IFS=$'\t' read -r tag date time; do
            if [[ -n "$tag" && "$tag" != "Tag" ]]; then
                snapshots+=("$tag|$date $time")
            fi
        done <<< "$snapshot_data"
    else
        # Fallback to regular parsing
        while IFS= read -r line; do
            if [[ $line =~ ^[[:space:]]*[0-9]+[[:space:]]*:[[:space:]]*(.+) ]]; then
                local tag="${BASH_REMATCH[1]}"
                snapshots+=("$tag|Unknown date")
            fi
        done < <(timeshift --list 2>/dev/null || true)
    fi

    printf '%s\n' "${snapshots[@]}"
}

# Create snapshot with enhanced options
create_snapshot() {
    print_header "Creating New Snapshot"

    local description=""
    local snapshot_type="ondemand"

    # Get description from user or generate automatically
    if [[ "${CONFIG[auto_description]}" == "true" ]]; then
        description="Manual snapshot created on $(date '+%Y-%m-%d at %H:%M:%S')"
        print_status "Auto-generated description: $description"

        echo -n "Use this description? [Y/n]: "
        read -r response
        if [[ $response =~ ^[Nn]$ ]]; then
            echo -n "Enter custom description: "
            read -r description
        fi
    else
        echo -n "Enter snapshot description: "
        read -r description
        [[ -z "$description" ]] && description="Manual snapshot $(date '+%Y-%m-%d %H:%M:%S')"
    fi

    # Show system info before creating snapshot
    print_status "System Information:"
    get_system_info

    # Confirm creation
    if [[ "${CONFIG[confirm_actions]}" == "true" ]]; then
        echo -n "Create snapshot with description '$description'? [Y/n]: "
        read -r response
        if [[ $response =~ ^[Nn]$ ]]; then
            print_warning "Snapshot creation cancelled"
            return 0
        fi
    fi

    # Create the snapshot
    print_status "Creating snapshot, please wait..."
    if timeshift --create --comments "$description" --tags "$snapshot_type"; then
        print_success "Snapshot created successfully"
        log_message "SUCCESS" "Snapshot created: $description"
    else
        print_error "Failed to create snapshot"
        log_message "ERROR" "Failed to create snapshot: $description"
        return 1
    fi

    # Check snapshot count
    check_snapshot_limit

    pause_for_input
}

# Enhanced snapshot deletion with safety checks
delete_snapshot() {
    print_header "Delete Snapshot"

    local -a snapshots=()
    local snapshot_list

    # Get snapshots
    snapshot_list=$(get_snapshots)
    if [[ -z "$snapshot_list" ]]; then
        print_warning "No snapshots available to delete"
        pause_for_input
        return 0
    fi

    # Parse snapshots into array
    while IFS='|' read -r tag date_time; do
        snapshots+=("$tag")
    done <<< "$snapshot_list"

    echo -e "\n${CYAN}Available Snapshots:${NC}"
    local i=1
    while IFS='|' read -r tag date_time; do
        echo -e "  ${WHITE}$i)${NC} $tag ${YELLOW}($date_time)${NC}"
        ((i++))
    done <<< "$snapshot_list"

    echo -e "  ${WHITE}0)${NC} Cancel"

    # Get user selection
    local selection
    while true; do
        echo -n "Select snapshot to delete [0-$((${#snapshots[@]})]: "
        read -r selection

        if [[ "$selection" == "0" ]]; then
            print_status "Operation cancelled"
            return 0
        elif [[ "$selection" =~ ^[0-9]+$ ]] && ((selection >= 1 && selection <= ${#snapshots[@]})); then
            break
        else
            print_error "Invalid selection. Please enter a number between 0 and ${#snapshots[@]}"
        fi
    done

    local selected_snapshot="${snapshots[$((selection-1))]}"

    # Safety confirmation
    print_warning "WARNING: This action cannot be undone!"
    echo -e "Snapshot to delete: ${RED}$selected_snapshot${NC}"

    if [[ "${CONFIG[confirm_actions]}" == "true" ]]; then
        echo -n "Type 'DELETE' to confirm: "
        read -r confirmation
        if [[ "$confirmation" != "DELETE" ]]; then
            print_status "Deletion cancelled"
            return 0
        fi
    fi

    # Delete the snapshot
    print_status "Deleting snapshot '$selected_snapshot'..."
    if timeshift --delete --snapshot "$selected_snapshot"; then
        print_success "Snapshot deleted successfully"
        log_message "SUCCESS" "Snapshot deleted: $selected_snapshot"
    else
        print_error "Failed to delete snapshot"
        log_message "ERROR" "Failed to delete snapshot: $selected_snapshot"
        return 1
    fi

    pause_for_input
}

# Enhanced snapshot restoration with safety checks
restore_snapshot() {
    print_header "Restore Snapshot"

    local -a snapshots=()
    local snapshot_list

    # Get snapshots
    snapshot_list=$(get_snapshots)
    if [[ -z "$snapshot_list" ]]; then
        print_warning "No snapshots available to restore"
        pause_for_input
        return 0
    fi

    # Parse snapshots into array
    while IFS='|' read -r tag date_time; do
        snapshots+=("$tag")
    done <<< "$snapshot_list"

    echo -e "\n${CYAN}Available Snapshots:${NC}"
    local i=1
    while IFS='|' read -r tag date_time; do
        echo -e "  ${WHITE}$i)${NC} $tag ${YELLOW}($date_time)${NC}"
        ((i++))
    done <<< "$snapshot_list"

    echo -e "  ${WHITE}0)${NC} Cancel"

    # Get user selection
    local selection
    while true; do
        echo -n "Select snapshot to restore [0-$((${#snapshots[@]})]: "
        read -r selection

        if [[ "$selection" == "0" ]]; then
            print_status "Operation cancelled"
            return 0
        elif [[ "$selection" =~ ^[0-9]+$ ]] && ((selection >= 1 && selection <= ${#snapshots[@]})); then
            break
        else
            print_error "Invalid selection. Please enter a number between 0 and ${#snapshots[@]}"
        fi
    done

    local selected_snapshot="${snapshots[$((selection-1))]}"

    # Multiple safety confirmations for restore
    echo -e "\n${RED}${BOLD}CRITICAL WARNING!${NC}"
    echo -e "${RED}This will restore your system to snapshot: $selected_snapshot${NC}"
    echo -e "${RED}Current system state will be LOST!${NC}"
    echo -e "${RED}System will REBOOT automatically!${NC}\n"

    # First confirmation
    echo -n "Do you understand the risks? [y/N]: "
    read -r response1
    if [[ ! $response1 =~ ^[Yy]$ ]]; then
        print_status "Restore cancelled"
        return 0
    fi

    # Second confirmation
    echo -n "Type the snapshot name to confirm: "
    read -r response2
    if [[ "$response2" != "$selected_snapshot" ]]; then
        print_status "Restore cancelled - snapshot name mismatch"
        return 0
    fi

    # Final confirmation
    echo -n "Final confirmation - type 'RESTORE' to proceed: "
    read -r response3
    if [[ "$response3" != "RESTORE" ]]; then
        print_status "Restore cancelled"
        return 0
    fi

    # Perform the restoration
    print_status "Restoring system to snapshot '$selected_snapshot'..."
    print_status "System will reboot in 5 seconds..."

    # Countdown
    for i in {5..1}; do
        echo -n "$i... "
        sleep 1
    done
    echo

    log_message "INFO" "System restore initiated: $selected_snapshot"

    if timeshift --restore --snapshot "$selected_snapshot" --skip-grub; then
        print_success "Restore initiated successfully"
        print_status "System will reboot now..."
        reboot
    else
        print_error "Failed to restore snapshot"
        log_message "ERROR" "Failed to restore snapshot: $selected_snapshot"
        return 1
    fi
}

# Enhanced snapshot listing with detailed information
list_snapshots() {
    print_header "Available Snapshots"

    local snapshot_list
    snapshot_list=$(get_snapshots)

    if [[ -z "$snapshot_list" ]]; then
        print_warning "No snapshots found"
        pause_for_input
        return 0
    fi

    echo -e "\n${CYAN}${BOLD}Snapshot Details:${NC}\n"

    local count=0
    while IFS='|' read -r tag date_time; do
        ((count++))
        echo -e "${WHITE}$count.${NC} ${GREEN}$tag${NC}"
        echo -e "    ${YELLOW}Created:${NC} $date_time"

        # Try to get snapshot size (if available)
        local size_info=""
        if command -v du &> /dev/null; then
            local snapshot_path="/timeshift/snapshots/$tag"
            if [[ -d "$snapshot_path" ]]; then
                size_info=$(du -sh "$snapshot_path" 2>/dev/null | cut -f1 || echo "Unknown")
                echo -e "    ${YELLOW}Size:${NC} $size_info"
            fi
        fi
        echo
    done <<< "$snapshot_list"

    echo -e "${CYAN}Total snapshots: $count${NC}"

    # Show detailed TimeShift output
    echo -e "\n${CYAN}${BOLD}TimeShift Details:${NC}"
    timeshift --list 2>/dev/null || print_warning "Could not retrieve detailed TimeShift information"

    pause_for_input
}

# Check snapshot limit and warn/cleanup if needed
check_snapshot_limit() {
    local max_snapshots="${CONFIG[max_snapshots]}"
    local current_count
    current_count=$(get_snapshots | wc -l)

    if ((current_count > max_snapshots)); then
        print_warning "Snapshot limit exceeded ($current_count > $max_snapshots)"
        echo -n "Auto-delete oldest snapshots? [y/N]: "
        read -r response
        if [[ $response =~ ^[Yy]$ ]]; then
            cleanup_old_snapshots
        fi
    fi
}

# Cleanup old snapshots
cleanup_old_snapshots() {
    local max_snapshots="${CONFIG[max_snapshots]}"
    print_status "Cleaning up old snapshots (keeping $max_snapshots newest)..."

    if timeshift --delete-all --max-snapshots "$max_snapshots"; then
        print_success "Old snapshots cleaned up"
    else
        print_warning "Failed to cleanup some snapshots"
    fi
}

# Configuration management
manage_config() {
    print_header "Configuration Management"

    echo -e "\n${CYAN}Current Configuration:${NC}"
    for key in "${!CONFIG[@]}"; do
        echo -e "  ${WHITE}$key:${NC} ${CONFIG[$key]}"
    done

    echo -e "\n${CYAN}Options:${NC}"
    echo -e "  ${WHITE}1)${NC} Edit configuration file"
    echo -e "  ${WHITE}2)${NC} Reset to defaults"
    echo -e "  ${WHITE}3)${NC} Reload configuration"
    echo -e "  ${WHITE}0)${NC} Back to main menu"

    echo -n "Select option [0-3]: "
    read -r choice

    case "$choice" in
        1)
            if command -v nano &> /dev/null; then
                nano "$CONFIG_FILE"
            elif command -v vi &> /dev/null; then
                vi "$CONFIG_FILE"
            else
                print_error "No text editor found"
            fi
            load_config
            ;;
        2)
            echo -n "Reset configuration to defaults? [y/N]: "
            read -r response
            if [[ $response =~ ^[Yy]$ ]]; then
                rm -f "$CONFIG_FILE"
                create_default_config
                load_config
                print_success "Configuration reset to defaults"
            fi
            ;;
        3)
            load_config
            print_success "Configuration reloaded"
            ;;
        0)
            return 0
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac

    pause_for_input
}

# System status and health check
system_status() {
    print_header "System Status & Health Check"

    echo -e "\n${CYAN}${BOLD}System Information:${NC}"
    get_system_info

    echo -e "\n${CYAN}${BOLD}TimeShift Status:${NC}"
    if timeshift --list &>/dev/null; then
        print_success "TimeShift is operational"

        local snapshot_count
        snapshot_count=$(get_snapshots | wc -l)
        echo -e "  ${WHITE}Total snapshots:${NC} $snapshot_count"
        echo -e "  ${WHITE}Max snapshots:${NC} ${CONFIG[max_snapshots]}"

        # Check backup device
        if [[ -d "${CONFIG[backup_location]}" ]]; then
            local available_space
            available_space=$(df -h "${CONFIG[backup_location]}" | tail -1 | awk '{print $4}')
            echo -e "  ${WHITE}Available space:${NC} $available_space"
        fi

        # Check last snapshot
        local last_snapshot
        last_snapshot=$(get_snapshots | head -1 | cut -d'|' -f1)
        if [[ -n "$last_snapshot" ]]; then
            echo -e "  ${WHITE}Last snapshot:${NC} $last_snapshot"
        fi
    else
        print_error "TimeShift is not properly configured or accessible"
    fi

    echo -e "\n${CYAN}${BOLD}Disk Usage:${NC}"
    df -h | head -1
    df -h | grep -E '^/dev/'

    echo -e "\n${CYAN}${BOLD}Memory Usage:${NC}"
    free -h

    pause_for_input
}

# Pause for user input
pause_for_input() {
    echo
    echo -n "Press Enter to continue..."
    read -r
}

# Display help information
show_help() {
    cat << EOF
${CYAN}${BOLD}TimeShift Manager v${SCRIPT_VERSION}${NC}
Modern system snapshot management tool

${CYAN}USAGE:${NC}
  $SCRIPT_NAME [OPTIONS]

${CYAN}OPTIONS:${NC}
  -h, --help          Show this help message
  -v, --version       Show version information
  -c, --config        Show configuration file location
  -s, --status        Show system status and exit
  -l, --list          List snapshots and exit
  --create [DESC]     Create snapshot with optional description
  --non-interactive   Run in non-interactive mode

${CYAN}INTERACTIVE MENU:${NC}
  1) Create new snapshot
  2) Delete snapshot
  3) Restore snapshot
  4) List snapshots
  5) System status
  6) Configuration
  7) Exit

${CYAN}FILES:${NC}
  Configuration: $CONFIG_FILE
  Log file: $LOG_FILE

${CYAN}EXAMPLES:${NC}
  $SCRIPT_NAME                    # Start interactive mode
  $SCRIPT_NAME --status           # Show system status
  $SCRIPT_NAME --create "Before update"  # Create snapshot
  $SCRIPT_NAME --list             # List all snapshots

${CYAN}REQUIREMENTS:${NC}
  - Must be run as root (use sudo)
  - TimeShift must be installed and configured
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                echo "TimeShift Manager v${SCRIPT_VERSION}"
                exit 0
                ;;
            -c|--config)
                echo "Configuration file: $CONFIG_FILE"
                exit 0
                ;;
            -s|--status)
                system_status
                exit 0
                ;;
            -l|--list)
                list_snapshots
                exit 0
                ;;
            --create)
                local desc="${2:-"CLI snapshot $(date '+%Y-%m-%d %H:%M:%S')"}"
                print_status "Creating snapshot: $desc"
                if timeshift --create --comments "$desc"; then
                    print_success "Snapshot created successfully"
                    exit 0
                else
                    print_error "Failed to create snapshot"
                    exit 1
                fi
                ;;
            --non-interactive)
                print_error "Non-interactive mode not yet implemented"
                exit 1
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

# Enhanced main menu with better formatting
show_main_menu() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}⏰ TIMESHIFT MANAGER ${WHITE}v${SCRIPT_VERSION}${NC} ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}     ${MAGENTA}Modern System Snapshot Management${NC}        ${BLUE}║${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC}  ${GREEN}1)${NC} Create new snapshot                         ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${RED}2)${NC} Delete snapshot                             ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${YELLOW}3)${NC} Restore snapshot                            ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}4)${NC} List snapshots                              ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${BLUE}5)${NC} System status & health check               ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${MAGENTA}6)${NC} Configuration management                   ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${WHITE}7)${NC} Help & Information                         ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${RED}8)${NC} Exit                                        ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"

    # Show quick status
    local snapshot_count
    snapshot_count=$(get_snapshots | wc -l 2>/dev/null || echo "0")
    echo -e "\n${CYAN}Quick Status:${NC} $snapshot_count snapshots available"
    echo -e "${CYAN}System:${NC} $(hostname) | ${CYAN}Date:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
}

# Main application loop
main() {
    # Parse command line arguments first
    parse_arguments "$@"

    # Initialize
    print_status "Starting TimeShift Manager v${SCRIPT_VERSION}"
    check_root
    check_dependencies
    create_default_config
    load_config

    # Create log file if it doesn't exist
    if [[ "${CONFIG[log_operations]}" == "true" ]]; then
        touch "$LOG_FILE" 2>/dev/null || true
        log_message "INFO" "TimeShift Manager started"
    fi

    # Main interactive loop
    while true; do
        show_main_menu

        echo -n "Enter your choice [1-8]: "
        read -r choice

        case $choice in
            1)
                create_snapshot
                ;;
            2)
                delete_snapshot
                ;;
            3)
                restore_snapshot
                ;;
            4)
                list_snapshots
                ;;
            5)
                system_status
                ;;
            6)
                manage_config
                ;;
            7)
                show_help
                pause_for_input
                ;;
            8)
                print_success "Thank you for using TimeShift Manager!"
                log_message "INFO" "TimeShift Manager exited normally"
                exit 0
                ;;
            *)
                print_error "Invalid option. Please choose 1-8."
                sleep 1
                ;;
        esac
    done
}

# Run main function with all arguments
main "$@"
