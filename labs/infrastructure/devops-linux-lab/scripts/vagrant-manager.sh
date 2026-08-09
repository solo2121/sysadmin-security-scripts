#!/usr/bin/env bash
# =============================================================================
# VAGRANT LAB MANAGER v8.0 (FINAL - HARBOR PASS FIXED)
# =============================================================================
#
# Changes:
#   - Fixed environment propagation for HARBOR_PASS
#   - Session cache prevents repeated prompts
#   - Start (T) no longer requires Harbor password
#   - Provision actions prompt only once per session
#
# =============================================================================

set -Eeuo pipefail
export VAGRANT_DEFAULT_PROVIDER=libvirt

# ========================== COLORS ==========================
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly GRAY='\033[0;90m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# ========================== GROUPS ==========================
readonly DEVOPS=("devops-1")
readonly WORKERS=("worker-1" "worker-2")
readonly ANSIBLE_NODES=("node1" "node2")
readonly LINUX_LABS=("ubuntu-lab" "rocky-lab" "alma-lab" "suse-lab")
readonly MODERN_LABS=("kind-lab" "k3d-lab")
readonly CICD_SERVER=("cicd-server")

# ========================== STATE ==========================
declare -A machine_states=()
declare -A machine_options=()
IDX=1

# ========================== SESSION CACHE ==========================
# Prevent repeated password prompts during the same session
HARBOR_PROMPT_DONE=0

# ========================== DEPENDENCY CHECK ==========================

require_vagrant() {
    if ! command -v vagrant >/dev/null 2>&1; then
        echo -e "${RED}ERROR: 'vagrant' was not found on PATH.${NC}" >&2
        echo "Install Vagrant or activate the environment that provides it." >&2
        exit 1
    fi
}

# ========================== HARBOR PASSWORD HANDLING ==========================

ensure_harbor_pass() {
    if [[ -z "${HARBOR_PASS:-}" ]]; then
        echo ""
        echo "============================================================"
        echo "  HARBOR REGISTRY PASSWORD REQUIRED"
        echo "============================================================"
        echo ""
        echo "Harbor container registry needs an admin password."
        echo "This is required for provisioning the main cluster."
        echo ""
        echo "You can also set it in advance:"
        echo "  export HARBOR_PASS='YourStrongPassword'"
        echo ""

        read -r -s -p "Enter Harbor admin password: " HARBOR_PASS
        echo ""

        if [[ -z "${HARBOR_PASS:-}" ]]; then
            echo -e "${RED}ERROR: Password cannot be empty.${NC}"
            exit 1
        fi

        if [[ ${#HARBOR_PASS} -lt 8 ]]; then
            echo -e "${YELLOW}WARNING: Password is less than 8 characters.${NC}"
            read -r -p "Continue? (y/N): " confirm
            [[ ! "$confirm" =~ ^[Yy]$ ]] && exit 1
        fi

        read -r -s -p "Confirm password: " HARBOR_PASS_CONFIRM
        echo ""

        if [[ "$HARBOR_PASS" != "$HARBOR_PASS_CONFIRM" ]]; then
            echo -e "${RED}ERROR: Passwords do not match.${NC}"
            exit 1
        fi

        export HARBOR_PASS
        echo -e "${GREEN}Password configured successfully.${NC}"
        echo "============================================================"
        echo ""
    else
        echo -e "${GREEN}Using HARBOR_PASS from environment.${NC}"
    fi
}

# ========================== LAZY PROMPT (ONCE PER SESSION) ==========================

ensure_harbor_pass_once() {
    if [[ "${HARBOR_PROMPT_DONE}" -eq 1 ]]; then
        return 0
    fi

    ensure_harbor_pass
    HARBOR_PROMPT_DONE=1
}

# ========================== VAGRANT WRAPPERS ==========================

vagrant_cmd() {
    # Always ensure Harbor password is exported to child processes
    if [[ -n "${HARBOR_PASS:-}" ]]; then
        export HARBOR_PASS
    fi

    # Redirect stdin to prevent interactive prompts
    vagrant "$@" </dev/null 2>&1
}

vagrant_status() {
    vagrant status --machine-readable </dev/null 2>/dev/null || true
}

# SSH doesn't need the password wrapper
vagrant_ssh() {
    vagrant ssh "$@"
}

# ========================== UI ==========================

clear_screen(){ printf "\033[H\033[2J"; }

header(){
    printf "${BLUE}┌──────────────────────────────────────────────┐${NC}\n"
    printf "${BLUE}│ ${BOLD}${WHITE}VAGRANT LAB MANAGER v8.5${NC}                  │${NC}\n"
    printf "${BLUE}└──────────────────────────────────────────────┘${NC}\n"
}

state_icon(){
    case "$1" in
        running) echo -e "${GREEN}▶${NC}" ;;
        poweroff) echo -e "${RED}■${NC}" ;;
        not_created) echo -e "${YELLOW}○${NC}" ;;
        *) echo -e "${GRAY}?${NC}" ;;
    esac
}

# ========================== REFRESH ==========================

refresh(){
    machine_states=()
    IDX=1

    local name type state
    while IFS=',' read -r _ name type state _; do
        [[ "$type" != "state" ]] && continue
        [[ -z "$name" ]] && continue
        machine_states["$name"]="$state"
    done < <(vagrant_status)
}

# ========================== GROUP DISPLAY ==========================

