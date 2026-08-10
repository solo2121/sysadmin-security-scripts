#!/usr/bin/env python3
"""
vagrant_manager.py

Interactive manager for the lab's Vagrant VMs.

Provides an interactive Rich-based TUI while preserving the same
Vagrant operations as the original Bash manager.

Usage:
    python3 vagrant_manager.py
    python3 vagrant_manager.py --list
    python3 vagrant_manager.py up web db
    python3 vagrant_manager.py status

Requires:
    rich

Install:
    pip install rich
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
from rich.panel import Panel
from rich.prompt import Confirm, Prompt
from rich.table import Table


console = Console()

VAGRANTFILE_CANDIDATES = ("Vagrantfile",)

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


@dataclass(frozen=True)
class VmAction:
    """Result of a Vagrant operation."""

    name: str
    ok: bool
    detail: str = ""


def find_vagrantfile() -> Path | None:
    """Find a Vagrantfile in the current directory or its parents."""
    here = Path.cwd()

    for directory in (here, *here.parents):
        for name in VAGRANTFILE_CANDIDATES:
            vagrantfile = directory / name

            if vagrantfile.is_file():
                return vagrantfile

    return None


def discover_vms(vagrantfile: Path) -> list[str]:
    """
    Discover VM names from the Vagrantfile.

    First tries the common:

        config.vm.define "name"

    pattern. If no VM definitions are found, falls back to
    `vagrant status`.
    """
    try:
        text = vagrantfile.read_text(
            encoding="utf-8",
            errors="ignore",
        )
    except OSError as exc:
        console.print(
            f"[yellow]Warning:[/yellow] Unable to read "
            f"{vagrantfile}: {exc}"
        )
        return []

    names = re.findall(
        r"""config\.vm\.define\s+["']([\w.-]+)["']""",
        text,
    )

    if names:
        return list(dict.fromkeys(names))

    return discover_vms_from_status(vagrantfile)


def discover_vms_from_status(vagrantfile: Path) -> list[str]:
    """Discover VM names using `vagrant status`."""
    if not shutil.which("vagrant"):
        return []

    try:
        result = subprocess.run(
            ["vagrant", "status"],
            cwd=vagrantfile.parent,
            capture_output=True,
            text=True,
            check=False,
        )
    except (FileNotFoundError, OSError):
        return []

    if result.returncode != 0:
        return []

    names: list[str] = []

    # Typical output:
    #
    # web                       not created (virtualbox)
    # db                        running (virtualbox)
    #
    status_pattern = re.compile(
        r"^\s*([\w.-]+)\s+"
        r"(not created|running|poweroff|saved|aborted|"
        r"stopping|starting|unknown)\b",
        re.IGNORECASE,
    )

    for line in result.stdout.splitlines():
        match = status_pattern.match(line)

        if match:
            names.append(match.group(1))

    return list(dict.fromkeys(names))


def require_vagrant() -> bool:
    """Check whether Vagrant is available on PATH."""
    if shutil.which("vagrant"):
        return True

    console.print(
        "[bold red]Error:[/bold red] 'vagrant' was not found on PATH. "
        "Install Vagrant or activate the environment that provides it."
    )
    return False


def run_vagrant(
    action: str,
    vm: str | None,
    vagrantfile: Path,
    extra_args: list[str] | None = None,
) -> VmAction:
    """
    Run a Vagrant subcommand with live output.

    Commands are always executed from the directory containing
    the discovered Vagrantfile.
    """
    cmd = ["vagrant", action]

    if vm:
        cmd.append(vm)

    if extra_args:
        cmd.extend(extra_args)

    label = vm or "(all)"

    console.rule(
        f"[bold cyan]vagrant {action}[/bold cyan] {label}"
    )

    try:
        result = subprocess.run(
            cmd,
            cwd=vagrantfile.parent,
            check=False,
        )
    except FileNotFoundError:
        return VmAction(
            name=label,
            ok=False,
            detail="vagrant not found",
        )
    except OSError as exc:
        return VmAction(
            name=label,
            ok=False,
            detail=str(exc),
        )
    except KeyboardInterrupt:
        console.print("[yellow]Interrupted by user.[/yellow]")
        return VmAction(
            name=label,
            ok=False,
            detail="interrupted",
        )

    if result.returncode == 0:
        return VmAction(name=label, ok=True)

    return VmAction(
        name=label,
        ok=False,
        detail=f"exit code {result.returncode}",
    )


def print_results(results: list[VmAction]) -> None:
    """Display operation results in a Rich table."""
    table = Table(
        title="Result",
        show_lines=False,
    )

    table.add_column("VM")
    table.add_column("Status")
    table.add_column("Detail")

    for result in results:
        status = (
            "[green]OK[/green]"
            if result.ok
            else "[red]FAILED[/red]"
        )

        table.add_row(
            result.name,
            status,
            result.detail,
        )

    console.print(table)


def show_status(vagrantfile: Path) -> bool:
    """Run `vagrant status` from the Vagrantfile directory."""
    console.rule("[bold cyan]vagrant status[/bold cyan]")

    try:
        result = subprocess.run(
            ["vagrant", "status"],
            cwd=vagrantfile.parent,
            check=False,
        )
    except FileNotFoundError:
        console.print(
            "[bold red]Error:[/bold red] Vagrant was not found."
        )
        return False
    except OSError as exc:
        console.print(
            f"[bold red]Error:[/bold red] Unable to run Vagrant: {exc}"
        )
        return False
    except KeyboardInterrupt:
        console.print("[yellow]Interrupted by user.[/yellow]")
        return False

    return result.returncode == 0


