<#
.SYNOPSIS
  VulnAD Lab Builder - Step 2: ACL misconfiguration klasik (inti dari
  BloodHound-style attack path & materi CRTO/CRTE).

  Mencakup:
  - GenericAll dari user biasa ke grup privileged (jsmith -> IT-Admins)
  - WriteDACL dari helpdesk1 ke OU (bisa grant dirinya sendiri privilege apapun)
  - ForceChangePassword dari ageorge ke svc_web
  - DCSync rights (Replicating Directory Changes) diberikan ke akun non-standar
#>

Import-Module ActiveDirectory
$Domain = (Get-ADDomain).DistinguishedName
$OU = "OU=VulnAD-Lab,$Domain"

function Get-ADObjectGuid { param($Identity) (Get-ADUser -Identity $Identity -ErrorAction SilentlyContinue) ?? (Get-ADGroup -Identity $Identity) }

Write-Host "[*] Grant GenericAll: jsmith -> grup IT-Admins" -ForegroundColor Cyan
# jsmith bisa nambah dirinya sendiri ke IT-Admins, lalu IT-Admins bisa di-abuse lebih lanjut
$group = Get-ADGroup "IT-Admins"
$acl = Get-Acl "AD:\$($group.DistinguishedName)"
$jsmithSid = (Get-ADUser "jsmith").SID
$identity = [System.Security.Principal.IdentityReference]$jsmithSid
$adRight = [System.DirectoryServices.ActiveDirectoryRights]"GenericAll"
$type = [System.Security.AccessControl.AccessControlType]"Allow"
$inheritanceType = [System.DirectoryServices.ActiveDirectorySecurityInheritance]"None"
$ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($identity,$adRight,$type,$inheritanceType)
$acl.AddAccessRule($ace)
Set-Acl -Path "AD:\$($group.DistinguishedName)" -AclObject $acl
Write-Host "    [+] jsmith punya GenericAll atas grup IT-Admins -> bisa self-add jadi admin"

Write-Host "[*] Grant WriteDACL: helpdesk1 -> OU VulnAD-Lab" -ForegroundColor Cyan
$ouObj = Get-ADOrganizationalUnit -Identity $OU
$acl2 = Get-Acl "AD:\$OU"
$helpdeskSid = (Get-ADUser "helpdesk1").SID
$identity2 = [System.Security.Principal.IdentityReference]$helpdeskSid
$adRight2 = [System.DirectoryServices.ActiveDirectoryRights]"WriteDacl"
$ace2 = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($identity2,$adRight2,$type,$inheritanceType)
$acl2.AddAccessRule($ace2)
Set-Acl -Path "AD:\$OU" -AclObject $acl2
Write-Host "    [+] helpdesk1 punya WriteDACL atas OU VulnAD-Lab -> bisa grant privilege apapun ke dirinya"

Write-Host "[*] Grant ForceChangePassword (ExtendedRight): ageorge -> svc_web" -ForegroundColor Cyan
$svcWeb = Get-ADUser "svc_web"
$acl3 = Get-Acl "AD:\$($svcWeb.DistinguishedName)"
$ageorgeSid = (Get-ADUser "ageorge").SID
$identity3 = [System.Security.Principal.IdentityReference]$ageorgeSid
$forceChangePwdGuid = [GUID]"00299570-246d-11d0-a768-00aa006e0529"
$adRight3 = [System.DirectoryServices.ActiveDirectoryRights]"ExtendedRight"
$ace3 = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($identity3,$adRight3,$type,$forceChangePwdGuid,$inheritanceType)
$acl3.AddAccessRule($ace3)
Set-Acl -Path "AD:\$($svcWeb.DistinguishedName)" -AclObject $acl3
Write-Host "    [+] ageorge bisa force-reset password svc_web tanpa tahu password lama"

Write-Host "[*] Grant DCSync rights (Replicating Directory Changes + All) ke svc_sql" -ForegroundColor Cyan
# Ini vector klasik: service account yang ke-compromise tapi punya hak replikasi
$rootDSE = "DC=vulnad,DC=local"
$acl4 = Get-Acl "AD:\$rootDSE"
$svcSqlSid = (Get-ADUser "svc_sql").SID
$identity4 = [System.Security.Principal.IdentityReference]$svcSqlSid
$replChangesGuid    = [GUID]"1131f6aa-9c07-11d1-f79f-00c04fc2dcd2"
$replChangesAllGuid = [GUID]"1131f6ad-9c07-11d1-f79f-00c04fc2dcd2"
foreach ($guid in @($replChangesGuid,$replChangesAllGuid)) {
    $aceDC = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($identity4,$adRight3,$type,$guid,$inheritanceType)
    $acl4.AddAccessRule($aceDC)
}
Set-Acl -Path "AD:\$rootDSE" -AclObject $acl4
Write-Host "    [+] svc_sql (Kerberoastable!) punya DCSync rights -> crack password lalu DCSync = Domain Admin"

Write-Host "[*] Selesai. Lanjut ke 03-delegation-and-misc.ps1" -ForegroundColor Green
Write-Host "[i] Attack path lengkap: svc_sql Kerberoast -> crack -> DCSync -> semua hash domain" -ForegroundColor Yellow
