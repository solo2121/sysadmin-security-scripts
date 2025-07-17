#!/usr/bin/env python3
"""
security_monitor.py
Monitor open ports and system resources for basic security auditing.

Requires: Python 3.6+, ss, ps, df (all present in every modern Linux).
Run as root or with sudo.
"""

import argparse
import logging
import os
import signal
import subprocess
import sys
import time
from collections import namedtuple
from logging.handlers import RotatingFileHandler

# ------------------------------------------------------------------------------
# Configuration helpers
# ------------------------------------------------------------------------------
LOG_FORMAT = "%(asctime)s [%(levelname)s] %(message)s"
INTERVAL = 10  # seconds between resource snapshots

PortInfo = namedtuple("PortInfo", "proto local_addr pid process_name")

# ------------------------------------------------------------------------------
# Logging
# ------------------------------------------------------------------------------
def setup_logging(log_file: str, verbose: bool):
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(level=level, format=LOG_FORMAT, handlers=[
        RotatingFileHandler(log_file, maxBytes=1_000_000, backupCount=3),
        logging.StreamHandler(sys.stdout)
    ])

# ------------------------------------------------------------------------------
# System probes
# ------------------------------------------------------------------------------
def list_listening_ports() -> list[PortInfo]:
    """Return all listening TCP/UDP sockets with owning PID/name."""
    ports = []
    for proto in ("tcp", "udp"):
        # ss output: State Recv-Q Send-Q Local Address:Port  Peer Address:Port  Process
        cmd = ["ss", "-ltn" if proto == "tcp" else "-lun", "-p"]
        try:
            out = subprocess.check_output(cmd, text=True)
        except FileNotFoundError:
            logging.error("Command 'ss' not found. Install iproute2.")
            return []

        for line in out.splitlines():
            if "LISTEN" not in line and "UNCONN" not in line:
                continue
            parts = line.split()
            if len(parts) < 5:
                continue
            local_addr = parts[4]
            # Process field looks like users:(("nginx",pid=123,fd=3))
            process_field = parts[-1]
            pid = None
            name = None
            if "pid=" in process_field:
                try:
                    pid = int(process_field.split("pid=")[1].split(",")[0])
                    name = process_field.split('"')[1]
                except (IndexError, ValueError):
                    pass
            ports.append(PortInfo(proto.upper(), local_addr, pid, name))
    return ports

def get_resource_snapshot() -> dict:
    """Return CPU %, load averages, memory %, disk %."""
    # CPU usage via ps
    cpu_line = subprocess.check_output(
        ["ps", "-A", "-o", "%cpu", "--no-headers"], text=True
    )
    cpu_total = sum(float(x) for x in cpu_line.split())

    # Load averages
    load = os.getloadavg()

    # Memory usage via /proc/meminfo
    with open("/proc/meminfo") as f:
        meminfo = f.read()
    mem_total = int(next(line for line in meminfo.splitlines() if "MemTotal" in line).split()[1])
    mem_avail = int(next(line for line in meminfo.splitlines() if "MemAvailable" in line).split()[1])
    mem_used_pct = 100 * (1 - mem_avail / mem_total)

    # Disk usage via df
    disk_line = subprocess.check_output(
        ["df", "/", "-h", "--output=pcent"], text=True
    )
    disk_used_pct = int(disk_line.splitlines()[1].strip().rstrip("%"))

    return dict(
        cpu_total=cpu_total,
        load_1=load[0],
        load_5=load[1],
        load_15=load[2],
        mem_used_pct=mem_used_pct,
        disk_used_pct=disk_used_pct,
    )

# ------------------------------------------------------------------------------
# Main loop
# ------------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="Security port & resource monitor")
    parser.add_argument("-i", "--interval", type=int, default=INTERVAL,
                        help="Seconds between resource snapshots")
    parser.add_argument("-l", "--logfile", default="/var/log/security_monitor.log",
                        help="Path to rotating log file")
    parser.add_argument("-v", "--verbose", action="store_true",
                        help="Enable debug output")
    args = parser.parse_args()

    if os.geteuid() != 0:
        print("Warning: not running as root – some processes/ports may be invisible.")

    setup_logging(args.logfile, args.verbose)

    logging.info("Security monitor started (interval=%ss).", args.interval)

    # Graceful shutdown on SIGINT/SIGTERM
    shutdown = False
    def _sig_handler(signum, frame):
        nonlocal shutdown
        shutdown = True
    signal.signal(signal.SIGINT, _sig_handler)
    signal.signal(signal.SIGTERM, _sig_handler)

    last_ports = set()
    while not shutdown:
        # Ports
        ports = list_listening_ports()
        port_set = {(p.proto, p.local_addr, p.pid) for p in ports}
        new = port_set - last_ports
        closed = last_ports - port_set
        last_ports = port_set

        for p in ports:
            if (p.proto, p.local_addr, p.pid) in new:
                logging.warning("NEW open port: %s %s (PID %s %s)",
                                p.proto, p.local_addr, p.pid or "?", p.process_name or "?")
        for proto, addr, pid in closed:
            logging.info("CLOSED port: %s %s (PID %s)", proto, addr, pid or "?")

        # Resources
        res = get_resource_snapshot()
        logging.info("RESOURCES CPU=%.1f%% Load=%.2f/%.2f/%.2f Mem=%.1f%% Disk=%d%%",
                     res["cpu_total"], res["load_1"], res["load_5"], res["load_15"],
                     res["mem_used_pct"], res["disk_used_pct"])

        time.sleep(args.interval)

    logging.info("Security monitor stopped.")

if __name__ == "__main__":
    main()
