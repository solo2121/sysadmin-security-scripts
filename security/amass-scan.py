#!/usr/bin/env python3
"""
Amass Automation Script – Python 3
Usage: ./amass-scan.py <domain> [output-dir]
"""

import subprocess
import sys
import os
from datetime import datetime

def usage():
    print(f"Usage: {sys.argv[0]} <domain> [output-dir]")
    print(f"Example: {sys.argv[0]} example.com amass-results")
    sys.exit(1)

def run(cmd):
    """Run shell command and stream output to terminal"""
    print(f"[CMD] {' '.join(cmd)}")
    subprocess.run(cmd, check=True)

def main():
    if len(sys.argv) < 2:
        usage()

    domain = sys.argv[1]
    output_dir = (
        sys.argv[2]
        if len(sys.argv) > 2
        else f"amass-scan-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
    )

    print(f"[*] Creating output directory: {output_dir}")
    os.makedirs(output_dir, exist_ok=True)

    print(f"[*] Starting Amass enumeration for domain: {domain}")

    # 1. Passive enumeration (no active probing)
    run(["amass", "enum", "-passive", "-d", domain, "-o", f"{output_dir}/passive.txt"])

    # 2. Active enumeration with brute forcing and DNS resolution
    run(["amass", "enum", "-active", "-brute", "-d", domain, "-o", f"{output_dir}/active.txt"])

    # 3. Full enumeration with JSON + text output
    run([
        "amass", "enum", "-d", domain,
        "-o", f"{output_dir}/full.txt",
        "-json", f"{output_dir}/full.json"
    ])

    print(f"[+] Amass scan completed. Results saved in {output_dir}/")

if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as e:
        print("[-] Command failed:", e, file=sys.stderr)
        sys.exit(1)