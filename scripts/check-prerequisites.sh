#!/usr/bin/env bash
#
# check-prerequisites.sh — validates that a host is ready to deploy either
# lab in this repo (Active Directory Pentest Lab, DevOps/DevSecOps Lab).
#
# Checks: hardware virtualization, KVM, libvirt, Vagrant, required Vagrant
# plugins, available disk/RAM, and basic network/DNS reachability.
#
# Every check prints PASS / WARN / FAIL and, on failure, an actionable fix
# command lifted directly from docs/setup/installation.md — this script does
# not install anything on its own, it only diagnoses.
#
# Usage:
#   ./scripts/check-prerequisites.sh          # check everything
#   ./scripts/check-prerequisites.sh --lab1   # also check AD Pentest Lab plugins (vagrant-winrm)
#   ./scripts/check-prerequisites.sh --lab2   # also check AD Pentest VLAN Lab plugins (vagrant-winrm)
#
# Exit code: 0 if no FAILs (WARNs are fine), 1 if any FAIL.

set -uo pipefail

PASS=0
WARN=0
FAIL=0

CHECK_LAB1=0
CHECK_LAB2=0
for arg in "$@"; do
    case "$arg" in
        --lab1) CHECK_LAB1=1 ;;
        --lab2) CHECK_LAB2=1 ;;
        --all) CHECK_LAB1=1; CHECK_LAB2=1 ;;
        -h|--help)
            echo "Usage: $0 [--lab1] [--lab2] [--all]"
            exit 0
            ;;
    esac
done

if [[ -t 1 ]]; then
    GREEN=$(tput setaf 2); YELLOW=$(tput setaf 3); RED=$(tput setaf 1)
    BOLD=$(tput bold); RESET=$(tput sgr0)
else
    GREEN=''; YELLOW=''; RED=''; BOLD=''; RESET=''
fi

CURRENT_USER="${USER:-$(id -un 2>/dev/null || whoami)}"

pass() { printf "  ${GREEN}[PASS]${RESET} %s\n" "$1"; PASS=$((PASS + 1)); }
warn() { printf "  ${YELLOW}[WARN]${RESET} %s\n" "$1"; [ -n "${2:-}" ] && printf "         %s\n" "$2"; WARN=$((WARN + 1)); }
fail() { printf "  ${RED}[FAIL]${RESET} %s\n" "$1"; [ -n "${2:-}" ] && printf "         Fix: %s\n" "$2"; FAIL=$((FAIL + 1)); }
section() { printf "\n${BOLD}%s${RESET}\n" "$1"; }

section "Hardware virtualization"

if grep -qE '(vmx|svm)' /proc/cpuinfo 2>/dev/null; then
    pass "CPU virtualization extensions present (vmx/svm)"
else
    fail "No vmx/svm flag found in /proc/cpuinfo" \
        "Enable virtualization (Intel VT-x / AMD-V) in your host's BIOS/UEFI"
fi

if [ -e /dev/kvm ]; then
    if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
        pass "/dev/kvm exists and is accessible"
    else
        warn "/dev/kvm exists but isn't read/writable by this user" \
            "sudo usermod -aG kvm \$USER  (then log out and back in)"
    fi
else
    fail "/dev/kvm does not exist" \
        "Install kvm packages: sudo apt install -y qemu-kvm libvirt-daemon-system"
fi

section "Libvirt"

if command -v virsh >/dev/null 2>&1; then
    pass "virsh is installed"
else
    fail "virsh not found" \
        "sudo apt install -y libvirt-daemon-system libvirt-clients virtinst"
fi

if command -v systemctl >/dev/null 2>&1; then
    if systemctl is-active --quiet libvirtd 2>/dev/null; then
        pass "libvirtd service is active"
    else
        fail "libvirtd service is not active" \
            "sudo systemctl enable --now libvirtd"
    fi
fi

if groups "$CURRENT_USER" 2>/dev/null | grep -qw libvirt; then
    pass "current user ($CURRENT_USER) is in the libvirt group"
else
    warn "current user ($CURRENT_USER) is not in the libvirt group" \
        "sudo usermod -aG libvirt \$USER  (then log out and back in)"
