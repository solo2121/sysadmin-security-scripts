# Security & Authorized Use Scope

## Legal & Ethical Framework

This repository contains **educational security content** — offensive and defensive techniques for learning purposes only.

**Your responsibility:** Use this content only in authorized, controlled environments (sandboxed VMs, test labs you own).

---

## Authorized Uses

### Personal Learning
- Running labs on your own hardware or VMs
- Pentesting your own infrastructure with written permission
- Studying attack and defense techniques in controlled environments
- Practicing for security certifications (OSCP, CEH, GIAC)

### Educational Organizations
- University security courses
- Bootcamp environments (with student consent)
- Corporate security training (internal use only)
- CTF (Capture The Flag) competitions

### Professional Security Testing
- Authorized penetration testing engagements (with written contract)
- Red team exercises (with scope agreement)
- Security research within lab boundaries
- Infrastructure hardening projects

---

## Prohibited Uses

### Illegal Activity
 - Unauthorized access to any system or network
 - Credential theft or privilege escalation on systems you don't own
 - Denial of service attacks
 - Data exfiltration or privacy violations
 - Creating ransomware or destructive payloads

### Unethical Testing
 - Testing third-party systems without explicit written permission
 - Social engineering individuals without authorization
 - Exposing vulnerabilities publicly (without coordinated disclosure)
 - Circumventing access controls on shared infrastructure

---

## Lab Environment Boundaries

### Content Included

| Category | Included | Notes |
|----------|----------|-------|
| **AD Attacks** | Yes | Kerberos, SMB relay, lateral movement — lab environment only |
| **Network Exploitation** | Yes | VLAN hopping, ARP spoofing — isolated network labs only |
| **Credential Attacks** | Yes | Brute force, hash cracking — dictionary attacks, not rainbow tables |
| **Web Exploitation** | Yes | SQL injection, XSS — vulnerable test apps only |
| **Post-Exploitation** | Yes | Persistence, privilege escalation — lab VMs only |
| **Wireless Testing** | Limited | WPA2 cracking in controlled labs only; never on public networks |

### Content NOT Included

| Category | Excluded | Reason |
|----------|----------|--------|
| Malware samples | No | Dangerous; use VirusTotal or malware sandboxes instead |
| Zero-day exploits | No | Unpatched vulnerabilities are out of scope |
| Worms / self-replicating code | No | Too dangerous for educational distribution |
| Backdoored applications | No | Supply chain attacks require responsible disclosure |
| Keyloggers / spyware | No | Surveillance tools forbidden |

---

## Lab Isolation Requirements

Before running any lab, ensure:

### Network Isolation
 - Lab VMs are on isolated virtual networks (Libvirt / Vagrant networks only)
 - No connection to corporate or shared networks
 - Lab network is NOT bridged to production infrastructure
 - Host system is protected by firewall when labs are running

### Credential Management
 - No production credentials stored in lab files
 - Lab credentials are weak/throwaway (only for lab VMs)
 - `.env` files are in `.gitignore` (never commit secrets)
 - Use `ansible-vault` for sensitive playbook data

### Access Control
 - Only authorized users (you) can access lab VMs
 - Lab VMs cannot be exposed to the internet
 - SSH keys for labs are local to your machine only
 - Lab data is encrypted at rest if stored on encrypted volumes

---

## Security Warnings

### Active Directory Attacks Lab
```
⚠️ WARNING: This lab contains techniques for compromising Active Directory domains.

This content is ONLY for:
- Internal security testing within your organization
- Educational environments with explicit authorization
- Personal learning on non-production infrastructure

DO NOT use against:
- Production Active Directory environments without written approval
- Organizations' systems without a signed penetration testing contract
- Any system you don't own or have explicit permission to test
```

### VLAN & Network Exploitation
```
WARNING: This lab includes network isolation bypass and VLAN hopping techniques.

Authorized use:
- Validating network segmentation controls you manage
- Security research in isolated lab networks

Prohibited:
- Testing shared corporate networks
- VLAN hopping on networks you don't manage
- Any network traffic manipulation without explicit authorization
```

### Credential Attacks
```
⚠️ WARNING: This lab includes brute force, credential spraying, and hash cracking.

Authorized use:
- Testing account security on systems you manage
- Security assessments with written approval
- Educational practice in isolated labs

Prohibited:
- Attacking production systems
- Unauthorized credential spraying
- Distributing pre-computed hash databases
```

---

## 📋 Checklist Before Running Labs

Before launching ANY security lab:

- [ ] I own or have written permission to test this infrastructure
- [ ] Lab VMs are on isolated networks (not connected to production)
- [ ] No production credentials are in lab configuration files
- [ ] I understand the attack/defense techniques in this lab
- [ ] Lab data is confidential and won't be shared publicly
- [ ] My organization's security team is aware of this testing (if applicable)
- [ ] I will not use this lab for unauthorized access to other systems

**If you cannot check all boxes, stop and seek proper authorization first.**

---

## 🔄 Responsible Disclosure

If you discover a vulnerability in this repository (e.g., security issue, malicious code):

1. **Do NOT open a public GitHub issue**
2. **Report privately** to: `security@solo2121.com`
3. **Include**:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Your contact information
4. **Expected response**: Within 3 business days

See `SECURITY.md` for full vulnerability reporting policy.

---

## 🏫 Teaching This Content

If you're an educator using this repository:

### Required
- ✅ Students sign acceptable use policy before accessing labs
- ✅ Labs are isolated from institutional networks
- ✅ Clear learning objectives for each exercise
- ✅ Assessment focuses on defense/remediation, not just attacks
- ✅ Content is covered in classroom context (not independent)

### Recommended
- 🎯 Combine attack labs with corresponding defense labs
- 🎯 Use labs for red team / blue team exercises
- 🎯 Teach threat modeling and risk assessment alongside techniques
- 🎯 Require students to demonstrate ethical reasoning
- 🎯 Document attendance and training records

### Not Allowed
- ❌ Providing lab access without supervision
- ❌ Using labs to teach only offensive techniques (no defense component)
- ❌ Allowing labs to be used for unauthorized testing
- ❌ Sharing lab VMs or credentials with external parties

---

## 📚 References

- **Ethical Hacking**: EC-Council Code of Ethics
- **Penetration Testing**: PTES (Penetration Testing Execution Standard)
- **Responsible Disclosure**: HackerOne & OWASP guidelines
- **Security Training**: SANS Institute ethical guidelines
- **Legal Framework**: Computer Fraud and Abuse Act (CFAA), local cybercrime laws

---

## Questions?

If you're unsure about authorized use, **ask first**:
- Contact repository maintainer at `security@solo2121.com`
- Consult your organization's security or legal team
- Review local cybercrime laws

**When in doubt, don't.**

---

## Acknowledgment

By using this repository, you acknowledge:
- You understand the security implications
- You will use this content ethically and legally
- You take responsibility for your actions
- You will report security issues responsibly
