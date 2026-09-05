#!/usr/bin/env bash
#
# ============================================================================
#  VulnUbuntu Lab Builder — Tiered Edition (Ubuntu 24.04)
#  Isolated lab network ONLY.
# ============================================================================

set -uo pipefail
LOGFILE="/root/vulnubuntu-setup.log"
export LOGFILE
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $EUID -ne 0 ]]; then
  echo "Jalankan sebagai root (sudo bash 00-setup.sh)"; exit 1
fi

echo "============================================================"
echo " VulnUbuntu Lab Builder — Tiered Edition"
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
echo "  1) low          - service kebuka lebar, kredensial default (Security+/CEH)"
echo "  2) medium       - enumerasi & credential hunting (OSCP awal, eCPPT)"
echo "  3) high         - crack hash, git history, JWT forge (OSCP, PNPT, eWPTX)"
echo "  4) expert       - SSTI, privesc via CVE spesifik (OSWE, OSEP tier)"
echo "  5) exploitdev   - binary exploitation BOF/format string/heap (OSED/GXPN)"
echo "  6) all          - deploy semua level sekaligus"
read -rp "Pilihan (contoh: 1 3, atau 6): " CHOICES

apt-get update -qq &>>"$LOGFILE"

mkdir -p /root/vulnubuntu-scripts
cp -rf "$SCRIPT_DIR"/lib "$SCRIPT_DIR"/levels /root/vulnubuntu-scripts/ 2>/dev/null || true
: > /root/vulnubuntu-scripts/FLAGS-AND-VULNS.md
echo "# VulnUbuntu — Daftar Kerentanan per Level" >> /root/vulnubuntu-scripts/FLAGS-AND-VULNS.md

declare -A MAP=( [1]="01-low.sh" [2]="02-medium.sh" [3]="03-high.sh" [4]="04-expert.sh" [5]="05-expert-exploitdev.sh" )

run_level() {
  local file="$1"
  if [[ -f "$SCRIPT_DIR/levels/$file" ]]; then
    echo -e "\n[*] Menjalankan level: $file" | tee -a "$LOGFILE"
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
 VulnUbuntu siap dipakai untuk latihan.
 IP VM: $IP

 Daftar lengkap kerentanan per level ada di:
   /root/vulnubuntu-scripts/FLAGS-AND-VULNS.md

 Ingat: matikan/isolasi VM ini saat tidak dipakai latihan.
============================================================
EOF
