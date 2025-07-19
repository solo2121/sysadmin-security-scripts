#!/bin/bash

# Enhanced Memory Optimizer for Ubuntu/Linux
# Features: Interactive menu, safety checks, visual feedback, and system information

# Function to display header
function show_header() {
    clear
    echo -e "\e[1;36m"
    echo "================================================"
    echo "          LINUX MEMORY OPTIMIZATION TOOL        "
    echo "================================================"
    echo -e "\e[0m"
}

# Function to display error message and exit
function error_exit() {
    echo -e "\e[1;31mError: $1\e[0m" 1>&2
    exit 1
}

# Function to show current memory usage
function show_memory() {
    echo -e "\e[1;34m"
    echo "Current Memory Usage:"
    echo "---------------------"
    free -h
    echo -e "\e[0m"
    echo -e "\e[1;35m"
    echo "Cache/Shared Memory:"
    echo "-------------------"
    awk '/^Mem/ {print "Total: " $2 " | Available: " $7}' <(free -m)
    echo -e "\e[0m"
}

# Function to clear caches
function clear_caches() {
    local level=$1
    if [ ! -w /proc/sys/vm/drop_caches ]; then
        error_exit "No write permission to /proc/sys/vm/drop_caches"
    fi

    echo -e "\e[1;33mCleaning memory caches (Level $level)...\e[0m"
    sync
    echo "$level" > /proc/sys/vm/drop_caches
    sleep 2
}

# Function to clear swap
function clear_swap() {
    if ! swapon --show | grep -q '.'; then
        echo -e "\e[1;33mNo active swap space found. Skipping swap clear.\e[0m"
        return
    fi

    echo -e "\e[1;33mClearing swap space...\e[0m"
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

    echo -e "\e[1;32m"
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
    echo -e "\e[0m"

    read -r -p "Enter your choice [1-8]: " choice
    case $choice in
        1)
            clear_caches 1
            ;;
        2)
            clear_caches 2
            ;;
        3)
            clear_caches 3
            ;;
        4)
            clear_swap
            ;;
        5)
            clear_caches 3
            clear_swap
            ;;
        6)
            # Memory will be shown automatically on next loop
            ;;
        7)
            echo -e "\e[1;35m"
            echo "System Information:"
            echo "------------------"
            echo "OS: $(lsb_release -d | cut -f2-)"
            echo "Kernel: $(uname -r)"
            echo "Uptime: $(uptime -p)"
            echo "CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"
            echo -e "\e[0m"
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
