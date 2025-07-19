#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Main menu function
main_menu() {
    clear
    echo -e "${YELLOW}"
    echo "===================================="
    echo "      Linux Log Analysis Tool       "
    echo "===================================="
    echo -e "${NC}"
    echo -e "${GREEN}1. System Logs (syslog)"
    echo "2. Authentication Logs (auth.log)"
    echo "3. Kernel Logs"
    echo "4. Apache/Nginx Access Logs"
    echo "5. Apache/Nginx Error Logs"
    echo "6. Custom Log File Analysis"
    echo "7. Real-time Log Monitoring"
    echo "8. Search Across All Logs"
    echo -e "${RED}9. Exit${NC}"
    echo -e "${YELLOW}====================================${NC}"
    read -p "Enter your choice [1-9]: " choice
}

# Function to analyze system logs
analyze_syslog() {
    clear
    echo -e "${YELLOW}==== SYSTEM LOG ANALYSIS (syslog) ====${NC}"
    echo ""
    
    echo -e "${BLUE}=== Last 20 System Errors ===${NC}"
    grep -i "error" /var/log/syslog | tail -n 20
    echo ""
    
    echo -e "${BLUE}=== Last 20 System Warnings ===${NC}"
    grep -i "warning" /var/log/syslog | tail -n 20
    echo ""
    
    echo -e "${BLUE}=== Most frequent error messages (top 10) ===${NC}"
    grep -i "error" /var/log/syslog | cut -d ' ' -f 5- | sort | uniq -c | sort -nr | head -n 10
    echo ""
    
    read -p "Press [Enter] to return to main menu..."
}

# Function to analyze auth logs
analyze_auth() {
    clear
    echo -e "${YELLOW}==== AUTHENTICATION LOG ANALYSIS ====${NC}"
    echo ""
    
    echo -e "${BLUE}=== Recent Failed Login Attempts ===${NC}"
    grep -i "failed" /var/log/auth.log | tail -n 20
    echo ""
    
    echo -e "${BLUE}=== Recent SSH Login Attempts ===${NC}"
    grep -i "sshd" /var/log/auth.log | tail -n 20
    echo ""
    
    echo -e "${BLUE}=== Users who logged in recently ===${NC}"
    grep -i "session opened" /var/log/auth.log | tail -n 10
    echo ""
    
    echo -e "${BLUE}=== Root Login Attempts ===${NC}"
    grep -i "root" /var/log/auth.log | tail -n 10
    echo ""
    
    read -p "Press [Enter] to return to main menu..."
}

# Function to analyze kernel logs
analyze_kernel() {
    clear
    echo -e "${YELLOW}==== KERNEL LOG ANALYSIS ====${NC}"
    echo ""
    
    echo -e "${BLUE}=== Last 20 Kernel Messages ===${NC}"
    tail -n 20 /var/log/kern.log
    echo ""
    
    echo -e "${BLUE}=== Kernel Errors ===${NC}"
    grep -i "error" /var/log/kern.log | tail -n 20
    echo ""
    
    echo -e "${BLUE}=== Hardware Detection Issues ===${NC}"
    grep -i "usb\|hd\|dma" /var/log/kern.log | tail -n 15
    echo ""
    
    read -p "Press [Enter] to return to main menu..."
}

# Function to analyze web server access logs
analyze_web_access() {
    clear
    echo -e "${YELLOW}==== WEB SERVER ACCESS LOG ANALYSIS ====${NC}"
    echo ""
    
    # Check for Apache or Nginx logs
    if [ -f "/var/log/apache2/access.log" ]; then
        LOG_FILE="/var/log/apache2/access.log"
        echo -e "${GREEN}Using Apache access logs${NC}"
    elif [ -f "/var/log/nginx/access.log" ]; then
        LOG_FILE="/var/log/nginx/access.log"
        echo -e "${GREEN}Using Nginx access logs${NC}"
    else
        echo -e "${RED}Could not find Apache or Nginx access logs${NC}"
        read -p "Press [Enter] to return to main menu..."
        return
    fi
    
    echo ""
    echo -e "${BLUE}=== Top 10 IPs accessing the server ===${NC}"
    awk '{print $1}' $LOG_FILE | sort | uniq -c | sort -nr | head -n 10
    echo ""
    
    echo -e "${BLUE}=== Top 10 requested URLs ===${NC}"
    awk '{print $7}' $LOG_FILE | sort | uniq -c | sort -nr | head -n 10
    echo ""
    
    echo -e "${BLUE}=== Recent 404 Errors ===${NC}"
    grep " 404 " $LOG_FILE | tail -n 10
    echo ""
    
    echo -e "${BLUE}=== Recent 500 Errors ===${NC}"
    grep " 500 " $LOG_FILE | tail -n 10
    echo ""
    
    read -p "Press [Enter] to return to main menu..."
}

# Function to analyze web server error logs
analyze_web_errors() {
    clear
    echo -e "${YELLOW}==== WEB SERVER ERROR LOG ANALYSIS ====${NC}"
    echo ""
    
    # Check for Apache or Nginx logs
    if [ -f "/var/log/apache2/error.log" ]; then
        LOG_FILE="/var/log/apache2/error.log"
        echo -e "${GREEN}Using Apache error logs${NC}"
    elif [ -f "/var/log/nginx/error.log" ]; then
        LOG_FILE="/var/log/nginx/error.log"
        echo -e "${GREEN}Using Nginx error logs${NC}"
    else
        echo -e "${RED}Could not find Apache or Nginx error logs${NC}"
        read -p "Press [Enter] to return to main menu..."
        return
    fi
    
    echo ""
    echo -e "${BLUE}=== Last 20 Error Messages ===${NC}"
    tail -n 20 $LOG_FILE
    echo ""
    
    echo -e "${BLUE}=== Most Frequent Errors (top 10) ===${NC}"
    grep -i "error" $LOG_FILE | cut -d ' ' -f 6- | sort | uniq -c | sort -nr | head -n 10
    echo ""
    
    echo -e "${BLUE}=== PHP Errors ===${NC}"
    grep -i "php" $LOG_FILE | tail -n 10
    echo ""
    
    read -p "Press [Enter] to return to main menu..."
}

