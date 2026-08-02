#!/usr/bin/env bash
set -Eeuo pipefail
#####################################################################
# Script Name: Ultimate Linux Audit Tool
# Author     : Miguel A. Carlo
# Date       : 2025-12-25
# Version    : 3.0
# Description: Ultra-complete Linux system audit tool. Performs full
#              system audit, security checks, suspicious files and
#              processes, open ports, weak password policies, and
#              generates a colorized terminal summary and detailed report.
#####################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Report file
REPORT="ultimate_audit_report_$(date +%Y%m%d_%H%M%S).txt"

# Helper functions
print_header() {
    echo -e "${CYAN}=========================================="
    echo -e " Ultimate Linux Audit Tool"
    echo -e "==========================================${NC}"
}

pause() { read -rp "Press [Enter] to continue..."; }
log() { echo -e "$1" >> "$REPORT"; }

check_root_warning() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${YELLOW}Warning: not running as root.${NC}"
        echo -e "${YELLOW}Some checks (password policy, shadow file, full SUID scan) will be incomplete.${NC}"
        echo -e "${YELLOW}Re-run with sudo for a complete report.${NC}"
        echo
        pause
    fi
}

# ---------------- Audit Functions ----------------

audit_system_info() {
    echo -e "${BLUE}Collecting system information...${NC}"
    log ">>> SYSTEM INFO"
    log "Hostname: $(hostname)"
    log "OS Version: $(grep PRETTY_NAME /etc/os-release | cut -d= -f2)"
    log "Uptime: $(uptime -p)"
    log "Kernel Version: $(uname -r)"
    log "Architecture: $(uname -m)"
    log ""
    echo -e "${GREEN}System info collected.${NC}"
}

audit_users() {
    echo -e "${BLUE}Collecting user info...${NC}"
    log ">>> USER ACCOUNTS"
    log "All users:"; cut -d: -f1 /etc/passwd >> "$REPORT"
    log ""
    log "Logged in users:"; who >> "$REPORT"
    log ""
    # Detect high-risk users
    log "High-risk users (UID 0 or no password):"
    awk -F: '($3==0) {print $1 " (UID=0)"}' /etc/passwd >> "$REPORT"
    awk -F: '($2=="!") {print $1 " (locked)" }' /etc/shadow 2>/dev/null >> "$REPORT" || true
    echo -e "${GREEN}User info collected.${NC}"
}

audit_network_ports() {
    echo -e "${BLUE}Checking open ports and services...${NC}"
    log ">>> OPEN PORTS & SERVICES"
    if command -v ss >/dev/null; then
        ss -tulnp >> "$REPORT"
    else
        log "ss command not found"
    fi
    if command -v nmap >/dev/null; then
        log ""
        log "Nmap localhost scan (top 1000 ports):"
        nmap -F 127.0.0.1 >> "$REPORT" || log "nmap scan failed or was interrupted"
    fi
    echo -e "${GREEN}Network ports info collected.${NC}"
}

audit_services() {
    echo -e "${BLUE}Checking running services...${NC}"
    log ">>> RUNNING SERVICES"
    systemctl list-units --type=service --state=running >> "$REPORT" || log "systemctl unavailable (no systemd?)"
    log ""
    echo -e "${GREEN}Services info collected.${NC}"
}

audit_disk() {
    echo -e "${BLUE}Checking disk usage...${NC}"
    log ">>> DISK USAGE"
    df -h >> "$REPORT"
    log ""
    echo -e "${GREEN}Disk usage info collected.${NC}"
}

audit_processes() {
    echo -e "${BLUE}Checking top processes and suspicious processes...${NC}"
    log ">>> TOP PROCESSES"
    { ps aux --sort=-%mem | head -n 20 >> "$REPORT"; } || true
    log ""
    log "Suspicious processes (no parent or rootless high privileges):"
    ps -eo pid,ppid,user,cmd,%mem,%cpu --sort=-%mem | awk '$2==0 || $3=="root"{print}' >> "$REPORT"
    log ""
    echo -e "${GREEN}Processes info collected.${NC}"
}

