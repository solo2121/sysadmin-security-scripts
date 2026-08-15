# Labs

This directory contains reproducible lab environments for infrastructure engineering and security practice. Each lab is self-contained and should be run from its own directory.

---

## Available Labs

| Lab | Path | Focus |
|-----|------|-------|
| DevOps Linux Lab | [`infrastructure/devops-linux-lab/`](infrastructure/devops-linux-lab/) | Vagrant/libvirt infrastructure, Linux administration, Kubernetes, DevOps workflows, and monitoring |
|  Active Directory Pentest Lab (base)| [`security/active-directory/base/`](security/active-directory/base/) | Active Directory enumeration, Kerberos attacks, lateral movement, privilege escalation, and remediation practice |
|  Active Directory Pentest Lab (vlan-segmented)| [`security/active-directory/vlan-segmented/`](security/active-directory/vlan-segmented/) | VLAN segmentation, multi-subnet enterprise simulation, topology validation, and network isolation testing |

Each lab above also ships a VirtualBox-compatible `Vagrantfile` under its own `virtualbox/` subdirectory (e.g. `security/active-directory/base/virtualbox/`), for hosts without KVM/libvirt. See that lab's README for VirtualBox-specific setup, configuration, and troubleshooting.

---

## Prerequisites

Recommended host setup (KVM/libvirt, the default provider):

- Linux host with hardware virtualization enabled.
- KVM/QEMU and libvirt.
- Vagrant.
- `vagrant-libvirt` plugin.
- `vagrant-reload` plugin for the Active Directory security labs.
- 8 GB RAM minimum, 16 GB or more recommended.
- 50 GB free disk minimum, 100 GB or more recommended.

See [`../docs/setup/installation.md`](../docs/setup/installation.md) for full setup instructions.

**No KVM/libvirt available (macOS, Windows, or a Linux host without libvirt)?**
Each lab also has a `virtualbox/Vagrantfile` — same VMs, IPs, and
provisioning, targeting VirtualBox instead. Requires
[VirtualBox](https://www.virtualbox.org/) 7.0+ and Vagrant >= 2.2 (the
VirtualBox provider is built into Vagrant, no extra plugin needed). Not
supported on Apple Silicon/ARM hosts. `cd` into a lab's `virtualbox/`
subdirectory and run `vagrant up --provider=virtualbox` instead of step
below. See each lab's README for details.

---

## Running a Lab

Clone the repository:

```bash
git clone https://github.com/solo2121/security-engineering-lab.git
cd security-engineering-lab
```

Change into the lab directory you want to use, then validate the Vagrantfile:

```bash
cd labs/infrastructure/devops-linux-lab
vagrant validate
```

Start the lab:

```bash
vagrant up
```

Check status:

```bash
vagrant status
```

Connect to a VM:

```bash
vagrant ssh <node-name>
```

Stop or remove the lab when finished:

```bash
vagrant halt
vagrant destroy -f
```

---

## Lab Safety

Security labs may include intentionally vulnerable services, weak credentials, exploitation workflows, and attack-chain documentation. Run them only in isolated lab networks you own or are authorized to test.

Before launching a security lab, review [`../docs/security-scope.md`](../docs/security-scope.md).

---

## Recommended Learning Path

1. Start with the DevOps Linux Lab to build comfort with Linux, Vagrant, virtualization, and infrastructure workflows.
2. Practice monitoring and hardening with scripts under [`../tools/sysadmin/`](../tools/sysadmin/).
3. Explore reconnaissance and validation tooling under [`../tools/security/`](../tools/security/).
4. Move into the  Active Directory Pentest Lab (base)for controlled attack-chain practice.
5. Use the  Active Directory Pentest Lab (vlan-segmented)to reason about segmentation, routing, and network isolation.

---

## Lab Quality Checklist

When adding or improving a lab, include:

- A `README.md` with prerequisites, setup, validation, and cleanup steps.
- A `Vagrantfile` or equivalent provisioning entry point.
- Scripts for repeatable setup and testing where practical.
- Documentation for architecture, credentials, and troubleshooting.
- Clear warnings for offensive or intentionally vulnerable components.

---

## Troubleshooting

Common checks:

- Confirm virtualization is enabled in BIOS/UEFI.
- Confirm your user belongs to the `libvirt` and `kvm` groups.
- Run `vagrant validate` before `vagrant up`.
- Check `virsh list --all` if VMs are stuck or partially created.
- Destroy and rebuild only lab resources you are sure you no longer need.

For more help, see [`../docs/setup/troubleshooting.md`](../docs/setup/troubleshooting.md).