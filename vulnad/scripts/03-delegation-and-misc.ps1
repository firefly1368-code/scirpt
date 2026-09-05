<#
.SYNOPSIS
  VulnAD Lab Builder - Step 3: Delegation misconfiguration & artefak klasik
  lainnya (GPP cpassword, LLMNR default, SMB signing).

  Mencakup:
  - Unconstrained delegation di komputer akun (dijelaskan simulasinya)
  - Constrained delegation misconfig di svc_web
  - GPP cpassword tertinggal di SYSVOL (teknik lama tapi masih diajarkan)
  - Catatan LLMNR/NBT-NS & SMB signing (default Windows, didokumentasikan saja)
#>

Import-Module ActiveDirectory

Write-Host "[*] Set Constrained Delegation: svc_web bisa delegate ke CIFS DC" -ForegroundColor Cyan
# svc_web (Kerberoastable) juga punya constrained delegation ke service CIFS di DC
# -> kalau svc_web ke-compromise, bisa impersonate user manapun ke CIFS DC
$dc = Get-ADComputer -Filter * | Select-Object -First 1
Set-ADUser -Identity "svc_web" -Add @{'msDS-AllowedToDelegateTo'=@("CIFS/$($dc.DNSHostName)")}
Set-ADAccountControl -Identity "svc_web" -TrustedToAuthForDelegation $true
Write-Host "    [+] svc_web: constrained delegation + protocol transition ke CIFS/$($dc.DNSHostName)"

Write-Host "[*] Menandai akun komputer DC eligible utk unconstrained delegation (default DC, didokumentasikan)" -ForegroundColor Cyan
Write-Host "    [i] Semua DC secara default 'Trusted for Delegation' (unconstrained) - ini existing behavior," -ForegroundColor Yellow
Write-Host "        gunakan untuk latihan memahami risiko printer bug / coercion attack (PetitPotam dsb) di lab TERISOLASI SAJA." -ForegroundColor Yellow

Write-Host "[*] Menanam GPP cpassword lama di SYSVOL (teknik historis, tetap diajarkan)..." -ForegroundColor Cyan
$domain = (Get-ADDomain).DNSRoot
$sysvolPath = "C:\Windows\SYSVOL\domain\Policies"
$gpoName = "{31B2F340-016D-11D2-945F-00C04FB984F9}"  # Default Domain Policy GUID placeholder
$prefPath = "$sysvolPath\$gpoName\Machine\Preferences\Groups"
New-Item -ItemType Directory -Path $prefPath -Force | Out-Null

# cpassword ini adalah AES-encrypted dengan KEY YANG SUDAH PUBLIK dari Microsoft (MS14-025)
# Cukup untuk latihan decrypt pakai gpp-decrypt / Get-GPPPassword
$gppXml = @'
<?xml version="1.0" encoding="utf-8"?>
<Groups clsid="{3125E937-EB16-4b4c-9934-544FC6D24D26}">
  <User clsid="{DF5F1855-51E5-4d24-8B1A-D9BDE98BA1D1}" name="localadmin" image="2" changed="2024-01-01 00:00:00" uid="{12345678-1234-1234-1234-123456789012}">
    <Properties action="U" newName="" fullName="" description="Lab local admin - GPP artifact"
      cpassword="j1Uyj3Vx8TY9LtLZil2uAuZkFQA/4latT76ZwgdHdhw" changeLogon="0" noChange="0" neverExpires="1"
      acctDisabled="0" userName="localadmin"/>
  </User>
</Groups>
'@
Set-Content -Path "$prefPath\Groups.xml" -Value $gppXml -Encoding UTF8
Write-Host "    [+] GPP Groups.xml ditanam di SYSVOL dengan cpassword ter-encrypt (key publik MS14-025)"
Write-Host "    [i] Password plaintext hasil decrypt: Passw0rd! (verifikasi sendiri pakai gpp-decrypt)"

Write-Host "[*] Selesai semua modul dasar." -ForegroundColor Green
Write-Host "[*] Catatan default Windows yang relevan untuk latihan responder/coercion:" -ForegroundColor Yellow
Write-Host "    - LLMNR & NBT-NS aktif secara default (poisoning attack surface)" -ForegroundColor Yellow
Write-Host "    - SMB Signing tidak wajib secara default di banyak konfigurasi (relay attack surface)" -ForegroundColor Yellow
Write-Host "    Ini BUKAN yang sengaja kami aktifkan - ini default OS, didokumentasikan untuk kesadaran saja." -ForegroundColor Yellow
