#!/bin/bash
set -euo pipefail

# Configuration
REMOTE_NAME="wolf-os-apps"
REMOTE_URL="https://jonathonp3.github.io/wolf-os-apps/"
GPG_URL="https://raw.githubusercontent.com/jonathonp3/wolf-os-apps/main/wolf-os-apps.gpg"
GPG_TEMP="/tmp/wolf-os-apps.gpg"
APP_ID="org.gnome.TextEditor"

echo "🚀 Starting Wolf-OS First-Boot Optimization..."

# 1. Integrity Check: Fix any interrupted previous attempts
flatpak repair --system || :

# 2. Ensure Flathub is enabled system-wide for dependencies (GNOME Platform)
echo "📦 Ensuring Flathub is available for runtimes..."
flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || :
flatpak remote-modify --system --enable flathub || :

# 3. Add Wolf-OS Custom App Store
echo "📦 Connecting to Wolf-OS App Store..."
wget2 -q -O "$GPG_TEMP" "$GPG_URL" || wget -q -O "$GPG_TEMP" "$GPG_URL" || :
if [[ -f "$GPG_TEMP" ]]; then
    flatpak remote-add --system --if-not-exists --gpg-import="$GPG_TEMP" "$REMOTE_NAME" "$REMOTE_URL" || :
    rm -f "$GPG_TEMP"
fi

# 4. Check if the Wolf-OS version of the app is already installed
# This prevents unnecessary uninstalls/reinstalls on subsequent runs
if flatpak list --system --columns=application,origin | grep -qE "${APP_ID}.*${REMOTE_NAME}"; then
    echo "✅ Wolf-OS Custom Editor is already active. Checking for updates..."
    flatpak update --system -y "$APP_ID" || :
else
    echo "🔄 Swapping stock editor for Wolf-OS Custom version..."
    # Remove the stock version if it exists
    flatpak uninstall --system -y "$APP_ID" || :
    # Install from Wolf-OS repo
    flatpak install --system -y "$REMOTE_NAME" "$APP_ID"
fi

# 5. Wolf-OS App Hardening: Element/Riot Keyring Fix
# Apply these BEFORE the app is run to ensure first-time success.
echo "🔐 Hardening Element/Riot Keyring Integration..."
flatpak override --system \
  --filesystem=/run/dbus/system_bus_socket \
  --talk-name=org.freedesktop.secrets \
  --env=PASSWORD_STORE=gnome-libsecret \
  im.riot.Riot || :

# 6. Apply Global Theming Override (ensures GTK themes match the OS)
echo "🎨 Applying theming overrides..."
flatpak override --system --filesystem=xdg-config/gtk-4.0:ro || :
flatpak override --system --filesystem=xdg-config/gtk-3.0:ro || :

# 6. Final Optimization: Remove unused runtimes to save space
flatpak uninstall --system --unused -y || :

# 7. Remove flatpaks
flatpak remove -y org.gnome.Extensions

# 8. Install Flatpaks
flatpak install --system -y flathub com.mattjakeman.ExtensionManager
flatpak install --system -y flathub com.transmissionbt.Transmission
flatpak install --system -y flathub org.mozilla.firefox
flatpak install --system -y flathub org.qbittorrent.qBittorrent


echo "✨ Rigel-OS Optimization tasks complete."

