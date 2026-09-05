# VulnAD — Daftar Attack Path (CRTO/CRTE style)

Domain: `vulnad.local` | Semua object lab ada di OU `VulnAD-Lab`

## Kredensial awal (buat mulai enumerasi, anggap ini "assumed breach")
| User | Password | Catatan |
|------|----------|---------|
| jsmith | Password1 | user biasa |
| ageorge | Welcome1 | user biasa |
| helpdesk1 | Helpdesk123 | member IT-Support |
| svc_sql | Summer2024! | SPN MSSQLSvc — Kerberoastable |
| svc_web | Password123! | SPN HTTP — Kerberoastable + constrained delegation |
| asrep_target | Winter2024! | DoesNotRequirePreAuth — AS-REP roastable (gak perlu tau ini buat nge-attack) |

## Attack Path #1 — Kerberoast langsung ke DCSync
1. Enumerasi SPN (`GetUserSPNs.py`, PowerView `Get-DomainUser -SPN`, atau Rubeus)
2. Request TGS untuk `svc_sql` → crack offline (hashcat mode 13100)
3. `svc_sql` ternyata punya hak **Replicating Directory Changes** (DCSync)
4. `secretsdump.py` / `Get-ADReplAccount` → dump seluruh hash domain, termasuk krbtgt
5. Golden Ticket dari krbtgt hash → Domain Admin persistence

## Attack Path #2 — ACL abuse chain (BloodHound-style)
1. Login sebagai `jsmith` (Password1)
2. `jsmith` punya **GenericAll** atas grup `IT-Admins` (tidak kelihatan di GUI biasa,
   ketauan lewat BloodHound edge atau `Get-ADGroup IT-Admins | Get-Acl`)
3. Self-add `jsmith` ke `IT-Admins`
4. Cek apakah `IT-Admins` punya privilege lanjutan (latihan: cari sendiri
   apakah ada nested delegation lain yang bisa dieksplorasi dari titik ini)

## Attack Path #3 — WriteDACL abuse
1. Login sebagai `helpdesk1`
2. Punya **WriteDACL** atas OU `VulnAD-Lab`
3. Grant dirinya sendiri `GenericAll` atas OU (atau langsung atas object spesifik
   di dalamnya) → full control ke semua object di OU tsb

## Attack Path #4 — Targeted password reset
1. Login sebagai `ageorge`
2. Punya **ForceChangePassword** (ExtendedRight) atas `svc_web`
3. Reset password `svc_web` tanpa perlu tahu password lama
4. `svc_web` juga Kerberoastable DAN constrained-delegation-enabled ke CIFS DC
   → setelah kuasai svc_web, coba S4U2Self/S4U2Proxy untuk impersonate user lain

## Attack Path #5 — GPP cpassword (teknik historis, MS14-025)
1. Baca `\\vulnad.local\SYSVOL\vulnad.local\Policies\{GUID}\Machine\Preferences\Groups\Groups.xml`
2. Decrypt `cpassword` pakai AES key publik Microsoft (`gpp-decrypt`, Metasploit
   `windows/gather/credentials/gpp`, atau CrackMapExec module `gpp_password`)

## Tools yang relevan buat latihan
- **Enumerasi**: BloodHound + SharpHound / PowerView / ldapdomaindump
- **Kerberoast/AS-REP**: Rubeus, impacket (`GetUserSPNs.py`, `GetNPUsers.py`)
- **ACL abuse**: PowerView (`Add-DomainObjectAcl`), BloodHound attack path viewer
- **Delegation**: Rubeus (`s4u`), impacket (`getST.py`)
- **Cracking**: hashcat (mode 13100 Kerberoast, 18200 AS-REP)

## Yang belum dicakup (karena cuma 1 DC + 1 Win7 client)
- Multi-tier admin tiering (Tier 0/1/2 model) — butuh lebih banyak host untuk realistis
- AD CS (Certificate Services) ESC1-ESC8 — bisa ditambah kalau nanti install role AD CS

Kalau nambah 1 VM lagi (Windows 10/11 modern client atau server kedua),
bilang aja — kita bisa demonstrasikan Kerberos delegation abuse yang lebih
kompleks atau AD CS attack path.

---

# Bagian 2: Attack Path dengan Windows 7 Client (`scripts-win7/`)

Setelah Win7 join domain dan diprovisioning (`00-join-domain.ps1` lalu
`01-vulnerable-config.ps1`), kombinasi 2 mesin ini membuka attack path
lateral movement & coercion yang gak bisa didemonstrasikan di 1 mesin saja.

## Attack Path #6 — EternalBlue langsung ke SYSTEM (MS17-010)
1. `nmap -p445 --script smb-vuln-ms17-010 <ip-win7>` untuk verifikasi
2. Exploit pakai Metasploit `exploit/windows/smb/ms17_010_eternalblue`
   atau versi manual dari AutoBlue-MS17-010
3. Dapat SYSTEM shell langsung tanpa perlu kredensial apapun
4. **Prasyarat**: pastikan Windows Update di Win7 ini dimatikan/tidak pernah
   patch MS17-010 (rilis Maret 2017) — VM fresh install biasanya rentan default

## Attack Path #7 — Pass-the-Hash lateral movement
1. Dari foothold manapun (misal setelah compromise akun domain di attack path 1-4),
   dump hash `labadmin` (local admin Win7) via Mimikatz/secretsdump kalau
   ketemu di memory/SAM
2. `labadmin:P@ssw0rd123` — `LocalAccountTokenFilterPolicy` sudah di-set 1,
   jadi bisa pass-the-hash penuh (bukan cuma RID 500) via `psexec.py`/`wmiexec.py`
   dari Kali/attacker box ke Win7

## Attack Path #8 — Unquoted Service Path (local privesc)
1. Setelah dapat shell low-priv di Win7 (misal via exploit lain atau RDP user biasa)
2. `wmic service get name,pathname,startmode | findstr /i /v "C:\Windows"` untuk cari
3. `VulnService` punya binPath tanpa tanda kutip + folder writable oleh Users
4. Tanam `Program.exe` (atau `Program Files\Vulnerable.exe`) berisi payload,
   restart service (atau tunggu reboot) → SYSTEM shell

## Attack Path #9 — Coercion attack (PetitPotam-style) ke DC
1. Dari Win7 (atau dari attacker box), paksa DC melakukan autentikasi ke listener
   yang kamu kontrol (`PetitPotam.py <attacker-ip> <dc-ip>`)
2. Relay autentikasi tsb (NTLM relay) ke DC pakai `ntlmrelayx.py`
3. Karena DC secara default trusted-for-delegation & AD CS belum ada di lab ini,
   fokus latihan adalah memahami MEKANISME coercion+relay-nya dulu — kalau mau
   demonstrasi penuh sampai Domain Admin (ESC8), perlu tambah role AD CS di DC
4. **PENTING**: teknik ini HANYA untuk lab terisolasi kamu sendiri — coercion
   attack terhadap infrastruktur yang bukan milikmu adalah serangan aktif ilegal

## Update tools untuk skenario Win7
- **MS17-010**: Metasploit, atau exploit standalone (AutoBlue-MS17-010) untuk
  latihan tanpa Metasploit (lebih mendalam, sesuai gaya OSCP/GXPN)
- **Pass-the-hash**: impacket (`psexec.py`, `wmiexec.py`), CrackMapExec
- **Coercion**: PetitPotam, Coercer, ntlmrelayx.py (bagian dari impacket)

