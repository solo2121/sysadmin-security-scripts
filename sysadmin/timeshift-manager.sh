#!/bin/bash

# TimeShift Manager - Simple System Snapshot Management Tool
# Description: Interactive shell script for managing system snapshots with TimeShift
# Version: 3.0 (Fixed Version)
# Author: Solo
# Last Modified: 2025-08-14
set -euo pipefail
IFS=$'\n\t'

# Constants
SCRIPT_NAME="$(basename "${0:-}")"
readonly SCRIPT_NAME
readonly SCRIPT_VERSION="3.0"
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

# Trap Ctrl+C
trap 'echo -e "\n${RED}Operation cancelled by user${NC}"; exit 1' INT

# Logging
log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null || true
}

# Output functions
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; log_message "INFO" "$1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; log_message "SUCCESS" "$1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; log_message "WARNING" "$1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; log_message "ERROR" "$1"; }
print_header() { echo -e "${CYAN}${BOLD}$1${NC}"; log_message "HEADER" "$1"; }

# Error exit
error_exit() { print_error "${1:-Unknown error occurred}"; exit "${2:-1}"; }

# Root check
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root. Use: sudo $SCRIPT_NAME"
    fi
}

# Dependency check
check_dependencies() {
    if ! command -v timeshift &>/dev/null; then
        print_error "TimeShift is not installed"
        echo -e "Install with:\n  ${CYAN}Ubuntu/Debian:${NC} sudo apt install timeshift\n  ${CYAN}Arch:${NC} sudo pacman -S timeshift"
        exit 1
    fi
}

# Get snapshot count
get_snapshot_count() {
    timeshift --list 2>/dev/null | awk '/^[0-9]+[[:space:]]+>/ {count++} END {print count+0}' || echo "0"
}

# Get snapshot names
get_snapshots() {
    local count
    count=$(get_snapshot_count)
    [[ $count -eq 0 ]] && echo "" && return
    timeshift --list 2>/dev/null | awk '/^[0-9]+[[:space:]]+>/ {print $3}'
}

pause_for_input() { echo; read -rp "Press Enter to continue..." _; }

create_snapshot() {
    print_header "Creating New Snapshot"
    read -rp "Enter snapshot description (or press Enter for auto): " description
    [[ -z "$description" ]] && description="Manual snapshot - $(date '+%Y-%m-%d %H:%M:%S')"
    print_status "Creating snapshot: $description"
    if timeshift --create --comments "$description"; then
        print_success "Snapshot created successfully!"
    else
        print_error "Failed to create snapshot"
    fi
    pause_for_input
}

delete_snapshot() {
    print_header "Delete Snapshot"
    local snapshots
    snapshots=$(get_snapshots)
    if [[ -z "$snapshots" ]]; then
        print_warning "No snapshots available"
        pause_for_input
        return
    fi
    echo -e "\n${CYAN}Available Snapshots:${NC}"
    local -a snapshot_array=()
    local counter=1
    while IFS= read -r snap; do
        echo -e "  ${WHITE}$counter)${NC} $snap"
        snapshot_array[counter]="$snap"
        ((counter++))
    done <<< "$snapshots"
    echo -e "  ${WHITE}0)${NC} Cancel"
    while true; do
        read -rp "Select snapshot to delete [0-$((counter-1))]: " choice
        [[ "$choice" == "0" ]] && print_status "Cancelled" && return
        if [[ "$choice" =~ ^[0-9]+$ && $choice -ge 1 && $choice -lt $counter ]]; then
            break
        else
            print_error "Invalid choice"
        fi
    done
    local target="${snapshot_array[choice]}"
    print_warning "This action cannot be undone! Target: ${RED}$target${NC}"
    read -rp "Type 'DELETE' to confirm: " confirm
    [[ "$confirm" != "DELETE" ]] && print_status "Cancelled" && return
    if timeshift --delete --snapshot "$target"; then
        print_success "Snapshot deleted"
    else
        print_error "Deletion failed"
    fi
    pause_for_input
}

restore_snapshot() {
    print_header "Restore Snapshot"
    local snapshots
    snapshots=$(get_snapshots)
    if [[ -z "$snapshots" ]]; then
        print_warning "No snapshots available"
        pause_for_input
        return
    fi
    echo -e "\n${CYAN}Available Snapshots:${NC}"
    local -a snapshot_array=()
    local counter=1
    while IFS= read -r snap; do
        echo -e "  ${WHITE}$counter)${NC} $snap"
        snapshot_array[counter]="$snap"
        ((counter++))
    done <<< "$snapshots"
    echo -e "  ${WHITE}0)${NC} Cancel"
    while true; do
        read -rp "Select snapshot to restore [0-$((counter-1))]: " choice
        [[ "$choice" == "0" ]] && print_status "Cancelled" && return
        if [[ "$choice" =~ ^[0-9]+$ && $choice -ge 1 && $choice -lt $counter ]]; then
            break
        else
            print_error "Invalid choice"
        fi
    done
    local target="${snapshot_array[choice]}"
    echo -e "\n${RED}${BOLD}CRITICAL WARNING!${NC} Restoring will erase current system state."
    read -rp "Type 'RESTORE' to confirm: " confirm
    [[ "$confirm" != "RESTORE" ]] && print_status "Cancelled" && return
    print_status "Restoring snapshot: $target"
    if timeshift --restore --snapshot "$target" --skip-grub; then
        print_success "Restore initiated. Rebooting..."
        reboot
    else
        print_error "Restore failed"
    fi
}

