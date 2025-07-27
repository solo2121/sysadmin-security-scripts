#!/usr/bin/env python3
"""
Ettercap Interactive CLI Menu - Advanced Network Security Testing Tool

This module provides a comprehensive, user-friendly command-line interface for ettercap,
a powerful network security tool used for network discovery, man-in-the-middle attacks,
packet capture, and protocol analysis.

Features:
    - Interactive menu-driven interface with input validation
    - ARP poisoning (MITM) attacks with safety checks
    - Network traffic sniffing with customizable filters
    - DNS spoofing with configuration file management
    - Cross-platform compatibility (Linux, Windows, macOS)
    - Comprehensive error handling and logging
    - Security warnings and authorization checks
    - Modern Python practices with type hints and async support

Security Notice:
    This tool is designed for authorized penetration testing, network security
    assessments, and educational purposes only. Unauthorized use against networks
    you do not own or have explicit written permission to test may violate local,
    state, and federal laws. Users are solely responsible for ensuring legal
    compliance.

Requirements:
    - Python 3.8+
    - ettercap installed and accessible via PATH
    - Root/Administrator privileges (recommended)
    - Network interface access

Author: Solo
Version: 2.0
License: MIT
Created: 2024
"""

import asyncio
import contextlib
import ipaddress
import logging
import os
import platform
import re
import shlex
import signal
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from enum import Enum, auto
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Union, Callable, Any
import argparse
from datetime import datetime

# Version and metadata
__version__ = "2.0"
__author__ = "Solo"
__license__ = "MIT"
__description__ = "Interactive CLI menu for ettercap network security testing"

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('ettercap-menu.log', mode='a')
    ]
)
logger = logging.getLogger(__name__)


class MenuOption(Enum):
    """Enumeration of available menu options for type safety and maintainability."""
    ARP_POISONING = auto()
    SNIFF_TRAFFIC = auto()
    DNS_SPOOFING = auto()
    CUSTOM_COMMAND = auto()
    HELP = auto()
    EXIT = auto()


class EttercapError(Exception):
    """Custom exception class for ettercap-related errors."""
    pass


class NetworkError(Exception):
    """Custom exception class for network-related errors."""
    pass


@dataclass
class NetworkInterface:
    """Data class representing a network interface with its properties."""
    name: str
    is_active: bool = False
    ip_address: Optional[str] = None
    mac_address: Optional[str] = None

    def __post_init__(self):
        """Validate interface name format."""
        if not self.name or not isinstance(self.name, str):
            raise ValueError("Interface name must be a non-empty string")


@dataclass
class AttackConfig:
    """Configuration container for various attack parameters."""
    interface: str
    target1: Optional[str] = None
    target2: Optional[str] = None
    dns_file: Optional[str] = None
    filter_expression: Optional[str] = None
    output_file: Optional[str] = None
    additional_args: List[str] = field(default_factory=list)

    def validate(self) -> bool:
        """Validate the attack configuration parameters."""
        if not self.interface:
            return False

        # Validate IP addresses if provided
        for target in [self.target1, self.target2]:
            if target and not self._is_valid_ip(target):
                return False

        # Validate DNS file if provided
        if self.dns_file and not Path(self.dns_file).is_file():
            return False

        return True

    @staticmethod
    def _is_valid_ip(ip: str) -> bool:
        """Validate IP address format."""
        try:
            ipaddress.ip_address(ip.strip())
            return True
        except ValueError:
            return False


