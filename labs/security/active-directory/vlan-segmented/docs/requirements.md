# Requirements

This document describes the host system, software, and permission requirements needed to run the VLAN-segmented Active Directory pentest lab.

This lab modifies libvirt networking and creates Linux bridges and VLAN interfaces. It is intended for advanced users familiar with Linux networking concepts.

---

## Host Operating System

- Linux is required. Recommended distributions:
  - Ubuntu 22.04+
  - Debian 12+
  - Fedora 38+
  - Arch Linux rolling release

> Windows and macOS hosts are not supported due to reliance on libvirt and Linux bridge networking.

---

## Virtualization Requirements

- CPU with hardware virtualization support, such as Intel VT-x or AMD-V.
- KVM enabled and working.

Verify KVM support:

```bash
lsmod | grep kvm
```

---

## Required Software

### Core Components

- QEMU / KVM.
- libvirt daemon (`libvirtd`).
- `virt-install`.
- `virsh`.

### Vagrant

- Vagrant 2.3 or newer is recommended.
- Vagrant libvirt provider.

Verify the provider:

```bash
vagrant plugin list | grep libvirt
```

---

## Networking Tools

The following tools are required by the setup and validation scripts:

- `iproute2`.
- `bridge-utils` or the modern bridge tooling available through `iproute2`.
- `nmcli` on NetworkManager-based systems.
- `brctl` if legacy bridge utilities are used.

---

## Permissions

Several scripts require root or sudo privileges to:

- Create Linux bridges.
- Configure VLAN interfaces.
- Attach libvirt networks.

Ensure your user has sudo access:

```bash
sudo -v
```

---

## libvirt Configuration

- libvirt must be running in system mode.
- Your user must be part of the `libvirt` group.

```bash
sudo usermod -aG libvirt $USER
newgrp libvirt
```

---

## Network Manager Compatibility

- NetworkManager is supported.
- systemd-networkd is supported.
- Manual network configuration tools may require adjustment.

The lab scripts attempt to detect the active network stack, but they assume standard Linux defaults.

---

## Disk Space and Resources

Recommended minimums:

- RAM: 16 GB.
- Recommended RAM: 32 GB.
- Disk space: 80 GB or more available.

---

## Security Notice

This lab contains intentionally vulnerable systems.

- Do not bridge lab networks to untrusted or production networks.
- Do not expose VLAN bridges externally.
- Use only on isolated hosts or dedicated lab machines.

---

## Validation

After meeting all requirements, proceed to network setup:

```bash
sudo ./scripts/setup-vlans.sh
```

If errors occur, refer to [`troubleshooting.md`](../../../../docs/setup/troubleshooting.md).