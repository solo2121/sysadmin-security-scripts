#!/usr/bin/env python3
"""
pacstall-maintenance.py
Python 3 maintenance script: update, upgrade, clean cache, remove orphans.
"""

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import List, Set


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def run(cmd: List[str], *, check: bool = True, **kw):
    cmd_str = " ".join(cmd)
    print(f":: Running: {cmd_str}")
    return subprocess.run(cmd, check=check, **kw)


def pacstall_installed_packages() -> List[str]:
    result = run(["pacstall", "-L"], capture_output=True, text=True)
    return [p.strip() for p in result.stdout.splitlines() if p.strip()]


def pacstall_dependencies(pkg: str) -> Set[str]:
    try:
        result = run(
            ["pacstall", "-S", pkg],
            check=False,
            capture_output=True,
            text=True,
        )
    except Exception:
        return set()
    deps = set()
    for line in result.stdout.splitlines():
        line = line.strip()
        if line and not line.startswith("#") and line != pkg:
            deps.add(line)
    return deps


def collect_needed_packages(installed: List[str]) -> Set[str]:
    needed = set()
    visited = set()

    def walk(pkg: str):
        if pkg in visited:
            return
        visited.add(pkg)
        needed.add(pkg)
        for dep in pacstall_dependencies(pkg):
            walk(dep)

    for p in installed:
        walk(p)
    return needed


def remove_orphans() -> None:
    print("==> Detecting orphaned Pacstall packages …")
    installed = pacstall_installed_packages()
    needed = collect_needed_packages(installed)
    orphans = [p for p in installed if p not in needed]

    if not orphans:
        print("    No orphaned packages found.")
        return

    print(f"    Orphans detected: {', '.join(orphans)}")
    for pkg in orphans:
        run(["sh", "-c", f"yes | pacstall -R {pkg}"])


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    if os.geteuid() != 0:
        print("This script must be run as root (sudo).", file=sys.stderr)
        sys.exit(1)

    print("==> Updating pacstall …")
    run(["pacstall", "-U"])

    print("==> Upgrading installed pacstall packages …")
    run(["pacstall", "-Up"])

    cache_dir = Path("/var/cache/pacstall")
    if cache_dir.is_dir():
        print("==> Cleaning cached .deb files …")
        removed = 0
        for deb in cache_dir.glob("*.deb"):
            deb.unlink()
            removed += 1
        print(f"    Removed {removed} cached .deb files from {cache_dir}")
    else:
        print("    No cache directory found – nothing to clean.")

    remove_orphans()
    print("==> Pacstall maintenance complete.")


if __name__ == "__main__":
    main()
# ---------------------------------------------------------------------------
# End of pacstall-maintenance.py
# ---------------------------------------------------------------------------