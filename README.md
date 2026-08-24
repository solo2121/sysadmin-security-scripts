# Security Engineering Lab

[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
![Platform](https://img.shields.io/badge/platform-Linux%7CmacOS%7CWindows-blue)
![Vagrant](https://img.shields.io/badge/Vagrant-Lab-orange)
![Security](https://img.shields.io/badge/Security-Research-red)
![DevSecOps](https://img.shields.io/badge/DevSecOps-Lab-purple)
[![CI](https://github.com/solo2121/security-engineering-lab/actions/workflows/ci.yml/badge.svg)](https://github.com/solo2121/security-engineering-lab/actions/workflows/ci.yml)

**Security Engineering Lab** is a modular, Vagrant-provisioned homelab for authorized security research and platform engineering. It includes isolated Active Directory environments, network segmentation, Kubernetes and DevSecOps workflows, Linux administration, and infrastructure automation.

The repository is designed to be **runnable, not static**: each lab includes deployable infrastructure, provisioning automation, validation workflows, and supporting technical documentation.

**Maintained by:** Miguel A. Carlo (`solo2121`)  
**Project status:** Active development

> [!IMPORTANT]
> **Supported hosts:** KVM/QEMU with libvirt is the primary provider on Linux for the full lab portfolio. VirtualBox workflows are maintained for compatible Intel/AMD x86_64 hosts running Linux, macOS, or Windows.
>
> **Apple Silicon status:** The Windows and Active Directory labs are not supported on Apple Silicon because they depend on x86_64 Windows guests, x86_64-oriented Vagrant boxes, and provider-specific validation.
>
> An experimental **Apple Silicon Lite / DevSecOps-only** profile is planned for ARM64-native Kubernetes and Linux platform-engineering workflows. It will exclude Windows, Active Directory, segmented-network, and other x86_64-dependent components. Until that profile is published and validated, Apple Silicon is not a supported deployment target.

---

<details>
<summary>Table of contents</summary>

- [Security Engineering Lab](#security-engineering-lab)
  - [At a glance](#at-a-glance)
  - [Which lab should I start with?](#which-lab-should-i-start-with)
  - [Quick start](#quick-start)
  - [See it in action](#see-it-in-action)
    - [Active Directory base lab](#active-directory-base-lab)
    - [DevOps/DevSecOps lab](#devopsdevsecops-lab)
    - [Segmented Active Directory lab](#segmented-active-directory-lab)
  - [Lab environments](#lab-environments)
    - [Active Directory Security Lab](#active-directory-security-lab)
    - [Segmented Active Directory Lab](#segmented-active-directory-lab-1)
    - [DevOps/DevSecOps platform lab](#devopsdevsecops-platform-lab)
    - [DevSecOps Lite — Apple Silicon / ARM64 (planned)](#devsecops-lite--apple-silicon--arm64-planned)
    - [Windows Server Hardening Lab (experimental)](#windows-server-hardening-lab-experimental)
  - [Provider compatibility](#provider-compatibility)
    - [Compatibility matrix](#compatibility-matrix)
    - [Apple Silicon status](#apple-silicon-status)
  - [Prerequisites](#prerequisites)
    - [Host requirements](#host-requirements)
    - [Recommended resources](#recommended-resources)
    - [Vagrant plugins](#vagrant-plugins)
  - [Architecture overview](#architecture-overview)
  - [What this project demonstrates](#what-this-project-demonstrates)
    - [Skills and technologies](#skills-and-technologies)
  - [Common workflows](#common-workflows)
    - [Rebuild a single VM](#rebuild-a-single-vm)
    - [Save and restore snapshots](#save-and-restore-snapshots)
    - [Re-run provisioning](#re-run-provisioning)
    - [Destroy a complete lab](#destroy-a-complete-lab)
    - [Switch providers](#switch-providers)
  - [Troubleshooting](#troubleshooting)
    - [`vagrant up` hangs or times out](#vagrant-up-hangs-or-times-out)
    - [Wrong provider selected](#wrong-provider-selected)
    - [WinRM or SSH connection failures](#winrm-or-ssh-connection-failures)
    - [Network or segmentation conflicts](#network-or-segmentation-conflicts)
    - [Apple Silicon and ARM64 incompatibility](#apple-silicon-and-arm64-incompatibility)
  - [Documentation hub](#documentation-hub)
  - [Repository structure](#repository-structure)
  - [Development quickstart](#development-quickstart)
  - [Project maturity](#project-maturity)
  - [Contributing](#contributing)
  - [Security and ethics](#security-and-ethics)
  - [Known limitations](#known-limitations)

</details>

---

## At a glance

| Item | Details |
|---|---|
| Primary provider | KVM/QEMU with libvirt on Linux |
| Alternative provider | VirtualBox on compatible Intel/AMD x86_64 hosts |
| Planned ARM64 profile | Apple Silicon DevSecOps Lite profile for validated Linux and Kubernetes workflows |
| Lab environments | Active Directory, network-segmented Active Directory, DevOps/DevSecOps, Windows Server hardening (experimental), and a planned ARM64 DevSecOps Lite profile |
| Automation | Vagrant, Ansible, Bash, and Python |
| Cloud-native stack | Selected DevOps/DevSecOps profiles use K3s, Harbor or an ARM64-compatible registry alternative, Argo CD, Prometheus, Grafana, Loki, Falco, and Kyverno; ARM64 availability is validated per component |
| Validation | GitHub Actions, pytest, Bats, ShellCheck, and documentation checks |
| Intended use | Authorized research, defensive security practice, and isolated education |

---

## Which lab should I start with?

| Lab | Default VMs | Host RAM (min / recommended) | Free disk | Best for |
|---|---:|---|---:|---|
| [Active Directory — base](./labs/security/active-directory/base/) | 6; up to 11 with `LAB_PROFILE=full` | 16 GB / 32 GB+ | 200 GB+ | Learning core AD attack paths, including Kerberoasting, AS-REP roasting, and AD CS abuse, without network-segmentation complexity. Start here if you are new to AD security. |
| [Active Directory — segmented](./labs/security/active-directory/vlan-segmented/) | 12 | 16 GB / 32 GB+ | 80 GB+ | Practicing lateral movement, routing controls, trust boundaries, and defensive visibility across segmented network boundaries. |
| [DevOps/DevSecOps](./labs/infrastructure/devops-linux-lab/) | 12 | 16 GB for a core cluster / 32 GB+ recommended | 200 GB+ | Kubernetes, Harbor, CI/CD, GitOps, observability, runtime security, policy enforcement, and Linux administration. Not AD-focused. |
| [DevSecOps Lite — Apple Silicon / ARM64 (planned)](./labs/infrastructure/devsecops-lite-arm64/) | Target: 1–3 ARM64 Linux nodes or containers | Target: 8 GB / 16 GB recommended | Target: 40 GB+ | Apple Silicon users who want to practice K3s, GitOps, observability, runtime security, policy enforcement, and Linux platform engineering without Windows or Active Directory dependencies. |
| [Windows Server Hardening (experimental)](./labs/security/windows-hardening/) | 1; 2 with `LAB_PROFILE=full` | 8 GB / 16 GB+ | 60 GB+ | A defensive counterpart to the AD base lab: a CIS-benchmark-inspired hardening baseline with controls mapped to specific attack techniques. Start after completing the AD base lab. |

> [!NOTE]
> Resource figures represent practical **host capacity**, not only aggregate guest allocations. Reserve additional CPU, RAM, and disk capacity for the host OS, Vagrant and provider overhead, base boxes, snapshots, package caches, and container-image storage.
>
> Resource figures marked **Target** for the planned ARM64 Lite profile are preliminary planning estimates. Publish measured requirements after validating the deployment on supported Apple Silicon hardware and the chosen ARM64 provider workflow.

Before deploying, run the full prerequisite check:

```bash
./scripts/check-prerequisites.sh --all
```

`--all` enables the lab-specific checks required by the repository's Windows-based and multi-lab workflows.

> [!NOTE]
> `make prereq` runs the baseline prerequisite check only. It does not currently pass `--all`.

For the recommended progression from Active Directory fundamentals through segmentation and DevSecOps workflows, see the [Learning Path](./docs/project/learning-path.md).

For constrained systems, see [Minimal Resource Deployment](./docs/guides/optimization/minimal-resource-deployment.md).

---

## Quick start

> [!CAUTION]
> Some labs intentionally include insecure configurations and authorized security-test scenarios. Deploy them only on an isolated host and virtual network that cannot route to production, personal, or public networks. Review the [Security Scope](./docs/security-scope.md) and [Emergency Isolation Runbook](./docs/architecture/emergency-isolation-runbook.md) before deployment.

Clone the repository and validate your host:

```bash
git clone https://github.com/solo2121/security-engineering-lab.git
cd security-engineering-lab
./scripts/check-prerequisites.sh --all
```

Start with the Active Directory base lab using the primary Linux provider:

```bash
cd labs/security/active-directory/base
vagrant up --provider=libvirt
```

Use VirtualBox only on a compatible Intel/AMD x86_64 host:

```bash
vagrant up --provider=virtualbox
```

Check the VM state:

```bash
vagrant status
```

Each lab includes a Python-based `vagrant_manager.py` for interactive or scripted VM management:

```bash
python3 vagrant_manager.py
```

Examples:

```bash
python3 vagrant_manager.py up kali dc01
python3 vagrant_manager.py up --provider virtualbox
```

Verify available commands:

```bash
python3 vagrant_manager.py --help
python3 vagrant_manager.py up --help
```

After deployment, follow the selected lab README and health-validation guidance before beginning an exercise. A successful `vagrant up` does not necessarily mean that every guest service, domain role, or Kubernetes component is fully ready.

The planned Apple Silicon DevSecOps Lite profile will have separate prerequisites, provider instructions, deployment commands, resource guidance, validation steps, and troubleshooting documentation. Do not use the x86_64 Vagrant workflows above as an Apple Silicon deployment path.

See the [Installation Guide](./docs/setup/installation.md), [Quickstart Examples](./docs/setup/quickstart-examples.md), and [Learning Path](./docs/project/learning-path.md) for provider setup, deployment patterns, and lab progression.

---

## See it in action

### Active Directory base lab

A complete Active Directory base lab deployment, from provider detection through domain promotion and post-boot health validation.

| 1. Provider auto-detection | 2. AD promotion succeeds | 3. Health check and lab manager |
|---|---|---|
| ![vagrant_manager.py detecting the libvirt provider and listing available lab VMs](./assets/demos/dc01-01-boot-provider-detect.gif) | ![Active Directory promotion completing successfully on dc01, followed by a reboot](./assets/demos/dc01-02-ad-promotion-success.gif) | ![Post-boot health check passing and the interactive lab manager menu](./assets/demos/dc01-03-healthcheck-manager.gif) |

### DevOps/DevSecOps lab

A complete Linux DevSecOps deployment, from K3s bootstrap through Harbor image seeding and authorized security-test scenario deployment.

| 1. K3s node ready | 2. Air-gapped image seeding | 3. Security-test scenarios deploy |
|---|---|---|
| ![K3s node Ready and kubectl API ready, with Ingress NGINX installing via Helm](./assets/demos/devops1-01-k3s-ready-ingress.gif) | ![Container images being pulled, tagged, and pushed into the air-gapped Harbor registry](./assets/demos/devops1-02-harbor-seeding.gif) | ![Authorized DevSecOps security-test scenarios deploying successfully, ending with Harbor login succeeding](./assets/demos/devops1-03-attack-vectors.gif) |

### Segmented Active Directory lab

A complete OPNsense deployment for the segmented Active Directory lab, from initial boot through reload and interface assignment.

| 1. Lab manager starts OPNsense | 2. Reload completes cleanly | 3. Full topology live |
|---|---|---|
| ![Pentest VLAN Lab Manager bringing the opnsense VM up under the libvirt provider](./assets/demos/opnsense-01-lab-manager-start.gif) | ![OPNsense reloading after configuration and coming back with Machine booted and ready](./assets/demos/opnsense-02-reload-success.gif) | ![OPNsense console showing the complete WAN, LAN, and VLAN interface assignments](./assets/demos/opnsense-03-vlan-topology.gif) |

Full unedited recordings are available for the [Active Directory lab](./assets/demos/dc01.webm), [DevOps lab](./assets/demos/devops1.webm), and [segmented Active Directory lab](./assets/demos/opnsense-vlan.webm).

---

## Lab environments

| Lab | Purpose | Location |
|---|---|---|
| Active Directory Security Lab | Windows enterprise infrastructure, Active Directory security research, identity attack-path simulation, and detection concepts | [labs/security/active-directory/base/](./labs/security/active-directory/base/) |
| Segmented Active Directory Lab | Segmentation-aware Active Directory research, routing controls, trust boundaries, and lateral-movement constraints | [labs/security/active-directory/vlan-segmented/](./labs/security/active-directory/vlan-segmented/) |
| DevOps/DevSecOps Lab | Linux administration, Kubernetes, GitOps, observability, runtime security, and policy enforcement | [labs/infrastructure/devops-linux-lab/](./labs/infrastructure/devops-linux-lab/) |
| DevSecOps Lite — Apple Silicon / ARM64 (planned) | ARM64-native Linux platform engineering, Kubernetes, GitOps, observability, runtime security, and policy enforcement without Windows or Active Directory dependencies | [labs/infrastructure/devsecops-lite-arm64/](./labs/infrastructure/devsecops-lite-arm64/) |
| Windows Server Hardening Lab (experimental) | CIS-benchmark-inspired defensive hardening, mapped one-to-one against the AD base lab's attack techniques | [labs/security/windows-hardening/](./labs/security/windows-hardening/) |

### Active Directory Security Lab

The base Active Directory lab provides Windows enterprise-style infrastructure for authorized identity security research and defensive validation.

It covers Active Directory Domain Services, Kerberos, LDAP, Active Directory Certificate Services, credential-access simulation, privilege-escalation research, post-compromise workflows, and detection-engineering concepts.

See the [lab README](./labs/security/active-directory/base/) for provider-specific instructions, resource profiles, validation procedures, and authorized security-testing guidance.

### Segmented Active Directory Lab

The segmented Active Directory lab extends the base Active Directory environment with controlled routing, separated trust boundaries, and segmentation-aware security testing.

It supports research into lateral-movement constraints, network-security concepts, detection and response across boundaries, and controlled routing between lab segments.

See the [lab README](./labs/security/active-directory/vlan-segmented/) and [segmented lab troubleshooting guide](./labs/security/active-directory/vlan-segmented/docs/troubleshooting.md) for deployment and troubleshooting information.

### DevOps/DevSecOps platform lab

The DevOps/DevSecOps platform lab focuses on Linux platform engineering, Kubernetes operations, GitOps, observability, runtime security, policy enforcement, container-security testing, and integrated CI/CD validation.

See the [lab README](./labs/infrastructure/devops-linux-lab/) for provider-specific deployment requirements, resource profiles, and validation guidance.

### DevSecOps Lite — Apple Silicon / ARM64 (planned)

The planned DevSecOps Lite profile is a deliberately scoped ARM64-native platform-engineering environment for Apple Silicon Macs and other compatible ARM64 hosts.

It is intended to provide a lower-resource route into Kubernetes, GitOps, observability, runtime security, policy enforcement, container security, and Linux administration. It will not be a functional replacement for the Active Directory, Windows Hardening, or segmented-network labs.

The profile is expected to include validated subsets of:

- K3s
- GitOps workflows
- Prometheus, Grafana, and Loki
- Falco runtime-security monitoring
- Kyverno policy enforcement
- Linux administration and container-security exercises

The final scope depends on validation of ARM64 Vagrant boxes or an alternative supported runtime, multi-architecture container images, Helm charts, registry workflows, network behavior, host integration, provisioning automation, and test coverage.

### Windows Server Hardening Lab (experimental)

A defensive counterpart to the Active Directory base lab: the same base box and AD-promotion pattern, but with a hardening baseline applied instead of intentional misconfigurations. Each control is documented against the specific attack technique it mitigates, using the base lab's own attack guide as the reference point.

This lab is experimental (`v0.1.0` MVP) and has not received the same level of real-world testing as the other labs. Complete the AD base lab first, then use this environment to study and validate the defensive side.

See the [lab README](./labs/security/windows-hardening/) and its [hardening guide](./labs/security/windows-hardening/docs/hardening-guide.md) for the full control list, known limitations, and baseline-validation procedures.

---

## Provider compatibility

Each full lab uses a provider-aware `Vagrantfile` supporting KVM/QEMU with libvirt and VirtualBox, subject to provider-specific requirements.

| Provider | Best for | Start command |
|---|---|---|
| **KVM/QEMU with libvirt** | Linux hosts with hardware virtualization and nested-virtualization support | `vagrant up --provider=libvirt` |
| **VirtualBox** | Compatible Intel/AMD x86_64 hosts running Linux, macOS, or Windows | `vagrant up --provider=virtualbox` |
| **Apple Silicon ARM64 Lite profile (planned)** | macOS users running validated ARM64-native Linux and Kubernetes workflows | Provider and deployment commands will be documented with the released Lite profile |

KVM/QEMU with libvirt is the primary development provider and generally offers the strongest performance for CPU-, memory-, storage-, and network-intensive environments.

> [!NOTE]
> “Supported” means the provider workflow is maintained and validated for the documented lab scope. It does not guarantee identical behavior across every host kernel, provider release, Vagrant plugin version, third-party Vagrant box revision, or hardware configuration.

### Compatibility matrix

| Component | KVM/QEMU with libvirt | VirtualBox |
|---|---|---|
| DevOps Linux lab | Supported with `--provider=libvirt` | Supported with `--provider=virtualbox` on compatible x86_64 hosts; Apple Silicon requires the separate planned Lite profile |
| DevSecOps Lite profile (planned) | N/A as a macOS-host deployment path | Experimental ARM64-native profile planned; limited to explicitly validated Linux and Kubernetes components |
| Active Directory base lab | Supported with `--provider=libvirt` | Supported with `--provider=virtualbox` on compatible x86_64 hosts |
| Segmented Active Directory lab | Supported with `--provider=libvirt` | Supported with `--provider=virtualbox` on compatible x86_64 hosts |
| Windows Server Hardening lab (experimental) | Supported with `--provider=libvirt` | Supported with `--provider=virtualbox` on compatible x86_64 hosts |
| Networking | Libvirt networks with automatic detection and fallback configuration | Host-only networking and VirtualBox internal networks |
| Network segmentation | Separate libvirt networks per segment | Isolated internal networks that model segmentation boundaries |
| Disk storage | qcow2 with libvirt storage configuration | VDI attached through a SATA controller |
| Nested virtualization | `host-passthrough` CPU configuration where required | Explicit nested hardware-virtualization configuration where supported |
| Graphics | VNC through virtio video, loopback-oriented | VMSVGA or VBoxSVGA with optional GUI support through `LAB_GUI=true` |
| Linked clones | Backing-file images are commonly used | VirtualBox linked clones are supported |
| Guest additions | Not required for libvirt workflows | `vagrant-vbguest` is optional |
| Recommended use | Primary development and performance-sensitive deployments | Cross-platform compatibility on supported x86_64 hosts |

The segmented lab uses separate libvirt networks and isolated VirtualBox internal networks to model segmentation boundaries. VirtualBox networking provides logical isolation but does not reproduce physical IEEE 802.1Q VLAN tagging.

### Apple Silicon status

Apple Silicon Macs use the ARM64 architecture. The full repository is not currently supported or validated on Apple Silicon because several lab environments depend on x86_64 Windows guests, x86_64 Vagrant boxes, guest media, and provider-specific networking and provisioning behavior.

The following labs remain unavailable on Apple Silicon:

- Active Directory Security Lab
- Segmented Active Directory Lab
- Windows Server Hardening Lab
- Any workflow requiring x86_64-only Vagrant boxes, Windows guest media, or nested-virtualization assumptions validated only on Intel/AMD hosts

A separate **DevSecOps Lite** profile is planned for Apple Silicon and other ARM64-capable hosts. Its intended scope is ARM64-native Linux and Kubernetes learning, including validated subsets of:

- K3s
- GitOps workflows
- Prometheus, Grafana, and Loki
- Falco runtime-security monitoring
- Kyverno policy enforcement
- Linux administration and container-security exercises

K3s supports ARM64, and Falco supports ARM64. However, every container image, Helm chart, registry workflow, host integration, runtime-security integration, and provisioning dependency must be validated as multi-architecture compatible before inclusion in the Lite profile.

Until the Lite profile is released with documented prerequisites, tested deployment procedures, provider guidance, and troubleshooting documentation, Apple Silicon remains unsupported for this repository.

See the [Installation Guide](./docs/setup/installation.md) for provider-specific setup instructions.

---

## Prerequisites

### Host requirements

- **Linux host:** Required for KVM/QEMU with libvirt full-lab workflows
- **Linux, macOS, or Windows host:** Supported with VirtualBox on compatible Intel/AMD x86_64 hardware
- **Apple Silicon host:** Not currently supported for published lab workflows; the planned ARM64 DevSecOps Lite profile will document its own validated prerequisites
- **CPU architecture:** Existing Windows Server and most current Vagrant box workflows require Intel/AMD x86_64 compatibility
- **Hardware virtualization:** Intel VT-x or AMD-V enabled in BIOS/UEFI where applicable
- **Vagrant:** A currently supported Vagrant release compatible with the selected provider
- **Virtualization provider:** KVM/QEMU with libvirt, or a supported VirtualBox release
- **Python:** Python 3.12+ for contributor tooling and lab-management utilities
- **Network:** Internet access for initial box, package, and container-image retrieval unless using prepared local or internal mirrors

### Recommended resources

Resource requirements vary by lab, selected provider, deployment profile, box-cache state, snapshot usage, and container-image storage. Use the estimates in [Which lab should I start with?](#which-lab-should-i-start-with) as a planning baseline, then review the selected lab README before deployment.

For constrained systems, see [Minimal Resource Deployment](./docs/guides/optimization/minimal-resource-deployment.md).

### Vagrant plugins

Install only the plugins required by your selected provider and lab. Run the full prerequisite check first:

```bash
./scripts/check-prerequisites.sh --all
```

This validates host dependencies and enables lab-specific plugin checks.

**Common Windows guest workflows**

```bash
vagrant plugin install vagrant-reload
vagrant plugin install vagrant-winrm
vagrant plugin install vagrant-hostmanager
```

**KVM/QEMU with libvirt**

```bash
vagrant plugin install vagrant-libvirt
```

**Optional VirtualBox convenience plugin**

```bash
vagrant plugin install vagrant-vbguest
```

---

## Architecture overview

[![Enterprise Infrastructure Architecture](./assets/diagrams/architecture-overview.png)](./assets/diagrams/)

The lab environments deploy independently through provider-aware Vagrant configurations. The architecture combines isolated Active Directory environments, segmented virtual networks, Kubernetes workloads, security monitoring, policy enforcement, and validation workflows.

The planned ARM64 DevSecOps Lite profile will remain a separately scoped architecture. It will focus on ARM64-native Linux and Kubernetes components and will not include Windows guests, Active Directory services, or the existing segmented-network topology.

The labs demonstrate:

- Isolated security research environments
- Enterprise-style Active Directory infrastructure
- Segmented network boundaries and controlled routing
- Kubernetes and containerized workloads
- Runtime-security monitoring
- Defensive hardening validation mapped to specific offensive techniques
- Reproducible infrastructure deployment
- Automated validation and documentation workflows

See the following documents for architecture details, trust boundaries, and design decisions:

- [Architecture Overview](./docs/architecture/architecture.md)
- [Security Scope](./docs/security-scope.md)
- [Threat Model](./docs/architecture/threat-model.md)
- [Emergency Isolation Runbook](./docs/architecture/emergency-isolation-runbook.md)

---

## What this project demonstrates

| Domain | Capabilities | Location |
|---|---|---|
| Active Directory security | Domain deployment, AD CS, identity attack-path simulation, privilege-escalation research, and post-compromise workflows | `labs/security/active-directory/base/` |
| Network segmentation | Logical segmentation boundaries, routing separation, trust relationships, and segmentation-aware security-testing scenarios | `labs/security/active-directory/vlan-segmented/` |
| DevOps/DevSecOps | Kubernetes operations, GitOps, observability, runtime security, and policy enforcement | `labs/infrastructure/devops-linux-lab/` |
| ARM64 DevSecOps Lite (planned) | ARM64-native Kubernetes, GitOps, observability, runtime security, policy enforcement, and container-security workflows | `labs/infrastructure/devsecops-lite-arm64/` |
| Defensive hardening (experimental) | CIS-benchmark-inspired hardening controls mapped to specific AD attack techniques, with validation tooling for each control | `labs/security/windows-hardening/` |
| Infrastructure as Code | Vagrant, Ansible, Bash, Python, and automation workflows | Repository-wide |
| Security documentation | Architecture, threat models, setup guides, troubleshooting, and learning paths | `docs/` |
| Validation and quality engineering | Python tests, Bash tests, linting, documentation checks, and CI workflows | `.github/`, `tests/`, and `scripts/` |

### Skills and technologies

| Area | Technologies and concepts |
|---|---|
| Linux administration | Ubuntu, Rocky Linux, AlmaLinux, openSUSE |
| Virtualization | KVM, QEMU, libvirt, VirtualBox, Vagrant |
| Infrastructure as Code | Vagrant, Ansible |
| DevOps | Git, GitHub Actions, CI/CD workflows |
| Kubernetes | K3s and Kubernetes administration |
| GitOps | Argo CD |
| Monitoring | Prometheus, Grafana, Loki |
| Runtime security | Falco |
| Policy security | Kyverno |
| Containers | Docker, Harbor |
| Active Directory | Windows Server, Kerberos, LDAP |
| AD CS | Certificate Services and escalation scenarios |
| Detection engineering | MITRE ATT&CK concepts and log analysis |
| Security testing | Nmap, BloodHound, Metasploit, and Hashcat |

---

## Common workflows

Run these commands from the selected lab directory.

> [!WARNING]
> `vagrant destroy -f` permanently removes the selected lab's VMs and can remove provider-managed disks. Vagrant snapshots are provider-dependent and are not a substitute for exporting artifacts or maintaining external backups of work you need to retain.

### Rebuild a single VM

```bash
vagrant destroy dc01 -f
vagrant up dc01
```

### Save and restore snapshots

Create a snapshot before a risky laboratory exercise:

```bash
vagrant snapshot save dc01 clean-install
```

Restore the snapshot:

```bash
vagrant snapshot restore dc01 clean-install
```

### Re-run provisioning

```bash
vagrant provision
```

### Destroy a complete lab

```bash
vagrant destroy -f
```

### Switch providers

Provider switching generally requires destroying and recreating the environment:

```bash
vagrant destroy -f
vagrant up --provider=libvirt
```

Or:

```bash
vagrant destroy -f
vagrant up --provider=virtualbox
```

For complete deployment and lab-management guidance, see:

- [Quickstart Examples](./docs/setup/quickstart-examples.md)
- [Vagrant Management Tutorial](./docs/guides/infrastructure/vagrant-management-tutorial.md)
- [Guides](./docs/guides/)
- Each lab's `docs/attack-guide.md`

---

## Troubleshooting

### `vagrant up` hangs or times out

Confirm the following:

- Hardware virtualization is enabled in BIOS/UEFI where applicable
- The selected virtualization provider is installed and available
- The prerequisites check completes successfully
- The host has sufficient CPU, RAM, and storage
- The selected lab profile is appropriate for available resources
- The selected Vagrant box is compatible with the host architecture

Run:

```bash
./scripts/check-prerequisites.sh --all
```

### Wrong provider selected

A VM created with one provider cannot normally be reused with another provider. Destroy the current environment and recreate it with the intended provider:

```bash
vagrant destroy -f
vagrant up --provider=libvirt
```

### WinRM or SSH connection failures

Windows guests may require additional time for boot, networking, service initialization, and reboot cycles.

Try:

```bash
vagrant up
```

Then re-run provisioning if necessary:

```bash
vagrant provision
```

Also verify that the expected guest interface, provider-assigned address, and architecture-compatible Vagrant box are available.

### Network or segmentation conflicts

Check for stale resources after an interrupted deployment:

- Libvirt bridges and networks
- VirtualBox host-only adapters
- VirtualBox internal-network definitions
- Previously allocated IP ranges
- Conflicting `NETWORK_BASE` settings

A clean redeployment may be required:

```bash
vagrant destroy -f
vagrant up
```

### Apple Silicon and ARM64 incompatibility

Do not attempt to deploy the existing Windows, Active Directory, Windows Hardening, segmented-network, or x86_64-only Vagrant workflows on Apple Silicon.

Until the planned ARM64 DevSecOps Lite profile is published and validated, Apple Silicon does not have a supported deployment path in this repository. Check the selected lab README and the [Installation Guide](./docs/setup/installation.md) before deploying.

See the [Troubleshooting Guide](./docs/setup/troubleshooting.md) and [segmented lab troubleshooting guide](./labs/security/active-directory/vlan-segmented/docs/troubleshooting.md) for detailed guidance.

---

## Documentation hub

| Document | Purpose |
|---|---|
| [Documentation Index](./docs/README.md) | Documentation map grouped by topic |
| [Learning Path](./docs/project/learning-path.md) | Recommended progression through the labs |
| [Architecture](./docs/architecture/architecture.md) | Infrastructure design and deployment architecture |
| [Security Scope](./docs/security-scope.md) | Security boundaries and intended use |
| [Threat Model](./docs/architecture/threat-model.md) | Threat-model documentation |
| [Emergency Isolation Runbook](./docs/architecture/emergency-isolation-runbook.md) | Emergency isolation procedures |
| [Roadmap](./docs/project/roadmap.md) | Planned improvements and future development |
| [Portfolio](./docs/project/portfolio.md) | Skills and competencies demonstrated |
| [Dependencies](./docs/dependencies.md) | Project dependencies and requirements |
| [Installation Guide](./docs/setup/installation.md) | Host and provider setup |
| [Quickstart Examples](./docs/setup/quickstart-examples.md) | Rapid deployment patterns |
| [Troubleshooting](./docs/setup/troubleshooting.md) | Common problems and solutions |
| [Lab Reset and Cleanup](./docs/guides/workflows/lab-reset-and-cleanup.md) | Snapshot revert, VM rebuild, full teardown, and host network cleanup |
| [Minimal Resource Deployment](./docs/guides/optimization/minimal-resource-deployment.md) | Reduced-resource deployment guidance |
| [Guides](./docs/guides/) | Security, infrastructure, and deployment guides |
| [Scripts](./scripts/) | Host-readiness and validation helpers |

---

## Repository structure

```text
security-engineering-lab/
├── .github/                # CI workflows, issue templates, and repository automation
├── assets/                 # Architecture diagrams and deployment demonstrations
├── docs/                   # Architecture, setup, security, project, and guide documentation
├── examples/               # Example configurations and reference material
├── labs/
│   ├── infrastructure/
│   │   ├── devops-linux-lab/
│   │   └── devsecops-lite-arm64/    # Planned Apple Silicon / ARM64 profile
│   └── security/
│       ├── active-directory/
│       │   ├── base/
│       │   └── vlan-segmented/
│       └── windows-hardening/       # Experimental, v0.1.0 MVP
├── scripts/                # Host-readiness, validation, and automation helpers
├── tests/                  # pytest, Bats, and repository validation tests
├── tools/                  # Standalone lab and security utilities
├── CHANGELOG.md
├── CONTRIBUTING.md
├── LICENSE
├── Makefile
├── README.md
├── SECURITY.md
└── pyproject.toml
```

The `devsecops-lite-arm64/` directory is a planned structure and should be added only when the Lite profile is implemented. Until then, remove that directory from this tree if you prefer the repository structure to list only tracked paths.

See the [Documentation Index](./docs/README.md) for the complete documentation map and each lab directory for provider-specific deployment instructions.

---

## Development quickstart

Install development dependencies:

```bash
python3 -m pip install -r requirements-dev.txt
```

Install pre-commit hooks:

```bash
pre-commit install
```

Common Make targets:

```bash
make lint       # ShellCheck and Python linting
make test       # pytest and Bats unit tests
make validate   # Validate lab Vagrantfiles
make security   # Bandit and detect-secrets checks
make docs-refs  # Check for dangling documentation references
```

Additional targets may include:

```bash
make format
make typecheck
make coverage
make validate-repo
make docs
make prereq
```

List all available targets:

```bash
make help
```

See [CONTRIBUTING.md](./CONTRIBUTING.md), the [Tests README](./tests/README.md), the [Scripts README](./scripts/README.md), and [Dependencies](./docs/dependencies.md) for development details.

> [!NOTE]
> Contributor tooling may have host-specific requirements. Review the relevant setup documentation when running shell, virtualization, or Linux-oriented validation workflows from macOS or Windows.

---

## Project maturity

The repository is actively developed. Core lab workflows are maintained through automated repository checks and documented validation procedures; individual provider, box, guest, dependency, and hardware combinations may still require host-specific troubleshooting.

The planned ARM64 DevSecOps Lite profile is a roadmap item, not a supported deployment target. It will require independently documented architecture decisions, component compatibility validation, automated tests, deployment procedures, and troubleshooting guidance before being labeled experimental or supported.

Review each lab README for its current validation status, supported profiles, provider requirements, and known limitations.

---

## Contributing

Contributions are welcome.

Before submitting a contribution:

- Open an issue before making major changes
- Keep pull requests focused
- Update documentation when required
- Add or update tests for behavioral changes
- Run relevant lint, test, validation, and documentation checks
- Do not include credentials, secrets, private keys, or sensitive host information
- Follow the repository contribution guidelines

For Apple Silicon or ARM64 work, include architecture compatibility evidence, image and chart validation results, provider documentation, automated tests where practical, and a clear statement of which features remain unsupported.

See [CONTRIBUTING.md](./CONTRIBUTING.md) for the complete contributor workflow.

---

## Security and ethics

This project is intended only for:

- Education
- Authorized security research
- Defensive security practice
- Isolated laboratory environments
- Testing systems owned by the operator or explicitly authorized for testing

Only test systems that you own or have explicit permission to assess.

Unauthorized access, testing, scanning, exploitation, credential attacks, or lateral movement against external systems is prohibited.

Intentionally vulnerable workloads and authorized security-test scenarios must remain isolated from production networks and systems.

For additional security information, see:

- [Security Scope](./docs/security-scope.md)
- [Threat Model](./docs/architecture/threat-model.md)
- [SECURITY.md](./SECURITY.md)

---

## Known limitations

- Full-profile deployments require substantial CPU, RAM, and storage.
- Full deployments generally target 32 GB or more RAM and approximately 200 GB free disk space.
- KVM/QEMU with libvirt requires a compatible Linux host.
- VirtualBox support currently targets compatible Intel/AMD x86_64 hosts.
- Apple Silicon is not supported for the Windows, Active Directory, segmented-network, or Windows Hardening labs because those workflows depend on x86_64 guests and provider-specific validation.
- A limited ARM64-native DevSecOps Lite profile is planned for Apple Silicon and other ARM64-capable hosts. It will support only explicitly validated Linux, Kubernetes, container-image, observability, runtime-security, and policy components.
- ARM64 support requires per-component validation of Vagrant boxes or alternative runtime images, container manifests, Helm charts, kernel and runtime integrations, networking behavior, deployment automation, and test coverage.
- Windows-based labs use Microsoft evaluation media; users are responsible for complying with applicable Microsoft licensing terms.
- The Windows Server Hardening lab is an experimental `v0.1.0` MVP with less real-world testing than the other labs. It does not yet cover AD CS hardening, LAPS, Credential Guard, or automated Sysmon deployment. See that lab's `docs/hardening-guide.md` for the complete list of known gaps.
- Third-party Vagrant boxes may change independently.
- CI validates repository quality and selected provider workflows but does not fully deploy every environment on every push.
- The project is designed primarily for a single-host laboratory