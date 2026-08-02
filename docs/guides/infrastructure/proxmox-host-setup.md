# Proxmox Host Setup for Vagrant Labs

This guide walks through running the security-engineering-lab on a Proxmox VE host. Since Proxmox runs KVM/QEMU natively and exposes libvirt, the Vagrantfiles work without modification — you just need to set up the host environment correctly inside a Proxmox VM.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Proxmox Host Requirements](#2-proxmox-host-requirements)
3. [Create the Vagrant Host VM in Proxmox](#3-create-the-vagrant-host-vm-in-proxmox)
4. [Enable Nested Virtualization](#4-enable-nested-virtualization)
5. [Install KVM and libvirt Inside the VM](#5-install-kvm-and-libvirt-inside-the-vm)
6. [Install Vagrant and Plugins](#6-install-vagrant-and-plugins)
7. [Clone the Lab and Run](#7-clone-the-lab-and-run)
8. [Networking Configuration](#8-networking-configuration)
9. [Storage Optimization](#9-storage-optimization)
10. [Accessing Lab Services from Outside Proxmox](#10-accessing-lab-services-from-outside-proxmox)
11. [Snapshots and Templates](#11-snapshots-and-templates)
12. [Troubleshooting](#12-troubleshooting)

---

## 1. Architecture Overview

```
Physical Host
└── Proxmox VE
    └── Ubuntu VM (the "Vagrant Host")
        ├── KVM / libvirt / QEMU (nested)
        └── Vagrant labs
            ├── labs/security/ad-pentest/        ← Lab 1 VMs
            ├── labs/security/ad-pentest-vlan/   ← Lab 1 VLAN VMs
            └── labs/infrastructure/devops-linux-lab/ ← Lab 2 VMs
```

All lab VMs run inside the Ubuntu VM as nested KVM guests. Proxmox provides the hardware virtualization layer. The Ubuntu VM is the only thing you manage in Proxmox directly.

---

## 2. Proxmox Host Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 8 cores with VT-x/AMD-V | 16+ cores |
| RAM | 32 GB | 64 GB |
| Storage | 500 GB SSD | 1 TB NVMe |
| Proxmox VE | 8.0+ | Latest stable |
| Network | 1 GbE | 10 GbE or bonded |

Verify hardware virtualization is enabled in BIOS before installing Proxmox. Check after boot:

```bash
# On Proxmox host shell
egrep -c '(vmx|svm)' /proc/cpuinfo
# Any number > 0 means virtualization is available
```

---

## 3. Create the Vagrant Host VM in Proxmox

### Download Ubuntu 24.04 ISO

In the Proxmox web UI:

1. Go to your storage → ISO Images → Download from URL
2. URL: `https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso`
3. Wait for download to complete

### Create the VM

In the Proxmox web UI, click **Create VM** and use these settings:

**General tab:**
- VM ID: `200` (or any unused ID)
- Name: `vagrant-host`

**OS tab:**
- ISO image: `ubuntu-24.04-live-server-amd64.iso`
- Type: Linux
- Version: 6.x - 2.6 Kernel

**System tab:**
- Machine: `q35`
- BIOS: `SeaBIOS`
- SCSI Controller: `VirtIO SCSI single`

**Disk tab:**
- Bus: `VirtIO Block`
- Size: `500G` minimum (lab VMs take significant space)
- Cache: `Write back`
- Discard: enabled (for SSD trim)

**CPU tab:**
- Cores: `8` minimum (16 recommended)
- Type: `host` — this is critical for nested virtualization

**Memory tab:**
- Memory: `32768` MB (32 GB) minimum
- Ballooning: disabled (set fixed allocation for stability)

**Network tab:**
- Bridge: `vmbr0`
- Model: `VirtIO (paravirtualized)`

Click **Finish**, then start the VM and install Ubuntu Server 24.04 with default settings.

### CLI alternative (on Proxmox shell)

```bash
qm create 200 \
  --name vagrant-host \
  --memory 32768 \
  --cores 8 \
  --cpu host \
  --machine q35 \
  --net0 virtio,bridge=vmbr0 \
  --scsihw virtio-scsi-single \
  --virtio0 local-lvm:500 \
  --cdrom local:iso/ubuntu-24.04-live-server-amd64.iso \
  --boot order=virtio0 \
  --ostype l26

qm start 200
```

---

## 4. Enable Nested Virtualization

Nested virtualization must be enabled on the Proxmox host before the Ubuntu VM can run KVM guests inside it.

```bash
# On the Proxmox HOST shell (not inside the VM)

# Check if nested virt is already on
cat /sys/module/kvm_intel/parameters/nested    # Intel
cat /sys/module/kvm_amd/parameters/nested      # AMD

# If it shows N, enable it

# Intel
echo "options kvm-intel nested=1" > /etc/modprobe.d/kvm-intel.conf
modprobe -r kvm_intel
modprobe kvm_intel

# AMD
echo "options kvm-amd nested=1" > /etc/modprobe.d/kvm-amd.conf
modprobe -r kvm_amd
modprobe kvm_amd

# Verify
cat /sys/module/kvm_intel/parameters/nested   # Should show Y or 1
```

This setting persists across reboots via `/etc/modprobe.d/`. The VM must be stopped and started (not rebooted) to pick up the change if it was just enabled.

Additionally, in the Proxmox UI for the VM:

- Hardware → Processor → Type: set to **host**

Or from the Proxmox shell:

```bash
qm set 200 --cpu host
```

---

## 5. Install KVM and libvirt Inside the VM

SSH into the Ubuntu VM and run the following.

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install KVM, QEMU, and libvirt
sudo apt install -y \
  qemu-kvm \
  qemu-system \
  libvirt-daemon-system \
  libvirt-clients \
  libvirt-dev \
  bridge-utils \
  virtinst \
  virt-manager \
  cpu-checker \
  ovmf \
  libguestfs-tools \
  jq \
  git \
  curl \
  wget \
  net-tools \
  python3 \
  python3-pip

# Verify KVM acceleration is available
kvm-ok
# Expected: INFO: /dev/kvm exists — KVM acceleration can be used

# Add your user to required groups
sudo usermod -aG libvirt $USER
sudo usermod -aG kvm $USER

# Apply group changes without logging out
newgrp libvirt

# Start and enable libvirt
sudo systemctl enable --now libvirtd
sudo systemctl status libvirtd

# Verify
virsh list --all
# Should return empty list with no errors
```

---

## 6. Install Vagrant and Plugins

```bash
# Install Vagrant from HashiCorp repository
wget -O - https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) \
  signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update
sudo apt install -y vagrant

# Verify
vagrant --version

# Install required plugins
vagrant plugin install vagrant-libvirt
vagrant plugin install vagrant-reload
vagrant plugin install vagrant-winrm    # For AD pentest lab Windows VMs

# Verify plugins
vagrant plugin list
```

---

## 7. Clone the Lab and Run

```bash
# Clone the repository
git clone https://github.com/solo2121/security-engineering-lab.git
cd security-engineering-lab

# Run the AD pentest lab
cd labs/security/ad-pentest

# Validate Vagrantfile before starting
vagrant validate

# Start the domain controller first
vagrant up dc01

# Check status
vagrant status

# Bring up the rest
vagrant up
```

### DevOps lab

```bash
cd ../../infrastructure/devops-linux-lab

# Set Harbor password before starting
export HARBOR_PASS='YourStrongPassword'

# Minimal profile (control plane + 1 worker)
LAB_PROFILE=minimal vagrant up
```

---

## 8. Networking Configuration

### Default Networking (Works Out of the Box)

The labs use `vagrant-libvirt` which creates a private network bridge automatically. No manual network configuration is needed for basic operation. All lab VMs will have private IPs accessible from inside the Ubuntu VM.

### Accessing Lab VMs from Your Workstation

By default, lab VMs are only reachable from inside the Ubuntu Proxmox VM. To access them from your laptop or workstation, use SSH port forwarding:

```bash
# Forward Kali SSH from your laptop through Proxmox VM to the lab
ssh -L 2222:172.28.128.10:22 user@PROXMOX_VM_IP

# Then connect to Kali
ssh -p 2222 root@localhost
```

Or set up a persistent SSH tunnel in `~/.ssh/config` on your workstation:

```
Host proxmox-lab
    HostName PROXMOX_VM_IP
    User ubuntu
    LocalForward 2222 172.28.128.10:22
    LocalForward 3389 172.28.128.30:3389
    LocalForward 8080 172.28.128.15:80
```

Then: `ssh proxmox-lab` opens all tunnels, and you connect to lab services on localhost.

### VLAN Lab Networking

The VLAN lab creates bridge interfaces inside the Ubuntu VM. If they are not created automatically, run the setup script:

```bash
cd labs/security/ad-pentest-vlan
sudo ./scripts/setup-vlans.sh
vagrant up
```

### Proxmox Bridge for Direct Lab Access (Advanced)

If you want lab VMs directly accessible on your LAN, add a bridge in Proxmox:

```bash
# On the Proxmox host shell
# Edit /etc/network/interfaces and add:

auto vmbr1
iface vmbr1 inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 2-4094
```

Then in Proxmox UI, add a second network interface to the Ubuntu VM on `vmbr1`. Inside the Ubuntu VM, connect the libvirt network to this bridge for direct LAN access.

---

## 9. Storage Optimization

Lab VMs consume significant disk space. The following optimizations help.

### Use a Separate Disk for Lab VMs

In Proxmox, add a second virtual disk dedicated to VM storage:

```bash
# In Proxmox UI: VM → Hardware → Add → Hard Disk
# Size: 500GB, same cache settings as main disk

# Inside Ubuntu VM after adding:
# Find the new disk
lsblk

# Format and mount it
sudo mkfs.ext4 /dev/vdb
sudo mkdir -p /var/lib/libvirt/images
sudo mount /dev/vdb /var/lib/libvirt/images

# Persist the mount
echo '/dev/vdb /var/lib/libvirt/images ext4 defaults 0 2' | \
  sudo tee -a /etc/fstab
```

libvirt stores all VM disk images in `/var/lib/libvirt/images/` by default. Pointing this to a dedicated disk keeps the OS disk clean.

### Enable Thin Provisioning

```bash
# Check your libvirt storage pool
virsh pool-list --all
virsh pool-info default

# qcow2 is already thin-provisioned by default in vagrant-libvirt
# Verify in Vagrantfile:
# l.storage :file, size: "50G", type: "qcow2"
# qcow2 only allocates what is actually used
```

### Disk Space Monitoring

```bash
# Check total disk usage by lab VMs
du -sh /var/lib/libvirt/images/

# List all VM disk images
ls -lh /var/lib/libvirt/images/*.qcow2

# Check available space
df -h /var/lib/libvirt/images/

# Compact a qcow2 image after deleting VM data
qemu-img convert -O qcow2 original.qcow2 compacted.qcow2
```

---

## 10. Accessing Lab Services from Outside Proxmox

### SSH Config on Your Workstation

```
# ~/.ssh/config on your laptop

Host vagrant-lab
    HostName PROXMOX_VM_IP
    User ubuntu
    IdentityFile ~/.ssh/id_rsa
    # AD pentest lab tunnels
    LocalForward 2210 172.28.128.10:22    # Kali
    LocalForward 3390 172.28.128.30:3389  # WIN10 RDP
    LocalForward 1433 172.28.128.23:1433  # DB01 SQL Server
    LocalForward 8015 172.28.128.15:80    # Juice Shop
    # DevOps lab tunnels
    LocalForward 30001 192.168.121.114:30001  # Harbor
    LocalForward 30003 192.168.121.114:30003  # ArgoCD
    LocalForward 16443 192.168.121.114:6443   # K3s API
```

Connect with: `ssh vagrant-lab`

Then from your laptop:
- Kali: `ssh -p 2210 root@localhost`
- WIN10 RDP: `xfreerdp /v:localhost:3390`
- Juice Shop: `http://localhost:8015`
- Harbor: `https://localhost:30001`

### RDP to Windows Lab Hosts

```bash
# From your laptop through the tunnel
xfreerdp /v:localhost:3390 \
  /u:vagrant \
  /p:Vagrant123! \
  /cert-ignore \
  /dynamic-resolution
```

### VPN Access (WireGuard — Optional)

For full access to all lab subnets without port forwarding, install WireGuard in the Ubuntu VM:

```bash
sudo apt install -y wireguard

# Generate keys
wg genkey | tee /etc/wireguard/private.key | \
  wg pubkey > /etc/wireguard/public.key

# Create config
sudo cat > /etc/wireguard/wg0.conf << WGEOF
[Interface]
Address = 10.99.0.1/24
ListenPort = 51820
PrivateKey = $(cat /etc/wireguard/private.key)

[Peer]
PublicKey = YOUR_CLIENT_PUBLIC_KEY
AllowedIPs = 10.99.0.2/32
WGEOF

sudo systemctl enable --now wg-quick@wg0
```

Configure your laptop as a WireGuard peer with routes to `172.28.128.0/24` for full lab access.

---

## 11. Snapshots and Templates

### Snapshots via Proxmox UI

Snapshots capture the entire state of the Ubuntu VM (memory + disk) at a point in time. Take one before starting each lab session.

```bash
# From Proxmox host shell
qm snapshot 200 pre-lab-session --vmstate 1 --description "Clean state before lab"

# List snapshots
qm listsnapshot 200

# Restore
qm rollback 200 pre-lab-session
```

Or use the Proxmox web UI: VM → Snapshots → Take Snapshot.

### Vagrant Box Caching

Vagrant downloads boxes (base OS images) on first use. Cache them to avoid re-downloading after a VM reset:

```bash
# List cached boxes
vagrant box list

# The boxes are stored in ~/.vagrant.d/boxes/
# Back this up to avoid re-downloading
ls ~/.vagrant.d/boxes/

# Export a box for sharing or backup
vagrant box repackage bento/ubuntu-24.04 libvirt 0.1.0
```

### VM-Level Snapshots (libvirt)

```bash
# Take a snapshot of a running Vagrant VM
virsh snapshot-create-as \
  security-engineering-lab_dc01 \
  "domain-joined" \
  "DC01 after domain join" \
  --atomic

# List snapshots
virsh snapshot-list security-engineering-lab_dc01

# Restore
virsh snapshot-revert security-engineering-lab_dc01 "domain-joined"
```

---

## 12. Troubleshooting

### kvm-ok fails — nested virtualization not working

```bash
# Verify nested is on in the Proxmox host
cat /sys/module/kvm_intel/parameters/nested

# If N, enable it
echo "options kvm-intel nested=1" > /etc/modprobe.d/kvm-intel.conf
modprobe -r kvm_intel && modprobe kvm_intel

# Stop the VM in Proxmox (not reboot)
# Ensure CPU type is set to host
qm set 200 --cpu host
# Start the VM again
```

### vagrant-libvirt fails to connect to libvirt

```bash
# Check libvirtd is running
sudo systemctl status libvirtd

# Verify your user is in the libvirt group
groups $USER | grep libvirt

# If not, add and re-login
sudo usermod -aG libvirt $USER
newgrp libvirt

# Test connection
virsh -c qemu:///system list --all

# Set the URI explicitly
export LIBVIRT_DEFAULT_URI=qemu:///system
vagrant up
```

### VMs boot but have no network

```bash
# Check the libvirt default network
virsh net-list --all
virsh net-start default
virsh net-autostart default

# Reload libvirtd
sudo systemctl restart libvirtd
```

### Out of disk space during vagrant up

```bash
# Check disk usage
df -h
du -sh /var/lib/libvirt/images/

# Clean up halted VMs
vagrant destroy -f    # Inside the lab directory

# Remove stale libvirt volumes
virsh vol-list default
virsh vol-delete --pool default VOLUME_NAME

# Compact qcow2 images
for img in /var/lib/libvirt/images/*.qcow2; do
  qemu-img convert -O qcow2 "$img" "${img}.new"
  mv "${img}.new" "$img"
done
```

### Windows VMs fail to provision

```bash
# Ensure vagrant-winrm is installed
vagrant plugin install vagrant-winrm
vagrant plugin install vagrant-reload

# Check WinRM connectivity
vagrant winrm-config dc01

# Increase boot timeout in the Vagrantfile if needed
# config.vm.boot_timeout = 1800
```

### Performance is slow

```bash
# Check nested virtualization is actually working
virt-host-validate
# Should show PASS for all KVM checks

# Verify the VM CPU type is host
virsh dominfo security-engineering-lab_dc01 | grep cpu

# Check for memory ballooning (disable it for lab VMs)
# In Proxmox UI: VM → Hardware → Memory → uncheck Ballooning

# Use virtio drivers for all VM disk and network interfaces
# Already configured in the Vagrantfiles
```

---

## Related Documentation

- [`vagrant-management-tutorial.md`](vagrant-management-tutorial.md) — Vagrant commands and workflows
- [`managing-kvm-qemu-cli-tutorial.md`](managing-kvm-qemu-cli-tutorial.md) — KVM management reference
- [`../../../labs/security/ad-pentest/README.md`](../../../labs/security/ad-pentest/README.md) — AD pentest lab setup
- [`../../../labs/infrastructure/devops-linux-lab/README.md`](../../../labs/infrastructure/devops-linux-lab/README.md) — DevOps lab setup
- [`../../setup/installation.md`](../../setup/installation.md) — Full dependency installation guide
- [`../../setup/troubleshooting.md`](../../setup/troubleshooting.md) — Common issues and fixes
