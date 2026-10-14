#!/usr/bin/bash
# First-boot provisioning.

set -euo pipefail

MARKER="/etc/rigel-os/rigel-os-provisioned"

echo "Rigel-OS: provisioning template..."

systemctl daemon-reload
systemctl enable --now sshd.service 2>/dev/null || :
# systemctl enable --now docker.service 2>/dev/null || :
systemctl enable --now rigel-os-optimization.service 2>/dev/null || :


# --- 5. Write the provisioning marker ---------------------------------
mkdir -p /etc/rigel-os
touch "$MARKER"

echo "Rigel-OS: template provisioning complete"
