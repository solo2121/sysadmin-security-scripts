#!/usr/bin/env python3
"""
vagrant_manager.py

Interactive manager for the lab's Vagrant VMs.
Replaces the previous bash manager with a small, testable Python CLI built on `rich`.

Features translated from bash v8.1:
  - Fixed environment propagation for HARBOR_PASS
  - Session cache prevents repeated prompts
  - Start (T) no longer requires Harbor password
  - Provision actions prompt only once per session
  - CI/CD server group included

Requires: rich (pip install rich)
"""

from __future__ import annotations

import argparse
import getpass
import os
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

# ========================== CONFIGURATION ==========================

VAGRANTFILE_CANDIDATES = ["Vagrantfile"]

# Curated inventory for UI grouping and batch actions.
# Actual execution and UI display are filtered against `vagrant status`.
VM_GROUPS = {
    "DEVOPS": ["devops-1"],
    "WORKERS": ["worker-1", "worker-2"],
    "ANSIBLE NODES": ["node1", "node2"],
    "LINUX LABS": ["ubuntu-lab", "rocky-lab", "alma-lab", "suse-lab"],
    "MODERN LABS": ["kind-lab", "k3d-lab"],
    "CI/CD SERVER": ["cicd-server"],
}

# Known Vagrant machine states. Used to parse `vagrant status` output safely.
_VAGRANT_STATES = (
    "not created",
    "running",
    "poweroff",
    "saved",
    "aborted",
    "unknown",
    "stopping",
    "preparing",
)

STATE_ICONS = {
    "running": "[green]▶[/green]",
    "poweroff": "[red]■[/red]",
    "not_created": "[yellow]○[/yellow]",
    "default": "[gray]?[/gray]",
}


@dataclass
class VmAction:
    name: str
    ok: bool
    detail: str = ""


# ========================== SESSION STATE ==========================

# Prevent repeated password prompts during the same session
HARBOR_PROMPT_DONE: bool = False
HARBOR_PASS: str | None = os.environ.get("HARBOR_PASS")


# ========================== VAGRANTFILE DISCOVERY ==========================

def find_vagrantfile() -> Path | None:
    """Look for a Vagrantfile in cwd, then walk up to the repo root."""
    here = Path.cwd()
    for candidate in [here, *here.parents]:
        for name in VAGRANTFILE_CANDIDATES:
            f = candidate / name
            if f.exists():
                return f
    return None


# ========================== VM STATUS ==========================

def get_machine_states(vagrantfile: Path) -> dict[str, str]:
    """
    Ask Vagrant for the state of all machines in the project.
    Vagrant status is authoritative — if a VM isn't in the Vagrantfile,
    it won't appear here, preventing stale hard-coded entries from acting up.
    """
    states: dict[str, str] = {}
    if not shutil.which("vagrant"):
        return states

    try:
        result = subprocess.run(
            ["vagrant", "status"],
            cwd=vagrantfile.parent,
            capture_output=True,
            text=True,
            check=False,
        )
    except FileNotFoundError:
        return states

    if result.returncode != 0:
        return states

    state_alt = "|".join(re.escape(s) for s in _VAGRANT_STATES)
    # Capture both the VM name and the state string
    pattern = re.compile(rf"^([\w\-]+)\s+({state_alt})\b", re.IGNORECASE)

    for line in result.stdout.splitlines():
        line = line.strip()
        m = pattern.match(line)
        if m:
            vm_name = m.group(1)
            state_str = m.group(2).lower().replace(" ", "_")
            states[vm_name] = state_str

    return states


# ========================== HARBOR PASSWORD HANDLING ==========================

