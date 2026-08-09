# DC01 Deployment Validation

This document records a successful automated deployment and configuration
validation run of the DC01 Active Directory domain controller in the
[AD Pentest Lab](../README.md), using the lab's `Vagrantfile`
(`config.vm.define "dc01"`).

The deployment process covers Windows configuration, Active Directory
deployment, security scenario preparation, network isolation, and final
validation checks, in the order they run as Vagrant provisioners.

---

## Deployment Progress

```text
✓ WinRM Bootstrap
✓ Static IP Configuration
✓ Windows Defender Lab Baseline
✓ Basic Active Directory Setup
✓ Post-Reboot Verification
✓ Active Directory Domain Controller Promotion
✓ WinRM Stabilization
✓ Complete Domain Controller Configuration
✓ Security Scenario Configuration
✓ Network Isolation
✓ Final Health Check
```

---

## Phase 0: WinRM Bootstrap

```text
PHASE 0: WINRM BOOTSTRAP

WinRM service configured
Firewall rules updated
Remote management enabled

[OK] WinRM bootstrap complete
```

---

## Static IP Configuration

```text
==============================================
FIXED STATIC IP CONFIGURATION
==============================================

[OK] Found non-NAT network adapter
[OK] Static IP configured: 172.28.128.21
[OK] DNS configured to DC01
[OK] Address state: Preferred
[OK] Windows Firewall configured

==============================================
STATIC IP CONFIGURATION COMPLETE
==============================================
```

---

## Windows Defender Lab Baseline

```text
==============================================
WINDOWS DEFENDER LAB BASELINE
==============================================

[OK] Registry keys configured
[OK] Defender lab baseline applied

==============================================
BASELINE CONFIGURATION COMPLETE
==============================================
```

---

## Phase 1: Basic Setup

```text
PHASE 1: BASIC SETUP

[OK] Active Directory Domain Services installed
[OK] Required Windows features installed

[SUCCESS] Phase 1 complete
```

---

## Phase 2: Post-Reboot Verification

```text
PHASE 2: POST-REBOOT VERIFICATION

WinRM service is running
WinRM remote management is configured

[SUCCESS] Phase 2 complete
```

---

## Phase 3: Active Directory Promotion

```text
PHASE 3: AD PROMOTION

[OK] Domain Controller promotion completed

Reboot required to complete configuration.

[SUCCESS] AD promotion complete
```

---

## Phase 4: WinRM Stabilization

```text
Stabilizing WinRM after AD promotion...

[OK] WinRM stabilized after AD promotion
```

---

## Phase 5: Complete Domain Controller Configuration

```text
PHASE 5: COMPLETE DC CONFIGURATION

[OK] AD domain detected: lab.local
[OK] Domain Controller configured: dc01.lab.local

[OK] Created 45+ realistic user accounts
[OK] Created enterprise-style user groups
[OK] Assigned security group memberships
[OK] Configured manager relationships

[OK] Created service accounts
[OK] Configured Service Principal Names (SPNs)

[SUCCESS] Complete DC configuration finished
```

---

## Active Directory Lab Environment

The automated deployment creates a realistic enterprise Active Directory
environment.

```text
Domain:
    lab.local

Domain Controller:
    dc01.lab.local

Users:
    45+ enterprise-style accounts

Groups:
    Department groups
    Security groups
    Administrative groups

Service Accounts:
    SQL
    Exchange
    SharePoint
    Backup
    Monitoring
    Web services
```

---

## Security Scenario Configuration

The environment intentionally includes vulnerable configurations and attack
simulation scenarios for security testing, penetration testing practice, and
defensive analysis.

All vulnerable configurations are isolated to this lab environment and are
not intended for production use.

### Configured Security Lab Scenarios

```text
[OK] ZeroLogon (CVE-2020-1472)
[OK] PetitPotam (CVE-2021-36942)
[OK] Resource-Based Constrained Delegation (RBCD)
[OK] Enhanced PrintNightmare
[OK] SMB Signing Disabled
[OK] LLMNR/NBNS Poisoning Enabled

[OK] Kerberoasting targets created
[OK] Service Principal Names configured
[OK] Vulnerable service accounts created
```

### Attack Paths Included

```text
1. AS-REP Roasting
2. Kerberoasting
3. Constrained Delegation
4. GPP Credential Extraction
5. SMB Relay
6. ZeroLogon
7. PetitPotam
8. Shadow Credentials
9. NoPac
10. Resource-Based Constrained Delegation
11. PrintNightmare
12. AD CS ESC9
13. LLMNR/NBNS Poisoning
14. gMSA Permission Abuse
15. ADIDNS Abuse (configured where supported)
```

> Certificate-authority-specific paths (ESC1, ESC3, ESC4, ESC6, ESC7, ESC8)
> are provisioned separately on `ca01-esc` (172.28.128.25) — see
> [`attack-guide.md`](attack-guide.md) for the full, combined attack-path list.

---

## Phase 6: Cleanup

```text
PHASE 6: CLEANUP

[SUCCESS] Cleanup phase complete
```

---

## Network Isolation

The DC01 server is isolated from the Internet while maintaining Vagrant
management connectivity.

```text
==============================================
DISABLING INTERNET GATEWAY - DC01
==============================================

[OK] NAT adapter detected
[OK] Default gateway removed
[OK] Internet access disabled
[OK] Lab network connectivity verified

==============================================
INTERNET ISOLATION COMPLETE
==============================================
```

```text
Lab Network:
    172.28.128.0/24

Internet:
    Disabled

Vagrant Management:
    Available through NAT
```

---

## Final DC01 Health Check

```text
==============================================
HEALTH CHECK - DC01
==============================================

[CHECK] VM responsiveness: OK
[CHECK] WinRM service: Running
[CHECK] Connectivity to DC: OK

==============================================
HEALTH CHECK COMPLETE
==============================================
```

You can reproduce this check manually once `vagrant up dc01` finishes:

```bash
# From labs/security/ad-pentest/
vagrant winrm-command "Test-Path C:\DC-FINAL.txt" --elevated
nslookup dc01.lab.local 172.28.128.21
```

---

## Educational Security Notice

This Active Directory environment intentionally contains insecure
configurations for:

- Penetration testing practice
- Attack-chain simulation
- Blue team detection exercises
- Security research and training

This lab is designed to run in an isolated environment only.

Do not deploy these configurations in production environments.

Destroy the environment when finished:

```bash
vagrant destroy
```