def pick_vms(vms: list[str]) -> list[str]:
    """Prompt the user to pick one, several, or all VMs."""
    if not vms:
        console.print(
            "[yellow]No VMs discovered; "
            "will run against all VMs.[/yellow]"
        )
        return []

    console.print("\n[bold]Available VMs:[/bold]")

    for index, name in enumerate(vms, start=1):
        console.print(f"  {index}. {name}")

    console.print("  a. all")

    choice = Prompt.ask(
        "Select VM number(s) (comma-separated) or 'a' for all",
        default="a",
    )

    if choice.strip().lower() == "a":
        return vms.copy()

    selected: list[str] = []
    seen: set[str] = set()

    for part in choice.split(","):
        part = part.strip()

        if not part.isdigit():
            continue

        index = int(part)

        if 1 <= index <= len(vms):
            name = vms[index - 1]

            if name not in seen:
                selected.append(name)
                seen.add(name)

    if not selected:
        console.print(
            "[yellow]No valid selection made; "
            "defaulting to all.[/yellow]"
        )
        return vms.copy()

    return selected


def validate_vm_names(
    requested: list[str],
    discovered: list[str],
) -> list[str]:
    """
    Validate explicitly supplied VM names.

    Returns the valid names while preserving their input order.
    """
    if not requested or not discovered:
        return requested

    known = set(discovered)
    invalid = [name for name in requested if name not in known]

    if invalid:
        console.print(
            "[bold red]Error:[/bold red] Unknown VM(s): "
            + ", ".join(invalid)
        )
        console.print(
            "[dim]Known VMs:[/dim] "
            + ", ".join(discovered)
        )
        return []

    return list(dict.fromkeys(requested))


def interactive_menu(
    vms: list[str],
    vagrantfile: Path,
) -> None:
    """Run the interactive Vagrant manager."""
    if not require_vagrant():
        return

    while True:
        console.print(
            Panel.fit(
                "\n".join(
                    f"{key}. {label}"
                    for key, (_, label) in ACTIONS.items()
                ),
                title="Vagrant Lab Manager",
                border_style="cyan",
            )
        )

        choice = Prompt.ask(
            "Choose an action",
            choices=list(ACTIONS.keys()),
            default="7",
        )

        action, _ = ACTIONS[choice]

        if action == "quit":
            console.print("Bye.")
            return

        if action == "status":
            show_status(vagrantfile)
            continue

        if action == "ssh":
            targets = pick_vms(vms)

            if len(targets) != 1:
                console.print(
                    "[yellow]SSH requires exactly one VM. "
                    "Pick a single number.[/yellow]"
                )
                continue

            run_vagrant(
                "ssh",
                targets[0],
                vagrantfile,
            )
            continue

        if action == "destroy":
            targets = pick_vms(vms)

            names = (
                ", ".join(targets)
                if targets
                else "ALL VMs"
            )

            if not Confirm.ask(
                f"[bold red]Really destroy {names}?[/bold red]",
                default=False,
            ):
                console.print("Cancelled.")
                continue

            targets_to_run = targets or [None]

            results = [
                run_vagrant(
                    "destroy",
                    vm,
                    vagrantfile,
                    extra_args=["-f"],
                )
                for vm in targets_to_run
            ]

            print_results(results)
            continue

        targets = pick_vms(vms)
        targets_to_run = targets or [None]

        results = [
            run_vagrant(
                action,
                vm,
                vagrantfile,
            )
            for vm in targets_to_run
        ]

        print_results(results)


def main() -> int:
    """Program entry point."""
    parser = argparse.ArgumentParser(
        description="Manage lab Vagrant VMs."
    )

    parser.add_argument(
        "action",
        nargs="?",
        choices=[
            "up",
            "halt",
            "reload",
            "provision",
            "destroy",
            "status",
        ],
        help="Action to run non-interactively.",
    )

    parser.add_argument(
        "vms",
        nargs="*",
        help="VM names to target (default: all).",
    )

    parser.add_argument(
        "--list",
        action="store_true",
        help="List discovered VMs and exit.",
    )

    args = parser.parse_args()

    vagrantfile = find_vagrantfile()

    if vagrantfile is None:
        console.print(
            "[bold red]Error:[/bold red] No Vagrantfile found "
            "in this directory or any parent."
        )
        return 1

    console.print(
        f"[dim]Vagrantfile:[/dim] {vagrantfile}"
    )

    vms = discover_vms(vagrantfile)

    if args.list:
        if vms:
            for vm in vms:
                console.print(vm)
        else:
            console.print(
                "[yellow]No VMs discovered.[/yellow]"
            )
        return 0

    if args.action:
        if not require_vagrant():
            return 1

        if args.action == "status":
            return 0 if show_status(vagrantfile) else 1

        targets = validate_vm_names(
            args.vms,
            vms,
        )

        if args.vms and not targets:
            return 1

        targets_to_run = targets or vms or [None]

        extra = (
            ["-f"]
            if args.action == "destroy"
            else None
        )

        results = [
            run_vagrant(
                args.action,
                vm,
                vagrantfile,
                extra_args=extra,
            )
            for vm in targets_to_run
        ]

        print_results(results)

        return 1 if any(not result.ok for result in results) else 0

    interactive_menu(
        vms,
        vagrantfile,
    )

    return 0


if __name__ == "__main__":
    sys.exit(main())