#!/usr/bin/env python3
"""
enum4linux-menu.py
A simple, interactive wrapper for enum4linux.

Tested with Python 3.7+
Requires: enum4linux installed and in $PATH
"""

import argparse
import os
import shlex
import subprocess
import sys
from typing import List, Tuple

# ------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------
BANNER = r"""
 ____ ____ ____ ____ ____ ____ ____ ____ ____ ____ ____ ____ ____ ____
||e |||n |||u |||m |||4 |||l |||i |||n |||u |||x |||  |||M |||E |||N |||U ||
||__|||__|||__|||__|||__|||__|||__|||__|||__|||__|||__|||__|||__|||__|||__||
|/__\|/__\|/__\|/__\|/__\|/__\|/__\|/__\|/__\|/__\|/__\|/__\|/__\|/__\|/__\|
Interactive wrapper for the classic SMB enumeration tool.
"""

# ------------------------------------------------------------------
# Available enum4linux switches
# (description, short switch, long switch)
# ------------------------------------------------------------------
OPTIONS: List[Tuple[str, str, str]] = [
    ("Do everything (-a)",                       "-a", ""),
    ("Enumerate users (-U)",                     "-U", ""),
    ("Enumerate groups (-G)",                    "-G", ""),
    ("Enumerate shares (-S)",                    "-S", ""),
    ("Enumerate passwords policy (-P)",          "-P", ""),
    ("Enumerate OS information (-O)",            "-O", ""),
    ("Enumerate printers (-i)",                  "-i", ""),
    ("Enumerate LSA Policy info (-L)",           "-L", ""),
    ("Enumerate RID cycling (RID range)",        "-r", ""),
    ("Enumerate via brute-force share names (-b", "-b", ""),
    ("Enumerate via brute-force user names (-B", "-B", ""),
    ("Enumerate via null session (-n)",          "-n", ""),
]

# ------------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------------
def clear_screen() -> None:
    os.system("cls" if os.name == "nt" else "clear")

def print_banner() -> None:
    print(BANNER)

def check_enum4linux() -> bool:
    """Return True if enum4linux is in $PATH."""
    return subprocess.run(["which", "enum4linux"], stdout=subprocess.DEVNULL).returncode == 0

def ask(prompt: str, valid: List[str]) -> str:
    """Ask until a valid choice is given."""
    while True:
        choice = input(prompt).strip().lower()
        if choice in valid:
            return choice

# ------------------------------------------------------------------
# Main interactive menu
# ------------------------------------------------------------------
def interactive_menu(target: str, custom_options: List[str]) -> None:
    selected = set()

    while True:
        clear_screen()
        print_banner()

        print(f"\nTarget: {target}\n")
        print("Select the checks you want to run. 0 to launch enum4linux.\n")

        for idx, (desc, short, long) in enumerate(OPTIONS, 1):
            marker = "[✓]" if short in selected else "[ ]"
            print(f"{idx:>2}. {marker} {desc}")

        choice = input("\nToggle option (1-{}) or 0 to run: ".format(len(OPTIONS))).strip()

        if choice == "0":
            break
        if choice.isdigit() and 1 <= int(choice) <= len(OPTIONS):
            short_switch = OPTIONS[int(choice) - 1][1]
            if short_switch in selected:
                selected.remove(short_switch)
            else:
                selected.add(short_switch)

    # Build final command line
    cmd = ["enum4linux"] + custom_options + list(selected) + [target]

    print("\n[+] Command that will be executed:")
    print("    " + " ".join(shlex.quote(c) for c in cmd))

    confirm = ask("\nProceed? [y/N]: ", ["y", "n", ""])
    if confirm == "y":
        print("\n" + "=" * 60)
        subprocess.run(cmd)
    else:
        print("\nAborted.")

# ------------------------------------------------------------------
# 5. CLI entry point
# ------------------------------------------------------------------
def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Interactive wrapper around enum4linux",
        formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument("-t", "--target", required=True,
                        help="Target IP address / hostname")
    parser.add_argument("-u", "--user", metavar="USER",
                        help="Username (if authentication is needed)")
    parser.add_argument("-p", "--password", metavar="PASS",
                        help="Password (if authentication is needed)")
    parser.add_argument("-d", "--domain", metavar="DOMAIN",
                        help="Domain / workgroup")
    parser.add_argument("--timeout", type=int, default=30,
                        help="Connection timeout in seconds (default: 30)")
    return parser.parse_args()

def build_custom_options(args: argparse.Namespace) -> List[str]:
    opts = []
    if args.user:
        opts += ["-u", args.user]
    if args.password:
        opts += ["-p", args.password]
    if args.domain:
        opts += ["-w", args.domain]
    if args.timeout:
        opts += ["-T", str(args.timeout)]
    return opts

def main() -> None:
    if not check_enum4linux():
        print("[!] enum4linux not found in $PATH.  Please install it first.")
        sys.exit(1)

    args = parse_args()
    custom_options = build_custom_options(args)
    interactive_menu(args.target, custom_options)

if __name__ == "__main__":
    main()
