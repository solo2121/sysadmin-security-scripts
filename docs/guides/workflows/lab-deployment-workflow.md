# Lab Deployment Workflow Guide

Detailed workflows and best practices for deploying and managing the sysadmin-security-lab.

---

## Table of Contents

1. [Pre-Deployment Planning](#pre-deployment-planning)
2. [DevOps Linux Lab Deployment](#devops-linux-lab-deployment)
3. [AD Pentest Lab Deployment](#ad-pentest-lab-deployment)
4. [Post-Deployment Verification](#post-deployment-verification)
5. [Lab Management Strategies](#lab-management-strategies)
6. [Performance Optimization](#performance-optimization)

---

## Pre-Deployment Planning

### Resource Assessment

```bash
# Assess current system capacity
hostnamectl                    # OS info
nproc                          # CPU cores
free -h                        # RAM
df -h /var/lib/libvirt/images  # Disk space
virsh nodeinfo                 # Hypervisor info

# Example output for planning:
# CPU: 16 cores available
# RAM: 32GB available
# Disk: 500GB available SSD
# Can run: Full AD pentest lab (14 VMs) + DevOps lab (3 VMs)
```

### Storage Planning

| Lab | VMs | Est. Disk/VM | Total Disk | Build Time |
|-----|-----|--------------|-----------|-----------|
| DevOps Linux | 3 | 20GB | 60GB | 15-20 min |
| AD Pentest | 14 | 25-40GB | 250-350GB | 60-90 min |
| Both Labs | 17 | Mixed | 310-410GB | 120+ min |

### Memory Planning

```bash
# Recommended allocation per VM type

# Linux control plane: 2GB base + 1GB per role
# Kubernetes control plane: 4GB minimum
# Kubernetes worker: 2GB minimum

# Windows Server: 4-8GB minimum
# Domain Controller: 4GB minimum
# Workstations: 2GB minimum

# Example 32GB system allocation:
# - DevOps control: 4GB
# - DevOps worker 1: 2GB
# - DevOps worker 2: 2GB
# - DC: 4GB
# - Kali: 4GB
# - SQL Server: 4GB
# - Others: 8GB
# Total: ~28GB (leaving 4GB for host OS)
```

---

## DevOps Linux Lab Deployment

### Phase 1: Preparation (5 minutes)

```bash
# 1. Navigate to lab
cd ~/labs/sysadmin-security-lab/labs/infrastructure/devops-linux-lab

# 2. Review configuration
cat Vagrantfile | head -50

# 3. Check prerequisites
vagrant version
vagrant plugin list | grep libvirt
virsh list

# 4. Verify connectivity
ping -c 1 8.8.8.8
```

### Phase 2: Box Preparation (10-30 minutes)

```bash
# 1. Pre-download base box (can be very slow first time)
vagrant box add ubuntu/jammy64 --provider libvirt

# Monitor download (in another terminal)
watch -n 2 'du -sh ~/.vagrant.d/boxes/ubuntu-jammy64/*/provider_libvirt/box.img'

# 2. Verify box is cached
vagrant box list
# Expected: ubuntu/jammy64 (libvirt, 20260530.0.0)

# 3. Optional: Import into libvirt directly for speed
sudo virsh vol-list --pool default
```

### Phase 3: VM Creation (15-20 minutes)

```bash
# 1. Start lab with verbose logging
VAGRANT_LOG=info vagrant up > deployment.log 2>&1 &

# 2. Monitor in separate terminal
watch -n 5 'vagrant status'
watch -n 5 'virsh list'
watch -n 2 'free -h | head -2'

# 3. Expected sequence:
# - k3s-cp boots first
# - Network provisioning
# - k3s installation
# - k3s-w1 and k3s-w2 boot in parallel
# - Worker registration to cluster

# 4. Check progress
tail -f deployment.log | grep -E "Running provisioner|k3s|cluster"
```

### Phase 4: Post-Deployment Verification (5 minutes)

```bash
# 1. Verify all VMs running
vagrant status

# 2. SSH into control plane
vagrant ssh k3s-cp

# Inside VM:
# - Check nodes
kubectl get nodes -o wide
kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[].status,ROLES:.metadata.labels.node-role\.kubernetes\.io/control-plane

# - Check system pods
kubectl get pods -A

# - Check resources
free -h
df -h
systemctl status k3s

# Exit
exit

# 3. Test network
vagrant ssh k3s-cp -c 'ping -c 1 192.168.122.11'

# 4. Document services
echo "=== Lab Services ===" > lab-services.txt
for vm in k3s-cp k3s-w1 k3s-w2; do
  echo "VM: $vm" >> lab-services.txt
  vagrant ssh $vm -c 'ip addr show eth1' >> lab-services.txt
done
cat lab-services.txt
```

---

## AD Pentest Lab Deployment

### Critical Deployment Order

```
Phase 1: Domain Controller (Critical - must be ready first)
  └─ DC01
  
Phase 2: Directory Services (Dependent on DC)
  ├─ CA01-ESC (Certificate Authority - AD CS ESC1/3/4/6/7/8 vulnerabilities)
  ├─ DB01 (SQL Server)
  └─ EXCH01 (Exchange)
  
Phase 3: Client/Attacker Systems (Once DC is ready)
  ├─ Kali (Attacker)
  ├─ Win10 (Domain workstation)
  ├─ Linux01 (Internal server)
  └─ Others
```

### Phase 1: Domain Controller Deployment (30-45 minutes)

```bash
cd ~/labs/sysadmin-security-lab/labs/security/ad-pentest

# 1. Start ONLY the Domain Controller
vagrant up dc01

# 2. Monitor initialization (WILL BE SLOW - DC is large)
watch -n 10 'virsh dominfo dc01 | grep -E "State|CPU"'

# 3. Check DC readiness
vagrant winrm-command "Test-Path C:\DC-FINAL.txt" --elevated 2>/dev/null
# Expected: Error initially, then success once ready

# 4. Verify DC services when ready
vagrant winrm-command "Get-AdDomain" --elevated
# Expected: Domain: lab.local

# 5. Verify DNS
nslookup dc01.lab.local 172.28.128.21
# Expected: Address: 172.28.128.21

# 6. Create deployment checkpoint
virsh snapshot-create-as --domain dc01 ready-for-clients \
    --description "DC ready, clients can join"
```

### Phase 2: Services Deployment (20-30 minutes)

```bash
# 1. Start CA and DB (parallel)
vagrant up ca01-esc db01

# 2. Monitor both
watch -n 10 'virsh list | grep -E "ca01-esc|db01"'

# 3. Verify services
# Check CA:
vagrant winrm-command "certutil -dcinfo" --elevated

# Check DB:
vagrant winrm-command "Get-SqlInstance" --elevated

# 4. Wait for stability
sleep 300

# 5. Checkpoint after services ready
virsh snapshot-create-as --domain dc01 services-ready
virsh snapshot-create-as --domain ca01-esc services-ready
```

### Phase 3: Client/Attacker Deployment (15-25 minutes)

```bash
# 1. Deploy Kali attacker VM (important for testing)
vagrant up kali

# 2. Deploy domain clients
vagrant up win10 linux01

# 3. Deploy remaining systems
vagrant up llm01 cloud-pentest

# 4. Full lab startup (from snapshot if exists)
# Option A: Clean start
vagrant up

# Option B: Selective start (to save resources)
export VAGRANT_VMS="dc01,kali,llm01,cloud-pentest"
vagrant up
```

### Phase 4: Lab Verification (10 minutes)

```bash
# 1. Verify all VMs
vagrant status

# 2. Test Kali attacker connectivity
vagrant ssh kali -c 'nslookup dc01.lab.local 172.28.128.21'

# 3. Test AD queries
vagrant ssh kali -c 'net user /domain' 2>/dev/null

# 4. Verify network segmentation
vagrant ssh kali -c 'ping -c 1 172.28.128.21'  # DC should respond
vagrant ssh kali -c 'ping -c 1 172.28.128.23'  # DB should respond

# 5. Validate critical services
# LLM endpoint
curl http://172.28.128.60:8080/health

# Cloud platform
curl http://172.28.128.80:4566/_localstack/health

# 6. Record lab state
echo "Lab deployed: $(date)" > lab-status.txt
vagrant status >> lab-status.txt
```

---

## Post-Deployment Verification

### Comprehensive Lab Validation

```bash
# Create validation script
cat > validate-lab.sh << 'EOF'
#!/bin/bash

echo "=== Lab Validation Report ==="
echo "Timestamp: $(date)"
echo

# Check VMs
echo "=== VM Status ==="
vagrant status

# Check Kubernetes (if applicable)
echo
echo "=== Kubernetes Status ==="
vagrant ssh k3s-cp -c 'kubectl get nodes' 2>/dev/null || echo "K3s not deployed"

# Check network
echo
echo "=== Network Validation ==="
virsh net-list

# Check storage
echo
echo "=== Storage Usage ==="
du -sh /var/lib/libvirt/images/

# Check resources
echo
echo "=== System Resources ==="
echo "Memory:"
free -h
echo
echo "CPU:"
nproc
echo

# Check services
echo "=== Service Endpoints ==="
curl -s http://localhost:3000/api/health | jq . || echo "Grafana: Not accessible"
curl -s http://localhost:9090/api/v1/status/config | jq . || echo "Prometheus: Not accessible"

EOF

chmod +x validate-lab.sh
./validate-lab.sh
```

### Network Connectivity Tests

```bash
# Test DNS resolution
for host in dc01 kali win10 db01; do
  echo "Testing $host..."
  nslookup $host.lab.local 172.28.128.21 2>/dev/null | grep "Address"
done

# Test ping connectivity
for ip in 172.28.128.10 172.28.128.21 172.28.128.23; do
  echo -n "Pinging $ip: "
  ping -c 1 -W 2 $ip >/dev/null 2>&1 && echo "OK" || echo "FAIL"
done

# Test service ports
for port in 53 389 3389 1433 8080; do
  echo -n "Port $port: "
  timeout 2 bash -c "</dev/tcp/localhost/$port" >/dev/null 2>&1 && echo "OPEN" || echo "CLOSED"
done
```

### Security Verification

```bash
# Verify domain join
vagrant winrm-command "Get-ADComputer -Filter * -Server dc01" --elevated

# Verify user accounts
vagrant winrm-command "Get-ADUser -Filter * -Server dc01" --elevated

# Verify certificate services
vagrant winrm-command "certutil -ca.ca" --elevated

# Verify SQL Server
vagrant winrm-command "sqlcmd -Q 'SELECT @@VERSION;'" --elevated
```

---

## Lab Management Strategies

### Strategy 1: Snapshots for Quick Recovery

```bash
# Create snapshots after successful deployment
for vm in $(vagrant status | awk '/running/ {print $1}'); do
  virsh snapshot-create-as --domain $vm initial \
      --description "Clean deployment state"
done

# List all snapshots
virsh snapshot-list --all

# Revert to snapshot
virsh snapshot-revert --domain k3s-cp initial

# Delete old snapshots
virsh snapshot-delete --domain k3s-cp old-state
```

### Strategy 2: Resource Monitoring

```bash
# Continuous monitoring
watch -n 5 'virt-top --batch --iterations=1 | head -20'

# Or use individual commands
while true; do
  clear
  echo "=== Lab Resource Usage $(date) ==="
  virsh list --stats
  sleep 10
done
```

### Strategy 3: Backup and Recovery

```bash
# Backup Vagrant metadata
tar -czf vagrant-backup.tar.gz .vagrant/

# Backup VM images (requires shutdown)
vagrant suspend
tar -czf vm-images-backup.tar.gz /var/lib/libvirt/images/
vagrant resume

# Export VM definition
virsh dumpxml k3s-cp > k3s-cp.xml
```

### Strategy 4: Scaling Management

```bash
# Deploy only essential services
export VAGRANT_VMS="dc01,kali"
vagrant up

# Later, add more services
unset VAGRANT_VMS
vagrant up llm01 cloud-pentest

# Monitor resource impact
free -h before_and_after
```

---

## Performance Optimization

### Pre-Deployment Optimization

```bash
# 1. Disable unnecessary services
sudo systemctl disable bluetooth
sudo systemctl disable cups

# 2. Adjust swappiness
echo 'vm.swappiness = 10' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# 3. Increase file descriptors
echo 'fs.file-max = 2097152' | sudo tee -a /etc/sysctl.conf
echo '* soft nofile 65536' | sudo tee -a /etc/security/limits.conf
echo '* hard nofile 65536' | sudo tee -a /etc/security/limits.conf

# 4. Enable CPU performance mode
sudo cpupower frequency-set -g performance
```

### During-Deployment Optimization

```bash
# 1. Disable auto-updates during deployment
sudo systemctl stop apt-daily-upgrade
sudo systemctl mask apt-daily-upgrade

# 2. Monitor and adjust
virt-top

# 3. If sluggish, reduce VM count
vagrant suspend k3s-w2

# 4. Re-enable when done
sudo systemctl unmask apt-daily-upgrade
sudo systemctl start apt-daily-upgrade
```

### Post-Deployment Optimization

```bash
# 1. Enable CPU frequency scaling
sudo cpupower frequency-set -g powersave

# 2. Re-enable services
sudo systemctl enable bluetooth
sudo systemctl enable cups

# 3. Monitor long-term stability
watch -n 30 'free -h && echo "---" && df -h /var/lib/libvirt/images'

# 4. Clean up temporary files
vagrant box prune
docker system prune -a
```

---

## Troubleshooting Deployment Issues

### Issue: DC Won't Boot

```bash
# Check VM status
virsh dominfo dc01

# Check libvirt logs
sudo journalctl -u libvirtd -n 50

# Try manual boot
virsh start dc01

# If still fails, check disk
virsh domblklist dc01
sudo qemu-img info /var/lib/libvirt/images/dc01_disk0.qcow2

# Last resort: rebuild
vagrant destroy dc01
vagrant box prune
vagrant up dc01
```

### Issue: Network Issues After DC Boot

```bash
# Restart network
virsh net-destroy default
virsh net-start default

# Check DNS
nslookup dc01.lab.local 172.28.128.21

# Fix DNS on clients
for vm in kali win10; do
  vagrant ssh $vm -c 'sudo netplan set ethernets.eth1.dhcp4-overrides.use-dns=false'
  vagrant ssh $vm -c 'sudo netplan set ethernets.eth1.nameservers.addresses=[172.28.128.21]'
  vagrant ssh $vm -c 'sudo netplan apply'
done
```

### Issue: Out of Memory During Deployment

```bash
# Check current usage
free -h

# Reduce VM memory if possible
# Edit Vagrantfile:
# libvirt.memory = 1024  # Reduce from 2048

# Or suspend non-essential VMs
vagrant suspend k3s-w2

# Monitor memory
watch -n 2 'free -h'
```

---

## Quick Reference: Deployment Checklist

- [ ] System requirements verified (CPU, RAM, disk)
- [ ] Libvirt installed and service running
- [ ] Vagrant installed with libvirt plugin
- [ ] Network configured (default or custom)
- [ ] Base boxes downloaded
- [ ] Lab directory checked out
- [ ] Resource allocation planned
- [ ] Snapshots planned
- [ ] Deployment order understood
- [ ] Monitoring setup ready
- [ ] Backup strategy prepared
- [ ] Recovery plan documented

---

**Last Updated:** 2026-05-30  
**Status:** Active & Maintained
