#!/usr/bin/env bash
# Check host-side virtualization tooling before Vagrant creates any VM.

set -Eeuo pipefail

provider=${1:-}

if [[ "$provider" != "libvirt" && "$provider" != "virtualbox" ]]; then
    echo "ERROR: Unsupported or missing provider: ${provider:-<none>}" >&2
    echo "Usage: $0 libvirt|virtualbox" >&2
    exit 2
fi

echo "=========================================="
echo "PRE-PROVISIONING SYSTEM CHECK"
echo "=========================================="
echo "Provider: $provider"

if [[ "$provider" == "libvirt" ]]; then
    if ! command -v virsh >/dev/null 2>&1; then
        echo "ERROR: libvirt not installed or virsh not in PATH"
        echo "Please install libvirt and ensure virsh is available."
        exit 1
    fi
    echo "✓ libvirt found"
else
    if ! command -v VBoxManage >/dev/null 2>&1; then
        echo "ERROR: VirtualBox not installed or VBoxManage not in PATH"
        echo "Please install VirtualBox and ensure VBoxManage is available."
        exit 1
    fi

    vbox_version=$(VBoxManage --version | cut -d. -f1)
    if [[ "$vbox_version" -lt 6 ]]; then
        echo "WARNING: VirtualBox version $vbox_version detected. Version 6+ recommended."
    else
        echo "✓ VirtualBox version $vbox_version found"
    fi
fi

echo "Checking system resources..."
total_mem=$(awk '/MemTotal/ {print int($2/1024/1024); exit}' /proc/meminfo 2>/dev/null || echo "0")
total_cpu=$(nproc 2>/dev/null || echo "0")

if [[ "$total_mem" -gt 0 && "$total_mem" -lt 8 ]]; then
    echo "WARNING: System has ${total_mem}GB RAM. Full lab requires 16GB+."
    echo "         Consider using LAB_PROFILE=minimal or dev."
fi

if [[ "$total_cpu" -gt 0 && "$total_cpu" -lt 4 ]]; then
    echo "WARNING: System has ${total_cpu} CPU cores. Full lab requires 4+ cores."
fi

echo "=========================================="
