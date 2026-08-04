# kube-manager.sh

Modern Kubernetes administration utility. Wraps common `kubectl` operations
(health checks, listing nodes/pods/namespaces, describe, logs, top, apply,
delete, context switching) behind a single consistent CLI with dry-run
support, colorized logging, and confirmation prompts before destructive
actions.

## Path

```
tools/sysadmin/utilities/kube-manager.sh
```

## Requirements

- Bash 5+
- `kubectl`
- `jq`
- `yq`
- `timeout` (GNU coreutils)

## Usage

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

## Notes

- `kubectl get all` (used by `resources`) is a known-incomplete kubectl
  shortcut: it omits ConfigMaps, Secrets, Ingresses, PVCs, and
  NetworkPolicies. Extend `list_resources()` if you need full visibility
  into a namespace.
- `componentstatuses` (used by `health`) is deprecated/unavailable on many
  managed clusters (EKS, GKE, AKS); failures there are expected and
  non-fatal.
- `--yes` is required for non-interactive contexts (CI, cron); without a
  TTY, confirmation prompts fail safe (decline) rather than hang or crash.
