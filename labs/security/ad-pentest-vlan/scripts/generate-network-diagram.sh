#!/usr/bin/env bash
# ==============================================================================
# Enterprise Pentest Lab - VLAN Network Diagram
# ==============================================================================
# Author      : Miguel A. Carlo
# Version     : 1.0.0
# Date        : 2026-01-31
# License     : MIT / Educational Use Only
#
# Description :
#   Generates a Mermaid network diagram visualizing the VLAN segmentation
#   and virtual machine assignments for the Enterprise Pentest Lab.
#   - Physical host NIC
#   - VLAN bridges and subnets
#   - VM IP assignments per VLAN
#   - Color-coded VLAN blocks for clarity
#
# Usage:
#   ./generate-vlan-diagram.sh
#   Example:
#     ./generate-vlan-diagram.sh > vlan-network-diagram.md
# ==============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

cat << 'EOF'
```mermaid
graph TB
    subgraph "Physical Host"
        NIC[Physical NIC<br/>enp3s0]
    end
    
    subgraph "VLAN Segmentation"
        VLAN10[VLAN 10: Management<br/>172.28.10.0/24]
        VLAN20[VLAN 20: Workstations<br/>172.28.20.0/24]
        VLAN30[VLAN 30: Servers<br/>172.28.30.0/24]
        VLAN40[VLAN 40: DMZ<br/>172.28.40.0/24]
        VLAN99[VLAN 99: Attacker<br/>172.28.99.0/24]
    end
    
    subgraph "Virtual Machines"
        OPNSENSE[OPNsense Firewall/Router<br/>172.28.10.1]
        DC01[DC01<br/>172.28.10.21]
        DB01[DB01<br/>172.28.10.23]
        CA01[CA01-ESC<br/>172.28.10.25]
        WIN10[WIN10<br/>172.28.20.30]
        LLM01[llm01<br/>172.28.30.60]
        LINUX01[linux01<br/>172.28.30.72]
        PRINT01[print01<br/>172.28.30.73]
        CLOUD[cloud-pentest<br/>172.28.30.80]
        MSF2[metasploitable2<br/>172.28.40.12]
        JUICE[Juice Shop<br/>172.28.40.15]
        KALI[Kali<br/>172.28.99.10]
    end

    NIC --> VLAN10
    NIC --> VLAN20
    NIC --> VLAN30
    NIC --> VLAN40
    NIC --> VLAN99

    VLAN10 --> OPNSENSE
    VLAN10 --> DC01
    VLAN10 --> DB01
    VLAN10 --> CA01
    VLAN20 --> WIN10
    VLAN30 --> LLM01
    VLAN30 --> LINUX01
    VLAN30 --> PRINT01
    VLAN30 --> CLOUD
    VLAN40 --> MSF2
    VLAN40 --> JUICE
    VLAN99 --> KALI

    style VLAN10 fill:#e1f5fe
    style VLAN20 fill:#f3e5f5
    style VLAN30 fill:#e8f5e8
    style VLAN40 fill:#fff3e0
    style VLAN99 fill:#ffebee
```
EOF
