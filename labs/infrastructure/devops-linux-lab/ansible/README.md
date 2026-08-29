# devops-linux-lab Ansible roles

This directory holds Ansible roles that replace parts of the inline
`vm.vm.provision "shell"` blocks in `../Vagrantfile` with idempotent,
independently testable roles. The goal is repeatability: the same roles
can be re-run against an existing node, run against a subset of nodes, or
linted/tested in CI, none of which is practical with heredoc shell
provisioners.

## Layout

```
ansible/
├── ansible.cfg
├── requirements.yml       # Empty manifest; no external collections needed
├── site.yml               # Top-level playbook wiring roles to node groups
├── inventory/
│   └── hosts.example.ini  # Copy to hosts.ini and adjust IPs/paths
├── group_vars/
│   ├── all.yml
│   └── k8s_master.yml
└── roles/
    ├── common/            # Base packages, SSH service, timezone, /etc/hosts
    ├── docker/            # Docker Engine install (Debian/RedHat/SUSE families)
    ├── ssh_keys/          # Distributes shared authorized_keys to lab nodes
    └── devops_tools/      # kubectl / Helm / kind / k3d CLI installation
```

## Usage

```bash
cd labs/infrastructure/devops-linux-lab/ansible
cp inventory/hosts.example.ini inventory/hosts.ini   # edit IPs/SSH key path
ansible-playbook site.yml
```

Every role uses only `ansible.builtin` modules, so no `ansible-galaxy
collection install` step is required — a stock `ansible-core` install is
enough. `requirements.yml` is kept as an empty manifest for future roles.

You can also target a single role or group, e.g.:

```bash
ansible-playbook site.yml --tags docker --limit linux_labs
ansible-playbook site.yml --limit k8s_master
```

## What this replaces today

* The duplicated "install curl/wget/git/jq/..." apt/dnf/zypper blocks for
  every VM → `common` role.
* The Docker install steps that were repeated per role (`kind`, worker,
  lab nodes) → `docker` role.
* The `/vagrant/ansible_key.pub` polling loop copied into every
  `"lab", "ansible"` node → `ssh_keys` role.
* The per-VM `curl | bash` installers for `kubectl`/Helm/kind/k3d →
  `devops_tools` role.

## What is intentionally still in the Vagrantfile

VM lifecycle, networking, disk attachment, and the stateful K3s
bootstrap/join sequence (token generation, Harbor, ingress-nginx,
monitoring stack, Jenkins/SonarQube/Vault containers) remain in the
Vagrantfile for now. Those steps are tightly coupled to Vagrant-managed
state (e.g. the shared `/vagrant/.k3s_token` file) and are a larger,
separate migration — converting them is a good next iteration once these
foundational roles are in place and proven out.

## Linting

These roles are written to comply with `ansible-lint`'s default rule set
(FQCN module names, explicit file modes, named tasks, `common_`/`docker_`/
etc.-prefixed role variables) and were verified locally with
`ansible-lint .` before submission. No extra `.ansible-lint` configuration
is included here so the CI `lint-ansible-roles` job's own settings apply.
