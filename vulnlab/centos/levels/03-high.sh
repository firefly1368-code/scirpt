#!/usr/bin/env bash
# Level: HIGH — attack surface kecil, butuh chaining beberapa vuln, crack hash,
# gali git history, dan exploit logic bug di custom app kecil.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

log "LEVEL HIGH — provisioning"

# --- SSH hanya key-based, tapi ada 1 user dengan password kuat-ish yang bisa dicrack offline lewat shadow leak ---
dnf install -y httpd php php-mysqlnd git &>/dev/null
make_user svc_deploy 'C0mpl3x!Pass_92x'
sed -i \
  -e 's/^#\?PermitRootLogin.*/PermitRootLogin no/' \
  -e 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' \
  -e 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' \
  /etc/ssh/sshd_config
systemctl restart sshd
ok "SSH key-only. Password svc_deploy hanya bisa didapat lewat shadow leak (lihat di bawah)"

# --- Backup script bikin file shadow-copy yang readable, "lupa" di-hapus ---
mkdir -p /var/backups/system
cp /etc/shadow /var/backups/system/shadow.bak 2>/dev/null
chmod 644 /var/backups/system/shadow.bak
ok "Shadow file backup readable di /var/backups/system/shadow.bak — perlu offline crack (hashcat/john)"

# --- Git repo dengan history yang bocorin credential lama (sudah di-"fix" di commit terbaru) ---
REPO=/srv/git/internal-tool
mkdir -p "$REPO" && cd "$REPO"
git init -q
git config user.email "dev@lab.local"; git config user.name "dev"
cat > config.py <<'EOF'
API_KEY = "sk_live_prod_key_will_be_removed"
DB_PASSWORD = "SuperSecretDbPass!2023"
EOF
git add config.py && git commit -qm "initial commit with config"
cat > config.py <<'EOF'
import os
API_KEY = os.environ.get("API_KEY")
DB_PASSWORD = os.environ.get("DB_PASSWORD")
EOF
git add config.py && git commit -qm "remove hardcoded secrets (fix security issue)"
chmod -R o+rX "$REPO"
ok "Git repo di $REPO — secret ada di commit history lama, bukan HEAD (git log -p)"

# --- Web app dengan JWT secret lemah (custom Flask app kecil) ---
dnf install -y python3 python3-pip &>/dev/null
pip3 install --quiet flask pyjwt &>/dev/null
mkdir -p /opt/apps/authapp
cat > /opt/apps/authapp/app.py <<'PYEOF'
from flask import Flask, request, jsonify
import jwt, datetime

app = Flask(__name__)
SECRET = "changeme123"  # lemah, brute-forceable dengan wordlist kecil

@app.route("/login", methods=["POST"])
def login():
    data = request.json or {}
    if data.get("user") == "guest" and data.get("pass") == "guest":
        token = jwt.encode({"user": "guest", "role": "user",
                             "exp": datetime.datetime.utcnow()+datetime.timedelta(hours=1)},
                            SECRET, algorithm="HS256")
        return jsonify(token=token)
    return jsonify(error="invalid"), 401

@app.route("/admin")
def admin():
    token = request.headers.get("Authorization","").replace("Bearer ","")
    try:
        payload = jwt.decode(token, SECRET, algorithms=["HS256"])
    except Exception:
        return jsonify(error="unauthorized"), 401
    if payload.get("role") != "admin":
        return jsonify(error="forbidden, need role=admin"), 403
    return jsonify(flag="high_level_flag_via_jwt_forge")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
PYEOF

cat > /etc/systemd/system/authapp.service <<'EOF'
[Unit]
Description=VulnCentOS AuthApp (JWT lab)
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/apps/authapp/app.py
Restart=always
User=nobody

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now authapp &>/dev/null
ok "AuthApp di port 5000 — login guest/guest lalu forge JWT role=admin (secret lemah, wordlist-crackable)"

# --- fail2ban ON dengan threshold wajar (bruteforce naif akan diblok) ---
dnf install -y epel-release &>/dev/null
dnf install -y fail2ban &>/dev/null
systemctl enable --now fail2ban &>/dev/null
ok "fail2ban aktif — bruteforce naif kena blok, perlu teknik lebih pelan/cerdas"

open_fw 22/tcp 5000/tcp
setenforce 1 2>/dev/null || true
sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config 2>/dev/null || true

append_flagsdoc "
## LEVEL: HIGH
- SSH: key-only, password login dimatikan
- svc_deploy password hanya didapat lewat crack /var/backups/system/shadow.bak
- Git repo /srv/git/internal-tool — secret ada di commit history lama, cek 'git log -p'
- AuthApp (port 5000): POST /login {user:guest,pass:guest} -> dapat JWT,
  lalu forge token role=admin (secret HS256 lemah) untuk akses GET /admin
- fail2ban aktif, SELinux enforcing — attack surface sengaja dikecilkan
"
log "LEVEL HIGH selesai."
