**KVM/QEMU (CLI) - A Complete Tutorial**

KVM (Kernel-based Virtual Machine) combined with QEMU (Quick Emulator) is a powerful virtualization solution for Linux. This tutorial covers how to manage KVM/QEMU virtual machines (VMs) entirely from the command line.

---

## **Prerequisites**
- A Linux system with KVM support (check with `kvm-ok` or `lsmod | grep kvm`)
- `qemu-kvm`, `libvirt`, and `virt-manager` (CLI tools) installed:
  ```bash
  sudo apt update && sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst
  ```
- Root or sudo privileges.

---

## **1. Checking KVM Support**
Verify that KVM is enabled:
```bash
lsmod | grep kvm
```
If you see `kvm_intel` or `kvm_amd`, your system supports KVM.

---

## **2. Managing Virtual Machines (VMs)**
### **A. Creating a New VM**
Use `virt-install` to create a VM:

```bash
sudo virt-install \
  --name=ubuntu-vm \
  --ram=2048 \
  --vcpus=2 \
  --disk path=/var/lib/libvirt/images/ubuntu-vm.qcow2,size=20 \
  --os-type=linux \
  --os-variant=ubuntu22.04 \
  --network bridge=virbr0 \
  --graphics none \
  --console pty,target_type=serial \
  --location 'http://archive.ubuntu.com/ubuntu/dists/jammy/main/installer-amd64/' \
  --extra-args 'console=ttyS0,115200n8 serial'
```
- `--name`: VM name.
- `--ram`: Memory in MB.
- `--vcpus`: Number of CPUs.
- `--disk`: Storage path and size (GB).
- `--network`: Network bridge (default: `virbr0` for NAT).
- `--graphics none`: Use serial console (headless).
- `--location`: OS installation source (ISO or URL).

---

### **B. Listing VMs**
List all VMs:
```bash
virsh list --all
```
- `--all` includes powered-off VMs.

---

### **C. Starting, Stopping, and Rebooting a VM**
- **Start a VM**:
  ```bash
  virsh start ubuntu-vm
  ```
- **Shutdown gracefully**:
  ```bash
  virsh shutdown ubuntu-vm
  ```
- **Force stop**:
  ```bash
  virsh destroy ubuntu-vm
  ```
- **Reboot**:
  ```bash
  virsh reboot ubuntu-vm
  ```

---

### **D. Accessing a VM’s Console**
Connect to the VM’s serial console:
```bash
virsh console ubuntu-vm
```
(Press `Ctrl + ]` to exit.)

---

### **E. Editing VM Configuration**
Dump the XML config, edit, and redefine:
```bash
virsh dumpxml ubuntu-vm > ubuntu-vm.xml
nano ubuntu-vm.xml  # Make changes
virsh define ubuntu-vm.xml
```

---

### **F. Cloning a VM**
Clone an existing VM:
```bash
virt-clone --original ubuntu-vm --name ubuntu-vm-clone --file /var/lib/libvirt/images/ubuntu-vm-clone.qcow2
```

---

### **G. Deleting a VM**
Remove a VM (does not delete disk):
```bash
virsh undefine ubuntu-vm --remove-all-storage
```

---

## **3. Managing Storage**
### **A. Listing Storage Pools**
```bash
virsh pool-list --all
```

### **B. Creating a Storage Pool**
```bash
virsh pool-define-as --name default --type dir --target /var/lib/libvirt/images
virsh pool-start default
virsh pool-autostart default
```

### **C. Creating a Disk Image**
```bash
qemu-img create -f qcow2 /var/lib/libvirt/images/ubuntu-disk.qcow2 20G
```

---

## **4. Managing Networks**
### **A. Listing Networks**
```bash
virsh net-list --all
```

### **B. Creating a Bridged Network**
Edit `/etc/netplan/01-netcfg.yaml` (example for Netplan):
```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp3s0:
      dhcp4: no
  bridges:
    br0:
      interfaces: [enp3s0]
      dhcp4: yes
```
Apply changes:
```bash
sudo netplan apply
```

### **C. Attaching a VM to a Bridge**
Edit VM config (`virsh edit ubuntu-vm`) and change:
```xml
<interface type='bridge'>
  <source bridge='br0'/>
</interface>
```

---

## **5. Snapshots**
### **A. Creating a Snapshot**
```bash
virsh snapshot-create-as ubuntu-vm --name "snap1"
```

### **B. Listing Snapshots**
```bash
virsh snapshot-list ubuntu-vm
```

### **C. Restoring a Snapshot**
```bash
virsh snapshot-revert ubuntu-vm --snapshotname "snap1"
```

### **D. Deleting a Snapshot**
```bash
virsh snapshot-delete ubuntu-vm --snapshotname "snap1"
```

---

## **6. Monitoring & Performance**
### **A. Viewing VM Resource Usage**
```bash
virsh domstats ubuntu-vm
```

### **B. CPU & Memory Usage**
```bash
virsh dominfo ubuntu-vm
```

---

## **Conclusion**
You now know how to manage KVM/QEMU VMs entirely from the CLI. Key commands:
- `virsh` – Manage VMs.
- `virt-install` – Create VMs.
- `qemu-img` – Manage disk images.
- `virt-clone` – Clone VMs.

For more details, check `man virsh`, `man qemu-img`, and the [official libvirt docs](https://libvirt.org/docs.html).

Happy virtualizing! 🚀