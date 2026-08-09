#!/usr/bin/env bash
# ==============================================================================
# Enterprise Pentest Lab - VLAN Bridge Setup
# ==============================================================================  
# Author      : Miguel A. Carlo
# Version     : 1.0.0
# Date        : 2026-01-31
# License     : MIT / Educational Use Only
#
# Description :
#   Professional, idempotent, and production-ready Bash script to configure
#   VLAN bridges for an enterprise-style penetration testing lab.  
#   - Supports multiple VLANs: Management, Workstations, Servers, DMZ, Attacker
#   - Auto-detects physical NIC or uses user-specified NIC
#   - Creates VLAN interfaces and bridges
#   - Configures static IPs for each bridge
#   - Generates persistent Netplan configuration (Ubuntu)
#   - Verifies bridge and VLAN interface setup
#
#   Designed for use with Vagrant-based lab environments simulating a realistic
#   corporate network with full segmentation.
#
# Usage:
#   ./setup-vlans.sh [physical_nic]
#   Example:
#     sudo ./setup-vlans.sh enp3s0
# ==============================================================================

set -euo pipefail
IFS=$'\n\t'

# Colors for professional output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ------------------------------------------------------------------------------
# CONFIGURATION (Single Source of Truth)
# ------------------------------------------------------------------------------

declare -A VLAN_CONFIG=(
    # ID:bridge_name:gateway_ip:description
    [10]="br-mgmt:172.28.10.1:Management Network"
    [20]="br-workstations:172.28.20.1:Workstations VLAN"
    [30]="br-servers:172.28.30.1:Servers VLAN"
    [40]="br-dmz:172.28.40.1:DMZ Network"
    [99]="br-attacker:172.28.99.1:Attacker VLAN"
)

# ------------------------------------------------------------------------------
# FUNCTIONS
# ------------------------------------------------------------------------------

log_info() { echo -e "${BLUE}[*]${NC} $1"; }
log_success() { echo -e "${GREEN}[+]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[-]${NC} $1"; }

die() {
    log_error "$1"
    exit 1
}