show_group(){
    local title="$1"
    shift
    local vms=("$@")

    echo
    echo -e "${PURPLE}${BOLD}${title}${NC}"
    printf "${GRAY}────────────────────────────────────────────${NC}\n"

    for vm in "${vms[@]}"; do
        local state="${machine_states[$vm]:-not_created}"

        printf " ${CYAN}[%02d]${NC} %-15s %s %-12s\n" \
            "$IDX" "$vm" "$(state_icon "$state")" "$state"

        machine_options["$IDX"]="$vm"
        ((IDX++))
    done
}

# ========================== VM MENU ==========================

vm_menu(){
    local vm="$1"
    local sel

    while true; do
        refresh
        clear_screen
        header

        local state="${machine_states[$vm]:-not_created}"

        echo
        echo -e "${PURPLE}${BOLD}VM MANAGEMENT${NC}"
        printf "${GRAY}────────────────────────────────────────────${NC}\n"
        echo -e "VM:    ${CYAN}$vm${NC}"
        echo -e "State: $state"

        # Show Harbor status
        if [[ -n "${HARBOR_PASS:-}" ]] && [[ "${HARBOR_PROMPT_DONE}" -eq 1 ]]; then
            echo -e "Harbor: ${GREEN}configured (session)${NC}"
        elif [[ -n "${HARBOR_PASS:-}" ]]; then
            echo -e "Harbor: ${GREEN}configured${NC}"
        else
            echo -e "Harbor: ${YELLOW}not set (only needed for provision)${NC}"
        fi

        echo
        echo -e "${CYAN}[S] SSH (no password needed)"
        echo -e "[U] Up with Provision (password needed once)"
        echo -e "[T] Start (no provision, no password)"
        echo -e "[H] Halt (no password)"
        echo -e "[R] Reload with Provision (password needed once)"
        echo -e "[P] Provision only (password needed once)"
        echo -e "[D] Destroy (no password)"
        echo -e "[B] Back"
        echo -e "[Q] Quit${NC}"
        echo

        printf "${BOLD}Action › ${NC}"
        read -r sel

        case "${sel^^}" in
            S)
                vagrant_ssh "$vm"
                ;;

            U)
                ensure_harbor_pass_once
                vagrant_cmd up "$vm" --provision
                ;;

            T)
                vagrant_cmd up "$vm"
                ;;

            H)
                vagrant_cmd halt "$vm"
                ;;

            R)
                ensure_harbor_pass_once
                vagrant_cmd reload "$vm" --provision
                ;;

            P)
                ensure_harbor_pass_once
                vagrant_cmd provision "$vm"
                ;;

            D)
                vagrant_cmd destroy -f "$vm"
                ;;

            B)
                return
                ;;

            Q)
                exit 0
                ;;

            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac

        read -r -p "Press Enter to continue..."
    done
}

# ========================== GROUP ACTIONS ==========================

start_group(){
    local group="$1"
    local vms=()

    case "$group" in
        devops)
            ensure_harbor_pass_once
            vms=("${DEVOPS[@]}")
            ;;
        worker)
            vms=("${WORKERS[@]}")
            ;;
        ansible)
            vms=("${ANSIBLE_NODES[@]}")
            ;;
        labs)
            vms=("${LINUX_LABS[@]}")
            ;;
        modern)
            vms=("${MODERN_LABS[@]}")
            ;;
        cicd)
            vms=("${CICD_SERVER[@]}")
            ;;
        all)
            ensure_harbor_pass_once
            vagrant_cmd up --provision
            return
            ;;
        *)
            return
            ;;
    esac

    for vm in "${vms[@]}"; do
        echo -e "${YELLOW}Starting $vm...${NC}"
        vagrant_cmd up "$vm"
    done
}

halt_all(){
    echo -e "${YELLOW}Halting all VMs...${NC}"
    vagrant_cmd halt -f || true
}

# ========================== MAIN ==========================

# NO automatic password prompt here!
# Password is only requested when provisioning is needed

require_vagrant

while true; do
    refresh
    clear_screen
    header

    IDX=1
    machine_options=()

    show_group "DEVOPS" "${DEVOPS[@]}"
    show_group "WORKERS" "${WORKERS[@]}"
    show_group "ANSIBLE NODES" "${ANSIBLE_NODES[@]}"
    show_group "LINUX LABS" "${LINUX_LABS[@]}"
    show_group "MODERN LABS" "${MODERN_LABS[@]}"
    show_group "CI/CD SERVER" "${CICD_SERVER[@]}"

    echo
    echo -e "${CYAN}[A] Start All (provision)  [V] DevOps (provision)"
    echo -e "[W] Workers (no provision)   [N] Ansible (no provision)"
    echo -e "[L] Linux Labs (no provision) [M] Modern (no provision)"
    echo -e "[C] CI/CD Server (no provision)"
    echo -e "[B] Halt All  [R] Refresh  [Q] Quit${NC}"
    echo
    echo -e "${GRAY}Note: Harbor password only required once per session for provisioning${NC}"
    echo

    printf "${BOLD}Selection › ${NC}"
    read -r sel

    if [[ "$sel" =~ ^[0-9]+$ ]]; then
        vm_menu "${machine_options[$sel]}"
        continue
    fi

    case "${sel^^}" in
        A) start_group all ;;
        V) start_group devops ;;
        W) start_group worker ;;
        N) start_group ansible ;;
        L) start_group labs ;;
        M) start_group modern ;;
        C) start_group cicd ;;
        B) halt_all ;;
        R) continue ;;
        Q) exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}" ;;
    esac
done
