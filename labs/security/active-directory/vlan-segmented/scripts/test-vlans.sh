#!/usr/bin/env bash
# ==============================================================================
# VLAN Network Test Suite - Enterprise Pentest Lab
# ==============================================================================
# Author      : Miguel A. Carlo
# Version     : 1.0.0
# Date        : 2026-01-31
# License     : MIT / Educational Use Only
#
# Description :
#   Professional validation suite for VLAN bridges and interfaces in an
#   enterprise-style penetration testing lab environment.
#   - Validates existence of bridges and VLAN interfaces
#   - Checks gateway reachability per VLAN
#   - Provides inter-VLAN isolation guidance
#   - Verifies Libvirt networks (if installed)
#   - Checks firewall/routing configuration for proper segmentation
#
# Usage:
#   ./vlan-test-suite.sh
#   Example:
#     sudo ./vlan-test-suite.sh
# ==============================================================================

set -euo pipefail

cat << 'EOF'
================================================
VLAN Network Test Suite - Enterprise Pentest Lab
================================================
EOF

echo -e "\n[1] Host Network Validation"
echo "---------------------------"

# Check bridges exist
for bridge in br-mgmt br-workstations br-servers br-dmz br-attacker; do
    if ip link show "$bridge" &>/dev/null; then
        echo "✓ Bridge $bridge exists"
    else
        echo "✗ Bridge $bridge missing"
    fi
done

# Check VLAN interfaces
for vlan in 10 20 30 40 99; do
    iface="$(ip -o link show | awk -F': ' '{print $2}' | grep "\.${vlan}$" | head -1)"
    if [[ -n "$iface" ]]; then
        echo "✓ VLAN $vlan interface: $iface"
    else
        echo "✗ VLAN $vlan interface missing"
    fi
done

echo -e "\n[2] Gateway Reachability"
echo "-------------------------"

declare -A GATEWAYS=(
    [10]="172.28.10.1"
    [20]="172.28.20.1"
    [30]="172.28.30.1"
    [40]="172.28.40.1"
    [99]="172.28.99.1"
)

for vlan in "${!GATEWAYS[@]}"; do
    if ping -c 2 -W 1 "${GATEWAYS[$vlan]}" &>/dev/null; then
        echo "✓ VLAN $vlan gateway reachable: ${GATEWAYS[$vlan]}"
    else
        echo "✗ VLAN $vlan gateway unreachable: ${GATEWAYS[$vlan]}"
    fi
done

echo -e "\n[3] Inter-VLAN Isolation Test"
echo "-------------------------------"

cat << 'EOF'
Expected behavior (no routing configured):
  ✓ Same VLAN: Should communicate
  ✗ Different VLANs: Should NOT communicate

To test, run from a VM:
  ping 172.28.20.30 (same VLAN) - should work
  ping 172.28.10.21 (different VLAN) - should fail
EOF

echo -e "\n[4] Libvirt Network Verification"
echo "----------------------------------"

if command -v virsh &>/dev/null; then
    echo "Libvirt networks:"
    virsh net-list --all
else
    echo "Libvirt not available"
fi

echo -e "\n[5] Firewall/Routing Check"
echo "---------------------------"

# Check if routing is enabled (should be 0 = disabled by default)
IP_FORWARD=$(cat /proc/sys/net/ipv4/ip_forward)
if [[ "$IP_FORWARD" == "0" ]]; then
    echo "✓ IP forwarding disabled (correct for segmentation)"
else
    echo "⚠ IP forwarding ENABLED - VMs can route between VLANs"
fi

# Check for nftables/iptables rules that might block traffic
if command -v nft &>/dev/null; then
    echo "NFTables rules:"
    nft list ruleset 2>/dev/null | grep -A5 -B5 "vlan" || echo "  No VLAN-specific rules"
fi

cat << 'EOF'

================================================
TEST COMMANDS FOR VMs
================================================

From Kali (VLAN 99):
  ping 172.28.99.1      # Should work (gateway)
  ping 172.28.10.21     # Should fail (different VLAN)
  ip -br addr show      # Check interfaces

From WIN10 (VLAN 20):
  ping 172.28.20.1      # Should work
  ping 172.28.30.60     # Should fail
  Get-NetIPAddress      # PowerShell

From DC01 (VLAN 10):
  ping 172.28.10.1      # Should work
  ping 172.28.20.30     # Should fail (unless routing enabled)
  Get-NetRoute          # PowerShell

To enable inter-VLAN routing on DC01 (for advanced labs):
  Set-NetIPInterface -InterfaceAlias "*" -Forwarding Enabled
  netsh routing ip install
================================================
EOF