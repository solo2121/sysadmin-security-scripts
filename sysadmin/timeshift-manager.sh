#!/bin/bash

# TimeShift Manager - Simple System Snapshot Management Tool
# Description: Interactive shell script for managing system snapshots with TimeShift
# Version: 3.2 (Fixed Version)
# Author: Solo
# Last Modified: 2025-07-28

set -euo pipefail
IFS=$'\n\t'

# Constants
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="3.2"
readonly LOG_FILE="/var/log/timeshift-manager.log"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly WHITE='\033[1;37m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Logging
log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null || true
}

# Output functions
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

# Error handling
error_exit() {
    local message="${1:-Unknown error occurred}"
    local exit_code="${2:-1}"
    print_error "$message"
    exit "$exit_code"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root. Use: sudo $SCRIPT_NAME" 1
    fi
}

# Check dependencies
check_dependencies() {
    if ! command -v timeshift &> /dev/null; then
        print_error "TimeShift is not installed"
        echo -e "Install with:"
        echo -e "  ${CYAN}Ubuntu/Debian:${NC} sudo apt install timeshift"
        echo -e "  ${CYAN}RHEL/CentOS:${NC} sudo yum install timeshift"
        echo -e "  ${CYAN}Arch:${NC} sudo pacman -S timeshift"
        exit 1
    fi
}

# Get snapshot count - consistent across all functions
get_snapshot_count() {
    timeshift --list 2>/dev/null | grep -c '^[0-9]\+[[:space:]]\+>' || echo "0"
}

# Get snapshot list - consistent across all functions
get_snapshots() {
    # First check if any snapshots exist
    local snapshot_count
    snapshot_count=$(get_snapshot_count)

    if [[ $snapshot_count -eq 0 ]]; then
        echo ""
        return
    fi

    # Extract snapshot names
    timeshift --list 2>/dev/null | awk '/^[0-9]+[[:space:]]+>/ {print $3}' || true
}

# Pause for input
pause_for_input() {
    echo
    echo -n "Press Enter to continue..."
    read -r
}

# Create snapshot
create_snapshot() {
    print_header "Creating New Snapshot"

    local description
    echo -n "Enter snapshot description (or press Enter for auto): "
    read -r description

    if [[ -z "$description" ]]; then
        description="Manual snapshot - $(date '+%Y-%m-%d %H:%M:%S')"
    fi

    print_status "Creating snapshot: $description"
    print_status "Please wait, this may take several minutes..."

    if timeshift --create --comments "$description" --tags "ondemand"; then
        print_success "Snapshot created successfully!"
    else
        print_error "Failed to create snapshot"
        return 1
    fi

    pause_for_input
}

# Delete snapshot
delete_snapshot() {
    print_header "Delete Snapshot"

    local snapshots
    snapshots=$(get_snapshots)

    if [[ -z "$snapshots" ]]; then
        print_warning "No snapshots available to delete"
        pause_for_input
        return 0
    fi

    echo -e "\n${CYAN}Available Snapshots:${NC}"

    # Create array and display snapshots
    local snapshot_list
    snapshot_list=$(echo "$snapshots")

    local -a snapshot_array
    local counter=1

    while IFS= read -r snapshot; do
        if [[ -n "$snapshot" ]]; then
            echo -e "  ${WHITE}$counter)${NC} $snapshot"
            snapshot_array[counter]="$snapshot"
            ((counter++))
        fi
    done < <(echo "$snapshot_list")

    echo -e "  ${WHITE}0)${NC} Cancel"

    local choice
    while true; do
        echo -n "Select snapshot to delete [0-$((counter-1))]: "
        read -r choice

        if [[ "$choice" == "0" ]]; then
            print_status "Operation cancelled"
            return 0
        elif [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice < counter)); then
            break
        else
            print_error "Invalid selection"
        fi
    done

    local selected_snapshot="${snapshot_array[choice]}"

    print_warning "WARNING: This action cannot be undone!"
    echo -e "Snapshot to delete: ${RED}$selected_snapshot${NC}"

    echo -n "Type 'DELETE' to confirm: "
    read -r confirmation

    if [[ "$confirmation" != "DELETE" ]]; then
        print_status "Deletion cancelled"
        return 0
    fi

    print_status "Deleting snapshot..."
    if timeshift --delete --snapshot "$selected_snapshot"; then
        print_success "Snapshot deleted successfully"
    else
        print_error "Failed to delete snapshot"
        return 1
    fi

    pause_for_input
}

