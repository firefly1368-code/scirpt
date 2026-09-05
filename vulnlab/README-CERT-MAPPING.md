# Pemetaan Level ke Sertifikasi

Lab ini tersedia untuk **CentOS Stream 9** (`centos/`) dan **Ubuntu 24.04** (`ubuntu24/`).
Struktur & filosofi levelnya identik di kedua OS, cuma package manager dan
beberapa nama service yang beda (dnf/firewalld vs apt/ufw).

## Cara pakai
```
cd centos/     # atau ubuntu24/
sudo bash 00-setup.sh
```
Pilih level lewat menu interaktif. Bisa pilih beberapa sekaligus (port beda per level).

## Pemetaan level ke sertifikasi

| Level | Fokus teknik | Kira-kira setara dengan |
|-------|-------------|--------------------------|
| **low** | Service default/anonymous, kredensial lemah, enumerasi dasar | CompTIA Security+, CEH (materi konsep & pengenalan tools) |
| **medium** | Enumerasi lebih dalam, SQLi dasar, credential hunting di file/comment | OSCP (bagian awal), eCPPT (dasar) |
| **high** | Chaining vuln, crack hash offline, git history secret, JWT forgery, fail2ban aktif | OSCP (penuh), PNPT, eWPTX (bagian web), GXPN (bagian dasar) |
| **expert** | SSTI -> RCE, privesc via CVE spesifik (bukan misconfig sudoers), attack surface minimal | OSWE (logic bug di web app), OSEP (evasion & chaining kompleks) |
| **exploitdev** | Stack BOF, format string, heap UAF, remote exploitation dengan pwntools | OSED, GXPN (bagian binary exploitation) |

## Yang TIDAK dicakup lab ini (dan kenapa)

**CRTO / CRTE (Red Team Ops / Red Team Expert)** — kedua sertifikasi ini fokus
100% pada **Active Directory attack**: Kerberoasting, ACL abuse, lateral movement
antar Windows host, Domain Admin escalation, C2 frameworks (Cobalt Strike/dsb).
Ini butuh **Windows Server (Domain Controller) + beberapa Windows client**,
bukan sesuatu yang bisa disimulasikan penuh di satu VM Linux. Kalau kamu mau
lanjut ke arah ini, opsi realistis:
- Bangun lab AD terpisah pakai [GOAD](https://github.com/Orange-Cyberdefense/GOAD) (Game of Active Directory) — proyek open-source yang memang dirancang untuk ini
- Atau saya bisa bantu rancang skrip provisioning AD lab kalau kamu punya akses Windows Server ISO/lisensi (butuh proyek terpisah dari lab Linux ini)

**GXPN/GIAC secara penuh** juga mencakup wireless exploitation, network device
attacks (router/switch), dan advanced evasion — level exploitdev di lab ini
cuma mengcover bagian binary exploitation dasarnya, bukan keseluruhan silabus.

## Prasyarat belajar yang disarankan
1. Mulai dari `low` → `medium` → `high` → `expert` secara berurutan, jangan loncat
2. Untuk level `exploitdev`, pelajari dasar assembly x86-64 & cara kerja stack dulu
   kalau belum familiar — pakai `gdb-peda` atau `pwndbg` untuk mempermudah
3. Setelah tiap level selesai, baca `FLAGS-AND-VULNS.md` untuk verifikasi
   pemahaman, jangan cuma ngejar flag
4. Reset/snapshot VM sebelum ganti level supaya tidak ada konflik port/service
