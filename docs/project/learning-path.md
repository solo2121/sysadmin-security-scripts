# Learning Path

Start here if you're new to **security-engineering-lab**. This page tells you
which lab to deploy first based on what you want to learn, in what order,
and which docs to read at each step. Full reference material lives in the
[Documentation Hub](../README.md) — this page is just the on-ramp.

## Step 0: Prerequisites

Before deploying anything, read [`installation.md`](../setup/installation.md) and
run [`scripts/check-prerequisites.sh`](../../scripts/check-prerequisites.sh) to
confirm your host has the CPU, RAM, and virtualization support each lab
needs. All three labs are Linux-host-only (KVM/libvirt) — see
[Known Limitations](../../README.md#known-limitations) before you start.

Worth five minutes before you deploy anything: [`architecture/threat-model.md`](../architecture/threat-model.md) explains *why* each lab is vulnerable the way it is — the assumed attacker, starting access, and goal per lab — rather than leaving you to infer it from the Vagrantfiles.

## Step 1: Pick your track

You don't need to run all three labs. Pick the one that matches your goal.

### Track A — Active Directory & offensive security

**Goal:** learn Windows enterprise attack paths from zero credentials to
Domain Admin.

1. Deploy [Lab 1 – Active Directory Pentest Lab](../../labs/security/active-directory/base/README.md).
2. Work through [`attack-guide.md`](../../labs/security/active-directory/base/docs/attack-guide.md)
   in order — it's numbered (recon → enumeration → initial access → credential
   attacks → AD CS → modern AD attacks), not a reference dump.
3. Read the full walkthrough:
   [domain-compromise-walkthrough.md](../guides/security/domain-compromise-walkthrough.md).
4. Once comfortable with the flat network, move to
   [Lab 2 – AD Pentest VLAN / Enterprise Segmentation](../../labs/security/active-directory/vlan-segmented/README.md)
   for network-segmentation-aware attack paths and lateral-movement constraints.

### Track B — DevOps & DevSecOps

**Goal:** learn Kubernetes platform engineering, GitOps, and runtime security.

1. Deploy [Lab 3 – DevSecOps / DevOps Lab](../../labs/infrastructure/devops-linux-lab/README.md)
   (start with `LAB_PROFILE=minimal` if you're short on resources).
2. Read [`devops-workflow.md`](../../labs/infrastructure/devops-linux-lab/docs/devops-workflow.md)
   for the day-to-day operational flow.
3. Go deeper with
   [`guides/infrastructure/devops-platform-overview.md`](../guides/infrastructure/devops-platform-overview.md)
   (quick path), then
   [`complete-devops-platform-guide.md`](../guides/infrastructure/complete-devops-platform-guide.md)
   (adds Terraform, ArgoCD/GitOps, image scanning, canary deployments).
4. For the security side specifically, see
   [`kubernetes-security-hardening.md`](../guides/infrastructure/kubernetes-security-hardening.md).

### Track C — AI / LLM security

**Goal:** practice prompt injection, RAG poisoning, and other LLM-specific attacks.

1. Deploy Lab 1 (Track A, step 1) — the LLM platform (`llm01`) is part of it.
2. In `attack-guide.md`, jump to the AI/LLM security section for the full
   list of vulnerable endpoints and attack techniques.

### Track D — Standalone scripting practice

**Goal:** practice individual sysadmin/security scripts without deploying a
full VM environment.

- Browse [`tools/security/`](../../tools/security/README.md) (recon, exploitation, audit,
  network, wireless tooling) and [`tools/sysadmin/`](../../tools/sysadmin/README.md)
  (monitoring, hardening, utilities). Each script is
  self-contained and documented independently of the labs.

## Step 2: Go deeper

Once you've finished a track, the [Documentation Hub](../README.md) indexes
everything else — architecture docs, troubleshooting, the full changelog,
and every guide referenced above.

## If you get stuck

Check [`troubleshooting.md`](../setup/troubleshooting.md) first, then
[open an issue](https://github.com/solo2121/security-engineering-lab/issues) if
your problem isn't covered.