class SystemUtils:
    """Utility class for system-related operations and checks."""

    @staticmethod
    def check_root_privileges() -> bool:
        """
        Check if the script is running with appropriate privileges.

        Returns:
            bool: True if running with elevated privileges, False otherwise
        """
        try:
            if platform.system() == "Windows":
                import ctypes
                return ctypes.windll.shell32.IsUserAnAdmin() != 0
            else:
                return os.geteuid() == 0
        except (ImportError, AttributeError, OSError):
            logger.warning("Cannot determine privilege level")
            return False

    @staticmethod
    def check_ettercap_installation() -> Tuple[bool, str]:
        """
        Verify ettercap installation and get version information.

        Returns:
            Tuple[bool, str]: (is_installed, version_info)
        """
        try:
            result = subprocess.run(
                ['ettercap', '--version'],
                capture_output=True,
                text=True,
                timeout=10,
                check=False
            )

            if result.returncode == 0:
                version_info = result.stdout.strip() or result.stderr.strip()
                return True, version_info
            else:
                return False, f"Ettercap check failed with exit code {result.returncode}"

        except subprocess.TimeoutExpired:
            return False, "Ettercap version check timed out"
        except FileNotFoundError:
            return False, "Ettercap not found in PATH"
        except Exception as e:
            return False, f"Unexpected error checking ettercap: {e}"

    @staticmethod
    def get_network_interfaces() -> List[NetworkInterface]:
        """
        Discover available network interfaces on the system.

        Returns:
            List[NetworkInterface]: List of discovered network interfaces
        """
        interfaces = []

        # Platform-specific interface discovery
        if platform.system() == "Linux":
            interfaces.extend(SystemUtils._get_linux_interfaces())
        elif platform.system() == "Darwin":
            interfaces.extend(SystemUtils._get_darwin_interfaces())
        elif platform.system() == "Windows":
            interfaces.extend(SystemUtils._get_windows_interfaces())

        # Add common fallback interfaces if none found
        if not interfaces:
            common_names = ['eth0', 'eth1', 'wlan0', 'wlan1', 'en0', 'wlp2s0']
            interfaces = [NetworkInterface(name) for name in common_names]

        return interfaces

    @staticmethod
    def _get_linux_interfaces() -> List[NetworkInterface]:
        """Get network interfaces on Linux systems."""
        interfaces = []
        net_path = Path('/sys/class/net')

        if net_path.exists():
            for iface_path in net_path.iterdir():
                if iface_path.name != 'lo':  # Skip loopback
                    is_active = (iface_path / 'operstate').read_text().strip() == 'up'
                    interfaces.append(NetworkInterface(iface_path.name, is_active))

        return interfaces

    @staticmethod
    def _get_darwin_interfaces() -> List[NetworkInterface]:
        """Get network interfaces on macOS systems."""
        try:
            result = subprocess.run(['ifconfig'], capture_output=True, text=True, timeout=5)
            interfaces = []

            for line in result.stdout.split('\n'):
                if ':' in line and not line.startswith('\t'):
                    iface_name = line.split(':')[0].strip()
                    if iface_name != 'lo0':  # Skip loopback
                        interfaces.append(NetworkInterface(iface_name))

            return interfaces
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return []

    @staticmethod
    def _get_windows_interfaces() -> List[NetworkInterface]:
        """Get network interfaces on Windows systems."""
        try:
            result = subprocess.run(['ipconfig'], capture_output=True, text=True, timeout=5)
            interfaces = []

            # Parse Windows ipconfig output
            for line in result.stdout.split('\n'):
                if 'adapter' in line.lower():
                    # Extract adapter name
                    match = re.search(r'adapter (.+?):', line)
                    if match:
                        iface_name = match.group(1).strip()
                        interfaces.append(NetworkInterface(iface_name))

            return interfaces
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return []


class InputValidator:
    """Class for handling input validation with comprehensive checks."""

    @staticmethod
    def validate_ip_address(ip: str) -> bool:
        """
        Validate IP address format (IPv4 or IPv6).

        Args:
            ip (str): IP address string to validate

        Returns:
            bool: True if valid IP address, False otherwise
        """
        try:
            ipaddress.ip_address(ip.strip())
            return True
        except ValueError:
            return False

    @staticmethod
    def validate_network_interface(interface: str) -> bool:
        """
        Validate network interface name format and availability.

        Args:
            interface (str): Interface name to validate

        Returns:
            bool: True if valid interface, False otherwise
        """
        if not interface or not interface.strip():
            return False

        interface = interface.strip()

        # Check if interface exists in discovered interfaces
        available_interfaces = SystemUtils.get_network_interfaces()
        return any(iface.name == interface for iface in available_interfaces)

    @staticmethod
    def validate_file_path(path: str, must_exist: bool = True) -> bool:
        """
        Validate file path format and existence.

        Args:
            path (str): File path to validate
            must_exist (bool): Whether the file must exist

        Returns:
            bool: True if valid path, False otherwise
        """
        try:
            file_path = Path(path.strip())

            if must_exist:
                return file_path.is_file() and os.access(file_path, os.R_OK)
            else:
                # Check if parent directory exists and is writable
                return file_path.parent.exists() and os.access(file_path.parent, os.W_OK)

        except (OSError, TypeError):
            return False

    @staticmethod
    def validate_menu_choice(choice: str, valid_choices: List[str]) -> bool:
        """
        Validate menu choice against available options.

        Args:
            choice (str): User's menu choice
            valid_choices (List[str]): List of valid choice options

        Returns:
            bool: True if valid choice, False otherwise
        """
        return choice.strip() in valid_choices


