#!/bin/bash
set -euo pipefail

# --- 1. PRE-INSTALL IDENTITY ---
# groupadd -r docker || true

# --- 2. AUTOMATED CLEANUP ---
echo "⚙️ Setting up First-Boot cleanup service..."
chmod +x /usr/libexec/rigel-os-optimization.sh

# --- 3. FINALISE ---
systemctl enable \
    sshd.service \
    # docker.service
    rigel-os-optimization.service \
    apps-tmpfiles.service

echo "✅ Wolf-OS Custom Assembly Complete! Ready for Deployment."

