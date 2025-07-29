
# **How to Install and Configure KVM/QEMU on Rhino Linux **

## **Introduction**

This tutorial provides a step-by-step guide to installing and configuring Kernel-based Virtual Machine (KVM) and Quick Emulator (QEMU) on Rhino Linux. KVM/QEMU enables the creation and management of virtual machines (VMs) on your Linux server, making it an ideal solution for virtualization.

## **Step 1: Verify Virtualization Support**

Before proceeding with the installation, ensure your processor supports virtualization.

1. Open a terminal and run the following command to check for hardware virtualization support:
    
2. lscpu | grep Virtualization
    
3. If the output shows "Virtualization: VT-x" or "VT-d," your processor supports virtualization.
    

## **Step 2: Install KVM, QEMU, and Related Packages**

Install the required packages for enabling KVM/QEMU virtualization.

1. Update the package repository and install the necessary packages:
    
2. sudo apt update
    
3. sudo apt install -y qemu-kvm libvirt-clients libvirt-daemon-system bridge-utils virtinst libvirt-daemon virt-top libguestfs-tools libosinfo-bin qemu-system tuned
    
4. Key packages installed:
    

- **qemu-kvm**: KVM integration with QEMU
    
- **libvirt**: Toolkit for managing virtualization technologies
    
- **bridge-utils**: Utilities for creating network bridges
    
- **virtinst**: Command-line tool for VM creation
    
- **virt-top**: Tool for monitoring VM performance
    
- **libguestfs-tools**: Tools for interacting with VM disk images
    
- **tuned**: Performance optimization tool
    

1. Add your user to the required groups:
    
2. sudo usermod -aG libvirt $(whoami)
    
3. sudo usermod -aG kvm $(whoami)
    
4. Reboot your system to apply group changes:
    
5. sudo reboot
    
6. Enable and start the tuned service:
    
7. sudo systemctl enable --now tuned
    
8. sudo tuned-adm profile virtual-host
    
9. sudo tuned-adm active
    
10. Verify the status of libvirt and KVM:
    
11. sudo virsh net-list --all
    
12. sudo nmcli device status
    

## **Step 3: Create a Bridge Network**

A bridge network allows VMs to communicate with the external network.

1. Create a bridge network:
    
2. sudo nmcli connection add type bridge con-name br0 ifname br0
    
3. Add your physical network interface as a slave to the bridge:
    
4. sudo nmcli connection add type ethernet slave-type bridge con-name 'KVM Bridge' ifname ens33 master br0
    
5. Enable automatic connection for slave devices:
    
6. sudo nmcli connection modify br0 connection.autoconnect-slaves 1
    
7. Activate the bridge connection:
    
8. sudo nmcli connection up br0
    
9. sudo nmcli connection reload
    
10. Verify the bridge status:
    
11. sudo nmcli device status
    
12. ip -brief addr show dev br0
    

## **Step 4: Set Permissions for the Image Directory**

The default location for VM images is /var/lib/libvirt/images. Configure proper permissions to allow user access.

1. Verify the current permissions:
    
2. ls /var/lib/libvirt/images
    
3. Reset the Access Control List (ACL):
    
4. sudo setfacl -R -b /var/lib/libvirt/images
    
5. Grant your user access:
    
6. sudo setfacl -R -m u:$(whoami):rwX /var/lib/libvirt/images
    
7. sudo setfacl -m d:u:$(whoami):rwx /var/lib/libvirt/images
    
8. Install a GUI for managing VMs:
    
9. sudo apt install virt-manager virt-viewer -y
    

## **Step 5: Convert OVA Files to QCOW2 Format**

KVM/QEMU supports the QCOW2 format for improved performance. Convert other formats to QCOW2 if needed.

### **5.1 Extract OVA Files**

1. Extract an OVA file: tar xf <ova_file>.ova -C <temporary_directory>
    

### **5.2 Convert VMDK to QCOW2**

1. Convert a VMDK file to QCOW2: qemu-img convert -c -O qcow2 <input_file.vmdk> <output_file.qcow2>
    

### **5.3 Convert Other Formats (VHD, VDI, RAW)**

Convert various formats to QCOW2:

# Convert VHD

qemu-img convert -c -O qcow2 my_disk.vhd my_disk.qcow2

# Convert VDI

qemu-img convert -c -O qcow2 my_disk.vdi my_disk.qcow2

# Convert RAW

qemu-img convert -c -O qcow2 my_disk.raw my_disk.qcow2

### **5.4 Display Progress**

Use the -p option to monitor progress:

qemu-img convert -c -O qcow2 -p my_disk.vmdk my_disk.qcow2

### **5.5 Batch Conversion**

Convert multiple VMDK files in a directory:

for file in *.vmdk; do qemu-img convert -c -O qcow2 -p "$file" "${file%.vmdk}.qcow2"; done

## **Step 6: Verify the Conversion**

1. Check details of the converted image: qemu-img info my_disk.qcow2
    

## **Step 7: Install Additional Tools**

Enhance virtualization management with additional tools.

1. Install useful utilities:
    
2. sudo apt install virtinst libosinfo-bin virt-top libguestfs-tools
    
3. Install the qemu-guest-agent:
    
4. sudo apt install qemu-guest-agent
    
5. Verify your user’s group memberships:
    
6. sudo usermod -aG libvirt,kvm $(whoami)
    

## **Step 8: Verify the Installation**

1. List available virtual machines: sudo virsh list --all
    

By following this guide, you will successfully install and configure KVM/QEMU on Rhino Linux. For additional support, consult the official documentation or join the community forums.