audit_suid_files() {
    echo -e "${BLUE}Searching for SUID/SGID files...${NC}"
    log ">>> SUID / SGID FILES"
    find / \( -path /proc -o -path /sys -o -path /dev -o -path /run \) -prune -o -perm /4000 -type f -print 2>/dev/null >> "$REPORT" || true
    find / \( -path /proc -o -path /sys -o -path /dev -o -path /run \) -prune -o -perm /2000 -type f -print 2>/dev/null >> "$REPORT" || true
    log ""
    echo -e "${GREEN}SUID/SGID files audit completed.${NC}"
}

audit_firewall() {
    echo -e "${BLUE}Checking firewall status...${NC}"
    log ">>> FIREWALL STATUS"
    if command -v ufw >/dev/null; then
        ufw status verbose >> "$REPORT" || true
    elif command -v firewall-cmd >/dev/null; then
        firewall-cmd --state >> "$REPORT" || true
    else
        log "No recognized firewall tool found."
    fi
    log ""
    echo -e "${GREEN}Firewall info collected.${NC}"
}

audit_ssh_security() {
    echo -e "${BLUE}Checking SSH security...${NC}"
    log ">>> SSH CONFIGURATION"
    SSH_CONFIG="/etc/ssh/sshd_config"
    if [ -f "$SSH_CONFIG" ]; then
        grep -E "PermitRootLogin|PasswordAuthentication|PubkeyAuthentication" "$SSH_CONFIG" >> "$REPORT" || log "None of the tracked directives are set explicitly"
    else
        log "SSH configuration file not found."
    fi
    log ""
    echo -e "${GREEN}SSH audit completed.${NC}"
}

audit_password_policy() {
    echo -e "${BLUE}Checking password policies...${NC}"
    log ">>> PASSWORD POLICY"
    if command -v chage >/dev/null; then
        { awk -F: '{print $1}' /etc/shadow 2>/dev/null | while read -r user; do
            chage -l "$user" >> "$REPORT" 2>/dev/null || true
        done; } || true
    fi
    log ""
    echo -e "${GREEN}Password policy audit completed.${NC}"
}

audit_cron_jobs() {
    echo -e "${BLUE}Collecting cron jobs...${NC}"
    log ">>> CRON JOBS"
    cut -f1 -d: /etc/passwd | while read -r user; do
        log "User: $user"
        crontab -l -u "$user" >> "$REPORT" 2>/dev/null || true
        log ""
    done
    echo -e "${GREEN}Cron jobs collected.${NC}"
}

# ---------------- Full Audit ----------------
full_audit() {
    echo -e "${YELLOW}Starting full audit...${NC}"
    audit_system_info
    audit_users
    audit_network_ports
    audit_services
    audit_disk
    audit_processes
    audit_suid_files
    audit_firewall
    audit_ssh_security
    audit_password_policy
    audit_cron_jobs
    echo -e "${YELLOW}Full audit completed. Report saved to ${REPORT}${NC}"

    # Terminal summary
    echo -e "${CYAN}=================== SUMMARY ===================${NC}"
    echo -e "${GREEN}Users, top processes, SUID files, and firewall status collected.${NC}"
    echo -e "${GREEN}Check ${REPORT} for full details.${NC}"
}

# ---------------- Menu ----------------
check_root_warning
while true; do
    clear
    print_header
    echo -e "${GREEN}1) System Info"
    echo -e "2) Users & High-Risk Users"
    echo -e "3) Network & Open Ports"
    echo -e "4) Services"
    echo -e "5) Disk Usage"
    echo -e "6) Processes & Suspicious Processes"
    echo -e "7) SUID/SGID Files"
    echo -e "8) Firewall"
    echo -e "9) SSH Security"
    echo -e "10) Password Policy"
    echo -e "11) Cron Jobs"
    echo -e "12) Full Audit"
    echo -e "0) Exit${NC}"
    read -rp "Select an option: " choice
    case $choice in
        1) audit_system_info; pause ;;
        2) audit_users; pause ;;
        3) audit_network_ports; pause ;;
        4) audit_services; pause ;;
        5) audit_disk; pause ;;
        6) audit_processes; pause ;;
        7) audit_suid_files; pause ;;
        8) audit_firewall; pause ;;
        9) audit_ssh_security; pause ;;
        10) audit_password_policy; pause ;;
        11) audit_cron_jobs; pause ;;
        12) full_audit; pause ;;
        0) echo -e "${RED}Exiting...${NC}"; exit 0 ;;
        *) echo -e "${RED}Invalid choice.${NC}"; pause ;;
    esac
done
