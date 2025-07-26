#!/usr/bin/env python3
"""
HashCrack - Advanced Password Cracking Utility

Description:
This script provides an interactive menu-driven interface for Hashcat, the world's 
fastest password recovery tool. It simplifies complex Hashcat commands while 
maintaining full functionality for advanced password cracking techniques.

Features:
- User-friendly interface with ASCII banner
- Supports multiple attack modes including:
  * Dictionary attacks
  * Combinator attacks
  * Mask attacks
  * Hybrid attacks
  * Rule-based attacks
  * Brute-force attacks
- Supports numerous hash types (MD5, SHA1, SHA256, NTLM, etc.)
- Custom hash type support for advanced users
- Command preview before execution
- Performance optimization options

Usage:
Run the script and follow the interactive prompts to:
1. Select your hash file
2. Choose the hash type
3. Select an attack mode
4. Configure attack parameters
5. Review and execute the command

Requirements:
- Python 3.x
- Hashcat installed and in PATH

Security Note: 
This tool should only be used for legitimate password recovery purposes such as: 
- Penetration testing with proper authorization 
- Forensic investigations 
- Password audits on systems you own or have permission to test

Disclaimer: Unauthorized use of this tool against systems you don't own is illegal.
"""

import os
import subprocess
import sys
import shutil

def clear_screen():
    os.system('cls' if os.name == 'nt' else 'clear')

def display_banner():
    print(r"""

   ██╗  ██╗ █████╗ ███████╗██╗  ██╗ ██████╗ █████╗ ████████╗
   ██║  ██║██╔══██╗██╔════╝██║  ██║██╔════╝██╔══██╗╚══██╔══╝
   ███████║███████║███████╗███████║██║     ███████║   ██║
   ██╔══██║██╔══██║╚════██║██╔══██║██║     ██╔══██║   ██║
   ██║  ██║██║  ██║███████║██║  ██║╚██████╗██║  ██║   ██║
   ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝   ╚═╝
        Password Cracking Menu for Advanced Users
""")

def get_hash_file():
    while True:
        hash_file = input("Enter the path to the hash file: ").strip()
        if os.path.isfile(hash_file):
            return hash_file
        print(f"Error: File '{hash_file}' not found. Please try again.")

def get_wordlist():
    while True:
        wordlist = input("Enter the path to the wordlist/dictionary file: ").strip()
        if os.path.isfile(wordlist):
            return wordlist
        print(f"Error: File '{wordlist}' not found. Please try again.")

def get_attack_type():
    attacks = {
        '1': {'name': 'Dictionary Attack', 'command': '0'},
        '2': {'name': 'Combinator Attack', 'command': '1'},
        '3': {'name': 'Mask Attack', 'command': '3'},
        '4': {'name': 'Hybrid Dictionary + Mask', 'command': '6'},
        '5': {'name': 'Hybrid Mask + Dictionary', 'command': '7'},
        '6': {'name': 'Rule-based Attack', 'command': '0 with rules'},
        '7': {'name': 'Toggle Case Attack', 'command': '2'},
        '8': {'name': 'Brute-Force', 'command': '3'},
        '9': {'name': 'Rainbow Table Attack', 'command': 'use -O'}
    }

    print("\nSelect attack type:")
    for key in sorted(attacks.keys()):
        print(f"{key}. {attacks[key]['name']}")

    while True:
        choice = input("Enter your choice (1-9): ").strip()
        if choice in attacks:
            return attacks[choice]
        print("Invalid choice. Please enter a number between 1-9.")

