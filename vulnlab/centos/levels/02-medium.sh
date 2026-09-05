#!/usr/bin/env bash
# Level: MEDIUM — service butuh kredensial, tapi kredensialnya "ketemu"
# lewat enumerasi (file config, source code, dsb). Butuh chaining sederhana.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

log "LEVEL MEDIUM — provisioning"

# --- Users: password tidak sekonyol level low, tapi masih dictionary-crackable
make_user alice Summer2024
make_user devuser DevPass!99
echo "devuser ALL=(root) NOPASSWD: /usr/bin/systemctl restart httpd" > /etc/sudoers.d/92-devuser
chmod 440 /etc/sudoers.d/92-devuser

sed -i \
  -e 's/^#\?PermitRootLogin.*/PermitRootLogin no/' \
  -e 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' \
  /etc/ssh/sshd_config
systemctl restart sshd
ok "SSH: root login dimatikan, tapi password auth tetap ON (perlu user valid dulu)"

# --- FTP butuh login (bukan anonymous), creds ada di file web app ---
dnf install -y vsftpd &>/dev/null
sed -i -e 's/^anonymous_enable=.*/anonymous_enable=NO/' -e 's/^local_enable=.*/local_enable=YES/' /etc/vsftpd/vsftpd.conf 2>/dev/null || \
  echo -e "anonymous_enable=NO\nlocal_enable=YES\nwrite_enable=YES" > /etc/vsftpd/vsftpd.conf
make_user ftpuser Ftp#2024x
systemctl enable --now vsftpd &>/dev/null
ok "FTP butuh kredensial ftpuser/Ftp#2024x"

# --- phpMyAdmin exposed, MySQL user dengan password medium, tapi hint tersembunyi di komentar HTML ---
dnf install -y mariadb-server httpd php php-mysqlnd &>/dev/null
systemctl enable --now mariadb httpd &>/dev/null
mysql -u root <<'SQL' 2>/dev/null || true
CREATE DATABASE IF NOT EXISTS webapp;
CREATE USER IF NOT EXISTS 'webapp'@'%' IDENTIFIED BY 'W3bApp_2024';
GRANT ALL PRIVILEGES ON webapp.* TO 'webapp'@'%';
FLUSH PRIVILEGES;
SQL

mkdir -p /var/www/html/portal
cat > /var/www/html/portal/index.php <<'EOF'
<html><body>
<h3>Internal Portal Login</h3>
<!-- TODO devuser: hapus komentar ini sebelum prod. temp db creds: webapp / W3bApp_2024 -->
<form method="post">
  <input name="u" placeholder="user"><input type="password" name="p" placeholder="pass">
  <input type="submit">
</form>
<?php
if (!empty($_POST['u'])) {
    $conn = @mysqli_connect("localhost","webapp","W3bApp_2024","webapp");
    $u = mysqli_real_escape_string($conn, $_POST['u']);
    // Query ini masih rentan SQLi di parameter 'p' (sengaja)
    $res = @mysqli_query($conn, "SELECT * FROM users WHERE username='$u' AND password='".$_POST['p']."'");
    echo $res ? "Login attempt processed" : "Error";
}
?>
</body></html>
EOF
chown -R apache:apache /var/www/html/portal
ok "Portal PHP dengan SQLi di field password + hint credential di HTML comment"

# --- Redis dengan password lemah, bind localhost saja (butuh SSRF/pivot dari web app) ---
dnf install -y redis &>/dev/null
sed -i 's/^bind .*/bind 127.0.0.1/' /etc/redis/redis.conf 2>/dev/null
echo "requirepass redis2024" >> /etc/redis/redis.conf
systemctl enable --now redis &>/dev/null
ok "Redis requirepass redis2024, hanya localhost (perlu pivot)"

# --- DVWA disetel security=medium secara default (via .htaccess trick tidak perlu, cukup dokumentasi) ---
install_docker_once
docker run -d --name dvwa --restart unless-stopped -p 8081:80 vulnerables/web-dvwa &>/dev/null
docker run -d --name webgoat --restart unless-stopped -p 8082:8080 webgoat/webgoat &>/dev/null
ok "DVWA (set security=medium di UI), WebGoat"

open_fw 21/tcp 22/tcp 80/tcp 8081/tcp 8082/tcp
setenforce 1 2>/dev/null || true
sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config 2>/dev/null || true

append_flagsdoc "
## LEVEL: MEDIUM
- SSH: root login OFF, password auth ON — perlu temukan user valid dulu
- alice/Summer2024, devuser/DevPass!99 (sudo terbatas restart httpd)
- FTP butuh login: ftpuser/Ftp#2024x
- /portal/ — SQLi di parameter password, hint credential ada di HTML comment (view-source!)
- MySQL webapp/W3bApp_2024
- Redis requirepass redis2024, bind localhost only — perlu pivot dari web app (SSRF/RCE)
- DVWA (set security ke 'medium'), WebGoat
"
log "LEVEL MEDIUM selesai."
