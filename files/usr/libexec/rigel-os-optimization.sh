#!/bin/bash
set -euo pipefail

# Configuration
LOG_FILE="/var/log/rigel-os-optimization.log"

# Flatpaks to install from Flathub
flatpaks=(
    "org.mozilla.firefox"       # Web browser
    "org.kde.elisa"             # Music player
    "org.kde.gwenview"          # Image viewer
    "org.kde.okular"            # Document viewer
)

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

log "🚀 Starting Rigel-OS First-Boot Optimization..."

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

# 2. Ensure Flathub is enabled system-wide
log "📦 Ensuring Flathub is available..."
flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
flatpak remote-modify --system --enable flathub 2>/dev/null || true

# 3. Replace any Fedora-remote copies with Flathub versions
log "🔄 Checking for Fedora-remote copies to replace..."
for app in "${flatpaks[@]}"; do
    current_origin=$(flatpak list --system --columns=application,origin 2>/dev/null \
        | awk -v id="$app" '$1==id {print $2}' | head -n1)
    if [ -n "$current_origin" ] && [ "$current_origin" != "flathub" ]; then
        log "🔄 Replacing $app (was: $current_origin) with Flathub version..."
        flatpak uninstall --system -y "$app" 2>/dev/null || true
    fi
done

# 4. Apply Global Theming Override
log "🎨 Applying theming overrides..."
flatpak override --system --filesystem=xdg-config/gtk-4.0:ro 2>/dev/null || true
flatpak override --system --filesystem=xdg-config/gtk-3.0:ro 2>/dev/null || true

# 5. Final Optimization: Remove unused runtimes to save space
log "🧹 Removing unused runtimes..."
flatpak uninstall --system --unused -y 2>/dev/null || true

# 6. Install Flatpaks from Flathub
log "📦 Installing required Flatpaks from Flathub..."
for app in "${flatpaks[@]}"; do
    log "📦 Installing $app..."
    if flatpak install --system -y flathub "$app" 2>/dev/null; then
        log "✅ $app installed successfully"
    else
        log "❌ Failed to install $app"
    fi
done

# 6b. Remove Fedora-remote apps not in the curated set
log "🧹 Removing unwanted Fedora-remote apps..."
for app in $(flatpak list --system --columns=application,origin 2>/dev/null \
             | awk '$2=="fedora" {print $1}'); do
    log "🗑  Removing $app (fedora remote)"
    flatpak uninstall --system -y "$app" 2>/dev/null || true
done

# Drop the stale Wolf-OS remote if present
if flatpak remotes --system 2>/dev/null | grep -q "^wolf-os-apps"; then
    log "🗑  Removing stale wolf-os-apps remote..."
    flatpak remote-delete --system wolf-os-apps 2>/dev/null || true
fi

# Now that apps are gone, clean up orphaned runtimes
log "🧹 Removing newly-unused runtimes..."
flatpak uninstall --system --unused -y 2>/dev/null || true

# 7. Setup clipboard bridge
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

# 8. Disable the service after first boot
log "🔧 Disabling first-boot service..."
systemctl disable rigel-os-optimization.service 2>/dev/null || true
log "✅ Service disabled for future boots"

log "✨ Rigel-OS Optimization tasks complete."
log "📋 Log saved to: $LOG_FILE"

exit 0

