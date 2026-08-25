#!/usr/bin/env python3
"""
generate_topology_diagram.py — Render lab network topology diagrams from code.

Generates a PNG network diagram from a structured description of each
lab's VLANs, gateway, and VMs, instead of a manually drawn image in
assets/ that can silently drift out of sync with the Vagrantfile.

Currently covers the segmented Active Directory lab (the most
topologically complex: OPNsense + 5 VLANs). The other labs (AD base,
DevOps/K3s) are flatter single-network topologies and are reasonable
candidates for the same treatment later.

IMPORTANT — this is not a live extraction from the Vagrantfile. The
topology data below (VLAN_CONFIG and LAB_VMS) is a hand-maintained
mirror of labs/security/active-directory/vlan-segmented/Vagrantfile's
own VLAN_CONFIG hash and the static hosts entries it writes (search
that file for "Lab VMs (VLAN IP scheme)"). If you change VLAN subnets,
add/remove a VM, or move a VM to a different VLAN in the Vagrantfile,
update the corresponding entry here in the same commit. A short
diff-based staleness check may be added later; until then, this is a
"kept in sync by convention" data source, not an enforced one.

Usage:
    python3 scripts/generate_topology_diagram.py
    python3 scripts/generate_topology_diagram.py --output assets/architecture/segmented-ad-topology

Requires the `diagrams` Python package and the Graphviz `dot` binary
(apt install graphviz / brew install graphviz).
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

try:
    from diagrams import Cluster, Diagram, Edge
    from diagrams.generic.network import Firewall, Router
    from diagrams.generic.os import LinuxGeneral, Windows
except ImportError:
    print(
        "error: the 'diagrams' package is required.\n"
        "  Install it with: pip install diagrams --break-system-packages\n"
        "  (also requires the Graphviz 'dot' binary: apt install graphviz)",
        file=sys.stderr,
    )
    sys.exit(1)

# Mirrors VLAN_CONFIG in
# labs/security/active-directory/vlan-segmented/Vagrantfile.
# Keys are VLAN IDs; "description" matches the Vagrantfile string.
VLAN_CONFIG = {
    10: {"label": "VLAN 10 - Management", "subnet": "172.28.10.0/24", "gateway": "172.28.10.1"},
    20: {"label": "VLAN 20 - Workstations", "subnet": "172.28.20.0/24", "gateway": "172.28.20.1"},
    30: {"label": "VLAN 30 - Servers", "subnet": "172.28.30.0/24", "gateway": "172.28.30.1"},
    40: {"label": "VLAN 40 - DMZ", "subnet": "172.28.40.0/24", "gateway": "172.28.40.1"},
    99: {"label": "VLAN 99 - Attacker", "subnet": "172.28.99.0/24", "gateway": "172.28.99.1"},
}

# Mirrors the static hosts entries the Vagrantfile writes (search for
# "Lab VMs (VLAN IP scheme)"). "os" selects the diagram icon.
LAB_VMS = {
    10: [
        ("dc01", "172.28.10.21", "windows"),
        ("db01", "172.28.10.23", "windows"),
        ("ca01-esc", "172.28.10.25", "windows"),
    ],
    20: [
        ("win10", "172.28.20.30", "windows"),
    ],
    30: [
        ("llm01", "172.28.30.60", "linux"),
        ("linux01", "172.28.30.72", "linux"),
        ("print01", "172.28.30.73", "linux"),
        ("cloud-pentest", "172.28.30.80", "linux"),
    ],
    40: [
        ("metasploitable2", "172.28.40.12", "linux"),
        ("juice-shop", "172.28.40.15", "linux"),
    ],
    99: [
        ("kali", "172.28.99.10", "linux"),
    ],
}

ICONS = {"windows": Windows, "linux": LinuxGeneral}


def build_diagram(output_path: str) -> None:
    graph_attr = {"splines": "ortho", "fontsize": "14"}

    with Diagram(
        "Segmented Active Directory Lab - Network Topology",
        filename=output_path,
        show=False,
        direction="LR",
        graph_attr=graph_attr,
    ):
        opnsense = Firewall("OPNsense\n(inter-VLAN routing)")

        for vlan_id, cfg in VLAN_CONFIG.items():
            vms = LAB_VMS.get(vlan_id, [])
            with Cluster(f"{cfg['label']}\n{cfg['subnet']}"):
                gateway = Router(f"gateway\n{cfg['gateway']}")
                opnsense >> Edge(color="gray50") >> gateway
                for name, ip, os_kind in vms:
                    icon_cls = ICONS[os_kind]
                    gateway >> Edge(label=ip, fontsize="10", color="gray70") >> icon_cls(name)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        default="assets/architecture/segmented-ad-topology",
        help="Output path without extension (diagrams appends .png). "
        "Default: assets/architecture/segmented-ad-topology",
    )
    args = parser.parse_args()

    output_dir = Path(args.output).parent
    output_dir.mkdir(parents=True, exist_ok=True)

    build_diagram(args.output)
    print(f"Wrote {args.output}.png")
    return 0


if __name__ == "__main__":
    sys.exit(main())
