# Security Engineering Lab


[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
![Platform](https://img.shields.io/badge/platform-Linux%7CmacOS%7CWindows-blue)
![Vagrant](https://img.shields.io/badge/Vagrant-Lab-orange)
![Security](https://img.shields.io/badge/Security-Research-red)
![DevSecOps](https://img.shields.io/badge/DevSecOps-Lab-purple)
[![CI](https://github.com/solo2121/security-engineering-lab/actions/workflows/ci.yml/badge.svg)](https://github.com/solo2121/security-engineering-lab/actions/workflows/ci.yml)


**Security Engineering Lab is a modular, Vagrant-provisioned security and infrastructure engineering lab repository for practicing Active Directory security, network segmentation, Kubernetes, DevSecOps workflows, Linux administration, and infrastructure automation.**


This repository is designed to be **runnable, not static**. The environments, automation, documentation, and workflows are implemented as deployable lab systems using Vagrant and KVM/QEMU with libvirt. Every lab's `Vagrantfile` also supports VirtualBox for hosts without KVM/libvirt (see [Supported providers](#supported-providers)).


**Maintained by:** Miguel A. Carlo (solo2121)  
**Project status:** Active development


---


Start here: [Learning Path](./docs/project/learning-path.md) provides the recommended path through the labs, from Active Directory security fundamentals to segmented environments and DevSecOps workflows.


## Table of contents

- [Supported providers](#supported-providers)
- [Prerequisites](#prerequisites)
- [Quick start](#quick-start)
- [What this project demonstrates](#what-this-project-demonstrates)
- [Architecture overview](#architecture-overview)
- [Lab environments](#lab-environments)
- [Project overview](#project-overview)
- [Highlights](#highlights)
- [Portfolio and learning goals](#portfolio-and-learning-goals)
- [Repository structure](#repository-structure)
- [Common workflows](#common-workflows)
- [Troubleshooting](#troubleshooting)
- [Skills demonstrated](#skills-demonstrated)
- [Documentation hub](#documentation-hub)
- [Security and ethics](#security-and-ethics)
- [Known limitations](#known-limitations)
- [Development quickstart](#development-quickstart)
- [Contributing](#contributing)
- [License](#license)


## Supported providers


Every lab supports both KVM/libvirt and VirtualBox from a single, unified
`Vagrantfile` per lab — select a provider via `--provider` or
`VAGRANT_DEFAULT_PROVIDER`.


| Provider | Best for | Vagrantfile location |
|---|---|---|
| **KVM/libvirt** (default) | Linux hosts with nested virtualization; best performance and the environment each lab is developed against | `<lab-path>/Vagrantfile` |
| **VirtualBox** | Cross-platform hosts (Windows, macOS, Linux) without KVM/libvirt, or hosts where libvirt isn't available | `<lab-path>/Vagrantfile` (pass `--provider=virtualbox`) |


Before your first `vagrant up`, run the host-readiness check — it validates
hardware virtualization, KVM/libvirt or VirtualBox, required Vagrant plugins,
and available disk/RAM, and prints an actionable fix for anything that fails:


```bash
./scripts/check-prerequisites.sh
# or: make prereq
```


Run any lab with an explicit provider from the lab's directory:


```bash
vagrant up --provider=libvirt
vagrant up --provider=virtualbox
```


You can also set a default provider for your shell session instead of passing `--provider` each time:


```bash
export VAGRANT_DEFAULT_PROVIDER=virtualbox
```


See [Installation Guide](./docs/setup/installation.md) for full per-provider prerequisites and setup steps, and [Known limitations](#known-limitations) below for provider differences (networking, performance, and nested virtualization).


## Prerequisites

- **Host OS:** Linux (for KVM/libvirt, the default provider) — or macOS, Windows, or Linux without libvirt (for VirtualBox). See [Supported providers](#supported-providers).
- **Virtualization:** [Vagrant](https://developer.hashicorp.com/vagrant/docs) >= 2.2, plus either [vagrant-libvirt](https://github.com/vagrant-libvirt/vagrant-libvirt) (KVM/QEMU) or [VirtualBox](https://www.virtualbox.org/) 7.0+ (built into Vagrant, no plugin needed). Hardware virtualization (Intel VT-x / AMD-V) enabled in the host BIOS/UEFI.
- **Vagrant plugins:** `vagrant-reload`, `vagrant-winrm` (all labs); `vagrant-libvirt`, `vagrant-hostmanager` (libvirt); `vagrant-vbguest` (VirtualBox, optional).
- **Resources:** 16 GB RAM minimum (32 GB+ recommended for full-profile deployments), 100–200 GB free disk depending on the lab and profile.
- **Python:** 3.10+ with `pip`, for the contributor tooling in [Development quickstart](#development-quickstart) and each lab's `vagrant_manager.py`.

Run `./scripts/check-prerequisites.sh` (or `make prereq`) to validate all of the above automatically before your first `vagrant up` — see [Quick start](#quick-start).


## Quick start

```bash
git clone https://github.com/solo2121/security-engineering-lab.git
cd security-engineering-lab

# Validate your host meets the prerequisites above
./scripts/check-prerequisites.sh

# Pick a lab and bring it up (KVM/libvirt is the default provider)
cd labs/security/active-directory/base
vagrant up
vagrant status

# Or explicitly choose a provider
vagrant up --provider=virtualbox
```

> **Note:** Each lab also ships a `vagrant_manager.py` (Python, `rich`-based)
> for interactive or scripted VM management — start/stop individual VMs,
> switch `LAB_PROFILE`, and select `--provider` without hand-typing raw
> `vagrant` commands. See [Common workflows](#common-workflows) below and
> each lab's own README.

See [Installation Guide](./docs/setup/installation.md) for the full walkthrough per lab, and [Quickstart Examples](./docs/setup/quickstart-examples.md) for more deployment patterns.


## What this project demonstrates


| Domain | Capabilities | Location |
|---|---|---|
| Active Directory Security | Domain deployment, AD CS, credential attack paths, privilege escalation research, and post-exploitation workflows | `labs/security/active-directory/base/` |
| Network Segmentation | VLAN design, routing boundaries, trust separation, and segmentation-aware attack paths | `labs/security/active-directory/vlan-segmented/` |
| DevOps / DevSecOps | Kubernetes operations, GitOps, observability, runtime security, and policy enforcement | `labs/infrastructure/devops-linux-lab/` |
| Infrastructure as Code | Vagrant, Ansible, and automation workflows | Repository-wide |
| Security Documentation | Architecture, threat models, setup guides, troubleshooting, and learning paths | `docs/` |


---


## Architecture overview


[![Enterprise Infrastructure Architecture](assets/diagrams/architecture-overview.png)](./assets/diagrams/)


Lab environments are deployed independently using their own Vagrant configurations. KVM/QEMU with libvirt is the default provider; each lab's `Vagrantfile` also supports VirtualBox for hosts without libvirt (`--provider=virtualbox`) — see [Supported providers](#supported-providers).


See:


- [Architecture Overview](./docs/architecture/architecture.md)
- [Security Scope](./docs/security-scope.md)


for architecture details, trust boundaries, and design decisions.


---


## Lab environments


### Lab 1 — Active Directory Pentest Lab


**Path:** [labs/security/active-directory/base/](./labs/security/active-directory/base/)


Focus areas:


- Windows enterprise-style infrastructure.
- Active Directory security.
- Kerberos authentication.
- AD Certificate Services (AD CS).
- Privilege escalation research.
- Post-exploitation workflows.
- Detection engineering concepts.


**VirtualBox support:** this lab now ships a single unified `Vagrantfile` supporting both KVM/QEMU (libvirt) and VirtualBox — select a provider with `vagrant up --provider=libvirt` or `vagrant up --provider=virtualbox`. See the lab README for provider-specific instructions.


---


### Lab 2 — Active Directory Pentest Lab (VLAN Edition)


**Path:** [labs/security/active-directory/vlan-segmented/](./labs/security/active-directory/vlan-segmented/)


Focus areas:


- Active Directory with network segmentation.
- VLAN boundaries.
- Controlled routing.
- Lateral movement constraints.
- Enterprise network security concepts.


This environment demonstrates how segmentation influences attack paths, trust boundaries, and adversary movement.


**VirtualBox support:** this lab now ships a single unified `Vagrantfile` supporting both KVM/QEMU (libvirt) and VirtualBox — select a provider with `vagrant up --provider=libvirt` or `vagrant up --provider=virtualbox`. See the lab README for provider-specific instructions.


---


### Lab 3 — DevOps / DevSecOps Lab


**Path:** [labs/infrastructure/devops-linux-lab/](./labs/infrastructure/devops-linux-lab/)


Focus areas:


- Kubernetes operations.
- GitOps workflows.
- Infrastructure automation.
- Observability.
- Runtime security.
- Policy enforcement.
- Platform engineering workflows.
- Integrated CI/CD and security validation workflows.


**VirtualBox support:** This lab uses a single unified Vagrantfile supporting both KVM/libvirt and VirtualBox — select the provider with `vagrant up --provider=virtualbox` (or `--provider=libvirt`). See the lab README for provider-specific instructions.


---


## Project overview


Security Engineering Lab demonstrates the integration of:


- Offensive security research.
- Linux system administration.
- Infrastructure automation.
- Cloud-native technologies.
- DevOps and DevSecOps practices.
- Security validation workflows.


The goal is to provide a realistic but isolated environment for learning how modern infrastructure is deployed, attacked, secured, and monitored.


---


## Highlights


- **Active Directory security research**
  - Kerberoasting.
  - AS-REP roasting.
  - AD CS abuse scenarios.
  - NTLM relay concepts.
  - DCSync.
  - Kerberos ticket attacks.


- **Segmented security lab environments**
  - VLAN-based architectures.
  - Routing boundaries.
  - Controlled trust relationships.
  - Segmentation-aware testing.


- **DevSecOps platform engineering**
  - Kubernetes.
  - GitOps.
  - Observability.
  - Runtime security.
  - Policy enforcement.


- **Infrastructure automation**
  - Reproducible deployments.
  - Vagrant-based provisioning.
  - Ansible automation.
  - CI validation.


- **Security engineering documentation**
  - Architecture documentation.
  - Threat modeling.
  - Deployment guides.
  - Troubleshooting workflows.


---


## Portfolio and learning goals


This repository demonstrates practical hands-on experience with:


- Linux administration.
- Active Directory environments.
- Infrastructure automation.
- KVM/libvirt and VirtualBox virtualization.
- Kubernetes administration.
- GitOps workflows.
- Infrastructure as Code.
- DevSecOps engineering.
- Detection engineering concepts.
- Security testing methodologies.


---


## Repository structure


```text
security-engineering-lab/
├── .github/
│   ├── ISSUE_TEMPLATE/
│   ├── workflows/
│   ├── CODEOWNERS
│   └── dependabot.yml
├── assets/
│   ├── diagrams/
│   │   └── architecture-overview.png
│   └── README.md
├── docs/
│   ├── architecture/
│   │   ├── architecture.md
│   │   ├── emergency-isolation-runbook.md
│   │   └── threat-model.md
│   ├── guides/
│   │   ├── infrastructure/
│   │   ├── optimization/
│   │   ├── security/
│   │   └── workflows/
│   ├── project/
│   │   ├── learning-path.md
│   │   ├── portfolio.md
│   │   └── roadmap.md
│   ├── dependencies.md
│   ├── README.md
│   ├── security-scope.md
│   └── setup/
│       ├── installation.md
│       ├── quickstart-examples.md
│       ├── README.md
│       └── troubleshooting.md
├── examples/
│   └── README.md
├── labs/
│   ├── infrastructure/
│   │   └── devops-linux-lab/
│   ├── README.md
│   └── security/
│       ├── active-directory/
│       │   ├── base/
│       │   ├── vlan-segmented/
│       ├── README.md
│       └── requirements.txt
├── scripts/
│   ├── check_doc_references.py
│   ├── check-prerequisites.sh
│   ├── README.md
│   └── validate_lab.py
├── tests/
│   ├── bash/
│   │   ├── test_log_analyzer.bats
│   │   └── test_setup_vlans.bats
│   ├── python/
│   │   ├── test_check_doc_references.py
│   │   ├── test_lib_banner_and_logging.py
│   │   ├── test_lib_cli.py
│   │   ├── test_lib_subprocess.py
│   │   ├── test_lib_validators.py
│   │   ├── test_port_scanner.py
│   │   └── test_validate_lab.py
│   └── README.md
├── tools/
│   ├── __init__.py
│   ├── lib/
│   │   ├── banner.py
│   │   ├── cli.py
│   │   ├── __init__.py
│   │   ├── logging.py
│   │   ├── README.md
│   │   ├── subprocess.py
│   │   └── validators.py
│   ├── README.md
│   ├── security/
│   │   ├── audit/
│   │   ├── exploitation/
│   │   ├── network/
│   │   ├── README.md
│   │   ├── reconnaissance/
│   │   └── wireless/
│   └── sysadmin/
│       ├── monitoring/
│       ├── README.md
│       ├── system-hardening/
│       └── utilities/
├── CHANGELOG.md
├── CODE_OF_CONDUCT.md
├── CONTRIBUTING.md
├── LICENSE
├── Makefile
├── pyproject.toml
├── README.md
├── requirements-dev.txt
└── SECURITY.md
```


---


## Common workflows

```bash
# Rebuild a single VM from scratch
vagrant destroy dc01 -f && vagrant up dc01

# Snapshot before a risky attack step, and roll back after
vagrant snapshot save dc01 clean-install
vagrant snapshot restore dc01 clean-install

# Re-run provisioning without recreating VMs
vagrant provision

# Interactive VM management (start/stop individual VMs, switch
# LAB_PROFILE, select --provider) instead of raw vagrant commands
python3 scripts/vagrant_manager.py
python3 scripts/vagrant_manager.py up kali dc01
python3 scripts/vagrant_manager.py up --provider virtualbox

# Tear the lab down completely
vagrant destroy -f
```

For full attack-simulation walkthroughs (domain compromise, AD CS
abuse, password attacks, LLM/OWASP scenarios, cloud-pentest scenarios),
see [Guides](./docs/guides/) and each lab's `docs/attack-guide.md`. For
more snapshot/rebuild patterns per provider, see [Vagrant Management
Tutorial](./docs/guides/infrastructure/vagrant-management-tutorial.md)
and [Quickstart Examples](./docs/setup/quickstart-examples.md).


## Troubleshooting

Common first steps for a stuck lab:

- **`vagrant up` hangs or times out:** confirm hardware virtualization
  is enabled in your BIOS/UEFI and that `./scripts/check-prerequisites.sh`
  passes. See [Prerequisites](#prerequisites).
- **Wrong provider, or a mid-deployment provider switch:** `vagrant
  destroy -f` and re-run `vagrant up --provider=<libvirt|virtualbox>`
  explicitly — a VM created under one provider can't be reused under
  the other.
- **WinRM/SSH connection failures on Windows VMs:** usually a slow boot,
  not a real failure; re-run `vagrant up` (or `vagrant provision`) once
  the VM finishes booting.
- **Network/VLAN conflicts:** check for a stale `br-*` (libvirt) or
  internal-network (VirtualBox) definition left over from a prior
  `vagrant destroy` that didn't clean up networking.

Full common-issues reference with exact error messages and fixes:
[Troubleshooting Guide](./docs/setup/troubleshooting.md). Lab-specific
troubleshooting: [vlan-segmented](./labs/security/active-directory/vlan-segmented/docs/troubleshooting.md).


---


## Skills demonstrated


| Area | Technologies |
|---|---|
| Linux Administration | Ubuntu, Rocky Linux, AlmaLinux, openSUSE |
| Virtualization | KVM, QEMU, libvirt, VirtualBox, Vagrant |
| Infrastructure as Code | Vagrant, Ansible |
| DevOps | Git, GitHub Actions, CI/CD workflows |
| Kubernetes | K3s |
| GitOps | Argo CD |
| Monitoring | Prometheus, Grafana, Loki |
| Runtime Security | Falco |
| Policy Security | Kyverno |
| Containers | Docker, Harbor |
| Active Directory | Windows Server, Kerberos, LDAP |
| AD CS | Certificate services and escalation scenarios |
| Detection Engineering | MITRE ATT&CK concepts, log analysis |
| Security Testing | Nmap, BloodHound, Metasploit, Hashcat |


---


## Documentation hub


| Document | Purpose |
|---|---|
| [Documentation Index](./docs/README.md) | Full map of every doc under `docs/`, grouped by topic |
| [Learning Path](./docs/project/learning-path.md) | Recommended learning progression |
| [Architecture](./docs/architecture/architecture.md) | Infrastructure design |
| [Security Scope](./docs/security-scope.md) | Security boundaries |
| [Roadmap](./docs/project/roadmap.md) | Planned improvements and future lab development |
| [Portfolio](./docs/project/portfolio.md) | Skills and competencies demonstrated |
| [Dependencies](./docs/dependencies.md) | Project dependencies and requirements |
| [Guides](./docs/guides/) | Security and deployment guides |
| [Installation Guide](./docs/setup/installation.md) | Host setup |
| [Quickstart Examples](./docs/setup/quickstart-examples.md) | Rapid deployment examples |
| [Troubleshooting](./docs/setup/troubleshooting.md) | Common issues |
| [Minimal Resource Deployment](./docs/guides/optimization/minimal-resource-deployment.md) | Reduced-resource deployment |
| [Emergency Isolation Runbook](./docs/architecture/emergency-isolation-runbook.md) | Emergency isolation procedures |
| [Threat Model](./docs/architecture/threat-model.md) | Threat modeling documentation |
| [Scripts](./scripts/) | Repo-wide host readiness and validation helpers |


---


## Security and ethics


This project is intended only for:


- Education.
- Authorized security research.
- Defensive security practice.
- Isolated laboratory environments.


Only test systems you own or where you have explicit authorization.


Unauthorized access, testing, or exploitation of external systems is prohibited.


---


## Known limitations


- Full deployment requires significant CPU, RAM, and storage.
- The default provider is KVM/QEMU with libvirt and requires a Linux host. VirtualBox is supported on macOS, Windows, and Linux hosts without libvirt (Intel/AMD x86_64 only; does not run on Apple Silicon/ARM). Every lab selects the provider from a single unified `Vagrantfile` via `--provider`. Note: `active-directory/vlan-segmented`'s libvirt and VirtualBox configurations had functionally diverged before being unified (the VirtualBox variant had accumulated a fuller LLM01 OWASP Top-10 module, a Terraform state-file secrets-exposure scenario for cloud-pentest, and an LDIF-based AD CS template-creation technique that the libvirt variant never received); the unified Vagrantfile now runs that fuller content under both providers.
- **Provider differences:** KVM/libvirt generally outperforms VirtualBox for CPU- and I/O-heavy workloads (e.g., the DevOps/DevSecOps lab's Kubernetes nodes) because it uses hardware-accelerated virtio devices by default. VirtualBox networking (host-only/NAT) behaves differently from libvirt's NAT/bridged networks, so IP ranges and port-forwarding assumptions in some guides are libvirt-oriented; check the lab's Vagrantfile and its README for the VirtualBox-specific network configuration. Nested virtualization (needed for K3s/Kind/K3d workloads) must be enabled explicitly on VirtualBox (`--nested-hw-virt on`) and is not guaranteed to perform as well as libvirt's KVM-backed nesting.
- Windows evaluation media is used for laboratory environments.
- Some systems represent simulated enterprise services for safe security practice.
- Third-party Vagrant boxes may change independently.
- CI validates repository quality but does not fully deploy every environment.
- Designed for a single-host laboratory architecture.


---


## Development quickstart


Common local commands (wrapped in a `Makefile` for convenience):


```bash
pip install -r requirements-dev.txt
pre-commit install


make lint       # shellcheck (errors) + flake8 (informational)
make test       # pytest + bats unit tests
make validate   # vagrant validate on all lab Vagrantfiles
make security   # bandit (informational) + detect-secrets
make docs-refs  # dangling doc-reference check (blocks CI on a real finding)
```


Run `make help` for the full target list, including `make format`,
`make typecheck`, `make coverage`, `make validate-repo`, `make docs`, and
`make prereq`.


See [CONTRIBUTING.md](./CONTRIBUTING.md) for the full contributor workflow,
and [tests/README.md](./tests/README.md) for what the test suites cover.


---


## Contributing


Contributions are welcome.


Please:


- Open an issue before major changes.
- Keep pull requests focused.
- Update documentation when required.
- Follow repository contribution guidelines.


See [CONTRIBUTING.md](./CONTRIBUTING.md) for details.


---


## License


This project is licensed under the MIT License.


See [LICENSE](./LICENSE) for details.


Copyright © 2023–2026 Miguel A. Carlo