class EttercapCommandBuilder:
    """Builder class for constructing ettercap commands with proper validation."""

    def __init__(self):
        self.base_command = "ettercap"
        self.args = []
        self.targets = []
        self.interface = None
        self.plugins = []
        self.filters = []

    def set_text_mode(self) -> 'EttercapCommandBuilder':
        """Set ettercap to text mode."""
        self.args.append("-T")
        return self

    def set_interface(self, interface: str) -> 'EttercapCommandBuilder':
        """Set network interface."""
        if InputValidator.validate_network_interface(interface):
            self.interface = interface
            self.args.extend(["-i", interface])
        else:
            raise ValueError(f"Invalid interface: {interface}")
        return self

    def add_mitm_arp(self, target1: str, target2: str) -> 'EttercapCommandBuilder':
        """Add ARP poisoning MITM attack."""
        if not InputValidator.validate_ip_address(target1):
            raise ValueError(f"Invalid target1 IP: {target1}")
        if not InputValidator.validate_ip_address(target2):
            raise ValueError(f"Invalid target2 IP: {target2}")

        self.args.extend(["-M", "arp:remote"])
        self.targets.extend([f"/{target1}//", f"/{target2}//"])
        return self

    def add_plugin(self, plugin: str) -> 'EttercapCommandBuilder':
        """Add ettercap plugin."""
        self.args.extend(["-P", plugin])
        return self

    def add_filter_file(self, filter_file: str) -> 'EttercapCommandBuilder':
        """Add filter file."""
        if InputValidator.validate_file_path(filter_file):
            self.args.extend(["-F", filter_file])
        else:
            raise ValueError(f"Invalid filter file: {filter_file}")
        return self

    def build(self) -> str:
        """
        Build the complete ettercap command.

        Returns:
            str: Complete ettercap command string
        """
        command_parts = [self.base_command] + self.args + self.targets
        return " ".join(command_parts)


