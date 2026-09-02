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
        log "⚠  flatpak repair timed out after 5 minutes, continuing anyway..."
    else
        log "⚠  flatpak repair exited with code $exit_code, continuing..."
    fi
}

# 2. Ensure Flathub is enabled system-wide for dependencies
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
    log "⚠  Could not download GPG key, continuing without Wolf-OS repo..."
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
        log "⚠  Failed to install Wolf-OS Custom Editor, continuing..."
    fi
fi

# 5. Apply Global Theming Override
log "🎨 Applying theming overrides..."
flatpak override --system --filesystem=xdg-config/gtk-4.0:ro 2>/dev/null || true
flatpak override --system --filesystem=xdg-config/gtk-3.0:ro 2>/dev/null || true

# 6. Final Optimization: Remove unused runtimes to save space
log "🧹 Removing unused runtimes..."
flatpak uninstall --system --unused -y 2>/dev/null || true

# 7. Install Flatpaks (KDE/Plasma)
log "📦 Installing required Flatpaks..."

# KDE-native applications installed via Flatpak
flatpaks=(
    "org.mozilla.firefox"      # Web browser
    # "org.kde.kate"           # Text editor (optional)
    # "org.kde.kcalc"          # Calculator (optional)
    # "org.kde.gwenview"       # Image viewer (optional)
)

for app in "${flatpaks[@]}"; do
    log "📦 Installing $app..."
    if flatpak install --system -y flathub "$app" 2>/dev/null; then
        log "✅ $app installed successfully"
    else
        log "❌ Failed to install $app"
    fi
done

# 8. Setup clipboard bridge
log "🔧 Checking for clipboard bridge..."

# Detect the real user
REAL_USER=""
if [ -n "${SUDO_USER:-}" ]; then
    REAL_USER="$SUDO_USER"
elif [ -n "${USER:-}" ] && [ "$USER" != "root" ]; then
    REAL_USER="$USER"
else
    REAL_USER=$(logname 2>/dev/null || echo "")
fi

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

    rm -rf /tmp/clipboard-bridge
    git clone https://github.com/jonathonp3/kde-wayland-clipboard-bridge /tmp/clipboard-bridge

    mkdir -p "$USER_HOME/.local/bin"
    mkdir -p "$USER_HOME/.config/systemd/user"
    mkdir -p "$USER_HOME/.config/autostart"

    cp /tmp/clipboard-bridge/wayland-spice-clipboard.sh "$USER_HOME/.local/bin/"
    cp /tmp/clipboard-bridge/wayland-spice-clipboard.service "$USER_HOME/.config/systemd/user/"
    cp /tmp/clipboard-bridge/import-env.desktop "$USER_HOME/.config/autostart/"

    chmod +x "$USER_HOME/.local/bin/wayland-spice-clipboard.sh"
    chown -R "$REAL_USER":"$REAL_USER" "$USER_HOME/.local"
    chown -R "$REAL_USER":"$REAL_USER" "$USER_HOME/.config"

    systemctl --user -M "$REAL_USER@" daemon-reload
    systemctl --user -M "$REAL_USER@" enable wayland-spice-clipboard.service
    systemctl --user -M "$REAL_USER@" start wayland-spice-clipboard.service

    rm -rf /tmp/clipboard-bridge

    if [ -f "$SCRIPT_PATH" ]; then
        log "✅ Clipboard bridge installed successfully for $REAL_USER"
    else
        log "⚠  Clipboard bridge installation failed"
    fi
fi

# 9. Disable the service after first boot
log "🔧 Disabling first-boot service..."
systemctl disable rigel-os-optimization.service 2>/dev/null || true
log "✅ Service disabled for future boots"

log "✨ Rigel-OS Optimization tasks complete."
log "📋 Log saved to: $LOG_FILE"

exit 0

