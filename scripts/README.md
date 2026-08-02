# Scripts

Repository-wide helper scripts. These operate on the repo as a whole (host
readiness, structure/documentation health) rather than on a single lab —
lab-specific scripts live alongside each lab under `labs/*/scripts/`.

---

## Directory Map

| Script | Purpose |
|--------|---------|
| [`check-prerequisites.sh`](check-prerequisites.sh) | Diagnoses whether a host is ready to deploy the labs (virtualization, KVM, libvirt, Vagrant, plugins, disk/RAM, network). Read-only — it never installs anything, only reports PASS/WARN/FAIL with a fix command for each failure. |
| [`validate_lab.py`](validate_lab.py) | Safe, read-only repository health check — verifies structure, required files, Vagrantfile syntax, and documentation consistency. Never starts VMs or touches the network. |

---

## Usage

```bash
# Check host readiness before deploying any lab
./scripts/check-prerequisites.sh

# Also check plugins needed for the AD Pentest Lab / VLAN Lab
./scripts/check-prerequisites.sh --lab1
./scripts/check-prerequisites.sh --lab2
./scripts/check-prerequisites.sh --all

# Validate repository structure and docs
python3 scripts/validate_lab.py
python3 scripts/validate_lab.py --verbose
python3 scripts/validate_lab.py --skip-vagrant   # CI without libvirt
```

Both scripts are also wrapped as `make prereq` and `make validate-repo` — see
the [`Makefile`](../Makefile) for the full list of developer targets.

---

## Related Documentation

- [`../docs/setup/installation.md`](../docs/setup/installation.md)
- [`../docs/setup/troubleshooting.md`](../docs/setup/troubleshooting.md)
- [`../docs/dependencies.md`](../docs/dependencies.md)
- [`../CONTRIBUTING.md`](../CONTRIBUTING.md)
