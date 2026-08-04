# tools/sysadmin/utilities

Menu-driven and CLI system administration scripts: DNS, memory, git, Kubernetes,
snapshots, and firewall management.

## Scripts at a glance

| Script | Interface | Root required | Destructive |
|---|---|---|---|
| [`bind-manager.sh`](#bind-managersh) | Interactive menu | Yes | Zone/record edits |
| [`free_mem.sh`](#free_memsh) | Interactive menu | Yes | Drops cache/swap |
| [`git-management.sh`](#git-managementsh) | Interactive menu | No | Commits/pushes |
| [`kube-manager.sh`](#kube-managersh) | CLI flags | No | Deletes (confirmed) |
| [`timeshift-manager.sh`](#timeshift-managersh) | CLI flag + menu | Yes | Restores overwrite system |
| [`ufw-manager.sh`](#ufw-managersh) | Interactive menu | Yes (self-elevates) | Firewall rule/state changes |

> **Note:** `kube-manager.sh` is the only script here built as a non-interactive,
> flag-driven CLI (supports `--dry-run`/`--yes` for scripting and CI). The rest
> are `read -rp`-driven interactive menus and are not designed to be piped or
> run unattended.

---

## `bind-manager.sh`

Interactive BIND9 DNS server administration: install, base configuration,
zone creation, record management, validation, status, and query logging.

- **Requires:** root; `bind9`/`bind-utils` (script can install them)
- **Manages:** `/etc/bind/named.conf`, `named.conf.options`, `named.conf.local`,
  zone files under `/etc/bind/zones`, logs under `/var/log/bind`
- **Usage:**
  ```bash
  sudo ./tools/sysadmin/utilities/bind-manager.sh
  ```
- **Menu:** Install BIND, configure options, create zone, add record, check
  config, restart service, show status, view zone files, toggle query logging

---

## `free_mem.sh`

Interactive memory-pressure viewer and cache-clearing utility.

- **Requires:** root (writes to `/proc/sys/vm/drop_caches`)
- **Destructive:** drops page cache, dentries/inodes, and/or swap — can cause
  a brief performance dip while caches rebuild; do not run under memory-critical
  production load without testing
- **Usage:**
  ```bash
  sudo ./tools/sysadmin/utilities/free_mem.sh
  ```
- **Menu:** clear page cache only / dentries & inodes / all caches / swap only /
  all caches + swap, show memory usage, show system info

---

## `git-management.sh`

Interactive helper for everyday git workflows, aligned with this repo's
`CONTRIBUTING.md` commit conventions.

- **Requires:** must be run inside a git repository; no root
- **Safety:** prompts for confirmation before pushing directly to `main`/`master`
- **Usage:**
  ```bash
  ./tools/sysadmin/utilities/git-management.sh
  ```
- **Menu:** status, stage files, commit (prompts for conventional-commit
  type/scope/description), push, fetch, pull, log, branches

---

## `kube-manager.sh`

Kubernetes administration CLI wrapping common `kubectl` operations — health
checks, listing nodes/pods/namespaces, describe, logs, top, apply, delete,
context switching — with dry-run support and confirmation prompts before
destructive actions.

- **Requires:** Bash 5+, `kubectl`, `jq`, `yq`, `timeout` (GNU coreutils)
- **Usage:**
  ```bash
  ./tools/sysadmin/utilities/kube-manager.sh [OPTIONS] COMMAND [ARGS]
  ```

### Options

| Flag | Description |
|---|---|
| `--dry-run` | Print the `kubectl` command that would run instead of executing it |
| `--yes` | Skip confirmation prompts (non-interactive mode) |
| `--verbose` | Print debug logging (e.g. commands as they run) |
| `-h`, `--help` | Show usage |

### Commands

| Command | Description |
|---|---|
| `health` | Cluster info, component statuses, node list |
| `nodes` | List nodes |
| `pods [namespace]` | List pods (default namespace: `default`) |
| `namespaces` | List namespaces |
| `resources [namespace]` | List all resources in a namespace |
| `describe <type> <name> [namespace]` | Describe a resource |
| `logs <pod> [namespace]` | Show last 200 lines of pod logs |
| `top` | Node/pod resource usage (requires metrics-server) |
| `apply <file>` | `kubectl apply -f <file>` |
| `delete <type> <name> [namespace]` | Delete a resource (prompts for confirmation) |
| `contexts` | List available kubeconfig contexts |
| `context <name>` | Switch kubeconfig context |
| `version` | Show script and kubectl version |

### Examples

```bash
./tools/sysadmin/utilities/kube-manager.sh health
./tools/sysadmin/utilities/kube-manager.sh pods default
./tools/sysadmin/utilities/kube-manager.sh logs nginx-pod
./tools/sysadmin/utilities/kube-manager.sh apply deployment.yaml
./tools/sysadmin/utilities/kube-manager.sh delete pod nginx --dry-run
./tools/sysadmin/utilities/kube-manager.sh context production
```

### Notes

- `kubectl get all` (used by `resources`) is a known-incomplete kubectl
  shortcut: it omits ConfigMaps, Secrets, Ingresses, PVCs, and
  NetworkPolicies. Extend `list_resources()` if you need full visibility
  into a namespace.
- `componentstatuses` (used by `health`) is deprecated/unavailable on many
  managed clusters (EKS, GKE, AKS); failures there are expected and
  non-fatal.
- `--yes` is required for non-interactive contexts (CI, cron); without a
  TTY, confirmation prompts fail safe (decline) rather than hang or crash.

---

## `timeshift-manager.sh`

Interactive Timeshift snapshot administration: create, delete, restore, list,
and inspect system snapshots, with logging to `/var/log/timeshift-manager.log`.

- **Requires:** root; `timeshift` installed and configured
- **Destructive:** restoring a snapshot overwrites the current system state
- **Usage:**
  ```bash
  sudo ./tools/sysadmin/utilities/timeshift-manager.sh          # interactive menu
  sudo ./tools/sysadmin/utilities/timeshift-manager.sh --list   # list snapshots and exit
  ```
- **Menu:** create snapshot, delete snapshot, restore snapshot, list snapshots,
  system info, exit

---

## `ufw-manager.sh`

Menu-driven UFW (Uncomplicated Firewall) administration: view rules, add/delete
rules, and toggle/reload/reset the firewall, with logging to `/var/log/ufw_manager.log`.

- **Requires:** `ufw` installed, Bash 4+; self-elevates via `sudo` if not
  already running as root
- **Destructive:** modifies live firewall rules and can enable/disable/reset
  the firewall
- **Usage:**
  ```bash
  ./tools/sysadmin/utilities/ufw-manager.sh
  ```
- **Menu:** show rules, add rule, delete rule, toggle/reload/reset, exit

---

## Contributing a new script

When adding a script to this directory, also add a section here following the
pattern above (Purpose, Requires, Destructive, Usage, Menu/Commands) so the
README and directory contents never drift out of sync.
