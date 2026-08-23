# Windows Server Hardening Lab — Credential Reference

## Intentional Training Credentials — Read First

This file documents credentials created exclusively for an isolated,
locally-hosted training lab.

These accounts and passwords are:

- Not real.
- Not reused anywhere.
- Stronger than the AD pentest lab's intentionally weak baseline, but
  still not production-strength — do not model production credential
  design on anything below.

Do not replicate these patterns in production environments.

---

## Domain Information

```yaml
DOMAIN_INFO:
  domain_name: hardened.local
  netbios_name: HARDENED
  functional_level: Windows Server 2022 (default for a fresh forest)
```

## Local/Built-in Accounts

| Account | Password | Notes |
|---|---|---|
| `vagrant` (local admin, `dc01-hardened`) | `vagrant` initially, provisioner updates via `VAGRANT_UPDATED_PASSWORD` env var (default `Vagrant123!`) | Used by Vagrant/WinRM for provisioning only |
| `Administrator` (domain, post AD-promotion) | `Passw0rd!` (Safe Mode Administrator password set during `Install-ADDSForest`) | Becomes the initial Domain Admin after promotion |

## Domain Password Policy (post-hardening)

```yaml
PASSWORD_POLICY:
  min_length: 14
  complexity_enabled: true
  max_password_age_days: 90
  min_password_age_days: 1
  lockout_threshold: 5
  lockout_duration_minutes: 15
  lockout_observation_window_minutes: 15
```

This is deliberately different from the AD pentest lab's policy (complexity
disabled, zero-length minimum) — see
[`hardening-guide.md` §9](hardening-guide.md#9-domain-password-policy-hardened)
for why.

## win-member (LAB_PROFILE=full)

| Account | Password | Notes |
|---|---|---|
| `vagrant` (local admin) | Same as `dc01-hardened` | Used for provisioning only |
| Domain join uses `HARDENED\Administrator` | `Passw0rd!` | Same account as above, used only during `Add-Computer` |

## Usage Notes

- No additional service accounts or user population are seeded in this
  MVP — see [`README.md` "Known limitations"](../README.md#known-limitations).
- If you extend this lab with seeded users or service accounts, document
  them here following the same table format the AD pentest lab uses in its
  own [`lab-credentials.md`](../../active-directory/base/docs/lab-credentials.md),
  and make sure any password-like string is reviewed against
  `.secrets.baseline` before committing (see root
  [`README.md`](../../../../README.md) CI section and
  `.pre-commit-config.yaml` for the detect-secrets hook used across this
  repo).
