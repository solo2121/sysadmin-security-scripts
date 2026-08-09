#!/usr/bin/env bats
#
# Unit tests for labs/security/active-directory/vlan-segmented/scripts/setup-vlans.sh
#
# Scope:
#   These tests source the real script (guarded against auto-execution
#   by the script's own `[[ "${BASH_SOURCE[0]}" == "${0}" ]]` check) and
#   validate VLAN_CONFIG and its parsing logic — the parts that are safe
#   to exercise without root privileges or real network interfaces.
#
#   They deliberately do NOT call create_vlan_bridge, generate_netplan_config,
#   or verify_setup directly, since those issue real `ip link` / `bridge` /
#   `netplan` commands that require root and a live network namespace —
#   out of scope for a CI unit test. Instead, this suite tests the exact
#   parameter-expansion logic those functions rely on, using the real
#   VLAN_CONFIG data sourced from the script itself.

SCRIPT_PATH="${BATS_TEST_DIRNAME}/../../labs/security/active-directory/vlan-segmented/scripts/setup-vlans.sh"

setup() {
    # shellcheck disable=SC1090
    source "$SCRIPT_PATH"

    # setup-vlans.sh sets `set -euo pipefail` for its own execution.
    # That's correct for the real script, but we don't want it leaking
    # into how these test assertions behave, so restore normal test
    # semantics right after sourcing.
    set +euo pipefail
}

@test "setup-vlans.sh sources without executing main" {
    [ -n "${VLAN_CONFIG+set}" ]
}

@test "VLAN_CONFIG defines the five expected VLAN IDs" {
    local ids=" ${!VLAN_CONFIG[*]} "

    for id in 10 20 30 40 99; do
        [[ "$ids" == *" $id "* ]]
    done
}

@test "each VLAN_CONFIG entry parses into bridge, gateway IP, and description" {
    for vlan_id in "${!VLAN_CONFIG[@]}"; do
        local config="${VLAN_CONFIG[$vlan_id]}"
        local bridge_name="${config%%:*}"
        local rest="${config#*:}"
        local gateway_ip="${rest%%:*}"
        local description="${rest#*:}"

        [ -n "$bridge_name" ]
        [[ "$gateway_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
        [ -n "$description" ]
    done
}

@test "accessing an undefined VLAN ID returns empty instead of erroring" {
    local config="${VLAN_CONFIG[9999]:-}"

    [ -z "$config" ]
}

@test "die() logs the failure message and exits non-zero" {
    run die "test failure message"

    [ "$status" -ne 0 ]
    [[ "$output" == *"test failure message"* ]]
}
