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

# 10. Setup clipboard bridge (only if not already installed)
log "🔧 Checking for clipboard bridge..."

# Detect the real user
REAL_USER=""
if [ -n "$SUDO_USER" ]; then
    REAL_USER="$SUDO_USER"
elif [ -n "$USER" ] && [ "$USER" != "root" ]; then
    REAL_USER="$USER"
else
    # Try to get the logged-in user
    REAL_USER=$(logname 2>/dev/null || echo "")
fi

# If still empty, fallback to first user
if [ -z "$REAL_USER" ]; then
    REAL_USER=$(getent passwd 1000 | cut -d: -f1 2>/dev/null || echo "jonathon")
fi

USER_HOME="/home/$REAL_USER"
SCRIPT_PATH="$USER_HOME/.local/bin/wayland-spice-clipboard.sh"

log "📝 Installing for user: $REAL_USER (home: $USER_HOME)"

if [ -f "$SCRIPT_PATH" ]; then
    log "✅ Clipboard bridge already installed for $REAL_USER, skipping"
else
    log "📦 Installing clipboard bridge for $REAL_USER..."
    
    # Clone the repository
    git clone https://github.com/jonathonp3/kde-wayland-clipboard-bridge /tmp/clipboard-bridge
    cd /tmp/clipboard-bridge
    chmod +x install.sh
    
    # Run the install script as the real user
    su - "$REAL_USER" -c "./install.sh"
    
    # Clean up
    cd /
    rm -rf /tmp/clipboard-bridge
    
    if [ -f "$SCRIPT_PATH" ]; then
        log "✅ Clipboard bridge installed successfully for $REAL_USER"
    else
        log "⚠️  Clipboard bridge installation failed"
    fi
fi

# 11. Disable the service after first boot
log "🔧 Disabling first-boot service..."
systemctl disable rigel-os-optimization.service 2>/dev/null || true
log "✅ Service disabled for future boots"

# 11. Disable the service after first boot
log "🔧 Disabling first-boot service..."
systemctl disable rigel-os-optimization.service 2>/dev/null || true
log "✅ Service disabled for future boots"

# 11. Disable the service after first boot
log "🔧 Disabling first-boot service..."
systemctl disable rigel-os-optimization.service 2>/dev/null || true
log "✅ Service disabled for future boots"

# 11. Disable the service after first boot (since it's a one-time optimization)
log "🔧 Disabling first-boot service..."
systemctl disable rigel-os-optimization.service 2>/dev/null || true
log "✅ Service disabled for future boots"

log "✨ Rigel-OS Optimization tasks complete."
log "📋 Log saved to: $LOG_FILE"

# Always exit with 0 to prevent systemd from retrying
exit 0