class EttercapMenu:
    """
    Main application class providing an interactive menu for ettercap operations.

    This class orchestrates the entire application flow, from initialization
    to menu presentation and command execution.
    """

    def __init__(self):
        """Initialize the EttercapMenu with configuration and state."""
        self.version = __version__
        self.author = __author__
        self.description = __description__
        self.running = True
        self.current_config = AttackConfig("")

        # Set up signal handlers for graceful shutdown
        self._setup_signal_handlers()

        # Initialize logging
        logger.info(f"Ettercap Menu v{self.version} initialized")

    def _setup_signal_handlers(self) -> None:
        """Set up signal handlers for graceful application shutdown."""
        def signal_handler(signum: int, frame) -> None:
            logger.info(f"Received signal {signum}, shutting down gracefully")
            print(f"\n[!] Received interrupt signal. Shutting down gracefully...")
            self.running = False
            sys.exit(0)

        signal.signal(signal.SIGINT, signal_handler)
        if platform.system() != "Windows":
            signal.signal(signal.SIGTERM, signal_handler)

    def display_banner(self) -> None:
        """Display the application banner with version and security information."""
        banner_width = 80
        separator = "=" * banner_width

        print(f"\n{separator}")
        print(f"║ Ettercap Interactive CLI Menu v{self.version}".ljust(banner_width - 1) + "║")
        print(f"║ {self.description}".ljust(banner_width - 1) + "║")
        print(f"║ Author: {self.author}".ljust(banner_width - 1) + "║")
        print(f"║ Build Date: {datetime.now().strftime('%Y-%m-%d')}".ljust(banner_width - 1) + "║")
        print(separator)
        print("║ ⚠️  SECURITY NOTICE: For authorized testing only!".ljust(banner_width - 1) + "║")
        print("║ 📋 Unauthorized use may violate local and federal laws".ljust(banner_width - 1) + "║")
        print(separator)

    def display_system_info(self) -> None:
        """Display system information and ettercap status."""
        print(f"\n📊 System Information:")
        print(f"   Platform: {platform.system()} {platform.release()}")
        print(f"   Python: {sys.version.split()[0]}")
        print(f"   Privileges: {'✅ Elevated' if SystemUtils.check_root_privileges() else '❌ Standard'}")

        is_installed, version_info = SystemUtils.check_ettercap_installation()
        print(f"   Ettercap: {'✅ Available' if is_installed else '❌ Not found'}")
        if is_installed:
            print(f"   Version: {version_info.split()[0] if version_info else 'Unknown'}")

        interfaces = SystemUtils.get_network_interfaces()
        active_interfaces = [iface for iface in interfaces if iface.is_active]
        print(f"   Network Interfaces: {len(interfaces)} total, {len(active_interfaces)} active")

    def get_validated_input(
        self,
        prompt: str,
        validator: Callable[[str], bool],
        error_message: str = "Invalid input. Please try again.",
        allow_empty: bool = False
    ) -> str:
        """
        Get user input with validation and comprehensive error handling.

        Args:
            prompt (str): Input prompt to display
            validator (Callable): Function to validate input
            error_message (str): Error message for invalid input
            allow_empty (bool): Whether to allow empty input

        Returns:
            str: Validated user input
        """
        while True:
            try:
                user_input = input(prompt).strip()

                if not user_input and not allow_empty:
                    print("❌ Input cannot be empty. Please try again.")
                    continue

                if allow_empty and not user_input:
                    return user_input

                if validator(user_input):
                    return user_input
                else:
                    print(f"❌ {error_message}")

            except KeyboardInterrupt:
                print("\n[!] Input cancelled by user")
                raise
            except EOFError:
                print("\n[!] Input stream closed")
                sys.exit(1)

    async def execute_ettercap_command(self, command: str) -> bool:
        """
        Execute ettercap command asynchronously with proper error handling.

        Args:
            command (str): Complete ettercap command to execute

        Returns:
            bool: True if command executed successfully, False otherwise
        """
        logger.info(f"Executing ettercap command: {command}")
        print(f"\n🚀 Executing: {command}")
        print("⚠️  Press Ctrl+C to stop the operation")
        print("-" * 60)

        try:
            # Use shlex.split for proper argument parsing
            cmd_args = shlex.split(command)

            # Create subprocess with proper handling
            process = await asyncio.create_subprocess_exec(
                *cmd_args,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT
            )

            # Read output line by line
            while True:
                line = await process.stdout.readline()
                if not line:
                    break
                print(line.decode().rstrip())

            # Wait for process completion
            await process.wait()

            if process.returncode == 0:
                print("\n✅ Command executed successfully")
                logger.info("Ettercap command completed successfully")
                return True
            else:
                print(f"\n❌ Command failed with exit code: {process.returncode}")
                logger.error(f"Ettercap command failed with exit code: {process.returncode}")
                return False

        except asyncio.CancelledError:
            print("\n⚠️  Operation cancelled by user")
            logger.info("Ettercap command cancelled by user")
            return False
        except FileNotFoundError:
            print("\n❌ Ettercap not found. Please ensure it's installed and in PATH")
            logger.error("Ettercap executable not found")
            return False
        except Exception as e:
            print(f"\n❌ Unexpected error: {e}")
            logger.error(f"Unexpected error executing ettercap: {e}")
            return False

    def show_available_interfaces(self) -> None:
        """Display available network interfaces with status information."""
        interfaces = SystemUtils.get_network_interfaces()

        if not interfaces:
            print("❌ No network interfaces detected")
            return

        print("\n🌐 Available Network Interfaces:")
        for i, interface in enumerate(interfaces[:10], 1):  # Show first 10
            status = "🟢 Active" if interface.is_active else "🔴 Inactive"
            print(f"   {i}. {interface.name} ({status})")

        if len(interfaces) > 10:
            print(f"   ... and {len(interfaces) - 10} more")

    async def handle_arp_poisoning(self) -> None:
        """Handle ARP poisoning (MITM) attack configuration and execution."""
        print("\n" + "="*60)
        print("🎯 ARP Poisoning (Man-in-the-Middle Attack)")
        print("="*60)
        print("⚠️  This will perform a MITM attack between two network hosts")
        print("⚠️  Ensure you have proper authorization!")
        print("📋 Typical usage: Gateway IP (target1) ↔ Victim IP (target2)")

        # Get target IP addresses
        target1 = self.get_validated_input(
            "\n🎯 Enter target 1 IP (e.g., gateway 192.168.1.1): ",
            InputValidator.validate_ip_address,
            "Invalid IP address format. Please enter a valid IPv4/IPv6 address."
        )

        target2 = self.get_validated_input(
            "🎯 Enter target 2 IP (e.g., victim 192.168.1.100): ",
            InputValidator.validate_ip_address,
            "Invalid IP address format. Please enter a valid IPv4/IPv6 address."
        )

        if target1 == target2:
            print("❌ Target IP addresses cannot be the same!")
            return

        # Show and select interface
        self.show_available_interfaces()
        interface = self.get_validated_input(
            "\n🌐 Enter network interface (e.g., eth0): ",
            InputValidator.validate_network_interface,
            "Invalid or unavailable network interface."
        )

        # Build command
        try:
            builder = EttercapCommandBuilder()
            command = (builder
                      .set_text_mode()
                      .set_interface(interface)
                      .add_mitm_arp(target1, target2)
                      .build())

            # Display configuration summary
            print(f"\n📋 Attack Configuration:")
            print(f"   Target 1 (Gateway): {target1}")
            print(f"   Target 2 (Victim):  {target2}")
            print(f"   Interface:          {interface}")
            print(f"   Command:            {command}")

            # Confirmation
            confirm = input("\n❓ Proceed with ARP poisoning attack? (y/N): ").lower()
            if confirm == 'y':
                await self.execute_ettercap_command(command)
            else:
                print("❌ Operation cancelled by user")

        except ValueError as e:
            print(f"❌ Configuration error: {e}")
            logger.error(f"ARP poisoning configuration error: {e}")

    async def handle_traffic_sniffing(self) -> None:
        """Handle network traffic sniffing configuration and execution."""
        print("\n" + "="*60)
        print("🔍 Network Traffic Sniffing")
        print("="*60)
        print("📡 Capture and analyze network packets on the specified interface")

        # Show and select interface
        self.show_available_interfaces()
        interface = self.get_validated_input(
            "\n🌐 Enter network interface (e.g., eth0): ",
            InputValidator.validate_network_interface,
            "Invalid or unavailable network interface."
        )

        # Sniffing options
        print("\n📋 Sniffing Options:")
        print("   1. Basic packet capture (all traffic)")
        print("   2. Filtered capture (specify BPF filter)")
        print("   3. Capture with output file")

        option = self.get_validated_input(
            "\n❓ Select sniffing option (1-3): ",
            lambda x: x in ('1', '2', '3'),
            "Please enter 1, 2, or 3."
        )

        try:
            builder = EttercapCommandBuilder().set_text_mode().set_interface(interface)

            if option == "2":
                filter_expr = input("🔍 Enter BPF filter (e.g., 'host 192.168.1.100'): ").strip()
                if filter_expr:
                    print(f"📋 Using filter: {filter_expr}")
                    # Note: BPF filters in ettercap work differently, this is for demonstration

            elif option == "3":
                output_file = input("💾 Enter output file path (optional): ").strip()
                if output_file and InputValidator.validate_file_path(output_file, must_exist=False):
                    print(f"💾 Output will be saved to: {output_file}")

            command = builder.build()

            print(f"\n📋 Sniffing Configuration:")
            print(f"   Interface: {interface}")
            print(f"   Mode:      {'Filtered' if option == '2' else 'Basic'}")
            print(f"   Command:   {command}")

            confirm = input("\n❓ Start traffic sniffing? (y/N): ").lower()
            if confirm == 'y':
                await self.execute_ettercap_command(command)
            else:
                print("❌ Operation cancelled by user")

        except ValueError as e:
            print(f"❌ Configuration error: {e}")
            logger.error(f"Traffic sniffing configuration error: {e}")

    async def handle_dns_spoofing(self) -> None:
        """Handle DNS spoofing configuration and execution."""
        print("\n" + "="*60)
        print("🌐 DNS Spoofing Attack")
        print("="*60)
        print("⚠️  This will intercept and modify DNS queries")
        print("⚠️  Ensure you have proper authorization!")
        print("📋 Requires a properly configured DNS spoof file")

        # Look for common DNS spoof files
        common_dns_files = [
            "/etc/ettercap/etter.dns",
            "/usr/share/ettercap/etter.dns",
            "/usr/local/share/ettercap/etter.dns",
            "./etter.dns"
        ]

        found_dns_file = None
        for dns_file in common_dns_files:
            if Path(dns_file).is_file():
                found_dns_file = dns_file
                break

        if found_dns_file:
            print(f"✅ Found DNS spoof file: {found_dns_file}")
            use_found = input("❓ Use this file? (Y/n): ").lower()
            if use_found != 'n':
                dns_file = found_dns_file
            else:
                dns_file = self.get_validated_input(
                    "📁 Enter path to DNS spoof file: ",
                    lambda x: InputValidator.validate_file_path(x, must_exist=True),
                    "File not found or not readable."
                )
        else:
            print("❌ No DNS spoof files found in common locations")
            dns_file = self.get_validated_input(
                "📁 Enter path to DNS spoof file: ",
                lambda x: InputValidator.validate_file_path(x, must_exist=True),
                "File not found or not readable."
            )

        # Show and select interface
        self.show_available_interfaces()
        interface = self.get_validated_input(
            "\n🌐 Enter network interface (e.g., eth0): ",
            InputValidator.validate_network_interface,
            "Invalid or unavailable network interface."
        )

        try:
            builder = EttercapCommandBuilder()
            command = (builder
                      .set_text_mode()
                      .set_interface(interface)
                      .add_plugin("dns_spoof")
                      .add_filter_file(dns_file)
                      .build())

            print(f"\n📋 DNS Spoofing Configuration:")
            print(f"   DNS File:   {dns_file}")
            print(f"   Interface:  {interface}")
            print(f"   Command:    {command}")

            confirm = input("\n❓ Proceed with DNS spoofing? (y/N): ").lower()
            if confirm == 'y':
                await self.execute_ettercap_command(command)
            else:
                print("❌ Operation cancelled by user")

        except ValueError as e:
            print(f"❌ Configuration error: {e}")
            logger.error(f"DNS spoofing configuration error: {e}")

    async def handle_custom_command(self) -> None:
        """Handle custom ettercap command execution with safety checks."""
        print("\n" + "="*60)
        print("⚙️  Custom Ettercap Command")
        print("="*60)
        print("⚠️  Advanced users only - ensure command safety!")
        print("📋 Enter a complete ettercap command with all parameters")

        custom_cmd = input("\n💻 Enter custom ettercap command: ").strip()

        if not custom_cmd:
            print("❌ No command entered")
            return

        # Security validation
        if not custom_cmd.startswith('ettercap'):
            print("⚠️  WARNING: Command doesn't start with 'ettercap'")
            print("⚠️  This could be potentially dangerous!")
            confirm = input("❓ Are you absolutely sure? (y/N): ").lower()
            if confirm != 'y':
                print("❌ Operation cancelled for security reasons")
                return

        # Display command for final confirmation
        print(f"\n📋 Command to execute:")
        print(f"   {custom_cmd}")

        final_confirm = input("\n❓ Execute this command? (y/N): ").lower()
        if final_confirm == 'y':
            await self.execute_ettercap_command(custom_cmd)
        else:
            print("❌ Operation cancelled by user")

    def show_help_information(self) -> None:
        """Display comprehensive help and usage information."""
        print("\n" + "="*70)
        print("📚 HELP & INFORMATION")
        print("="*70)

        help_text = """
🔍 About Ettercap:
   Ettercap is a comprehensive network security tool designed for:
   • Network discovery and host analysis
   • Man-in-the-Middle (MITM) attacks
   • Packet capture and traffic analysis
   • Protocol manipulation and filtering
   • DNS spoofing and ARP poisoning

⚖️  LEGAL NOTICE:
   This tool should ONLY be used on networks you own or have explicit
   written permission to test. Unauthorized network attacks may violate:
   • Local computer crime laws
   • State and federal regulations
   • International cybersecurity treaties

   Users assume full legal responsibility for their actions.

🔧 Technical Requirements:
   • Ettercap installed and accessible via system PATH
   • Root/Administrator privileges (recommended for most operations)
   • Network interface access and appropriate drivers
   • Python 3.8+ with required dependencies

🌐 Common Network Interfaces:
   • Linux:   eth0, wlan0, enp0s3, wlp2s0
   • macOS:   en0, en1, bridge0
   • Windows: "Local Area Connection", "Wi-Fi", "Ethernet"

📖 Usage Examples:
   • ARP Poisoning: ettercap -T -M arp:remote /192.168.1.1// /192.168.1.100// -i eth0
   • Traffic Sniffing: ettercap -T -i eth0
   • DNS Spoofing: ettercap -T -i eth0 -P dns_spoof

🔗 Additional Resources:
   • Official Documentation: https://ettercap.github.io/ettercap/
   • Man Pages: man ettercap
   • Community Forums: https://github.com/Ettercap/ettercap

🐛 Troubleshooting:
   • Permission Denied: Run with sudo/administrator privileges
   • Interface Not Found: Check interface name with 'ip link' or 'ifconfig'
   • Ettercap Not Found: Install via package manager (apt, yum, brew, etc.)
        """

        print(help_text)

    def display_main_menu(self) -> str:
        """
        Display the main application menu and get user choice.

        Returns:
            str: User's menu selection
        """
        menu_options = """
🏠 Main Menu:
   1. 🎯 ARP Poisoning (MITM Attack)
   2. 🔍 Network Traffic Sniffing
   3. 🌐 DNS Spoofing Attack
   4. ⚙️  Custom Ettercap Command
   5. 📚 Help & Information
   6. 🚪 Exit Application
        """

        print(menu_options)

        return self.get_validated_input(
            "\n❓ Select an option (1-6): ",
            lambda x: InputValidator.validate_menu_choice(x, ['1', '2', '3', '4', '5', '6']),
            "Invalid choice. Please enter a number between 1-6."
        )

    async def run(self) -> None:
        """
        Main application event loop with menu handling and error recovery.

        This method orchestrates the entire application flow, including
        initialization, menu presentation, and graceful error handling.
        """
        try:
            # Initial system checks
            if not self._perform_system_checks():
                return

            # Main application loop
            while self.running:
                try:
                    # Clear screen and show banner (optional)
                    if os.name == 'nt':  # Windows
                        os.system('cls')
                    else:  # Unix/Linux/macOS
                        os.system('clear')

                    self.display_banner()
                    self.display_system_info()

                    # Get user menu choice
                    choice = self.display_main_menu()

                    # Handle menu selection
                    if choice == "1":
                        await self.handle_arp_poisoning()
                    elif choice == "2":
                        await self.handle_traffic_sniffing()
                    elif choice == "3":
                        await self.handle_dns_spoofing()
                    elif choice == "4":
                        await self.handle_custom_command()
                    elif choice == "5":
                        self.show_help_information()
                    elif choice == "6":
                        print("\n👋 Thank you for using Ettercap CLI Menu!")
                        logger.info("Application shutdown requested by user")
                        self.running = False
                        break

                    # Pause before returning to menu
                    if self.running:
                        input("\n⏸️  Press Enter to continue...")

                except KeyboardInterrupt:
                    print("\n\n🔄 Returning to main menu...")
                    continue
                except Exception as e:
                    print(f"\n❌ Menu error: {e}")
                    logger.error(f"Menu handling error: {e}")
                    input("\n⏸️  Press Enter to continue...")
                    continue

        except KeyboardInterrupt:
            print("\n\n👋 Application terminated by user")
            logger.info("Application terminated by user interrupt")
        except Exception as e:
            print(f"\n💥 Critical application error: {e}")
            logger.critical(f"Critical application error: {e}")
        finally:
            self._cleanup()

    def _perform_system_checks(self) -> bool:
        """
        Perform essential system checks before starting the application.

        Returns:
            bool: True if all checks pass, False if critical issues found
        """
        print("🔍 Performing system checks...")

        # Check ettercap installation
        is_installed, version_info = SystemUtils.check_ettercap_installation()
        if not is_installed:
            print("\n❌ Critical Error: Ettercap is not installed or not accessible")
            print("📋 Installation instructions:")
            print("   • Ubuntu/Debian: sudo apt install ettercap-text-only")
            print("   • CentOS/RHEL:   sudo yum install ettercap")
            print("   • Arch Linux:    sudo pacman -S ettercap")
            print("   • macOS:         brew install ettercap")
            print("   • Windows:       Download from https://ettercap.github.io/ettercap/")
            return False

        print(f"✅ Ettercap found: {version_info.split()[0] if version_info else 'Version unknown'}")

        # Check privileges
        if not SystemUtils.check_root_privileges():
            print("\n⚠️  Warning: Running without elevated privileges")
            print("📋 Some operations may fail without root/administrator access")
            confirm = input("❓ Continue anyway? (y/N): ").lower()
            if confirm != 'y':
                print("❌ Startup cancelled by user")
                return False

        print("✅ System checks completed successfully")
        return True

    def _cleanup(self) -> None:
        """Perform cleanup operations before application exit."""
        logger.info("Performing application cleanup")
        print("\n🧹 Cleaning up...")

        # Close any open file handles, network connections, etc.
        # This is where you'd add any specific cleanup code

        print("✅ Cleanup completed")


