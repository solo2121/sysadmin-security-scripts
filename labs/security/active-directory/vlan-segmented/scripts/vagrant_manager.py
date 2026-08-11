#!/usr/bin/env python3
"""
vagrant_manager.py

Interactive manager for the Pentest VLAN Lab.

Provides a Rich-based Python CLI while preserving the behavior
of the original Bash manager.

Features:
- VLAN-based inventory grouping
- OPNsense direct SSH
- VAGRANT_DEFAULT_PROVIDER forced to libvirt
- Sequential start of all VMs to preserve network boot order
- Interactive per-VM management
- Safe non-interactive destroy behavior
- LAB_PROFILE-aware: "Start All" / "Halt All" and the no-args CLI
  default only target VMs that actually exist under the Vagrantfile's
  current profile (explicit LAB_PROFILE, or its hardware-based
  auto-detection when LAB_PROFILE is unset), instead of always
  targeting all 12 known VMs.

Requires:
    rich

Install:
    pip install rich
"""

from __future__ import annotations

import argparse
import os
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

# ========================== CONFIGURATION ==========================

VAGRANTFILE_CANDIDATES = ("Vagrantfile",)

# Explicit lab inventory.
#
# Keep the exact case-sensitive machine IDs used by the Vagrantfile.
#
# VLAN 10 intentionally appears first in ALL_VMS so the router/DC
# infrastructure boots before dependent clients.

VLAN_10 = ("opnsense", "DC01", "DB01", "CA01-ESC")
VLAN_20 = ("WIN10", "print01")
VLAN_30 = ("linux01", "llm01", "cloud-pentest")
VLAN_40 = ("metasploitable2", "juice-shop")
VLAN_99 = ("kali",)

ALL_VMS = (
    *VLAN_10,
    *VLAN_20,
    *VLAN_30,
    *VLAN_40,
    *VLAN_99,
)

# UI rendering order: top to bottom.

VLAN_GROUPS = {
    "VLAN 99 - ATTACKER": VLAN_99,
    "VLAN 40 - DMZ / PUBLIC": VLAN_40,
    "VLAN 30 - LINUX SERVERS": VLAN_30,
    "VLAN 20 - WORKSTATIONS": VLAN_20,
    "VLAN 10 - AD CORE / ROUTER": VLAN_10,
}

STATE_ICONS = {
    "running": "[green]▶[/green]",
    "paused": "[yellow]⏸[/yellow]",
    "poweroff": "[red]■[/red]",
    "not_created": "[red]■[/red]",
    "default": "[bright_black]?[/bright_black]",
}

# Vagrant's machine-readable state values that we recognize.
KNOWN_STATES = {
    "running",
    "paused",
    "poweroff",
    "not_created",
    "aborted",
    "saved",
    "unknown",
    "stopping",
    "starting",
}


@dataclass(frozen=True)
class VmAction:
    """Result of a Vagrant operation."""

    name: str
    ok: bool
    detail: str = ""
    returncode: int | None = None


# ========================== VAGRANTFILE DISCOVERY ==========================


def find_vagrantfile() -> Path | None:
    """Find a Vagrantfile in the current directory or any parent."""
    here = Path.cwd()

    for directory in (here, *here.parents):
        for name in VAGRANTFILE_CANDIDATES:
            vagrantfile = directory / name

            if vagrantfile.is_file():
                return vagrantfile

    return None


# ========================== VAGRANT INVENTORY ==========================


