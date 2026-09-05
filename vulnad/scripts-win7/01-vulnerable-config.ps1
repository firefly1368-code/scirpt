<#
.SYNOPSIS
  VulnAD Lab - Provisioning kerentanan di Windows 7 client.
  Jalankan SETELAH join domain & restart, login sebagai local Administrator.

  Mencakup:
  - SMBv1 aktif (default di Win7) -> target MS17-010 / EternalBlue
  - Firewall dimatikan (biar service kelihatan penuh saat scanning)
  - Local admin dengan password lemah (lateral movement / pass-the-hash target)
  - Unquoted service path (local privesc klasik)
  - Cached credential domain admin (buat latihan Mimikatz sekali DC-side ada foothold)
  - UAC diturunkan (biar bisa didemonstrasikan pass-the-hash penuh tanpa UAC remote restriction)
#>

Write-Host "============================================================"
Write-Host " VulnAD Lab - Provisioning Windows 7 client"
Write-Host "============================================================"
$confirm = Read-Host "Ketik 'SAYA MENGERTI' untuk lanjut"
if ($confirm -ne "SAYA MENGERTI") { Write-Host "Dibatalkan."; exit }

Write-Host "[*] Pastikan SMBv1 aktif (default Win7, verifikasi saja)..." -ForegroundColor Cyan
sc.exe config lanmanworkstation depend= bowser/mrxsmb10/mrxsmb20/nsi
sc.exe config mrxsmb10 start= auto
Write-Host "    [+] SMBv1 aktif -> potensi target MS17-010 (EternalBlue) kalau patch belum diinstall"
Write-Host "    [i] CEK: pastikan Windows Update SUDAH DIMATIKAN / VM ini tidak pernah di-patch MS17-010"

Write-Host "[*] Mematikan Windows Firewall (semua profile)..." -ForegroundColor Cyan
netsh advfirewall set allprofiles state off
Write-Host "    [+] Firewall off -> service & port kelihatan penuh saat nmap scan"

Write-Host "[*] Membuat local admin dengan password lemah..." -ForegroundColor Cyan
net user labadmin "P@ssw0rd123" /add
net localgroup Administrators labadmin /add
Write-Host "    [+] labadmin / P@ssw0rd123 -> local admin, target pass-the-hash/pass-the-ticket"

Write-Host "[*] Membuat service dengan unquoted path (local privesc klasik)..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path "C:\Program Files\Vulnerable App" -Force | Out-Null
Copy-Item "C:\Windows\System32\cmd.exe" "C:\Program Files\Vulnerable App\service.exe" -ErrorAction SilentlyContinue
sc.exe create VulnService binPath= "C:\Program Files\Vulnerable App\service.exe" start= auto
# Path ini SENGAJA tidak diberi tanda kutip -> Windows akan coba jalankan
# C:\Program.exe dulu, lalu C:\Program Files\Vulnerable.exe, dst -> classic
# unquoted service path privesc kalau folder itu writable oleh low-priv user
icacls "C:\Program Files\Vulnerable App" /grant Users:F
Write-Host "    [+] VulnService dengan unquoted path + folder writable Users -> local privesc"

Write-Host "[*] Menonaktifkan UAC remote restriction (LocalAccountTokenFilterPolicy)..." -ForegroundColor Cyan
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
    -Name "LocalAccountTokenFilterPolicy" -Value 1 -PropertyType DWord -Force | Out-Null
Write-Host "    [+] Local admin sekarang bisa dipakai penuh untuk pass-the-hash via network (PsExec/WMIExec)"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " Windows 7 client siap. Kombinasikan dengan attack path DC:" -ForegroundColor Green
Write-Host " - EternalBlue (MS17-010) langsung ke SYSTEM shell" -ForegroundColor Green
Write-Host " - Pass-the-hash pakai labadmin ke mesin ini dari foothold lain" -ForegroundColor Green
Write-Host " - Unquoted service path -> local privesc setelah dapat shell low-priv" -ForegroundColor Green
Write-Host " - PetitPotam/coercion: paksa Win7 auth ke 'attacker' lalu relay ke DC" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
