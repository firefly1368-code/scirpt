<#
.SYNOPSIS
  VulnAD Lab Builder - Step 1: User & group yang sengaja rentan.
  Jalankan SETELAH reboot pasca promosi jadi DC, login sebagai Domain Admin.

  Mencakup:
  - Service account dengan SPN + password lemah (Kerberoasting - CRTO/CRTE inti)
  - Akun dengan "Do not require Kerberos preauthentication" (AS-REP Roasting)
  - User biasa dengan password super lemah / never expires
  - Grup nested yang bikin privilege escalation path tidak jelas dari GUI
#>

Import-Module ActiveDirectory
$Domain = (Get-ADDomain).DistinguishedName

Write-Host "[*] Membuat OU untuk lab..." -ForegroundColor Cyan
New-ADOrganizationalUnit -Name "VulnAD-Lab" -Path $Domain -ProtectedFromAccidentalDeletion $false -ErrorAction SilentlyContinue
$OU = "OU=VulnAD-Lab,$Domain"

function New-LabUser {
    param($Name, $Password, [switch]$NoPreauth, [switch]$NeverExpires)
    $secPwd = ConvertTo-SecureString $Password -AsPlainText -Force
    New-ADUser -Name $Name -SamAccountName $Name -UserPrincipalName "$Name@$((Get-ADDomain).DNSRoot)" `
        -Path $OU -AccountPassword $secPwd -Enabled $true -PasswordNeverExpires:$NeverExpires `
        -ErrorAction SilentlyContinue
    if ($NoPreauth) {
        Set-ADAccountControl -Identity $Name -DoesNotRequirePreAuth $true
    }
}

Write-Host "[*] Membuat service account rentan Kerberoasting..." -ForegroundColor Cyan
# SPN + password lemah -> klasik Kerberoasting target
New-LabUser -Name "svc_sql" -Password "Summer2024!" -NeverExpires
New-LabUser -Name "svc_web" -Password "Password123!" -NeverExpires
setspn -A MSSQLSvc/dbserver.vulnad.local:1433 svc_sql
setspn -A HTTP/webapp.vulnad.local svc_web
Write-Host "    [+] svc_sql (Summer2024!) & svc_web (Password123!) punya SPN -> Kerberoastable"

Write-Host "[*] Membuat akun rentan AS-REP Roasting..." -ForegroundColor Cyan
New-LabUser -Name "asrep_target" -Password "Winter2024!" -NoPreauth -NeverExpires
Write-Host "    [+] asrep_target -> DoesNotRequirePreAuth=true (AS-REP roastable)"

Write-Host "[*] Membuat user biasa dengan password lemah..." -ForegroundColor Cyan
New-LabUser -Name "jsmith" -Password "Password1" -NeverExpires
New-LabUser -Name "ageorge" -Password "Welcome1"  -NeverExpires
New-LabUser -Name "helpdesk1" -Password "Helpdesk123" -NeverExpires

Write-Host "[*] Membuat grup nested (privilege path tersembunyi)..." -ForegroundColor Cyan
New-ADGroup -Name "IT-Support" -GroupScope Global -Path $OU -ErrorAction SilentlyContinue
New-ADGroup -Name "IT-Admins"  -GroupScope Global -Path $OU -ErrorAction SilentlyContinue
Add-ADGroupMember -Identity "IT-Support" -Members "helpdesk1" -ErrorAction SilentlyContinue
Add-ADGroupMember -Identity "IT-Admins" -Members "IT-Support" -ErrorAction SilentlyContinue
# IT-Admins ditaruh masuk Domain Admins secara tidak langsung lewat ACL abuse (lihat script 02)
Write-Host "    [+] helpdesk1 -> IT-Support -> IT-Admins (nested, privilege tidak kelihatan langsung dari user)"

Write-Host "[*] Selesai. Lanjut ke 02-acl-misconfig.ps1" -ForegroundColor Green
