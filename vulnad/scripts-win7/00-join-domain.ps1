<#
.SYNOPSIS
  VulnAD Lab - Join Windows 7 client ke domain vulnad.local
  Kompatibel PowerShell 2.0 (default di Win7 tanpa update tambahan).

.NOTES
  - Windows 7 edition harus Professional/Enterprise/Ultimate (Home tidak
    bisa join domain).
  - Set DNS server VM Win7 ini ke IP Domain Controller SEBELUM run script ini,
    supaya bisa resolve vulnad.local. Cek dulu: ping vulnad.local
  - Jalankan sebagai Administrator (klik kanan PowerShell -> Run as Administrator)
#>

Write-Host "============================================================"
Write-Host " VulnAD Lab - Join Windows 7 ke domain vulnad.local"
Write-Host " Pastikan DNS adapter sudah diarahkan ke IP Domain Controller!"
Write-Host "============================================================"
$confirm = Read-Host "Ketik 'SAYA MENGERTI' untuk lanjut"
if ($confirm -ne "SAYA MENGERTI") { Write-Host "Dibatalkan."; exit }

$DomainName   = "vulnad.local"
$DomainAdmin  = Read-Host "Username domain admin (contoh: Administrator)"
$DomainPwd    = Read-Host "Password domain admin" -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($DomainPwd)
$PlainPwd = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

# Cara paling kompatibel PS2.0: pakai WMI JoinDomainOrWorkgroup
$computer = Get-WmiObject -Class Win32_ComputerSystem
$result = $computer.JoinDomainOrWorkgroup($DomainName, $PlainPwd, "$DomainName\$DomainAdmin", $null, 3)

if ($result.ReturnValue -eq 0) {
    Write-Host "[+] Berhasil join domain. Restart komputer untuk apply." -ForegroundColor Green
    Write-Host "    Setelah restart, login pakai: $DomainName\<username>"
} else {
    Write-Host "[-] Gagal join domain. Return code: $($result.ReturnValue)" -ForegroundColor Red
    Write-Host "    Cek koneksi ke DC (ping $DomainName) dan DNS setting." -ForegroundColor Red
}