list_snapshots() {
    print_header "Available Snapshots"
    local snaps
    snaps=$(get_snapshots)
    if [[ -z "$snaps" ]]; then
        print_warning "No snapshots found"
    else
        local count=1
        while IFS= read -r snap; do
            echo -e "${WHITE}$count.${NC} ${GREEN}$snap${NC}"
            ((count++))
        done <<< "$snaps"
        echo -e "\n${CYAN}Detailed list:${NC}"
        timeshift --list || true
    fi
    pause_for_input
}

show_system_info() {
    print_header "System Information"
    echo -e "${WHITE}Hostname:${NC} $(hostname)"
    echo -e "${WHITE}Kernel:${NC} $(uname -r)"
    echo -e "${WHITE}Uptime:${NC} $(uptime -p)"
    echo -e "\n${CYAN}Disk Usage:${NC}"
    df -h | grep -E '^/dev/' | head -5
    echo -e "\n${CYAN}TimeShift Status:${NC}"
    if timeshift --list &>/dev/null; then
        print_success "Operational"
        echo -e "${WHITE}Snapshots:${NC} $(get_snapshot_count)"
    else
        print_error "Not configured"
    fi
    pause_for_input
}

show_help() {
    echo -e "${CYAN}${BOLD}TimeShift Manager v${SCRIPT_VERSION}${NC}"
    echo -e "${WHITE}Author:${NC} Solo"
    echo -e "${WHITE}Description:${NC} An interactive command-line tool to manage system snapshots using TimeShift."
    echo
    echo -e "${CYAN}USAGE:${NC}"
    echo "  sudo $SCRIPT_NAME [OPTIONS]"
    echo
    echo -e "${CYAN}OPTIONS:${NC}"
    echo "  -h, --help       Show this help message and exit"
    echo "  -v, --version    Show version information and exit"
    echo "  -l, --list       List available snapshots and exit"
    echo "  -s, --status     Show system status and exit"
    echo
    echo -e "${CYAN}INTERACTIVE MENU:${NC}"
    echo "  When no options are provided, the script launches an interactive menu:"
    echo "    1) Create a new snapshot"
    echo "    2) Delete an existing snapshot"
    echo "    3) Restore your system to a previous snapshot"
    echo "    4) List all available snapshots with details"
    echo "    5) Display system and disk usage information"
    echo "    6) Exit the program"
    echo
    echo -e "${CYAN}NOTES:${NC}"
    echo "  - Must be run as root (use: sudo $SCRIPT_NAME)"
    echo "  - TimeShift must be installed and configured before use"
    echo "  - Restoring a snapshot will overwrite the current system state"
    echo
    echo -e "${CYAN}EXAMPLES:${NC}"
    echo "  sudo $SCRIPT_NAME"
    echo "      Launch interactive menu mode."
    echo
    echo "  sudo $SCRIPT_NAME --list"
    echo "      Display all snapshots and exit."
    echo
    echo "  sudo $SCRIPT_NAME --status"
    echo "      Show system and snapshot status, then exit."
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) show_help; exit 0 ;;
            -v|--version) echo "v${SCRIPT_VERSION}"; exit 0 ;;
            -l|--list) list_snapshots; exit 0 ;;
            -s|--status) show_system_info; exit 0 ;;
            *) print_error "Unknown option $1"; exit 1 ;;
        esac
        shift
    done
}

show_main_menu() {
    clear
    echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}TimeShift Manager v${SCRIPT_VERSION}${NC}       ${BLUE}║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"
    echo "1) Create snapshot"
    echo "2) Delete snapshot"
    echo "3) Restore snapshot"
    echo "4) List snapshots"
    echo "5) System info"
    echo "6) Exit"
    echo
}

main() {
    parse_arguments "$@"
    check_root
    check_dependencies
    touch "$LOG_FILE" 2>/dev/null || true
    while true; do
        show_main_menu
        read -rp "Choice [1-6]: " c
        case "$c" in
            1) create_snapshot ;;
            2) delete_snapshot ;;
            3) restore_snapshot ;;
            4) list_snapshots ;;
            5) show_system_info ;;
            6) print_success "Goodbye"; exit 0 ;;
            *) print_error "Invalid choice" ;;
        esac
    done
}

main "$@"
