#!/usr/bin/env bash

# =============================================================================
# Enterprise Bridge Attachment Manager (libvirt)
#
# Author : Miguel A. Carlo
# Date   : 2026-02-02
# Version: 1.0.0
#
# DESCRIPTION:
#
# This script attaches virtual machines to pre-created Linux bridge interfaces
# using libvirt, following an enterprise-style access-port network design.
#
# Each VM is connected to exactly one bridge that represents a single VLAN.
# Traffic on these bridges is UNTAGGED. Inter-VLAN routing, firewalling,
# and DHCP are handled exclusively by a dedicated OPNsense virtual machine.
#
# Key characteristics:
#   - One Linux bridge per VLAN (access ports)
#   - No VLAN tagging in libvirt or the host
#   - OPNsense is the only Layer-3 device
#   - Idempotent execution (safe to re-run)
#   - Windows-optimized NIC models where required
#
# Intended use cases:
#   - Enterprise Active Directory labs
#   - Penetration testing environments (PNPT / OSCP / PJPT)
#   - IDS/IPS, lateral movement, and segmentation testing
#
# Prerequisites:
#   - libvirtd running
#   - Linux bridges already created (e.g. setup-vlans.sh)
#   - OPNsense VM deployed for routing (recommended)
#
# Usage:
#   Run AFTER all VMs are created (e.g. vagrant up)
#
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

# Note: OPNsense is the Layer-3 router and connects to every VLAN; it is
# validated separately (see below) and is not listed as a single-VLAN access port.
declare -A VM_BRIDGES=(
    [DC01]="br-mgmt"
    [DB01]="br-mgmt"
    [CA01-ESC]="br-mgmt"

    [WIN10]="br-workstations"

    [linux01]="br-servers"
    [print01]="br-servers"
    [llm01]="br-servers"
    [cloud-pentest]="br-servers"

    [metasploitable2]="br-dmz"
    [juice-shop]="br-dmz"

    [kali]="br-attacker"
)

declare -A BRIDGE_VLAN_MAP=(
    [br-mgmt]=10
    [br-workstations]=20
    [br-servers]=30
    [br-dmz]=40
    [br-attacker]=99
)

declare -A VM_NIC_MODEL=(
    [DC01]="e1000e"
    [DB01]="e1000e"
    [CA01-ESC]="e1000e"
    [WIN10]="e1000e"
    [print01]="e1000e"
)

DEFAULT_NIC_MODEL="virtio"

# =============================================================================
# LOGGING
# =============================================================================

log_header() {
    echo -e "\n\033[1;36m============================================================\033[0m"
    echo -e "\033[1;36m$1\033[0m"
    echo -e "\033[1;36m============================================================\033[0m"
}

log_info()    { echo -e "\033[0;34m[*]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[+]\033[0m $1"; }
log_warning() { echo -e "\033[1;33m[!]\033[0m $1"; }
log_error()   { echo -e "\033[0;31m[-]\033[0m $1"; }

# =============================================================================
# VALIDATION
# =============================================================================

vm_exists() { virsh dominfo "$1" &>/dev/null; }
bridge_exists() { ip link show "$1" &>/dev/null; }

validate_prerequisites() {
    log_header "Prerequisite Validation"

    if ! systemctl is-active --quiet libvirtd; then
        log_error "libvirtd is not running"
        return 1
    fi

    local bridges
    bridges=$(printf "%s\n" "${VM_BRIDGES[@]}" | sort -u)

    for br in $bridges; do
        bridge_exists "$br" || {
            log_error "Missing bridge: $br"
            return 1
        }
    done

    if virsh dominfo opnsense &>/dev/null; then
        log_success "OPNsense VM detected"
    else
        log_warning "OPNsense VM not found (no routing)"
    fi
}

# =============================================================================
# INTERFACE CHECKS
# =============================================================================

has_bridge_attached() {
    local vm="$1"
    local bridge="$2"
    virsh domiflist "$vm" 2>/dev/null | awk '{print $3}' | grep -qx "$bridge"
}

# =============================================================================
# ATTACHMENT
# =============================================================================

attach_interface_to_bridge() {
    local vm="$1"
    local bridge="$2"
    local vlan="${BRIDGE_VLAN_MAP[$bridge]}"
    local model="${VM_NIC_MODEL[$vm]:-$DEFAULT_NIC_MODEL}"

    log_info "Attaching $vm → $bridge (VLAN $vlan access)"

    local xml
    xml=$(mktemp)

    cat > "$xml" <<EOF
<interface type='bridge'>
  <source bridge='$bridge'/>
  <model type='$model'/>
</interface>
EOF

    if virsh attach-device "$vm" "$xml" --config --live; then
        rm -f "$xml"
        return 0
    fi

    log_warning "Live attach failed, trying config-only"
    if virsh attach-device "$vm" "$xml" --config; then
        log_warning "Reboot required: virsh reboot $vm"
        rm -f "$xml"
        return 0
    fi

    rm -f "$xml"
    return 1
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    log_header "Enterprise Bridge Attachment Manager"
    echo "Design : Access bridges per VLAN"
    echo "Routing: OPNsense only"
    echo

    validate_prerequisites || exit 1

    local ok=0 skip=0 fail=0

    for vm in "${!VM_BRIDGES[@]}"; do
        local bridge="${VM_BRIDGES[$vm]}"
        echo -e "\n\033[1m$vm → $bridge\033[0m"

        if ! vm_exists "$vm"; then
            log_warning "VM not found"
            ((skip++))
            continue
        fi

        if has_bridge_attached "$vm" "$bridge"; then
            log_success "Already attached"
            ((ok++))
            continue
        fi

        if attach_interface_to_bridge "$vm" "$bridge"; then
            log_success "Attached successfully"
            ((ok++))
        else
            log_error "Attachment failed"
            ((fail++))
        fi
    done

    log_header "Summary"
    echo "Success: $ok"
    echo "Skipped: $skip"
    echo "Failed : $fail"
}

# =============================================================================
# ENTRY POINT
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    [[ $EUID -ne 0 ]] && log_warning "Root recommended for libvirt operations"
    main
fi
