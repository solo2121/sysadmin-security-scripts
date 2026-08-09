# Troubleshooting

This document lists common issues, causes, and fixes when working with the VLAN-segmented Active Directory pentest lab.

Most problems are related to permissions, libvirt state, or host networking conflicts.

---

## 1. VLAN or Bridge Creation Fails

### Symptoms

- `RTNETLINK answers: Operation not permitted`
- `Cannot find device br-vlanXX`
- The script exits early during setup

### Causes

- The script was not run with root privileges.
- libvirt is not running.
- Conflicting bridge names already exist.

### Fix

```bash
sudo ./scripts/setup-vlans.sh
```

Verify bridges:

```bash
ip link show type bridge
```

If a bridge already exists, remove it manually before retrying.

---

## 2. libvirt Cannot Attach a VM to a Bridge

### Symptoms

- VM fails to start.
- Error: `Network not found` or `Bridge not available`

### Causes

- libvirt is not running in system mode.
- The user is not in the `libvirt` group.
- The bridge was created after libvirt started.

### Fix

```bash
sudo systemctl restart libvirtd
```

Check permissions:

```bash
groups | grep libvirt
```

Re-attach the bridges:

```bash
sudo ./scripts/attach-vlan-bridges.sh
```

---

## 3. No Network Connectivity Between VMs

### Symptoms

- Ping fails between hosts on the same VLAN.
- ARP resolution does not complete.

### Causes

- Incorrect IP configuration.
- VM attached to the wrong bridge.
- Firewall blocking traffic.

### Fix

Validate interfaces:

```bash
ip a
```

Check bridge membership:

```bash
bridge link
```

Temporarily disable firewalls for testing:

```bash
sudo iptables -F
```

---

## 4. Unexpected Cross-VLAN Connectivity

### Symptoms

- Hosts on different VLANs can communicate without routing.

### Causes

- Bridges were accidentally connected.
- A physical interface is attached to a bridge.
- The host is acting as a router.

### Fix

Ensure bridges are isolated:

```bash
bridge vlan show
```

Disable IP forwarding:

```bash
echo 0 | sudo tee /proc/sys/net/ipv4/ip_forward
```

---

## 5. NetworkManager Conflicts

### Symptoms

- Bridges disappear after reboot.
- VLAN interfaces reset automatically.

### Causes

- NetworkManager is managing the bridges.

### Fix

Mark bridges as unmanaged:

```bash
nmcli dev set br-vlan10 managed no
nmcli dev set br-vlan20 managed no
nmcli dev set br-vlan30 managed no
```

---

## 6. Scripts Work Once but Fail After Reboot

### Symptoms

- The lab works initially but breaks after reboot.

### Causes

- Bridges are not persistent.
- libvirt networks are not reattached.

### Fix

Re-run the setup scripts:

```bash
sudo ./scripts/setup-vlans.sh
sudo ./scripts/attach-vlan-bridges.sh
```

Persistence can be added manually if needed.

---

## 7. Diagram Generation Fails

### Symptoms

- Mermaid file is not generated.
- Diagram output is empty.

### Causes

- Missing permissions.
- Invalid configuration values.

### Fix

Verify the config file:

```bash
cat configs/lab_config.yaml
```

Re-run:

```bash
./scripts/generate-network-diagram.sh
```

---

## Debug Checklist

Before opening an issue:

- [ ] libvirt is running.
- [ ] Bridges exist.
- [ ] VMs are attached to the correct bridges.
- [ ] IP addressing is correct.
- [ ] No unintended routing exists.

---

## Support Notes

This lab assumes familiarity with:

- Linux networking.
- VLAN concepts.
- libvirt internals.

Issues caused by unsupported host configurations may not be addressed.