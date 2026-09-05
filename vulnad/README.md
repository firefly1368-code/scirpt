# VulnAD Lab — Windows Server 2022 Active Directory (CRTO/CRTE practice)

**Untuk lab terisolasi (host-only/internal network) SAJA. Jangan pernah
dijalankan di server produksi atau domain yang beneran dipakai.**

## Urutan eksekusi

1. **`00-promote-dc.ps1`** — promote server fresh install jadi Domain Controller
   baru untuk domain `vulnad.local`. Server akan reboot otomatis.
2. Setelah reboot, login lagi sebagai Administrator domain.
3. **`run-all.ps1`** — jalankan ini, otomatis eksekusi modul 01 → 03:
   - `01-vulnerable-users-groups.ps1` — service account Kerberoastable,
     akun AS-REP roastable, user password lemah, grup nested
   - `02-acl-misconfig.ps1` — GenericAll, WriteDACL, ForceChangePassword,
     DCSync rights yang salah taruh
   - `03-delegation-and-misc.ps1` — constrained delegation misconfig,
     GPP cpassword di SYSVOL

Semua dijalankan dari PowerShell **as Administrator**, di domain controller itu sendiri
(`.\run-all.ps1` — kalau kena execution policy, jalankan dulu:
`Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`).

## Setelah selesai

Baca **`ATTACK-PATHS.md`** — isinya daftar lengkap attack path yang bisa
dilatih (Kerberoasting → DCSync, ACL abuse chain, WriteDACL, targeted
password reset, GPP cpassword) beserta kredensial awal buat mulai dari
posisi "assumed breach".

## Kalau nanti nambah mesin kedua

Attack path lateral movement & coercion (EternalBlue, pass-the-hash, PetitPotam)
sekarang **sudah tercakup** lewat client Windows 7 di `scripts-win7/`. Yang masih
butuh mesin tambahan: AD CS (ESC1-ESC8) dan multi-tier admin model realistis.

## Windows 7 Client (`scripts-win7/`)

1. **`00-join-domain.ps1`** — join Win7 ke domain `vulnad.local`
   (arahkan DNS adapter Win7 ke IP DC dulu sebelum run, dan pastikan
   edisi Win7 Professional/Enterprise/Ultimate, bukan Home)
2. Restart, login ulang
3. **`01-vulnerable-config.ps1`** — aktifkan SMBv1 (target EternalBlue),
   matikan firewall, bikin local admin lemah, unquoted service path,
   nonaktifkan UAC remote restriction

Lihat `ATTACK-PATHS.md` bagian 2 untuk attack path #6-#9 (EternalBlue,
pass-the-hash, unquoted service path, coercion attack ke DC).