def ensure_harbor_pass() -> None:
    """Prompt for Harbor password if not set in environment."""
    global HARBOR_PASS

    if HARBOR_PASS:
        console.print("[green]Using HARBOR_PASS from environment.[/green]")
        return

    console.print(Panel.fit(
        "[bold]HARBOR REGISTRY PASSWORD REQUIRED[/bold]\n\n"
        "Harbor container registry needs an admin password.\n"
        "This is required for provisioning the main cluster.\n\n"
        "You can also set it in advance:\n"
        "[cyan]export HARBOR_PASS='YourStrongPassword'[/cyan]",
        border_style="yellow"
    ))

    while True:
        pwd = getpass.getpass("Enter Harbor admin password: ")
        if not pwd:
            console.print("[bold red]ERROR: Password cannot be empty.[/bold red]")
            continue

        if len(pwd) < 8:
            console.print("[yellow]WARNING: Password is less than 8 characters.[/yellow]")
            if not Confirm.ask("Continue?", default=False):
                sys.exit(1)

        pwd_confirm = getpass.getpass("Confirm password: ")
        if pwd != pwd_confirm:
            console.print("[bold red]ERROR: Passwords do not match.[/bold red]")
            continue

        HARBOR_PASS = pwd
        console.print("[green]Password configured successfully.[/green]")
        break


def ensure_harbor_pass_once() -> None:
    """Lazy prompt: only ask once per session."""
    global HARBOR_PROMPT_DONE
    if HARBOR_PROMPT_DONE:
        return

    ensure_harbor_pass()
    HARBOR_PROMPT_DONE = True


# ========================== VAGRANT EXECUTION ==========================

def require_vagrant() -> None:
    if not shutil.which("vagrant"):
        console.print(
            "[bold red]Error:[/bold red] 'vagrant' was not found on PATH. "
            "Install Vagrant or activate the environment that provides it."
        )
        sys.exit(1)


def run_vagrant(
    action: str,
    vagrantfile: Path,
    vm: str | None = None,
    extra_args: list[str] | None = None,
) -> VmAction:
    """
    Run a vagrant subcommand from the Vagrantfile's directory.
    Redirects stdin to /dev/null to prevent interactive prompts blocking the manager,
    except for 'ssh' which requires an interactive TTY.
    """
    cmd = ["vagrant", action]
    if vm:
        cmd.append(vm)
    if extra_args:
        cmd.extend(extra_args)

    label = vm or "(all)"
    console.rule(f"[bold cyan]vagrant {action}[/bold cyan] {label}")

    env = os.environ.copy()
    env["VAGRANT_DEFAULT_PROVIDER"] = "libvirt"
    if HARBOR_PASS:
        env["HARBOR_PASS"] = HARBOR_PASS

    # SSH requires an interactive stdin, other commands should block stdin
    stdin_arg = None if action == "ssh" else subprocess.DEVNULL

    try:
        result = subprocess.run(
            cmd,
            cwd=vagrantfile.parent,
            env=env,
            stdin=stdin_arg
        )
    except FileNotFoundError:
        return VmAction(name=label, ok=False, detail="vagrant not found")
    except KeyboardInterrupt:
        console.print("[yellow]Interrupted by user.[/yellow]")
        return VmAction(name=label, ok=False, detail="interrupted")

    ok = result.returncode == 0
    detail = "" if ok else f"exit code {result.returncode}"
    return VmAction(name=label, ok=ok, detail=detail)


# ========================== UI ==========================

def show_main_menu(states: dict[str, str]) -> dict[str, str]:
    """Render the main menu and return the mapping of selection numbers to VMs."""
    console.clear()
    console.print(Panel.fit("[bold white]VAGRANT LAB MANAGER v8.1[/bold white]", border_style="blue"))

    table = Table(show_header=False, box=None, padding=(0, 1, 0, 1))
    table.add_column("ID", style="cyan", width=5)
    table.add_column("VM", style="white", width=15)
    table.add_column("State", width=20)

    idx = 1
    options: dict[str, str] = {}

    for group_name, configured_vms in VM_GROUPS.items():
        # Filter to only display VMs that actually exist according to Vagrant
        actual_vms = [vm for vm in configured_vms if vm in states]

        if not actual_vms:
            continue

        table.add_row("", f"[bold purple]{group_name}[/bold purple]", "", style="underline")
        for vm in actual_vms:
            state = states.get(vm, "not_created")
            icon = STATE_ICONS.get(state, STATE_ICONS["default"])
            table.add_row(f"[{idx:02d}]", vm, f"{icon} {state}")
            options[str(idx)] = vm
            idx += 1
        table.add_row()  # Spacer between groups

    console.print(table)

    console.print("[cyan][A] Start All (provision)  [V] DevOps (provision)[/cyan]")
    console.print("[cyan][W] Workers (no provision)   [N] Ansible (no provision)[/cyan]")
    console.print("[cyan][L] Linux Labs (no provision) [M] Modern (no provision)[/cyan]")
    console.print("[cyan][C] CI/CD Server (no provision) [B] Halt All[/cyan]")
    console.print("[cyan][R] Refresh  [Q] Quit[/cyan]")
    console.print("[gray]Note: Harbor password only required once per session for provisioning[/gray]")

    return options


