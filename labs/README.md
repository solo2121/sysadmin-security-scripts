# Labs

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](../LICENSE)
[![Platform](https://img.shields.io/badge/platform-KVM%2Flibvirt%20%7C%20VirtualBox-blue)](https://www.linux-kvm.org/)
![Vagrant](https://img.shields.io/badge/Vagrant-Lab-orange)
![Security](https://img.shields.io/badge/Security-Research-red)

This directory contains the reproducible lab environments for the Security Engineering Lab project. Each lab is self-contained, ships its own `Vagrantfile`, and should be run from its own directory.

For the project-wide overview, architecture, and portfolio summary, see the [root README](../README.md).

---

## Lab overview

| Lab | Path | Focus |
|---|---|---|
| DevOps/DevSecOps Lab | [`infrastructure/devops-linux-lab/`](infrastructure/devops-linux-lab/) | Vagrant/libvirt infrastructure, Linux administration, Kubernetes, DevOps workflows, and monitoring |
| Active Directory Pentest Lab (base) | [`security/active-directory/base/`](security/active-directory/base/) | Active Directory enumeration, Kerberos attacks, lateral movement, privilege escalation, and remediation practice |
| Active Directory Pentest Lab (VLAN-segmented) | [`security/active-directory/vlan-segmented/`](security/active-directory/vlan-segmented/) | VLAN segmentation, multi-subnet enterprise simulation, topology validation, and network isolation testing |
| Windows Server Hardening Lab (experimental) | [`security/windows-hardening/`](security/windows-hardening/) | Defensive counterpart to the AD pentest lab; CIS-benchmark-inspired hardening baseline, with each control mapped to a specific attack technique |

Every lab ships a single, unified `Vagrantfile` supporting both KVM/libvirt and VirtualBox (select the provider with `--provider`). See each lab's own README for VirtualBox-specific setup, configuration, and troubleshooting.

---

## Intended audience and prerequisites

These labs are intended for security practitioners, platform engineers, and students who want a reproducible, disposable environment for authorized offensive and defensive security practice, and for infrastructure engineering. Familiarity with Linux, Vagrant, and basic networking is assumed; each lab's own README documents its lab-specific prerequisites in detail.

Recommended host setup (KVM/libvirt, the default and primary provider on Linux):

- Linux host with hardware virtualization enabled.
- KVM/QEMU and libvirt.
- Vagrant.
- `vagrant-libvirt` plugin.
- `vagrant-reload` plugin for the Active Directory security labs.
- 8 GB RAM minimum, 16 GB or more recommended.
- 50 GB free disk minimum, 100 GB or more recommended.

See [Installation Guide](../docs/setup/installation.md) for the full setup instructions, and [Minimal Resource Deployment](../docs/guides/optimization/minimal-resource-deployment.md) for constrained hosts.

---

## Supported virtualization providers

| Provider | Support level | Notes |
|---|---|---|
| KVM/QEMU with libvirt | Primary, on Linux | Default provider for all labs; requires the `vagrant-libvirt` plugin. |
| VirtualBox | Alternative, on compatible Intel/AMD x86_64 hosts | Same VMs, IPs, and provisioning as libvirt through the same `Vagrantfile`; requires [VirtualBox](https://www.virtualbox.org/) 7.0+ and Vagrant >= 2.2. No extra plugin needed. |

> [!IMPORTANT]
> Apple Silicon/ARM hosts are not supported. All current labs depend on x86_64 guests and x86_64-oriented Vagrant boxes. See the [root README](../README.md#apple-silicon-status) for status.

---

## Deployment and usage workflow

Clone the repository:

```bash
git clone https://github.com/solo2121/security-engineering-lab.git
cd security-engineering-lab
```

Change into the lab directory you want to use, then validate the `Vagrantfile`:

```bash
cd labs/infrastructure/devops-linux-lab
vagrant validate
```

Start the lab with the primary Linux provider:

```bash
vagrant up --provider=libvirt
```

Use VirtualBox only on a compatible Intel/AMD x86_64 host:

```bash
vagrant up --provider=virtualbox
```

Check VM status:

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

## Configuration notes

- Every lab's `Vagrantfile` supports both the libvirt and VirtualBox providers; select the provider explicitly with `--provider` rather than relying on the default.
- Lab-specific configuration (VM counts, `LAB_PROFILE` options, network layout, and credentials) is documented in each lab's own README and `docs/` directory.
- Supported lab environments that ship a `vagrant_manager.py` script can be managed interactively; see each lab's README for usage.

---

## Lab safety

Security labs may include intentionally vulnerable services, weak credentials, exploitation workflows, and attack-chain documentation. Run them only in isolated lab networks that you own or are explicitly authorized to test, and that cannot route to production, personal, or public networks.

Before launching a security lab, review the [Security Scope](../docs/security-scope.md) and [Emergency Isolation Runbook](../docs/architecture/emergency-isolation-runbook.md).

---

## Recommended learning path

1. Start with the DevOps/DevSecOps Lab to build comfort with Linux, Vagrant, virtualization, and infrastructure workflows.
2. Practice monitoring and hardening with scripts under [`../tools/sysadmin/`](../tools/sysadmin/).
3. Explore reconnaissance and validation tooling under [`../tools/security/`](../tools/security/).
4. Move into the Active Directory Pentest Lab (base) for controlled attack-chain practice.
5. Use the Active Directory Pentest Lab (VLAN-segmented) to reason about segmentation, routing, and network isolation.
6. Once comfortable with the attack side, try the Windows Server Hardening Lab to see and validate the corresponding defensive controls for each technique.

For the complete recommended progression, see the [Learning Path](../docs/project/learning-path.md).

---

## Lab quality checklist

When adding or improving a lab, include:

- A `README.md` with prerequisites, setup, validation, and cleanup steps.
- A `Vagrantfile` or equivalent provisioning entry point.
- Scripts for repeatable setup and testing where practical.
- Documentation for architecture, credentials, and troubleshooting.
- Clear warnings for offensive or intentionally vulnerable components.

---

## Validation and troubleshooting

Common checks:

- Run `./scripts/check-prerequisites.sh --all` from the repository root before deploying.
- Confirm virtualization is enabled in BIOS/UEFI.
- Confirm your user belongs to the `libvirt` and `kvm` groups.
- Run `vagrant validate` before `vagrant up`.
- Check `virsh list --all` if VMs are stuck or partially created.
- Destroy and rebuild only lab resources you are sure you no longer need.

For more help, see [Troubleshooting](../docs/setup/troubleshooting.md).

---

## Related documentation

- [Root README](../README.md) — project overview, architecture, and portfolio summary
- [Documentation Index](../docs/README.md) — full documentation map
- [Security Scope](../docs/security-scope.md) — authorized use and isolation requirements
- [CONTRIBUTING.md](../CONTRIBUTING.md) — contributor workflow
- [LICENSE](../LICENSE) — project license
