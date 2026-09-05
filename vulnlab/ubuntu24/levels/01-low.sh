#!/usr/bin/env bash
# Level: LOW (Ubuntu 24) — sama filosofi dengan CentOS: service terbuka lebar,
# kredensial default, cocok buat pemula (Security+, CEH tier).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

log "LEVEL LOW (Ubuntu) — provisioning"
apt-get update -qq &>/dev/null

make_user alice alice123
make_user bob password
echo "root:toor" | chpasswd
usermod -aG sudo bob 2>/dev/null
echo "bob ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/90-bob
chmod 440 /etc/sudoers.d/90-bob

apt-get install -y -qq openssh-server &>/dev/null
sed -i \
  -e 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' \
  -e 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' \
  -e 's/^#\?PermitEmptyPasswords.*/PermitEmptyPasswords yes/' \
  /etc/ssh/sshd_config
systemctl restart ssh

apt-get install -y -qq telnetd &>/dev/null && systemctl enable --now inetutils-telnetd &>/dev/null
ok "telnet aktif di 23"

apt-get install -y -qq vsftpd &>/dev/null
cat > /etc/vsftpd.conf <<'EOF'
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
mkdir -p /srv/ftp && chmod 777 /srv/ftp
systemctl enable --now vsftpd &>/dev/null
ok "FTP anonymous read/write di 21"

apt-get install -y -qq samba &>/dev/null
cat >> /etc/samba/smb.conf <<'EOF'

[open-share]
   path = /srv/samba/open
   guest ok = yes
   guest only = yes
   read only = no
   force user = nobody
EOF
mkdir -p /srv/samba/open && chmod 777 /srv/samba/open
systemctl enable --now smbd nmbd &>/dev/null
ok "Samba guest share terbuka di 445"

apt-get install -y -qq mariadb-server &>/dev/null
systemctl enable --now mariadb &>/dev/null
sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf 2>/dev/null
mysql -u root <<'SQL' 2>/dev/null || true
CREATE USER IF NOT EXISTS 'admin'@'%' IDENTIFIED BY 'admin123';
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%';
FLUSH PRIVILEGES;
SQL
systemctl restart mariadb
ok "MariaDB admin/admin123 exposed di 3306"

apt-get install -y -qq redis-server &>/dev/null
sed -i 's/^bind .*/bind 0.0.0.0/' /etc/redis/redis.conf
sed -i 's/^protected-mode yes/protected-mode no/' /etc/redis/redis.conf
systemctl enable --now redis-server &>/dev/null
ok "Redis tanpa auth di 6379"

install_docker_once
docker run -d --name dvwa --restart unless-stopped -p 8081:80 vulnerables/web-dvwa &>/dev/null
docker run -d --name juiceshop --restart unless-stopped -p 8083:3000 bkimminich/juice-shop &>/dev/null
ok "DVWA (8081, set security=low), Juice Shop (8083)"

apt-get install -y -qq ufw &>/dev/null
open_fw 21/tcp 22/tcp 23/tcp 80/tcp 445/tcp 3306/tcp 6379/tcp 8081/tcp 8083/tcp
ufw --force enable &>/dev/null
systemctl disable --now fail2ban &>/dev/null || true

# AppArmor dilonggarkan biar mirip "SELinux permissive" versi Ubuntu
aa-complain /etc/apparmor.d/* &>/dev/null || true

append_flagsdoc "
## LEVEL: LOW (Ubuntu 24)
- SSH: root/toor, PasswordAuth ON
- bob/password — sudo NOPASSWD ALL
- Telnet aktif (23), FTP anonymous rw (21), Samba guest share (445)
- MariaDB admin/admin123 exposed di 3306
- Redis tanpa auth di 6379
- DVWA (set security ke 'low'), Juice Shop
- AppArmor complain mode, fail2ban off
"
log "LEVEL LOW (Ubuntu) selesai."
