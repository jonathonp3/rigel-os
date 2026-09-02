#!/bin/bash
set -euo pipefail

# --- 1. PRE-INSTALL IDENTITY ---
# groupadd -r docker || true

# --- 2. AUTOMATED CLEANUP ---
echo "⚙️ Setting up optimization script "
chmod +x /usr/libexec/rigel-os-optimization.sh

# --- 3. FINALISE ---
# docker.service is intentionally disabled for now
systemctl enable \
    sshd.service \
    rigel-os-optimization.service \
    apps-tmpfiles.service

echo "✅ Wolf-OS Custom Assembly Complete! Ready for Deployment."
