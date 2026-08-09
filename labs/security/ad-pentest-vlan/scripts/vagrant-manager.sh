#!/usr/bin/env bash
# ============================================================
# PENTEST LAB MANAGER v4.1 - VLAN EDITION (WITH OPNSENSE)
# ============================================================

set -Eeuo pipefail
export VAGRANT_DEFAULT_PROVIDER="libvirt"

# ---------- Colors ----------
readonly RED='\033[0;31m'; readonly GREEN='\033[0;32m'; readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'; readonly PURPLE='\033[0;35m'; readonly CYAN='\033[0;36m'
readonly GRAY='\033[0;90m'; readonly BOLD='\033[1m'; readonly NC='\033[0m'

declare -A machine_states machine_options
IDX=1

require_vagrant(){
  if ! command -v vagrant >/dev/null 2>&1; then
    echo -e "${RED}ERROR: 'vagrant' was not found on PATH.${NC}" >&2
    echo "Install Vagrant or activate the environment that provides it." >&2
    exit 1
  fi
}

# ============================================================
# VLAN INVENTORY (SIMPLE MODEL)
# Format: VM:VLAN
# ============================================================

# These names must match the case-sensitive IDs in the Vagrantfile.
VLAN_10=("opnsense" "DC01" "DB01" "CA01-ESC")
VLAN_20=("WIN10" "print01")
VLAN_30=("linux01" "llm01" "cloud-pentest")
VLAN_40=("metasploitable2" "juice-shop")
VLAN_99=("kali")
readonly ALL_VMS=("${VLAN_10[@]}" "${VLAN_20[@]}" "${VLAN_30[@]}" "${VLAN_40[@]}" "${VLAN_99[@]}")
# ============================================================

clear_screen(){ printf "\033[H\033[2J"; }

header(){
  echo -e "${BLUE}${BOLD}PENTEST VLAN LAB MANAGER v4.1${NC}"
}

icon(){
  case "$1" in
    running) echo -e "${GREEN}▶${NC}" ;;
    paused) echo -e "${YELLOW}⏸${NC}" ;;
    poweroff|not_created) echo -e "${RED}■${NC}" ;;
    *) echo -e "${GRAY}?${NC}" ;;
  esac
}

# ============================================================

refresh(){
  machine_states=()
  IDX=1
  local name type state
  while IFS=',' read -r _ name type state _; do
      [[ "$type" != "state" ]] && continue
      [[ -z "$name" ]] && continue
      machine_states["$name"]="$state"
  done < <(vagrant status --machine-readable 2>/dev/null || true)
}

get_ip(){
    local vm_name="$1"
    # Use vagrant ssh-config to get the hostname (IP) which is provider-agnostic
    vagrant ssh-config "$vm_name" 2>/dev/null | awk '/HostName/ {print $2}' || echo "N/A"
}

# ============================================================

show_vlan(){
  local title="$1"
  shift
  local group=("$@")

  if [[ ${#group[@]} -eq 0 ]]; then
    return
  fi

  echo
  echo -e "${PURPLE}${BOLD}$title${NC}"
  printf "${GRAY}──────────────────────────────────────────────────${NC}\n"

  for m in "${group[@]}"; do
    local state="${machine_states[$m]:-not_created}"
    printf " ${CYAN}[%02d]${NC} %-20s %-3s %-12s ${GRAY}%s${NC}\n" \
      "$IDX" \
      "$m" \
      "$(icon "$state")" \
      "$state" \
      "$(get_ip "$m")"

    machine_options[$IDX]="$m"
    ((IDX++))
  done
}

main_menu(){
  clear_screen
  IDX=1
  machine_options=()

  header

  show_vlan "VLAN 99 - ATTACKER" "${VLAN_99[@]}"
  show_vlan "VLAN 40 - DMZ / PUBLIC" "${VLAN_40[@]}"
  show_vlan "VLAN 30 - LINUX SERVERS" "${VLAN_30[@]}"
  show_vlan "VLAN 20 - WORKSTATIONS" "${VLAN_20[@]}"
  show_vlan "VLAN 10 - AD CORE / ROUTER" "${VLAN_10[@]}"

  echo
  echo -e "${CYAN}[A] Start All   [B] Halt All   [R] Refresh   [Q] Quit${NC}"
}

vm_menu(){
  local vm="$1"
  local sel

  [[ -z "$vm" ]] && return

  while true; do
    refresh
    clear_screen
    header

    echo -e "${PURPLE}VM: ${CYAN}$vm${NC}"
    echo -e "State: ${machine_states[$vm]:-not_created}"
    echo -e "IP: $(get_ip "$vm")"

    echo
    echo "[S] SSH"
    echo "[U] Up"
    echo "[H] Halt"
    echo "[D] Destroy"
    echo "[R] Reload"
    echo "[B] Back"

    read -rp "Action › " sel

    case "${sel^^}" in
      S) 
        if [[ "$vm" == "opnsense" ]]; then
          echo -e "${YELLOW}Connecting to OPNsense (root/opnsense)...${NC}"
          ssh "root@$(get_ip "$vm")" 2>/dev/null || vagrant ssh "$vm"
        else
          vagrant ssh "$vm"
        fi
        # No pause needed, returning from SSH will show menu again
        ;;
      U) vagrant up "$vm" ;;
      H) vagrant halt "$vm" ;;
      D) vagrant destroy -f "$vm" ;;
      R) vagrant reload "$vm" ;;
      B) return ;;
    esac
  done
}

# ============================================================
# MAIN ACTIONS
# ============================================================

start_all(){
  echo -e "${GREEN}Starting all VMs...${NC}"
  vagrant up --no-parallel "${ALL_VMS[@]}"
}

halt_all(){
  echo -e "${YELLOW}Halting all VMs...${NC}"
  vagrant halt "${ALL_VMS[@]}"
}

# ============================================================

# Initial refresh
require_vagrant
refresh

# Main loop
while true; do
  main_menu

  printf "${BOLD}Selection › ${NC}"
  read -r sel

  if [[ "$sel" =~ ^[0-9]+$ ]] && [[ -n "${machine_options[$sel]}" ]]; then
    vm_menu "${machine_options[$sel]}"
    refresh
    continue
  fi

  case "${sel^^}" in
    Q) exit 0 ;;
    R) refresh ;;
    A) start_all ;;
    B) halt_all ;;
  esac

  refresh
done
