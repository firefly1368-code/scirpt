#!/usr/bin/env bash
# Level: LOW — semuanya kebuka lebar, kredensial default, tanpa filtering.
# Cocok buat yang baru mulai belajar enumerasi dasar.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

log "LEVEL LOW — provisioning"

# --- Users & SSH ---
make_user alice alice123
make_user bob password
echo "root:toor" | chpasswd
echo "bob ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/90-bob
chmod 440 /etc/sudoers.d/90-bob

sed -i \
  -e 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' \
  -e 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' \
  -e 's/^#\?PermitEmptyPasswords.*/PermitEmptyPasswords yes/' \
  /etc/ssh/sshd_config
systemctl restart sshd

# --- Telnet (klasik, plaintext creds) ---
dnf install -y telnet-server &>/dev/null
systemctl enable --now telnet.socket &>/dev/null && ok "telnet aktif di 23 (plaintext auth)"

# --- FTP anonymous full access ---
dnf install -y vsftpd &>/dev/null
cat > /etc/vsftpd/vsftpd.conf <<'EOF'
listen=YES
anonymous_enable=YES
anon_upload_enable=YES
anon_mkdir_write_enable=YES
write_enable=YES
local_enable=YES
pasv_enable=YES
pasv_min_port=30000
pasv_max_port=31000
EOF
mkdir -p /var/ftp/pub && chmod 777 /var/ftp/pub
systemctl enable --now vsftpd &>/dev/null
ok "FTP anonymous read/write di 21"

# --- Samba open guest share ---
dnf install -y samba &>/dev/null
cat >> /etc/samba/smb.conf <<'EOF'

[open-share]
   path = /srv/samba/open
   guest ok = yes
   guest only = yes
   read only = no
   force user = nobody
EOF
mkdir -p /srv/samba/open && chmod 777 /srv/samba/open
systemctl enable --now smb nmb &>/dev/null
ok "Samba guest share terbuka di 445"

# --- MySQL/MariaDB root tanpa password, bind ke semua interface ---
dnf install -y mariadb-server &>/dev/null
systemctl enable --now mariadb &>/dev/null
mysqladmin -u root password "" 2>/dev/null || true
sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/my.cnf.d/mariadb-server.cnf 2>/dev/null || \
  echo -e "[mysqld]\nbind-address = 0.0.0.0" >> /etc/my.cnf.d/mariadb-server.cnf
mysql -u root <<'SQL' 2>/dev/null || true
CREATE DATABASE IF NOT EXISTS shop;
CREATE USER IF NOT EXISTS 'admin'@'%' IDENTIFIED BY 'admin123';
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%';
FLUSH PRIVILEGES;
SQL
systemctl restart mariadb
ok "MariaDB root no-password, user admin/admin123, exposed di 3306"

# --- Redis tanpa auth ---
dnf install -y redis &>/dev/null
sed -i 's/^bind .*/bind 0.0.0.0/' /etc/redis/redis.conf 2>/dev/null
sed -i 's/^protected-mode yes/protected-mode no/' /etc/redis/redis.conf 2>/dev/null
systemctl enable --now redis &>/dev/null
ok "Redis tanpa auth di 6379"

# --- Web apps rentan via Docker ---
install_docker_once
docker run -d --name dvwa --restart unless-stopped -p 8081:80 vulnerables/web-dvwa &>/dev/null
docker run -d --name juiceshop --restart unless-stopped -p 8083:3000 bkimminich/juice-shop &>/dev/null
ok "DVWA (8081, set security=low), Juice Shop (8083)"

# --- Firewall & SELinux dibuka lebar ---
open_fw 21/tcp 22/tcp 23/tcp 80/tcp 445/tcp 3306/tcp 6379/tcp 8081/tcp 8083/tcp
setenforce 0 2>/dev/null || true
sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config 2>/dev/null || true
systemctl disable --now fail2ban &>/dev/null || true

append_flagsdoc "
## LEVEL: LOW
- SSH: root/toor, PasswordAuth ON
- bob/password — sudo NOPASSWD ALL
- Telnet aktif (23), FTP anonymous rw (21), Samba guest share (445)
- MariaDB root no-password + admin/admin123 exposed di 3306
- Redis tanpa auth di 6379
- DVWA (set security level ke 'low' di UI), Juice Shop
- SELinux permissive, fail2ban off
"
log "LEVEL LOW selesai."
