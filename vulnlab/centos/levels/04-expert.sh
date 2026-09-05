#!/usr/bin/env bash
# Level: EXPERT — attack surface minimal, hampir tidak ada default creds.
# Butuh menemukan logic bug custom + exploit CVE spesifik pada versi yang
# sengaja di-pin lama (sudo / polkit), plus SSTI di custom app.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

log "LEVEL EXPERT — provisioning"

# --- SSH: key-only, satu low-priv user, tanpa hint credential apapun ---
make_user appuser 'R4nd0m_Str0ng_Pass_Xk92!'
sed -i \
  -e 's/^#\?PermitRootLogin.*/PermitRootLogin no/' \
  -e 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' \
  /etc/ssh/sshd_config
systemctl restart sshd
ok "SSH key-only, satu user low-priv (akses awal harus lewat web app)"

# --- Custom Flask app dengan SSTI tersembunyi (bukan textbook-obvious) ---
dnf install -y python3 python3-pip &>/dev/null
pip3 install --quiet flask &>/dev/null
mkdir -p /opt/apps/reportgen
cat > /opt/apps/reportgen/app.py <<'PYEOF'
from flask import Flask, request, render_template_string

app = Flask(__name__)

# Sengaja: nama pelanggan dirender pakai template string -> SSTI
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
    # celah: render_template_string dengan input user -> Jinja2 SSTI -> RCE
    return render_template_string(page)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)
PYEOF

cat > /etc/systemd/system/reportgen.service <<'EOF'
[Unit]
Description=VulnCentOS ReportGen (SSTI lab)
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/apps/reportgen/app.py
Restart=always
User=appuser

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now reportgen &>/dev/null
ok "ReportGen di port 5001 — SSTI di parameter 'customer' (Jinja2), initial foothold user appuser"

# --- Privesc: pin versi sudo & polkit yang vulnerable ke CVE lama, TANPA sudoers longgar ---
dnf versionlock delete sudo polkit &>/dev/null || true
CUR_SUDO=$(rpm -q sudo)
CUR_POLKIT=$(rpm -q polkit 2>/dev/null || echo "n/a")
dnf versionlock add sudo &>/dev/null
dnf versionlock add polkit &>/dev/null 2>&1 || true
ok "Versi sudo ($CUR_SUDO) & polkit ($CUR_POLKIT) di-lock — cek CVE yang relevan utk versi ini (CVE-2019-14287 / CVE-2021-3560 dsb, tergantung versi repo)"

# TIDAK ada NOPASSWD sudoers untuk appuser — privesc harus lewat CVE binary itu sendiri
# atau lewat vector lain yang harus ditemukan sendiri saat enumerasi.

# --- File konfigurasi internal yang sedikit "bocor" tapi butuh privilege buat baca ---
mkdir -p /opt/internal
cat > /opt/internal/notes.enc <<'EOF'
U2FsdGVkX1+3q8k5vXz3F0m0z2s7l5b8m6JzX2b1v9k=
EOF
chmod 640 /opt/internal/notes.enc
chown root:appuser /opt/internal/notes.enc
ok "File /opt/internal/notes.enc readable oleh grup appuser (openssl enc format) — decode setelah dapat akses lebih tinggi/kunci yang relevan"

# --- fail2ban ketat + SELinux enforcing penuh ---
dnf install -y epel-release &>/dev/null
dnf install -y fail2ban &>/dev/null
cat > /etc/fail2ban/jail.local <<'EOF'
[sshd]
enabled = true
maxretry = 3
bantime = 3600
findtime = 300
EOF
systemctl enable --now fail2ban &>/dev/null
setenforce 1 2>/dev/null || true
sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config 2>/dev/null || true

open_fw 22/tcp 5001/tcp

append_flagsdoc "
## LEVEL: EXPERT
- SSH key-only, satu user low-priv (appuser) — TIDAK ada credential hint di manapun
- ReportGen (port 5001) GET /report?customer=<payload> — Jinja2 SSTI -> RCE (foothold)
- sudo & polkit di-pin ke versi repo saat instalasi — cek 'sudo -V' & CVE database
  untuk versi tsb sebagai privesc path (tidak ada NOPASSWD sudoers)
- /opt/internal/notes.enc — terenkripsi (openssl enc), readable grup appuser,
  perlu temukan kunci/metode dekripsi dari bagian lain sistem
- fail2ban ketat (maxretry=3), SELinux enforcing penuh, attack surface minimal
- Tantangan: chain SSTI RCE -> stabilkan shell -> enumerasi CVE privesc -> root
"
log "LEVEL EXPERT selesai."