def vm_menu(vagrantfile: Path, vm: str) -> None:
    """Individual VM management menu."""
    while True:
        states = get_machine_states(vagrantfile)
        state = states.get(vm, "not_created")

        console.clear()
        console.print(Panel.fit(f"[bold white]VM MANAGEMENT: {vm}[/bold white]", border_style="blue"))

        console.print(f"VM:    [cyan]{vm}[/cyan]")
        console.print(f"State: {state}")

        if HARBOR_PASS and HARBOR_PROMPT_DONE:
            console.print("Harbor: [green]configured (session)[/green]")
        elif HARBOR_PASS:
            console.print("Harbor: [green]configured[/green]")
        else:
            console.print("Harbor: [yellow]not set (only needed for provision)[/yellow]")

        console.print("\n[cyan][S] SSH (no password needed)")
        console.print("[U] Up with Provision (password needed once)")
        console.print("[T] Start (no provision, no password)")
        console.print("[H] Halt (no password)")
        console.print("[R] Reload with Provision (password needed once)")
        console.print("[P] Provision only (password needed once)")
        console.print("[D] Destroy (no password)")
        console.print("[B] Back")
        console.print("[Q] Quit[/cyan]")

        choice = Prompt.ask("[bold]Action[/bold]", default="B").upper()

        if choice == "S":
            run_vagrant("ssh", vagrantfile, vm=vm)
        elif choice == "U":
            ensure_harbor_pass_once()
            run_vagrant("up", vagrantfile, vm=vm, extra_args=["--provision"])
        elif choice == "T":
            run_vagrant("up", vagrantfile, vm=vm)
        elif choice == "H":
            run_vagrant("halt", vagrantfile, vm=vm)
        elif choice == "R":
            ensure_harbor_pass_once()
            run_vagrant("reload", vagrantfile, vm=vm, extra_args=["--provision"])
        elif choice == "P":
            ensure_harbor_pass_once()
            run_vagrant("provision", vagrantfile, vm=vm)
        elif choice == "D":
            if Confirm.ask(f"[bold red]Really destroy {vm}?[/bold red]", default=False):
                run_vagrant("destroy", vagrantfile, vm=vm, extra_args=["-f"])
        elif choice == "B":
            return
        elif choice == "Q":
            sys.exit(0)
        else:
            console.print("[red]Invalid option[/red]")

        Prompt.ask("[gray]Press Enter to continue...[/gray]", default="")


# ========================== GROUP ACTIONS ==========================

def start_group(vagrantfile: Path, group_key: str) -> None:
    """Start a specific group of VMs or all VMs."""
    if group_key == "all":
        ensure_harbor_pass_once()
        run_vagrant("up", vagrantfile, vm=None, extra_args=["--provision"])
        return

    # Map menu letters to group names
    group_map = {
        "V": "DEVOPS",
        "W": "WORKERS",
        "N": "ANSIBLE NODES",
        "L": "LINUX LABS",
        "M": "MODERN LABS",
        "C": "CI/CD SERVER",
    }

    group_name = group_map.get(group_key)
    if not group_name:
        return

    states = get_machine_states(vagrantfile)
    # Only act on VMs that actually exist
    vms = [vm for vm in VM_GROUPS[group_name] if vm in states]

    # DevOps group requires provisioning in your lab setup
    if group_name == "DEVOPS":
        ensure_harbor_pass_once()
        for vm in vms:
            console.print(f"[yellow]Starting {vm} (provision)...[/yellow]")
            run_vagrant("up", vagrantfile, vm=vm, extra_args=["--provision"])
    else:
        for vm in vms:
            console.print(f"[yellow]Starting {vm}...[/yellow]")
            run_vagrant("up", vagrantfile, vm=vm)