fi

section "Vagrant"

if command -v vagrant >/dev/null 2>&1; then
    VAGRANT_VERSION=$(vagrant --version 2>/dev/null | awk '{print $2}')
    pass "vagrant is installed (v${VAGRANT_VERSION:-unknown})"
else
    fail "vagrant not found" \
        "See docs/setup/installation.md section 2 (Install Vagrant) for your distro"
fi

if command -v vagrant >/dev/null 2>&1; then
    INSTALLED_PLUGINS=$(vagrant plugin list 2>/dev/null || true)

    check_plugin() {
        local plugin="$1"
        if echo "$INSTALLED_PLUGINS" | grep -q "^${plugin} "; then
            pass "vagrant plugin: ${plugin}"
        else
            fail "vagrant plugin missing: ${plugin}" \
                "vagrant plugin install ${plugin}"
        fi
    }

    check_plugin "vagrant-libvirt"
    check_plugin "vagrant-reload"

    if [ "$CHECK_LAB1" -eq 1 ] || [ "$CHECK_LAB2" -eq 1 ]; then
        check_plugin "vagrant-winrm"
    fi
fi

section "Disk and memory"

AVAIL_KB=$(df --output=avail -k "$PWD" 2>/dev/null | tail -1 | tr -d ' ')
if [ -n "${AVAIL_KB:-}" ]; then
    AVAIL_GB=$((AVAIL_KB / 1024 / 1024))
    if [ "$AVAIL_GB" -ge 100 ]; then
        pass "disk space: ${AVAIL_GB} GiB free (recommended: 100+ GiB for both labs)"
    elif [ "$AVAIL_GB" -ge 40 ]; then
        warn "disk space: ${AVAIL_GB} GiB free" \
            "Fine for one lab; running both labs concurrently needs ~100 GiB+"
    else
        fail "disk space: only ${AVAIL_GB} GiB free" \
            "Free up space or deploy from a volume with more room — each lab's VMs need tens of GiB"
    fi
fi

TOTAL_MEM_KB=$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null)
if [ -n "${TOTAL_MEM_KB:-}" ]; then
    TOTAL_MEM_GB=$((TOTAL_MEM_KB / 1024 / 1024))
    if [ "$TOTAL_MEM_GB" -ge 32 ]; then
        pass "system RAM: ${TOTAL_MEM_GB} GiB (comfortable for either lab)"
    elif [ "$TOTAL_MEM_GB" -ge 16 ]; then
        warn "system RAM: ${TOTAL_MEM_GB} GiB" \
            "Workable for one lab at reduced VM counts — see docs/guides/optimization/minimal-resource-deployment.md"
    else
        fail "system RAM: only ${TOTAL_MEM_GB} GiB" \
            "Both labs are RAM-heavy (multiple concurrent VMs). See docs/guides/optimization/minimal-resource-deployment.md for a reduced profile"
    fi
fi

section "Network"

if getent hosts github.com >/dev/null 2>&1; then
    pass "DNS resolution works (github.com)"
else
    fail "cannot resolve github.com" \
        "Check DNS / network configuration before cloning boxes or the repo"
fi

if command -v curl >/dev/null 2>&1; then
    if curl -sSf --max-time 5 -o /dev/null https://vagrantcloud.com 2>/dev/null; then
        pass "vagrantcloud.com is reachable (box downloads should work)"
    else
        warn "could not reach vagrantcloud.com within 5s" \
            "Box downloads may fail — check firewall/proxy settings"
    fi
fi

section "Summary"
echo "  ${GREEN}${PASS} passed${RESET}, ${YELLOW}${WARN} warnings${RESET}, ${RED}${FAIL} failed${RESET}"
echo

if [ "$FAIL" -gt 0 ]; then
    echo "One or more required checks failed. Fix the items above before running 'vagrant up'."
    exit 1
elif [ "$WARN" -gt 0 ]; then
    echo "No blocking failures, but review the warnings above."
    exit 0
else
    echo "All checks passed — this host looks ready."
    exit 0
fi
