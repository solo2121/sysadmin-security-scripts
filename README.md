# Security Engineering Lab


[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
![Platform](https://img.shields.io/badge/platform-Linux%7CmacOS%7CWindows-blue)
![Vagrant](https://img.shields.io/badge/Vagrant-Lab-orange)
![Security](https://img.shields.io/badge/Security-Research-red)
![DevSecOps](https://img.shields.io/badge/DevSecOps-Lab-purple)
[![CI](https://github.com/solo2121/security-engineering-lab/actions/workflows/ci.yml/badge.svg)](https://github.com/solo2121/security-engineering-lab/actions/workflows/ci.yml)


**Security Engineering Lab** is a modular, Vagrant-provisioned security and infrastructure engineering lab for practicing Active Directory security, network segmentation, Kubernetes, DevSecOps workflows, Linux administration, and infrastructure automation.


This repository is designed to be **runnable, not static**. It provides deployable lab environments, provisioning automation, validation workflows, and technical documentation. KVM/QEMU with libvirt is the primary development provider. VirtualBox is supported on compatible Intel/AMD x86_64 hosts. Oracle also provides a macOS Arm64 build for Apple Silicon Macs, but this repository's current Vagrant boxes and Windows Server-oriented workflows must be architecture-compatible before they can be considered supported on Apple Silicon.


**Maintained by:** Miguel A. Carlo (`solo2121`)  
**Project status:** Active development


---


## At a glance


| Item | Details |
|---|---|
| Primary provider | KVM/QEMU with libvirt |
| Alternative provider | VirtualBox on supported Intel/AMD x86_64 hosts |
| Lab environments | Active Directory, segmented Active Directory, DevOps/DevSecOps |
| Automation | Vagrant, Ansible, Bash, and Python |
| Cloud-native stack | K3s, Harbor, Argo CD, Prometheus, Grafana, Loki, Falco, and Kyverno |
| Validation | GitHub Actions, pytest, Bats, ShellCheck, and documentation checks |
| Intended use | Authorized research, defensive security practice, and isolated education |


Start here: [Learning Path](./docs/project/learning-path.md) provides the recommended progression through the labs, from Active Directory security fundamentals to segmented environments and DevSecOps workflows.


---


## See it in action


A full run of the Active Directory base lab, from `vagrant up` through domain promotion to a health-checked domain controller:


| 1. Provider auto-detection | 2. AD promotion succeeds | 3. Health check and lab manager |
|---|---|---|
| ![vagrant_manager.py detecting the libvirt provider and listing available lab VMs](./assets/demos/dc01-01-boot-provider-detect.gif) | ![Active Directory promotion completing successfully on dc01, followed by a reboot](./assets/demos/dc01-02-ad-promotion-success.gif) | ![Post-boot health check passing and the interactive lab manager menu](./assets/demos/dc01-03-healthcheck-manager.gif) |


A full run of the DevOps Linux lab, from K3s bootstrap through an airgapped Harbor registry to the DevSecOps attack-vector scenarios:


| 1. K3s node ready | 2. Airgapped image seeding | 3. Attack vectors deploy clean |
|---|---|---|
| ![K3s node Ready and kubectl API ready, with Ingress NGINX installing via Helm](./assets/demos/devops1-01-k3s-ready-ingress.gif) | ![Container images being pulled, tagged, and pushed into the airgapped Harbor registry](./assets/demos/devops1-02-harbor-seeding.gif) | ![DevSecOps attack-vector scenarios deploying successfully, ending with Harbor login succeeding](./assets/demos/devops1-03-attack-vectors.gif) |


Full unedited recordings are also available: [dc01.webm](./assets/demos/dc01.webm) and [devops1.webm](./assets/demos/devops1.webm).


---


## Supported providers


Each lab uses one provider-aware `Vagrantfile` that supports KVM/QEMU with libvirt and VirtualBox, subject to the provider-specific limitations documented below.


| Provider | Best for | Selection |
|---|---|---|
| **KVM/libvirt** | Linux hosts with hardware virtualization and nested virtualization support | `vagrant up --provider=libvirt` |
| **VirtualBox** | Cross-platform use on supported Intel/AMD x86_64 hosts | `vagrant up --provider=virtualbox` |


KVM/libvirt is the primary development provider and generally provides the best performance for CPU-, memory-, storage-, and network-intensive environments.


Before the first deployment, run the host-readiness check:


```bash
./scripts/check-prerequisites.sh
```


Or use the Make target:


```bash
make prereq
```


Run a lab with an explicit provider:


```bash
vagrant up --provider=libvirt
vagrant up --provider=virtualbox
```


You can also define a default provider for the current shell session:


```bash
export VAGRANT_DEFAULT_PROVIDER=virtualbox
```


See the [Installation Guide](./docs/setup/installation.md) for provider-specific setup instructions.


### Provider compatibility matrix


| Component | KVM/libvirt | VirtualBox |
|---|---|---|
| DevOps Linux lab | Supported with `--provider=libvirt` | Supported with `--provider=virtualbox` on compatible x86_64 hosts |
| Active Directory base lab | Supported with `--provider=libvirt` | Supported with `--provider=virtualbox` on compatible x86_64 hosts |
| Active Directory VLAN-segmented lab | Supported with `--provider=libvirt` | Supported with `--provider=virtualbox` on compatible x86_64 hosts |
| CI validation | Repository validation and selected provider checks where runner support is available | Repository validation and selected provider checks where runner support is available |
| Networking | Libvirt networks with automatic detection and fallback configuration | Host-only networking and VirtualBox internal networks |
| Network segmentation | Separate libvirt networks per segment | Isolated VirtualBox internal networks that model VLAN-like boundaries |
| Disk storage | qcow2 with libvirt storage configuration | VDI attached through a SATA controller |
| Nested virtualization | `host-passthrough` CPU configuration where required | Explicit nested hardware virtualization configuration where supported |
| Graphics | VNC through virtio video, loopback-oriented | VMSVGA or VBoxSVGA; optional GUI support through `LAB_GUI=true` |
| Linked clones | Not applicable; libvirt commonly uses backing-file images | Supported through VirtualBox linked clones |
| Guest additions | Not required for libvirt workflows | `vagrant-vbguest` is optional |
| Recommended use | Primary development and performance-sensitive deployments | Cross-platform compatibility on supported x86_64 hosts |


The provider configuration is implemented in a unified `Vagrantfile` per lab rather than separate provider-specific files. CI includes validation jobs for each lab's Vagrantfile against both providers — a libvirt job using the `vagrant-libvirt` plugin and a VirtualBox job using the VirtualBox provider built into Vagrant.


---


## Prerequisites


### Host requirements


- **Linux host:** Required for KVM/QEMU with libvirt.
- **macOS, Windows, or Linux host:** Supported with VirtualBox.
- **Intel/AMD x86_64 hosts:** Use x86_64 Vagrant boxes and guest operating systems.
- **Apple Silicon Macs:** Oracle provides a macOS Arm64 VirtualBox build. These labs are not currently validated for Apple Silicon because their existing Vagrant boxes, Windows Server workflows, and container images may require x86_64 architecture.
- **Hardware virtualization:** Intel VT-x or AMD-V must be enabled in the host BIOS/UEFI when applicable.
- **Vagrant:** Version 2.2 or newer.
- **Virtualization provider:** Either KVM/QEMU with libvirt or VirtualBox 7.0 or newer; use a current Oracle-supported version for macOS Arm64 hosts.


### Vagrant plugins


The required plugins vary by provider and lab.


#### Provider and lab plugins


Common provider or lab plugins include:


- `vagrant-reload`
- `vagrant-winrm`
- `vagrant-hostmanager`
- `vagrant-libvirt`


Install the common plugins as required by the installation documentation:


```bash
vagrant plugin install vagrant-reload
vagrant plugin install vagrant-winrm
vagrant plugin install vagrant-hostmanager
```


For libvirt:


```bash
vagrant plugin install vagrant-libvirt
```


#### Optional VirtualBox plugin


`vagrant-vbguest` is optional and may be used to manage VirtualBox Guest Additions. It is not required for basic VirtualBox support:


```bash
vagrant plugin install vagrant-vbguest
```


### Recommended resources


- **Minimum:** 16 GB RAM and approximately 100 GB of free disk space for reduced-resource deployments.
- **Recommended:** 32 GB or more RAM and approximately 200 GB of free disk space for full-profile deployments.
- **CPU:** A multi-core x86_64 or ARM64 processor with hardware virtualization support.
- **Network:** Internet access for initial box, package, and container-image retrieval unless using an already prepared or internally mirrored environment.
- **Python:** Python 3.10 or newer with `pip` for contributor tooling and lab management utilities.


Run the automated host-readiness check before deployment:


```bash
./scripts/check-prerequisites.sh
```


---


## Quick start


Clone the repository:


```bash
git clone https://github.com/solo2121/security-engineering-lab.git
cd security-engineering-lab
```


Validate the host:


```bash
./scripts/check-prerequisites.sh
```


Select a lab. For example:


```bash
cd labs/security/active-directory/base
```


Start the default provider:


```bash
vagrant up
```


Check the VM state:


```bash
vagrant status
```


To use VirtualBox explicitly:


```bash
vagrant up --provider=virtualbox
```


To use libvirt explicitly:


```bash
vagrant up --provider=libvirt
```


Each lab includes a Python-based `vagrant_manager.py` for interactive or scripted VM management. Run it from the selected lab directory:


```bash
python3 vagrant_manager.py
```


Examples:


```bash
python3 vagrant_manager.py up kali dc01
python3 vagrant_manager.py up --provider virtualbox
```


Verify the exact command syntax with:


```bash
python3 vagrant_manager.py --help
python3 vagrant_manager.py up --help
```


See the following documentation for additional deployment patterns:


- [Installation Guide](./docs/setup/installation.md)
- [Quickstart Examples](./docs/setup/quickstart-examples.md)
- [Learning Path](./docs/project/learning-path.md)


---


## What this project demonstrates


| Domain | Capabilities | Location |
|---|---|---|
| Active Directory security | Domain deployment, AD CS, credential attack paths, privilege-escalation research, and post-exploitation workflows | `labs/security/active-directory/base/` |
| Network segmentation | VLAN-like boundaries, routing separation, trust relationships, and segmentation-aware attack paths | `labs/security/active-directory/vlan-segmented/` |
| DevOps and DevSecOps | Kubernetes operations, GitOps, observability, runtime security, and policy enforcement | `labs/infrastructure/devops-linux-lab/` |
| Infrastructure as Code | Vagrant, Ansible, and automation workflows | Repository-wide |
| Security documentation | Architecture, threat models, setup guides, troubleshooting, and learning paths | `docs/` |
| Validation and quality engineering | Python tests, Bash tests, linting, documentation checks, and CI workflows | `.github/`, `tests/`, and `scripts/` |


---


## Architecture overview


[![Enterprise Infrastructure Architecture](./assets/diagrams/architecture-overview.png)](./assets/diagrams/)


Lab environments are deployed independently using their own Vagrant configurations.


The primary architecture uses KVM/QEMU with libvirt. VirtualBox is supported through the same provider-aware Vagrantfiles on compatible x86_64 hosts. Oracle also distributes VirtualBox for Apple Silicon macOS, but this repository does not currently claim Apple Silicon compatibility until ARM64 box, guest, and image support is implemented and validated.


The labs are designed to demonstrate:


- Isolated security research environments.
- Enterprise-style Active Directory infrastructure.
- Segmented network boundaries.
- Controlled routing and trust relationships.
- Kubernetes and containerized workloads.
- Runtime-security monitoring.
- Reproducible infrastructure deployment.
- Automated validation and documentation workflows.


The VLAN-segmented lab models enterprise network segmentation. Libvirt uses separate virtual networks, while VirtualBox uses isolated internal networks that provide VLAN-like boundaries. The VirtualBox implementation does not reproduce physical 802.1Q tagging.


See the following documents for architecture details, trust boundaries, and design decisions:


- [Architecture Overview](./docs/architecture/architecture.md)
- [Security Scope](./docs/security-scope.md)
- [Threat Model](./docs/architecture/threat-model.md)
- [Emergency Isolation Runbook](./docs/architecture/emergency-isolation-runbook.md)


---


## Lab environments


### Lab 1 — Active Directory Pentest Lab


**Path:** [labs/security/active-directory/base/](./labs/security/active-directory/base/)


This environment focuses on Windows enterprise-style infrastructure and Active Directory security research.


Focus areas include:


- Windows Server infrastructure.
- Active Directory Domain Services.
- Kerberos authentication.
- LDAP.
- Active Directory Certificate Services.
- Credential attack paths.
- Privilege-escalation research.
- Post-exploitation workflows.
- Detection-engineering concepts.


The lab uses a unified `Vagrantfile` supporting both KVM/libvirt and VirtualBox on compatible x86_64 hosts. Its Windows Server-focused configuration currently requires x86_64-compatible Vagrant boxes and guest media.


See the lab README for provider-specific instructions, resource profiles, and attack-simulation guidance.


### Lab 2 — Active Directory Pentest Lab — VLAN Edition


**Path:** [labs/security/active-directory/vlan-segmented/](./labs/security/active-directory/vlan-segmented/)


This environment extends the Active Directory lab with segmented network architectures and controlled routing boundaries.


Focus areas include:


- Active Directory with network segmentation.
- VLAN-like network boundaries.
- Controlled routing.
- Trust separation.
- Lateral-movement constraints.
- Segmentation-aware attack paths.
- Enterprise network-security concepts.
- Detection and response across network boundaries.


The environment demonstrates how segmentation influences attack paths, trust relationships, and adversary movement.


The lab uses a unified `Vagrantfile` supporting both KVM/libvirt and VirtualBox on compatible x86_64 hosts. Its Windows Server-focused configuration currently requires x86_64-compatible Vagrant boxes and guest media.


See the lab README and [lab-specific troubleshooting guide](./labs/security/active-directory/vlan-segmented/docs/troubleshooting.md) for additional information.


### Lab 3 — DevOps and DevSecOps Lab


**Path:** [labs/infrastructure/devops-linux-lab/](./labs/infrastructure/devops-linux-lab/)


This environment focuses on Linux-based DevOps, Kubernetes operations, platform engineering, and runtime-security workflows.


Focus areas include:


- Kubernetes administration.
- K3s.
- GitOps workflows.
- Argo CD.
- Infrastructure automation.
- Harbor registry operations.
- Observability.
- Prometheus and Grafana.
- Loki logging.
- Falco runtime security.
- Kyverno policy enforcement.
- Platform engineering workflows.
- Integrated CI/CD and security validation.


The lab uses a unified `Vagrantfile` supporting both KVM/libvirt and VirtualBox on compatible x86_64 hosts. Apple Silicon enablement requires ARM64-compatible Linux boxes, container images, and provider configuration validation before it can be considered supported.


See the lab README for provider-specific deployment requirements and resource profiles.


---


## Project overview


Security Engineering Lab integrates:


- Offensive security research.
- Linux system administration.
- Infrastructure automation.
- Cloud-native technologies.
- DevOps and DevSecOps practices.
- Security validation workflows.
- Detection-engineering concepts.
- Reproducible lab deployment.


The goal is to provide a realistic but isolated environment for learning how modern infrastructure is deployed, attacked, secured, monitored, and validated.


All security testing is intended for systems owned by the operator or explicitly authorized for testing.


---


## Highlights


### Active Directory security research


- Kerberoasting.
- AS-REP roasting.
- Active Directory Certificate Services abuse scenarios.
- Credential attack paths.
- NTLM relay concepts.
- DCSync research.
- Kerberos ticket attacks.
- Privilege-escalation workflows.
- Post-exploitation and detection concepts.


### Segmented security environments


- VLAN-like network architectures.
- Separate trust boundaries.
- Controlled routing.
- Segmentation-aware testing.
- Lateral-movement constraints.
- Enterprise network-security concepts.


### DevSecOps platform engineering


- Kubernetes.
- K3s.
- GitOps.
- Argo CD.
- Observability.
- Runtime security.
- Policy enforcement.
- Harbor registry workflows.
- Container-security testing.
- Security validation in CI/CD.


### Infrastructure automation


- Reproducible deployments.
- Vagrant-based provisioning.
- KVM/libvirt automation.
- VirtualBox provider support.
- Ansible workflows.
- Bash and Python tooling.
- Host-readiness validation.
- CI-based quality checks.


### Security engineering documentation


- Architecture documentation.
- Threat modeling.
- Security scope definition.
- Installation guides.
- Attack-simulation guides.
- Troubleshooting workflows.
- Emergency isolation procedures.
- Learning paths and portfolio documentation.


---


## Portfolio and learning goals


This repository demonstrates practical experience with:


- Linux administration.
- Active Directory environments.
- Infrastructure automation.
- KVM, QEMU, libvirt, and VirtualBox.
- Vagrant and Ansible.
- Kubernetes administration.
- GitOps workflows.
- Infrastructure as Code.
- DevSecOps engineering.
- Detection-engineering concepts.
- Security testing methodologies.
- Reproducible environment design.
- Technical documentation and project organization.


The recommended progression is documented in the [Learning Path](./docs/project/learning-path.md).


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
│   ├── demos/
│   │   ├── dc01-01-boot-provider-detect.gif
│   │   ├── dc01-02-ad-promotion-success.gif
│   │   ├── dc01-03-healthcheck-manager.gif
│   │   ├── dc01.webm
│   │   ├── devops1-01-k3s-ready-ingress.gif
│   │   ├── devops1-02-harbor-seeding.gif
│   │   ├── devops1-03-attack-vectors.gif
│   │   └── devops1.webm
│   └── README.md
├── docs/
│   ├── architecture/
│   ├── guides/
│   ├── project/
│   ├── setup/
│   ├── dependencies.md
│   ├── README.md
│   └── security-scope.md
├── examples/
├── labs/
│   ├── infrastructure/
│   │   └── devops-linux-lab/
│   └── security/
│       └── active-directory/
│           ├── base/
│           └── vlan-segmented/
├── scripts/
├── tests/
├── tools/
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


### Rebuild a single VM


Run these commands from the lab directory:


```bash
vagrant destroy dc01 -f
vagrant up dc01
```


### Save and restore snapshots


Create a snapshot before a risky laboratory exercise:


```bash
vagrant snapshot save dc01 clean-install
```


Restore the snapshot afterward:


```bash
vagrant snapshot restore dc01 clean-install
```


### Re-run provisioning


Re-run provisioning without recreating the virtual machines:


```bash
vagrant provision
```


### Use the lab manager


Run the manager from the selected lab directory:


```bash
python3 vagrant_manager.py
```


Examples:


```bash
python3 vagrant_manager.py up kali dc01
python3 vagrant_manager.py up --provider virtualbox
```


The manager can be used to:


- Start or stop individual VMs.
- Select a provider.
- Switch laboratory profiles.
- Inspect VM status.
- Run common Vagrant operations.


Verify the exact command syntax with:


```bash
python3 vagrant_manager.py --help
python3 vagrant_manager.py up --help
```


### Destroy the complete lab


```bash
vagrant destroy -f
```


For complete attack-simulation walkthroughs, see:


- [Guides](./docs/guides/)
- [Vagrant Management Tutorial](./docs/guides/infrastructure/vagrant-management-tutorial.md)
- [Quickstart Examples](./docs/setup/quickstart-examples.md)


The Active Directory base and VLAN-segmented labs each ship a `docs/attack-guide.md`; see those lab directories for attack-simulation guidance. The DevOps Linux lab documents its workflows in `labs/infrastructure/devops-linux-lab/docs/lab-guide.md`.


---


## Troubleshooting


### `vagrant up` hangs or times out


Confirm that:


- Hardware virtualization is enabled in the BIOS/UEFI when applicable.
- The selected provider is installed and available.
- The prerequisites script completes successfully.
- The host has sufficient CPU, RAM, and storage.
- The selected lab profile is appropriate for the host.
- On Apple Silicon, the selected box, guest operating system, and container images are ARM64-compatible; this repository does not currently validate that configuration.


Run:


```bash
./scripts/check-prerequisites.sh
```


### The wrong provider was selected


A VM created with one provider cannot normally be reused with another provider.


Destroy the existing environment and select the provider explicitly:


```bash
vagrant destroy -f
vagrant up --provider=libvirt
```


Or:


```bash
vagrant destroy -f
vagrant up --provider=virtualbox
```


### WinRM or SSH connection failures


Windows guests may require additional time to complete boot, networking, and service initialization.


Try:


```bash
vagrant up
```


again after the VM finishes booting, or re-run provisioning:


```bash
vagrant provision
```


Also verify:


- The guest has completed its reboot cycle.
- The expected network interface is available.
- The provider has assigned the expected address.
- The selected Vagrant box is available and compatible with the host architecture.


### Network or segmentation conflicts


Check for stale resources left behind after an interrupted deployment:


- Libvirt bridges and networks.
- VirtualBox host-only adapters.
- VirtualBox internal-network definitions.
- Previously allocated IP ranges.
- Conflicting `NETWORK_BASE` settings.


A complete destroy and clean redeployment may be required:


```bash
vagrant destroy -f
vagrant up
```


For the complete troubleshooting reference, see the [Troubleshooting Guide](./docs/setup/troubleshooting.md).


For VLAN-segmented lab issues, see the [VLAN lab troubleshooting guide](./labs/security/active-directory/vlan-segmented/docs/troubleshooting.md).


---


## Skills demonstrated


| Area | Technologies and concepts |
|---|---|
| Linux administration | Ubuntu, Rocky Linux, AlmaLinux, openSUSE |
| Virtualization | KVM, QEMU, libvirt, VirtualBox, Vagrant |
| Infrastructure as Code | Vagrant, Ansible |
| DevOps | Git, GitHub Actions, CI/CD workflows |
| Kubernetes | K3s, Kubernetes administration |
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


## Documentation hub


| Document | Purpose |
|---|---|
| [Documentation Index](./docs/README.md) | Map of documentation under `docs/`, grouped by topic |
| [Learning Path](./docs/project/learning-path.md) | Recommended progression through the labs |
| [Architecture](./docs/architecture/architecture.md) | Infrastructure design and deployment architecture |
| [Security Scope](./docs/security-scope.md) | Security boundaries and intended use |
| [Roadmap](./docs/project/roadmap.md) | Planned improvements and future development |
| [Portfolio](./docs/project/portfolio.md) | Skills and competencies demonstrated |
| [Dependencies](./docs/dependencies.md) | Project dependencies and requirements |
| [Guides](./docs/guides/) | Security, infrastructure, and deployment guides |
| [Installation Guide](./docs/setup/installation.md) | Host and provider setup |
| [Quickstart Examples](./docs/setup/quickstart-examples.md) | Rapid deployment patterns |
| [Troubleshooting](./docs/setup/troubleshooting.md) | Common problems and solutions |
| [Minimal Resource Deployment](./docs/guides/optimization/minimal-resource-deployment.md) | Reduced-resource deployment guidance |
| [Emergency Isolation Runbook](./docs/architecture/emergency-isolation-runbook.md) | Emergency isolation procedures |
| [Threat Model](./docs/architecture/threat-model.md) | Threat modeling documentation |
| [Scripts](./scripts/) | Host-readiness and validation helpers |


---


## Security and ethics


This project is intended only for:


- Education.
- Authorized security research.
- Defensive security practice.
- Isolated laboratory environments.
- Testing systems owned by the operator or explicitly authorized for testing.


Only test systems that you own or have explicit permission to assess.


Unauthorized access, testing, scanning, exploitation, credential attacks, or lateral movement against external systems is prohibited.


The intentionally vulnerable workloads and attack scenarios included in this repository must remain isolated from production networks and systems.


For additional security information, see:


- [Security Scope](./docs/security-scope.md)
- [Threat Model](./docs/architecture/threat-model.md)
- [SECURITY.md](./SECURITY.md)


---


## Known limitations


- Full-profile deployments require significant CPU, RAM, and storage.
- The recommended full-deployment target is 32 GB or more RAM and approximately 200 GB of free disk space.
- The primary provider is KVM/QEMU with libvirt and requires a compatible Linux host.
- VirtualBox is supported on compatible Intel/AMD x86_64 hosts.
- Oracle provides a macOS Arm64 VirtualBox build for Apple Silicon, but this repository's labs are not currently validated or documented as Apple Silicon-compatible.
- Existing x86_64 Windows Server and x86_64-only Vagrant box workflows require Intel/AMD x86_64 hardware unless equivalent ARM64 guest definitions are added and validated.
- Windows-based labs use Microsoft evaluation media. Users are responsible for complying with the applicable Microsoft licensing terms.
- Some systems represent simulated enterprise services for safe security practice.
- Third-party Vagrant boxes may change independently.
- CI validates repository quality and selected provider workflows but does not fully deploy every environment on every push.
- The project is designed primarily for a single-host laboratory architecture.


### Provider differences


KVM/libvirt generally outperforms VirtualBox for CPU- and I/O-intensive workloads, including Kubernetes and DevSecOps deployments, because it uses hardware-accelerated virtualization and virtio devices by default.


VirtualBox networking behaves differently from libvirt networking. IP ranges, host-only adapters, NAT behavior, and port-forwarding assumptions may differ between providers. Check the selected lab's `Vagrantfile` and README before relying on provider-specific network instructions.


Nested virtualization is required for some Kubernetes workloads. It must be enabled explicitly where supported by VirtualBox and may not perform as well as KVM-backed virtualization.


Network segmentation is implemented differently by provider:


- Libvirt uses separate virtual networks or interfaces.
- VirtualBox uses isolated internal networks that model VLAN-like boundaries.
- The resulting behavior may not exactly match a physical 802.1Q VLAN deployment.


Provider switching generally requires destroying and recreating the environment:


```bash
vagrant destroy -f
vagrant up --provider=<libvirt|virtualbox>
```


### Apple Silicon compatibility status


Oracle provides a macOS Arm64 build of VirtualBox for Apple Silicon Macs. VirtualBox availability on a host does not by itself make a Vagrant lab portable: the Vagrant boxes, guest operating systems, provisioning dependencies, and container images must all match the host and guest architecture.


This repository currently supports its VirtualBox workflows on compatible Intel/AMD x86_64 hosts. Apple Silicon enablement is a future compatibility target and requires ARM64 Vagrant boxes, ARM64 guest media where needed, multi-architecture container images, and documented validation for each lab.


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
make validate   # Validate all lab Vagrantfiles
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


See the following documents for development details:


- [CONTRIBUTING.md](./CONTRIBUTING.md)
- [Tests README](./tests/README.md)
- [Scripts README](./scripts/README.md)
- [Dependencies](./docs/dependencies.md)


---


## Contributing


Contributions are welcome.


Before submitting a contribution:


- Open an issue before making major changes.
- Keep pull requests focused.
- Update documentation when required.
- Add or update tests for behavioral changes.
- Run the relevant lint, test, validation, and documentation checks.
- Follow the repository contribution guidelines.
- Do not include credentials, secrets, private keys, or sensitive host information.


See [CONTRIBUTING.md](./CONTRIBUTING.md) for the complete contributor workflow.


---


## License


This project is licensed under the MIT License.


See [LICENSE](./LICENSE) for the full license text.


Copyright © 2023–2026 Miguel A. Carlo
