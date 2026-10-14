#!/bin/bash
set -euo pipefail

# --- 1. PRE-INSTALL IDENTITY ---
# groupadd -r docker || true

# --- 2. AUTOMATED CLEANUP ---
echo "⚙️ Setting up optimization script "
chmod +x /usr/libexec/rigel-os-optimization.sh
chmod +x /usr/libexec/rigel-os-provision.sh

# --- 3. ENABLE SYSTEMD UNITS IN THE VENDOR LAYER ---
mkdir -p /usr/lib/systemd/system/multi-user.target.wants

ln -sf ../rigel-os-provision.service \
    /usr/lib/systemd/system/multi-user.target.wants/rigel-os-provision.service
echo "✅ Rigel-OS Custom Assembly Complete! Ready for Deployment."
