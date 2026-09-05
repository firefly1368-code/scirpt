#!/usr/bin/env bash
# lib/common.sh — shared helpers untuk Ubuntu 24 (apt/ufw based)
LOGFILE="${LOGFILE:-/root/vulnubuntu-setup.log}"

log() { echo -e "\n[*] $(date '+%H:%M:%S') - $1" | tee -a "$LOGFILE"; }
ok()  { echo "    [+] $1" | tee -a "$LOGFILE"; }
err() { echo "    [-] $1" | tee -a "$LOGFILE"; }

export DEBIAN_FRONTEND=noninteractive

make_user() {
  local u="$1" p="$2"
  id "$u" &>/dev/null || useradd -m -s /bin/bash "$u"
  echo "${u}:${p}" | chpasswd
}

open_fw() {
  command -v ufw &>/dev/null || return 0
  for p in "$@"; do ufw allow "$p" &>/dev/null; done
}

install_docker_once() {
  command -v docker &>/dev/null && return 0
  apt-get update -qq &>/dev/null
  apt-get install -y -qq ca-certificates curl gnupg &>/dev/null
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc 2>/dev/null
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -qq &>/dev/null
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin &>/dev/null
  systemctl enable --now docker &>/dev/null
}

append_flagsdoc() {
  mkdir -p /root/vulnubuntu-scripts
  echo -e "$1" >> /root/vulnubuntu-scripts/FLAGS-AND-VULNS.md
}
