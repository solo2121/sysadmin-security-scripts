#!/bin/bash

# Linux System Monitoring Script
# Enhanced version with interactive menu and detailed monitoring
# Features:
#   - Open port monitoring (ss, netstat, lsof)
#   - Process resource usage (CPU, memory)
#   - Network connection analysis
#   - System resource tracking (CPU, memory, disk, load)
#   - Color-coded output for better readability
#   - Dependency checks for required tools

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to display header
header() {
    echo -e "${YELLOW}"
    echo "================================================================="
    echo " $1"
    echo "================================================================="
    echo -e "${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for required tools
check_dependencies() {
    local missing=0
    local tools=("ss" "lsof" "netstat" "top" "free" "df" "uptime" "vmstat" "iostat" "mpstat")

    for tool in "${tools[@]}"; do
        if ! command_exists "$tool"; then
            echo -e "${RED}Error: $tool is not installed.${NC}"
            missing=$((missing + 1))
        fi
    done

    if [ $missing -gt 0 ]; then
        echo -e "${RED}Please install missing tools before running this script.${NC}"
        exit 1
    fi
}

# Monitor open ports
monitor_ports() {
    header "OPEN PORTS MONITORING"
    echo -e "${CYAN}Note: Run with sudo to see all processes${NC}\n"

    echo -e "${GREEN}[1] Using ss command:${NC}"
    ss -tulnp | awk 'BEGIN {printf "%-20s %-10s %-20s %-20s %-25s\n", "Protocol", "State", "Local Address", "Foreign Address", "Process"}
    NR>1 {printf "%-20s %-10s %-20s %-20s %-25s\n", $1, $2, $5, $6, $7}'

    echo -e "\n${GREEN}[2] Using netstat command:${NC}"
    netstat -tulnp 2>/dev/null | awk 'BEGIN {printf "%-10s %-10s %-20s %-20s %-25s\n", "Proto", "State", "Local Address", "Foreign Address", "PID/Program"}
    NR>2 {printf "%-10s %-10s %-20s %-20s %-25s\n", $1, $6, $4, $5, $7}'

    echo -e "\n${GREEN}[3] Using lsof command:${NC}"
    lsof -i -P -n 2>/dev/null | grep LISTEN | awk 'BEGIN {printf "%-10s %-10s %-15s %-10s %-15s\n", "Command", "PID", "User", "Protocol", "Ports"}
    {split($9, a, ":"); printf "%-10s %-10s %-15s %-10s %-15s\n", $1, $2, $3, $8, a[2]}'
}

# Monitor processes
monitor_processes() {
    header "PROCESS MONITORING"

    echo -e "${GREEN}[1] Top 10 CPU consuming processes:${NC}"
    ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | head -n 11 | awk 'BEGIN {printf "%-10s %-10s %-50s %-8s %-8s\n", "PID", "PPID", "COMMAND", "%MEM", "%CPU"}
    NR>1 {printf "%-10s %-10s %-50s %-8s %-8s\n", $1, $2, $3, $4, $5}'

    echo -e "\n${GREEN}[2] Top 10 memory consuming processes:${NC}"
    ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%mem | head -n 11 | awk 'BEGIN {printf "%-10s %-10s %-50s %-8s %-8s\n", "PID", "PPID", "COMMAND", "%MEM", "%CPU"}
    NR>1 {printf "%-10s %-10s %-50s %-8s %-8s\n", $1, $2, $3, $4, $5}'

    echo -e "\n${GREEN}[3] Process count by user:${NC}"
    ps -eo user=|sort|uniq -c | sort -rn | awk '{printf "%-15s %-10s\n", $2, $1}'
}

# Monitor network connections
monitor_network() {
    header "NETWORK CONNECTIONS"

    echo -e "${GREEN}[1] Active connections summary:${NC}"
    ss -s | head -n 5

    echo -e "\n${GREEN}[2] TCP connections:${NC}"
    ss -t -a | awk 'BEGIN {printf "%-10s %-25s %-25s %-15s\n", "State", "Local Address", "Remote Address", "Process"}
    NR>1 {printf "%-10s %-25s %-25s %-15s\n", $1, $4, $5, $6}'

    echo -e "\n${GREEN}[3] UDP connections:${NC}"
    ss -u -a | awk 'BEGIN {printf "%-25s %-25s %-15s\n", "Local Address", "Remote Address", "Process"}
    NR>1 {printf "%-25s %-25s %-15s\n", $4, $5, $6}'

    echo -e "\n${GREEN}[4] Interface statistics:${NC}"
    ip -s link | grep -v "lo:" | awk '/^[0-9]+:/ {print $2; getline; print $0; getline; print $0; print ""}'
}

# Monitor system resources
monitor_resources() {
    header "SYSTEM RESOURCES"

    echo -e "${GREEN}[1] CPU usage:${NC}"
    mpstat 1 1 | tail -n 2 | awk '{print "User: " $3 "%  System: " $5 "%  Idle: " $12 "%"}'

    echo -e "\n${GREEN}[2] Memory usage:${NC}"
    free -h | awk '/Mem/ {print "Total: " $2 "  Used: " $3 "  Free: " $4 "  Available: " $7}'

    echo -e "\n${GREEN}[3] Disk usage:${NC}"
    df -h | awk 'BEGIN {printf "%-20s %-8s %-8s %-8s %-8s %-12s\n", "Filesystem", "Size", "Used", "Avail", "Use%", "Mounted on"}
    NR>1 {printf "%-20s %-8s %-8s %-8s %-8s %-12s\n", $1, $2, $3, $4, $5, $6}'

    echo -e "\n${GREEN}[4] System load:${NC}"
    uptime | awk -F': ' '{print "Load average: " $2}'

    echo -e "\n${GREEN}[5] I/O Statistics:${NC}"
    iostat -dx 1 2 | tail -n +4
}

# Display main menu
show_menu() {
    echo -e "${BLUE}"
    echo "================================================================="
    echo " LINUX SYSTEM MONITORING DASHBOARD"
    echo "================================================================="
    echo -e "${NC}"
    echo -e "${GREEN}1. Open Ports Analysis${NC}"
    echo -e "   - Lists listening ports with processes (ss, netstat, lsof)"
    echo -e "${GREEN}2. Process Resource Usage${NC}"
    echo -e "   - Top CPU/Memory processes and user process counts"
    echo -e "${GREEN}3. Network Connections${NC}"
    echo -e "   - Active connections, TCP/UDP stats, interface metrics"
    echo -e "${GREEN}4. System Resources${NC}"
    echo -e "   - CPU, Memory, Disk, Load Average and I/O stats"
    echo -e "${GREEN}5. Comprehensive System Scan${NC}"
    echo -e "   - All reports combined (ports, processes, network, resources)"
    echo -e "${GREEN}6. Exit${NC}"
    echo -e "${CYAN}7. Refresh Menu${NC}"
    echo ""
}

# Main function
main() {
    clear
    check_dependencies

    while true; do
        clear
        show_menu
        read -r -p "Enter your choice [1-7]: " choice

        case $choice in
            1)
                clear
                monitor_ports
                ;;
            2)
                clear
                monitor_processes
                ;;
            3)
                clear
                monitor_network
                ;;
            4)
                clear
                monitor_resources
                ;;
            5)
                clear
                monitor_ports
                echo -e "\n${YELLOW}--------------------------------------------${NC}\n"
                monitor_processes
                echo -e "\n${YELLOW}--------------------------------------------${NC}\n"
                monitor_network
                echo -e "\n${YELLOW}--------------------------------------------${NC}\n"
                monitor_resources
                ;;
            6)
                echo -e "\n${GREEN}Exiting... Thank you for using the monitor!${NC}\n"
                exit 0
                ;;
            7)
                # Just refresh the menu
                ;;
            *)
                echo -e "\n${RED}Invalid option! Please choose 1-7${NC}"
                sleep 2
                ;;
        esac

        if [ "$choice" != "7" ] && [ "$choice" != "6" ]; then
            echo -e "\n"
            read -r -p "Press [Enter] to return to main menu..."
        fi
    done
}

# Execute main function
main
