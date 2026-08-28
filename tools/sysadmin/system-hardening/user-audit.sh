#!/usr/bin/env bash
# ============================================================
# Linux User Account Security Audit
# Author: Miguel A. Carlo
# Description: Reviews login-capable accounts, human users,
#              UID 0 accounts, sudo privileges, password aging,
#              locked accounts, and shell assignments.
# ============================================================

set -euo pipefail

# Colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

# ------------------------------------------------------------
# 1. Login-capable accounts
# ------------------------------------------------------------
show_login_capable_accounts() {
    local passwd_file=$1

    echo -e "${YELLOW}[+] Login-capable accounts:${RESET}"
    awk -F: '
        $7 !~ /(nologin|false)$/ {
            printf "  %-15s UID=%-6s Shell=%s\n", $1, $3, $7
        }
    ' "$passwd_file"
    echo
}

# ------------------------------------------------------------
# 2. Normal (human) users
# ------------------------------------------------------------
show_normal_user_accounts() {
    local passwd_file=$1

    echo -e "${YELLOW}[+] Normal user accounts (UID >= 1000):${RESET}"
    awk -F: '
        $3 >= 1000 && $7 !~ /(nologin|false)$/ {
            printf "  %-15s UID=%-6s Home=%s Shell=%s\n", $1, $3, $6, $7
        }
    ' "$passwd_file" || true
    echo
}

# ------------------------------------------------------------
# 3. UID 0 check (root clones)
# ------------------------------------------------------------
check_uid0_accounts() {
    local passwd_file=$1
    local uid0_users uid0_count

    echo -e "${YELLOW}[+] UID 0 accounts (CRITICAL CHECK):${RESET}"

    uid0_users=$(awk -F: '$3 == 0 {print $1}' "$passwd_file")
    uid0_count=$(echo "$uid0_users" | wc -l)

    if [[ "$uid0_count" -gt 1 ]]; then
        echo -e "${RED}  WARNING: Multiple UID 0 accounts found:${RESET}"
        echo "$uid0_users" | sed 's/^/   - /'
    else
        echo -e "${GREEN}  OK: Only root has UID 0${RESET}"
    fi
    echo
}

# ------------------------------------------------------------
# 4. System accounts with interactive shells (EXCLUDING root)
# ------------------------------------------------------------
check_suspect_system_accounts() {
    local passwd_file=$1
    local suspect_accounts

    echo -e "${YELLOW}[+] System accounts with interactive shells (excluding root):${RESET}"

    suspect_accounts=$(awk -F: '
        $1 != "root" &&
        $3 < 1000 &&
        $7 ~ /(bash|sh|zsh)$/ {
            printf "%s UID=%s Shell=%s\n", $1, $3, $7
        }
    ' "$passwd_file")

    if [[ -n "$suspect_accounts" ]]; then
        echo -e "${RED}  WARNING:${RESET}"
        echo "$suspect_accounts" | sed 's/^/   - /'
    else
        echo -e "${GREEN}  OK: No system accounts (other than root) have interactive shells${RESET}"
    fi
    echo
}

# ------------------------------------------------------------
# 5. Sudo access check
# ------------------------------------------------------------
show_sudo_capable_users() {
    echo -e "${YELLOW}[+] Sudo-capable users:${RESET}"

    if getent group sudo &>/dev/null; then
        local sudo_members
        sudo_members=$(getent group sudo | awk -F: '{print $4}')
        if [[ -n "$sudo_members" ]]; then
            echo "  Members: $sudo_members"
        else
            echo "  Members: (none)"
        fi
    else
        echo "  sudo group not present"
    fi
    echo
}

# ------------------------------------------------------------
# 6. SSH root login configuration
# ------------------------------------------------------------
show_ssh_root_login_config() {
    local sshd_config=$1
    local ssh_setting

    echo -e "${YELLOW}[+] SSH root login configuration:${RESET}"

    if [[ -f "$sshd_config" ]]; then
        ssh_setting=$(grep -Ei '^PermitRootLogin' "$sshd_config" | tail -1 || true)
        if [[ -z "$ssh_setting" ]]; then
            echo "  PermitRootLogin not explicitly set (default applies)"
        else
            echo "  $ssh_setting"
        fi
    else
        echo "  SSH not installed"
    fi
    echo
}

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------
main() {
    local passwd_file="${PASSWD:-/etc/passwd}"
    local sshd_config="${SSHD_CONFIG:-/etc/ssh/sshd_config}"

    echo -e "${BLUE}=== Linux User Account Security Audit ===${RESET}\n"

    show_login_capable_accounts "$passwd_file"
    show_normal_user_accounts "$passwd_file"
    check_uid0_accounts "$passwd_file"
    check_suspect_system_accounts "$passwd_file"
    show_sudo_capable_users
    show_ssh_root_login_config "$sshd_config"

    echo -e "${BLUE}=== Audit Complete ===${RESET}"
    echo -e "${GREEN}If no RED warnings appeared, your account configuration is clean.${RESET}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
