#!/usr/bin/env bash
# Level: EXPERT (Ubuntu 24) — SSTI foothold, privesc via pinned CVE, minimal surface.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

log "LEVEL EXPERT (Ubuntu) — provisioning"
apt-get update -qq &>/dev/null
apt-get install -y -qq openssh-server python3 python3-pip python3-venv &>/dev/null

make_user appuser 'R4nd0m_Str0ng_Pass_Xk92!'
sed -i \
  -e 's/^#\?PermitRootLogin.*/PermitRootLogin no/' \
  -e 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' \
  /etc/ssh/sshd_config
systemctl restart ssh
ok "SSH key-only, satu user low-priv, tanpa hint credential"

python3 -m venv /opt/apps/reportgen-venv &>/dev/null
/opt/apps/reportgen-venv/bin/pip install --quiet flask &>/dev/null
mkdir -p /opt/apps/reportgen
cat > /opt/apps/reportgen/app.py <<'PYEOF'
from flask import Flask, request, render_template_string

app = Flask(__name__)
TEMPLATE = """
<html><body>
<h3>Report Generator</h3>
<form method="get">
  <input name="customer" placeholder="Customer name" value="{{ request.args.get('customer','') }}">
  <input type="submit" value="Generate">
</form>
<div>Report for: __CUSTOMER__</div>
</body></html>
"""

@app.route("/report")
def report():
    customer = request.args.get("customer", "Guest")
    page = TEMPLATE.replace("__CUSTOMER__", customer)
    return render_template_string(page)  # Jinja2 SSTI sengaja

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)
PYEOF

cat > /etc/systemd/system/reportgen.service <<EOF
[Unit]
Description=VulnUbuntu ReportGen (SSTI lab)
After=network.target

[Service]
ExecStart=/opt/apps/reportgen-venv/bin/python3 /opt/apps/reportgen/app.py
Restart=always
User=appuser

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now reportgen &>/dev/null
ok "ReportGen port 5001 — SSTI di parameter 'customer' (foothold)"

# Pin sudo ke versi repo saat ini (bukan downgrade paksa, cuma dikunci)
apt-mark hold sudo &>/dev/null || true
CUR_SUDO=$(dpkg -l sudo | tail -1 | awk '{print $3}')
ok "Versi sudo ($CUR_SUDO) di-hold — cek CVE relevan untuk versi ini sebagai privesc path"

mkdir -p /opt/internal
cat > /opt/internal/notes.enc <<'EOF'
U2FsdGVkX1+3q8k5vXz3F0m0z2s7l5b8m6JzX2b1v9k=
EOF
chmod 640 /opt/internal/notes.enc
chown root:appuser /opt/internal/notes.enc
ok "/opt/internal/notes.enc readable grup appuser — perlu temukan metode dekripsi"

apt-get install -y -qq fail2ban ufw &>/dev/null
cat > /etc/fail2ban/jail.local <<'EOF'
[sshd]
enabled = true
maxretry = 3
bantime = 3600
findtime = 300
EOF
systemctl enable --now fail2ban &>/dev/null
open_fw 22/tcp 5001/tcp
ufw --force enable &>/dev/null

append_flagsdoc "
## LEVEL: EXPERT (Ubuntu 24)
- SSH key-only, appuser tanpa hint credential apapun
- ReportGen (5001) GET /report?customer=<payload> — Jinja2 SSTI -> RCE
- sudo di-hold ke versi repo saat instalasi — cek CVE utk versi tsb, TIDAK ada
  NOPASSWD sudoers, privesc harus lewat CVE binary itu sendiri
- /opt/internal/notes.enc terenkripsi (openssl enc), readable grup appuser
- fail2ban ketat (maxretry=3), AppArmor enforce, attack surface minimal
"
log "LEVEL EXPERT (Ubuntu) selesai."