# Restore snapshot
restore_snapshot() {
    print_header "Restore Snapshot"

    local snapshots
    snapshots=$(get_snapshots)

    if [[ -z "$snapshots" ]]; then
        print_warning "No snapshots available to restore"
        pause_for_input
        return 0
    fi

    echo -e "\n${CYAN}Available Snapshots:${NC}"

    # Create array and display snapshots
    local snapshot_list
    snapshot_list=$(echo "$snapshots")

    local -a snapshot_array
    local counter=1

    while IFS= read -r snapshot; do
        if [[ -n "$snapshot" ]]; then
            echo -e "  ${WHITE}$counter)${NC} $snapshot"
            snapshot_array[counter]="$snapshot"
            ((counter++))
        fi
    done < <(echo "$snapshot_list")

    echo -e "  ${WHITE}0)${NC} Cancel"

    local choice
    while true; do
        echo -n "Select snapshot to restore [0-$((counter-1))]: "
        read -r choice

        if [[ "$choice" == "0" ]]; then
            print_status "Operation cancelled"
            return 0
        elif [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice < counter)); then
            break
        else
            print_error "Invalid selection"
        fi
    done

    local selected_snapshot="${snapshot_array[choice]}"

    echo -e "\n${RED}${BOLD}CRITICAL WARNING!${NC}"
    echo -e "${RED}This will restore your system to: $selected_snapshot${NC}"
    echo -e "${RED}Current system state will be LOST!${NC}"
    echo -e "${RED}System will REBOOT automatically!${NC}\n"

    echo -n "Do you understand the risks? [y/N]: "
    read -r response1
    if [[ ! $response1 =~ ^[Yy]$ ]]; then
        print_status "Restore cancelled"
        return 0
    fi

    echo -n "Type 'RESTORE' to confirm: "
    read -r response2
    if [[ "$response2" != "RESTORE" ]]; then
        print_status "Restore cancelled"
        return 0
    fi

    print_status "Restoring system to snapshot: $selected_snapshot"
    print_status "System will reboot in 5 seconds..."

    for i in {5..1}; do
        echo -n "$i... "
        sleep 1
    done
    echo

    if timeshift --restore --snapshot "$selected_snapshot" --skip-grub; then
        print_success "Restore initiated successfully"
        print_status "System will reboot now..."
        reboot
    else
        print_error "Failed to restore snapshot"
        return 1
    fi
}

# List snapshots
list_snapshots() {
    print_header "Available Snapshots"

    local snapshots
    snapshots=$(get_snapshots)

    if [[ -z "$snapshots" ]]; then
        print_warning "No snapshots found"
    else
        echo -e "\n${CYAN}Snapshot List:${NC}\n"
        local counter=1

        while IFS= read -r snapshot; do
            if [[ -n "$snapshot" ]]; then
                echo -e "${WHITE}$counter.${NC} ${GREEN}$snapshot${NC}"
                ((counter++))
            fi
        done < <(echo "$snapshots")

        echo -e "\n${CYAN}Total snapshots: $((counter-1))${NC}"

        echo -e "\n${CYAN}Detailed Information:${NC}"
        timeshift --list 2>/dev/null || print_warning "Could not retrieve details"
    fi

    pause_for_input
}

