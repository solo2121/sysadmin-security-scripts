# Security Policy

This document explains the security support scope for the sysadmin-security-lab and how to report vulnerabilities responsibly.

---

## Supported Environments

This repository is actively maintained and tested on:

- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS
- Debian 12

Other Debian-based systems may work, but they are not officially supported.

---

## Reporting a Vulnerability

If you discover a security issue in this repository, such as accidentally committed credentials, a script that could cause unintended harm, or a misconfiguration in the lab environments, please report it responsibly.

Please do not open a public issue for security-sensitive reports.

### Preferred reporting methods

1. Send a detailed report to **security@solo2121.com**.
   Include your name, a description of the issue, and steps to reproduce it.
2. If email is unavailable, submit a confidential [GitHub Security Advisory](https://github.com/solo2121/sysadmin-security-lab/security/advisories/new).

---

## Response Policy

- All reports will be acknowledged within **3 business days**.
- A fix or mitigation will be provided within **7 business days** when applicable.
- Reporters will be credited in release notes unless anonymity is requested.

---

## Intentional Vulnerabilities

This lab contains intentional vulnerabilities for educational and authorized research purposes. These are expected and by design.

Please do not report the following as security issues:

- Weak credentials in [`lab-credentials.md`](labs/security/ad-pentest/docs/lab-credentials.md).
- AD CS misconfigurations such as ESC1–ESC9.
- Intentional ACL abuse paths.
- LLM endpoints without authentication.
- LocalStack AWS services configured with permissive IAM.

---

## Security Best Practices for Users

- Run all lab environments in an isolated VM or network.
- Never expose Vagrant lab ports to public IP addresses.
- Keep your host OS updated and follow standard security hygiene.
- Treat all credentials in this repository as lab-only and never reuse them on real systems.

---

## License

[MIT License](LICENSE) — Copyright (c) 2023–2026 Miguel A. Carlo