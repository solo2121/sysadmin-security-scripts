# **QEMU/KVM CLI Management Tutorial**

This tutorial covers **QEMU** (Quick Emulator) and **KVM** (Kernel-based Virtual Machine) management from the **command line** in Ubuntu. We'll go through installation, VM creation, networking, snapshots, and advanced management.

---

## **1. Installation & Setup**
### **1.1 Check Virtualization Support**
Verify that your CPU supports hardware virtualization (Intel VT-x or AMD-V):
```bash
egrep -c '(vmx|svm)' /proc/cpuinfo
```
- If output ≥ **1**, virtualization is supported.
- Ensure it’s enabled in BIOS.

### **1.2 Install QEMU, KVM & Libvirt**
```bash
sudo apt update
sudo apt install -y qemu qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst virt-manager
```
- `qemu` – Emulator
- `qemu-kvm` – KVM acceleration
- `libvirt` – VM management daemon
- `virtinst` – CLI tools for VM creation
- `virt-manager` – Optional GUI (useful for beginners)

### **1.3 Verify KVM is Working**
```bash
sudo systemctl status libvirtd
lsmod | grep kvm  # Should show kvm_intel or kvm_amd
```

### **1.4 Add User to Libvirt Group**
```bash
sudo usermod -aG libvirt $(whoami)
sudo usermod -aG kvm $(whoami)
```
Log out and back in for changes to apply.

---

## **2. Creating a Virtual Machine (VM)**
### **2.1 Using `virt-install` (Recommended)**
```bash
sudo virt-install \
  --name ubuntu-vm \
  --ram 2048 \
  --vcpus 2 \
  --disk path=/var/lib/libvirt/images/ubuntu-vm.qcow2,size=20 \
  --os-type linux \
  --os-variant ubuntu22.04 \
  --network bridge=virbr0 \
  --graphics spice \
  --console pty,target_type=serial \
  --cdrom ~/Downloads/ubuntu-22.04-live-server-amd64.iso
```
- `--name`: VM name  
- `--ram`: Memory (MB)  
- `--vcpus`: CPU cores  
- `--disk`: Storage (creates a **20GB** qcow2 disk)  
- `--cdrom`: ISO path  

### **2.2 Using Raw `qemu-system` Command**
```bash
qemu-system-x86_64 \
  -enable-kvm \
  -m 2048 \
  -smp 2 \
  -drive file=/var/lib/libvirt/images/ubuntu-vm.qcow2,format=qcow2 \
  -cdrom ~/Downloads/ubuntu-22.04-live-server-amd64.iso \
  -boot d \
  -vga virtio \
  -display none \
  -daemonize
```
- Runs in the background (`-daemonize`)  
- Uses **KVM acceleration** (`-enable-kvm`)  

---

## **3. Managing VMs with `virsh`**
### **3.1 Basic VM Operations**
| Command | Description |
|---------|-------------|
| `virsh list --all` | List all VMs (running & stopped) |
| `virsh start ubuntu-vm` | Start VM |
| `virsh shutdown ubuntu-vm` | Graceful shutdown |
| `virsh destroy ubuntu-vm` | Force stop |
| `virsh reboot ubuntu-vm` | Reboot VM |
| `virsh suspend ubuntu-vm` | Pause VM |
| `virsh resume ubuntu-vm` | Resume paused VM |
| `virsh undefine ubuntu-vm` | Delete VM (keeps disk) |

### **3.2 Accessing VM Console**
- **Text Console (Serial)**:
  ```bash
  virsh console ubuntu-vm
  ```
  (Press `Ctrl + ]` to exit)  

- **Graphical Console (SPICE/VNC)**:
  ```bash
  virt-viewer ubuntu-vm
  ```

---

## **4. Networking**
### **4.1 Default Network (NAT)**
```bash
virsh net-list --all
virsh net-info default
```
- VMs get **NAT** networking by default.  

### **4.2 Bridge Networking (Host Network Access)**
1. **Create a Bridge**:
   ```bash
   sudo nano /etc/netplan/01-netcfg.yaml
   ```
   Add:
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
2. **Apply Changes**:
   ```bash
   sudo netplan apply
   ```
3. **Attach VM to Bridge**:
   ```bash
   virsh edit ubuntu-vm
   ```
   Change `<interface>` to:
   ```xml
   <interface type='bridge'>
     <source bridge='br0'/>
     <model type='virtio'/>
   </interface>
   ```

---

## **5. Storage Management**
### **5.1 Create a New Disk**
```bash
qemu-img create -f qcow2 /var/lib/libvirt/images/new-disk.qcow2 10G
```
- **qcow2** is recommended (supports snapshots, compression).  

### **5.2 Attach Disk to VM**
```bash
virsh attach-disk ubuntu-vm /var/lib/libvirt/images/new-disk.qcow2 vdb --persistent
```
- `vdb` = Second disk in Linux.  

---

## **6. Snapshots & Cloning**
### **6.1 Create a Snapshot**
```bash
virsh snapshot-create-as ubuntu-vm --name "snap1" --description "Before updates"
```
### **6.2 List Snapshots**
```bash
virsh snapshot-list ubuntu-vm
```
### **6.3 Revert to Snapshot**
```bash
virsh snapshot-revert ubuntu-vm --snapshotname "snap1"
```
### **6.4 Clone a VM**
```bash
virt-clone --original ubuntu-vm --name ubuntu-vm-clone --file /var/lib/libvirt/images/clone.qcow2
```

---

## **7. Advanced Commands**
### **7.1 Edit VM Configuration**
```bash
virsh edit ubuntu-vm  # Opens in default editor (nano/vim)
```
### **7.2 Remote Management**
```bash
virsh -c qemu+ssh://user@remote-host/system list --all
```
### **7.3 Check VM Performance**
```bash
virsh domstats ubuntu-vm
```

---

## **Conclusion**
You now know how to:
✅ Install & configure QEMU/KVM  
✅ Create & manage VMs via CLI  
✅ Configure networking & storage  
✅ Use snapshots & cloning  

For more details, check:
- `man virsh`
- `man qemu-system-x86_64`
- [Libvirt Documentation](https://libvirt.org/docs.html)

Happy virtualizing! 🚀