# Lab Reset and Cleanup Guide

A consolidated reference for tearing a lab down and getting back to a known-good
state — whether you want to retry a broken deployment, reclaim host resources,
or hand the host back exactly as it was before you started. This complements
[`lab-deployment-workflow.md`](lab-deployment-workflow.md) (which covers
deployment and snapshots) by focusing on the reverse operation: reset and
reproducibility.

---

## Table of Contents

1. [When to Use Which Reset](#when-to-use-which-reset)
2. [Level 1: Snapshot Revert](#level-1-snapshot-revert)
3. [Level 2: Single-VM Rebuild](#level-2-single-vm-rebuild)
4. [Level 3: Full Lab Teardown](#level-3-full-lab-teardown)
5. [Level 4: Host Network Cleanup (VLAN-segmented lab only)](#level-4-host-network-cleanup-vlan-segmented-lab-only)
6. [Verifying a Clean State](#verifying-a-clean-state)
7. [Cross-Lab Notes](#cross-lab-notes)

---

## When to Use Which Reset

| Situation | Use |
|---|---|
| You broke something during an attack/exercise, want to retry from a known point | [Snapshot revert](#level-1-snapshot-revert) |
| One VM misbehaves but the rest of the lab is fine | [Single-VM rebuild](#level-2-single-vm-rebuild) |
| You're done with a lab session and want VMs gone but may redeploy later | [Full lab teardown](#level-3-full-lab-teardown) |
| You're done for good and want the host network back to its pre-lab state | [Full lab teardown](#level-3-full-lab-teardown) + [Host network cleanup](#level-4-host-network-cleanup-vlan-segmented-lab-only) |

---

## Level 1: Snapshot Revert

Fastest option if you created snapshots during deployment (see
[Strategy 1: Snapshots for Quick Recovery](lab-deployment-workflow.md#strategy-1-snapshots-for-quick-recovery)
in the deployment guide).

```bash
virsh snapshot-list --all
virsh snapshot-revert --domain <vm-name> <snapshot-name>
```

No VMs are destroyed and no host network state changes. This does not undo
in-guest changes made after the snapshot was taken on other, non-reverted VMs
(for example, AD state changes replicated from a compromised DC).

## Level 2: Single-VM Rebuild

```bash
vagrant destroy -f <vm-name>
vagrant up <vm-name> --provider=libvirt
```

Or, for the AD labs, use the interactive manager instead of raw `vagrant`
commands so `LAB_PROFILE` is respected automatically:

```bash
python3 scripts/vagrant_manager.py
```

## Level 3: Full Lab Teardown

From the lab directory (`labs/security/active-directory/base/`,
`labs/security/active-directory/vlan-segmented/`, or
`labs/infrastructure/devops-linux-lab/`):

```bash
vagrant destroy -f
```

This removes all VMs and their disks for that lab. It does **not**:

- Remove Vagrant boxes cached on the host (`vagrant box list` /
  `vagrant box remove <box>` if you want to reclaim that space too).
- Remove any host-level networking created outside of Vagrant/libvirt's own
  network management — see [Level 4](#level-4-host-network-cleanup-vlan-segmented-lab-only)
  for the VLAN-segmented lab specifically.

## Level 4: Host Network Cleanup (VLAN-segmented lab only)

The VLAN-segmented Active Directory lab's
[`scripts/setup-vlans.sh`](../../../labs/security/active-directory/vlan-segmented/scripts/setup-vlans.sh)
creates VLAN interfaces, bridges, and can write persistent Netplan
configuration directly on the host. `vagrant destroy -f` has no awareness of
these and will not remove them.

If you want the host network back to its pre-lab state after tearing down
this specific lab:

```bash
# List VLAN bridges created by setup-vlans.sh
ip link show type bridge

# Remove a bridge (repeat per bridge)
sudo ip link set br-vlanXX down
sudo ip link delete br-vlanXX type bridge

# If setup-vlans.sh wrote a persistent Netplan file, remove or revert it,
# then re-apply
sudo netplan apply
```

See [`troubleshooting.md`](../../../labs/security/active-directory/vlan-segmented/docs/troubleshooting.md#host-network-cleanup-after-vagrant-destroy)
for the same steps in context with other VLAN-lab issues.

> [!NOTE]
> There is currently no automated teardown counterpart to `setup-vlans.sh`.
> This is a manual step until one exists — see
> [`roadmap.md`](../../project/roadmap.md) for planned automation work.

The Active Directory base lab and the DevOps/DevSecOps lab do not modify
host-level networking, so `vagrant destroy -f` alone is sufficient to return
the host to its pre-lab state for those two.

## Verifying a Clean State

After a full teardown, confirm nothing was left behind:

```bash
# No lab VMs should remain
vagrant global-status
virsh list --all

# (VLAN-segmented lab only) no lab bridges should remain
ip link show type bridge

# No orphaned libvirt networks
virsh net-list --all
```

## Cross-Lab Notes

- Tearing down one lab does not affect the others — each lab directory has
  its own `Vagrantfile` and VM scope.
- If you plan to redeploy the same lab shortly after, prefer
  [snapshot revert](#level-1-snapshot-revert) or
  [single-VM rebuild](#level-2-single-vm-rebuild) over a full teardown —
  both are faster than reprovisioning from scratch.
- For deployment-time validation after a rebuild, see
  [Post-Deployment Verification](lab-deployment-workflow.md#post-deployment-verification)
  in the deployment guide.