def get_vagrant_inventory(
    vagrantfile: Path,
) -> tuple[dict[str, str], dict[str, str]]:
    """
    Collect VM states and SSH endpoints.

    Uses Vagrant's machine-readable status output for reliable state
    detection and a single `vagrant ssh-config` call for running VMs.
    """
    states: dict[str, str] = {}
    ssh_hosts: dict[str, str] = {}

    if not shutil.which("vagrant"):
        return states, ssh_hosts

    # ------------------------------------------------------------------
    # 1. Get machine states.
    # ------------------------------------------------------------------

    try:
        result = subprocess.run(
            [
                "vagrant",
                "status",
                "--machine-readable",
            ],
            cwd=vagrantfile.parent,
            capture_output=True,
            text=True,
            check=False,
            stdin=subprocess.DEVNULL,
        )
    except (FileNotFoundError, OSError):
        return states, ssh_hosts

    if result.returncode == 0:
        for line in result.stdout.splitlines():
            parts = line.split(",")

            if len(parts) < 4:
                continue

            if parts[2] != "state":
                continue

            vm_name = parts[1].strip()
            state = parts[3].strip()

            if vm_name and state:
                states[vm_name] = state

    # ------------------------------------------------------------------
    # 2. Get SSH endpoints only for running machines.
    # ------------------------------------------------------------------

    running_vms = [
        vm
        for vm, state in states.items()
        if state == "running"
    ]

    if not running_vms:
        return states, ssh_hosts

    try:
        result = subprocess.run(
            ["vagrant", "ssh-config", *running_vms],
            cwd=vagrantfile.parent,
            capture_output=True,
            text=True,
            check=False,
            stdin=subprocess.DEVNULL,
        )
    except (FileNotFoundError, OSError):
        return states, ssh_hosts

    if result.returncode != 0:
        return states, ssh_hosts

    current_vm: str | None = None

    for line in result.stdout.splitlines():
        stripped = line.strip()

        if stripped.startswith("Host "):
            parts = stripped.split(maxsplit=1)

            if len(parts) == 2:
                current_vm = parts[1].strip()

        elif stripped.startswith("HostName ") and current_vm:
            parts = stripped.split(maxsplit=1)

            if len(parts) == 2:
                ssh_hosts[current_vm] = parts[1].strip()
                current_vm = None

    return states, ssh_hosts


# ========================== VAGRANT EXECUTION ==========================


def resolve_active_vms(
    vagrantfile: Path,
) -> tuple[list[str], bool]:
    """
    Determine which known lab VMs actually exist under the Vagrantfile's
    current LAB_PROFILE.

    Uses `vagrant status --machine-readable` (via get_vagrant_inventory)
    as the source of truth rather than re-implementing the Vagrantfile's
    PROFILES table or its hardware-based get_optimal_profile auto-detect
    logic in Python. `vagrant status` already reflects whichever profile
    the Vagrantfile resolved to -- explicit LAB_PROFILE or auto-detected
    -- because it lists exactly the machines the current run's
    `config.vm.define` calls actually produced.

    Returns (active_vm_names_in_declared_order, resolved_via_status).
    If `vagrant status` is unavailable or returns nothing, falls back to
    the full ALL_VMS inventory and reports resolved_via_status=False, so
    callers can fall back to the previous unconditional behavior.
    """
    states, _ = get_vagrant_inventory(vagrantfile)

    if not states:
        return list(ALL_VMS), False

    active = [vm for vm in ALL_VMS if vm in states]
    return (active or list(ALL_VMS)), True


def require_vagrant() -> bool:
    """Return True when Vagrant is available on PATH."""
    if shutil.which("vagrant"):
        return True

    console.print(
        "[bold red]Error:[/bold red] 'vagrant' was not found on PATH. "
        "Install Vagrant or activate the environment that provides it."
    )

    return False


def build_vagrant_environment() -> dict[str, str]:
    """Build the environment used for every Vagrant invocation."""
    env = os.environ.copy()
    env["VAGRANT_DEFAULT_PROVIDER"] = "libvirt"
    return env


