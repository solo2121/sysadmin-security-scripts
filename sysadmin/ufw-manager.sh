#!/usr/bin/env bash
# -------------------------------------------------------------
#  UFW Firewall Management Script  –  v1.2
#  Requires: ufw, bash 4+, root privileges
# -------------------------------------------------------------
set -euo pipefail
IFS=$'\n\t'
# -------------------------------------------------------------
# This script provides a menu-driven interface to manage UFW
# (Uncomplicated Firewall) rules, including adding, deleting,
# and toggling the firewall status.
# -------------------------------------------------------------

# --- constants -----------------------------------------------
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="/var/log/ufw_manager.log"
# --- colours via tput (safe) ---------------------------------
readonly RED=$(tput setaf 1)
readonly GRN=$(tput setaf 2)
readonly YEL=$(tput setaf 3)
readonly BLU=$(tput setaf 4)
readonly MAG=$(tput setaf 5)
readonly CYN=$(tput setaf 6)
readonly WHITE=$(tput setaf 7)
readonly BOLD=$(tput bold)
readonly RESET=$(tput sgr0)

# --- sanity checks -------------------------------------------
command -v ufw >/dev/null  || { echo "${RED}ufw not found – install first${RESET}" >&2; exit 1; }

if [[ $EUID -ne 0 ]]; then
    echo "${RED}${BOLD}Need root – restarting via sudo …${RESET}"
    exec sudo "$0" "$@"
fi

# --- helpers -------------------------------------------------
pause() {
    read -rp "${YEL}${BOLD}Press Enter to continue …${RESET}"
}

print_status() {
    echo
    if ufw status | grep -q 'Status: active'; then
        echo "${GRN}● UFW is ACTIVE${RESET}"
    else
        echo "${RED}● UFW is INACTIVE${RESET}"
    fi
    echo
}

print_rules() {
    echo -e "\n${BLU}${BOLD}=== CURRENT RULES ===${RESET}"
    ufw status numbered | sed \
        -e "s/^\[[0-9]\+/${YEL}${BOLD}&${RESET}/" \
        -e "s/ALLOW/${GRN}${BOLD}ALLOW${RESET}/g" \
        -e "s/DENY\|REJECT\|LIMIT/${RED}${BOLD}&${RESET}/g"
}

# --- add rule ------------------------------------------------
add_rule() {
    echo -e "\n${BLU}${BOLD}=== ADD RULE ===${RESET}"
    PS3="${YEL}${BOLD}Action: ${RESET}"
    select action in allow deny reject limit back; do
        case $action in
            allow|deny|reject|limit) ;;
            back|"") return ;;
            *) continue ;;
        esac

        read -rp "${CYN}${BOLD}Port/service (22, 80/tcp, http): ${RESET}" port
        [[ -z $port ]] && { echo "${RED}Port cannot be empty${RESET}"; continue; }

        read -rp "${CYN}${BOLD}From IP/CIDR (blank = any): ${RESET}" src
        cmd=(ufw "$action")
        [[ -n $src ]] && cmd+=(from "$src")
        cmd+=(to any port "$port")

        echo -e "\n${YEL}Running: ${cmd[*]}${RESET}"
        if "${cmd[@]}"; then
            echo "${GRN}✔ Rule added${RESET}"
        else
            echo "${RED}✖ Failed${RESET}"
        fi
        break
    done
}

# --- delete rule ---------------------------------------------
delete_rule() {
    print_rules
    read -rp "${YEL}${BOLD}Rule number to delete (c = cancel): ${RESET}" num
    [[ $num == [cC] ]] && return
    [[ $num =~ ^[0-9]+$ ]] || { echo "${RED}Invalid number${RESET}"; return; }

    ufw --force delete "$num" && echo "${GRN}✔ Rule deleted${RESET}" \
                               || echo "${RED}✖ Could not delete${RESET}"
}

# --- toggle / reset -----------------------------------------
toggle_firewall() {
    PS3="${YEL}${BOLD}Choose: ${RESET}"
    select choice in enable disable reload reset back; do
        case $choice in
            enable)  ufw enable ;;
            disable) ufw disable ;;
            reload)  ufw reload ;;
            reset)
                read -rp "${RED}${BOLD}Reset UFW? (y/N): ${RESET}" c
                [[ $c =~ [Yy] ]] && ufw --force reset
                ;;
            back|"") return ;;
            *) continue ;;
        esac
        break
    done
}

# --- main loop ----------------------------------------------
trap 'echo -e "\n${RED}Aborted by user${RESET}"; exit 130' INT TERM

while :; do
    clear
    echo "${BLU}${BOLD}"
    echo "============================================="
    echo "          UFW FIREWALL MANAGEMENT           "
    echo "=============================================${RESET}"
    print_status

    cat <<EOF
${WHITE}${BOLD}MENU:${RESET}
 ${BLU}1${RESET} Show rules
 ${BLU}2${RESET} Add rule
 ${BLU}3${RESET} Delete rule
 ${BLU}4${RESET} Toggle / reload / reset
 ${BLU}5${RESET} Exit
EOF

    read -rp "${YEL}${BOLD}Choice (1-5): ${RESET}" c
    case $c in
        1) print_rules ;;
        2) add_rule ;;
        3) delete_rule ;;
        4) toggle_firewall ;;
        5) echo "${BLU}${BOLD}Bye!${RESET}"; exit 0 ;;
        *) continue ;;
    esac
    pause
done
