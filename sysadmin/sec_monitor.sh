#!/bin/bash

# Enhanced Security Monitoring Script
# Version 2.1 - With Flatpak/Zed Editor support

# Configuration
LOG_FILE="/var/log/security_monitor.log"
ALERT_EMAIL="admin@example.com"
WHITELIST_PROCESSES="Xorg|systemd-timesyncd|kworker|i2pd|at-spi-bus-launcher|dbus-launch|sshd|crond|rsyslogd|zed-editor|flatpak"
WHITELIST_TEMP_FILES=".X[0-9]-lock|.ICE-unix|.XIM-unix|zed-cli://"
SUSPICIOUS_PATTERNS="(nc|netcat|nmap|masscan|miner|xmrig|\./|tmp/[^ ]*\.(sh|py)|httpd|pty|/dev/shm/)"
FLATPAK_PATHS="/var/lib/flatpak/|/home/*/.local/share/flatpak/"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Enhanced logging
log_message() {
    local level=$1
    local message=$2

    case $level in
        "INFO") echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE" ;;
        "WARNING") echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE" ;;
        "ALERT") echo -e "${RED}[ALERT]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE" ;;
        "DEBUG") echo -e "${GREEN}[DEBUG]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE" ;;
    esac
}

# Network monitoring
check_network_connections() {
    log_message "INFO" "Checking network connections..."

    netstat -tuln | grep LISTEN | grep -vE ":(22|80|443|53|631|5353)" | while read -r line; do
        log_message "WARNING" "Unusual listening port: $line"
    done

    netstat -tupln | grep ESTABLISHED | grep -vE ":(22|80|443|53)" | while read -r line; do
        log_message "ALERT" "Suspicious outbound connection: $line"
    done
}

# User activity monitoring
check_user_activity() {
    log_message "INFO" "Checking user activity..."

    local failed_threshold=5
    grep "Failed password" /var/log/auth.log 2>/dev/null | awk '{print $1,$2,$3,$9}' | sort | uniq -c | \
    awk -v threshold=$failed_threshold '{if ($1 > threshold) print $0}' | while read -r line; do
        log_message "ALERT" "Brute force attempt: $line"
    done

    if [ -f /tmp/last_users.txt ]; then
        comm -23 <(cut -d: -f1 /etc/passwd | sort) <(sort /tmp/last_users.txt) | grep -vE "backup|sync|systemd-" | \
        while read -r user; do
            log_message "ALERT" "New user detected: $user"
        done
    fi
    cut -d: -f1 /etc/passwd | sort > /tmp/last_users.txt
}

# File system monitoring
check_file_integrity() {
    log_message "INFO" "Checking file system integrity..."

    find /etc /bin /sbin -type f -mtime -1 2>/dev/null | grep -vE "/etc/ssl/certs|/var/lib/dpkg" | \
    while read -r file; do
        log_message "WARNING" "Recently modified system file: $file"
    done

    find /tmp /var/tmp -name ".*" -type f 2>/dev/null | grep -vE "$WHITELIST_TEMP_FILES" | \
    while read -r file; do
        log_message "WARNING" "Hidden temp file: $file"
    done
}

# Advanced process checking
check_processes() {
    log_message "INFO" "Scanning running processes..."

    ps aux | pgrep -E "$SUSPICIOUS_PATTERNS" | pgrep -vE "grep|$WHITELIST_PROCESSES|\[.*\]" | while read -r line; do
        pid=$(echo "$line" | awk '{print $2}')
        cmd=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf $i" "; print ""}')

        # Skip Flatpak and known safe paths
        if [[ "$cmd" =~ $FLATPAK_PATHS ]] || [[ "$cmd" == *"zed-cli://"* ]]; then
            log_message "DEBUG" "Whitelisted application: $(echo "$cmd" | cut -d' ' -f1)"
            continue
        fi

        if [ -f "/proc/$pid/exe" ]; then
            origin=$(readlink -f "/proc/$pid/exe")

            if [[ "$origin" == /usr/* || "$origin" == /lib* || "$origin" =~ $FLATPAK_PATHS ]]; then
                log_message "DEBUG" "Verified system binary: $(basename "$origin")"
                continue
            fi

            log_message "ALERT" "Suspicious process: $cmd (Origin: $origin)"
        else
            log_message "ALERT" "Hidden process: $cmd"
        fi
    done
}

# System log monitoring
check_system_logs() {
    log_message "INFO" "Checking system logs..."

    dmesg | grep -i "error\|warning\|fail" | grep -vE "ACPI Error|usb usb.*port.*disabled" | \
    while read -r line; do
        log_message "WARNING" "Kernel issue: $line"
    done

    grep -i "authentication failure\|invalid user\|connection closed" /var/log/auth.log 2>/dev/null | \
    while read -r line; do
        log_message "INFO" "Auth event: $line"
    done
}

# Notification system
send_alert_email() {
    if grep -q "ALERT:" "$LOG_FILE"; then
        local alert_count=$
        (grep -c "ALERT:" "$LOG_FILE")
        log_message "INFO" "Sending alert with $alert_count issues"
        echo -e "Security Alerts:\n\n$(grep -A 1 "ALERT:" "$LOG_FILE" | tail -n 20)" | \
        mail -s "Security Alert: $(hostname)" "$ALERT_EMAIL"
    fi
}

# Menu system
show_menu() {
    while true; do
        clear
        echo -e "${BLUE}==== Security Monitoring Menu ====${NC}"
        echo -e "1. ${GREEN}Run Full Scan${NC}"
        echo -e "2. ${YELLOW}Network Check${NC}"
        echo -e "3. ${YELLOW}User Activity${NC}"
        echo -e "4. ${YELLOW}Process Scan${NC}"
        echo -e "5. ${YELLOW}View Status${NC}"
        echo -e "6. ${RED}Exit${NC}"
        echo -n "Select option [1-6]: "

        read -r choice
        case $choice in
            1) run_full_scan ;;
            2) check_network_connections ;;
            3) check_user_activity ;;
            4) check_processes ;;
            5) show_status ;;
            6) exit 0 ;;
            *) echo -e "${RED}Invalid option!${NC}"; sleep 1 ;;
        esac
        echo -e "\n${GREEN}Press enter to continue...${NC}"
        read -r
    done
}

# Core functions
run_full_scan() {
    log_message "INFO" "Starting comprehensive security scan..."
    check_network_connections
    check_user_activity
    check_file_integrity
    check_processes
    check_system_logs
    log_message "INFO" "Scan completed"
    send_alert_email
}

show_status() {
    clear
    echo -e "${BLUE}==== Security Status ====${NC}"
    echo -e "Last scan: $(date -r "$LOG_FILE" 2>/dev/null || echo "Never")"
    echo -e "\n${YELLOW}Recent alerts:${NC}"
    grep "ALERT:" "$LOG_FILE" | tail -n 5 || echo "None found"
    echo -e "\n${GREEN}Whitelisted applications:${NC}"
    echo "$WHITELIST_PROCESSES" | tr '|' '\n'
    read -rp "Press enter to continue..."
}

# Initialization
[ "$(id -u)" -ne 0 ] && echo -e "${RED}Run as root!${NC}" && exit 1
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

# Start
show_menu
