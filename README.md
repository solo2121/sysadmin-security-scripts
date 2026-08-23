# Security Engineering Lab

[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
![Platform](https://img.shields.io/badge/platform-Linux%7CmacOS%7CWindows-blue)
![Vagrant](https://img.shields.io/badge/Vagrant-Lab-orange)
![Security](https://img.shields.io/badge/Security-Research-red)
![DevSecOps](https://img.shields.io/badge/DevSecOps-Lab-purple)
[![CI](https://github.com/solo2121/security-engineering-lab/actions/workflows/ci.yml/badge.svg)](https://github.com/solo2121/security-engineering-lab/actions/workflows/ci.yml)

**Security Engineering Lab** is a modular, Vagrant-provisioned homelab for authorized Active Directory security research, network segmentation, Kubernetes, DevSecOps workflows, Linux administration, and infrastructure automation.

This repository is designed to be **runnable, not static**. It includes deployable lab environments, provisioning automation, validation workflows, and technical documentation. KVM/QEMU with libvirt is the primary development provider. VirtualBox is supported on compatible Intel/AMD x86_64 hosts.

Apple Silicon is not currently supported. Oracle provides an Arm64 build of VirtualBox for macOS, but this repository requires architecture-compatible Vagrant boxes, Windows guest workflows, provisioning dependencies, and container images before Apple Silicon can be considered validated.

**Maintained by:** Miguel A. Carlo (`solo2121`)  
**Project status:** Active development

---

## At a glance

| Item | Details |
|---|---|
| Primary provider | KVM/QEMU with libvirt |
| Alternative provider | VirtualBox on compatible Intel/AMD x86_64 hosts |
| Lab environments | Active Directory, segmented Active Directory, DevOps/DevSecOps |
| Automation | Vagrant, Ansible, Bash, and Python |
| Cloud-native stack | K3s, Harbor, Argo CD, Prometheus, Grafana, Loki, Falco, and Kyverno |
| Validation | GitHub Actions, pytest, Bats, ShellCheck, and documentation checks |
| Intended use | Authorized research, defensive security practice, and isolated education |

### Which lab should I start with?

| Lab | Default VMs | RAM (min / recommended) | Disk | Best for |
|---|---|---|---|---|
| [Active Directory — base](./labs/security/active-directory/base/) | 6 (up to 11 with `LAB_PROFILE=full`) | 16 GB / 32 GB+ | 150 GB+ | Learning core AD attack paths (Kerberoasting, AS-REP roasting, AD CS abuse) without network segmentation to worry about. Start here if you're new to AD security. |
| [Active Directory — VLAN-segmented](./labs/security/active-directory/vlan-segmented/) | 12 | 16 GB / 32 GB | 80 GB+ | The same AD attack surface behind an OPNsense firewall with real VLAN segmentation — for practicing lateral movement across network boundaries once you're comfortable with the base lab. |
| [DevOps / DevSecOps](./labs/infrastructure/devops-linux-lab/) | 12 | 16 GB (core cluster only) / 32 GB | 200 GB+ | Kubernetes (K3s), Harbor, CI/CD (Gitea/Jenkins/SonarQube/Vault/ZAP), and Linux administration practice — not AD-focused. |

Run `./scripts/check-prerequisites.sh --all` before deploying any lab to confirm your host meets the requirements above.

Start with the [Learning Path](./docs/project/learning-path.md) for the recommended progression through the labs, from Active Directory security fundamentals to segmented environments and DevSecOps workflows.

---

## See it in action

### Active Directory base lab

A complete Active Directory base-lab deployment, from provider detection through domain promotion and post-boot health validation.

| 1. Provider auto-detection | 2. AD promotion succeeds | 3. Health check and lab manager |
|---|---|---|
| ![vagrant_manager.py detecting the libvirt provider and listing available lab VMs](./assets/demos/dc01-01-boot-provider-detect.gif) | ![Active Directory promotion completing successfully on dc01, followed by a reboot](./assets/demos/dc01-02-ad-promotion-success.gif) | ![Post-boot health check passing and the interactive lab manager menu](./assets/demos/dc01-03-healthcheck-manager.gif) |

### DevOps and DevSecOps lab

A complete Linux DevSecOps deployment, from K3s bootstrap through Harbor image seeding and authorized security-test scenario deployment.

| 1. K3s node ready | 2. Airgapped image seeding | 3. Security-test scenarios deploy |
|---|---|---|
| ![K3s node Ready and kubectl API ready, with Ingress NGINX installing via Helm](./assets/demos/devops1-01-k3s-ready-ingress.gif) | ![Container images being pulled, tagged, and pushed into the airgapped Harbor registry](./assets/demos/devops1-02-harbor-seeding.gif) | ![Authorized DevSecOps security-test scenarios deploying successfully, ending with Harbor login succeeding](./assets/demos/devops1-03-attack-vectors.gif) |

### VLAN-segmented Active Directory lab

A complete OPNsense deployment for the segmented Active Directory lab, from initial boot through reload and interface assignment.

| 1. Lab manager starts OPNsense | 2. Reload completes cleanly | 3. Full topology live |
|---|---|---|
| ![Pentest VLAN Lab Manager bringing the opnsense VM up under the libvirt provider](./assets/demos/opnsense-01-lab-manager-start.gif) | ![OPNsense reloading after configuration and coming back with Machine booted and ready](./assets/demos/opnsense-02-reload-success.gif) | ![OPNsense console showing the complete WAN, LAN, and VLAN interface assignments](./assets/demos/opnsense-03-vlan-topology.gif) |

Full unedited recordings are available for the [Active Directory lab](./assets/demos/dc01.webm), [DevOps lab](./assets/demos/devops1.webm), and [VLAN-segmented lab](./assets/demos/opnsense-vlan.webm).

---

## Quick start

Clone the repository:

```bash
git clone https://github.com/solo2121/security-engineering-lab.git
cd security-engineering-lab
```

Validate host requirements before deploying a lab:

```bash
./scripts/check-prerequisites.sh
```

Or use the Make target:

```bash
make prereq
```

Select a lab. For example, start with the Active Directory base lab:

```bash
cd labs/security/active-directory/base
```

Start the lab with libvirt:

```bash
vagrant up --provider=libvirt
```

Or start the lab with VirtualBox on a compatible x86_64 host:

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

Verify manager syntax with:

```bash
python3 vagrant_manager.py --help
python3 vagrant_manager.py up --help
```

See the [Installation Guide](./docs/setup/installation.md), [Quickstart Examples](./docs/setup/quickstart-examples.md), and [Learning Path](./docs/project/learning-path.md) for provider setup, deployment patterns, and lab progression.

---

## Lab environments

| Lab | Purpose | Location |
|---|---|---|
| Active Directory Security Lab | Windows enterprise infrastructure, Active Directory security research, identity attack-path simulation, and detection concepts | [labs/security/active-directory/base/](./labs/security/active-directory/base/) |
| Segmented Active Directory Lab | Segmentation-aware Active Directory research, routing controls, trust boundaries, and lateral-movement constraints | [labs/security/active-directory/vlan-segmented/](./labs/security/active-directory/vlan-segmented/) |
| DevOps and DevSecOps Lab | Linux administration, Kubernetes, GitOps, observability, runtime security, and policy enforcement | [labs/infrastructure/devops-linux-lab/](./labs/infrastructure/devops-linux-lab/) |

### Active Directory Security Lab

The base Active Directory lab focuses on Windows enterprise-style infrastructure and authorized security research.

Focus areas include:

- Windows Server infrastructure
- Active Directory Domain Services
- Kerberos authentication
- LDAP
- Active Directory Certificate Services
- Credential-access and identity attack-path simulation
- Privilege-escalation simulation and detection research
- Post-compromise simulation and detection workflows
- Detection-engineering concepts

See the [lab README](./labs/security/active-directory/base/) for provider-specific instructions, resource profiles, and authorized security-testing guidance.

### Segmented Active Directory Lab

The VLAN-segmented lab extends the base Active Directory lab with controlled routing, separated trust boundaries, and segmentation-aware security testing.

Focus areas include:

- Active Directory with segmented network boundaries
- Controlled routing and trust separation
- Lateral-movement constraints
- Segmentation-aware security-testing scenarios
- Enterprise network-security concepts
- Detection and response across network boundaries

See the [lab README](./labs/security/active-directory/vlan-segmented/) and [VLAN lab troubleshooting guide](./labs/security/active-directory/vlan-segmented/docs/troubleshooting.md) for deployment and troubleshooting information.

### DevOps and DevSecOps Lab

The DevOps lab focuses on Linux platform engineering, Kubernetes operations, GitOps workflows, observability, runtime security, and policy enforcement.

Focus areas include:

- Kubernetes administration with K3s
- GitOps workflows with Argo CD
- Harbor registry operations
- Prometheus, Grafana, and Loki observability
- Falco runtime security
- Kyverno policy enforcement
- Container-security testing
- Infrastructure automation
- Integrated CI/CD and security validation

See the [lab README](./labs/infrastructure/devops-linux-lab/) for provider-specific deployment requirements and resource profiles.

---

## Provider compatibility

Each lab uses a provider-aware `Vagrantfile` supporting KVM/QEMU with libvirt and VirtualBox, subject to provider-specific requirements.

| Provider | Best for | Start command |
|---|---|---|
| **KVM/libvirt** | Linux hosts with hardware virtualization and nested virtualization support | `vagrant up --provider=libvirt` |
| **VirtualBox** | Compatible Intel/AMD x86_64 hosts running Linux, macOS, or Windows | `vagrant up --provider=virtualbox` |

KVM/libvirt is the primary development provider and generally provides the best performance for CPU-, memory-, storage-, and network-intensive environments.

### Compatibility matrix

| Component | KVM/libvirt | VirtualBox |
|---|---|---|
| DevOps Linux lab | Supported with `--provider=libvirt` | Supported with `--provider=virtualbox` on compatible x86_64 hosts |
| Active Directory base lab | Supported with `--provider=libvirt` | Supported with `--provider=virtualbox` on compatible x86_64 hosts |
| Active Directory segmented lab | Supported with `--provider=libvirt` | Supported with `--provider=virtualbox` on compatible x86_64 hosts |
| Networking | Libvirt networks with automatic detection and fallback configuration | Host-only networking and VirtualBox internal networks |
| Network segmentation | Separate libvirt networks per segment | Isolated internal networks that model VLAN-like boundaries |
| Disk storage | qcow2 with libvirt storage configuration | VDI attached through a SATA controller |
| Nested virtualization | `host-passthrough` CPU configuration where required | Explicit nested hardware virtualization configuration where supported |
| Graphics | VNC through virtio video, loopback-oriented | VMSVGA or VBoxSVGA with optional GUI support through `LAB_GUI=true` |
| Linked clones | Backing-file images are commonly used | VirtualBox linked clones are supported |
| Guest additions | Not required for libvirt workflows | `vagrant-vbguest` is optional |
| Recommended use | Primary development and performance-sensitive deployments | Cross-platform compatibility on supported x86_64 hosts |

The segmented lab uses separate virtual networks with libvirt and isolated internal networks with VirtualBox. VirtualBox networking models VLAN-like boundaries but does not reproduce physical IEEE 802.1Q VLAN tagging.

### Apple Silicon status

Oracle provides an Arm64 version of VirtualBox for Apple Silicon Macs. VirtualBox availability alone does not make a Vagrant lab architecture-compatible.

This repository currently supports VirtualBox workflows on compatible Intel/AMD x86_64 hosts. Apple Silicon support requires:

- ARM64-compatible Vagrant boxes
- ARM64 guest media where required
- Multi-architecture container images
- Validated provider configuration for each lab
- Documented deployment and testing workflows

See the [Installation Guide](./docs/setup/installation.md) for provider-specific setup instructions.

---

## Prerequisites

### Host requirements

- **Linux host:** Required for KVM/QEMU with libvirt
- **Linux, macOS, or Windows host:** Supported with VirtualBox on compatible Intel/AMD x86_64 hardware
- **CPU architecture:** Existing Windows Server and most current Vagrant box workflows require Intel/AMD x86_64 compatibility
- **Hardware virtualization:** Intel VT-x or AMD-V enabled in BIOS/UEFI when applicable
- **Vagrant:** Version 2.2 or newer
- **Virtualization provider:** KVM/QEMU with libvirt or VirtualBox 7.0 or newer
- **Python:** Python 3.10 or newer with `pip` for contributor tooling and lab-management utilities
- **Network:** Internet access for initial box, package, and container-image retrieval unless using prepared local or internal mirrors

### Recommended resources

- **Reduced-resource deployments:** At least 16 GB RAM and approximately 100 GB free disk space; availability depends on the selected lab and resource profile
- **Full-profile deployments:** 32 GB or more RAM and approximately 200 GB free disk space
- **CPU:** Multi-core processor with hardware virtualization support
- **Storage:** SSD or NVMe storage is strongly recommended for Kubernetes, Windows Server, and multi-VM workloads

### Vagrant plugins

Install the common plugins required by the selected lab and provider:

```bash
vagrant plugin install vagrant-reload
vagrant plugin install vagrant-winrm
vagrant plugin install vagrant-hostmanager
```

Install the libvirt provider plugin when using KVM/QEMU:

```bash
vagrant plugin install vagrant-libvirt
```

The VirtualBox Guest Additions plugin is optional:

```bash
vagrant plugin install vagrant-vbguest
```

---

## Architecture overview

[![Enterprise Infrastructure Architecture](./assets/diagrams/architecture-overview.png)](./assets/diagrams/)

The lab environments deploy independently through their own provider-aware Vagrant configurations. The architecture combines isolated Active Directory environments, segmented virtual networks, Kubernetes workloads, security monitoring, policy enforcement, and validation workflows.

The labs demonstrate:

- Isolated security research environments
- Enterprise-style Active Directory infrastructure
- Segmented network boundaries and controlled routing
- Kubernetes and containerized workloads
- Runtime-security monitoring
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
| Network segmentation | VLAN-like boundaries, routing separation, trust relationships, and segmentation-aware security-testing scenarios | `labs/security/active-directory/vlan-segmented/` |
| DevOps and DevSecOps | Kubernetes operations, GitOps, observability, runtime security, and policy enforcement | `labs/infrastructure/devops-linux-lab/` |
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
./scripts/check-prerequisites.sh
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

See the [Troubleshooting Guide](./docs/setup/troubleshooting.md) and [VLAN lab troubleshooting guide](./labs/security/active-directory/vlan-segmented/docs/troubleshooting.md) for detailed guidance.

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
│   │   └── devops-linux-lab/
│   └── security/
│       └── active-directory/
│           ├── base/
│           └── vlan-segmented/
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

See the [Documentation Index](./docs/README.md) for the complete documentation map and each lab directory for provider-specific deployment instructions.

---

## Development quickstart

Install development dependencies:

```bash
pip install -r requirements-dev.txt
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
- Apple Silicon support is a future compatibility target and requires ARM64-compatible boxes, guest media, container images, and per-lab validation.
- Windows-based labs use Microsoft evaluation media; users are responsible for complying with applicable Microsoft licensing terms.
- Third-party Vagrant boxes may change independently.
- CI validates repository quality and selected provider workflows but does not fully deploy every environment on every push.
- The project is designed primarily for a single-host laboratory architecture.

---

## License

This project is licensed under the MIT License.

See [LICENSE](./LICENSE) for the full license text.

Copyright © 2023–2026 Miguel A. Carlo