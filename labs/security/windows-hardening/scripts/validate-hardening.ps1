<#
.SYNOPSIS
    Validates the Windows Server Hardening Lab baseline on dc01-hardened.

.DESCRIPTION
    Read-only checks for every control documented in
    ../docs/hardening-guide.md. Makes no changes to the system. Prints a
    PASS/FAIL/WARN line per control and a summary at the end.

    Not part of the automated Vagrant provisioning — copy this onto the VM
    and run it manually. See ../README.md "Validating the hardening" for
    how to get it there over WinRM.

.NOTES
    Run as Administrator for full access to audit policy and Defender
    status (auditpol and Get-MpComputerStatus both need elevation).
#>

$ErrorActionPreference = 'Continue'
$results = @()

function Test-Control {
    param(
        [string]$Name,
        [scriptblock]$Check,
        [string]$Expected
    )
    try {
        $actual = & $Check
        $pass = $actual -eq $true
        $script:results += [PSCustomObject]@{
            Control  = $Name
            Status   = if ($pass) { 'PASS' } else { 'FAIL' }
            Expected = $Expected
        }
    } catch {
        $script:results += [PSCustomObject]@{
            Control  = $Name
            Status   = 'WARN (check errored)'
            Expected = "$Expected -- error: $($_.Exception.Message)"
        }
    }
}

Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host " WINDOWS HARDENING LAB - VALIDATION" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

Test-Control -Name "LLMNR disabled" -Expected "EnableMulticast = 0" -Check {
    $v = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name EnableMulticast -ErrorAction SilentlyContinue
    $v.EnableMulticast -eq 0
}

Test-Control -Name "NetBIOS over TCP/IP disabled" -Expected "TcpipNetbiosOptions = 2 on all adapters" -Check {
    $adapters = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.TcpipNetbiosOptions -ne $null }
    -not ($adapters | Where-Object { $_.TcpipNetbiosOptions -ne 2 })
}

Test-Control -Name "SMB signing required (server)" -Expected "RequireSecuritySignature = True" -Check {
    (Get-SmbServerConfiguration).RequireSecuritySignature -eq $true
}

Test-Control -Name "SMB signing required (client)" -Expected "RequireSecuritySignature = True" -Check {
    (Get-SmbClientConfiguration).RequireSecuritySignature -eq $true
}

Test-Control -Name "NTLM restriction configured (audit or deny)" -Expected "RestrictReceivingNTLMTraffic >= 1" -Check {
    $v = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0" -Name RestrictReceivingNTLMTraffic -ErrorAction SilentlyContinue
    $v.RestrictReceivingNTLMTraffic -ge 1
}

Test-Control -Name "NTLMv1/LM refused" -Expected "LmCompatibilityLevel = 5" -Check {
    $v = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name LmCompatibilityLevel -ErrorAction SilentlyContinue
    $v.LmCompatibilityLevel -eq 5
}

Test-Control -Name "Print Spooler disabled" -Expected "Status = Stopped, StartType = Disabled" -Check {
    $svc = Get-Service Spooler -ErrorAction SilentlyContinue
    $svc.Status -eq 'Stopped' -and $svc.StartType -eq 'Disabled'
}

Test-Control -Name "SMBv1 disabled" -Expected "State = Disabled" -Check {
    (Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -ErrorAction SilentlyContinue).State -eq 'Disabled'
}

Test-Control -Name "Defender real-time protection enabled" -Expected "RealTimeProtectionEnabled = True" -Check {
    (Get-MpComputerStatus -ErrorAction SilentlyContinue).RealTimeProtectionEnabled -eq $true
}

$auditSubcategories = @(
    "Kerberos Authentication Service",
    "Kerberos Service Ticket Operations",
    "Credential Validation",
    "Directory Service Access",
    "Directory Service Changes",
    "Security Group Management",
    "User Account Management",
    "Logon",
    "Certification Services"
)
foreach ($sub in $auditSubcategories) {
    Test-Control -Name "Audit policy: $sub" -Expected "Success and Failure enabled" -Check {
        $out = auditpol /get /subcategory:"$sub" 2>$null
        ($out -join "`n") -match 'Success and Failure' -or (($out -join "`n") -match 'Success' -and ($out -join "`n") -match 'Failure')
    }
}

Test-Control -Name "Domain password policy hardened" -Expected "MinPasswordLength >= 14, ComplexityEnabled True" -Check {
    try {
        $pol = Get-ADDefaultDomainPasswordPolicy -ErrorAction Stop
        $pol.MinPasswordLength -ge 14 -and $pol.ComplexityEnabled -eq $true
    } catch {
        $false
    }
}

Write-Host ""
$results | Format-Table -AutoSize

$passCount = ($results | Where-Object { $_.Status -eq 'PASS' }).Count
$failCount = ($results | Where-Object { $_.Status -ne 'PASS' }).Count
$totalCount = $results.Count
$scorePercent = if ($totalCount -gt 0) { [math]::Round(($passCount / $totalCount) * 100, 1) } else { 0 }

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host " HARDENING COMPLIANCE SCORE" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  CIS Level 1-inspired baseline: $scorePercent% ($passCount/$totalCount controls passed)" -ForegroundColor $(if ($scorePercent -ge 90) { 'Green' } elseif ($scorePercent -ge 70) { 'Yellow' } else { 'Red' })
Write-Host ""
Write-Host "  This score reflects the hand-written control checks in this" -ForegroundColor Gray
Write-Host "  script, mapped loosely to CIS Level 1 domains -- it is not a" -ForegroundColor Gray
Write-Host "  formal CIS-CAT or HardeningKitty assessment. See" -ForegroundColor Gray
Write-Host "  docs/hardening-guide.md for what is and is not covered." -ForegroundColor Gray
Write-Host ""

if ($failCount -eq 0) {
    Write-Host "[SUCCESS] All $totalCount controls passed." -ForegroundColor Green
} else {
    Write-Host "[WARN] $failCount of $totalCount controls did not pass. See docs/hardening-guide.md for remediation." -ForegroundColor Yellow
}
