#!/usr/bin/env python3

import os
import sys
import subprocess
import time
from datetime import datetime

def clear_screen():
    os.system('clear' if os.name == 'posix' else 'cls')

def print_header():
    clear_screen()
    print("""
    ***************************************
    *      Advanced TCPDump Wrapper       *
    *      Python 3 TCP Capture Tool       *
    ***************************************
    """)

def get_interface_list():
    try:
        result = subprocess.run(['tcpdump', '-D'], capture_output=True, text=True, check=True)
        interfaces = [line.split()[1] for line in result.stdout.split('\n') if line]
        return interfaces
    except subprocess.CalledProcessError as e:
        print(f"Error getting interfaces: {e.stderr}")
        return []
    except FileNotFoundError:
        print("tcpdump not found. Please install tcpdump first.")
        sys.exit(1)

def select_interface(interfaces):
    print_header()
    print("Available network interfaces:\n")
    for i, iface in enumerate(interfaces, 1):
        print(f"{i}. {iface}")
    
    while True:
        try:
            choice = int(input("\nSelect interface (number): "))
            if 1 <= choice <= len(interfaces):
                return interfaces[choice-1]
            else:
                print(f"Please enter a number between 1 and {len(interfaces)}")
        except ValueError:
            print("Please enter a valid number.")

def select_save_location():
    print_header()
    default_dir = os.path.join(os.path.expanduser('~'), 'pcaps')
    
    print(f"Current default save location: {default_dir}")
    print("\nOptions:")
    print("1. Use default location")
    print("2. Specify custom location")
    print("3. Use current directory")
    
    while True:
        choice = input("\nSelect save location option (1-3): ")
        if choice == '1':
            os.makedirs(default_dir, exist_ok=True)
            return default_dir
        elif choice == '2':
            custom_path = input("Enter full path to save directory: ")
            if os.path.isdir(custom_path):
                return custom_path
            else:
                print("Directory doesn't exist. Creating it...")
                try:
                    os.makedirs(custom_path, exist_ok=True)
                    return custom_path
                except Exception as e:
                    print(f"Error creating directory: {e}")
                    continue
        elif choice == '3':
            return os.getcwd()
        else:
            print("Invalid choice. Please select 1, 2, or 3.")

def generate_filename(interface):
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    return f"capture_{interface}_{timestamp}.pcap"

def select_capture_options():
    print_header()
    print("Capture Options:\n")
    print("1. Basic capture (no filters)")
    print("2. Capture specific port")
    print("3. Capture specific host")
    print("4. Capture specific protocol")
    print("5. Advanced filter (custom)")
    
    options = []
    while True:
        choice = input("\nSelect capture option (1-5): ")
        if choice == '1':
            return []
        elif choice == '2':
            port = input("Enter port number: ")
            return [f"port {port}"]
        elif choice == '3':
            host = input("Enter host IP: ")
            return [f"host {host}"]
        elif choice == '4':
            print("\nProtocol options:")
            print("1. TCP")
            print("2. UDP")
            print("3. ICMP")
            proto_choice = input("Select protocol: ")
            protocols = {1: 'tcp', 2: 'udp', 3: 'icmp'}
            return [f"{protocols.get(int(proto_choice), 'tcp')}"]
        elif choice == '5':
            custom_filter = input("Enter custom filter (e.g., 'host 192.168.1.1 and port 80'): ")
            return [custom_filter]
        else:
            print("Invalid choice. Please select 1-5.")

def select_packet_count():
    print_header()
    print("Packet Count Options:\n")
    print("1. Unlimited (capture until stopped)")
    print("2. Specific number of packets")
    
    while True:
        choice = input("\nSelect packet count option (1-2): ")
        if choice == '1':
            return []
        elif choice == '2':
            count = input("Enter number of packets to capture: ")
            return ['-c', count]
        else:
            print("Invalid choice. Please select 1 or 2.")

def run_tcpdump(interface, save_dir, filename, filter_options, count_options):
    save_path = os.path.join(save_dir, filename)
    command = ['sudo', 'tcpdump', '-i', interface, '-w', save_path] + filter_options + count_options
    
    print("\nStarting capture with the following command:")
    print(" ".join(command))
    print(f"\nSaving to: {save_path}")
    print("Press Ctrl+C to stop capture...\n")
    
    try:
        process = subprocess.Popen(command)
        process.wait()
    except KeyboardInterrupt:
        print("\nCapture stopped by user.")
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
    except Exception as e:
        print(f"Error during capture: {e}")
    finally:
        print(f"\nCapture complete. File saved to: {save_path}")
        file_size = os.path.getsize(save_path) / (1024 * 1024)  # Convert to MB
        print(f"File size: {file_size:.2f} MB")

def main():
    if os.geteuid() != 0:
        print("This script requires root privileges. Please run with sudo.")
        sys.exit(1)
    
    interfaces = get_interface_list()
    if not interfaces:
        print("No network interfaces found.")
        sys.exit(1)
    
    interface = select_interface(interfaces)
    save_dir = select_save_location()
    filter_options = select_capture_options()
    count_options = select_packet_count()
    filename = generate_filename(interface)
    
    run_tcpdump(interface, save_dir, filename, filter_options, count_options)

if __name__ == "__main__":
    main()