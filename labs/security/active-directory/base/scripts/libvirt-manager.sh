#!/usr/bin/env bash
# ==========================================================
# Libvirt + Vagrant Admin Manager (Functional CLI Edition)
# ==========================================================
set -euo pipefail

# ────────────────────────────────────────────────
# Configuration
# ────────────────────────────────────────────────
POOL="default"
NETWORK="default"
VAGRANT_DIR="${VAGRANT_DIR:-./vagrant}"
LOGFILE="${LOGFILE:-$HOME/.local/share/libvirt-admin.log}"

mkdir -p "$(dirname "$LOGFILE")" &>/dev/null
: > "$LOGFILE"

# ────────────────────────────────────────────────
# Colors & Formatting
# ────────────────────────────────────────────────
RED='\033[1;31m'    GREEN='\033[1;32m'    YELLOW='\033[1;33m'
BLUE='\033[1;34m'   CYAN='\033[1;36m'     MAGENTA='\033[1;35m'
BOLD='\033[1m'      RESET='\033[0m'

# ────────────────────────────────────────────────
# Utility functions
# ────────────────────────────────────────────────
log()      { echo "$(date '+%Y-%m-%d %H:%M:%S') | $*" >> "$LOGFILE"; }
die()      { echo -e "${RED}ERROR:${RESET} $*" >&2; exit 1; }
warn()     { echo -e "${YELLOW}Warning:${RESET} $*"; }
success()  { echo -e "${GREEN}✓ $1${RESET}"; }
pause()    { echo; read -rp "Press ENTER to continue..." _; }
confirm()  {
    echo -ne "${YELLOW}Confirm [y/N]: ${RESET}"
    read -r ans
    [[ "$ans" =~ ^[Yy]$ ]]
}
header() {
    clear
    echo -e "${BLUE}══════════════════════════════════════════════════════${RESET}"
    echo -e "  ${CYAN}${BOLD}$1${RESET}"
    echo -e "${BLUE}══════════════════════════════════════════════════════${RESET}"
    echo
}
need() {
    command -v "$1" &>/dev/null || die "'$1' is required but not installed."
}

# ────────────────────────────────────────────────
# Dependency checks
# ────────────────────────────────────────────────
for cmd in virsh virt-install virt-clone vagrant; do
    need "$cmd"
done

if ! groups | grep -qw libvirt; then
    warn "Current user is not in the 'libvirt' group — some operations may fail"
fi

# ────────────────────────────────────────────────
# safe_run wrapper
# ────────────────────────────────────────────────
safe_run() {
    local rc
    set +e
    "$@"
    rc=$?
    set -e
    return $rc
}

# ────────────────────────────────────────────────
# Core functions
# ────────────────────────────────────────────────

list_vms() {
    header "Virtual Machines Overview"
    echo -e "${CYAN}┌─ Libvirt VMs ────────────────────────────────────────┐${RESET}"
    safe_run virsh list --all || echo "  (Libvirt not responding)"
    echo -e "${CYAN}└──────────────────────────────────────────────────────┘${RESET}"
    echo
    echo -e "${CYAN}┌─ Vagrant VMs ($VAGRANT_DIR) ─────────────────────────┐${RESET}"
    if [[ -d "$VAGRANT_DIR" ]]; then
        (cd "$VAGRANT_DIR" && safe_run vagrant status) || echo "  vagrant status failed"
    else
        echo "  Directory not found"
    fi
    echo -e "${CYAN}└──────────────────────────────────────────────────────┘${RESET}"
    pause
}

vm_info() {
    header "VM Information"
    read -rp "VM name → " vm
    echo
    if virsh dominfo "$vm" &>/dev/null; then
        virsh dominfo "$vm"
    elif [[ -d "$VAGRANT_DIR" ]]; then
        (cd "$VAGRANT_DIR" && safe_run vagrant status "$vm" 2>/dev/null) || echo "Not found in Vagrant either"
    else
        echo "VM not found"
    fi
    pause
}

start_vm() {
    header "Start VM"
    read -rp "VM name → " vm
    if virsh dominfo "$vm" &>/dev/null; then
        safe_run virsh start "$vm" && success "Started"
    elif [[ -d "$VAGRANT_DIR" ]]; then
        (cd "$VAGRANT_DIR" && safe_run vagrant up "$vm")
    else
        echo "VM not found"
    fi
    pause
}

stop_vm() {
    header "Stop VM"
    read -rp "VM name → " vm
    if virsh dominfo "$vm" &>/dev/null; then
        safe_run virsh shutdown "$vm" && success "Shutdown initiated"
    elif [[ -d "$VAGRANT_DIR" ]]; then
        (cd "$VAGRANT_DIR" && safe_run vagrant halt "$vm")
    else
        echo "VM not found"
    fi
    pause
}

force_stop_vm() {
    header "Force Stop / Destroy VM"
    read -rp "VM name → " vm
    if virsh dominfo "$vm" &>/dev/null; then
        safe_run virsh destroy "$vm" && success "VM destroyed"
    elif [[ -d "$VAGRANT_DIR" ]]; then
        (cd "$VAGRANT_DIR" && safe_run vagrant destroy -f "$vm")
    else
        echo "VM not found"
    fi
    pause
}

clone_vm() {
    header "Clone VM"
    read -rp "Source VM name → " src
    read -rp "New VM name → " dest
    safe_run virt-clone --original "$src" --name "$dest" --auto-clone && success "Cloned VM"
    pause
}