def halt_all(vagrantfile: Path) -> None:
    console.print("[yellow]Halting all VMs...[/yellow]")
    run_vagrant("halt", vagrantfile, vm=None, extra_args=["-f"])


# ========================== MAIN ==========================

def main() -> None:
    parser = argparse.ArgumentParser(description="Manage lab Vagrant VMs.")
    parser.add_argument(
        "action",
        nargs="?",
        choices=["up", "halt", "reload", "provision", "destroy", "status"],
        help="Action to run non-interactively.",
    )
    parser.add_argument("vms", nargs="*", help="VM names to target (default: all).")
    parser.add_argument(
        "--provision",
        action="store_true",
        help="Run Vagrant provisioning with the action.",
    )
    args = parser.parse_args()

    vagrantfile = find_vagrantfile()
    if vagrantfile is None:
        console.print(
            "[bold red]Error:[/bold red] No Vagrantfile found in this directory or any parent."
        )
        sys.exit(1)

    require_vagrant()

    # Non-interactive CLI mode
    if args.action:
        if args.action == "status":
            run_vagrant("status", vagrantfile)
            return

        states = get_machine_states(vagrantfile)

        # Validate explicitly provided VM names against Vagrant's known states
        if args.vms:
            unknown = [vm for vm in args.vms if vm not in states]
            if unknown:
                console.print(
                    f"[bold red]Unknown VM(s):[/bold red] {', '.join(unknown)}"
                )
                sys.exit(1)

        # Safety: prevent global destroy if no targets were provided
        if args.action == "destroy" and not args.vms:
            console.print(
                "[bold red]Error:[/bold red] Refusing to destroy all VMs without explicit targets.\n"
                "Specify VMs to destroy: python3 vagrant_manager.py destroy devops-1 worker-1"
            )
            sys.exit(1)

        # Determine Harbor prompt requirement and extra arguments
        if args.action == "provision":
            ensure_harbor_pass_once()
            extra = None
        elif args.action in ["up", "reload"] and args.provision:
            ensure_harbor_pass_once()
            extra = ["--provision"]
        elif args.action == "destroy":
            extra = ["-f"]
        else:
            extra = None

        results = [
            run_vagrant(args.action, vagrantfile, vm=vm, extra_args=extra)
            for vm in (args.vms or [None])
        ]
        if any(not r.ok for r in results):
            sys.exit(1)
        return

    # Interactive Menu Loop
    while True:
        states = get_machine_states(vagrantfile)
        options = show_main_menu(states)

        choice = Prompt.ask("[bold]Selection[/bold]", default="R")

        if choice.isdigit() and choice in options:
            vm_menu(vagrantfile, options[choice])
            continue

        choice = choice.upper()

        if choice == "A":
            start_group(vagrantfile, "all")
        elif choice == "V":
            start_group(vagrantfile, "V")
        elif choice == "W":
            start_group(vagrantfile, "W")
        elif choice == "N":
            start_group(vagrantfile, "N")
        elif choice == "L":
            start_group(vagrantfile, "L")
        elif choice == "M":
            start_group(vagrantfile, "M")
        elif choice == "C":
            start_group(vagrantfile, "C")
        elif choice == "B":
            halt_all(vagrantfile)
        elif choice == "R":
            continue
        elif choice == "Q":
            sys.exit(0)
        else:
            console.print("[red]Invalid option[/red]")
            Prompt.ask("[gray]Press Enter to continue...[/gray]", default="")


if __name__ == "__main__":
    main()
