"""
tools.lib — Shared utilities for sysadmin-security-lab command-line tools.

This package centralizes cross-cutting concerns that were previously
duplicated across the individual scripts in ``tools/security/`` and
``tools/sysadmin/``:

- ``cli``        — common argparse scaffolding and dependency checks
- ``logging``    — consistent, colorized console logging setup
- ``subprocess`` — safe wrappers around subprocess execution
- ``validators`` — input validation (IP ranges, hostnames, ports, files)
- ``banner``     — shared CLI banner/header rendering

Each module is intentionally dependency-light (standard library only)
so that individual tools remain runnable without extra installs beyond
what they already require (e.g. ``requests``, ``scapy``).

Nothing in this package performs network scanning, exploitation, or
credential access on its own — it only provides plumbing that the
tools in ``tools/security/`` and ``tools/sysadmin/`` build on.
"""

from __future__ import annotations

__all__ = ["cli", "logging", "subprocess", "validators", "banner"]

__version__ = "0.1.0"
