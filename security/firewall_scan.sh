#!/usr/bin/env bash
# ------------------------------------------------------------------
#  Nmap Firewall & Port Detection Script  (version 2)
#  Description: Comprehensive network scanning tool that performs multiple
#               Nmap techniques to identify open ports, firewall rules,
#               and potential evasion methods. Combines SYN, ACK, FIN,
#               NULL, Xmas, and Window scans with service detection,
#               OS fingerprinting, and firewall bypass attempts.
#
#  Author: [Solo]
#  Created: [08 Setember 2023]
#  Last Modified: [21 July 2025]
#  License: [License, e.g., MIT, GPL]
#  Repository: [https://github.com/solo2121/sysadmin-security-scripts]
# ------------------------------------------------------------------
set -euo pipefail
IFS=$'\n\t'

# ---------- Colours ----------
readonly RED=$'\e[31m'
readonly GRN=$'\e[32m'
readonly YEL=$'\e[33m'
readonly BLU=$'\e[34m'
readonly RST=$'\e[0m'

# ---------- Help ----------
usage() {
    cat <<EOF
${BLU}SYNOPSIS${RST}
    $0 <target> [output-dir]

${BLU}DESCRIPTION${RST}
    This script performs a comprehensive network scan using multiple Nmap
    techniques to identify:
    - Live hosts in the target network
    - Open ports and services
    - Firewall filtering rules
    - Potential firewall evasion methods
    - Operating system information
    - Network topology (traceroute)

    Output is saved in multiple formats (.nmap, .gnmap, .xml) for analysis.

${BLU}EXAMPLES${RST}
    Scan a network range:      $0 192.168.1.0/24
    Scan a domain with custom output directory: $0 scanme.nmap.org ~/results
EOF
    exit 1
}

# ---------- Sanity checks ----------
[[ $# -lt 1 ]] && usage
[[ -z "${1:-}" ]] && { echo "${RED}Target cannot be empty${RST}"; exit 1; }

command -v nmap >/dev/null || { echo "${RED}nmap is not in \$PATH${RST}"; exit 1; }

# ---------- Vars ----------
TARGET="$1"
OUTPUT_DIR="${2:-nmap-firewall-scan}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(realpath "$OUTPUT_DIR")"   # Absolute path for later use

# ---------- Helper Functions ----------
msg() {
    echo -e "${BLU}[*]${RST} $*"
}

ok() {
    echo -e "${GRN}[+]${RST} $*"
}

die() {
    echo -e "${RED}[-]${RST} $*" >&2
    exit 1
}

# ---------- Initial discovery ----------
msg "Running quick host discovery (-sn) to identify live hosts..."
nmap -sn "$TARGET" -oG "$OUTPUT_DIR/host-discovery-$TIMESTAMP.gnmap" 2>/dev/null || true

msg "Running initial port scan to detect open ports (-T4 --open)..."
nmap -Pn -T4 --open -v -oG "$OUTPUT_DIR/initial-scan-$TIMESTAMP.gnmap" "$TARGET" || \
    die "Initial scan failed"

# Extract ports
PORTS=$(
    awk -F '[ /]' '/Ports:/{for(i=5;i<=NF;i+=4) printf "%s,", $i}' \
        "$OUTPUT_DIR/initial-scan-$TIMESTAMP.gnmap" | sed 's/,$//'
)
[[ -z $PORTS ]] && PORTS="1-1000"   # Fallback to common ports if none found
ok "Target ports identified: $PORTS"

# ---------- Scan Wrapper Function ----------
scan() {
    local scan_name=$1
    local opts=$2
    local description=$3
    local outfile="$OUTPUT_DIR/${scan_name}-${TIMESTAMP}"

    msg "Running $scan_name scan ($description)..."
    nmap $opts -p "$PORTS" "$TARGET" -oA "$outfile"
    ok "$scan_name results saved to $outfile.nmap"
}

# ---------- Parallel TCP Scans ----------
msg "Starting parallel TCP scan batch (max 3 concurrent scans)..."
pids=()
scan "syn-scan" "-sS -T4" "SYN stealth scan (standard TCP connect)" &
pids+=($!)
scan "ack-scan" "-sA -T4" "ACK scan (useful for firewall rule detection)" &
pids+=($!)
scan "fin-scan" "-sF -T4" "FIN scan (often bypasses non-stateful firewalls)" &
pids+=($!)
wait "${pids[@]}" || msg "Some scans produced warnings, continuing..."

# ---------- Additional Firewall Evasion Scans ----------
scan "null-scan" "-sN -T4" "NULL scan (all flags cleared)"
scan "xmas-scan" "-sX -T4" "Xmas scan (FIN, PSH, URG flags set)"
scan "window-scan" "-sW -T4" "Window scan (examines TCP window sizes)"

# ---------- UDP Scanning ----------
scan "udp-top1000" "-sU -T4 --max-retries 1" "UDP top 1000 ports scan"

# ---------- Service and OS Detection ----------
scan "service-os-scan" "-sS -A --version-intensity 5" "Aggressive service/OS detection"

# ---------- Traceroute and Banner Grabbing ----------
msg "Running traceroute and service banner collection..."
nmap -sS -p "$PORTS" --traceroute \
     --script banner,http-headers,ssh-hostkey \
     "$TARGET" -oA "$OUTPUT_DIR/traceroute-banners-$TIMESTAMP" || true

# ---------- Firewall Bypass Attempts ----------
msg "Executing firewall bypass scripts..."
nmap -sS -p "$PORTS" --script firewall-bypass \
     "$TARGET" -oN "$OUTPUT_DIR/firewall-bypass-$TIMESTAMP.nmap" || true

# ---------- Completion ----------
ok "Scanning complete. All results stored in: $OUTPUT_DIR/"
cat <<EOF

${YEL}ANALYSIS GUIDE${RST}
1. Compare SYN vs ACK/FIN/NULL/Xmas scan results to identify filtering:
   - Consistent responses across scans may indicate no filtering
   - Inconsistent responses suggest active firewall rules

2. Look for port states:
   - 'filtered' = Firewall is likely blocking
   - 'open|filtered' = Firewall may be stealthily dropping packets

3. Check service-os-scan results for:
   - Service versions (potential vulnerabilities)
   - OS fingerprinting (helps tailor further attacks)

4. Review firewall-bypass output for:
   - Potential packet crafting options
   - Alternative routing suggestions
   - Protocol-specific bypass techniques

5. Examine UDP scan for:
   - Unexpected open UDP services
   - DNS, NTP, SNMP, or other UDP-based services
EOF