def run_vagrant(
    action: str,
    vagrantfile: Path,
    vm: str | None = None,
    vms_list: list[str] | tuple[str, ...] | None = None,
    extra_args: list[str] | None = None,
) -> VmAction:
    """
    Run a Vagrant subcommand from the Vagrantfile directory.

    All Vagrant commands force the libvirt provider.

    SSH receives the normal interactive stdin. Other commands receive
    /dev/null so unexpected prompts cannot block the manager.
    """
    cmd = ["vagrant", action]

    if vms_list:
        cmd.extend(vms_list)
    elif vm:
        cmd.append(vm)

    if extra_args:
        cmd.extend(extra_args)

    label = (
        ", ".join(vms_list)
        if vms_list
        else (vm or "(all)")
    )

    console.rule(
        f"[bold cyan]vagrant {action}[/bold cyan] {label}"
    )

    env = build_vagrant_environment()

    stdin_arg = (
        None
        if action == "ssh"
        else subprocess.DEVNULL
    )

    try:
        result = subprocess.run(
            cmd,
            cwd=vagrantfile.parent,
            env=env,
            stdin=stdin_arg,
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
        console.print(
            "[yellow]Interrupted by user.[/yellow]"
        )

        return VmAction(
            name=label,
            ok=False,
            detail="interrupted",
        )

    if result.returncode == 0:
        return VmAction(
            name=label,
            ok=True,
            returncode=result.returncode,
        )

    return VmAction(
        name=label,
        ok=False,
        detail=f"exit code {result.returncode}",
        returncode=result.returncode,
    )


def ssh_opnsense(host: str) -> VmAction:
    """
    Connect directly to OPNsense using root SSH.

    This intentionally bypasses `vagrant ssh` because OPNsense requires
    direct root-shell access.
    """
    console.print(
        "[yellow]Attempting direct SSH to OPNsense...[/yellow]"
    )

    if not host or host == "N/A":
        console.print(
            "[red]Could not determine OPNsense SSH host "
            "for direct connection.[/red]"
        )

        return VmAction(
            name="opnsense",
            ok=False,
            detail="missing host",
        )

    if not shutil.which("ssh"):
        return VmAction(
            name="opnsense",
            ok=False,
            detail="ssh not found",
        )

    try:
        result = subprocess.run(
            ["ssh", f"root@{host}"],
            check=False,
        )
    except FileNotFoundError:
        return VmAction(
            name="opnsense",
            ok=False,
            detail="ssh not found",
        )
    except OSError as exc:
        return VmAction(
            name="opnsense",
            ok=False,
            detail=str(exc),
        )
    except KeyboardInterrupt:
        return VmAction(
            name="opnsense",
            ok=False,
            detail="interrupted",
        )

    if result.returncode == 0:
        return VmAction(
            name="opnsense",
            ok=True,
            returncode=result.returncode,
        )

    return VmAction(
        name="opnsense",
        ok=False,
        detail=f"exit code {result.returncode}",
        returncode=result.returncode,
    )


# ========================== UI ==========================


def show_main_menu(
    states: dict[str, str],
    ssh_hosts: dict[str, str],
    status_resolved: bool,
) -> tuple[dict[str, str], set[str]]:
    """
    Render the main menu.

    When status_resolved is True, a VM name absent from `states` is not
    just "not created" -- it isn't defined at all under the current
    LAB_PROFILE, and is shown as excluded rather than startable.

    Excluded VMs are listed for discoverability but are intentionally
    left out of the returned `options` mapping: they don't exist under
    the Vagrantfile's current LAB_PROFILE, so passing one to `vagrant`
    fails with "was not found configured for this Vagrant environment"
    instead of a clean, actionable message. Callers should route their
    selection number through `excluded` first.

    Returns (options, excluded):
        options:  selection number -> VM name, for VMs that are
                  selectable right now.
        excluded: selection numbers that correspond to a VM excluded by
                  the current LAB_PROFILE.
    """
    console.clear()

    console.print(
        Panel.fit(
            "[bold white]PENTEST VLAN LAB MANAGER v4.1[/bold white]",
            border_style="blue",
        )
    )

    if status_resolved:
        active_count = sum(1 for vm in ALL_VMS if vm in states)
        console.print(
            f"[dim]LAB_PROFILE: {active_count} of {len(ALL_VMS)} known "
            f"VMs active -- set LAB_PROFILE to change "
            f"(see the Vagrantfile's PROFILES table)[/dim]"
        )

    table = Table(
        show_header=False,
        box=None,
        padding=(0, 1, 0, 1),
    )

    table.add_column("ID", style="cyan", width=5)
    table.add_column("VM", style="white", width=18)
    table.add_column("State", width=15)
    table.add_column(
        "IP/Host",
        style="bright_black",
    )

    index = 1
    options: dict[str, str] = {}
    excluded: set[str] = set()

    for vlan_name, configured_vms in VLAN_GROUPS.items():
        table.add_row(
            "",
            f"[bold purple]{vlan_name}[/bold purple]",
            "",
            "",
            style="underline",
        )

        for vm in configured_vms:
            if status_resolved and vm not in states:
                table.add_row(
                    f"[{index:02d}]",
                    f"[dim]{vm}[/dim]",
                    "[yellow]excluded (LAB_PROFILE)[/yellow]",
                    "",
                )
                excluded.add(str(index))
                index += 1
                continue

            state = states.get(
                vm,
                "not_created",
            )

            icon = STATE_ICONS.get(
                state,
                STATE_ICONS["default"],
            )

            host = ssh_hosts.get(
                vm,
                "N/A",
            )

            table.add_row(
                f"[{index:02d}]",
                vm,
                f"{icon} {state}",
                host,
            )

            options[str(index)] = vm
            index += 1

        table.add_row()

    console.print(table)

    console.print(
        "[cyan][A] Start All   "
        "[B] Halt All   "
        "[R] Refresh   "
        "[Q] Quit[/cyan]"
    )

    return options, excluded


def vm_menu(
    vagrantfile: Path,
    vm: str,
) -> None:
    """Display the individual VM management menu."""
    while True:
        states, ssh_hosts = get_vagrant_inventory(
            vagrantfile
        )

        state = states.get(
            vm,
            "not_created",
        )

        host = ssh_hosts.get(
            vm,
            "N/A",
        )

        console.clear()

        console.print(
            Panel.fit(
                "[bold white]"
                "PENTEST VLAN LAB MANAGER v4.1"
                "[/bold white]",
                border_style="blue",
            )
        )

        console.print(
            f"VM:    [cyan]{vm}[/cyan]"
        )
        console.print(
            f"State: {state}"
        )
        console.print(
            f"Host:  {host}"
        )

        console.print("\n[cyan][S] SSH[/cyan]")
        console.print("[cyan][U] Up[/cyan]")
        console.print("[cyan][H] Halt[/cyan]")
        console.print("[cyan][D] Destroy[/cyan]")
        console.print("[cyan][R] Reload[/cyan]")
        console.print("[cyan][B] Back[/cyan]")

        choice = Prompt.ask(
            "[bold]Action[/bold]",
            default="B",
        ).upper()

        if choice == "S":
            if state != "running":
                console.print(
                    f"[yellow]{vm} is not running. "
                    "Start it before connecting via SSH."
                    "[/yellow]"
                )

            elif vm == "opnsense":
                result = ssh_opnsense(host)

                if not result.ok:
                    console.print(
                        f"[red]OPNsense SSH failed: "
                        f"{result.detail}[/red]"
                    )

            else:
                run_vagrant(
                    "ssh",
                    vagrantfile,
                    vm=vm,
                )

        elif choice == "U":
            run_vagrant(
                "up",
                vagrantfile,
                vm=vm,
            )

        elif choice == "H":
            run_vagrant(
                "halt",
                vagrantfile,
                vm=vm,
            )

        elif choice == "D":
            if Confirm.ask(
                f"[bold red]Really destroy {vm}?"
                "[/bold red]",
                default=False,
            ):
                run_vagrant(
                    "destroy",
                    vagrantfile,
                    vm=vm,
                    extra_args=["-f"],
                )

        elif choice == "R":
            run_vagrant(
                "reload",
                vagrantfile,
                vm=vm,
            )

        elif choice == "B":
            return

        else:
            console.print(
                "[red]Invalid option[/red]"
            )

        Prompt.ask(
            "[bright_black]Press Enter to continue...[/bright_black]",
            default="",
        )


# ========================== GROUP ACTIONS ==========================


def start_all(
    vagrantfile: Path,
    vms: tuple[str, ...] | list[str],
) -> VmAction:
    """
    Start the given lab VMs sequentially.

    --no-parallel is intentional and preserves the original Bash
    manager's network boot ordering. Callers should pass the VMs
    active under the current LAB_PROFILE (see resolve_active_vms),
    not unconditionally ALL_VMS.
    """
    console.print(
        "[green]Starting all VMs...[/green]"
    )

    return run_vagrant(
        "up",
        vagrantfile,
        vms_list=vms,
        extra_args=["--no-parallel"],
    )


def halt_all(
    vagrantfile: Path,
    vms: tuple[str, ...] | list[str],
) -> VmAction:
    """Halt the given lab VMs."""
    console.print(
        "[yellow]Halting all VMs...[/yellow]"
    )

    return run_vagrant(
        "halt",
        vagrantfile,
        vms_list=vms,
    )


# ========================== CLI HELPERS ==========================


def validate_vm_names(
    requested: list[str],
    states: dict[str, str],
) -> list[str]:
    """
    Validate explicitly supplied VM names.

    Uses Vagrant's discovered inventory when available and falls back
    to the authoritative ALL_VMS inventory when status is unavailable.
    """
    if not requested:
        return []

    known = set(states) if states else set(ALL_VMS)

    unknown = [
        vm
        for vm in requested
        if vm not in known
    ]

    if unknown:
        console.print(
            "[bold red]Unknown VM(s):[/bold red] "
            + ", ".join(unknown)
        )

        console.print(
            "[dim]Known lab VMs:[/dim] "
            + ", ".join(ALL_VMS)
        )

        return []

    # Preserve order while removing duplicates.
    return list(dict.fromkeys(requested))


def print_results(
    results: list[VmAction],
) -> None:
    """Display operation results."""
    table = Table(
        title="Result",
        show_lines=False,
    )

    table.add_column("Target")
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


# ========================== MAIN ==========================


def main() -> int:
    """Program entry point."""
    parser = argparse.ArgumentParser(
        description="Manage Pentest Lab VLAN VMs."
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
        help=(
            "Action: up (start), halt (stop), reload (restart), "
            "provision (run provisioning), destroy (delete), "
            "status (show)."
        ),
    )

    parser.add_argument(
        "vms",
        nargs="*",
        help="VM names to target (default: all).",
    )

    parser.add_argument(
        "--provision",
        action="store_true",
        help=(
            "Run Vagrant provisioning with the "
            "'up' or 'reload' action."
        ),
    )

    args = parser.parse_args()

    # ------------------------------------------------------------------
    # Find Vagrantfile.
    # ------------------------------------------------------------------

    vagrantfile = find_vagrantfile()

    if vagrantfile is None:
        console.print(
            "[bold red]Error:[/bold red] No Vagrantfile found "
            "in this directory or any parent."
        )
        return 1

    # ------------------------------------------------------------------
    # Require Vagrant.
    # ------------------------------------------------------------------

    if not require_vagrant():
        return 1

    # ------------------------------------------------------------------
    # Non-interactive CLI mode.
    # ------------------------------------------------------------------

    if args.action:
        if args.action == "status":
            result = run_vagrant(
                "status",
                vagrantfile,
            )

            return 0 if result.ok else 1

        states, _ = get_vagrant_inventory(
            vagrantfile
        )

        targets = validate_vm_names(
            args.vms,
            states,
        )

        if args.vms and not targets:
            return 1

        # Safety: never allow an implicit global destroy.
        if (
            args.action == "destroy"
            and not args.vms
        ):
            console.print(
                "[bold red]Error:[/bold red] Refusing to "
                "destroy all VMs without explicit targets."
            )

            console.print(
                "Specify VMs to destroy, for example:"
            )

            console.print(
                "  python3 vagrant_manager.py "
                "destroy kali DC01"
            )

            return 1

        # Determine additional Vagrant arguments.
        if args.action == "destroy":
            extra = ["-f"]

        elif (
            args.action in {"up", "reload"}
            and args.provision
        ):
            extra = ["--provision"]

        else:
            extra = None

        results: list[VmAction] = []

        # ------------------------------------------------------------------
        # No explicit VM targets.
        #
        # Preserve lab-wide policies:
        #   up       -> active-profile VMs + --no-parallel
        #   halt     -> active-profile VMs
        #   reload   -> active-profile VMs
        #   provision -> active-profile VMs
        #
        # "Active-profile VMs" comes from `vagrant status`, which already
        # reflects the Vagrantfile's LAB_PROFILE (explicit or
        # auto-detected) -- not a hardcoded ALL_VMS list. If `vagrant
        # status` is unavailable, this falls back to ALL_VMS, matching
        # the previous unconditional behavior.
        # ------------------------------------------------------------------

        if not args.vms:
            active_vms, status_resolved = resolve_active_vms(
                vagrantfile
            )

            if status_resolved and len(active_vms) < len(ALL_VMS):
                console.print(
                    f"[dim]LAB_PROFILE resolved to {len(active_vms)} "
                    f"of {len(ALL_VMS)} known VMs: "
                    f"{', '.join(active_vms)}[/dim]"
                )

            if args.action == "up":
                results.append(
                    run_vagrant(
                        "up",
                        vagrantfile,
                        vms_list=active_vms,
                        extra_args=["--no-parallel"],
                    )
                )

            elif args.action in {
                "halt",
                "reload",
                "provision",
            }:
                results.append(
                    run_vagrant(
                        args.action,
                        vagrantfile,
                        vms_list=active_vms,
                        extra_args=extra,
                    )
                )

        # ------------------------------------------------------------------
        # Explicit VM targets.
        # ------------------------------------------------------------------

        else:
            for vm in targets:
                results.append(
                    run_vagrant(
                        args.action,
                        vagrantfile,
                        vm=vm,
                        extra_args=extra,
                    )
                )

        if results:
            print_results(results)

            if any(
                not result.ok
                for result in results
            ):
                return 1

        return 0

    # ------------------------------------------------------------------
    # Interactive mode.
    # ------------------------------------------------------------------

    while True:
        states, ssh_hosts = get_vagrant_inventory(
            vagrantfile
        )
        active_vms = [vm for vm in ALL_VMS if vm in states] or list(ALL_VMS)
        status_resolved = bool(states)

        options, excluded = show_main_menu(
            states,
            ssh_hosts,
            status_resolved,
        )

        choice = Prompt.ask(
            "[bold]Selection[/bold]",
            default="R",
        )

        if choice.isdigit():
            if choice in options:
                vm_menu(
                    vagrantfile,
                    options[choice],
                )
                continue

            if choice in excluded:
                console.print(
                    "[yellow]That VM is excluded by the current "
                    "LAB_PROFILE and does not exist in this Vagrant "
                    "environment.[/yellow]"
                )
                console.print(
                    "[dim]Set LAB_PROFILE to a profile that includes "
                    "it, e.g. LAB_PROFILE=full[/dim]"
                )

                Prompt.ask(
                    "[bright_black]Press Enter to continue...[/bright_black]",
                    default="",
                )
                continue

        choice = choice.upper()

        if choice == "A":
            result = start_all(vagrantfile, active_vms)
            print_results([result])

        elif choice == "B":
            result = halt_all(vagrantfile, active_vms)
            print_results([result])

        elif choice == "R":
            continue

        elif choice == "Q":
            console.print("Bye.")
            return 0

        else:
            console.print(
                "[red]Invalid option[/red]"
            )

            Prompt.ask(
                "[bright_black]Press Enter to continue...[/bright_black]",
                default="",
            )


if __name__ == "__main__":
    sys.exit(main())