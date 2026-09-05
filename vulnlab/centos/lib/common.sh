#!/usr/bin/env bash
# lib/common.sh — shared helpers, di-source oleh script level manapun
LOGFILE="${LOGFILE:-/root/vulncentos-setup.log}"

log() { echo -e "\n[*] $(date '+%H:%M:%S') - $1" | tee -a "$LOGFILE"; }
ok()  { echo "    [+] $1" | tee -a "$LOGFILE"; }
err() { echo "    [-] $1" | tee -a "$LOGFILE"; }

make_user() {
  # make_user <username> <password>
  local u="$1" p="$2"
  id "$u" &>/dev/null || useradd -m "$u"
  echo "${u}:${p}" | chpasswd
}

open_fw() {
  command -v firewall-cmd &>/dev/null || return 0
  for svc in "$@"; do firewall-cmd --permanent --add-port="$svc" &>/dev/null || firewall-cmd --permanent --add-service="$svc" &>/dev/null; done
  firewall-cmd --reload &>/dev/null
}

install_docker_once() {
  command -v docker &>/dev/null && return 0
  dnf install -y dnf-plugins-core &>/dev/null
  dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo &>/dev/null
  dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin &>/dev/null
  systemctl enable --now docker &>/dev/null
}

append_flagsdoc() {
  # append_flagsdoc <text> — nambah entri ke dokumentasi akhir
  mkdir -p /root/vulncentos-scripts
  echo -e "$1" >> /root/vulncentos-scripts/FLAGS-AND-VULNS.md
}
