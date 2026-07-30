# Documentation index

This is a map of every doc in `docs/`, grouped by folder. Start here if
you're not sure where to look.

## Getting started

| Doc | What it covers |
|---|---|
| [`project/learning-path.md`](project/learning-path.md) | **Start here.** Which lab to try first, and in what order |
| [`setup/installation.md`](setup/installation.md) | Host setup, prerequisites, deploying any of the three labs |
| [`setup/troubleshooting.md`](setup/troubleshooting.md) | Common setup and runtime issues |
| [`setup/quickstart-examples.md`](setup/quickstart-examples.md) | Worked setup examples |
| [`guides/optimization/minimal-resource-deployment.md`](guides/optimization/minimal-resource-deployment.md) | Running any of the three labs on smaller hosts |

## Architecture

| Doc | What it covers |
|---|---|
| [`architecture/architecture.md`](architecture/architecture.md) | Overall infrastructure design for all three labs |
| [`architecture/threat-model.md`](architecture/threat-model.md) | Assets, trust boundaries, and assumed attacker per lab |
| [`architecture/security-scope.md`](architecture/security-scope.md) | What's authorized/isolated for the offensive-security content |

## Workflows

| Doc | What it covers |
|---|---|
| [`guides/workflows/workflows.md`](guides/workflows/workflows.md) | General repo/lab workflows |
| [`guides/workflows/lab-deployment-workflow.md`](guides/workflows/lab-deployment-workflow.md) | Step-by-step lab deployment flow |

## Infrastructure guides

| Doc | What it covers |
|---|---|
| [`guides/infrastructure/devops-platform-overview.md`](guides/infrastructure/devops-platform-overview.md) | Quick start: Vagrant → Docker → Minikube → Jenkins → Prometheus/Grafana |
| [`guides/infrastructure/complete-devops-platform-guide.md`](guides/infrastructure/complete-devops-platform-guide.md) | Full depth: adds Terraform, ArgoCD/GitOps, image scanning, canary deployments |
| [`guides/infrastructure/kubernetes-security-hardening.md`](guides/infrastructure/kubernetes-security-hardening.md) | k3s cluster hardening |
| [`guides/infrastructure/ansible-automation.md`](guides/infrastructure/ansible-automation.md) | Ansible roles used in the lab |
| [`guides/infrastructure/vagrant-management-tutorial.md`](guides/infrastructure/vagrant-management-tutorial.md) | Vagrant commands and workflows |
| [`guides/infrastructure/managing-kvm-qemu-cli-tutorial.md`](guides/infrastructure/managing-kvm-qemu-cli-tutorial.md) | KVM/QEMU CLI reference |
| [`guides/infrastructure/proxmox-host-setup.md`](guides/infrastructure/proxmox-host-setup.md) | Running the host virtualization layer on Proxmox |

## Security guides

| Doc | What it covers |
|---|---|
| [`guides/security/security-tooling-reference.md`](guides/security/security-tooling-reference.md) | Tooling reference used across the AD pentest lab |
| [`guides/security/password-attacks.md`](guides/security/password-attacks.md) | Password attack techniques and lab usage |
| [`guides/security/metasploit-lab-guide.md`](guides/security/metasploit-lab-guide.md) | Metasploit usage in the lab |
| [`guides/security/network-traffic-analysis.md`](guides/security/network-traffic-analysis.md) | Traffic analysis / packet capture workflows |
| [`guides/security/detection-and-blue-team.md`](guides/security/detection-and-blue-team.md) | Blue-team detection content (SIEM, alerting) |
| [`guides/security/ad-mitre-log-source-playbook.md`](guides/security/ad-mitre-log-source-playbook.md) | Mapping AD log sources to MITRE ATT&CK |
| [`guides/security/llm-security-compliance-lab.md`](guides/security/llm-security-compliance-lab.md) | LLM platform vulnerability/compliance testing |

## Reference archive

Older reference material, kept for continuity but not actively maintained
against the current lab structure:

| Doc | What it covers |
|---|---|
| [`archive/reference/complete-git-tutorial-linux-users.md`](archive/reference/complete-git-tutorial-linux-users.md) | Git tutorial for Linux users |
| [`archive/reference/complete-pacstall-tutorial-aur-ubuntu.md`](archive/reference/complete-pacstall-tutorial-aur-ubuntu.md) | Pacstall/AUR-on-Ubuntu tutorial |
| [`archive/reference/timeshift-cli-guide-external-drive-backups.md`](archive/reference/timeshift-cli-guide-external-drive-backups.md) | Timeshift CLI backup guide |
| [`archive/reference/apparmor.md`](archive/reference/apparmor.md) | AppArmor reference notes |

## Project

| Doc | What it covers |
|---|---|
| [`project/portfolio.md`](project/portfolio.md) | Portfolio-style project summary |
| [`project/roadmap.md`](project/roadmap.md) | Planned improvements and future lab development |

---

Looking for lab-specific docs (attack guides, credentials, networking) instead of general repo docs? Those live alongside each lab:

- `labs/security/ad-pentest/docs/`
- `labs/security/ad-pentest-vlan/docs/`
- `labs/infrastructure/devops-linux-lab/docs/`

See [`labs/README.md`](../labs/README.md) for the full lab index.
