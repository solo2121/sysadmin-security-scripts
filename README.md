# Security Engineering Lab


[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
![Platform](https://img.shields.io/badge/platform-Linux%7CmacOS%7CWindows-blue)
![Vagrant](https://img.shields.io/badge/Vagrant-Lab-orange)
![Security](https://img.shields.io/badge/Security-Research-red)
![DevSecOps](https://img.shields.io/badge/DevSecOps-Lab-purple)
[![CI](https://github.com/solo2121/security-engineering-lab/actions/workflows/ci.yml/badge.svg)](https://github.com/solo2121/security-engineering-lab/actions/workflows/ci.yml)


**Security Engineering Lab is a modular, Vagrant-provisioned security and infrastructure engineering lab repository for practicing Active Directory security, network segmentation, Kubernetes, DevSecOps workflows, Linux administration, and infrastructure automation.**


This repository is designed to be **runnable, not static**. The environments, automation, documentation, and workflows are implemented as deployable lab systems using Vagrant and KVM/QEMU with libvirt. Each lab also includes a VirtualBox-compatible `Vagrantfile` (see [Known limitations](#known-limitations)) for hosts without KVM/libvirt.


**Maintained by:** Miguel A. Carlo (solo2121)  
**Project status:** Active development


---


Start here: [Learning Path](./docs/project/learning-path.md) provides the recommended path through the labs, from Active Directory security fundamentals to segmented environments and DevSecOps workflows.


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


Lab environments are deployed independently using their own Vagrant configurations. KVM/QEMU with libvirt is the default provider; each lab also includes VirtualBox-compatible Vagrantfiles for hosts without libvirt.


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


**VirtualBox support:** VirtualBox-compatible Vagrantfiles are available in `labs/security/active-directory/base/virtualbox/`. See the lab README for provider-specific instructions.


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


**VirtualBox support:** VirtualBox-compatible Vagrantfiles are available in `labs/security/active-directory/vlan-segmented/virtualbox/`. See the lab README for provider-specific instructions.


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


**VirtualBox support:** VirtualBox-compatible Vagrantfiles are available in `labs/infrastructure/devops-linux-lab/virtualbox/`. See the lab README for provider-specific instructions.


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
│   │       └── virtualbox/
│   ├── README.md
│   └── security/
│       ├── active-directory/
│       │   ├── base/
│       │   │   └── virtualbox/
│       │   ├── vlan-segmented/
│       │   │   └── virtualbox/
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
- The default provider is KVM/QEMU with libvirt and requires a Linux host. Each lab includes a VirtualBox-compatible `Vagrantfile` for macOS, Windows, and Linux hosts without libvirt. VirtualBox itself is Intel/AMD (x86_64) only and does not run on Apple Silicon/ARM.
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