def get_hash_type():
    common_hashes = {
        '1': {'name': 'MD5', 'code': '0'},
        '2': {'name': 'SHA1', 'code': '100'},
        '3': {'name': 'SHA256', 'code': '1400'},
        '4': {'name': 'SHA512', 'code': '1700'},
        '5': {'name': 'NTLM', 'code': '1000'},
        '6': {'name': 'LM', 'code': '3000'},
        '7': {'name': 'WordPress', 'code': '400'},
        '8': {'name': 'Joomla', 'code': '11'},
        '9': {'name': 'Unix Crypt', 'code': '500'},
        '10': {'name': 'Custom Hash Type', 'code': ''}
    }

    print("\nSelect hash type:")
    for key in sorted(common_hashes.keys()):
        print(f"{key}. {common_hashes[key]['name']}")

    while True:
        choice = input("Enter your choice (1-10): ").strip()
        if choice in common_hashes:
            if choice == '10':
                return input("Enter the hashcat hash type code: ").strip()
            return common_hashes[choice]['code']
        print("Invalid choice. Please enter a number between 1-10.")

def build_hashcat_command(hash_file, hash_type, attack, wordlist=None, mask=None, rules=None):
    cmd = ['hashcat', '-m', hash_type]

    if attack['command'] == '0':
        cmd.extend(['-a', '0', hash_file, wordlist])
    elif attack['command'] == '1':
        cmd.extend(['-a', '1', hash_file, wordlist, wordlist])  # Using same wordlist for combinator
    elif attack['command'] == '3':
        if mask:
            cmd.extend(['-a', '3', hash_file, mask])
        else:
            print("\nMask Attack requires a mask pattern.")
            print("Example masks: ?a?a?a?a?a?a?a?a (8 chars), ?d?d?d?d (4 digits)")
            mask = input("Enter mask pattern: ").strip()
            cmd.extend(['-a', '3', hash_file, mask])
    elif attack['command'] == '6':
        cmd.extend(['-a', '6', hash_file, wordlist, mask or '?a?a?a?a'])
    elif attack['command'] == '7':
        cmd.extend(['-a', '7', hash_file, mask or '?a?a?a?a', wordlist])
    elif attack['command'] == '0 with rules':
        if not rules:
            rules = input("Enter rule file path or built-in rule name (e.g., best64.rule): ").strip()
        cmd.extend(['-a', '0', '-r', rules, hash_file, wordlist])
    elif attack['command'] == '2':
        cmd.extend(['-a', '2', hash_file, wordlist])
    elif attack['command'] == 'use -O':
        cmd.extend(['-O', hash_file, wordlist])

    # Add additional options
    if input("Enable performance optimization? (y/n): ").lower() == 'y':
        cmd.append('-O')
    if input("Enable force? (y/n): ").lower() == 'y':
        cmd.append('--force')
    if input("Show cracked passwords? (y/n): ").lower() == 'y':
        cmd.append('--show')

    return cmd

def main():
    clear_screen()
    display_banner()

    if not shutil.which('hashcat'):
        print("Error: hashcat not found in PATH. Please install hashcat first.")
        sys.exit(1)

    hash_file = get_hash_file()
    hash_type = get_hash_type()
    attack = get_attack_type()

    wordlist = None
    if attack['command'] in ['0', '1', '6', '7', '0 with rules', '2', 'use -O']:
        wordlist = get_wordlist()

    mask = None
    if attack['command'] in ['3', '6', '7'] and input("Do you want to specify a mask? (y/n): ").lower() == 'y':
        mask = input("Enter mask pattern (e.g., ?d?d?d?d for 4 digits): ").strip()

    rules = None
    if attack['command'] == '0 with rules':
        rules = input("Enter rule file path or built-in rule name (e.g., best64.rule): ").strip()

    cmd = build_hashcat_command(hash_file, hash_type, attack, wordlist, mask, rules)

    print("\nGenerated Hashcat command:")
    print(' '.join(cmd))

    if input("\nDo you want to execute this command? (y/n): ").lower() == 'y':
        try:
            subprocess.run(cmd, check=True)
        except subprocess.CalledProcessError as e:
            print(f"Error executing hashcat: {e}")
        except KeyboardInterrupt:
            print("\nOperation cancelled by user.")
    else:
        print("Command not executed.")

if __name__ == "__main__":
    main()
