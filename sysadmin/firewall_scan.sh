#!/usr/bin/env bash
# ------------------------------------------------------------------
#  Nmap Firewall & Port Detection Script  (version 2)
#  Usage: ./firewall-scan-v2.sh <target> [output-dir]
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

${BLU}EXAMPLES${RST}
    $0 192.168.1.0/24
    $0 scanme.nmap.org ~/results
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

# ---------- Helper ----------
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
msg "Running quick host discovery (-sn) …"
nmap -sn "$TARGET" -oG "$OUTPUT_DIR/host-discovery-$TIMESTAMP.gnmap" 2>/dev/null || true

msg "Running initial port scan to detect open ports (-T4 --open) …"
nmap -Pn -T4 --open -v -oG "$OUTPUT_DIR/initial-scan-$TIMESTAMP.gnmap" "$TARGET" || \
    die "Initial scan failed"

# Extract ports
PORTS=$(
    awk -F '[ /]' '/Ports:/{for(i=5;i<=NF;i+=4) printf "%s,", $i}' \
        "$OUTPUT_DIR/initial-scan-$TIMESTAMP.gnmap" | sed 's/,$//'
)
[[ -z $PORTS ]] && PORTS="1-1000"   # Fallback
ok "Ports to be targeted: $PORTS"

# ---------- Scan wrapper ----------
scan() {
    local scan_name=$1
    local opts=$2
    local outfile="$OUTPUT_DIR/${scan_name}-${TIMESTAMP}"

    msg "Running $scan_name …"
    nmap $opts -p "$PORTS" "$TARGET" -oA "$outfile"
    ok "$scan_name results saved to $outfile.nmap"
}

# ---------- Parallel scans ----------
msg "Starting parallel scan batch (max 3 at a time) …"
pids=()
scan "-sS" "-T4" "syn-scan" &
pids+=($!)
scan "-sA" "-T4" "ack-scan" &
pids+=($!)
scan "-sF" "-T4" "fin-scan" &
pids+=($!)
wait "${pids[@]}" || msg "Some scans produced warnings, continuing …"

# ---------- More firewall evasion tests ----------
scan "-sN" "-T4" "null-scan"
scan "-sX" "-T4" "xmas-scan"
scan "-sW" "-T4" "window-scan"

# ---------- UDP ----------
scan "-sU" "-T4 --max-retries 1" "udp-top1000"

# ---------- Service / version / OS ----------
scan "-sV" "-sS -A --version-intensity 5" "service-os-scan"

# ---------- Traceroute + banner scripts ----------
msg "Running traceroute & banner grabbing …"
nmap -sS -p "$PORTS" --traceroute \
     --script banner,http-headers,ssh-hostkey \
     "$TARGET" -oA "$OUTPUT_DIR/traceroute-banners-$TIMESTAMP" || true

# ---------- Firewall bypass script ----------
msg "Running firewall-bypass NSE …"
nmap -sS -p "$PORTS" --script firewall-bypass \
     "$TARGET" -oN "$OUTPUT_DIR/firewall-bypass-$TIMESTAMP.nmap" || true

# ---------- Done ----------
ok "All scans finished.  Results stored under: $OUTPUT_DIR/"
cat <<EOF

${YEL}Analysis tips${RST}
1. Compare SYN vs ACK/FIN/NULL/Xmas to spot filtering.
2. Look for “filtered” or “open|filtered” states.
3. Check service-os-scan for OS guesses.
4. Review firewall-bypass output for possible bypass vectors.
EOF
