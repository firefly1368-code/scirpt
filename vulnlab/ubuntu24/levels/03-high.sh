#!/usr/bin/env bash
# Level: HIGH (Ubuntu 24) — chaining, crack hash, git history, JWT forge.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

log "LEVEL HIGH (Ubuntu) — provisioning"
apt-get update -qq &>/dev/null
apt-get install -y -qq openssh-server apache2 php git python3 python3-pip python3-venv &>/dev/null

make_user svc_deploy 'C0mpl3x!Pass_92x'
sed -i \
  -e 's/^#\?PermitRootLogin.*/PermitRootLogin no/' \
  -e 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' \
  -e 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' \
  /etc/ssh/sshd_config
systemctl restart ssh
ok "SSH key-only. Password svc_deploy hanya lewat shadow leak"

mkdir -p /var/backups/system
cp /etc/shadow /var/backups/system/shadow.bak
chmod 644 /var/backups/system/shadow.bak
ok "Shadow backup readable — perlu offline crack"

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
git add config.py && git commit -qm "remove hardcoded secrets"
chmod -R o+rX "$REPO"
ok "Git repo $REPO — secret ada di commit history lama"

python3 -m venv /opt/apps/authapp-venv &>/dev/null
/opt/apps/authapp-venv/bin/pip install --quiet flask pyjwt &>/dev/null
mkdir -p /opt/apps/authapp
cat > /opt/apps/authapp/app.py <<'PYEOF'
from flask import Flask, request, jsonify
import jwt, datetime

app = Flask(__name__)
SECRET = "changeme123"

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

cat > /etc/systemd/system/authapp.service <<EOF
[Unit]
Description=VulnUbuntu AuthApp (JWT lab)
After=network.target

[Service]
ExecStart=/opt/apps/authapp-venv/bin/python3 /opt/apps/authapp/app.py
Restart=always
User=nobody

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now authapp &>/dev/null
ok "AuthApp port 5000 — login guest/guest lalu forge JWT role=admin"

apt-get install -y -qq fail2ban ufw &>/dev/null
systemctl enable --now fail2ban &>/dev/null
open_fw 22/tcp 5000/tcp
ufw --force enable &>/dev/null

append_flagsdoc "
## LEVEL: HIGH (Ubuntu 24)
- SSH key-only, svc_deploy password hanya lewat crack shadow.bak
- Git repo /srv/git/internal-tool — secret di commit history lama
- AuthApp (5000): login guest/guest -> forge JWT role=admin (secret lemah)
- fail2ban aktif, AppArmor enforce
"
log "LEVEL HIGH (Ubuntu) selesai."
