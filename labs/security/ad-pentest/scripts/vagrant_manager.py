#!/usr/bin/env python3
"""
vagrant_manager.py

Interactive manager for the lab's Vagrant VMs. Replaces the previous
vagrant-manager.sh (manual ANSI codes / bash case-statement TUI) with a
small, testable Python CLI built on `rich`.

Usage:
    python3 vagrant_manager.py            # interactive menu
    python3 vagrant_manager.py --list     # print discovered VMs and exit
    python3 vagrant_manager.py up web db  # run 'vagrant up' on specific VMs
    python3 vagrant_manager.py status     # show status table and exit

Requires: rich (pip install rich)
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.prompt import Prompt, Confirm

console = Console()

VAGRANTFILE_CANDIDATES = ["Vagrantfile"]

ACTIONS = {
    "1": ("up", "Bring VM(s) up"),
    "2": ("halt", "Halt VM(s)"),
    "3": ("reload", "Reload VM(s)"),
    "4": ("provision", "Re-run provisioning"),
    "5": ("destroy", "Destroy VM(s)"),
    "6": ("ssh", "SSH into a VM"),
    "7": ("status", "Show status"),
    "q": ("quit", "Quit"),
}


@dataclass
class VmAction:
    name: str
    ok: bool
    detail: str = ""


def find_vagrantfile() -> Path | None:
    """Look for a Vagrantfile in cwd, then walk up to the repo root."""
    here = Path.cwd()
    for candidate in [here, *here.parents]:
        for name in VAGRANTFILE_CANDIDATES:
            f = candidate / name
            if f.exists():
                return f
    return None


def discover_vms(vagrantfile: Path) -> list[str]:
    """
    Parse VM names out of the Vagrantfile.

    Matches the common `config.vm.define "name"` pattern. If nothing is
    found, falls back to asking `vagrant status` for machine names, which
    also works and doesn't depend on Vagrantfile formatting.
    """
    text = vagrantfile.read_text(errors="ignore")
    names = re.findall(r'config\.vm\.define\s+["\']([\w\-]+)["\']', text)
    if names:
        return names
    return discover_vms_from_status()


def discover_vms_from_status() -> list[str]:
    if not shutil.which("vagrant"):
        return []
    try:
        result = subprocess.run(
            ["vagrant", "status"],
            capture_output=True,
            text=True,
            check=False,
        )
    except FileNotFoundError:
        return []
    names = []
    for line in result.stdout.splitlines():
        # Typical line: "web                       not created (virtualbox)"
        m = re.match(r"^([\w\-]+)\s+\S.*\(.*\)$", line.strip())
        if m:
            names.append(m.group(1))
    return names


def require_vagrant() -> None:
    if not shutil.which("vagrant"):
        console.print(
            "[bold red]Error:[/bold red] 'vagrant' was not found on PATH. "
            "Install Vagrant or activate the environment that provides it."
        )
        sys.exit(1)


def run_vagrant(action: str, vm: str | None, extra_args: list[str] | None = None) -> VmAction:
    """Run a vagrant subcommand, streaming output live, and return a result."""
    cmd = ["vagrant", action]
    if vm:
        cmd.append(vm)
    if extra_args:
        cmd.extend(extra_args)

    label = vm or "(all)"
    console.rule(f"[bold cyan]vagrant {action}[/bold cyan] {label}")
    try:
        result = subprocess.run(cmd)
    except FileNotFoundError:
        return VmAction(name=label, ok=False, detail="vagrant not found")
    except KeyboardInterrupt:
        console.print("[yellow]Interrupted by user.[/yellow]")
        return VmAction(name=label, ok=False, detail="interrupted")

    ok = result.returncode == 0
    detail = "" if ok else f"exit code {result.returncode}"
    return VmAction(name=label, ok=ok, detail=detail)


def print_results(results: list[VmAction]) -> None:
    table = Table(title="Result", show_lines=False)
    table.add_column("VM")
    table.add_column("Status")
    table.add_column("Detail")
    for r in results:
        status = "[green]OK[/green]" if r.ok else "[red]FAILED[/red]"
        table.add_row(r.name, status, r.detail)
    console.print(table)


def show_status(vms: list[str]) -> None:
    require_vagrant()
    console.rule("[bold cyan]vagrant status[/bold cyan]")
    subprocess.run(["vagrant", "status"])


def pick_vms(vms: list[str]) -> list[str]:
    """Prompt the user to pick one, several, or all VMs."""
    if not vms:
        console.print("[yellow]No VMs discovered; will run against all VMs.[/yellow]")
        return []

    console.print("\n[bold]Available VMs:[/bold]")
    for i, name in enumerate(vms, start=1):
        console.print(f"  {i}. {name}")
    console.print("  a. all")

    choice = Prompt.ask(
        "Select VM number(s) (comma-separated) or 'a' for all",
        default="a",
    )
    if choice.strip().lower() == "a":
        return vms

    selected = []
    for part in choice.split(","):
        part = part.strip()
        if part.isdigit() and 1 <= int(part) <= len(vms):
            selected.append(vms[int(part) - 1])
    if not selected:
        console.print("[yellow]No valid selection made; defaulting to all.[/yellow]")
        return vms
    return selected


def interactive_menu(vms: list[str]) -> None:
    require_vagrant()
    while True:
        console.print(
            Panel.fit(
                "\n".join(f"{k}. {label}" for k, (_, label) in ACTIONS.items()),
                title="Vagrant Lab Manager",
                border_style="cyan",
            )
        )
        choice = Prompt.ask("Choose an action", choices=list(ACTIONS.keys()), default="7")
        action, _ = ACTIONS[choice]

        if action == "quit":
            console.print("Bye.")
            return

        if action == "status":
            show_status(vms)
            continue

        if action == "ssh":
            targets = pick_vms(vms)
            if len(targets) != 1:
                console.print("[yellow]SSH requires exactly one VM. Pick a single number.[/yellow]")
                continue
            run_vagrant("ssh", targets[0])
            continue

        if action == "destroy":
            targets = pick_vms(vms)
            names = ", ".join(targets) if targets else "ALL VMs"
            if not Confirm.ask(f"[bold red]Really destroy {names}?[/bold red]", default=False):
                console.print("Cancelled.")
                continue
            results = [run_vagrant("destroy", vm, extra_args=["-f"]) for vm in (targets or [None])]
            print_results(results)
            continue

        targets = pick_vms(vms)
        results = [run_vagrant(action, vm) for vm in (targets or [None])]
        print_results(results)


def main() -> None:
    parser = argparse.ArgumentParser(description="Manage lab Vagrant VMs.")
    parser.add_argument(
        "action",
        nargs="?",
        choices=["up", "halt", "reload", "provision", "destroy", "status"],
        help="Action to run non-interactively.",
    )
    parser.add_argument("vms", nargs="*", help="VM names to target (default: all).")
    parser.add_argument("--list", action="store_true", help="List discovered VMs and exit.")
    args = parser.parse_args()

    vagrantfile = find_vagrantfile()
    if vagrantfile is None:
        console.print(
            "[bold red]Error:[/bold red] No Vagrantfile found in this directory or any parent."
        )
        sys.exit(1)

    vms = discover_vms(vagrantfile)

    if args.list:
        if vms:
            for v in vms:
                console.print(v)
        else:
            console.print("[yellow]No VMs discovered.[/yellow]")
        return

    if args.action:
        require_vagrant()
        if args.action == "status":
            show_status(vms)
            return
        targets = args.vms or vms
        extra = ["-f"] if args.action == "destroy" else None
        results = [run_vagrant(args.action, vm, extra_args=extra) for vm in (targets or [None])]
        print_results(results)
        if any(not r.ok for r in results):
            sys.exit(1)
        return

    interactive_menu(vms)


if __name__ == "__main__":
    main()
