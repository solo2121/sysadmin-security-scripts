# Sysadmin Security Lab

[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE) 
![Platform](https://img.shields.io/badge/platform-Linux-blue) 
![Vagrant](https://img.shields.io/badge/Vagrant-Lab-orange) 
![Security](https://img.shields.io/badge/Security-Research-red) 
![DevSecOps](https://img.shields.io/badge/DevSecOps-Lab-purple) 
[![CI](https://github.com/solo2121/sysadmin-security-lab/actions/workflows/ci.yml/badge.svg)](https://github.com/solo2121/sysadmin-security-lab/actions/workflows/ci.yml)

**Sysadmin Security Lab is a modular, Vagrant-provisioned security and infrastructure engineering lab repository for practicing Active Directory security, network segmentation, Kubernetes, DevSecOps workflows, Linux administration, and infrastructure automation on Linux hosts.**

This repository is designed to be **runnable, not static**. The environments, automation, documentation, and workflows are implemented as deployable lab systems using Vagrant and KVM/libvirt.

**Maintained by:** Miguel A. Carlo (solo2121)  
**Project status:** Active development

---

Start here: [Learning Path](./docs/project/learning-path.md) provides the recommended path through the labs, from Active Directory security fundamentals to segmented environments and DevSecOps workflows.

## What this project demonstrates

| Domain | Capabilities | Location |
|---|---|---|
| Active Directory Security | Domain deployment, AD CS, credential attack paths, privilege escalation research, and post-exploitation workflows | `labs/security/ad-pentest/` |
| Network Segmentation | VLAN design, routing boundaries, trust separation, and segmentation-aware attack paths | `labs/security/ad-pentest-vlan/` |
| DevOps / DevSecOps | Kubernetes operations, GitOps, observability, runtime security, and policy enforcement | `labs/infrastructure/devops-linux-lab/` |
| Infrastructure as Code | Vagrant, Ansible, Terraform/OpenTofu, and automation workflows | Repository-wide |
| Security Documentation | Architecture, threat models, setup guides, troubleshooting, and learning paths | `docs/` |

---

## Architecture overview

![Enterprise Infrastructure Architecture](assets/diagrams/architecture-overview.png)

The repository contains independent lab environments. Each environment can be deployed separately using its own Vagrant configuration on KVM/QEMU virtualization infrastructure.

See:

- [Architecture Overview](./docs/architecture/architecture.md)
- [Security Scope](./docs/architecture/security-scope.md)

for architecture details, trust boundaries, and design decisions.

---

## Lab environments

### Lab 1 — Active Directory Pentest Lab

**Path:** [labs/security/ad-pentest/](./labs/security/ad-pentest/)

Focus areas:

- Windows enterprise-style infrastructure.
- Active Directory security.
- Kerberos authentication.
- AD Certificate Services (AD CS).
- Privilege escalation research.
- Post-exploitation workflows.
- Detection engineering concepts.

---

### Lab 2 — Active Directory Pentest Lab (VLAN Edition)

**Path:** [labs/security/ad-pentest-vlan/](./labs/security/ad-pentest-vlan/)

Focus areas:

- Active Directory with network segmentation.
- VLAN boundaries.
- Controlled routing.
- Lateral movement constraints.
- Enterprise network security concepts.

This environment demonstrates how segmentation influences attack paths, trust boundaries, and adversary movement.

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
- Integrated CI/CD pipelines (Gitea, Jenkins, SonarQube, Vault, OWASP ZAP).

---

## Project overview

Sysadmin Security Lab demonstrates the integration of:

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
- KVM/libvirt virtualization.
- Kubernetes administration.
- GitOps workflows.
- Infrastructure as Code.
- DevSecOps engineering.
- Detection engineering concepts.
- Security testing methodologies.

---

## Repository structure

```text
sysadmin-security-lab/
├── .github/
│   ├── ISSUE_TEMPLATE/
│   ├── workflows/
│   ├── CODEOWNERS
│   └── dependabot.yml
├── assets/
├── docs/
│   ├── architecture/
│   ├── guides/
│   └── workflows/
├── labs/
│   ├── infrastructure/
│   │   └── devops-linux-lab/
│   └── security/
│       ├── ad-pentest/
│       └── ad-pentest-vlan/
├── scripts/
├── tools/
│   ├── security/
│   └── sysadmin/
├── tests/
├── CHANGELOG.md
├── CONTRIBUTING.md
├── LICENSE
├── Makefile
├── SECURITY.md
└── README.md
```

---

## Skills demonstrated

| Area | Technologies |
|---|---|
| Linux Administration | Ubuntu, Rocky Linux, AlmaLinux, openSUSE |
| Virtualization | KVM, QEMU, libvirt, Vagrant |
| Infrastructure as Code | Terraform, OpenTofu, Ansible |
| DevOps | Git, GitHub Actions, CI/CD workflows |
| Kubernetes | k3s, Kind, K3d |
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
| [Learning Path](./docs/project/learning-path.md) | Recommended learning progression |
| [Architecture](./docs/architecture/architecture.md) | Infrastructure design |
| [Security Scope](./docs/architecture/security-scope.md) | Security boundaries |
| [Roadmap](./docs/project/roadmap.md) | Planned improvements and future lab development |
| [Guides](./docs/guides/) | Security and deployment guides |
| [Installation Guide](./docs/setup/installation.md) | Host setup |
| [Troubleshooting](./docs/setup/troubleshooting.md) | Common issues |
| [Minimal Resource Deployment](./docs/guides/optimization/minimal-resource-deployment.md) | Reduced-resource deployment |

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
- Linux hosts only due to KVM/libvirt requirements.
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
make validate   # vagrant validate on all three lab Vagrantfiles
make security   # bandit (informational) + detect-secrets
```

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