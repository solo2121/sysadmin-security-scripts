#!/bin/bash
# TimeShift Manager - System Snapshot Management Tool
# Description: Interactive shell script for managing system snapshots with TimeShift
# Version: 4.0
# Author: Solo
# Last Modified: 2025-07-11

set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Define color variables
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}This script must be run as root. Use sudo.${NC}" >&2
    exit 1
fi

# Check for required packages
check_dependencies() {
    local missing=()

    if ! command -v timeshift &> /dev/null; then
        missing+=("timeshift")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}Missing dependencies:${NC} ${missing[*]}"
        echo -e "Install with: ${CYAN}sudo apt install ${missing[*]}${NC}"
        exit 1
    fi
}

check_dependencies

# Function to get snapshot tags
get_snapshot_tags() {
    timeshift --list 2>/dev/null | grep -E '^[0-9]+ :' | awk -F':' '{print $2}' | awk '{$1=$1;print}'
}

# Function to create snapshot
create_snapshot() {
    echo -e "\n${GREEN}Creating new snapshot...${NC}"
    read -rp "$(echo -e "${CYAN}Enter snapshot description (optional): ${NC}")" description
    if [ -z "$description" ]; then
        description="Manual snapshot $(date '+%Y-%m-%d %H:%M:%S')"
    fi
    timeshift --create --comments "$description"
    echo -e "${GREEN}✓ Snapshot created successfully${NC}"
    echo -n "Press Enter to continue... "
    read -r
}

# Function to delete snapshot
delete_snapshot() {
    # Get snapshot tags
    local tags=()
    while read -r tag; do
        [ -n "$tag" ] && tags+=("$tag")
    done < <(get_snapshot_tags)

    if [ ${#tags[@]} -eq 0 ]; then
        echo -e "\n${YELLOW}No snapshots available to delete.${NC}"
        echo -n "Press Enter to continue... "
        read -r
        return
    fi

    echo -e "\n${CYAN}Available Snapshots:${NC}"
    PS3="$(echo -e "${MAGENTA}Enter the NUMBER of the snapshot to delete (0 to cancel): ${NC}")"
    select tag in "${tags[@]}"; do
        if [[ "$REPLY" == "0" ]]; then
            return
        elif [ -n "$tag" ]; then
            echo -e "\n${YELLOW}WARNING: This action cannot be undone!${NC}"
            echo -e "Snapshot to delete: ${CYAN}$tag${NC}"
            read -rp "Confirm deletion? (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                timeshift --delete --snapshot "$tag"
                echo -e "${GREEN}✓ Snapshot deleted successfully${NC}"
                echo -n "Press Enter to continue... "
                read -r
                return
            else
                echo -e "${BLUE}Deletion canceled${NC}"
                echo -n "Press Enter to continue... "
                read -r
                return
            fi
        else
            echo -e "${RED}Invalid selection. Please choose a valid number.${NC}"
        fi
    done
}

# Function to restore snapshot
restore_snapshot() {
    # Get snapshot tags
    local tags=()
    while read -r tag; do
        [ -n "$tag" ] && tags+=("$tag")
    done < <(get_snapshot_tags)

    if [ ${#tags[@]} -eq 0 ]; then
        echo -e "\n${YELLOW}No snapshots available to restore.${NC}"
        echo -n "Press Enter to continue... "
        read -r
        return
    fi

    echo -e "\n${CYAN}Available Snapshots:${NC}"
    PS3="$(echo -e "${MAGENTA}Enter the NUMBER of the snapshot to restore (0 to cancel): ${NC}")"
    select tag in "${tags[@]}"; do
        if [[ "$REPLY" == "0" ]]; then
            return
        elif [ -n "$tag" ]; then
            echo -e "\n${RED}WARNING: System will reboot to restore snapshot!${NC}"
            echo -e "Snapshot to restore: ${CYAN}$tag${NC}"
            read -rp "Are you sure? (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo -e "${GREEN}Restoring system to snapshot...${NC}"
                timeshift --restore --snapshot "$tag" --reboot
                exit 0
            else
                echo -e "${BLUE}Restore canceled${NC}"
                echo -n "Press Enter to continue... "
                read -r
                return
            fi
        else
            echo -e "${RED}Invalid selection. Please choose a valid number.${NC}"
        fi
    done
}

# Function to list snapshots
list_snapshots() {
    echo -e "\n${CYAN}Available Snapshots:${NC}"
    timeshift --list
    echo -n "Press Enter to continue... "
    read -r
}

# Main menu
while true; do
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════╗"
    echo -e "║  ${CYAN}▄█▀▀▀▄█   ${GREEN}🕒 TIME SHIFT MANAGER ${CYAN}v4.0 ${BLUE}        "
    echo -e "║  █${CYAN}▒▒▒▒▒${BLUE}█   ${MAGENTA}● Professional Backup Utility ${BLUE}  "
    echo -e "║  █${CYAN}▒${RED}■${CYAN}▒${RED}■${CYAN}▒${BLUE}█   ${YELLOW}══════════════════════════${BLUE}    "
    echo -e "║   ${BLUE}▀████▀                            ${BLUE}      "
    echo -e "╠══════════════════════════════════════════════════╣"
    echo -e "║  ${GREEN}1) Create new snapshot${BLUE}                         "
    echo -e "║  ${RED}2) Delete snapshot${BLUE}                             "
    echo -e "║  ${CYAN}3) Restore snapshot${BLUE}                            "
    echo -e "║  ${YELLOW}4) List snapshots${BLUE}                              "
    echo -e "║  ${MAGENTA}5) Exit${BLUE}                                     "
    echo -e "╚══════════════════════════════════════════════════╝${NC}"

    read -rp "$(echo -e "${MAGENTA}Enter choice [${GREEN}1${MAGENTA}-${GREEN}5${MAGENTA}]: ${NC}")" choice

    case $choice in
        1) create_snapshot ;;
        2) delete_snapshot ;;
        3) restore_snapshot ;;
        4) list_snapshots ;;
        5) echo -e "${GREEN}Exiting...${NC}"; exit 0 ;;
        *) echo -e "${RED}Invalid option. Try again.${NC}"; sleep 1 ;;
    esac
done