delete_vm() {
    header "Delete VM"
    read -rp "VM name → " vm
    if confirm; then
        safe_run virsh undefine "$vm" --remove-all-storage && success "VM deleted"
    else
        echo "Aborted"
    fi
    pause
}

create_vm_iso() {
    header "Create new VM from ISO"
    read -rp "VM name → " name
    read -rp "ISO path → " iso
    read -rp "RAM (MB) → " ram
    read -rp "vCPUs → " vcpus
    read -rp "Disk path → " disk
    read -rp "Disk size (GB) → " size

    safe_run virt-install \
        --name "$name" \
        --ram "$ram" \
        --vcpus "$vcpus" \
        --disk path="$disk",size="$size" \
        --cdrom "$iso" \
        --network network="$NETWORK" \
        --graphics spice \
        --os-type linux \
        --noautoconsole

    success "VM creation started"
    pause
}

list_volumes() {
    header "Storage Volumes"
    safe_run virsh vol-list --pool "$POOL"
    pause
}

create_volume() {
    header "Create Volume"
    read -rp "Volume name → " vol
    read -rp "Size (GB) → " size
    safe_run virsh vol-create-as "$POOL" "$vol" "${size}G" && success "Volume created"
    pause
}

delete_volume() {
    header "Delete Volume"
    read -rp "Volume name → " vol
    if confirm; then
        safe_run virsh vol-delete "$vol" --pool "$POOL" && success "Volume deleted"
    else
        echo "Aborted"
    fi
    pause
}

list_snaps() {
    header "Snapshots"
    read -rp "VM name → " vm
    safe_run virsh snapshot-list "$vm"
    pause
}

create_snap() {
    header "Create Snapshot"
    read -rp "VM name → " vm
    read -rp "Snapshot name → " snap
    safe_run virsh snapshot-create-as "$vm" "$snap" && success "Snapshot created"
    pause
}

revert_snap() {
    header "Revert Snapshot"
    read -rp "VM name → " vm
    read -rp "Snapshot name → " snap
    safe_run virsh snapshot-revert "$vm" "$snap" && success "Reverted"
    pause
}

delete_snap() {
    header "Delete Snapshot"
    read -rp "VM name → " vm
    read -rp "Snapshot name → " snap
    if confirm; then
        safe_run virsh snapshot-delete "$vm" "$snap" && success "Snapshot deleted"
    else
        echo "Aborted"
    fi
    pause
}

list_networks() {
    header "Networks"
    safe_run virsh net-list --all
    pause
}

toggle_network() {
    header "Start / Stop Network"
    read -rp "Network name → " net
    if virsh net-info "$net" | grep -q "Active: yes"; then
        safe_run virsh net-destroy "$net" && success "Network stopped"
    else
        safe_run virsh net-start "$net" && success "Network started"
    fi
    pause
}

list_pools() {
    header "Storage Pools"
    safe_run virsh pool-list --all
    pause
}

refresh_pool() {
    header "Refresh Storage Pool"
    read -rp "Pool name → " pool
    safe_run virsh pool-refresh "$pool" && success "Pool refreshed"
    pause
}

# ────────────────────────────────────────────────
# Main menu
# ────────────────────────────────────────────────
main_menu() {
    while true; do
        header "Libvirt + Vagrant Manager"

        cat << 'EOF'
  Virtual Machines
  ──────────────────────────────────────────────────────
   1   List all VMs (libvirt + vagrant)
   2   Show VM information
   3   Start VM
   4   Graceful shutdown
   5   Force stop / destroy domain

  Management
  ──────────────────────────────────────────────────────
   6   Clone VM (libvirt only)
   7   Delete VM (with disks)  ⚠ dangerous
   8   Create new VM from ISO

  Storage
  ──────────────────────────────────────────────────────
   9   List storage volumes
  10   Create new volume
  11   Delete volume

  Snapshots
  ──────────────────────────────────────────────────────
  12   List snapshots
  13   Create snapshot
  14   Revert to snapshot
  15   Delete snapshot

  Networking & Pools
  ──────────────────────────────────────────────────────
  16   List networks
  17   Start / stop network
  18   List storage pools
  19   Refresh storage pool

  ──────────────────────────────────────────────────────
   0   Exit

EOF

        echo -ne "${CYAN}Select option → ${RESET}"
        read -r choice

        case "$choice" in
            1)  list_vms ;;
            2)  vm_info ;;
            3)  start_vm ;;
            4)  stop_vm ;;
            5)  force_stop_vm ;;
            6)  clone_vm ;;
            7)  delete_vm ;;
            8)  create_vm_iso ;;
            9)  list_volumes ;;
            10) create_volume ;;
            11) delete_volume ;;
            12) list_snaps ;;
            13) create_snap ;;
            14) revert_snap ;;
            15) delete_snap ;;
            16) list_networks ;;
            17) toggle_network ;;
            18) list_pools ;;
            19) refresh_pool ;;
            0)  clear; echo -e "${GREEN}Goodbye.${RESET}"; exit 0 ;;
            *)  echo -e "${RED}Invalid choice${RESET}"; sleep 1 ;;
        esac
    done
}

# ────────────────────────────────────────────────
# Start program
# ────────────────────────────────────────────────
main_menu
