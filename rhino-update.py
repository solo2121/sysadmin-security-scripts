#!/usr/bin/env python3
"""
rhino-update – colourful one-shot update & cleanup for Rhino Linux
Requires sudo.
"""

import os
import subprocess
import sys
from typing import List

# ── ANSI helpers ----------------------------------------------------------- #
RESET   = "\033[0m"
BOLD    = "\033[1m"
RED     = "\033[31m"
GREEN   = "\033[32m"
YELLOW  = "\033[33m"
BLUE    = "\033[34m"
MAGENTA = "\033[35m"
CYAN    = "\033[36m"

def ok(msg: str) -> None:
    print(f"{GREEN}✅ {msg}{RESET}")

def warn(msg: str) -> None:
    print(f"{YELLOW}⚠️  {msg}{RESET}")

def err(msg: str) -> None:
    print(f"{RED}❌ {msg}{RESET}")

def info(msg: str) -> None:
    print(f"{CYAN}ℹ️  {msg}{RESET}")

def title(msg: str) -> None:
    print(f"\n{MAGENTA}{BOLD}🦏 {msg}{RESET}")

# ── Core logic ------------------------------------------------------------- #
def run(cmd: List[str], description: str = "") -> None:
    if description:
        print(f"\n{BLUE}{BOLD}➜ {description}{RESET}")
    print(f"{CYAN}▶ {' '.join(cmd)}{RESET}")

    try:
        subprocess.run(cmd, check=True, stdout=sys.stdout, stderr=sys.stderr)
    except subprocess.CalledProcessError as exc:
        err(f"Command failed (exit code {exc.returncode})")
        print(f"{RED}Failed: {' '.join(exc.cmd)}{RESET}", file=sys.stderr)
        sys.exit(exc.returncode)
    except FileNotFoundError as exc:
        err(f"Command not found: {exc.filename}")
        sys.exit(127)

def main() -> None:
    if os.geteuid() != 0:
        err("This script must be run as root (sudo).")
        sys.exit(1)

    title("Rhino Linux Update & Cleanup")

    try:
        run(["rpk", "update", "-y"], "Updating all packages …")
        run(["rpk", "cleanup", "-y"], "Purging orphaned packages …")

    except KeyboardInterrupt:
        warn("Operation cancelled by user.")
        sys.exit(130)

    ok("Rhino Linux is up-to-date and squeaky-clean!")

if __name__ == "__main__":
    main()
