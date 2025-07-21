#!/usr/bin/env python3
"""
Amass Automation Script - Comprehensive Domain Enumeration Tool

Description:
This script automates the Amass enumeration process in three phases:
1. Passive reconnaissance (no direct interaction with target)
2. Active scanning with brute forcing techniques
3. Comprehensive enumeration with JSON and text outputs

The script creates timestamped output directories by default and handles
command execution with proper error reporting.

Author: Solo
Version: 1.0
Date: 2025-07-21
License: MIT

Usage: ./amass-scan.py <domain> [output-dir]
Example: ./amass-scan.py example.com scan-results
"""

import subprocess
import sys
import os
from datetime import datetime

def usage():
    """Display usage information and exit"""
    print("\nAmass Automation Script - Domain Enumeration Tool")
    print("-" * 50)
    print(f"Usage: {sys.argv[0]} <domain> [output-dir]")
    print(f"Example: {sys.argv[0]} example.com amass-results\n")
    sys.exit(1)

def run(cmd):
    """Execute shell command with real-time output and error handling"""
    print(f"[+] Executing: {' '.join(cmd)}")
    try:
        subprocess.run(cmd, check=True)
    except subprocess.CalledProcessError as e:
        print(f"[-] Command failed with error: {e}", file=sys.stderr)
        raise
    except FileNotFoundError:
        print("[-] Error: Amass not found. Please install Amass first.", file=sys.stderr)
        sys.exit(1)

def main():
    if len(sys.argv) < 2:
        usage()

    domain = sys.argv[1]
    output_dir = (
        sys.argv[2]
        if len(sys.argv) > 2
        else f"amass-scan-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
    )

    print(f"\n[+] Starting Amass enumeration for: {domain}")
    print(f"[+] Output directory: {output_dir}\n")
    
    os.makedirs(output_dir, exist_ok=True)

    # 1. Passive enumeration (no active probing)
    print("\n[PHASE 1] Passive Enumeration")
    run(["amass", "enum", "-passive", "-d", domain, "-o", f"{output_dir}/passive.txt"])

    # 2. Active enumeration with brute forcing
    print("\n[PHASE 2] Active Enumeration with Brute Forcing")
    run(["amass", "enum", "-active", "-brute", "-d", domain, "-o", f"{output_dir}/active.txt"])

    # 3. Full enumeration with JSON + text output
    print("\n[PHASE 3] Comprehensive Enumeration")
    run([
        "amass", "enum", "-d", domain,
        "-o", f"{output_dir}/full.txt",
        "-json", f"{output_dir}/full.json"
    ])

    print(f"\n[+] Scan completed successfully!")
    print(f"[+] Results saved in: {output_dir}/")
    print(f"[+] Files created:")
    print(f"    - passive.txt (passive results)")
    print(f"    - active.txt (active brute force results)")
    print(f"    - full.txt (comprehensive results)")
    print(f"    - full.json (JSON formatted comprehensive results)\n")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n[-] Scan interrupted by user. Exiting...")
        sys.exit(1)
    except Exception as e:
        print(f"[-] An unexpected error occurred: {e}", file=sys.stderr)
        sys.exit(1)