get_physical_nic() {
    # Prefer manually specified NIC, otherwise auto-detect
    local nic="${1:-}"
    
    if [[ -n "$nic" ]]; then
        if ip link show "$nic" &>/dev/null; then
            echo "$nic"
            return 0
        else
            log_warning "Specified NIC '$nic' not found, auto-detecting..."
        fi
    fi
    
    # Auto-detect: first physical NIC that's not virtual
    local detected=$(ip -o link show | awk -F': ' '
        $2 !~ /^(lo|virbr|docker|br-|veth|tap|tun|vmnet|vboxnet)/ &&
        $2 !~ /\./ &&
        $2 != "" {
            print $2;
            exit
        }
    ')
    
    [[ -n "$detected" ]] || die "Could not detect physical NIC"
    echo "$detected"
}

create_vlan_bridge() {
    local vlan_id="$1"
    local config="${VLAN_CONFIG[$vlan_id]}"
    local bridge_name="${config%%:*}"
    local rest="${config#*:}"
    local gateway_ip="${rest%%:*}"
    local description="${rest#*:}"
    
    local vlan_iface="${PHYSICAL_NIC}.${vlan_id}"
    
    log_info "Configuring VLAN ${vlan_id}: ${description}"
    
    # 1. Create VLAN interface (idempotent)
    if ! ip link show "$vlan_iface" &>/dev/null; then
        ip link add link "$PHYSICAL_NIC" name "$vlan_iface" type vlan id "$vlan_id" || {
            log_warning "VLAN interface $vlan_iface already exists or failed"
        }
    fi
    
    # 2. Create bridge (idempotent)
    if ! ip link show "$bridge_name" &>/dev/null; then
        ip link add name "$bridge_name" type bridge || {
            log_warning "Bridge $bridge_name already exists or failed"
        }
    fi
    
    # 3. Bring interfaces up
    ip link set dev "$vlan_iface" up
    ip link set dev "$bridge_name" up
    
    # 4. Connect VLAN to bridge (if not already)
    local current_master
    current_master=$(ip -j link show "$vlan_iface" | jq -r '.[].master' 2>/dev/null || echo "")
    
    if [[ "$current_master" != "$bridge_name" ]]; then
        ip link set dev "$vlan_iface" master "$bridge_name" || {
            log_warning "Failed to connect $vlan_iface to $bridge_name (might already be connected)"
        }
    fi
    
    # 5. Configure bridge IP
    if ! ip addr show "$bridge_name" | grep -q "$gateway_ip"; then
        ip addr add "${gateway_ip}/24" dev "$bridge_name" || {
            log_warning "Failed to add IP to $bridge_name (might already exist)"
        }
    fi
    
    # 6. Disable NetworkManager interference
    if command -v nmcli &>/dev/null; then
        nmcli device set "$vlan_iface" managed no 2>/dev/null || true
        nmcli device set "$bridge_name" managed no 2>/dev/null || true
    fi
    
    # 7. Disable STP (lab environment - no loops)
    ip link set dev "$bridge_name" type bridge stp_state 0
    
    log_success "VLAN ${vlan_id}: ${vlan_iface} → ${bridge_name} (${gateway_ip}/24)"
}

generate_netplan_config() {
    local netplan_file="/etc/netplan/99-vagrant-lab-vlans.yaml"
    
    log_info "Generating netplan configuration..."
    
    cat > "$netplan_file" << EOF
# ==============================================================================
# Vagrant Pentest Lab - VLAN Configuration
# Auto-generated by setup-vlans.sh
# ==============================================================================
network:
  version: 2
  renderer: networkd
  ethernets:
    ${PHYSICAL_NIC}:
      dhcp4: false
      dhcp6: false
      optional: true
EOF
    
    # Add bridges
    echo "  bridges:" >> "$netplan_file"
    for vlan_id in "${!VLAN_CONFIG[@]}"; do
        local config="${VLAN_CONFIG[$vlan_id]}"
        local bridge_name="${config%%:*}"
        local rest="${config#*:}"
        local gateway_ip="${rest%%:*}"
        local vlan_iface="${PHYSICAL_NIC}.${vlan_id}"
        
        cat >> "$netplan_file" << EOF
    ${bridge_name}:
      interfaces: [${vlan_iface}]
      addresses: [${gateway_ip}/24]
      parameters:
        stp: false
        forward-delay: 0
EOF
    done
    
    # Add VLANs
    echo "  vlans:" >> "$netplan_file"
    for vlan_id in "${!VLAN_CONFIG[@]}"; do
        local vlan_iface="${PHYSICAL_NIC}.${vlan_id}"
        cat >> "$netplan_file" << EOF
    ${vlan_iface}:
      id: ${vlan_id}
      link: ${PHYSICAL_NIC}
EOF
    done
    
    log_success "Netplan config written to ${netplan_file}"
}

verify_setup() {
    log_info "Verifying VLAN bridge setup..."
    
    echo -e "\n${BLUE}=== Bridges ===${NC}"
    bridge -j link show | jq -r '.[] | "  \(.ifname) (master: \(.master))"' || true
    
    echo -e "\n${BLUE}=== VLAN Interfaces ===${NC}"
    for vlan_id in "${!VLAN_CONFIG[@]}"; do
        local vlan_iface="${PHYSICAL_NIC}.${vlan_id}"
        if [[ -d "/sys/class/net/${vlan_iface}" ]]; then
            local vlan_info=$(cat "/sys/class/net/${vlan_iface}/uevent" 2>/dev/null | grep -i vlan || echo "VLAN info not available")
            echo "  ${vlan_iface}: ${vlan_info}"
        fi
    done
    
    echo -e "\n${BLUE}=== IP Addresses ===${NC}"
    for vlan_id in "${!VLAN_CONFIG[@]}"; do
        local config="${VLAN_CONFIG[$vlan_id]}"
        local bridge_name="${config%%:*}"
        local rest="${config#*:}"
        local gateway_ip="${rest%%:*}"
        
        if ip addr show "$bridge_name" &>/dev/null; then
            local current_ip=$(ip -o -4 addr show "$bridge_name" | awk '{print $4}')
            echo "  ${bridge_name}: ${current_ip:-NOT CONFIGURED} (expected: ${gateway_ip}/24)"
        fi
    done
}

# ------------------------------------------------------------------------------
# MAIN EXECUTION
# ------------------------------------------------------------------------------

main() {
    echo -e "${GREEN}==============================================${NC}"
    echo -e "${GREEN}  Enterprise Pentest Lab - VLAN Setup        ${NC}"
    echo -e "${GREEN}==============================================${NC}"
    
    # Parse arguments
    PHYSICAL_NIC_SPECIFIED="${1:-}"
    PHYSICAL_NIC=$(get_physical_nic "$PHYSICAL_NIC_SPECIFIED")
    
    echo ""
    log_info "Physical NIC: ${PHYSICAL_NIC}"
    log_info "VLANs to configure: ${!VLAN_CONFIG[*]}"
    echo ""
    
    # Ensure NIC is up
    ip link set dev "$PHYSICAL_NIC" up || log_warning "Could not bring up $PHYSICAL_NIC"
    
    # Create all VLAN bridges
    for vlan_id in "${!VLAN_CONFIG[@]}"; do
        create_vlan_bridge "$vlan_id"
    done
    
    echo ""
    
    # Generate persistent configuration
    if [[ -d "/etc/netplan" ]]; then
        generate_netplan_config
        echo ""
        log_info "To apply netplan configuration, run:"
        echo "  sudo netplan apply"
        echo ""
    else
        log_warning "Netplan not found (not Ubuntu?). Configuration is not persistent."
        log_info "To make configuration persistent, add to your network configuration."
    fi
    
    # Verify
    verify_setup
    
    echo ""
    echo -e "${GREEN}==============================================${NC}"
    echo -e "${GREEN}  Setup Complete!                            ${NC}"
    echo -e "${GREEN}==============================================${NC}"
    echo ""
    log_success "Next steps:"
    echo "  1. Test connectivity: ping 172.28.99.1 (attacker gateway)"
    echo "  2. Start lab: LAB_PROFILE=full vagrant up"
    echo "  3. Verify segmentation with the test script"
    echo ""
}

# Only run if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi