#!/usr/bin/env bash
#
# install-dependencies.sh — installs the Python and system tooling required
# by the AD Pentest Lab (nmap, Impacket, BloodHound, Certipy, kerbrute, ...).
#
# Exits on the first failure instead of silently continuing, and resolves
# requirements.txt relative to this script so it works regardless of the
# caller's current working directory.

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
KERBRUTE_URL="https://github.com/ropnop/kerbrute/releases/latest/download/kerbrute_linux_amd64"

# Install Python dependencies (shared across the security labs)
pip install -r "${SCRIPT_DIR}/../../requirements.txt"

# Install required system tools
sudo apt update
sudo apt install -y \
    nmap \
    crackmapexec \
    smbclient \
    ldap-utils \
    bloodhound-python \
    impacket-scripts \
    seclists \
    responder \
    enum4linux-ng

# Install Certipy
pip install certipy-ad

# Install kerbrute
tmp_kerbrute="$(mktemp)"
trap 'rm -f "${tmp_kerbrute}"' EXIT

wget --quiet --output-document="${tmp_kerbrute}" "${KERBRUTE_URL}"
chmod +x "${tmp_kerbrute}"
sudo mv "${tmp_kerbrute}" /usr/local/bin/kerbrute
trap - EXIT

echo "Installation complete!"