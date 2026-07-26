#!/usr/bin/env bash
# ============================================================
# Linux Memory Optimization Tool
# Author: Miguel A. Carlo
# Description: Interactive memory utility for viewing memory
#              pressure and safely clearing Linux page cache,
#              dentries, and inode caches when appropriate.
# ============================================================

set -euo pipefail

# Colors via tput
readonly BOLD=$(tput bold)
readonly RED=$(tput setaf 1)
readonly GREEN=$(tput setaf 2)
readonly YELLOW=$(tput setaf 3)
readonly BLUE=$(tput setaf 4)
readonly MAGENTA=$(tput setaf 5)
readonly CYAN=$(tput setaf 6)
readonly RESET=$(tput sgr0)

# Function to display header
show_header() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "================================================"
    echo "          LINUX MEMORY OPTIMIZATION TOOL"
    echo "================================================"
    echo -e "${RESET}"
}

# Function to display error message and exit
error_exit() {
    echo -e "${RED}Error: $1${RESET}" >&2
    exit 1
}

# Function to show current memory usage
show_memory() {
    echo -e "${BLUE}Current Memory Usage:${RESET}\n---------------------"
    free -h
    echo
    echo -e "${MAGENTA}Cache/Shared Memory:${RESET}\n-------------------"
    awk '/^Mem/ {print "Total: " $2 " | Available: " $7}' <(free -m)
    echo
}

# Function to clear caches
clear_caches() {
    local level=$1
    if [ ! -w /proc/sys/vm/drop_caches ]; then
        error_exit "No write permission to /proc/sys/vm/drop_caches"
    fi

    echo -e "${YELLOW}Cleaning memory caches (Level $level)...${RESET}"
    sync
    echo "$level" > /proc/sys/vm/drop_caches
    sleep 2
}

# Function to clear swap
clear_swap() {
    if ! swapon --show | grep -q '.'; then
        echo -e "${YELLOW}No active swap space found. Skipping swap clear.${RESET}"
        return
    fi

    echo -e "${YELLOW}Clearing swap space...${RESET}"
    swapoff -a
    swapon -a
    sleep 1
}

# Check root privileges
if [ "$(id -u)" -ne 0 ]; then
    error_exit "This script requires root privileges. Please run with sudo."
fi

# Main menu
while true; do
    show_header
    show_memory

    echo -e "${GREEN}"
    echo "MAIN MENU"
    echo "---------"
    echo "1) Clear PageCache Only"
    echo "2) Clear Dentries & Inodes"
    echo "3) Clear All Caches (PageCache/Dentries/Inodes)"
    echo "4) Clear Swap Space Only"
    echo "5) Clear All Caches + Swap"
    echo "6) Show Memory Usage"
    echo "7) System Information"
    echo "8) Exit"
    echo -e "${RESET}"

    read -r -p "Enter your choice [1-8]: " choice
    case $choice in
        1)
            clear_caches 1 || true
            ;;
        2)
            clear_caches 2 || true
            ;;
        3)
            clear_caches 3 || true
            ;;
        4)
            clear_swap || true
            ;;
        5)
            clear_caches 3 || true
            clear_swap || true
            ;;
        6)
            # Memory will be shown automatically on next loop
            ;;
        7)
            echo -e "${MAGENTA}"
            echo "System Information:"
            echo "------------------"
            echo "OS: $(lsb_release -d | cut -f2-)"
            echo "Kernel: $(uname -r)"
            echo "Uptime: $(uptime -p)"
            echo "CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"
            echo -e "${RESET}"
            read -r -p "Press [Enter] to continue..."
            ;;
        8)
            echo "Exiting. Goodbye!"
            exit 0
            ;;
        *)
            echo "Invalid option. Please try again."
            sleep 2
            ;;
    esac
done