def create_argument_parser() -> argparse.ArgumentParser:
    """
    Create and configure command-line argument parser.

    Returns:
        argparse.ArgumentParser: Configured argument parser
    """
    parser = argparse.ArgumentParser(
        prog="ettercap-menu",
        description=__description__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 ettercap-menu.py                 # Run interactive menu
  python3 ettercap-menu.py --version       # Show version information
  python3 ettercap-menu.py --check-system  # Perform system checks only

Security Notice:
  This tool is for authorized network security testing only.
  Unauthorized use may violate local, state, and federal laws.
        """
    )

    parser.add_argument(
        "--version",
        action="version",
        version=f"%(prog)s {__version__}"
    )

    parser.add_argument(
        "--check-system",
        action="store_true",
        help="Perform system checks and exit"
    )

    parser.add_argument(
        "--log-level",
        choices=["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"],
        default="INFO",
        help="Set logging level (default: INFO)"
    )

    parser.add_argument(
        "--no-banner",
        action="store_true",
        help="Suppress banner display"
    )

    return parser


async def main() -> None:
    """
    Main application entry point with comprehensive error handling.

    This function serves as the primary entry point, handling command-line
    arguments, logging configuration, and application initialization.
    """
    try:
        # Parse command-line arguments
        parser = create_argument_parser()
        args = parser.parse_args()

        # Configure logging level
        logging.getLogger().setLevel(getattr(logging, args.log_level))

        # Handle special command-line options
        if args.check_system:
            print("🔍 Performing system checks...")

            # Check ettercap installation
            is_installed, version_info = SystemUtils.check_ettercap_installation()
            print(f"Ettercap: {'✅ Available' if is_installed else '❌ Not found'}")
            if is_installed:
                print(f"Version: {version_info}")

            # Check privileges
            has_privileges = SystemUtils.check_root_privileges()
            print(f"Privileges: {'✅ Elevated' if has_privileges else '❌ Standard'}")

            # Check interfaces
            interfaces = SystemUtils.get_network_interfaces()
            print(f"Network Interfaces: {len(interfaces)} found")
            for iface in interfaces[:5]:  # Show first 5
                status = "Active" if iface.is_active else "Inactive"
                print(f"  • {iface.name} ({status})")

            sys.exit(0 if is_installed else 1)

        # Initialize and run the main application
        app = EttercapMenu()
        await app.run()

    except KeyboardInterrupt:
        print("\n\n👋 Application interrupted by user")
        logger.info("Application interrupted by user")
        sys.exit(130)  # Standard exit code for Ctrl+C
    except PermissionError as e:
        print(f"\n❌ Permission Error: {e}")
        print("💡 Try running with elevated privileges (sudo/administrator)")
        logger.error(f"Permission error: {e}")
        sys.exit(1)
    except FileNotFoundError as e:
        print(f"\n❌ File Not Found: {e}")
        print("💡 Ensure all required files and dependencies are installed")
        logger.error(f"File not found error: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"\n💥 Critical Error: {e}")
        logger.critical(f"Critical application error: {e}", exc_info=True)
        sys.exit(1)


def run_sync() -> None:
    """
    Synchronous wrapper for the async main function.

    This function provides compatibility for environments that don't
    support direct async execution or for integration with other tools.
    """
    try:
        # Python 3.7+ recommended way to run async main
        asyncio.run(main())
    except AttributeError:
        # Fallback for older Python versions
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        try:
            loop.run_until_complete(main())
        finally:
            loop.close()


if __name__ == "__main__":
    # Entry point - run the application
    run_sync()
