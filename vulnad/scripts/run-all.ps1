<#
.SYNOPSIS
  VulnAD Lab Builder - jalankan modul 01-03 secara berurutan.
  PRASYARAT: 00-promote-dc.ps1 sudah dijalankan & server sudah reboot jadi DC.
#>

Write-Host "============================================================" -ForegroundColor Yellow
Write-Host " VulnAD Lab Builder - Provisioning kerentanan AD" -ForegroundColor Yellow
Write-Host " Pastikan ini sudah menjadi Domain Controller (via 00-promote-dc.ps1)" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow
$confirm = Read-Host "Ketik 'SAYA MENGERTI' untuk lanjut"
if ($confirm -ne "SAYA MENGERTI") { Write-Host "Dibatalkan."; exit }

try { Get-ADDomain | Out-Null } catch {
    Write-Host "[-] Server ini belum jadi Domain Controller. Jalankan 00-promote-dc.ps1 dulu." -ForegroundColor Red
    exit 1
}

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
& "$here\01-vulnerable-users-groups.ps1"
& "$here\02-acl-misconfig.ps1"
& "$here\03-delegation-and-misc.ps1"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " VulnAD siap dipakai untuk latihan CRTO/CRTE." -ForegroundColor Green
Write-Host " Baca ATTACK-PATHS.md untuk daftar lengkap teknik yang ditanam." -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
