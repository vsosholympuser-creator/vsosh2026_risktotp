#!/usr/bin/env bash
set -euo pipefail

apt install -y python3 python3-pip

python3 -m pip install --break-system-packages -U pyotp

install -o root -g root -m 0755 ./Binaries/secure-passwd   /usr/local/sbin/secure-passwd
install -o root -g root -m 0755 ./Binaries/secure-sshkeys  /usr/local/sbin/secure-sshkeys
install -o root -g root -m 0755 ./Binaries/secure-admin    /usr/local/sbin/secure-admin
install -o root -g root -m 0755 ./Binaries/secure-audit-view /usr/local/sbin/secure-audit-view
install -o root -g root -m 0755 ./Binaries/secure-approve /usr/local/sbin/secure-approve

echo "! Binaries setup complete."

getent group operators >/dev/null || groupadd operators

cat > /etc/sudoers.d/operators <<'EOF'
%operators ALL=(root) NOPASSWD: /usr/local/sbin/secure-passwd *
%operators ALL=(root) NOPASSWD: /usr/local/sbin/secure-sshkeys *
%operators ALL=(root) NOPASSWD: /usr/local/sbin/secure-admin *
%operators ALL=(root) NOPASSWD: /usr/local/sbin/secure-audit-view *
%operators ALL=(root) NOPASSWD: /usr/local/sbin/secure-approve *
EOF

chmod 0440 /etc/sudoers.d/operators
visudo -cf /etc/sudoers.d/operators
echo "! Sudoers setup complete."

apt install -y apparmor apparmor-utils apparmor-profiles logrotate
systemctl enable --now apparmor
aa-status >/dev/null || true
echo "! AppArmor installation complete."

install -o root -g root -m 0644 ./AppArmor/passwd_aa      /etc/apparmor.d/usr.local.sbin.secure-passwd
install -o root -g root -m 0644 ./AppArmor/sshkeys_aa     /etc/apparmor.d/usr.local.sbin.secure-sshkeys
install -o root -g root -m 0644 ./AppArmor/admin_aa /etc/apparmor.d/usr.local.sbin.secure-admin
install -o root -g root -m 0644 ./AppArmor/audit_aa  /etc/apparmor.d/usr.local.sbin.secure-audit-view
install -o root -g root -m 0644 ./AppArmor/approve_aa /etc/apparmor.d/usr.local.sbin.secure-approve

apparmor_parser -r /etc/apparmor.d/usr.local.sbin.secure-passwd -W
apparmor_parser -r /etc/apparmor.d/usr.local.sbin.secure-sshkeys -W
apparmor_parser -r /etc/apparmor.d/usr.local.sbin.secure-admin -W
apparmor_parser -r /etc/apparmor.d/usr.local.sbin.secure-audit-view -W
apparmor_parser -r /etc/apparmor.d/usr.local.sbin.secure-approve -W

aa-enforce /usr/local/sbin/secure-passwd
aa-enforce /usr/local/sbin/secure-sshkeys
aa-enforce /usr/local/sbin/secure-admin
aa-enforce /usr/local/sbin/secure-audit-view
aa-enforce /usr/local/sbin/secure-approve

echo "! AppArmor setup complete."

install -o root -g root -m 0750 -d /var/log/risktotp
install -o root -g root -m 0750 -d /var/lib/risktotp
touch /var/log/risktotp/audit.log
chown root:root /var/log/risktotp/audit.log
chmod 0640 /var/log/risktotp/audit.log
echo "! Folder setup complete."

cat logrotate > /etc/logrotate.d/risktotp

echo "! Logrotate setup complete."

echo "! Install finished."