# System information
show_system_info() {
    print_header "System Information"

    echo -e "\n${CYAN}System Details:${NC}"
    echo -e "${WHITE}Hostname:${NC} $(hostname)"
    echo -e "${WHITE}Kernel:${NC} $(uname -r)"
    echo -e "${WHITE}Uptime:${NC} $(uptime -p 2>/dev/null || uptime | cut -d',' -f1)"

    echo -e "\n${CYAN}Disk Usage:${NC}"
    df -h | head -1
    df -h | grep -E '^/dev/' | head -5

    echo -e "\n${CYAN}TimeShift Status:${NC}"
    if timeshift --list &>/dev/null; then
        print_success "TimeShift is operational"
        local snapshot_count
        snapshot_count=$(get_snapshot_count)
        echo -e "${WHITE}Available snapshots:${NC} $snapshot_count"
    else
        print_error "TimeShift is not properly configured"
    fi

    pause_for_input
}

# Show help
show_help() {
    echo -e "${CYAN}${BOLD}TimeShift Manager v${SCRIPT_VERSION}${NC}"
    echo "System snapshot management tool"
    echo
    echo -e "${CYAN}USAGE:${NC}"
    echo "  sudo ./timeshift-manager.sh [OPTIONS]"
    echo
    echo -e "${CYAN}OPTIONS:${NC}"
    echo "  -h, --help          Show this help message"
    echo "  -v, --version       Show version information"
    echo "  -l, --list          List snapshots and exit"
    echo "  -s, --status        Show system status and exit"
    echo
    echo -e "${CYAN}INTERACTIVE MENU:${NC}"
    echo "  1) Create new snapshot"
    echo "  2) Delete snapshot"
    echo "  3) Restore snapshot"
    echo "  4) List snapshots"
    echo "  5) System information"
    echo "  6) Exit"
    echo
    echo -e "${CYAN}REQUIREMENTS:${NC}"
    echo "  - Must be run as root (use sudo)"
    echo "  - TimeShift must be installed and configured"
    echo
    echo -e "${CYAN}EXAMPLES:${NC}"
    echo "  sudo ./timeshift-manager.sh           # Interactive mode"
    echo "  sudo ./timeshift-manager.sh --list    # List snapshots"
    echo "  sudo ./timeshift-manager.sh --status  # Show system status"
}

# Parse arguments
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
            -l|--list)
                list_snapshots
                exit 0
                ;;
            -s|--status)
                show_system_info
                exit 0
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

# Main menu
show_main_menu() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}⏰ TIMESHIFT MANAGER ${WHITE}v${SCRIPT_VERSION}${NC}               ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}     ${MAGENTA}System Snapshot Management${NC}           ${BLUE}║${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC}  ${GREEN}1)${NC} Create new snapshot                  ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${RED}2)${NC} Delete snapshot                      ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${YELLOW}3)${NC} Restore snapshot                     ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}4)${NC} List snapshots                       ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${BLUE}5)${NC} System information                   ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${WHITE}6)${NC} Exit                                 ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"

    local snapshot_count
    snapshot_count=$(get_snapshot_count)
    echo -e "\n${CYAN}Status:${NC} $snapshot_count snapshots | ${CYAN}Host:${NC} $(hostname) | ${CYAN}Date:${NC} $(date '+%Y-%m-%d %H:%M')"
}

# Main function
main() {
    parse_arguments "$@"

    print_status "Starting TimeShift Manager v${SCRIPT_VERSION}"
    check_root
    check_dependencies

    touch "$LOG_FILE" 2>/dev/null || true
    log_message "INFO" "TimeShift Manager started"

    while true; do
        show_main_menu

        echo -n "Enter your choice [1-6]: "
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
                show_system_info
                ;;
            6)
                print_success "Thank you for using TimeShift Manager!"
                log_message "INFO" "TimeShift Manager exited normally"
                exit 0
                ;;
            *)
                print_error "Invalid option. Please choose 1-6."
                sleep 1
                ;;
        esac
    done
}

main "$@"