# Function to analyze custom log file
analyze_custom() {
    clear
    echo -e "${YELLOW}==== CUSTOM LOG FILE ANALYSIS ====${NC}"
    echo ""
    
    read -p "Enter full path to log file: " custom_log
    
    if [ ! -f "$custom_log" ]; then
        echo -e "${RED}File does not exist or is not accessible${NC}"
        read -p "Press [Enter] to return to main menu..."
        return
    fi
    
    echo ""
    echo -e "${GREEN}Analyzing $custom_log${NC}"
    echo ""
    
    echo -e "${BLUE}=== Last 20 Lines ===${NC}"
    tail -n 20 "$custom_log"
    echo ""
    
    echo -e "${BLUE}=== Error Count ===${NC}"
    grep -i "error" "$custom_log" | wc -l
    echo ""
    
    echo -e "${BLUE}=== Last 10 Errors ===${NC}"
    grep -i "error" "$custom_log" | tail -n 10
    echo ""
    
    echo -e "${BLUE}=== Unique Error Types ===${NC}"
    grep -i "error" "$custom_log" | cut -d ' ' -f 6- | sort | uniq -c | sort -nr | head -n 10
    echo ""
    
    read -p "Press [Enter] to return to main menu..."
}

# Function for real-time monitoring
realtime_monitor() {
    clear
    echo -e "${YELLOW}==== REAL-TIME LOG MONITORING ====${NC}"
    echo ""
    
    echo "1. Monitor system logs (syslog)"
    echo "2. Monitor authentication logs"
    echo "3. Monitor kernel logs"
    echo "4. Monitor web server access logs"
    echo "5. Monitor web server error logs"
    echo "6. Monitor custom log file"
    echo "7. Back to main menu"
    echo ""
    
    read -p "Enter your choice [1-7]: " rt_choice
    
    case $rt_choice in
        1) tail -f /var/log/syslog ;;
        2) tail -f /var/log/auth.log ;;
        3) tail -f /var/log/kern.log ;;
        4)
            if [ -f "/var/log/apache2/access.log" ]; then
                tail -f /var/log/apache2/access.log
            elif [ -f "/var/log/nginx/access.log" ]; then
                tail -f /var/log/nginx/access.log
            else
                echo -e "${RED}Could not find access logs${NC}"
                read -p "Press [Enter] to continue..."
                realtime_monitor
            fi
            ;;
        5)
            if [ -f "/var/log/apache2/error.log" ]; then
                tail -f /var/log/apache2/error.log
            elif [ -f "/var/log/nginx/error.log" ]; then
                tail -f /var/log/nginx/error.log
            else
                echo -e "${RED}Could not find error logs${NC}"
                read -p "Press [Enter] to continue..."
                realtime_monitor
            fi
            ;;
        6)
            read -p "Enter full path to log file: " custom_log
            if [ -f "$custom_log" ]; then
                tail -f "$custom_log"
            else
                echo -e "${RED}File does not exist or is not accessible${NC}"
                read -p "Press [Enter] to continue..."
                realtime_monitor
            fi
            ;;
        7) return ;;
        *) 
            echo -e "${RED}Invalid option${NC}"
            read -p "Press [Enter] to continue..."
            realtime_monitor
            ;;
    esac
}

# Function to search across all logs
search_all_logs() {
    clear
    echo -e "${YELLOW}==== SEARCH ACROSS ALL LOGS ====${NC}"
    echo ""
    
    read -p "Enter search term: " search_term
    
    if [ -z "$search_term" ]; then
        echo -e "${RED}Search term cannot be empty${NC}"
        read -p "Press [Enter] to return to main menu..."
        return
    fi
    
    echo ""
    echo -e "${GREEN}Searching for '$search_term' in all logs...${NC}"
    echo ""
    
    # Common log locations
    LOG_FILES="/var/log/syslog /var/log/auth.log /var/log/kern.log /var/log/dmesg"
    LOG_FILES="$LOG_FILES /var/log/apache2/*.log /var/log/nginx/*.log"
    LOG_FILES="$LOG_FILES /var/log/mysql/*.log /var/log/apt/*.log"
    
    for log in $LOG_FILES; do
        if [ -f "$log" ]; then
            echo -e "${BLUE}=== Results in $log ===${NC}"
            grep -i "$search_term" "$log" | tail -n 10
            echo ""
        fi
    done
    
    read -p "Press [Enter] to return to main menu..."
}

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}This script should be run as root for full log access${NC}"
    read -p "Continue anyway? [y/N]: " cont
    if [ "$cont" != "y" ] && [ "$cont" != "Y" ]; then
        exit 1
    fi
fi

# Main loop
while true; do
    main_menu
    case $choice in
        1) analyze_syslog ;;
        2) analyze_auth ;;
        3) analyze_kernel ;;
        4) analyze_web_access ;;
        5) analyze_web_errors ;;
        6) analyze_custom ;;
        7) realtime_monitor ;;
        8) search_all_logs ;;
        9)
            echo -e "${GREEN}Exiting...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option. Please try again.${NC}"
            sleep 1
            ;;
    esac
done