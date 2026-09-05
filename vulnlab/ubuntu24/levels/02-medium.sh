#!/usr/bin/env bash
# Level: MEDIUM (Ubuntu 24) — perlu enumerasi & credential hunting, chaining sederhana.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

log "LEVEL MEDIUM (Ubuntu) — provisioning"
apt-get update -qq &>/dev/null

make_user alice Summer2024
make_user devuser 'DevPass!99'
echo "devuser ALL=(root) NOPASSWD: /usr/bin/systemctl restart apache2" > /etc/sudoers.d/92-devuser
chmod 440 /etc/sudoers.d/92-devuser

apt-get install -y -qq openssh-server &>/dev/null
sed -i \
  -e 's/^#\?PermitRootLogin.*/PermitRootLogin no/' \
  -e 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' \
  /etc/ssh/sshd_config
systemctl restart ssh
ok "SSH: root login OFF, password auth ON"

apt-get install -y -qq vsftpd &>/dev/null
cat > /etc/vsftpd.conf <<'EOF'
listen=YES
anonymous_enable=NO
local_enable=YES
write_enable=YES
EOF
make_user ftpuser 'Ftp#2024x'
systemctl enable --now vsftpd &>/dev/null
ok "FTP butuh kredensial ftpuser/Ftp#2024x"

apt-get install -y -qq mariadb-server apache2 php libapache2-mod-php php-mysql &>/dev/null
systemctl enable --now mariadb apache2 &>/dev/null
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
    $res = @mysqli_query($conn, "SELECT * FROM users WHERE username='$u' AND password='".$_POST['p']."'");
    echo $res ? "Login attempt processed" : "Error";
}
?>
</body></html>
EOF
chown -R www-data:www-data /var/www/html/portal
ok "Portal PHP dengan SQLi di field password + hint credential di HTML comment"

apt-get install -y -qq redis-server &>/dev/null
sed -i 's/^bind .*/bind 127.0.0.1/' /etc/redis/redis.conf
echo "requirepass redis2024" >> /etc/redis/redis.conf
systemctl enable --now redis-server &>/dev/null
ok "Redis requirepass redis2024, localhost only — perlu pivot"

install_docker_once
docker run -d --name dvwa --restart unless-stopped -p 8081:80 vulnerables/web-dvwa &>/dev/null
docker run -d --name webgoat --restart unless-stopped -p 8082:8080 webgoat/webgoat &>/dev/null
ok "DVWA (set security=medium), WebGoat"

apt-get install -y -qq ufw &>/dev/null
open_fw 21/tcp 22/tcp 80/tcp 8081/tcp 8082/tcp
ufw --force enable &>/dev/null

append_flagsdoc "
## LEVEL: MEDIUM (Ubuntu 24)
- SSH: root login OFF, password auth ON
- alice/Summer2024, devuser/DevPass!99 (sudo terbatas restart apache2)
- FTP butuh login: ftpuser/Ftp#2024x
- /portal/ — SQLi di parameter password, hint credential di HTML comment
- MySQL webapp/W3bApp_2024
- Redis requirepass redis2024, localhost only — perlu pivot dari web app
- DVWA (set security ke 'medium'), WebGoat
"
log "LEVEL MEDIUM (Ubuntu) selesai."
