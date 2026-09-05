<#
.SYNOPSIS
  VulnAD Lab Builder - Step 0: Promote fresh Windows Server 2022 to a new
  AD DS forest/domain. Jalankan ini SEKALI di awal, di VM lab terisolasi.

.NOTES
  - Jalankan sebagai Administrator, di PowerShell (bukan ISE) supaya reboot
    otomatisnya jalan mulus.
  - VM ini akan reboot otomatis setelah promosi selesai.
  - Set network adapter ke Host-only/Internal SEBELUM menjalankan ini.
#>

Write-Host "============================================================" -ForegroundColor Yellow
Write-Host " VulnAD Lab Builder - Promote to Domain Controller" -ForegroundColor Yellow
Write-Host " Domain yang akan dibuat: vulnad.local (bisa diganti di bawah)" -ForegroundColor Yellow
Write-Host " PASTIKAN network adapter sudah Host-only/Internal!" -ForegroundColor Red
Write-Host "============================================================" -ForegroundColor Yellow
$confirm = Read-Host "Ketik 'SAYA MENGERTI' untuk lanjut"
if ($confirm -ne "SAYA MENGERTI") { Write-Host "Dibatalkan."; exit }

$DomainName    = "vulnad.local"
$NetbiosName   = "VULNAD"
$SafeModePwd   = ConvertTo-SecureString "SafeMode_P@ssw0rd_2024!" -AsPlainText -Force

Write-Host "[*] Install fitur AD DS..." -ForegroundColor Cyan
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

Write-Host "[*] Set static IP disarankan manual dulu kalau belum (DNS akan self-refer ke 127.0.0.1 otomatis)." -ForegroundColor Cyan

Write-Host "[*] Membuat forest baru: $DomainName ..." -ForegroundColor Cyan
Import-Module ADDSDeployment
Install-ADDSForest `
  -DomainName $DomainName `
  -DomainNetbiosName $NetbiosName `
  -SafeModeAdministratorPassword $SafeModePwd `
  -InstallDns:$true `
  -DatabasePath "C:\Windows\NTDS" `
  -LogPath "C:\Windows\NTDS" `
  -SysvolPath "C:\Windows\SYSVOL" `
  -Force:$true `
  -NoRebootOnCompletion:$false

# Setelah reboot, VM akan jadi Domain Controller untuk vulnad.local.
# Lanjutkan dengan 01-vulnerable-users-groups.ps1 setelah login ulang.
