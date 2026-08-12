# Emergency Lab-Isolation Runbook

This is a home-lab runbook for one specific scenario: you suspect a lab VM,
network, or bridge has reached the real internet, or become reachable from
your production/trusted network, when it shouldn't have.

**This is not an enterprise incident-response plan.** It doesn't cover
chain-of-custody, legal hold, or multi-person response coordination — see
[`security-scope.md`](../security-scope.md) for the authorized-use scope
this repository operates under, and
[`threat-model.md`](threat-model.md) for what each lab assumes is and
isn't isolated by design.

**Do not reconnect the lab to your network, or resume normal use, until you
have completed the [Validation checklist](#validation-checklist-before-reconnecting)
at the end of this document.**

---

## 1. Immediate containment

Act in this order — isolate first, investigate after. A lab that's still
connected keeps leaking or receiving traffic while you read logs.

1. **Stop the specific VM(s) you suspect**, without destroying evidence yet:
   ```bash
   # Graceful stop (preferred — preserves disk state for investigation)
   virsh shutdown <vm-name>

   # If it doesn't respond within a minute or two, force it off
   virsh destroy <vm-name>
   ```
   `virsh destroy` powers the VM off immediately (it does **not** delete
   the VM or its disk — despite the name, this is the libvirt equivalent
   of pulling the power cord, not a teardown). The AD Pentest Lab's
   `scripts/libvirt-manager.sh` wraps the same `virsh destroy` call under
   its **Force Stop / Destroy VM** menu option if you prefer the
   interactive tool.

2. **Disable the libvirt network(s) the lab uses**, so no other VM on that
   network can send or receive anything while you investigate:
   ```bash
   virsh net-list --all              # see which networks are active
   virsh net-destroy <network-name>  # stops the network immediately
   ```
   Network names to check, by lab (see
   [`threat-model.md`](threat-model.md) for what each one is for):
   - AD Pentest Lab: `vagrant0` by default (the `LAB_NET` Vagrant
     environment variable in `labs/security/active-directory/base/Vagrantfile`).
   - AD Pentest VLAN Lab: `br-wan`, `br-mgmt`, `br-workstations`,
     `br-servers`, `br-dmz`, `br-attacker`.
   - DevOps/DevSecOps Lab: the auto-detected `vagrant-libvirt` network
     (see `labs/infrastructure/devops-linux-lab/Vagrantfile`) plus any
     `forwarded_port` host bindings — check these are bound to
     `127.0.0.1`, not `0.0.0.0`, as documented in that lab's Vagrantfile.
   `libvirt-manager.sh`'s **Start / Stop Network** menu option wraps the
   same `virsh net-destroy` call.

3. **If you suspect the host's own network interface is bridged or
   misconfigured** (not just a libvirt virtual network), disconnect the
   host's physical network connection until you've confirmed the bridge
   configuration. Don't rely on software-level VM/network shutdown alone
   if you think the underlying host bridge itself is the problem.

---

## 2. Determine what actually happened

Do this **after** containment, not instead of it.

- **Check for unexpected external connections** from the host (not from
  inside a guest VM, which may be compromised):
  ```bash
  # Active connections involving libvirt/lab-related processes
  ss -tupn | grep -i qemu

  # Recent connection history, if your host logs it
  journalctl -u libvirtd --since "1 hour ago"
  ```
- **Check libvirt network state and NAT rules** to confirm which networks
  actually had outbound routing:
  ```bash
  virsh net-list --all
  virsh net-dumpxml <network-name>   # confirm forward mode: nat / none / route
  ```
  Every lab network in this repository is designed as `nat` (isolated
  outbound-only) or `none` (fully isolated, VLAN bridges in the VLAN lab)
  — see [`threat-model.md`](threat-model.md#repository-wide-assumptions).
  If a network you expected to be `none` shows `nat`, or a `nat` network
  shows a forwarding rule you don't recognize, that's the misconfiguration
  to focus on.
- **Check host firewall/NAT rules** for anything not explained by
  `libvirt`'s own managed rules:
  ```bash
  sudo iptables -L -n -v
  sudo iptables -t nat -L -n -v
  ```
- **Preserve logs and evidence before you destroy anything.** Copy, don't
  move, so the original is still available if something goes wrong during
  copy:
  ```bash
  mkdir -p ~/lab-incident-$(date +%Y%m%d-%H%M%S)
  cp -a /var/log/libvirt/ ~/lab-incident-*/         # libvirt/qemu logs
  virsh dumpxml <vm-name> > ~/lab-incident-*/vm-config.xml
  virsh net-dumpxml <network-name> > ~/lab-incident-*/network-config.xml
  ```
  If you plan to snapshot the VM disk itself for later analysis, do that
  **before** destroying the VM (see Step 4) — `virsh snapshot-create-as
  <vm> <snapshot-name>` (also available via `libvirt-manager.sh`'s
  **Create Snapshot** option) captures current disk state without
  requiring the VM to be powered on first.

---

## 3. Determine whether trusted systems were exposed

- Check whether the lab network was ever bridged (not just NAT'd) to your
  real LAN. Every Vagrantfile in this repo uses `private_network` or
  isolated libvirt networks by design — if you find a `public_network` or
  a manual bridge to your host's main interface that you didn't
  deliberately add, treat that as the likely root cause.
- Check your router/firewall's own logs or connected-device list for any
  lab VM's IP ranges (`172.28.x.x` for the AD labs, the auto-detected
  range for the DevOps lab) appearing outside the host running Vagrant.
- If you find evidence the lab *did* reach a trusted system or the real
  internet, treat every credential that lab VM had — including any real
  credentials you may have typed into it, not just the intentional lab
  credentials in `lab-credentials.md` — as compromised. See
  [Credential rotation](#4-credential-rotation) below.

---

## 4. Credential rotation

- **Lab credentials** (the intentional weak/training credentials in
  [`lab-credentials.md`](../../labs/security/active-directory/base/docs/lab-credentials.md))
  don't need rotation on their own — they're documented as disposable,
  lab-only, and never meant to be reused anywhere.
- **Rotate anything real** you may have typed into a lab VM by mistake:
  host SSH keys used to reach the lab, any API keys/tokens pasted into a
  guest for testing, and your own account password if you reused it
  anywhere in the lab (you shouldn't have, but if you did, rotate it now).
- **Rotate host-level credentials** if you have reason to believe the
  libvirt host itself — not just a guest VM — was reachable from outside:
  this repository's threat model explicitly assumes the virtualization
  host is fully trusted and not itself a target, so a host-level
  compromise is outside what any lab here is designed to contain.

---

## 5. When to destroy and rebuild vs. restore from snapshot

- **Destroy and rebuild** (`vagrant destroy -f <vm-name>` /
  `vagrant destroy -f` for the whole lab, then `vagrant up`) when you
  can't be confident about what changed on the VM, or when the VM is one
  of the intentionally-vulnerable targets anyway (rebuilding is fast and
  cheap, and this repo's labs are designed for exactly that workflow —
  see the **Verification and Cleanup** section of
  [`installation.md`](../setup/installation.md)).
- **Restore from a snapshot** only if you took one *before* the incident
  and are confident it predates whatever went wrong:
  ```bash
  virsh snapshot-list <vm-name>
  virsh snapshot-revert <vm-name> <snapshot-name>
  ```
- When in doubt, prefer destroy-and-rebuild. These labs are designed to
  be disposable; a lab VM is not a system you should ever need to trust
  the provenance of after a suspected breach.

---

## Validation checklist before reconnecting

Do not resume normal use of the lab, or reconnect it to any network,
until every item below is checked:

- [ ] The specific VM(s) involved have been powered off, and either
      rebuilt from a clean `vagrant up` or reverted to a known-good
      snapshot taken before the incident.
- [ ] `virsh net-dumpxml` for every network this lab uses shows the
      forward mode you expect (`nat` or `none`/isolated — see
      [`threat-model.md`](threat-model.md)), not something you didn't
      configure.
- [ ] Host firewall/NAT rules (`iptables -L`, `iptables -t nat -L`) show
      only rules you recognize as belonging to libvirt's managed
      networks.
- [ ] Any forwarded ports (DevOps lab) are confirmed bound to `127.0.0.1`,
      not `0.0.0.0`, by checking the relevant `vm.vm.network
      "forwarded_port"` lines in the Vagrantfile against `ss -tulpn` on
      the host.
- [ ] Any real (non-lab) credentials that may have touched the affected
      VM have been rotated.
- [ ] You've identified — not just guessed at — the root cause (e.g., a
      manually added bridge, a misconfigured `public_network` line, a
      host firewall rule that predates the lab). If you can't identify a
      root cause, don't reconnect; the same issue will likely recur.
- [ ] Logs and any disk snapshots relevant to the incident have been
      preserved somewhere outside the VM you're about to rebuild.

Only after every box above is checked should you run `vagrant up` again
or reconnect the lab's host to your normal network.
