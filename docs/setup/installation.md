# Installation Guide

This guide provides comprehensive instructions for setting up a Linux host to deploy the lab environments in this repository. The labs are provisioned using Vagrant with the KVM/libvirt provider.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Step 1: Host System Setup](#step-1-host-system-setup)
- [Step 2: Install Vagrant](#step-2-install-vagrant)
- [Step 3: Install Vagrant Plugins](#step-3-install-vagrant-plugins)
- [Step 4: Deploy a Lab Environment](#step-4-deploy-a-lab-environment)
- [Verification and Cleanup](#verification-and-cleanup)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Automated Prerequisite Check

Before proceeding, run the `check-prerequisites.sh` script from the repository root. It validates your system's configuration for KVM, libvirt, Vagrant, required plugins, and resource availability without making any changes.

```bash
# First, clone the repository if you haven't already
git clone https://github.com/solo2121/security-engineering-lab.git
cd security-engineering-lab

# Run the check
./scripts/check-prerequisites.sh --all
```

It won't install anything for you, but every failure includes the exact
fix command.

### Host requirements

- Linux host recommended.
- Hardware virtualization enabled in BIOS/UEFI.
- Sufficient CPU, RAM, and disk space for your chosen lab.
- Internet access for package installation and box downloads.

### Recommended host resources

These are general recommendations. Exact needs depend on which lab and how many VMs you deploy.

- **Lab 1**: High memory and storage usage due to Windows servers, AD CS, and supporting systems.
- **Lab 2**: Moderate to high memory usage due to Kubernetes, observability, and registry services.

If your host doesn't meet the full recommendations, see
[`docs/guides/optimization/minimal-resource-deployment.md`](../guides/optimization/minimal-resource-deployment.md)
for tested reduced-VM profiles for both labs.

### Required tools

- Vagrant.
- KVM/QEMU.
- Libvirt.
- Virt-Manager.
- Required Vagrant plugins.

### Recommended Linux distros

The labs should work best on Debian-based or Fedora/RHEL-based Linux hosts with Libvirt and KVM support.

---

## Host Setup

### 1. Update your system

```bash
sudo apt update
sudo apt upgrade -y
```

### 2. Install Vagrant

#### Debian / Ubuntu

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update
sudo apt install -y vagrant
```

#### Fedora / RHEL / CentOS Stream

```bash
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo dnf -y install vagrant
```

### 3. Install virtualization packages

#### Debian / Ubuntu

```bash
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients virt-manager
```

#### Fedora / RHEL / CentOS Stream

```bash
sudo dnf install -y @virtualization virt-manager
```

### 4. Enable and start Libvirt

#### Debian / Ubuntu

```bash
sudo systemctl enable --now libvirtd
```

#### Fedora / RHEL / CentOS Stream

```bash
sudo systemctl enable --now libvirtd
```

### 5. Add your user to the libvirt group

```bash
sudo usermod -aG libvirt $USER
newgrp libvirt
```

### 6. Verify KVM is available

```bash
lsmod | grep kvm
```

If KVM modules are loaded, your host is ready for virtualization.

---

## Install Vagrant Plugins

The repository uses Libvirt-based Vagrant workflows, so install the required plugins before starting the labs.

### Common plugins

```bash
vagrant plugin install vagrant-libvirt
```

### Lab 1 plugins

For the Active Directory Pentest Lab, install the additional plugins used by Windows and reload workflows:

```bash
vagrant plugin install vagrant-reload
vagrant plugin install vagrant-winrm
```

---

## Lab 1: Active Directory Pentest Lab

This lab is located in:

```text
labs/security/ad-pentest/
```

An alternate VLAN-segmented edition is located in:

```text
labs/security/ad-pentest-vlan/
```

This environment includes Windows Server 2022, domain-joined workstations, AD CS, Kali Linux, LocalStack, and additional research targets.

> **Windows licensing note:** The Windows Server and Windows 10 boxes used in this lab are built from Microsoft's free [Windows Server Evaluation](https://www.microsoft.com/evalcenter/evaluate-windows-server-2022) and [Windows 10/11 Evaluation](https://developer.microsoft.com/windows/downloads/virtual-machines/) media, intended for evaluation, testing, and development use. Evaluation media is time-limited (commonly 180 days for Windows Server) and is not licensed for production use. You are responsible for complying with Microsoft's licensing terms if you use this lab beyond evaluation purposes.

### Install Lab 1 dependencies

```bash
sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system virt-manager vagrant
vagrant plugin install vagrant-libvirt
vagrant plugin install vagrant-reload
vagrant plugin install vagrant-winrm
```

### Clone the repository

```bash
git clone https://github.com/solo2121/security-engineering-lab.git
cd security-engineering-lab/labs/security/ad-pentest
```

### Start the lab

Start the Domain Controller first, then deploy the rest of the environment.

```bash
vagrant up dc01
vagrant status
vagrant up
```

### VLAN edition

If you want the segmented network edition, use:

```bash
cd ../ad-pentest-vlan
vagrant up dc01
vagrant up
```

### Verify Lab 1

After deployment, verify the virtual machines are running and the domain controller is reachable.

```bash
vagrant status
```

You should see the lab machines in a running state.

---

## Lab 2: DevOps / DevSecOps Lab

This lab is located in:

```text
labs/infrastructure/devops-linux-lab/
```

It includes k3s, Kind, K3d, Harbor, Argo CD, Prometheus, Grafana, Loki, Falco, Kyverno, Cert-Manager, Terraform, OpenTofu, and Ansible.

### Install Lab 2 dependencies

```bash
sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system virt-manager vagrant
vagrant plugin install vagrant-libvirt
```

### Enter the lab directory

```bash
cd security-engineering-lab/labs/infrastructure/devops-linux-lab
```

### Start the lab

```bash
vagrant up
```

### Verify Lab 2

Check the VM status once startup is complete.

```bash
vagrant status
```

---

## Common Setup Notes

### Libvirt access issues

If Vagrant cannot connect to Libvirt, verify your user is in the `libvirt` group and that `libvirtd` is running.

```bash
groups
systemctl status libvirtd
```

### Permission issues

If you are prompted for password access repeatedly, recheck group membership and restart your shell session.

### Box download issues

If box downloads fail, confirm your network connection and make sure Vagrant can reach the configured box source.

### Virtualization performance

If the host is underpowered, reduce the number of running VMs or allocate more memory and CPU.

---

## Verification Checklist

Before you continue using the labs, confirm the following:

- Vagrant is installed.
- Libvirt is installed and running.
- KVM modules are loaded.
- Your user can manage libvirt domains.
- Required Vagrant plugins are installed.
- The lab directory contains the expected `Vagrantfile`.
- `vagrant up` starts the environment successfully.

---

## Uninstall and Cleanup

If you want to stop or destroy a lab environment:

```bash
vagrant halt
```

To destroy all VMs in the current lab:

```bash
vagrant destroy -f
```

**Easier option:** each lab ships an interactive manager script that lists every machine's state and can start, halt, or destroy VMs individually or all at once, without you needing to remember Vagrant machine names:

```bash
cd labs/security/ad-pentest       # or ad-pentest-vlan / infrastructure/devops-linux-lab
./scripts/vagrant-manager.sh
```

In the Active Directory Pentest Lab manager, press `X` to destroy every VM in the lab in one step (with a confirmation prompt) and optionally clean up the lab's leftover libvirt network.

You can also remove unused packages and clean up your system if needed.

---

## Troubleshooting

### Vagrant cannot find the provider

Make sure the `vagrant-libvirt` plugin is installed.

```bash
vagrant plugin list
```

### Libvirt service is not active

Start and enable the service.

```bash
sudo systemctl enable --now libvirtd
```

### KVM is missing

Confirm that your CPU supports virtualization and that it is enabled in BIOS/UEFI.

### VM startup fails

Check:
- Available RAM.
- Available disk space.
- Virtualization support.
- Network bridge or NAT configuration.

### Windows VM provisioning problems

For Lab 1, make sure the Windows-specific plugins are installed and that you started the Domain Controller first.

---

## Related Documentation

- [README](README.md)
- [Architecture Design](../architecture/architecture.md)
- [Security Scope](../architecture/security-scope.md)
- [Troubleshooting](troubleshooting.md)

---

## Notes

This project is intended for educational, defensive security, and authorized research purposes only.

All testing must be performed only in environments that you own or are explicitly authorized to use.