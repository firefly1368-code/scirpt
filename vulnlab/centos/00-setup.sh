#!/usr/bin/env bash
#
# ============================================================================
#  VulnCentOS Lab Builder — Tiered Edition
#  Target: CentOS Stream 9 (isolated lab network ONLY)
#
#  Pilih level: low / medium / high / expert
#  Bisa install lebih dari satu level sekaligus (mis. deploy semua utk
#  latihan progresif), atau satu-satu.
#
#  !!! PERINGATAN !!!
#  - JANGAN jalankan di server produksi.
#  - JANGAN expose VM ini ke internet / jaringan kantor.
#  - Jalankan hanya di VM terisolasi (host-only / internal network).
# ============================================================================

set -uo pipefail
LOGFILE="/root/vulncentos-setup.log"
export LOGFILE
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $EUID -ne 0 ]]; then
  echo "Jalankan sebagai root (sudo bash 00-setup.sh)"; exit 1
fi

echo "============================================================"
echo " VulnCentOS Lab Builder — Tiered Edition"
echo " Script ini akan SENGAJA MELEMAHKAN keamanan sistem ini."
echo " Pastikan ini VM lab terisolasi, bukan server produksi/nyata."
echo "============================================================"
read -rp "Ketik 'SAYA MENGERTI' untuk lanjut: " CONFIRM
[[ "$CONFIRM" == "SAYA MENGERTI" ]] || { echo "Dibatalkan."; exit 1; }

if command -v curl &>/dev/null; then
  PUB_IP=$(curl -s --max-time 3 ifconfig.me 2>/dev/null || true)
  if [[ -n "$PUB_IP" ]]; then
    echo
    echo "[!] VM ini kedeteksi bisa akses internet (IP publik: $PUB_IP)."
    echo "    Sebaiknya set interface jadi host-only/internal dulu."
    read -rp "    Tetap lanjut? (yes/NO): " NETCONFIRM
    [[ "$NETCONFIRM" == "yes" ]] || { echo "Dibatalkan."; exit 1; }
  fi
fi

echo
echo "Pilih level yang mau di-deploy (bisa lebih dari satu, pisah spasi):"
echo "  1) low     - service kebuka lebar, kredensial default, buat pemula"
echo "  2) medium  - butuh enumerasi & kredensial 'ketemu', chaining sederhana"
echo "  3) high    - crack hash, gali git history, forge JWT, fail2ban aktif"
echo "  4) expert  - custom app SSTI, privesc via CVE spesifik, surface minimal"
echo "  5) exploitdev - binary exploitation (BOF/format string/heap UAF), gaya OSED/GXPN"
echo "  6) all     - deploy semua level sekaligus (port berbeda per level)"
read -rp "Pilihan (contoh: 1 3, atau 6): " CHOICES

dnf install -y epel-release &>>"$LOGFILE"
dnf makecache &>>"$LOGFILE"

mkdir -p /root/vulncentos-scripts
cp -rf "$SCRIPT_DIR"/lib "$SCRIPT_DIR"/levels /root/vulncentos-scripts/ 2>/dev/null || true
: > /root/vulncentos-scripts/FLAGS-AND-VULNS.md
echo "# VulnCentOS — Daftar Kerentanan per Level" >> /root/vulncentos-scripts/FLAGS-AND-VULNS.md

declare -A MAP=( [1]="01-low.sh" [2]="02-medium.sh" [3]="03-high.sh" [4]="04-expert.sh" [5]="05-expert-exploitdev.sh" )

run_level() {
  local file="$1"
  if [[ -f "$SCRIPT_DIR/levels/$file" ]]; then
    log_msg="Menjalankan level: $file"
    echo -e "\n[*] $log_msg" | tee -a "$LOGFILE"
    bash "$SCRIPT_DIR/levels/$file" 2>&1 | tee -a "$LOGFILE"
  fi
}

if [[ "$CHOICES" == *6* || "$CHOICES" == *all* ]]; then
  for f in 01-low.sh 02-medium.sh 03-high.sh 04-expert.sh 05-expert-exploitdev.sh; do run_level "$f"; done
else
  for c in $CHOICES; do
    [[ -n "${MAP[$c]:-}" ]] && run_level "${MAP[$c]}"
  done
fi

echo
IP=$(hostname -I | awk '{print $1}')
cat <<EOF | tee -a "$LOGFILE"

============================================================
 VulnCentOS siap dipakai untuk latihan.
 IP VM: $IP

 Daftar lengkap kerentanan per level ada di:
   /root/vulncentos-scripts/FLAGS-AND-VULNS.md

 Ingat: matikan/isolasi VM ini saat tidak dipakai latihan.
============================================================
EOF
