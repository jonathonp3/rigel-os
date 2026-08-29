#!/bin/bash
set -euo pipefail

# Configuration
REMOTE_NAME="wolf-os-apps"
REMOTE_URL="https://jonathonp3.github.io/wolf-os-apps/"
GPG_URL="https://raw.githubusercontent.com/jonathonp3/wolf-os-apps/main/wolf-os-apps.gpg"
GPG_TEMP="/tmp/wolf-os-apps.gpg"
APP_ID="org.gnome.TextEditor"
LOG_FILE="/var/log/rigel-os-optimization.log"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

log "🚀 Starting Wolf-OS First-Boot Optimization..."

# 1. Integrity Check: Fix any interrupted previous attempts
log "🔧 Running flatpak repair (may take several minutes)..."
timeout 300 flatpak repair --system --verbose || {
    exit_code=$?
    if [ $exit_code -eq 124 ]; then
        log "⚠️  flatpak repair timed out after 5 minutes, continuing anyway..."
    else
        log "⚠️  flatpak repair exited with code $exit_code, continuing..."
    fi
}

# 2. Ensure Flathub is enabled system-wide for dependencies (GNOME Platform)
log "📦 Ensuring Flathub is available for runtimes..."
flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
flatpak remote-modify --system --enable flathub 2>/dev/null || true

# 3. Add Wolf-OS Custom App Store
log "📦 Connecting to Wolf-OS App Store..."
if wget2 -q -O "$GPG_TEMP" "$GPG_URL" 2>/dev/null || wget -q -O "$GPG_TEMP" "$GPG_URL" 2>/dev/null; then
    if [[ -f "$GPG_TEMP" && -s "$GPG_TEMP" ]]; then
        flatpak remote-add --system --if-not-exists --gpg-import="$GPG_TEMP" "$REMOTE_NAME" "$REMOTE_URL" 2>/dev/null || true
        rm -f "$GPG_TEMP"
    fi
else
    log "⚠️  Could not download GPG key, continuing without Wolf-OS repo..."
fi

# 4. Check if the Wolf-OS version of the app is already installed
if flatpak list --system --columns=application,origin 2>/dev/null | grep -qE "${APP_ID}.*${REMOTE_NAME}"; then
    log "✅ Wolf-OS Custom Editor is already active. Checking for updates..."
    flatpak update --system -y "$APP_ID" 2>/dev/null || true
else
    log "🔄 Swapping stock editor for Wolf-OS Custom version..."
    flatpak uninstall --system -y "$APP_ID" 2>/dev/null || true
    if flatpak install --system -y "$REMOTE_NAME" "$APP_ID" 2>/dev/null; then
        log "✅ Wolf-OS Custom Editor installed successfully"
    else
        log "⚠️  Failed to install Wolf-OS Custom Editor, continuing..."
    fi
fi

# 5. Wolf-OS App Hardening: Element/Riot Keyring Fix
log "🔐 Hardening Element/Riot Keyring Integration..."
flatpak override --system \
  --filesystem=/run/dbus/system_bus_socket \
  --talk-name=org.freedesktop.secrets \
  --env=PASSWORD_STORE=gnome-libsecret \
  im.riot.Riot 2>/dev/null || true

# 6. Apply Global Theming Override
log "🎨 Applying theming overrides..."
flatpak override --system --filesystem=xdg-config/gtk-4.0:ro 2>/dev/null || true
flatpak override --system --filesystem=xdg-config/gtk-3.0:ro 2>/dev/null || true

# 7. Final Optimization: Remove unused runtimes to save space
log "🧹 Removing unused runtimes..."
flatpak uninstall --system --unused -y 2>/dev/null || true

# 8. Remove old Gnome Extensions app
log "📦 Removing old Gnome Extensions app..."
flatpak remove -y org.gnome.Extensions 2>/dev/null || {
    log "ℹ️  org.gnome.Extensions not found or already removed"
}

# 9. Install Flatpaks
log "📦 Installing required Flatpaks..."

# Array of flatpaks to install
flatpaks=(
    "com.mattjakeman.ExtensionManager"
    "org.mozilla.firefox"
)

for app in "${flatpaks[@]}"; do
    log "📦 Installing $app..."
    if flatpak install --system -y flathub "$app" 2>/dev/null; then
        log "✅ $app installed successfully"
    else
        log "❌ Failed to install $app"
    fi
done

# 10. Setup clipboard bridge for KDE Wayland to SPICE
log "🔧 Setting up clipboard bridge for KDE Wayland..."
if command -v wl-paste &>/dev/null && command -v xclip &>/dev/null; then
    # Use the pre-installed bridge script from /usr/libexec
    if [ -f "/usr/libexec/wayland-spice-clipboard.sh" ]; then
        BRIDGE_SCRIPT="/usr/libexec/wayland-spice-clipboard.sh"
        log "✅ Using pre-installed bridge script from /usr/libexec"
    else
        # Fallback: create the script
        cat > /usr/local/bin/spice-clipboard-bridge << 'BRIDGE_EOF'
#!/bin/bash
while true; do
    wl-paste --primary 2>/dev/null | xclip -selection clipboard -in 2>/dev/null
    sleep 0.5
done
BRIDGE_EOF
        chmod +x /usr/local/bin/spice-clipboard-bridge
        BRIDGE_SCRIPT="/usr/local/bin/spice-clipboard-bridge"
        log "✅ Fallback clipboard bridge script created"
    fi
    
    # Create system service
    cat > /etc/systemd/system/spice-clipboard-bridge.service << 'SERVICE_EOF'
[Unit]
Description=SPICE Wayland Clipboard Bridge for KDE
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/libexec/wayland-spice-clipboard.sh
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SERVICE_EOF
    
    # Update ExecStart to use the correct script
    sed -i "s|ExecStart=.*|ExecStart=$BRIDGE_SCRIPT|g" /etc/systemd/system/spice-clipboard-bridge.service
    
    systemctl daemon-reload
    systemctl enable spice-clipboard-bridge.service 2>/dev/null || true
    systemctl start spice-clipboard-bridge.service 2>/dev/null || true
    log "✅ Clipboard bridge service enabled and started"
else
    log "⚠️  wl-paste or xclip not found - clipboard bridge skipped"
fi

# 11. Disable the service after first boot (since it's a one-time optimization)
log "🔧 Disabling first-boot service..."
systemctl disable rigel-os-optimization.service 2>/dev/null || true
log "✅ Service disabled for future boots"

log "✨ Rigel-OS Optimization tasks complete."
log "📋 Log saved to: $LOG_FILE"

# Always exit with 0 to prevent systemd from retrying
exit 0
