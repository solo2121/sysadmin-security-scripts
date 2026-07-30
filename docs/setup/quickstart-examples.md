# Complete Setup Guide with Examples

This guide provides step-by-step examples for setting up and running the sysadmin-security-lab, including command examples, verification steps, troubleshooting, and common workflows.

---

## Table of Contents

1. [Verification Checklist](#verification-checklist)
2. [System Setup Examples](#system-setup-examples)
3. [Vagrant Configuration Examples](#vagrant-configuration-examples)
4. [Lab Deployment Examples](#lab-deployment-examples)
5. [Troubleshooting with Examples](#troubleshooting-with-examples)
6. [Common Workflows](#common-workflows)

---

## Verification Checklist

### Hardware Virtualization Support

#### Intel Processors

```bash
grep -o 'vmx' /proc/cpuinfo | head -1
```

If there is no output, virtualization may be disabled in BIOS or UEFI.

#### AMD Processors

```bash
grep -o 'svm' /proc/cpuinfo | head -1
```

If there is no output, virtualization may be disabled in BIOS or UEFI.

### System Requirements Check

```bash
# Check CPU cores
nproc

# Check RAM
free -h

# Check disk space
df -h /var/lib/libvirt/images 2>/dev/null || echo "Path may not exist yet"

# Verify kernel version
uname -r
```

---

## System Setup Examples

### Installation Verification

#### Verify KVM Module Loading

```bash
# Before installation
lsmod | grep kvm

# After installation
lsmod | grep kvm
```

You should see `kvm_intel` or `kvm_amd` along with `kvm` after KVM is available.

#### Verify Libvirt Installation

```bash
virsh version
```

You should see the libvirt library version and the running hypervisor version.

#### Verify Libvirt Service

```bash
sudo systemctl status libvirtd
```

The service should be active and running.

#### Verify User Permissions

```bash
id
virsh list
```

Your user should belong to the `libvirt` and `kvm` groups, and `virsh list` should work without permission errors.

#### Verify Default Network

```bash
virsh net-list
```

If `default` is not active, start it:

```bash
virsh net-start default
virsh net-autostart default
```

---

### Vagrant Installation Example

#### Download and Install

```bash
mkdir -p ~/opt/vagrant
cd ~/opt/vagrant

wget https://releases.hashicorp.com/vagrant/2.4.1/vagrant_2.4.1_linux_amd64.zip
unzip vagrant_2.4.1_linux_amd64.zip

sudo ln -sf ~/opt/vagrant/vagrant /usr/local/bin/vagrant
vagrant --version
```

#### Install Vagrant Plugins

```bash
vagrant plugin install vagrant-libvirt
vagrant plugin install vagrant-reload
vagrant plugin install vagrant-disksize
vagrant plugin list
```

#### Vagrant Box Preparation

```bash
vagrant box add ubuntu/jammy64 --provider libvirt
vagrant box list
```

---

## Vagrant Configuration Examples

### Basic Vagrantfile Example

```ruby
# File: Vagrantfile
Vagrant.configure("2") do |config|
  config.vm.define "web" do |web|
    web.vm.box = "ubuntu/jammy64"
    web.vm.hostname = "web-server"
    web.vm.network "private_network", ip: "192.168.122.10"

    web.vm.provider "libvirt" do |libvirt|
      libvirt.memory = 2048
      libvirt.cpus = 2
      libvirt.disk_bus = "virtio"
      libvirt.nic_model_type = "virtio"
    end

    web.vm.provision "shell", inline: <<-SHELL
      apt-get update
      apt-get install -y nginx
    SHELL
  end
end
```

### Multi-VM Vagrantfile Example

```ruby
# File: Vagrantfile
Vagrant.configure("2") do |config|
  vms = {
    "control" => { ip: "192.168.122.10", mem: 4096, cpu: 2 },
    "worker1" => { ip: "192.168.122.11", mem: 2048, cpu: 1 },
    "worker2" => { ip: "192.168.122.12", mem: 2048, cpu: 1 }
  }

  vms.each do |name, settings|
    config.vm.define name do |node|
      node.vm.box = "ubuntu/jammy64"
      node.vm.hostname = name
      node.vm.network "private_network", ip: settings[:ip]

      node.vm.provider "libvirt" do |libvirt|
        libvirt.memory = settings[:mem]
        libvirt.cpus = settings[:cpu]
      end
    end
  end
end
```

---

## Lab Deployment Examples

### DevOps Linux Lab Deployment

#### Step 1: Navigate to Lab Directory

```bash
cd sysadmin-security-lab/labs/infrastructure/devops-linux-lab
ls -la
```

#### Step 2: Pre-download Base Boxes

```bash
vagrant box add ubuntu/jammy64 --provider libvirt
vagrant box list
```

#### Step 3: Start Lab with Status Monitoring

```bash
vagrant up
```

In another terminal, monitor the VMs if needed:

```bash
watch -n 5 'virsh list'
```

#### Step 4: Verify Lab Status

```bash
vagrant status
vagrant ssh k3s-cp -c 'hostname && uname -a'
```

#### Step 5: Verify Kubernetes Cluster

```bash
vagrant ssh k3s-cp
kubectl get nodes
kubectl get pods -A
exit
```

#### Step 6: Access Lab Services

```bash
vagrant ssh k3s-cp -c 'ip addr show eth1 | grep "inet " | awk "{print \$2}" | cut -d/ -f1'
```

Services may then be accessible if configured, such as Grafana and Prometheus.

---

### Active Directory Pentest Lab Deployment

#### Step 1: Navigate to AD Lab

```bash
cd sysadmin-security-lab/labs/security/ad-pentest
ls -la
```

#### Step 2: Deploy Domain Controller First

```bash
vagrant up dc01
```

Wait for the domain controller to finish provisioning before starting the rest of the environment.

#### Step 3: Deploy Full Lab

```bash
vagrant up
```

#### Step 4: Verify Lab Components

```bash
nslookup dc01.lab.local 172.28.128.21
vagrant ssh kali
nslookup -type=SRV _ldap._tcp.lab.local 172.28.128.21
curl http://172.28.128.60:8080/health
```

---

## Troubleshooting with Examples

### Issue: Permission Denied on Vagrant Commands

#### Example Error

```bash
error: failed to connect to /var/run/libvirt/libvirt-sock
error: Permission denied
```

#### Solution

```bash
id
sudo usermod -aG libvirt $USER
sudo usermod -aG kvm $USER
newgrp libvirt
virsh list
```

### Issue: Network Connectivity Problems

#### Example Error

```bash
SSH authentication failed. This is typically caused by the
public/private key mismatch for the machine.
```

#### Diagnosis

```bash
virsh net-list
ip link show virbr0
virsh net-start default
virsh net-autostart default
vagrant ssh k3s-cp -c 'ping -c 1 192.168.122.1'
```

### Issue: Insufficient Disk Space

#### Example Error

```bash
error: Requested operation is not valid: storage pool does not have enough free space
```

#### Solution

```bash
df -h /var/lib/libvirt/images/
ls -lh /var/lib/libvirt/images/*.qcow2
vagrant box prune
vagrant destroy -f
```

### Issue: High CPU/Memory Usage

#### Example Monitoring

```bash
virt-top
htop
```

High CPU usage is normal during deployment. Wait for provisioning to complete before making changes.

#### Optimization Example

```ruby
libvirt.memory = 1024
libvirt.cpus = 1
```

You can also deploy only the VMs you need.

---

## Common Workflows

### Workflow 1: Daily Lab Session

```bash
vagrant resume
vagrant status
vagrant ssh k3s-cp -c 'kubectl get nodes'
vagrant ssh k3s-cp
vagrant suspend
```

### Workflow 2: Create Lab Snapshot Before Testing

```bash
virsh snapshot-create-as --domain k3s-cp stable-v1 --description "Before security testing"
virsh snapshot-list --domain k3s-cp
virsh snapshot-revert --domain k3s-cp stable-v1
```

### Workflow 3: SSH into Multiple VMs

```bash
vagrant ssh k3s-cp
vagrant ssh k3s-cp -c 'kubectl get nodes'
vagrant ssh k3s-w1 -c 'systemctl status kubelet'
```

### Workflow 4: Debugging Lab Issues

```bash
VAGRANT_LOG=debug vagrant up 2>&1 | tee debug.log
virsh list
virsh dominfo k3s-cp
virsh console k3s-cp
virsh net-info default
tail -100 debug.log | grep -i error
vagrant destroy k3s-w1
vagrant up k3s-w1
```

---

## Summary Table: Common Commands

| Task | Command | Example |
|------|---------|---------|
| Start lab | `vagrant up` | `cd labs/infrastructure/devops-linux-lab && vagrant up` |
| Stop lab | `vagrant suspend` | `vagrant suspend` |
| Destroy lab | `vagrant destroy -f` | `vagrant destroy -f` |
| SSH to VM | `vagrant ssh <name>` | `vagrant ssh k3s-cp` |
| Run command | `vagrant ssh <name> -c 'cmd'` | `vagrant ssh k3s-cp -c 'kubectl get nodes'` |
| Check status | `vagrant status` | `vagrant status` |
| List VMs | `virsh list` | `virsh list --all` |
| Create snapshot | `virsh snapshot-create-as` | `virsh snapshot-create-as --domain k3s-cp backup1` |
| Revert snapshot | `virsh snapshot-revert` | `virsh snapshot-revert --domain k3s-cp backup1` |
| Monitor resources | `virt-top` | `virt-top` |
| Check network | `virsh net-list` | `virsh net-list --all` |

---

**Last Updated:** 2026-06-26  
**Status:** Active & Maintained