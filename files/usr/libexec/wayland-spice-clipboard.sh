#!/bin/bash
# SPDX-License-Identifier: MIT
# SPICE Clipboard Bridge for KDE Wayland
# Syncs Wayland and KDE clipboards to X11 for SPICE compatibility

set -euo pipefail

get_wayland_clipboard() {
    wl-paste --primary 2>/dev/null || echo ""
}

get_kde_clipboard() {
    qdbus org.kde.klipper /klipper getClipboardContents 2>/dev/null || echo ""
}

while true; do
    # Get clipboard from Wayland primary
    WAYLAND=$(get_wayland_clipboard)
    
    if [ -n "$WAYLAND" ]; then
        CURRENT_X11=$(xclip -selection clipboard -out 2>/dev/null || echo "")
        if [ "$WAYLAND" != "$CURRENT_X11" ]; then
            echo "$WAYLAND" | xclip -selection clipboard -in 2>/dev/null
        fi
    fi
    
    # Also try KDE clipboard
    KDE_CLIP=$(get_kde_clipboard)
    if [ -n "$KDE_CLIP" ]; then
        CURRENT_X11=$(xclip -selection clipboard -out 2>/dev/null || echo "")
        if [ "$KDE_CLIP" != "$CURRENT_X11" ]; then
            echo "$KDE_CLIP" | xclip -selection clipboard -in 2>/dev/null
        fi
    fi
    
    sleep 0.5
done
